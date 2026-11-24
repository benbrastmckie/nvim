# Implementation Summary: Task #645

- **Task**: 645 - Repair seven failing Gate 8 suites (remaining scope: the `.mcp.json` merge defect)
- **Status**: [COMPLETED]
- **Started**: 2026-11-24
- **Completed**: 2026-11-24
- **Effort**: ~0.3 hours
- **Dependencies**: None
- **Artifacts**: plans/01_mcp-merge-closure-confirmation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

The `.mcp.json` merge defect named as this task's remaining scope was already fixed and
committed before this implementation dispatch began. No code edit was scoped or made; this
dispatch was verification-and-close only, confirming the fix live and closing the task's
acceptance criteria that a confirmatory dispatch is permitted to close inside a batch.

## What Changed

- No source file was edited. The fix (`merge.lua`'s `remove_tracked` `"new_object"` branch) was
  already committed at `3c7f91a92`, confirmed git-clean and live in this dispatch.
- `specs/645_repair_seven_failing_gate8_suites/plans/01_mcp-merge-closure-confirmation.md` —
  phase checklists annotated `(completed: ...)` with verbatim evidence; both phase headings
  marked `[COMPLETED]`.
- `specs/645_repair_seven_failing_gate8_suites/progress/phase-1-progress.json` — created.
- `specs/645_repair_seven_failing_gate8_suites/handoffs/phase-1-handoff-*.md` — created.

## Decisions

- Treated the live measurements as authoritative over both the task description's stale
  "one remaining defect" framing and the plan's own pre-dispatch hypothesis — all matched, but
  each was independently re-confirmed rather than assumed.
- Declined to force `--override-batch-gate-deferral` to satisfy acceptance criterion 1 directly
  inside this dispatch; that flag is reserved for the batch-gate stage's own discharger, and the
  non-stale `batch-gate-pending-sess_1795494587_0fa3fc.json` marker (covering task_numbers
  693/694/697/645/639) confirms the deferral is still live, not stale drift.

## Plan Deviations

- None (implementation followed plan).

## Verification

- `bash .claude/scripts/tests/test-mcp-merge-target.sh`: **`Results: 7 passed, 0 failed`**, exit
  0. Assertion C (requirement d) — `[PASS] hand-written entry survives regeneration alongside
  the extension's own entry`. Assertion E — `[PASS] retraction still happened after a load ->
  regenerate -> unload sequence ... and the hand-written entry survived`.
- `known-failures.txt`: 4 data rows (`test-run-all-parallel.sh`, `test-gate-cache-equivalence.sh`,
  `test-verify-deploy-context-budget.sh`, `test-double-loading-check.sh`) — unchanged, not
  increased (acceptance criterion 4).
- `git status --short` empty for `lua/neotex/plugins/ai/shared/extensions/merge.lua`,
  `lua/neotex/plugins/ai/shared/extensions/init.lua`, and
  `agent-system/extensions/core/scripts/tests/test-mcp-merge-target.sh` — the fix is committed,
  not an uncommitted artifact a sibling or regenerate could erase.
- `bash .claude/scripts/deploy-headless.sh`: **`[deploy-headless] RESULT=landed_verify_clean`**,
  exit 0 (acceptance criterion 5). Inline pass: `[verify-deploy] PASS -- 41 check(s), 0
  failure(s)`.
- `bash .claude/scripts/verify-deploy.sh --only-gate 8 --gate8-touched lua/neotex/plugins/ai/shared/extensions/merge.lua`:
  `[verify-deploy] PASS -- 1 check(s), 0 failure(s)`, exit 0 — scoped Gate 8 check green.
- **Acceptance criterion 1 (complete gate set, exit 0) is deferred, not satisfied, inside this
  dispatch.** A non-stale `batch-gate-pending-sess_1795494587_0fa3fc.json` marker (covering
  task_numbers 693, 694, 697, 645, 639) exists for this session; an unfiltered
  `verify-deploy.sh` run in this dispatch returned verbatim:
  `[verify-deploy] DEFERRED: a batch-gate-pending marker exists and this invocation is unfiltered
  -- the complete gate set is already owed to that session's own once-per-invocation batch-gate
  stage.` The complete 42-gate battery is owed to the orchestration close's once-per-invocation
  batch-gate stage, not to this dispatch.
- Build/Tests: Passed (scoped). Files verified: Yes.

## Root Cause and Which Side Was Wrong

**The merge code was the wrong side, not the test's expectation.** `merge.lua`'s
`M.unmerge_settings`'s `remove_tracked` helper originally treated three tracked-entry types —
`"new_array"`, `"new_object"`, and `"new_value"` — identically: unconditional wholesale
`t[key] = nil`. For an object-shaped merge target (`.mcp.json`'s `mcpServers` map and the
per-server entry nested inside it), the first extension to populate that object key is tracked
as `"new_object"`. Wholesale removal of a `"new_object"` deleted the *entire* object, including
any sibling key a user hand-added into it afterward — not just the tracked extension's own
sub-keys. The already-landed fix gave `"new_object"` its own branch (confirmed live at
`merge.lua:587`) that recurses into the tracked `info.children` — mirroring the existing
`"merged"` branch's object-walk shape — and prunes the object only once it is empty, with a
defensive no-children fallback at lines 601-602 preserving the old unconditional-removal
behavior for a shape `deep_merge` never actually produces. `"new_array"` and `"new_value"`
correctly retain unconditional removal (line 583): a freshly created array or scalar has no
nested tracked structure a hand-written sibling could hide inside.

**Assertions C and E are one fault, not two.** Both exercise the identical tracked record
(`mcpServers` -> `mcpfixture-server`) through `remove_tracked`'s `"new_object"` arm: Assertion C
observes survival immediately post-regenerate (a forced reload's retract-then-remerge round
trip), and Assertion E observes survival one step further, post-unload. They are the same code
path and the same tracked record exercised at two points of one sequence, not two independent
defects.

## Corrected Framing for a Future Reader

The task description's framing was stale by the time this implementation dispatch began: the
named defect was already closed (commit `3c7f91a92`, predating this dispatch), so "the whole of
this task's scope" resolved to confirmation rather than a fix. The description's
"SOURCE STORE IS THE EDIT TARGET: `agent-system/extensions/core/**`" line does not apply to this
defect: the fix lives in `lua/neotex/plugins/ai/shared/extensions/merge.lua` and `init.lua` —
primary Neovim plugin code, not mirrored under `agent-system/` — plus a contract-doc update under
`agent-system/extensions/nvim/` (the `nvim` extension, not `core`). Only the unchanged test file
lives under `agent-system/extensions/core/`.

## Impacts

- A hand-written `.mcp.json` server entry now survives both a forced-reload regenerate and a
  subsequent unload, alongside any extension-managed sibling entry in the same `mcpServers`
  object — closing a real data-loss risk for any user who hand-edits `.mcp.json` alongside a
  loaded extension's own `mcp` merge target.
- `known-failures.txt` did not grow; no assertion was loosened or skipped.

## Follow-ups

- Acceptance criterion 1 (complete gate set, exit 0) remains owed to the orchestration close's
  once-per-invocation batch-gate stage — not a defect in this task's own scope, just not yet
  discharged at the time of this summary.
- Out of scope, per the task's own binding constraints: the `known-failures.txt` roster for
  `test-deploy-propagation.sh` and its sibling, the orchestrator's
  stall-on-backgrounded-verify-deploy behavior, and re-diagnosing the six already-closed findings
  or `test-gate-cache-equivalence.sh`.

## References

- Plan: `specs/645_repair_seven_failing_gate8_suites/plans/01_mcp-merge-closure-confirmation.md`
- Research report: `specs/645_repair_seven_failing_gate8_suites/reports/01_mcp-merge-defect-already-fixed.md`
- Dispatch: `specs/645_repair_seven_failing_gate8_suites/.dispatch/17.md`
