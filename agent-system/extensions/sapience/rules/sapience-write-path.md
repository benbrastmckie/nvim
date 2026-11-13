---
paths: ["agent-system/extensions/sapience/**", ".claude/context/project/sapience/**"]
---

# Sapience Write-Path Rule

## Path Pattern

Applies to: `agent-system/extensions/sapience/**` (the source store: `EXTENSION.md`, skills,
agents, context files, merge sources) and `.claude/context/project/sapience/**` (its deployed
context mirror).

## The Standing Contract

No instruction surface under either path above may name an MCP write tool (`sapience_remember`,
`sapience_wrapup`, `sapience_handoff`, `sapience_adddoc`) as the path a write SHOULD take. Every
prescribed write routes through `scripts/sapience-remember.sh`'s direct `POST /ingest-kos` call,
because that is the only call site that can produce a repo-tagged, per-repo-scopable write (see
`context/project/sapience/domain/per-repo-scoping.md`'s "Why the MCP Write Tools Cannot Produce a
Tagged Write"). Each converted or newly-prescribed call site carries an explicit note bound, so
total unreviewed write volume per completed task does not rise above the existing 3-8-note
postflight set -- a converted call site must inherit that bound, never add a second,
independently-sized one.

## Discussing a Tool vs. Prescribing It as a Write Path

This rule distinguishes naming a tool AS the write path a write SHOULD take from merely
documenting, for a reader's orientation, that the tool exists and why it is not used. The
second is discussion, and it is explicitly permitted. Sanctioned discussion sites, named by
path so a future check can treat them differently from a prescription:

- `context/project/sapience/domain/per-repo-scoping.md`'s mechanism section ("Why the MCP Write
  Tools Cannot Produce a Tagged Write") and its four-population Hazards census.
- `context/project/sapience/domain/review-gate-boundary.md`'s "Two Different Paths Into the
  Vault" inventory and its `## Write-Tool Disposition` table.

A check that flagged either site for naming all four tools would be wrong: both name the tools
to explain why each is not the write path, never to prescribe one of them as the write path.

## Verdict: Advisory, Not Mechanized

This rule is **advisory**, enforced by inspection (and by this file's own text, read before an
instruction surface under either path above is edited), not by a lint or a write-time hook. The
corpus this rule governs is small and largely static: 14 files under the source store path,
exactly three of which legitimately name the MCP write tools in the discussing sense above. The
only mechanized shape this codebase has evidence it trusts for this class of false positive --
distinguishing a legitimate discussion site from a prescription -- is marker suppression
(the pattern `scripts/lib/task-reference-patterns.sh` and `scripts/lib/record-version-patterns.sh`
both use), and building that machinery for a corpus this small and this static is
disproportionate to the risk it would close. This verdict is not an oversight; it is a
considered rejection of mechanization, recorded here so a future reader cannot mistake
"advisory" for "unconsidered."

**Promotion criterion**: this verdict is reconsidered, and a mechanized lint becomes
proportionate, if either of the following is measured: a recurrence of an untagged prescribed
write (an instruction surface under either path above naming an MCP write tool as the write path
a write SHOULD take, found after this rule's creation), or growth of the governed surface set
past what a single inspection pass can reliably cover.

## The Permission Grant Matches the Standing Contract

`settings-fragment.json` grants the seven read-shaped tools (`sapience`, `sapience_search`,
`sapience_briefing`, `sapience_context`, `sapience_ask`, `sapience_outstanding`,
`sapience_papers`) and none of the four MCP write tools (`sapience_remember`, `sapience_wrapup`,
`sapience_handoff`, `sapience_adddoc`) at this repository's project scope. A call to any of the
four now raises an interactive permission prompt in an interactive session and is denied outright
in a headless/autonomous run, rather than succeeding silently. Nothing legitimate is lost: the
prescribed write path (`scripts/sapience-remember.sh`'s `POST /ingest-kos` call) needs no MCP
grant at all, because it is a Bash script call, not an MCP tool invocation.

A repository that loaded sapience before this grant was narrowed keeps the already-merged
write-tool entries in its own `.claude/settings.local.json` until the additive-only merge engine
gains retraction, or the file is hand-edited; a fresh load or a fresh deploy gets the seven-tool
grant directly.
