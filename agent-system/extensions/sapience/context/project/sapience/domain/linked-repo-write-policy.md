# Linked-Repo Write and Capture Policy

Five rulings on how a repo carrying `.sapience/project.json` differs from one that does not,
across the write-tool grant, the mid-run ban, capture opt-in, transcript filtering, and a
non-creator member's gated suggestions. Four of the five are "no change based on link state";
the fifth documents an existing, unchanged mechanism as a ruling rather than leaving it an
undocumented side effect. These rulings agree, by citation, with the write rule and sharing
policy `sf1-engine`'s `integration/project-link.md` section 10 states for SF-1's own harness;
see "Cross-Harness Agreement" below for how a plain, pre-verification `project` key field and
SF-1's verified `project_cid` path can both be true at once without conflict.

## Ruling 1: The write-tool grant and its per-session bound are link-state-independent

`settings-fragment.json` grants only the seven read-shaped tools, linked or unlinked. The reason
the four MCP write tools (`sapience_remember`, `sapience_wrapup`, `sapience_handoff`,
`sapience_adddoc`) are withheld — the connector hardcodes `provenance` with no injectable repo
marker, so no argument can produce a tagged write (`per-repo-scoping.md`'s "Why the MCP Write
Tools Cannot Produce a Tagged Write") — does not depend on project linkage. A linked repo's
project-tagged writes share the SAME existing 3-8-note postflight bound
(`per-repo-scoping.md`'s "The Tagged-Write Call Site"), never a second, independently-sized one —
mirroring `sf1-engine` ruling 3, which holds the per-session write bound to the same number
"no separate, larger budget for project-tagged writes," and `rules/sapience-write-path.md`'s own
existing text that a converted call site inherits the bound rather than adding a second one.

The one mechanism this ruling adds: `scripts/sapience-remember.sh` resolves
`.sapience/project.json`'s `project` cid to a `key` via `GET /v1/people/projects` (the same
runtime resolution `sapience-publish.sh`'s `ko` subcommand already implements) and adds a plain
`project: "<key>"` field to the KO body — never `project_cid`. No new MCP grant, no new script,
no new budget: one additional optional field on the same call, through the same script, under
the same ceiling.

**Check**: `settings-fragment.json`'s `permissions.allow[]` holds exactly the seven
`mcp__sapience__*` read grants and none of the four write tools — a regression assertion, not a
diff, since this ruling changes nothing about the fragment.

## Ruling 2: The mid-run ban is not lifted, for either note kind

The ban on calling an MCP write tool mid-run stays in force, linked or unlinked, for both the
person's own typed decisions and agent-authored findings. It was never about note kind; it is
about the untagged, unbounded MCP-write-tool path itself (`per-repo-scoping.md`'s "Why the MCP
Write Tools Cannot Produce a Tagged Write"), which link state does not change. Separately,
`sf1-engine` ruling 7 forbids any write attaching a verified `project_cid` from an autonomous task
run unless its origin is `'typed'`, and keeps that gate closed today because one of its two named
leak surfaces — a turn handed to a worker running with every hook, permission rule, and
instruction file disabled — is exactly what a headless/orchestrated dispatch is. Ruling 1's
mechanism never attaches `project_cid` at all, so it does not reach ruling 7's gate; it is a
different, pre-verification write that was already safe before this question was asked.

The one surface that already satisfies "a decision the member typed reaches the project at once"
is `/sapience`'s Stage 9 approval picker: a human reviews the literal payload and explicitly
confirms it. This is not the ban lifted — it is a structurally different, already-interactive-only
mechanism (no MCP tool call, no autonomous dispatch; `AskUserQuestion` is withheld from every
`Agent`-tool dispatch) that was never subject to the ban in the first place. No exception is
carved into the ban for either note kind.

**Check**: grepping the extension tree for a new instruction naming an MCP write tool as a write
path finds the same sanctioned-discussion-only sites `rules/sapience-write-path.md` already
names (see that rule's corrected count), with no fourth site added as a linked-repo carve-out.

## Ruling 3: A link file implies no capture opt-in; the capture-map entry's writer is unchanged

Extension activation and transcript-capture opt-in are already deliberately decoupled —
`per-repo-scoping.md`'s "Capture/Activation Reconciliation" states that no script in this
extension reads or writes the `capture` key, whose owner is `~/.dotfiles`. The same reasoning
extends to the link file: whether a repo's confirmed, bounded, outward writes should be
project-tagged (what `.sapience/project.json` governs) is orthogonal to whether that repo's
passive, unbounded interactive-transcript extraction should run at all (what
`capture.projects[].enabled` governs). Creating a project binding must not silently flip on a
second, much larger exposure as a side effect. The capture-map entry continues to be written only
by its existing owner — never by `sapience-project-bind.sh`, never by any hook, never implicitly
from the link file's presence.

**Check**: `sapience-project-bind.sh`, the only writer of `.sapience/project.json`, is grepped for
any reference to `~/.sapience/config.json` or `capture.projects` — zero occurrences, matching the
zero-occurrence baseline true today.

## Ruling 4: Orchestrated and subagent transcripts stay filtered

No change based on link state, and no change based on the postflight pass's existence.
`source_skip()`'s `subagent`/`harness-started` classification is a fixed, non-overridable gate —
not even `SAPIENCE_INCLUDE_HEADLESS=1` reaches it (`transcript-filter-ceiling.md`) — independent
of whether a project binding exists. The premise that the postflight pass makes the filter
redundant does not hold: postflight writes a bounded, curated 3-8-note set the completing agent
itself selected as noteworthy, not the full raw transcript. Admitting the full orchestrated
transcript into extraction alongside it would reintroduce exactly the unbounded, unreviewed,
un-curated volume the write-path bound and `per-repo-scoping.md`'s few-high-value-notes posture
exist to prevent, and would reopen the two leak surfaces `sf1-engine` ruling 7 keeps closed (the
dispatched-child and worker-turn cases) that Ruling 2 above relies on staying closed. The filter
and the postflight pass are two different risk-bounded mechanisms for two different content
shapes; one existing is not grounds to loosen the other.

**Check**: a linked repo's session transcripts classify `subagent`/`harness-started` in
`~/.sapience/source_rules.json` exactly as an unlinked repo's do — linking changes no verdict.

## Ruling 5: A non-creator member's gated suggestions surface through the existing `/sapience` draft

No new mechanism; this documents an existing one as a ruling. `sapience-project-bind.sh` always
creates a fresh project rather than joining an existing one, because the creator/owner receives
`follow:true` and sees every member's notes flow without a per-note confirm, while a non-creator
member's own tagged note lands as a suggestion only that member sees (an empty
`cross = doors & (sent | added | ...)` intersection). Because this repo's own binding is always
the owner side, the question is live only for the member-side half: a member reading back its own
pending suggestions. `GET /v1/people/projects/suggestions` — already wired into
`sapience-vault-read.sh`'s `vault.suggestions` field and already folded into `/sapience`'s Stage
3 draft-assembly instruction — already is that surfacing path, firing on every interactive
`/sapience` invocation in a linked repo with no new code needed. Promoting a suggestion to a
confirmed note remains the member's own action inside the Sapience app, never performed
autonomously by an agent.

**Check**: a `/sapience` dry-run against a fixture `vault.suggestions` payload with at least one
entry produces a draft naming the pending suggestion in its summary text, never silently omitted.

## Cross-Harness Agreement

`sf1-engine`'s `integration/project-link.md` section 10 ("Rulings, the app's read route, and the
write rule and sharing policy") is the governing cross-harness contract for this feature across
both the SF-1 and Claude Code arms. That document's own cross-repository register names this
record's task directly as an obligation owed back: a statement of the same write rule and sharing
policy from the Claude Code side, agreeing with its ruling. The five rulings above discharge that
obligation by citation rather than by a second, independently-derived statement of the same
policy: none loosens anything section 10 forbids, and the one new mechanism Ruling 1 adds (a
plain `project` key field, never `project_cid`) sits entirely below section 10's own gate, which
governs only a write attaching a *verified* `project_cid`. A future flip of `REPO_LINK_FOR` that
makes a verified `project_cid` reachable from this call site would reopen section 10's ruling 7
gate for it; until then, the two harnesses' write rules agree because the Claude Code side's
mechanism has not yet reached the boundary section 10 polices.
