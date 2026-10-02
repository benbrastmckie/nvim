# Implementation Summary: Reconcile MCP Registration Surfaces

- **Task**: 241 - Reconcile MCP registration surfaces: redundant playwright grants, dead manifest mcp_servers fields, ownership doc and nix README
- **Status**: [COMPLETED]
- **Started**: 2026-10-02
- **Completed**: 2026-10-02
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_reconcile-mcp-surfaces.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Reconciled four related MCP registration/permission surfaces in the agent-system source store:
emptied two byte-identical, redundant copies of the 9-tool playwright safe-tier enumeration;
deleted five inert `manifest.json` `mcp_servers` fields (including `nix`'s trap-name
`mcp-nixos` declaration); corrected `core/context/patterns/mcp-server-ownership.md`'s five
now-stale passages; and corrected `nix/README.md`'s registration passage. A sixth, scope-added
phase also repointed a second doc (`web/context/project/web/tools/playwright-mcp-guide.md`) that
the research sweep had not flagged but whose grant-location claim item 1 made false. All seven
phases ran to completion; the one hard precondition (live user-scope playwright grant count = 9)
was re-verified and held, so no item was blocked.

## What Changed

- `agent-system/extensions/web/settings-fragment.json` — emptied the 9-entry playwright
  `permissions.allow` list to `[]`; no wildcard substituted
- `agent-system/extensions/present/settings-fragment.json` — same, byte-identical change
- `agent-system/extensions/filetypes/manifest.json` — deleted the inert `mcp_servers` field
  (`superdoc`, `openpyxl`)
- `agent-system/extensions/founder/manifest.json` — deleted the inert `mcp_servers` field
  (`sec-edgar`, `firecrawl`)
- `agent-system/extensions/lean/manifest.json` — deleted the inert `mcp_servers` field
  (`lean-lsp`); the real per-project registration (a `SessionStart` hook) is untouched
- `agent-system/extensions/memory/manifest.json` — deleted the inert `mcp_servers` field
  (`obsidian-memory`); `memory/settings-fragment.json`'s separate, out-of-scope `mcpServers`
  block (owned by a different existing task) was left byte-identical
- `agent-system/extensions/nix/manifest.json` — deleted the inert `mcp_servers` field declared
  under the trap name `mcp-nixos`, which would otherwise have produced colliding
  `mcp__mcp-nixos__*` tools
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` — corrected five
  passages (the playwright worked-pair note, the lean-lsp wildcard-drift paragraph, the carve-out
  worked example's location, the "second dead surface" Known-gap paragraph, and the Migration
  paragraph's tense) from pending-follow-up/present-tense-defect phrasing to a corrected-end-state
  description; the memory (`obsidian-memory`) Known-gap entry was deliberately left open
- `agent-system/extensions/nix/README.md` — rewrote the `### mcp-nixos` registration passage to
  record live user-scope registration under the name `nixos`, explained why the trap name was
  deleted, and dropped the dangling `mcpServers`-block sentence and the pending-follow-up sentence;
  the six upstream package/URL-level occurrences of `mcp-nixos` are untouched
- `agent-system/extensions/web/context/project/web/tools/playwright-mcp-guide.md` — repointed two
  sentences in `## Permission Tiers -- Unprompted vs. Prompting` from the now-emptied
  `web/settings-fragment.json` to user-scope `~/.claude/settings.json` (scope addition, performed
  because item 1's precondition held)

## Decisions

- Item 1's two fragments were rewritten to `{"permissions": {"allow": []}}` rather than deleted,
  because both extensions' manifests declare `merge_targets.settings.source:
  "settings-fragment.json"` and neither manifest was in scope to repoint.
- Phase 6 (the playwright-mcp-guide.md scope addition) was performed, not dropped, since item 1's
  precondition held and Phase 2 ran — leaving that doc pointing at an emptied file would have
  reintroduced the exact drift-and-confusion class item 1 removes.
- Phase 4 was committed as a single atomic batch (five edit sites in one file), per its
  `Commit Mode: atomic-batch` declaration, to avoid an internally-contradictory intermediate
  document state.

## Plan Deviations

- **Task 1.6** (doc-lint baseline): plan predicted a one-FAIL baseline (`core`,
  `reap-session-runtime-files.sh` drift); the actual re-verified baseline was zero-FAIL — that
  pre-existing drift had evidently already been fixed by another task since plan time.
- **Task 1.3** (no-dangling-reader sweep): found one additional hit beyond the plan's inventory,
  `agent-system/extensions/epidemiology/context/project/epidemiology/tools/mcp-guide.md`, which
  uses the string `"mcp_servers"` only as a generic MCP-client-config JSON example — unrelated to
  the agent-system manifest mechanism, not a reader, out of file scope. Left untouched.
- **Task 7.6 / 7.8** (gate exit codes and doc-lint PASS requirement): `deploy-headless.sh` and
  `verify-deploy.sh` both landed non-zero, and `check-extension-docs.sh` shows `core` (plus
  `literature` and `project-wide`) as FAIL. Every finding names a file in a concurrently-dispatched
  sibling task's declared file scope (task 44's `commands/task.md`,
  `context/patterns/task-abandon-mode.md`, `context/patterns/task-description-transformation-examples.md`;
  task 39's `literature/scripts/literature-ingest-online.sh`) — none names a file this plan
  touched. `nix`, `web`, and `present` (the three extensions this plan actually edited docs/grants
  in) are all PASS. Reported per the plan's own risk-mitigation table and concurrency note, not
  fixed.

## Verification

- Build: N/A (markdown/JSON source-store edit task)
- Tests: `jq empty` passed on all seven edited JSON files; `grep`/hash/diff checks per-phase all
  passed as specified in the plan
- Files verified: Yes — `memory/settings-fragment.json` hash unchanged, `lean/manifest.json`
  hooks intact, `nix/settings-fragment.json` grants intact, ownership doc known-gap (d) still
  open, `mcp-nixos-integration.md` unmodified
- `deploy-headless.sh`: landed (`RESULT=landed_verify_red`); its own fast-gate verification
  failures are both sibling-attributable (see Plan Deviations)
- `verify-deploy.sh`: FAIL, 2 of 33 checks, same sibling attribution
- `check-extension-docs.sh`: `nix`, `web`, `present` PASS; `core`/`literature`/`project-wide` FAIL,
  entirely from sibling tasks 44 and 39's in-flight edits, not this plan's files

## Impacts

- A newly added safe Playwright tool now requires exactly one edit (user-scope
  `~/.claude/settings.json`) instead of three synchronized edits across two extension fragments
  plus the user-scope file.
- `nix`'s manifest no longer declares a trap-name `mcp-nixos` server that would have collided with
  the live `nixos` registration and its matching grants if ever read.
- Three documents (`mcp-server-ownership.md`, `nix/README.md`, `playwright-mcp-guide.md`) no
  longer assert a pending follow-up, an unregistered server, or a grant location that this task's
  own changes just falsified.

## Follow-ups

- None from this task's own scope. Pre-existing, out-of-scope items noted but intentionally
  untouched: `memory/settings-fragment.json`'s dead `mcpServers` block (owned by a separate
  existing task) and the three sibling-owned doc-lint/verify-deploy findings observed during
  Phase 7 (owned by their respective concurrently-dispatched tasks).

## References

- specs/241_reconcile_mcp_registration_surfaces/plans/01_reconcile-mcp-surfaces.md
- specs/241_reconcile_mcp_registration_surfaces/reports/01_reconcile-mcp-surfaces.md
- agent-system/extensions/core/context/patterns/mcp-server-ownership.md
- agent-system/extensions/nix/README.md
