# Review-Gate Boundary

## Two Different Paths Into the Vault

Sapience has two architecturally distinct ways content reaches the hosted vault, and they are
governed by different rules. Confusing them is the single most consequential mistake this
extension's design avoids.

**The transcript-extraction path** (`~/.sapience/upload.py`, driven by the `sapience sync` /
`coverage` / `pending` / `review` CLI verbs) reads Claude Code session transcripts, classifies
and chunks candidate content, and stages it locally. This machine's `config.json` sets
`auto_approve: false`, so nothing staged by this path reaches the hosted vault until a human
runs `sapience review` and explicitly approves it.

**The MCP write-tool path** (`sapience_remember`, `sapience_wrapup`, `sapience_handoff`,
`sapience_adddoc`, called live during a session) writes straight to the hosted vault. There is
no staging and no review step for this path -- confirmed directly from each tool's own
description string in `mcp.py`: `sapience_wrapup`'s description states each note "is saved to
the user's persistent cross-session memory," with no mention of staging or approval.

## Why This Makes the Postflight-Only Scoping Load-Bearing

Because the MCP write-tool path bypasses the `auto_approve: false` review gate entirely, every
call is effectively a permanent, unreviewed write. This extension's gap-2 instruction (write 3-8
notes at the `[IMPLEMENTING]` -> `[COMPLETED]` transition, drawn from the summary artifact,
through `scripts/sapience-remember.sh`'s direct `POST /ingest-kos` call -- see
`## Write-Tool Disposition` below) bounds unreviewed content **per completed task**, not per tool
call. A
per-agent instruction to call `sapience_remember` proactively mid-run -- the shape this extension
deliberately does not add -- would instead produce an unreviewed write per decision, per agent,
potentially many times across a single `/orchestrate` batch, with no equivalent to the staged
review gate the rest of this machine's sapience workflow relies on.

## A Third Direct Write Path: `sapience-retrieve.sh`'s Sibling Script

`sapience-remember.sh` (`agent-system/extensions/sapience/scripts/`) posts straight to `POST
/ingest-kos`, the same endpoint the MCP write-tool path above uses -- so it bypasses the
`auto_approve: false` review gate exactly the same way: no staging, no review step, every write
permanent and unreviewed the instant the server returns `written >= 1`. It differs from the four
MCP tools only in *what* it writes (a repo-tagged KO, for the per-dispatch retrieval injection
`sapience-retrieve.sh` reads back) and in being called from task-boundary postflight rather than
mid-session. See `per-repo-scoping.md`'s "D3: Why Replace, Not Both" section for the full scoping
mechanism and the bound that keeps this path's unreviewed volume per completed task (a
3-8-note set) rather than per decision -- the same per-task bound this file's gap-2 instruction
already applies to the postflight call site (see `## Write-Tool Disposition` below).

## The Permission Grant's Repository-Scoped Tradeoff

