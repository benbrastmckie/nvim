# Implementation Summary: Task #586

- **Task**: 586 - Suite/gate wall-clock cost standing consumer
- **Status**: [IN PROGRESS]
- **Started**: 2026-11-17T19:52:58Z
- **Completed**: 2026-11-17T21:05:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None blocking. Two concurrent siblings (604, 624) shared this cycle's working
  tree; their declared `file_scope` sets were disjoint from this plan's.
- **Artifacts**: plans/02_suite-cost-consumer-actions.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Executed the five-phase plan acting on the audit's 0-DELETE/14-KEEP verdict instead of deleting
any suite. Phases 1, 2, 3, and 5 completed fully and are committed; Phase 4 closed `[PARTIAL]`
because host load rose above `measure-gate-costs.sh`'s idleness threshold partway through its
own measurement pass, blocking the probe-artifact regeneration — a deliberate, plan-sanctioned
deferral (the plan's own Rollback/Contingency section explicitly names this exact outcome as
acceptable) rather than a forced, contaminated result.

## What Changed

- `agent-system/extensions/core/scripts/claude-refresh.sh` — new, independently-gated leaked
  test-fixture reaper pass (`run_tmp_fixture_pass`/`take_tmp_fixture_live_refs`/
  `tmp_fixture_is_live_referenced`), wired into `main()`'s six-pass sequence and `print_help()`.
  Follows the same FORCE-gated three-mode contract as the existing Claude/Lean passes. Batches
  all metadata gathering (one `find -printf` call, one `du --files0-from=-` call, one
  `readlink -f <many args>` call) rather than forking per entry — an early per-entry-fork
  implementation measured ~44s against the real 1,733-entry `/tmp` backlog before this fix
  brought it down to ~3s.
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` — nine new
  assertions (block `(l)`) covering the new pass's three candidacy gates (ownership, no live
  `/proc/*/cwd`/`/proc/*/fd` reference, age threshold) and its FORCE-gated removal mechanics
  (including the non-writable-content leak mechanism), plus an extended mutation check.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — new `--corpus-probe` opt-in flag
  (default off) and an extended guard that skips the standing corpus-size probe on any
  gate-narrowed invocation (`--only-gate`/`--max-cost`) unless the flag is passed; an unfiltered
  invocation is unaffected. New header subsection documenting the full contract.
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` — two new
  assertions (case `(t)`) proving the suppression and the forced opt-in against the suite's real
  `FIXTURE_RICH` fixture.
- `agent-system/extensions/core/scripts/tests/run-all.sh` — comment-only pointer to the new
  decision record, naming it as the place the suite-population counting methodology is written
  down.
- `specs/decisions/suite-cost-delete-keep-verdict.md` (new) — the standing verdict (0 DELETE, 14
  KEEP over the recursive meta-suite class), the four-way suite-population counting methodology
  (157 / 197 / 179 / 204, each with its own re-derivation command), the demotion-tier
  non-recommendation, and the realized savings/residual state (including Phase 4's deferred
  regeneration, named explicitly as owed follow-up).
- Real `/tmp` leaked-fixture backlog reclaimed: 1,733 entries / 1.4 GB before, 240 entries /
  549 MB after.
- `.claude/` deployed tree regenerated via `deploy-headless.sh` (`RESULT=landed_verify_clean`).

## Decisions

- Matched the new `claude-refresh.sh` pass to the Claude/Lean passes' FORCE-gated three-mode
  contract (report under no-flag/`--dry-run`, act only under `--force`), not the build-waiter
  pass's age-threshold-only contract, because removal here is irrecoverable.
- Did not add a third automated test case asserting an unfiltered invocation still emits the
  corpus line — it would require a full, unfiltered gate battery against `FIXTURE_RICH`
  (measured ~22s), roughly doubling that suite's own cost for one assertion. Verified manually
  instead and recorded the result in the phase's own progress file and this summary.
- Phase 4's regeneration was deferred rather than forced through under host contention — a
  contaminated cost artifact is worse than a stale one, since `--max-cost` and `run-all.sh`'s own
  scheduler both act on these files.
- The complete, unfiltered `verify-deploy.sh` gate sweep was deferred to the batch-level stage
  for both Phases 3 and 5 (both declare `Verification Tier: full`), per the dispatch's Batch Gate
  Deferral directive — discharged instead via scoped suite/gate narrowing at each phase.

## Plan Deviations

