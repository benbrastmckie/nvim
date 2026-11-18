# Implementation Summary: Task #591

- **Task**: 591 - Decide the fate of the errors.json triage surface
- **Status**: [COMPLETED]
- **Started**: 2026-11-17T03:07:48Z
- **Completed**: 2026-11-17T07:35:00Z
- **Effort**: ~4.5 hours
- **Dependencies**: 572, 585
- **Artifacts**: plans/01_retire-errors-triage-surface.md, reports/01_errors-record-disposition.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

The `specs/errors.json` / `scripts/errors-append.sh` / `/errors` triage surface is retired
outright. All 19 existing records were audited and dispositioned (17 traced to a specific
discharging task, 2 named as generic follow-up candidates); the surface's command, writer
script, test suite, schema, and format contract were deleted; every manifest, index, gate,
allowlist, and deny-list registration was removed; every prose reference across the source
store (rules, standards, formats, patterns, commands, skills, docs, and script comments) was
swept; and the deployed tree was wiped and regenerated to confirm no orphaned residue survives.

## What Changed

- `specs/errors.json` — deleted (content reachable in git history; disposition audit in
  `reports/01_errors-record-disposition.md`)
- `agent-system/extensions/core/commands/errors.md` — deleted
- `agent-system/extensions/core/scripts/errors-append.sh` — deleted
- `agent-system/extensions/core/scripts/tests/test-errors-append.sh` — deleted
- `agent-system/extensions/core/context/formats/errors-format.md` — deleted
- `agent-system/extensions/core/context/schemas/errors-schema.json` — deleted
- `agent-system/extensions/core/manifest.json` — dropped the three provides rows for the deleted files
- `agent-system/extensions/core/index-entries.json` — deleted 2 index entries, narrowed 8 `load_when.commands` arrays, corrected a stale keyword/summary reference, and refreshed several `line_count` values
- `agent-system/extensions/core/scripts/tests/suite-classification.data` and `suite-cost-hints.txt` — dropped the retired suite's rows
- `agent-system/extensions/core/scripts/verify-deploy.sh` — narrowed gate 1 to the six events-store paths (comment, `say` line, and corpus loop)
- `agent-system/extensions/core/scripts/gate-registry.data` — narrowed gate 1's `input_corpus` and `name` to match
- `agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh` — narrowed its scratch corpus and comment to match
- `agent-system/extensions/core/scripts/lib/engine-written-state-paths-lib.sh` — the engine-written-state literal is now three elements (`specs/TODO.md`, `specs/state.json`, `specs/events.jsonl`)
- `agent-system/extensions/core/scripts/tests/test-engine-written-state-paths-lib.sh`, `test-git-commit-scoped.sh`, `test-git-commit-phase.sh` — rewrote the three assertions that previously expected `specs/errors.json` to be admitted; they now assert its absence/drop
- `agent-system/extensions/core/scripts/measure-eager-context.sh` — dropped `specs/errors.json` from `VOLATILE_PATHS`
- `agent-system/extensions/core/hooks/events-log-artifact.sh` — removed the `errors_json` match branch and its event-emission arm
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` — removed the `error_ref` derivation from `specs/errors.json`
- `agent-system/extensions/core/scripts/events-append.sh` — reworded the `--error-ref` help line to describe a generic external cross-link
- 15 rule/standard/format files (`rules/error-handling.md`, `merge-sources/claudemd.md`, `README.md`, `context/standards/error-recovery-strategies.md`, `orchestrator-runtime-files.md`, `git-staging-scope.md`, `shell-strict-mode.md`, `context/standards/error-handling.md`, `git-safety.md`, `context/formats/issue-log.md`, `events-format.md`, `command-output.md`, `command-structure.md`, `subagent-return.md`) — swept and retargeted onto `issue-record.sh`/`issues.jsonl` where the prose described the retired triage surface as live
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` — eager context re-measured (69,930 B, down from 70,389 B, still under the 70,400 B baseline)
- 19 further context/command/skill/docs files — swept for remaining `/errors` and `errors.json` references (architecture, orchestration, patterns, processes, commands, skills, guides, reference docs)
- 10 script files — swept for header comments, structural-model citations, and scratch-tree stub-list entries naming `errors-append.sh`
- Deployed tree — wiped and regenerated via `deploy-headless.sh --wipe`

## Decisions

- Retirement over retention: `/errors` had zero production write-path callers (`errors-append.sh
  append` was never invoked outside its own command, test fixtures, and `verify-deploy.sh`'s
  manifest-presence check); every genuinely useful capability it nominally offered is already
  provided by `issues.jsonl` plus the orchestration conclusion stage, confirmed by direct
  reading rather than assumption.
- All 9 `fixed`-status records were closed by direct edits to `specs/errors.json`, never by
  running `/errors --fix` — confirmed empirically (zero `fix_status: "in_progress"` occurrences
  anywhere in git history) — so the mutable-lifecycle-field capability the task description
  raised as worth checking was never actually exercised.
- `CORE_TEST_SUBJECT_MODE=source-store` was used for mid-dispatch verification of
  "deploy-tree-first" test suites, which otherwise resolve the intentionally stale deployed
  tree before Phase 8's redeploy — this is the library's own sanctioned override for exactly
  this pre-redeploy asymmetry, not a workaround.
