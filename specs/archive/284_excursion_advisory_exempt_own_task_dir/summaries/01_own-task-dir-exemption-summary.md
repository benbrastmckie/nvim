# Implementation Summary: Task #284

- **Task**: 284 - Exempt a task's own directory from the postflight file_scope excursion advisory, so the aggregator signal it was built for is visible
- **Status**: [COMPLETED]
- **Started**: 2026-10-08T00:00:00Z
- **Completed**: 2026-10-08T02:35:00Z
- **Effort**: ~2.75 hours
- **Dependencies**: None
- **Artifacts**: plans/01_own-task-dir-exemption.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, shell-strict-mode.md

## Overview

Fixed the postflight `modified_files`-vs-`file_scope` excursion advisory
(`agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`'s WORK (h) block) so it
no longer fires unconditionally on every task's own required artifacts (the lifecycle forces
every dispatch to write into its own `specs/{NNN}_{slug}/` tree). The dispatching task's own
resolved task directory is now an implicit, unconditional in-scope member for the comparison,
for every task that already declares a non-empty `file_scope`. The genuine aggregator-edit signal
the advisory was originally built for (task 100, abandoned) still survives intact: a write
outside both the declared `file_scope` and the task's own directory still produces exactly one
advisory naming that file.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — WORK (h) block now
  derives `task_dir_rel` from `$TASK_DIR`/`$PROJECT_ROOT` and splices it (trailing-slash
  directory prefix) into a local `effective_file_scope_json` used only by the excursion jq
  comprehension, inside the pre-existing `length > 0` guard (left untouched, so a task with no
  declared `file_scope` still gets zero advisories, exactly as before). A defensive fallback
  warns (never exits, never changes verdict) if `$TASK_DIR` is not `$PROJECT_ROOT`-relative as
  expected. The script header's WORK (h) summary now documents this behavior plus two fully
  recorded rulings: the exemption covers the WHOLE task directory (parity with the commit
  pipeline, which already stages the whole directory regardless of declared scope), and the
  channel STAYS advisory, with a verbatim two-part promotion criterion recorded for a future
  decision to promote to a blocking gate.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — three new
  regression fixtures (synthetic candidates #715, #716, #717): (a) a task whose declared
  `file_scope` does NOT include its own directory, writing only inside it — zero advisories; (b)
  the same shape plus one genuinely undeclared path outside both scope and the task's own tree —
  exactly one advisory, naming only that path; (c) an archived task directory
  (`specs/archive/{N}_{name}/`, no active directory present) — zero advisories, proving the
  implicit member resolves from the directory the dispatch actually used. The pre-existing
  `707_candidate` invariant (whose declared `file_scope` already includes its own directory) is
  untouched.
- `specs/archive/state.json` — project #270's (jq-null-safety-audit, abandoned) description had
  its dangling "...and it was recorded separately" clause (pointing at the also-abandoned
  `close_aggregator_file_scope_blind_spot` record) replaced with a restatement naming this task
  and what it actually decided, so the cross-reference no longer misleads a reader into believing
  a live follow-on record exists.

## Decisions

- The `file_scope` splice is applied inside the existing `length > 0` guard (to a local
  `effective_file_scope_json`), not unconditionally right after the read — unconditional
  splicing would have widened the guard's own trigger to fire even for tasks with NO declared
  `file_scope`, contradicting the plan's explicit Non-Goal.
- Whole-directory exemption (not an artifact-subdirectory allowlist), by parity with
  `git-commit-scoped.sh`'s existing whole-task-directory staging behavior.
- Enforcement level stays advisory in this change (a decision, not a deferral); the two-part
  promotion criterion (zero false positives over a bake-in period, AND a schema check enforcing
  repo-relative `modified_files` paths) is recorded verbatim in the script header.
- Phase 4's cross-reference edit used `python3 -I` JSON load/replace/dump-to-temp-then-move
  instead of a jq `sub()` pipeline, to avoid any regex-metacharacter risk against free-form prose
  (same temp-file-and-move safety property; validated identically with `jq empty`).

## Plan Deviations

- **Task 1.4** altered: the implicit `file_scope` splice targets a local
  `effective_file_scope_json` inside the existing guard, rather than mutating `file_scope_json`
  unconditionally right after the read — required to honor the plan's own Non-Goal against
  widening the guard's trigger condition (see Phase 1 progress file for full reasoning).
- **Task 4.4** altered: used `python3 -I` instead of a jq `--arg`/`sub()` pipeline for the
  archived cross-reference's string replacement (same temp-file-and-move safety property).
- **Phase 5 verification** closed `[COMPLETED WITH EXCLUSIONS]`: `verify-deploy.sh` reported 2 of
  35 checks failing (Gate 8 shell-suite runner, Gate 13 orphan detection) for reasons confirmed
  (via `git log`/direct reproduction) to be entirely outside this task's `file_scope` — a
  pre-existing exec-bit regression on 4 unrelated test files (task 330, 2026-10-03) and a
  session-state artifact of task 345's in-flight `detect-noop-bash.sh` hook not yet registered in
  the orphan-detection exclusion list. Full Item/Reason/Evidence table in the plan's Phase 5
  section.

## Verification

- Build: N/A (shell scripts)
- Tests: Passed — `test-orchestrate-cycle-postflight.sh` 192 passed, 0 failed (184 pre-existing +
  8 new assertions across 3 new fixtures), including a negative control (Phase 1's splice
  temporarily reverted to a no-op, confirmed all 3 new cases FAIL, then restored and re-verified
  green) proving the new tests are load-bearing rather than vacuous.
- Files verified: Yes — `bash -n` syntax-clean on both edited scripts; `shellcheck -x` emits the
  identical pre-existing finding set as the pre-change `HEAD` baseline on both (zero new
  findings, confirmed by diff); `check-task-references.sh` reports 0 occurrences in both edited
  scripts and in `specs/archive/state.json`; `jq empty` validates `specs/archive/state.json` with
  its `completed_projects` count unchanged (289) and exactly 1 line changed per `git diff --stat`.
- Deploy: `deploy-headless.sh` (default, non-destructive resync) reconciled the deployed `.claude/`
  tree after my source-store edits; Gate 5 (manifest-driven content-hash parity) PASSED for both
  edited files post-reconcile.

## Impacts

- Every future `/orchestrate` cycle for every task with a non-empty declared `file_scope` stops
  receiving a spurious excursion advisory for its own required artifacts (reports/plans/summaries/
  dotfiles), restoring the channel's signal-to-noise ratio toward the genuine aggregator-edit case
  it was built to catch.
- Task 270's (archived) description no longer points readers at an abandoned record as if it were
  a live follow-on.

## Follow-ups

- Promotion of the excursion advisory to a blocking gate remains explicitly deferred; the
  recorded two-part criterion (zero false positives over a bake-in period, AND a
  `modified_files` repo-relative-path schema check) is the trigger for a future task to revisit.
- Gate 13's orphan-detection exclusion-list gap for `detect-noop-bash.sh`'s new
  `noop-bash-shapes-<session>` state-file pattern is task 345's own remaining work, not this
  task's — recorded here only as evidence for Phase 5's Reasoned Exclusions, not as a TODO this
  task owns.
- The 4 non-executable test files (`test-dispatch-metrics.sh`,
  `test-lint-agent-contracts-heartbeat.sh`, `test-script-inventory.sh`,
  `test-task-lock-liveness.sh`) are a pre-existing, unrelated exec-bit regression (task 330,
  2026-10-03) that this task did not introduce and does not own.

## References

- Plan: `specs/284_excursion_advisory_exempt_own_task_dir/plans/01_own-task-dir-exemption.md`
  (Phase 5's Reasoned Exclusions table has the complete evidence chain)
- Research: `specs/284_excursion_advisory_exempt_own_task_dir/reports/01_excursion-advisory-own-task-dir-exemption.md`
- Progress files: `specs/284_excursion_advisory_exempt_own_task_dir/progress/phase-{1..5}-progress.json`
- Issue log: `specs/284_excursion_advisory_exempt_own_task_dir/issues.jsonl`
