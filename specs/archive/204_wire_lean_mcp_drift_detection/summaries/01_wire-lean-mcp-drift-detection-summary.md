# Implementation Summary: Task #204

- **Task**: 204 - Wire verify-lean-mcp.sh into a moment where lean-lsp registration drift is actually caught
- **Status**: [COMPLETED]
- **Started**: 2026-09-09T00:00:00Z
- **Completed**: 2026-09-09T02:00:00Z
- **Effort**: ~1.75 hours
- **Dependencies**: Task 203 (COMPLETED — reconciled the sanctioned lean-lsp registration shape)
- **Artifacts**: plans/01_wire-lean-mcp-drift-detection.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, shell-script-testing.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

`core/scripts/verify-lean-mcp.sh` already diagnosed lean-lsp MCP registration drift correctly and
already named `setup-lean-mcp.sh` as the remedy, but nothing ever invoked it — a broken
registration could sit undetected indefinitely. This task supplied the missing invocation: a new
lean-owned wrapper, `lean-mcp-preflight-check.sh`, that calls the existing verifier, stays silent
on a correct registration and outside a Lean project, and otherwise emits one actionable message
naming the remedy — wired directly into Stage 2 (Preflight Status Update) of the four lean skills
that dispatch to lean-lsp-using agents. All 5 plan phases completed; all Testing & Validation
checklist items verified.

## What Changed

