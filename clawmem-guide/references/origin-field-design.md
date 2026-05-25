# Frontmatter origin 字段设计决策

## 时间
2026-05-02

## 背景
export-wiki.ts 输出 wiki 文件时，原来只靠外部 `historyState.json` 记录"哪些源文件已导出"。用户问：为什么文件本身不记录自己的来源？

## 设计决策

**原来（不健壮）**：
- wiki 文件 frontmatter 只有 `date`, `source`, `source_name`
- 外部 `historyState.json` 记录 `{"/home/dddog/.hermes/sessions/20260411_074209_515495a8.jsonl": "2026-04-11.md"}`
- 如果 wiki 文件被移动/复制，追溯链条就断了

**改进后（健壮）**：
- 每个 wiki 文件 frontmatter 直接写 `origin: "/path/to/source.jsonl"`
- 文件到哪里，源头信息跟到哪里，不依赖外部 state

## 实现
```typescript
// export-wiki.ts generateDailyMarkdown()
const originPaths = [...new Set(daySessions.map(s => s.path))];
for (const p of originPaths) {
  parts.push(`origin: "${p}"`);
}
```

## 教训
**源头信息从一开始就内嵌，不要依赖外部映射表。** 健壮性 > 灵活性。
