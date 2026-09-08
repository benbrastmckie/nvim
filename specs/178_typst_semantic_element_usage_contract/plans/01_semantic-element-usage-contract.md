# Implementation Plan: Semantic Element Usage Contract for the Typst Extension

- **Task**: 178 - Author the missing semantics layer for the typst extension's semantic elements, and wire it into the implementation agent and skill as an actual structural gate
- **Status**: [IMPLEMENTING]
- **Effort**: 4.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/178_typst_semantic_element_usage_contract/reports/01_semantic-element-usage-contract.md
- **Artifacts**: plans/01_semantic-element-usage-contract.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The typst extension documents *how* to invoke its semantic elements (`#theorem`, `#definition`,
`#remark`, `rule-block`, ...) but nowhere states what any of them is *for*, how sparingly to reach
for one, or where it may legally appear relative to headings and results. That absence is what let
a produced chapter open — immediately after its `= Agency` heading, before any prose — with a
`#remark("Formalization Status")` block containing a 25-item enumerated tracking checklist. This
plan authors the missing semantics layer as a new standard, gives the mechanics files and the
chapter template the semantics they lack, wires the standard into the context index, and — the
load-bearing part — installs it as a structural self-review gate in both the typst implementation
agent and its skill, so `typst compile` exiting 0 stops being the sole verification.

All edits land under `agent-system/extensions/typst/**` at the global root
`/home/benjamin/.config/nvim`. No `.typ` file is produced or modified, so there is nothing to
compile and no `typst compile` gate applies to this task's own acceptance.

### Research Integration

The research report confirmed every audit claim against live files and supplies the exact edit
anchors this plan uses:
- `patterns/theorem-environments.md` is 74 lines, mechanics-only, and its Label Conventions table
  has rows for `thm:`, `lem:`, `def:`, `cor:`, `ex:` but **no `rem:` row**.
- The one existing sparingness norm lives in `standards/type-theory-foundations.md` (line ~163,
  "Do NOT add DTT remarks to every definition... strategic placement, not exhaustive annotation")
  and is scoped exclusively to DTT annotation remarks. It is the right *shape* of rule and
  generalizes to nothing.
- `templates/chapter-template.md`'s existing `#remark[...]` (in "Example: Minimal Chapter", under
  `== Multi-Agent Modality`) is **not** a positive model: no substantial result precedes it. A
  correct example needs a `#theorem`/`#proof` immediately before the remark.
- The agent's only structural gate is Stage 4C ("Compilation must succeed. All specified files
  must exist") plus Stage 5 `typst compile`; Critical Requirements MUST NOT items 2-4 are all
  compile/PDF-centric.
- `skills/skill-typst-implementation/SKILL.md` has **no** content-level MUST NOT items — its only
  MUST NOT list is a postflight-boundary division-of-labor list. Its Stage 5b self-execution
  fallback authors `.typ` files *without* passing through the agent's Stage 4C, which is precisely
  why the gate must be installed in both files rather than the agent alone.
- `index-entries.json` (529 lines, `{"entries": [...]}`) — every `project/typst/standards/*` entry
  uses the identical shape (`path`, `line_count`, `load_when.agents`, `load_when.task_types`,
  `domain`, `subdomain`, `summary`, `keywords`), which the new entry copies verbatim.

The report's falsified-hypothesis framing governs Phase 5: `chapter-template.md`'s checklist
already requires "Opening paragraph explaining chapter purpose", the agent already loads that file,
and the defect landed anyway. Passive checklist prose is a proven-insufficient terminus for this
work.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap path was provided in this dispatch; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:
- A reader of the new standard can answer, for each semantic element (definition, theorem, lemma,
  corollary, example, proof, remark, `rule-block`, `rule-list`), what it is for, its expected
  density, and where it may legally appear — without consulting the originating conversation.
- The remark norm is stated in a form that would have flagged the observed 25-item
  chapter-opening checklist on both counts (chapter-opener placement AND enumerated status list).
- Enumerated formalization-status / tracking content is given a stated legal home, not merely a
  prohibition.
- The new standard reaches `typst-implementation-agent` through `index-entries.json`.
- The agent and the skill each carry an executed structural self-review step plus explicit,
  enforceable MUST NOT items naming the standard — not one more checklist line.

