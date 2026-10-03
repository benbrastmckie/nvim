# Implementation Summary: Task #327

- **Task**: 327 - Repair the extension lifecycle hook mechanism: broken resolver schema, absent
  return-code channel, uninvoked verification stage
- **Status**: [COMPLETED]
- **Started**: 2026-10-03T08:45:00Z
- **Completed**: 2026-10-03T12:40:00Z
- **Effort**: ~3.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_lifecycle-hook-mechanism-repair.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

The extension lifecycle hook mechanism in `agent-system/extensions/core/scripts/skill-base.sh`
was dead on four independent counts: its resolver queried a `.loaded_extensions` key that has
never existed in the live `.claude-extensions.json` schema; its hook-script path assumed a
nested deploy layout the deploy pipeline never produces; a non-zero hook exit reached no caller
through any channel; and the `verification` stage's only call site sat in a function nothing
calls. All seven plan phases are complete: the resolver and hook-path are fixed and proven live
against the real `nix`/`neovim` extensions, an observable-but-never-blocking rc channel was
added, the `verification` stage now has a live call site in `command-gate-out.sh`, ten new
regression cases were added and mutation-checked, `creating-extensions.md` was brought into
agreement with the repaired mechanism, and `check-extension-docs.sh` gained a new validator rule
(Rule W) that would have caught the original defect.

## What Changed

- `agent-system/extensions/core/scripts/skill-base.sh` — `skill_get_extension_dir` now resolves
  the real object-schema `.claude-extensions.json` (`.extensions | to_entries[] | select(status
  == "active")`) joined with each deployed extension's own manifest `task_type`.
  `skill_run_extension_hook` resolves hook scripts by basename against the flat deployed
  `.claude/scripts/` directory (accepting both the `scripts/`-prefixed source-mirroring form and
  a bare filename), emits a loud stderr NOTE instead of a silent skip when a resolved hook is
  missing/non-executable, and exposes four `SKILL_HOOK_LAST_*` globals (`_RC`, `_STATUS`,
  `_NAME`, `_PATH`) reset unconditionally at function entry. The function's literal last
  statement remains `return 0` — the non-blocking disposition is structural, not conventional. A
  non-zero hook exit additionally appends one `deviation`-category row to `specs/events.jsonl`.
