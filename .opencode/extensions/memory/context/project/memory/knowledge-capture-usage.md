# Usage Examples

Example workflows for the knowledge capture system commands.

---

## /fix-it Command Examples

The `/fix-it` command scans files for embedded tags (FIX:, NOTE:, TODO:, QUESTION:) and creates structured tasks.

### Example 1: Scan Entire Project

```bash
/fix-it
```

**Workflow:**
1. Scans entire project for FIX:/NOTE:/TODO:/QUESTION: tags
2. Displays summary:
   ```
   Tags Found:
   - FIX: 3 tags
   - NOTE: 5 tags
   - TODO: 12 tags
   - QUESTION: 2 tags
   ```
3. Presents interactive selection with checkboxes
4. User selects which tags to convert to tasks
5. Creates tasks in specs/TODO.md and updates state.json

### Example 2: Scan Specific Directory

```bash
/fix-it src/core/
```

**Use Case:** Focus on a specific module or component without scanning the entire codebase.

**Workflow:**
1. Scans only src/core/ directory
2. Shows tags found in that directory only
3. Interactive selection and task creation

### Example 3: Scan Multiple Paths

```bash
/fix-it src/core.lua src/utils/ config/
```

**Use Case:** Review multiple specific files and directories in one operation.

---

## /learn Command Examples

The `/learn` command adds knowledge to the memory vault with four input modes.

### Example 1: Add Text Memory

```bash
/learn "Use pcall() in Lua for safe function calls"
```

**Workflow:**
1. Content mapped as single segment (<500 tokens)
2. Memory search finds related memories
3. User selects operation (UPDATE/EXTEND/CREATE)
4. Memory created or updated with topic assignment

### Example 2: Add File Content

```bash
/learn ~/notes/telescope-tips.md
```

**Workflow:**
1. File content segmented at heading boundaries
2. Each segment searched against vault
3. User reviews overlap scores and recommendations
4. Operations executed (mix of UPDATE/EXTEND/CREATE)

### Example 3: Scan Directory

```bash
/learn ./lua/plugins/
```

**Workflow:**
1. Recursive scan with exclusion patterns
2. Two-tier text detection (extensions + MIME type)
3. User selects files to process (multiSelect)
4. Files segmented and routed through pipeline
5. Operations summary: "3 updates, 5 extends, 14 creates"

### Example 4: Review Task Artifacts

```bash
/learn --task 142
```

**Workflow:**
1. Scans specs/142_task_name/ for artifacts
2. Displays found files:
   ```
   Artifacts found for Task 142:

   1. reports/research-002.md (Research Report)
   2. plans/implementation-003.md (Implementation Plan)
   3. summaries/implementation-summary-20260305.md (Summary)
   ```
3. User selects artifacts to review
4. Content mapped and searched
5. Classification for each segment:
   ```
   Classify this segment:
   - [x] [PATTERN] - Design or implementation pattern
   - [ ] [TECHNIQUE] - Reusable method
   - [ ] [SKIP] - Not valuable
   ```
6. Memories created with classification tags and topic

### Example 5: Extract Pattern from Research

```bash
/learn --task 146
```

**Scenario:** Task 146 contains research on subagent workflows.

**Workflow:**
1. Research report segmented (3 segments)
2. Segment 1: 55% match to existing memory -> EXTEND
3. Segment 2: 15% match -> CREATE (classified as [INSIGHT])
4. Segment 3: 70% match -> UPDATE existing
5. Result:
   ```markdown
   # Memory: Subagent Workflow Best Practices

   **Category**: [INSIGHT]
   **Topic**: meta/agents/subagents
   **Source**: Task 146 - reports/research-001.md

   Key findings on isolated context windows and metadata passing...
   ```

---

## /todo Examples

The enhanced `/todo` command includes CHANGE_LOG updates and memory harvest suggestions.

### Example 1: Archive with CHANGE_LOG Update

```bash
/todo
```

**Workflow:**
1. Scans for completed tasks
2. Archives tasks to specs/archive/
3. Updates specs/CHANGE_LOG.md
4. Suggests memory harvest from completed work
5. Commits all changes

### Example 2: Preview Before Archiving

```bash
/todo --dry-run
```

**Output:**
```
Dry Run - Would Archive:
- 3 completed tasks
- 1 abandoned task
- 2 roadmap items would be annotated
- 5 memory harvest suggestions available
```

---

## Cross-Feature Workflow Example

Complete workflow demonstrating all features working together:

### Step 1: Scan for Issues

```bash
/fix-it src/
```

Finds 3 FIXME tags in source code, creates tasks.

### Step 2: Research a Task

```bash
/research 150
```

Creates comprehensive research report.

### Step 3: Create Memories from Research

```bash
/learn --task 150
```

**Workflow:**
1. Reviews research report (segmented into 4 chunks)
2. Searches vault for each segment
3. Operations:
   - Segment 1: UPDATE existing memory (72% overlap)
   - Segment 2: CREATE as [INSIGHT]
   - Segment 3: EXTEND existing memory (45% overlap)
   - Segment 4: CREATE as [TECHNIQUE]
4. Topics assigned based on content analysis

### Step 4: Implement the Task

```bash
/implement 150
```

Executes plan, creates implementation.

### Step 5: Archive and Update

```bash
/todo
```

- Archives completed task
- Updates ROAD_MAP.md with completion annotation
- Updates CHANGE_LOG.md with entry
- Suggests reviewing implementation for additional memories

---

## Content Mapping Examples

### Markdown File Segmentation

**Input:** `research-report.md` (2500 tokens)

```markdown
# Research Report

## Summary
Brief overview...

## Finding 1: MCP Integration
Details about MCP...

## Finding 2: Grep Fallback
Details about fallback...

## Recommendations
Action items...
```

**Content Map:**
```json
{
  "segments": [
    {"id": "seg-001", "topic": "meta/research", "summary": "Summary overview", "tokens": 150},
    {"id": "seg-002", "topic": "meta/mcp", "summary": "MCP Integration patterns", "tokens": 800},
    {"id": "seg-003", "topic": "meta/search", "summary": "Grep fallback strategy", "tokens": 600},
    {"id": "seg-004", "topic": "meta/process", "summary": "Recommendations", "tokens": 450}
  ]
}
```

### Directory Scan Flow

**Input:** `/learn ./lua/plugins/`

**Scan Results:**
```
Files found: 15
After size filter: 12
After text detection: 12

Select files to process:
[x] telescope.lua (2.3KB) - 3 segments expected
[x] lsp.lua (4.1KB) - 5 segments expected
[ ] unused.lua (0.5KB) - 1 segment expected
[x] keymaps.lua (1.8KB) - 2 segments expected
```

**Processing:**
```
Processing telescope.lua...
  Segment 1: "Telescope setup" -> CREATE (18% overlap)
  Segment 2: "Custom pickers" -> UPDATE MEM-telescope-custom-pickers (68% overlap)
  Segment 3: "Key mappings" -> EXTEND MEM-neovim-plugin-patterns (42% overlap)

Processing lsp.lua...
  [...]
```

---

## Summary

The integrated knowledge capture system provides:

- **`/fix-it`** - Capture issues, TODOs, and research questions from code
- **`/learn`** - Add knowledge from text, files, directories, or task artifacts
  - Content mapping for intelligent segmentation
  - MCP/grep search for deduplication
  - Three operations: UPDATE, EXTEND, CREATE
  - Topic-based organization
- **`/todo`** - Archive with CHANGE_LOG tracking and memory suggestions

Together, they create a continuous knowledge loop: discover -> document -> harvest -> archive.
