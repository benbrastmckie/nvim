# /learn Command Usage Guide

## Overview

The `/learn` command adds knowledge to the memory vault from four input sources: text, files, directories, or task artifacts. All inputs flow through content mapping, MCP-based memory search, and three memory operations (UPDATE, EXTEND, CREATE).

## Input Modes

### Text Mode

Add quoted text directly as memory:

```bash
/learn "Use pcall() in Lua for safe function calls"
/learn "Pattern: always use explicit returns in modules"
```

### File Mode

Add content from a single file:

```bash
/learn /path/to/notes.md
/learn ~/docs/python-tips.txt
```

### Directory Mode

Scan a directory tree for learnable content:

```bash
/learn ./src/utils/
/learn ~/notes/python/
```

**Features**:
- Recursive scanning with exclusion patterns (.git/, node_modules/, etc.)
- Two-tier text detection: extension whitelist + MIME-type fallback
- Size limits: 100KB per file, warning at 50 files, hard limit at 200 files
- Interactive file selection before processing

### Task Mode

Review artifacts from a completed task:

```bash
/learn --task 142
/learn --task 142 --category PATTERN
```

**Workflow**:
1. Scan task directory for artifacts (reports/, plans/, summaries/)
2. Select artifacts to review
3. Classify each segment (TECHNIQUE, PATTERN, CONFIG, WORKFLOW, INSIGHT, SKIP)
4. Create memories with classification tags

---

## Content Mapping

For inputs over 500 tokens, content is segmented into topic-aligned chunks:

```
Input: Large markdown file (2500 tokens)
       |
       v
Content Map:
  - Segment 1: "HTTP session configuration" (350 tokens)
  - Segment 2: "Custom retry adapter patterns" (280 tokens)
  - Segment 3: "Timeout and backoff usage" (420 tokens)
```

**Segmentation by file type**:
- Markdown: Split at heading boundaries
- Code: Split at function/class boundaries
- Text: Split at paragraph boundaries

**Small inputs** (<500 tokens) bypass segmentation and become a single segment.

---

## Memory Search

Each segment is matched against existing memories:

```
Segment: "HTTP session configuration"
Key terms: requests, session, adapter, retry, timeout

Related Memories:
1. MEM-requests-retry-patterns (72% overlap) -> UPDATE recommended
2. MEM-python-http-patterns (45% overlap) -> EXTEND recommended
3. (no match) -> CREATE recommended
```

**Search methods**:
- **MCP path**: `execute("search", {query: key_terms})`
- **Grep fallback**: `grep -l -i keyword .memory/10-Memories/*.md`

---

## Memory Operations

### UPDATE (>60% overlap)

Replace existing memory content:

```
Before: MEM-requests-basics "Requests basics"
After:  MEM-requests-basics "HTTP session configuration"
        - Old content moved to ## History section
        - modified field updated
```

### EXTEND (30-60% overlap)

Append new section to existing memory:

```
Before: MEM-python-http-patterns "Python HTTP patterns"
After:  MEM-python-http-patterns with new:
        ## Extension (2026-03-11)
        [new content about retry adapters]
```

### CREATE (<30% overlap)

Create new memory file:

```
New: MEM-requests-session-config "HTTP session configuration"
     - Fresh memory with topic and tags
     - Added to index (category + topic sections)
```

---

## Topic Organization

Memories include a `topic` field with slash-separated paths:

```yaml
topic: "python/libs/requests"
```

**Topic inference priority**:
1. Source directory path
2. Keyword analysis
3. Related memory topics
4. User override

**Index organization**:
```
## By Topic

### python/
  - python/libs/requests - 3 memories
  - python/patterns - 5 memories

### meta/
  - meta/commands - 2 memories
```

---

## Interactive Flow

### Step 1: Content Preview

```
Segment: Use pcall() in Lua for safe function calls
Topic: python/error-handling
Key terms: pcall, safe, function, error, exception

Related Memories Found:
- MEM-error-handling-patterns: "Error handling patterns" (65% match)
```

### Step 2: Operation Selection

```
What would you like to do with this segment?
[ ] UPDATE MEM-error-handling-patterns (replace content)
[ ] EXTEND MEM-error-handling-patterns (append section)
[ ] CREATE new memory
[ ] SKIP - don't save
```

### Step 3: Confirmation

```
Operation: UPDATE MEM-error-handling-patterns
Topic: python/error-handling (confirm or modify)

Proceed? [Yes/No]
```

---

## Examples

### Example 1: Simple Text

```bash
/learn "vim.keymap.set accepts a table with silent and buffer options"
```

Flow:
1. Single segment (under 500 tokens)
2. Search finds MEM-error-handling-patterns (45% match)
3. User selects EXTEND
4. Memory updated with new section

### Example 2: File Import

```bash
/learn ~/docs/python-notes.md
```

Flow:
1. File segmented into 3 topic chunks
2. Each segment searched against vault
3. Segment 1: UPDATE existing
4. Segment 2: EXTEND existing
5. Segment 3: CREATE new

### Example 3: Directory Scan

```bash
/learn ./lua/plugins/
```

Flow:
1. Recursive scan finds 12 files
2. User selects 8 files (multiSelect)
3. Files segmented (22 segments total)
4. Search and classify each
5. Result: 3 updates, 5 extends, 14 creates

### Example 4: Task Artifact Review

```bash
/learn --task 142
```

Flow:
1. Scan specs/142_task_name/ for artifacts
2. Select research report and summary
3. Classify as [INSIGHT] and [PATTERN]
4. Create memories with tags

---

## Quick Reference

| Command | Mode | Description |
|---------|------|-------------|
| `/learn "text"` | Text | Add text as memory |
| `/learn /path/file` | File | Add file content |
| `/learn /path/dir/` | Directory | Scan directory |
| `/learn --task N` | Task | Review task artifacts |

| Operation | Overlap | Action |
|-----------|---------|--------|
| UPDATE | >60% | Replace memory content |
| EXTEND | 30-60% | Append dated section |
| CREATE | <30% | Create new memory |

---

## Best Practices

### Writing Good Memories

1. **Use descriptive content** - Clear, focused knowledge
2. **One concept per memory** - Keep memories atomic
3. **Include context** - Source and date are auto-captured
4. **Use consistent topics** - Follow existing topic hierarchy

### Managing the Vault

1. **Review index.md** - Navigate by category and topic
2. **Prefer UPDATE/EXTEND** - Consolidate related knowledge
3. **Use directory mode** - Batch import notes efficiently
4. **Review after /learn** - Verify topic assignments

### Topic Guidelines

1. **Use existing topics** when possible (check index.md)
2. **Create new paths** for genuinely new domains
3. **Keep hierarchy shallow** - 2-3 levels is typical
4. **Be consistent** - python/libs not libs/python

---

## See Also

- [Memory Vault Structure](../../../data/.memory/20-Indices/index.md)
- [Memory Template](../../../data/.memory/30-Templates/memory-template.md)
- [Knowledge Capture Usage](./knowledge-capture-usage.md)
