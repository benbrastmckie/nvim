# Implementation Summary: Task #695

- **Task**: 695 - Design the /slice command: one clean path from work branch to a stack of review pull requests
- **Status**: [COMPLETED]
- **Started**: 2026-11-24T00:15:54Z
- **Completed**: 2026-11-24T01:55:00Z
- **Effort**: one implement dispatch, five phases
- **Dependencies**: None
- **Artifacts**: plans/01_slice-command-design.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

This task ruled and built nothing. It wrote one new decision record,
`specs/decisions/slice-command-one-path-to-review.md`, which rules the `/slice` command, names the
single surviving mechanism and every file to be deleted, gives a verdict for each listed open
record, and amends two existing records by dated notes. Every claim about an existing
implementation was re-derived from live files and live forge reads before the ruling was written.

## What Changed

- `specs/decisions/slice-command-one-path-to-review.md` — Created (857 lines): Evidence E1 to E9,
  command surface, mechanism, basis, review base, size bar, survivor and deletion table, grants,
  constraints, rejected alternatives, verdicts, successors, operator worklist, what is discarded,
  risks, assertions amended.
- `specs/decisions/review-slices-are-declared-tasks.md` — Dated `**Amended by**` note added under
  the opening paragraph (8 lines added, none changed).
- `specs/decisions/isolation-off-landing-verification-and-review-time-squash.md` — Second dated
  `**Amended by**` note added (6 lines added, none changed).

## Decisions

- **One survivor.** `/slice`: a user-invoked command over one script (`check`, `build`,
  `status`) and one series file. A slice is a declared path set cut from the work-ref tip, built
  by a private-index overlay. No inference code.
- **Basis: neither builder.** `review-stack-prepare.sh` and its suite are deleted. The sf1-engine
  builder is not promoted: it has opened no pull request, and 993 of its 2,187 lines are one
  repository's gate and report template. Six of its design properties carry upstream.
- **No review base.** Two roles, work ref and target. The target is chosen at a prompt that shows
  each candidate's measured difference; the `review_base` key and its name-equality refusal go.
- **Size bar: approved, then enforced.** Declared `slice_bar`, else the nearest-rank 75th
  percentile of merged pull requests on the target (n at least 5), else an unmeasured default;
  printed with its source, revisable at the prompt, then a refusal at build with a recorded-reason
  escape. This goes beyond the research report, because this repository's own measured bar is 52
  lines and 1 file, drawn from the wrong population.
- **`/merge` removed, not fixed**, after `/slice` has opened one real pull request. `/merge
  --stack` is never built.
- **Verdicts.** 690 survives unchanged; 692, 694 and 655 survive revised; 693 and the five held
  records (670, 671, 672, 674, 686) are to be abandoned; 509 is unaffected and one obligation on
  it lapses. Verdicts are a worklist for the operator and were not executed.
- **Corrections to carried claims** (record section E9): the sf1-engine builder has opened zero
  pull requests, not 22; there are three builders, not two; seven mechanism rows, not five;
  `/merge`'s target is an overridable default; `stack_cut.py` cuts whole files, not hunks, and
  does not compare-and-swap; this repository has 12 merged pull requests, not none.

## Plan Deviations

- **Task 1.5** altered: `stack_cut.py` was read in full for its schema, cut, size and restack
  paths (lines 1 to 110, 369 to 640, 727 to 741, 861 to 906) and by signature and docstring for
  the rest; that sufficed to correct the "hunk-level" claim.

## Verification

- Build: N/A
- Tests: `test-review-stack-prepare.sh` re-run from the source store as evidence: 61 passed, 0
  failed. Scoped touched-path check over the three touched files: "touched-path run complete -- 0
  suite(s) selected, 3 owed, 0 no-suite-by-class, across 3 touched path(s)"; its owed fallback ran
  98 suites, 98 passed, 0 failed. This is an owed classification, not a full-battery pass.
- Full gate set: deferred to the batch-level stage under the dispatch's Batch Gate Deferral
  directive; not run independently in this dispatch.
- Files verified: Yes. `git diff --numstat` on the two amended records shows additions only. No
  change under `agent-system/**` or `.claude/**` in `fbdccb9dd..HEAD`. The plan artifact validates.
- Plan-revision sentinel: `.plan-revised.json` absent at every phase's pre-write check.

## Impacts

- 692 and 693 are `planned` against the ruling this record overturns and depend on 695; their
  plans must not be implemented as written.
- The five held worktree and two-root records lose their review-side rationale.
- The task's recorded `file_scope` lists four `agent-system/**` paths that this task did not
  touch; they belong to the successors.
- `/slice` itself has no production evidence; the first successor's acceptance is one real slice
  pushed and opened by the operator.

## Follow-ups

- Operator: apply the record's "Operator worklist" (abandon 693 and the five held records, or
  hold them with a rewritten reason; revise 692, 694, 655; create successors 1, 2, 3, 5, 6).
- Operator preference open at no cost: 75th percentile against another opening offer for the
  measured bar.
- Not read: the stack-PR design record (its PD rulings lose their subject with the script).

## References

- `specs/decisions/slice-command-one-path-to-review.md`
- `specs/695_slice_command_design_and_consolidation/plans/01_slice-command-design.md`
- `specs/695_slice_command_design_and_consolidation/reports/01_slice-command-design.md`
- `specs/decisions/review-slices-are-declared-tasks.md`
- `specs/decisions/isolation-off-landing-verification-and-review-time-squash.md`
- `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md`
