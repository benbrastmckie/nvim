# Implementation Summary: Task #29

- **Task**: 29 - Generate .mcp.json from extension manifests, then register obsidian-memory through it
- **Status**: [COMPLETED]
- **Started**: 2026-11-06T07:25:00Z
- **Completed**: 2026-11-06T10:10:00Z
- **Effort**: ~2.75 hours
- **Dependencies**: 22
- **Artifacts**: plans/01_mcp-merge-target-mechanism.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added a `merge_targets.mcp` manifest key so an extension can declare an MCP server and have the
deploy engine register it into a project-scoped `.mcp.json` -- a surface Claude Code itself
reads, replacing the dead `mcpServers` declarations that used to sit inert inside
`settings-fragment.json` files. The mechanism reuses the existing, proven `merge_settings()`/
`unmerge_settings()` primitive verbatim (the same one `merge_targets.settings` already uses),
which is what gives it all four required properties -- generation, retraction on unload,
idempotent redeploy, and hand-written-entry survival -- without new merge logic. A durable
regression harness, full documentation (including two user-visible gotchas), and the settled
resolution of the absorbed obsidian-memory sub-task round out the six phases.

## What Changed

- `lua/neotex/plugins/ai/shared/extensions/init.lua` -- new `mcp` branches in
  `process_merge_targets()`/`reverse_merge_targets()`, plus decision-6 empty-file cleanup on
  unload
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` -- new `verify_mcp_merge()` and its
  `verify_extension` call site
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` -- `M.write_json`/`M.merge_settings`
  gained an optional `opts.sort_keys` (the Risks-table contingency for byte-identical redeploys),
  passed only from the `mcp` branch
- `lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua` -- new `mcp` positive validation
  case; the stale `"should reject manifest with invalid merge_targets type"` test rewritten to
  assert the real open-set contract
- `lua/neotex/plugins/ai/shared/extensions/merge_spec.lua` -- new describe block asserting all
  four `.mcp.json` requirements directly against `merge_settings()`/`unmerge_settings()`
- `agent-system/extensions/core/scripts/tests/test-mcp-merge-target.sh` -- new durable
  scratch-tree regression harness (7 assertions, wired into Gate 8 via `run-all.sh`)
- `agent-system/extensions/core/context/guides/extension-development.md` -- `merge_targets.mcp`
  authoring guide, fragment shape, mandatory `"type"` field, valid-key list