- Phase 7/8's `full` verification tier was discharged against a scoped narrowing per the
  dispatch's Batch Gate Deferral directive (multi-task `/orchestrate` batch invocation): the
  selector-resolved suite run for Phase 7, and `verify-deploy.sh --only-gate 1,13
  --skip-unchanged` for Phase 8 — the two gates most directly implicated by this task's
  deletions. The full, unnarrowed battery is deferred to the once-per-batch stage.

## Plan Deviations

- **Task 2.3** altered: also corrected an unlisted `errors-append` keyword/summary reference on
  the `standards/error-recovery-strategies.md` index entry, required by Phase 2's own
  verification grep.
- **Task 4 (verification)** altered: Phase 4's stated verification grep is satisfied by evident
  intent rather than literal zero matches, since the phase's own task list requires three test
  fixtures that still name `specs/errors.json` to assert its absence.
- **Task 5.2** altered: also retargeted an unlisted `## Error Handling` bullet in
  `merge-sources/claudemd.md` pointing at `errors.json`.
- **Task 5.5** altered: also retargeted the `.decisions.lock` row's comparison (which pointed at
  the deleted `.errors.lock` row) and removed the now-dead `**/.errors.lock` gitignore-pattern
  line.
- **Task 5.8** altered: left `.agent-logs/errors.json` (a different, never-implemented
  permission-denial log) untouched in `context/standards/error-handling.md` — out of scope.
- **Task 5.10** altered: also removed the `/errors` command's own illustrative output-example
  block in `command-output.md`.
- **Task 6 (permission-configuration.md)** skipped: all 6 mentions in that file are the same
  unrelated `.agent-logs/errors.json` concept excluded in Task 5.8.
- **Task 7.2** altered: repointed `orchestrate-record-decision.sh`'s write-mechanics citation to
  `state-write.sh` (the actual structural match) rather than `issue-record.sh`/`events-append.sh`.
- **Task 7.3** altered: restated `validate-state.sh`'s bash+jq idiom inline rather than citing a
  surviving document, since none carries the specific policy statement the deleted file documented.
- **Discovered, not fixed (follow-up candidates)**: (1) `scripts/lib/runtime-file-patterns.sh`
  still carries a dead 25-member `errors-lock` entry, out of this task's declared file_scope,
  requiring a careful renumbering a future task should take on deliberately. (2)
  `test-common-lib.sh`'s `deploy-tree-first` fixture case and `test-git-commit-scoped.sh`'s U5
  case both fail for reasons confirmed unrelated to this task (a prior commit from task 555, and
  a foreign in-flight edit to `git-commit-scoped.sh`, respectively).

## Verification

- Build: N/A (meta task, no build step)
- Tests: Selector-resolved suite runs across Phases 2-4 and 7 (up to 168 suites) all green except
  pre-existing baseline failures and the two unrelated findings named above; scoped
  `verify-deploy.sh --only-gate 1,13` discharge for Phase 8 passes (7 checks, 0 failures); the
  full, unnarrowed battery is deferred to the batch-level stage per this invocation's directive
- Files verified: Yes — all 5 removed source paths confirmed absent from both the source store
  and the redeployed `.claude/` tree; `validate-index.sh` and `lint-dead-command-recommendations.sh`
  both pass cleanly

## Impacts

- `/errors` is no longer a routable command; any caller still invoking it will get a normal
  "unknown command" response rather than silent dead-end behavior.
- The engine-written-state staging allowlist, eager-context volatile deny-list, and artifact-
  logging hook no longer carry a reference to a nonexistent file, closing the exact
  half-retired-residue risk the task description named.
- Eager context budget recovered ~459 B of headroom (70,389 B -> 69,930 B against a 70,400 B
  ceiling).

## Follow-ups

- `scripts/lib/runtime-file-patterns.sh`'s dead `errors-lock` member (25-member registry,
  `**/.errors.lock` gitignore pattern) is now permanently inert and should be removed in a
  dedicated follow-up that can safely renumber its five consuming sites.
- Two pre-existing, unrelated test failures were observed during this task's broader selector
  runs and are not this task's to fix: `test-common-lib.sh`'s `deploy-tree-first` fixture case
  (traced to commit `53e141696`, task 555) and `test-git-commit-scoped.sh`'s U5 case (traced to
  a foreign, already-in-flight edit to `git-commit-scoped.sh` by a different task).
- The full, unnarrowed gate battery (`verify-deploy.sh`'s remaining 27 gates, `tests/run-all.sh`
  unnarrowed, `validate-wiring.sh`, `check-record-versioning.sh`'s full repo sweep, the complete
  `lint/` set) is deferred to the once-per-batch-invocation stage this `/orchestrate` cycle runs
  after every task's dispatch completes — its result should be checked there, not assumed clean
  from this task's scoped discharges alone.

## References

- Plan: `specs/591_retire_errors_json_triage_surface/plans/01_retire-errors-triage-surface.md`
- Disposition report: `specs/591_retire_errors_json_triage_surface/reports/01_errors-record-disposition.md`
- Progress files: `specs/591_retire_errors_json_triage_surface/progress/phase-{1..8}-progress.json`
