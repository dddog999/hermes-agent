# GitHub Actions 自动同步上游方案

## 目标

每周日 03:00 UTC 自动将 NousResearch/hermes-agent (upstream/main) 的内容同步到 dddog999/hermes-agent (origin/main)。

## 核心挑战

GitHub Actions runner 里的 `actions/checkout@v4` 遇到 git push 时，GitHub App 权限限制导致 workflow 文件无法被 git push 修改。需用纯 GitHub API 方案绕过。

## 最终方案：纯 API 同步

### 原理
1. 不 checkout 仓库，用 gh api 读取 upstream 和 origin 的 commit SHA 和 tree SHA
2. 比较 tree SHA（相同 = 内容已同步，无需处理 commit 历史差异）
3. 用 `gh api /git/commits` 创建新 commit（upstream 的 tree + origin 的 parent）
4. 用 `gh api /git/refs/heads/main` 更新分支引用

### Workflow YAML

```yaml
name: Sync upstream

on:
  schedule:
    - cron: "0 3 * * 0"  # 每周日 03:00 UTC
  workflow_dispatch:

permissions:
  contents: write

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - name: Check sync status
        id: check
        env:
          PAT: ${{ secrets.GH_TOKEN }}
        run: |
          ORIGIN_SHA=$(gh api repos/${{ github.repository }}/git/refs/heads/main --jq '.object.sha')
          UPSTREAM_SHA=$(gh api repos/NousResearch/hermes-agent/git/refs/heads/main --jq '.object.sha')
          ORIGIN_TREE=$(gh api repos/${{ github.repository }}/git/commits/$ORIGIN_SHA --jq '.tree.sha')
          UPSTREAM_TREE=$(gh api repos/NousResearch/hermes-agent/git/commits/$UPSTREAM_SHA --jq '.tree.sha')
          echo "origin_sha=$ORIGIN_SHA" >> $GITHUB_OUTPUT
          echo "upstream_sha=$UPSTREAM_SHA" >> $GITHUB_OUTPUT
          echo "origin_tree=$ORIGIN_TREE" >> $GITHUB_OUTPUT
          echo "upstream_tree=$UPSTREAM_TREE" >> $GITHUB_OUTPUT
          [ "$ORIGIN_TREE" = "$UPSTREAM_TREE" ] && echo "in_sync=true" >> $GITHUB_OUTPUT || echo "in_sync=false" >> $GITHUB_OUTPUT

      - name: Sync to upstream tree
        if: steps.check.outputs.in_sync == 'false'
        env:
          PAT: ${{ secrets.GH_TOKEN }}
        run: |
          UPSTREAM_SHA="${{ steps.check.outputs.upstream_sha }}"
          UPSTREAM_TREE="${{ steps.check.outputs.upstream_tree }}"
          ORIGIN_SHA="${{ steps.check.outputs.origin_sha }}"
          NEW_COMMIT=$(gh api repos/${{ github.repository }}/git/commits \
            -F message="chore: sync with upstream/main ($UPSTREAM_SHA)" \
            -F tree="$UPSTREAM_TREE" \
            -F parents[]="$ORIGIN_SHA" \
            --jq '.sha')
          gh api repos/${{ github.repository }}/git/refs/heads/main \
            -X PATCH -F sha="$NEW_COMMIT" -F force=true

      - name: Already in sync
        if: steps.check.outputs.in_sync == 'true'
        run: echo "Already in sync with upstream/main"
```

## 关键设计决策

### Tree SHA 对比 vs Commit Count
- 之前用 `compare API` 查 commit 数量，但 origin 可能通过 API 同步（tree 相同但 commit 历史不同），导致误判
- 用 tree SHA 对比更准确：tree 相同 = 内容完全一致

### 为什么不用 checkout
`actions/checkout@v4` 会设置 git credential helper，使得 push 时 GitHub App 限制被触发（`.github/workflows/` 路径被拒绝）。纯 API 不走 git 协议，绕过此限制。

### GH_TOKEN secret
需要 `repo` scope（用于读写 git objects 和 refs）。设置：
```bash
gh secret set GH_TOKEN --body "$(gh auth token)" --repo owner/repo
```

## sync-upstream.yml 丢失问题

同步后 main 分支的 tree 变成 upstream 的 tree，但 upstream 没有 sync-upstream.yml。**解决方案**：

每次同步后需要把 sync-upstream.yml 重新写回仓库。有两种方式：

### 方式 A：用另一个 workflow 触发（推荐）
在另一个 workflow（如 `sync.yml`）里手动触发 sync-upstream 的 restore 逻辑。

### 方式 B：把 workflow 内容存为 secret
在 `SYNC_WORKFLOW_YAML` secret 里存 base64 编码的 workflow 内容，同步后重新 decode + PUT 到 `.github/workflows/sync-upstream.yml`。

## 已知限制
- 同步后的 commit 历史只有一个 merge commit（`chore: sync with upstream/main`），不是完整的 upstream 历史
- 如果 origin 有独立 commit 需要保留，此方案不适用（会丢失 origin 独有的 commit）
- 当前 origin/main 是干净的（没有自己独有的 commit），所以此方案可用

## 调试命令
```bash
# 检查 main 当前 SHA
gh api repos/owner/repo/git/refs/heads/main --jq '.object.sha'

# 检查 upstream 最新 SHA  
gh api repos/NousResearch/hermes-agent/git/refs/heads/main --jq '.object.sha'

# 对比 tree SHA
gh api repos/owner/repo/git/commits/<sha> --jq '.tree.sha'
gh api repos/NousResearch/hermes-agent/git/commits/<sha> --jq '.tree.sha'

# 手动创建 sync commit
gh api repos/owner/repo/git/commits -F message="sync" -F tree=<upstream_tree_sha> -F parents[]=<origin_sha> --jq '.sha'

# 手动更新 ref
gh api repos/owner/repo/git/refs/heads/main -X PATCH -F sha=<new_commit> -F force=true
```