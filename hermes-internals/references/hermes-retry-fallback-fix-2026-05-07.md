---
name: hermes-retry-fallback-fix
description: "Hermes Agent retry/fallback rate limit behavior — root cause, fix pattern, and key code locations in run_agent.py"
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [hermes-agent, retry, fallback, rate-limit, run-agent, internals]
    related_skills: [hermes-internal-debugging, systematic-debugging]
---

# Hermes Retry/Fallback Rate Limit Fix

## Problem (2026-05-07)

When MiniMax CN hit HTTP 429, Hermes switched to fallback providers with **zero delay**
between attempts. The fallback chain (OpenRouter free models) got exhausted in seconds —
each attempt hit the next provider without any cooldown, triggering cascading failures.

## Root Cause Locations (`~/.hermes/hermes-agent/run_agent.py`)

| Line (approx) | Issue |
|----------------|-------|
| ~13030 | `jittered_backoff(base_delay=10, max_delay=60)` — intervals too short |
| ~12553 | Rate limit eager fallback: **no delay** before switching to next provider |
| ~12949 | Max retries exhausted → fallback: **no delay** between providers |
| ~12889 | Non-retryable client error → fallback: **no delay** |

## Fix Applied

### 1. Normal retry backoff — base_delay 10→15, max_delay 60→90
```python
wait_time = jittered_backoff(retry_count, base_delay=15.0, max_delay=90.0)
```

### 2. Rate limit eager fallback — wait 15-45s before next provider
```python
_fb_wait = jittered_backoff(
    self._fallback_index + 1,
    base_delay=15.0, max_delay=45.0,
)
time.sleep(_fb_wait)
self._try_activate_fallback(reason=classified.reason)
```

### 3. Fallback chain cooldown — 30-120s, increasing per index
```python
_fallback_cooldown = jittered_backoff(
    self._fallback_index + 1,
    base_delay=30.0, max_delay=120.0,
)
time.sleep(_fallback_cooldown)
self._try_activate_fallback()
```

### 4. Client error fallback — 10-30s brief pause
```python
time.sleep(jittered_backoff(1, base_delay=10.0, max_delay=30.0))
```

## Key Pattern

When fixing rate limit behavior in a fallback chain:
- **Always add cooldown before switching providers** — prevents cascading failures
  that burn through the entire fallback chain in seconds.
- **Make cooldown increase with fallback_index** — later fallbacks get longer
  waits since earlier ones have already been tried.
- **Use `jittered_backoff`, not fixed `time.sleep`** — prevents thundering-herd
  when multiple sessions retry simultaneously.
- **Verify with `python3 -m py_compile`** before restarting Hermes.

## Fallback Chain Flow

```
Primary (MiniMax CN) → 429
  ↓ +15-45s jittered wait
Fallback #1 (OpenRouter free) → 429
  ↓ +30-120s jittered wait (higher index = longer wait)
Fallback #2 (OpenRouter free) → ...
```

## Provider-Specific Notes

- **MiniMax CN**: Token Plan rate limits are quota-based, not request-count-based.
  Rotation can't recover — skip straight to fallback.
- **OpenRouter free models**: Connection errors common; transient transport errors
  can be retried with rebuilt client via `_try_recover_primary_transport`.
- **`_pool_may_recover_from_rate_limit()`**: Check this before eager fallback —
  some providers can recover via credential rotation.
