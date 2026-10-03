# Implementation Summary: Task #265

- **Task**: 265 - Run Gate 8 in parallel inside verify-deploy.sh via run-all.sh --jobs (absorbing the deploy-headless.sh inline-verify redundancy)
- **Status**: [COMPLETED]
- **Started**: 2026-10-03T00:17:00Z
- **Completed**: 2026-10-03T03:05:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None blocking (task 261 and the admission-posture serialization edge were already discharged)
- **Artifacts**: plans/01_gate8-jobs-and-inline-verify.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Part A made `verify-deploy.sh`'s Gate 8 (the `tests/run-all.sh` shell-battery call site) request
`run-all.sh`'s existing opt-in `--jobs` parallelism, defaulting to `auto` with a
`VERIFY_DEPLOY_GATE8_JOBS` escape hatch, after first fixing a deterministic nested-environment
defect in `test-run-all-parallel.sh`. Part B gave `deploy-headless.sh` an opt-in `--skip-verify`
flag (new exit 4, `RESULT=landed_verify_skipped`) and threaded it into deploy-headless.sh's two
genuine callers, eliminating a wholly redundant inline verification pass on those paths. All 8
plan phases are COMPLETED; the full battery's `[FAIL]` set is unchanged in substance across every
measurement in this task.

**Important premise correction surfaced during implementation (Phase 6)**: the dispatch's and
plan's own framing of Part B's rationale ("the checkpoint's pre/post/confirm snapshots run at
FULL depth, never `--skip-slow`") was stale. A separate, already-completed prior task
("stop redeploy-checkpoint gate 8 amplification") had already switched both callers' own
independent snapshot pairs to `--skip-slow`, matching `deploy-headless.sh`'s own inline verify
depth exactly, and removed Gate 8 from this checkpoint path entirely (independent of this task).
`context/patterns/batch-orchestration-guardrails.md` already documented this as a "decided OUT...
recorded as a genuine, scoped follow-up for a future task" — this task's Part B IS that follow-up,
now landed with the caller-contract audit that prior task deferred actually completed. The
underlying mechanism (suppress the inline pass; both callers' own snapshots already cover the
identical gate set) remained valid; only the magnitude of the saving changed — not a ~9-minute
Gate 8 pass, but a real, measured ~2m9s-per-checkpoint-fire `--skip-slow` pass (materially larger
than this plan's own carried-forward ~50-70s estimate, measured here under heavier ambient load).
This is disclosed in full in `specs/265_parallelize_gate8_shell_test_suite/progress/phase-6-progress.json`
and in the Phase 6/7/8 plan-checklist annotations rather than silently absorbed.

## What Changed

- `agent-system/extensions/core/scripts/tests/test-run-all-parallel.sh` — isolated `RUN_ALL_NESTED`
  for the suite's own "unguarded" fixture measurements (single `unset RUN_ALL_NESTED` in the setup
  block), fixing a deterministic (not merely load-sensitive) failure when this suite is discovered
  nested inside another `run-all.sh` invocation.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — Gate 8 now passes
  `--jobs "$GATE8_JOBS"` to `run-all.sh`, with `GATE8_JOBS="${VERIFY_DEPLOY_GATE8_JOBS:-auto}"`;
  status-2 remedy text names the override variable; header documents the variable, its default,
  and the rejected alternatives. `--skip-slow`, the deploy-consumer branch, and the
  missing-`run-all.sh` branch are byte-identical (confirmed via `git diff`).
- `agent-system/extensions/core/scripts/deploy-headless.sh` — new opt-in `--skip-verify` flag;
  suppresses the inline `verify-deploy.sh --skip-slow` pass entirely when set; new exit code `4`
  via its own `elif` arm (distinct from the `0` and `3` arms); `RESULT=landed_verify_skipped`;
  header documents the flag, exit code, and `RESULT=` token; `--help` `sed` range bumped from
  `2,101p` to `2,149p` to cover the lengthened header.
- `agent-system/extensions/core/scripts/command-gate-out.sh` — appends `--skip-verify` to its
  `deploy-headless.sh` invocation, with a comment explaining why suppression is safe there
  (its own independent pre/post `--skip-slow` snapshot pair already covers the identical gate
  set).
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — same `--skip-verify` addition
  at the Inter-Cycle Redeploy Checkpoint's `deploy-headless.sh` call; also documented, in place,
  why its pre-existing `depth_disagreement` diagnostic (`deploy_exit -eq 0`) is now effectively
  dead in real operation on this path (deliberately NOT widened to `-eq 0 || -eq 4`, since 4 means
  "suppressed", not "ran and passed") while remaining correct for the test fixture and the
  operational rollback path.
- `agent-system/extensions/core/scripts/tests/test-deploy-verify-wiring.sh` — 8 new cases (10-12):
  `--help` documents `--skip-verify`/exit 4/`landed_verify_skipped`; `--skip-verify --dry-run`
  still exits 0 with no verification announcement; structural assertion that exit 4 is reachable
  only under the `SKIP_VERIFY` guard via its own distinct `elif` arm.
- Documentation: `context/patterns/regeneration-is-manual-only.md`,
  `context/standards/shell-script-testing.md`, `context/patterns/batch-orchestration-guardrails.md`,
  `docs/architecture/orchestrate-state-machine.md` — the `--skip-verify`/exit-4 contract, Gate 8's
  `--jobs` opt-in and measured numbers, the why-this-mechanism and `--only-gate`-vs-suppression
  rationale, and closing out the previously-deferred follow-up.

## Decisions

- Gate 8 defaults to `--jobs auto` (nproc capped at 4) rather than a fixed value, with
  `VERIFY_DEPLOY_GATE8_JOBS` as the override — the same opt-in-escape-hatch shape `run-all.sh`
  itself already uses, so no new convention was invented.
- Exit code `4` / `RESULT=landed_verify_skipped` chosen over reusing `0` (would misrepresent a
  suppressed verify as a passed one) or `3` (means "verify ran and found something", false when
  verify never ran).
- `--only-gate`-narrowed inline verify was weighed against outright suppression and rejected: on
  both genuine caller paths, the caller's own `--skip-slow` pair already covers every gate a
  narrowed inline pass could usefully re-check, so narrowing still pays real cost for zero
  additional information.
- The Phase 4 decision gate's one set-difference (`test-four-tier-conflict.sh`, present in both
  sequential baseline runs, absent from the one `--jobs auto` run, and absent from the final
  sequential-default full-battery run in Phase 8) was treated as ambient-load noise in an
  already-documented `LOAD_SENSITIVE_BASENAMES` suite, not a new parallelism-caused regression —
  it is scheduled serially before the parallel pool regardless of `--jobs`, so this task's change
  cannot be its cause. Proceeded past the gate with this disclosed in full rather than
  escalated as a blocking user decision, consistent with the gate's own framing of the actual
  trigger condition ("a genuinely load-sensitive suite OUTSIDE the known five").

