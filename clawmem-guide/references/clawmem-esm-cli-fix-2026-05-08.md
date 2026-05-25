---
name: clawmem-esm-cli-fix
description: ClawMem src/cli/index.ts ESM require() bug fix — 2026-05-08
---

# ClawMem ESM `require()` Bug（2026-05-08）

## 问题

`src/cli/index.ts` 中 `isWSL()` 函数使用了 `require('os')`：
```typescript
function isWSL(): boolean {
  return process.platform === 'linux' &&
    (!!process.env.WSL_DISTRO_NAME ||
      require('os').release().toLowerCase().includes('wsl'));
}
```

但 `package.json` 声明 `"type": "module"`，项目是 ESM，`require()` 不可用。

## 症状

```bash
npm run build  # 成功
node dist/cli/index.js --version  # 失败
# ReferenceError: require is not defined in ES module scope
```

## 修复

```typescript
import { homedir, release } from 'os';

function isWSL(): boolean {
  return process.platform === 'linux' &&
    (!!process.env.WSL_DISTRO_NAME ||
      release().toLowerCase().includes('wsl'));
}
```

## 验证

```bash
cd /mnt/c/Users/kangle/clawmem
npm run build
node dist/cli/index.js --version  # 应返回 0.1.0
npm test  # CLI 相关测试应不再报 require 错误
```
