# Research Report: Task #494

**Task**: 494 - simplify_status_transitions
**Started**: 2026-04-25T00:00:00Z
**Completed**: 2026-04-25T00:30:00Z
**Effort**: Medium (research-only, ~20 files to audit)
**Dependencies**: None
**Sources/Inputs**:
- Codebase exploration: .claude/ directory (commands, skills, context, rules, extensions)
- Script analysis: update-task-status.sh
**Artifacts**: - specs/494_simplify_status_transitions/reports/01_simplify-status-transitions.md
**Standards**: report-format.md, status-markers.md

## Executive Summary

- Status transition enforcement is scattered across **15 unique files** (plus identical extension/core copies) in documentation, commands, skills, and context files
- No programmatic enforcement exists -- the `update-task-status.sh` script does NOT validate transitions; all enforcement is via Claude-facing markdown instructions
- The primary enforcement sites are: (1) the orchestrator skill's "Allowed Statuses" table, (2) the checkpoint-gate-in.md transition table, (3) two context files with "Valid Transitions" matrices, (4) the rules/state-management.md "Cannot skip/regress" rules, and (5) per-command GATE IN validation in each command file
- The /plan command and skill-planner already use the simplified model (block only terminal states); /research and /implement still use restrictive per-status allow-lists
- The simplification requires consistent changes: replace all per-status allow-lists with a single terminal-state check (`completed`, `abandoned`, `expanded`)

## Context & Scope

The goal is to replace the current forward-only status transition model with a permissive one: any workflow command (`/research`, `/plan`, `/revise`, `/implement`) can run from any non-terminal status. Only terminal states (`[COMPLETED]`, `[ABANDONED]`, `[EXPANDED]`) block transitions.

This research systematically identifies every file that enforces or documents the current restrictive model.

## Findings

### Category 1: Files with Restrictive Per-Status Allow-Lists (MUST CHANGE)

These files actively restrict which commands can run from which statuses. They are the primary enforcement mechanism.

#### 1.1 `.claude/skills/skill-orchestrator/SKILL.md` (lines 52-59)

The orchestrator skill defines a strict "Allowed Statuses" table:

```
| Operation | Allowed Statuses |
|-----------|------------------|
| research | not_started, planned, partial, blocked |
| plan | not_started, researched, partial |
| implement | planned, implementing, partial, researched |
| revise | planned, implementing, partial, blocked |
```

**Change needed**: Replace this table with a single rule: "All operations are allowed unless status is `completed`, `abandoned`, or `expanded`."

**Extension copy**: `.claude/extensions/core/skills/skill-orchestrator/SKILL.md` (identical, lines 52-59) -- must be changed in sync.

---

#### 1.2 `.claude/context/checkpoints/checkpoint-gate-in.md` (lines 33-39)

Contains a restrictive transition table:

```
| Current Status | Allowed Transitions |
|----------------|---------------------|
| not_started | researching, planning, implementing |
| researched | planning, implementing |
| planned | implementing |
| implementing | implementing (resume) |
| partial | implementing (resume) |
```

**Change needed**: Replace table with: "Any non-terminal status allows any in-progress transition (researching, planning, implementing)."

**Extension copy**: `.claude/extensions/core/context/checkpoints/checkpoint-gate-in.md` (identical) -- must be changed in sync.

---

#### 1.3 `.claude/commands/research.md`

**Single-task mode** (line 258): Status validation in CHECKPOINT 1: GATE IN:
```
Status allows research: not_started, planned, partial, blocked, researched
```

**Multi-task mode** (lines 140-145): Bash case statement in MULTI-TASK DISPATCH:
```bash
case "$status" in
  not_started|researched|planned|partial|blocked) validated_tasks+=("$task_num") ;;
  *) skipped_tasks+=("$task_num: invalid status [$status]") ;;
esac
```

**Change needed**: Replace both with terminal-state check only (block completed/abandoned/expanded, allow everything else).

**Extension copy**: `.claude/extensions/core/commands/research.md` (identical) -- must be changed in sync.

---

#### 1.4 `.claude/commands/implement.md`

**Single-task mode** (line 292): GATE IN validation:
```
Status allows implementation: planned, implementing, partial, researched, not_started
```

**Multi-task mode** (lines 138-158): Bash case statement:
```bash
case "$status" in
  planned|implementing|partial|researched|not_started) ;;
  completed) [--force handling] ;;
  abandoned) skipped ;;
  *) skipped_tasks+=("$task_num: invalid status [$status]") ;;
esac
```

**Change needed**: Replace the enumerated allow-list with terminal-state blocking. Keep `--force` behavior for completed tasks. Remove the `*` catch-all that rejects unknown statuses.

