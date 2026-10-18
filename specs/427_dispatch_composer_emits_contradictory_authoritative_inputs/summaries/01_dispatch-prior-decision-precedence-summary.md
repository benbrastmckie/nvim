# Implementation Summary: Stop the Dispatch Composer Emitting a Superseded Prior Decision as Settled

- **Task**: 427 - Stop the dispatch composer emitting a superseded Prior Decision as settled
- **Status**: [COMPLETED]
- **Started**: 2026-10-17T23:38:03Z
- **Completed**: 2026-10-18T00:45:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_dispatch-prior-decision-precedence.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`orchestrate-build-dispatch.sh` previously rendered every `.decisions.json` entry under a
hardcoded, unconditional authority claim ("Treat these as settled — do not re-ask a question
already answered here"), with no way to tell whether the task's own `## Description` had changed
since that answer was recorded. This implementation adds an optional `description_fingerprint`
field to newly written `.decisions.json` entries, has the composer recompute the identical digest
over the current description at render time and mark a mismatching entry `POTENTIALLY SUPERSEDED`
inline, softens the blanket authority prose to a conditional form only when a mismatch is
detected, and states the full precedence rule once in `orchestrate-state-machine.md`.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-record-decision.sh` — extracts the task's
  description and writes an optional `description_fingerprint` (sha256 hex of
  `printf '%s' "<description>" | sha256sum`) on newly appended entries, omitted entirely (never
  an empty string) when `sha256sum` is unavailable.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — documents the new optional
  field in the Decisions File Schema section, naming the authoritative digest shape and the
  composer as its consumer.
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — recomputes the digest
  over the current description at render time, marks a mismatching entry `POTENTIALLY SUPERSEDED`
  inline (an entry with no fingerprint is never marked), and switches the section's intro prose to
  a conditional form only when at least one entry in that render actually mismatched; byte-identical
  to the prior behavior when nothing mismatches or when `sha256sum`/the field is unavailable.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-record-decision.sh` — added cases
  (c1) digest-equality and (c2) sha256sum-unavailable-omission; refreshed case (h)'s hand-copied
  composer render expression to the new marker-aware shape.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — extended Group
  10 with the matching-fingerprint (byte-identical), mismatching-fingerprint (marked, conditional
  intro, full text preserved, second matching entry unmarked), and explicit-unmarked-legacy-entry
  cases; confirmed the existing absent/empty-file cases unchanged.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — new `## Prior
  Decisions vs. Current Description: Precedence` section stating the full rule: `.decisions.json`
  is historical and immutable; the current Description always governs; a Prior Decision renders
  `POTENTIALLY SUPERSEDED` exactly on a fingerprint mismatch; the conflict is surfaced, never
  resolved silently; an unfingerprinted entry is permanently unverifiable (a known, accepted
  limitation); two accepted approximations (over-surfacing preferred to under-surfacing; the
  digest is taken at recorder-write time).

## Decisions

- The digest shape (`printf '%s' "$description" | sha256sum | awk '{print $1}'`, never `echo`) is
  duplicated at both the writer and reader sites rather than extracted into `lib/common.sh`,
  pinned mechanically from both sides by tests instead of structurally shared — `common.sh` is
  sourced by nearly every script in the store, making a shared-helper edit a full-sweep blast
  radius during a cycle with concurrent sibling tasks on the same tree.
- Every `jq` equality comparison uses the `| not` form, never `!=` (Claude Code Issue #1132's
  `\!=` escaping hazard).
- An entry lacking `description_fingerprint` is never marked — absence means "cannot be verified,"
  not "superseded." No existing `.decisions.json` record is mutated, backfilled, or rewritten.

## Plan Deviations

- Phase 1's `verify-deploy.sh --skip-slow --only-gate 3,4` command example in the plan passes the
  extension subdirectory as `TARGET_REPO`; the script requires the repository root. Ran the
  equivalent check against the repo root instead — same flags, both named gates PASS.
- Phase 3's doc text states the no-mutation limitation generically rather than naming the
  originating task number, per `rules/no-task-references-in-deliverables.md` (this document is a
  deliverable outside `specs/**`). The substance of the limitation is stated in full.
- Phase 4: per this dispatch's own `## Batch Gate Deferral` directive (this phase declares
  `**Verification Tier**: full` and is the plan's final phase), the complete `verify-deploy.sh`
  gate set was deferred to the once-per-invocation batch-level stage rather than run independently
  here. Discharged instead against a scoped covering set: 15 named suites via `run-all.sh --only`
  (all PASS), `verify-deploy.sh --skip-slow --only-gate 3,4` (PASS), and a full-corpus
  `lint-shellcheck.sh` pass (401 files, 0 findings).

## Verification

- Build: N/A (shell scripts and markdown; no compiled build step)
- Tests: Passed — all four phases' named covering suites green (test-orchestrate-record-decision.sh
  11/11, test-orchestrate-build-dispatch.sh 167/167, plus the 15-suite Phase 4 scoped set);
  full-corpus shellcheck 401 files / 0 findings; doc-lint and task-reference lint both PASS.
- Files verified: Yes — all six touched files re-checked clean (`git status --short`) and
  attributed solely to this task's own commits (`git log`) before the final phase closed.

## Impacts

- A future dispatch file carrying a Prior Decision answered against a now-stale description will
  surface that conflict explicitly instead of instructing the dispatched agent to treat it as
  unconditionally settled — closing the exact failure mode (a silently superseded answer presented
  as authoritative) the originating issue identified.
- Every `.decisions.json` entry written before this change (and any entry written on a host
  without `sha256sum`) remains permanently unverifiable by this mechanism and renders as settled,
  by design — documented as a known, accepted limitation rather than a residual bug.

## Follow-ups

- None required by this task's scope. The full repository gate set (deferred per the Batch Gate
  Deferral directive) runs once at this `/orchestrate` invocation's end; if it surfaces anything
  attributable to this task's six files, it should be investigated against this summary's
  Verification section first.
- The `specs/state.json` / `TODO.md` desync observed during `verify-deploy.sh --deep` runs in this
  session (caused by concurrently-running sibling tasks in the same batch, outside this task's
  file scope) was recorded in the issue log at each phase it was observed; not fixed here since it
  is not this task's own file_scope.

## References

- Plan: `specs/427_dispatch_composer_emits_contradictory_authoritative_inputs/plans/01_dispatch-prior-decision-precedence.md`
- Report: `specs/427_dispatch_composer_emits_contradictory_authoritative_inputs/reports/01_dispatch-prior-decision-precedence.md`
- Handoffs: `specs/427_dispatch_composer_emits_contradictory_authoritative_inputs/handoffs/`
- Progress: `specs/427_dispatch_composer_emits_contradictory_authoritative_inputs/progress/`