- `agent-system/extensions/lean/scripts/lean-mcp-preflight-check.sh` — new WARN-only wrapper
  around `verify-lean-mcp.sh`. Lean-project pre-check (lakefile.lean/lakefile.toml at CWD or git
  root, copied verbatim from the verifier's own detection) exits 0 silently outside a Lean
  project; if the deployed verifier is missing, exits 0 silently; otherwise invokes it once,
  non-quiet, and on non-zero exit prints a `[lean-mcp-preflight]` header (worded differently for
  the exit-2 project-path-mismatch case vs. every other non-zero case) plus the filtered
  `[FAIL]`/`[WARN]`/`Run setup-lean-mcp` lines, or a generic fallback line if the filter is empty.
  Always exits 0 — WARN, never BLOCK.
- `agent-system/extensions/lean/scripts/tests/test-lean-mcp-preflight-check.sh` — new Class B
  (`set -uo pipefail`) regression suite with 5 fixtures (A: observed drift shape / B: correct
  registration / C: non-Lean repository / D: exit-2 project-path mismatch / E: fallback-text
  path) plus a mutation/falsifiability check that neutralizes the wrapper's failure branch and
  confirms fixtures A, D, E go silent while B, C are unaffected. All 8 assertions PASS. Resolves
  `verify-lean-mcp.sh`'s location by trying both the source-store-relative path and the
  deployed-tree-relative path, so the suite runs identically from either layout.
- `agent-system/extensions/lean/manifest.json` — `provides.scripts` gained
  `lean-mcp-preflight-check.sh` and `tests/test-lean-mcp-preflight-check.sh`. No top-level
  `hooks` object added (would be dead code given the live call graph; see Decisions).
- `agent-system/extensions/lean/skills/skill-lean-research/SKILL.md` — Stage 2 gained a guarded
  call (`if [ -x .claude/scripts/lean-mcp-preflight-check.sh ]; then bash
  .claude/scripts/lean-mcp-preflight-check.sh || true; fi`), appended after the existing
  unmodified status-update call. Pure addition, no reordering.
- `agent-system/extensions/lean/skills/skill-lean-research-hard/SKILL.md` — same guarded call,
  byte-identical block.
- `agent-system/extensions/lean/skills/skill-lean-implementation/SKILL.md` — same.
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` — same.
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — revised the
  `verify-lean-mcp.sh` entry (removed the stale "no automated caller by design" claim) and added
  a new entry for `lean-mcp-preflight-check.sh` naming the WARN-only contract, the four call
  sites, the measured cost, and the Stage-2-migration follow-up.

## Decisions

- **Wiring point**: direct per-skill Stage 2 calls, not a manifest `hooks.preflight`
  declaration. The lean manifest has no top-level `hooks` object, and none of the four
  lean-lsp-using skills route Stage 2 through `skill_preflight_update` in `skill-base.sh`
  (research writes state.json via `state-write.sh`; the other three call `update-task-status.sh
  preflight` directly) — a `hooks.preflight` declaration would be dead code given the live call
  graph. Rejected alternatives and reasons carried forward unchanged from the plan's research
  integration: dispatch-time invocation (invisible to directly-invoked `/research`/`/plan`/
  `/implement`), `SessionStart` hook (fires once per session regardless of task type, misses
  lean work begun mid-session, couples lean-specific logic into core's global `settings.json`).
- **WARN, never BLOCK**: the wrapper always exits 0 and no call site treats its output as
  failure; lean4 work without lean-lsp remains a usable, slower, degraded mode via compiled
  probes. Every emitted message names `setup-lean-mcp.sh` so the warning is actionable, unlike
  the pre-existing silent failure this task fixes.
- **Single non-quiet verifier invocation** (a deliberate refinement over the research report's
  `--quiet`-plus-second-run recommendation): same cost and same silence on the green path, but
  the failure message can carry the verifier's own already-correct diagnosis lines instead of a
  lowest-common-denominator restatement.
- **Reconciled Scope Hypothesis discrepancy** (Phase 4): the plan's own verification grep
  (`lean-research-agent\|lean-implementation-agent`) found only 2 of the intended 4 SKILL.md
  files, because the `-hard` variants dispatch to `lean-research-hard-agent` /
  `lean-implementation-hard-agent` — `-hard-agent` is not a substring match for `-agent` alone.
  Confirmed by direct `subagent_type` inspection that all four named skills dispatch to a
  lean-lsp-using agent via the Agent tool, and that `skill-lake-repair` /
  `skill-lean-version` have no Agent-tool dispatch at all. Recorded inline in the plan's Phase 4
  Scope Hypothesis section; all four (and only four) skills received the call site.
- **Deployed-tree vs. source-store path resolution fix** (discovered during Phase 5 deploy
  verification): the test suite's `VERIFIER_SRC` path assumed the source-store layout
  (`scripts/tests/../../../core/scripts/verify-lean-mcp.sh`), which does not resolve in a
  deployed consumer repo where every extension's scripts flatten into one `.claude/scripts/`
  directory (`scripts/tests/../verify-lean-mcp.sh`). Fixed by trying both candidate paths in
  order, confirmed by re-deploying to `~/Projects/BimodalLogic` and re-running the deployed
  suite (all 8 assertions still PASS).

## Plan Deviations

- None (implementation followed plan). The two items above (Scope Hypothesis reconciliation,
  deployed-path fix) were both anticipated contingencies the plan explicitly asked to reconcile
  and record rather than deviations from the plan's intent.

## Verification

- Build: N/A (shell scripts, no build step)
- Tests: Passed — `test-lean-mcp-preflight-check.sh` exits 0, all 8 assertions PASS (5 fixtures
  + differing-message anti-vacuous check + 2-part mutation/falsifiability check), verified both
  from the source store and from the deployed tree in `~/Projects/BimodalLogic`
- Files verified: Yes — `lean-mcp-preflight-check.sh` and its test suite are both `shellcheck`
  clean; `jq empty` passes on the modified lean manifest with both new `provides.scripts`
  entries present; `check-task-references.sh` reports 0 occurrences across all 4 scanned trees;
  `git status` shows tracked changes confined to `agent-system/**` and `specs/**` (`.claude/` is
  gitignored and untracked, consistent with the source-store/deploy boundary)

### Measured wall-clock cost (5-run means, `date +%s%N` deltas around `bash script.sh`)

| Scenario | Mean |
|----------|------|
| Non-Lean directory (early exit) | ~6ms |
| Correctly-registered Lean project (full 9-check verifier run, output discarded) | ~25ms |
| Drifted Lean project (Check 3 fails fast, output captured and filtered) | ~20ms |

All three are within the same order of magnitude as the ~30ms `verify-lean-mcp.sh --quiet`
baseline recorded in the research report, and well under the ~100ms stop-and-record threshold
the plan set. Confirmed by inspection: every command reachable from the wrapper or from
`verify-lean-mcp.sh` is `test`, `jq`, `git rev-parse --show-toplevel`, or output formatting — no
repository walk, no network call, no MCP server spawn.

## Impacts

- A lean4 task's Stage 2 preflight now surfaces lean-lsp MCP registration drift the moment
  before dispatch, at negligible added cost, rather than the drift surfacing only as ENOENT
  session-startup noise discovered by someone going looking (the originating defect).
- The fix is repo-agnostic: any repo that loads the lean extension and redeploys picks it up
  automatically, confirmed live against `~/Projects/BimodalLogic` (which had exactly the
  exit-2 project-path-mismatch drift shape at verification time — its own preflight now
  reports it).
- `verify-lean-mcp.sh` itself, its exit codes, and its operator-facing manual-invocation
  behavior are unchanged — this task added a caller, not a change to the diagnostic.

## Follow-ups

- Migrate the four lean skills onto `context/patterns/skill-preflight-flow.md`'s shared Stage
  2+3 block, then replace the four inline guarded calls with a single manifest
  `hooks.preflight` declaration pointing at `lean-mcp-preflight-check.sh` — the same mechanism
  the nix extension already uses. Recorded in both the script header and the inventory entry;
  not undertaken here per the plan's explicit non-goal (separately-risky refactor touching
  postflight markers and monotonic-max clamping).
- Cross-reference: the consumer-repo deploy-propagation task reaches for the same
  cheap-natural-preflight-moment architectural shape for a different subject (deployed-tree
  staleness vs. MCP registration drift); that task was `[NOT STARTED]` with no preflight
  mechanism to reuse at the time this task ran, so no merge was attempted.

## References

- specs/204_wire_lean_mcp_drift_detection/plans/01_wire-lean-mcp-drift-detection.md
- specs/204_wire_lean_mcp_drift_detection/reports/01_wire-verify-lean-mcp-preflight.md
- agent-system/extensions/core/docs/reference/utility-scripts-inventory.md
