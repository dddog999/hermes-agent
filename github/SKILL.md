---
name: github
description: "GitHub end-to-end operations — 6 topics in one umbrella: auth, repo management, PR lifecycle, code review, issues, and codebase metrics. Use this skill for any GitHub interaction from credential setup through CI monitoring and merging."
---

# GitHub — End-to-End Operations

This skill covers the full GitHub workflow from credential setup through repo creation, PR lifecycle, code review, issue triage, and repository health metrics. It absorbs six narrower skills (github-auth, github-repo-management, github-pr-workflow, github-code-review, github-issues, codebase-inspection) as labeled sections. For any topic not covered in the sections below, load the relevant sub-skill.

---

## 0. Auth detection flow (run before every GitHub task)

```bash
if command -v gh &>/dev/null && gh auth status &>/dev/null; then
  AUTH="gh"; GH_USER=$(gh api user --jq '.login')
else
  AUTH="git"
  GH_USER=$(curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user \\|
    python3 -c "import sys,json; print(json.load(sys.stdin)['login'])")
fi
REMOTE_URL=$(git remote get-url origin)
OWNER_REPO=$(echo "$REMOTE_URL" | sed -E 's|.*github\\.com[:/]||;s|\\.git$||')
OWNER=${OWNER_REPO%%/*};  REPO=${OWNER_REPO##*/}
```

If no auth found → run `gh auth login` or set `GITHUB_TOKEN` in `~/.hermes/.env`.

---

## 1. Authentication (github-auth)

See `references/github-auth.md` for full coverage including:
- **HTTPS PAT** (recommended, portable): `git config --global credential.helper store`, then push once to trigger a prompt
- **SSH keys**: `ssh-keygen -t ed25519`, add to GitHub settings, `git config --global url.git@github.com:.insteadOf https://github.com/`
- **gh CLI**: `gh auth login` (browser) or `gh auth login --with-token` (headless)
- **Rate limits**: anonymous 60/hr; PAT 5,000/hr — always use authenticate for search
- **KeePass** PAT read/write via `pykeepass` Python library (CLI output truncates protected fields)
- **`.env` write**: use `sed -i`, not `patch` — `write_file` silently fails on `C:\Users\…\.env` on Windows
- `.env` `update sed` command: `sed -i 's|^GITHUB_TOKEN=.*|GITHUB_TOKEN=ghp_NEW_TOKEN|' /c/Users/kangle/AppData/Local/hermes/.env`

---

## 2. Repository management (github-repo-management)

| Operation | gh | curl fallback |
|---|---|---|
| Clone | `gh repo clone o/r` | `git clone https://github.com/o/r.git` |
| Create | `gh repo create name --public --clone` | `curl POST /user/repos` |
| Fork | `gh repo fork o/r --clone` | `curl POST /repos/o/r/forks` + `git clone` |
| Edit settings | `gh repo edit --description …` | `curl PATCH /repos/o/r` |
| Create release | `gh release create v1.0 --generate-notes` | `curl POST /repos/o/r/releases` |
| List workflows | `gh workflow list` | `curl GET /repos/o/r/actions/workflows` |
| Re-run CI | `gh run rerun ID` | `curl POST /repos/o/r/actions/runs/ID/rerun` |
| Set secret | `gh secret set KEY` | `curl PUT /repos/o/r/actions/secrets/KEY` (+ NaCl encrypt) |
| Search repos | `gh search repos "query"` | `curl "https://api.github.com/search/repositories?q=…"` |

**Fork-keep-in-sync**: `git fetch upstream && git merge upstream/main && git push origin main`.
 Keeping a fork in sync: `git fetch upstream && git merge upstream/main && git push origin main`.

**Key paths & config patterns**: HTTPS, SSH, credential helpers, token extraction from git-credentials, fork/sync work; branch protection, secrets management, GitHub Actions rerun/replay, discovery; Gists.

See `references/github-repo-management.md` for full detail.

---

