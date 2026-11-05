## Immediate Next Action

Begin Phase 2: add the exit-code `7` decision block to
`agent-system/extensions/core/scripts/git-commit-scoped.sh`, immediately after the existing V9
exit-code decision (`${#out_of_repo_dropped[@]} -gt 0 && commit_exit -eq 0 -> exit 6`). Fire
exit `7` when `${#containment_dropped[@]} -gt 0` and `commit_exit -eq 0`, guarded behind the
existing `${#array[@]}`-test-first idiom (no unguarded empty-array expansion under `set -u`).

## Current State

Phase 1 is `[COMPLETED]` in the plan file. The V10 Containment classification branch is live
inside `git-commit-scoped.sh`'s V2 loop, gated on `--task`, fully fail-open, and verified both by
the full pre-existing 52-case `test-git-commit-scoped.sh` suite (unchanged, 0 regressions) and by
an ad-hoc scratch-repo probe (one in-scope path committed, one out-of-scope sibling dropped with
a distinct WARN naming the task number, `issue-record.sh` fired non-fatally, exit 0 — exit codes
are deliberately unchanged in this phase per the plan). The resolver-driven `--only` suite set
(15 suites covering this script and its live callers) ran green, with the one pre-existing
`test-guard-git-push.sh` failure confirmed EXPECTED (unrelated, in `known-failures.txt`), 0 NEW
failures. Git tree is clean; the phase-closing commit for Phase 1 is about to be issued via
`git-commit-phase.sh` immediately after this handoff is written (it rides inside that same
commit, per `git-staging-scope.md`'s "a phase closes with exactly one commit" rule).

## Key Decisions Made

- `root_resolved` (previously computed inline at the top of the V2 loop) was moved up to just
  before the new V10 effective-scope resolution block, since that block needs it too (for
  `task_lookup_dir` and `derived_probe_output_prefixes`). The V2 loop references the same
  variable name unchanged.
- V10's normalized-path join uses V9's already-computed `p_dir_rel` plus `basename -- "$p"`,
  never a fresh whole-path `realpath` — this both preserves V9's leaf-symlink safety rationale
  and incidentally normalizes a trailing-slash directory pathspec to the same form as its
  `file_scope` counterpart (both `dirname` and `basename` strip a trailing slash already).
- The header's new V10 prose already says "see exit code 7 above" even though Phase 1 does not
  yet add that table row — intentional forward reference, since Phase 2 (next) closes it in the
  same dispatch.

## Deviations from Plan

- None.

## What NOT to Try

- Do not resolve the whole pathspec with `realpath -m` for V10's normalization — this would
  resolve a leaf symlink to its target and misclassify scope membership, exactly the hazard V9's
  own header already documents for the identical reason.

## Critical Context

- `containment_scope_arr` and `is_contained_v10` are both defined before the V2 loop, so Phase 2
  (and Phase 3's test fixtures) can rely on them being populated by the time any V2 iteration
  runs.
- `issue-record.sh` is NOT in this suite's `REQUIRED_SCRIPTS`/scratch-repo copy list and is
  therefore absent in every existing scratch-repo case — this is what already proves the
  non-fatal-when-absent path (the `|| true` guard around the `issue-record.sh` call) without a
  dedicated new case, though Phase 3 is expected to add one explicitly per the plan's task list.

## References

- Plan: `specs/394_file_scope_containment_chokepoint_for_scoped_commit/plans/01_file-scope-containment-chokepoint.md`
- Edited script: `agent-system/extensions/core/scripts/git-commit-scoped.sh`
- Progress file: `specs/394_file_scope_containment_chokepoint_for_scoped_commit/progress/phase-1-progress.json`