- **Task 586 Phase 1** (performance): the first implementation of the leaked-fixture reaper pass
  forked `stat`/`du`/`readlink` once per candidate/symlink, measuring ~44s per invocation against
  the real backlog — not in the original plan task list. Fixed via batching before the phase
  closed; recorded via `issue-record.sh`.
- **Task 586 Phase 2** (near-miss, not altered): invoking the whole `claude-refresh.sh` script
  under `--force` to run the reaper also arms the Claude-process and Lean-LSP termination passes
  in the same invocation. No harm resulted (both reported zero actions), but recorded via
  `issue-record.sh` as a near-miss for future invocations to use a direct function call instead.
- **Task 586 Phase 3** (deferred, not altered): the plan's "unfiltered invocation still emits the
  corpus line" verification bullet was satisfied manually rather than as a third automated test
  case, for the cost reason stated above.
- **Task 586 Phase 4** (deferred): `gate-cost-model.csv` and `suite-cost-hints.txt` were not
  regenerated — host load rose to 3.26-3.86 (above the 2.0 threshold) partway through this
  phase's own measurement pass. `test-gate-cache-equivalence.sh`'s own re-timing (576.6s) is
  contaminated-suspected for the same reason and should not be cited as a confirmed figure.
  `test-verify-deploy-gate-selection-crash-net.sh`'s re-timing (78.68s, down from 148.6s) IS
  trustworthy — it completed in the foreground before load rose, with idleness confirmed
  throughout.

## Verification

- Build: N/A (shell scripts, no build step)
- Tests:
  - `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-claude-refresh-matcher.sh,test-lake-build-guard.sh` — 0 failures.
  - `bash agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` (direct) — 172 passed, 0 failed.
  - `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-verify-deploy-gate-selection.sh` — 0 failures (29 passed).
  - `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` — 0 findings across all five edited scripts.
  - `bash .claude/scripts/deploy-headless.sh` — `RESULT=landed_verify_clean`, 40 checks, 0 failures (fast-gate checkpoint).
  - `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4` — exit 0, 3 checks, 0 failures (doc-lint + task-reference lint over the new decision record).
  - The complete, unfiltered gate sweep is deferred to the batch-level stage per the dispatch's Batch Gate Deferral directive (not run independently in this dispatch).
- Files verified: Yes — all edited/created files confirmed present and committed; `git status --short` shows no uncommitted work from this task and no hand-authored file under `.claude/**`.

## Impacts

- Every gate-narrowed `verify-deploy.sh` invocation (`--only-gate`/`--max-cost`) now saves
  ~2.4 seconds of fixed corpus-probe overhead; `test-gate-cache-equivalence.sh` (28 invocations)
  and `test-verify-deploy-gate-selection-crash-net.sh` (~26 invocations) are the suites that pay
  this cost most, and the latter's own re-timing confirms a real ~47% wall-clock reduction.
  `claude-refresh.sh`'s hourly `--dry-run` systemd cadence now also reports leaked test fixtures
  (report-only; the cadence never passes `--force`, so it stays non-destructive).
- The leaked-fixture backlog is reclaimed going forward by routine `/refresh` usage, not just by
  this one-time sweep.
- Future suite-count citations have a single durable reference
  (`specs/decisions/suite-cost-delete-keep-verdict.md`) naming all four legitimate populations
  and their re-derivation commands, closing the "bare suite count is not a safe citation" gap.

## Follow-ups

- Resume Phase 4 once the host's 1-minute load average is confirmed idle (<=2.0) throughout the
  measurement window: re-time `test-gate-cache-equivalence.sh` again (its one prior re-timing is
  contaminated-suspected), then run
  `measure-gate-costs.sh --regen-hints --skip-gate-measure` and `measure-gate-costs.sh`, reading
  each artifact's own `# ALL_VALID=` header before trusting it, then re-read/stage both
  explicitly and record the realized total saving. This is named as owed follow-up in the
  decision record itself, not left only in `issues.jsonl`.

## References

- Plan: `specs/586_suite_gate_cost_standing_consumer/plans/02_suite-cost-consumer-actions.md`
- Research: `specs/586_suite_gate_cost_standing_consumer/reports/01_suite-gate-cost-audit.md`,
  `specs/586_suite_gate_cost_standing_consumer/reports/02_suite-cost-verdict-table.md`
- Decision record: `specs/decisions/suite-cost-delete-keep-verdict.md`
- Progress files: `specs/586_suite_gate_cost_standing_consumer/progress/phase-{1..5}-progress.json`
- Handoffs: `specs/586_suite_gate_cost_standing_consumer/handoffs/phase-{1,2,3,4,5}-handoff-*.md`
