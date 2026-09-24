# Implementation Plan: Task #253

- **Task**: 253 - Define the Typst chapter-quality standard across the four dimensions, with per-rule blocking/advisory and mechanical/judged classification
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/253_typst_chapter_quality_standard/reports/01_chapter-quality-standard-research.md
- **Artifacts**: plans/01_chapter-quality-standard.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/no-task-references-in-deliverables.md
  - .claude/rules/source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This task produces exactly one file — `agent-system/extensions/typst/context/project/typst/standards/chapter-quality.md` in the **source store**, never under `.claude/**` — defining the measurable quality bar for hand-built Typst manual chapters. The standard fixes four settled dimensions (SOURCE GROUNDING, ANTI-FLUFF DENSITY, PRESENTATION CLARITY, OPEN-QUESTION HONESTY), dual-tags every individual rule on two independent axes (BLOCKING-or-ADVISORY and MECHANICAL-or-JUDGED), defers explicitly to three adjacent existing standards rather than restating them, defines an interface contract for two repo-local checks it must not implement, and records a load-bearing rationale section. Definition of done: all eight acceptance criteria in the task description verify green against the written file, and no other file in the repository is modified.

### Research Integration

The research report is unusually complete for this task: it already drafts the full 15-rule inventory (5 + 3 + 4 + 3) with both axis tags and per-rule ownership notes, drafts the interface contract's finding-record shape, and verifies the consuming checker's expectations against this dispatch. The implementation phases below transcribe that inventory and add the rationale prose around it; they are deliberately not a second design pass. Key research findings carried into the plan:

- The severity-split rationale already exists verbatim in this extension at `agent-system/extensions/typst/scripts/typst-element-lint.sh` (header, "SEVERITY SPLIT" block, ~lines 32-38). The standard restates that reasoning rather than inventing a new one.
- No `CONFIRM` comment convention exists anywhere in the repository today. SOURCE GROUNDING must **define** it, not reference one.
- `document-structure.md` already constrains heading depth ("one `=` per chapter", "`===` … use sparingly"), which is why PRESENTATION CLARITY's heading-depth bound can be BLOCKING without being an unreviewed fresh threshold.
- `textbook-standards.md`'s existing "Quality Checklist" (8 items) is the closest existing analogue; the new standard becomes the authoritative quality bar while `textbook-standards.md` keeps ownership of the underlying content conventions.

### Prior Plan Reference

No prior plan. This is the first planning round for this task.

### Roadmap Alignment

No ROADMAP.md found at `specs/ROADMAP.md`; no roadmap phases apply.

## Goals & Non-Goals

**Goals**:
- Produce `agent-system/extensions/typst/context/project/typst/standards/chapter-quality.md` with exactly the four settled dimensions, named exactly as specified.
- Give every one of the ~15 rules an explicit BLOCKING-or-ADVISORY tag and an explicit MECHANICAL-or-JUDGED tag, stated in the rule's own entry (not inferred from a section heading).
- Tag every ANTI-FLUFF DENSITY rule ADVISORY, with the standard stating per-rule that the dimension never blocks.
- State, for every threshold introduced without a corpus observation behind it, that it is unreviewed and therefore ADVISORY on first release.
- Cross-reference `textbook-standards.md`, `semantic-element-usage.md`, and `notation-conventions.md`, each with an explicit statement of what is deferred rather than restated, and an explicit ownership resolution where both could be read as owning a rule.
- Define an interface contract (not an implementation) for the consuming repository's name-resolution check and chapter-source coverage check.
- Record a rationale section that preserves why each dimension exists, including the OPEN-QUESTION HONESTY reasoning in full.

