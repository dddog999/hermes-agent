This file documents the PAT workflow scope pitfall encountered when pushing upstream merges to a fork.

## Symptoms

After merging upstream/main into your fork branch, `git push fork BRANCH` fails with:
```
! [remote rejected] fix/patch-timeout -> fix/patch-timeout
(refusing to allow a Personal Access Token to create or update workflow
`.github/workflows/docker-publish.yml` without `workflow` scope)
```

## Root Cause

GitHub Personal Access Tokens (PATs) used for git pushes need the `workflow` scope
to modify any file under `.github/workflows/` or `.github/actions/`. If your PAT
was created without this scope (common for read-only or code-only tokens), pushes
containing workflow changes will be rejected at the server level — it's a server-side
check, not a client-side one.

## Recovery Procedure

1. **Check what workflow files changed in the merge:**
   ```bash
   git diff --stat HEAD -- ".github/"
   ```

2. **Get the remote branch's commit SHA:**
   ```bash
   SHA=$(git ls-remote fork BRANCH_NAME | awk '{print $1}')
   ```

3. **Restore workflow files to the remote branch version:**
   ```bash
   git show $SHA:.github/workflows/docker-publish.yml > .github/workflows/docker-publish.yml
   git show $SHA:.github/workflows/lint.yml > .github/workflows/lint.yml
   # repeat for any other workflow files that changed
   ```

4. **For newly-added workflow files from upstream (not in remote branch):**
   ```bash
   git reset HEAD -- .github/workflows/uv-lockfile-check.yml
   echo ".github/workflows/uv-lockfile-check.yml" >> .git/info/exclude
   ```

5. **Amend the merge commit and push:**
   ```bash
   git add .github/workflows/docker-publish.yml .github/workflows/lint.yml
   git commit --amend --no-edit
   git push fork BRANCH_NAME
   ```

## Verification

After push succeeds, verify with `git diff --stat fork/BRANCH_NAME` to ensure
no unintended files were excluded.
