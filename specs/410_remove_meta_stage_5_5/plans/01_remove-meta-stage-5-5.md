# Implementation Plan: Task #410

**Task**: 410 - Remove meta Stage 5.5 auto-research artifact generation
**Status**: [COMPLETED]
**Created**: 2026-04-13
**Effort**: ~1 hour
**Phases**: 3
**Complexity**: simple
**Dependencies**: None

---

## Summary

Remove Stage 5.5 (GenerateResearchArtifacts) from the meta-builder-agent so tasks created by `/meta` start in NOT STARTED status instead of RESEARCHED. Three files require changes: the agent definition, the skill return format, and the multi-task creation standard. All changes are deletions or text replacements -- no new logic is needed.

---

## Phase 1: Remove Stage 5.5 from meta-builder-agent.md [COMPLETED]

**File**: `.claude/agents/meta-builder-agent.md`
**Effort**: 30 minutes

### Step 1.1: Update Stage 5 transition (line 592)

**old_string**:
```
**If user selects "Yes"**: Proceed to Stage 5.5 (Research Artifact Generation).
```

**new_string**:
```
**If user selects "Yes"**: Proceed to Stage 6 (CreateTasks).
```

### Step 1.2: Delete entire Stage 5.5 section (lines 594-691)

Remove the entire block from `### Interview Stage 5.5: GenerateResearchArtifacts` through the line before `### Interview Stage 6: CreateTasks`. This includes:
- The stage header and trigger/purpose
- Subsections 5.5.1 (directory creation)
- Subsection 5.5.2 (research report template)
- Subsection 5.5.3 (artifact tracking)
- Subsection 5.5.4 (proceed to Stage 6)
- The `---` separator after Stage 5.5

Delete from:
```
### Interview Stage 5.5: GenerateResearchArtifacts
```
Through and including the `---` separator that immediately precedes `### Interview Stage 6: CreateTasks`.

### Step 1.3: Update state.json template (lines 774-792)

**old_string**:
```json
{
  "project_number": 36,
  "project_name": "task_slug",
  "status": "researched",
  "task_type": "meta",
  "dependencies": [35, 34],
  "artifacts": [
    {
      "type": "research",
      "path": "specs/036_task_slug/reports/01_meta-research.md",
      "summary": "Auto-generated research from /meta interview"
    }
  ]
}
```

**Note**: Tasks created via /meta start in `"researched"` status because Stage 5.5 generates research artifacts from interview context. This enables immediate `/plan N` without requiring separate `/research N`.
```

**new_string**:
```json
{
  "project_number": 36,
  "project_name": "task_slug",
  "status": "not_started",
  "task_type": "meta",
  "dependencies": [35, 34],
  "artifacts": []
}
```

### Step 1.4: Update TODO.md entry template (lines 794-806)

**old_string**:
```markdown
### {N}. {Title}
- **Effort**: {estimate}
- **Status**: [RESEARCHED]
- **Task Type**: {task_type}
- **Dependencies**: Task #35, Task #34  OR  None
- **Research**: [01_meta-research.md]({NNN}_{slug}/reports/01_meta-research.md)

**Description**: {description}

---
```

**new_string**:
```markdown
### {N}. {Title}
- **Effort**: {estimate}
- **Status**: [COMPLETED]
- **Task Type**: {task_type}
- **Dependencies**: Task #35, Task #34  OR  None

**Description**: {description}

---
```

### Step 1.5: Update batch insertion code (lines 827-840)

**old_string**:
```python
    # Build entry (with RESEARCHED status and research link)
    padded_num = f"{task_num:03d}"
    research_path = f"{padded_num}_{task['slug']}/reports/01_meta-research.md"

    entry = f"""### {task_num}. {task['title']}
- **Effort**: {task['effort']}
- **Status**: [RESEARCHED]
- **Task Type**: {task['task_type']}
- **Dependencies**: {dep_str}
- **Research**: [01_meta-research.md]({research_path})

**Description**: {task['description']}

---"""
```

**new_string**:
```python
    # Build entry (NOT STARTED status, no research link)
    entry = f"""### {task_num}. {task['title']}
- **Effort**: {task['effort']}
- **Status**: [COMPLETED]
- **Task Type**: {task['task_type']}
- **Dependencies**: {dep_str}

**Description**: {task['description']}

---"""
```

### Step 1.6: Verify DeliverSummary next_steps (no change expected)

Read lines 1100-1260 and confirm that the DeliverSummary examples already say `/research` as the next step. Per research report, no changes are needed here -- but verify during implementation.

---

## Phase 2: Update skill-meta return format [COMPLETED]

**File**: `.claude/skills/skill-meta/SKILL.md`
**Effort**: 15 minutes

### Step 2.1: Update summary text (line 130)

**old_string**:
```
  "summary": "Created 2 tasks for command creation workflow. Tasks start in RESEARCHED status.",
```

**new_string**:
```
  "summary": "Created 2 tasks for command creation workflow. Tasks start in NOT STARTED status.",
