## Immediate Next Action

Begin Phase 3: add the regression suite cases to
`agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` (a `build_repo_with_scope`
fixture helper, plus the ten anticipated cases listed in the plan's Phase 3 task list).

## Current State

Phases 1 and 2 are both `[COMPLETED]` in the plan file. `git-commit-scoped.sh` now emits exit
code `7` for the commit-succeeded-with-Containment-drops shape, with documented precedence (V9
keeps precedence over V10; all-dropped stays exit `2` via V3; drop-plus-no-diff-survivor stays
exit `4` via V6). Verified by three ad-hoc scratch-repo probes exercising exactly these three
shapes (exit 7, exit 2, exit 4 respectively, each confirmed via the actual script output, not
assumed), plus the same 15-suite resolver-driven `--only` set green (14 passed, 1 pre-existing
EXPECTED failure in `test-guard-git-push.sh`, 0 NEW failures), plus the full 52-case
`test-git-commit-scoped.sh` suite still green with zero regressions. `bash -n` and `shellcheck`
both clean.

## Key Decisions Made

- Exit `7`'s decision block is placed immediately after V9's own exit-6 decision (not before),
  so V9 keeps precedence by placement exactly as the plan specifies — an invocation tripping both
  gates in the same call reports `6`.
- The header's exit-code table entries for `4` and `6` were both touched to mention V10/exit `7`
  by name (4's wording folds in the Containment drop reason; 6's wording states the new
  precedence-over-7 rule), in addition to adding the new entry `7` itself.

## Deviations from Plan

- None.

## What NOT to Try

- Do not expect the all-dropped Containment shape to reach the new exit-7 branch — it is
  structurally unreachable there, because V3's post-filter refusal (exit 2) already fires before
  the commit is even attempted whenever every positive pathspec was dropped, Containment-dropped
  paths included. Confirmed directly by the Case B probe during this phase.

## Critical Context

- The three probe shapes used during this phase (partial drop + committable survivor -> 7;
  all-dropped -> 2; drop + no-diff survivor -> 4) are the exact three Phase 3 is expected to turn
  into permanent suite cases — reuse the same scratch-repo construction rather than re-deriving
  it.

## References

- Plan: `specs/394_file_scope_containment_chokepoint_for_scoped_commit/plans/01_file-scope-containment-chokepoint.md`
- Edited script: `agent-system/extensions/core/scripts/git-commit-scoped.sh`
- Progress file: `specs/394_file_scope_containment_chokepoint_for_scoped_commit/progress/phase-2-progress.json`
