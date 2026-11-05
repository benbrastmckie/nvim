# Sapience Extension

Permission grants and orientation docs for Sapience, the hosted knowledge vault at app.spnc.ai
configured by this machine's nix modules (`modules/home/services/sapience.nix`). This extension
provides no task type, no routing agents, and no slash command -- it closes three gaps blocking
autonomous work in this repository from using the vault, and documents the vault's own model.

## File Inventory

| File | Role |
|------|------|
| `manifest.json` | Extension declaration: no `task_type`, no `routing_agents`, `routing_exempt: true`; three merge targets (`claudemd`, `index`, `settings`) |
| `settings-fragment.json` | `permissions.allow` grant for the four MCP write tools (gap 1's payload) |
| `EXTENSION.md` | Merges into `.claude/CLAUDE.md` under `extension_sapience`; carries the gap-2 postflight wrapup instruction |
| `index-entries.json` | Context index entries for the five files under `context/project/sapience/` |
| `context/project/sapience/` | Domain notes: vault model, review-gate boundary, transcript-filter ceiling, subagent orientation |

## The Three Gaps This Extension Closes

**Gap 1 -- missing write-tool permissions.** The dotfiles-level `permissions.allow` list grants
only the seven read-only `mcp__sapience__*` tools. The four write tools
(`sapience_remember`, `sapience_wrapup`, `sapience_handoff`, `sapience_adddoc`) are absent, so an
autonomous dispatch that tries to save a finding hits an interactive permission prompt and fails
non-interactively. `settings-fragment.json` grants exactly these four tools, merged into this
repository's own `.claude/settings.local.json`.

**Repository-scoped, not machine-wide.** This fix only helps dispatches inside this `nvim` config
repository. A session in any other project on this machine still hits the same permission prompt
on the four write tools, because that project's own `.claude/settings.local.json` never receives
this grant. Making the fix machine-wide would mean adding the same four entries to
`~/.dotfiles/config/claude/settings.json`, a different repository, and is a deliberately
out-of-scope follow-up. See `context/project/sapience/domain/review-gate-boundary.md`.

**Gap 2 -- postflight knowledge capture.** `EXTENSION.md`'s wrapup instruction is
documentation-only: no script, no hook. It merges into `.claude/CLAUDE.md`, which is injected
into every agent dispatch (subagents included), so the instruction reaches every implementation
agent without any new executable surface.

**Gap 3 -- subagent orientation -- closed by documentation, not a hook.** A manifest
`hooks.context_injection` entry naming a new per-dispatch script was considered and dropped. That
mechanism cannot work for an extension declaring no `task_type`:
`skill_get_extension_dir()` in `skill-base.sh` resolves lifecycle hooks by exact `task_type`
string equality, and no task will ever carry `task_type: "sapience"`. This extension ships no
hook and no script for gap 3. Instead, `context/project/sapience/domain/subagent-orientation.md`
documents the deliberate alternative (session-level briefing plus an explicitly invoked `sf1`
escape hatch) and the checkable code citation that makes the refutation verifiable rather than
asserted.
