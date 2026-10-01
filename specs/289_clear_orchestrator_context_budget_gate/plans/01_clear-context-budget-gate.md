# Implementation Plan: Task #289

- **Task**: 289 - Clear orchestrator context budget gate
- **Status**: [IMPLEMENTING]
- **Effort**: 3.75 hours
- **Dependencies**: None (the sibling task that last edited `commands/orchestrate.md` has landed)
- **Research Inputs**: specs/289_clear_orchestrator_context_budget_gate/reports/01_context-budget-gate-trim.md
- **Artifacts**: plans/01_clear-context-budget-gate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Clear all three of verify-deploy Gate 20's open findings in one coordinated change, by removing
duplicated prose from the three largest eager-loaded sources rather than by moving the recorded
`baseline_bytes` ceiling. Phase 2–4 trim content until the eager-load total and
`skills/skill-orchestrate/SKILL.md` are both genuinely under their recorded limits with headroom;
Phase 5 then promotes `ORCHESTRATOR_BUDGET_GATE_MODE` from `warn` to `hard` and records the
deliberate trim in the config's own derivation narrative; Phase 6 verifies the gate and its test
suite end to end.

### Research Integration

The report's live re-measurement supersedes the task description's snapshot: the eager-load
overage is **2,339 B** (68,289 B measured against `baseline_bytes: 65,950`), not 2,030 B, and the
overage has drifted upward twice during this cycle. Confirmed independently at planning time
(`measure-eager-context.sh --check` → `TOTAL: 68289 B`; `wc -c` → SKILL.md 20,325 B). The report
identified the concrete trim targets each phase below acts on, verified the hard-mode precondition
is now satisfied, and established that `docs/architecture/orchestrate-state-machine.md` and
`context/standards/git-workflow-narrative.md` already own the detail being pointer-ized (so no new
documents are needed). Its central decision — trim content, never silently re-derive
`baseline_bytes` — is carried through unchanged, and is also what the user's focus asks for.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch, so no roadmap review/update phases are included.
`specs/ROADMAP.md`'s "Budgets" table does carry a now-stale snapshot of these same two figures;
refreshing it is an optional, explicitly-marked task in Phase 6, not a requirement for clearing
the gate.

### User Focus Integration

The user asked to cut verbosity out of the agent-system files while retaining and improving
functionality. That is exactly this task's mechanism, so the plan takes the *generous* trim rather
than the minimum one: every cut below is duplication removal or extraction behind a pointer into a
file that already owns the detail (no information loss), and the targets are headroom figures
below the limits, not the limits themselves. Phase 3 is included for this reason even though
Phase 2 alone is sized to close the gate.

## Goals & Non-Goals

**Goals**:
- Eager-load total measures at or under 65,950 B, with a target of ≤ 64,500 B for durable headroom
- `skills/skill-orchestrate/SKILL.md` measures under 20,000 B, with a target of ≤ 19,700 B
- `ORCHESTRATOR_BUDGET_GATE_MODE` defaults to `hard`, with the stale deferral narrative replaced by
  a dated record of the re-checked precondition
- Gate 20's three sub-checks all report `[PASS]`, and the two currently-red cases in
  `test-verify-deploy-context-budget.sh` clear
- Every byte removed is a duplicate or is relocated into a file that already owns that detail

**Non-Goals**:
- Moving `eager_load.baseline_bytes` or either file's `ceiling_bytes` (explicitly rejected)
- Trimming `commands/orchestrate.md` (under ceiling with 772 B headroom; not an open finding)
- Relocating SKILL.md or `commands/orchestrate.md` executable bash blocks (a code change)
- Trimming any non-core extension's CLAUDE.md fragment (core's own fragment suffices)
- Creating a new `context/patterns/eager-context-trim-candidates.md` catalogue (report's own
  "not required for this task to close" follow-up suggestion)

## Constraints

- **Source store, never `.claude/`**: every edit below targets `agent-system/extensions/core/**`.
  `.claude/**` is a regenerated deploy artifact (`rules/source-store-deploy-boundary.md`).