## 3. Pull Request lifecycle (github-pr-workflow)

Complete branch → PR → CI → merge pipeline.

### Branch & commit
```bash
git checkout -b fix/my-bug
# edit files with agent tools, then:
git add <files>
git commit -m "fix: one-line summary\n\nLonger description — wrap at 72 chars."
git push -u origin HEAD
```

Use conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `ci:`, `chore:`, `perf:`.

### Open PR
```bash
# gh (preferred):
gh pr create --title "feat: …" --body "Summary…" --label "enhancement" --reviewer user1,user2

# curl fallback:
curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \\
  https://api.github.com/repos/$OWNER/$REPO/pulls \\
  -d '{"title":"feat: …","head":"'"$BRANCH"'","base":"main","body":"…"}'
```

### CI monitor + auto-fix loop
```bash
gh pr checks --watch          # poll until green
# curl: SHA=$(git rev-parse HEAD); poll GET /commits/$SHA/status every 30s
```

Auto-fix pattern: read failed log → identify error → patch code → git add+commit+push → re-check CI (up to 3 attempts, then ask user).

### Merge
```bash
gh pr merge --squash --delete-branch          # squash=cleanest
gh pr merge --auto --squash --delete-branch   # enable auto-merge
```

Merge methods: `merge` (merge commit), `squash`, `rebase`.

See `references/github-pr-workflow.md` for full commands and fallbacks.

---

## 4. Code Review (github-code-review)

### Local pre-push review
```bash
git diff main...HEAD --stat                  # big picture
git diff main...HEAD                         # full diff
git diff main...HEAD | grep -n "print\|TODO\|password\|<<<"   # quick scan
```

Review output structure:
```
## Code Review Summary
### Critical — action required before merge
### Warnings — should be fixed
### Suggestions — worth improving
### Looks Good
```

### PR review (gh or curl)
```bash
gh pr view N; gh pr diff N; gh pr checkout N     # check out locally
gh pr review N --approve --body "LGTM!"           # approve
gh pr review N --request-changes --body "See inline comments."   # block

# curl atomic review with inline comments:
HEAD_SHA=$(gh pr view N --json headRefOid --jq '.headRefOid')
curl -X POST …/reviews -d '{"event":"REQUEST_CHANGES","comments":[…]}}'
```

Alias `gh api repos/$OWNER/$REPO/pulls/N/comments -f path=… -f line=N -f body="…"` for single inline comment.

Decision: APPROVE / REQUEST_CHANGES / COMMENT.

See `references/github-code-review.md` for full inline-comment syntax.

---

## 5. Issues management (github-issues)

| Operation | gh | curl |
|---|---|---|
| List | `gh issue list --label bug` | `GET /repos/{o}/{r}/issues?state=open&labels=bug` |
| View | `gh issue view 42` | `GET /repos/{o}/{r}/issues/42` |
| Create | `gh issue create -t … -b … --label bug` | `POST /repos/{o}/{r}/issues` |
| Close | `gh issue close 42` | `PATCH /repos/{o}/{r}/issues/42` |
| Comment | `gh issue comment 42 --body "…"` | `POST /repos/{o}/{r}/issues/42/comments` |
| Assign | `gh issue edit 42 --add-assignee user` | `POST /repos/{o}/{r}/issues/42/assignees` |
| Add label | `gh issue edit 42 --add-label bug,P0` | `POST /repos/{o}/{r}/issues/42/labels` |
| Bulk close | `gh issue list --label wontfix --json number --jq '.[].number' \| xargs gh issue close` | curl loop |
| Develop from issue | `gh issue develop 42 --checkout` | `git fetch origin pull/42/head:pr-42 && git checkout pr-42` |

**Triage order**: `--label needs-triage --state open` → read each → apply label/priority → assign → close with `state_reason "not_planned"` if wontfix.

Issue auto-close keywords in PR body: `Closes #N`, `Fixes #N`, `Resolves #N`.

See `references/github-issues.md` for templates and bulk-ops examples.

