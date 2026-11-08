---
description: Create new version of implementation plan, or update task description if no plan exists
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Read, Edit, Glob
argument-hint: TASK_NUMBER [REASON]
model: opus
---

# /revise Command

Create a new version of an implementation plan, or update task description if no plan exists.

**Artifact Numbering Note**: Plan revision creates a new plan file within the same artifact round. The revised plan uses the SAME artifact number (not incremented) because it replaces the previous plan in the same round. Only a research-phase dispatch — or a forced `/orchestrate --plan`/`--implement` dispatch that skips research — advances the artifact number to start a new round; an unforced plan or implement dispatch shares the round its preceding research already opened.

## Arguments

- `$1` - Task number (required)
- Remaining args - Optional reason for revision

## Execution

### CHECKPOINT 1: GATE IN

```bash
source .claude/scripts/command-gate-in.sh "$task_number" "revise"
# Exports: SESSION_ID, TASK_TYPE, TASK_STATUS, PROJECT_NAME, DESCRIPTION, PADDED_NUM
# Displays: [REVISE] Task {N}: {project_name}
# The Phase-1 (gate-in refactor) operation-aware exemption means "revise" is never rejected on
# terminal-status tasks, preserving skill-reviser's documented "works regardless of task
# status" contract. No other ABORT conditions exist for /revise.
```

**Check Plan Existence** (revise-specific; no gate-script equivalent — determines routing):
```bash
plan_exists=$(ls "specs/${PADDED_NUM}_${PROJECT_NAME}/plans/"*.md 2>/dev/null | head -1)
```

- Plan file exists: Plan Revision path
- No plan file: Description Update path

**On GATE IN success**: Task validated. **IMMEDIATELY CONTINUE** to CHECKPOINT 2 below.

---

### CHECKPOINT 2: DELEGATE TO SKILL

Invoke `skill-reviser` with the validated task context. The skill delegates to `reviser-agent` which handles:

- **Plan Revision path**: Load current plan, discover new research, synthesize revised plan
- **Description Update path**: Update task description based on revision reason

Pass to skill-reviser:
- `task_number` - Validated task number
- `session_id` - `$SESSION_ID` from GATE IN
- `revision_reason` - Optional reason from remaining args
- `plan_exists` - Whether a plan file exists (boolean flag)

```
skill: "skill-reviser"
args: "task_number={N} session_id={SESSION_ID} revision_reason={reason} plan_exists={true|false}"
```

The skill spawns the reviser-agent and returns a brief text summary. Status update (state.json),
artifact linking, and git commit for the Plan Revision path are handled by CHECKPOINT 3 below via
`command-gate-out.sh`; the Description Update path intentionally skips that correction (see
CHECKPOINT 3).

**On DELEGATE success**: Revision complete. **IMMEDIATELY CONTINUE** to CHECKPOINT 3 below.

---

### CHECKPOINT 3: GATE OUT

```bash
bash .claude/scripts/command-gate-out.sh "$task_number" "revise" "$SESSION_ID"
# Reads .return-meta.json; applies defensive status correction if needed
# status_token mapping (Phase 1 of the gate-in refactor): operation "revise" -> target_status "plan"
# Runs validate-artifact.sh --fix (non-blocking)
# Defensive correction (state.json + TODO.md) handled by this script
```

**Description-update path skips the correction automatically**: `skill-reviser` reports
`status="description_updated"` for that path, which falls outside `command-gate-out.sh`'s
`implemented|researched|planned` gate, so no defensive correction fires — this is intentional
(there is no "planned" state to defend when only the description changed).

The following step is revise-specific (not handled by `command-gate-out.sh`):

**Verify Artifacts (Plan Revision only)**: If `plan_exists` was true (plan revision path), check
the revised plan file exists on disk:
```bash
revised_plan=$(ls -1t "specs/${PADDED_NUM}_${PROJECT_NAME}/plans/"*.md 2>/dev/null | head -1)
if [ -z "$revised_plan" ]; then
    echo "WARNING: No plan file found after revision."
fi
```

**Cleanup**: `/revise` has no CHECKPOINT 3 commit block of its own (`skill-reviser` commits
inline), so this is the command's own last step and owns `.return-meta.json`'s deletion --
skill_cleanup does not delete it at the skill's own Stage 9:
```bash
rm -f "specs/${PADDED_NUM}_${PROJECT_NAME}/.return-meta.json"
```

**On GATE OUT success**: Revision verified.

---

## Output

**Plan Revision:**
```
Plan revised for Task #{N}

Previous: MM_{short-slug}.md
New: MM_{short-slug}.md

Preserved phases: {N}
Revised phases: {range}

Status: [PLANNED]
Next: /orchestrate {N}
```

**Description Update:**
```
Description updated for Task #{N}

Previous: {old_description}
New: {new_description}

Status: [{current_status}]
```

## Error Handling

### GATE IN Failure
- Task not found: Return error with guidance
- Locked by another session: `command-gate-in.sh` propagates `task-lock.sh acquire`'s refusal
  (a fresh lock held by a genuinely different session) — ABORT with the lock's held-by/reason
  message; re-run once the other session's operation completes or its lock goes stale
- Cross-task `file_scope` overlap (the cross-task file_scope overlap check): if another currently-locked task's `file_scope`
  overlaps this task's and that lock is fresh, `/revise` ABORTs before DELEGATE, naming the
  conflicting task number — this is a new failure mode `/revise` did not have before this
  gate-in refactor; re-run once the other task's lock releases or goes stale
- Note: unlike a research/plan/implement dispatch, `/revise` has no terminal-status ABORT — the
  Phase-1 gate-in exemption preserves the pre-existing "works regardless of task status"
  contract; only the two lock-refusal modes above can block `/revise` at GATE IN

### DELEGATE Failure
- skill-reviser handles all error cases internally
- Missing plan for revision: Agent falls back to description update
- Write failure: Agent logs error, preserves original
- Git commit failure: Non-blocking (logged by skill)

### GATE OUT Failure
- Missing artifacts: Log warning, continue with available
- Status mismatch: Apply defensive correction via `command-gate-out.sh` (status_token `plan`)