**Non-Goals**:
- Editing `typst/manual/chapters/08-agency.typ` or any chapter in the Logos/Theory repository.
  Document remediation is the user's, after reloading the improved extension.
- Editing anything under `.claude/**` (regenerated deploy artifact).
- Rewriting `theorem-environments.md` or `chapter-template.md` beyond the precise additions named
  in Phases 3 and 4.
- Adding automated lint scripts or hooks. The gate this task installs is an agent/skill-executed
  self-review step; a mechanical linter is out of scope.
- Adding `typst-research-agent` to the new index entry's `load_when.agents`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The new MUST NOT items become inert prose in the same way the chapter-template checklist item did | H | M | Phase 5 words them as an **executed sub-step inside Stage 4C** ("before marking the phase verified, re-read each authored `.typ` section against `semantic-element-usage.md` and confirm ..."), with the MUST NOT list as reinforcement, never as the sole carrier |
| Agent gate is installed but the skill's Stage 5b self-execution path bypasses it | H | M | Phase 5 edits BOTH files; the skill gets its own labeled subsection (not merged into the postflight-boundary MUST NOT list) scoped to the Stage 5b inline-authoring path |
| Wording drift between the duplicated agent and skill MUST NOT items | M | M | The skill's items cross-reference the agent's Critical Requirements section by name while still stating their own enforceable text; both are authored in one phase so they are written together |
| `line_count` in the new index entry drifts from the authored file | L | H | Phase 2 computes `line_count` with `wc -l` against the file as it exists after Phase 1, never estimates it |
| Scope creep into rewriting unrelated template/pattern content | M | M | Phases 3 and 4 enumerate exactly the additions permitted (one table row, one pointer, one worked example pair) |
| Edits land in `.claude/**` instead of the source store and are silently wiped on next regeneration | H | L | Every phase names absolute source-store paths under `agent-system/extensions/typst/**`; Phase 6 greps the diff to confirm no `.claude/**` path was written |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5 | 1 |
| 3 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Author the Semantic Element Usage Standard [COMPLETED]

**Goal**: Create the missing semantics layer — a single standard stating, per semantic element,
what it is for, its expected density, and its legal placement.

**Tasks**:
- [x] Create `agent-system/extensions/typst/context/project/typst/standards/semantic-element-usage.md` *(completed)*
- [x] Write a short preamble stating the file's scope: these elements are rhetorical commitments,
      not decorations; `typst compile` has no opinion on any of them *(completed)*
- [x] Write a **Universal Placement Rule** section applying to every element: a semantic element
      MUST NOT be the first body content after a heading with no intervening prose. Every heading
      opens with prose that states what the section is about; elements come after that prose *(completed)*
- [x] Write one subsection per element, each with three labeled parts — **What it is for**,
      **Expected density**, **Legal placement** — covering: `definition`, `theorem`, `lemma`,
      `corollary`, `example`, `proof`, `remark`, and `rule-block` / `rule-list` from
      `patterns/rule-environments.md` *(completed: also covers corollary, confirmed present via cor: label prefix)*
- [x] Encode the user's remark norm in substance, close to its original wording: remarks are for
      SPARING, high-value OFF-TOPIC points or big-picture reflections on the current development;
      they typically FOLLOW some substantial result; a remark is never a chapter opener and never
      a long enumerated status/tracking list *(completed)*
- [x] Add a **Where tracking content belongs** section: enumerated formalization-status /
      completion-tracking checklists are task-management material and belong in `specs/**` task
      artifacts; if they must live in the document at all, an appendix or a dedicated status
      section — never chapter-opening body prose, never inside a `#remark` *(completed)*
- [x] Add a **Worked contrast** section with an explicit INCORRECT example (a `#remark` carrying an
      enumerated status list immediately under a chapter heading) and its CORRECT counterpart
      (opening prose; result; then a short reflective remark), matching the Correct/Incorrect
      style already used in `standards/textbook-standards.md` *(completed)*
- [x] Add a closing **Self-review questions** list the agent and skill can execute verbatim at
      Phase 5's gate (one question per prohibition) *(completed)*