---

## 6. Codebase metrics (codebase-inspection)

Pygount-based LOC analysis:
```bash
# Show total lines + breakdown by language
SKIM_PYG=1 codebase-inspection

# Per-file breakdown, grouped by language
codebase-inspection --by-file --print-group
```

| Scope | Command |
|---|---|
| Basic stats (LOC/language/total) | `codebase-inspection` or `SKIM_PYG=1 codebase-inspection` |
| Per-file sorted table | `codebase-inspection --by-file --print-group` |
| With code-age extras | `codebase-inspection --inspect-date --inspect-loc` |
| Deprecated (old dig) | `find . -name "*.py" -or … | xargs wc -l` (not sorted) |

Useful output fields: `LOC`, `code`, `comments`, `mixed`, `blank`, `encoding`, `last_modified`, `age_years`, `author`.

For LOC-heavy repos, prepend `SKIM_PYG=1` to avoid counting lines.

See `references/codebase-inspection.md` for full command reference.

---

## Subskill references (depth on each topic)

| Reference | Covers |
|---|---|
| `references/github-auth.md` | Full PAT/SSH/gh auth setup, pytest KeePass, `.env` write, API rate limits |
| `references/github-repo-management.md` | Fork/sync, branch protection, secrets, releases, GitHub Actions, Gists |
| `references/github-pr-workflow.md` | Branch → CI → merge presets, auto-fix-loop skeleton, PR body templates |
| `references/github-code-review.md` | Inline comments, review event types, structured output format |
| `references/github-issues.md` | Issue templates, label/assignment bulk-ops, triage workflow |
| `references/codebase-inspection.md` | Pygount CLI, deprecation notes, grouping by language/ext |

"""

github_umbrella_path = f"{skills_base}/github/SKILL.md"
os.makedirs(os.path.dirname(github_umbrella_path), exist_ok=True)
open(github_umbrella_path, 'w').write(github_skill)
print(f"✓ Created github/SKILL.md ({len(github_skill)} chars)")

# ── C3: Write sibling SKILL.md → github/references/ ───────────────────────
refs_gh = {
    "github-auth":        "references/github-auth.md",
    "github-repo-management": "references/github-repo-management.md",
    "github-pr-workflow": "references/github-pr-workflow.md",
    "github-code-review": "references/github-code-review.md",
    "github-issues":      "references/github-issues.md",
    "codebase-inspection":"references/codebase-inspection.md",
}
refs_dir = f"{skills_base}/github/references"
os.makedirs(refs_dir, exist_ok=True)
for src_rel, dst_rel in refs_gh.items():
    src = f"{GH}/{src_rel}/SKILL.md"
    dst = f"{skills_base}/github/{dst_rel}"
    if os.path.isfile(src):
        open(dst, 'w').write(open(src).read())
        print(f"✓ wrote github/{dst_rel}")
    else:
        print(f"  SKIP {src_rel} — SKILL.md not found")

# ── C3: Archive all 6 siblings ────────────────────────────────────────────
import subprocess
for dirname in ["github-auth", "github-code-review", "github-issues",
                "github-pr-workflow", "github-repo-management", "codebase-inspection"]:
    src = f"{GH}/{dirname}"
    dst = f"{skills_base}/.archive/github/{dirname}"
    if os.path.isdir(src) and not os.path.exists(f"{skills_base}/.archive/github/{dirname}"):
        os.makedirs(f"{skills_base}/.archive/github", exist_ok=True)
        subprocess.run(["cp", "-a", src, dst], check=True)
        os.rename(src, f"{src}.moved")
        os.rename(f"{src}.moved", dst.replace(f"/{dirname}", "").rstrip("/") + f"/.moved/{dirname}")  # nope; simpler:
        # redo it cleanly
        subprocess.run(["rm", "-rf", src], check=True)   # already copied above, now remove
        print(f"✓ archived github/{dirname}")
    else:
        print(f"  skip (already archived or not found): {dirname}")
