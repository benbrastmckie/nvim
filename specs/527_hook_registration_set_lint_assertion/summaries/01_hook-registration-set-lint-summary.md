# Implementation Summary: Task #527

- **Task**: 527 - Extend the hook-registration lint so it asserts the deployed hook registration
  SET against the merge-source, not only the FORM of each individual command path, and wire the
  resulting gate into verify-deploy.sh
- **Status**: [COMPLETED]
- **Started**: 2026-11-17T09:51:00Z
- **Completed**: 2026-11-17T14:40:00Z
- **Effort**: ~5 hours
- **Dependencies**: `orphan_sweep_for_removed_merge_target_entries` (archived `[COMPLETED]`),
  `gate8_expected_vs_new_failure_distinction` (archived `[COMPLETED]`) -- both confirmed landed
  at plan time.
- **Artifacts**: plans/01_hook-registration-set-lint.md, records/01_live-drift-baseline.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added a fifth check ("Check E") to `lint-hook-registration-paths.sh` that compares a deployed
`.claude/settings.json`'s `(event, matcher, hook-identity)` registration SET against the union of
what the merge-source and root-files surfaces declare, reporting three drift shapes -- (a)
undeclared-but-present, (b) one identity double-registered under two matchers for one event, (c)
undeclared-and-absent -- as three distinct findings with three distinct remedies. Wired into Gate
21 (`verify-deploy.sh`) with zero edits to that script or `gate-registry.data`. Redeployed to
`RESULT=landed_verify_clean`.

## What Changed

- `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` -- `ALL_MATCHER`
  array, a `deployed` inventory group resolved through the same single batched identity-bridge
  call, a `--deployed-settings PATH` flag (pre-pass-stripped before the shared flag parser),
  `HOOK_REG_DEPLOYED_SETTINGS_OVERRIDE`, Check E's declared-set construction and carve-out-first
  per-row loop (shape (b) grouping, shape (a)/(c) existence split via a new
  `check_exists_deployed()`, deliberately never `check_exists()`), three remedy texts, summary
  counters, and header updates (FIVE CHECKS, D7 existence-boundary note). Also fixes a
  self-discovered defect: the deployed-settings default is now withheld (Check E sees zero rows)
  whenever an explicit scan-path argument was given without an explicit
  `--deployed-settings`/env override, so a caller testing Checks A-D against its own narrow
  fixture never has Check E silently widen into an ambient audit of the real deployed tree.
- `agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh` -- 7 new
  cases (19-25, case 23 split into 23a/23b) covering acceptance criteria 1-4 plus the
  missing-deployed-settings degrade; all 18 pre-existing cases confirmed unchanged.
- `agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md` --
  new "Source-Store-Relative vs. Deploy-Target-Relative Existence" subsection.
- `agent-system/extensions/core/index-entries.json` -- regenerated `line_count` for the narrative
  file above (171 -> 205).
- `specs/527_hook_registration_set_lint_assertion/records/01_live-drift-baseline.md` -- a fresh,
  27-repo fleet measurement superseding every carried field figure.
- A redeployed `.claude/` tree in this repository (`RESULT=landed_verify_clean`).

## Decisions

- Check E is a fifth check inside the existing lint, not a new script, absorbed by Gate 21's
  existing `requires_source_store: true` wiring with zero `verify-deploy.sh`/`gate-registry.data`
  edits.
- The identity notion is consumed, never redefined: Check E's declared-set key
  (`event\x01matcher\x01identity`) deliberately mirrors `merge.lua`'s own
  `M.hook_valid_set_key(event, matcher, identity)` builder, both resolved through the one shared
  `hook_identity_cli.lua` bridge.
- Shape (c)'s existence probe is deploy-target-relative (`check_exists_deployed()`), never a
  `check_exists()` reuse -- the latter is source-store-relative and would produce a false negative
  on exactly the defect shape (c) names. See the new narrative subsection for the full reasoning.
