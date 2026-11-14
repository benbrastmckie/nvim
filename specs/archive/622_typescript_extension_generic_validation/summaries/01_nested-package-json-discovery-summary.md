# Implementation Summary: Task #622

- **Task**: 622 - Validate the typescript extension's generic toolchain detection against a
  real no-tsconfig node:test repository
- **Status**: [COMPLETED]
- **Started**: 2026-11-14T01:00:44Z
- **Completed**: 2026-11-14T02:35:00Z
- **Effort**: ~2 hours
- **Dependencies**: Task 621 (completed)
- **Artifacts**: plans/01_nested-package-json-discovery.md, reports/01_typescript-generic-validation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

The research phase established that the `typescript` extension's detection logic is correct and
generic, but the extension's verification-stage hook failed the task's PASS CONDITION against
`/home/benjamin/Projects/Sapience/sf1-engine` because the hook is invoked with cwd fixed at the
repo root and only ever looked for `package.json` relative to that cwd -- sf1-engine's
TypeScript project lives at `sf1-v2/opencode-plugin/`, so the gate silently skipped entirely.
This implementation closed that gap entirely inside the extension's own source-store hook
(`agent-system/extensions/typescript/scripts/typescript-verify.sh`), added the extension's first
regression suite, synced the two coupled derived surfaces, and re-ran the original
falsifiability experiment end-to-end against the same real repository -- which now passes.

## What Changed

- `agent-system/extensions/typescript/scripts/typescript-verify.sh` -- extracted the existing
  per-directory detection into a `verify_project(dir, prefix)` function; added a bounded,
  vendor-excluded `find`-based fallback search (depth 4, excluding `node_modules`/`.git`/`dist`/
  `build`/`.next`/`out`/`vendor`/`.venv`, sorted, iterated via `while read ... < <(find ...)`
  process substitution so the parent-shell counters are never lost), a 10-project discovery cap
  with a loud stderr NOTICE on truncation, per-project path-prefixed output
  (`[typescript-verify][a/b] ...`), and a malformed-nested-manifest policy (warn + skip, never
  fatal) distinct from the unchanged cwd-local exit-1 contract. The tier-1 fast path (cwd
  already has `package.json`) is byte-identical to the pre-change script and never invokes
  `find`.
