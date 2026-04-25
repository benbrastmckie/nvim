# Implementation Plan: Simplify Status Transitions

- **Task**: 494 - simplify_status_transitions
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/494_simplify_status_transitions/reports/01_simplify-status-transitions.md
- **Artifacts**: plans/01_simplify-status-transitions.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Replace the forward-only status transition model with a permissive one across 14 unique files (plus 12 extension copies). The new rule: any workflow command can run from any non-terminal status; only COMPLETED, ABANDONED, and EXPANDED block transitions. All changes are markdown text edits -- no scripts or code changes required. The `/plan` command and `skill-planner` already follow the permissive model and serve as the template.

### Research Integration

Research report `01_simplify-status-transitions.md` provides a complete inventory of 26 file edits across 7 categories. Key findings:
- No programmatic enforcement exists; all enforcement is via Claude-facing markdown instructions
- `update-task-status.sh` is already transition-agnostic (no changes needed)
- `/plan` and `skill-planner` already use the permissive model (template to follow)
- Extension copies under `.claude/extensions/core/` must mirror parent files exactly

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Replace all per-status allow-lists with terminal-state-only blocking
- Remove "Cannot skip phases" and "Cannot regress" rules
- Ensure consistent terminal-state set (COMPLETED, ABANDONED, EXPANDED) across all files
- Update transition diagrams to reflect the hub pattern
- Keep extension copies in lockstep with parent files

**Non-Goals**:
- Adding programmatic enforcement in scripts (stays markdown-only)
- Changing the status markers themselves or their semantics
- Modifying `update-task-status.sh` (already correct)
- Changing `/plan` or `skill-planner` beyond adding `expanded` to terminal checks

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Extension copies drift from parents | M | L | Phase 4 does a diff check after all edits |
| Removing guards allows illogical sequences | L | L | /implement already checks for plan file existence (artifact check, not status check) |
| Missing a file with transition enforcement | M | L | Research used exhaustive grep; plan includes verification phase |
| CLAUDE.md transition docs become stale | M | M | Phase 3 updates CLAUDE.md status section |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Core Enforcement Files (Priority 1) [COMPLETED]

**Goal**: Update the 7 primary enforcement files that actively restrict transitions, replacing per-status allow-lists with terminal-state-only blocking.

**Tasks**:
- [ ] `.claude/skills/skill-orchestrator/SKILL.md` (lines 52-59): Replace "Allowed Statuses" table with single rule: "All operations allowed unless status is completed, abandoned, or expanded"
- [ ] `.claude/context/checkpoints/checkpoint-gate-in.md` (lines 33-39): Replace transition table with terminal-state check
- [ ] `.claude/commands/research.md` (lines 140-145, 258): Replace allow-list in both single-task and multi-task sections with terminal-state check (block completed/abandoned/expanded, allow everything else)
- [ ] `.claude/commands/implement.md` (lines 138-158, 292): Replace allow-list with terminal-state check; preserve `--force` flag behavior for completed tasks; remove `*` catch-all
- [ ] `.claude/rules/state-management.md` (lines 25-39): Remove "Cannot skip phases" and "Cannot regress" rules; replace with terminal-state-only rules
- [ ] `.claude/context/orchestration/state-management.md` (lines 285-311): Rewrite transition matrix to permissive model; remove "Invalid Transitions" section
- [ ] `.claude/context/standards/status-markers.md` (lines 30-179, 231-258, 325-342): Simplify per-status "Valid Transitions" to reference permissive rule; replace pipeline diagram with hub diagram; simplify Validation Rules

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-orchestrator/SKILL.md` - Replace allowed-statuses table
- `.claude/context/checkpoints/checkpoint-gate-in.md` - Replace transition table
- `.claude/commands/research.md` - Replace allow-lists (2 locations)
- `.claude/commands/implement.md` - Replace allow-lists (2 locations), keep --force
- `.claude/rules/state-management.md` - Remove skip/regress rules
- `.claude/context/orchestration/state-management.md` - Rewrite transition matrix
- `.claude/context/standards/status-markers.md` - Simplify transitions and diagram

**Verification**:
- Each file contains only terminal-state blocking (no enumerated allow-lists)
- `--force` flag behavior preserved in implement.md
- No references to "Cannot skip" or "Cannot regress" remain

---

### Phase 2: Near-Consistent and Minor Files (Priority 2-3) [COMPLETED]

**Goal**: Update the 7 remaining files that are already close to the permissive model or need only minor changes.

**Tasks**:
- [ ] `.claude/commands/plan.md` (lines 135-136, 255-257): Add `expanded` to terminal state check (already blocks completed/abandoned)
- [ ] `.claude/skills/skill-planner/SKILL.md` (lines 64-67): Add `expanded` to terminal state check
- [ ] `.claude/skills/skill-implementer/SKILL.md` (lines 59-62): Add `abandoned` and `expanded` to terminal state check (currently only blocks completed)
- [ ] `.claude/skills/skill-spawn/SKILL.md` (line 25): Replace allow-list with terminal-state check
- [ ] `.claude/context/workflows/status-transitions.md` (lines 35-48): Update deprecated diagram to show permissive model
- [ ] `.claude/extensions/epidemiology/commands/epi.md` (line 355): Update comment to reflect permissive model
- [ ] `.claude/extensions/present/skills/skill-funds/SKILL.md` (lines 103-106): Add `abandoned` and `expanded` to terminal state check

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/commands/plan.md` - Add expanded to terminal check
- `.claude/skills/skill-planner/SKILL.md` - Add expanded to terminal check
- `.claude/skills/skill-implementer/SKILL.md` - Add abandoned/expanded
- `.claude/skills/skill-spawn/SKILL.md` - Replace allow-list
- `.claude/context/workflows/status-transitions.md` - Update deprecated diagram
- `.claude/extensions/epidemiology/commands/epi.md` - Update comment
- `.claude/extensions/present/skills/skill-funds/SKILL.md` - Add abandoned/expanded

