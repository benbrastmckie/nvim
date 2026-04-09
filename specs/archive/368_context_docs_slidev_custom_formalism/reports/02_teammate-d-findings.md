# Teammate D Findings: Strategic Horizons

**Task**: 368 - context_docs_slidev_custom_formalism
**Teammate**: D (Horizons)
**Focus**: Long-term alignment and strategic direction for formalism rendering
**Date**: 2026-04-07

---

## Key Findings

### 1. The Logos Formalism Is Structurally Expansive

The Logos system currently defines 29+ logical operators spanning 7 categories: counterfactual/modal, temporal, epistemic, normative, abilities/choice, causal/constitutive, and classical. The training objectives document confirms the intent to support fine-tuning for domain-specific ontologies (legal, narrative, technical documentation). This strongly implies the operator set will grow as new application verticals are pursued (legal, medical, finance, defense). The custom SVG rendering components — LogosOp.vue and KaTex.vue — currently hardcode exactly 4 compound operators (boxright, diamondright, circleright, dotcircleright). This is the most non-scalable aspect of the current design.

### 2. The Presentation Layer Sits at the Intersection of Two Critical Assets

The investor pitch deck is not merely a sales artifact. It is the primary public-facing representation of the Logos formalism at a moment when the project is raising capital and establishing scientific credibility. The formalism notation displayed on slide S4 ("Logos Operators" panel) and the appendix slides serves two audiences simultaneously: non-technical investors who need to see coherent structure, and technically-minded reviewers (angels, AI researchers, safety-focused VCs) who will evaluate whether the notation is rigorous. The rendering quality directly reflects on the intellectual substance of the system.

### 3. The Current Three-Layer System Creates Maintenance Fragmentation

The research report identified that SVG definitions are duplicated between LogosOp.vue and KaTex.vue with an unresolved `vertical-align` discrepancy (-0.1em vs -0.15em). Setup/katex.ts provides a third, lower-quality rendering path via `\htmlStyle` overlap tricks. There is no single source of truth for operator SVG geometry. If a new compound operator is added (e.g., a double-arrow or a stit operator), it must be added to three separate places. The documentation task is valuable but does not address this underlying fragmentation — it can only describe it.

### 4. No Current Reuse Strategy Exists Between Decks or Output Channels

The `strategy/02-deck/slidev/` directory is a self-contained presentation with no connection to adjacent rendering contexts: the Logos Vision docs (`logos/docs/`), the training description files (`logos/description/`), or potential future academic paper rendering (Typst/LaTeX). The components are embedded directly in the deck rather than extracted to a shared package or library. This means any future deck (for academic conferences, follow-on fundraising, product demos) would either copy these components verbatim or reinvent them.

---

## Strategic Alignment Assessment

**The task as scoped (documentation) is fully aligned with near-term goals.** Documenting the existing patterns in the founder extension context is a direct investment in agent productivity for future deck creation. The research report's recommendation (Option A: add to slidev-deck-template.md) is the right call for the immediate task.

**However, the task addresses a symptom rather than the root cause.** The strategic question is whether the formalism rendering should remain embedded in individual decks or be extracted into a shared, versioned component library. Given:
- The Logos formalism will expand as new verticals are pursued
- Multiple presentation contexts will be needed (fundraising, academic, product)
- The KaTex.vue duplication problem will compound over time
- The project is at a stage where technical debt is cheap to fix

...the documentation task is a good short-term move, but a component extraction decision should be made within the next 1-2 decks created, not deferred indefinitely.

**The investor context adds urgency on correctness.** The deck is currently in active use for pre-seed fundraising ($3.5M target, 2026). Any rendering inconsistencies in the formalism display (e.g., misaligned operators, fallback text instead of SVG glyphs) undermine the impression of technical polish. The documentation helps future deck agents avoid these errors.

---

## Scalability Analysis

### Operator Count Growth
Current: 4 compound operators (SVG), 18+ HTML entity operators
Projected: Each new vertical (medical, defense, autonomous systems) may introduce 2-5 new compound operators (e.g., dynamic logic operators, deontic modalities with custom symbols, probability operators)
Growth rate: Moderate (not exponential). New operators are introduced deliberately as formal logic fragments are implemented for new domains.

### Multi-Deck Proliferation
The Logos roadmap describes a pre-seed raise in 2026, a Series A target in year 3, plus academic publication and partnership pathways. Each milestone typically requires updated or purpose-built presentations. Three to six decks over the next 3 years is a plausible lower bound. Under the current architecture, each deck would re-import the component files (or duplicate them).

