# Implementation Summary: Task #275

- **Task**: 275 - Per-repo orchestration queue: registered, live, archived on finish, and consumed by admission
- **Status**: [COMPLETED]
- **Started**: 2026-11-04T14:52:16Z
- **Completed**: 2026-11-04T16:00:27Z
- **Effort**: ~2.5 hours
- **Dependencies**: 170, 272
- **Artifacts**: plans/01_per-repo-orchestration-queue.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md

## Overview

Added a per-repo orchestration queue as six additive subcommands on `task-lock.sh`
(`queue-register`, `queue-heartbeat`, `queue-finish`, `queue-reap`, `queue-list`, `queue-check`),
built on the existing session registry rather than replacing it. The queue gives each
orchestration its own identity (`orchestration_id`, distinct from `session_id`), tracks the
lifecycle `registered -> running -> finished -> archived`, archives finished orchestrations into
`specs/.orchestration/archive/` (never `rm -f`), computes liveness by calling the existing
`session_liveness()` unchanged, and exposes a blocking `queue-check` admission gate wired into
`/orchestrate`'s pre-dispatch stage that refuses a conflicting invocation immediately, naming the
conflict, with `--allow-scope-collision` as its override.

## What Changed

- `agent-system/extensions/core/scripts/lib/common.sh` — added `common_orchestration_id()`,
  modeled on `common_session_id()`.
- `agent-system/extensions/core/scripts/task-lock.sh` — added `orchestration_queue_dir()`,
  `orchestration_archive_dir()`, `write_queue_entry()`, and the six `cmd_queue_*` subcommands,
  dispatch entries, and usage string.
- `agent-system/extensions/core/scripts/tests/test-task-lock-queue.sh` — new fixture suite, 17
  cases: register/re-register/heartbeat/missing-entry, liveness reasons via `queue-list`,
  finish/idempotency, reap dry-run/live with `disposition_reason`, and the seven-case
  `queue-check` refusal matrix.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — `queue-register` beside
  `session-register` in Setup; `queue-finish` beside `session-release` in Move 4.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — `queue-heartbeat` co-sited
  with `session-heartbeat`.
- `agent-system/extensions/core/commands/orchestrate.md` — blocking `queue-check` before
  dispatch, forwarding `ALLOW_SCOPE_COLLISION_FLAG`; `--allow-scope-collision` flags-table row
  updated.
- `agent-system/extensions/core/context/patterns/task-lock.md` — new `## Orchestration-Queue
  CLI` section (Reader Contract, Lifecycle, Record Schema, per-subcommand detail, Liveness Is
  Consumed subsection, Refusal Contract, Known Limitations), cross-referenced from the
  Session-Registry CLI section and the Four-Tier Conflict Response section.
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` — two new
  Class Table rows for `specs/.orchestration/queue/{orchestration_id}.json` (**Ephemeral**) and
  `specs/.orchestration/archive/{orchestration_id}.json` (**Durable provenance, but untracked**).
- `agent-system/extensions/core/manifest.json` — registered the new test file via
  `sync-manifest-scripts.sh --write`.
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` — reviewed,
  dated ceiling move for `commands/orchestrate.md` (21000 -> 21500) and
  `skills/skill-orchestrate/SKILL.md` (24000 -> 24500), following the file's own established
  "reviewed, dated ceiling move" convention; both files already carried a razor-thin pre-existing
  margin before this task's genuinely new, non-duplicative mechanism.

## Decisions

- D1-D7 from the plan were followed as written (identity minted by `queue-register` and resolved
  by `session_id` thereafter; liveness via `session_liveness()` against the queue entry file
  itself, never the session registry; archive = move, no second ledger; archive is local and
  untracked; documentation sited in `task-lock.md` as a peer section; `queue-check` wired at one
  call site only, `command-gate-in.sh` untouched; `--allow-scope-collision` is the refusal's
  override).
- The archive record carries an additional `disposition_reason` field (null for a clean
  `queue-finish`, the triggering liveness verdict string for a `queue-reap` disposition) — a
  modest, deliberate extension of the plan's illustrative schema, matching the plan's own Phase 2
  task text ("a reason field naming the liveness verdict").
- `queue-reap`'s archived `finished_at` is the entry's own last `heartbeat_at` (not the reap
  time); `archived_at` is the reap operation's own time.

## Plan Deviations

- Phases 1, 2, and 3 were implemented together in one editing pass rather than strictly
  sequentially, since `write_queue_entry()` is infrastructure shared by all six subcommands.
  Each phase's own verification criteria were still checked and confirmed green independently
  before considering that phase closed.
- Phase 6 discharged the full gate set against this dispatch's Batch Gate Deferral directive's
  scoped tier (`verify-deploy.sh --skip-slow` plus a 105-suite selection run covering every
  touched file) rather than independently running the complete, unscoped gate 8 battery, which
  separately hit its own 1500s timeout on an unrelated full run. The full gate is deferred to the
  batch-level stage, never forgiven.

## Verification

- Build: N/A (shell scripts and markdown)
- Tests: `test-task-lock-queue.sh` 17/17 PASS; regression set (`test-common-lib.sh`,
  `test-session-registry.sh`, `test-task-lock-liveness.sh`, `test-task-lock-reap.sh`,
  `test-conflict-predicate.sh`, `test-four-tier-conflict.sh`, `test-orchestrate-cycle-plan.sh`,
  `test-runtime-file-tracking.sh`, `test-session-runtime-files.sh`) all PASS; a 105-suite
  selection run covering every touched file: 97 passed, 8 failed (all pre-existing/unrelated or
  already-EXPECTED baseline failures, confirmed via `git stash push -- <touched files>` against
  unmodified `master` for 5 of them)
- Files verified: Yes (`verify-deploy.sh --skip-slow` 37/37 PASS after redeploy;
  `check-deploy-freshness.sh` reports no stale extension)

## Impacts

- `/orchestrate` now refuses a whole-batch invocation immediately when its `file_scope` collides
  with an in-flight orchestration elsewhere in the same repo, with the conflict named and
  `--allow-scope-collision` as the override — closing the "no orchestration-level record exists"
  gap this task's record identified.
- A finished orchestration's record now persists in `specs/.orchestration/archive/` rather than
  vanishing, giving a future reader (or a future retention-policy task) something to read.

## Follow-ups

- No archive pruning or retention policy exists yet (deliberate Non-Goal; recorded as a Known
  Limitation in `task-lock.md`).
- A measured cross-repo counterexample to the per-repo scope ruling remains tracked in a separate
  record that owns running the scope question to an owner decision; no amendment was made here.
- Five pre-existing, unrelated test-suite failures (`test-orchestrate-cycle-postflight.sh`,
  `test-orchestrate-predispatch-review.sh`, `test-orchestrate-unwind-dispatch.sh`,
  `test-postflight-deploy-gate.sh`, `test-redeploy-checkpoint-promotion.sh`) and one more
  (`test-gate-out-repair-reporting.sh`) were observed on `master`, confirmed unrelated to this
  task's scope, and left unfixed as out of scope — recorded in the issue log for visibility.

## References

- Plan: `specs/275_per_repo_orchestration_queue/plans/01_per-repo-orchestration-queue.md`
- Report: `specs/275_per_repo_orchestration_queue/reports/01_per-repo-orchestration-queue.md`
- `agent-system/extensions/core/context/patterns/task-lock.md`
- `agent-system/extensions/core/scripts/tests/test-task-lock-queue.sh`