- `agent-system/extensions/core/docs/architecture/extension-system.md` -- new "MCP Server
  Registration" section, corrected registration-surface note, `mcp` step in load/unload process
  lists, two-gotcha subsection, two stale `merge_opencode_agents()`/`unmerge_opencode_agents()`
  rows removed
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` -- one-hop
  cross-reference to the new mechanical how-to
- `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` -- header comment
  generalized to not cite the deleted memory fragment file
- `agent-system/extensions/memory/settings-fragment.json` -- deleted (dead `mcpServers` block,
  no permission grants)
- `agent-system/extensions/memory/manifest.json` -- dangling `merge_targets.settings` entry
  removed
- `agent-system/extensions/memory/README.md`,
  `context/project/memory/memory-setup.md`,
  `context/project/memory/memory-troubleshooting.md` -- corrected to describe Claude Code's
  native `/ide` integration as the real `obsidian-claude-code-mcp` connection path; the
  nonexistent npm package removed; tool surface explicitly marked unverified with reason
- `agent-system/extensions/core/manifest.json`, `agent-system/extensions/core/index-entries.json`,
  `agent-system/extensions/memory/index-entries.json` -- mechanical side-effects (new test
  script registered in `provides.scripts`; `line_count` corrections for edited doc files)

## Decisions

- Requirement (d) (hand-written survival) resolves by construction (deep-merge's additive-only
  semantics); `.mcp.json` carries no in-file "generated" banner, documented in prose instead.
- `.mcp.json` is NOT added to `.gitignore` -- it sits at the same project-root tier as the
  tracked `.claude-extensions.json`.
- `validate_merge_targets()` stays open-set; no closed key enum introduced (the cost -- a
  typo'd key validates silently -- is pre-existing and identical for all merge-target keys).
- The empty-file cleanup on unload lives in `reverse_merge_targets()`'s new `mcp` branch, not in
  `merge.lua`, so the `settings` path stays untouched.
- The absorbed obsidian-memory sub-task resolves per the settled Option 1 decision: the
  npx/`.mcp.json` wiring is dropped entirely; Claude Code's native `/ide` integration is
  documented as the real connection path; no substitute Obsidian MCP package is selected and no
  tool names are invented.

## Plan Deviations

- **Task 6.2** altered: the plan's full, unscoped `verify-deploy.sh` run was discharged against
  a scoped `--only-gate 3,4,13,21,22,23` invocation instead, per this dispatch's own Batch Gate
  Deferral directive (this task is one of several implement-phase dispatches inside one
  multi-task `/orchestrate` batch; the complete gate set runs once for the whole batch).
- **Task 6.3** altered: the plan's full, unscoped `run-all.sh` run was discharged against
  `run-all.sh --only test-mcp-merge-target.sh,test-lint-hook-registration-paths.sh,test-manifest-scripts-sync.sh`
  instead, per the same directive.
- **Task 2.4** altered: `merge_spec.lua`'s "confirm zero failures" criterion could not be
  literally met -- the file carries one pre-existing, unrelated hook-dedupe test failure,
  confirmed unchanged by this task's own edits throughout. All 4 new `.mcp.json` requirement
  tests pass.

## Verification

- Build: N/A (Lua/Neovim configuration, no compiled build step)
- Tests: `test-mcp-merge-target.sh` 7/7 PASS; `manifest_spec.lua` 18/0; `merge_spec.lua` 10/1
  (1 pre-existing, unrelated failure, unchanged throughout this task); `test-lint-hook-registration-paths.sh`
  PASS; `test-manifest-scripts-sync.sh` FAILs on 9 undeclared `agent-system/extensions/lean`
  files -- all belonging to the concurrently-dispatched sibling task's own in-flight territory,
  not introduced by this task
- Files verified: Yes

### Empirical findings (Phase 3, carried into documentation)

- **Requirement (c), byte-identity**: REPRODUCED the risk on first measurement (`jq .` is
  order-preserving, not sorting). Applied the plan's pre-approved contingency -- an optional
  `opts.sort_keys` on `M.write_json`/`M.merge_settings`, passed only from the `mcp` branch --
  and re-confirmed byte-identical under `cmp`.
- **The regenerate-then-unload risk**: REPRODUCED. A `load -> regenerate (forced reload) ->
  unload` sequence does not retract the extension's own entry, because `manager.load`
  overwrites (never merges) its own previously-persisted tracked data on every load call. This
  is a pre-existing limitation of the shared `merge_settings`/`state_mod.mark_loaded` path (the
  `settings` branch has the identical limitation) -- not introduced by `mcp`, and left
  unfixed per the plan's explicit instruction. A plain `load -> unload` round trip (no
  intervening reload) retracts fully and correctly, including the empty-file cleanup.
- **`claude mcp get <fixture>`**: the server RESOLVED, reporting
  `Scope: Project config (shared via .mcp.json)` and
  `Status: ⏸ Pending approval (run \`claude\` to approve)` -- a visible pending-trust status
  under the v2.1.196+ workspace-trust gate, not an outright resolution failure. Documented
  verbatim in `extension-system.md`'s "Two user-visible gotchas" subsection.

### No-deploy constraint

Confirmed at every phase and again at completion: `git status --short` shows no `.claude/`
modifications and no root `.mcp.json` exists. All verification ran against scratch fixtures
under a `mktemp -d` WORKDIR, never against this repository.

## Impacts

- Any future extension can register a real MCP server by declaring `merge_targets.mcp`,
  reaching a surface (`project-scoped .mcp.json`) Claude Code actually reads -- closing a gap
  where every prior `mcpServers`/`mcp_servers` declaration in this system registered nothing.
- Two previously undocumented, easily-misread behaviors (workspace-trust pending-approval status,
  already-running-session invisibility) are now documented where a user will find them before
  filing a correctly-working registration as broken.
- The memory extension no longer carries a dead, fabricated server declaration; its docs now
  tell the truth about the `/ide`-based connection path and plainly flag the unverified tool
  surface.

## Follow-ups

- `agent-system/extensions/lean`'s own pre-existing/concurrent findings (9 undeclared
  script/fixture files surfaced by Gate 13 orphan detection and `test-manifest-scripts-sync.sh`;
  two `deployed script content drift` findings) are the concurrently-dispatched sibling task's
  own territory and were left untouched throughout -- not a follow-up for this task, noted here
  only so a reader of this summary does not mistake them for a regression this task introduced.
- This task's own `lint-hook-registration-paths.sh` edit produces an expected,
  unavoidable `deployed script content drift` finding until this repository's own `.claude/`
  tree is next regenerated (deliberately deferred here by the dispatch's no-deploy constraint).
- No in-repo extension currently declares `merge_targets.mcp` (by design, per the settled
  obsidian-memory decision) -- the mechanism ships with zero live consumers until a future task
  registers a real server through it.

## References

- `specs/029_generate_mcp_json_from_extension_manifests/plans/01_mcp-merge-target-mechanism.md`
- `specs/029_generate_mcp_json_from_extension_manifests/reports/01_mcp-json-generation-mechanism.md`
- `specs/029_generate_mcp_json_from_extension_manifests/progress/phase-{1..6}-progress.json`
- `specs/029_generate_mcp_json_from_extension_manifests/handoffs/phase-{1..5}-handoff-*.md`
- `agent-system/extensions/core/scripts/tests/test-mcp-merge-target.sh`
