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

## Link State Does Not Change the Write Path

A repo carrying `.sapience/project.json` gets no different write-tool grant and no lifted
mid-run ban: `context/project/sapience/domain/linked-repo-write-policy.md`'s Ruling 1 and
Ruling 2 hold identically for a linked and an unlinked repo.

- **Ruling 1** (grant is link-state-independent): `settings-fragment.json` grants the same seven
  read-shaped tools regardless of linkage, because the reason the four MCP write tools are
  withheld — the connector hardcodes `provenance` with no injectable repo marker, so no argument
  can produce a tagged write — does not depend on project linkage. The one mechanism a link adds
  is `scripts/sapience-remember.sh` resolving the link file's `project` cid to a `key` and adding
  a plain `project: "<key>"` field to the KO body, never `project_cid` — no new MCP grant, no new
  script, no new budget.
- **Ruling 2** (mid-run ban holds for both note kinds): the ban on calling an MCP write tool
  mid-run stays in force, linked or unlinked, for both the person's own typed decisions and
  agent-authored findings — it was never about note kind, it is about the untagged, unbounded
  MCP-write-tool path itself, which link state does not change. A linked repo's project-tagged
  writes inherit the existing 3-8-note postflight bound and never add a second,
  independently-sized one.

See `context/project/sapience/domain/linked-repo-write-policy.md` for the full five-ruling
record and its rationale, and `sf1-engine`'s `integration/project-link.md` section 10 for the
cross-harness contract both harnesses' write rules agree with.

## Discussing a Tool vs. Prescribing It as a Write Path

This rule distinguishes naming a tool AS the write path a write SHOULD take from merely
documenting, for a reader's orientation, that the tool exists and why it is not used. The
second is discussion, and it is explicitly permitted. Sanctioned discussion sites, named by
path so a future check can treat them differently from a prescription:

- `context/project/sapience/domain/per-repo-scoping.md`'s mechanism section ("Why the MCP Write
  Tools Cannot Produce a Tagged Write") and its four-population Hazards census.
- `context/project/sapience/domain/review-gate-boundary.md`'s "Two Different Paths Into the
  Vault" inventory and its `## Write-Tool Disposition` table.
- `context/project/sapience/domain/linked-repo-write-policy.md`'s Ruling 1 and Ruling 2
  discussion above and its own "Cross-Harness Agreement" section.
- `EXTENSION.md`'s write-tool prohibition and vendor-SessionStart-nudge-supersession prose.
- `index-entries.json`'s `keywords` array entry for this rule file's own index record, which
  lists all four tool names for discoverability, not as a write-path prescription.
- This rule file's own `## The Permission Grant Matches the Standing Contract` section below,
  which names all four tools to state the grant that withholds them.

A check that flagged any of these sites for naming all four tools would be wrong: each names the
tools to explain why each is not the write path, never to prescribe one of them as the write
path.

## Verdict: Advisory, Not Mechanized

This rule is **advisory**, enforced by inspection (and by this file's own text, read before an
instruction surface under either path above is edited), not by a lint or a write-time hook. The
corpus this rule governs is small and largely static: 14 instruction-surface files (the `.md`
files under the source store path) are the governed set, of which 5 presently name one of the
four MCP write tools at all (`EXTENSION.md`, this rule file, `review-gate-boundary.md`,
`linked-repo-write-policy.md`, `per-repo-scoping.md`) -- and the six sanctioned-discussion sites
named above cover every one of those 5, plus `index-entries.json` (not itself one of the 14
`.md` files, but named above because its `keywords` array also surfaces all four tool names).
Re-run `grep -rln 'sapience_remember\|sapience_wrapup\|sapience_handoff\|sapience_adddoc'` over
the 14-file `.md` set to reconfirm this count rather than trusting it stale. The
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

`deep_merge` itself remains additive-only by design (load-bearing for `manager.unload`'s own
tracked-removal path, which a merge's own tracking record depends on). Retraction is a separate
step: `manager.load`'s forced-reload branch now unmerges an extension's own prior tracked record
before re-merging its current fragment, and sweeps any `mcp__<server>__`-prefixed grant left
behind by a fragment that has since narrowed. Both a forced reload of an already-loaded
repository and a fresh load/deploy converge on the seven-tool grant.
