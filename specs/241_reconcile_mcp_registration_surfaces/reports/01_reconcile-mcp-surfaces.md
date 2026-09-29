# Research Report

**Task**: 241 - Reconcile MCP registration surfaces: redundant playwright grants, dead manifest mcp_servers fields, ownership doc and nix README
**Started**: 2026-09-29T22:43:24Z
**Completed**: 2026-09-29T22:46:03Z
**Effort**: small
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/**), `~/.claude/settings.json`, `~/.claude.json`, `~/.dotfiles/config/claude/settings.json` (read-only cross-repo verification)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The hard precondition for item 1 is met right now: `~/.claude/settings.json` carries exactly
  9 `mcp__playwright__*` entries, byte-for-byte the same 9 tools enumerated in
  `agent-system/extensions/web/settings-fragment.json` and `.../present/settings-fragment.json`
  (confirmed identical via diff). `~/.claude.json` registers `playwright` at user scope
  (`command: playwright-mcp`). Item 1 is unblocked.
- Item 2's five-manifest inventory is exact and closed: `filetypes`, `founder`, `lean`, `memory`,
  `nix` are the only `manifest.json` files under `agent-system/extensions/*/` carrying an
  `mcp_servers` field. A repo-wide grep restricted to `*.sh`/`*.py`/`*.lua` in `agent-system/`
  found zero readers of the field — the only remaining references are the five doc mentions the
  task description already names plus a `manifest.json`-and-doc self-reference set, all of which
  already describe the field as inert. `nix`'s block still declares the trap name `mcp-nixos`
  (would map to `mcp__mcp-nixos__*` if ever read). `lean`'s `manifest.json` also declares
  `install-lean-lsp-session-hook.sh` / `lean-lsp-register-project.sh` under `hooks`, confirming
  the SessionStart/local-scope registration path the task description asserts, independent of
  the dead `mcp_servers` block.
- Item 3's four passages verified byte-for-byte against
  `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`: (a) the "Grant
  permissions at the same scope..." section still calls playwright asymmetry "a separate
  follow-up, not performed here"; (b) "Known gaps" still calls the five-manifest
  `mcp_servers` field "a recorded follow-up, not performed by this document's own edits"; (c)
  "Wildcard over enumeration" still narrates the lean-lsp triple duplication in the present tense
  ("The correct end state is one wildcard...") even though that end state is already live —
  `core/root-files/settings.json` has 0 `lean` permission entries, `lean/settings-fragment.json`
  has exactly one entry (`mcp__lean-lsp__*`), and no dead `mcpServers` block remains in lean's
  fragment; (d) "Known gaps" still lists memory's `obsidian-memory` `mcpServers` block in
  `memory/settings-fragment.json` as open, and it is — confirmed present, unchanged, and correctly
  out of this task's scope (owned by a separate existing task).
- Item 4's target passage is exactly at `nix/README.md` lines 26-34 as described, asserting
  mcp-nixos is "not currently registered by anything in this repository" and that registering it
  "is a pending follow-up." Both are now false: `~/.claude.json` registers `nixos` at user scope
  (`command: uvx`, `args: ["mcp-nixos"]`), with no project-scoped entry anywhere in
  `~/.claude.json`'s `.projects`. The other 6 `mcp-nixos` occurrences in the README (lines 3, 18,
  23, 92, 101, 195) are all the upstream package/tool name and are correctly left alone.
  `context/project/nix/tools/mcp-nixos-integration.md` was re-read in full and needs no edit — it
  is written conditionally throughout and already uses the correct `mcp__nixos__nix` /
  `mcp__nixos__nix_versions` tool names.
- No new stale surface beyond the four items was found. A fifth-looking candidate —
  `epidemiology/context/project/epidemiology/tools/mcp-guide.md`'s two `"mcp_servers": {...}`
  JSON snippets — is generic example configuration for R's `rmcp`/`mcptools` packages, unrelated
  to this system's extension-manifest mechanism (epidemiology's own `manifest.json` has no
  `mcp_servers` field), and is correctly out of scope.

## Context & Scope

Re-verified, at research time (not merely trusting the task-creation-time research already
recorded in the task description and TODO.md entry), every factual claim underpinning the four
planned items, with special attention to the item 1 hard precondition, which is explicitly
required to be re-checked at implementation time because it can regress between task creation and
implementation (a home-manager rebuild could drop the user-scope grants). All verification was
read-only; no files were modified during this research pass, consistent with the research phase
of the lifecycle.

## Findings

### Codebase Patterns

- **Item 1 precondition (live)**: `jq '[.permissions.allow[]? | select(test("playwright"))] |
  length' ~/.claude/settings.json` → `9`. The 9 entries are exactly:
  `browser_navigate`, `browser_snapshot`, `browser_take_screenshot`, `browser_console_messages`,
  `browser_network_requests`, `browser_click`, `browser_type`, `browser_find`, `browser_wait_for`
  — identical to both extension fragments (`diff` confirms byte-identical arrays across all
  three locations). **Item 1 is unblocked** as of this research pass.
- **Item 2 five-file inventory (closed)**: iterating every `agent-system/extensions/*/manifest.json`
  and testing `has("mcp_servers")` returns true for exactly `filetypes`, `founder`, `lean`,
  `memory`, `nix` — matching the task description's claim with no additions or omissions.
  `nix`'s block: `{"mcp-nixos": {"command": "uvx", "args": ["mcp-nixos"]}}` (trap name
  confirmed). `lean`'s block: `{"lean-lsp": {"command": "uvx", "args": ["lean-lsp-mcp"]}}`
  (confirmed inert relative to the actual SessionStart-hook-driven local registration; lean's
  manifest also separately declares `install-lean-lsp-session-hook.sh` and
  `lean-lsp-register-project.sh` under its `hooks` block, the real mechanism).
