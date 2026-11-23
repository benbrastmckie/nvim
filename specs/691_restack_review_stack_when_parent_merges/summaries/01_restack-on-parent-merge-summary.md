# Implementation Summary: Task #691

- **Task**: 691 - Restack review stack when parent merges
- **Status**: [COMPLETED]
- **Started**: 2026-11-23T22:50:00Z
- **Completed**: 2026-11-23T23:23:04Z
- **Effort**: ~1.5 hours
- **Dependencies**: None (the parent plan's Phase 3 had already landed)
- **Artifacts**: plans/01_restack-on-parent-merge.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Implemented the `restack` subcommand of `review-stack-prepare.sh`: detecting a merged
bottom-of-stack entry (by ancestry or squash test, or an operator-supplied `--merged NN`
override), recomputing every surviving descendant's commit onto the review base's new
remote-tracking tip, and moving each descendant's ref by compare-and-swap, or refusing by name
on anything unresolvable or conflicting. All three plan phases landed and closed `[COMPLETED]`
in one dispatch; the suite grew from 38 to 61 passing cases with no pre-existing case or
assertion edited.

## What Changed

- `agent-system/extensions/core/scripts/review-stack-prepare.sh` — added the `restack`
  subcommand in full: the `--merged NN` flag (distinct from cut's `--merge N+M`), the dispatch
  arm, `rsp_restack_load_manifest`, `rsp_restack_plan` (ref resolution and refusals),
  `rsp_restack_detect_merged`/`rsp_restack_compute_disposition` (bottom-up detection per D1,
  `--merged` override per D3), `rsp_restack_recompute` (off-tree descendant recompute per D4),
  `rsp_restack_print` (disposition, no-op/stale-stack reports, operator commands), and
  `rsp_restack_execute` (compare-and-swap ref moves, manifest rewrite). Added exit codes 53
  (`review_base_remote_ref_absent`) and 54 (`review_base_ref_divergence`). Extended
  `rsp_show_stack`'s human-readable output with a `state=` column (D5). Reconciled the header's
  `USAGE`/`EXIT CODES` blocks and the `restack`/`show` prose. Fixed a latent `$(...)`-subshell
  bug in the shared `rsp_move_commit_onto_new_parent` primitive (see Plan Deviations).
- `agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh` — added 23 new
  cases across the three phases (8 + 9 + 6), plus three new fixture helpers
  (`restack_fixture_repo`, `restack_set_remote_tracking`, `restack_build_chain`) and an
  `entry_field`-style reader (`restack_entry_field`). The pre-existing 38 cases and both static
  assertions are present unmodified (confirmed via `git diff`, additions only).

## Decisions

- D1's squash test reuses the SAME refusing `rsp_move_commit_onto_new_parent` the real
  descendant recompute uses (PD6: one primitive serves both call sites), rather than a separate
  non-refusing probe — a conflict during detection refuses (48) immediately, exactly as a
  conflict during the real recompute does.
- The review base's remote-tracking ref is resolved at `refs/remotes/<remote>/<review_base>`,
  the same convention cut already uses for stack branches; this requires `review_base` to be a
  branch-shaped ref for restack specifically (documented via the new `restack_fixture_repo` test
  helper, which declares `review_base` as a dedicated branch rather than reusing the tag the
  cut suite's own fixtures use).
- The local/remote-tracking divergence refusal (54) fires whenever the review base's local ref
  is not an ancestor of its remote-tracking ref (covers both "local ahead" and a true fork); the
  ordinary "remote moved ahead" case never refuses.
- `show`'s new `state=` field is appended at the end of its existing PR line so the pre-existing
  substring assertion checking `branch=... base=... title=... body_path=...` stays intact.

## Plan Deviations

- None against any named task. One latent bug, unrelated to any specific task but necessary to
  fix for this phase's own deliverable to work: `rsp_move_commit_onto_new_parent` (shared by cut
  and restack) returned its result tree via stdout captured in `"$(...)"` at all three call
  sites; a refusal's `exit 48` inside that command-substitution subshell only terminates the
  subshell, silently swallowing the refusal. Never triggered by the existing 38-case cut suite
  (no conflicting-cut case exists), but immediately triggered by this phase's own required
  "conflicting descendant refuses 48" case. Fixed by switching the function to set a global
  `RSP_MOVE_RESULT_TREE` and calling it as a plain statement at all three call sites, matching
  the file's own documented resolver convention. Logged via `issue-record.sh`. The 38
  pre-existing cut cases still pass unmodified.

## Verification

- Build: N/A (bash script)
- Tests: Passed — `test-review-stack-prepare.sh`: 61 passed, 0 failed (38 original unmodified +
  23 new); both static assertions pass with source lines byte-identical to their pre-task form.
- Files verified: Yes — `verify-touched.sh` resolved both touched files to exactly
  `test-review-stack-prepare.sh` at every phase close, no sentinel.
- Lints: `check-task-references.sh` and `check-record-versioning.sh` report 0 occurrences on
  both touched files.
- Redeploy: `bash .claude/scripts/deploy-headless.sh` — `RESULT=landed_verify_clean`, 41
  checks/0 failures; `.claude/` is gitignored, nothing new to commit there.
- Batch gate: this task's Phase 3 declared `full` tier was discharged via the scoped
  `verify-touched.sh` invocation per this dispatch's Batch Gate Deferral directive; the complete
  gate set is deferred to the once-per-invocation batch-level close, not run independently here.

## Impacts

- Operators can now run `restack --stack-id NAME [--merged NN]` after a stack's bottom PR
  merges, to move every surviving descendant onto the review base's new tip without ever
  fetching, pushing, or touching HEAD/the index/the working tree.
- `show`'s human-readable output now surfaces which entries have merged without reaching for
  `--json`.
- The `rsp_move_commit_onto_new_parent` bugfix also makes `cut`'s own (previously untested)
  conflict-refusal path correct, should a future case exercise it.

## Follow-ups

- None required by this task. The parent design record's remaining territory (if any) continues
  under its own file scope.

## References

- Plan: `specs/691_restack_review_stack_when_parent_merges/plans/01_restack-on-parent-merge.md`
- Parent design record: `specs/685_stack_pr_submission_from_integration_branch/plans/01_stack-pr-submission.md`
  (Phase 4)
- Script: `agent-system/extensions/core/scripts/review-stack-prepare.sh`
- Suite: `agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh`
- Handoffs: `specs/691_restack_review_stack_when_parent_merges/handoffs/phase-{1,2,3}-handoff-*.md`
