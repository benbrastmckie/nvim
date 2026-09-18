# Implementation Summary: Task #213

- **Task**: 213 - Thread focus prompt into cycle plan (absorbed former tasks 214 and 216)
- **Status**: [COMPLETED]
- **Started**: 2026-09-18T04:43:58Z
- **Completed**: 2026-09-18T10:30:00Z
- **Effort**: ~6 hours
- **Dependencies**: None
- **Artifacts**: plans/01_focus-forced-phase-cycle-budget.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed three coupled defects in the batch `/orchestrate` engine (`orchestrate-cycle-plan.sh`, a
1,859-line script, plus its collaborators): (A) a user-typed `$2+` focus prompt never reached the
dispatched agent's dispatch file; (B) a forced-phase queue that emptied silently fell through to
ordinary status-derived dispatch instead of stopping for the rest of the run; (C) the per-task
work-cycle budget accumulated across separate `/orchestrate` invocations while forced plan/
implement admission ignored which artifacts actually existed. All seven phases of the plan are
now `[COMPLETED]`, the full source-store test suite passes (83/84 suites; the one remaining
failure is pre-existing and unrelated — see Follow-ups), and the fix was redeployed and confirmed
against a real, separate consumer repository (`~/Projects/Logos/Verification`).

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — added `--focus` flag parsing
  and a shared `compose_focus()` helper composing the user's focus text with a task's
  `research_questions` into one labelled `--focus` value for every phase; added
  `forced_round_seeded` tracking and a three-way branch in section (f) so a task whose forced
  queue empties THIS run is excluded via a `blocked[]` row (`"forced round complete"`) instead of
  falling through to status-derived dispatch; removed durable `cycle_count` seeding/flushing
  (per-run budget, resets every invocation) and removed `--continue-budget` end to end; added
  durable `dispatch_seq_counter` seeding (max-based) and `--flush-seq` calls at both dispatch_seq
  mint sites (main loop and aux-dispatch loop) so a dispatch_seq never repeats across runs; added
  a forced-implement-with-no-plan blocked-row check; changed `resolve_agent()`'s `plan)` arm to
  pick `reviser-agent` when a plan exists, `planner-agent` otherwise.
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — the `plan` branch now
  also resolves the newest `plans/*.md` and renders `- existing_plan_path:`/`- revision_reason:`
  (the field names `agents/reviser-agent.md` expects) whenever a plan exists.
- `agent-system/extensions/core/scripts/orchestrate-loop-guard-init.sh` — extended `--seed`'s
  output to also peek `dispatch_seq_counter`; added a new `--flush-seq` form (mirrors `--flush`
  but for `dispatch_seq_counter`); updated header documentation to reflect the per-run budget
  contract and the now-stale `budget-continuation-override` locked-region history.
- `agent-system/extensions/core/scripts/parse-command-args.sh` — removed `CONTINUE_BUDGET_FLAG`
  end to end (default, detection, strip pattern, export list).
- `agent-system/extensions/core/scripts/skill-base.sh` — corrected a stale comment naming the
  now-deleted `test-loop-guard-budget-override.sh` and an inaccurate `append_detected_defect`
  stubbing claim.
- `agent-system/extensions/core/commands/orchestrate.md` — added `focus_prompt` to the parsed-flag
  list and dry-run short-circuit (array-based, quote-safe); fixed "falls through" contradictions
  in the Constraints prose and the `force_phases` delegation bullet; added the artifact-admission
  rule to the `--plan`/`--implement` option rows; confirmed `--continue-budget` fully removed.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — added `focus_prompt` to the
  Setup list and Move 1's `orchestrate-cycle-plan.sh` call (bash-array quoting, not the
  word-splitting `$(...)` idiom); added a MUST NOT against live re-invocation purely to inspect
  state (`--dry-run`/`mt_state_file` are the only sanctioned checks); documented the
  `forced_round_complete` blocked-row contract.
- `agent-system/extensions/core/merge-sources/claudemd.md` — fixed the Multi-task syntax
  paragraph's "falling through" contradiction; added the per-run budget contract and the
  artifact-admission rule to the `/orchestrate` command-table row.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — extended the
  `--focus` narrative (two locations) to cover the two-segment composition; added a NEW
  non-terminal, same-run worked example (beside the existing terminal-task example) showing the
  observed live incident and its fix; corrected the "Maximum dispatch cycles" narrative to state
  the per-run contract and `dispatch_seq_counter`'s continuing durability.
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` — replaced the
  "Defect B" cumulative-budget section with the per-run contract and rationale; fixed the
  `pending_dispatch` section's stale cross-reference to the removed override; recorded the
  loop-guard-staleness detector's now-moot relationship to budgeting.
- Tests: new/extended cases in `test-orchestrate-cycle-plan.sh` (Groups 22, 23; inverted Group
  2/4-5/8/18/19 assertions), `test-force-phases.sh` (new stop-after-forced-phase + counter-case
  section), `test-session-runtime-files.sh` (inverted Case 3), `test-orchestrate-build-dispatch.sh`
  (new Group 11: `existing_plan_path`/`revision_reason` rendering + newest-report pin),
  `test-mint-dispatch-seq.sh` (comment fix only). Deleted
  `scripts/tests/test-loop-guard-budget-override.sh` (its whole subject — the removed override).
- `agent-system/extensions/core/manifest.json` — removed the stale scripts entry for the deleted
  test file (fallout caught by the full-suite pass).
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` — deliberately
  bumped the eager-load budget baseline (fallout from the deliberate doc-content growth).

## Decisions

