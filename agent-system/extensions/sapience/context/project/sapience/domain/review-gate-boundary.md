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
call is effectively a permanent, unreviewed write. This extension's gap-2 instruction (call
`sapience_wrapup` with 3-8 notes at the `[IMPLEMENTING]` -> `[COMPLETED]` transition, drawn from
the summary artifact) bounds unreviewed content **per completed task**, not per tool call. A
per-agent instruction to call `sapience_remember` proactively mid-run -- the shape this extension
deliberately does not add -- would instead produce an unreviewed write per decision, per agent,
potentially many times across a single `/orchestrate` batch, with no equivalent to the staged
review gate the rest of this machine's sapience workflow relies on.

## The Permission Grant's Repository-Scoped Tradeoff

`settings-fragment.json` grants the four write tools at this repository's own project scope
(`.claude/settings.local.json`), not machine-wide. Sapience is registered at user scope
(`~/.claude.json`), and the canonical rule for this codebase (see
`context/patterns/mcp-server-ownership.md`) would put a user-scope server's permission grant in
user-scope `~/.claude/settings.json` -- but that file is reset from `~/.dotfiles` by
`home.activation.claudeSettings` on every home-manager switch, so a direct edit there would be
silently reverted. The project-scoped grant in this extension is a deliberate tradeoff: it closes
the gap for autonomous dispatches inside this repository (this task's actual blocker) without
touching the enforced file. The consequence is real and should not be read as "gap 1 is fully
closed": a sapience session in any other project on this machine still hits an interactive
permission prompt on these four tools, because that project's own
`.claude/settings.local.json` never receives this grant. Closing the gap machine-wide would mean
adding the same four entries to `~/.dotfiles/config/claude/settings.json` -- a different
repository, and deliberately out of this extension's scope.

## Explicit Grants, Not a Wildcard

The grant lists the four tool names explicitly (`mcp__sapience__sapience_remember`, `_wrapup`,
`_handoff`, `_adddoc`) rather than a `mcp__sapience__*` wildcard. This matches the existing
seven-entry dotfiles allow-list's own convention, which is also explicit, one tool per line. The
tradeoff: a future new sapience write tool is not auto-granted by this fragment and needs its own
line added here -- a known maintenance item, not a surprise, given the precedent it follows.