**Verification**:
- All files use consistent terminal-state set: completed, abandoned, expanded
- No per-status allow-lists remain in any file

---

### Phase 3: CLAUDE.md and Documentation Updates [COMPLETED]

**Goal**: Update the root CLAUDE.md status documentation to reflect the permissive model, ensuring user-facing docs match the new behavior.

**Tasks**:
- [ ] `.claude/CLAUDE.md` Status Markers section: Update to note that transitions are permissive (any non-terminal status allows any command)
- [ ] `.claude/CLAUDE.md` Status Transitions subsection in state-management rules reference: Remove or update "Cannot skip/Cannot regress" references if present
- [ ] `.claude/docs/architecture/system-overview.md` (line 143): Update "status allows research" to "status is not terminal"
- [ ] Review `.claude/context/orchestration/preflight-pattern.md` and `.claude/context/workflows/preflight-postflight.md` for any transition model references; update if needed

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/CLAUDE.md` - Update status transition documentation
- `.claude/docs/architecture/system-overview.md` - Update validation description
- `.claude/context/orchestration/preflight-pattern.md` - Update if references specific transitions
- `.claude/context/workflows/preflight-postflight.md` - Update if references specific transitions

**Verification**:
- No documentation references the old forward-only model
- Status section clearly states the permissive rule

---

### Phase 4: Extension Core Copies and Verification [NOT STARTED]

**Goal**: Sync all `.claude/extensions/core/` copies to match their parent files and verify consistency across the entire changeset.

**Tasks**:
- [ ] Copy updated content to each of the 12 extension core mirrors:
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
- [ ] Run diff between each parent file and its extension copy to confirm they are identical
- [ ] Grep across all `.claude/` files for residual per-status allow-lists: `"not_started.*researched.*planned"`, `"Cannot skip"`, `"Cannot regress"`, `"forward.only"`
- [ ] Verify `update-task-status.sh` was NOT modified

**Timing**: 30 minutes

**Depends on**: 2, 3

**Files to modify**:
- 12 extension core copies (listed above) - mirror parent file changes

**Verification**:
- `diff` between each parent and extension copy returns empty (identical)
- Grep for old transition patterns returns zero matches
- `update-task-status.sh` unchanged (git diff shows no changes)

## Testing & Validation

- [ ] Grep for "Cannot skip" and "Cannot regress" across all `.claude/` files -- expect zero matches
- [ ] Grep for "Allowed Statuses" table format in orchestrator -- expect zero matches
- [ ] Verify each parent file matches its extension/core copy via diff
- [ ] Confirm `update-task-status.sh` has no changes (git diff)
- [ ] Spot-check: `/plan` command GATE IN still blocks completed/abandoned/expanded
- [ ] Spot-check: `/implement` command preserves `--force` override for completed tasks
- [ ] Spot-check: `/research` command blocks completed/abandoned/expanded only

## Artifacts & Outputs

- `specs/494_simplify_status_transitions/plans/01_simplify-status-transitions.md` (this plan)
- `specs/494_simplify_status_transitions/summaries/01_simplify-status-transitions-summary.md` (after implementation)
- 26 modified files across `.claude/` and `.claude/extensions/`

## Rollback/Contingency

All changes are markdown text edits tracked by git. Rollback is a single `git revert` of the implementation commit(s). No scripts, databases, or external state are affected. If partial rollback is needed, individual files can be restored from git history since changes are independent across files.
