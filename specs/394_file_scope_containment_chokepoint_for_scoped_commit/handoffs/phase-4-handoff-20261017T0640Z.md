## Immediate Next Action

Begin Phase 5: author the "Phase Commit (mid-dispatch)" subsection in
`git-staging-scope.md` (the archived specification's Rider requirement), re-read the whole
edited file once for internal consistency, and run the complete gate set.

## Current State

Phase 4 is `[COMPLETED]` in the plan file. `git-staging-scope.md`'s exit-code table row `7` no
longer reads "RESERVED" (`grep -c RESERVED` on the file returns `0`); rows `2` and `4` now name
V10 by name; a **V10** gate-label entry was added immediately after V9, in the same voice and
level of detail; and the "Staging-Layer Containment Filter" subsection was extended with a new
"Three Containment sites, not one" paragraph naming all three sites (postflight WORK (h)/(i),
`git-commit-phase.sh`'s self-check, and V10 inside `git-commit-scoped.sh` itself), which commit
surface each reaches, and that `git-commit-phase.sh`'s own self-check is now deliberately
redundant with V10 rather than load-bearing. `grep -n "V10"` confirms the term appears in both
the table and the gate-label list. The diff is confirmed prose/table-only (`git diff --stat`
shows one file, no code).

## Key Decisions Made

- The "Three Containment sites" paragraph forward-references a "Phase Commit (mid-dispatch)"
  subsection that does not exist until Phase 5 authors it in this same dispatch -- intentional,
  mirroring the identical forward-reference pattern Phase 1 already used for exit code `7` before
  Phase 2 landed it.
- The caller-escalation residual paragraph was corrected to state that exit `7` is NOT a member
  of `orchestrate-cycle-postflight.sh`'s explicit `2|3|4|5|6)` case branch (that script is outside
  this task's `file_scope` and was not touched), but IS still caught loudly by that `case`
  statement's own pre-existing `*)` "unrecognized future exit code" fallback -- verified by
  reading that script's actual branch at `orchestrate-cycle-postflight.sh:1923-1952` rather than
  assumed.

## Deviations from Plan

- None in the edited content itself. See "Verification" below for two KNOWN, EXPECTED,
  structural gate findings that are not a deviation from correctness but ARE worth recording
  explicitly rather than glossed over.

## What NOT to Try

- Do not attempt to fix the doc-lint gate's two findings by hand-editing `.claude/**` or
  `index-entries.json` from the source store -- both are structural source-store/deploy-boundary
  residuals the plan's own Risk table already names and accepts (see Verification below); the
  remedy script itself (`generate-context-line-counts.sh`) REFUSES to run from the source store
  by design ("must run from a deployed scripts/ tree").
- Do not pass `agent-system` as `verify-deploy.sh`'s `TARGET_REPO` argument -- it looks for a
  deploy tree at `agent-system/.claude`, which does not exist (`agent-system/` IS the source
  store, not a deploy consumer). The correct `TARGET_REPO` is the repo root (`.`), where the real
  `.claude/` deploy tree lives.

## Verification Detail (read before treating Phase 4's gate run as fully green)

`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 .` was
run against the repo root under heavy concurrent system load (multiple other verify-deploy.sh
and test-suite invocations were observed running concurrently in this same session window, from
sibling task 393 and/or other `/orchestrate` activity). Gate 4 (task-reference lint) timed out
at its internal 60s bound under that load rather than genuinely failing; re-running
`check-task-references.sh --quiet` scoped individually to each of this task's three edited files
(via the documented `REPO_ROOT=$(pwd) bash ... check-task-references.sh --quiet PATH_SCOPE`
source-store override) confirms all three report "0 unexempted task-reference occurrences" --
PASS.

Gate 3 (doc-lint) genuinely reports 2 FAILs, both pre-existing structural residuals, not content
defects:
1. "deployed script content drift" for `test-git-commit-scoped.sh` -- the deployed `.claude/`
   copy is stale relative to the source-store edit just made. Expected and acknowledged by the
   plan's own Risk table ("propagation is the orchestrator's deploy-pending gate's job, not an
   edit under `.claude/**`"); resolved by the next `deploy-headless.sh` run, not by this dispatch.
2. Rule R: `index-entries.json`'s declared `line_count` for `git-staging-scope.md` (748) no
   longer matches the file's new actual count (811) after this phase's edits. The named remedy,
   `generate-context-line-counts.sh --write`, explicitly REFUSES to run from the source store
   ("must run from a deployed scripts/ tree ... Deploy first") -- confirmed by direct
   invocation. This is therefore also an unavoidable, deploy-time-only remedy, not something
   fixable from inside this dispatch, and `index-entries.json` is outside this task's own
   `file_scope` regardless (confirmed clean/unmodified by this task's own commits via
   `git status --porcelain`).

Both findings are the SAME class of residual the plan's Risk table titled "Source-store/deploy
skew" already named and accepted before this phase began. Neither reflects an error in the
prose/table content itself (which was read through for internal consistency per the phase's own
task list).

## Critical Context

- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-task-references.sh --quiet
  <path>` is the correct source-store-invocation override for scoped task-reference checks when
  the full-repo gate run is too slow or contended to finish inside its internal bound.

## References

- Plan: `specs/394_file_scope_containment_chokepoint_for_scoped_commit/plans/01_file-scope-containment-chokepoint.md`
- Edited doc: `agent-system/extensions/core/context/standards/git-staging-scope.md`
- Progress file: `specs/394_file_scope_containment_chokepoint_for_scoped_commit/progress/phase-4-progress.json`
