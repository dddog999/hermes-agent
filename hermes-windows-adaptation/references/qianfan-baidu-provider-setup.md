# 百度千帆（Qianfan）Provider 配置

## 获取 API Key

通过 pykeepass 从 KeePass 读取：

```python
from pykeepass import PyKeePass
kp = PyKeePass('path/to/Database.kdbx', password='...')
# 搜索无标题条目中包含 qianfan.baidubce.com 的记录
for e in kp.entries:
    if 'qianfan.baidubce.com' in (e.url or ''):
        print(f"API Key: {e.password}")
        print(f"URL: {e.url}")
```

## 配置

### .env

```bash
QIANFAN_API_KEY=bce-v3/ALTAK-xxxxxxxxx/xxxxxxxxxxxxx
```

### config.yaml：添加到 providers 段

```yaml
providers:
  qianfan:
    api_mode: chat_completions
    base_url: https://qianfan.baidubce.com/v2
    key_env: QIANFAN_API_KEY
    model: ERNIE-4.5-8K
```

### 使用

```bash
# CLI
hermes model          # 选 qianfan
# 或直接用：
hermes --provider qianfan
```

## 注意事项

- Baidu Qianfan 使用 BCE IAM 认证（格式：`bce-v3/ALTAK-.../...`）
- 兼容 OpenAI 的 chat/completions API
- URL 末尾要带 `/v2`（不是 `/v1`）
