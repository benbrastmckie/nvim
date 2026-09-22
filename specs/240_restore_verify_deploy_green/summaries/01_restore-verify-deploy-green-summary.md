# Implementation Summary: Task #240

- **Task**: 240 - Restore verify-deploy.sh to green
- **Status**: [COMPLETED]
- **Started**: 2026-09-21T00:00:00Z
- **Completed**: 2026-09-21T00:55:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_restore-verify-deploy-green.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Restored the two `verify-deploy.sh` check failures named in the dispatch. GATE 17 (scoped-commit
boundary lint) had one false-positive violation from an inert test fixture string; it is fixed by
rewording the fixture. GATE 20 Sub-check B (eager-load total vs. `baseline_bytes`) was already
passing at implementation time (65,257 B measured, under the 65,950 B baseline), so the budget
config's stale informational fields were corrected rather than trimming a set that was not over
budget. A full `deploy-headless.sh` run confirms both target gates PASS; a third, unrelated gate
(Gate 5, manifest content-hash equality) failed due to a concurrently-running sibling task's
own in-flight uncommitted edit, which is documented and left untouched per this task's scope.

## What Changed

- `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh` — reworded the GATE 17
  test fixture from `'git commit -m "true"'` to `'git commit --message "true"'`, eliminating the
  lint's substring false positive while keeping the classifier assertion's intent unchanged.
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` — updated
  `eager_load.measured_bytes` (66026 -> 65257), `eager_load.measured_at` (2026-09-18 ->
  2026-09-21), and replaced the stale "KNOWN as of 2026-09-18 ... 66,026 B" note passage with a
  dated "CORRECTED 2026-09-21" passage explaining the 66,026 B figure did not reproduce, either
  fresh or against its own recording commit. `baseline_bytes` (65950) was left unchanged, since
  no regression was reproduced.
- `specs/240_restore_verify_deploy_green/plans/01_restore-verify-deploy-green.md` — phase
  checklists checked off, Phase 3 closed `[COMPLETED WITH EXCLUSIONS]` with a `#### Reasoned
  Exclusions` record.

## Decisions

- Kept `baseline_bytes` unmoved: the fresh measurement (65,257 B) matched the plan-time
  measurement and left 693 B of headroom, so there was no reproduced regression to justify
  raising the ceiling. The 66,026 B figure in the prior note is treated as a stale/erroneous
  measurement rather than a real event.
- Rewording the GATE 17 fixture (`-m` -> `--message`) was preferred over an `EXCLUDED_FILES`
  allowlist entry, since it fixes the false positive precisely without exempting the whole file
  from the lint.

## Plan Deviations

- **Phase 2, Task 2** (over-baseline branch): skipped — not applicable, since the fresh
  measurement (65,257 B) was under baseline (65,950 B), so the over-baseline trim/rebaseline
  branch's admission condition never held.
- **Phase 3, Task 2**: `deploy-headless.sh`'s overall RESULT was `landed_verify_red` (1 of 33
  checks failed), not `landed` with 0 failed checks. The failing check (Gate 5, manifest-driven
  category parity + content-hash equality) reported `core: Content differs from source:
  scripts/claude-refresh.sh`. That file is uncommitted and modified in the working tree,
  matching exactly the declared `file_scope` of the concurrent sibling task
  `refresh_orphan_waiter_reaper`, whose `specs/state.json` status is `implementing` (actively in
  flight in this same orchestrate cycle). `git log` shows no task-240 commit touching that file.
  Per the plan's own risk mitigation and the territory contract, this is reported here rather
  than fixed, since it is that sibling's own in-flight work, not a regression caused by this
  task. Phase 3 closed `[COMPLETED WITH EXCLUSIONS]` with a full `#### Reasoned Exclusions`
  record in the plan file.

## Verification

- Build: N/A
- Tests: `test-detect-noop-bash.sh` — 40 passed, 0 failed
- `lint-scoped-commit-boundary.sh --verbose` — Total violations: 0
- `measure-eager-context.sh --check` — TOTAL 65,257 B <= baseline_bytes 65,950 B
- `jq . orchestrator-context-budget.json` — parses cleanly
- `deploy-headless.sh` (first run, this task's own dispatch) — RESULT `landed_verify_red` (not
  `landed`); Gate 17 PASS, Gate 20 PASS (both sub-checks); Gate 5 FAIL, attributed to sibling task
  `refresh_orphan_waiter_reaper`'s in-flight uncommitted edit to
  `agent-system/extensions/core/scripts/claude-refresh.sh` (not this task's edit)
- **Deploy re-verification (later dispatch, same task)**: once the sibling task's edit to
  `claude-refresh.sh` was committed, `deploy-headless.sh` was re-run and reported
  `RESULT=landed_verify_clean` (33 checks, 0 failures). This dispatch independently re-ran
  `verify-deploy.sh` directly and confirmed `PASS -- 34 check(s), 0 failure(s)`, with Gate 5, Gate
  17, and Gate 20 all passing. The deploy is now fully clean; no residual Gate 5 finding remains.
- Files verified: Yes

## Impacts

- `verify-deploy.sh` no longer reports a false-positive scoped-commit-boundary violation from
  the noop-bash test fixture.
- The eager-load budget config's informational snapshot is now accurate and reproducible,
  removing a stale, incorrect "66,026 B over baseline" record that could otherwise mislead a
  future reader into believing a regression exists when none does.
- Task 240 is the ordering dependency named by the dispatch for tasks that edit eager-loaded
  files (`merge-sources/claudemd.md`, `rules/pr-prohibition.md`,
  `rules/source-store-deploy-boundary.md`, `rules/git-workflow.md`); with GATE 20 headroom
  restored and confirmed (693 B), those tasks can now proceed with an accurate baseline measured
  after this fix.

## Follow-ups

- None. The previously-flagged Gate 5 finding cleared once the sibling task's edit landed and the
  deploy was regenerated; a fresh `deploy-headless.sh` and an independent `verify-deploy.sh` run
  both confirm a fully clean deploy (see Verification).

## References

- `specs/240_restore_verify_deploy_green/plans/01_restore-verify-deploy-green.md`
- `specs/240_restore_verify_deploy_green/reports/01_restore-verify-deploy-green.md`
- `specs/240_restore_verify_deploy_green/progress/phase-1-progress.json`
- `specs/240_restore_verify_deploy_green/progress/phase-2-progress.json`
- `specs/240_restore_verify_deploy_green/progress/phase-3-progress.json`
