# ClawMem WSL 路径检测 — 关键代码片段（2026-05-06）

> 补充到 `clawmem-wsl-path-fixes` 技能的 references/ 中。SKILL.md 主文件因权限问题无法直接修改，待修复。

## isWSL() 检测（TypeScript）

```typescript
function isWSL(): boolean {
  return process.platform === 'linux' &&
    (!!process.env.WSL_DISTRO_NAME ||
      process.release?.name?.toLowerCase().includes('wsl') || false);
}
```

**注意**：`os.release()` 在 Node.js 中不存在（那是 Python 的），应改用 `process.release?.name`。

## getWindowsUsernameSync() — 用于 SOURCES 初始化

```typescript
function getWindowsUsernameSync(): string {
  return process.env.WINDOWS_USERNAME || os.homedir().split('/').pop() || 'unknown';
}
```

**重要**：`os.hostname()` 在 WSL 返回 Linux 内部主机名（如 `DESKTOP-4JFHQ88`），不是 Windows 用户名。输出子目录应使用本函数而非 `os.hostname()`。

## export-wiki.ts 动态路径函数

```typescript
function getNutstoreRoot(): string {
  if (isWSL()) {
    const winUser = getWindowsUsernameSync();
    const userPath = `/mnt/c/Users/${winUser}`;
    if (fs.existsSync(path.join(userPath, 'Nutstore', '1', 'myNutstore (1)'))) {
      return path.join(userPath, 'Nutstore', '1', 'myNutstore (1)');
    }
    if (fs.existsSync(path.join(userPath, 'Nutstore', '1', 'myNutstore'))) {
      return path.join(userPath, 'Nutstore', '1', 'myNutstore');
    }
    return path.join(userPath, 'Nutstore', '1', 'myNutstore (1)');
  } else {
    return path.join(os.homedir(), 'Nutstore', '1', 'myNutstore (1)');
  }
}

function getWikiBase(): string {
  return path.join(getNutstoreRoot(), 'hermes-sync', 'wiki');
}

function getCodebuddyIdeBase(): string {
  if (isWSL()) {
    return path.join('/mnt/c/Users', getWindowsUsernameSync(), 'AppData', 'Local');
  } else {
    return path.join(os.homedir(), 'AppData', 'Local');
  }
}

function getCodebuddyCliWinBase(): string {
  if (isWSL()) {
    return path.join('/mnt/c/Users', getWindowsUsernameSync(), '.codebuddy');
  } else {
    return path.join(os.homedir(), '.codebuddy');
  }
}
```

## clawmem CLI detectNutstorePath() WSL 分支修复

```typescript
async function detectNutstorePath() {
  const possiblePaths = [
    `${home}/Nutstore/1/myNutstore/clawmem`,
    `${home}/Nutstore/1/myNutstore (1)/clawmem`,
    `${home}/坚果云/clawmem`,
  ];
  if (isWSL()) {
    const winUser = await getWindowsUsername();
    possiblePaths.push(
      `/mnt/c/Users/${winUser}/Nutstore/1/myNutstore/clawmem`,
      `/mnt/c/Users/${winUser}/Nutstore/1/myNutstore (1)/clawmem`,
      `/mnt/c/Users/kangle/Nutstore/1/myNutstore/clawmem`,
      `/mnt/c/Users/kangle/Nutstore/1/myNutstore (1)/clawmem`,
    );
  }
  // ...
}
```

**注意**：`detectNutstorePath()` 需要改为 `async`，所有调用处必须加 `await`。

## Pitfall: git stash pop 覆盖工作区修改

**场景**：
```bash
git stash          # 暂存当前修改
git checkout <file> # 从历史恢复文件（此时工作区是干净版本）
git stash pop      # 错误：stash 中的旧修改会覆盖你刚才 checkout 的文件
```

**后果**：手动恢复的版本被 stash 中的旧版本覆盖，修改丢失。

**正确做法**：先 `git stash show -p` 查看 stash 内容，确认没有冲突后再 pop。如果需要保留工作区修改，用 `git stash show -p | patch -p1` 手动合并。
