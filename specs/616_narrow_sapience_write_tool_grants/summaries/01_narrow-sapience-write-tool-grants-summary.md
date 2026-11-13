# Implementation Summary: Task #616

- **Task**: 616 - Narrow sapience write tool grants
- **Status**: [COMPLETED]
- **Started**: 2026-11-13T00:00:00Z
- **Completed**: 2026-11-13T02:15:00Z
- **Effort**: ~3.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_narrow-sapience-write-tool-grants.md, summaries/01_narrow-sapience-write-tool-grants-summary.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Narrowed `agent-system/extensions/sapience/settings-fragment.json`'s `permissions.allow` from
11 `mcp__sapience__*` entries to 7 by deleting the four MCP write-tool grants
(`sapience_remember`, `sapience_wrapup`, `sapience_handoff`, `sapience_adddoc`), applying the
research report's selected shape (i). Brought every surface that stated the old 11-grant/4-write
figure as current fact into agreement with the new 7-grant figure across five phases, closing
the escape valve named in `rules/sapience-write-path.md`'s former "Accepted Residual" section.

## What Changed

- `agent-system/extensions/sapience/settings-fragment.json` — removed the four write-tool
  grants from `permissions.allow`; 7 entries remain, hooks unchanged.
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` — check (e) retargeted from
  11 to 7 grants, with a note on the additive-merge residual for repos that loaded sapience
  before this narrowing.
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` — the carve-out's
  `**Worked example**:` paragraph now states that no MCP server grant in this repository
  presently exercises the carve-out; the three governing requirements and the following
  contrast paragraph are unchanged.
- `agent-system/extensions/core/docs/guides/permission-configuration.md` — its cross-reference
  no longer promises a "sapience-extension worked example"; it points to the three governing
  requirements instead.
- `agent-system/extensions/core/index-entries.json` — `mcp-server-ownership.md`'s `line_count`
  corrected (504 -> 499) via `generate-context-line-counts.sh --write`, a direct consequence of
  shrinking that file's worked-example paragraph.
- `agent-system/extensions/sapience/rules/sapience-write-path.md` — the former "Accepted
  Residual: The Four-Tool Permission Grant Stays Intact" section is now "The Permission Grant
  Matches the Standing Contract", stating the seven-tool grant, the deny/prompt consequence for
  the four write tools, the no-MCP-grant-needed script write path, and the merge-retraction
  interaction, as current fact.
- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md` —
  grant-count statements (lines 49, 73, 75) now state seven tools; the carve-out paragraph no
  longer claims sapience is `core`'s named worked example (the write-tool-specific "mutating,
  unreviewed" framing was generalized since the grant carries no write tool); the former "Coming
  staleness of core's worked example" paragraph is replaced by "The dotfiles-level read-grant
  question remains open, independent of core's wording", preserving the still-open question
  without depending on `core` naming sapience; the explicit-grant enumeration lists seven names.
  `## Write-Tool Disposition` is untouched.
