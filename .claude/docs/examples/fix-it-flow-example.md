# Integration Example: Fix-It Flow

This example traces a complete `/fix-it` command execution through the Neovim Configuration agent system, showing how the command scans for tags, presents findings interactively, and creates user-selected tasks.

---

## Scenario

A user runs `/fix-it nvim/lua/` to scan the Neovim Lua configuration directory for embedded tags. The system displays findings, then prompts the user to select which task types to create.

---

## Tag Types and Task Generation

The `/fix-it` command recognizes four tag types in source code comments:

| Tag | Task Type | Behavior |
|-----|-----------|----------|
| `FIX:` | fix-it-task | All FIX: and NOTE: tags grouped into single task |
| `NOTE:` | fix-it-task + learn-it-task | Creates two task types (with dependency when both selected) |
| `TODO:` | todo-task | User selects which TODO: tags become tasks (with optional topic grouping) |
| `QUESTION:` | research-task | User selects which QUESTION: tags become research tasks (content-based language detection) |

**Dependency behavior**: When NOTE: tags exist and both fix-it and learn-it tasks are selected, the learn-it task is created first and the fix-it task depends on it. This ensures proper workflow: learn-it extracts knowledge to context files (NOTE: tags remain in source), then fix-it addresses the code changes and removes both NOTE: and FIX: tags.

**QUESTION: language detection**: Unlike other tag types, QUESTION: tags use **content-based language detection** instead of file-type detection. The question text is analyzed for domain keywords (nvim/lsp/telescope -> neovim, theorem/proof/lemma -> latex, .claude/command/agent -> meta), defaulting to "general" for ambiguous cases. This ensures research questions are routed to the appropriate research agent based on what is being asked, not where the question was written.

---

## Complete Flow Diagram

```
User Input: /fix-it nvim/lua/
       |
       v
[Layer 1: Command] .claude/commands/fix-it.md
       |
       | Frontmatter specifies: allowed-tools: Skill
       v
[Layer 2: Skill] skill-fix-it/SKILL.md (DIRECT EXECUTION)
       |
       | 1. Parse arguments -> paths = ["nvim/lua/"]
       | 2. Generate session ID
       | 3. Execute tag extraction (grep patterns)
       | 4. Display tag summary to user
       | 5. AskUserQuestion: Select task types
       | 6. AskUserQuestion: Select TODO items (if applicable)
       | 7. Analyze TODO topics and cluster (if 2+ items)
       | 8. AskUserQuestion: Confirm topic grouping (if groups found)
       | 9. Create selected tasks
       | 8. Git commit postflight
       v
Output: Created N tasks from M tags
```

**Key difference from old pattern**: No subagent delegation. Everything executes directly in skill-fix-it using AskUserQuestion for interactivity.

---

## Step-by-Step Walkthrough

### Step 1: User Invokes Command

```bash
/fix-it nvim/lua/
```

Claude Code reads `.claude/commands/fix-it.md` and sees:

```yaml
---
description: Scan files for FIX:, NOTE:, TODO: tags and create structured tasks interactively
allowed-tools: Skill
argument-hint: [PATH...]
---
```

### Step 2: Skill Executes Tag Extraction

The skill (`skill-fix-it/SKILL.md`) executes directly (no subagent).

**Skill Step 1: Parse Arguments**

```bash
paths="nvim/lua/"
session_id="sess_1768940708_a1b2c3"
```

**Skill Step 2: Scan for Tags**

Execute grep patterns for each file type:

```bash
# Lua files
grep -rn --include="*.lua" "-- FIX:" nvim/lua/ 2>/dev/null
grep -rn --include="*.lua" "-- NOTE:" nvim/lua/ 2>/dev/null
grep -rn --include="*.lua" "-- TODO:" nvim/lua/ 2>/dev/null

# Example output:
nvim/lua/plugins/lsp.lua:67:-- TODO: Add language server for Go
nvim/lua/plugins/lsp.lua:89:-- FIX: Handle edge case in completion setup
nvim/lua/config/keymaps.lua:45:-- NOTE: This pattern should be documented
nvim/lua/utils/helpers.lua:23:-- TODO: Optimize this function
```

