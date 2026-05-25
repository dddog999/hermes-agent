# Hindsight 调试笔记（2026-05-19）

## execute_code Python 版本 vs hindsight 安装版本冲突

**问题**：`execute_code` 工具用的 Python 来自 uv：
```
C:\Users\dddog\AppData\Roaming\uv\python\cpython-3.11-windows-x86_64-none\python.exe
```
但 `hindsight-all` 安装在 Python 3.12：
```
C:\Users\dddog\AppData\Local\Programs\Python\Python312\python.exe
```

执行 `import hindsight_api` 在 uv Python 3.11 下失败（ModuleNotFoundError）。

**解决**：所有 hindsight 相关操作必须用 Python 3.12 显式路径：
```python
py312 = r'C:\Users\dddog\AppData\Local\Programs\Python\Python312\python.exe'
```

## 嵌入式 PostgreSQL 数据损坏修复

**症状**：日志 `connection to server at 127.0.0.1, port 5432 failed: server closed the connection unexpectedly`

**原因**：`.pg0/instances/hindsight/data/` 目录为空（PG 数据文件丢失）

**现象**：
- `start.log` 只有启动重定向提示，没有数据文件
- `postmaster.pid` 不存在
- `ls data/` 只有 `start.log` 一个文件

**修复后现象**：
- Hindsight 启动时自动 init PG：`hindsight_api.pg0 - Starting embedded PostgreSQL (name=hindsight, port=auto)...`
- 自动执行 migration：`Running migration ...`
- 自动修复 embedding dimension（384→1024）：`Altering memory_units.embedding column dimension from 384 to 1024`

## Health check 响应

成功时：
```json
{"status":"healthy","database":"connected"}
```

## 启动后 LLM 验证失败（401）

如果 MiniMax API key 是占位符，health 仍然返回 healthy 但 LLM 相关功能不可用：
```
WARNING - LLM connection verification failed: Error code: 401 - login fail: Please carry the API secret key
```
只有填入真实 key 后才能进行实体提取等 LLM 操作。
