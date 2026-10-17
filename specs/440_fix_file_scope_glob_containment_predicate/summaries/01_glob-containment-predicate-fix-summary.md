# Implementation Summary: Task #440

- **Task**: 440 - Fix the file_scope containment predicate so a /** entry contains its descendants instead of matching literally
- **Status**: [COMPLETED]
- **Started**: 2026-10-17T18:51:30Z
- **Completed**: 2026-10-17T19:27:24Z
- **Effort**: ~0.6 hours
- **Dependencies**: None (task 425 confirmed independent, no dependencies[] edge needed)
- **Artifacts**: plans/01_glob-containment-predicate-fix.md, reports/01_glob-containment-predicate-fix.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed a quoted-case-pattern bug at two independently copy-pasted containment predicates --
`is_contained_v10()` in `git-commit-scoped.sh` and its ported twin `is_contained()` in
`git-commit-phase.sh` -- that made a `/**`-suffixed `file_scope` entry never contain any path,
at any nesting depth. Both predicates now strip a literal trailing `/**` suffix and test prefix
containment against the stripped base, placed immediately after the exact-match test and before
the pre-existing directory/glob-ancestor branches. Six new test cases (four in
`test-git-commit-scoped.sh`'s Z-series, two in `test-git-commit-phase.sh`) prove direct-child
containment, deep-descendant containment, same-prefix-sibling exclusion (the non-widening
proof), and unaffected non-glob-entry behaviour, at both sites. The source store was redeployed.

## What Changed

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` -- added a guarded branch to
  `is_contained_v10()`: strips a literal trailing `/**` from a normalized file_scope entry and
  tests exact-or-slash-bounded prefix containment against the stripped base; extended the
  function's header comment to name the new form.
- `agent-system/extensions/core/scripts/git-commit-phase.sh` -- applied the identical branch to
  the ported twin `is_contained()`.
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` -- appended `Z11`-`Z14`:
  direct-child containment, deep-descendant containment, same-prefix-sibling exclusion (the
  non-widening proof), and a `/**` entry alongside a plain non-glob entry.
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` -- appended `Case 10`
  (direct child + deep descendant, both land) and `Case 11` (same-prefix sibling excluded, the
  non-widening proof).
- Redeployed `.claude/**` tree via `deploy-headless.sh`; both deployed script copies confirmed
  (by direct grep) to carry the new branch.

## Decisions

- Transcribed the research report's validated fix verbatim rather than re-deriving it: one
  guarded branch per function (`[ "$entry_base" != "$entry_norm" ]`), leaving every pre-existing
  branch byte-identical.
- Placed the new branch immediately after the exact-match test and before the two pre-existing
  case branches (matching the plan's specified order exactly), not appended at the end of the
  loop body.
- Chose `lib/widget-area/**` (git-commit-scoped.sh suite) and `other/widget-area/**`
  (git-commit-phase.sh suite) as the new test cases' base directories, rather than the plan's
  illustrative `specs/999_probe/**`, because the fixture task directory is already admitted by
  each suite's implicit task-directory-scope widening regardless of the `/**` fix -- a base
  inside it would not isolate the new branch under test.
- No shared helper was extracted between the two sites (deliberately rejected per the plan's
  Non-Goals); each site's fix is self-contained, matching the pre-existing "ported, not
  reinvented" pattern both functions already carry.
- Wrapped each suite's new cases in their own nested `task-ref-ok:begin`/`:end` marker pair, in
  addition to each file's existing far-above marker pair, because the write-time
  no-task-references hook scans only the Edit tool call's own `new_string`, not the full file --
  a begin marker many lines above the edited region is invisible to that per-call scan.

## Plan Deviations

- **Phase 2/Phase 3** (test base directory): used `lib/widget-area/**` /
  `other/widget-area/**` instead of the plan's illustrative `specs/999_probe/**` -- see
  Decisions above. Functionally equivalent and strictly better isolation of the behaviour under
  test; recorded in both phases' progress files.
- **Phase 4** (`deploy-headless.sh` result): reported `RESULT=landed_verify_red` instead of
  `RESULT=landed_verify_clean`. The deploy itself landed and both deployed copies carry the fix.
  The three fast-gate failures (two 30-second gate timeouts under transient heavy
  concurrent-dispatch load, and an SC2034 shellcheck finding) were all confirmed to sit inside
  sibling task 441's own in-flight, uncommitted edits (`check-extension-docs.sh`,
  `sync-manifest-scripts.sh`), not in this task's declared file_scope -- not a regression from
  this task's changes.
- **Phase 4** (full gate set): the complete `verify-deploy.sh` gate set (no `--skip-slow`, no
  `--only-gate`) was not independently run. Per this dispatch's Batch Gate Deferral directive
  (this task ran inside a multi-task `/orchestrate` batch invocation), the full gate set is
  deferred to the once-per-invocation batch-level stage. Discharged instead against the scoped
  narrowing invocation
  (`run-all.sh --only test-git-commit-scoped.sh,test-git-commit-phase.sh`), run twice against
  the deployed tree, passing cleanly both times.

## Verification

- Build: N/A (shell scripts; `bash -n` clean on all four edited files)
- Tests: Passed -- both suites green (`test-git-commit-scoped.sh`: 14 Z-series cases including
  the 4 new ones; `test-git-commit-phase.sh`: 19 cases including the 2 new ones), run multiple
  times across the source-store and deployed trees
- shellcheck: zero new findings on any of the four edited files (pre-existing SC1091/SC2329
  info-level findings unchanged)
- RED-before-fix observation: each new test case was independently confirmed to fail against a
  scratch copy with the new branch's `entry_base` assignment neutralized, then the real script
  was restored via `git show HEAD:...` and confirmed clean before continuing
- Files verified: Yes (diffs confirmed no pre-existing branch modified/reordered; both deployed
  copies grepped for the new branch)
- Live sanity check: a real `/**` file_scope entry from `specs/state.json`
  (`agent-system/extensions/books/agents/**`, project 342) correctly contains real descendant
  paths and correctly excludes a same-prefix sibling under the deployed predicate

## Impacts

- Any future commit (via `git-commit-scoped.sh --task` or `git-commit-phase.sh`) against a task
  whose `file_scope` declares a `/**`-suffixed entry will now correctly stage files under that
  entry, instead of silently dropping them as "out of scope" (the defect that caused task 434's
  phases 3-4 to lose up to 26 files from their own commits).
- The `--task`-omitted fail-open workaround and the exact-path-listing plan-author workaround
  (both used to route around this defect during task 434) are no longer necessary for future
  tasks that declare a `/**` entry, though neither this task's scope nor this summary retracts
  either workaround where it has already been used historically.

## Follow-ups

- None required by this task's scope. The research report's documented non-goals (extracting a
  shared containment helper, evaluating brace expansion or other glob syntax in `file_scope`
  entries, normalizing site 2's missing trailing-slash handling to match site 1, and
  documenting the supported `file_scope` entry grammar in `git-staging-scope.md`) remain
  legitimate future work but are out of scope here.

## References

- Plan: specs/440_fix_file_scope_glob_containment_predicate/plans/01_glob-containment-predicate-fix.md
- Report: specs/440_fix_file_scope_glob_containment_predicate/reports/01_glob-containment-predicate-fix.md
- Handoffs: specs/440_fix_file_scope_glob_containment_predicate/handoffs/
