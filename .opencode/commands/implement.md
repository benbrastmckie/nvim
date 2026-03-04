---
description: Execute implementation with resume support
---

Execute the implementation plan for the given task, phase by phase.

**Input**: $ARGUMENTS

---

## Parse Input

- First token: task number — accepts `OC_N` or `N` (strip `OC_` prefix to get integer N)
- `--force`: skip status validation
- Remaining tokens: optional custom instructions
- If invalid: "Usage: /implement <OC_N> [--force] [instructions]"

---

## Steps

### 1. Look up task

Strip `OC_` prefix, find task in `specs/state.json`:
```bash
jq --arg n "N" '.active_projects[] | select(.project_number == ($n | tonumber))' specs/state.json
```
If not found: "Task OC_N not found in state.json"

Extract: `language`, `status`, `project_name`, `description`

Zero-pad N to 3 digits: `NNN`

Directory: `specs/OC_NNN_<project_name>/`

### 2. Validate status (unless --force)

- `planned`, `partial`, `researched`, `not_started`: proceed
- `implementing`: warn "already implementing, resuming"
- `abandoned`: error "task is abandoned, use /task --recover first"
- `completed`: error "already completed, use --force to re-implement"

### 3. Display task header

Print a visual header showing the active task:

```
╔══════════════════════════════════════════════════════════╗
║  Task OC_N: <project_name>                               ║
║  Action: IMPLEMENTING                                     ║
╚══════════════════════════════════════════════════════════╝
```

This header appears at the start of the implement command to clearly indicate which task is being implemented.

### 4. Find implementation plan

Look for `specs/OC_NNN_<project_name>/plans/implementation-*.md` — use the highest version.

If no plan found: "No plan found. Run `/plan OC_N` first."

Read the plan to understand all phases and their current status (`[NOT STARTED]`, `[IN PROGRESS]`, `[COMPLETED]`, `[PARTIAL]`).

### 5. Update status to IMPLEMENTING

Edit `specs/state.json`: set `status` to `"implementing"`, update `last_updated`.

Edit `specs/TODO.md`: change current status marker to `[IMPLEMENTING]` on the `### OC_N.` entry.

### 6. Execute phases

For each phase with status `[NOT STARTED]` or `[PARTIAL]` (skip `[COMPLETED]`):

1. **Track changes** - Capture baseline git state before phase execution
2. Update phase status to `[IN PROGRESS]` in the plan file
3. Execute the phase steps
4. Verify the phase (run verification steps from the plan)
5. Update phase status to `[COMPLETED]` in the plan file
6. **Commit phase changes** - Stage and commit only files modified in this phase
7. Briefly report phase completion before moving to next

**Per-phase commit**:
```bash
# After phase completion, commit only changed files
git status --porcelain | awk '{print $NF}' > /tmp/phase_files_$$.txt
phase_files=$(cat /tmp/phase_files_$$.txt | tr '\n' ' ')

if [ -n "$phase_files" ]; then
    git add $phase_files
    git commit -m "task OC_${N} phase {P}: {phase_name}

Session: ${session_id}

Co-Authored-By: OpenCode <noreply@opencode.ai>" || echo "Warning: Phase commit failed"
fi

rm -f /tmp/phase_files_$$.txt
```

**Commit-on-block** (when phase fails and cannot complete):
```bash
# Create partial report if not exists, then commit
if [ -n "$phase_files" ]; then
    git add $phase_files
    git commit -m "task OC_${N}: partial implementation (blocked phase {P})

Session: ${session_id}

Co-Authored-By: OpenCode <noreply@opencode.ai>" || echo "Warning: Blocked commit failed"
fi
```

If any custom instructions were given in $ARGUMENTS, incorporate them.

**Language-specific guidance**:
- **meta**: Edit `.opencode/` files, create/update agent and command definitions
- **lean**: Write Lean 4 proofs, use `lake build` to verify
- **typst**: Write Typst markup, use `typst compile` to verify
- **latex**: Write LaTeX, use `pdflatex` to verify
- **general**: Follow the plan steps using appropriate tools

### 7. Write implementation summary

Create directory: `mkdir -p specs/OC_NNN_<project_name>/summaries/`

Write `specs/OC_NNN_<project_name>/summaries/implementation-summary-YYYYMMDD.md`:

```markdown
# Implementation Summary: Task #N

**Completed**: YYYY-MM-DD
**Language**: <language>

## Changes Made

<Overview of what was implemented>

## Files Modified

- `path/to/file` - <what changed>

## Verification

- <What was verified and how>

## Notes

<Any important notes or follow-up items>
```

### 8. Update status to COMPLETED

Edit `specs/state.json`:
- Set `status` to `"completed"`
- Update `last_updated`
- Add `completion_summary`: 1-3 sentence description of what was accomplished
- Add to `artifacts` array:
```json
{
  "type": "summary",
  "path": "specs/OC_NNN_<project_name>/summaries/implementation-summary-YYYYMMDD.md",
  "summary": "<one sentence>"
}
```

Edit `specs/TODO.md` on the `### OC_N.` entry:
- Change `[IMPLEMENTING]` to `[COMPLETED]`
- Add line: `- **Summary**: [implementation-summary-YYYYMMDD.md](OC_NNN_<project_name>/summaries/implementation-summary-YYYYMMDD.md)`

### 9. Report to user

Show:
- Phases completed
- Files changed
- Summary path
- Any follow-up suggestions

---

## Rules

- Execute phases in order — do not skip ahead
- Mark each phase `[COMPLETED]` in the plan file as you finish it
- If a phase fails, mark it `[PARTIAL]` in the plan and stop — do not mark task completed
- Write the summary BEFORE updating status to COMPLETED
- Directories use 3-digit padded number: `OC_174_slug` not `OC_17_slug`
- For Lean tasks, always verify with `lake build` after each phase
- **Commit after each phase completion** — stage only files modified in that phase
- **Commit when blocked** — if phase fails, commit partial progress before stopping