- `agent-system/extensions/core/scripts/command-gate-out.sh` — reads `task_type` from
  `specs/state.json` (this script previously had none in scope at all) and invokes the
  `verification` hook immediately after its existing `skill_validate_task_artifacts` call — the
  first live call site for that stage on a path that runs for every task.
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` — new Group 5 (10
  cases: resolver hit/miss/inactive-status/no-file, hook-fires in both the bare and
  `scripts/`-prefixed manifest forms, rc observability, reset discipline, and the loud-skip
  NOTE), sourced source-store-first in per-case subshells (the reverse of the suite's own
  deployed-tree-first default, deliberately, since the functions under test are mid-edit in the
  source store). `skill_get_extension_dir` and `skill_run_extension_hook` removed from the
  suite's residuals footer.
- `agent-system/extensions/core/docs/guides/creating-extensions.md` — added the hook-script
  path-resolution rule to the Hook Schema section, an rc-observability subsection beneath the
  unchanged "Exit non-zero: warning logged (non-blocking, skill continues)" sentence, and
  corrected the Lifecycle Stage Mapping table's `verification` row to name the live gate-out
  call site instead of the callerless `skill_validate_artifact()`.
- `agent-system/extensions/core/scripts/check-extension-docs.sh` — new Rule W
  (`check_lifecycle_hooks_resolve`): for every extension, validates that each top-level
  `hooks.<stage>` value names a valid stage and a basename declared in `provides.scripts`
  (`fail()` — a manifest authoring error no deploy can fix), and separately flags a
  declared-but-not-yet-deployed or non-executable resolved script (`advisory()` — mirrors
  `check_core_deploy_advisory`'s existing FAIL-vs-ADVISORY rationale). Registered in the Rule
  letter index and the per-extension dispatch loop.

## Decisions

- rc is observable only, never returned — every one of the four `skill_run_extension_hook` call
  sites is unmodified, and no opt-in blocking mode was added (recorded decision, carried from
  research through to the doc update).
- The pre-existing, callerless `skill_validate_artifact()` hook call was left in place
  (commented as a deliberate, harmless duplicate cross-referencing the new live site) rather
  than removed.
- Basename resolution accepts both the `scripts/`-prefixed form (what `nix`/`nvim` actually use)
  and a bare filename, so neither manifest needed to change.
- Rule W's severity split (advisory for not-yet-deployed, fail for a bad stage name or an
  undeclared-in-`provides.scripts` basename) mirrors `check_core_deploy_advisory`'s existing
  rationale rather than inventing a new one.

## Plan Deviations

- Phase 4's mutation-check restore used `cp` from a pre-mutation backup instead of `git checkout
  -- <path>` — the repo's destructive-git guard correctly blocked the `git checkout` approach on
  a dirty tree before any command in that invocation ran at all (confirmed via `git status`, no
  damage). End state is identical; see `progress/phase-4-progress.json`.
- Phase 7's `test-gate-out-repair-reporting.sh` run reports 1 failure (Case 1's summary-line
  assertion) that is NOT a regression from this task: the identical failure was reproduced
  against the pre-task `command-gate-out.sh`/`skill-base.sh` content (commit `202b76734^`,
  restored via `cp`/confirmed via `git status`), tracing to a drift between
  `validate-artifact.sh`'s current output shape and that fixture's pinned expectation — unrelated
  to the lifecycle hook mechanism. Left unfixed as out of this task's scope; see
  `progress/phase-7-progress.json` for the full reproduction record.
- Phase 7's full `verify-deploy.sh` run (no `--skip-slow`) is NOT clean: 6 of 34 checks failed.
  Every failure was individually attributed in `progress/phase-7-progress.json`'s
  `full_gate_set_result`. Two checks (doc-lint, verify.lua) show exactly this task's own 5
  edited files as deployed-vs-source drift — EXPECTED, see Deploy State below. The remaining
  four (agent-contracts lint on an unrelated books agent file; 4 of `tests/run-all.sh`'s 110
  suites, 3 already tagged `(EXPECTED)` by that runner itself plus 1 in the unrelated typst
  extension; a transient orphan-file finding that no longer existed moments later; and
  task-lookup-adoption lint in the unrelated present/web extensions) are pre-existing and
  unrelated to this task's 5 files. This plan's own "Repository full gate set clean" Testing &
  Validation line is annotated as a deviation (altered) rather than checked off at face value.

## Verification

- Build: N/A (shell scripts; `bash -n` passes on all four changed files)
- Tests: `test-skill-base-lifecycle.sh` 48 passed / 0 failed (10 new cases, mutation-checked:
  7/10 provably FAIL against the old `.loaded_extensions` resolver). `test-gate-out-repair-reporting.sh`
  18 passed / 1 failed (pre-existing, unrelated — see Plan Deviations). `check-extension-docs.sh`
  shows zero new findings for `nix`/`nvim`; its only FAILs are this task's own 4 expected
  source/deploy drift lines.
- `shellcheck`: clean vs. captured pre-edit baselines on all four changed shell files.
- Task-reference lint: 0 occurrences across all 5 changed files.
- Full gate set (`verify-deploy.sh`, no `--skip-slow`): FAIL, 6 of 34 checks, fully attributed
  (see Plan Deviations above and `progress/phase-7-progress.json`) — 2 are this task's own
  expected source/deploy drift, 4 are pre-existing and unrelated.
- End-to-end proof: `skill_get_extension_dir nix` → `.claude/extensions/nix` (was empty);
  `skill_get_extension_dir neovim` → `.claude/extensions/nvim` (was empty); the real
  `nix-preflight.sh`, `nix-context.sh`, `nvim-context.sh` hooks all fire live via
  `skill_run_extension_hook` and exit 0 (previously dead, never invoked by any mechanism).
- Files verified: Yes (all five target files edited and verified individually per phase).

## Impacts

- The `nix` and `neovim` extensions' previously-dead `preflight`/`context_injection` hooks now
  fire on every real `/research`, `/plan`, `/implement` dispatch for those task types, once the
  source store is deployed (see Deploy State below). Both hook scripts were independently
  confirmed benign (`exit 0` console probes).
- Any future extension author gets a loud NOTE instead of a silent no-op if their declared hook
  path does not resolve, and `check-extension-docs.sh`'s new Rule W catches the same class of
  defect at lint time, before the hook ever ships silently dead.
- The `verification` lifecycle stage is now reachable by any extension that chooses to declare
  one (none does today) via `command-gate-out.sh`'s gate-out path, which runs on every task.

## Deploy State (explicit, per dispatch instruction)

**The deployed `.claude/` tree is NOT updated by this task.** All five edited files live only in
the source store (`agent-system/extensions/core/`). `.claude/**` is a disposable deploy artifact;
regeneration (`<leader>al` "Reload All", or `deploy-headless.sh`) is an operator action
deliberately left outside this change — a sibling task (books extension scaffolding) was live on
this same working tree for most of this task's execution, and a mid-task regeneration would have
swept in its in-flight edits. Until that regeneration happens, the repaired mechanism is live in
the source store only; every probe and regression case in this task sourced the source-store
copy directly (never the deployed `.claude/scripts/skill-base.sh`), which is why they already
demonstrate the fix despite no deploy having occurred. `check-extension-docs.sh`'s own
deployed-vs-source content-drift check (Rule F) correctly flags all four edited scripts as
drifted — this is the expected, documented signal that a deploy is now pending for this task's
change, not a defect.

## Follow-ups

- None required for this task's acceptance. Operator should run `<leader>al` "Reload All" (or
  `deploy-headless.sh`) at a convenient point to bring `.claude/` into agreement with the source
  store and make the repaired mechanism live in the deployed tree.
- The pre-existing `test-gate-out-repair-reporting.sh` Case 1 failure (unrelated drift between
  `validate-artifact.sh`'s current output and that suite's pinned fixture expectation) remains
  open; it predates this task and is out of scope here.

## References

- Plan: `specs/327_repair_extension_lifecycle_hook_mechanism/plans/01_lifecycle-hook-mechanism-repair.md`
- Progress files: `specs/327_repair_extension_lifecycle_hook_mechanism/progress/phase-{1..7}-progress.json`
- Handoffs: `specs/327_repair_extension_lifecycle_hook_mechanism/handoffs/`
- Research report: `specs/327_repair_extension_lifecycle_hook_mechanism/reports/01_lifecycle-hook-mechanism-repair.md`
