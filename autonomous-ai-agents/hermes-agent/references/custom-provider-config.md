# Hermes Agent 自定义 Provider 配置

## config.yaml providers: 字段名关键点

定义自定义 named provider 时，`_get_named_custom_provider()` 的字段映射：

```yaml
providers:
  myprovider:
    api_mode: chat_completions        # 正确：runtime 用 entry_api_mode
    base_url: https://api.example.com/v1  # 正确：映射到 base_url
    # 以下是容易搞错的字段名
    default_model: my-model            # ✓ 正确：被代码读取的 key
    # model: xxx                       # ✗ 不会生效
    key_env: MYPORVIDER_API_KEY       # ✓ 正确：指定从哪个 env var 读 api_key
    # api_key: sk-xxx                 # ✗ inline key 不推荐（版本管理问题）
```

**字段映射表**（源码：`runtime_provider.py` `_get_named_custom_provider()`）：

| config.yaml 字段 | 代码读取 key | 说明 |
|---|---|---|
| `api`, `url`, `base_url` | `base_url` | 三者等价，取第一个非空 |
| `api_mode`, `transport` | `api_mode` | 两者等价 |
| `default_model` | `model` | 结果字典的 key 是 `model` |
| `key_env` | 从 `os.getenv(key_env)` 读 | 必须指定，否则 api_key 为空 |
| `api_key` | fallback | 仅当 `key_env` 未指定或 env var 为空时使用 |

## .env 中对应写法

```bash
MYPORVIDER_API_KEY=sk-xxxx
MYPORVIDER_BASE_URL=https://api.example.com/v1  # 可选，base_url 已写在 config.yaml
```

## ⚠️ /model 自动补全不包含自定义 provider

自定义 providers（`providers.xxx` 下的条目）**不会自动注册**到 `/model` 的 Tab 自动提示列表。`/model` 的补全来源只有：
- `model_aliases` — config.yaml 显式配置的别名（推荐）
- `model.aliases` — 通过 `hermes config set model.aliases.xxx` 设置
- 内置模型目录（`MODEL_ALIASES`）
- LM Studio 本地模型

**手动输 `/model myprovider/model-name` 是可以用的**（底层 `switch_model` 支持 `provider/model` 格式），但 Tab 不会提示。

**解决方案：** 添加 `model_aliases` 段：

```yaml
model_aliases:
  myalias:                          # Tab 补全时输入的简短名称
    model: my-model-name
    provider: myprovider            # 对应 providers 下的 key
```

之后 `/model mya` + Tab 就会提示 `myalias → my-model-name (myprovider)`。

## 调试方法

用 Python 直接验证解析结果：

```python
import sys, os
sys.path.insert(0, '/home/dddog/.hermes/hermes-agent')
os.environ['MYPORVIDER_API_KEY'] = 'your-key-here'

# 清缓存
for mod in list(sys.modules.keys()):
    if 'hermes_cli' in mod:
        del sys.modules[mod]

from hermes_cli.runtime_provider import _get_named_custom_provider
result = _get_named_custom_provider('myprovider')
print(result)
# 期望: {'base_url': ..., 'api_key': 'sk-xxx...', 'model': 'my-model', 'api_mode': 'chat_completions'}
```

## 已验证可用的 Provider

### SenseNova (token.sensenova.cn)

- API key 来源：KeePass `kp_db.kdbx`（`https://platform.sensenova.cn/console` 条目，username=dddog999）
- 完整 key：`sk-iKAqzH9rXFDKhgaT5dar89PsgaG99DHm`
- 可用模型（均免费，context 262k）：
  - `deepseek-v4-flash` ✓
  - `sensenova-6.7-flash-lite` ✓
  - `sensenova-u1-fast` ✗（列表中有但实际报错 model not found）
- 模型列表：`GET https://token.sensenova.cn/v1/models`
- Endpoint：`https://token.sensenova.cn/v1/chat/completions`
