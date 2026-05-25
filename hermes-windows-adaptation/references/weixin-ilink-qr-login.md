# WeChat iLink QR Login 实操记录

## 会话摘要（2026-05-10）

### 背景
- 从 WSL 迁移到 Windows 原生后，旧的 WEIXIN_TOKEN 过期（iLink session 有时效）
- 需要重新扫码获取新 token

### 流程
1. 确认依赖：`aiohttp` + `cryptography` 已安装
2. 调用 iLink API 获取二维码：
   ```bash
   curl -s -H "iLink-App-Id: bot" "https://ilinkai.weixin.qq.com/ilink/bot/get_bot_qrcode?bot_type=3"
   ```
3. 返回的字段：
   - `qrcode`: hex token
   - `qrcode_img_content`: 微信 LiteApp URL
   - `ret`: 0 = OK
4. 用户扫描二维码后，轮询 `get_qrcode_status`：
   ```bash
   curl -s -H "iLink-App-Id: bot" "https://ilinkai.weixin.qq.com/ilink/bot/get_qrcode_status?qrcode=<hex>"
   ```
5. 轮询返回的状态：
   - `wait`: 未扫描
   - `scaned`: 已扫码，等待手机确认
   - `confirmed`: 已确认，同时返回 token
   - `expired`: 二维码过期

### 关键坑：字段名映射（导致自写轮询脚本失效）

`qr_login()` 在 weixin.py 中有字段名映射，但自写轮询脚本直接读 API 返回时字段名不同：

```python
# API 实际返回的字段（2026-05-10 实测）
api_response = {
    "bot_token": "15c4dd0b2260@im.bot:06000097472f4d97f08d72a6e5f1c11934cdcb",
    "ilink_bot_id": "15c4dd0b2260@im.bot",
    "ilink_user_id": "o9cq80xMOXhdNT5YIQ1hSKO89SRc@im.wechat",
    "baseurl": "https://ilinkai.weixin.qq.com",
    "status": "confirmed",
    "ret": 0
}

# 自写脚本如果检查 data.get('token') 或 data.get('account_id') 会永远不匹配！
# ❌ 错误写法：
# if data.get('account_id') and data.get('token'):  # 永远不触发
#     ...

# ✅ 正确写法：用 API 实际字段名
# if data.get('ilink_bot_id') and data.get('bot_token'):
#     account_id = data['ilink_bot_id']
#     token = data['bot_token']
#     base_url = data.get('baseurl')
```

### 推荐做法

**不要自写轮询脚本**。直接用内置的 `qr_login()` 函数，它已处理字段映射：

```python
from gateway.platforms.weixin import qr_login
from hermes_constants import get_hermes_home
import asyncio
credentials = asyncio.run(qr_login(str(get_hermes_home())))
# credentials = {
#     "account_id": ...,
#     "token": ...,
#     "base_url": ...,
#     "user_id": ...,
# }
```

或直接跑 `hermes gateway setup`（交互式向导）→ 选 Weixin / WeChat。

### 存放位置

新 token 写入 `~/.hermes/.env`：

```env
WEIXIN_ACCOUNT_ID=<account_id>
WEIXIN_TOKEN=<account_id>:<token_hex>
WEIXIN_BASE_URL=https://ilinkai.weixin.qq.com
WEIXIN_CDN_BASE_URL=https://novac2c.cdn.weixin.qq.com/c2c
WEIXIN_DM_POLICY=pairing
```

Gateway 启动时自动读取，无需额外配置。
