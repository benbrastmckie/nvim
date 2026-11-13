# Implementation Plan: Task #616

- **Task**: 616 - Narrow sapience write tool grants
- **Status**: [COMPLETED]
- **Effort**: 3.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/616_narrow_sapience_write_tool_grants/reports/01_narrow-sapience-write-tool-grants.md
- **Artifacts**: plans/01_narrow-sapience-write-tool-grants.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Narrow `agent-system/extensions/sapience/settings-fragment.json`'s `permissions.allow` from 11
`mcp__sapience__*` entries to 7 by deleting the four MCP write-tool grants
(`sapience_remember`, `sapience_wrapup`, `sapience_handoff`, `sapience_adddoc`), then bring every
surface that states the old grant set as current fact into agreement with it in the same task.
The research report selected grant shape **(i) — remove all four** and recorded the reasoning;
this plan applies that decision and closes the consistency radius, which is wider than the two
files the dispatch names.

Phases 1-4 land the narrowing and the prose/doc consistency edits; Phase 5 folds in the
remaining merge-source and extension-metadata edits, regenerates the deployed tree (already
stale for `sapience` per this dispatch's own deploy-freshness context), and verifies the
acceptance criterion that a fresh load produces the narrowed set.

### Premise Re-Validation

The dispatch flagged three Carried-Figure lines. All three were checked against live state and
the prior research report; **all three are confirmed unchanged and accurate**:

| Dispatch line | Claim | Verification result |
|---|---|---|
| 26 | "No such task existed until this one" (the named escape valve) | **Confirmed.** `agent-system/extensions/sapience/rules/sapience-write-path.md`'s "Accepted Residual: The Four-Tool Permission Grant Stays Intact" section still carries the remedy clause verbatim; no other task record names it. |
| 60 | Shape (ii)'s premise — `_wrapup`, `_handoff`, `_adddoc` are never-prescribed | **Confirmed.** `review-gate-boundary.md`'s `## Write-Tool Disposition` table gives an affirmative "ruled out / replaced / out of scope" disposition for each, and no instruction surface prescribes any of them. |
| 74 | The rule's source is `agent-system/extensions/sapience/`, never the deployed `.claude/` mirror | **Confirmed.** `agent-system/extensions/sapience/rules/sapience-write-path.md` exists on disk and is the source of the deployed `.claude/rules/sapience-write-path.md`. |

### Research Integration

The report's Decisions 1-6 and Recommendations 1-7 are adopted in full and are the backbone of
Phases 1-5. Specifically: grant shape (i) (Decision 1), the fragment edit (Decision 2), the
replace-not-renumber treatment of `core`'s worked example (Decision 3), the landed-disposition
rewrite of the rule section (Decision 4), the three additional in-scope sapience files
(Decision 5), and the merge-retraction limitation as a stated non-blocker (Decision 6).

**Four coupled surfaces this plan adds beyond the research report's edit set**, found by direct
inspection while sizing the phases:

1. `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` — check (e) hardcodes
   `[ "$GRANT_COUNT" -eq 11 ]` (line 242) plus the matching header, pass, and fail strings
   (lines 35, 243, 245). This is the very probe the task's own acceptance criterion 4 relies on
   ("a fresh load produces the narrowed set"); left at 11, that probe reports **failure** against
   a correctly-narrowed fresh deploy. This is a functional coupling, not a prose one.
2. `agent-system/extensions/core/docs/guides/permission-configuration.md:109` — the research
   report assessed this file as "a pointer asserting no fact," but it names "the
   **sapience-extension** worked example" by name, so it goes stale the moment Phase 2 replaces
   that worked example.
3. `agent-system/extensions/sapience/manifest.json:4` — the extension description states "grants
   all 11 mcp__sapience__* tools."
4. `agent-system/extensions/sapience/index-entries.json:30-31` — a `"11 grants"` keyword and an
   `"11-grant/per-project-registration tradeoff"` summary, both feeding the context index.

Additionally, `review-gate-boundary.md`'s **"Coming staleness of `core`'s worked example"**
paragraph (lines 81-92) needs rewriting rather than leaving alone: its subject premise — that
`core`'s carve-out subsection cites this extension by path as its worked example — becomes false
once Phase 2 lands. The still-open dotfiles-level read-grant trigger it also records must be
preserved, in a form that no longer claims `core` cites sapience.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided in this dispatch; `specs/ROADMAP.md` was not consulted.

## Goals & Non-Goals

**Goals**:
- Apply grant shape (i): `permissions.allow` carries exactly the 7 non-write entries.
- Keep `verify-sapience-mcp.sh`'s check (e) a true acceptance probe by retargeting it to 7.
- Replace `core`'s carve-out worked example so it states a true configuration, with the three
  governing requirements left intact as forward-looking guidance, and the anchor
  `permission-configuration.md` points at left located (not deleted).
- Rewrite the rule's Accepted Residual section as a landed disposition, per
  `no-record-versioning-in-deliverables.md` — current arrangement only, no narration of what the
  grant used to be.
- Leave no surface under `agent-system/extensions/sapience/**` or `core`'s two permission
  documents stating the 11-tool / 4-write-tool grant as current fact.
- State the merge-retraction interaction explicitly rather than implying full closure.

**Non-Goals**:
- The inert `mcp__sapience__sapience` entry and the ungranted `sapience_connect` /
  `sapience_join` tools (research Finding; Recommendation 6) — recorded, not acted on.
- The separate, still-open question of removing the dotfiles-level user-scope read grants — a
  different trigger for the same `core` paragraph; do not pre-empt it.
- Hand-editing this repository's own `.claude/settings.local.json` to retract the four already-
  merged entries, or fixing the merge-additivity defect that makes that retraction necessary.
- `per-repo-scoping.md`'s four-population census and `review-gate-boundary.md`'s
  `## Write-Tool Disposition` table (Recommendation 5) — both remain accurate.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `verify-sapience-mcp.sh` left at `-eq 11` makes the acceptance probe report failure on a correct narrowing | H | H if unaddressed | Phase 1 edits the script in the same commit as the fragment; Phase 5 runs the probe and reads its (e) line. |
| Deleting `core`'s worked example outright dangles `permission-configuration.md`'s pointer | M | M | Phase 2 replaces in place and edits the pointer's own wording; both files re-read after the edit. |
| Replacement text in `core` pre-empts the still-open dotfiles read-grant question | M | M | Phase 2's text describes only the write-tool-grant state this task produces; Phase 4 preserves the other trigger separately. |
| The narrowing is reported as fully closed while this repo's merged `settings.local.json` still carries 11 entries | M | H if unstated | Phases 1 and 5 both state the merge-retraction interaction; Phase 5's verification records the live count as an observed, expected residual rather than a regression. |
| A sibling task (615, 617) edits a shared file concurrently on this same working tree | M | M | Re-read every file immediately before editing; stage explicit file lists only; never `git-snapshot.sh` in reverting mode; stop and report any foreign commit or modification. |
| After narrowing, sapience's 7-read project grant duplicates the dotfiles user-scope read list rather than lifting a withheld tier | L | M | Phase 2 states the carve-out is currently unexercised without asserting anything about the redundancy, which belongs to the separate dotfiles question. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 2 |
| 4 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Narrow the Grant and Retarget Its Verification Probe [COMPLETED]

**Goal**: `permissions.allow` carries exactly the 7 non-write entries, and the probe that checks
the merged result expects 7, not 11.

**Tasks**:
- [x] Re-read `agent-system/extensions/sapience/settings-fragment.json` immediately before
      editing (sibling-task concurrency). *(completed)*
- [x] Delete exactly these four entries from `permissions.allow`:
      `mcp__sapience__sapience_remember`, `mcp__sapience__sapience_wrapup`,
      `mcp__sapience__sapience_handoff`, `mcp__sapience__sapience_adddoc`. *(completed)*
- [x] Leave the remaining seven entries untouched and in their current relative order, including
      the inert `mcp__sapience__sapience` entry (explicitly out of scope). *(completed)*
- [x] Leave the `hooks` block entirely unchanged. *(completed)*
- [x] Confirm the file is still valid JSON and the array length is 7:
      `jq '.permissions.allow | length' agent-system/extensions/sapience/settings-fragment.json`.
      *(completed: returns 7)*
- [x] Re-read `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh`, then update
      check (e) to expect 7: the `-eq 11` comparison (line 242), the header comment (line 35),
      and the pass/fail message strings (lines 243, 245) — including the `$GRANT_COUNT/11`
      denominator in the failure message. *(completed)*
- [x] Add a short note at check (e) recording that a repository which loaded sapience BEFORE this
      narrowing keeps its already-merged write-tool entries (the merge engine is additive-only),
      so a count above 7 there is a known pre-existing residual rather than new drift.
      *(completed)*
- [x] Commit this phase's two files with an explicit file list. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Exactly four entries are removed and exactly seven remain in
`permissions.allow`; `verify-sapience-mcp.sh` carries the literal `11` at exactly lines 35, 242,
243, and 245. The implementer confirms both by re-reading each file and running the `jq` length
check and `grep -n '\b11\b' agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh`
after editing (expected: no remaining grant-count hits).

**Tier Justification**: Covered by
`bash .claude/scripts/tests/run-all.sh --only test-lint-hook-registration-paths.sh,test-sapience-mcp-registration.sh`,
the exact suite set `suite_selection_select` returns for these two paths.

**Files to modify**:
- `agent-system/extensions/sapience/settings-fragment.json` - delete the four write-tool grant entries from `permissions.allow`
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` - check (e) expects 7 grants, not 11; add the additive-merge residual note

**Verification**:
- `jq '.permissions.allow | length'` on the fragment returns `7`.
- `jq -e '[.permissions.allow[] | select(test("remember|wrapup|handoff|adddoc"))] | length == 0'`
  on the fragment succeeds.
- `jq '.hooks | keys' ` on the fragment still returns the five hook keys.
- `bash -n agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` parses clean.
- `bash .claude/scripts/tests/run-all.sh --only test-lint-hook-registration-paths.sh,test-sapience-mcp-registration.sh`
  is green.

---

### Phase 2: Replace `core`'s Carve-Out Worked Example [COMPLETED]

**Goal**: `mcp-server-ownership.md`'s carve-out subsection states a true configuration, keeps its
three governing requirements as forward-looking guidance, and leaves a located passage at the
anchor `permission-configuration.md` points to.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` lines
      320-350 immediately before editing. *(completed)*
- [x] Replace the `**Worked example**:` paragraph (currently beginning "the sapience extension's
      `agent-system/extensions/sapience/settings-fragment.json` grants four write tools") with
      text stating, as current fact, that no MCP server grant in this repository presently
      exercises this carve-out. *(completed)*
- [x] Keep the three numbered governing requirements above it, and the "distinct from the
      safe/unsafe split carve-out" paragraph below it, byte-identical. *(completed)*
- [x] Write the replacement so it describes only the write-tool-grant state this task produces;
      do NOT assert anything about the dotfiles-level user-scope read allow-list, which is a
      separate, still-open question. *(completed)*
- [x] Per `no-record-versioning-in-deliverables.md`, state the current arrangement only — no
      "previously", "no longer", "used to", or supersession framing. *(completed)*
- [x] Update `agent-system/extensions/core/docs/guides/permission-configuration.md:109` so the
      cross-reference no longer promises a "sapience-extension worked example"; it should point
      at the subsection and its three governing requirements. *(completed)*
- [x] Re-read the surrounding sentence in `permission-configuration.md` after the edit and
      confirm it still reads correctly (research Risk 1's explicit instruction: re-read, do not
      assume).
- [x] Commit this phase's two files with an explicit file list. *(deviation: altered — a third
      file, `agent-system/extensions/core/index-entries.json`, was also committed: this phase's
      edit shrank `mcp-server-ownership.md`'s line count, which `generate-context-line-counts.sh
      --write` corrected in the same gate pass; see progress file deviation entry)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for both paths (no
suite maps to either), so the honest covering check is plan-format.md's source-store
non-`specs/**` markdown sub-case (b):
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` - replace the carve-out's worked-example paragraph; three governing requirements unchanged
- `agent-system/extensions/core/docs/guides/permission-configuration.md` - drop the "sapience-extension" naming from the second carve-out's cross-reference

**Verification**:
- Diff read-through confirms every changed hunk lies inside prose, and that the three numbered
  requirements and the following contrast paragraph are untouched.
- `grep -n "sapience" agent-system/extensions/core/context/patterns/mcp-server-ownership.md`
  returns no hit inside the carve-out subsection that asserts a live sapience grant.
- `grep -n "sapience-extension worked example" agent-system/extensions/core/docs/guides/permission-configuration.md`
  returns nothing.
- The anchor text `permission-configuration.md` links to still exists at that heading.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  is green.

---

### Phase 3: Record the Landed Disposition in the Rule [COMPLETED]

**Goal**: `rules/sapience-write-path.md` states the current grant arrangement as a landed fact,
with no residual and no escape-valve pointer remaining.

**Tasks**:
- [x] Re-read `agent-system/extensions/sapience/rules/sapience-write-path.md` immediately before
      editing. Confirm the edit target is the source store, not `.claude/rules/`. *(completed)*
- [x] Retitle the `## Accepted Residual: The Four-Tool Permission Grant Stays Intact` heading to
      one naming the current state (the grant now matches the standing contract). *(completed:
      retitled to "## The Permission Grant Matches the Standing Contract")*
- [x] Rewrite the section body to state, as current fact: `settings-fragment.json` grants the
      seven read-shaped tools and none of the four MCP write tools; a call to any of the four now
      raises an interactive permission prompt in an interactive session and is denied outright in
      a headless/autonomous run, rather than succeeding silently; and the prescribed write path
      (`scripts/sapience-remember.sh`'s `POST /ingest-kos`) needs no MCP grant because it is a
      Bash script call, so nothing legitimate is lost. *(completed)*
- [x] Remove the "named escape valve ... follow-up task" sentence — that follow-up is this work.
      *(completed)*
- [x] Add one sentence recording the merge-retraction interaction: a repository that loaded
      sapience before this narrowing keeps the already-merged write-tool entries in its own
      `.claude/settings.local.json` until the additive-only merge engine gains retraction or the
      file is hand-edited; fresh loads and fresh deploys get the narrowed set. *(completed)*
- [x] Per `no-record-versioning-in-deliverables.md`, phrase all of the above as the current
      arrangement — no "previously", "no longer", "the grant used to", or supersession table.
      *(completed)*
- [x] Leave the Standing Contract, "Discussing a Tool vs. Prescribing It", and "Verdict:
      Advisory, Not Mechanized" sections unchanged, including the promotion criterion.
      *(completed)*
- [x] Commit this phase's file with an explicit file list. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this path (no suite
maps to it), so the honest covering check is plan-format.md's source-store non-`specs/**`
markdown sub-case (b):
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`.

**Files to modify**:
- `agent-system/extensions/sapience/rules/sapience-write-path.md` - Accepted Residual section becomes a landed-disposition statement; escape-valve pointer removed

**Verification**:
- Diff read-through confirms every changed hunk lies in the one rewritten section.
- `grep -n "escape valve\|Accepted Residual\|Stays Intact"` on the file returns nothing.
- `grep -niE "no longer|previously|formerly|used to|supersed"` on the file returns nothing.
- The Standing Contract and Verdict sections are byte-identical in the diff.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  is green.

---

### Phase 4: Reconcile `review-gate-boundary.md` [COMPLETED]

**Goal**: The sapience domain's own permission-grant disclosure states the seven-tool grant, and
its "Coming staleness" paragraph no longer rests on a premise Phase 2 made false.

**Tasks**:
- [x] Re-read `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md`
      immediately before editing; Phase 2's `core` text must already be in place. *(completed)*
- [x] `## The Permission Grant's Repository-Scoped Tradeoff` (line 49): state the grant as the
      seven read-shaped tools at project scope, not "all 11 ... (the 4 write tools plus 7 read
      tools)". *(completed)*
- [x] Same section, lines 73 and 75: correct "an interactive permission prompt on all 11 tools"
      and "adding the same 11 entries to `~/.dotfiles/config/claude/settings.json`" to the
      seven-tool figure. *(completed)*
- [x] Rewrite the carve-out paragraph (lines ~60-79) so it no longer claims this extension is
      "the worked example the subsection names by path" — Phase 2 removed that naming. Keep the
      substantive point that the project-scope placement is what a nix-enforced user-scope
      settings file leaves available, and keep the "enlarging the blast radius machine-wide is
      the WRONG fix" reasoning. *(completed: the write-tool-specific "mutating, unreviewed"
      framing was generalized to "this extension's tools", since the grant no longer includes
      any write tool)*
- [x] Rewrite the `**Coming staleness of core's worked example.**` paragraph (lines 81-92): its
      premise (that `core` cites this extension by path) is false after Phase 2. Preserve the
      separate, still-open dotfiles-level read-grant question it records, restated so it does not
      depend on `core` naming sapience. *(completed: retitled
      "**The dotfiles-level read-grant question remains open, independent of core's wording.**")*
- [x] `## Explicit Grants, Not a Wildcard` (lines 93-101): the enumeration now lists seven names
      (`sapience`, `sapience_search`, `_briefing`, `_context`, `_ask`, `_outstanding`,
      `_papers`); the "matches the dotfiles allow-list's own convention for the same seven read
      tools" sentence and the auto-grant tradeoff both still hold. *(completed)*
- [x] Leave `## Write-Tool Disposition` (lines 103-117) entirely unchanged — it is sanctioned
      discussion, and research Recommendation 5 says explicitly not to touch it. *(completed:
      confirmed byte-identical in diff)*
- [x] Per `no-record-versioning-in-deliverables.md`, state the current arrangement only.
      *(completed)*
- [x] Commit this phase's file with an explicit file list. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1, 2

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this path (no suite
maps to it), so the honest covering check is plan-format.md's source-store non-`specs/**`
markdown sub-case (b):
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`.

**Scope Hypothesis**: The stale grant-count statements in this file sit at lines 49, 73, 75, 85,
and 95, and the two paragraphs needing structural rewrite are the carve-out paragraph (~60-79)
and "Coming staleness" (81-92). The implementer confirms by running
`grep -n '\b11\b\|four write\|4 write' ` on the file before editing and
`grep -n '\b11\b' ` after (expected: no grant-count hits remain), and by re-reading the two
paragraphs in full rather than editing by line number.

**Files to modify**:
- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md` - grant figures become seven; carve-out and Coming-staleness paragraphs rewritten; Write-Tool Disposition untouched

**Verification**:
- Diff read-through confirms every changed hunk lies in prose and that
  `## Write-Tool Disposition` is untouched in the diff.
- `grep -n '\b11\b'` on the file returns no grant-count hit.
- `grep -n "worked example the subsection names by path"` returns nothing.
- `grep -niE "no longer|previously|formerly|used to"` returns nothing in the changed sections.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  is green.

---

### Phase 5: Merge Sources, Extension Metadata, Redeploy, and Fresh-Load Verification [COMPLETED]

**Goal**: Every remaining surface states the seven-tool grant, the deployed tree is regenerated
from the narrowed source, and a fresh load is confirmed to produce the narrowed set.

This phase carries the task's merge-source and metadata edits together with the regeneration
they feed: `EXTENSION.md` is merged into the deployed `.claude/CLAUDE.md` and `index-entries.json`
into the deployed context index, so the edits and the regeneration that propagates them belong in
one phase rather than split across a later reconciliation.

**Tasks**:
- [x] Re-read each file below immediately before editing (sibling-task concurrency). *(completed)*
- [x] `agent-system/extensions/sapience/EXTENSION.md` (lines 7-8): "carries 11 permission grants
      (7 read tools + 4 write tools)" becomes the seven read-tool figure. The five-hook and
      six-hook-surface counts are unrelated and stay. *(completed)*
- [x] `agent-system/extensions/sapience/README.md` line 15 (the file-inventory table row) and
      line 28 (Gap 1's body): both state the seven read-tool grant. *(completed)*
- [x] `agent-system/extensions/sapience/manifest.json` line 4 (`description`): "grants all 11
      mcp__sapience__* tools" becomes the seven read-tool figure. Confirm the file is still valid
      JSON. *(completed)*
- [x] `agent-system/extensions/sapience/index-entries.json` lines 30-31: drop the `"11 grants"`
      keyword and restate the `"11-grant/per-project-registration tradeoff"` summary. The four
      write-tool names remain legitimate keywords (the entry indexes the Write-Tool Disposition
      table, which is sanctioned discussion). Confirm valid JSON. *(completed)*
- [x] Per `no-record-versioning-in-deliverables.md`, all four files state the current arrangement
      only. *(completed)*
- [x] Commit the four source files with an explicit file list. *(completed)*
- [x] Regenerate the deployed tree (it is already stale for `sapience` per this dispatch's
      deploy-freshness context):
      `timeout 540 bash .claude/scripts/deploy-headless.sh`, invoked with the Bash tool's
      `timeout` parameter raised to 600000 per `context/patterns/external-process-wait.md` Rule 1.
      *(completed: this is the fourth deploy-headless.sh pass this dispatch — three earlier
      idempotent passes already ran during Phases 2-4 to keep each phase's own scoped gate
      green; see those phases' progress-file deviations)*
- [x] Verify the acceptance criterion with a fresh load into a scratch test repository (NOT this
      repo, whose merged settings carry the pre-existing additive residual): create a clean
      directory, load the sapience extension there, and confirm its
      `.claude/settings.local.json` carries exactly the seven `mcp__sapience__*` entries and no
      write-tool entry. *(completed: loaded via `manager.load('sapience', {project_dir=...,
      confirm=false})` headlessly against a throwaway scratch git repo, confirmed exactly 7
      `mcp__sapience__*` entries with no write tool, then discarded the scratch repo)*
- [x] Run `bash .claude/scripts/verify-sapience-mcp.sh` against that test repository and confirm
      check (e) PASSES at 7. *(completed: check (e) PASS at "7 permission grants and all 5
      hooks"; check (b) failed because the scratch load used `manager.load` directly rather than
      the SessionStart MCP-registration hook, which is outside this task's edit surface — the
      plan's own verification criterion names only check (e))*
- [x] Record this repository's own live merged count
      (`jq '[.permissions.allow[]? | select(startswith("mcp__sapience__"))] | length' .claude/settings.local.json`)
      as an observed, expected residual of the additive-only merge engine — not a regression, not
      a failure of this task — and state it in the implementation summary. *(completed: this
      repository's own `.claude/settings.local.json` carries 11 `mcp__sapience__*` entries —
      the pre-existing additive-merge residual the plan anticipated, recorded in the summary)*
- [x] Run the complete gate set and confirm green. *(deviation: altered — per this dispatch's
      Batch Gate Deferral directive, discharged against the scoped narrowing invocation
      `verify-deploy.sh --skip-slow --only-gate 3,4` instead of the complete gate set, which runs
      once for the whole batch at the end of this invocation; see the summary's verification
      section)*
- [x] Commit the completion with an explicit file list. *(completed)*

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Scope Hypothesis**: The remaining stale grant-count statements are exactly five — `EXTENSION.md`
lines 7-8 (one statement), `README.md` lines 15 and 28, `manifest.json` line 4, and
`index-entries.json` lines 30-31 (one keyword plus one summary). The implementer confirms by
running, across the whole source store after all edits,
`grep -rn '\b11\b\|four write\|4 write' agent-system/extensions/sapience/ agent-system/extensions/core/context/patterns/mcp-server-ownership.md agent-system/extensions/core/docs/guides/permission-configuration.md`
and verifying no grant-count hit remains (test-fixture hits under `scripts/tests/` that are
unrelated "Case 11" labels are expected and excluded).

**Files to modify**:
- `agent-system/extensions/sapience/EXTENSION.md` - grant figure becomes seven read tools
- `agent-system/extensions/sapience/README.md` - inventory-table row and Gap 1 body state the seven-tool grant
- `agent-system/extensions/sapience/manifest.json` - description states the seven-tool grant
- `agent-system/extensions/sapience/index-entries.json` - "11 grants" keyword and 11-grant summary restated
- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, regenerating the entire deployed tree

**Verification**:
- `jq -e . agent-system/extensions/sapience/manifest.json` and
  `jq -e . agent-system/extensions/sapience/index-entries.json` both parse.
- The repo-wide grep in the Scope Hypothesis returns no remaining grant-count hit.
- `deploy-headless.sh` exits 0 and the deploy-freshness warning for `sapience` clears.
- The scratch test repository's `.claude/settings.local.json` carries exactly 7
  `mcp__sapience__*` entries, none of them a write tool.
- `bash .claude/scripts/verify-sapience-mcp.sh` against that test repository reports check (e)
  PASS at 7 grants and 5 hooks.
- The complete gate set — `bash .claude/scripts/verify-deploy.sh` — is green.

## Testing & Validation

- [ ] `agent-system/extensions/sapience/settings-fragment.json` has exactly 7 entries in
      `permissions.allow`, none matching `remember|wrapup|handoff|adddoc`, and its `hooks` block
      is unchanged.
- [ ] `verify-sapience-mcp.sh` check (e) expects 7 and passes against a correctly-narrowed fresh
      deploy.
- [ ] `mcp-server-ownership.md`'s carve-out subsection states a true configuration, keeps its
      three governing requirements, and still holds the anchor `permission-configuration.md`
      links to.
- [ ] `permission-configuration.md` no longer promises a sapience-extension worked example.
- [ ] `sapience-write-path.md` records a landed disposition with no residual and no escape-valve
      pointer, and carries the merge-retraction sentence.
- [ ] No file under `agent-system/extensions/sapience/**` (excluding `scripts/tests/` fixtures)
      states the 11-tool / 4-write-tool grant as current fact.
- [ ] No deliverable file added in this task uses record-versioning language.
- [ ] A fresh extension load into a scratch test repository produces exactly the seven-entry
      grant set.
- [ ] `bash .claude/scripts/verify-deploy.sh` is green.

## Artifacts & Outputs

- Narrowed `agent-system/extensions/sapience/settings-fragment.json` (7 entries).
- Updated `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` (check (e) at 7).
- Replaced carve-out worked example in
  `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` and its cross-reference
  in `agent-system/extensions/core/docs/guides/permission-configuration.md`.
- Landed-disposition section in `agent-system/extensions/sapience/rules/sapience-write-path.md`.
- Reconciled `review-gate-boundary.md`, `EXTENSION.md`, `README.md`, `manifest.json`,
  `index-entries.json`.
- Regenerated `.claude/` deploy tree.
- Implementation summary stating the merge-retraction limitation explicitly.

## Rollback/Contingency

Every phase is a single scoped commit over 1-2 files, so reverting any phase is
`git revert` of that phase's commit; no schema, state, or data migration is involved. If
Phase 5's fresh-load verification shows a count other than 7, the fault is in Phase 1's fragment
edit (check `jq '.permissions.allow | length'`) or in a stale deploy (re-run
`deploy-headless.sh`), not in the later prose phases — do not revert Phases 2-4 to chase it.

If the scratch-test-repository load proves impractical within this dispatch, the fallback
evidence is a direct read of the narrowed fragment plus the merge engine's documented
additive-only behavior; record that substitution explicitly in the summary rather than claiming
the fresh-load criterion was met.
