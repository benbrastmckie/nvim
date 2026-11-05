# Implementation Summary: Task #388

- **Task**: 388 - Fix prune_next_body() mis-parsing a Run line when a CLI flag precedes the rationale comment.
- **Status**: [COMPLETED]
- **Started**: 2026-10-14T15:17:00Z
- **Completed**: 2026-10-14T18:00:00Z
- **Effort**: ~3.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_prune-next-body-flag-misparse.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed a silent-content-loss defect in `prune_next_body()` (and its sibling
`count_pruned_next_ids()`) in `roadmap-integration.sh`: a trailing CLI flag on a Run line (e.g.
`/orchestrate 716,714 --hard   # rationale`) was fused into the task-id list by an
overly-broad whitespace strip, causing an active task to be silently dropped from the roadmap's
Run order -- in the worst case (a single-task flagged line), the entire line vanished. Both
functions now segment the flag portion off before the whitespace collapse, re-splice it verbatim
into every output branch, and fail safe (unchanged line + stderr warning) on any id token they
cannot classify as numeric. Added 25 new flag-bearing `--prune` test cases across both the
classic and stage roadmap layouts, extended `roadmap-format.md`'s Next Grammar to formally admit
the flag segment, and redeployed. A real end-to-end test run also surfaced and fixed an unrelated
bash-quoting bug in the new fail-safe warning message.

## What Changed

- `agent-system/extensions/core/scripts/roadmap-integration.sh` -- `prune_next_body()`: segments
  an optional flag portion off the task-id list on the first whitespace-preceded `-` (not the
  first run of whitespace, which would mis-split a grammar-legal intra-list space), right-trims
  before segmenting, applies the whitespace collapse to the id list only, re-splices the flag
  verbatim into the partial-keep output branch, and fails safe on a non-numeric id token.
  `count_pruned_next_ids()`: mirrors the same flag cut and adds a numeric guard before the
  `jq --argjson` lookup so a non-numeric token can never be mis-read as "not active."
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` -- added "Case group
  3b" (classic layout) and "Phase 5b" (stage layout), each a dedicated, isolated fixture covering
  all 7 plan-listed scenarios plus an all-terminal-flagged absence case and a non-numeric-id
  fail-safe case (9 Run lines, 25 assertions total across both layouts).
- `agent-system/extensions/core/context/formats/roadmap-format.md` -- extended the `## Next
  Grammar` Run-line pattern and the `## Parsing Patterns Summary`'s matching row to
  `^/orchestrate ([\d, ]+)(\s+(-\S.*?))?(\s{3}# (.+))?$`, added prose stating the round-trip
  guarantee and that no arbitrary trailing text is admitted beyond the flag segment.

## Decisions

- Anchored flag-segment detection on the first whitespace-preceded `-`, deliberately departing
  from the research report's Recommendation 1 (first run of whitespace), which would mis-split
  the grammar-legal `716, 714 --hard`.
- Added the new test fixtures as entirely separate, isolated blocks/fixture-writer functions
  rather than mutating the shared fixtures other case groups already depend on.
- Closed Phase 5 via `[COMPLETED WITH EXCLUSIONS]` rather than `[PARTIAL]`: three pre-existing,
  confirmed-unrelated `verify-deploy.sh` findings (a hanging literature-extension test suite, a
  lean-extension doc-lint gap, and a 225 B eager-load-budget overage) were excluded with full
  evidence rather than attempted, since none touches any of this task's three files and fixing
  any of them would be unauthorized scope-widening.

## Plan Deviations

- **Phase 3**: during full end-to-end `--prune` verification, discovered and fixed a bash-quoting
  bug in Phase 1's own fail-safe warning (a literal single quote embedded inside the awk
  program's bash single-quoted script delimiter corrupted the emitted stderr message). Not caught
  by Phase 1's own isolated scratchpad harness, which happened to use correct quote-escaping when
  re-typing the function. Fixed by switching the warning's id delimiters to square brackets.
- **Phase 5**: reported a system-wide resource incident (a concurrent sibling's repeated hang on
  an unrelated literature-extension test driving system load to 50+ on a 24-core machine) to the
  main/orchestrating session, and closed the phase via a documented Reasoned Exclusions record
  rather than a literal `verify-deploy.sh` exit 0 (see that record in the plan for full evidence).

## Verification

- Build: N/A (bash/awk scripts, no compile step)
- Tests: Passed -- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
  test-roadmap-generation.sh,test-skill-base-lifecycle.sh,test-sweep-invalidated-claims.sh` exits
  0; all 25 new flag-coverage assertions pass; anti-vacuity confirmed (reverting Phase 1's fix in
  a scratch copy makes 20 of the 25 new assertions fail); the full `verify-deploy.sh` gate set
  passes except for three pre-existing, evidenced, unrelated exclusions (see Phase 5's Reasoned
  Exclusions record).
- Files verified: Yes -- all three edited files confirmed byte-identical between source store and
  deployed tree after redeploy.

## Impacts

- A live roadmap authoring a CLI flag on a Run line (the shape that originally surfaced this
  defect in a consumer repository) no longer silently loses active tasks or the flag itself on
  `--prune`.
- `count_pruned_next_ids()`'s diagnostic `pruned=`/`retained=` stderr counters are now accurate on
  flag-bearing input.
- `roadmap-format.md`'s documented grammar now matches what live roadmaps already author.

## Follow-ups

- `covered_ids_from()` (a separate, pre-existing defect: it scrapes all digits from the whole Run
  line including rationale prose and numeric flag arguments) remains unfixed -- explicitly out of
  scope per this task's Non-Goals; recorded to the issue log for a future task.
- The three Phase 5 Reasoned-Exclusions items (the hanging zotero test suite, the lean doc-lint
  gap, and the eager-load budget overage) remain open for their respective owning tasks.

## References

- Plan: `specs/388_prune_next_body_flag_misparse_drops_active_task/plans/01_prune-next-body-flag-misparse.md`
- Research report: `specs/388_prune_next_body_flag_misparse_drops_active_task/reports/01_prune_next_body_flag_misparse.md`
- Issue log: `specs/388_prune_next_body_flag_misparse_drops_active_task/issues.jsonl`