**Extension copy**: `.claude/extensions/core/commands/implement.md` (identical) -- must be changed in sync.

---

#### 1.5 `.claude/skills/skill-spawn/SKILL.md` (line 25)

```
Task status allows spawn (implementing, partial, blocked, planned, researched)
```

**Change needed**: Replace with terminal-state check.

**Extension copy**: `.claude/extensions/core/skills/skill-spawn/SKILL.md` (identical) -- must be changed in sync.

---

### Category 2: Files with "Valid Transitions" Matrices (MUST CHANGE)

These files define the full transition graph. They need to be rewritten to reflect the permissive model.

#### 2.1 `.claude/context/orchestration/state-management.md` (lines 285-298, 306-311)

Contains the most detailed transition matrix:

```
[NOT STARTED] -> [RESEARCHING] | [PLANNING] | [IMPLEMENTING] | [BLOCKED] | [EXPANDED]
[RESEARCHING] -> [RESEARCHED] | [BLOCKED] | [ABANDONED]
[RESEARCHED] -> [PLANNING] | [IMPLEMENTING] | [BLOCKED] | [EXPANDED]
[PLANNING] -> [PLANNED] | [BLOCKED] | [ABANDONED]
...
```

And "Invalid Transitions" (lines 306-311):
```
- [NOT STARTED] -> [COMPLETED] (must go through work phases)
- [NOT STARTED] -> [ABANDONED] (cannot abandon work never started)
- [ABANDONED] -> [COMPLETED] (abandoned work not complete)
```

**Change needed**: Replace the matrix with: "From any non-terminal status, the system can transition to any command's in-progress status (researching, planning, revising, implementing) or to blocked/abandoned/expanded. Terminal states (completed, abandoned, expanded) block all outgoing transitions."

**Extension copy**: `.claude/extensions/core/context/orchestration/state-management.md` (identical) -- must be changed in sync.

---

#### 2.2 `.claude/context/standards/status-markers.md` (lines 30-179, 325-342)

Each status marker has a "Valid Transitions" list. For example:

```
[NOT STARTED]:
- -> [RESEARCHING] (research begins)
- -> [PLANNING] (planning begins, skip research)
- -> [IMPLEMENTING] (implementation begins, skip research and planning)
- -> [BLOCKED] (blocked before starting)
```

And the "Validation Rules" section (lines 325-342) duplicates the full matrix.

**Change needed**: Replace per-status "Valid Transitions" lists with the new permissive rule. Simplify the Validation Rules section.

**Extension copy**: `.claude/extensions/core/context/standards/status-markers.md` (identical) -- must be changed in sync.

---

#### 2.3 `.claude/rules/state-management.md` (lines 25-39)

Contains the "Cannot skip / Cannot regress" rules:

```
[NOT STARTED] -> [RESEARCHING] -> [RESEARCHED]
[RESEARCHED] -> [PLANNING] -> [PLANNED]
[PLANNED] -> [IMPLEMENTING] -> [COMPLETED]

Invalid Transitions:
- Cannot skip phases (e.g., NOT STARTED -> PLANNED)
- Cannot regress (e.g., PLANNED -> RESEARCHED) except for revisions
- Cannot mark COMPLETED without all phases done
```

**Change needed**: Remove "Cannot skip phases" and "Cannot regress" rules entirely. Keep only the terminal-state rules.

**Extension copy**: `.claude/extensions/core/rules/state-management.md` (identical) -- must be changed in sync.

---

#### 2.4 `.claude/context/workflows/status-transitions.md` (lines 35-48)

Although marked as DEPRECATED, this file still contains the linear transition diagram:

```
[NOT STARTED] -> [RESEARCHING] -> [RESEARCHED] -> [PLANNING] -> [PLANNED] -> [IMPLEMENTING] -> [COMPLETED]
```

**Change needed**: Update or simply leave the deprecation notice. Since it's deprecated, updating is low priority but keeping it consistent prevents confusion.

**Extension copy**: `.claude/extensions/core/context/workflows/status-transitions.md` (identical) -- must be changed in sync.

---

### Category 3: Command GATE IN Validation (ALREADY PERMISSIVE or NEEDS MINOR CHANGE)

#### 3.1 `.claude/commands/plan.md`

**Single-task mode** (lines 254-258): GATE IN validation already uses the permissive model:
```
- If completed or abandoned: ABORT "Task is in terminal state"
- All other states: proceed
```

**Multi-task mode** (lines 134-138): Also already permissive:
```bash
# /plan accepts any non-terminal status
if [ "$status" = "completed" ] || [ "$status" = "abandoned" ]; then
  invalid_tasks+=("$task_num: terminal status [$status]")
```