- **No task-number references in the edited files**: `agent-system/**` is outside `specs/**`, so
  the config `derivation`/`note` narratives and the `verify-deploy.sh` comment MUST describe the
  landed sibling change by a durable anchor (e.g. "the `[HOLD]` status-marker change", a commit
  SHA, or "the task that last edited `commands/orchestrate.md`"), never as "task 293". The
  config's existing narratives already follow this convention ("the per-dispatch
  worktree-isolation removal task") — match it.
- **Measure, never estimate**: every byte figure asserted in this plan is a hypothesis. Each phase
  re-measures with the named command and reports the actual number.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Eager total drifts up again from unrelated in-flight tasks before this lands | H | M | Target ≤ 64,500 B (≈1,450 B headroom), not the bare 65,950 B limit; re-measure in Phase 6 immediately before closing |
| A trim silently drops a load-bearing MUST/MUST NOT from SKILL.md | H | M | Only the two report-verified true duplicates are touched; Phase 4 forbids opportunistic further cuts without fresh duplicate evidence |
| Pointer-ized `/orchestrate` detail becomes unfindable for a reader who does not follow pointers | M | M | Target doc (`docs/architecture/orchestrate-state-machine.md`) already owns this content; keep a one-line behavioural summary inline, matching `rules/source-store-deploy-boundary.md`'s live precedent |
| Flipping to `hard` before SKILL.md is actually under ceiling converts a warn into a deploy-blocking failure | H | L | Phase 5 depends on Phases 2–4 and re-verifies both measurements before flipping |
| git-workflow.md trim deletes narrative instead of relocating it | M | M | Phase 3 requires the removed paragraphs be *added to* `git-workflow-narrative.md` in the same edit, verified by a byte-growth check on that file |
| Config `_comment` and `verify-deploy.sh` comment left contradicting each other | M | M | Phase 5 updates both in the same commit and greps for residual "deferred"/"concurrently being edited" language |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |
| 4 | 6 | 5 |

Phases within the same wave can execute in parallel. Phases 2, 3 and 4 touch three disjoint files
(`merge-sources/claudemd.md`, `rules/git-workflow.md` + its narrative sidecar,
`skills/skill-orchestrate/SKILL.md`) and may be dispatched concurrently under territory contracts.

---

### Phase 1: Widen file_scope and capture pre-trim baselines [COMPLETED]

**Goal**: Record the authoritative pre-trim measurements and declare the two files this task edits
that its current `file_scope` does not list, so no phase below touches an undeclared file.

**Tasks**:
- [x] Record pre-trim figures from `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`
      (the `TOTAL:` line and the per-file table) into the phase's progress notes *(completed: TOTAL 68,289 B, matches plan's drift-confirmed figure)*
- [x] Record `wc -c` for `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`,
      `merge-sources/claudemd.md`, `rules/git-workflow.md`, and
      `context/standards/git-workflow-narrative.md` *(completed: 20,325 / 19,793 / 9,740 / 7,769 B)*
- [x] Append `agent-system/extensions/core/merge-sources/claudemd.md` and
      `agent-system/extensions/core/context/standards/git-workflow-narrative.md` to task 289's
      `file_scope` in `specs/state.json` (append via `+=`, never a wholesale `.file_scope = [...]`
      assignment), then run `bash .claude/scripts/generate-todo.sh` *(completed: both paths already present in file_scope -- no append or regeneration needed)*
- [x] Confirm `jq` shows the widened `file_scope` and that no other `active_projects` entry was
      modified *(completed: jq confirms both paths present; 53 other active_projects entries untouched)*

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: the pre-trim figures are expected to be eager `TOTAL: 68,289 B` and SKILL.md
`20,325 B` (both confirmed live at planning time). If the measured values differ, use the measured
values everywhere below and note the drift — the later phases' targets are absolute limits, not
deltas from these numbers.

