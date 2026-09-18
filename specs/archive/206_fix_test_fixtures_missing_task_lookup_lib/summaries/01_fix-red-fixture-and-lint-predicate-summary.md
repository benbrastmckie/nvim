# Implementation Summary: Task #206

- **Task**: 206 - fix_test_fixtures_missing_task_lookup_lib
- **Status**: [COMPLETED]
- **Started**: 2026-09-17T16:51:00Z
- **Completed**: 2026-09-17T21:45:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_fix-red-fixture-and-lint-predicate.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, context/standards/shell-strict-mode.md

## Overview

Two core shell suites were red on master: `test-postflight-deploy-gate.sh` (missing
`task-lookup-lib.sh` in an explicit fixture lib list) and `test-lint-json-channel-discipline.sh`
(a false positive in `lint-json-channel-discipline.sh`'s `check_emit_perline()` predicate over a
`> "$var"` file redirect). Both were fixed with single, minimal edits, backed by a new permanent
regression case for the lint false positive and a defensive audit that closed two further
dormant (not-yet-red) instances of the same missing-lib gap in other fixtures. Suite (3)
(`test-gate-out-repair-reporting.sh`) was withdrawn from scope by the dispatch addendum after a
2026-09-17 survey found it already green, and was not touched.

## What Changed