**Change needed**: Add `expanded` to the terminal state check (currently only blocks completed/abandoned). Otherwise already correct -- this is the model we want all commands to follow.

**Extension copy**: `.claude/extensions/core/commands/plan.md` (identical) -- must be changed in sync.

---

#### 3.2 `.claude/skills/skill-planner/SKILL.md` (lines 64-67)

Already uses the permissive model:
```bash
# Validate status (only block terminal states)
if [ "$status" = "completed" ] || [ "$status" = "abandoned" ]; then
  return error "Task is in terminal state [$status]"
fi
```

**Change needed**: Add `expanded` to the terminal state check. Otherwise already correct.

**Extension copy**: `.claude/extensions/core/skills/skill-planner/SKILL.md` (identical) -- must be changed in sync.

---

#### 3.3 `.claude/skills/skill-implementer/SKILL.md` (lines 59-62)

Nearly permissive, only blocks "completed":
```bash
if [ "$status" = "completed" ]; then
  return error "Task already completed"
fi
```

**Change needed**: Add `abandoned` and `expanded` to make consistent with full terminal-state set.

**Extension copy**: `.claude/extensions/core/skills/skill-implementer/SKILL.md` (identical) -- must be changed in sync.

---

#### 3.4 `.claude/skills/skill-reviser/SKILL.md` (line 59)

Explicitly states no status-based abort:
```
**No status-based ABORT rules.** The skill works regardless of task status.
```

**Change needed**: Consider adding terminal-state blocking for consistency, or leave as-is since revise is a lightweight operation.

---

#### 3.5 `.claude/skills/skill-researcher/SKILL.md`

No explicit status validation in the skill (validation is done by the command and orchestrator). The skill just validates the task exists.

**Change needed**: None (status validation handled upstream).

---

### Category 4: Extension-Specific Files

#### 4.1 `.claude/extensions/epidemiology/commands/epi.md` (line 355)

```
# Validate status allows research (not_started or researched for re-research)
```

**Change needed**: Update comment to reflect permissive model.

---

#### 4.2 `.claude/extensions/present/skills/skill-funds/SKILL.md` (lines 103-106)

```bash
# Validate status allows research
if [ "$status" = "completed" ]; then
  return error "Task already completed"
fi
```

**Change needed**: Add `abandoned` and `expanded` to terminal-state check.

---

### Category 5: Documentation-Only Files (SHOULD UPDATE for consistency)

#### 5.1 `.claude/context/orchestration/preflight-pattern.md`

Describes the preflight process but does not enforce specific transitions. References status-sync-manager for validation.

**Change needed**: Minor text update if it references specific allowed transitions.

---

#### 5.2 `.claude/context/workflows/preflight-postflight.md`

Documents the preflight/postflight lifecycle.

**Change needed**: Update any references to the transition model.

---

#### 5.3 `.claude/docs/architecture/system-overview.md` (line 143)

```
Validate: task exists, status allows research
```

**Change needed**: Update to "status is not terminal" if the full transition validation reference is updated.

---

#### 5.4 `.claude/docs/templates/command-template.md` (line 33), `.claude/docs/guides/creating-skills.md` (line 36), `.claude/docs/guides/creating-commands.md` (line 72)

All contain variations of "validate task exists and status allows operation."

**Change needed**: None (the phrasing is general enough to remain correct).

---

### Category 6: Script (NO CHANGE NEEDED)

#### 6.1 `.claude/scripts/update-task-status.sh`

This script does NOT validate transitions. It performs:
- Argument validation (operation, task_number, target_status, session_id)
- Idempotency check (already at target status -> no-op)
- Atomic updates to state.json, TODO.md, and plan files

**Change needed**: None. The script is already transition-agnostic.

**Extension copy**: `.claude/extensions/core/scripts/update-task-status.sh` (identical) -- no change needed.

---

### Category 7: Transition Diagram in status-markers.md

#### 7.1 `.claude/context/standards/status-markers.md` (lines 231-258)

The ASCII art transition diagram shows the linear pipeline:

```
[NOT STARTED] -> [RESEARCHING] -> [RESEARCHED] -> [PLANNED] -> [IMPLEMENTING] -> [COMPLETED]
```

**Change needed**: Replace with a simpler diagram showing that any non-terminal status can reach any in-progress status. The new diagram would show a "hub" pattern rather than a pipeline.

---

## Decisions

1. The new rule is: any command can run from any non-terminal status. Terminal states are: COMPLETED, ABANDONED, EXPANDED.
2. The `--force` flag on /implement should continue to override the COMPLETED block.
3. The update-task-status.sh script requires no changes.
4. Extension copies (.claude/extensions/core/) must be updated in lockstep with the primary files.

## Recommendations

