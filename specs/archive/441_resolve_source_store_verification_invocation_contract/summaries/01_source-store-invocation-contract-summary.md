# Implementation Summary: Resolve Source-Store Verification Invocation Contract

- **Task**: Resolve source-store verification invocation contract
- **Status**: [COMPLETED]
- **Started**: 2026-10-17T19:00:00Z
- **Completed**: 2026-10-17T22:15:00Z
- **Effort**: ~3.25 hours
- **Dependencies**: None
- **Artifacts**: plans/01_source-store-invocation-contract.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Three verification/maintenance scripts (`verify-deploy.sh`, `check-extension-docs.sh`,
`sync-manifest-scripts.sh`) carried a split-brain invocation contract: refused to run from the
agent-system source store yet wrote results back into source-store manifests. Research
established `verify-deploy.sh` never actually carried the refusal; only the other two did, via
`deploy-root-guard.sh`, and the refusal was not load-bearing for correctness. This implementation
adopts resolution (a): both affected scripts now run from either tree with no environment
override, via a new opt-in self-correcting path in the shared guard, plus documentation of the
contract and a full redeploy-and-gate sweep.

## What Changed

- `agent-system/extensions/core/scripts/deploy-root-guard.sh` — added an opt-in self-correcting
  branch gated on `DEPLOY_ROOT_GUARD_SELF_CORRECT=1`: when set, and only after the default
  structural check has already failed, the guard resolves a candidate root via
  `git rev-parse --show-toplevel` and accepts it as `REPO_ROOT` only when
  `agent-system/extensions` exists directly under it, completing with status 0. A caller that
  does not opt in, or whose candidate fails the structural test, sees today's refusal unchanged.
  Header comment rewritten to describe both paths.
- `agent-system/extensions/core/scripts/check-extension-docs.sh` — opts in
  (`DEPLOY_ROOT_GUARD_SELF_CORRECT=1`) immediately before its existing conditional guard-source
  line; header comment rewritten; Rule Q's repair-hint line now prints a pasteable
  repository-root command (`bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh
  --write`) instead of an unresolvable relative path.
- `agent-system/extensions/core/scripts/sync-manifest-scripts.sh` — same opt-in and header
  rewrite.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — header note only: it resolves
  `TARGET` from its argument or `$(pwd)` and therefore runs correctly from either tree, and
  deliberately invokes the deployed copies of its sub-check scripts because its purpose is
  comparing the deployed tree against the source store. No behavioral change.
- `agent-system/extensions/core/scripts/tests/test-deploy-root-guard.sh` — new suite, 10
  assertions covering the default-deploy-shaped path, the default non-opt-in refusal, the
  opt-in acceptance path, and the two opt-in rejection branches (bad root, non-git directory).
- `agent-system/extensions/core/scripts/tests/test-manifest-scripts-sync.sh` — extended with
  three no-override assertions (one per script plus the updated repair-pointer-text assertion).
- `agent-system/extensions/core/manifest.json` — declared the new test suite via
  `sync-manifest-scripts.sh --write`.
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — new `###
  Opt-In Self-Correcting Resolution` subsection under `## Root-Resolution Guard for Core
  Scripts`, naming the two opted-in scripts and the seven sibling scripts that deliberately do
  not opt in.

## Decisions

- Resolution (a) (self-correcting, no override required) was adopted for the two scripts that
  actually carried the refusal; resolution (b) was rejected because the research found the
  guard not load-bearing for correctness.
- The opt-in is scoped narrowly to two scripts via an explicit per-caller variable rather than
  changed as `deploy-root-guard.sh`'s default behavior, leaving its ~58 other sourcing callers
  untouched.
- `verify-deploy.sh` required no behavioral change; only a clarifying header note, since it
  never carried the refusal in the first place.

## Plan Deviations

- Phase 4, task 4 (`verify-deploy.sh` with no `--skip-slow`/`--only-gate`) and task 6 (full
  `run-all.sh`) were deferred to the batch-level stage per this dispatch's own Batch Gate
  Deferral directive, and discharged instead via scoped narrowing invocations
  (`verify-deploy.sh --skip-slow --only-gate 3,4,22`; `run-all.sh --only` over the 57 suites
  `suite_selection_select` maps to the three touched scripts). The complete gate set is
  attributed to run once for the whole /orchestrate batch.
- An unplanned sub-step was required in Phase 4: `deploy-headless.sh`'s first attempt caught 3
  real shellcheck SC2034 findings (cross-file variable handoffs the per-file shellcheck analysis
  cannot see across files), fixed with inline `# shellcheck disable=SC2034` comments and
  one-line reasons. The second `deploy-headless.sh` attempt landed clean.

## Verification

- Build: N/A (shell scripts; `bash -n` clean on all four touched scripts)
- Tests: Passed — `test-deploy-root-guard.sh` (10/10), `test-manifest-scripts-sync.sh` (19/19),
  the dependent-suite sets named per phase (all NEW-failure-free against the known-failures
  roster), scoped gate selection (`--only-gate 3,4,22`, 4/4 checks passed)
- Files verified: Yes — `deploy-headless.sh`'s second attempt reported `RESULT=landed_verify_clean`
  (37 checks, 0 failures); deployed copies of all touched files are drift-clean; both in-scope
  scripts produce byte-identical output from the source store (no override) and from the
  deployed copy

## Impacts

- An agent editing the source store (the mandated edit target) can now invoke
  `check-extension-docs.sh` and `sync-manifest-scripts.sh` directly from
  `agent-system/extensions/core/scripts/` with a bare `bash <path>` invocation, with no need to
  discover the refusal by trial or reach into the deployed tree to validate source-store work.
- `deploy-root-guard.sh`'s ~58 other sourcing callers are unaffected: the opt-in is additive and
  gated on a variable no other caller sets.

## Follow-ups

- The seven sibling scripts sharing the same conditional-bypass shape
  (`audit-deletion-references.sh`, `check-record-versioning.sh`, `check-task-references.sh`,
  `generate-context-line-counts.sh`, `measure-eager-context.sh`, `measure-eager-surface.sh`,
  `validate-context-index.sh`) were deliberately left out of scope and remain candidates for the
  same opt-in treatment in a future task, once the pattern has proven out here.

## References

- `specs/441_resolve_source_store_verification_invocation_contract/reports/01_source-store-verification-invocation-contract.md`
- `specs/441_resolve_source_store_verification_invocation_contract/plans/01_source-store-invocation-contract.md`
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