### Documentation Coverage
The current documentation approach (embed patterns in slidev-deck-template.md) scales adequately for 2-3 decks. Beyond that, the template file risks becoming too long, or the patterns drift from the actual components. A dedicated `logos-formalism-patterns.md` file (Option B from the research report, deferred for now) would become the right structure if the system expands.

### Rendering Quality Ceiling
The SVG approach (LogosOp.vue, KaTex.vue) is a robust rendering strategy. The quality ceiling is not a concern — pixel-precise SVG glyphs scale infinitely. The issue is the duplication of SVG geometry, not the approach itself.

---

## Creative Alternatives

### Alternative 1: Logos Formalism Slidev Addon Package

Extract the formalism components into a standalone `slidev-addon-logos` npm package. This would contain:
- `LogosOp.vue` (with full operator registry)
- `KaTex.vue` (with synchronized SVG registry)
- `setup/katex.ts` (shared macro definitions)
- A unified SVG geometry module shared by both components (eliminating duplication)

Decks would install it via `npm install slidev-addon-logos` and declare it in `package.json`. This is exactly how Slidev addons work (e.g., `@slidev/theme-seriph`). The cost is a small amount of npm infrastructure; the benefit is version-pinned, consistent rendering across all Logos presentations.

**Verdict**: Valuable when the third deck is being created. Not warranted for the current documentation task.

### Alternative 2: Unified Logos SVG Geometry Module

Rather than a full addon, create a single `logos-operators.ts` file in the deck's `setup/` directory that exports both the SVG string map (for KaTex.vue) and the operator registry (for LogosOp.vue). Both components import from this single source. This eliminates the duplication without requiring npm package infrastructure.

**Verdict**: A small, immediate improvement that could be done alongside (not instead of) the documentation task. Low cost, high correctness value.

### Alternative 3: Typst/LaTeX Export Pipeline

The Logos formalism will eventually appear in academic papers. Typst supports custom SVG embedding and custom operator definitions. A parallel `logos-formalism.typ` module defining the same operators in Typst notation would allow consistent notation across presentations and papers. The HTML entity inventory from the research report maps directly to Unicode characters usable in Typst.

**Verdict**: Strategic but out of scope for this task. Worth a future research task when the first Logos paper is being prepared.

### Alternative 4: Scope This Task to Include the Shared Module Refactor

Instead of only documenting the three-layer system, the task could be extended to also implement Alternative 2 (unified geometry module) and document the new single-source architecture. This would cost approximately 1 additional hour but would leave the codebase in a better state than documentation alone.

**Verdict**: A legitimate scope expansion worth raising with the user. The plan is already created; this would require a revision.

---

## Recommendations

1. **Complete the documentation task as planned (Option A).** The plan is well-scoped and the research is thorough. No changes to the current plan are needed to deliver value.

2. **Raise the unified SVG module opportunity (Alternative 2) as a follow-on recommendation.** Document the duplication coupling prominently in the slidev-deck-template.md section (as the research already recommends) so that the next deck developer sees the note and can act on it. If the user is actively working on the deck, suggest a 1-hour follow-on task to extract the shared geometry.

3. **Flag the slidev addon path (Alternative 1) for the third deck milestone.** When a third Logos presentation is being created, the investment in a proper addon package becomes justified. A roadmap note or task creation at that point is appropriate.

4. **Do not add a formal-methods rendering system (Typst/LaTeX) to this task scope.** That is a distinct concern driven by publication timelines, not presentation timelines.

5. **Consider Option B (separate `logos-formalism-patterns.md`) as a future trigger.** If the operator count doubles (to 8+ compound SVG operators) or a second deck with formalism is created, the formalism documentation should be extracted from `slidev-deck-template.md` into its own indexed context file. The documentation task should include a note about this trigger condition.

---

## Confidence Level

**High.**

The strategic picture is clear from the available materials:
- Logos formalism objectives document confirms operator expansion intent
- Investor deck confirms active use case urgency
- Research report provides accurate component-level analysis
- The duplication problem is confirmed by reading both Vue files
- The three-layer fragmentation is a documented pattern, not an inference

The main uncertainty is the pace of deck proliferation — if the project stays with a single deck for 2+ years, the documentation-only approach is sufficient indefinitely. The recommendations are robust to both fast and slow deck creation rates.
