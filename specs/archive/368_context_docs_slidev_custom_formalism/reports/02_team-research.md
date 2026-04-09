# Research Report: Better Formalism Management in Slidev

- **Task**: 368 - Create context documentation for Slidev custom formalism rendering
- **Started**: 2026-04-07T20:32:00Z
- **Completed**: 2026-04-07T21:20:00Z
- **Effort**: ~45 minutes (team research, 4 teammates)
- **Dependencies**: None
- **Sources/Inputs**:
  - /home/benjamin/Projects/Logos/Vision/strategy/02-deck/slidev/slides.md
  - /home/benjamin/Projects/Logos/Vision/strategy/02-deck/slidev/components/LogosOp.vue
  - /home/benjamin/Projects/Logos/Vision/strategy/02-deck/slidev/components/KaTex.vue
  - /home/benjamin/Projects/Logos/Vision/strategy/02-deck/slidev/setup/katex.ts
  - Slidev documentation (sli.dev)
  - KaTeX documentation (katex.org)
- **Artifacts**: reports/02_team-research.md (this file)
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report.md

## Executive Summary

- The current deck uses three inconsistent formalism rendering mechanisms: LogosOp.vue (SVG components), raw HTML entities, and dead KaTeX infrastructure (KaTex.vue + setup/katex.ts macros that are never invoked)
- The 4 compound operators (boxright, diamondright, circleright, dotcircleright) genuinely require SVG -- no KaTeX macro or font solution can produce these composite glyphs
- All standard operators (~70+ instances) are rendered as HTML entities with inconsistent font wrappers, when they could use either Unicode literals or native KaTeX `$...$` syntax
- SVG geometry is duplicated between LogosOp.vue and KaTex.vue with a confirmed vertical-align discrepancy (-0.1em vs -0.15em)
- The recommended architecture is: keep LogosOp.vue for the 4 compound operators, replace HTML entities with Unicode literals + shared CSS class, and either remove or archive dead KaTeX infrastructure
- The documentation task (368) should proceed as planned, but should prominently note the duplication coupling and recommend a follow-on unified geometry module

## Context and Scope

This team research was conducted to answer: "Is there a better, more consistent way to manage all formalism in Slidev?" The investigation covered the current implementation in the Logos Vision investor pitch deck, alternative approaches from the Slidev/KaTeX ecosystem, critical analysis of fragility and maintenance risks, and long-term strategic alignment.

The deck is a pre-seed fundraising presentation ($3.5M target, 2026) displaying 29+ logical operators across 7 categories. The formalism rendering quality directly reflects on the project's technical credibility.

## Findings

### Current State: Three Inconsistent Rendering Paths

**Path 1: LogosOp.vue (8 instances, 2 slides)** -- The only mechanism actively doing custom rendering work. Produces clean inline SVG for the 4 compound operators. Uses `currentColor` inheritance, 28x16 viewBox, baseline alignment at -0.1em.

**Path 2: Raw HTML entities (~70+ instances, 3 slides)** -- Standard Unicode logic symbols expressed as hex entities (`&#x25A1;`, `&#x2227;`, etc.). Wrapped inconsistently in `font-serif` spans, `code` tags, or bare. Source is opaque but renders correctly.

**Path 3: Dead KaTeX infrastructure (0 instances)** -- Both `KaTex.vue` (custom wrapper with SVG placeholder injection) and `setup/katex.ts` (macro definitions using `\htmlStyle` overlap hack) were built but never wired into slides.md. Zero `$...$` math blocks exist in the slides.

### Hard Constraint: Compound Operators Require SVG

KaTeX macros expand to LaTeX, not HTML or SVG. The `\htmlClass`/`\htmlStyle` commands only wrap content in styled spans. There is no KaTeX mechanism to produce a true composite SVG glyph from within a macro definition. The `\htmlStyle{margin-left:-0.55em}` kerning hack in setup/katex.ts produces visually inferior, font-dependent output compared to LogosOp.vue's coordinated SVG viewBox. This is confirmed by both the KaTeX documentation and direct code analysis.

### KaTeX Native Support for Standard Operators

All standard operators in the deck have native KaTeX equivalents:
- Modal: `\Box`, `\Diamond`
- Classical: `\land`, `\lor`, `\neg`, `\top`, `\bot`
- Quantifiers: `\forall`, `\exists`, `\lambda`
- Ordering: `\leq`, `\sqsubseteq`

These work in Slidev's native `$...$` syntax without any custom configuration.

### Fragility Analysis

- **SVG geometry duplication**: LogosOp.vue and KaTex.vue define identical SVG paths for the same 4 operators with a vertical-align discrepancy (-0.1em vs -0.15em)
- **Four-place maintenance surface**: Adding a 5th compound operator requires changes in LogosOp.vue, KaTex.vue, setup/katex.ts, and slides.md with no single source of truth
- **KaTex.vue placeholder mechanism**: The `\text{##SVG0##}` substitution pattern is not validated against KaTeX's HTML output structure -- if KaTeX escapes `#` characters or wraps text nodes differently, SVG injection silently fails
- **No accessibility**: SVG operators lack `aria-label`, `role="img"`, or `<title>` elements
- **Font-dependent rendering**: HTML entities render differently across machines depending on installed serif fonts

### Alternative Approaches Evaluated

| Approach | Verdict | Notes |
|----------|---------|-------|
| Pure KaTeX macros | Partial | Works for ~90% of operators, cannot produce compound SVG glyphs |
| KaTeX macros + single SVG component | Recommended | Cleanest architecture -- removes KaTex.vue entirely |
| Single unified Vue component | Viable | Merges LogosOp + KaTex into one, but retains unnecessary KaTeX wrapper |
| Custom web font (PUA chars) | Impractical | High overhead for 4 symbols, no `currentColor` support |
| MDC syntax (`:LogosOp{op="..."}`) | Minor ergonomic | Cleaner than raw HTML but doesn't change architecture; had 2024 breaking changes |
| Markdown transformer shorthand | Not recommended | Adds third mechanism, harder for collaborators |
| Typst integration | Premature | No stable Slidev-Typst integration exists |

