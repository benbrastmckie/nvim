# Implementation Summary: Task #628

- **Task**: 628 - Retract sapience write-tool grants from deployed repositories
- **Status**: [COMPLETED]
- **Started**: 2026-11-17T16:20:00Z
- **Completed**: 2026-11-17T20:45:00Z
- **Effort**: ~4.5 hours
- **Dependencies**: task 527 (pattern only, no blocking edge)
- **Artifacts**: plans/01_retract-sapience-write-grants.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Retracted the sapience extension's four MCP write-tool grants (`sapience_remember`,
`sapience_wrapup`, `sapience_handoff`, `sapience_adddoc`) from all five repositories that had
loaded the extension before `settings-fragment.json` was narrowed to seven read-shaped tools.
The merge engine's additive-only semantics meant a forced reload never propagated the narrowing
to an already-loaded repository; two complementary mechanisms now close this: a tracked-record
retraction in `manager.load`'s forced-reload branch, and an MCP-permission-grant orphan sweep
discovered to be necessary during implementation because the tracked history for the real
repositories had already been lost to a prior ordinary redeploy.

## What Changed

- `lua/neotex/plugins/ai/shared/extensions/init.lua` — forced-reload retraction block in
  `manager.load` (unmerges an extension's own prior `merged_sections` before re-merging its
  current fragment, with rollback restore and a fail-safe suppression notice); new
  `build_permission_valid_set` (the orphan sweep's orchestration-layer counterpart to
  `build_hook_valid_set`); doc-comment updates on `reverse_merge_targets` and `opts.force`.
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` — `M.unmerge_settings` now returns a
  `pre_removal_snapshot` 2nd value; new `M.restore_retracted_sections`; new
  `M.extract_mcp_prefix`, `M.remove_orphaned_mcp_permission_grants`,
  `M.restore_removed_mcp_permission_grants` (the MCP-permission-grant orphan sweep).
- `lua/neotex/plugins/ai/shared/extensions/merge_spec.lua` — 4 new cases in the "permission
  array tracking" describe block (narrowed-fragment retraction, sibling retention, hand-added
  survival, restore-primitive round-trip) and a new 5-case "orphan sweep for MCP permission
  grants" describe block. 39/39 pass.
- `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh` — new Assertion G:
  a real `deploy-headless.sh` forced-reload convergence check against a scratch fixture.
  10/10 assertions pass.
- `agent-system/extensions/sapience/rules/sapience-write-path.md` — rewrote the residual caveat
  paragraph to state the fixed, real behavior.
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` — rewrote the header
  check-(e) description and the failure-branch NOTE to stop excusing a count above 7.
- `agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md` —
  new table row and a new subsection naming all five retraction/sweep mechanisms.
- `agent-system/extensions/core/index-entries.json` — reconciled `line_count` for the narrative
  file (205 -> 238).
- All five repositories' deployed `.claude/` trees — redeployed; each now grants exactly the
  seven read-shaped sapience tools.

## Decisions

- Kept both retraction mechanisms (tracked-record unmerge-then-remerge, and the new orphan
  sweep) rather than replacing one with the other: the tracked-record path remains correct for
  other merge-target categories and future narrowings; the orphan sweep is what actually closes
  this task's acceptance criteria for the five already-affected repositories, whose tracked
  history was already lost.
- Added the new sweep's row into the EXISTING sweep-inventory table in
  `source-store-deploy-boundary-narrative.md` rather than a disconnected new file, since that
  table was already the authoritative mechanism map.
- Investigated, rather than ignored, an unexpected `settings.json` delta in 2 of 5 repositories
  during Phase 5 and judged it benign in-scope convergence (see Plan Deviations).

## Plan Deviations

- **Task 2.9** (altered): the planned tracked-record retraction mechanism alone cannot
  retroactively remediate the five already-affected repositories — git history confirms the
  tracked record was already reset to the narrow set by an ordinary redeploy before this task
  began, so the historical wide record no longer exists anywhere on disk. Added a second
  mechanism (the MCP-permission-grant orphan sweep) not in the original plan, confirmed
  empirically to close the gap the first mechanism alone could not.
- **Task 3.3** (deferred): the planned rollback-integration case (forcing `manager.load` to fail
  after retraction, via its own `pcall`) was deferred — no monkeypatch seam exists in a
  black-box bash integration harness. The restore primitives are unit-tested directly in
  isolation instead.
- **Phase 5, fingerprint diff** (investigated, not deviated from): 2 of 5 repositories'
  `settings.json` changed beyond the sanctioned sapience-grant delta. Investigated per the
  plan's own Risk mitigation and judged benign (convergence to current source, consistent with
  this task's uniform-across-keys design), not a regression. Recorded via `issue-record.sh`.

## Verification

- Build: N/A (Lua/Neovim extension, no compiled build step)
- Tests: Passed — `merge_spec.lua` 39/39; `test-deploy-propagation.sh` 10/10 (source-store copy)
  and 2/2 (deployed copy, post-redeploy, via `run-all.sh --only`); `verify-sapience-mcp.sh`
  check (e) passes in this repository; `verify-deploy.sh --skip-slow --only-gate 3,4` PASS
  post-redeploy (Batch Gate Deferral scoped tier — the full untargeted gate set is deferred to
  the batch-level pass per this dispatch's directive)
- Files verified: Yes — all five repositories' deployed grant lists and fingerprints confirmed
  directly (see records file)

## Impacts

- Every repository that loads or reloads the sapience extension going forward converges to the
  seven read-shaped grants, whether the drift already existed or is introduced by a future
  fragment narrowing.
- The forced-reload retraction block in `manager.load` now runs for EVERY extension on EVERY
  forced resync, not only sapience — confirmed to also correctly heal pre-existing, unrelated
  merge-target drift in two of the five repositories (investigated and judged a welcome,
  in-scope side effect of the generalized fix, not a regression).
- A future extension that declares MCP tool permissions under its own `mcp__<server>__` prefix
  automatically benefits from the same orphan-sweep protection.

## Follow-ups

- A follow-up task may build a Lua-level fault-injection harness to directly test
  `manager.load`'s rollback restore path on a genuine mid-load failure (deferred in Phase 3).
- A follow-up task may build the permissions-SET detection check this task explicitly left out
  of scope (research Recommendation 4; `lint-hook-registration-paths.sh`/Gate 21 untouched).
- Future baseline-capture work should snapshot raw file content, not only a hash, so a
  byte-level diff is always possible without indirect reasoning (the process gap this task hit
  in Phase 5).

## References

- `specs/628_retract_sapience_write_tool_grants/plans/01_retract-sapience-write-grants.md`
- `specs/628_retract_sapience_write_tool_grants/reports/01_retract-sapience-write-grants.md`
- `specs/628_retract_sapience_write_tool_grants/records/01_pre-change-baseline.md`
