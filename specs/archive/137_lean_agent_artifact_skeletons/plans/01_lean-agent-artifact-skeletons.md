# Implementation Plan: Task #137

- **Task**: 137 - Lean agent artifact skeletons
- **Status**: [COMPLETED]
- **Effort**: 5 hours
- **Dependencies**: None (task 136 is a sequencing risk, not a blocker -- see Risks)
- **Research Inputs**: specs/137_lean_agent_artifact_skeletons/reports/01_lean-agent-artifact-skeletons.md
- **Artifacts**: plans/01_lean-agent-artifact-skeletons.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Eight agent definition files instruct agents to produce `report` and `summary` artifacts without
handing them a validator-conforming inline skeleton, so the artifacts they author fail
`validate-artifact.sh` on required metadata fields and sections. The fix is entirely additive
editing of agent markdown in the source store (`agent-system/extensions/{lean,formal}/agents/`):
add two missing skeletons outright, amend six incomplete ones, then redeploy and demonstrate
conformance. Definition of done: every one of the eight files carries a fenced skeleton whose
metadata lines and section headings cover 100% of `validate-artifact.sh`'s `REPORT_METADATA`/
`REPORT_SECTIONS` or `SUMMARY_METADATA`/`SUMMARY_SECTIONS`, the edits survive a redeploy, and a
real lean dispatch produces a summary and report that validate with zero errors and zero
auto-repairs.

### Research Integration

The research report (`reports/01_lean-agent-artifact-skeletons.md`) supplies four findings this
plan is built on:

1. The authoritative field/section lists, transcribed directly from
   `agent-system/extensions/core/scripts/validate-artifact.sh` lines 19-44 (re-confirmed at plan
   time, unchanged): `REPORT_METADATA` = Task, Started, Completed, Effort, Dependencies,
   Sources/Inputs, Artifacts, Standards; `REPORT_SECTIONS` = Executive Summary, Context & Scope,
   Findings, Decisions, Recommendations; `SUMMARY_METADATA` = Task, Status, Started, Completed,
   Artifacts, Standards; `SUMMARY_SECTIONS` = Overview, What Changed, Decisions, Impacts,
   Follow-ups, References (a required *minimum*, not a whitelist -- extra sections are accepted
   by design).
2. The two plain lean agents are worse than the dispatch assumed: they lack any *stage* that
   instructs writing the artifact at all, not merely a skeleton. `lean-research-agent.md` jumps
   from `## Stage 0` (:208) to `## Write Final Metadata` (:236); `lean-implementation-agent.md`
   jumps from `## Stage 0` (:121) to `## Final Verification Stage` (:149). Neither links its
   format doc in Context References. So these two phases *insert* a stage, they do not amend one.
3. The two hard lean agents are intermediate: both link the correct format doc and both have a
   named write stage (`### Stage 7: Create Implementation Summary` :405; `### Stage 6: Create
   Research Report` :260) carrying domain-valuable content but no metadata header and no section
   headings. Per work item (d), these are amended in place, never replaced.
4. Sweep result (work item (c)): all four `agent-system/extensions/formal/agents/*-research-agent.md`
   files *do* carry an inline report skeleton, but every one is missing the same 5 metadata
   fields and the `## Decisions` section -- a distinct defect shape (present-but-incomplete)
   that the dispatch named only generically. There is no formal-extension implementation agent.

Matching validator semantics carried forward into the edits: section matching is
`grep -qE "^##+ ${section}"` (prefix match at any heading depth) and metadata matching is
`grep -qF "**${field}**:"` (literal substring anywhere in the file). The prefix-match tolerance
is why `### Recommendations` nested under `## Findings` already satisfies `Recommendations`
everywhere. The literal-substring tolerance is why a `**Standards**:` hit in an agent file's own
Context References prose is a false positive for the *produced artifact* -- the field must live
inside the fenced skeleton to have any effect.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found in this repository (`specs/ROADMAP.md` does not exist); the `roadmap_flag`
was not set in the dispatch. No roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Add a complete inline summary skeleton to `lean-implementation-agent.md`, including the explicit
  bracketed-Status vocabulary sentence copied from `general-implementation-agent.md`.
- Add a complete inline report skeleton to `lean-research-agent.md` covering all eight
  `REPORT_METADATA` fields and all five `REPORT_SECTIONS`.
- Amend (not replace) the existing write stages in `lean-implementation-hard-agent.md` and
  `lean-research-hard-agent.md`, preserving their hard/lean-specific content.
- Amend the four `extensions/formal/agents/*-research-agent.md` skeletons to add the missing
  metadata fields and `## Decisions` section, preserving each agent's domain-specific sections.
- Redeploy and confirm the edits survive regeneration of `.claude/`.
- Demonstrate conformance on a real lean dispatch, not a hand-written fixture.

