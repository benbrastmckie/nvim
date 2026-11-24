# Implementation Summary: Task #639

- **Task**: 639 - Make issue-record.sh failures visible instead of silently losing the evidence entry
- **Status**: [COMPLETED]
- **Started**: 2026-11-24T05:00:00Z
- **Completed**: 2026-11-24T05:35:00Z
- **Effort**: ~35 minutes
- **Dependencies**: None
- **Artifacts**: plans/01_refusal-entry-visibility.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`scripts/issue-record.sh` previously refused an unrecognized flag with `error: unknown
argument: ...` on stderr and `exit 1`, and the documented non-fatal invocation form
(`>/dev/null 2>&1 || echo "Note: ..." >&2`) discarded that diagnostic, so a mistyped flag
silently dropped the caller's intended evidence entry with no attributable signal. This
implementation makes the dropped entry self-recording instead of merely announced: an
argument-shaped refusal now appends one schema-valid refusal entry into the resolved task's own
`issues.jsonl`, carrying the offending flag and the caller's own `--what-happened` prose
verbatim, and exits a new, distinct code `2`.

## What Changed

- `agent-system/extensions/core/scripts/issue-record.sh` — the `*)` parse-loop arm now records
  the offending flag into `unknown_arg` and `break`s instead of calling `usage()` immediately.
  A new refusal-mode block forces `kind=issue`, `class="knowledge-capture gap"`,
  `severity=minor`, synthesizes `what_happened` naming the flag and quoting the caller's own
  `--what-happened` verbatim (or stating none was parsed), clears every other optional field
  (preserving a malformed `--tags-json` only as `tags.issue_record_refusal.caller_tags_json`),
  and clears a non-integer `--dispatch-seq`. A new `exit_refusal_aware()` helper routes the four
  reachable refusal sites (`usage()`'s own exit, and the three task-directory-resolution sites)
  to exit `2` when `unknown_arg` is set, `1` otherwise — every content-shaped refusal is
  unchanged. The header's invocation-contract comment and exit-code block now document code `2`.
- `agent-system/extensions/core/scripts/tests/test-issue-record.sh` — four new regression cases
  (w) mistyped flag under the documented non-fatal form, (x) exit-code discrimination (2 vs 1),
  (y) refusal mode under a concurrent malformed `--tags-json`/`--dispatch-seq`, (z) the
  unresolvable-task-directory residual. All four were confirmed to fail against pre-change
  behaviour (non-vacuous).
- `agent-system/extensions/core/context/formats/issue-log.md` — extended the "Recording is
  always non-fatal" bullet and added an "Argument-Shaped Refusal Entries" subsection documenting
  the entry shape, exit code `2`, and the stated residual.
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — one static sentence in
  the rendered `## Issue Log` block pointing a dispatched agent at the refusal entry when its
  fallback note fires.
- `agent-system/extensions/core/index-entries.json` — regenerated `line_count` for the
  `formats/issue-log.md` entry (334 -> 376).

## Decisions

- Adopted the research report's candidate 2 (separate the argument-shaped refusal by exit code)
  with the refusal written directly into `issues.jsonl` rather than a sibling breadcrumb file —
  this is read by the existing conclusion-stage consumer with no consumer change and needs no
  new runtime-file registry entry.
- Declined flag-aliasing (candidate 1, fixes only one typo) and contract-wide stderr
  unswallowing (candidate 3, ~20 call sites plus a file outside this task's `file_scope`).
  Adopted candidate 3 only at the one hand-typed surface (`orchestrate-build-dispatch.sh`'s
  rendered template) as a static discoverability pointer.

## Plan Deviations

- Phase 4: `verify-touched.sh`'s scoped run showed 22 of 23 selected suites green; the one
  failure (`test-orchestrate-conclusion-roadmap.sh` Case H) was excluded as unrelated to this
  task — traced to concurrent sibling tasks 691/692 reshaping the stack-based PR/merge flow,
  outside this task's declared `file_scope`. Closed `[COMPLETED WITH EXCLUSIONS]` with a full
  Reasoned Exclusions record and a cross-task `issue-record.sh` entry
  (`iss_1795497640271_xQnaY2`).

## Verification

- Build: N/A (bash scripts)
- Tests: Passed — `test-issue-record.sh` 31/31 (source-store and default deployed modes),
  `test-orchestrate-build-dispatch.sh` 238/238, `test-orchestrate-cycle-plan.sh` 472/472
  (including Group 27 Case F), `generate-context-line-counts.sh` check mode clean.
- Files verified: Yes

## Impacts

- Every caller of `issue-record.sh` (every dispatch kind, per `phase-closure.md`'s mandatory
  recording obligation) now recovers an attributable record of a mistyped flag instead of
  silently losing the intended evidence entry — directly closing the silent-data-loss path the
  orchestration conclusion stage's evidence base depended on.
- No change to any of the ~20 existing non-fatal call sites' invocation text or to any
  content-shaped refusal's behavior (missing required field, unresolvable `--task`, invalid
  closed-set value, etc.) — all byte-for-byte unchanged (27 pre-existing cases (a)-(v) still
  pass).

## Follow-ups

- None for this task. The unrelated `test-orchestrate-conclusion-roadmap.sh` Case H failure is
  recorded separately (`iss_1795497640271_xQnaY2`) for the batch's own conclusion stage to pick
  up against tasks 691/692's stack-mode merge flow work.

## References

- `specs/639_make_issue_record_failures_visible/plans/01_refusal-entry-visibility.md`
- `specs/639_make_issue_record_failures_visible/reports/01_issue-record-failure-visibility.md`
- `agent-system/extensions/core/scripts/issue-record.sh`
- `agent-system/extensions/core/scripts/tests/test-issue-record.sh`
- `agent-system/extensions/core/context/formats/issue-log.md`
