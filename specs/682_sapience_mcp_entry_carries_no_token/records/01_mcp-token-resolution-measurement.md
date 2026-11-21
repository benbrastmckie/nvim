# Measurement Record: mcp.py Token Resolution With `SAPIENCE_TOKEN` Unset

Phase 1 of `plans/01_remove-token-from-mcp-entry.md`. Mechanical measurement, not a
read-through: each of the four invocation shapes the `~/.claude.json` MCP entry reaches
(`--briefing-text`, `--receipt`, `--effect-line`, and the bare stdio server), plus the
`--statusline` authentication probe named in the plan, was run against the installed
`~/.sapience/mcp.py` under an environment with `SAPIENCE_TOKEN` (and every other variable)
stripped, using `env -i HOME="$HOME" <absolute-python3> ~/.sapience/mcp.py <flag>`. The
resolved absolute interpreter was `/nix/store/d46rhmbqymlll29aff158h8yd1rg6yzv-python3-3.13.15-env/bin/python3.13`.

## Token Fingerprint (no raw value recorded)

- `~/.sapience/config.json` mode: `-rw-------` (0600)
- `.token` field length: 16
- `.token` field SHA-256, first 12 hex chars: `1ccd05e02475`

## Per-Shape Results

| # | Shape | Command | Observed result | Verdict |
|---|-------|---------|------------------|---------|
| 1 | `--statusline` (auth probe) | `env -i HOME="$HOME" python3 mcp.py --statusline` | `sapience: 5262 staged · 1 worth seeing` (exit 0) — a live, authenticated server reply, not the token-absent fallback text `sapience: set token` that line 2008 of `mcp.py` prints when `TOKEN` is falsy | **PASS** — token resolved from `config.json` |
| 2 | `--briefing-text` | `env -i HOME="$HOME" python3 mcp.py --briefing-text` | Full "Your Sapience remembers:" block printed (exit 0); this call is authenticated (server-backed content), which is impossible with an empty `TOKEN` | **PASS** |
| 3 | `--receipt` | `env -i HOME="$HOME" python3 mcp.py --receipt` | One-line receipt printed: "Your Sapience kept 20 things recently: ... (sapience stats for more)" (exit 0); authenticated | **PASS** |
| 4 | `--effect-line` | `printf '{}' \| env -i HOME="$HOME" python3 mcp.py --effect-line` | Silent, exit 0 (the flag's own documented silent-when-nothing-to-say behavior; no `Set SAPIENCE_TOKEN` stderr message or non-zero exit, which is the only observable failure mode for this shape) | **PASS** |
| 5 | bare stdio server (`initialize`) | `echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26"}}' \| env -i HOME="$HOME" python3 mcp.py` | A well-formed JSON-RPC `result` reply (`serverInfo`, `capabilities`, `instructions`), exit 0 — not the `Set SAPIENCE_TOKEN (from your Sapience link).` stderr message plus `sys.exit(1)` that the `if not TOKEN:` guard at `mcp.py:2015-2016` produces when `TOKEN` is empty | **PASS** |

All five probes passed. No shape required `SAPIENCE_TOKEN` to be present in the environment;
each resolved the token from `~/.sapience/config.json` via the single module-level statement
`TOKEN = os.environ.get('SAPIENCE_TOKEN') or _CFG.get('token') or ''` (`mcp.py:44`), which runs
at import time, before any CLI-flag or stdio dispatch — confirming mechanically what the research
report established by inspection.

## Verdict for Build Item (2)

No divergent shape was found. Build item (2) applies **unconditionally**: Phase 2 may drop
`SAPIENCE_TOKEN` from the written MCP entry's `env` for every scope, with no case requiring the
variable to be retained. The plan's contingency clause ("if Phase 1 contradicts the research...")
does not trigger.
