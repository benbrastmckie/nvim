# Research Report: Task #178

**Task**: 178 - Author the missing semantics layer for the typst extension's semantic elements, and wire it into the implementation agent and skill as an actual structural gate
**Started**: 2026-09-07T00:00:00Z
**Completed**: 2026-09-07T00:00:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/typst/**` (source store, global root `/home/benjamin/.config/nvim`)
- Dispatch file: `specs/178_typst_semantic_element_usage_contract/.dispatch/2.md`
**Artifacts**:
- This report: `specs/178_typst_semantic_element_usage_contract/reports/01_semantic-element-usage-contract.md`
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- Confirmed all five audit claims in the dispatch against the live source-store files: `theorem-environments.md` (74 lines) is mechanics-only, has no `rem:` row in its Label Conventions table, and there is no file anywhere under `context/project/typst/**` that states what any semantic element (definition/theorem/lemma/example/proof/remark/rule-block/rule-list) is *for*, its density, or its legal placement.
- The only existing sparingness norm ("Do NOT add DTT remarks to every definition... strategic placement, not exhaustive annotation") lives in `standards/type-theory-foundations.md` lines 63-201 and is explicitly scoped to DTT annotation remarks only — it does not generalize and is not cross-referenced from `theorem-environments.md`.
- `templates/chapter-template.md`'s existing `#remark[...]` in its "Example: Minimal Chapter" section is **not** a positive model of the user's norm: it appears directly under a `== Multi-Agent Modality` heading with no substantial preceding result in that subsection, and the template's "Checklist for New Chapters" already required "Opening paragraph explaining chapter purpose" — a checklist item the observed `08-agency.typ` defect violated directly, proving unenforced checklist prose does not change agent behavior.
- The only verification gate in `agents/typst-implementation-agent.md` is Stage 4C ("Compilation must succeed. All specified files must exist") and Stage 5 (`typst compile`); Critical Requirements MUST NOT items 2-4 are all compile/PDF-centric. No structural/rhetorical check exists in the agent, and `skills/skill-typst-implementation/SKILL.md` has no content-level MUST NOT items at all (only postflight-boundary MUST NOTs about not doing agent work).
- `index-entries.json` has 26 entries; every sibling entry under `project/typst/standards/*` follows a uniform shape (`path`, `line_count`, `load_when.agents`, `load_when.task_types: ["typst"]`, `domain`, `subdomain`, `summary`, `keywords`) that a new `semantic-element-usage.md` entry should copy exactly.
- Recommendation: the planner should treat this as five concrete, independently-verifiable edits (A-E as scoped in the dispatch), landing entirely under `agent-system/extensions/typst/**`. No `.typ` files are touched; there is nothing to compile, so no `typst compile` verification step applies to this task's own acceptance criteria.

## Context & Scope

This is a `meta` task type (per dispatch Identity: `task_type: meta`). It authors and wires
markdown/JSON governance content for the `typst` extension — it does not touch any `.typ`
document. The research scope was: (1) verify the audit's five factual claims against the current
file contents, since the dispatch explicitly forbids re-litigating already-established facts but
a research phase must still confirm they still hold; (2) locate every integration point named in
scope items A-E so the plan can cite exact line ranges / edit anchors; (3) determine the correct
`index-entries.json` entry shape by example; (4) determine what a "positive remark placement
example" needs to look like structurally, given the existing chapter-template example does not
already satisfy it.

Out of scope (per dispatch): editing any `.typ` file in the Logos/Theory repository; editing
anything under `.claude/**` (deploy artifact — edits belong in `agent-system/extensions/**`,
see `rules/source-store-deploy-boundary.md`).

## Findings

### Codebase Patterns

**`patterns/theorem-environments.md`** (74 lines, confirmed via `wc`/`cat`):
- Line 16 defines `#let remark = thmbox("rem", "Remark", color: gray)` inside the "Using thmbox
  Package" section — purely a mechanical `#let` binding, no commentary.
- Sections present, in order: "Using thmbox Package", "Usage" (Basic/Named/Labeled), "Proofs",
  "Custom Styling", "Label Conventions" (a 5-row table: `thm:`, `lem:`, `def:`, `cor:`, `ex:` —
  `rem:` is absent, confirming audit claim 1's second half).
- Zero mentions of purpose, density, or placement for any environment. This is the file scope
  item B targets.

**`patterns/rule-environments.md`** (the sibling file the dispatch says must also be covered by
the new standard, scope A): defines `rule-block` and `rule-list` for typing/inference rules. It
already has a "When to Use" / "Do NOT use for" section (its own local semantics), but this is
scoped to rule presentation only and says nothing about density or heading-adjacency norms. The
new standard should reference these two functions alongside definition/theorem/lemma/example/
proof/remark, per scope A's explicit instruction to "cover ... the elements in
`patterns/rule-environments.md`."

**`standards/type-theory-foundations.md`** (203 lines): the sparingness precedent lives at lines
63-201 ("Layer 3: Strategic DTT Highlights" through "Avoid Over-Verbosity" through the Quality
Checklist item "DTT remarks placed strategically, not exhaustively" at line 201). Verbatim
sparingness language: *"Do NOT add DTT remarks to every definition. The goal is strategic
placement, not exhaustive annotation."* (line 163) and *"The type-theoretic interpretation is
clear from the preface convention; no per-definition remark is needed for standard material."*
(line 185). This is scoped narrowly to DTT annotation remarks connecting to Lean/implementation
material — it does not state anything about remarks in general, and nothing in this file or
elsewhere generalizes it. Confirms audit claim 3 exactly.

**`templates/chapter-template.md`** (checked in full): the "Checklist for New Chapters" section's
first content bullet is literally `- [ ] Opening paragraph explaining chapter purpose`. This
directly maps to the observed defect (a `#remark` block standing in place of that opening
paragraph) and is the concrete evidence the dispatch's falsified-hypothesis argument rests on: an
unenforced checklist bullet, loaded into the agent's context via `index-entries.json`, did not
prevent the violation it names. The template's own worked example ("Example: Minimal Chapter")
contains:
```typst
== Multi-Agent Modality

Another extension adds agent-indexed modalities.

#remark[
  Multi-agent extensions require careful treatment of common knowledge.
]
```
This remark follows one sentence of section-opening prose, not "some substantial result" (no
theorem, proof, or definition precedes it in that subsection) — it is closer to a side-note than
the "follows a substantial result" pattern the dispatch's scope item C requires modeling. A new
positive example needs a `#theorem`/`#proof` (or comparable substantial result) immediately
preceding the `#remark`, to actually demonstrate the norm rather than merely gesture at it.

**`agents/typst-implementation-agent.md`** (174 lines): Stage 4 "Execute Typst Development
Loop" step C, "Verify Phase Completion" (lines 92-94), reads only:
```
**C. Verify Phase Completion**
- Compilation must succeed
- All specified files must exist
```
Stage 5 "Final Compilation Verification" (lines 122-125) runs `typst compile document.typ`.
Critical Requirements (lines 159-175): MUST DO includes "Run `typst compile` to verify
compilation" and "Include PDF in artifacts if compilation succeeds"; MUST NOT items 2-4 are
"Mark completed without successful compilation", "Skip compilation verification", "Return
completed if PDF doesn't exist". None of these items can catch a document that compiles
successfully but places a `#remark` as chapter-opening content or embeds a long enumerated status
list inside one — `typst compile` has no opinion on rhetorical structure. This confirms audit
claim 4. Scope item E's target anchors are: Stage 4C (add a structural self-review step) and the
Critical Requirements MUST NOT list (add explicit items).

**`skills/skill-typst-implementation/SKILL.md`** (111 lines): a thin wrapper. Its only MUST NOT
list (lines 86-95, "MUST NOT (Postflight Boundary)") governs what the *skill* must not do after
the agent returns (edit `.typ` files, run compile, analyze source, write summaries) — it is about
division of labor between skill and agent, not about document quality. There is currently no
content-level structural gate anywhere in this file. Critically, `skill-self-execution-fallback.md`
(imported at SKILL.md Stage 5b) describes a real fallback path where the *skill's own execution
context* (not the subagent) performs the `.typ` writes directly, bypassing
`typst-implementation-agent.md`'s Stage 4C entirely. This is why the dispatch requires wiring the
same MUST NOT items into SKILL.md as well as the agent file — the agent's Stage 4C alone does not
cover the self-execution fallback path.

**`index-entries.json`** (26 entries, verified via `python3 -m json.load`): the entry for
`project/typst/patterns/theorem-environments.md` is:
```json
{
  "path": "project/typst/patterns/theorem-environments.md",
  "line_count": 74,
  "load_when": { "agents": ["typst-implementation-agent"], "task_types": ["typst"] },
  "domain": "project",
  "subdomain": "typst",
  "summary": "Theorem, definition, and proof environments",
  "keywords": ["typst", "theorems", "environments"]
}
```
All four `project/typst/standards/*.md` sibling entries follow the identical shape (verified
for `document-structure.md`, `notation-conventions.md`, `textbook-standards.md`,
`typst-style-guide.md`, `type-theory-foundations.md`, `compilation-standards.md`,
`package-usage.md`). Two of these (`textbook-standards.md`, `typst-style-guide.md`,
`package-usage.md`) list both `typst-implementation-agent` and `typst-research-agent` under
`load_when.agents`; the rest list only `typst-implementation-agent`. Since the new standard is
primarily an enforcement/authoring concern (not a research concern), `typst-implementation-agent`
alone matches the majority pattern and is sufficient per the dispatch's explicit requirement
("`load_when.agents` including typst-implementation-agent, following the shape of sibling
entries") — the dispatch does not require `typst-research-agent`, but the plan/implementer should
note this is a judgment call, not a hard constraint either way. `line_count` must be computed
from the actual authored file at implementation time (this report does not fix that number since
the standard has not been written yet).

### External Resources

Not applicable — this is a closed, self-contained governance-content task entirely internal to
the `typst` extension's own conventions. No web research was performed; the dispatch and the
existing extension files are the complete and authoritative source of truth (`typst compile`
semantics themselves are irrelevant to this task, since it produces no `.typ` output).

### Recommendations

1. **New standard file** at `agent-system/extensions/typst/context/project/typst/standards/semantic-element-usage.md`. Per-element sections (definition, theorem, lemma, example, proof, remark, rule-block/rule-list) each stating: what it's for, expected density (e.g., "one per major result", vs. remark's "sparing — after a substantial result, not a chapter opener"), and legal placement (explicitly: never as the first body content immediately after a heading, with no intervening prose). Encode the remark norm using language close to the dispatch's own wording ("Remarks are for sparing, high-value off-topic points, or big-picture reflections on the current development, and they typically follow some substantial result. A remark is never a chapter opener, and never a long enumerated status/tracking list.") so the acceptance criterion ("stated in a form that would have flagged the observed 25-item chapter-opening checklist") is met literally. Add an explicit statement of where enumerated formalization-status/tracking content belongs instead — task-management material (i.e., `specs/**`, not chapter body), or at most an appendix/dedicated status section — since the dispatch requires this content have a stated legal home, not just a prohibition.
2. **`patterns/theorem-environments.md`**: add a `rem:` row to the Label Conventions table; add a short semantics pointer/cross-reference to the new standard (the file's own scope per its title should probably stay mechanics-focused, with a one-line pointer, consistent with how `type-theory-foundations.md` currently owns the one existing sparingness rule rather than duplicating it in `theorem-environments.md`).
3. **`templates/chapter-template.md`**: add a second worked example (or extend the existing "Example: Minimal Chapter") showing a `#theorem`/`#proof` pair immediately followed by a `#remark[...]` that reflects on the result just proved — a structurally correct positive model, contrasted implicitly (or explicitly, via a short "Correct" vs. "Incorrect" pair matching the style already used in `standards/textbook-standards.md`'s Formatting Guidelines section) against a chapter-opening remark anti-pattern.
4. **`index-entries.json`**: append one new entry after (or near) the `type-theory-foundations.md` entry, following the exact sibling shape documented above, with `load_when.agents: ["typst-implementation-agent"]` and `load_when.task_types: ["typst"]`.
5. **`agents/typst-implementation-agent.md`**: extend Stage 4C ("Verify Phase Completion") with an explicit structural self-review sub-step referencing the new standard by name/path, and add at least two new MUST NOT items to the Critical Requirements list: (a) forbid a semantic element standing as the first body content after a chapter heading with no intervening prose, (b) forbid a long enumerated status/tracking list inside a `#remark`. These should be worded as agent self-checks performed during/after Stage 4B (file authoring), not merely compile-time checks, since `typst compile` cannot detect them.
6. **`skills/skill-typst-implementation/SKILL.md`**: add the same two MUST NOT items (or a cross-reference to the agent's list) scoped to the self-execution fallback path (Stage 5b), so a skill-level inline authoring pass carries the same structural gate the agent carries. This is additive to, not a replacement for, the existing postflight-boundary MUST NOT list — it should live in its own labeled subsection so it isn't confused with the postflight-boundary content-vs-process distinction already documented there.

## Decisions

- The new standard file is authored under `standards/`, not `patterns/`, matching the dispatch's own explicit path (`.../standards/semantic-element-usage.md`) and the existing domain convention that `standards/` holds "what/why" governance content while `patterns/` holds "how" mechanics (consistent with `type-theory-foundations.md` and `textbook-standards.md` both living in `standards/`).
- `load_when.agents` for the new index entry is `["typst-implementation-agent"]` only (not also `typst-research-agent`), matching the majority pattern among `standards/*` entries and the dispatch's literal requirement; this is a low-stakes judgment call the plan may revisit without re-researching.
- The positive remark example belongs in `chapter-template.md` (scope item C explicitly names this file), not in the new standard itself — the standard states the rule in prose; the template demonstrates it in situ, mirroring how `type-theory-foundations.md`'s "Pattern" code blocks already pair rule statements with `typst` snippets.

## Risks & Mitigations

- **Risk**: the new MUST NOT items in `typst-implementation-agent.md` are unenforceable in the same way the chapter-template checklist item was (prose the agent can silently skip). **Mitigation**: word them as an explicit self-review sub-step inside Stage 4C ("before marking Verify Phase Completion, re-read each newly authored/modified `.typ` section against `semantic-element-usage.md` and confirm: ...") rather than only as a passive MUST NOT list entry — the dispatch's own falsified-hypothesis argument is specifically that passive prose without a checked step failed once already.
- **Risk**: duplicating the MUST NOT wording verbatim across two files (agent + skill) risks drift if one is edited later without the other. **Mitigation**: plan should have the skill's version cross-reference the agent's Critical Requirements section by name rather than re-deriving independent wording, where practical, while still satisfying the dispatch's requirement that the skill carry its own enforceable items (not just a pointer) for its self-execution fallback path.
- **Risk**: scope creep into rewriting unrelated parts of `theorem-environments.md` or `chapter-template.md`. **Mitigation**: the plan should scope edits precisely to the table row, semantics pointer, and one new worked example, per the dispatch's exact scope items B and C.

## Context Extension Recommendations

- **Topic**: Semantic element usage/rhetorical-structure norms for the typst extension.
- **Gap**: No file under `context/project/typst/**` (or the deployed `.claude/context/index.json`) currently carries `keywords` like `semantics`, `usage`, `remark`, or `placement` for the typst subdomain — confirmed by grepping the deployed index for those terms and finding no hits. This is exactly the gap this task's scope item A closes.
- **Recommendation**: this task itself is the fix; no further context-extension task is needed beyond what scope A-E already specifies.

## Appendix

- Files read in full: `patterns/theorem-environments.md`, `patterns/rule-environments.md`,
  `templates/chapter-template.md`, `standards/textbook-standards.md` (grep + full read),
  `standards/type-theory-foundations.md` (targeted grep on `remark`/`sparing`),
  `agents/typst-implementation-agent.md` (Stage 60-175), `skills/skill-typst-implementation/SKILL.md`
  (full), `agent-system/extensions/core/context/patterns/skill-self-execution-fallback.md` (full),
  `standards/document-structure.md` (partial, to rule out overlap).
- Commands used: `find`, `grep -n`, `python3 -c "import json; json.load(...)"` to enumerate and
  validate `index-entries.json` entries and confirm the sibling-entry shape; `jq` against
  `.claude/context/index.json` to confirm no existing `semantics`/`remark`/`usage` keyword
  coverage for the typst subdomain.
- No WebSearch/WebFetch used — task is entirely internal-codebase governance content.
