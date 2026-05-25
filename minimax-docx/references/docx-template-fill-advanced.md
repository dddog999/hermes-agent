# Docx Template Fill Advanced
> Archived `docx-template-fill-advanced` — demoted as verbatim reference from minimax-docx umbrella.

---


# Advanced DOCX Template Filling

Use when filling DOCX templates with data from JSON/Excel, especially when:
- Template uses double-brace style markers like `{{P1}}`
- Markers may be split across multiple XML runs
- Need to preserve formatting (fonts, paragraphs)
- Working with OCR-derived content

## Key Concepts

### Marker System
Use `{{P1}}`, `{{P2}}`, etc. as placeholders in templates. Benefits:
- Distinct from normal text
- Easy to find and replace
- Can be split across runs (Word sometimes splits `{{P1}}` into `{{` + `P1` + `}}`)

### Template Structure (典型村 example)
```
Para 3: {{P1}} + fixed_text (P1 content + template text)
Para 6: Text box with {{P2}} marker
Para 7: {{P3_TITLE}}【X-Y 类别】
Para 8: {{P3_CONTENT}} (content standard)
Para 9: {{P3_SCORE}} (score)
Para 10: 自评情况简述：{{P3_DESC}}
Para 11: {{P3_DESC}} (description content)
Para 22: ({{P2}}) for page 2
```

## Critical Lessons

### 1. Template Fixing
**Problem**: Original templates may have issues:
- Double markers (e.g., `{{P1}}...{{P1}}`)
- Residual content in text boxes
- Wrong bracket types (Chinese vs English)

**Solution**: Create dedicated fix scripts:
```python
# Fix Para3 double markers
# Keep only first {{P1}}, remove second

# Fix Para22 brackets
# Change Chinese （） to English ()

# Fix text box content
# Clear residual text, keep only {{P2}}
```

### 2. P2 Replacement Logic
**Problem**: Template has `({{P2}})`, replacing `{{P2}}` with `(bid)` causes `((bid))`

**Solution**: Replace `{{P2}}` with just `bid`, not `(bid)`:
```python
t.text = t.text.replace('{{P2}}', bid)  # Not f'({bid})'
```

### 3. OCR Content Parsing (P3)
**Problem**: P3 raw text has markdown format with Chinese/English colons

**Solution**: Robust parser:
```python
def parse_p3(p3_raw):
    # Handle both ： and :
    # Strip ## prefix
    # Track in_desc state for description
    # Don't reset in_desc on empty lines
```

### 4. Verification Strategy
**Three-level verification**:
1. **Data level**: Check all_data.json P1 length ≤ 100
2. **XML level**: Scan for markers, double brackets, wrong text
3. **Content level**: Verify P3 has description content

**Important**: Use correct quote characters (Chinese quotes not English quotes)

### 5. Manual Data Fixing
When automated truncation fails, manually update all_data.json:
```python
def truncate_p1(text, max_len=100):
    # Find last sentence-ending punctuation (。！？)
    # Truncate there if within limit
    # Otherwise hard truncate at max_len
```

## Script Structure

### Template Generator (build_tpl_v*.py)
1. Copy source template
2. Read XML, modify markers
3. Fix known issues (double markers, brackets)
4. Save new template

### Filler Script (fill_v*.py)
1. Load all_data.json
2. For each item:
   - Truncate P1 to ≤ 100 chars
   - Parse P3 raw content
   - Load template
   - Replace markers at XML level
   - Replace 云汉→康乐
   - Clean all markers
   - Save as `{P2}_{P4}.docx`

### Validator Script (verify_v*.py)
1. Check P1 length from source data
2. Scan XML for markers and issues
3. Verify P3 description content
4. Report pass/fail per file

## Common Pitfalls

1. **Split markers**: Word splits markers across runs. Use XML-level replacement, not string replacement.

2. **Quote mismatch**: Template uses Chinese quotes but validation uses English quotes. Match exactly.

3. **Para3 structure**: `{{P1}}` + fixed_text. P1 length check should use source data, not Para3 total length.

4. **Double brackets**: Template `({{P2}})` + replacement `(bid)` = `((bid))`. Replace marker without adding brackets.

5. **Empty P3 description**: Some entries have empty description. Parser should handle gracefully.

## Output Format
- Directory: `extracted/output/`
- Naming: `{P2}_{P4}.docx` (e.g., `1-1_环境整治.docx`)
- Validation: 100% pass rate on all markers cleared