**Files to modify**:
- `specs/state.json` - widen task 289's `file_scope` by two entries
- `specs/TODO.md` - regenerated, not hand-edited

**Verification**:
- `jq '.active_projects[] | select(.project_number==289) | .file_scope' specs/state.json` lists
  both new paths alongside the original four
- `git diff --stat specs/state.json` shows a single-task change

---

### Phase 2: Trim the eager CLAUDE.md fragment behind pointers [COMPLETED]

**Goal**: Remove the duplicated `/orchestrate` prose from core's `.claude/CLAUDE.md` merge source
so the eager-load total drops at or under 65,950 B with headroom, without losing any documented
behaviour.

**Tasks**:
- [x] Trim the `/orchestrate` row of the Command Reference table (line ~116, ~1,670 B — the single
      largest cell in the file) to a short behavioural summary plus
      `See .claude/docs/architecture/orchestrate-state-machine.md for the full forced-phase,
      terminal-task-admission, artifact-keyed-admission and cycle-budget semantics` *(completed)*
- [x] Before removing each clause, confirm `docs/architecture/orchestrate-state-machine.md` already
      documents it; if any clause is NOT covered there, add it to that doc in this same phase
      rather than deleting it (that file is non-eager, so moving prose into it costs zero eager
      bytes) *(completed: artifact-keyed-admission clause was missing; added a new paragraph to the Forced Phases section)*
- [x] Trim the **Multi-task syntax** paragraph (line ~120, ~811 B) to one sentence plus its two
      existing pointers (`multi-task-operations.md`, `batch-orchestration-guardrails.md`) *(completed)*
- [x] Trim the **Model Enforcement** paragraph (line ~167, ~842 B) to the tier rule in one sentence
      plus its existing `agent-frontmatter-standard.md` pointer *(completed)*
- [x] Match the file's own established house style for this shape (its `## Hard Mode` and
      `## Literature Mode` sections: short summary + `See <path> for the full X`) *(completed)*
- [x] Re-measure the eager total and stop when it is ≤ 64,500 B; if the three cuts above land short
      of that, do NOT reach for a fourth target in this phase — record the measured value and let
      Phase 3's cut close the remainder *(completed: TOTAL 66,081 B, still 131 B over 65,950 B -- Phase 3 required)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the three named cells total ~3,323 B. Note that the `/orchestrate` row alone
(~1,670 B) does **not** cover the 2,339 B deficit — contrary to the research report's
recommendation 1, which overstates that single cut as sufficient. At least two of the three cuts
are therefore required to clear the gate from this phase alone, and all three are expected to be
needed to reach the headroom target. Confirm the per-cut savings with `wc -c` after each edit
rather than trusting these figures.

**Files to modify**:
- `agent-system/extensions/core/merge-sources/claudemd.md` - three pointer-izations
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - only if a removed
  clause is not already covered there (non-eager; additions here are free)

