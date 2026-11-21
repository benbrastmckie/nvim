# Research Report: Task #678

**Task**: 678 - Sapience linked-repo write and capture policy
**Started**: 2026-11-21T00:00:00Z
**Completed**: 2026-11-21T00:00:00Z
**Effort**: research, --hard
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/sapience/**` (source store), `.claude/rules/sapience-write-path.md` (deployed mirror)
- Cross-repository: `/home/benjamin/Projects/Sapience/sf1-engine/integration/project-link.md` (the governing contract this task is named in and must agree with)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `sf1-engine`'s `integration/project-link.md` section 10 already states the cross-harness write
  rule this task owes agreement with, and names this exact task by slug in its own
  cross-repository register as the obligation this report discharges. The rulings below adopt
  that document's rulings 1-7 **by citation**, the same pattern the document itself uses for the
  app's own Q39, rather than re-deriving a second, drifting copy.
- This extension already has every mechanical piece a linked-repo write needs, built by an
  earlier task group and currently gated to the interactive, human-confirmed `/sapience` command:
  `sapience-project-bind.sh` (creates/shares a project, writes `.sapience/project.json`),
  `sapience-vault-read.sh` (reads the binding plus vault state, including
  `GET /v1/people/projects/suggestions`), and `sapience-publish.sh ko` (writes a project-tagged
  KO via the plain, pre-verification `project` key field — `REPO_LINK_FOR`/`project_cid` is
  confirmed dark for this credential, per `command-draft-and-picker.md`'s "Dark Migration Path").
  None of this is reachable from an orchestrated/headless dispatch, because `AskUserQuestion` —
  Stage 9's mandatory single approval picker — is categorically withheld from any `Agent`-tool
  dispatch.
- The four blockers named in the task description (no MCP write-tool grant, the mid-run ban, the
  capture/activation decoupling, the orchestrated-transcript filter) are properties of the
  **MCP-write-tool and transcript-extraction paths**, not of the already-built script-based
  `/sapience` path, and the research below finds no reason any of the four should change based on
  link state alone. The one concrete, low-risk mechanism that DOES let an orchestrated run in a
  linked repo "produce project notes" is extending the existing postflight call site
  (`sapience-remember.sh`, invoked by `postflight-sapience-notes.sh`) to also send the plain
  `project` key field when `.sapience/project.json` resolves — reusing the exact runtime
  key-resolution code `sapience-publish.sh`'s `ko` subcommand already has, and never sending
  `project_cid` (an explicit non-goal `sapience-publish.sh` already states, extended here to the
  postflight path for the same reason).
- Five numbered rulings below answer the task description's five questions. None requires lifting
  the mid-run MCP-write-tool ban, none requires a new MCP grant, and none requires loosening the
  3-8-note-per-task postflight bound — the existing architecture already has the right shape;
  what is missing is (a) one small script extension and (b) explicit documentation of rulings
  that are currently either absent or only implicit in code.

## Context & Scope

Researched: how a Claude Code session in a repository carrying `.sapience/project.json` (a
"linked repo") should differ from today's unlinked behavior for (1) MCP write-tool grants and
their per-session bound, (2) the mid-run call ban, (3) capture opt-in, (4) the orchestrated/
subagent transcript filter, and (5) surfacing a non-creator member's gated suggestions — while
agreeing with `sf1-engine`'s `integration/project-link.md` so both harnesses (Claude Code and
SF-1) apply one policy.

Territory read in full: `agent-system/extensions/sapience/settings-fragment.json`,
`rules/sapience-write-path.md`, `EXTENSION.md` (the actual merge source for `.claude/CLAUDE.md` —
see Finding 0 below; the dispatch's `merge-sources/claudemd.md` path does not exist in this
extension), `manifest.json`, `context/project/sapience/domain/{review-gate-boundary,
transcript-filter-ceiling,per-repo-scoping,command-draft-and-picker,vault-model}.md`,
`scripts/{sapience-remember,sapience-publish,sapience-vault-read,sapience-project-bind,
postflight-sapience-notes}.sh`, `skills/skill-sapience/SKILL.md`. Cross-repository:
`/home/benjamin/Projects/Sapience/sf1-engine/integration/project-link.md` in full (the document
that names this task).

**Finding 0 — path naming mismatch in the dispatch.** The dispatch lists
`merge-sources/claudemd.md` as part of this task's territory. No such path exists in this
extension; the actual merge source for `.claude/CLAUDE.md` is `EXTENSION.md`
(`manifest.json`'s `merge_targets.claudemd.source: "EXTENSION.md"`). A future plan/implement
phase editing "the merge source" should target `EXTENSION.md`, not create a new file at the
dispatch's literal path.

## Findings

### Codebase Patterns

**The write-path rule is link-state-independent today, and should stay that way.**
`rules/sapience-write-path.md`'s standing contract ("No instruction surface... may name an MCP
write tool... as the path a write SHOULD take") and `settings-fragment.json`'s 7-read-tool grant
are not conditioned on any repo state — they are the same for every repository that loads this
extension. The reason given (`per-repo-scoping.md`'s "Why the MCP Write Tools Cannot Produce a
Tagged Write": the MCP connector hardcodes `provenance` with no injectable marker) is about the
MCP client's own code, not about project linkage, so it holds identically whether or not
`.sapience/project.json` exists.

**The already-built linked-repo write surface is categorically interactive-only.**
`skill-sapience/SKILL.md` states explicitly: "No `Agent` tool anywhere in this skill, by design...
`AskUserQuestion` is categorically withheld from every `Agent`-tool dispatch of a named
`subagent_type`, independent of frontmatter." Stage 9's single approval picker is mandatory and
every write (`sapience-publish.sh ko/doc-comment/doc-version/dm`) is gated behind it. This means
the entire built "linked-repo write" mechanism is already structurally confined to a plain
interactive session, never an orchestrated/headless one — a stronger and simpler guarantee than a
written policy, because the tool that would need to fire mid-run in an orchestrated dispatch does
not exist there at all.

**The project-tagging mechanism in use today is pre-verification, not the `project_cid` mechanism
`sf1-engine`'s contract governs.** `sapience-publish.sh`'s `ko` subcommand sends a plain
`project: "<key>"` field (resolved at runtime from `.sapience/project.json`'s `project` cid via
`GET /v1/people/projects`), and its own header comment states as a **non-goal**: "`project_cid`
is NEVER sent on any call... the `REPO_LINK_FOR` path is confirmed dark for this token."
`command-draft-and-picker.md`'s "Dark Migration Path" section independently confirms the same
measurement ("a probe carrying a bogus project identifier returned a normal answer with none of
the markers an enabled binding check would add"). `sf1-engine`'s `integration/project-link.md`
section 7 confirms `REPO_LINK_FOR` defaults to off and is `""` for every account on the deployed
release line. **Consequence**: today, a KO written via `project:` carries no server-side
origin/suggestion enforcement at all (that machinery — `project_cid_verify`, `origin`,
`project_room_contribute` — only fires on a verified `project_cid`). It is a private, project-
labeled KO in the writer's own store, not yet a shared-room contribution. This is a real,
load-bearing fact for the rulings below: writing the plain `project` field today is safe
precisely because it does not yet reach the sharing/suggestion machinery `sf1-engine`'s gate M4
and Q39 govern.

**`sapience-remember.sh` (the postflight call site) sends no project tag at all today.** Its
request body carries only `provenance` (the `[repo:<slug>]` tag), `subject`, `predicate`,
`object_value`, `ko_type`, `confidence`, `explicit: true`, and an optional `source_loc` —
confirmed by reading its `jq -n` body construction directly (`scripts/sapience-remember.sh:192-215`).
No `project` field, no `project_cid`. This is the concrete gap the "orchestrated run in a linked
repo produces project notes" half of the task's done-when criterion requires closing.

**`sapience-vault-read.sh` already reads `GET /v1/people/projects/suggestions` into
`vault.suggestions`, and `skill-sapience`'s Stage 3 already instructs folding it into the draft.**
("`vault.project_notes` and `vault.suggestions` — open threads and server-suggested next steps
worth surfacing in the draft," `skills/skill-sapience/SKILL.md:107-108`.) This is already the
mechanism Question 5 asks for; it is simply undocumented as a ruling.

**The capture/activation decoupling is an existing, deliberate design this extension does not
own the fix for.** `per-repo-scoping.md`'s "Capture/Activation Reconciliation" subsection states
plainly that no script in this source store reads or writes `~/.sapience/config.json`'s
`capture.projects[].enabled` list, and that building a reconciling writer here would create "the
two-writers-disagreeing hazard the Hazards census already warns about" — the opt-in list's owner
is `~/.dotfiles`, per `rules/source-store-deploy-boundary.md`'s task-siting rule.

### External Resources (sf1-engine's cross-repository contract)

`integration/project-link.md` section 10 ("Rulings, the app's read route, and the write rule and
sharing policy") states seven rulings this document adopts by citation:

1. Which note classes flow automatically (Q39: a typed decision reaches the project at once; an
   agent/template/dispatched-child note reaches it only as a suggestion; undeclared origin
   defaults to agent's).
2. Gate M4 restated for a linked repository: an autonomous task run creates no confirmed KO in
   its own store, sends no `project_cid`-tagged write whose origin resolves to anything other
   than `'typed'`, and causes no room row to render without the suggestion framing.
3. The per-session write bound for an automatic project write is the SAME existing bound as every
   other hosted write — no separate, larger budget for project-tagged writes.
4. Attribution: every automatic project write carries author and said-date through to injection.
5. The sharing policy (six filters generalized from `solo_sync.py`): pre-filtered before
   extraction; no document body/quote/name/link crosses repositories; no constraint/decision
   object created automatically; third-party content excluded; capped/sequential/fail-closed;
   off-by-default beyond the person's own typed decision.
6. Folder moves mid-conversation resolve the project link fresh per launch (conservative default:
   a session that moved folders writes to no project for the remainder of that session).
7. **Automatic project writes (any write attaching a verified `project_cid`) stay OFF** until two
   named leak paths close (a dispatched child's own subsequent turns reaching the lossless feed
   as if typed; and turns handed to a worker running with every hook/permission/instruction
   surface disabled) — explicitly because "an undeclared-is-agent's default is a classification
   default, not a leak-proofing mechanism by itself."

`integration/project-link.md`'s own cross-repository register names this task directly: "Owed by
it: the Claude Code arm's own statement of the same write rule and sharing policy, which must
agree with the ruling above." The rulings below are written to discharge that obligation.

## Recommendations

### Ruling 1 — MCP write-tool grant and per-session bound in a linked repo

**No change based on link state.** `settings-fragment.json` continues to grant only the 7
read-shaped tools, linked or unlinked — the reason the four MCP write tools are withheld
(`per-repo-scoping.md`'s connector-hardcoded-provenance argument) does not depend on project
linkage, and `sf1-engine` ruling 3 independently confirms the per-session bound for an automatic
project write is "the same... no separate, larger budget" — never a bigger or separately-shaped
budget for the linked case. The Claude Code analog of that bound is the existing 3-8-note
postflight set; a linked repo's project-tagged writes share that SAME bound (never a second,
independently-sized one), mirroring `rules/sapience-write-path.md`'s own existing text ("a
converted call site must inherit that bound, never add a second, independently-sized one").

**Concrete mechanism**: extend `sapience-remember.sh` with an optional project-tagging step —
when `.sapience/project.json` resolves at the repo toplevel, resolve its `project` cid to a `key`
via `GET /v1/people/projects` (the identical runtime resolution `sapience-publish.sh`'s `ko`
subcommand already implements) and add `project: "<key>"` to the KO body, exactly as that
subcommand does — and, per the non-goal it already states, **never** send `project_cid`. No new
MCP grant, no new script, no new budget: the same script, the same call site, the same 3-8-note
ceiling, one additional optional field.

**Check**: a dry-run of `sapience-remember.sh` from a repo with a `.sapience/project.json`
fixture prints a body containing `"project": "<key>"` and no `project_cid` key anywhere in the
payload; the same dry-run from a repo without the file prints a body with no `project` key at
all (unlinked behavior is byte-for-byte unchanged — mirroring `project-link.md` section 9's own
"the resulting request is byte-identical to today's call" bar for the unlinked case).

### Ruling 2 — the mid-run ban: not lifted, for either note kind

**The mid-run ban on calling an MCP write tool stays in force, linked or unlinked, for both the
person's own typed decisions and agent-authored findings.** The ban was never about note kind; it
is about the untagged, unbounded MCP-write-tool path (`per-repo-scoping.md`'s "Why the MCP Write
Tools Cannot Produce a Tagged Write"), which link state does not change. Separately, `sf1-engine`
ruling 7 forbids any write that would attach a verified `project_cid` from an autonomous task run
unless its origin is `'typed'`, and explicitly keeps that gate closed today because one of the
two leak surfaces it names — "turns handed to the Claude Code worker, which runs with every hook,
permission rule, and instruction file disabled" — is precisely what an orchestrated/headless
dispatch is. Ruling 1's mechanism never attaches `project_cid` at all, so it does not even reach
ruling 7's gate; it is a different, pre-verification write that was already safe to make before
this question was asked (Finding above).

The one surface that already satisfies `sf1-engine`'s "a decision the member typed reaches the
project at once" is `/sapience`'s existing Stage 9 approval picker: a human reviews the literal
payload and explicitly confirms it. This is not "the mid-run ban lifted" — it is a structurally
different, already-interactive-only mechanism that was never subject to the ban in the first
place (no MCP tool call, no autonomous dispatch). No new exception needs to be carved into the
ban for either note kind.

**Check**: grep the full `agent-system/extensions/sapience/` tree for any new instruction naming
`sapience_remember`/`sapience_wrapup`/`sapience_handoff`/`sapience_adddoc` as a write path (the
existing advisory inspection `rules/sapience-write-path.md` already calls for) — the count of
legitimate discussion-only occurrences should remain the same three sites that rule already
names, with no fourth added as a linked-repo carve-out.

### Ruling 3 — a link file does not imply capture opt-in; the capture-map entry's owner is unchanged

**No implication, and no new writer.** Extension activation and transcript-capture opt-in are
already deliberately decoupled (`per-repo-scoping.md`'s "Capture/Activation Reconciliation": "no
script in this extension reads or writes the `capture` key today," owner is `~/.dotfiles`). The
same reasoning extends cleanly to the link file: whether a repo's **confirmed, bounded, outward**
writes should be project-tagged (what `.sapience/project.json` governs) is an orthogonal question
from whether that repo's **passive, unbounded** interactive-transcript extraction should run at
all (what `capture.projects[].enabled` governs) — different stakeholders, different risk shapes.
Creating a project binding must not silently flip on a second, much larger exposure (every typed
word in that directory tree becoming extraction-eligible) as a side effect. The capture-map entry
continues to be written only by its existing owner (the user, via `~/.dotfiles` tooling) — never
by `sapience-project-bind.sh`, never by any hook, never implicitly from the presence of a link
file.

**Check**: `sapience-project-bind.sh` (the only writer of `.sapience/project.json`) is grepped for
any reference to `~/.sapience/config.json` or `capture.projects` — none should exist, now or
after any future edit, matching the zero-occurrence baseline already true today.

### Ruling 4 — orchestrated/subagent transcripts stay filtered; the postflight pass is not a substitute

**No change based on link state, and no change based on "the postflight pass already distils
them."** `source_skip()`'s `subagent`/`harness-started` classification is a fixed, non-overridable
gate (not even `SAPIENCE_INCLUDE_HEADLESS=1` reaches it — `transcript-filter-ceiling.md`), and
this is independent of whether a project binding exists. More importantly, the premise that the
postflight pass makes the filter redundant does not hold: postflight writes a bounded, curated
3-8-note set the completing agent itself selected as noteworthy — it is not the full raw
transcript, and admitting the full orchestrated transcript into extraction besides it would
reintroduce exactly the unbounded, unreviewed, un-curated volume the write-path rule's bound and
`per-repo-scoping.md`'s "few, high-value, well-formed notes... never a write per decision"
posture exist to prevent. It would also reopen `sf1-engine` ruling 7's still-open leak surfaces
(the dispatched-child and worker-turn cases), which this document's own ruling 2 above relies on
staying closed. The filter and the postflight pass are not redundant; they are two different
risk-bounded mechanisms for two different content shapes, and the existence of one is not grounds
to loosen the other.

**Check**: `~/.sapience/source_rules.json`'s cached classifications for a linked-repo session
remain `subagent`/`harness-started` exactly as for an unlinked one — a live census (as already
performed once at 1013/1295 filtered) repeated after linking a repo should show no change in the
filter's own verdicts for that repo's transcripts.

### Ruling 5 — surfacing a non-creator member's gated suggestions

**No new mechanism; document the existing one as a ruling.** This repository's own binding script
(`sapience-project-bind.sh`) always **creates** a fresh project rather than joining an existing
one, specifically because — per that script's own header comment — the creator/owner receives
`follow:true` and sees every member's notes flow without a per-note confirm, while a non-creator
member's own tagged note lands as a suggestion only that member sees (empty
`cross = doors & (sent | added | ...)` intersection). Because this repo's own binding is always
the owner side, this repo's own session does not face the suggestion-gating problem for notes
*it* reads back. The question becomes live only for the member-side half: a member (any account,
including this repo's own credential if it is ever added to someone else's project) reading back
its OWN pending suggestions. `GET /v1/people/projects/suggestions`, already wired into
`sapience-vault-read.sh`'s `vault.suggestions` field and already folded into `/sapience`'s Stage 3
draft-assembly instruction ("open threads and server-suggested next steps worth surfacing in the
draft"), already is that surfacing path — it fires on every interactive `/sapience` invocation in
a linked repo, with no new code needed. **Ruling**: this is the ruled path, made explicit rather
than left as an undocumented side effect of an unrelated design record; promoting a suggestion to
a confirmed note remains the member's own action inside the Sapience app (never performed
autonomously by an agent, matching the same non-autonomy precedent `sapience-project-bind.sh`'s
own header states for the outward-facing share call).

**Check**: a `/sapience` dry-run against a fixture `vault.suggestions` payload with at least one
entry produces a draft that names the pending suggestion in its summary text (never silently
omitted), confirming the existing Stage 3 instruction is actually exercised, not merely present
in prose.

## Decisions

- Adopt `sf1-engine`'s `integration/project-link.md` section 10 rulings 1-7 by citation as the
  governing cross-harness contract; do not re-derive a second, potentially drifting statement of
  the same policy in this repository's own docs. Where this repository's docs restate any part of
  it (EXTENSION.md, the domain files, `rules/sapience-write-path.md`), they should cite the
  source document and summarize, not paraphrase into a new independent claim.
- The write-path rule, the MCP write-tool grant, the mid-run ban, and the capture/activation
  decoupling are all **link-state-independent**: none of the four blockers named in the task
  description should be lifted or loosened specifically because a repo is linked.
- The one new mechanism this task's done-when criterion requires — an orchestrated run in a
  linked repo producing project notes — is satisfied by extending `sapience-remember.sh` to send
  the plain, pre-verification `project` key field (reusing `sapience-publish.sh`'s existing
  runtime resolution code) when `.sapience/project.json` resolves, while continuing to never send
  `project_cid` (an existing non-goal, extended to this call site for the same reason it already
  applies to `sapience-publish.sh ko`).
- `/sapience`'s existing `vault.suggestions` wiring is the ruled path for Question 5; it needs
  documentation, not new code.

## Risks & Mitigations

- **Risk**: a future `REPO_LINK_FOR` flag flip (server-side `project_cid` verification going
  live) could silently reach the postflight auto-write path once it starts sending `project_cid`
  instead of/alongside the plain `project` field, reopening `sf1-engine` ruling 7's gate for
  exactly the write this report just cleared. **Mitigation**: the non-goal ("never send
  `project_cid`") must be encoded as an explicit, checkable statement in `sapience-remember.sh`
  (mirroring `sapience-publish.sh`'s own header comment), not merely implied by the current
  absence of the field, so a future editor sees the constraint before adding one.
- **Risk**: the dispatch's territory names `merge-sources/claudemd.md`, which does not exist
  (Finding 0). A plan phase that creates this path instead of editing `EXTENSION.md` would create
  a dead file the merge engine never reads. **Mitigation**: state this explicitly in the plan so
  the edit target is `EXTENSION.md`.
- **Risk**: documenting Ruling 5 only in a domain file nobody reads before running `/sapience`
  leaves the existing `vault.suggestions` behavior effectively undiscoverable as a *ruling* (it
  already runs; what's missing is the reader's confidence that it is intentional, bounded
  behavior rather than an accident). **Mitigation**: add the ruling to
  `command-draft-and-picker.md` (which already documents the Stage 3/9 design) rather than only
  to this report.

## Context Extension Recommendations

- **Topic**: cross-repository contract agreement for a shared feature (the `sapience` extension
  and `sf1-engine`).
- **Gap**: no existing context file in this repository documents the pattern of "another
  repository's document names this repository's task by slug as an owed obligation" as something
  a research dispatch should actively check for (grep the named document's own cross-repository
  register) before writing its own ruling.
- **Recommendation**: a short addition to `context/patterns/context-discovery.md` or a new
  pointer noting that a task whose description names an external document (by path, as this
  task's description does with `sf1-engine`'s `integration/project-link.md`) should always read
  that document's own "obligations owed" framing in full before drafting independent rulings,
  since the external document may already contain the authoritative answer, as it did here.

## Appendix

### Search queries / commands used

- `cat /home/benjamin/.config/nvim/.claude-extensions.json` (resolve `source_dir` for the
  `sapience` extension, per `rules/source-store-deploy-boundary.md`)
- `find agent-system/extensions/sapience -type f` (full file inventory)
- `grep -rl "project.json\|project-link\|linked repo\|\.sapience/project"` across the extension
- `find / -iname "project-link.md"` (located `sf1-engine`'s governing document)
- Direct reads: `settings-fragment.json`, `rules/sapience-write-path.md`,
  `context/project/sapience/domain/{review-gate-boundary,transcript-filter-ceiling,
  per-repo-scoping,command-draft-and-picker,vault-model}.md`, `EXTENSION.md`, `manifest.json`,
  `scripts/{sapience-remember,sapience-publish,sapience-vault-read,sapience-project-bind,
  postflight-sapience-notes}.sh`, `skills/skill-sapience/SKILL.md`,
  `/home/benjamin/Projects/Sapience/sf1-engine/integration/project-link.md` (full file).

### References

- `agent-system/extensions/sapience/rules/sapience-write-path.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/transcript-filter-ceiling.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/command-draft-and-picker.md`
- `agent-system/extensions/sapience/scripts/sapience-remember.sh`
- `agent-system/extensions/sapience/scripts/sapience-publish.sh`
- `agent-system/extensions/sapience/scripts/postflight-sapience-notes.sh`
- `agent-system/extensions/sapience/skills/skill-sapience/SKILL.md`
- `/home/benjamin/Projects/Sapience/sf1-engine/integration/project-link.md` (sections 1-10,
  especially section 10's seven rulings and the Cross-repository register)
