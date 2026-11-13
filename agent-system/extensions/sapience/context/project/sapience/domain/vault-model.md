# Vault Model

## Hosted Vault

Sapience is a hosted knowledge vault at `https://app.spnc.ai`. It is not a local file store: the
MCP server registered in `~/.claude.json` (`mcpServers.sapience`) is a thin client that talks to
this hosted service over HTTPS, authenticated by a token in that same registration's `env`
block. Machine-wide configuration (the nix module, the GNOME desktop launchers, the three
Claude Code hooks) lives at `~/.dotfiles/docs/sapience.md` -- read that file for the full machine
setup rather than duplicating it here.

## The MCP Thin Client

The twelve MCP tools (`sapience_search`, `_briefing`, `_context`, `_ask`, `_outstanding`,
`_papers`, `_remember`, `_wrapup`, `_handoff`, `_adddoc`, `_connect`, `_join`) are the primary
interface an agent uses. Each is a network call to the hosted vault; none of them is a local
cache lookup.

## `mcp.py`'s Exact Mode Inventory

This section covers `~/.sapience/mcp.py` specifically — one of two local vendor CLIs, not the
only one; see "`sapience_cli.py` and `POST /v1/cli/context`" below for the other.
`~/.sapience/mcp.py` doubles as a small CLI, used by the `SessionStart` hook and by the GNOME
desktop launchers. Its complete set of CLI modes is:

- `--briefing-text` -- SessionStart hook: prints a "Your Sapience remembers" block, silent when
  there is nothing to say.
- `--statusline` -- a one-line summary (e.g. "sapience: 3 staged, 2 worth seeing").
- `--stats` -- vault statistics.
- `--status` -- which memory store each surface on this machine points at.
- `--receipt` -- SessionEnd hook: one-line receipt of what was kept this session.
- `--effect-line` -- Stop hook: one line on what Sapience did for the turn that just ended.
- `--adddoc` / `--adddir` -- ingest a local PDF/txt/md file or directory into the vault.
- `--refresh-cache` -- background cache refresh for the statusline fast path.

**There is no `--search` mode and no `--ask` mode.** Any shell-side query that needs the vault's
own search or question-answering must go through the separate `sf1 "question"` one-shot CLI, a
direct HTTPS call to `/v1/ask`, or `GET /v1/search` -- each a network round-trip, never a local
lookup. The one per-dispatch, shell-invoked retrieval mechanism this extension does provide,
`sapience-retrieve.sh`, calls `/v1/search` directly rather than through `mcp.py`; see
`per-repo-scoping.md` for its repo-tag-filtered scoping mechanism and `subagent-orientation.md`
for why a per-dispatch injection is the accepted shape.

## `sapience_cli.py` and `POST /v1/cli/context`

`~/.sapience/sapience_cli.py` is the second local vendor CLI, distinct from `mcp.py` above. Its
`hook session|prompt|tool|stop` modes back the `UserPromptSubmit` and `PreToolUse` hooks (the
deployed `SessionStart` hook calls `mcp.py`, not this script's `session` mode — see
`domain/injection-site-scoping.md` for the corrected, measured site-by-site table). All four
modes share one endpoint, `POST /v1/cli/context`. The measured fact that matters most here: on
this endpoint, the `project` field the `prompt` mode already sends is silently ignored — a
request naming this repository's own resolved slug and an otherwise-identical request naming a
nonexistent sentinel project return byte-identical `text`/`visible` bodies. See
`domain/injection-site-scoping.md` for the full reproduction, the response's attribution-free
key set, and the two owner actions that follow from it; it is not restated here.
