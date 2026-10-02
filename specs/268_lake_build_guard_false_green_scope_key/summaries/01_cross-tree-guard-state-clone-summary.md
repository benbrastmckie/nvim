# Implementation Summary: Task #268

- **Task**: 268 - lake-build-guard false-green (cross-tree guard-state clone)
- **Status**: [COMPLETED]
- **Started**: 2026-09-30T18:00:00Z
- **Completed**: 2026-10-02T16:52:00Z
- **Effort**: ~5 hours across two dispatches
- **Dependencies**: None
- **Artifacts**: plans/01_cross-tree-guard-state-clone.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Research reproduced a real, deterministic false green: `dispatch-worktree.sh`'s `cp -al`
hardlink clone of `.lake/` made the five `build-guard.*` state files one shared inode across
every provisioned worktree, so a worktree build's write silently clobbered the main tree's
record/log, and a subsequent unguarded `result` read reported the foreign tree's verdict as its
own. Phases 1-4 fixed this at the root (excluded the five state files from the clone), pinned
both consequences with red-then-green regression tests, pinned the incidental
fingerprint-path-embedding protection that keeps `decide_sharing()` safe across trees even without
the clone fix, and recorded the hazard class in both scripts' headers.

**Mid-implementation finding**: between Phase 4's commit and this final dispatch, a
separately-tracked task (the worktree-isolation-layer removal task, completed) deleted
`dispatch-worktree.sh` and both of its test files wholesale, removing the entire per-dispatch
worktree-provisioning layer from the codebase. This makes the specific false-green mechanism this
task targeted structurally unreachable rather than merely patched: there is no longer any
`cp -al`-cloning consumer anywhere in `agent-system/**`. Phase 1's regression tests and Phase 2's
fix lived entirely inside the now-deleted files and cannot be re-verified going forward, but this
is a stronger outcome than the plan anticipated, not a weaker one. Phase 3's Test C
(cross-tree replay refusal in `test-lake-build-guard.sh`) and Phase 4's `lake-build-guard.sh`
header convention both survive intact, generically worded (not hard-dependent on
`dispatch-worktree.sh`'s existence), and remain the standing guard against any *future*
`cp -al`-cloning consumer.

## What Changed

- `agent-system/extensions/core/scripts/dispatch-worktree.sh` — Phase 2 excluded the five
  `build-guard.*` state files from the `.lake/` hardlink clone in `cmd_provision()`; Phase 4 added
  a header hazard note. **Subsequently deleted wholesale** by the separately-tracked
  worktree-isolation-layer removal task (confirmed via `git log`), after this task's own commits
  landed. No longer present in source store or deployed tree.
- `agent-system/extensions/core/scripts/tests/test-dispatch-worktree.sh` — Phase 1 added cases
  T14 (inode distinctness) and T15 (cross-tree `result` clobbering), both proven red before
  Phase 2's fix and green after. **Subsequently deleted** along with its target file by the same
  other task.
- `agent-system/extensions/core/scripts/lake-build-guard.sh` — Phase 4 extended the header's
  `FAMILY CONVENTIONS` and `RECORDED DEAD ENDS` sections with the no-hardlink-sharing convention
  and the `--git-common-dir` dead end, phrased generically (no hard dependency on
  `dispatch-worktree.sh`'s continued existence). No logic change. Confirmed byte-identical
  source-vs-deployed and `bash -n` clean.
- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` — Phase 3 added Test C,
  pinning the incidental cross-tree non-replay protection (fingerprint path-embedding) with a raw
  `cp -al` clone independent of `dispatch-worktree.sh`. Confirmed still green (48/48 including
  Test C), and confirmed load-bearing by the plan's own reverted mutation check at authoring time.
- `specs/268_lake_build_guard_false_green_scope_key/plans/01_cross-tree-guard-state-clone.md` —
  Phase 5 recorded the mid-implementation finding above and annotated every Phase 5 task/
  verification bullet and the top-level Testing & Validation checklist with the evidence behind
  each deviation from the plan's literal (now partly moot) expectations.

## Decisions

- Adopted the research's root-cause fix (exclusion at the clone) over tree-identity-in-record,
  because it closed both the record-clobbering and lock-contention halves of the defect with no
  record-format change (recorded in the plan's own Decisions section; unaffected by the later
  deletion).
- Phase 5 closed the task on the best achievable gate rather than blocking on two confirmed
  pre-existing, unrelated failures (see Follow-ups) — consistent with Phase 2's own established
  precedent of evidencing and documenting unrelated failures rather than treating them as
  blockers.
- Did not attempt to "restore" or re-author `dispatch-worktree.sh`/its tests to force a literal
  parity match with the original Phase 5 task list: the other task's removal is a legitimate,
  separately-tracked, completed piece of work, and re-litigating it is out of this task's scope.

## Plan Deviations

- **Phase 5 verification criteria** (`deploy-headless.sh`/`verify-deploy.sh`/`run-all.sh` all
  exit 0, four-file parity): altered. Two of the four named files no longer exist (deleted by the
  other task); the remaining two are confirmed byte-identical and fully green. Both gate failures
  (`run-all.sh`'s 1 NEW suite, `verify-deploy.sh`'s Gate 20) are confirmed pre-existing and
  unrelated to this task's files — see `progress/phase-5-progress.json` for full evidence.
- **Top-level Testing & Validation checklist**: several items (T14/T15 existence, "both suites
  still pass") are satisfied only historically — the suite they describe no longer exists to
  re-run. Annotated inline rather than silently left unchecked or silently checked without
  qualification.
- **Phase 2's own prior deviation** (run-all.sh 8 pre-existing failures, recorded at the time) is
  unchanged by this finding and carried forward as-is.

## Verification

- Build: N/A (shell scripts; no build step)
- Tests: `test-lake-build-guard.sh` 48/48 passed (including Test C). `test-dispatch-worktree.sh`
  no longer exists to test (file deleted by a separately-tracked task after this task's Phase 4).
  `run-all.sh`: 102 passed, 4 failed (3 expected per `known-failures.txt`, 1 NEW and confirmed
  pre-existing/unrelated per that same manifest's own header comment). `verify-deploy.sh` (full,
  no `--skip-slow`): 2 of 34 checks failed, both confirmed pre-existing and unrelated.
- Files verified: Yes — `bash -n` clean on both surviving touched files; byte-identical
  source-vs-deployed for both.

## Impacts

- The specific false-green mechanism this task targeted (cross-tree `build-guard.*` state
  clobbering via `dispatch-worktree.sh`'s `cp -al` clone) is now structurally impossible: the
  clone site itself no longer exists anywhere in the codebase.
- `lake-build-guard.sh` retains a standing, generically-worded guard (header convention + Test C)
  against any future consumer that clones a Lean package root via `cp -al`, independent of
  `dispatch-worktree.sh`'s absence.
- `--no-share` is no longer load-bearing as a workaround for this specific defect, since its root
  cause's only known trigger path has been removed.

## Follow-ups

- Two confirmed pre-existing, unrelated gate failures remain open, each already tracked
  elsewhere and neither touched by this task:
  1. `test-typst-element-lint.sh` (case-h2 NEW failure) — traced, per
     `agent-system/extensions/core/scripts/tests/known-failures.txt`'s own header, to an
     uncommitted, concurrently in-flight change to
     `agent-system/extensions/typst/scripts/typst-element-lint.sh`; resolves once that work
     commits or reverts.
  2. `skills/skill-orchestrate/SKILL.md` exceeding its Gate 20 context-budget ceiling (20930 B
     vs. 20000 B) — already the explicit subject of a separately-tracked, concurrently dispatched
     sibling task this same cycle (trim-skill-orchestrate-under-gate20-ceiling).
- The research's Context Extension Recommendation to update
  `context/patterns/batch-orchestration-guardrails.md` was deliberately left out of this task's
  footprint (declared in the plan's Non-Goals/Decisions) because that file sits in a concurrent
  sibling task's declared `file_scope` this same cycle; carried forward as a follow-up for
  whichever task next touches that file.

## References

- `specs/268_lake_build_guard_false_green_scope_key/reports/01_false_green_scope_key_defect.md`
- `specs/268_lake_build_guard_false_green_scope_key/plans/01_cross-tree-guard-state-clone.md`
- `specs/268_lake_build_guard_false_green_scope_key/progress/phase-1-progress.json` through
  `phase-5-progress.json`
- `agent-system/extensions/core/scripts/tests/known-failures.txt`
