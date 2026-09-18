# Implementation Summary: Task #215

- **Task**: 215 - Unwind an unconsumed /orchestrate dispatch
- **Status**: [COMPLETED]
- **Started**: 2026-09-18T17:35:00Z
- **Completed**: 2026-09-18T18:48:00Z
- **Effort**: ~1.3 hours wall-clock (plan estimated 7 hours)
- **Dependencies**: 213 (per-run cycle-budget change; confirmed already live)
- **Artifacts**: plans/01_unwind-unconsumed-dispatch.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added a by-hand recovery script, `orchestrate-unwind-dispatch.sh`, that reverses every mutation
`orchestrate-cycle-plan.sh`'s live Move 1 makes for one task when Move 2 (the Agent call) never
runs: the preflight status/last_updated/session_id write, the task lock, the `.dispatch/{seq}.md`
file, the durable `dispatch_seq_counter`, and `pending_dispatch` in `.orchestrator-loop-guard`.
The one missing input — the pre-dispatch state — is now captured by `orchestrate-cycle-plan.sh`
itself, which widens its `pending_dispatch` record with four new `prior_*` fields on every
non-replay live dispatch. All work is documented as the sanctioned recovery path and verified
with a real (not mocked) end-to-end fixture test.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — captures
  `prior_status`/`prior_last_updated`/`prior_session_id` immediately before the preflight status
  write, and `prior_dispatch_seq_counter` in the existing top-of-script `--seed` loop (the
  earliest point that reads the durable guard file this run); persists all four into
  `pending_dispatch` only on the non-replay path.
- `agent-system/extensions/core/scripts/orchestrate-loop-guard-init.sh` — header comment updated
  to document the four new `prior_*` fields on `--record-pending`'s shape.
- `agent-system/extensions/core/scripts/orchestrate-unwind-dispatch.sh` — new. Reads
  `pending_dispatch`, applies a 6-condition refusal gate (legacy record, consumed dispatch, agent
  already started, session mismatch, live foreign lock), and either restores every Move 1
  mutation exactly (via `state-write.sh --regen-todo`, `orchestrate-loop-guard-init.sh
  --flush-seq`/`--clear-pending`, `task-lock.sh release`, an optional `git-commit-scoped.sh`
  commit) or refuses cleanly, touching nothing.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-unwind-dispatch.sh` — new. An
  integration suite that runs the REAL `orchestrate-cycle-plan.sh` to prepare a live dispatch,
  then the REAL `orchestrate-unwind-dispatch.sh` to reverse it, across 5 cases (happy path with
  `--commit`, consumed refusal, agent-started refusal, dry-run no-writes, foreign fresh-lock
  refusal). 21/21 assertions pass.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — new Group 24:
  proves the REAL live dispatch populates the `prior_*` pre-image correctly, and that a replay
  never overwrites an existing record with the now-in-flight status.
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` — documents the
  four new `pending_dispatch` fields and cross-references the new script.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — new "Unwinding
  an Unconsumed Dispatch" subsection: what Move 1 mutates, the refusal gate, the by-hand-only
  rationale, and the distinction from `reconcile-task-status.sh`.
- `agent-system/extensions/core/context/standards/git-safety.md` — new "Recovering an Unconsumed
  Dispatch" subsection naming what `guard-destructive-git.sh` blocks and pointing to the new
  script as the sanctioned non-git recovery path.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Move 1 now points to the
  script for a prepared row that will never be issued.
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — new entry.
- `agent-system/extensions/core/manifest.json` — registers both new files under
  `provides.scripts` (doc-lint had correctly flagged them as on-disk-but-undeclared after the
  first deploy attempt).

## Decisions

- Pre-image lives inside `pending_dispatch` itself (dies exactly when the dispatch is consumed,
  no second ledger to keep in sync); `prior_dispatch_seq_counter` is recorded explicitly rather
  than assumed as `seq - 1`.
- A `pending_dispatch` record predating this change (missing the `prior_*` fields) is refused as
  a LEGACY record — no override flag; hand recovery remains the documented fallback.
- Lock release delegates entirely to `task-lock.sh release`'s own built-in holder-identity check
  rather than adding a second, redundant check.
- WORK (c) resolved as **by-hand only, never automatic** — see the state-machine doc's full
  three-point rationale (the existing replay mechanism already gives the automatic answer in the
  opposite direction; no liveness signal distinguishes "gone" from "about to finish"; discarding
  work should stay an explicit operator choice).

## Plan Deviations

- None (implementation followed plan). The amendment already folded into the plan (drop "rolls
  back the cycle count"; acceptance checks `pending_dispatch`/`dispatch_seq_counter` instead) was
  followed as written.

## Verification

- Build: N/A (shell scripts)
- Tests: `test-orchestrate-cycle-plan.sh` 209/209 passing (including new Group 24);
  `test-orchestrate-unwind-dispatch.sh` 21/21 passing; full `scripts/tests/run-all.sh`
  83 passed / 2 failed / 85 total, both failures pre-existing and unrelated (gate-out repair
  reporting; the independently tracked eager-context-budget drift)
- Files verified: Yes
- shellcheck: new script and new test both clean at default severity;
  `orchestrate-cycle-plan.sh` has zero new findings in the touched region
- Deploy: `deploy-headless.sh` → `RESULT=landed_verify_clean`, 33/33 `verify-deploy.sh` checks
  pass; deployed copies byte-match the source store

## Impacts

- An operator (or an orchestrating session deliberately abandoning a prepared row at the user's
  request) now has a documented, sanctioned, non-destructive way to undo a prepared-but-unissued
  `/orchestrate` dispatch, closing the gap observed live on 2026-09-14 where hand-editing
  `specs/state.json` was the only option.
- `pending_dispatch`'s schema gained four optional fields; every existing reader (`--seed`, the
  UNCONSUMED DISPATCH REPLAY check) is unaffected since the new fields are additive-only and
  never read by the pre-existing replay logic.

## Follow-ups

- None required by this task. `commands/orchestrate.md` exceeding its context-budget ceiling
  (flagged as a WARN by verify-deploy.sh Gate 20) is pre-existing and independently tracked
  (project 235 in `specs/state.json`); this task's own doc additions to `SKILL.md` stayed well
  within its ceiling (18993 B / 20000 B).

## References

- Plan: `specs/215_unwind_unconsumed_orchestrate_dispatch/plans/01_unwind-unconsumed-dispatch.md`
- Research: `specs/215_unwind_unconsumed_orchestrate_dispatch/reports/01_unwind-unconsumed-dispatch.md`
- New script: `agent-system/extensions/core/scripts/orchestrate-unwind-dispatch.sh`
- New test: `agent-system/extensions/core/scripts/tests/test-orchestrate-unwind-dispatch.sh`
