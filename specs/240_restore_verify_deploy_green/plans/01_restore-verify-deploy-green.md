# Implementation Plan: Task #240

- **Task**: 240 - Restore verify-deploy.sh to green
- **Status**: [IMPLEMENTING]
- **Effort**: 1.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/240_restore_verify_deploy_green/reports/01_restore-verify-deploy-green.md
- **Artifacts**: plans/01_restore-verify-deploy-green.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two `verify-deploy.sh` checks were reported failing. Research reproduced only one of them.
GATE 17 (scoped-commit boundary lint) flags a false positive: an inert test fixture string at
`agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh:152`. The fix is to reword
that fixture. GATE 20 Sub-check B (eager-load total vs. `baseline_bytes`) currently PASSES:
65257 B is under the 65950 B baseline, leaving 693 B of headroom. The planner re-measured it at
plan time and got the same 65257 B. The `66026 B` figure in the budget config's informational
`note` did not reproduce, even against the commit that recorded it. The plan therefore rewords
the GATE 17 fixture, corrects the stale GATE 20 informational fields (without touching
`baseline_bytes`), and adds a conditional re-measure step. If a concurrent sibling has since
pushed the total over baseline, that step falls back to the dispatch's original
trim-then-rebaseline guidance. It closes with a full `deploy-headless.sh` verification.

### Research Integration

- GATE 17: single violation. The lint's `CANDIDATE_PATTERN='git commit -m'` is a plain
  substring match. The preferred fix rewords the fixture to `'git commit --message "true"'`.
  `--message` is git's long form of `-m`. It still does not match `is_trivial_segment()`'s
  exact-match case list, so the classification under test is unchanged. The allowlisting
  fallback would exempt the whole file, so it is less precise and not preferred.
- GATE 20 Sub-check B: `verify-deploy.sh` reads only `eager_load.baseline_bytes`. The
  `measured_bytes`, `measured_at` and `note` fields are informational. Research found no
  regression, so it recommends against a speculative trim.
- Risk flagged by research: sibling task 248 (undeclared file scope) is running in the same
  orchestrate cycle. It could move the live eager total before implementation, so the total
  must be re-measured at implementation time.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap consultation requested for this dispatch.

## Goals & Non-Goals

**Goals**:
- Reach `Total violations: 0` from `lint-scoped-commit-boundary.sh --verbose`.
- Keep all 40 assertions of `test-detect-noop-bash.sh` passing.
- Keep the eager-load total at or under `eager_load.baseline_bytes`, confirmed by a fresh
  measurement at implementation time.
- Make the budget config's informational fields accurate and reproducible.
- `bash .claude/scripts/deploy-headless.sh` reports RESULT `landed` (exit 0) with 0 failed
  checks.

**Non-Goals**:
- A speculative eager-set trim when the gate already passes.
- Changing `baseline_bytes` when there is no reproduced regression.
- Adding `test-detect-noop-bash.sh` to the lint's `EXCLUDED_FILES` allowlist, unless the reword
  proves impossible.
- Any edit under `.claude/` (the deploy artifact). Only `agent-system/extensions/core/**` is
  edited.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Sibling task (248, undeclared scope) grows the eager set before Phase 2 | M | L | Phase 2 re-measures first; if over baseline, trim (preferred) or rebaseline with dated justified note, scoped to the actual cause |
| Fixture reword changes classifier behavior | M | L | Replacement verified against exact-match case list; full 40-assertion suite rerun as a hard gate |
| Full `deploy-headless.sh` surfaces an unrelated failing gate caused by a sibling's in-flight edit | M | M | Diagnose via `git log`/`git status`; if outside this task's scope and attributable to a sibling, report it in the handoff rather than fixing foreign files |
| Concurrent edits to shared files | L | L | Re-read each file immediately before editing; stage only this task's hunks with explicit paths |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Reword GATE 17 fixture [COMPLETED]

**Goal**: Remove the scoped-commit lint false positive without changing what the test covers.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh` around line
  152 to confirm the fixture is still `'git commit -m "true"'`. *(completed)*
- [x] Replace it with `'git commit --message "true"'`. Leave the assertion label and
  `assert_nontrivial` unchanged. *(completed)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh` and confirm
  `40 passed, 0 failed`. *(completed)*
- [x] Run `bash agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh --verbose`
  and confirm `Total violations: 0`. *(completed)*