**Non-Goals**:
- Implementing `chapter-quality-check.sh` or any mechanical checker. That is the dependent task's scope.
- Writing or modifying the two repo-local checks (name-resolution, chapter-source coverage), or shelling out to them.
- Registering the new standard in `agent-system/extensions/typst/index-entries.json`, or any agent/`load_when` wiring. The deliverable is exactly one file; wiring belongs to the dependent checker task.
- Redesigning, renaming, merging, reordering, or extending the four dimensions.
- Any write under `.claude/**` (a disposable deploy artifact regenerated from the source store).
- Editing `textbook-standards.md`, `semantic-element-usage.md`, or `notation-conventions.md` to remove their now-deferred-to content.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A rule lands with only one of its two required tags, silently failing acceptance criterion 3 | H | M | Phase 5 runs an explicit per-rule tag sweep (count rules, count BLOCKING/ADVISORY tags, count MECHANICAL/JUDGED tags; all three counts must be equal) rather than an eyeball pass |
| Deliverable written under `.claude/**` instead of the source store | H | L | Phase 1 creates the file at the source-store path and Phase 5 greps `.claude/` for any `chapter-quality.md`; `.claude/rules/source-store-deploy-boundary.md` is cited in the plan metadata |
| A rule restates rather than defers to an existing standard, creating two drifting owners | M | M | Phase 4 is a dedicated ownership-resolution pass; each of the three cross-references must name what is deferred AND which file owns the rule |
| An ANTI-FLUFF rule accidentally tagged BLOCKING | H | L | Phase 2 tags all three ADVISORY inline; Phase 5 asserts zero BLOCKING occurrences inside the ANTI-FLUFF DENSITY section |
| A task-number reference leaks into the deliverable | M | L | Phase 5 greps the file for `task [0-9]`/`#[0-9]` patterns; cross-references use durable anchors (filenames, section headings) only |
| Over-specifying the per-repo checks turns the interface contract into an implementation | M | M | Phase 4 writes only: what a conforming check verifies, what record shape it reports, and how its findings compose — explicitly no code, no repo paths beyond the documented `typst/scripts/` convention |
| Backticked cross-reference paths in the new file do not resolve (the `prose` tier's named blind spot) | M | M | Phase 5 extracts every backticked path from the deliverable and tests each against the live tree |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |

All five phases write to the same single file, so the plan is deliberately strictly sequential: there is no wave with two phases in it, and no phase may be run in parallel with another. Phases within the same wave could execute in parallel, but no such wave exists here by design.

---

### Phase 1: Scaffold file and classification vocabulary [NOT STARTED]

**Goal**: Create the deliverable at its settled source-store path with the document skeleton and the two classification axes defined once, up front, so every later rule entry can reference them rather than re-explaining them.

**Tasks**:
- [ ] Create `agent-system/extensions/typst/context/project/typst/standards/chapter-quality.md` with a single `# Chapter Quality Standard` H1, matching the flat `##`-section shape of the eight sibling standards in the same directory
- [ ] Write a `## Scope` section: what this standard measures (a hand-built manual chapter), that it is an agent-system standard deployed to every repo loading the typst extension, and that it is the authoritative chapter-quality bar
- [ ] Write a `## Rule Classification` section defining Axis 1 (BLOCKING vs ADVISORY) — BLOCKING findings alone drive a consuming checker's exit code; ADVISORY findings are reported and counted but never affect exit status
- [ ] In the same section, state the unreviewed-threshold rule: any threshold introduced without a corpus observation behind it is ADVISORY on first release and is labelled unreviewed in its own rule entry
- [ ] In the same section, define Axis 2 (MECHANICAL vs JUDGED) — MECHANICAL is checkable by a shell script without understanding the prose; JUDGED requires a reader, and a conforming checker emits JUDGED rules as a structured prompt for a reviewing agent rather than silently skipping them
- [ ] State the rule-entry format every rule below uses, including that both tags are mandatory and stated in the rule's own entry
- [ ] Add empty `##` headings for the four dimensions, named exactly: `SOURCE GROUNDING`, `ANTI-FLUFF DENSITY`, `PRESENTATION CLARITY`, `OPEN-QUESTION HONESTY` — in that order, with no fifth

**Timing**: 0.4 hours

**Depends on**: none

**Verification Tier**: prose

**Verification**:
- File exists at the source-store path and nowhere under `.claude/**`
- Exactly four dimension headings are present, spelled and ordered exactly as specified
- Both axes are defined before the first dimension section

---

### Phase 2: SOURCE GROUNDING and ANTI-FLUFF DENSITY rules [NOT STARTED]

**Goal**: Write the first two dimensions' rule entries, each dual-tagged, including the standard's own definition of the `CONFIRM` comment convention (which does not pre-exist anywhere in the repository).

**Tasks**:
- [ ] SOURCE GROUNDING — write five rule entries per the research inventory: every substantive claim traces to a cited source (BLOCKING/JUDGED); backticked paths resolve against the live tree (BLOCKING/MECHANICAL); citations resolve in `bibliography.bib` (BLOCKING/MECHANICAL, pointing at `patterns/bibliography.md`); no hand-typed count, version, or hash (BLOCKING/JUDGED); `CONFIRM` comments well-formed (BLOCKING/MECHANICAL)
- [ ] Define the `CONFIRM` comment convention explicitly in the SOURCE GROUNDING section: an inline `// CONFIRM: <claim needing a source>` marker an author writes in place of guessing, so a gap is visible and deferrable rather than silently fabricated; "well-formed" is a syntactic check on the non-empty claim-text payload only, independent of whether the claim later resolves true or false
- [ ] ANTI-FLUFF DENSITY — write three rule entries, each tagged ADVISORY with no exception: claim-to-word ratio threshold (ADVISORY/MECHANICAL, labelled unreviewed); no section without a stated reader need (ADVISORY/JUDGED); hedging and filler connective prose flagged against a seed phrase list (ADVISORY/MECHANICAL, seed list drawn from `textbook-standards.md`'s Professional Tone "Avoid" column, labelled unreviewed and extensible)
- [ ] State explicitly, in each ANTI-FLUFF DENSITY rule entry, that the rule never blocks — a dimension-level note is not sufficient
- [ ] Add a dimension-level preamble to ANTI-FLUFF DENSITY recording that the whole dimension is an advisory score, never a hard gate

**Timing**: 0.6 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: The research report asserts five SOURCE GROUNDING rules and three ANTI-FLUFF DENSITY rules. Confirm at implementation time by counting rule entries written in each section; if a drafted rule proves to be two rules or a duplicate of another, adjust the count and record the deviation in the phase's completion note rather than forcing the drafted number.

**Files to modify**:
- `agent-system/extensions/typst/context/project/typst/standards/chapter-quality.md` — fill the first two dimension sections

**Verification**:
- Every rule entry in both sections carries both an Axis 1 tag and an Axis 2 tag
- Zero occurrences of `BLOCKING` within the ANTI-FLUFF DENSITY section's rule entries
- The `CONFIRM` syntax is defined in the file itself, not merely referenced
- Each rule whose threshold has no corpus observation behind it is labelled unreviewed

---

### Phase 3: PRESENTATION CLARITY and OPEN-QUESTION HONESTY rules [NOT STARTED]

**Goal**: Write the remaining two dimensions' rule entries, with PRESENTATION CLARITY pointing at existing enforcers and owners instead of re-specifying placement or re-deriving a notation model.

**Tasks**:
- [ ] PRESENTATION CLARITY — write four rule entries: every notation symbol / glossary term defined before first use (BLOCKING/JUDGED); heading depth bounded at level 3 `===` (BLOCKING/MECHANICAL); paragraph length bounded (ADVISORY/MECHANICAL, labelled unreviewed); every non-obvious concept introduced has an accompanying example or figure (ADVISORY/JUDGED)
- [ ] In the notation rule, point at `notation-conventions.md`'s two-tier `shared-notation.typ` / `{project}-notation.typ` import pattern as the source of truth for where a symbol's definition is recorded — do not re-derive a second notation model
- [ ] In the heading-depth rule, anchor the bound in `document-structure.md`'s existing level conventions so the rule is a formalization of an existing bound, not a fresh numeric guess — and say so, since that is why it can be BLOCKING
- [ ] Add an explicit note under PRESENTATION CLARITY that element **placement** is out of scope for this standard: the Universal Placement Rule is owned by `semantic-element-usage.md` and already mechanically enforced, BLOCKING, by `scripts/typst-element-lint.sh` check 1. Name the rule and its enforcer; do not re-specify placement
- [ ] OPEN-QUESTION HONESTY — write three rule entries, each BLOCKING/JUDGED: speculative claims explicitly marked (define the marker, and state it is distinct from the `CONFIRM` marker of dimension 1); open questions listed in a discoverable location rather than buried inline; no future-tense claim stated as settled fact
- [ ] For each OPEN-QUESTION HONESTY rule, state why it is JUDGED rather than MECHANICAL (a misclassification as mechanical becomes a false gate downstream; as judged, an unenforced rule) — in particular that future-tense/modal phrase patterns are too unreliable as a standalone mechanical signal

**Timing**: 0.6 hours

**Depends on**: 2

**Verification Tier**: prose

**Scope Hypothesis**: The research report asserts four PRESENTATION CLARITY rules and three OPEN-QUESTION HONESTY rules, for a total of 15 rules across all four dimensions. Confirm at implementation time by counting rule entries across the whole file; report the actual total in the phase completion note rather than asserting 15 without recount.

**Files to modify**:
- `agent-system/extensions/typst/context/project/typst/standards/chapter-quality.md` — fill the remaining two dimension sections

**Verification**:
- Every rule entry in both sections carries both axis tags
- PRESENTATION CLARITY contains no restatement of the Universal Placement Rule's mechanics, only a named reference to it and to its existing enforcer
- The speculative-claim marker is defined and explicitly distinguished from `CONFIRM`

---

### Phase 4: Cross-reference ownership and per-repo interface contract [NOT STARTED]

**Goal**: Write the two deference sections — internal (three existing standards) and per-repo (two local checks) — so no rule has ambiguous double ownership and so a repo-local check can be implemented against a contract without importing agent-system code.

**Tasks**:
- [ ] Write a `## Deferrals and Ownership` section with one subsection per cross-referenced standard
- [ ] `textbook-standards.md` — state what is deferred: Definition Ordering Principle, Motivation Requirements, Professional Tone Standards, and Chapter Structure remain owned there as the underlying content conventions; this standard's corresponding rules are the chapter-quality-scoring restatement only. Resolve the overlap with its existing "Quality Checklist" explicitly: this standard is the authoritative chapter-quality bar
- [ ] `semantic-element-usage.md` — state what is deferred: the Universal Placement Rule (owned there, enforced by `scripts/typst-element-lint.sh`) and per-element expected-density mechanics, notably the Example element's density rule. Its "Self-Review Questions" overlap this standard's judged rules; say which file owns which
- [ ] `notation-conventions.md` — state what is deferred: the notation architecture and import pattern that answer "where is a symbol's definition recorded"; this standard owns only the before-first-use ordering consequence for scoring
- [ ] For each of the three, state in one sentence which file owns any rule both could be read as owning
- [ ] Write a `## Interface Contract for Repo-Local Checks` section stating up front that both checks are repo-local (the consuming repository's own `typst/scripts/`), are never implemented or duplicated in agent-system, and are never invoked by a consuming checker shelling out to repo code
- [ ] Define the shared finding-record shape both checks emit: dimension, rule identifier (namespaced `local:<check-name>`), severity (BLOCKING or ADVISORY, the repo's choice), location (file:line), message
- [ ] Define the name-resolution check contract: what it verifies (identifiers named in chapter prose that purport to name a function/variable defined in the repo's own modules actually resolve in the live tree at check time), why it is repo-local (the modules it resolves against are per-repo), what it reports, and how its findings compose (independent script, findings namespaced `local:name-resolution`, aggregated at the repo's own CI/test layer)
- [ ] Define the chapter-source coverage check contract: what it verifies (every chapter file the repo's build includes has a recorded quality-check run against it, so no chapter ships unreviewed), what it reports, and how its findings compose, namespaced `local:chapter-source-coverage`
- [ ] State how local findings compose with this standard's own findings: aggregation at the repo layer, with the same Axis 1 exit-code semantics applied uniformly

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/typst/context/project/typst/standards/chapter-quality.md` — add the deferrals/ownership and interface-contract sections

**Verification**:
- All three named standards are cross-referenced, each with an explicit statement of what is deferred rather than restated
- Every overlap identified in the task description has a single named owner
- The interface-contract section contains no shell code, no implementation, and no requirement that a repo import agent-system code

---

### Phase 5: Rationale section and acceptance verification sweep [NOT STARTED]

**Goal**: Record the load-bearing rationale for all four dimensions, then mechanically verify every acceptance criterion before declaring the deliverable done.

**Tasks**:
- [ ] Write a `## Rationale` section with one entry per dimension recording why the dimension exists, so a future editor cannot quietly delete a rule whose purpose is no longer obvious
- [ ] SOURCE GROUNDING rationale — a chapter built from research is only as good as its traceability; an untraceable claim is indistinguishable from a fabricated one, and the `CONFIRM` marker exists so a gap is recorded rather than guessed
- [ ] ANTI-FLUFF DENSITY rationale — restate the existing severity-split reasoning from `scripts/typst-element-lint.sh`'s header verbatim in substance: an unreviewed hard threshold that fires on correct documents is exactly the failure mode the split exists to prevent, because a gate that fires on correct documents gets switched off. Do not invent a different rationale
- [ ] PRESENTATION CLARITY rationale — the chapter is read linearly by a reader who cannot look ahead; a term used before it is defined costs the reader the rest of the section
- [ ] OPEN-QUESTION HONESTY rationale — record in full: a forward-looking chapter on training agents to synthesize programs from verified components must not present genuinely open research questions as resolved. This reasoning belongs in the standard, not in a commit message where it will be lost
- [ ] Verify acceptance criterion 1: the file exists at `agent-system/extensions/typst/context/project/typst/standards/chapter-quality.md` and `grep -rl chapter-quality .claude/` returns nothing
- [ ] Verify criteria 2-4 mechanically: exactly four dimension headings with the exact names; per-rule tag sweep where rule-entry count, Axis 1 tag count, and Axis 2 tag count are all equal; zero BLOCKING tags inside the ANTI-FLUFF DENSITY section
- [ ] Verify criterion 5: all three cross-referenced filenames appear with an accompanying deferral statement
- [ ] Verify criteria 6-7: the interface-contract section covers both named checks; the rationale section contains the OPEN-QUESTION HONESTY reasoning
- [ ] Verify criterion 8: no task-number references — grep for `task [0-9]`, `tasks [0-9]`, and `#[0-9][0-9]` patterns in the file
- [ ] Extract every backticked path from the file and confirm each resolves against the live tree (the `prose` tier's named blind spot for broken cross-references)
- [ ] Confirm `git status --short` shows exactly one modified/added path under `agent-system/` and nothing else attributable to this task

**Timing**: 0.4 hours

**Depends on**: 4

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts that exactly one file is created and that all eight acceptance criteria are checkable mechanically or by a single read. Confirm by running the `git status --short` check above; if any second file turns out to be required, stop and record why rather than expanding scope silently.

**Files to modify**:
- `agent-system/extensions/typst/context/project/typst/standards/chapter-quality.md` — add the rationale section

**Verification**:
- All eight acceptance criteria verified with the commands above, and their outputs recorded
- Every backticked path in the deliverable resolves
- Exactly one file changed

---

## Testing & Validation

- [ ] `test -f agent-system/extensions/typst/context/project/typst/standards/chapter-quality.md` succeeds
- [ ] No file named `chapter-quality.md` exists anywhere under `.claude/`
- [ ] Exactly four dimension headings, named `SOURCE GROUNDING`, `ANTI-FLUFF DENSITY`, `PRESENTATION CLARITY`, `OPEN-QUESTION HONESTY`, with no fifth
- [ ] Rule-entry count equals Axis 1 tag count equals Axis 2 tag count (no rule missing either tag)
- [ ] Zero `BLOCKING` tags within the ANTI-FLUFF DENSITY section
- [ ] `textbook-standards.md`, `semantic-element-usage.md`, and `notation-conventions.md` each appear with an explicit deferral statement
- [ ] Interface-contract section defines both the name-resolution and chapter-source coverage contracts, with the shared finding-record shape
- [ ] Rationale section present, containing the OPEN-QUESTION HONESTY reasoning
- [ ] No task-number references in the deliverable
- [ ] Every backticked path in the deliverable resolves against the live tree
- [ ] `git status --short` shows exactly one added path attributable to this task

## Artifacts & Outputs

- `agent-system/extensions/typst/context/project/typst/standards/chapter-quality.md` — the sole deliverable, the chapter-quality standard
- `specs/253_typst_chapter_quality_standard/summaries/01_*-summary.md` — implementation summary (produced by the implement phase, not by this plan)

## Rollback/Contingency

The deliverable is a single new file in the source store; nothing existing is modified. Rollback is `git rm` (or delete) of that one file, restoring the tree to its pre-task state — no destructive git operation on uncommitted work is needed or warranted.

If a defensive checkpoint is wanted before Phase 4 or 5 (the phases that most rework earlier prose), use the durable, non-reverting form: `bash .claude/scripts/git-snapshot.sh 253 --no-revert`. Do not emit a bare default-mode `git-snapshot.sh` call as a routine checkpoint — that form reverts the working tree and belongs only to a genuine rollback scenario (see `.claude/context/contracts/recovery.md`'s rollback rung for the invocation shape, including its out-of-scope override flag).

Contingency: if a drafted rule proves unclassifiable on either axis during writing, tag it ADVISORY/JUDGED (the strictly weaker, non-gating combination), state in its entry that its classification is provisional and why, and record the open question in the phase completion note. An honestly-provisional rule is recoverable downstream; a confidently-misclassified one becomes a false gate.
