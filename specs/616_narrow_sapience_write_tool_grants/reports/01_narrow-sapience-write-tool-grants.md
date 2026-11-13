# Research Report: Task #616

**Task**: 616 - Narrow sapience write tool grants
**Started**: 2026-11-13T00:00:00Z
**Completed**: 2026-11-13T00:00:00Z
**Effort**: small (2-4 file edits, no code logic, no tests)
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/sapience/settings-fragment.json`
- `agent-system/extensions/sapience/rules/sapience-write-path.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md`
- `agent-system/extensions/sapience/EXTENSION.md`, `README.md`, `index-entries.json`
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`
- `agent-system/extensions/core/docs/guides/permission-configuration.md`
- `agent-system/extensions/core/docs/architecture/extension-system.md` (merge-additivity evidence)
- `.claude/settings.local.json` (live deployed grant state, this repository)
- Repo-wide grep for other carve-out worked examples (`nix-enforced`, `sapience_wrapup`, etc.)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The grant to narrow is `agent-system/extensions/sapience/settings-fragment.json`'s
  `permissions.allow`, which currently lists 11 `mcp__sapience__*` entries: 4 write tools
  (`sapience_remember`, `sapience_wrapup`, `sapience_handoff`, `sapience_adddoc`) plus 7 read
  tools, plus one inert entry (see Findings).
- **Recommended shape: (i), full removal of all four write-tool grants**, leaving exactly the
  seven read-tool entries. None of the four is ever the prescribed write path, and the only
  legitimate use the dispatch poses as a cost — an interactively-requested ad hoc save — is
  already better served by `scripts/sapience-remember.sh` via Bash (tagged, noise-gate-safe),
  which needs no MCP grant at all.
- This is the sole worked example of `mcp-server-ownership.md`'s "nix-enforced user-scope
  settings file" carve-out anywhere in the repository; removing the grant means no server in
  the repository currently exercises that carve-out, so the worked-example paragraph needs
  replacement, not just a number update.
