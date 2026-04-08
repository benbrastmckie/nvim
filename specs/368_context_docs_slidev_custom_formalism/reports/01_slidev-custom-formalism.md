# Research Report: Task #368

**Task**: 368 - context_docs_slidev_custom_formalism
**Started**: 2026-04-07T00:00:00Z
**Completed**: 2026-04-07T00:30:00Z
**Effort**: small-medium (3 files to modify/create, well-scoped content)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: LogosOp.vue, KaTex.vue, setup/katex.ts (Logos Vision deck)
- Codebase: slides.md usage patterns (lines 218-224, 693-697)
- Codebase: slidev-deck-template.md (existing founder context)
- Codebase: deck/README.md (existing component docs)
- Codebase: index-entries.json (founder extension index)
**Artifacts**:
- specs/368_context_docs_slidev_custom_formalism/reports/01_slidev-custom-formalism.md
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- The Logos Vision deck uses a three-layer rendering system for custom mathematical operators: LogosOp.vue (SVG inline), KaTex.vue (KaTeX with SVG injection), and HTML entities with font-serif spans
- LogosOp.vue is the primary rendering method in the current slides.md; KaTex.vue exists but is unused in the current deck
- The setup/katex.ts provides fallback macro definitions using the htmlStyle overlap technique for native Slidev KaTeX (non-component) rendering
- Documentation should be added to slidev-deck-template.md (new section) and deck/README.md (new component entries), with index-entries.json updates only if a separate file is created
- Content fits within the existing slidev-deck-template.md file without requiring a separate custom-formalism-patterns.md

## Context & Scope

The task requires documenting custom formalism rendering patterns discovered in the Logos Vision deck project. These patterns enable rendering of non-standard logical operators (box-right, diamond-right, circle-right, dot-circle-right) that have no Unicode codepoints and must be rendered as compound SVG glyphs.

### Constraints
- Documentation must integrate with the existing founder extension context structure
- The slidev-deck-template.md is already 383 lines; the new section should be concise
- These patterns are specific to decks that present formal logic notation

## Findings

### Component Analysis: LogosOp.vue

**Purpose**: Renders compound logical operators as inline SVG glyphs in plain HTML context.

**Architecture**:
- Props: `op` (String, required) -- operator name key
- Operator registry: 4 entries (`boxright`, `diamondright`, `circleright`, `dotcircleright`)
- ViewBox: `0 0 28 16` for all operators
- Sizing: `width="1.4em" height="1em"` (scales with surrounding text)
- Alignment: `vertical-align: -0.1em` (baseline alignment for inline text flow)
- Color: Uses `currentColor` throughout (inherits from parent CSS color)
- Fallback: Renders the raw `op` string in a `<span>` if the key is not found

**SVG Structure Pattern**:
Each operator follows a shape-then-arrow pattern:
1. Left shape (rect/polygon/circle with `fill="none" stroke="currentColor" stroke-width="1.5"`)
2. Connecting line (`stroke-width="1.3"`)
3. Right arrowhead (filled polygon)

**Usage in slides.md** (2 locations):
- Line 218: Inline within `<span class="font-serif">` for operator listings
- Line 695: Inline with `style="font-size: 12px;"` wrapper for smaller rendering

### Component Analysis: KaTex.vue

**Purpose**: Wraps KaTeX rendering with custom macro preprocessing to inject SVG operators into mathematical expressions.

**Architecture**:
- Props: `expr` (String, required), `display` (Boolean, default false)
- SVG operator registry: Duplicates the same 4 SVG definitions from LogosOp.vue (with slightly different vertical-align: `-0.15em` vs `-0.1em`)
- Rendering pipeline:
  1. Scan `expr` for custom macros (`\boxright`, etc.)
  2. Replace each with `\text{##SVG{N}##}` placeholder
  3. Render through `katex.renderToString()` with `throwOnError: false`
  4. Post-process: replace `##SVG{N}##` placeholders with actual SVG HTML

