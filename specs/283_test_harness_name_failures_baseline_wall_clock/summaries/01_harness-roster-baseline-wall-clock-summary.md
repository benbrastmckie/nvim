# Implementation Summary: Task #283

- **Task**: 283 - Fix the agent-system test harness (run-all.sh): name failing suites, add a
  known-failing baseline, and reduce wall clock
- **Status**: [COMPLETED]
- **Started**: 2026-09-30T12:19:00Z
- **Completed**: 2026-09-30T14:45:00Z
- **Effort**: ~2.5 hours (plan estimated 7 hours)
- **Dependencies**: None
- **Artifacts**: plans/01_harness-roster-baseline-wall-clock.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed all three defects the dispatch named in `agent-system/extensions/core/scripts/tests/run-all.sh`
and its orchestrator call sites: failing suites are now named in a consolidated, regression-tested
end-of-run roster; a committed, machine-readable `known-failures.txt` baseline lets a run report
`N failed (E expected, X NEW)`; and the dominant wall-clock cost (the orchestrator's own redeploy
checkpoints re-running the full 105-suite battery 2-3 times per cycle) was removed via `--skip-slow`
on all five `deploy_findings_snapshot` call sites, measured at an 85% reduction (13m48s -> 2m4s)
for one such invocation. Along the way, a shared stale-fixture bug that accounted for 3 of the 8
originally-named failures was fixed at its root cause.

## What Changed

