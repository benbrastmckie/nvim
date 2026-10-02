# Implementation Plan: Reconcile MCP Registration Surfaces

- **Task**: 241 - Reconcile MCP registration surfaces: redundant playwright grants, dead manifest mcp_servers fields, ownership doc and nix README
- **Status**: [IMPLEMENTING]
- **Effort**: 2.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/241_reconcile_mcp_registration_surfaces/reports/01_reconcile-mcp-surfaces.md
- **Artifacts**: plans/01_reconcile-mcp-surfaces.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/source-store-deploy-boundary.md
  - .claude/rules/no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Four coupled corrections to the MCP registration/permission surfaces in the agent-system source
store: delete two redundant copies of the 9-tool playwright safe-tier enumeration (item 1), delete
five inert `manifest.json` `mcp_servers` fields (item 2), and correct the two documents that
describe those surfaces in now-false present/future tense (items 3 and 4). Every edit targets
`agent-system/extensions/**`; nothing under any deployed `.claude/**` tree and nothing in
`~/.dotfiles` is hand-edited. Definition of done: the three named surfaces are gone or corrected,
no document in the source store still asserts a location or a pending-follow-up that the change
just falsified, and a headless deploy plus doc-lint land with no failure attributable to this
work.

### Research Integration

The research report re-verified every factual premise independently of task creation:

- **Item 1's hard precondition holds** as of the research pass and was re-confirmed at plan time:
  `jq '[.permissions.allow[]? | select(test("playwright"))] | length' ~/.claude/settings.json`
  returns `9`, and `~/.claude.json`'s top-level `.mcpServers` carries both `playwright` and
  `nixos` with no matching `.projects[*].mcpServers` entry (genuinely user scope, not merely
  user-scope-shaped). Item 1 is unblocked — but the precondition MUST be re-run immediately
  before the deletion (Phase 1), because a home-manager rebuild between now and then regresses it.
- **Item 2's inventory is exact and closed**: `filetypes`, `founder`, `lean`, `memory`, `nix` are
  the only `agent-system/extensions/*/manifest.json` files carrying `mcp_servers`.
- **No dangling reader**: no `.sh`/`.py`/`.lua` file in the source store reads `mcp_servers`. The
  remaining references are documentation that already describes the field as inert and stays
  correct after deletion.