**Key insight**: The placeholder substitution is necessary because KaTeX cannot render arbitrary HTML/SVG. The `\text{}` wrapper creates a text-mode node that passes through the placeholder string, which is then replaced after KaTeX rendering.

**Current usage**: Not used in slides.md. Available for mathematical expression contexts where operators appear alongside other KaTeX-rendered formulas (e.g., `\phi \boxright \psi`).

### KaTeX Macro Configuration: setup/katex.ts

**Purpose**: Defines fallback macros for Slidev's built-in KaTeX renderer (used in `$...$` and `$$...$$` markdown syntax, not the KaTex.vue component).

**Configuration**:
- `trust: true` -- enables `\htmlStyle` command
- `strict: false` -- suppresses warnings for custom macros
- 4 macros defined, all using the same overlap technique:
  ```
  \mathrel{\Box\htmlStyle{margin-left:-0.55em}{\rightarrow}}
  ```
- The `\mathrel` wrapper ensures proper spacing as a relation operator
- The `\htmlStyle{margin-left:-0.55em}` pulls the arrow leftward to overlap with the shape, creating a visually connected glyph

**Rendering quality**: This is a fallback -- the overlap technique produces acceptable but imperfect results compared to the pixel-precise SVG rendering in LogosOp/KaTex.vue.

### HTML Entity Patterns

**Purpose**: Standard Unicode operators rendered directly via HTML entities.

**Pattern**: `<span class="font-serif">&#xHHHH;</span>` or `<span class="font-serif italic">...</span>`

**Operator inventory from slides.md**:

| Entity | Unicode | Symbol | Category |
|--------|---------|--------|----------|
| `&#x25A1;` | U+25A1 | White square (necessity) | Modal |
| `&#x25C7;` | U+25C7 | White diamond (possibility) | Modal |
| `&#x2193;` | U+2193 | Downward arrow (store) | Temporal |
| `&#x2191;` | U+2191 | Upward arrow (recall) | Temporal |
| `&#x22A1;` | U+22A1 | Squared dot (stability) | Temporal |
| `&#x21AA;` | U+21AA | Rightwards arrow with hook | Epistemic |
| `&#x227A;` | U+227A | Precedes (preference) | Normative |
| `&#x21A6;` | U+21A6 | Rightwards arrow from bar | Normative |
| `&#x2227;` | U+2227 | Logical AND | Classical |
| `&#x2228;` | U+2228 | Logical OR | Classical |
| `&#xAC;` | U+00AC | NOT sign | Classical |
| `&#x22A4;` | U+22A4 | Down tack (top/true) | Classical |
| `&#x22A5;` | U+22A5 | Up tack (bottom/false) | Classical |
| `&#x2200;` | U+2200 | For all | Classical |
| `&#x2203;` | U+2203 | There exists | Classical |
| `&#x03BB;` | U+03BB | Lambda | Classical |
| `&#x2264;` | U+2264 | Less than or equal | Causal |
| `&#x2291;` | U+2291 | Square image of or equal | Constitutive |

**Styling convention**: `font-serif` class for all formal notation; `italic` added for text-like operators (temporal letters, epistemic letters).

### Dual Rendering Decision Tree

Based on actual usage patterns in slides.md:

1. **Is the symbol a standard Unicode character?**
   - YES: Use HTML entity in `<span class="font-serif">` (or `font-serif italic` for text operators)
   - NO: Continue to step 2

2. **Is the symbol a compound operator (shape + arrow)?**
   - YES: Continue to step 3
   - NO: Use plain text in `<span class="font-serif italic">`

3. **Is the operator inside a mathematical expression (with KaTeX rendering)?**
   - YES (component context): Use `<KaTex expr="\phi \boxright \psi" />`
   - YES (markdown `$...$`): Rely on setup/katex.ts macro fallback
   - NO (plain HTML context): Use `<LogosOp op="boxright"/>`

### Assessment: File Modification Plan

**Option A (Recommended): Add section to slidev-deck-template.md**

The custom formalism content is approximately 60-80 lines. Added to the existing 383-line template, this keeps it under 470 lines -- well within reasonable context file size. Benefits:
- Single source of truth for all Slidev deck patterns
- Agents loading slidev-deck-template.md automatically get formalism docs
- No index-entries.json changes needed