- [x] Cross-reference `standards/type-theory-foundations.md` as the narrow, pre-existing instance
      of the same sparingness principle, so the two are not read as competing rules *(completed)*

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts the standard covers **nine** elements (definition,
theorem, lemma, corollary, example, proof, remark, `rule-block`, `rule-list`). The implementer
must confirm the actual element set by reading `patterns/theorem-environments.md` (the `#let`
bindings block) and `patterns/rule-environments.md` before writing, and cover whatever set those
two files actually define — the count above is a hypothesis, not a fact. Any element defined
there but absent from the draft is a defect.

**Files to modify**:
- `agent-system/extensions/typst/context/project/typst/standards/semantic-element-usage.md` - new file

**Verification**:
- File exists and is non-empty; every element defined in `theorem-environments.md` and
  `rule-environments.md` has its own subsection with all three labeled parts
- Read the standard cold and answer, for `#remark`: what is it for, how often, where may it
  appear. All three answerable from the file alone
- Confirm the file's stated rule would flag BOTH defects in the observed document: element as
  first body content after a heading, and enumerated status list inside a remark

---

### Phase 2: Wire the Standard into the Context Index [NOT STARTED]

**Goal**: Make the new standard actually reach `typst-implementation-agent` at spawn.

**Tasks**:
- [ ] Compute the authored file's line count: `wc -l` on the Phase 1 output
- [ ] Append one entry to `agent-system/extensions/typst/index-entries.json`, adjacent to the
      `project/typst/standards/type-theory-foundations.md` entry, copying the sibling shape
      exactly: `path`, `line_count`, `load_when.agents`, `load_when.task_types`, `domain`,
      `subdomain`, `summary`, `keywords`
- [ ] Set `load_when.agents` to `["typst-implementation-agent"]` and `load_when.task_types` to
      `["typst"]`
- [ ] Set `keywords` to include the terms research found missing from the deployed index:
      `semantics`, `usage`, `remark`, `placement`, alongside `typst`
- [ ] Validate the file parses: `python3 -c "import json; json.load(open('index-entries.json'))"`
- [ ] Add a one-line pointer to `context/project/typst/README.md`'s "Key Files" list naming the
      new standard, consistent with how sibling standards are listed there

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly **one** new JSON entry and **one** new README
line. The implementer must confirm no sibling entry for this path already exists (grep the JSON
for `semantic-element-usage`) before appending, and confirm the entry count increases by exactly
one.

**Files to modify**:
- `agent-system/extensions/typst/index-entries.json` - append one entry
- `agent-system/extensions/typst/context/project/typst/README.md` - one Key Files line

**Verification**:
- `json.load` succeeds; entry count is prior count + 1
- The new entry's `line_count` equals `wc -l` of the Phase 1 file
- `load_when.agents` contains `typst-implementation-agent` (this is the delivery mechanism; per
  the retrieved memory, `load_when` arrays are the actual enforcement, not tier labels)

---

### Phase 3: Give theorem-environments.md the Semantics It Lacks [NOT STARTED]

**Goal**: Close the two concrete gaps in the mechanics file without turning it into a second copy
of the standard.

**Tasks**:
- [ ] Add a `rem:` row to the Label Conventions table in
      `context/project/typst/patterns/theorem-environments.md` (the table currently has `thm:`,
      `lem:`, `def:`, `cor:`, `ex:` and omits `rem:` entirely)
- [ ] Add a short **Semantics** section near the top of the file (after the `#let` bindings block)
      stating in two or three sentences that this file documents mechanics only, and that what
      each environment is FOR, how sparingly to use it, and where it may appear are governed by
      `standards/semantic-element-usage.md` — with an explicit path pointer
- [ ] Inline the single most load-bearing rule at the pointer so the file is not merely a
      redirect: a semantic element is never the first body content after a heading
- [ ] Do not otherwise restructure the file

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/typst/context/project/typst/patterns/theorem-environments.md` - add
  `rem:` table row and a Semantics pointer section

**Verification**:
- The Label Conventions table contains a `rem:` row mapping to Remark
- The file names `standards/semantic-element-usage.md` by path
- File length grew by roughly 8-12 lines; no existing section was rewritten or removed

---

### Phase 4: Model Correct Remark Placement in the Chapter Template [NOT STARTED]

**Goal**: Make the template demonstrate the norm in situ rather than leaving it unstated, so the
positive pattern is visible where chapters are actually drafted.

**Tasks**:
- [ ] In `context/project/typst/templates/chapter-template.md`, add a worked example showing a
      `#theorem[...]` (or `#definition`) followed by `#proof[...]`, followed immediately by a
      short `#remark[...]` that reflects on the result just established — the "remark follows a
      substantial result" pattern