```

### Step 2.2: Remove research artifact objects from artifacts array (lines 138-151)

Remove the two `"type": "research"` objects, keeping only the `"type": "task"` objects:

**old_string**:
```json
  "artifacts": [
    {
      "type": "task",
      "path": "specs/430_create_export_command/",
      "summary": "Task directory for new command"
    },
    {
      "type": "research",
      "path": "specs/430_create_export_command/reports/01_meta-research.md",
      "summary": "Auto-generated research from /meta interview"
    },
    {
      "type": "task",
      "path": "specs/431_export_command_tests/",
      "summary": "Task directory for tests"
    },
    {
      "type": "research",
      "path": "specs/431_export_command_tests/reports/01_meta-research.md",
      "summary": "Auto-generated research from /meta interview"
    }
  ],
```

**new_string**:
```json
  "artifacts": [
    {
      "type": "task",
      "path": "specs/430_create_export_command/",
      "summary": "Task directory for new command"
    },
    {
      "type": "task",
      "path": "specs/431_export_command_tests/",
      "summary": "Task directory for tests"
    }
  ],
```

### Step 2.3: Update metadata fields (lines 160-162)

**old_string**:
```json
    "tasks_status": "researched"
  },
  "next_steps": "Run /plan 430 to create implementation plan (research already complete)"
```

**new_string**:
```json
    "tasks_status": "not_started"
  },
  "next_steps": "Run /research 430 to begin research on first task"
```

### Step 2.4: Update the note after the return example (lines 166-167)

**old_string**:
```
**Note**: Tasks created via `/meta` start in RESEARCHED status because the interview process generates research artifacts from the captured context. This enables immediate `/plan N` execution without requiring separate `/research N` calls.
```

**new_string**:
```
**Note**: Tasks created via `/meta` start in NOT STARTED status. Run `/research N` to begin the standard research -> plan -> implement lifecycle.
```

---

## Phase 3: Update multi-task-creation-standard.md [COMPLETED]

**File**: `.claude/docs/reference/standards/multi-task-creation-standard.md`
**Effort**: 15 minutes

### Step 3.1: Remove Research Generation row from reference implementation table (line 373)

Delete this row:
```
| **Research Generation** | **Interview Stage 5.5 (GenerateResearchArtifacts)** |
```

### Step 3.2: Update State Updates row (line 374)

**old_string**:
```
| State Updates | Interview Stage 6 (batch insertion with RESEARCHED status) |
```

**new_string**:
```
| State Updates | Interview Stage 6 (batch insertion with NOT STARTED status) |
```

### Step 3.3: Remove Stage 5.5 from Enhanced Stages list (line 378)

Delete this line:
```
- **Stage 5.5 (GenerateResearchArtifacts)**: Creates `01_meta-research.md` from interview context for each task
```

### Step 3.4: Remove Research Gen column from compliance table (lines 384-390)

**old_string**:
```
| Command | Required | Grouping | Dependencies | Ordering | Visualization | Research Gen |
|---------|----------|----------|--------------|----------|---------------|--------------|
| `/meta` | Yes | **Automatic** | Full DAG | Kahn's | Linear/Layered | **Yes** |
| `/fix-it` | Yes | Yes | Internal only | No | No | No |
| `/review` | Yes | Yes | No | No | No | No |
| `/errors` | Partial* | No | No | No | No | No |
| `/task --review` | Yes | No | parent_task | No | No | No |
```

**new_string**:
```
| Command | Required | Grouping | Dependencies | Ordering | Visualization |
|---------|----------|----------|--------------|----------|---------------|
| `/meta` | Yes | **Automatic** | Full DAG | Kahn's | Linear/Layered |
| `/fix-it` | Yes | Yes | Internal only | No | No |
| `/review` | Yes | Yes | No | No | No |
| `/errors` | Partial* | No | No | No | No |
| `/task --review` | Yes | No | parent_task | No | No |
```

### Step 3.5: Remove Stage 5.5 references from Enhanced Features section (lines 394-397)

Delete these two lines:
```
- **Research Artifact Generation** (Stage 5.5): Creates lightweight research reports from interview context
- **RESEARCHED Status**: Tasks start in `researched` status, enabling immediate `/plan N` without separate `/research N`
```

Keep the remaining line about Automatic Topic Clustering.

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Existing tasks 409-413 have RESEARCHED status from auto-generation | Known | Low | No retroactive fixup needed; tasks have detailed descriptions with file paths |
| Users run `/plan N` after `/meta` instead of `/research N` | Low | Low | DeliverSummary already says "Run /research N"; status check in `/plan` will catch invalid transition |
| Prompt-mode path references Stage 5.5 | Low | Medium | Research verified line 1305 has no Stage 5.5 reference |

## Validation

After implementation, verify:

1. **Grep for residual references**: Search all three files for "5.5", "Stage 5.5", "RESEARCHED" (in meta context), "meta-research", "GenerateResearch" to confirm complete removal
2. **Template consistency**: Confirm state.json template shows `"not_started"` and empty artifacts array
3. **TODO.md template**: Confirm `[COMPLETED]` status and no research link line
4. **DeliverSummary**: Confirm next_steps examples still say `/research` (unchanged)
5. **No orphaned references**: Grep `.claude/` broadly for "Stage 5.5" to catch any cross-references not identified in research
