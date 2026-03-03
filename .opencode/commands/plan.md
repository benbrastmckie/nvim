---
description: Create a phased implementation plan for a task
---

Create an implementation plan for the given task. Do NOT implement anything.

**Input**: $ARGUMENTS

---

## Parse Input

- First token: task number — accepts `OC_N` or `N` (strip `OC_` prefix to get integer N)
- Remaining tokens: optional notes/constraints
- If invalid: "Usage: /plan <OC_N> [notes]"

---

## Steps

### 1. Look up task

Strip `OC_` prefix, find task in `specs/state.json`:
```bash
jq --arg n "N" '.active_projects[] | select(.project_number == ($n | tonumber))' specs/state.json
```
If not found: "Task OC_N not found in state.json"

Extract: `language`, `status`, `project_name`, `description`

Zero-pad N to 3 digits: `NNN` (e.g. `printf "%03d" N`)

Directory: `specs/OC_NNN_<project_name>/`

### 2. Validate status

- `researched`, `not_started`, `partial`: proceed
- `planning`: warn "already planning, proceeding"
- `abandoned`: error "task is abandoned, use /task --recover first"
- `completed`: warn "already completed, re-planning"

### 3. Display task header

Print a visual header showing the active task:

```
╔══════════════════════════════════════════════════════════╗
║  Task OC_N: <project_name>                               ║
║  Action: PLANNING                                         ║
╚══════════════════════════════════════════════════════════╝
```

This header appears at the start of the plan command to clearly indicate which task is being planned.

### 4. Update status to PLANNING

Edit `specs/state.json`: set `status` to `"planning"`, update `last_updated`.

Edit `specs/TODO.md`: change current status marker to `[PLANNING]` on the `### OC_N.` entry.

### 5. Read existing research

Check for `specs/OC_NNN_<project_name>/reports/research-001.md`. If it exists, read it for context. If not, plan from the task description alone.

### 6. Create implementation plan

Decompose the task into phases. Each phase should be independently completable (2-4 hours of work). Use the task description, research findings, and any notes from $ARGUMENTS.

Create directory: `mkdir -p specs/OC_NNN_<project_name>/plans/`

Write `specs/OC_NNN_<project_name>/plans/implementation-001.md`:

```markdown
# Implementation Plan: Task #N

**Task**: OC_N - <title>
**Version**: 001
**Created**: YYYY-MM-DD
**Language**: <language>

## Overview

<2-3 sentence description of the approach>

## Phases

### Phase 1: <Name>

**Status**: [NOT STARTED]
**Estimated effort**: X hours

**Objectives**:
1. <objective>

**Files to modify**:
- `path/to/file` - <what changes>

**Steps**:
1. <step>

**Verification**:
- <how to verify this phase is done>

---

### Phase 2: <Name>

...

---

## Dependencies

- <dependency or "None">

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| <risk> | <mitigation> |

## Success Criteria

- [ ] <criterion>
```

### 7. Update status to PLANNED

Edit `specs/state.json`:
- Set `status` to `"planned"`
- Update `last_updated`
- Add to `artifacts` array:
```json
{
  "type": "plan",
  "path": "specs/OC_NNN_<project_name>/plans/implementation-001.md",
  "summary": "<one sentence>"
}
```

Edit `specs/TODO.md` on the `### OC_N.` entry:
- Change `[PLANNING]` to `[PLANNED]`
- Add line: `- **Plan**: [implementation-001.md](OC_NNN_<project_name>/plans/implementation-001.md)`

### 8. Commit changes

Create a targeted commit with only the changed files:

```bash
# Generate session ID
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"

# Get list of changed files
git status --porcelain | awk '{print $NF}' > /tmp/changed_files_$$.txt
changed_files=$(cat /tmp/changed_files_$$.txt | tr '\n' ' ')

# Commit if there are changes
if [ -n "$changed_files" ]; then
    git add $changed_files
    git commit -m "task OC_${N}: create implementation plan

Session: ${session_id}

Co-Authored-By: OpenCode <noreply@opencode.ai>" || echo "Warning: Commit failed but plan created"
fi

# Cleanup
rm -f /tmp/changed_files_$$.txt
```

**Files committed**:
- `specs/OC_NNN_<project_name>/plans/implementation-001.md` - Plan file
- `specs/state.json` - Status and artifact updates
- `specs/TODO.md` - Status marker and plan link

**Error handling**: Commit failures are non-blocking. Log a warning and continue.

### 9. Report to user

Show:
- Plan path
- Number of phases and estimated total effort
- Next step: `/implement OC_N`

---

## Rules

- Write the plan file BEFORE updating status to PLANNED
- Phases should be granular enough to be resumable if interrupted
- Directories use 3-digit padded number: `OC_174_slug` not `OC_17_slug`
- If plan already exists, create `implementation-002.md` (increment version)
- Commit changes after creating plan (non-blocking — log warning if commit fails)
