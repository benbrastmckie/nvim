# Implementation Summary: Task #659

- **Task**: 659 - Never demote on an ignored-specs skip
- **Status**: [COMPLETED]
- **Started**: 2026-11-20T02:30:00Z
- **Completed**: 2026-11-20T04:55:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: Task 658 (completed) supplied `scripts/lib/specs-ignore-lib.sh`'s predicate
  and `git-commit-scoped.sh`'s V13 exit-code split (8/9), both consumed unchanged
- **Artifacts**: plans/01_never-demote-ignored-specs-skip.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added the two durable skip-recording channels the dispatch required for a V13 (gitignored
specs tree) skip — a deduped `issue-record.sh` entry where a task context exists, an
`events-append.sh` `--category deviation` line where none does — corrected one adjacent
misleading "commit failed" wording on the redeploy-checkpoint completion path, added the
dispatch's required automated negative-control pair against authentic ignored-specs fixtures,
and landed a durable per-reader stated-answer register for every git-history reader the dispatch
named. The pre-existing non-demotion exclusion itself (task 658's exit-8/9 split) was confirmed
correct and untouched throughout.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — the `8|9)` V13 arm now
  fires a deduped `issue-record.sh` entry (`--class "repository configuration"`,
  `--severity minor`, `--resolution fixed_inline`), keyed on `${session_id}|v13-skip|${commit_rc}`
  so one entry is written at most once per `/orchestrate` invocation per exit code, never once
  per cycle.
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` — a new `v13_record_skip_event`
  helper fires an `events-append.sh` `--category deviation` line at both V13 exit sites (8 and 9)
  only when `--task` is absent; a `--task`-bearing invocation deliberately does not (its caller
  owns the task-local record).
- `agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh` — the post-deploy
  reconcile promotion commit now captures the commit's exit code explicitly and prints a
  `NOTE:`-level line for exit 8/9 (the repository's own configuration) instead of the generic
  "commit failed" warning; every other nonzero code keeps the existing wording byte-identical.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — added a
  `make_specs_ignored` fixture helper and cases 987 (authentic all-ignored, real script, exit 8),
  987b (per-invocation dedup), 988 (stubbed partial-ignore, exit 9), and 989 (the negative
  control's other half: the same authentic ignored-specs fixture, with a stubbed genuine failure,
  still demotes). Also added `specs-ignore-lib.sh` to `setup_sandbox`'s own copy list — without
  it the real script falls through V13 to an unrelated V7 check.
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` — extended both AA
  fixture builders with `events-append.sh`/`central-log-lib.sh`, and added cases AA8 (no-`--task`
  event append), AA9 (negative half: `--task` present, no event), AA10 (partial-ignore variant),
  plus a fixture-containment guard proving this repository's own `specs/events.jsonl` is
  untouched by the suite.
- `agent-system/extensions/core/context/standards/absent-specs-git-history.md` (new) — the
  per-reader stated answers, the full V13 recording contract, and the named residuals.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — corrected the V13
  treatment paragraph's "No `issue-record.sh` entry is fired for this arm — these are not
  issues." sentence in place to describe the implemented recording contract, with a pointer to
  the new standard.
- `agent-system/extensions/core/index-entries.json` — registered the new context file and
  reconciled `git-staging-scope.md`'s own `line_count`.

## Decisions

- Kept the dedup identity keyed on `session_id` (not `dispatch_seq`), matching the realistic
  scenario of a session spanning multiple cycles with an incrementing `dispatch_seq` but the
  same underlying repository-configuration skip recurring.
- Did not add a recording call at `redeploy-checkpoint-lib.sh`'s own call site (Phase 3):
  it always passes `--task`, so Phase 2's event channel is deliberately gated off there, and a
  second independent dedup implementation for one adjacent surface would be out of proportion.
  Recorded as a named residual in the new standard instead.
- Updated the in-arm comment "No issue-record.sh call either: these are not issues." at the
  postflight site (not itemized by the plan's task list, but directly contradicted by the new
  code added two lines below it).

## Plan Deviations

- Phase 4: added `specs-ignore-lib.sh` to `test-orchestrate-cycle-postflight.sh`'s
  `setup_sandbox` copy list — not itemized by the plan's task list, but required for cases
  987/987b to exercise the real (unstubbed) `git-commit-scoped.sh` at all. Recorded as an issue
  (class "test fixture gap") and in the Phase 4 handoff.
- Phase 7: closed `[COMPLETED WITH EXCLUSIONS]`, not plain `[COMPLETED]` — see Follow-ups below.

## Verification

- Build: N/A (shell scripts; `bash -n` and `shellcheck` clean on every edited script, no new
  findings)
- Tests: Passed — 340/340 in `test-orchestrate-cycle-postflight.sh` direct run (including the new
  987/987b/988/989), 87/87 in `test-git-commit-scoped.sh` direct run (including AA8/AA9/AA10 and
  the containment case), 4/4 in `test-redeploy-checkpoint-promotion.sh`'s own scoped suite, plus
  every phase's own Tier Justification `--only` suite set (8, 19, 17, 8, 8 respectively) all
  green. Discriminating check performed and reverted cleanly: with Phase 1's recording block
  temporarily disabled, cases 987/987b/988 FAILED on the missing `issues.jsonl` entry while 989
  still PASSED, proving the new assertions are not vacuous.
- Files verified: Yes — all eight edited/created source-store files confirmed diff-clean against
  the deployed tree after `deploy-headless.sh`; `index-entries.json`'s `line_count` values
  self-consistent.

## Impacts

- A consumer repository whose `specs/` tree is wholly or partly gitignored (the originating
  symptom, observed from a second consumer repository) now completes with `completed` and no
  spurious `STATUS DEMOTED` notice, while a genuinely failing commit in that same repository
  still demotes correctly — the exception was narrowed, never removed.
- Every history reader named by the dispatch now has a written, discoverable answer for an
  absent specs git history, consolidated in one new standard rather than scattered across
  individual scripts' own comments.

## Follow-ups

- One pre-existing, out-of-scope defect was surfaced (not introduced) by this task's own
  verification runs: `gate27` (`lint-subject-resolution-declaration.sh`) flags
  `agent-system/extensions/core/scripts/tests/run-all.sh` for calling
  `common_test_resolve_subject` without a paired `common_test_declare_subject`. Confirmed
  pre-existing by running the lint directly against the unmodified file; `run-all.sh` is not
  named in any phase's `Files to modify` and is outside this task's declared `file_scope`.
  Recorded as an `issues.jsonl` entry (class "pre-existing defect noticed", severity minor,
  resolution open, suggested-channel follow_up_task) — a candidate for a future, separately
  scoped task.
- Stated no-change verdicts (Phase 7's closing task), all carried durably in
  `context/standards/absent-specs-git-history.md` rather than repeated here: `validate-state.sh`'s
  `--deep` artifact-loss check already degrades via two explicit `log_warn` lines (no code
  change); `dispatch-metrics.sh`'s churn split already reports an honest zero for an untracked
  specs tree (no code change); `reconcile-task-status.sh` and `task-lock.sh` issue no git-history
  read at all (measured directly against the live source); `lib/territory-contention-lib.sh`'s
  only `git log` text is prose inside an advisory note, not an executed command.
- Task 501 (shared territory, declared not blocking) still edits
  `scripts/orchestrate-cycle-postflight.sh`; the two tasks must never be co-admitted into one
  batch, per the user's own ruling recorded in the dispatch.

## References

- Plan: `specs/659_never_demote_on_ignored_specs_skip/plans/01_never-demote-ignored-specs-skip.md`
- Report: `specs/659_never_demote_on_ignored_specs_skip/reports/01_never-demote-ignored-specs-skip.md`
- New standard: `context/standards/absent-specs-git-history.md`
