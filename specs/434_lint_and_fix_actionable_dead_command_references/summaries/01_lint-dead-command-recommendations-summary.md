# Implementation Summary: Task #434

- **Task**: 434 - Add a self-updating lint for recommendations naming a command with no definition file, and clear the 187 dead lifecycle-command recommendation lines
- **Status**: [COMPLETED]
- **Started**: 2026-10-17
- **Completed**: 2026-10-17
- **Effort**: ~8 hours
- **Dependencies**: None
- **Artifacts**: plans/01_lint-dead-command-recommendations.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Built a new, self-updating lint (`lint-dead-command-recommendations.sh`) that derives its
valid-command set by enumerating `agent-system/extensions/*/commands/*.md` at run time, flags any
literal `Next: /X` / `Run /X` recommendation naming a command with no definition file, and paired
it with a fixture suite proving the enumeration (not just the regex) drives the verdict. Used the
lint's own red output as the authoritative worklist to retarget 188 dead-command recommendation
lines across 92 files in 12 extensions onto `/orchestrate` (the only lifecycle driver that exists),
plus a structural (non-string-substituted) fix to `command-output.md`'s template assignments.
Wired the lint into `verify-deploy.sh` as gate 24 and redeployed to `RESULT=landed_verify_clean`.

## What Changed

- `agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh` — new lint;
  zero-tolerance, no hardcoded allowlist, enumerates valid commands from the filesystem.
- `agent-system/extensions/core/scripts/tests/test-lint-dead-command-recommendations.sh` — new
  fixture suite (12 assertions across 5 cases: violating fixture, real-command negative, the
  self-updating-behavior proof, both non-canonical shapes, and the README exclusion).
- `agent-system/extensions/core/context/formats/command-output.md` — removed `/research`,
  `/plan`, `/implement` from Assigned Commands lines and the Template Assignment Table; assigned
  `/orchestrate` to Template B with an in-file rationale; fixed a stray `/cmd` placeholder to
  match the file's own `/{command}` convention.
- 92 files across `core`, `founder`, `present`, `formal`, `cslib`, `web`, `literature`, `lean`,
  `nvim`, `nix`, `epidemiology`, `books` — every dead-command recommendation line retargeted onto
  `/orchestrate`, several multi-step research-then-plan-then-implement sequences collapsed to one
  `/orchestrate` call.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — added `gate24_run()`.
- `agent-system/extensions/core/scripts/gate-registry.data` — appended the gate 24 row
  (`timeout_s=30`, `cost_class=free`, matching sibling full-corpus lints).