- `agent-system/extensions/core/scripts/tests/test-handoff-dispatch-identity.sh`,
  `test-orchestrate-context-growth.sh`, `test-orchestrate-recover-message-findings.sh` — replaced
  each suite's hardcoded `lib/` copy-list with a glob-copy (`cp "$CORE_DIR"/lib/*.sh ...`),
  matching the precedent at `test-force-phases.sh:106`. All three were failing solely because their
  copy-lists predated `return-meta-status-vocabulary.sh` being added as a real dependency of
  `orchestrate-cycle-postflight.sh`; none reflected a defect in the handoff-identity contract
  itself (the dispatch's own explicit question).
- `agent-system/extensions/core/scripts/tests/run-all.sh` — added a `FAILED_SUITE_NAMES` array, an
  end-of-run `[run-all] Failing suites (N):` roster block (unconditional, `[FAIL]`-token-free by
  construction), optional `known-failures.txt` manifest reading, EXPECTED/NEW classification on
  both the roster and the tally line, and an opt-in `--fail-on-new` flag. Default exit-code
  semantics are unchanged; a missing manifest degrades to exactly the pre-existing output.
- `agent-system/extensions/core/scripts/tests/known-failures.txt` — new, advisory, basename-keyed
  manifest. Seeded from a fresh live run taken after the stale-fixture fix landed: 4 rows
  (`test-gate-out-repair-reporting.sh`, `test-lint-json-channel-discipline.sh`,
  `test-verify-deploy-context-budget.sh` as `real-defect`; `test-run-all-parallel.sh` as
  `intermittent`). `test-typst-element-lint.sh` was deliberately excluded — its redness traced to
  another, concurrently in-flight session's uncommitted WIP on `typst-element-lint.sh`, not a
  committed defect.
- `agent-system/extensions/core/scripts/tests/test-run-all-failure-reporting.sh` — new regression
  suite (32 cases): inline `[FAIL]` naming, roster presence, roster/tally count agreement, the
  `[FAIL]`-token double-count guard, `--quiet` and `--jobs 3` parity, empty-roster-on-green, and
  the full manifest/`--fail-on-new` classification matrix. Confirmed to fail loudly (8 of 22 cases)
  when the roster code is temporarily reverted, proving it is not vacuously green.
- `agent-system/extensions/core/manifest.json` — added `tests/known-failures.txt` and
  `tests/test-run-all-failure-reporting.sh` to `provides.scripts`.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — added `--skip-slow` to all
  three `deploy_findings_snapshot` call sites (pre-redeploy, post-redeploy, confirm). Replaced the
  pre-existing "DEFECT A" full-depth-is-deliberate comment (which documented the opposite choice)
  with an accurate account of the new trade-off, including a residual-gap finding discovered during
  this work (see Decisions below).
- `agent-system/extensions/core/scripts/command-gate-out.sh` — added `--skip-slow` symmetrically to
  both `deploy_findings_snapshot` call sites (pre- and post-redeploy).
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — retired the stale
  "Known pre-existing failures and flakes" prose list in favor of a pointer to
  `known-failures.txt`, kept the category-meaning explanations, and documented the roster,
  `--fail-on-new`, and `--skip-slow` contracts.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — added a note
  to the Inter-Cycle Redeploy Checkpoint section recording this task's `--skip-slow` decision
  alongside the prior "sibling redundant-verify-deploy-passes" task's finding it partially
  supersedes (see Decisions below).

## Decisions

- **Glob-copy over per-file `LIBS` list for the three Phase-1 suites**: chosen over adding the
  single missing filename, because `lib/` is only 16 files / 188K (no material sandbox-setup
  slowdown) and this closes the whole class of drift, not just this one instance.
- **Owner field uses durable anchors, never bare task numbers**: `known-failures.txt` lives under
  `agent-system/extensions/**`, where `no-task-references-in-deliverables.md` prohibits task-number
  citations. All `real-defect` rows use `needs-owner`; the `intermittent` row uses
  `accepted (see this suite's own case3/4 comment...)`.
- **`test-typst-element-lint.sh` excluded from the manifest**: its failure traced to another
  session's uncommitted WIP at seed time (confirmed via `git status`/`git diff`), not a committed
  defect. Re-add it as `real-defect` if it is still red against a clean, fully-committed tree.
- **Material residual-risk finding (discovered mid-implementation, not anticipated by the plan's
  Risk table in this specific form)**: `context/patterns/batch-orchestration-guardrails.md`
  already documents a prior "sibling redundant-verify-deploy-passes" task that investigated and
  REJECTED a weaker version of this same optimization (sharing one Gate-8 capture between the
  pre- and post-redeploy snapshot), because roughly 40 of the ~73 suites under
  `agent-system/extensions/core/scripts/tests/` resolve their own subject-under-test
  preferentially from the DEPLOYED tree (`$REPO_ROOT/.claude/scripts/...`, a
  deploy-tree-first/source-store-fallback pattern — e.g. `test-assess-repo-health.sh`), not the
  source-store sibling. For those suites, a dispatched agent's own pre-deploy phase-gate run of
  `run-all.sh` tests the STALE deployed copy, never its own just-made edits; only a run taken
  AFTER `deploy-headless.sh` lands tests the fresh, just-deployed copy. This task's `--skip-slow`
  change is a STRICTER version of the idea that prior task rejected: it defers gate 8 on BOTH
  sides of every pre/post pair, so those ~40 suites now receive NO coverage from this checkpoint
  against a freshly-deployed tree at all (worse than the rejected single-capture idea, which would
  at least have run gate 8 once). This was a deliberate choice, not an oversight, made because the
  measured wall-clock cost (a single dispatch consuming ~45 minutes, per the dispatch's own
  account) was judged to dominate the residual coverage loss — but it is flagged here, in the code
  comments (search "DEFECT A / --skip-slow WALL-CLOCK TRADE-OFF" in `orchestrate-cycle-plan.sh`),
  and in `batch-orchestration-guardrails.md` for explicit human review rather than silently
  accepted. See Follow-ups below.
- **`index-entries.json` left unmodified**: attempted to refresh the `shell-script-testing.md`
  entry's summary/keywords per Phase 6, then reverted the edit on discovering the file is
  concurrently modified by another in-flight session in this repo (unrelated `state-schema.json`
  line-count changes observed via `git diff`). Committing the file under this task would have
  swept in that foreign uncommitted work (`git-commit-scoped.sh` stages whole files, not hunks).

## Plan Deviations

- **Phase 4, task "Row format"**: owner uses a durable anchor or `needs-owner`, never a bare task
  number as the plan's literal task text suggested — corrected per the no-task-references rule
  (Phase 6's own task list already anticipated and required this correction).
- **Phase 6, task "Verify the `index-entries.json` entry"**: skipped (see Decisions above) due to
  concurrent-session contention on that file, rather than hand-edited under risk of sweeping in
  foreign changes.
- **Commit granularity**: Phase 2's and Phase 4's edits to `run-all.sh` were made in the same
  working-tree session before the first commit of that file, so the "phase 2" commit
  (`31e300c1f`) incidentally includes Phase 4's `run-all.sh` code (manifest classification,
  `--fail-on-new`) alongside Phase 2's roster code. No functional impact — both phases' code is
  correct and tested — but the commit boundary does not exactly match the phase boundary for that
  one file.

## Verification

- Build: N/A (shell scripts)
- Tests: All new/modified suites green —
  `test-handoff-dispatch-identity.sh` (8/8), `test-orchestrate-context-growth.sh` (6/6),
  `test-orchestrate-recover-message-findings.sh` (23/23),
  `test-run-all-failure-reporting.sh` (32/32, confirmed non-vacuous by reverting the roster code),
  `test-orchestrate-cycle-plan.sh` (331/331), `test-deploy-baseline-lib.sh` (7/7).
- A live 105-suite `run-all.sh` run reports exactly 5 failures (down from the dispatch's originally
  named 8), with the roster and tally counts agreeing and zero `[FAIL]`-token double-counting
  confirmed by direct inspection and a live `verify-deploy.sh --findings --only-gate 8` run.
- Files verified: Yes — all new files exist, are executable where required, and are registered in
  `manifest.json`'s `provides.scripts`.
- `bash .claude/scripts/check-task-references.sh`: 0 unexempted occurrences.
- No file under `.claude/**` was hand-edited (gitignored; confirmed via `git check-ignore`).

## Impacts

- An agent no longer needs to set-difference `[RUN]`/`[PASS]` markers to discover which suites
  failed — the roster names them directly, and the manifest tells it immediately whether a failure
  is pre-existing or its own.
- The orchestrator's own inter-cycle and postflight redeploy checkpoints no longer re-run the full
  105-suite shell battery, removing the single largest measured contributor (13m48s -> 2m4s per
  invocation, up to 3 invocations per cycle) to the ~45-minute single-dispatch wall-clock cost the
  dispatch measured.
- A future reader of `context/standards/shell-script-testing.md` finds one source of truth for the
  known-failing set instead of a prose list that had already gone stale once.

## Follow-ups

- Spawn a follow-up task to fix (or formally re-triage) the 3 `needs-owner` real-defect rows in
  `known-failures.txt`: `test-gate-out-repair-reporting.sh` (state accumulation/reset bug in
  `validate-artifact.sh`), `test-lint-json-channel-discipline.sh` (stderr-corrupts-JSON bug in
  `chapter-quality-check.sh`), `test-verify-deploy-context-budget.sh` (live Gate 20 over-budget
  findings against `skill-orchestrate/SKILL.md`).
- Spawn a follow-up task to design a narrower, wall-clock-cheap alternative to this task's
  `--skip-slow` choice for the redeploy checkpoint: running only the ~40 deploy-tree-first suites
  (identified via their `REPO_ROOT/.claude/scripts` resolution pattern) against gate 8
  post-redeploy, instead of either the full 105-suite battery (too slow) or nothing (the material
  coverage gap this task's Decisions section documents). This is the same
  "changed-files-to-affected-suites selector" the plan's own Non-Goals deferred, now with a
  concretely scoped starting point.
- Re-check `test-typst-element-lint.sh` against a clean, fully-committed tree once the other
  in-flight session's `typst-element-lint.sh` WIP lands or is reverted; add it to
  `known-failures.txt` as `real-defect` if it is still red.
- Refresh `index-entries.json`'s `standards/shell-script-testing.md` entry (summary, keywords,
  line_count) once the file is not concurrently contended by another session.

## References

- Plan: `specs/283_test_harness_name_failures_baseline_wall_clock/plans/01_harness-roster-baseline-wall-clock.md`
- Research: `specs/283_test_harness_name_failures_baseline_wall_clock/reports/01_test-harness-defects-research.md`
- `agent-system/extensions/core/scripts/tests/run-all.sh` (roster, manifest, `--fail-on-new`)
- `agent-system/extensions/core/scripts/tests/known-failures.txt` (baseline manifest)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (Inter-Cycle
  Redeploy Checkpoint section, including the prior "sibling redundant-verify-deploy-passes" finding
  this task's `--skip-slow` change partially supersedes)
