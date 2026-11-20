# Implementation Summary: Task #654

- **Task**: 654 - Reconcile the open commit-layer cluster and write its dependency ordering
- **Status**: [COMPLETED]
- **Started**: 2026-11-20T08:50:00Z
- **Completed**: 2026-11-20T09:50:00Z
- **Effort**: 1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_commit-layer-cluster-rulings.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

All thirteen cluster members now have a ruling backed by a state change. Seven dependency edges and seven description appends are in `specs/state.json`, and the decision record is at `specs/decisions/commit-layer-cluster-ordering.md`. No script and no file outside `specs/` was edited.

## What Changed

- `specs/state.json` — seven new dependency edges: 535 after 567, 486 after 541, 501 after 570, 536 after 524, 553 after 536, 657 after 553, 655 after 513.
- `specs/state.json` — appended description blocks on 513, 535, 536 and 592 (the four NEEDS REVISION rulings), on 570 (re-measured blind spot and an attribution request), and on 655 and 657 (pointers to the record and the inputs they must design for). Each block opens with `RE-MEASURED AND RULED (commit-layer cluster ordering`.
- `specs/TODO.md` — regenerated from `state.json`.
- `specs/decisions/commit-layer-cluster-ordering.md` — new decision record: fourteen ruling rows, seven edges, three judgment calls, re-measured premises, inputs to the branch feature, residual overlaps, and how it was checked.
- `specs/654_reconcile_commit_layer_cluster_and_ordering/baseline.json` — before-state of the fifteen affected tasks, and the audit results.

## Decisions

- Tally: NEEDS EDGE 7 (486, 501, 524, 541, 553, 567, 570), NEEDS REVISION 4 (513, 535, 536, 592), UNAFFECTED 2 (508, 517), SUBSUMED 0.
- Judgment 1: no. Neither source-store commit scoping nor the third containment site is a hard prerequisite for branch targeting; both precede the branch tasks by file territory only.
- Judgment 2: no. The starting-position task and an admission-time branch check are separate defects; the dispatch composer stays the fix site.
- Judgment 3: yes. One detector with an expected-ref parameter covers commit existence and branch target; the branch task now depends on it.
- Edge 6 sits on 657, as the plan decided.
- Baseline saved all fifteen descriptions, not only the seven being changed, so the "other eight unchanged" check is an exact comparison.

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A
- Tests: Passed. `verify-touched.sh` exit 0 (98 passed, 0 failed; 58 suites selected, 3 paths owed). Its touched set was the ten uncommitted working-tree paths, nine of them sibling or runtime files; this task's own files were already committed and were not in the set.
- State: `validate-state.sh --deep` exit 0 before, after the edges, after the appends, and at the end (21 passed, 10 warnings, 0 failed each time).
- Edges: all seven present by jq; each target gained exactly one dependency and lost none. All seven writes passed the write-time cycle refusal. Drain dry-run over the twelve chained tasks: no cycle, no stop.
- Descriptions: the heading-line query lists exactly 513, 535, 536, 570, 592, 655, 657. Each begins with its baseline text; the other eight are identical to baseline.
- Audit: 7 of 7 NEEDS EDGE members in an edge, 4 of 4 NEEDS REVISION members revised, 2 of 2 UNAFFECTED members unchanged.
- Full gate set: deferred to the batch-level stage at orchestration close; not run in this dispatch.
- Files verified: Yes

## Impacts

- 657 now waits for the whole commit-layer chain (567, 535, 541, 486, 501, 524, 536, 553), and 655 waits for 657 and 513.
- 570 and 513 are also gated by open tasks outside the chain (519 and 479), so the chain cannot drain without them.
- 535 and 536 should be planned from their appended blocks, not their original text, which is stale against the source store.

## Follow-ups

- The record's "33 unordered pairs before, 0 after" and "123 open tasks sorted" figures come from the research simulation and were not re-run.
- The 570 ignored-specs blind spot and the 513 no-commit exemption are read from code, not reproduced in a fixture.
- Overlaps between cluster members and open non-members (548, 598, 484, 639, 551, 609, 472, 520, 571, 618) remain unordered; the record lists them.
- Uncommitted files not made by this dispatch were in the working tree throughout: `.claude-extensions.json`, `.pid`, and plan and `.return-meta.json` files under `specs/658_*` and `specs/660_*`.
- `records/full-sweep-owed.jsonl` in this task directory carries owed rows for two sibling plan paths, written by `verify-touched.sh`.

## References

- specs/654_reconcile_commit_layer_cluster_and_ordering/plans/01_commit-layer-cluster-rulings.md
- specs/654_reconcile_commit_layer_cluster_and_ordering/reports/01_commit-layer-cluster-rulings.md
- specs/decisions/commit-layer-cluster-ordering.md
- specs/654_reconcile_commit_layer_cluster_and_ordering/baseline.json