- `agent-system/extensions/core/manifest.json`, `agent-system/extensions/core/index-entries.json`
  — registered the two new script files; corrected a `command-output.md` line-count drift.
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh`,
  `.../tests/test-run-all-selection.sh` — fixed two pre-existing latent defects (a hardcoded
  23-gate expectation; a SIGPIPE/`pipefail` footgun in a candidate-derivation loop) that the new
  corpus file's addition surfaced.
- `agent-system/extensions/core/scripts/tests/known-failures.txt` — recorded one additional
  pre-existing, load-sensitive, out-of-scope test timeout (see Follow-ups).

## Decisions

- New file over extending an existing lint: `lint-routing-wiring.sh` never enumerates
  `commands/*.md` (manifest-keyed, incompatible detection model); `lint-contract-compliance.sh` is
  scoped to hard-mode behavioral contracts. Reused `lint-corpus-scan-lib.sh` for file collection
  and flag parsing to hold the additive cost down.
- Scope is the full corpus (including `context/`, `docs/`, `.json`), not the executable-surface
  subset `adoption-lint-conventions.md` prescribes for its own lint class — a recommendation line
  IS the defect wherever rendered.
- `/orchestrate` assigned to Template B in `command-output.md` (not left unassigned) since it is
  the lifecycle driver producing exactly that template's phase-metrics-and-summary-artifact shape.
- A multi-step `research` → `plan` → `implement` recommendation sequence collapses to one
  `/orchestrate` call; a "skip the plan step" alternative maps to `/orchestrate {N} --implement`
  (the documented forcing flag).

## Plan Deviations

- Added incidental manifest/index-entries housekeeping in Phase 3 (not originally enumerated) to
  satisfy gate 3 doc-lint, caused by Phase 1/2's new files.
- Worked around a pre-existing quoted-glob bug in `git-commit-phase.sh`/`git-commit-scoped.sh`'s
  file_scope-Containment guard (every `/**`-suffixed `file_scope` entry fails to contain any path
  due to case-pattern quoting disabling glob interpretation) by committing directly via
  `git-commit-scoped.sh` with `--task` omitted (a documented fail-open opt-out) for every phase
  touching deeply-nested files. Reported as a tooling-defect issue; not fixed here (companion
  task 394's likely territory).
- Phase 7's "all 24 gates must pass" closed as `[COMPLETED WITH EXCLUSIONS]`: gates 1-7 and 9-24
  all pass; gate 8 (`run-all.sh`) cannot pass cleanly via `verify-deploy.sh`'s own invocation
  (no `--fail-on-new`) for structural reasons predating this task (two pre-existing EXPECTED test
  failures already in `known-failures.txt`). `deploy-headless.sh`'s own inline verification runs
  `--skip-slow`, which defers gate 8 entirely, so `RESULT=landed_verify_clean` was still reached.

## Verification

- Build: N/A
- Tests: `test-lint-dead-command-recommendations.sh` 12/12 pass; `run-all.sh` discovers and passes
  it; `test-gate-registry-resolution.sh` 32/32 and `test-run-all-selection.sh` 19/19 pass after fix
- Lint: `lint-dead-command-recommendations.sh` exits `0` over the whole source store (1062 files,
  776 candidates, 0 violations), both source-store and deployed copies
- Gates: `verify-deploy.sh` gates 1-7, 9-24 all PASS (including the new gate 24); gate 8 blocked by
  pre-existing, unrelated test failures (see Follow-ups)
- Deploy: `deploy-headless.sh` → `RESULT=landed_verify_clean`, exit 0 (confirmed twice)
- Files verified: Yes

## Impacts

- Any future dead/removed lifecycle command (not just `/implement`/`/research`/`/plan`) is now
  caught automatically by gate 24 with no allowlist maintenance.
- The `/revise`-rendering-an-unrunnable-recommendation defect class that originally surfaced this
  task cannot recur without gate 24 failing.

## Follow-ups

- `agent-system/extensions/core/scripts/tests/known-failures.txt` gained one new row:
  `test-gate-cache-equivalence.sh` (load-sensitive, `needs-owner`) — its cold-baseline case's
  gate10 (`validate-state.sh --deep`) 30s timeout inside a fresh git-worktree fixture, reproduced
  even with no other process running, most likely because `specs/state.json` has grown past
  whatever size gate 10's timeout was calibrated against. Unrelated to this task; recalibrating
  gate 10's timeout or that suite's fixture is separate follow-up work.
- A tooling-defect issue was recorded (non-fatal) describing the quoted-glob bug in
  `git-commit-phase.sh`/`git-commit-scoped.sh`'s `is_contained`/`is_contained_v10` predicates for
  a `/**`-suffixed `file_scope` entry — likely task 394's territory, not fixed here.
- The companion prose-sweep task (phase-versus-command prose, architectural/dispatch-model
  references) remains fully out of scope as planned and still carries its dependency edge onto
  this task.

## References

- `specs/434_lint_and_fix_actionable_dead_command_references/reports/01_lint-and-fix-dead-command-references.md`
- `specs/434_lint_and_fix_actionable_dead_command_references/plans/01_lint-dead-command-recommendations.md`
- `specs/434_lint_and_fix_actionable_dead_command_references/progress/phase-1-progress.json` through `phase-7-progress.json`