**Verification**:
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`
  reports `TOTAL:` ≤ 65,950 B (target ≤ 64,500 B) and `Volatile-file hits: 0`
- `wc -c agent-system/extensions/core/merge-sources/claudemd.md` is below 19,793 B, keeping the
  sibling `claudemd-size-budget.json` ceiling (19,950 B) satisfied with more margin than before
- Every behavioural clause removed is findable by `grep` in
  `docs/architecture/orchestrate-state-machine.md`

---

### Phase 3: Relocate git-workflow.md destructive-git narrative [COMPLETED]

**Goal**: Move the two operational-narrative paragraphs out of the second-largest eager rule into
the narrative sidecar that already owns that elaboration, adding eager headroom with no information
loss.

**Tasks**:
- [x] Compress the rollback-procedure walkthrough in "No Destructive Git on Uncommitted Work"
      (~964 B: the explicit-task-number rationale, the `file_scope` refusal story, and the
      `--allow-out-of-scope` override walkthrough) to a bare MUST + pointer to
      `context/standards/git-workflow-narrative.md` and `context/contracts/recovery.md`'s rollback
      rung *(completed)*
- [x] Compress the "never emit `git-snapshot.sh` in its default (reverting) form" paragraph
      (~430 B) to the bare MUST NOT plus its existing
      `context/patterns/checkpoint-before-overflow.md` pointer *(completed)*
- [x] **Add** both removed narratives to `context/standards/git-workflow-narrative.md`'s existing
      "No Destructive Git on Uncommitted Work — Snapshot Mode Detail" section (which today covers
      only the exemption's per-mode detail), so the detail is relocated, not deleted *(completed)*
- [x] Verify the rule still states every MUST/MUST NOT it stated before: the forbidden-command
      list, both exemptions, and the enforcement-hook attribution must all survive verbatim *(completed: combined grep count matches pre-trim exactly at 8)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: ~1,394 B expected to come out of `rules/git-workflow.md` (9,740 B → ~8,350 B).
Confirm with `wc -c` before and after; the figure matters only insofar as the Phase 6 total lands
under baseline.

**Files to modify**:
- `agent-system/extensions/core/rules/git-workflow.md` - two compressions
- `agent-system/extensions/core/context/standards/git-workflow-narrative.md` - receives the
  relocated narrative (non-eager; growth here is free)

**Verification**:
- `wc -c` shows `rules/git-workflow.md` smaller and `git-workflow-narrative.md` larger by a
  comparable amount (relocation, not deletion)
- `REPO_ROOT=$(pwd) bash .../measure-eager-context.sh --check` `TOTAL:` is lower than Phase 2's
  closing figure
- `grep -c 'MUST NOT\|Forbidden on a dirty tree\|guard-destructive-git.sh'` on the rule returns a
  count no lower than the pre-trim count

---

### Phase 4: Trim SKILL.md under its ceiling [COMPLETED]

**Goal**: Bring `skills/skill-orchestrate/SKILL.md` from 20,325 B to under its 20,000 B
ROADMAP-derived ceiling with margin, using only the two verified true duplicates.

**Tasks**:
- [x] Collapse the three Skill-to-Agent Mapping lifecycle-dispatch rows (lines ~317–319: Research /
      Plan / Implement dispatch, which differ only in the `$AGENT` variable and restate one
      identical resolution-and-context clause) into a single row naming all three agent variables
      once (~133 B) *(completed: saved 140 B)*
- [x] Collapse the duplicated `detected_defects`-never-prompts constraint: keep Move 4's full
      statement (line ~268) and reduce the "MUST NOT (Postflight Boundary)" restatement (lines
      ~310–311) to a short pointer back to it, preserving the distinct phase-order MUST NOT that
      precedes it untouched (~150–200 B) *(completed: saved 86 B)*
- [x] Re-measure; if still at or above 19,700 B, find additional savings **only** by producing
      fresh duplicate-detection evidence (two passages stating the same constraint in full) —
      never by compressing a uniquely-stated contract *(completed: landed at 20,099 B after the first two cuts; found one more genuine duplicate -- the Context References bullet self-admitted '(see above)' duplicating the opening paragraph's pointer to the same doc -- removed it, landing at 19,993 B, under the 20,000 B ceiling. Did not reach the 19,700 stretch target; no further genuine duplicate prose found)*
- [x] Confirm no MUST/MUST NOT clause count dropped and no inlined bash snippet was altered *(completed: MUST NOT 7->7, MUST 7->7; git diff touches zero lines inside any fenced bash block)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the two named trims total ~283–333 B against a 325 B deficit — i.e. they are
expected to land at roughly 19,992–20,042 B, which may **not** clear the ceiling and will almost
certainly not reach the 19,700 B headroom target. Measure after each cut; expect the third task
above (evidence-backed additional duplicate hunting) to be genuinely required, and treat
"two cuts were enough" as the surprise, not the default.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - two (or more) duplicate
  collapses

**Verification**:
- `wc -c agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` < 20,000 B (target
  ≤ 19,700 B)
- `grep -c 'MUST NOT'` and `grep -c 'MUST '` return counts no lower than pre-trim
- `git diff` shows no change inside any fenced bash block

---

### Phase 5: Promote the gate to hard and record the derivation [COMPLETED]

**Goal**: Flip `ORCHESTRATOR_BUDGET_GATE_MODE`'s default from `warn` to `hard` now that the
precondition is satisfied, and record in the config that both findings were closed by a deliberate
content trim rather than a baseline move.

**Tasks**:
- [x] Re-verify both gating measurements before editing anything: eager `TOTAL:` ≤ 65,950 B and
      SKILL.md < 20,000 B. If either is not satisfied, STOP and return to Phase 2/3/4 — do not
      flip the default *(completed: 65,402 B / 19,993 B, both satisfied)*
- [x] Re-confirm the promotion precondition holds (no in-flight task is editing
      `commands/orchestrate.md`; check `git log --oneline -5 -- agent-system/extensions/core/commands/orchestrate.md`
      and the `file_scope` of every non-terminal task in `specs/state.json`) *(completed: the sibling task -- the [HOLD] status-marker change -- is status=completed; no other task actively dispatched this session touches the file)*
- [x] Flip `ORCHESTRATOR_BUDGET_GATE_MODE="${ORCHESTRATOR_BUDGET_GATE_MODE:-warn}"` to `:-hard}` at
      `agent-system/extensions/core/scripts/verify-deploy.sh` (line ~190) *(completed)*
- [x] Rewrite the explanatory comment above it (lines ~179–189): drop the stale "concurrently being
      edited" / "promote once that concurrent edit settles" deferral, and record the dated
      re-checked precondition using a durable anchor (commit SHA or change description), **not** a
      task number *(completed: used 'the `[HOLD]` status-marker change')*
- [x] Mirror the same change in `context/config/orchestrator-context-budget.json`'s top-level
      `_comment`, removing the matching deferred-promotion language so the two cannot contradict *(completed)*
- [x] Refresh the informational snapshots only — `files."skills/skill-orchestrate/SKILL.md"
      .measured_bytes/.measured_at` and `eager_load.measured_bytes/.measured_at` — to the true
      post-trim values *(completed: 19,993 B / 65,402 B, both dated 2026-10-01)*
- [x] Append one dated sentence to the SKILL.md `derivation` and to the `eager_load.note` recording
      that the overage was closed by a deliberate duplication trim, naming the files trimmed, and
      stating explicitly that `baseline_bytes` and both `ceiling_bytes` were left unmoved *(completed)*
- [x] Leave `ceiling_bytes` (both files) and `eager_load.baseline_bytes` byte-identical *(completed: verified via jq, unchanged from HEAD)*

**Timing**: 0.5 hours

**Depends on**: 2, 3, 4

**Verification Tier**: interface

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - default flip + comment rewrite
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` - `_comment`,
  snapshots, derivation narratives