**Non-Goals**:
- Weakening `validate-artifact.sh`'s required-field or required-section arrays. The artifacts are
  wrong, not the validator; task 136 is separately tightening it and a loosening here would fight
  that work directly.
- Editing any file under `.claude/` by hand. `.claude/` is a disposable deploy artifact
  (`.claude/rules/source-store-deploy-boundary.md`); the only correct edit targets are under
  `agent-system/extensions/`.
- Restructuring, renumbering, or rewriting any agent's existing stages beyond what the skeleton
  insertion/amendment requires.
- Adding the general "every terminus-writing agent must inline a validator-matching skeleton"
  guideline to `creating-extensions.md`. The research report recommends this as a follow-up meta
  task; it is out of scope here.
- Touching the reporting side of auto-repair counts (task 13 owns that).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Task 136 changes `REPORT_METADATA`/`SECTIONS` arrays before or during this work, staling every skeleton written here | H | M | Phase 1 re-transcribes the arrays from the live script immediately before any edit and records the exact values; Phase 6 re-runs the same transcription as a drift gate before declaring done |
| Eight hand-edited skeletons drift out of sync with each other and with the `general-*` reference over time | M | H | Each edited file gets an explicit copy-source cross-reference naming `general-implementation-agent.md`'s Stage 6 or `general-research-agent.md`'s Stage 6 as the canonical shape, matching the existing cross-reference convention already used in the lean hard agents |
| Acceptance requires a real lean dispatch, which needs a Lean repository and cross-repo deployment -- this repo has no Lean project | H | H | Phase 7 targets `/home/benjamin/Projects/BimodalLogic` (present, and the repo where the defect was originally observed) and is gated on explicit user go-ahead for the cross-repo deploy and dispatch; Phase 6 provides a full static conformance gate that stands on its own if Phase 7 is deferred |
| An edit accidentally lands in `.claude/agents/` and is silently wiped on next regeneration | H | M | Every phase names only `agent-system/extensions/**` paths; the `validate-meta-write.sh` advisory hook fires on `.claude/**` writes; Phase 6's redeploy-then-diff step would catch a source/deploy mismatch |
| Amending the hard agents' stages destroys their domain-specific content (sorry inventory, adversarial verification, Tier-1 lemma table) | M | M | Phase 4 is explicitly an amend-in-place phase with a pre-edit inventory of the content to preserve and a post-edit grep confirming each preserved item still present |
| The formal-agent skeletons' domain sections (`## Domain Analysis`, `### Mathlib Theorems`, `## Appendix`) get restructured while adding fields | M | L | Phase 5 adds lines only; a post-edit heading diff per file confirms no pre-existing heading was removed or renamed |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 5 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 6 | 2, 3, 4, 5 |
| 5 | 7 | 6 |

Phases within the same wave can execute in parallel. Waves 2 and 3 own disjoint file sets
(Phase 2: `lean-research-agent.md`; Phase 3: `lean-implementation-agent.md`; Phase 5: the four
`formal/agents/*-research-agent.md`; Phase 4: the two lean hard agents), so parallel dispatch
carries no write conflict.

---

### Phase 1: Re-transcribe Validator Contract and Capture Copy Sources [COMPLETED]

**Goal**: Establish, at implementation time rather than research time, the exact required-field
and required-section lists the skeletons must satisfy, and pin the two canonical copy sources.
This gates every subsequent phase against task 136 drift.

**Tasks**:
- [x] Read `agent-system/extensions/core/scripts/validate-artifact.sh` lines 15-45 and transcribe
      `REPORT_METADATA`, `REPORT_SECTIONS`, `SUMMARY_METADATA`, `SUMMARY_SECTIONS`,
      `SUMMARY_SECTIONS_OPTIONAL` verbatim into the phase progress record. *(completed: verbatim match, no drift)*
- [x] Diff the transcription against the five lists recorded in this plan's Research Integration
      section. If any list differs, STOP and record the delta -- every downstream phase's skeleton
      content changes with it. *(completed: no drift vs Research Integration section)*
- [x] Read `agent-system/extensions/core/agents/general-implementation-agent.md`'s
      `### Stage 6: Create Implementation Summary` block and record the exact bracketed-Status
      vocabulary sentence and the fenced skeleton verbatim. *(completed: recorded from lines 465-529)*
- [x] Read `agent-system/extensions/core/agents/general-research-agent.md`'s
      `### Stage 6: Create Research Report` block and record its fenced skeleton verbatim. *(completed: recorded from lines 267-321)*
- [x] Cross-check both against `agent-system/extensions/core/context/formats/summary-format.md`
      and `report-format.md` "Example Skeleton" sections; note any divergence between the
      reference agent and the prose spec (the spec wins on a conflict). *(completed: no divergence found)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This plan asserts the five validator arrays hold the exact values recorded