- [ ] Label the correct example explicitly (e.g. `**Correct**`) and pair it with a labeled
      INCORRECT counterexample showing a `#remark` as the first content after a chapter heading,
      carrying an enumerated status list
- [ ] Confirm the existing `#remark[...]` under `== Multi-Agent Modality` in "Example: Minimal
      Chapter" either gains a preceding substantial result or is not left standing as the
      template's only remark model (research found it is not a valid positive example as written)
- [ ] Extend the "Checklist for New Chapters" with an item referencing the new standard by path
      — as reinforcement of Phase 5's gate, explicitly NOT as this task's enforcement mechanism
- [ ] Do not otherwise restructure the template

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/typst/context/project/typst/templates/chapter-template.md` - add
  Correct/Incorrect remark-placement example pair; one checklist line

**Verification**:
- The template contains a remark that follows a theorem/proof pair
- The template contains a labeled incorrect example matching the observed defect shape
- The template no longer presents a heading-adjacent remark as an unqualified model

---

### Phase 5: Install the Structural Gate in the Agent and Skill [NOT STARTED]

**Goal**: Stop compile-green from being the sole verification. This is the phase the task's
acceptance actually turns on — the falsified hypothesis is that prose guidance alone changes
behavior, so this phase must produce an executed step, not another checklist line.

**Tasks**:
- [ ] In `agents/typst-implementation-agent.md`, extend Stage 4 step **C. Verify Phase
      Completion** (currently only "Compilation must succeed / All specified files must exist")
      with an explicit **Structural self-review** sub-step: before marking the phase verified,
      re-read each `.typ` section authored or modified in this phase against
      `standards/semantic-element-usage.md` and answer that standard's self-review questions,
      naming the file by path
- [ ] Word the sub-step as an action with a stated output (confirm each question, name any
      violation found and the fix applied), not as a passive reminder
- [ ] Add to the agent's **Critical Requirements** MUST NOT list at minimum: (a) MUST NOT leave a
      semantic element standing as the first body content after a chapter or section heading with
      no intervening prose; (b) MUST NOT place a long enumerated status/tracking checklist inside
      a `#remark` (or any semantic element) — that content belongs in task artifacts, an appendix,
      or a dedicated status section
- [ ] Add to the agent's MUST DO list: perform the Stage 4C structural self-review before marking
      any phase complete
- [ ] In `skills/skill-typst-implementation/SKILL.md`, add a new labeled subsection —
      **MUST NOT (Document Structure)**, separate from the existing "MUST NOT (Postflight
      Boundary)" list so the content-gate and division-of-labor concerns are not conflated —
      carrying the same two enforceable items, scoped to the Stage 5b self-execution fallback path
      where the skill authors `.typ` files inline and never passes through the agent's Stage 4C
- [ ] Have the skill's subsection cross-reference the agent's Critical Requirements section by
      name to limit future drift, while still stating its own enforceable items rather than being
      a bare pointer
- [ ] Add a corresponding self-review step to the skill's Stage 5b fallback description so the
      inline path executes the check, not merely declares it

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts **two** files edited and **at least two** new MUST NOT
items per file. The implementer must confirm, by reading both files, that no other execution path
authors `.typ` content — in particular re-read
`agent-system/extensions/core/context/patterns/skill-self-execution-fallback.md` to confirm
Stage 5b is the only agent-bypassing authoring path. If a third path exists, it needs the same
gate and the phase's file list grows.

**Files to modify**:
- `agent-system/extensions/typst/agents/typst-implementation-agent.md` - Stage 4C self-review
  sub-step; MUST DO and MUST NOT additions
- `agent-system/extensions/typst/skills/skill-typst-implementation/SKILL.md` - new
  MUST NOT (Document Structure) subsection; Stage 5b self-review step

**Verification**:
- Stage 4C names `semantic-element-usage.md` and describes an executed check with an output, not
  a reminder
- Both files carry the heading-adjacency prohibition and the enumerated-status-list prohibition
- The skill's new subsection is distinct from its postflight-boundary MUST NOT list
- Trace the observed defect against the edited agent text: a chapter-opening
  `#remark("Formalization Status")` with a 25-item list is caught by a named MUST NOT item and by
  the Stage 4C check, in both the agent path and the Stage 5b path