**Verification**:
- `grep -n 'ORCHESTRATOR_BUDGET_GATE_MODE:-' agent-system/extensions/core/scripts/verify-deploy.sh`
  shows `:-hard}`
- `git diff` on the config shows `ceiling_bytes` and `baseline_bytes` unchanged
- `jq . agent-system/extensions/core/context/config/orchestrator-context-budget.json` parses
- `grep -rn 'concurrently being edited\|deferred until commands/orchestrate.md'` over both files
  returns nothing
- `bash .claude/scripts/check-task-references.sh` (or a `grep -nE 'task [0-9]+'` over both edited
  files) finds no task-number reference

---

### Phase 6: Full gate and test verification [NOT STARTED]

**Goal**: Confirm Gate 20's three sub-checks pass with the gate now at `hard`, confirm the gate's
test suite is fully green, and leave the recorded figures honest.

**Tasks**:
- [ ] Run `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 20`
      and confirm all three sub-checks report `[PASS]` with no findings
- [ ] Run `bash agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh`
      and confirm all 13 cases pass (the two previously-red cases — "baseline fixture is not clean"
      and "could not compute a safe eager-load pad amount" — should clear once the eager trim lands)
- [ ] Run the full `verify-deploy.sh` (no `--only-gate`) to confirm no other gate regressed from
      the trims, particularly the `claudemd-size-budget.json` sibling gate