- [x] Commit only this file with an explicit path (`task 240 phase 1: reword noop-bash commit
  fixture`). *(completed)*

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh` - one fixture string
  (line 152)

**Verification**:
- Test suite reports 40 passed and 0 failed. The lint reports 0 violations.

---

### Phase 2: Re-measure eager load and correct budget config [NOT STARTED]

**Goal**: Confirm GATE 20 Sub-check B is green with a fresh measurement, and make the config's
informational fields accurate.

**Tasks**:
- [ ] Run `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`
  and record the `TOTAL: <bytes> B` value.
- [ ] **If TOTAL <= 65950** (expected, since plan time measured 65257): re-read
  `agent-system/extensions/core/context/config/orchestrator-context-budget.json` and update only
  `eager_load.measured_bytes` (to the fresh TOTAL), `eager_load.measured_at` (today's ISO date)
  and the tail of `eager_load.note`. Replace the "KNOWN as of 2026-09-18 ... 66,026 B" passage
  with a dated correction: the 66,026 B figure did not reproduce, not even against its own
  recording commit, which re-measures to 65,257 B; the live total is `<TOTAL>` B with
  `<65950-TOTAL>` B headroom. Keep the baseline-policy prose that precedes it. Leave
  `baseline_bytes` unchanged.
- [ ] **If TOTAL > 65950** (a sibling regression landed): find the file(s) that grew (use
  `git log` on the eager channels: the core and extension claudemd merge sources, and core
  `rules/*.md`). Preferred: trim at least the overage plus a few hundred bytes of headroom by
  collapsing restatement into pointers in `agent-system/extensions/core/**` eager files. Keep
  all operational content, and do not edit a file inside a live sibling's declared scope.
  Fallback: raise `baseline_bytes` with a dated, justified note that names the cause. Then update
  `measured_bytes`, `measured_at` and `note` as above.
- [ ] Validate JSON (`jq . <config> >/dev/null`). Re-run the measurement and confirm
  `TOTAL <= baseline_bytes`.
- [ ] Commit only the touched files with explicit paths (`task 240 phase 2: correct eager-load
  budget snapshot`).

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Only the budget config's three informational fields change, because the
total is expected to stay near 65257 B, under baseline. Confirm with the fresh measurement in
step 1. If it is over baseline, the trim branch applies and its file list is decided at that
point.

**Files to modify**:
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` -
  `measured_bytes`, `measured_at`, `note` (and `baseline_bytes` only in the over-baseline
  fallback)
- (conditional, over-baseline only) eager-loaded files under
  `agent-system/extensions/core/merge-sources/` or `agent-system/extensions/core/rules/`

**Verification**:
- `measure-eager-context.sh --check` shows TOTAL <= `baseline_bytes`, and the config parses as
  valid JSON.

---

### Phase 3: Full deploy verification [NOT STARTED]

**Goal**: Confirm the whole deploy pipeline is green end to end.

**Tasks**:
- [ ] Run `bash .claude/scripts/deploy-headless.sh` (long-running) and capture the full output to
  a log in the scratchpad. Wait with a bounded waiter, following
  `context/patterns/bounded-build-waiter.md`.
- [ ] Confirm RESULT is `landed` (exit 0) and `verify-deploy.sh` reports 0 failed checks.
- [ ] Confirm Gate 17 and Gate 20 Sub-check B specifically report PASS.
- [ ] If another gate fails, check `git log` and `git status` for attribution. Fix it only if
  this task's edits caused it. If a sibling's in-flight work caused it, record the finding in the
  summary and handoff and do not edit foreign files.

**Timing**: 0.5 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Files to modify**:
- None (verification only; `.claude/` regeneration by the deploy script is by design)

**Verification**:
- `deploy-headless.sh` exits 0 with RESULT `landed` and 0 failed checks.

## Testing & Validation

- [ ] `test-detect-noop-bash.sh`: 40 passed, 0 failed
- [ ] `lint-scoped-commit-boundary.sh --verbose`: Total violations: 0
- [ ] `measure-eager-context.sh --check`: TOTAL <= `eager_load.baseline_bytes`
- [ ] `jq` parses `orchestrator-context-budget.json`
- [ ] `deploy-headless.sh`: RESULT landed, exit 0, 0 failed checks

## Artifacts & Outputs

- Modified `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh`
- Modified `agent-system/extensions/core/context/config/orchestrator-context-budget.json`
- `specs/240_restore_verify_deploy_green/summaries/01_restore-verify-deploy-green-summary.md`

## Rollback/Contingency

Each phase is a single scoped commit touching one or two files. To revert, run `git revert` on
that commit. Never use a destructive reset on the shared tree. If the fixture reword cannot keep
the 40 assertions green, fall back to a narrowly reasoned `EXCLUDED_FILES` entry in
`lint-scoped-commit-boundary.sh`. Model it on the existing test-fixture allowlist entries.