**Skill Step 3: Parse and Categorize**

```
fix_tags = [
  {file: "nvim/lua/plugins/lsp.lua", line: 89, content: "Handle edge case in completion setup"}
]
note_tags = [
  {file: "nvim/lua/config/keymaps.lua", line: 45, content: "This pattern should be documented"}
]
todo_tags = [
  {file: "nvim/lua/plugins/lsp.lua", line: 67, content: "Add language server for Go"},
  {file: "nvim/lua/utils/helpers.lua", line: 23, content: "Optimize this function"}
]
```

### Step 3: Display Tag Summary

User sees:

```
## Tag Scan Results

**Files Scanned**: nvim/lua/
**Tags Found**: 4

### FIX: Tags (1)
- `nvim/lua/plugins/lsp.lua:89` - Handle edge case in completion setup

### NOTE: Tags (1)
- `nvim/lua/config/keymaps.lua:45` - This pattern should be documented

### TODO: Tags (2)
- `nvim/lua/plugins/lsp.lua:67` - Add language server for Go
- `nvim/lua/utils/helpers.lua:23` - Optimize this function
```

### Step 4: Interactive Task Type Selection

**Skill Step 4: AskUserQuestion for Task Types**

The skill invokes AskUserQuestion with multi-select enabled:

```json
{
  "questions": [
    {
      "question": "Which task types would you like to create from these tags?",
      "header": "Task Types",
      "multiSelect": true,
      "options": [
        {
          "label": "Fix-it task (groups all FIX: and NOTE: tags)",
          "description": "Creates 1 task to address 2 items from FIX:/NOTE: tags"
        },
        {
          "label": "Learn-it task (documents insights from NOTE: tags)",
          "description": "Creates 1 task to update context files based on 1 NOTE: tag"
        },
        {
          "label": "TODO tasks (individual tasks from TODO: tags)",
          "description": "Select which of the 2 TODO: items should become tasks"
        }
      ]
    }
  ]
}
```

User selects:
- ✓ Fix-it task
- ✗ Learn-it task
- ✓ TODO tasks

### Step 5: Interactive TODO Item Selection

**Skill Step 5: AskUserQuestion for TODO Items**

Since "TODO tasks" was selected, the skill prompts for individual TODO item selection:

```json
{
  "questions": [
    {
      "question": "Select which TODO: items should become individual tasks:",
      "header": "TODO Items",
      "multiSelect": true,
      "options": [
        {
          "label": "Add language server for Go",
          "description": "From nvim/lua/plugins/lsp.lua:67"
        },
        {
          "label": "Optimize this function",
          "description": "From nvim/lua/utils/helpers.lua:23"
        }
      ]
    }
  ]
}
```

User selects:
- ✓ Add language server for Go
- ✓ Add language server for Rust
- ✓ Optimize this function

### Step 5.5: Topic Grouping (New Feature)

**Skill Step 5.5: Analyze TODO Topics**

Since multiple TODOs were selected (3 items), the skill analyzes them for topic grouping:

```
TODO analysis:
  "Add language server for Go" at nvim/lua/plugins/lsp.lua:67
    → key_terms: ["language", "server", "Go"]
    → file_section: "nvim/lua/plugins/"
    → action_type: "implementation"

  "Add language server for Rust" at nvim/lua/plugins/lsp.lua:89
    → key_terms: ["language", "server", "Rust"]
    → file_section: "nvim/lua/plugins/"
    → action_type: "implementation"

  "Optimize this function" at nvim/lua/utils/helpers.lua:23
    → key_terms: ["optimize", "function"]
    → file_section: "nvim/lua/utils/"
    → action_type: "improvement"

Clustering result:
  Group 1: "LSP Configuration" - 2 items (shared: language server, implementation)
  Group 2: "Utility Optimization" - 1 item
```

**Skill Step 5.6: AskUserQuestion for Topic Grouping**

Since there's at least one group with 2+ items, the skill presents grouping options:

```json
{
  "questions": [
    {
      "question": "How should TODO items be grouped into tasks?",
      "header": "TODO Topic Grouping",
      "multiSelect": false,
      "options": [
        {
          "label": "Accept suggested topic groups",
          "description": "Creates 2 grouped tasks: LSP Configuration (2 items), Utility Optimization (1 item)"
        },
        {
          "label": "Keep as separate tasks",
          "description": "Creates 3 individual tasks (one per TODO item)"
        },
        {
          "label": "Create single combined task",
          "description": "Creates 1 task containing all 3 TODO items"
        }
      ]
    }
  ]
}
```

User selects: **Accept suggested topic groups**

### Step 6: Task Creation

**Skill Step 6: Create Selected Tasks**

Based on user selections, create tasks. **Note**: When NOTE: tags exist and both fix-it and learn-it are selected, learn-it is created first with the fix-it task depending on it.

**Example A: Both fix-it and learn-it selected (with dependency)**

If user selected both "Fix-it task" and "Learn-it task" for NOTE: tags:

**Learn-It Task (Task #650, created FIRST)**:
```json
{
  "project_number": 650,
  "project_name": "update_context_from_note_tags",
  "status": "not_started",
  "task_type": "meta",
  "priority": "medium",
  "description": "Update 1 context files based on learnings:\n\n- nvim/lua/Layer2/Temporal.lua:45 - This pattern should be documented"
}
```

**Fix-It Task (Task #651, with dependency)**:
```json
{
  "project_number": 651,
  "project_name": "fix_issues_from_tags",
  "status": "not_started",
  "task_type": "neovim",
  "priority": "high",
  "dependencies": [650],
  "description": "Address 2 items from embedded tags:\n\n- nvim/lua/Layer1/Modal.lua:89 - Handle edge case in frame validation\n- nvim/lua/Layer2/Temporal.lua:45 - This pattern should be documented"
}
```

The TODO.md entry for the fix-it task includes:
```markdown
- **Dependencies**: 650
```

**Example B: Topic-grouped TODO tasks (new feature)**

When user selects "Accept suggested topic groups" in Step 5.6:

**Grouped TODO Task #1 (Task #650)**:
```json
{
  "project_number": 650,
  "project_name": "lsp_configuration_2_todo_items",
  "status": "not_started",
  "task_type": "neovim",
  "priority": "medium",
  "effort": "1.5 hours",
  "description": "Address TODO items related to LSP Configuration:\n\n- [ ] Add language server for Go (`nvim/lua/Layer1/Modal.lua:67`)\n- [ ] Add language server for Rust (`nvim/lua/Layer1/Modal.lua:89`)\n\n---\n\nShared context: Related to LSP language servers"
}
```

**Grouped TODO Task #2 (Task #651)**:
```json
{
  "project_number": 651,
  "project_name": "utility_optimization_1_todo_item",
  "status": "not_started",
  "task_type": "neovim",
  "priority": "medium",
  "effort": "1 hour",
  "description": "Address TODO items related to Utility Optimization:\n\n- [ ] Optimize this function (`nvim/lua/Shared/Utils.lua:23`)\n\n---\n\nShared context: Performance improvement in shared utilities"
}
```

**Effort scaling applied**:
- LSP Configuration: 2 items = 1h + 30min = 1.5 hours
- Utility Optimization: 1 item = 1 hour (base)

**Example C: Separate TODO tasks (original behavior)**

When user selects "Keep as separate tasks":

**TODO Task (Task #650)**:
```json
{
  "project_number": 650,
  "project_name": "add_go_language_server",
  "status": "not_started",
  "task_type": "neovim",
  "priority": "medium",
  "description": "Add language server for Go\n\nSource: nvim/lua/Layer1/Modal.lua:67"
}
```

(Plus 2 more individual tasks for soundness theorem and utility optimization)

### Step 7: Postflight Git Commit

```bash
git add specs/TODO.md specs/state.json
git commit -m "fix-it: create 2 tasks from 4 tags

Session: sess_1768940708_a1b2c3

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

### Step 8: User Sees Results

**Example output when both fix-it and learn-it selected (with dependency)**:

```
## Tasks Created from Tags

**Tags Processed**: 4 tags scanned, 3 tasks created

### Created Tasks

| # | Type | Title | Priority | Task Type | Dependencies |
|---|------|-------|----------|----------|--------------|
| 650 | learn-it | Update context files from NOTE: tags | Medium | meta | - |
| 651 | fix-it | Fix issues from FIX:/NOTE: tags | High | neovim | 650 |
| 652 | todo | Add language server for Go | Medium | neovim | - |
```

**Example output with topic-grouped TODO tasks (new feature)**:

```
## Tasks Created from Tags

**Tags Processed**: 4 tags scanned, 3 tasks created

### Created Tasks

| # | Type | Title | Priority | Task Type | Effort |
|---|------|-------|----------|----------|--------|
| 650 | fix-it | Fix issues from FIX:/NOTE: tags | High | neovim | 2-4h |
| 651 | todo (grouped) | LSP Configuration: 2 TODO items | Medium | neovim | 1.5h |
| 652 | todo (grouped) | Utility Optimization: 1 TODO item | Medium | neovim | 1h |

---

**Next Steps**:
1. Review tasks in TODO.md
2. Run `/research 650` to begin
3. Progress through /research -> /plan -> /implement cycle
```

**Example output with separate TODO tasks (original behavior)**:

```
## Tasks Created from Tags

**Tags Processed**: 4 tags scanned, 4 tasks created

### Created Tasks

| # | Type | Title | Priority | Task Type |
|---|------|-------|----------|----------|
| 650 | fix-it | Fix issues from FIX:/NOTE: tags | High | neovim |
| 651 | todo | Add language server for Go | Medium | neovim |
| 652 | todo | Add language server for Rust | Medium | neovim |
| 653 | todo | Optimize this function | Medium | neovim |
```

---

## Tag Detection Examples

### Lua Files (.lua)

```lua
-- FIX: This needs to handle the empty frame case
-- NOTE: The S5 axiom pattern could be generalized
-- TODO: Add reflexivity lemma
-- QUESTION: What is the best way to implement telescope pickers?
```

### LaTeX Files (.tex)

```latex
% FIX: Correct the citation format
% NOTE: This theorem should be referenced in the appendix
% TODO: Add proof sketch for completeness
% QUESTION: How do I prove the lemma about modal accessibility?
```

### Markdown Files (.md)

```markdown
<!-- FIX: Update outdated section -->
<!-- NOTE: Consider reorganizing these examples -->
<!-- TODO: Add code examples -->
<!-- QUESTION: What is the best structure for agent documentation? -->
```

### Python/Shell Files

```python
# FIX: Handle edge case when input is empty
# NOTE: This algorithm could be optimized
# TODO: Add unit tests
# QUESTION: What is the recommended approach for async file I/O?
```

---

## Context Routing for NOTE: Tags

NOTE: tags are special because they can create both fix-it and learn-it tasks. The learn-it task routes to appropriate context directories:

| Source File Pattern | Target Context Directory |
|--------------------|-------------------------|
| `.claude/agents/*.md` | `.claude/context/agents/` |
| `.claude/skills/*/SKILL.md` | `.claude/context/skills/` |
| `.claude/commands/*.md` | `.claude/context/commands/` |
| `nvim/lua/**/*.lua` | `.claude/context/project/neovim/` |
| `docs/*.tex` | `.claude/context/project/logic/` |

---

## Edge Case Scenarios

### Scenario A: No Tags Found

If user runs `/fix-it nvim/lua/` but no tags exist:

```
## No Tags Found

Scanned files in: nvim/lua/
No FIX:, NOTE:, TODO:, or QUESTION: tags detected.

Nothing to create.
```

Exits gracefully without prompts.

### Scenario E: QUESTION: Tags with Content-Based Language Detection

If user runs `/fix-it` and the scan finds QUESTION: tags:

```
## Tag Scan Results

**Files Scanned**: nvim/lua/
**Tags Found**: 3

### QUESTION: Tags (3)
- `nvim/lua/config/lsp.lua:45` - What is the best way to configure LSP hover windows?
- `docs/guide.tex:89` - How do I prove this theorem about completeness?
- `scripts/build.sh:12` - What is the best approach for caching build artifacts?
```

When creating research tasks, language is detected from **question content**, not source file:

| Question | Source File | Detected Language | Reason |
|----------|-------------|-------------------|--------|
| "What is the best way to configure LSP hover windows?" | `.lua` | neovim | Contains "LSP" keyword |
| "How do I prove this theorem about completeness?" | `.tex` | latex | Contains "theorem" keyword |
| "What is the best approach for caching build artifacts?" | `.sh` | general | No domain keywords found |

**Key insight**: The middle question would be detected as "latex" even though it's in a .tex file - this is the desired behavior. A math question in a .tex file could theoretically be "general" if it doesn't contain latex keywords, while an LSP question in any file type would be "neovim".

### Scenario B: Only FIX: Tags

If only FIX: tags are found:

- Display tag summary with only FIX: tags section
- AskUserQuestion offers only "Fix-it task" option (no NOTE:/TODO: options)
- User can choose to create or skip

### Scenario C: Large Number of TODO Items

If more than 20 TODO: tags are found:

The AskUserQuestion prompt includes an option:

```json
{
  "options": [
    {
      "label": "Select all TODO items",
      "description": "Create tasks for all 23 TODO: tags"
    },
    ...individual items...
  ]
}
```

This prevents overwhelming the UI with too many checkboxes.

### Scenario D: User Selects Nothing

If user deselects all task types:

```
## No Tasks Created

You chose not to create any tasks from the 4 tags found.

Run /fix-it again if you change your mind.
```

Exits gracefully without creating tasks or git commits.

---

## Comparison: Old vs New Flow

### Old Pattern (Deprecated)

```
User runs: /fix-it nvim/lua/ --dry-run
  → skill-fix-it (thin wrapper)
    → fix-it-agent (subagent via Task tool)
      → Returns JSON metadata to skill
    → skill reads metadata, displays preview
User reviews preview
User runs: /fix-it nvim/lua/ (without --dry-run)
  → Same delegation flow, but creates tasks automatically
```

**Issues**:
- Required two commands (dry-run, then execute)
- Background subagent process
- No granular control (all or nothing)

### New Pattern (Current)

```
User runs: /fix-it nvim/lua/
  → skill-fix-it (direct execution)
    → Scans tags inline
    → Displays findings
    → AskUserQuestion: task types
    → AskUserQuestion: TODO items (if applicable)
    → Creates selected tasks
```

**Benefits**:
- Single command, interactive flow
- Synchronous execution, no background process
- Granular control over which tasks to create
- Always preview before creation

---

## Summary

This example demonstrated:

1. **Direct Execution**: No subagent delegation, all logic in skill-fix-it
2. **Interactive Selection**: AskUserQuestion for task type and TODO/QUESTION item choices
3. **Tag Extraction**: Using grep patterns for multiple file types (FIX:, NOTE:, TODO:, QUESTION:)
4. **Task Grouping**: FIX:/NOTE: grouped into fix-it task, TODO:/QUESTION: individual or topic-grouped tasks
5. **Topic Analysis**: Automatic clustering of related TODO and QUESTION items by shared terms and context
6. **Content-Based Language Detection**: QUESTION: tags detect language from question content, not source file
7. **User Control**: Granular selection of what to create and how to group
8. **Edge Case Handling**: Graceful handling of no tags, user cancelation, large item lists

The `/fix-it` command provides:
- Automated task discovery from embedded source comments
- Interactive preview-then-select workflow
- **Smart topic grouping for related TODO and QUESTION items**
- **Content-based language routing for research tasks**
- Structured task creation following project standards
- User control over which tasks are created and grouping approach

---

## Related Documentation

- [Research Flow Example](research-flow-example.md) - End-to-end research flow
- [Creating Commands](../guides/creating-commands.md) - Command creation guide
- [Creating Skills](../guides/creating-skills.md) - Skill creation guide (direct execution pattern)
- `.claude/commands/fix-it.md` - Command definition
- `.claude/skills/skill-fix-it/SKILL.md` - Skill definition (direct execution, no agent)

---

**Document Version**: 2.0 (Updated 2026-01-20)
**Created**: 2026-01-20
**Maintained By**: Neovim Configuration Team