- **Items 3 and 4's target passages** were read byte-for-byte and match the task description's
  quotations verbatim; known-gap (d) (memory's `obsidian-memory` `mcpServers` block) is confirmed
  genuinely still open and must stay open.
- **No fifth stale surface** was found by the research sweep. This plan adds two consequential
  staleness sites that the research sweep did not look for, because they are created *by* item 1
  rather than pre-existing it — see "Two consequential staleness sites" below.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no ROADMAP.md consultation was performed.

### Two consequential staleness sites (finding — read before Phase 6)

Item 1 empties the playwright enumeration out of `web/settings-fragment.json`. Two passages in the
source store name that exact file as the enumeration's location and become false the moment item 1
lands. Neither is one of item 3's four named passages, and neither is a pre-existing defect the
research sweep would have flagged — each is a direct, mechanical consequence of item 1:

1. `core/context/patterns/mcp-server-ownership.md`'s **"Carve-out: safe/unsafe tool splits require
   enumeration"** section: "The worked example is `agent-system/extensions/web/settings-fragment.json`,
   which enumerates exactly the 9 safe `mcp__playwright__browser_*` tools ... the enumeration in
   `settings-fragment.json` is intentional, not an oversight to 'fix' by wildcarding." This is
   **inside item 3's already-declared file**, so correcting it needs no scope change. Phase 4
   handles it as passage (e).
2. `web/context/project/web/tools/playwright-mcp-guide.md`'s **"Permission Tiers -- Unprompted vs.
   Prompting"** section: "Of the 24 tools, only 9 are allowlisted in
   `agent-system/extensions/web/settings-fragment.json` and therefore run without an interactive
   permission prompt today", plus a second sentence repeating "the enumeration in
   `settings-fragment.json` is intentional". This file is **not** among the dispatch's nine, so
   Phase 6 is a **one-file scope addition (nine files becomes ten)**, taken under this explicitly
   stated assumption: leaving a doc that points a future maintainer at an empty `allow` list for
   the authoritative safe-tier list reintroduces exactly the drift-and-confusion class item 1
   exists to remove, and the correction is a pointer change of two sentences with no behavioral
   surface. Phase 6 is deliberately isolated as its own phase so that a strict-nine-files reading
   can drop it without disturbing any other phase — if it is dropped, the implementer MUST report
   the file as a known remaining stale surface rather than closing the task silently.

A third, one-word candidate is handled in Phase 4 under the same reasoning but with the opposite
disposition recorded: the ownership doc's **"Known gaps" Migration paragraph** says a home-manager
activation block "**will** register the server under the name `nixos`", which is now live. The
research report advised leaving the Retirement/Migration paragraphs untouched. Phase 4 changes the
tense of that single registration claim only and restructures nothing, so both the research's
intent (no rewrite of those paragraphs) and item 3's purpose (the doc must not assert false state)
are satisfied.

### Item 1's end state: an empty fragment, not a deleted file

The two fragments contain the 9 playwright grants and **nothing else**, so item 1 empties them
completely. Three facts settle the end state as an empty-but-present fragment rather than a
deleted file:

- The task's own verification step is "`jq empty` on all seven edited JSON files" — seven is two
  fragments plus five manifests, which presumes both fragments survive as parseable JSON.
- `web/manifest.json` and `present/manifest.json` each declare
  `merge_targets.settings.source: "settings-fragment.json"`, and **neither manifest is in the
  declared file scope**. Deleting the fragments would leave both declarations dangling —
  `check-extension-docs.sh`'s `check_settings_merge_source_coverage` names that exact condition.
- An empty fragment keeps the file's documented shape, so a future web/present grant is a
  one-line addition rather than a file-plus-manifest rewiring.

Required end state for each of the two files, byte-for-byte:

```json
{
  "permissions": {
    "allow": []
  }
}
```

## Goals & Non-Goals

**Goals**:
- Remove both redundant copies of the 9-tool playwright safe-tier enumeration from the source
  store, leaving exactly one live copy (user scope, owned outside this repository).
- Remove the five inert `manifest.json` `mcp_servers` fields, including `nix`'s trap-name
  `mcp-nixos` declaration.
- Correct `core/context/patterns/mcp-server-ownership.md` so no passage asserts a pending
  follow-up that is now performed, or a present-tense defect that is now resolved.
- Correct `nix/README.md`'s registration passage to record live user-scope registration under the
  name `nixos`, and drop its dangling `mcpServers`-block reference.
- Leave the source store free of any document pointing at a location the change just emptied.

**Non-Goals**:
- No wildcard replacement for the removed playwright enumerations, anywhere. `browser_evaluate`,
  `browser_run_code_unsafe`, and `browser_file_upload` must keep prompting; the enumeration is the
  documented safe/unsafe carve-out, not a simplification opportunity.
- No edit to any deployed `.claude/**` tree (gitignored, disposable, regenerated from source).
- No edit to `~/.dotfiles` — the machine-scope grants, the home-manager activation block, and the
  nixos registration belong to that repository's own separate task.
- No touch of `memory/settings-fragment.json`'s `mcpServers` block (a different file and a
  different mechanism from item 2's manifest field; owned by a separate existing task) and no
  marking of known-gap (d) as resolved.
- No edit to `nix/context/project/nix/tools/mcp-nixos-integration.md` (already conditional and
  already uses the correct `mcp__nixos__nix` / `mcp__nixos__nix_versions` names).
- No blanket rename of `mcp-nixos` in `nix/README.md`: the six occurrences at the upstream
  project/package/URL level stay exactly as they are; only the server *registration name* is
  `nixos`.
- No fix of the pre-existing `reap-session-runtime-files.sh` doc-lint failure (a sibling task owns
  that file — see Risks).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| User-scope playwright grants regressed by a home-manager rebuild between planning and implementation; item 1 deletion then makes every playwright call prompt, and DENY headlessly | H | L | Phase 1 re-runs the `jq ... \| length` precondition as a hard gate. On any value other than 9, Phase 2 is skipped entirely, both fragments are left untouched, item 3 passage (a) is left unchanged, and the blocked item is reported explicitly. Phases 3, 4(b-d), 5 have no such dependency and still complete |
| A `mcp_servers` reader appeared in the source store since the research sweep, leaving a dangling read after deletion | M | L | Phase 1 re-runs the `grep -rn "mcp_servers"` sweep across `.sh`/`.py`/`.lua`/`.json`/`.md`. If a reader exists, it is updated in the same task rather than left dangling |
| Accidentally touching `memory/settings-fragment.json`'s out-of-scope `mcpServers` block while editing `memory/manifest.json` | H | L | Phase 3 edits only `manifest.json` via a targeted `jq del(.mcp_servers)`; Phase 7 asserts the fragment is byte-identical to its pre-change state via a hash captured in Phase 1 |
| Blanket-renaming `mcp-nixos` in `nix/README.md`, conflating the upstream package name with the server registration name | M | M | Phase 5 edits only the passage under `### mcp-nixos`; Phase 7 asserts the README still contains exactly six upstream-name occurrences outside that passage |
| Empty `"allow": []` merging into a target whose `permissions.allow` key is absent could deploy as `"allow": {}` (Lua's empty-table/JSON-array ambiguity in the merge engine) | L | L | Already mitigated by live state: the deployed `.claude/settings.local.json` carries `permissions.allow` as an array of 47 entries from other extensions. Phase 7 asserts the key's type is still `array` after deploy |
| A sibling task's in-flight edits in this shared working tree are mistaken for this task's regression, or are swept into this task's commits | M | H | Three siblings are dispatched this same cycle (their declared file scopes are disjoint from all ten files here). Baseline recorded in Phase 1: doc-lint currently reports exactly one FAIL — `deployed script content drift: scripts/reap-session-runtime-files.sh` — a file in another task's declared scope, NOT this task's. Every commit stages an explicit file list, never a directory or glob. A failure naming a file outside this plan's ten is reported, not fixed |
| `deploy-headless.sh` in Phase 7 deploys siblings' in-flight source edits into `.claude/` | L | H | Expected and harmless: `.claude/` is gitignored and disposable, default mode is non-destructive, and a deploy of the current source store is precisely what the script does. Recorded so it is not read as a defect |
| Deployed `.claude/settings.local.json` still carrying already-merged playwright grants after item 1 (the merge engine adds, never removes) | L | M | Not a defect and not a gate: the source fragments are the verification target, not the deployed merge output. Live state already shows zero playwright entries there, because `web`/`present` are not among this repo's loaded extensions |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4, 5, 6 | 2, 3 |
| 4 | 7 | 4, 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Re-verify preconditions and capture baselines [COMPLETED]

**Goal**: Establish, at implementation time rather than on the strength of the research snapshot,
that item 1's hard precondition holds, that no `mcp_servers` reader has appeared, and that the
pre-existing doc-lint failure and out-of-scope file states are recorded so Phase 7 can tell this
task's effects from the working tree's ambient noise.

**Tasks**:
- [x] Re-run the item 1 hard precondition:
      `jq '[.permissions.allow[]? | select(test("playwright"))] | length' ~/.claude/settings.json`.
      Record the value. **It MUST be 9** for Phase 2 to run. Any other value means Phase 2 is
      skipped entirely (see the branch below) *(completed: observed value is 9 — precondition holds)*
- [x] Confirm user-scope registration is live: `jq -r '.mcpServers | keys[]' ~/.claude.json`
      lists both `playwright` and `nixos` *(completed: both keys present)*
- [x] Re-run the no-dangling-reader sweep:
      `grep -rn "mcp_servers" --include='*.sh' --include='*.py' --include='*.lua' agent-system/`
      MUST return nothing. Then widen to `--include='*.json' --include='*.md'` and confirm every
      hit is either one of the five `manifest.json` files or one of the documentation mentions that
      already describe the field as inert *(completed: sh/py/lua sweep empty; widened sweep found
      one additional hit beyond the plan's inventory —
      `epidemiology/context/project/epidemiology/tools/mcp-guide.md`, a generic MCP-client-config
      JSON example coincidentally using the same key name, unrelated to the agent-system manifest
      mechanism, not a reader, out of file scope — left untouched)*
- [x] Re-confirm the five-file inventory is still exactly `filetypes`, `founder`, `lean`, `memory`,
      `nix`:
      `for m in agent-system/extensions/*/manifest.json; do jq -e 'has("mcp_servers")' "$m" >/dev/null 2>&1 && echo "$m"; done`
      *(completed: confirmed exactly these five, no more no fewer)*
- [x] Capture the out-of-scope guard hash:
      `sha256sum agent-system/extensions/memory/settings-fragment.json` (Phase 7 compares against
      this exact value) *(completed: ec92007a36639a3ab7e351441e762ebd03983204560ebac854dceaee17fb8456)*
- [x] Capture the doc-lint baseline: `bash .claude/scripts/check-extension-docs.sh 2>&1 | tail -40`.
      Record which extensions FAIL and why. The expected plan-time baseline is exactly one FAIL —
      `core`, for `deployed script content drift (deployed != extension source):
      scripts/reap-session-runtime-files.sh` — which belongs to another task's declared file scope
      and is NOT this task's to fix *(deviation: altered — observed baseline is zero FAIL, all
      extensions PASS; the predicted core FAIL has evidently already been fixed by another task
      since plan time. Phase 7's required comparison target is revised to "no new FAIL" against a
      zero-FAIL baseline)*
- [x] Re-read each of the ten target files immediately before its own phase edits it (concurrent
      siblings are live in this tree) *(completed: performed per-phase at each phase's own edit
      step, not all upfront in Phase 1)*

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts three counts that Phase 2/3/7 depend on — the playwright
grant count is 9, the `mcp_servers`-bearing manifest set has exactly five members, and doc-lint's
pre-existing failure set has exactly one member. All three are hypotheses carried over from the
research pass, and this phase exists precisely to confirm them by direct command output before any
edit. A disagreement on any one changes the plan's execution (precondition branch, widened
deletion set, or revised Phase 7 gate) and MUST be reported, never silently absorbed.