- [ ] Re-run `measure-eager-context.sh --check` one final time and confirm the config's
      `eager_load.measured_bytes` matches the live `TOTAL:`; correct the snapshot if it drifted
- [ ] Optional (explicitly out of required scope): refresh `specs/ROADMAP.md`'s "Budgets" table
      (lines ~26–29) from its stale 67,980 B / 21,317 B snapshot to the live post-trim figures. Skip
      without penalty if `specs/ROADMAP.md` is claimed by another in-flight task
- [ ] Write the execution summary to
      `specs/289_clear_orchestrator_context_budget_gate/summaries/01_*-summary.md` reporting the
      measured before/after bytes for each trimmed file

**Timing**: 0.5 hours

**Depends on**: 5

**Verification Tier**: full

**Files to modify**:
- `specs/ROADMAP.md` - optional snapshot refresh only
- `specs/289_clear_orchestrator_context_budget_gate/summaries/01_*-summary.md` - new

**Verification**:
- Gate 20: three `[PASS]` lines, zero findings, with `ORCHESTRATOR_BUDGET_GATE_MODE` unset (proving
  the new `hard` default is what ran)
- `test-verify-deploy-context-budget.sh` exits 0
- Full `verify-deploy.sh` failure count is no higher than its pre-task count

## Testing & Validation

- [ ] `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`
      → `TOTAL:` ≤ 65,950 B (target ≤ 64,500 B), `Volatile-file hits: 0`
- [ ] `wc -c agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` < 20,000 B
- [ ] `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 20`
      → all three sub-checks `[PASS]`, run with the env var unset
- [ ] `bash agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` → 13/13
- [ ] Full `verify-deploy.sh` → no new failures versus the pre-task run
- [ ] `eager_load.baseline_bytes` and both `ceiling_bytes` byte-identical to their pre-task values
- [ ] No removed behavioural clause is absent from its relocation target
      (`orchestrate-state-machine.md`, `git-workflow-narrative.md`)
- [ ] No task-number reference introduced into any `agent-system/**` file

## Artifacts & Outputs

- Trimmed `merge-sources/claudemd.md`, `rules/git-workflow.md`, `skills/skill-orchestrate/SKILL.md`
- Grown (relocation targets) `docs/architecture/orchestrate-state-machine.md` (if needed) and
  `context/standards/git-workflow-narrative.md`
- `scripts/verify-deploy.sh` with `ORCHESTRATOR_BUDGET_GATE_MODE` defaulting to `hard` and a
  current, non-stale comment
- `context/config/orchestrator-context-budget.json` with refreshed snapshots and a dated derivation
  record of the deliberate trim
- Widened `file_scope` in `specs/state.json`, regenerated `specs/TODO.md`
- `specs/289_clear_orchestrator_context_budget_gate/summaries/01_*-summary.md`

## Rollback/Contingency

- Every phase commits per green sub-step, so any individual trim is revertible with
  `git revert <sha>` without disturbing the others.
- **If the trims cannot reach ≤ 65,950 B** (e.g. unrelated eager growth lands concurrently):
  do NOT flip the gate to `hard`, and do NOT silently re-derive `baseline_bytes`. Stop at Phase 4,
  mark Phase 5 `[BLOCKED]`, and return a `user_decision` asking the user to choose between a
  further trim target and a dated, reviewed `baseline_bytes` move — the config's own note requires
  that choice be deliberate and recorded.
- **If flipping to `hard` surfaces an unrelated hard failure** in sub-check C: revert only the
  `verify-deploy.sh` default flip (keeping the trims and the config record, which stand on their
  own), and record the newly-surfaced blocker.
- Before any destructive rollback on a dirty tree, take a non-reverting checkpoint first:
  `bash .claude/scripts/git-snapshot.sh 289 --no-revert`.
