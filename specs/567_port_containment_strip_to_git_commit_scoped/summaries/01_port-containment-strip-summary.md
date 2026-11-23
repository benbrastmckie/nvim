# Implementation Summary: Task #567

- **Task**: 567 - Port git-commit-phase.sh's deployed-tree containment strip into git-commit-scoped.sh's V10 resolution block
- **Status**: [COMPLETED]
- **Started**: 2026-11-23T03:00:00Z
- **Completed**: 2026-11-23T04:45:00Z
- **Effort**: 2 hours
- **Dependencies**: None
- **Artifacts**: plans/01_port-containment-strip.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed Site 3 of the three documented Containment-predicate sites by porting the identical
deployed-tree (`.claude`/`.claude/`/`.claude/*`) `file_scope` strip that `git-commit-phase.sh`'s
own Containment Self-Check (Site 2) already carries into `git-commit-scoped.sh`'s V10
effective-scope resolution block (Site 3). Before this change, a deployed-tree `file_scope`
entry admitted at Site 2 was still independently vetoed at Site 3, because Site 3 re-read the
unstripped `file_scope` straight from `specs/state.json`. All four phases completed: the strip
itself, a new regression case (Z19) plus Case 26's restored end-to-end assertion, the standards
doc update, and a scoped close-out verification over the whole touched set.

## What Changed

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` — inserted a deployed-tree strip
  in the V10 resolution block, between the raw `containment_scope_arr` population loop and its
  non-emptiness guard. Strips every `.claude`/`.claude/`/`.claude/*` entry, warns via this
  script's own inline `echo "WARN: ..." >&2` convention (no `warn()` helper exists here), and
  adds no `issue-record.sh` call, mirroring Site 2's parity exactly.
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` — added case Z19,
  pinning that a `.claude/`-only declared `file_scope` strips to empty at Site 3's V10
  resolution and fully disables the Containment check: both the task-directory path and a
  genuinely out-of-scope sibling path land in the same commit, with no out-of-scope drop WARN.
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` — restored Case 26's
  full end-to-end assertion (rc=0, `src/a.txt` present in `HEAD`), replacing its stale
  "Deliberately NOT asserted here" comment block that predated the Site-3 fix. Case 26's two
  pre-existing Site-2-only assertions (no drop warning, empty `proposed_file_scope`) are
  unchanged. Case 20 (idempotence) was re-run unmodified and still passes.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — revised the "A third
  asymmetry" paragraph pair: it no longer claims the deployed-tree strip is site-2-only. It now
  states the strip runs at both Site 2 and Site 3, with the identical strip-then-test ordering
  at each. The `proposed_file_scope_lookup` read-only annotation mechanism remains the one
  deliberate, narrower residual still unmirrored at Site 3 (it has no drop-warning-annotation
  surface there to mirror onto); the paragraph preserves that half's substance unchanged.

## Decisions

- Chose non-colliding loop variable names (`v10_scope_entry`, `v10_scope_stripped`) rather than
  reusing `entry`/`s`/`ewp`/`dp`/`task_dir_entry`, all already in use elsewhere in this script's
  surrounding block or in `is_contained_v10()`.
- Placed the strip strictly before the `if [ "${#containment_scope_arr[@]}" -gt 0 ]; then` guard
  (never inside it), so a scope that strips to empty fails open through the existing path rather
  than surviving into the own-task-directory / engine-written-state / derived-output widening
  splices.
- Z19 dirties both the implicit task-directory path and a genuinely out-of-scope sibling path
  and asserts both land — proving the V10 check is fully disabled, not merely that the
  task-directory's own implicit scope member still admits itself.
- Ran a one-off sanity check (not part of the committed test suite): temporarily reverted the
  Phase 1 strip in the working copy only, re-ran `test-git-commit-scoped.sh`, confirmed Z19 FAILS
  exactly as expected (rc=7, the sibling path dropped as out-of-scope), then restored the strip
  and confirmed `git diff` against HEAD was empty before continuing.
- Scope-strip-only, as the dispatch and plan both specify: the within-dispatch
  `proposed_file_scope_lookup` annotation mechanism was deliberately NOT ported to Site 3.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (shell scripts, no build step)
- Tests: Passed — `test-git-commit-scoped.sh` 88/88 (including new Z19), `test-git-commit-phase.sh`
  98/98 (including widened Case 26 and unmodified Case 20), and a final multi-path
  `verify-touched.sh` run over all four touched paths selecting 22 suites, 22/22 passed.
- Files verified: Yes — `bash -n` exits 0 on both edited shell scripts; `git diff` after each
  phase showed exactly the intended single hunk with no unrelated lines changed.
- The complete gate set (`verify-deploy.sh`) was explicitly NOT run independently by this
  dispatch; it is deferred to the once-per-invocation batch-level close per this dispatch's own
  Batch Gate Deferral directive.

## Impacts

- A task declaring a deployed-tree-only `file_scope` (or one that reduces to that after the
  strip) now fails open identically at both documented Containment chokepoints that read
  `specs/state.json`'s `file_scope` directly (Site 2 and Site 3), closing the gap where a path
  admitted at one site was silently vetoed at the other.
- The one remaining asymmetry between the two sites is now exactly one mechanism
  (`proposed_file_scope_lookup`, a read-only warning-text annotation with no admit/reject
  effect), down from two (the strip plus the lookup), and the standards doc accurately reflects
  this.

## Follow-ups

- None.

## References

- Plan: `specs/567_port_containment_strip_to_git_commit_scoped/plans/01_port-containment-strip.md`
- Research: `specs/567_port_containment_strip_to_git_commit_scoped/reports/01_port-containment-strip.md`
- Standard updated: `agent-system/extensions/core/context/standards/git-staging-scope.md`
