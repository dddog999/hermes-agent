# 2026-05-10: Nutstore 迁移记录

> 将 Hermes Agent 技能目录从本地迁移到坚果云同步目录，建立 mklink /D 符号链接。
> 用户: dddog | 环境: Windows + Git Bash (MSYS2) | 云盘: 坚果云 (Nutstore)

## 初始状态

- 源技能: `C:\Users\dddog\Nutstore\1\myNutstore\hermes-sync\skills\` (203 个 SKILL.md)
- 目标: `C:\Users\dddog\.hermes\skills\` (已有 232 个 SKILL.md，含内置技能)
- 差异: 29 个 openclaw-imports/ 和 autonomous-ai-agents/ 下的内置技能不在坚果云中

## 执行步骤

### 1. 首次复制（cp -r 遗漏了隐藏文件）

```bash
cp -r /c/Users/dddog/Nutstore/1/myNutstore/hermes-sync/skills/* /c/Users/dddog/.hermes/skills/
```

**问题：** `.archive/`、`.usage.json` 等隐藏文件没有被复制。

### 2. 补复制隐藏文件

```bash
# 识别缺失
diff <(cd nutstore-skills && find . -name "SKILL.md" | sort) \
     <(cd ~/.hermes/skills && find . -name "SKILL.md" | sort) | grep "^<"

# 补复制 .archive/
cp -r /c/Users/dddog/Nutstore/1/myNutstore/hermes-sync/skills/.archive /c/Users/dddog/.hermes/skills/
cp /c/Users/dddog/Nutstore/1/myNutstore/hermes-sync/skills/.usage.json /c/Users/dddog/.hermes/skills/
```

### 3. 回填内置技能到坚果云

```bash
for dir in autonomous-ai-agents/claude-code autonomous-ai-agents/codex autonomous-ai-agents/opencode; do
  target="/c/Users/dddog/Nutstore/1/myNutstore/hermes-sync/skills/$dir"
  mkdir -p "$target" && cp -r "$dir/"* "$target/"
done

mkdir -p "/c/Users/dddog/Nutstore/1/myNutstore/hermes-sync/skills/openclaw-imports"
for dir in openclaw-imports/*/; do
  skillname=$(basename "$dir")
  target="/c/Users/dddog/Nutstore/1/myNutstore/hermes-sync/skills/openclaw-imports/$skillname"
  mkdir -p "$target" && cp -r "$dir"* "$target/"
done

# 元数据
cp /c/Users/dddog/.hermes/skills/.bundled_manifest "/c/Users/dddog/Nutstore/1/myNutstore/hermes-sync/skills/"
cp /c/Users/dddog/.hermes/skills/.curator_state "/c/Users/dddog/Nutstore/1/myNutstore/hermes-sync/skills/"
```

### 4. 建立符号链接

```bash
# 备份原目录
mv /c/Users/dddog/.hermes/skills /c/Users/dddog/.hermes/skills.bak

# 创建联接（用 cmd.exe，因为 Git Bash ln -s 失败）
cmd.exe /c "mklink /D C:\Users\dddog\.hermes\skills C:\Users\dddog\Nutstore\1\myNutstore\hermes-sync\skills"
```

**注意：** 删除原 skills 目录后，如果终端当前在 ~/.hermes/skills/ 中，需要指定 workdir。

### 5. 验证

```bash
ls /c/Users/dddog/.hermes/skills/dddog-profile/SKILL.md       # ✓ 自定义技能
ls /c/Users/dddog/.hermes/skills/creative/sketch/SKILL.md     # ✓ 内置技能
ls /c/Users/dddog/.hermes/skills/openclaw-imports/            # ✓ 回填技能
```

## 结果

- 232 个 SKILL.md 全部可通过符号链接访问
- 坚果云目录包含所有 Hermes 技能 + 元数据
- 旧目录备份为 `~/.hermes/skills.bak/`
- 多设备：在其他电脑上执行同样的 `mklink /D` 即可共享