- Consistency requires touching more files than the two the dispatch names explicitly
  (`settings-fragment.json` and `mcp-server-ownership.md`'s worked example): `review-gate-boundary.md`,
  `EXTENSION.md`, and `README.md` all state the current "11 tools / 4 write tools" grant as fact
  and go stale the same way the named two would if left alone.
- A separately-recorded, already-known merge-additivity defect means this source-level narrowing
  will not retroactively strip the 4 write-tool lines from THIS repository's own already-deployed
  `.claude/settings.local.json` (confirmed still present, 11 entries) — a redeploy carries the
  narrowed set into fresh deploys and fresh repos, but this repository's own live grant needs a
  separate hand-edit or the merge-retraction defect fixed to actually lose the 4 entries now.

## Context & Scope

This is the phase=research dispatch for task 616, the named escape valve recorded in
`rules/sapience-write-path.md`'s "Accepted Residual" section. The task's own SCOPE section asks
for four things: (1) decide what the grant set becomes, with reasons; (2) apply the narrowing to
the fragment; (3) update `core/context/patterns/mcp-server-ownership.md`'s worked example in the
same change; (4) update the Accepted Residual section to record the landed disposition. This
report performs (1) as a documented decision and recommends the concrete edits for (2)-(4) (plus
adjacent consistency edits this research surfaced) for the plan/implement phases to apply —
research does not itself edit extension source files.

Scope boundaries respected: this report does not touch `.claude/` (the deployed mirror) directly,
per `source-store-deploy-boundary.md`; all recommended edits target the source store under
`agent-system/extensions/**`. It does not expand into the separately-named, separately-scoped
"dotfiles-level read grant removal" trigger that `review-gate-boundary.md`'s own "Coming
staleness of core's worked example" paragraph already anticipates — that trigger is a different,
still-open future task and is unaffected by this one.

## Findings

### The current grant set (settings-fragment.json)

11 entries in `permissions.allow`, in this order: `sapience_remember`, `sapience_wrapup`,
`sapience_handoff`, `sapience_adddoc` (the 4 write tools), `sapience` (bare tool-name form, no
underscore-suffixed anything), `sapience_search`, `sapience_briefing`, `sapience_context`,
`sapience_ask`, `sapience_outstanding`, `sapience_papers` (7 read-shaped tools).

**The `mcp__sapience__sapience` entry matches no real tool.** The live MCP server exposes
`sapience_adddoc`, `_ask`, `_briefing`, `_connect`, `_context`, `_handoff`, `_join`,
`_outstanding`, `_papers`, `_remember`, `_search`, `_wrapup` — 12 tools total, none named bare
`sapience`. This entry is inert cruft, distinct from the "bare `mcp__{server}`" case
`mcp-server-ownership.md` warns grants nothing (this is `mcp__sapience__sapience`, a
well-formed but non-matching tool-suffix grant). Also notable: `sapience_connect` and
`sapience_join` are not granted at all today. Both observations are **out of this task's scope**
(scope item 1 names exactly the four write tools) and are recorded here as a finding for a
possible future cleanup task, not acted on.

### No instruction surface prescribes any of the four write tools as a write path

`rules/sapience-write-path.md`'s standing contract and `review-gate-boundary.md`'s
`## Write-Tool Disposition` table both independently confirm this for all four tools:
- `sapience_remember` — never prescribed; its connector cannot produce a tagged write
  (`per-repo-scoping.md`'s "Why the MCP Write Tools Cannot Produce a Tagged Write").
- `sapience_wrapup` — replaced by the `sapience-remember.sh` script call site at postflight, not
  kept alongside it.
- `sapience_handoff` — ruled out; no instruction surface calls it.
- `sapience_adddoc` — out of scope; ingests documents, not findings.

The one prescribed write path, `scripts/sapience-remember.sh`'s direct `POST /ingest-kos` call,
is invoked via Bash and needs **no MCP permission grant of any kind** — confirmed by the script's
own existence as a deployed `.claude/scripts/` shell script, not an MCP tool call.

### The grant is the sole worked example of its carve-out in the repository

A repo-wide grep for `nix-enforced` / `carve-out` text shows exactly three files mention the
specific "nix-enforced user-scope settings file cannot receive a new grant" carve-out:
`mcp-server-ownership.md` (defines it), `permission-configuration.md` (cross-references it), and
`review-gate-boundary.md` (sapience's own disclosure, required by the carve-out's own
third requirement). No other extension's `settings-fragment.json` or context file invokes this
carve-out. Removing the write-tool grant therefore leaves **no current instance** of a server
using this carve-out to widen a withheld tier at project scope anywhere in the repository — the
worked-example paragraph cannot simply have its numbers updated, because the scenario it
describes (sapience exercising the carve-out for 4 write tools) will no longer be true.

### Consistency surface is wider than the two files the dispatch names

The dispatch names `settings-fragment.json` (apply) and `mcp-server-ownership.md`'s worked
example (update) explicitly, plus the Accepted Residual section. Grepping for the same
"11 tools" / "4 write tools" fact inside `agent-system/extensions/sapience/**` (fully in this
task's own edit surface, unlike `core/`) turns up three more files stating it as current fact,
not discussion:

- `review-gate-boundary.md`: "## The Permission Grant's Repository-Scoped Tradeoff" section
  states the fragment "grants all 11 `mcp__sapience__*` tools (the 4 write tools plus 7 read
  tools)"; "## Explicit Grants, Not a Wildcard" lists all 11 tool names explicitly as what the
  grant lists.
- `EXTENSION.md` (the file merged into `.claude/CLAUDE.md`'s "Sapience Extension" section,
  visible every session): "`settings-fragment.json` carries 11 permission grants (7 read tools +
  4 write tools)".
- `README.md`: two separate sentences state "all 11 `mcp__sapience__*` tools (7 read + 4 write)"
  and "11 `mcp__sapience__*` tools (the 7 read tools plus the 4 write tools)".

Leaving any of these three stating "11"/"4 write tools" after the fragment is narrowed to 7
entries reproduces exactly the inconsistency-between-surfaces problem the dispatch's own coupling
rationale (narrowing the grant without updating `mcp-server-ownership.md` would leave it stale)
was written to prevent — just inside `sapience/**` rather than crossing into `core/`.

`permission-configuration.md` (core) only cross-references "the sapience-extension worked
example" by pointer, asserting no fact about tool counts itself; it will stay correct as long as
`mcp-server-ownership.md`'s own worked-example paragraph is replaced with something that still
exists at that location (see Recommendations) rather than deleted outright, which would leave the
pointer dangling.

### The merge-retraction gap means this repo's own live grant will not shrink automatically

`.claude/settings.local.json` in this repository currently lists the same 11 entries, merged in
from an earlier (unnarrowed) deploy of the fragment. `extension-system.md` documents the merge
engine as **additive-only by design**: "neither ever deletes a deployed file or a merged
`context/index.json`" entry — the same additive discipline applies to `settings-fragment.json`
merges into `settings.local.json`. A source-level narrowing therefore does not retroactively
strip the 4 write-tool lines already merged into this repository's `settings.local.json` (or any
other repository's, if sapience was already loaded there before this change lands); it only
changes what a **fresh** load/deploy produces going forward. The dispatch's own "ORDERING NOTE"
names this directly and says the task should state the interaction rather than imply the
narrowing takes effect everywhere on its own — this finding confirms that interaction is real and
currently live in this very repository's deployed settings.

## Decisions

1. **Grant shape selected: (i) — remove all four write-tool grants, keep the seven read-tool
   grants, explicit enumeration (no wildcard), unchanged ordering of the remaining seven.** The
   candidate shapes from the dispatch, weighed:
   - **(i) remove all four** — selected. Cost: a user who explicitly asks, mid-session, to
     invoke `sapience_remember`/`_wrapup`/`_handoff`/`_adddoc` by name now hits a one-time
     interactive permission prompt before the call fires, rather than the call succeeding
     immediately and silently. Benefit: closes the residual completely — a stray, non-explicit,
     proactive call (the actual danger the rule exists to guard against, actively encouraged by
     the harness's own session-start nudge text) is now DENIED outright in a headless/autonomous
     run (no one to answer the prompt) and requires explicit human sign-off in an interactive
     one, instead of succeeding silently either way. No legitimate use is lost: the postflight
     write path already needs no MCP grant (it is a script), and an ad hoc, human-requested save
     can use the same script via Bash, producing a STRICTLY BETTER result (tagged, per-repo-
     scopable, `explicit: true` so it cannot be silently noise-gated) than the MCP tool would.
   - **(ii) keep `sapience_remember` only** — rejected. `sapience_remember` is precisely the tool
     the harness's own nudge text names by name ("save it with sapience_remember — don't wait to
     be asked"), so keeping it grantable without a prompt keeps the single most actively-pushed
     attack surface for the stray-proactive-call failure mode open, for a benefit (frictionless
     ad hoc saves) the script-via-Bash path already provides in a strictly better shape. Keeping
     it "for a user who explicitly asks" does not actually require a standing grant: the
     interactive prompt this decision accepts under shape (i) already lets an explicit ask
     through with one click; a standing grant only removes that one click, at the cost of also
     removing it for the stray unprompted case this task exists to close.
   - **(iii) keep the grants, close the gap some other way** — rejected as infeasible today, not
     merely undesirable. The only two closures evaluated by prior research in this extension's
     own domain files are (a) make the write tools themselves produce a tagged write — ruled out
     mechanically: `remember_provenance()` in `~/.sapience/mcp.py` hardcodes `provenance` with no
     injectable repo marker (`per-repo-scoping.md`) — and (b) intercept the call with a hook
     before it fires — ruled out: the sapience domain's own Hazards census states plainly that
     "nothing in this repository sits between the client and the tool-call result" for any
     `mcp__sapience__*` call. With neither closure available, narrowing the grant is the only
     remaining lever, which is exactly why this task exists as the named escape valve rather than
     a documentation-only fix.

2. **Edit target for the grant**: `agent-system/extensions/sapience/settings-fragment.json`'s
   `permissions.allow` array. Delete the four entries `mcp__sapience__sapience_remember`,
   `mcp__sapience__sapience_wrapup`, `mcp__sapience__sapience_handoff`,
   `mcp__sapience__sapience_adddoc`. Leave the remaining seven entries (including the inert
   `mcp__sapience__sapience` entry — out of scope per Findings) untouched and in their current
   relative order.

3. **`core/context/patterns/mcp-server-ownership.md`'s carve-out worked example must be replaced,
   not merely re-numbered.** Because sapience no longer exercises the carve-out for any tool
   after this change (Findings), the paragraph describing "the sapience extension's ...
   settings-fragment.json grants four write tools ... at this repository's own project scope ...
   deliberately withholding these four mutating/unreviewed tools from [user scope]" states a
   configuration that will no longer exist. The replacement text should state, as current fact,
   that no MCP server grant in this repository presently exercises this carve-out, while keeping
   the three governing requirements intact as general, forward-looking guidance for a future
   extension that does need it (see Recommendations for exact wording). This keeps
   `permission-configuration.md`'s existing cross-reference to "the sapience-extension worked
   example" from dangling, by leaving a located passage at that anchor rather than deleting it.

4. **`rules/sapience-write-path.md`'s "Accepted Residual" section is retitled and rewritten to
   record a landed disposition**, per `no-record-versioning-in-deliverables.md`: state the
   current grant set and the current consequence (no live grant on any of the four write tools;
   a call to any of them now prompts/denies rather than succeeding silently), not a narration of
   what the grant "used to be."

5. **Three additional in-scope files need the same factual update, beyond the two the dispatch
   names explicitly**, because they are inside `agent-system/extensions/sapience/**` (this task's
   own edit surface) and currently state the stale "11 tools / 4 write tools" fact as fact, not
   discussion: `review-gate-boundary.md` (two sections), `EXTENSION.md` (one line, which is also
   what renders into `.claude/CLAUDE.md`'s "Sapience Extension" section every session), and
   `README.md` (two sentences). Leaving these three stale while fixing only the two named files
   reproduces the exact cross-surface inconsistency this task exists to close, just at a smaller
   radius. This report recommends including them in the plan's edit set (see Recommendations);
   it does not expand this task's scope beyond write-tool-grant consistency — all three edits are
   restatements of the same single fact (the tool-count/grant-set), not new design decisions.

6. **The merge-retraction gap is a stated, accepted limitation, not a blocker.** Per the
   dispatch's own ORDERING NOTE and this report's Findings: this task's narrowing takes effect at
   the source-store level and in any fresh extension load/deploy, but does not retroactively
   strip the four write-tool lines already merged into THIS repository's own
   `.claude/settings.local.json` (confirmed still present today). Closing that residually requires
   either the separately-tracked merge-retraction defect being fixed, or a direct hand-edit of
   this repository's own `settings.local.json` — outside this task's scope, and the plan/implement
   phase should say so explicitly in its own acceptance text rather than imply full closure.

## Recommendations

1. **`settings-fragment.json`** — remove the four write-tool lines from `permissions.allow`,
   keeping the seven-entry remainder unchanged. No other structural change (hooks block, order of
   remaining entries) is needed.

2. **`core/context/patterns/mcp-server-ownership.md`** — replace the "Worked example" paragraph
   under "Carve-out: a nix-enforced user-scope settings file cannot receive a new grant" (the
   paragraph currently beginning "the sapience extension's
   `agent-system/extensions/sapience/settings-fragment.json` grants four write tools...") with
   text stating plainly that no MCP server grant in this repository currently exercises this
   carve-out, while keeping the three numbered governing requirements above it as still-valid
   general guidance for a future extension. This keeps the anchor `permission-configuration.md`
   points to intact (a located passage, not a deleted one) while making the claim true.

3. **`rules/sapience-write-path.md`** — retitle "## Accepted Residual: The Four-Tool Permission
   Grant Stays Intact" (a heading naming the now-closed residual) to describe the current,
   landed state (e.g. a heading naming that the grant now matches the standing rule, with body
   text stating the current seven-tool-only grant and the current consequence of calling any of
   the four write tools — a permission prompt/denial, not a silent success — rather than
   narrating what the prior grant used to permit). Remove the "named escape valve" sentence
   pointing at a follow-up task, since that follow-up is this task.

4. **`review-gate-boundary.md`, `EXTENSION.md`, `README.md`** — update the three
   "11 tools"/"4 write tools" factual statements found in Findings to state the current
   seven-read-tool-only grant, in the same change, so a reader of any one sapience-domain file is
   not misled by another. This is the same single fact restated three times, not three separate
   decisions.

5. **Do not touch** `per-repo-scoping.md`'s four-population census or `review-gate-boundary.md`'s
   `## Write-Tool Disposition` table — both already describe the tools in the permitted
   "discussion, not prescription" sense (`sapience-write-path.md`'s own carved-out exception), and
   neither asserts a tool-count fact that becomes false after this change.
   `per-repo-scoping.md`'s one-sentence note that "[the untagged, MCP-write-tool] population stays
   untagged going forward only if a stray proactive call bypasses the rule" becomes, if anything,
   a more accurate description once the grant is narrowed (a stray call is now gated), not a
   stale one — leave it as is.

6. **Do not expand this task into the `mcp__sapience__sapience` inert-entry or
   `sapience_connect`/`sapience_join` ungranted-tool findings** (Findings, above) — both are
   genuine but orthogonal to the write-tool-grant narrowing this task is scoped to; record them
   for a possible separate future task rather than folding them into this change's diff.

7. **State the merge-retraction limitation explicitly in whatever artifact closes this task**
   (plan acceptance criteria or implementation summary): the narrowed grant reaches fresh
   loads/deploys and fresh test repositories immediately, but this repository's own
   `.claude/settings.local.json` keeps the four write-tool entries until the merge-retraction
   defect is fixed or the file is hand-edited — do not claim full closure without that caveat.

## Risks & Mitigations

- **Risk**: deleting the sapience worked example from `mcp-server-ownership.md` outright (rather
  than replacing it with a "currently unexercised" statement) would leave
  `permission-configuration.md`'s cross-reference ("see ... for the sapience-extension worked
  example") pointing at nothing. **Mitigation**: replace in place rather than delete (Recommendation
  2); verify the cross-reference's surrounding sentence in `permission-configuration.md` still
  reads correctly after the replacement (it does not itself assert a tool count, only a pointer,
  so no edit to that file should be needed — but the implement phase should re-read it once
  `mcp-server-ownership.md`'s text lands, not assume).
- **Risk**: narrowing in the source store without redeploying leaves `specs/TODO.md`/postflight
  believing the change is "live" when this repository's own merged `settings.local.json` still
  grants the four tools. **Mitigation**: Decision 6 / Recommendation 7 — state the limitation
  explicitly rather than let a future reader assume full closure from this task's completion
  alone.
- **Risk**: a reviewer narrowly reads the dispatch's two explicitly-named files
  (`settings-fragment.json`, `mcp-server-ownership.md`) and considers the task done, missing the
  three additional in-scope sapience-domain files (Findings/Decision 5) that state the same now-
  stale fact. **Mitigation**: this report calls them out by name and section so the plan phase can
  size the edit set correctly from the start rather than discover them in a second pass.
- **Risk (not applicable to this task, recorded for completeness)**: the OTHER staleness trigger
  `review-gate-boundary.md` already names for `core`'s worked example — becoming inaccurate once
  a *separate* task removes the dotfiles-level read grants — is unrelated to and unaffected by
  this narrowing. Do not conflate the two triggers when writing the replacement worked-example
  text; the replacement should describe the write-tool-grant state this task produces, not
  pre-empt the still-open read-grant question.

## Context Extension Recommendations

- **Topic**: inert/incomplete MCP tool-name entries in a `permissions.allow` list.
- **Gap**: `mcp-server-ownership.md`'s "Grant form" subsection documents that a *bare*
  `mcp__{server}` grants nothing, but has no equivalent note for a well-formed-but-non-matching
  suffix (`mcp__sapience__sapience`, which matches no tool the live server exposes) or for a
  server's tool surface outgrowing an explicit enumeration silently (sapience exposes
  `sapience_connect`/`sapience_join`, neither currently granted). Both are instances of the same
  general "enumeration drift" risk the document's "Wildcard over enumeration" section already
  names in the abstract, but the document has no worked example of *detecting* drift after the
  fact, only of preferring a wildcard to prevent it going forward.
- **Recommendation**: a future, separately-scoped task could add a short "detecting drift" note
  (or a small verification script, mirroring `verify-sapience-mcp.sh`'s existing checks) that
  diffs a server's live tool list against its `settings-fragment.json` enumeration and flags
  non-matching or missing entries — not part of this task's own scope, which is limited to the
  four write tools.

## Appendix

- Grant count and content verified by direct read of
  `agent-system/extensions/sapience/settings-fragment.json` and
  `.claude/settings.local.json` (lines 55-65) in this repository, 2026-11-13.
- Live MCP tool surface (12 `mcp__sapience__*` tools) cross-checked against the deferred-tool
  listing surfaced in this session's own system reminder.
- Carve-out uniqueness confirmed via `grep -rln "nix-enforced" agent-system/` (3 files: the
  defining doc, the cross-referencing guide, and sapience's own disclosure — no fourth file).
- Merge-additivity evidence: `agent-system/extensions/core/docs/architecture/extension-system.md`
  line 728, "additive-only by design: neither ever deletes a deployed file or a merged
  `context/index.json`".
- No separate task or record documents the "grant-retraction defect" by that name elsewhere in
  the repository (grep returned no hits beyond this task's own dispatch text); it is described
  here, and should be described in the implementation artifact, directly from the live
  merge-additivity behavior rather than a citation to a filed defect record.
