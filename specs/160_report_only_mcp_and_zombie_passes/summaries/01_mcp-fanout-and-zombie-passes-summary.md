# Implementation Summary: Task #160

- **Task**: 160 - Add report-only refresh passes for unused MCP fan-out and unreaped child processes
- **Status**: [COMPLETED]
- **Started**: 2026-09-07T20:28:50Z
- **Completed**: 2026-09-07T20:46:22Z
- **Effort**: ~1 hour
- **Dependencies**: None (file-overlap serialization with the Lean LSP reclamation pass on `claude-refresh.sh`, not a logical prerequisite)
- **Artifacts**: plans/01_mcp-fanout-and-zombie-passes.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added two strictly additive, report-only diagnostic passes to `claude-refresh.sh` -- an
unreaped-child (zombie) reporting pass and an MCP server fan-out reporting pass with a conditional
scoping advisory -- plus a documentation correction removing a disproven "subagents cannot access
project-scoped MCP servers" claim from `docs-README.md`. Neither new pass ever reaches a signal
call, both were verified end-to-end against the live system and against a synthetic fixture test
suite (76 assertions, 0 failures), and all six acceptance criteria were discharged mechanically
via grep/diff rather than by inspection.

## What Changed

- `agent-system/extensions/core/docs/docs-README.md` -- replaced the disproven subagent-barrier
  claim with the accurate workspace-trust framing, pointing to
  `context/patterns/mcp-server-ownership.md` as the authority.
- `agent-system/extensions/core/scripts/claude-refresh.sh` -- added `ZOMBIE_SNAPSHOT_PS_FIELDS`,
  `take_zombie_snapshot`, `zombie_row_is_defunct`, `run_zombie_pass` (zombie pass); added
  `MCP_SNAPSHOT_PS_FIELDS`, `CLAUDE_JSON_PATH` seam, `mcp_playwright_evidence_of_use`,
  `mcp_lean_lsp_evidence_of_use`, `mcp_server_evidence_of_use`, `run_mcp_fanout_pass` (MCP
  fan-out pass, including an Evidence column so an undetectable server reports "no use signal
  available" rather than being silently unflagged); wired both into `main()` after
  `run_lean_pass`.
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` -- added assertion
  blocks (h) zombie-state discrimination + full output-shape, (i) MCP session/memory arithmetic +
  evidence discriminator (both directions), and (j) structural kill/terminate_pid absence + advisory
  text content; extended the mutation check's function-name loop (+7 names) and its exact-count
  guard (14/15 -> 21/22).
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` -- two new Process Safety bullets;
  a Step 2 clarification that the confirmation trigger is scoped to the two destructive passes
  only.
- `agent-system/extensions/core/commands/refresh.md` -- two new Process Safety bullets.

## Decisions

- Session-count attribution for the MCP pass uses a simple, generic model (case-insensitive
  substring match of the server's own registered key against argv, then ppid-chain connected-component
  grouping) rather than a bespoke per-server parser -- it matched the live-observed shape for both
  registered servers without hard-coding either name into the matching logic.
- Added an Evidence column to the MCP pass's report table (not originally spelled out as a column
  in the plan's task list) so "no use signal available" is reported explicitly for an unrecognized
  server, rather than only implicitly not-flagging it -- this was a gap caught while writing
  Phase 4's tests against the Phase 3 code, and fixed before the tests were written against it.
- The zombie pass reports memory as an explicit, hard-coded zero with a stated rationale (a zombie
  holds only a PID slot and exit-status record) rather than omitting a memory column, so the report
  can never be misread as listing reclaimable memory.

## Plan Deviations

- None (implementation followed plan; the Evidence-column addition was a same-phase-3 refinement
  made before Phase 3 was verified complete, not a deviation from a already-closed phase).

## Verification

- Build: N/A (bash script; `bash -n` syntax check passed)
- Tests: Passed (`test-claude-refresh-matcher.sh`: Passed 76, Failed 0)
- Files verified: Yes

## Impacts

- `/refresh` (and the hourly `claude-refresh.timer` dry-run cadence) now additionally surfaces
  unreaped zombie children and MCP server fan-out/memory cost with a scoping advisory, with zero
  change to either pass's termination behavior.
- The corrected `docs-README.md` MCP Configuration section and `context/patterns/mcp-server-ownership.md`
  are now internally consistent; no known-false claim about subagent MCP access remains in the
  in-scope canonical source tree.

## Follow-ups

- The same disproven subagent-barrier claim still appears in the OpenCode mirror
  (`.opencode/**/docs/README.md`), out of scope per the canonical-source constraint (recorded in
  Phase 1 as a known unaddressed duplicate).
- The MCP fan-out pass's evidence-of-use discriminator currently recognizes only `playwright` and
  `lean-lsp` by name; a third registered server reports "no use signal available" rather than being
  silently mis-flagged, but has no dedicated detector -- adding one is future work, not a defect.

## References

- Plan: specs/160_report_only_mcp_and_zombie_passes/plans/01_mcp-fanout-and-zombie-passes.md
- Research: specs/160_report_only_mcp_and_zombie_passes/reports/01_mcp-fanout-and-zombie-passes.md
- Progress files: specs/160_report_only_mcp_and_zombie_passes/progress/phase-{1..6}-progress.json
