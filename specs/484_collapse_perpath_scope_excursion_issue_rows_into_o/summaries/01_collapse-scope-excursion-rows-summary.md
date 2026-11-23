# Implementation Summary: Task #484

- **Task**: 484 - Collapse per-path scope excursion issue rows into one record per drop event
- **Status**: [COMPLETED]
- **Started**: 2026-11-23T06:40:00Z
- **Completed**: 2026-11-23T09:40:00Z
- **Effort**: ~3 hours
- **Dependencies**: Serialized behind #430, #446, #469 per the plan's Serialization Note
- **Artifacts**: plans/01_collapse-scope-excursion-rows.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Both "scope excursion" emitters (`git-commit-phase.sh`'s Phase-Commit Containment Self-Check and
`git-commit-scoped.sh`'s V10 guard) previously wrote one `issue-record.sh` call per dropped path
from inside their per-path loops, so a single drop event touching many out-of-scope paths wrote
many near-identical `issues.jsonl` rows. A new shared library,
`scripts/lib/scope-excursion-record-lib.sh`, gives both emitters one call site that accumulates
a drop event's paths and fires exactly one collapsed `issue-record.sh` call afterward, carrying
the full dropped-path set through the `--tags-json` seam as `tags.dropped_paths` plus
`tags.occurrence.{count,first_seen,last_seen}`. No change was made to `issue-record.sh`'s
schema/CLI or to `orchestrate-conclusion-aggregate.sh`'s grouping pipeline: both already treat
`tags` as an opaque validated object and group by `class`, so the collapsed shape groups
identically to pre-existing single-path rows with no backfill.

## What Changed

- `agent-system/extensions/core/scripts/lib/scope-excursion-record-lib.sh` — new; one public
  function (`scope_excursion_record_emit`) that builds the collapsed `--tags-json` payload and
  fires a single non-fatal `issue-record.sh` call per drop event, with a `jq`-absent fallback
  that inlines every dropped path into `what_happened` instead (never fewer paths, only fewer
  rows/no `--tags-json`).
- `agent-system/extensions/core/scripts/tests/test-scope-excursion-record-lib.sh` — new; 8
  cases covering the collapsed shape, both tolerances (absent `issue-record.sh`, `jq`-absent
  fallback), and a repo-wide guard asserting this library is the only non-test site emitting
  the `scope excursion` class literal.
- `agent-system/extensions/core/scripts/git-commit-phase.sh` — the Phase-Commit Containment
  Self-Check now accumulates its drops (with measured `first_seen`/`last_seen`) and fires one
  post-loop `scope_excursion_record_emit` call instead of one `issue-record.sh` call per
  dropped path; the per-path `warn()` and `propose_file_scope_addition()` calls are unchanged.
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` — V10's containment guard now
  fires one post-loop collapsed call over its pre-existing `containment_dropped` ledger,
  placed before the V13/V3 exit-code decisions so the record lands whether the commit that
  follows succeeds, fails, or is never attempted.
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` — two new cases (a
  three-path drop collapsing into one record; the record still firing when the drop is
  followed by a failed commit), 106 pre-existing cases pass unmodified (112/112 total).
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` — two new cases (a
  three-pathspec drop collapsing into one record; the record still firing on the V3
  all-dropped refusal), 88 pre-existing cases pass unmodified (93/93 total).
- `agent-system/extensions/core/manifest.json` — registers the two new files in
  `provides.scripts`.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — corrects the "Three
  Containment sites, not one" passage: only the two commit-wrapper sites (`git-commit-phase.sh`,
  `git-commit-scoped.sh`) fire an issue row; the postflight-sited filter prints its own per-path
  notice to stderr but never calls `issue-record.sh`.
- `agent-system/extensions/core/context/formats/issue-log.md` — cross-references the new
  library from the "Occurrence Collapse" section as that convention's concrete implementation.
- `agent-system/extensions/core/index-entries.json` — regenerated `line_count` for the two
  touched doc entries.
- A regenerated deployed `.claude/` tree (via `deploy-headless.sh`).

## Decisions

- **Representation**: a full `tags.dropped_paths` array (never a bounded sample) plus
  `tags.occurrence.{count,first_seen,last_seen}` — preserves the no-suppression posture, since
  no other durable store of the dropped-path set exists.
- **Collapse site**: the two emitters, through one shared library function, rather than an
  `issue-record.sh` CLI change (unnecessary — `--tags-json` already carries everything) or a
  read-time-only scheme (cannot recover which rows belong to one drop event without a
  write-side marker).
- **Library call-site shape**: refactored mid-implementation from two call sites (one per
  jq-present/jq-absent branch, each with its own `--class "scope excursion"` literal) to one
  shared call site, after the repo-wide guard case found 2 occurrences inside the library's own
  file — the plan's stated goal of "exactly one non-test home" required a single literal, not
  one per library, so the library itself was tightened to match.
- **Third-site asymmetry**: corrected the doc to match the code (the postflight-sited filter
  never fired an issue row) rather than adding a third emitter — out of this task's scope.
- **Severity and posture**: `--severity minor` and drop-and-warn preserved byte-for-byte at
  both sites.

## Plan Deviations

- None (implementation followed the plan). The library call-site refactor noted above was a
  correction surfaced by the plan's own Phase 4 verification step, not a deviation from its
  stated design — the plan explicitly named "exactly one non-test home" as the goal.

## Verification

- Build: N/A (bash scripts; `bash -n` syntax checks passed on both emitter edits)
- Tests: Passed — `test-scope-excursion-record-lib.sh` 8/8,
  `test-git-commit-phase.sh` 112/112 (106 pre-existing + 2 new),
  `test-git-commit-scoped.sh` 93/93 (88 pre-existing + 2 new),
  `test-orchestrate-conclusion-aggregate.sh` 21/21 unmodified.
- Corpus re-verification: a scratch fixture mixing two old-style single-path rows and one new
  collapsed row grouped into one proposal via `orchestrate-conclusion-aggregate.sh` with all
  three citations present — no backfill needed.
- Deploy: `deploy-headless.sh` landed clean on the second attempt (41/41 fast-gate checks) after
  fixing a missing shebang (shellcheck SC2148) and four missing
  `common_test_declare_subject` calls (subject-resolution declaration lint) surfaced by the
  first attempt's `RESULT=landed_verify_red`.
- Scoped touched-path check: `bash .claude/scripts/verify-touched.sh` (no arguments) — 60
  mapped suites (60/60 passed) plus the 10-path OWED `--cost-class free` fallback battery
  (98/98 passed), 0 failures. The complete gate set is deferred to the orchestration's
  once-per-invocation batch gate stage per this dispatch's Batch Gate Deferral directive.
- Files verified: Yes (both new files confirmed present in the deployed tree post-redeploy).

## Impacts

- A future multi-file drop event (e.g. a phase legitimately touching many migrated test
  suites) now produces one readable `issues.jsonl` row instead of dozens of near-identical
  ones, restoring the aggregate signal for the "scope excursion" class at conclusion-stage
  tallying.
- The existing `issues.jsonl` corpus (single-path rows) remains fully parseable and groups
  correctly alongside new collapsed rows with no migration.
- `scope-excursion-record-lib.sh` is now the concrete, copyable implementation of
  `issue-log.md`'s "Occurrence Collapse" write-side convention for any future caller with the
  same precondition.

## Follow-ups

- The sibling "source store excursion" per-path fan-out in `git-commit-phase.sh` has the
  identical shape under a different class name and was deliberately left untouched (the
  task's required outcomes are worded around the "scope excursion" class specifically) —
  recorded as a follow-up candidate, not acted on here.
- Giving the postflight-sited Containment filter (`orchestrate-cycle-postflight.sh`'s WORK
  (h)/(i)) its own batched `issue-record.sh` call, achieving true three-site parity, is left to
  a separately-scoped follow-up; this task only corrected the doc to match the code's current
  two-site posture.
- `file_scope` calibration, infrastructure-path allowlisting, and class-vocabulary
  normalization remain owned by #430, #446, #469, and #477 respectively — this task took no
  position on any of them.

## References

- Research: `specs/484_collapse_perpath_scope_excursion_issue_rows_into_o/reports/01_collapse-scope-excursion-rows.md`
- Plan: `specs/484_collapse_perpath_scope_excursion_issue_rows_into_o/plans/01_collapse-scope-excursion-rows.md`
- Handoffs: `specs/484_collapse_perpath_scope_excursion_issue_rows_into_o/handoffs/phase-{1..5}-handoff-*.md`