- `agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` — added
  `task-lookup-lib.sh` to the `REQUIRED_LIBS` array (single-token addition; fixture now builds a
  complete minimal script tree that `task-lock.sh`'s unconditional `source` can resolve).
- `agent-system/extensions/core/scripts/lint/lint-json-channel-discipline.sh` — appended one
  exclusion stage (`grep -vE '>[[:space:]]*"?\$\{?[A-Za-z_]'`) to `check_emit_perline()`'s existing
  exclusion pipeline, with an explanatory comment, so a redirect to a variable-held file path is
  no longer misclassified as an unredirected stdout write.
- `agent-system/extensions/core/scripts/tests/test-lint-json-channel-discipline.sh` — added a new
  "EMIT case 3 (per-line)" regression fixture: a synthetic `orchestrate-triage-classify.sh`-shaped
  file with one `printf ... > "$var"` redirected write plus one legitimate final unredirected
  emit, asserting a clean pass. Verified this case fails against the pre-fix predicate before
  restoring the fix (a genuine regression test, not a tautology).
- `agent-system/extensions/core/scripts/tests/test-handoff-dispatch-identity.sh` — added
  `task-lookup-lib.sh` to both explicit lib loops (the `require_file` preflight loop and the
  `setup_sandbox()` copy loop) — a dormant (still-green) instance of the same missing-lib gap,
  found and closed defensively during the item (d) audit.
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` — added
  `lib/task-lookup-lib.sh` to `REQUIRED_SCRIPTS`, and extended the existing `chmod +x` skip-guard
  (keyed off `lib/common.sh`) with a second OR-clause so the new lib entry gets the same
  non-executable treatment — another dormant instance of the same gap, closed defensively.
- `specs/state.json` — appended (via `jq` `+=`, not wholesale replacement) the two audit-gap
  files above to task 206's `file_scope` array, since the audit found them after task creation.

## Decisions

- **Suite (2) — fix the predicate, not allowlist, not change the code.** The write at
  `orchestrate-triage-classify.sh:225` is correct as written: it must land in a real file because
  the caller consumes it via `--slurpfile`, so redirecting it to stdout would be wrong. An
  allowlist entry naming only that one line is narrower than the actual defect class — any future
  `> "$var"` file-redirect write in any `EMIT_PERLINE_FILES` script would hit the same false
  positive. Fixing the predicate is the general fix, and it does not over-suppress: the
  pre-existing "two genuine violations" case and both negative controls behave identically after
  the change (verified in Phase 3).
- **Item (d) audit method and result.** Swept `agent-system/extensions/core/scripts/tests/` with
  a `grep -lE` over `task-lock\.sh|skill-base\.sh|update-task-status\.sh`, yielding 23 matches; one
  (`test-postflight-deploy-gate.sh`) is the Phase 1 primary target rather than an audit find,
  leaving 22 audit candidates (matching the research report's predicted count exactly). Each was
  read and classified into five buckets:
  - `wholesale_copy_safe` (6): `test-force-phases.sh`, `test-gate-out-repair-reporting.sh`,
    `test-roadmap-items-producer.sh`, `test-skill-base-lifecycle.sh`, `test-update-task-status.sh`,
    `test-reconcile-handoff-status.sh` — fixture copies `lib/*.sh` wholesale (or the whole
    `scripts/` tree), immune by construction.
  - `explicit_list_already_complete` (6): `test-loop-guard-budget-override.sh`,
    `test-orchestrate-churn.sh`, `test-orchestrate-context-growth.sh`,
    `test-orchestrate-cycle-plan.sh`, `test-orchestrate-cycle-postflight.sh`,
    `test-phase-heartbeat.sh` — explicit lib list already includes `task-lookup-lib.sh`.
  - `no_fixture_copy` (5): `test-corroborate-phase-counts.sh`, `test-mint-dispatch-seq.sh`,
    `test-orchestrate-build-aux-dispatch.sh`, `test-orchestrate-build-dispatch.sh`,
    `test-postflight-marker-schema.sh` — sources the real script directly from its real location,
    no synthetic lib list exists.
  - `static_analysis_only` (3): `test-lint-lifecycle-status-var.sh`,
    `test-lint-task-lookup-adoption.sh`, `test-resume-scan-nonconformance.sh` — never executes the
    real `task-lock.sh`/`skill-base.sh`/`update-task-status.sh` chain.
  - `genuine_gap_fixed` (2): `test-git-commit-scoped.sh`, `test-handoff-dispatch-identity.sh` —
    explicit lib list omitted `task-lookup-lib.sh` while also copying `task-lock.sh`; both were
    dormant (still green pre-fix, since their exercised code paths did not happen to trip the
    missing source), not red. Both fixed; both remain green post-fix (8/0 and 7/0 respectively).
- **`file_scope` deviation.** The two audit-gap files were outside task 206's original
  `file_scope` (declared at creation, before the item (d) audit ran). Per the dispatch's
  instruction to fix any gap found, and per `state-management.md` (`file_scope` is descriptive,
  not filesystem-validated), both paths were appended to `specs/state.json`'s `file_scope` array
  via `jq` `+=` rather than left undeclared.

## Plan Deviations

- None (implementation followed plan). The one plan-adjacent deviation (the `file_scope`
  extension) was explicitly anticipated and authorized by Phase 4's own task list and risk table,
  not an unplanned departure.

## Verification

- Build: N/A (shell scripts, no build step)
- Tests:
  - `test-postflight-deploy-gate.sh`: 19 passed, 0 failed (source store and deployed copy)
  - `test-lint-json-channel-discipline.sh`: 12 passed, 0 failed (source store and deployed copy),
    including the new "EMIT case 3 (per-line)" regression case, confirmed to fail against the
    pre-fix predicate before the fix was restored
  - `lint-json-channel-discipline.sh` real-corpus run: 0 violations (source store: 178 files; from
    the deployed `.claude/` copy: 179 files — one more countable file in the deployed tree, not a
    regression)
  - `test-handoff-dispatch-identity.sh`: 8 passed, 0 failed (unchanged-green, dormant gap closed)
  - `test-git-commit-scoped.sh`: 7 passed, 0 failed (unchanged-green, dormant gap closed)
  - Full core suite set (`run-all.sh`, 85 suites): 84 passed, 1 failed. The one failure
    (`test-verify-deploy-context-budget.sh` case4, a byte-count-drift check against
    `commands/orchestrate.md`'s verify-deploy Gate 20) is unrelated to this task — it references
    none of the five files this task touched, was last modified by unrelated tasks (142, 213), and
    was confirmed present on every redeploy performed during this task both before and after this
    task's edits. No suite regressed relative to the pre-change baseline.
  - shellcheck: clean for all 5 touched files. Every finding present is pre-existing and identical
    against each file's pre-task committed content; zero new findings introduced by this task's
    edits.
- Files verified: Yes — all 5 touched files diff-clean between the source store and the `.claude/`
  deployed copy after `deploy-headless.sh` (non-destructive default mode). `git status --porcelain
  -- .claude/` is empty (fully gitignored, confirmed via `git check-ignore`), so no hand-edits
  landed under `.claude/**`.

## Impacts

- The two previously-red core shell suites are green again, unblocking any CI/test-suite gate
  that depends on the full core suite set passing.
- `lint-json-channel-discipline.sh`'s real-corpus run now reports 0 violations (down from 2),
  removing a false-positive finding against `orchestrate-triage-classify.sh` without weakening
  the predicate's ability to catch genuine unredirected stdout writes (verified via the new
  regression case and the pre-existing "two genuine violations" case).
- Two dormant fixtures (`test-handoff-dispatch-identity.sh`, `test-git-commit-scoped.sh`) that
  carried the same latent missing-lib gap — currently green only because their exercised code
    paths never happened to trip the missing `source` — are now closed defensively, reducing
  future flake risk as `task-lock.sh`'s dependency surface grows.
- The downstream task that isolates shell suites from host state
  (`isolate_shell_suites_from_host_state`) can land its own changes to `core/scripts/tests/`
  cleanly on top: every fixture edit here was a single-token addition to an existing
  array/loop list, with no restructuring or style change.

## Follow-ups

- None. Suite (3) (`test-gate-out-repair-reporting.sh`) was withdrawn from scope by the dispatch
  addendum (confirmed green, 19/0, by research) and intentionally not touched.
- The pre-existing, unrelated `test-verify-deploy-context-budget.sh` case4 failure
  (`commands/orchestrate.md` byte-count drift against verify-deploy Gate 20) remains open but is
  out of this task's scope; it predates this task's changes and does not reference any file this
  task touched.

## References

- Plan: `specs/206_fix_test_fixtures_missing_task_lookup_lib/plans/01_fix-red-fixture-and-lint-predicate.md`
- Research report: `specs/206_fix_test_fixtures_missing_task_lookup_lib/reports/01_fixture-missing-task-lookup-lib.md`
- Progress files: `specs/206_fix_test_fixtures_missing_task_lookup_lib/progress/phase-{1..5}-progress.json`
- Dispatch: `specs/206_fix_test_fixtures_missing_task_lookup_lib/.dispatch/1.md`