### Priority 1 (Must Change -- Active Enforcement)

| # | File | Lines | Nature of Change |
|---|------|-------|------------------|
| 1 | `.claude/skills/skill-orchestrator/SKILL.md` | 52-59 | Replace "Allowed Statuses" table with terminal-state-only blocking |
| 2 | `.claude/context/checkpoints/checkpoint-gate-in.md` | 33-39 | Replace transition table with terminal-state check |
| 3 | `.claude/commands/research.md` | 140-145, 258 | Replace allow-list with terminal-state check |
| 4 | `.claude/commands/implement.md` | 138-158, 292 | Replace allow-list with terminal-state check |
| 5 | `.claude/rules/state-management.md` | 25-39 | Remove "Cannot skip/regress" rules |
| 6 | `.claude/context/orchestration/state-management.md` | 285-311 | Rewrite transition matrix and invalid transitions |
| 7 | `.claude/context/standards/status-markers.md` | 30-179, 231-258, 325-342 | Simplify per-status transitions and diagram |

### Priority 2 (Should Change -- Near-Consistent Already)

| # | File | Lines | Nature of Change |
|---|------|-------|------------------|
| 8 | `.claude/commands/plan.md` | 135-136, 255-257 | Add `expanded` to terminal check |
| 9 | `.claude/skills/skill-planner/SKILL.md` | 64-67 | Add `expanded` to terminal check |
| 10 | `.claude/skills/skill-implementer/SKILL.md` | 59-62 | Add `abandoned`/`expanded` to terminal check |
| 11 | `.claude/skills/skill-spawn/SKILL.md` | 25 | Replace allow-list with terminal-state check |

### Priority 3 (Minor Updates)

| # | File | Lines | Nature of Change |
|---|------|-------|------------------|
| 12 | `.claude/context/workflows/status-transitions.md` | 35-48 | Update deprecated diagram for consistency |
| 13 | `.claude/extensions/epidemiology/commands/epi.md` | 355 | Update comment |
| 14 | `.claude/extensions/present/skills/skill-funds/SKILL.md` | 103-106 | Add `abandoned`/`expanded` |

### Extension Copies (Must Mirror)

Every file in Priority 1-3 that exists under `.claude/extensions/core/` must be updated identically. The affected extension paths are:

- `.claude/extensions/core/skills/skill-orchestrator/SKILL.md`
- `.claude/extensions/core/context/checkpoints/checkpoint-gate-in.md`
- `.claude/extensions/core/commands/research.md`
- `.claude/extensions/core/commands/implement.md`
- `.claude/extensions/core/rules/state-management.md`
- `.claude/extensions/core/context/orchestration/state-management.md`
- `.claude/extensions/core/context/standards/status-markers.md`
- `.claude/extensions/core/commands/plan.md`
- `.claude/extensions/core/skills/skill-planner/SKILL.md`
- `.claude/extensions/core/skills/skill-implementer/SKILL.md`
- `.claude/extensions/core/skills/skill-spawn/SKILL.md`
- `.claude/extensions/core/context/workflows/status-transitions.md`

## Risks & Mitigations

- **Risk**: Removing transition guards could allow illogical sequences (e.g., implementing without a plan).
  - **Mitigation**: The /implement command already checks for plan file existence (line 299: "No implementation plan found. Run /plan {N} first."). This is an artifact check, not a status check, and remains in place.

- **Risk**: Extension copies drift out of sync.
  - **Mitigation**: All extension/core copies are currently identical to their parent files. The implementation plan should use a script or loop to apply the same changes to both locations.

- **Risk**: Some commands may have undocumented status checks in comments or implicit behavior.
  - **Mitigation**: This research used exhaustive grep patterns across all .claude/ files. The inventory is comprehensive.

## Appendix

### Search Queries Used

1. `transition|allowed.*status|valid.*status|status.*gate|cannot.*regress|forward.only|backward|regress` (236 file matches, narrowed to 15 unique enforcement sites)
2. `Allowed Statuses|allowed.*status.*for|Status allows|status allows|invalid status|terminal.*status` (50 content matches)
3. `Cannot skip|Cannot regress|skip phases|forward-only` (4 relevant matches in rules/state-management.md and its copy)
4. `status allows|terminal.*state|completed.*abandoned` (30 content matches across extensions)
5. `diff` comparisons between .claude/ files and .claude/extensions/core/ copies (all identical)

### File Count Summary

| Category | Files | Extension Copies | Total Edits |
|----------|-------|------------------|-------------|
| Must Change (enforcement) | 7 | 7 | 14 |
| Should Change (consistency) | 4 | 4 | 8 |
| Minor Updates | 3 | 1 | 4 |
| **Total** | **14** | **12** | **26** |
