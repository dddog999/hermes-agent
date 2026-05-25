---
name: clawmem-ts-debugging
description: ClawMem 项目 TypeScript 调试方法论——HEAD 隔离验证、TS 5.9 兼容性修复、括号平衡分析
---

# ClawMem TypeScript 调试方法论

## 铁律：先验证 HEAD，再调试

**永远先用 `git stash` + `git checkout HEAD -- <file>` 确认错误是否在 HEAD 中。**

未提交的本地修改版本可能因 LF/CRLF 转换、文件内容被外部工具重写等原因带有幽灵错误。先隔离 HEAD：

```bash
git stash
npx tsc --noEmit 2>&1 | grep "src/cli/index.ts"
# 无输出 → HEAD 无错误，问题在工作目录的未提交修改
git checkout HEAD -- src/cli/index.ts
```

**教训**：调查"幽灵错误"时，第一步永远是隔离 HEAD vs 工作目录。花了 2 小时调括号平衡，结果发现 HEAD 零错误。

## TypeScript 5.9 Strict 兼容性修复

### TS2345 — 参数类型不匹配
```typescript
// 单行
await core.addMemory({ content: 'Test' } as any);

// 多行 — sed 改行尾
sed -i 's/});/} as any);/' tests/file.test.ts
```

### TS2769 — execSync 重载不匹配
Node.js 20+ 的 `execSync` 不接受 `shell: true`：
```typescript
// 删除 shell: true
execSync(`command`, { encoding: 'utf8' });
```

### TS7016 — 缺少模块类型声明
为 `.mjs` 文件创建 `.d.mts` 声明：
```typescript
// src/hooks/utils.d.mts
export function parseTranscript(content: string): { user: string; assistant: string };
export function runClawmem(args: string[], timeout?: number): string;
// ...
```

### TS7017 — global 索引签名
```typescript
global.execSync = () => {};  // ❌
(global as any).execSync = () => {};  // ✅
```

### TS18046 — catch error unknown
```typescript
catch (error: unknown) {
  if ((error as any).stdout) { ... }
}
```

### TS2339 — 对象字面量缺属性
```typescript
const input = {
  hook_event_name: 'Stop',
  transcript_path: undefined as any,
  transcript: undefined as any,
  messages: undefined as any,
  conversation: undefined as any,
};
```

### TS7034/TS7005 — 隐式 any
```typescript
let latestMemoryBefore: string | null = null;
```

## 括号平衡分析（TS1005 '}' expected）

```python
# Python 字节级分析，绕过字符串引号误判
data = open('src/cli/index.ts', 'rb').read()
lines = data.split(b'\n')
for i in range(1500, len(lines)):
    line = lines[i]
    if b'});' in line:
        indent = len(line) - len(line.lstrip())
        print(f'L{i+1} indent={indent}: {repr(line[:40])}')
```

关键：`});` 是 TypeScript/yargs 命令的最小闭包单位。indent=2 的 `});` 缺失 = 某个 `.action()` 未关闭。

## 验收命令

```bash
npx tsc --noEmit 2>&1 >/dev/null; echo "Exit: $?"

# 只看 src 错误
npx tsc --noEmit 2>&1 | grep "^src/"

# 只看特定文件
npx tsc --noEmit 2>&1 | grep "src/cli/index.ts"
```

## 相关 Commit

- `69317fb` — fix(tests): TypeScript 5.9 strict模式兼容修复