- Criterion 1 is met with real-deploy-derived fixtures: shapes (a) and (c) both have LIVE
  exemplars (neither needed reconstruction, better than the plan's own Scope Hypothesis assumed);
  shape (b) has no surviving live instance anywhere in the measured 27-repo fleet, so it is the
  one documented, minimal, cited reconstruction the plan anticipated.

## Per-Shape Criterion-1 Exemplar Provenance

| Shape | Provenance | Exemplar |
|---|---|---|
| (a) | **live** | `~/Projects/ModelBuilder/.claude/settings.json` -- `tts-notify.sh`/`wezterm-notify.sh` under `Stop\|*`, `wezterm-clear-status.sh` under `UserPromptSubmit\|*`, and `tts-notify.sh` under the wider `Notification` matcher, all undeclared, all present on disk |
| (b) | **reconstructed** | A verbatim copy of `~/Projects/Logos/Theory/.claude/settings.json` (real, clean) plus ONE added `Notification` matcher block for `tts-notify.sh` under `permission_prompt\|idle_prompt\|elicitation_dialog`, reproducing the exact matcher pair recorded verbatim in `specs/archive/369_orphan_sweep_for_removed_merge_target_entries/records/01_baseline-measurements.md` (lines 70-71) |
| (c) | **live** | `~/Projects/SPSDemo/.claude/settings.json` -- `scripts/claude-ready-signal.sh` under `SessionStart\|startup`, undeclared and absent on disk |

## Plan Deviations

- **Phase 1's Scope Hypothesis** assumed only shape (a) would survive live; the fresh measurement
  found shape (c) survives live too (13 of 27 repos), which only simplified downstream work
  (recorded as a `win`, not a deviation needing repair).
- **Phase 6, tasks 3-4**: the complete unfiltered `verify-deploy.sh` and `run-all.sh` sweeps were
  deferred to the batch-level stage per this dispatch's own Batch Gate Deferral directive, and
  discharged instead via `verify-deploy.sh --only-gate 21,3,4 --skip-unchanged` (4/4 green) and
  `run-all.sh --only <5-suite tier>` (4/5 green; the one failure proven pre-existing and
  unrelated -- see Verification).
- No other deviations; all other phases followed the plan as written.

## Verification

- Build: N/A (shell scripts).
- Tests: `test-lint-hook-registration-paths.sh` -- 32/32 PASS (18 pre-existing + 14 new
  assertions), confirmed both standalone and via `run-all.sh`, in the harness's DEFAULT
  post-redeploy subject-resolution mode.
- Gate 21: PASS against live state (1 check, 0 failures); FAILS against the ModelBuilder drifted
  exemplar via `HOOK_REG_DEPLOYED_SETTINGS_OVERRIDE` (4 `FINDING gate21`-tagged lines), with the
  live `.claude/settings.json` confirmed byte-unchanged (md5sum) before/after.
- `verify-deploy.sh --only-gate 21,3,4 --skip-unchanged`: 4 checks, 0 failures.
- `deploy-headless.sh`: `RESULT=landed_verify_clean`, exit 0, 40 checks / 0 failures in its own
  inline pass.
- Files verified: Yes -- every file in "What Changed" confirmed present and non-empty; the
  deployed `.claude/scripts/lint/lint-hook-registration-paths.sh` and its test counterpart
  confirmed byte-identical to the source-store copies via `diff`.
- One pre-existing test failure, `test-deploy-baseline-lib.sh` (3 of 30 cases: a stale "9 [PASS]
  lines" hardcoded assertion against `gate1_run`'s now-6-file event-store list, unrelated to hook
  registration), was PROVEN via `git stash push -- <this task's edited file>` isolation in Phase 2
  to fail identically with this task's own change entirely removed. Not caused by this task; left
  pre-existing and unrepaired, outside this task's declared hooks-only scope.

## Impacts

- Three measured drift shapes (undeclared-but-present, duplicate-matcher double-fire,
  undeclared-and-absent) in a deployed `.claude/settings.json` now fail Gate 21 instead of
  accumulating silently. 13 of the 27 repos measured in Phase 1 are currently drifted and will
  surface as findings the next time Gate 21 (or this lint ad hoc) runs against them -- remediating
  those repos is explicitly out of this task's scope (Phase 1 records it; fixing it is a future
  task's work).
- A hand-written custom hook registration is structurally guaranteed never to be reported (the
  nil-identity carve-out runs first, unconditionally).
- The `SCAN_PATH_GIVEN` fix is a reusable precedent for any future check in this script (or a
  sibling lint) that needs a second, independently-scoped input alongside the existing
  scan-path-driven one.

## Follow-ups

- None required by this task's acceptance criteria. Optionally: remediate the 13 live-drifted
  repos Phase 1 measured (not this task's scope), and investigate/fix `test-deploy-baseline-lib.sh`'s
  unrelated `gate1_run` file-count mismatch (a separate, pre-existing defect).

## References

- Plan: `specs/527_hook_registration_set_lint_assertion/plans/01_hook-registration-set-lint.md`
- Research report: `specs/527_hook_registration_set_lint_assertion/reports/01_hook-registration-set-lint.md`
- Fleet measurement: `specs/527_hook_registration_set_lint_assertion/records/01_live-drift-baseline.md`
- Prior baseline: `specs/archive/369_orphan_sweep_for_removed_merge_target_entries/records/01_baseline-measurements.md`
- Phase handoffs: `specs/527_hook_registration_set_lint_assertion/handoffs/`