- **No dangling reader (re-confirmed)**: `grep -rn "mcp_servers" --include="*.sh" --include="*.py"
  --include="*.lua" agent-system/` returns zero matches. The only remaining hits are the
  `manifest.json` files themselves and markdown docs, all already accounted for in the task
  description's doc-mention list.
- **settings-fragment.json `mcpServers` block state (separate mechanism, cross-checked for
  contamination risk)**: exactly one file anywhere under `agent-system/extensions/*/settings-fragment.json`
  still carries an `mcpServers` block — `memory/settings-fragment.json`
  (`obsidian-memory`), confirmed present and unchanged. `nix/settings-fragment.json` has no
  `mcpServers` block and retains exactly the two grants
  `mcp__nixos__nix` / `mcp__nixos__nix_versions`.
- **lean triple-duplication end state (already reached, matches item 3(c)'s claim)**:
  `core/root-files/settings.json` → 0 entries matching `lean`; `lean/settings-fragment.json` →
  exactly one entry, `mcp__lean-lsp__*`.
- **Ownership doc passages (a)–(d)**: read in full; each passage's current wording matches the
  task description's quotations verbatim (see Executive Summary for the specific stale phrases
  each still contains). No additional stale passage was found beyond the four named — in
  particular, the doc's "Known gaps" Retirement/Migration paragraphs (about
  `epidemiology`/`filetypes`/`founder`/`nix` `settings-fragment.json` `mcpServers` blocks) already
  correctly describe that *separate* mechanism's resolved state in past tense and are not part of
  this task's four passages; they should not be touched.
- **nix/README.md**: lines 26-34 confirmed as the sole stale passage; the other six `mcp-nixos`
  occurrences (upstream package name, tools-table cell, GitHub URL) are correct as-is and must not
  be touched. `context/project/nix/tools/mcp-nixos-integration.md` re-read in full: uses only
  `mcp__nixos__nix` / `mcp__nixos__nix_versions`, phrased conditionally throughout — needs no edit.
- **Cross-repo registration facts** (read-only, `~/.claude.json` / `~/.dotfiles`, not edited):
  `~/.claude.json`'s top-level `.mcpServers` carries both `nixos` (`uvx mcp-nixos`) and
  `playwright` (`playwright-mcp`), both with no matching entries under any `.projects[*].mcpServers`
  — i.e. genuinely user-scope, not merely user-scope-shaped. `~/.dotfiles/config/claude/settings.json`
  carries the corresponding `mcp__nixos__nix` / `mcp__nixos__nix_versions` grants (separate task's
  territory; not read further than confirming existence).

### External Resources

Not applicable — this is a purely internal reconciliation task with no external API or library
surface.

### Recommendations

- Proceed with all four items as specified in the task description; no revision to scope, file
  list, or verification steps is indicated by this research pass.
- At implementation time, re-run the item 1 precondition check
  (`jq '[.permissions.allow[]? | select(test("playwright"))] | length' ~/.claude/settings.json`)
  one more time immediately before the deletion, per the task's own "re-verify at implementation
  time" instruction — this research pass's confirmation is current as of 2026-09-29T22:46Z but a
  home-manager rebuild between now and implementation would still regress it.
- No plan-level changes needed to the "DO NOT EDIT" list
  (`context/project/nix/tools/mcp-nixos-integration.md`) or the "OUT OF SCOPE" boundary (task 30's
  `memory/settings-fragment.json` `mcpServers` block) — both were independently re-verified here
  and remain correct constraints.

## Decisions

- Confirmed item 1 is unblocked (precondition count = 9); the plan should proceed with the
  deletion rather than routing it into the "blocked item" fallback path.
- Confirmed no fifth stale surface exists; the epidemiology `mcp-guide.md` example snippets are
  correctly excluded from scope.

## Risks & Mitigations

- **Precondition regression between research and implementation**: mitigated by the task's own
  binding instruction to re-check the count immediately before the item 1 deletion at
  implementation time, not merely rely on this report's snapshot.
- **Accidental touch of the OUT-OF-SCOPE memory `mcpServers` block**: mitigated by this report's
  explicit re-confirmation that it is a different file/mechanism from item 2's manifest.json
  target, and by the task's own verification step requiring it be byte-identical post-change.
- **Blanket-rename risk on nix/README.md**: mitigated by this report's explicit re-listing of the
  six occurrences that must stay untouched (upstream project name) versus the one passage
  (lines 26-34) that must change (registration claim).

## Context Extension Recommendations

None — this is a meta task correcting existing documentation; no new context file is indicated.

## Appendix

- Search queries used: `jq` field/permission inspections on `~/.claude/settings.json`,
  `~/.claude.json`, and every `agent-system/extensions/*/manifest.json` and
  `*/settings-fragment.json`; `grep -rn "mcp_servers"` / `grep -rn "mcp-nixos"` across
  `agent-system/` and `nix/README.md`; `diff` between web/present playwright enumeration arrays.
- References: `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`,
  `agent-system/extensions/nix/README.md`, `agent-system/extensions/{web,present}/settings-fragment.json`,
  `agent-system/extensions/{filetypes,founder,lean,memory,nix}/manifest.json`.
