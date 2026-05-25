# GSD-Master 迭代笔记

本文件记录 GSD 技能的真实评测结果和改进历史，供后续优化参考。

---

## Iteration 2 — 离线测试驱动优化 (2026-05-01)

### 评测方法
使用 `delegate_task` 并行调用 MiniMax API，每个测试场景独立子代理，最多3轮tool调用。

评测框架位置: `/tmp/gsd-master-eval/iteration-2/REPORT.md`

### 8项测试结果（全部通过）

| # | 场景 | 结果 | 关键发现 |
|---|------|------|----------|
| 1 | 新项目启动 | ✅ | 第一条回复即触发/gsd-new-project，引用STATE.md |
| 2 | 活跃项目继续 | ✅ | 强制检查.planning/，读取STATE.md，路由execute-phase |
| 3 | Bug诊断 | ✅ | 正确识别bug场景，建议diagnose-issues，未直接给命令 |
| 4 | 进度查询 | ✅ | 读取STATE.md/ROADMAP.md，给出结构化报告，路由progress |
| 5 | 简单翻译任务 | ✅ | 快速完成，无过度工程化，正确识别边界 |
| 6 | 新增需求讨论 | ✅ | 检查phase边界，指出需求在Phase 3而非Phase 2 |
| 7 | 闲聊 | ✅ | 完全不触发GSD，正确识别为非开发请求 |
| 8 | 技术选型(有项目) | ✅ | 检查plan归属，阻止直接讨论Redis vs Memcached |

**通过率: 8/8 (100%)**

### 发现的问题
测试3发现: `diagnose-issues.md` 依赖 UAT gaps 结构，对于无项目场景的简单bug报告（如 `npm build` 失败）缺乏轻量级诊断路径。

**改进**: 在 SKILL.md 新增 "Bug Reports: Lightweight Diagnosis (No Project Required)" 章节。

---

## 离线测试驱动优化工作流

当需要优化某个技能时：

1. **准备测试用例**: 在 `/tmp/<skill>-eval/iteration-N/evals/evals.json` 准备结构化测试
2. **并行执行**: 用 `delegate_task` 并行跑测试（注意 MiniMax 频率限制，每次最多3个）
3. **分析结果**: 检查每个场景的触发准确性、状态保持、边界正确性
4. **识别问题**: 从失败场景提取改进点
5. **落地改进**: 用 `skill_manage(action='patch')` 更新 SKILL.md
6. **记录**: 在 `references/iteration-notes.md` 记录评测结果和改进历史

### 注意事项
- MiniMax API 有频率限制（429错误），每批测试控制在3个以内
- 子代理默认继承父会话的模型和工具集，必要时在 context 中显式声明
- 测试场景需要覆盖: should-trigger / should-not-trigger / 状态保持 / 漂移防止 四个维度
