# Usage Examples

Example workflows for the knowledge capture system commands.

---

## /fix Command Examples

The `/fix` command scans files for embedded tags (FIX:, NOTE:, TODO:) and creates structured tasks.

### Example 1: Scan Entire Project

```bash
/fix
```

**Workflow:**
1. Scans entire project for FIX:/NOTE:/TODO: tags
2. Displays summary:
   ```
   Tags Found:
   - FIX: 3 tags
   - NOTE: 5 tags
   - TODO: 12 tags
   ```
3. Presents interactive selection with checkboxes
4. User selects which tags to convert to tasks
5. Creates tasks in specs/TODO.md and updates state.json

### Example 2: Scan Specific Directory

```bash
/fix src/core/
```

**Use Case:** Focus on a specific module or component without scanning the entire codebase.

**Workflow:**
1. Scans only src/core/ directory
2. Shows tags found in that directory only
3. Interactive selection and task creation

### Example 3: Scan Multiple Paths

```bash
/fix src/core.lua src/utils/ config/
```

**Use Case:** Review multiple specific files and directories in one operation.

---

## /remember Task Mode Examples

The `/remember --task OC_N` command reviews task artifacts and creates classified memories.

### Example 1: Review All Task Artifacts

```bash
/remember --task 142
```

**Workflow:**
1. Scans specs/OC_142_implement_knowledge_capture_system/ for artifacts
2. Displays found files:
   ```
   Artifacts found for Task OC_142:
   
   1. reports/research-002.md (Research Report)
   2. plans/implementation-003.md (Implementation Plan)
   3. summaries/implementation-summary-20260305.md (Summary)
   ```
3. User selects artifacts to review (e.g., selects all)
4. Reviews each artifact with classification:
   ```
   Reviewing: plans/implementation-003.md
   
   Classify this artifact:
   - [x] [PATTERN] - Design or implementation pattern
   - [ ] [TECHNIQUE] - Reusable method
   - [ ] [CONFIG] - Configuration knowledge
   - [ ] [WORKFLOW] - Process or procedure
   - [ ] [INSIGHT] - Key learning
   - [ ] [SKIP] - Not valuable
   ```
5. Creates memory with classification tag
6. Updates memory vault index

### Example 2: Create Memory from Research Report

```bash
/remember --task 146
```

**Scenario:** Task OC_146 is a research task on subagent workflows.

**Workflow:**
1. Finds research-001.md with comprehensive findings
2. User reviews and classifies as [INSIGHT]
3. Memory created:
   ```markdown
   # Memory: Subagent Workflow Best Practices
   
   **Category**: [INSIGHT]
   **Source**: Task OC_146 - reports/research-001.md
   **Date**: 2026-03-05
   
   Key findings on isolated context windows and metadata passing...
   ```

### Example 3: Extract Pattern from Implementation

```bash
/remember --task 139
```

**Scenario:** Task OC_139 demonstrated stage-progressive loading.

**Workflow:**
1. Reviews implementation-001.md
2. Classifies as [PATTERN]
3. Memory captures reusable pattern for context loading

---

## /todo Examples

The enhanced `/todo` command now includes CHANGE_LOG updates and memory harvest suggestions.

### Example 1: Archive with CHANGE_LOG Update

```bash
/todo
```

**Workflow:**
1. Scans for completed tasks
2. Archives tasks to specs/archive/
3. Updates specs/CHANGE_LOG.md:
   ```markdown
   ### 2026-03-05
   
   **Task OC_142: implement_knowledge_capture_system**
   - Status: completed
   - Type: meta
   - Summary: Implemented knowledge capture system
   ```
4. Commits all changes

### Example 2: Preview Before Archiving

```bash
/todo --dry-run
```

**Use Case:** Preview what would be archived without making changes.

**Output:**
```
Dry Run - Would Archive:
- 3 completed tasks
- 1 abandoned task
- 2 roadmap items would be annotated
- 5 memory harvest suggestions available
```

### Example 3: Memory Harvest Suggestions

When archiving tasks, /todo now suggests memory creation:

```
Memory Harvest Suggestions from Completed Tasks:

From Task OC_142:
- [x] [PATTERN] - Clean-break approach for command renaming
- [x] [TECHNIQUE] - Skill extraction from embedded logic
- [ ] [CONFIG] - CHANGE_LOG.md format

Create selected memories? [Yes/No]
```

---

## Cross-Feature Workflow Example

Complete workflow demonstrating all three features working together:

### Step 1: Scan for Issues
```bash
/fix src/
```
Finds 3 FIXME tags in source code, creates tasks.

### Step 2: Research a Task
```bash
/research OC_150
```
Creates comprehensive research report.

### Step 3: Create Memories from Research
```bash
/remember --task 150
```
Reviews research report, classifies findings as [INSIGHT] and [TECHNIQUE].

### Step 4: Implement the Task
```bash
/implement OC_150
```
Executes plan, creates implementation.

### Step 5: Archive and Update
```bash
/todo
```
- Archives completed task
- Updates ROAD_MAP.md with completion annotation
- Updates CHANGE_LOG.md with entry
- Suggests harvesting implementation patterns

---

## Migration Guide: /learn to /fix

If you were using `/learn` before the rename:

| Old Command | New Command | Notes |
|-------------|-------------|-------|
| `/learn` | `/fix` | Same functionality |
| `/learn src/` | `/fix src/` | No change in behavior |
| `/learn file.lua` | `/fix file.lua` | Same tag scanning |

**What Changed:**
- Command name only
- All functionality identical
- No aliases or fallbacks (clean-break approach)

**How to Adapt:**
1. Replace muscle memory: type `/fix` instead of `/learn`
2. Update any scripts or documentation referencing `/learn`
3. Use `/fix --help` for reference

---

## Summary

These examples demonstrate the integrated knowledge capture system:

- **`/fix`** - Capture issues and TODOs from code
- **`/remember --task`** - Harvest knowledge from completed work
- **`/todo`** - Archive with CHANGE_LOG tracking and memory suggestions

Together, they create a continuous knowledge loop: discover -> document -> harvest -> archive.
