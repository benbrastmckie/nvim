## Immediate Next Action

All phases complete -- proceed to Stage 5 (implementation summary) and Stage 7 (metadata write).

## Current State

All five phases are closed in the plan file: Phases 1-4 `[COMPLETED]`, Phase 5
`[COMPLETED WITH EXCLUSIONS]`. The "Phase Commit (mid-dispatch)" subsection is authored in
`git-staging-scope.md`, cross-referencing the existing `### implement` section and the
"Three Containment sites" paragraph rather than restating them. The whole edited file was
re-read once end-to-end for internal consistency (table, gate-label list, and the two new
subsections all agree).

The full gate set (`verify-deploy.sh` against the repo root, including the unabridged `run-all.sh`
battery of 162 suites) was run twice -- once under heavy concurrent system load from other
sessions, once again after confirming (`ps aux`) zero other verify-deploy/run-all processes were
running. Both runs agree on the same five findings, all recorded with evidence in Phase 5's own
`#### Reasoned Exclusions` table:

1. Deployed-script content drift for `test-git-commit-scoped.sh` (deploy-boundary skew).
2. `index-entries.json` `line_count` staleness for `git-staging-scope.md` (deploy-boundary skew;
   the remedy script refuses to run outside a deployed tree).
3. The same content-drift finding surfaced a second time by the manifest-driven verification
   gate (gate 5).
4. `test-run-all-selection.sh` case1/case1b/case3 -- confirmed pre-existing and unrelated via
   `git log`/`git status` on both the test file and `suite-selection-lib.sh` (neither touched by
   this task).
5. `test-gate-cache-equivalence.sh`'s cold-baseline/negative-case assertions -- confirmed
   pre-existing and unrelated the same way, and reproduced identically once concurrent load was
   confirmed idle (ruling out a load-induced flake).

This task's own declared `file_scope` (`git-commit-scoped.sh`, `git-staging-scope.md`,
`test-git-commit-scoped.sh`) and the directly-related `test-git-commit-phase.sh` are all
independently confirmed green -- `bash agent-system/extensions/core/scripts/tests/run-all.sh
--only test-git-commit-scoped.sh,test-git-commit-phase.sh` reports 2 passed, 0 failed.

An `issue-record.sh` entry (`--class "unrelated test corpus defect"`, severity minor) was filed
non-fatally, per the dispatch's own Issue Log instruction, documenting findings 4 and 5 for a
future dispatch to pick up independently of this task.

## Key Decisions Made

- The "Phase Commit (mid-dispatch)" subsection forward-references were resolved: the "Three
  Containment sites" paragraph's own forward-reference to this subsection (added in Phase 4) now
  resolves correctly.
- `[COMPLETED WITH EXCLUSIONS]` was chosen over plain `[COMPLETED]` for Phase 5, applying the
  five-condition admission test in `context/standards/status-markers.md` honestly: the phase's
  own stated verification ("run and observed green") is not literally satisfied once the five
  findings above are counted, but every one is a decided, tightly-scoped, documented, evidenced
  exclusion with no residual work for this task (either a deploy-boundary artifact outside this
  task's reach, or a corpus-wide pre-existing defect this task did not cause and does not own).

## Deviations from Plan

- None in the authored content. The gate-set verification criterion is formally an exclusion
  rather than a clean pass, recorded via `[COMPLETED WITH EXCLUSIONS]` and the Reasoned
  Exclusions table rather than silently claimed as fully green.

## What NOT to Try

- Do not attempt to fix `test-run-all-selection.sh`'s or `test-gate-cache-equivalence.sh`'s
  failures as part of this task -- both are out of `file_scope`, pre-existing, and unrelated;
  see the Reasoned Exclusions table for the full evidence trail. A future task should pick these
  up independently (the `issue-record.sh` entry filed this phase is the pointer for that).
- Do not re-run `verify-deploy.sh`/`run-all.sh` expecting a clean pass without first either
  redeploying (`deploy-headless.sh`) to clear the deploy-drift/line-count findings, or separately
  fixing the two unrelated corpus suites -- neither is in scope here.

## Critical Context

- The whole task is now complete: all five plan phases are closed, and the next step is writing
  the implementation summary and `.return-meta.json`/`.orchestrator-handoff.json`.

## References

- Plan: `specs/394_file_scope_containment_chokepoint_for_scoped_commit/plans/01_file-scope-containment-chokepoint.md`
- Edited doc: `agent-system/extensions/core/context/standards/git-staging-scope.md`
- Progress file: `specs/394_file_scope_containment_chokepoint_for_scoped_commit/progress/phase-5-progress.json`
