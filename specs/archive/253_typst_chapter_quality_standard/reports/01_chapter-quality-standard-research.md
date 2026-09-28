# Research Report: Task #253

**Task**: 253 - Define the Typst chapter-quality standard across the four dimensions, with
per-rule blocking/advisory and mechanical/judged classification
**Started**: 2026-09-24T00:00:00Z
**Completed**: 2026-09-24T00:00:00Z
**Effort**: ~2 hours
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/typst/context/project/typst/standards/*.md` (all 8 existing
  standards), `agent-system/extensions/typst/scripts/typst-element-lint.sh`,
  `agent-system/extensions/typst/index-entries.json`, `agent-system/extensions/typst/context/project/typst/patterns/bibliography.md`
- `specs/TODO.md` entry for the dependent task (checker/wiring), which specifies the exact
  interface the produced standard must support
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The deliverable is fully scoped by the dispatch: exactly one file at
  `agent-system/extensions/typst/context/project/typst/standards/chapter-quality.md` (source
  store, never `.claude/**`), with four fixed dimensions (Source Grounding, Anti-Fluff Density,
  Presentation Clarity, Open-Question Honesty), every rule dual-tagged
  BLOCKING/ADVISORY x MECHANICAL/JUDGED, mandatory cross-references to three existing standards,
  an interface-contract section for two per-repo checks, and a rationale section.
- This report drafts the complete rule inventory (15 rules across the four dimensions) with a
  proposed classification for each, ready for the planner to transcribe into an implementation
  plan with minimal further design work.
- The severity-split precedent already exists verbatim in this extension:
  `scripts/typst-element-lint.sh`'s header (lines 24-29) states the exact rationale the dispatch
  asks this standard to mirror for its own ADVISORY rules — an unreviewed hard threshold that
  fires on correct documents gets switched off, so unreviewed thresholds start ADVISORY.
- Three existing standards own adjacent ground and must be deferred to, not restated:
  `textbook-standards.md` (Definition Ordering Principle, Motivation Requirements, Chapter
  Structure, Quality Checklist), `semantic-element-usage.md` (Universal Placement Rule — already
  mechanically enforced by `typst-element-lint.sh` — and the Example element's density rule), and
  `notation-conventions.md` (the two-tier `shared-notation.typ`/`{project}-notation.typ` import
  pattern).
- The dependent task (checker + wiring, already filed and blocked on this one) names this
  standard as its literal specification and quotes its rule inventory, its blocking/advisory
  split, and its mechanical/judged split as inputs it must not re-derive — confirming the shape
  drafted below is directly consumable.
- `chapter-quality.md`'s own line count and cross-reference shape should mirror the other eight
  standards files in the same directory (142-359 lines each); no existing standard uses this
  extension's `load_when.agents`/`task_types` index metadata for anything beyond
  `typst-implementation-agent` + `["typst"]`, though the dependent task additionally wires
  `typst-research-agent` — that wiring is task 254's scope, not this task's.

## Context & Scope

Researched what the new standard must contain, how it must interoperate with three existing
standards in the same directory, and what interface the standard's "Defer, do not duplicate —
per-repo" section must define for two checks that live outside `agent-system/**`. No web research
was needed — everything relevant is local to this repository. The research also verified the
dependent task's (already-filed) expectations against the dispatch to confirm the two are
consistent, since a mismatch there would make the standard undeliverable to its consumer.

## Findings

### Codebase Patterns

**Directory and naming**: All eight existing standards live flat in
`agent-system/extensions/typst/context/project/typst/standards/` as `{kebab-name}.md`, no
subdirectories, 141-359 lines each with a single `# Title` H1 and `##` section headings. The new
file's path (`standards/chapter-quality.md`) matches this exactly.

**Severity-split precedent** (`scripts/typst-element-lint.sh` header): the script already
implements a placement-vs-advisory split that is the direct ancestor of Axis 1 in this task.
Verbatim rationale (lines 24-29): checks 2 and 3 (remark item count, remark density) are
"ADVISORY-ONLY: they are reported and counted but NEVER affect the exit code... Promoting either
to blocking requires first observing their behavior against a real corpus of chapters... an
unreviewed hard threshold that fires on correct documents is exactly the failure mode this split
exists to prevent (a gate that fires on correct documents gets switched off)." The new standard's
rationale section for ANTI-FLUFF DENSITY should restate this same reasoning, not invent a new one,
since the dispatch explicitly ties the axis to this file's "stated rationale."

**`textbook-standards.md`** already owns:
- Definition Ordering Principle ("CRITICAL: Every mathematical term must be defined before its
  first use", with an explicit audit procedure) — the prose-level rule PRESENTATION CLARITY's
  "notation/glossary term defined before first use" rule must defer to, not restate.
- Motivation Requirements ("Each major concept requires motivation before its formal definition",
  minimum 2 sentences, integrated into narrative, never an explicit `_Motivation_` header) —
  overlaps ANTI-FLUFF DENSITY's "no section without a stated reader need."
- Professional Tone Standards (a terminology table: avoid "obviously"/"clearly"/"trivial"/"easy")
  — overlaps ANTI-FLUFF DENSITY's hedging/filler flags; a MECHANICAL word-list check for the new
  standard can literally reuse this table's "Avoid" column as a seed list.
- Chapter Structure and the existing "Quality Checklist" (8 items, including "All terms defined
  before use", "Notation is consistent with shared-notation.typ") — this is the closest existing
  analogue to a "chapter quality" list, and the new standard supersedes it as the authoritative
  quality bar while textbook-standards.md keeps ownership of the underlying content conventions.

**`semantic-element-usage.md`** already owns:
- The Universal Placement Rule ("A semantic element MUST NOT be the first body content after a
  heading, with no intervening prose") — already mechanically enforced, BLOCKING, by
  `typst-element-lint.sh` check 1. PRESENTATION CLARITY must name this rule and its enforcer, not
  re-specify placement.
- Per-element "Expected density" entries, notably Example: "At least one per non-obvious
  definition" — directly overlaps PRESENTATION CLARITY's "a concept introduced has an
  accompanying example or figure." Defer density/placement mechanics here; PRESENTATION CLARITY's
  rule restates only the reader-facing consequence for chapter-quality scoring purposes.

**`notation-conventions.md`** already owns the two-tier notation architecture (`shared-notation.typ`
+ `{project}-notation.typ`, re-exported via `#import`) and is the natural anchor for "where is a
symbol's definition recorded" — PRESENTATION CLARITY's notation rule points here rather than
re-deriving a second notation model.

**`document-structure.md`** already constrains heading depth structurally, even though it is not
one of the three standards the dispatch names for cross-reference: "Level-1 heading: One `=`
heading per chapter"; "Level-3 headings (`===` for subsections (use sparingly)". This gives the
PRESENTATION CLARITY heading-depth-bound rule a pre-existing, non-arbitrary anchor (max depth
`===`), which is why that rule can safely be BLOCKING rather than an unreviewed ADVISORY
threshold — it is not a fresh numeric guess, it formalizes a bound the layout standard already
states.

**No existing "CONFIRM comment" convention exists anywhere in the repository** (`grep -rn
"CONFIRM:"` across `agent-system/` and `.claude/` returns nothing outside this task's own
artifacts). The dispatch's Source Grounding dimension ("CONFIRM comments well-formed") therefore
requires this standard to *define* the convention, not merely reference one. The natural
definition, consistent with the dimension's purpose (no fabrication in place of a citation): an
inline marker an author writes when a claim cannot be immediately verified, in place of guessing —
e.g. `// CONFIRM: <specific claim that needs a source>` — so the gap is visible and deferrable
rather than silently fabricated. "Well-formed" is then a syntactic, MECHANICAL check (the marker
carries a non-empty claim-text payload), independent of whether the underlying claim is later
resolved true or false.

**Interface-contract precedent** (from the dependent task's own filed description, `specs/TODO.md`
task 254): the checker "implements the standard's interface contract for them — it does not
implement the checks themselves," and findings must carry "its dimension, its rule, and its
BLOCKING-or-ADVISORY severity." This confirms the interface contract this standard must define
should specify a **finding record shape** (dimension, rule id, severity, location, message) that a
repo-local script can emit and that composes with the checker's own output shape, rather than any
tighter coupling (no shared code, no agent-system import).

### External Resources

None consulted; scope is entirely internal-standard authoring.

## Recommendations — Draft Rule Inventory

The following is a complete, classification-tagged draft of the standard's rule content, organized
by dimension, ready for the planner/implementer to transcribe (with rationale prose added) into
`chapter-quality.md`. Every rule below carries both required axes.

### 1. SOURCE GROUNDING

| # | Rule | Axis 1 | Axis 2 | Notes |
|---|------|--------|--------|-------|
| 1.1 | Every substantive claim traces to a cited source (repo path, paper, or verified fact) | BLOCKING | JUDGED | Core grounding requirement; "substantive" and source adequacy need a reader. |
| 1.2 | Backticked paths resolve against the live tree | BLOCKING | MECHANICAL | Script can extract backtick-delimited paths and test existence. |
| 1.3 | Citations (`@key`) resolve in `bibliography.bib` | BLOCKING | MECHANICAL | Extract `@key` occurrences; grep `.bib` for matching entry keys (see `patterns/bibliography.md`). |
| 1.4 | No hand-typed count, version, or hash — such values must be derived from a cited, checkable source, never typed from memory | BLOCKING | JUDGED | Whether a number was "hand-typed" vs. derived cannot be determined from text alone. |
| 1.5 | `CONFIRM` comments are well-formed: `// CONFIRM: <claim needing a source>` with non-empty claim text | BLOCKING | MECHANICAL | Syntactic format check only; resolving the underlying claim is out of scope for this rule. |

### 2. ANTI-FLUFF DENSITY (all rules ADVISORY, no exceptions, per acceptance criterion 4)

| # | Rule | Axis 1 | Axis 2 | Notes |
|---|------|--------|--------|-------|
| 2.1 | Claim-to-word ratio meets a stated per-section threshold | ADVISORY | MECHANICAL | Unreviewed on first release; standard must say so explicitly (mirrors `typst-element-lint.sh`'s check 2/3). |
| 2.2 | No `==`/`===` section lacks a stated reader need in its opening prose | ADVISORY | JUDGED | Overlaps `textbook-standards.md` Motivation Requirements; this rule is the chapter-quality-scoring restatement, not a new prose requirement. |
| 2.3 | Hedging and filler connective prose flagged against a seed phrase list (e.g. "it seems", "arguably", "it is worth noting that", "needless to say"; seed list drawn from `textbook-standards.md`'s Professional Tone "Avoid" column) | ADVISORY | MECHANICAL | Phrase-list grep; list is unreviewed/extensible, standard must say so. |

### 3. PRESENTATION CLARITY

| # | Rule | Axis 1 | Axis 2 | Notes |
|---|------|--------|--------|-------|
| 3.1 | Every notation symbol / glossary term is defined before its first use | BLOCKING | JUDGED | Ownership: the ordering principle is `textbook-standards.md`'s Definition Ordering Principle (restated here for scoring, not re-derived); the notation source-of-truth is `notation-conventions.md`'s two-tier system. Cross-chapter ordering needs semantic tracking a script cannot reliably do. |
| 3.2 | Heading depth bounded at `===` (level 3); `====` and deeper prohibited | BLOCKING | MECHANICAL | Grounded in `document-structure.md`'s existing "use sparingly" / one-`=`-per-chapter convention, not a fresh guess — grep heading marker depth. |
| 3.3 | Paragraph length bounded (word/line count) | ADVISORY | MECHANICAL | Fresh, unreviewed numeric threshold; standard must say so explicitly. |
| 3.4 | Every non-obvious concept introduced has an accompanying example or figure | ADVISORY | JUDGED | Ownership: `semantic-element-usage.md`'s Example entry already sets expected density/placement mechanics; this rule restates only the reader-facing consequence. "Non-obvious" is inherently a judgment call, so BLOCKING risks the fire-on-correct-documents failure mode. |

### 4. OPEN-QUESTION HONESTY

| # | Rule | Axis 1 | Axis 2 | Notes |
|---|------|--------|--------|-------|
| 4.1 | Speculative claims are explicitly marked (e.g. a defined "Speculative:" tag, distinct from the `CONFIRM` marker in dimension 1) | BLOCKING | JUDGED | Distinguishing speculative from established claims needs a reader; this is the dimension the rationale section must justify most heavily (see Rationale below). |
| 4.2 | Open questions are listed in a dedicated, discoverable location (e.g. an `== Open Questions` section) rather than buried inline | BLOCKING | JUDGED | Presence of a section heading is a cheap mechanical proxy but not sufficient; whether content is genuinely "listed rather than buried" needs a reader. |
| 4.3 | No future-tense claim is stated as settled fact | BLOCKING | JUDGED | Future-tense/modal phrase patterns are too unreliable as a standalone mechanical signal (high false-positive/negative rate); requires reading for intent. |

**Total: 15 rules** (5 + 3 + 4 + 3), every one carrying both axes. All 3 ANTI-FLUFF DENSITY rules
are ADVISORY with no exception, satisfying acceptance criterion 4 exactly.

### Interface Contract Draft (for the two per-repo checks)

Both checks are **repo-local**, live in the consuming repository's own `typst/scripts/`, and are
never implemented or duplicated in `agent-system/**`. The standard defines only the contract each
must satisfy:

**Shared finding-record shape** (both checks emit findings in this shape, matching the fields the
dependent checker's own output uses per `specs/TODO.md` task 254: "its dimension, its rule, and
its BLOCKING-or-ADVISORY severity"):
```
{ dimension, rule (namespaced "local:<check-name>"), severity (BLOCKING|ADVISORY, repo's choice),
  location (file:line), message }
```

**Name-resolution check contract**: verifies that every identifier referenced in chapter prose
that purports to name a Typst function/variable defined in the repo's own `template.typ` /
`notation/*.typ` / source modules actually resolves in the live tree at check time. Repo-local
because the modules it resolves against are per-repo, not agent-system content. Composes by
running as an independent script whose findings are namespaced `local:name-resolution` and
aggregated at the repo's own CI/test layer alongside `chapter-quality-check.sh`'s output — never
by `chapter-quality-check.sh` shelling out to repo code.

**Chapter-source coverage check contract**: verifies that every chapter file the repo's build
includes (per `document-structure.md`'s `#include "chapters/NN-*.typ"` pattern) has a recorded
`chapter-quality-check.sh` run against it, so no chapter ships unreviewed. Composes the same way,
namespaced `local:chapter-source-coverage`.

## Decisions

- The standard's file path is settled per the dispatch's PATH NOTE:
  `agent-system/extensions/typst/context/project/typst/standards/chapter-quality.md` (not the
  originally-sketched `context/standards/chapter-quality.md`).
- The four dimensions are settled and MUST NOT be redesigned, renamed, merged, reordered, or
  extended — confirmed as non-negotiable in the dispatch and treated as such in this research.
- The `CONFIRM` comment convention does not pre-exist and must be defined by this standard itself
  (see Findings above for the proposed syntax).
- ANTI-FLUFF DENSITY's three rules are all ADVISORY with no exception; this report's draft
  reflects that exactly (see table above).
- The two per-repo checks (name-resolution, chapter-source coverage) are out of scope for this
  standard's implementation — only their interface contract is defined here, confirmed consistent
  with the dependent task's own description.

## Risks & Mitigations

- **Risk**: A rule drafted here turns out unimplementable as classified once the checker (task 254)
  is built. **Mitigation**: task 254's own description already requires amending the standard in
  the same commit that changes the checker if a rule proves unimplementable as classified — this
  is a known, accepted downstream process, not a defect in this research.
- **Risk**: The `CONFIRM` marker convention drafted here conflicts with a convention introduced
  independently elsewhere before task 254 lands. **Mitigation**: confirmed via repo-wide grep that
  no such convention exists anywhere today; the standard is the first and sole source of truth for
  it.
- **Risk**: Cross-references to `textbook-standards.md`, `semantic-element-usage.md`, and
  `notation-conventions.md` could drift out of sync if those files change independently.
  **Mitigation**: acceptance criterion 5 already requires explicit cross-references stating what
  is deferred rather than restated, which is the standard mechanism this repository already uses
  (e.g. `type-theory-foundations.md` <-> `semantic-element-usage.md`'s existing cross-reference
  pair) to keep two standards from silently diverging.

## Context Extension Recommendations

None. This is a meta task producing a single well-scoped standards document within an existing,
well-documented extension; no gaps in `.claude/context/` documentation were identified during this
research.

## Appendix

- Search queries / commands used: `find`/`ls` over
  `agent-system/extensions/typst/context/project/typst/standards/`; `grep -rn "CONFIRM:"` across
  `agent-system/` and `.claude/`; `grep -rln "bibliography"`; read of
  `scripts/typst-element-lint.sh` header (lines 1-80); read of `specs/TODO.md` entries 253 and 254
  in full.
- References: `agent-system/extensions/typst/context/project/typst/standards/textbook-standards.md`,
  `semantic-element-usage.md`, `notation-conventions.md`, `document-structure.md`;
  `agent-system/extensions/typst/scripts/typst-element-lint.sh`;
  `agent-system/extensions/typst/context/project/typst/patterns/bibliography.md`;
  `agent-system/extensions/typst/index-entries.json`; `specs/TODO.md` (task 254 description, for
  cross-consistency verification only — not itself a source cited by the deliverable, which must
  carry no task-number references).