- `agent-system/extensions/typescript/scripts/tests/test-typescript-verify.sh` -- new hermetic
  regression suite (the extension's first), 15 assertions covering the plan's nine enumerated
  cases plus the project cap and cwd-local malformed-manifest cases. A stub `npm`/`pnpm`/`yarn`/
  `bun` on `PATH` keeps every fixture hermetic (no real package manager, network, or install).
- `agent-system/extensions/typescript/manifest.json` -- `provides.scripts` regenerated via
  `sync-manifest-scripts.sh --write` to declare the new suite.
- `agent-system/extensions/typescript/context/project/typescript/tools/package-manager-detection.md`
  -- new "No `package.json` At cwd, But One Exists Below" section documenting the two-tier
  detection; the "No `package.json` At All" section rescoped to apply only after the fallback
  search has also come up empty.
- `agent-system/extensions/typescript/index-entries.json` -- `line_count` for the edited doc
  regenerated via `generate-context-line-counts.sh --write` (64 -> 100).

## Decisions

- One shared hermetic stub-binary directory is prepended to `PATH` once for the whole test-suite
  run rather than per-case; all 15 cases are equally hermetic either way.
- The tier-2 malformed-manifest policy is deliberately asymmetric from tier-1: a malformed
  `package.json` discovered below cwd warns and skips (one bad nested manifest must never blank
  out sibling findings), while one found directly at cwd keeps the pre-existing `exit 1`
  hook-input-error contract unchanged.
- The cap-truncation notice is computed once after the discovery loop completes (comparing the
  final found-count against the cap), rather than mid-loop, avoiding off-by-one complexity.

## Plan Deviations

- **Task 4.6** (redeploy this repo's own deployed tree) deferred: this dispatch's own
  `.dispatch/13.md` carried a Batch Gate Deferral directive for this final phase, deferring the
  costly whole-tree redeploy to the batch-level Inter-Cycle Redeploy Checkpoint rather than
  running it independently here.
- **Task 4.7** (run the full gate set) altered to a scoped discharge per the same directive:
  Gate 3 doc-lint (`check-extension-docs.sh --quiet`) and Gate 8's new-suite content
  (`run-all.sh --only test-typescript-verify.sh`) both already PASS from Phases 2-3;
  `sync-manifest-scripts.sh --check` and `generate-context-line-counts.sh --check` are both
  clean. The unfiltered `verify-deploy.sh`/`run-all.sh`, `check-task-references.sh --quiet`, and
  `validate-state.sh --deep` are deferred to the once-per-invocation batch-level stage, not
  waived.

## Verification

- Build: N/A (shell scripts; `bash -n` and `shellcheck` both clean)
- Tests: Passed -- 15/15 assertions in the new regression suite; mutation check independently
  verified (reverting the tier-2 fallback in a scratch copy causes 5 of the 15 assertions to
  correctly FAIL, proving the suite is not vacuous)
- Live re-validation: Passed -- the deployed hook in sf1-engine, confirmed byte-identical to the
  source-store copy, now names `sf1-v2/opencode-plugin`, correctly SKIPs typecheck (no
  tsconfig), resolves `npm`, and runs the real `node --test test/*.test.ts` battery (531 passed,
  29 failed -- matching the plan's carried Scope Hypothesis exactly, 46 skipped). Final summary
  moved from `ran_pass=0 ran_fail=0 skipped_no_command=1` (nothing ran) to
  `ran_pass=0 ran_fail=1 skipped_no_command=1` (the gate actually ran and reported a real
  finding).
- HARD CONSTRAINT: `sf1` and `opencode-plugin` each return zero hits under
  `agent-system/extensions/typescript/`. The combined grep (which also includes `sapience`)
  returns 2 hits, confirmed to be the pre-existing, universal `sapience-retrieve.sh`
  memory-context call present in every extension's skills since task 499/620 -- not a reference
  to the target repo. The HARD CONSTRAINT's actual intent (no special-casing) holds.
- Files verified: Yes (all new/edited files confirmed on disk and non-empty; manifest and
  index-entries.json re-checked clean after regeneration)

## Impacts

- The `typescript` extension's verification-stage hook now correctly discovers a
  Node/TypeScript project that lives below the task's repo root in any consuming repository,
  not only one at the repo root -- generically, with no repo-specific content anywhere in the
  extension.
- The extension gained its first regression suite, closing a gap `lint-test-harness-adoption.sh`
  would otherwise have flagged once the extension's scripts grew this complex.
- sf1-engine's 29 pre-existing failing subtests are now visible to this hook's reporting (an
  accurate finding, not a defect) -- out of scope for this task, and sf1-engine's own repo
  health (two unrelated pre-existing `verify-deploy.sh` FAILs: task-reference lint and
  runtime-file-tracking policy) is likewise out of scope.

## Follow-ups

- The full gate-set battery deferred from Phase 4 (unfiltered `verify-deploy.sh`/`run-all.sh`,
  `check-task-references.sh --quiet`, `validate-state.sh --deep`) still needs to run once at the
  batch-level stage of this `/orchestrate` invocation, attributed back to this task via its
  `modified_files`.
- This repo's own deployed `.claude/` tree redeploy (currently stale for the `lean` extension,
  and now also for `typescript`) is expected to be picked up by the orchestrator's own
  Inter-Cycle Redeploy Checkpoint; no independent action is needed from this task.
- sf1-engine's own two pre-existing `verify-deploy.sh` FAILs (task-reference lint,
  runtime-file-tracking policy) and its 29 pre-existing failing subtests are unrelated findings
  about that repository's own health, not this task's extension -- noted for completeness, not
  actioned here.

## References

- Plan: `specs/622_typescript_extension_generic_validation/plans/01_nested-package-json-discovery.md`
- Research report: `specs/622_typescript_extension_generic_validation/reports/01_typescript-generic-validation.md`
- Progress files: `specs/622_typescript_extension_generic_validation/progress/phase-{1,2,3,4}-progress.json`
- Handoffs: `specs/622_typescript_extension_generic_validation/handoffs/phase-{1,2,3,4}-handoff-*.md`