---

### Phase 6: Acceptance Verification Against the Observed Defect [NOT STARTED]

**Goal**: Confirm the delivered contract would actually have flagged the document that motivated
it, and that nothing landed in the deploy artifact.

**Tasks**:
- [ ] Re-read the new standard cold and answer, for every covered element, "what is it for" and
      "where may it appear" using only the file — the task's stated acceptance criterion
- [ ] Walk the observed defect (a `#remark("Formalization Status")[...]` with a 25-item numbered
      checklist and label `<rem-agency-status>`, standing immediately after `= Agency <sec-agency>`
      with no intervening prose) against each of: the standard, the agent's Stage 4C, the agent's
      MUST NOT list, and the skill's new subsection. Record which specific rule catches it in each
    location
- [ ] Confirm the enumerated-tracking-content question "where does this belong instead" has an
      explicit answer in the standard
- [ ] `git status --short` and the staged diff: confirm no path under `.claude/**` was written and
      no `.typ` file anywhere was modified
- [ ] Validate `index-entries.json` parses and the new entry's `line_count` still matches the
      final file after all Phase 1-5 edits
- [ ] Run the repository's applicable lints/gates for changed markdown and JSON (including the
      task-reference check for files outside `specs/**`)

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: full

**Files to modify**:
- None (verification only; corrective edits to Phase 1-5 files permitted if a check fails)

**Verification**:
- Every acceptance clause in the task description maps to a named location in the delivered files
- No `.claude/**` or `.typ` path appears in the diff
- JSON valid; `line_count` accurate

---

## Testing & Validation

- [ ] `semantic-element-usage.md` exists and covers every element defined in
      `theorem-environments.md` and `rule-environments.md`, each with purpose, density, and
      placement
- [ ] The remark norm as written flags both the chapter-opener placement and the enumerated
      status list of the motivating defect
- [ ] Enumerated tracking content has a stated legal home in the standard
- [ ] `theorem-environments.md` Label Conventions table has a `rem:` row
- [ ] `chapter-template.md` shows a remark following a substantial result, plus a labeled
      anti-pattern
- [ ] `index-entries.json` parses; new entry present with `typst-implementation-agent` in
      `load_when.agents` and an accurate `line_count`
- [ ] `typst-implementation-agent.md` Stage 4C carries an executed structural self-review naming
      the standard, and the MUST NOT list carries both prohibitions
- [ ] `skill-typst-implementation/SKILL.md` carries the same prohibitions in a subsection distinct
      from the postflight-boundary list, plus a Stage 5b self-review step
- [ ] No file under `.claude/**` modified; no `.typ` file modified
- [ ] Task-reference lint passes for all changed files outside `specs/**`

## Artifacts & Outputs

- `agent-system/extensions/typst/context/project/typst/standards/semantic-element-usage.md` (new)
- `agent-system/extensions/typst/index-entries.json` (one appended entry)
- `agent-system/extensions/typst/context/project/typst/README.md` (one Key Files line)
- `agent-system/extensions/typst/context/project/typst/patterns/theorem-environments.md` (`rem:`
  row + Semantics pointer)
- `agent-system/extensions/typst/context/project/typst/templates/chapter-template.md`
  (Correct/Incorrect remark example pair + checklist line)
- `agent-system/extensions/typst/agents/typst-implementation-agent.md` (Stage 4C self-review,
  MUST DO / MUST NOT additions)
- `agent-system/extensions/typst/skills/skill-typst-implementation/SKILL.md` (MUST NOT (Document
  Structure) subsection + Stage 5b self-review step)
- `specs/178_typst_semantic_element_usage_contract/summaries/01_*-summary.md` (implementation
  summary)

## Rollback/Contingency

Every change is additive markdown/JSON in a single extension directory tree, committed per phase.
Rollback is `git revert` of the phase commits, or deleting the one new file and reverting the six
edited files. Nothing here is generated into `.claude/**` by this task; a subsequent extension
reload regenerates the deploy tree from whatever the source store holds, so reverting the source
store is a complete rollback. No `.typ` document, no compiled PDF, and no downstream repository is
touched, so there is no external artifact to unwind.