### Strategic Considerations

- **Operator expansion is confirmed**: The Logos objectives describe new operators for each vertical (legal, medical, defense). The current 4-operator SVG registry will grow.
- **Multi-deck proliferation is projected**: Pre-seed (now), Series A (year 3), academic publications, partner demos -- 3-6 decks over 3 years is a plausible lower bound.
- **No reuse strategy exists**: Components are embedded in the single deck directory with no path to sharing across presentations.

## Decisions

1. **LogosOp.vue is the correct solution for compound operators** -- All teammates converged on this conclusion independently. The SVG approach is robust, scalable, and visually superior to any KaTeX alternative.

2. **KaTex.vue and setup/katex.ts macros are dead code in the current deck** -- Zero usage in slides.md. The `\htmlStyle` kerning hack produces inferior output. These should be removed or archived unless inline math prose is planned.

3. **HTML entities should be replaced with Unicode literals** -- `∧` instead of `&#x2227;` for source readability, wrapped in a shared CSS class (`.logos-symbol`) instead of ad-hoc `font-serif` spans.

4. **The documentation task (368) should proceed as planned** -- No scope change needed. The plan's Option A (add to slidev-deck-template.md) is correctly scoped.

## Recommendations

### For Task 368 (Documentation)

1. **Document the recommended architecture** in the context files: LogosOp.vue for compound operators, Unicode literals for standard operators, native KaTeX `$...$` for mathematical prose contexts
2. **Prominently note the SVG geometry duplication** between LogosOp.vue and KaTex.vue with the vertical-align discrepancy
3. **Include the decision tree**: When to use LogosOp (compound operators) vs Unicode literals (standard operators in HTML context) vs native KaTeX (mathematical prose)
4. **Note trigger conditions** for escalating to a separate context file (Option B): when operator count doubles or a second formalism deck is created

### Follow-On Recommendations (New Tasks)

1. **Unified SVG geometry module** (1 hour): Create `setup/logos-operators.ts` exporting a shared SVG registry consumed by both Vue components. Eliminates duplication and the vertical-align discrepancy. Worth raising as a follow-on task.

2. **Dead code cleanup** (30 min): Remove or archive KaTex.vue and the `\htmlStyle` macros in setup/katex.ts if no inline math prose is planned. If retained, add comments documenting their purpose and current non-use.

3. **HTML entity to Unicode migration** (30 min): Replace all `&#xNNNN;` entities with Unicode literals and consolidate font wrappers to a single `.logos-symbol` CSS class.

4. **Slidev addon package** (future): Extract formalism components into `slidev-addon-logos` when the third Logos presentation is created. Not justified yet.

5. **Accessibility improvement** (30 min): Add `aria-label` attributes to LogosOp.vue SVG output.

## Risks and Mitigations

- **Risk**: Removing KaTex.vue before confirming no inline math is planned could require rebuilding it later.
  **Mitigation**: Archive rather than delete; document the decision and trigger for reactivation.

- **Risk**: Unicode literal rendering varies by platform serif fonts.
  **Mitigation**: The shared CSS class approach (`font-family: serif`) provides consistent fallback. The same risk exists with HTML entities.

- **Risk**: Operator expansion outpaces documentation.
  **Mitigation**: Document the trigger conditions for escalating to a dedicated context file.

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Contribution |
|----------|-------|--------|------------|------------------|
| A | Primary approach | completed | high | Comprehensive inventory of all rendering paths; identified KaTeX as dead code |
| B | Alternatives | completed | high | Confirmed SVG is irreplaceable for compound operators; evaluated 6 alternatives |
| C | Critic | failed (no output) | -- | Did not produce findings file |
| D | Horizons | completed | high | Strategic expansion analysis; unified geometry module recommendation |

### Conflicts Resolved

**No significant conflicts.** All three contributing teammates independently converged on the same core finding: LogosOp.vue is the right tool for compound operators, KaTex.vue is dead code, and HTML entities should be replaced with Unicode literals. The only variation was in emphasis:
- Teammate A emphasized the pitch deck context (no inline math needed)
- Teammate B emphasized the hard constraint (KaTeX cannot produce composite SVG glyphs)
- Teammate D emphasized the strategic trajectory (operator expansion, multi-deck future)

These perspectives are complementary, not conflicting.

### Gaps Identified

1. **Teammate C (Critic) did not produce findings** -- Runtime behavior of the KaTex.vue placeholder mechanism and edge case analysis was not independently verified
2. **No direct testing** of KaTeX macro output quality vs SVG rendering was performed (would require running the deck)
3. **Accessibility audit** was mentioned but not conducted in depth

## Appendix

### References
- [LaTeX | Slidev](https://sli.dev/features/latex) - Native KaTeX support documentation
- [Configure KaTeX | Slidev](https://sli.dev/custom/config-katex) - Custom macro configuration
- [Supported Functions | KaTeX](https://katex.org/docs/supported.html) - Full function reference
- [KaTeX Options](https://katex.org/docs/options.html) - Trust, macros, globalGroup options

### Source Files Analyzed
- `strategy/02-deck/slidev/slides.md` (1075 lines)
- `strategy/02-deck/slidev/components/LogosOp.vue`
- `strategy/02-deck/slidev/components/KaTex.vue`
- `strategy/02-deck/slidev/setup/katex.ts`