**Recommended insertion point**: After the "Component Usage" section (line 287) and before "Library Integration Patterns" (line 289).

**Content to add**:
1. "Custom Formalism Rendering" section with the three-layer overview
2. LogosOp component usage with props and example
3. KaTex component usage with props, pipeline explanation, and example
4. HTML entity pattern with the font-serif convention
5. Decision tree for choosing the right rendering method
6. Reference to setup/katex.ts for native KaTeX fallback

**Option B (Alternative): Create custom-formalism-patterns.md**

Only if the content grows beyond ~100 lines or if formalism documentation expands to cover additional operator families. Would require:
- New file at `.claude/extensions/founder/context/project/founder/patterns/custom-formalism-patterns.md`
- New index entry in `index-entries.json` with deck agent routing
- Cross-reference from slidev-deck-template.md

**deck/README.md updates**:

Add LogosOp.vue and KaTex.vue to the Components table (line 49 area):

| Component | Props | Usage |
|-----------|-------|-------|
| `LogosOp.vue` | op | Inline SVG compound operator (boxright, diamondright, circleright, dotcircleright) |
| `KaTex.vue` | expr, display | KaTeX rendering with custom SVG operator injection |

Also update the component count in the directory tree (line 49: "4 files" -> "6 files") and the Components section description.

## Decisions

- **Option A selected**: Add to slidev-deck-template.md rather than creating a separate file. The content is small enough and topically cohesive with the template reference.
- **No index-entries.json changes needed**: Since no new file is created, the existing slidev-deck-template.md entry already routes correctly.
- **deck/README.md component table must be updated**: LogosOp.vue and KaTex.vue are missing from the components documentation despite being present in the source deck.

## Recommendations

1. **Add "Custom Formalism Rendering" section to slidev-deck-template.md** after "Component Usage" (around line 287). Include the three-layer rendering overview, component API docs, HTML entity patterns, and the decision tree.

2. **Update deck/README.md component table** to include LogosOp.vue and KaTex.vue with their props and usage descriptions. Update the "4 files" count to "6 files" in the directory tree.

3. **No separate custom-formalism-patterns.md needed** at this time. Revisit if the formalism documentation grows to cover additional operator families or rendering techniques.

4. **Harmonize vertical-align values** between LogosOp.vue (-0.1em) and KaTex.vue (-0.15em) -- this is a minor inconsistency that could be noted in the documentation as intentional (math context may need slightly different alignment) or flagged as a potential fix.

## Risks & Mitigations

- **Risk**: KaTex.vue SVG definitions duplicate LogosOp.vue definitions. If one is updated without the other, visual inconsistency results.
  - **Mitigation**: Document this coupling in the context so future editors know to update both.

- **Risk**: The setup/katex.ts overlap technique is fragile -- different KaTeX versions may render the overlap differently.
  - **Mitigation**: Document it as a fallback, with the Vue components as the preferred rendering path.

## Appendix

### Files Examined
- `/home/benjamin/Projects/Logos/Vision/strategy/02-deck/slidev/components/LogosOp.vue` (27 lines)
- `/home/benjamin/Projects/Logos/Vision/strategy/02-deck/slidev/components/KaTex.vue` (55 lines)
- `/home/benjamin/Projects/Logos/Vision/strategy/02-deck/slidev/setup/katex.ts` (15 lines)
- `/home/benjamin/Projects/Logos/Vision/strategy/02-deck/slidev/slides.md` (usage at lines 218-224, 693-697)
- `.claude/extensions/founder/context/project/founder/patterns/slidev-deck-template.md` (383 lines)
- `.claude/extensions/founder/context/project/founder/deck/README.md` (297 lines)
- `.claude/extensions/founder/index-entries.json` (672 lines)

### Search Queries
- Glob: `.claude/extensions/founder/**/*.md`
- Grep: `LogosOp|KaTex|boxright|diamondright` in slides.md
- Directory listing of slidev components/ and setup/