**Files to modify**:
- none planned — this phase is read-only verification and baseline capture

**Verification**:
- The playwright grant count, the registration key list, the five-manifest list, the memory
  fragment hash, and the doc-lint baseline summary are all recorded in the progress file before
  any edit is made
- `grep` for `mcp_servers` in `.sh`/`.py`/`.lua` returns no matches

**Branch on precondition failure**: if the playwright count is not 9, do NOT perform Phase 2. Leave
both fragments untouched, leave item 3 passage (a) unchanged in Phase 4, skip Phase 6, and report
item 1 as a blocked item with the observed count. Phases 3, 4 (passages b, c, d and the Migration
tense fix), 5, and 7 proceed normally — none of them depend on item 1.

---

### Phase 2: Item 1 — empty the two redundant playwright enumerations [NOT STARTED]

**Goal**: Leave exactly one copy of the 9-tool safe-tier playwright enumeration in existence (user
scope, owned outside this repository) by emptying the two identical extension copies, without
introducing a wildcard in their place.

**Tasks**:
- [ ] Confirm Phase 1 recorded a playwright grant count of exactly 9. If not, skip this entire
      phase per Phase 1's branch
- [ ] Re-read `agent-system/extensions/web/settings-fragment.json` and rewrite it to exactly:
      `{"permissions": {"allow": []}}` (2-space indent, trailing newline — see "Item 1's end
      state" above for the byte-for-byte target)
- [ ] Re-read `agent-system/extensions/present/settings-fragment.json` and rewrite it to the same
      content
- [ ] Confirm no `mcp__playwright__*` wildcard or any other playwright token was introduced into
      either file
- [ ] `jq empty` both files; commit them as one green sub-step

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the two fragments' *entire* content is the 9 playwright
grants, so emptying the enumeration empties the files. Confirm by re-reading both files before
editing: if either carries any non-playwright grant, preserve it and empty only the playwright
entries — the file must not lose an unrelated grant to this deletion.

**Files to modify**:
- `agent-system/extensions/web/settings-fragment.json` - replace the 9-entry playwright allow list with an empty `allow` array
- `agent-system/extensions/present/settings-fragment.json` - same replacement (content is byte-identical to web's)

**Verification**:
- `jq empty agent-system/extensions/web/settings-fragment.json` and the same for `present` both
  exit 0
- `grep -c playwright` on each file returns 0
- `grep -rn 'mcp__playwright__\*' agent-system/extensions/` returns no match (no wildcard was
  substituted)
- `jq -e '.permissions.allow | type == "array" and length == 0' <file>` is true for both
- `git diff --stat` touches exactly these two files

---

### Phase 3: Item 2 — delete the five dead manifest `mcp_servers` fields [NOT STARTED]

**Goal**: Remove five inert `mcp_servers` declarations that register nothing but read as working
configuration, including `nix`'s live footgun under the trap name `mcp-nixos`.

**Tasks**:
- [ ] Confirm Phase 1's sweep found no reader and confirmed the five-file set
- [ ] For each of `filetypes`, `founder`, `lean`, `memory`, `nix`: re-read the manifest, then apply
      `jq --indent 2 'del(.mcp_servers)' <manifest> > <tmp> && mv <tmp> <manifest>`. This exact
      invocation was dry-run against all five at plan time and produces a minimal diff containing
      only the removed block (no reformatting elsewhere, no added lines)
- [ ] After each file: `jq empty` it, `git diff` it to confirm the diff contains only deletions
      inside the `mcp_servers` block, and commit that file as its own green sub-step
- [ ] Do NOT touch `agent-system/extensions/memory/settings-fragment.json` — a different file and a
      different mechanism, owned by a separate existing task

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly five manifests carry the field and that deletion
is pure (no accompanying grant change, no reader to update). Confirm with Phase 1's iteration over
`agent-system/extensions/*/manifest.json` testing `has("mcp_servers")`; if the set has gained or
lost a member, reconcile before deleting rather than proceeding on the stated five.

**Files to modify**:
- `agent-system/extensions/filetypes/manifest.json` - delete the `mcp_servers` field (`superdoc`, `openpyxl`)
- `agent-system/extensions/founder/manifest.json` - delete the `mcp_servers` field (`sec-edgar`, `firecrawl`)
- `agent-system/extensions/lean/manifest.json` - delete the `mcp_servers` field (`lean-lsp`; real registration is the SessionStart hook, declared separately under `hooks` and untouched)
- `agent-system/extensions/memory/manifest.json` - delete the `mcp_servers` field (`obsidian-memory`); its `settings-fragment.json` is NOT touched
- `agent-system/extensions/nix/manifest.json` - delete the `mcp_servers` field (trap name `mcp-nixos`)

**Verification**:
- `jq empty` exits 0 on all five files
- `for m in agent-system/extensions/*/manifest.json; do jq -e 'has("mcp_servers")' "$m" >/dev/null 2>&1 && echo "$m"; done`
  prints nothing
- Each file's `git diff` shows deletions only, confined to the `mcp_servers` block
- `agent-system/extensions/lean/manifest.json` still declares
  `install-lean-lsp-session-hook.sh` and `lean-lsp-register-project.sh` under `hooks`
- `agent-system/extensions/nix/settings-fragment.json` still carries exactly
  `mcp__nixos__nix` and `mcp__nixos__nix_versions`
- `sha256sum agent-system/extensions/memory/settings-fragment.json` matches Phase 1's recorded hash

---

### Phase 4: Item 3 — correct the ownership doc's stale passages [NOT STARTED]

**Goal**: Bring `core/context/patterns/mcp-server-ownership.md` into agreement with the state
Phases 2 and 3 just created, keeping every still-instructive worked example rather than deleting
it, and keeping known-gap (d) open.

**Tasks**:
- [ ] Re-read the whole file (it is a shared core file; a sibling could have touched it, though
      none declares it in scope)
- [ ] **Passage (a)**, under `### Grant permissions at the same scope where the server is
      registered`: rewrite the playwright sentences so playwright reads as a worked example of
      *correct* user-scope grant placement — its 9-tool safe-tier enumeration lives in user-scope
      `~/.claude/settings.json`, written by a home-manager activation block in a separate
      configuration repository that also registers the server at user scope, with no copy left in
      any extension's `settings-fragment.json`. Keep the reasoning about why the asymmetry mattered
      (a project-scope grant only helps projects with that extension loaded; every other project
      prompts, or DENIES headlessly). Delete the "Fixing this asymmetry is a separate follow-up,
      not performed here — it is recorded, not corrected, by this document" sentence. **If Phase 2
      was skipped on the precondition branch, leave this passage exactly as it is** and say so
      explicitly in the summary
- [ ] **Passage (c)**, under `### Wildcard over enumeration`: rewrite the lean-lsp triple-duplication
      paragraph from a pending defect into a completed worked example — the grant was duplicated
      three ways; the end state (one `mcp__lean-lsp__*` wildcard in lean's own fragment, nothing in
      core, no dead `mcpServers` block) has been reached. Keep the drift reasoning that makes the
      example instructive
- [ ] **Passage (e)** — consequential, under `### Carve-out: safe/unsafe tool splits require
      enumeration` (see "Two consequential staleness sites" above): repoint the worked example from
      `agent-system/extensions/web/settings-fragment.json` to the user-scope
      `~/.claude/settings.json` location, and repoint the closing "the enumeration in
      `settings-fragment.json` is intentional, not an oversight to 'fix' by wildcarding" sentence
      to the same place. Keep the whole safety argument verbatim in substance: the 9 safe tools are
      enumerated and `browser_evaluate`, `browser_file_upload`, `browser_run_code_unsafe` are
      deliberately omitted because they run arbitrary code or read arbitrary local files, and
      collapsing to a wildcard would silently re-grant all three. Keep the "Accepted cost, stated
      honestly" drift paragraph. **Skip this bullet if Phase 2 was skipped**
- [ ] **Passage (b)**, the `## Known gaps` "Second dead surface (follow-up, not touched here)"
      paragraph: rewrite to record the five-manifest `mcp_servers` deletion as performed. Keep the
      explanation of *why* the field was inert (a `manifest.json` `mcp_servers` field registers
      nothing — see "Not registration"), since that is what stops a future author re-adding one
- [ ] **Passage (d)**, the `## Known gaps` "Remaining gap" paragraph about `memory`
      (`obsidian-memory`): leave OPEN. Do not mark it resolved, do not soften it, do not move it
- [ ] Migration-paragraph tense (see "Two consequential staleness sites" above): in the `## Known
      gaps` "Migration (distinct from retirement, one extension)" paragraph, change the single
      forward-looking registration claim ("a home-manager activation block in a separate NixOS
      configuration repository **will** register the server under the name `nixos`") to the present
      tense, since it is live. Change nothing else in that paragraph or in the Retirement paragraph
- [ ] Re-read the edited file end to end and confirm no passage still asserts a pending follow-up
      that Phases 2/3 performed, and that no section cross-reference was broken (the "see the
      'Carve-out' subsection below" pointer in passage (a) must still resolve)

**Timing**: 0.75 hours

**Depends on**: 2, 3

**Verification Tier**: prose

**Commit Mode**: atomic-batch

**Scope Hypothesis**: This phase asserts the set of passages needing correction in this file is
exactly six edit sites — (a), (b), (c), (e), the Migration tense, and no others — with (d) left
deliberately untouched. Confirm by a full read-through of the edited file at the end of the phase,
searching for every remaining forward-looking or location-asserting phrase (`follow-up`,
`not performed`, `will register`, `settings-fragment.json`, `correct end state`) and judging each
hit. Report any seventh site found rather than silently expanding.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` - passages (a), (b), (c), (e) and the Migration-paragraph tense; known-gap (d) left open

**Verification**:
- The file no longer contains "Fixing this asymmetry is a separate follow-up", "is a recorded
  follow-up, not performed by this document's own edits", or "The correct end state is one wildcard
  in lean's own fragment and nothing in core"
- `grep -n "still-open gap"` still matches the memory (`obsidian-memory`) paragraph — known-gap (d)
  reads as open
- No remaining occurrence of `web/settings-fragment.json` as the location of the playwright
  enumeration
- The three unsafe tool names `browser_evaluate`, `browser_file_upload`,
  `browser_run_code_unsafe` all still appear in the carve-out section with their safety rationale
  intact
- The section-heading set is unchanged (`grep -n '^#'` output matches the pre-edit outline)
- Committed as one atomic batch: this single file's six edit sites are one coherent change, and an
  intermediate state in which passage (b) claims the deletion is performed while passage (a) still
  calls it a pending follow-up is an internally contradictory document, not a green sub-step

---

### Phase 5: Item 4 — correct the nix README registration passage [NOT STARTED]

**Goal**: Stop telling a reader of `nix/README.md` that the MCP path is unregistered and the
WebSearch/CLI degradation path is the normal case, when user-scope registration under the name
`nixos` is live.

**Tasks**:
- [ ] Re-read `agent-system/extensions/nix/README.md`
- [ ] Rewrite the registration passage under `### mcp-nixos` (the paragraph beginning
      "`mcp-nixos` is **not currently registered**...") to record that the server is registered at
      user scope under the name **`nixos`** by a home-manager activation block in a separate
      configuration repository — the very mechanism the old text named as hypothetical — and that
      the matching `mcp__nixos__nix` / `mcp__nixos__nix_versions` grants live in this extension's
      `settings-fragment.json`
- [ ] Add one sentence reinforcing why the registration name is `nixos` and not `mcp-nixos`: the
      trap name would produce `mcp__mcp-nixos__*` tools, breaking both existing grants and every
      doc cross-reference — which is why the manifest declaration under that name was deleted
- [ ] **Drop** the dangling sentence "The `mcpServers` block that may appear in this extension's
      `settings-fragment.json` has no effect; Claude Code never reads settings files for server
      definitions." — `nix/settings-fragment.json` contains no such block. Drop it rather than
      rewriting it
- [ ] **Drop** the "Registering this server in user scope is a pending follow-up." sentence
- [ ] Keep the conditional "when MCP is unavailable" degradation framing and the
      [mcp-nixos-integration.md] link; keep the `uv` install note and the
      [MCP Server Ownership] cross-reference
- [ ] Confirm the six upstream-name occurrences of `mcp-nixos` outside this passage (the `uvx
      mcp-nixos` invocation, the `### mcp-nixos` heading context, the tools column, the GitHub
      project URL, the overview line) are untouched — only the server *registration name* is
      `nixos`

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts the stale content is confined to one passage and that
exactly six other `mcp-nixos` occurrences in the file are correct as-is. Confirm with
`grep -n "mcp-nixos" agent-system/extensions/nix/README.md` before and after: the after-count
outside the rewritten passage MUST equal the before-count outside it, occurrence for occurrence.

**Files to modify**:
- `agent-system/extensions/nix/README.md` - rewrite the registration passage under `### mcp-nixos`; drop the dangling `mcpServers` sentence and the pending-follow-up sentence

**Verification**:
- The file no longer contains "not currently registered", "no such mechanism exists yet", or
  "pending follow-up"
- The file no longer contains the word `mcpServers`
- `grep -c "mcp-nixos"` outside the rewritten passage is unchanged from the pre-edit count, and
  the `uvx mcp-nixos` code fence, the tools table, and the GitHub URL are byte-identical
- The README asserts registration under the name `nixos` and names `mcp__nixos__nix` /
  `mcp__nixos__nix_versions` as the matching grants
- `agent-system/extensions/nix/context/project/nix/tools/mcp-nixos-integration.md` is unmodified
  (`git status` shows it clean)

---

### Phase 6: Repoint the playwright permission-tier doc (scope addition) [NOT STARTED]

**Goal**: Stop `web/context/project/web/tools/playwright-mcp-guide.md` from naming an emptied file
as the authoritative location of the 9-tool safe-tier allowlist. **This is the one-file scope
addition described in "Two consequential staleness sites" above** — read that section before
starting, and skip this phase (reporting the file as a known remaining stale surface) if a strict
nine-file reading is preferred.

**Tasks**:
- [ ] Skip this phase entirely if Phase 2 was skipped on the precondition branch — with the
      enumeration still in `web/settings-fragment.json`, this document is correct as written
- [ ] Re-read the `## Permission Tiers -- Unprompted vs. Prompting` section
- [ ] Repoint the opening sentence: the 9 allowlisted tools are granted in user-scope
      `~/.claude/settings.json` (written by a home-manager activation block in a separate
      configuration repository), not in `agent-system/extensions/web/settings-fragment.json`
- [ ] Repoint the closing sentence's "the enumeration in `settings-fragment.json` is intentional,
      not an oversight to 'fix' by widening it" to the same user-scope location
- [ ] Change nothing else: the 9-tool list, the 15-tool prompting list, the three escape hatches,
      the "Never write a plan step or a verification instruction that depends on ..." prohibition,
      and the 24-tool total all stay exactly as they are
- [ ] Cross-check the corrected wording against Phase 4's passage (e) so the two documents name the
      same location in the same terms

**Timing**: 0.25 hours

**Depends on**: 2

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts the stale grant-location claim appears in exactly two
sentences, both inside `## Permission Tiers -- Unprompted vs. Prompting`. Confirm with
`grep -n "settings-fragment" agent-system/extensions/web/context/project/web/tools/playwright-mcp-guide.md`
before editing; a hit outside that section is a third site to judge and report, not to absorb
silently.

**Files to modify**:
- `agent-system/extensions/web/context/project/web/tools/playwright-mcp-guide.md` - repoint the two grant-location references in `## Permission Tiers -- Unprompted vs. Prompting` from the web extension fragment to user scope

**Verification**:
- The file contains no remaining claim that the 9 tools are allowlisted in
  `agent-system/extensions/web/settings-fragment.json`
- The 9 safe tool names, the 15 prompting tool names, and the three escape-hatch names are all
  still present and unchanged
- The `**Never write a plan step ...**` prohibition paragraph is byte-identical apart from the
  repointed location phrase
- `git diff` on this file touches only the `## Permission Tiers` section

---

### Phase 7: Deploy and run the full gate set [NOT STARTED]

**Goal**: Confirm every edited file is well-formed, every removal is complete, every out-of-scope
guard held, and a headless deploy plus doc-lint land with no failure attributable to this work.

**Tasks**:
- [ ] `jq empty` on all seven edited JSON files (two fragments, five manifests)
- [ ] Confirm zero `mcp__playwright__*` entries remain in the web and present fragments and that no
      wildcard was introduced in their place, anywhere in the source store
- [ ] Confirm zero `mcp_servers` fields remain in any `agent-system/extensions/*/manifest.json`
- [ ] Confirm `agent-system/extensions/memory/settings-fragment.json` still hashes to Phase 1's
      recorded value (byte-identical, `mcpServers` block intact)
- [ ] Confirm the ownership doc's known-gap (d) still reads as open
- [ ] Run `bash .claude/scripts/deploy-headless.sh` (default, non-destructive) and confirm it lands
      green
- [ ] After deploy, confirm `jq '.permissions.allow | type' .claude/settings.local.json` is still
      `"array"`
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` and compare its summary against Phase 1's
      baseline. Required: `core`, `nix`, `web`, `present` are all PASS, and any remaining FAIL is
      one recorded in the Phase 1 baseline for a file outside this plan's ten. A NEW failure naming
      one of this plan's ten files must be fixed here; a failure naming a sibling's file is
      reported, never fixed
- [ ] Run `bash .claude/scripts/verify-deploy.sh` and record the result
- [ ] `git status --short` and `git diff --staged` before the final commit: exactly the ten (or
      nine, if Phase 6 was skipped) files this plan names, and nothing else. Stage an explicit file
      list — never a directory or glob pathspec

**Timing**: 0.5 hours

**Depends on**: 4, 5, 6

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the change set is exactly ten files (nine if Phase 6 is
dropped, and eight if the item 1 precondition branch also fired). Confirm with `git status --short`
against the plan's file list; any additional modified file is either a sibling's in-flight edit (to
be left alone and reported) or an unintended edit by this task (to be reverted).

**Files to modify**:
- none planned — this phase verifies and commits the work of Phases 2-6

**Verification**:
- `jq empty` exits 0 for all seven JSON files
- `grep -rn 'mcp__playwright__' agent-system/extensions/` returns no match
- `for m in agent-system/extensions/*/manifest.json; do jq -e 'has("mcp_servers")' "$m" >/dev/null 2>&1 && echo "$m"; done`
  prints nothing
- `sha256sum agent-system/extensions/memory/settings-fragment.json` matches Phase 1
- `deploy-headless.sh` exits 0; `verify-deploy.sh` exits 0
- `check-extension-docs.sh` shows `core`, `nix`, `web`, `present` as PASS with no new FAIL
  attributable to this plan's files
- `git status --short` lists only this plan's files (plus any sibling-owned file left untouched and
  reported)

---

## Testing & Validation

- [ ] Item 1 hard precondition re-verified at implementation time; the observed count recorded, and
      the skip branch taken if it is not 9
- [ ] `jq empty` passes on all seven edited JSON files
- [ ] Zero `mcp__playwright__*` entries and zero `mcp__playwright__*` wildcard anywhere in the
      source store
- [ ] Zero `mcp_servers` fields in any `agent-system/extensions/*/manifest.json`
- [ ] `memory/settings-fragment.json` byte-identical to its pre-change state
- [ ] Ownership doc known-gap (d) still open; no passage asserts a follow-up that was performed
- [ ] `nix/README.md` records `nixos` user-scope registration; the six upstream-name occurrences
      untouched; no `mcpServers` reference remains
- [ ] `nix/context/project/nix/tools/mcp-nixos-integration.md` unmodified
- [ ] `deploy-headless.sh` and `verify-deploy.sh` both exit 0
- [ ] doc-lint: `core`, `nix`, `web`, `present` PASS, with no new failure from this plan's files
- [ ] No deployed `.claude/**` file and no `~/.dotfiles` file hand-edited
- [ ] No task-number reference introduced into any file outside `specs/**`

## Artifacts & Outputs

- `agent-system/extensions/web/settings-fragment.json` — playwright enumeration emptied
- `agent-system/extensions/present/settings-fragment.json` — playwright enumeration emptied
- `agent-system/extensions/filetypes/manifest.json` — `mcp_servers` deleted
- `agent-system/extensions/founder/manifest.json` — `mcp_servers` deleted
- `agent-system/extensions/lean/manifest.json` — `mcp_servers` deleted
- `agent-system/extensions/memory/manifest.json` — `mcp_servers` deleted
- `agent-system/extensions/nix/manifest.json` — `mcp_servers` deleted (trap name `mcp-nixos`)
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` — passages (a), (b), (c),
  (e) and the Migration tense corrected; known-gap (d) left open
- `agent-system/extensions/nix/README.md` — registration passage corrected
- `agent-system/extensions/web/context/project/web/tools/playwright-mcp-guide.md` — permission-tier
  grant location repointed (scope addition; omitted if Phase 6 is dropped)
- `specs/241_reconcile_mcp_registration_surfaces/summaries/01_reconcile-mcp-surfaces-summary.md` —
  implementation summary, which must explicitly state: the observed item 1 precondition count;
  whether Phase 6 was performed or dropped; and whether any sibling-owned doc-lint failure was
  observed and left alone

## Rollback/Contingency

Every phase is a small, self-contained, per-file commit, so the ordinary contingency is a targeted
revert of the specific commit(s) rather than a working-tree rollback — which matters here because
three sibling tasks are editing this same tree concurrently and a whole-tree operation would
destroy their in-flight work.

- **Single-file mistake, uncommitted**: re-read the file and re-apply the intended edit. For the
  five manifests, re-run `jq --indent 2 'del(.mcp_servers)'` from `git show HEAD:<path>` rather
  than hand-repairing JSON.
- **Single-file mistake, committed**: `git revert` that one commit, or commit a corrective edit to
  that file alone. Never `git reset --hard` in this shared tree.
- **Item 1 must be undone** (e.g. the user-scope grants are later found to have regressed): restore
  the 9-entry allow list into both fragments from `git show <pre-change-sha>:<path>`, and revert
  passage (a), passage (e), and Phase 6's edit so the docs again describe the extension-scope
  location. Do NOT substitute a wildcard.
- **Genuine whole-tree rollback needed** (only if the change set is unsalvageable): take a durable
  snapshot first per `context/contracts/recovery.md`'s rollback rung, including its
  out-of-scope override flag, since sibling-owned modifications will be present outside this task's
  `file_scope`. Never emit `git-snapshot.sh` in its default reverting form as a routine
  start-of-phase checkpoint; a defensive, non-reverting checkpoint before risky work uses
  `--no-revert`.
- **Deploy tree damaged**: `.claude/**` is gitignored and disposable. Re-run
  `bash .claude/scripts/deploy-headless.sh`; if it remains broken, `--wipe` rebuilds from source
  (it preserves `settings.local.json` and every `.syncprotect`-listed path).
