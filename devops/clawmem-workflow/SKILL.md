---
name: clawmem-workflow
description: ClawMem 项目工作流规范 — planning-with-files、验证checklist、虚假complete反模式
---

# ClawMem 工作流规范

## 工作流：planning-with-files（不是 GSD）

ClawMem 项目使用 planning-with-files（Manus-style）工作流。规则写入 `AGENTS.md`。

### 规划文件（项目根目录）

| 文件 | 用途 | 更新频率 |
|------|------|----------|
| `task_plan.md` | 阶段追踪 + 验收条件 | 每 phase 完成后 |
| `progress.md` | 排查过程详细记录 | 每次错误后 |
| `findings.md` | 决策、关键发现 | 每 2 次 view/search 后 |

### 核心规则

1. **回复前必读** `task_plan.md`，确认当前 phase
2. **执行前先建 plan**：复杂任务先写 task_plan.md 再执行
3. **2-Action Rule**：每 2 次 view/browser/search 后更新 findings.md
4. **phase 完成标准**：必须实际运行 CLI 验证，不能只靠代码存在
5. **3轮对话后强制重读**：task_plan.md + findings.md

## 关键反模式：虚假 complete

**教训（2026-05-04）**：Phase 3-4 代码骨架已存在，task_plan.md 标记 complete，但 CLI 有 `require('os')` bug 跑不起来。

**checklist：phase 标记 complete 前必须验证**
```
node dist/cli/index.js <command> --help      # CLI 能跑
node dist/cli/index.js <command> --dry-run   # 功能正常
```

## 机器专属配置（多设备同步注意事项）

### 两台机器的坚果云路径不同
| 机器 | Nutstore 根路径 |
|------|-----------------|
| dddog (wooking) | `/mnt/c/Users/ddddog/Nutstore/1/myNutstore` |
| kangle (本机) | `/mnt/c/Users/kangle/Nutstore/1/myNutstore (1)` |

⚠️ 注意 `myNutstore (1)` 含空格和括号，路径必须加引号。

### export-wiki.ts 三处硬编码（必须动态化）
`dist/export-wiki.js` 编译后检查：

1. **nutstoreRoot** — 硬编码 `dddog` → 用 `os.userInfo().username` 动态获取，或 WSL 检测
2. **codebuddy_cli_win 路径** — `/mnt/c/Users/ddddog/.codebuddy` → 应为 `/mnt/c/Users/{username}/.codebuddy`
3. **SOURCES[].outputSubdir** — `dddog-hermes` / `dddog-codebuddy-*` → 应为 `{hostname}-hermes` / `{hostname}-codebuddy-*`

**验证方法**：
```bash
grep -i "dddog" dist/export-wiki.js  # 不应有匹配
grep "DESKTOP-4JFHQ88\|kangle" dist/export-wiki.js  # 应有动态 hostname
```

### 机器专属记忆的标注约定
**规则**：凡涉及 WSL Tailscale IP、机器名、WSL 密码、Windows 用户名等每台不同的信息，记忆文件 frontmatter 或文件名必须标注 `user-hostname`。

```yaml
---
machine: kangle-DESKTOP-4JFHQ88
source: wooking  # 记录来源
---
```

## CLI 验证记录（Phase 3-6）

| Phase | 命令 | 验证命令 | 结果 |
|-------|------|----------|------|
| Phase 3 dedup | dedup | `--dry-run` | ✅ 正常 |
| Phase 4 forget | forget | `--dry-run --json` | ✅ 正常 |
| Phase 5 search | search-l0 | `search-l0 "test"` | ✅ 正常 |
| Phase 6 pipeline | run-pipeline | `--help` | ✅ CLI 正常 |

详见 `clawmem-dev-pitfalls/references/cli-verification-2026-05-04.md`
