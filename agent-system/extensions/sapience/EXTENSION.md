## Sapience Extension

Permission grants and orientation docs for Sapience, the hosted knowledge vault at app.spnc.ai
configured by this machine's own nix modules. See `~/.dotfiles/docs/sapience.md` for the full
machine configuration; this extension does not duplicate it.

### Already Ambient -- Do Not Rebuild

The MCP server registration (`~/.claude.json`'s `mcpServers.sapience`) and three hooks
(SessionStart -> `mcp.py --briefing-text`, SessionEnd -> `mcp.py --receipt`, Stop -> `mcp.py
--effect-line`) already exist in `~/.dotfiles/config/claude/settings.json`, enforced on every
home-manager switch. This extension never re-registers the server or re-declares those hooks.

### What This Extension Adds

The seven existing `mcp__sapience__*` permission grants in `~/.dotfiles` are read-only. This
extension's `settings-fragment.json` grants the four MCP write tools
(`sapience_remember`, `sapience_wrapup`, `sapience_handoff`, `sapience_adddoc`) at this
repository's own project scope, so an autonomous `/orchestrate` dispatch here can save a finding
without hitting an interactive permission prompt. This fix is repository-scoped, not
machine-wide -- see `context/project/sapience/domain/review-gate-boundary.md`.

### Postflight Wrapup Instruction

At the `[IMPLEMENTING]` -> `[COMPLETED]` transition, call `sapience_wrapup` with 3-8 distilled
notes drawn from the summary artifact just written. Do NOT call `sapience_remember` proactively
mid-run: MCP write tools bypass the `sapience review` gate, and a per-dispatch save would flood
the vault across an `/orchestrate` batch.

### No Task Type, No Routing, No Slash Command

Sapience is not a domain to implement in: this extension declares no `task_type` and no
`routing_agents`, and provides no `/sapience` command -- review, sync, coverage, pending, and
stats are already covered by the GNOME desktop launchers the nix module installs.

### Context Pointers

Read-on-demand reference material, not eager-loaded:

- `context/project/sapience/README.md`
- `context/project/sapience/domain/vault-model.md`
- `context/project/sapience/domain/review-gate-boundary.md`
- `context/project/sapience/domain/transcript-filter-ceiling.md`
- `context/project/sapience/domain/subagent-orientation.md`
