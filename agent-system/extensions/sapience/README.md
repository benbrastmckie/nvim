# Sapience Extension

Permission grants, the per-repo MCP activation surface, and orientation docs for Sapience, the
hosted knowledge vault at app.spnc.ai configured by this machine's nix modules
(`modules/home/services/sapience.nix`). This extension provides no task type, no routing
agents, and no slash command -- it closes the gaps blocking autonomous work in this repository
from using the vault, makes loading the extension the sole per-repo activation surface, and
documents the vault's own model.

## File Inventory

| File | Role |
|------|------|
| `manifest.json` | Extension declaration: no `task_type`, no `routing_agents`, `routing_exempt: true`; three merge targets (`claudemd`, `index`, `settings`) |
| `settings-fragment.json` | `permissions.allow` grant for all 11 `mcp__sapience__*` tools (7 read + 4 write) and five of the six total hook surfaces -- `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `SessionEnd`, `Stop` (gaps 1 and 4's payload); the sixth, a separate user-level MCP-registration `SessionStart` hook, is installed below, not merged by this fragment |
| `scripts/setup-sapience-mcp.sh` | Per-project writer: registers/repairs/removes `.projects["<abs path>"].mcpServers.sapience` in `~/.claude.json` |
| `hooks/sapience-mcp-register-project.sh` | Bidirectional `SessionStart` hook: invokes the writer when this repo's `.claude-extensions.json` shows the extension active, removes the entry when it does not |
| `scripts/install-sapience-mcp-session-hook.sh` | Idempotent, `--remove`-capable installer seeding the hook and the writer to `$HOME/.claude/{hooks,scripts}/` and registering the `SessionStart` entry in `$HOME/.claude/settings.json` |
| `scripts/verify-sapience-mcp.sh` | Verifier: checks extension activation, the per-project MCP entry, the installed files, the `SessionStart` registration, and the merged settings fragment |
| `EXTENSION.md` | Merges into `.claude/CLAUDE.md` under `extension_sapience`; carries the per-repo activation contract and the gap-2 postflight wrapup instruction |
| `index-entries.json` | Context index entries for the six files under `context/project/sapience/` |
| `context/project/sapience/` | Domain notes: vault model, review-gate boundary, transcript-filter ceiling, subagent orientation, per-repo scoping (now also the MCP-registration triad) |

## The Gaps This Extension Closes

**Gap 1 -- missing permission grants, now fully per-repo.** `settings-fragment.json` grants all
11 `mcp__sapience__*` tools (the 7 read tools plus the 4 write tools) at this repository's own
project scope, merged into `.claude/settings.local.json`. Loading this extension is what grants
them here; unloading it removes them. See
`context/project/sapience/domain/review-gate-boundary.md`.

**Gap 2 -- postflight knowledge capture.** `EXTENSION.md`'s wrapup instruction is
documentation-only: no script, no hook of its own. It merges into `.claude/CLAUDE.md`, which is
injected into every agent dispatch (subagents included), so the instruction reaches every
implementation agent without any new executable surface.

**Gap 3 -- subagent orientation -- closed by documentation, not a hook.** A manifest
`hooks.context_injection` entry naming a new per-dispatch script was considered and dropped. That
mechanism cannot work for an extension declaring no `task_type`:
`skill_get_extension_dir()` in `skill-base.sh` resolves lifecycle hooks by exact `task_type`
string equality, and no task will ever carry `task_type: "sapience"`. This extension ships no
hook and no script for gap 3. Instead, `context/project/sapience/domain/subagent-orientation.md`
documents the deliberate alternative (session-level briefing plus an explicitly invoked `sf1`
escape hatch) and the checkable code citation that makes the refutation verifiable rather than
asserted.

**Gap 4 -- MCP server registration, now a per-repo activation surface.** The
`setup-sapience-mcp.sh` / `sapience-mcp-register-project.sh` / `install-sapience-mcp-session-hook.sh`
/ `verify-sapience-mcp.sh` triad (first three) plus verifier mirror the lean extension's own
per-project `lean-lsp` triad: loading this extension and running the installer makes a repo's own
`.projects[<abs path>].mcpServers.sapience` entry in `~/.claude.json` appear and disappear with
the extension's load state, via a `SessionStart` hook installed at a stable user-level path (not
inside any repository's own disposable `.claude/` tree). A surviving top-level
`.mcpServers.sapience` entry, written by this machine's home-manager activation, is EXPECTED
residual, not drift, until a separate task disables that activation -- see
`context/project/sapience/domain/per-repo-scoping.md`.