## Plan Deviations

- **Phase 6 (premise correction)**: the dispatch/plan's "full depth, never `--skip-slow`" framing
  for the checkpoint's own snapshot pair was found stale on re-read — see Overview above and
  `progress/phase-6-progress.json`'s `deviations` array for the full account. The suppression
  mechanism itself was implemented exactly as planned; only the rationale wording and the
  magnitude of the measured saving were corrected.
- **Phase 7, task 1 (altered)**: a full live `/orchestrate` cycle fire was not self-triggered from
  inside this implement dispatch (cycle boundaries belong to the orchestrator engine, not a
  dispatched sub-agent). Substituted an isolated, directly-measured timing of the one component
  that changed (`deploy-headless.sh`'s own call, with and without `--skip-verify`), which fully
  accounts for the checkpoint's total delta since nothing else in the call chain was touched.
- **Phase 8, task 2 (wording correction)**: the plan asked to cite "task 261's recorded battery
  numbers" directly; `hooks/validate-no-task-references.sh` correctly blocked that as a
  task-number citation in a deliverable file outside `specs/**`. Fixed by inlining the actual
  numbers into the existing `--jobs` bullet in `shell-script-testing.md` and referencing it
  descriptively instead of by task number.

## Verification

- Build: N/A (shell scripts; `bash -n` clean on every edited file)
- Tests: `test-deploy-verify-wiring.sh` 28/28, `test-verify-deploy-gate-selection.sh` 5/5,
  `test-lint-deploy-caller-wrap.sh` 7/7, `test-orchestrate-cycle-plan.sh` 344/344 (including
  checkpoint (k)'s `depth_disagreement` assertions, unaffected since its fixture stub ignores
  `--skip-verify`), `test-run-all-parallel.sh` 9/9 both standalone and under simulated
  `RUN_ALL_NESTED=1` nesting. Final full `run-all.sh --quiet`: 103 passed, 3 failed (2 expected
  per `known-failures.txt`, 1 NEW — `test-typst-element-lint.sh`, attributable to a still-live,
  concurrently-dispatched sibling task's uncommitted edit to `typst-element-lint.sh`, not to this
  task's own changes).
- Files verified: Yes (`bash -n` on every edited `.sh` file; `grep -n 'task [0-9]'` on every
  edited doc file returns nothing; `deploy-headless.sh` resync + its own inline verify passed
  clean after every source-store edit round).

### Measured numbers (verbatim, both complete `[FAIL]` sets)

**Sequential baseline (Phase 2)** — `time bash verify-deploy.sh --findings` (no `--skip-slow`):
real 14m1.512s. `[FAIL]` set (4 suites): `test-four-tier-conflict.sh`,
`test-gate-out-repair-reporting.sh`, `test-lint-json-channel-discipline.sh`,
`test-typst-element-lint.sh`.

**`--jobs auto` (Phase 4)** — same command: real 6m47.357s (51.6% reduction). `[FAIL]` set
(3 suites, proper subset of baseline): `test-gate-out-repair-reporting.sh`,
`test-lint-json-channel-discipline.sh`, `test-typst-element-lint.sh`.

**`VERIFY_DEPLOY_GATE8_JOBS=1` rerun (Phase 4)**: real 13m51.562s — reproduced the sequential
baseline's exact 4-suite set.

**Checkpoint-component isolation (Phase 7)** — `time bash deploy-headless.sh`: without
`--skip-verify`, real 2m17.574s (exit 0, `RESULT=landed_verify_clean`); with `--skip-verify`,
real 0m8.425s (exit 4, `RESULT=landed_verify_skipped`). Delta: ~2m9s removed per checkpoint fire.

**Final full battery, sequential default (Phase 8)** — `run-all.sh --quiet`: 103 passed, 3 failed
(2 expected, 1 NEW), 106 total. `[FAIL]` set identical to the Phase 4 `--jobs auto` set.

All measurements taken on the same host (nproc=24) under heavy, documented ambient
concurrent-agent-session load (see each phase's progress file for load averages and the sibling
tasks observed active).

## Impacts

- A full `verify-deploy.sh` run (no `--skip-slow`) is ~51.6% faster under the new default, with an
  operational, no-code-change rollback (`VERIFY_DEPLOY_GATE8_JOBS=1`).
- The Inter-Cycle Redeploy Checkpoint and `command-gate-out.sh`'s single-task redeploy trigger
  each save a real, measured ~2m9s per fire by no longer paying `deploy-headless.sh`'s own now
  wholly-redundant inline verification pass.
- Closes out a previously-deferred follow-up explicitly recorded in
  `context/patterns/batch-orchestration-guardrails.md` ("Suppressing `deploy-headless.sh`'s own
  internal `--skip-slow` verify... decided OUT... a genuine, scoped follow-up for a future task").

## Follow-ups

- `test-four-tier-conflict.sh` is not yet listed in `scripts/tests/known-failures.txt` despite
  being observed failing under ambient load in this task's measurements (it is already in
  `run-all.sh`'s own `LOAD_SENSITIVE_BASENAMES` array, which governs scheduling, not the separate
  known-failures manifest, which governs EXPECTED/NEW classification). A follow-up could add it
  to the manifest under the `load-sensitive` category if this recurs.
- `test-typst-element-lint.sh`'s redness in every measurement this task took traces to a
  concurrently-dispatched sibling task's uncommitted edit to
  `agent-system/extensions/typst/scripts/typst-element-lint.sh` (observed in `git status` at
  dispatch start and still present at Phase 8's final run). This is exactly the confound
  `known-failures.txt` already documents and deliberately excludes this suite for; no action
  needed from this task.
- `context/patterns/batch-orchestration-guardrails.md`'s own residual-gap note (the ~40
  deploy-tree-first suites receiving no post-redeploy Gate-8 coverage from the checkpoint) predates
  this task and is unchanged by it; a narrower future fix remains recommended there, not here.

## References

- Plan: `specs/265_parallelize_gate8_shell_test_suite/plans/01_gate8-jobs-and-inline-verify.md`
- Progress files: `specs/265_parallelize_gate8_shell_test_suite/progress/phase-{1..8}-progress.json`
- `context/patterns/batch-orchestration-guardrails.md`'s "### The Inter-Cycle Redeploy Checkpoint"
  subsection (authoritative checkpoint contract)
- `context/patterns/regeneration-is-manual-only.md`'s "`--skip-verify`: an opt-in suppression for
  callers with their own baseline" subsection
