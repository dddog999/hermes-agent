# dida365-ai-tools 使用说明（二合一模式）

`dida365-ai-tools` 支持 **两种运行模式**：

## 模式一：独立 CLI（推荐日常使用）

通过 `npx -p dida365-ai-tools dida365` 或全局安装后直接使用：

```bash
npm install -g dida365-ai-tools
dida365 auth cookie <token>    # 设置认证
dida365 auth status             # 查看状态
dida365 project list            # 项目列表
dida365 task create "<标题>"    # 创建任务
```

> ⚠️ 注意：直接用 `npx dida365-ai-tools`（无子命令）会启动 MCP 服务器模式，导致挂起。
> ✅ 正确 CLI 用法：`npx -p dida365-ai-tools dida365 <command>` 或全局安装后 `dida365 <command>`。

## 模式二：MCP 服务器（AI Agent 集成）

作为 MCP 服务器在 stdio 上等待 JSON-RPC 协议输入：

```bash
# Claude Code 集成
claude mcp add dida365 -- npx dida365-ai-tools
```

## 认证

需要获取 Dida365 Cookie token：
1. 浏览器打开 F12 → Application → Cookies → api.dida365.com
2. 找到 `td_cookie` 值
3. CLI 模式：`dida365 auth cookie <token>`
4. MCP 模式：通过客户端设置（如 `mcpx auth --name dida365 --token <token>`）