- User focus applies to research, plan AND implement dispatches (matches `commands/orchestrate.md`'s
  `$2+` contract and `orchestrate-build-dispatch.sh`'s phase-agnostic rendering); `research_questions`
  stays research-only, unchanged.
- The forced-round-complete exclusion is `blocked[]`, not a new top-level array — no schema change
  needed downstream.
- Chose `--flush-seq` (a new, uniform `orchestrate-loop-guard-init.sh` form) over reusing
  `skill-base.sh`'s `skill_orchestrate_mint_dispatch_seq` at the aux-dispatch mint site, because
  that site runs before `skill-base.sh` is sourced in `orchestrate-cycle-plan.sh`.
- `cycle_count` is left inert in the durable guard file's schema (never read/written by the batch
  engine again) rather than migrated/deleted, so old guard files need no special handling.

## Plan Deviations

- **Phase 3 manual verification**: the plan's `--dry-run` re-check bullet cannot literally observe
  `forced_round_seeded` state (confirmed: `--dry-run` never reads the persisted `mt_state_file` by
  pre-existing design). Verified via a second LIVE call instead, which does show the `blocked[]`
  row; exhaustively covered by LIVE-to-LIVE fixture cases.
- **Group 21 Case E** (an existing test, not one this plan's file list originally named): fixed a
  fixture gap the new artifact-based admission rule correctly caught (the fixture task had no
  plan artifact) by giving it one, preserving the case's original intent.
- **Phase 4/6 grep verification**: 9 intentional `continue-budget`/`continue_budget` string hits
  remain (2 historical-context code comments explaining the removal, plus a new regression test
  proving the flag is now rejected) — followed the task's own top-level ACCEPTANCE wording
  ("grep finds nothing in the source store outside history") over a phase-local literal-zero-hits
  bullet, since a strictly-zero bar would make it impossible to test the removal.
- **Phase 5 verification**: `test-orchestrate-build-dispatch.sh` resolves its SUT deploy-tree-first
  by documented design; the 2 new Group 11 assertions failed against the pre-redeploy `.claude/`
  copy (verified correct by temporary sync-and-revert) and now pass genuinely post-redeploy (72/72).
- **Phase 6 re-grep**: the literal grep pattern over-matches dozens of unrelated pre-existing hits
  across the source store (the common phrase "falls through" used for unrelated mechanisms);
  manually confirmed none contradicts this task's own 3 defects rather than expanding scope.
- **Phase 7 fallout**: two genuine fallout items were found and fixed during the full-suite/redeploy
  pass (a stale `manifest.json` entry for the deleted test file; the eager-load context-budget
  baseline) — see What Changed.

## Verification

- Build: N/A (shell/markdown source store; no compiled build)
- Tests: `test-orchestrate-cycle-plan.sh` 199/199, `test-force-phases.sh` 33/33,
  `test-session-runtime-files.sh` 6/6, `test-mint-dispatch-seq.sh` 14/14,
  `test-orchestrate-build-dispatch.sh` 72/72 (post-redeploy), full `run-all.sh` 83/84 (the one
  remaining failure is pre-existing/unrelated — see Follow-ups). `shellcheck --severity=warning`
  clean (zero new warnings) on every edited `.sh`.
- Files verified: Yes
- Deploy: `deploy-headless.sh --wipe` — `RESULT=landed_verify_clean`, 33/33 verify-deploy checks.
- Consumer-repo confirmation (`~/Projects/Logos/Verification`, resync-deployed): focus threading
  (`--dry-run --focus` shows the composed `User focus:` text), stop-after-forced-phase (a repeated
  and an omitted-flag re-check both produce zero dispatch rows and the `forced_round_complete`
  blocked row), and dispatch_seq durability (two separate runs minted strictly increasing durable
  seq values, 2 then 3, no repeat) — all confirmed live against a scratch copy of that repo's own
  tree, its own real working copy left untouched beyond the one intended resync deploy.

## Impacts

- `/orchestrate N --research "<questions>"` (and `--plan`/`--implement`) now threads the user's
  typed focus text into the dispatched agent's context with no hand editing required.
- A forced round genuinely terminates for the rest of a run once exhausted — no more silent
  drift into unintended plan/implement work on a later check within the same invocation.
- `--continue-budget` is gone; re-running `/orchestrate` is the only, always-available way to
  continue past an exhausted per-run budget, and repeated forced runs are never spuriously refused.
- Forced `--plan`/`--implement` now correctly key off artifact presence rather than status,
  closing the "reviser has nothing to revise" and "implement dispatched with no plan" gaps.

## Follow-ups

- `test-gate-out-repair-reporting.sh` (4 failing cases) is a pre-existing failure in the full
  suite, confirmed via `git log`/clean `git status` to be unrelated to and predate this task
  (last touched by an unrelated, already-merged task). Not fixed here — out of scope.
- `commands/orchestrate.md` remains over its configured context-budget ceiling (19,967 B vs.
  8,000 B) — a pre-existing, already-documented, warn-tier gap this task's edits made
  incrementally larger; a future trim is recorded as a separate follow-up, not fixed here.
- `--force-phases` is still not forwarded to `commands/orchestrate.md`'s `--dry-run`
  short-circuit — a known, named, separate gap this task deliberately did not widen scope to fix.

## References

- Plan: `specs/213_thread_focus_prompt_into_cycle_plan/plans/01_focus-forced-phase-cycle-budget.md`
- Research report: `specs/213_thread_focus_prompt_into_cycle_plan/reports/01_focus-prompt-forced-phase-cycle-plan.md`
- Progress files: `specs/213_thread_focus_prompt_into_cycle_plan/progress/phase-{1..7}-progress.json`
