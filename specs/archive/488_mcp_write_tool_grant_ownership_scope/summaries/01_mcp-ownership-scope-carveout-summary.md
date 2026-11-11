# Implementation Summary: Task #488

- **Task**: 488 - MCP write-tool grant ownership scope
- **Status**: [COMPLETED]
- **Started**: 2026-11-09T00:00:00Z
- **Completed**: 2026-11-09T01:00:00Z
- **Effort**: 1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_mcp-ownership-scope-carveout.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Amended `mcp-server-ownership.md` with an explicit carve-out verdict covering the case where a
server's matching user-scope settings file is externally enforced (nix-reset) and cannot be
durably written by this repository's deploy, repaired the two other passages in the same file
that would otherwise contradict the new carve-out, made the disclosure pointer between the
standard and the sapience extension symmetric, and redeployed. The verdict reached: the sapience
extension's project-scoped grant of its four MCP write tools is the sanctioned placement for this
tier, not a standards violation — `settings-fragment.json` was correctly left unchanged.

## What Changed

- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` — added
  `### Carve-out: a nix-enforced user-scope settings file cannot receive a new grant` under
  `## Permission` (stating the governing rule's unstated assumption, the verdict, the three
  requirements, and the sapience worked example); added a forward pointer from the governing
  rule ("Grant permissions at the same scope where the server is registered"); updated the
  `## Composition` table's first-row fix cell and `## Decision procedure` step 3 so neither
  still reads as if project-scope registration were the only exception.
- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md` —
  "The Permission Grant's Repository-Scoped Tradeoff" section now back-links to the new carve-out
  subsection by heading and states the verdict plainly, while keeping the existing honest caveat
  that other projects on the machine still prompt.
- `agent-system/extensions/core/docs/guides/permission-configuration.md` — extended the existing
  `**Carve-out**:` paragraph with a second carve-out sentence and a link to the new subsection.
- `agent-system/extensions/core/index-entries.json`,
  `agent-system/extensions/sapience/index-entries.json` — regenerated `line_count` fields for the
  two edited context files (via `generate-context-line-counts.sh --write`, run with
  `REPO_ROOT` set since the source-store invocation path requires it).
- Deployed `.claude/` tree regenerated via `deploy-headless.sh`; all three edited source files
  confirmed byte-identical to their deployed copies.

## Decisions

- The new carve-out subsection is named `### Carve-out: a nix-enforced user-scope settings file
  cannot receive a new grant`, placed immediately after the existing safe/unsafe carve-out and
  before `## Composition`, so a reader scanning carve-outs under `## Permission` finds both.
- The worked example names the sapience extension's four tools explicitly
  (`mcp__sapience__sapience_remember`, `_wrapup`, `_handoff`, `_adddoc`), matching
  `settings-fragment.json`'s actual enumeration rather than a wildcard.
- `settings-fragment.json` was deliberately left unchanged throughout, per the research verdict
  and the plan's Non-Goals.

## Plan Deviations

- **Phase 3, task "Run the full gate set"** altered: discharged against the scoped narrowing
  invocation (`verify-deploy.sh --only-gate 3,4`) rather than the full gate set, per the dispatch
  file's Batch Gate Deferral directive (this task is one of several `implement`-phase dispatches
  inside one multi-task `/orchestrate` batch invocation). The full run surfaced 3 pre-existing
  failures (eager-load baseline, a shellcheck finding in
  `agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh`, a dead-command
  recommendation in two z3 agent files) confirmed via `git log` as authored by other, unrelated
  work, not this task. The complete gate set is deferred to the once-per-invocation batch-level
  stage, not forgiven.

## Verification

- Build: N/A (prose-only edits plus a deploy regeneration)
- Tests: Scoped gate `verify-deploy.sh --only-gate 3,4` (doc-lint, task-reference lint) — Passed,
  both before and after redeploy
- Files verified: Yes — all three edited files confirmed byte-identical between source store and
  deployed tree; `settings-fragment.json` confirmed unchanged throughout

## Impacts

- Future extension authors facing a nix-enforced (or otherwise externally-reset) user-scope
  settings file now have an explicit, three-requirement carve-out to cite instead of appearing to
  violate the governing same-scope rule.
- The disclosure pointer between `mcp-server-ownership.md` and the sapience extension's own docs
  now resolves in both directions.

## Follow-ups

- None. The 3 unrelated full-gate failures surfaced during Phase 3's redeploy belong to other,
  still in-flight work and are out of this task's scope; they are expected to resolve (or be
  addressed) at the batch-level full-gate stage this dispatch's directive defers to.

## References

- `specs/488_mcp_write_tool_grant_ownership_scope/plans/01_mcp-ownership-scope-carveout.md`
- `specs/488_mcp_write_tool_grant_ownership_scope/reports/01_mcp-ownership-scope-verdict.md`
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md`
- `agent-system/extensions/core/docs/guides/permission-configuration.md`