- `agent-system/extensions/sapience/EXTENSION.md`, `README.md`, `manifest.json`,
  `index-entries.json` — all four restate the seven-tool grant figure (EXTENSION.md lines 7-8,
  README.md's inventory-table row and Gap 1 body, manifest.json's description, and
  index-entries.json's keyword/summary for `review-gate-boundary.md`).
- Regenerated the deployed `.claude/` tree (idempotent `deploy-headless.sh`, run once per phase
  that introduced new source/deploy drift, four passes total this dispatch).

## Decisions

- Grant shape (i) — remove all four write-tool grants, keep the seven read-shaped tools — was
  the research report's selection, applied here without revisiting the choice.
- Ran `generate-context-line-counts.sh --write` and an interim, idempotent `deploy-headless.sh`
  pass after each phase that introduced source/deploy drift (Phases 1, 3, 4; metadata+final in
  Phase 5), rather than deferring all deploy regeneration to Phase 5 alone, so each phase's own
  named scoped gate (`verify-deploy.sh --skip-slow --only-gate 3,4`) could pass as literally
  written within that phase.
- Generalized `review-gate-boundary.md`'s "mutating, unreviewed write tools" blast-radius
  framing to "this extension's tools", since the grant it describes no longer includes any
  write tool.

## Plan Deviations

- **Phase 2**: committed a third file, `agent-system/extensions/core/index-entries.json`,
  beyond the plan's named two — a direct, same-phase consequence of the line-count change the
  phase's own edit produced.
- **Phases 1, 3, 4**: each ran an additional idempotent `deploy-headless.sh` pass (not named in
  those phases' own task lists) so each phase's scoped gate could pass within that phase rather
  than being left red pending Phase 5's planned redeploy.
- **Phase 5**: discharged "run the complete gate set" against the dispatch's Batch Gate
  Deferral directive's scoped narrowing invocation (`verify-deploy.sh --skip-slow --only-gate
  3,4`) instead of the complete gate set, which runs once for the whole batch at the end of this
  invocation.

## Verification

- Build: N/A (markdown/JSON/shell source-store edits).
- Tests: `test-lint-hook-registration-paths.sh` and `test-sapience-mcp-registration.sh` — PASS
  (Phase 1). `verify-deploy.sh --skip-slow --only-gate 3,4` — PASS (Phases 2, 3, 4, 5; the
  batch-deferred scoped discharge for the Verification Tier: full phase). `bash -n
  verify-sapience-mcp.sh` parses clean.
- Files verified: Yes — `jq` length/JSON-validity checks on every edited JSON file; grep-based
  checks confirmed no remaining 11-grant/4-write-tool statement, no record-versioning language,
  and no task-reference violation in the changed files.
- Fresh-load acceptance criterion: a scratch git repository (outside this repo) loaded the
  sapience extension via `manager.load('sapience', {project_dir=..., confirm=false})` headlessly
  and produced exactly 7 `mcp__sapience__*` entries in its `.claude/settings.local.json`, none a
  write tool. `verify-sapience-mcp.sh` run against that scratch repo reported check (e) PASS at
  "7 permission grants and all 5 hooks"; check (b) (per-project MCP registration) failed there
  because the scratch load used `manager.load` directly rather than the SessionStart
  registration hook — outside this task's edit surface and outside the plan's own criterion,
  which names only check (e).
- **Merge-retraction interaction, stated explicitly, not implied as fully closed**: this
  repository's own live `.claude/settings.local.json` still carries 11 `mcp__sapience__*`
  entries (`jq '[.permissions.allow[]? | select(startswith("mcp__sapience__"))] | length'`). This
  is the expected, pre-existing additive-merge residual the plan anticipated — this repository
  loaded sapience before this narrowing, and the merge engine is additive-only, so the
  already-merged write-tool entries persist here until that engine gains retraction or the file
  is hand-edited. It is not a regression and not a failure of this task; a fresh load or fresh
  deploy elsewhere gets the narrowed 7-entry grant directly, as the scratch-repo test above
  confirms.
- A full, unscoped `verify-deploy.sh --skip-slow` run (run as part of each deploy pass, not the
  batch-deferred scoped gate) consistently reported `skills/skill-orchestrate/SKILL.md`
  exceeding its 25000 B budget ceiling, and intermittently reported gate3/gate4/gate10 60s
  timeouts under concurrent sibling-task load. Neither finding is in this task's edit surface
  (no phase touches `skill-orchestrate/SKILL.md`, and the timeouts did not recur consistently)
  and both are left unaddressed here, reported for visibility.

## Impacts

- Any session that proactively attempts an MCP call to `sapience_remember`, `sapience_wrapup`,
  `sapience_handoff`, or `sapience_adddoc` in this repository (or any fresh load elsewhere) now
  hits an interactive permission prompt in an interactive session, and is denied outright in a
  headless/autonomous run, instead of succeeding silently and landing a permanent, undeletable,
  untagged write. The prescribed write path (`scripts/sapience-remember.sh`) is unaffected, since
  it is a Bash script call and needs no MCP grant.
- A repository that loaded sapience before this change keeps its already-merged four write-tool
  grants in its own `.claude/settings.local.json` until the additive-only merge engine gains
  retraction, or the file is hand-edited — this repository is itself such a case (see
  Verification above).

## Follow-ups

- None named by this task. The merge-retraction limitation (an already-merged repository's
  write-tool entries persisting) and the separate, still-open dotfiles-level user-scope read-grant
  question are both recorded as non-blockers in the touched files, not new follow-up items this
  task is creating.

## References

- `specs/616_narrow_sapience_write_tool_grants/plans/01_narrow-sapience-write-tool-grants.md`
- `specs/616_narrow_sapience_write_tool_grants/reports/01_narrow-sapience-write-tool-grants.md`
- `agent-system/extensions/sapience/rules/sapience-write-path.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md`
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`
