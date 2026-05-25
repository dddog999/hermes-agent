# browser-use vs browser-harness 对比

## 一句话总结

```
browser-use = browser-harness + CLI工具 + Session管理 + Profile同步 + 云浏览器
```

browser-harness 是底层 CDP 桥接层（约 1000 行），browser-use 是封装好的完整产品。

## 核心区别

| | browser-use | browser-harness |
|---|---|---|
| 定位 | 开箱即用的浏览器自动化产品 | 极薄 CDP 桥接层（框架） |
| 目标用户 | 普通用户，直接可用 | 开发者，需配置 AI Agent |
| 安装 | `npm install browser-use` | 需手动配 Chrome Remote Debugging |
| CLI | 完整 CLI（state/click/eval/python/agent） | 仅 `browser-harness` + `bh` 命令 |
| Session 管理 | 内置，多 session，profile 同步 | 仅 CDP 连接，无状态管理 |
| 学习能力 | 无 | 有：自动写 `agent_helpers.py` 自我改进 |
| 代码量 | 较大 | ~1000 行 |

## 财务系统自动化场景

**推荐 browser-use**，原因：
- 有现成 skill，零配置直接用
- Chrome Profile 持久化可复用登录状态
- SMS 验证码只需首次手动

**browser-harness 适合**：
- 需要 Agent 在运行时自己写代码扩展能力的场景
- 开发者，需要极细粒度 CDP 控制
- 普通财务系统自动化用不上这些能力

## 参考

- browser-harness 仓库：https://github.com/browser-use/browser-harness
- browser-use 仓库：https://github.com/browser-use/browser-use
