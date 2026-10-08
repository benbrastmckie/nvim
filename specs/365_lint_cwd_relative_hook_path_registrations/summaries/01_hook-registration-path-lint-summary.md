# Implementation Summary: Task #365

- **Task**: 365 - Lint forbidding CWD-relative paths and fragment-absent registrations in hook
  commands, wired as a verify-deploy gate
- **Status**: [COMPLETED]
- **Started**: 2026-10-07T22:30:00Z
- **Completed**: 2026-10-08T00:35:00Z
- **Effort**: ~7 hours across 3 dispatches
- **Dependencies**: Task 364 (completed)
- **Artifacts**: plans/01_hook-registration-path-lint.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added `lint-hook-registration-paths.sh`, a new source-store lint gating four independent defect
classes in hook registrations: a relative invoked-script path (any directory, not only
`.claude/`); the same defective shape taught by a copy-paste registration template in
source-store markdown; a registration reachable only through install-once
`root-files/settings.json` and by no fragment surface; and a registration invoking a
source-store script that does not exist. The lint is wired into `verify-deploy.sh` as gate 21
with an 18-assertion both-polarity `mktemp -d` fixture suite, and both new scripts are registered
in `manifest.json`.

## What Changed

- `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` — new file, 595
  lines, executable. Implements Check A (path shape in settings surfaces), Check B (path shape in
  markdown registration templates), Check C (fragment coverage of root-files registrations), and
  Check D (script existence). Fails CLOSED on a missing/broken shared library. Accepts
  `/`-absolute, `"$CLAUDE_PROJECT_DIR"`-anchored, and `~/`-anchored invoked-script paths; flags
  everything else.
- `agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh` — new file,
  603 lines, executable. 18 assertions (6 FAILING shapes + 9 PASSING shapes, plus a non-vacuity
  inversion check), all `mktemp -d`-built and torn down, no committed fixture files.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — added gate 21 (modeled on gate 12);
  widened the `--only-gate` range from 1-20 to 1-21 at all four named sites plus one extra stale
  prose mention.
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` — widened
  cases (b) and (d) to `seq 1 21`, moved the invalid-id probe from 21 to 22, updated the "all N
  gates" count strings.
- `agent-system/extensions/core/manifest.json` — registered both new scripts in
  `installed_files` at their alphabetically-correct positions.
- `specs/365_lint_cwd_relative_hook_path_registrations/plans/01_hook-registration-path-lint.md` —
  all six phases closed (five `[COMPLETED]`, Phase 6 `[COMPLETED WITH EXCLUSIONS]` with a
  `#### Reasoned Exclusions` record); all twelve dispatch acceptance criteria checked off with
  evidence.

## Decisions

- D1: `~/` accepted as a third anchor (cwd-independent via `$HOME`; already in deliberate use at
  `neovim-integration.md` line 34).
- D2: a `~/`-anchored path is exempt from the Check D existence test (user-supplied, outside the
  source store).
- D3: the lint's scan surface is settings JSON plus source-store markdown only — `.sh` files are
  never scanned, which is what makes the explicit-`cd` direct-invocation shape pass by scan
  scope, not by a classifier heuristic.
- D4: this lint's fragment-coverage identity deliberately diverges from `merge.lua`'s
  `hooks/`-anchored `hook_identity()` — `merge.lua` is outside this task's `file_scope`, and the
  divergence is recorded, not reconciled.
- D5: the fragment-coverage identity key is `(normalized invoked script path, event, type)`,
  normalization stripping only the anchor prefix.

## Plan Deviations

- None remaining. Phase 6's three earlier-deferred tasks (full-battery run, criterion walk,
  redeploy + re-verify) were all completed this dispatch; the plan's own `deviations` annotations
  were replaced with `*(completed: ...)*` evidence. One reasoned exclusion remains recorded in
  Phase 6's `#### Reasoned Exclusions` subsection (see Verification below) — this is a deliberate,
  evidenced exclusion, not an unresolved deviation.

## Verification

- Build: N/A (shell scripts)
- Tests: `test-lint-hook-registration-paths.sh` 18 passed / 0 failed (standalone and from inside
  a completed `run-all.sh --fail-on-new` invocation). `test-verify-deploy-gate-selection.sh` 5
  passed / 0 failed.
- Gate 21 standalone (`--only-gate 21 .`): `[PASS]`. Gate 21 from the deployed `.claude/` copy:
  exit 0, identical corpus counts to the source-store invocation.
- Full `verify-deploy.sh --skip-slow` battery (gates 1-7, 9-21): `1 of 34 check(s) failed` — the
  one failure is gate 13 (whole-tree orphan detection), attributable entirely to a separate,
  concurrently in-flight task's unfinished quarantine of `scripts/roadmap-integration.sh`
  (commits `bc2205f0d`, `9e3b1c5b8`), outside this task's `file_scope`. Gate 21 itself: `[PASS]`.
  Gate 8 (`run-all.sh`, the gate `--skip-slow` defers) run separately with `--fail-on-new`: 112
  passed, 5 failed (4 EXPECTED per `known-failures.txt`, 1 NEW — `test-verify-deploy-context-budget.sh`
  — traced to the identical gate-13 root cause via its own full-battery baseline fixture). 0
  failures trace to this task's own deliverable. Recorded as a Reasoned Exclusion in the plan's
  Phase 6 body.
- All 12 dispatch acceptance criteria verified with concrete command evidence (see plan's Testing
  & Validation section).
- Files verified: Yes (both new scripts executable, `jq empty manifest.json` succeeds, deployed
  copies byte-identical to source-store originals).

## Impacts

- Tasks 282 and 347 (both open, both adding hook registrations to
  `core/merge-sources/settings-hooks.json`) are now gated against reintroducing a CWD-relative
  registration or a fragment-unreachable registration.
- The four source-store markdown files carrying hook-registration templates
  (`neovim-integration.md`, `tts-stt-integration.md`, `wezterm-integration.md`,
  `workflow-interruptions.md`) are now guarded against drifting back to the defective shape.
- `root-files/settings.json` line 118's previously-silent dead registration
  (`scripts/claude-ready-signal.sh`, which exists nowhere) is now caught by Check D; fixing that
  line itself is out of this task's non-goals (it lives in the deployed consumer repo's
  install-once copy, not the source store).

## Follow-ups

- The gate-13 orphan-detection finding and gate-8's one NEW fixture failure
  (`test-verify-deploy-context-budget.sh`) will clear on their own once the separate, already
  in-flight `roadmap-integration.sh` quarantine task completes its deployment cleanup — no action
  needed from this task.
- `root-files/settings.json` line 118's dead `scripts/claude-ready-signal.sh` registration in the
  deployed consumer repo remains unfixed (explicitly out of this task's non-goals; the source
  store itself carries no such registration).

## References

- Plan: `specs/365_lint_cwd_relative_hook_path_registrations/plans/01_hook-registration-path-lint.md`
- Lint: `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh`
- Test: `agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh`
- `agent-system/extensions/core/scripts/verify-deploy.sh` (gate 21)
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh`
- `agent-system/extensions/core/manifest.json`
- Handoffs: `specs/365_lint_cwd_relative_hook_path_registrations/handoffs/`