in Research Integration above, and that the two copy sources live in the two named `### Stage 6`
blocks. Confirm both by direct read of the live files at implementation time; the array
transcription is the phase's own gate and a mismatch halts the phase rather than being papered
over.

**Files to modify**:
- None (read-only phase; output is the recorded transcription in the phase progress file)

**Verification**:
- The transcribed arrays are recorded and either match this plan's Research Integration section
  exactly, or the delta is written down and every downstream phase's skeleton content is adjusted
  before it starts.
- The two copy-source blocks are recorded verbatim, including the bracketed-Status sentence.

---

### Phase 2: Add Report Skeleton to lean-research-agent.md [COMPLETED]

**Goal**: Give `lean-research-agent.md` a report-writing stage it currently lacks entirely,
carrying a skeleton that covers all eight `REPORT_METADATA` fields and all five
`REPORT_SECTIONS`.

**Tasks**:
- [x] Add `@.claude/context/formats/report-format.md` to the `## Context References` block
      (currently lists only `return-metadata-file.md`). *(completed: added)*
- [x] Insert a new stage heading `## Stage 1: Create Research Report` between `## Stage 0:
      Initialize Early Metadata` and `## Write Final Metadata`, matching the file's existing `##`
      stage-heading depth (this file uses `##` for stages, unlike the hard agents' `###`). *(completed: inserted)*
- [x] Under it, add the path-construction note (`specs/{NNN}_{SLUG}/reports/{NN}_{short-slug}.md`,
      `{NN}` from `artifact_number`) and a fenced markdown skeleton modelled on the Phase 1
      copy source from `general-research-agent.md`, carrying all eight `**Field**:` metadata
      lines and `## Executive Summary`, `## Context & Scope`, `## Findings`,
      `## Decisions`, `## Recommendations` (or `### Recommendations` nested under Findings, as
      the copy source does -- the validator's prefix match accepts either) as literal headings. *(completed: done, nested ### Recommendations under Findings)*
- [x] Fold the existing `## Tactic Survey Results` template (currently a free-standing block at
      :199) into the skeleton as an additional section, citing `SUMMARY_SECTIONS`-style
      "required minimum, not exhaustive whitelist" semantics so it is clearly additive, and leave
      the original protocol prose (`### Tactic Discovery Survey Protocol`) in place. *(completed: done, original prose untouched)*
- [x] Add a one-line cross-reference naming `general-research-agent.md`'s
      `### Stage 6: Create Research Report` as the canonical copy source for this skeleton. *(completed: done)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/lean/agents/lean-research-agent.md` - add report-format.md to Context
  References; insert a report-writing stage with a full inline skeleton; fold in the existing
  Tactic Survey Results template as an extra section

**Verification**:
- For each of the eight `REPORT_METADATA` fields, `grep -F '**<field>**:'` inside the newly added
  fenced block returns a hit (check the fenced block, not the whole file -- a whole-file hit can
  come from surrounding agent prose).
- For each of the five `REPORT_SECTIONS`, `grep -E '^##+ <section>'` inside the fenced block
  returns a hit.
- `grep -c '^## Tactic Survey Results'` confirms the pre-existing template content survived.
- No pre-existing `##`/`###` heading in the file was removed or renamed (heading list diff
  against the pre-edit file).

---

### Phase 3: Add Summary Skeleton to lean-implementation-agent.md [COMPLETED]

**Goal**: Give `lean-implementation-agent.md` a summary-writing stage it currently lacks
entirely, carrying a skeleton covering all six `SUMMARY_METADATA` fields, all six
`SUMMARY_SECTIONS`, and the explicit bracketed-Status vocabulary sentence.

**Tasks**:
- [x] Add `@.claude/context/formats/summary-format.md` to the `## Context References` block. *(completed: added)*
- [x] Insert a new stage heading `## Create Implementation Summary` immediately before
      `## Final Verification Stage (MANDATORY)` (:149), at the file's existing `##` stage depth. *(completed: inserted)*
- [x] Add the path-construction note (`specs/{NNN}_{SLUG}/summaries/{NN}_{short-slug}-summary.md`,
      `{NN}` from `artifact_number`). *(completed: done)*
- [x] Copy the mandatory-header framing sentence and the bracketed-Status vocabulary sentence
      verbatim from the Phase 1 copy source: `**Status**: [COMPLETED]` when every plan phase is
      done, `**Status**: [IN PROGRESS]` on a partial run, `**Status**: [BLOCKED]` when blocked,
      naming `summary-format.md` as the vocabulary's home. *(completed: done, verbatim)*
- [x] Add the fenced markdown skeleton with all six `SUMMARY_METADATA` bullets and the six
      required `##` section headings (`Overview`, `What Changed`, `Decisions`, `Impacts`,
      `Follow-ups`, `References`), plus `## Plan Deviations` and `## Verification` as the copy
      source carries them. *(completed: done)*
- [x] Place the lean-specific content (theorems/lemmas proved, sorry inventory, `lake build`
      result) inside `## What Changed` and `## Verification` rather than as new top-level
      sections, so the six required headings stay intact and the existing `### Recording
      Verification Results` stage (:223) has a documented destination for its output. *(completed: done)*
- [x] Add a one-line cross-reference naming `general-implementation-agent.md`'s
      `### Stage 6: Create Implementation Summary` as the canonical copy source. *(completed: done)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` - add summary-format.md to
  Context References; insert a summary-writing stage with a full inline skeleton and the
  bracketed-Status vocabulary sentence

**Verification**:
- Each of the six `SUMMARY_METADATA` fields greps inside the new fenced block.
- Each of the six `SUMMARY_SECTIONS` headings greps inside the new fenced block via
  `^##+ <section>`.
- The literal bracketed-Status sentence is present and names all three of `[COMPLETED]`,
  `[IN PROGRESS]`, `[BLOCKED]`.
- Heading-list diff confirms no pre-existing heading removed or renamed.

---

### Phase 4: Amend the Two Lean Hard Agents' Write Stages [COMPLETED]

**Goal**: Wrap the existing (content-correct but structurally incomplete) write stages in
`lean-implementation-hard-agent.md` and `lean-research-hard-agent.md` in full skeletons, with
zero loss of their hard/lean-specific content.

**Tasks**:
- [x] Pre-edit: inventory the content to preserve. For `lean-implementation-hard-agent.md`
      `### Stage 7: Create Implementation Summary` (:405-414): phases executed, theorems/lemmas
      proved, final verification results, sorry inventory, plan deviations from inline checklist
      annotations. For `lean-research-hard-agent.md` `### Stage 6: Create Research Report`
      (:260-271): `## Adversarial Self-Verification`, `## Literature Proof Structure` (Tier 1
      only), `## Tactic Survey Results`, and the Tier-1 five-column lemma-mapping-table
      requirement in `## Findings`. Record this inventory before touching either file. *(completed: done, recorded in progress file)*
- [x] `lean-implementation-hard-agent.md`: amend Stage 7 in place -- add the mandatory metadata
      header, the bracketed-Status vocabulary sentence, and the six `SUMMARY_SECTIONS` headings,
      relocating each preserved bullet into its natural home (sorry inventory and verification
      results under `## Verification`/`## What Changed`; plan deviations under
      `## Plan Deviations`). Do not delete the stage or its bullets. *(completed: done, verified via scoped grep and preservation grep)*
- [x] `lean-research-hard-agent.md`: amend Stage 6 in place -- inline the full report skeleton
      (all eight metadata fields, all five sections) rather than referring to a "base report",
      then append the three hard-specific extra sections and keep the Tier-1 lemma-table
      requirement attached to `## Findings`. Inlining (rather than cross-referencing
      `lean-research-agent.md`) is deliberate: agents are dispatched with only their own file
      loaded, which is why the `general-*` agents each inline their own skeleton rather than
      pointing at one another. *(completed: done, verified via scoped grep and preservation grep)*
- [x] Add the same copy-source cross-reference line to both files. *(completed: done)*

**Timing**: 1 hour

**Depends on**: 2, 3

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly two files and exactly the preserved-content
items listed in the first task above. Confirm at implementation time by re-reading both stage
blocks in full before editing; if either stage carries content not on the inventory, add it to
the inventory rather than dropping it.

**Files to modify**:
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` - amend Stage 7 with
  the full summary metadata header, Status vocabulary sentence, and six required sections
- `agent-system/extensions/lean/agents/lean-research-hard-agent.md` - amend Stage 6 with the
  full report metadata header and five required sections, plus the three preserved extra sections

**Verification**:
- All six `SUMMARY_METADATA` fields and six `SUMMARY_SECTIONS` grep inside the hard
  implementation agent's amended Stage 7 fenced block; all eight `REPORT_METADATA` fields and
  five `REPORT_SECTIONS` grep inside the hard research agent's amended Stage 6 block.
- Every item on the pre-edit preservation inventory greps successfully in the post-edit file --
  explicitly including `Adversarial Self-Verification`, `Literature Proof Structure`,
  `Tactic Survey Results`, `sorry`, and the lemma-mapping-table requirement.
- Neither stage heading was renumbered or removed.

---

### Phase 5: Amend the Four Formal-Extension Report Skeletons [COMPLETED]

**Goal**: Bring the four existing (present-but-incomplete) formal-extension report skeletons up
to full `REPORT_METADATA`/`REPORT_SECTIONS` coverage, adding lines only.

**Tasks**:
- [x] Per file, re-confirm the gap before editing: for each of the eight `REPORT_METADATA` fields
      run `grep -F '**<field>**:'` *scoped to the fenced skeleton block* (not the whole file --
      `logic-research-agent.md`'s file-wide `**Standards**:` hit at :89 comes from its Context
      References prose and is a false positive for the produced artifact), and
      `grep -E '^##+ Decisions'` for the section. *(completed: done, negatives recorded in progress file)*
- [x] `formal-research-agent.md` (Stage 4, skeleton at :145-185): add the missing `**Effort**:`,
      `**Dependencies**:`, `**Sources/Inputs**:`, `**Artifacts**:`, `**Standards**:` lines and a
      `## Decisions` section. Also add `## Context & Scope` -- this file uses `## Domain Analysis`
      in its place, which does not satisfy the literal-heading check; keep `## Domain Analysis`
      as well. *(completed: done)*
- [x] `logic-research-agent.md` (Stage 5, skeleton at :221-269): add `**Effort**:`,
      `**Dependencies**:`, `**Sources/Inputs**:`, `**Artifacts**:`, `**Standards**:` (inside the
      skeleton, regardless of the Context References hit) and a `## Decisions` section. *(completed: done)*
- [x] `math-research-agent.md` (Stage 5, skeleton at :210-254): same five metadata lines plus
      `## Decisions`. *(completed: done)*
- [x] `physics-research-agent.md` (Stage 5, skeleton at :204-248): same five metadata lines plus
      `## Decisions`. *(completed: done)*
- [x] Add the `general-research-agent.md` copy-source cross-reference line to each of the four. *(completed: done)*
- [x] Preserve every existing domain section untouched: `## Domain Analysis`,
      `### Mathlib Theorems`, `### Context File Review`, `### Cross-Domain Synthesis`,
      `### Recommendations`, `## Risks & Mitigations`, `## Appendix`. *(completed: done, confirmed via heading-list diff)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: This plan asserts exactly four defective files in
`agent-system/extensions/formal/agents/` (there is no formal-extension implementation agent),
each missing the same five metadata fields plus `## Decisions`, with `Context & Scope`
additionally missing from `formal-research-agent.md` only. Confirm per-file with the scoped greps
in the first task before editing; edit only what the greps show missing, and record any file that
turns out already conforming as an explicit negative.

**Files to modify**:
- `agent-system/extensions/formal/agents/formal-research-agent.md` - add 5 metadata lines,
  `## Decisions`, `## Context & Scope`
- `agent-system/extensions/formal/agents/logic-research-agent.md` - add 5 metadata lines,
  `## Decisions`
- `agent-system/extensions/formal/agents/math-research-agent.md` - add 5 metadata lines,
  `## Decisions`
- `agent-system/extensions/formal/agents/physics-research-agent.md` - add 5 metadata lines,
  `## Decisions`

**Verification**:
- All eight `REPORT_METADATA` fields and all five `REPORT_SECTIONS` grep inside each of the four
  fenced skeleton blocks.
- Per-file heading-list diff shows only additions, no removals or renames.
- The pre-edit scoped-grep results are recorded, including negatives, so a later reader can see
  which fields were actually missing per file.

---

### Phase 6: Redeploy and Static Conformance Gate [COMPLETED WITH EXCLUSIONS]

**Goal**: Confirm the source-store edits regenerate correctly into `.claude/` and that every
edited skeleton is statically conformant, closing the "survives regeneration" acceptance clause.

**Tasks**:
- [x] Re-run the Phase 1 validator-array transcription as a drift gate; if task 136 changed the
      arrays mid-flight, reconcile the skeletons before proceeding. *(completed: done, no drift -- arrays unchanged from Phase 1)*
- [x] Run `bash .claude/scripts/deploy-headless.sh /home/benjamin/.config/nvim` (default
      non-destructive resync mode). *(deviation: altered — ran successfully (deploy itself landed) but exited 3, not 0, due to pre-existing verification-gate failures unrelated to this task; see Reasoned Exclusions)*
- [ ] Diff each of the eight edited source files against its deployed counterpart under
      `.claude/agents/` -- the skeletons must be byte-identical, confirming the edits landed in
      the source store and not only in the deploy tree. *(deviation: skipped — lean/formal extensions are not installed/active in this repository's .claude-extensions.json, so no deployed counterpart exists to diff against; this check is deferred to Phase 7's cross-repo deploy into BimodalLogic, which already performs a deploy-then-verify step there)*
- [x] Run the full field/section grep matrix against the eight *deployed* files (not just the
      source ones), recording a pass/fail cell per file per required field and section. *(deviation: altered — ran the matrix against the eight source files instead of deployed files, since lean/formal are not deployed in this repo; all 8 pass with zero missing fields/sections)*
- [x] Confirm no file under `.claude/` was hand-edited during this task: `git status` shows no
      unexpected `.claude/` modifications beyond what the redeploy produced. *(completed: done -- .claude/ is fully gitignored here; confirmed no Write/Edit tool call targeted .claude/** during this task)*
- [x] Commit the source-store edits. *(completed: done, each phase committed per green sub-step)*

**Timing**: 0.75 hours

**Depends on**: 2, 3, 4, 5

**Verification Tier**: full

**Files to modify**:
- None directly (the redeploy regenerates `.claude/`, which is a deploy artifact, not an edit
  target)

**Verification**:
- `deploy-headless.sh` exits 0.
- The eight source/deploy skeleton diffs are empty.
- The grep matrix over the deployed files is 100% pass: 8 metadata fields x 5 report skeletons
  (lean-research, lean-research-hard, and the four formal -- 6 report skeletons total) and 6
  metadata fields x 2 summary skeletons, plus every required section.
- The repository's standard gate set for a documentation/agent-file change passes.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Diff each of the eight edited source files against its deployed counterpart under `.claude/agents/` | The lean and formal extensions are not installed/active in this repository -- `.claude/` here only carries agents for the extensions this repo actually uses | `python3 -c "import json; print(list(json.load(open('.claude-extensions.json'))['extensions'].keys()))"` -> `['memory', 'literature', 'nix', 'core', 'email', 'nvim']` (no `lean`/`formal`); `ls .claude/agents/` lists no `lean-*.md` or `formal-*.md` file. `deploy-headless.sh` only resyncs extensions the state file already marks active (confirmed by reading its own header comment), so it cannot deploy these files here regardless of source content. The equivalent check is not dropped -- it is performed in Phase 7, which already deploys into `/home/benjamin/Projects/BimodalLogic`, a repo where these extensions ARE installed. |
| Run the full field/section grep matrix against the eight *deployed* files | Same root cause: no deployed copy of any of the eight files exists in this repo to grep | Same evidence as above. Substitute check performed instead: the identical field/section grep matrix run directly against the eight *source* files (`agent-system/extensions/{lean,formal}/agents/*.md`) -- recorded per-phase in `progress/phase-{2,3,4,5}-progress.json` and re-confirmed in one consolidated pass at Phase 6: all 6 report skeletons (8/8 metadata fields, 5/5 sections) and both summary skeletons (6/6 metadata fields, 6/6 sections) pass with zero missing entries. |
| `deploy-headless.sh` exits 0 | The deploy itself landed (source-store changes propagated to every extension this repo has active), but the script's own post-deploy verification gate fails on defects with no connection to `agent-system/extensions/{lean,formal}/**`: two `index-entries.json` line-count drifts under `core`/`literature` (`patterns/postflight-control.md`, `schemas/state-schema.json`, `project/literature/patterns/zotero-item-creation.md`), a whole-tree orphan finding on `index-entries.json` itself, a failing shell test-suite run, and a state-writer boundary lint finding | `bash .claude/scripts/deploy-headless.sh /home/benjamin/.config/nvim; echo "EXIT: $?"` -> `EXIT: 3`; `bash .claude/scripts/check-extension-docs.sh` isolates the two failing extensions as `core` and `literature` only -- both `lean` and `formal` report `PASS`; none of the four failure lines named above mention any file this task touched. These are pre-existing repo-wide conditions (concurrent work from other in-flight tasks in this session), out of scope for a task whose acceptance criterion is specific to the eight lean/formal agent files. |

---

### Phase 7: End-to-End Demonstration on a Real Lean Dispatch [COMPLETED]

**GO-AHEAD GRANTED** (Phase 7): the user approved the cross-repo deploy and dispatch. The
blocker recorded here previously (no interactive user in an autonomous run) is resolved.

**EVIDENCE RECORD — report half SATISFIED, summary half PENDING.**

Deploy step: satisfied without a fresh `deploy-headless.sh` run. The user reloaded the agent
system into the Lean repository from nvim at 11:13 local on 2026-09-07. All eight lean/formal
agent files there were verified byte-identical (`diff -q`) to their `agent-system/extensions/`
source-store originals, and the deployed `lean-implementation-agent.md` summary skeleton was
machine-checked to carry all six required SUMMARY sections and all eight metadata fields.

Report half — THREE independent passes, all from research dispatches that completed AFTER the
11:13 reload, so all authored by the amended `lean-research-agent`:

| Task | Artifact | Research completed | `validate-artifact.sh <path> report` |
|------|----------|--------------------|--------------------------------------|
| 539 | `reports/01_linter-debt-burndown.md` | 12:41 | `[PASS] report artifact is valid (0 warning(s))` |
| 544 | `reports/01_sp-underivable-native-bl-soundness.md` | 12:13 | `[PASS] report artifact is valid (0 warning(s))` |
| 545 | `reports/01_hg-completeness-dense-dedekind.md` | 12:13 | `[PASS] report artifact is valid (0 warning(s))` |

All three run without `--fix`; zero errors, zero warnings, zero `[FIXED]` auto-repair lines. The
pre-reload `lean-research-agent` carried no report-writing stage at all, so a conforming report is
positive evidence of the amended agent rather than of chance.

Summary half — NOT YET SATISFIED, and deliberately NOT closed with the one summary available.
The only summary written after the reload is task 546's
`summaries/01_ztime-rtime-rename-summary.md` (12:09), and it FAILS validation (4 missing metadata
fields, 5 missing sections, including `## What changed` whose lowercase `c` alone defeats the
validator's case-sensitive `^##+ What Changed`). This is NOT counter-evidence: that task's
implement dispatch STARTED at 09:08 and ran continuously through phase commits at 09:21, 10:21,
11:26, 11:47 and 11:54 to completion at 12:10 — it spans the 11:13 reload, so the agent
definition in force for the whole run was the PRE-amendment one, which had no summary skeleton.
Its failure is a demonstration of the original defect, not of a regression.

**SUMMARY HALF — SATISFIED. PHASE 7 ACCEPTANCE MET IN FULL.**

Task 539's implement dispatch supplied the missing summary. Provenance is unambiguous: the
`implement` lock was acquired 2026-09-07T19:48:57Z (12:48 local) and every phase commit lands
between 13:00 and 13:55 — the entire run is after the 11:13 agent reload, so the amended
`lean-implementation-agent` was in force throughout.

Artifact: `specs/539_linter_debt_burndown_nolints_dupnamespace/summaries/01_linter-debt-burndown-summary.md`
(written 13:54). Verbatim validator output, run WITHOUT `--fix`:

```
Validating summary: specs/539_linter_debt_burndown_nolints_dupnamespace/summaries/01_linter-debt-burndown-summary.md
[PASS] summary artifact is valid (0 warning(s))
```

Exit 0. Zero errors, zero warnings, zero `[FIXED]` auto-repair lines. Structural confirmation: the
artifact carries all eight required metadata fields (`Task`, `Status`, `Started`, `Completed`,
`Effort`, `Dependencies`, `Artifacts`, `Standards`) and all six required sections (`Overview`,
`What Changed`, `Decisions`, `Impacts`, `Follow-ups`, `References`) as authored — no repair was
needed or applied.

**Acceptance tally**: report half proven three times over (tasks 539, 544, 545 — all
`[PASS] ... (0 warning(s))`); summary half proven once (task 539). Both artifact classes
demonstrated on real dispatches; no hand-written fixture was used anywhere, as the criterion
requires.

**Phase 6 exclusion retired as a side effect.** Phase 6 closed `[COMPLETED WITH EXCLUSIONS]`
because the source-vs-deployed diff and the deployed-file grep matrix could not run in this
repository (the lean/formal extensions are not installed here). Both checks ran in the Lean
repository during this phase: all eight deployed `lean-*`/`formal-*`/`logic-*`/`math-*`/
`physics-*` agent files were confirmed byte-identical (`diff -q`) to their
`agent-system/extensions/` source-store originals, and the deployed
`lean-implementation-agent.md` skeleton was machine-checked against the validator's own
`SUMMARY_SECTIONS`/metadata vocabulary. The exclusion's deferred verification is therefore
discharged; the Phase 6 marker is left as recorded for historical accuracy.

**Goal**: Satisfy the acceptance criterion that a lean-language task run end to end produces a
summary and a report that both pass `validate-artifact.sh` with zero errors and zero
auto-repairs, demonstrated on a real dispatch rather than a hand-written fixture.

**Tasks**:
- [ ] Confirm with the user before proceeding: this phase deploys to and dispatches inside a
      second repository (`/home/benjamin/Projects/BimodalLogic`, where the defect was originally
      observed on 2026-09-01). Cross-repo deployment and a real agent dispatch are outward-facing
      actions with real cost -- do not start them without explicit go-ahead.
- [ ] Deploy the updated agents into the Lean repository:
      `bash .claude/scripts/deploy-headless.sh /home/benjamin/Projects/BimodalLogic`, then verify
      the four `.claude/agents/lean-*.md` files there carry the new skeletons.
- [ ] Identify a suitable existing lean-type task in that repo, or create a minimal scoped one, to
      drive research and implementation through to artifact creation.
- [ ] Run the dispatch to completion so that both a `reports/` and a `summaries/` artifact are
      authored by the lean agents.
- [ ] Run `bash .claude/scripts/validate-artifact.sh <report path> report` and
      `bash .claude/scripts/validate-artifact.sh <summary path> summary` (without `--fix`), and
      record the full output.
- [ ] Confirm zero errors and zero `[FIXED]` auto-repair lines in both outputs. Any `[FIXED]`
      line means a field was still missing from the skeleton -- treat it as a Phase 2/3/4 defect
      and loop back.

**Timing**: 1.25 hours

**Depends on**: 6

**Verification Tier**: full

**Scope Hypothesis**: This plan asserts `/home/benjamin/Projects/BimodalLogic` is a deployable
Lean repository with lean-type agents already present (confirmed at plan time:
`.claude/agents/lean-{implementation,research}{,-hard}-agent.md` all exist there). Confirm it is
still deployable and has an available lean task before starting; if it is not, report the block
rather than substituting a hand-written fixture, which the acceptance criterion explicitly
excludes.

**Files to modify**:
- None in this repository. Artifacts are produced in the target Lean repository by the dispatch
  itself.

**Verification**:
- Both `validate-artifact.sh` invocations exit 0 with zero errors and zero warnings attributable
  to missing metadata or sections.
- Neither invocation reports an auto-repair; the artifacts are conformant as authored.
- The validator output is recorded verbatim in the implementation summary as the acceptance
  evidence.

---

## Testing & Validation

- [ ] Validator arrays re-transcribed from the live `validate-artifact.sh` at Phase 1 and again at
      Phase 6; any drift reconciled before completion.
- [ ] Per-file scoped grep matrix: every required metadata field and section present inside each
      of the eight fenced skeleton blocks (not merely somewhere in the file).
- [ ] Per-file heading-list diff shows additions only -- no pre-existing heading removed or
      renamed in any of the eight files.
- [ ] Preservation check on the two hard lean agents: every item on the Phase 4 pre-edit inventory
      still present post-edit.
- [ ] `deploy-headless.sh` exits 0 and source/deploy skeletons are byte-identical.
- [ ] `validate-artifact.sh` reports zero errors and zero auto-repairs on a real lean-dispatch
      report and summary.
- [ ] No hand-authored files under `.claude/` in the final diff.
- [ ] Sweep negatives recorded explicitly ("checked X, already conforming") so a later reader
      knows the search happened -- covering the two lean hard agents, the four formal research
      agents, and the confirmed absence of a formal-extension implementation agent.

## Artifacts & Outputs

- `agent-system/extensions/lean/agents/lean-research-agent.md` - new report-writing stage with
  full inline skeleton
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` - new summary-writing stage
  with full inline skeleton and bracketed-Status vocabulary
- `agent-system/extensions/lean/agents/lean-research-hard-agent.md` - Stage 6 amended with a full
  inline report skeleton
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` - Stage 7 amended with a
  full inline summary skeleton
- `agent-system/extensions/formal/agents/formal-research-agent.md` - skeleton amended
- `agent-system/extensions/formal/agents/logic-research-agent.md` - skeleton amended
- `agent-system/extensions/formal/agents/math-research-agent.md` - skeleton amended
- `agent-system/extensions/formal/agents/physics-research-agent.md` - skeleton amended
- Regenerated `.claude/agents/` deploy tree (artifact of the redeploy, not an edit target)
- `specs/137_lean_agent_artifact_skeletons/summaries/01_lean-agent-artifact-skeletons-summary.md` -
  implementation summary carrying the sweep report with explicit negatives and the Phase 7
  validator output as acceptance evidence

## Rollback/Contingency

All edits are additive markdown changes to eight agent files in the source store, committed per
green sub-step. Rollback is `git revert` of the phase commits followed by
`bash .claude/scripts/deploy-headless.sh` to regenerate `.claude/` from the reverted source --
no schema, state, or runtime code is touched, so there is nothing to migrate back.

Contingency by phase:
- Phase 1 drift detected: halt, record the delta, and adjust every skeleton's content before any
  file is edited. Do not proceed on stale field lists.
- Phase 4 preservation failure: revert that file only and re-amend from the recorded pre-edit
  inventory; the other seven files are independent.
- Phase 6 source/deploy mismatch: an edit landed in `.claude/` rather than the source store.
  Re-apply it under `agent-system/extensions/` and redeploy; do not patch the deploy tree.
- Phase 7 blocked (no available lean task, or the target repo is not deployable): report the block
  explicitly and leave the task `[PARTIAL]` on that phase. Do not substitute a hand-written
  fixture -- the acceptance criterion rules it out, and a fixture pass would be false evidence.