`settings-fragment.json` grants all 11 `mcp__sapience__*` tools (the 4 write tools plus 7 read
tools) at this repository's own project scope (`.claude/settings.local.json`), not machine-wide.
Sapience's MCP registration now also reaches local (per-project) scope: the
`setup-sapience-mcp.sh` / `sapience-mcp-register-project.sh` triad (see
`per-repo-scoping.md`'s "The MCP-Registration Triad") writes
`.projects["<abs path>"].mcpServers.sapience` in `~/.claude.json` for exactly this project,
gated on the same extension-load state the grant above is gated on. The grant and the
per-project registration are therefore now SCOPE-MATCHED -- both project-scoped, both tied to
whether this extension is loaded -- rather than the earlier shape, where a project-scoped grant
served a server registered only at machine-wide user scope.

A top-level, machine-wide `~/.claude.json` `.mcpServers.sapience` entry still survives alongside
the per-project one, written by this machine's home-manager activation
(`modules/home/services/sapience.nix`'s `sapienceMcpServer` block). For AS LONG AS that entry
survives, the canonical rule for this codebase (see `context/patterns/mcp-server-ownership.md`)
would put a user-scope server's permission grant in user-scope `~/.claude/settings.json` -- but
that file is reset from `~/.dotfiles` by `home.activation.claudeSettings` on every home-manager
switch, so a direct edit there would be silently reverted. This is exactly the case
`mcp-server-ownership.md`'s "Carve-out: a nix-enforced user-scope settings file cannot receive a
new grant" subsection (under its `## Permission` section) sanctions: the project-scoped grant
here is not merely the only placement this extension can reach, it is the VERDICT the standard
reaches for a nix-enforced settings file, with this extension as the worked example the
subsection names by path. The consequence is real and should not be read as "the activation gap
is fully closed": a sapience session in any other project on this machine that has not loaded
this extension still hits an interactive permission prompt on all 11 tools, because that
project's own `.claude/settings.local.json` never receives this grant. Closing the gap
machine-wide would mean adding the same 11 entries to
`~/.dotfiles/config/claude/settings.json` -- a different repository, and the carve-out subsection
itself names this as the WRONG fix, not merely out of this extension's scope: it would enlarge
the blast radius for these mutating, unreviewed write tools from one opted-in repository to
every project on the machine.

**Coming staleness of `core`'s worked example.** `mcp-server-ownership.md`'s carve-out
subsection cites this extension by path as its worked example, and calls the 4-grant placement
a nix-enforced carve-out asserting a seven-tool read-only allow-list exists at USER scope. That
text still holds today -- the dotfiles-level seven-tool read allow-list and this fragment's own
11-grant project-scope copy coexist, so neither description is wrong yet. It becomes
*inaccurate*, not merely outdated, only once a separate task removes the user-scope read grants
from `~/.dotfiles/config/claude/settings.json`, at which point `core`'s text would describe a
surface absent from that file. Updating `core/context/patterns/mcp-server-ownership.md` is
outside this extension's own edit surface; the named escape valve is a follow-up task that
updates that worked example together with whichever change removes the dotfiles-level read
grants, so neither surface is left inconsistent.

## Explicit Grants, Not a Wildcard

The grant lists all 11 tool names explicitly (`mcp__sapience__sapience_remember`, `_wrapup`,
`_handoff`, `_adddoc`, `sapience`, `sapience_search`, `_briefing`, `_context`, `_ask`,
`_outstanding`, `_papers`) rather than a `mcp__sapience__*` wildcard. This matches the
dotfiles allow-list's own convention for the same seven read tools, which is also explicit, one
tool per line. The tradeoff: a future new sapience tool is not auto-granted by this fragment and
needs its own line added here -- a known maintenance item, not a surprise, given the precedent
it follows.

## Write-Tool Disposition

An affirmative disposition for each of the four MCP write tools, so that "ruled out" is a
recorded decision rather than silence:

| Tool | Disposition | Reason |
|------|-------------|--------|
| `sapience_remember` | Never named as a prescribed write path. | Its connector hardcodes `provenance` with no injectable repo marker (see `per-repo-scoping.md`'s "Why the MCP Write Tools Cannot Produce a Tagged Write"), so no argument to this tool can produce a tagged write. |
| `sapience_wrapup` | Replaced by the `sapience-remember.sh` script call site, not kept alongside it. | Keeping both would double permanent, unreviewed write volume for zero added reachability -- the tagged write already covers what an unfiltered read would find (`per-repo-scoping.md`'s "D3: Why Replace, Not Both"). |
| `sapience_handoff` | Ruled out, not converted. | No instruction surface in this extension calls it today. Adding a second session-closing write path would either duplicate the postflight note set under the same 3-8-note bound (a redundant write for no new coverage) or breach that bound (a second unreviewed write per completed task), and whichever note it carried would still land untagged. |
| `sapience_adddoc` | Out of scope. | It ingests a document, not a finding; this extension's write path is finding capture, not document ingestion. |

Naming a tool in this table is **discussion**, not prescription: the standing rule (see
`rules/sapience-write-path.md`) distinguishes naming a tool AS the write path a write SHOULD take
from documenting, as this table does, which tools exist and why each is not used.
