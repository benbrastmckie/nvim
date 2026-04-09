---
title: Teammate A Findings — Current Formalism Rendering and Best Approach
date: 2026-04-07
task: 368
role: Primary Approach Researcher
---

# Key Findings

The Slidev presentation at `slides.md` uses **three distinct, inconsistent mechanisms** to render
formalism (logical operators, symbols, and notation):

1. **`LogosOp` Vue component** — inline SVG for compound shape+arrow operators
2. **HTML entities** (`&#x25A1;`, `&#x2227;`, etc.) — for standard Unicode logic symbols
3. **`\htmlStyle`-based KaTeX macros** — defined in `setup/katex.ts`, never actually invoked in slides
4. **`KaTex.vue` component** — a custom Vue wrapper around KaTeX; never used anywhere in `slides.md`

The `KaTex.vue` component and `setup/katex.ts` macros represent **dead infrastructure**: they were
built but not wired up. All actual formalism in `slides.md` goes through `LogosOp` or raw HTML
entities, entirely outside the KaTeX pipeline.

---

# Current Usage Patterns

## Pattern 1: `LogosOp` Vue Component (used in slides.md)

Used for the four compound operators (shape + arrow glyphs) that KaTeX cannot render cleanly:

| Usage location | Operators used |
|---|---|
| S4 How Training Works (line 218) | `boxright`, `diamondright`, `circleright`, `dotcircleright` |
| A1b Logos Operators (lines 695-696) | `boxright`, `diamondright`, `circleright`, `dotcircleright` |

Total: **8 instances** of `<LogosOp op="..."/>` across 2 slides.

Example usage:
```html
<div><b>Counterfactual + Modal:</b> <span class="font-serif">
  <LogosOp op="boxright"/>, <LogosOp op="diamondright"/>, &#x25A1;, &#x25C7;
</span></div>
```

The `LogosOp` component renders pure inline SVG (defined in `components/LogosOp.vue`). It has no
dependency on KaTeX and works entirely in the Vue/HTML layer. The SVG geometry is duplicated between
`LogosOp.vue` and `KaTex.vue`.

## Pattern 2: Raw HTML Entities (used in slides.md)

Used for all other logic symbols — standard Unicode characters expressed as hex entities:

| Entity | Symbol | Meaning | Occurrences |
|---|---|---|---|
| `&#x25A1;` | □ | Modal necessity | ~4 |
| `&#x25C7;` | ◇ | Modal possibility | ~4 |
| `&#x2227;` | ∧ | Conjunction | ~4 |
| `&#x2228;` | ∨ | Disjunction | ~4 |
| `&#xAC;` | ¬ | Negation | ~4 |
| `&#x22A4;` | ⊤ | Top/True | ~4 |
| `&#x22A5;` | ⊥ | Bottom/False | ~4 |
| `&#x2200;` | ∀ | Universal quantifier | ~4 |
| `&#x2203;` | ∃ | Existential quantifier | ~4 |
| `&#x2193;` | ↓ | Cross-temporal store | ~4 |
| `&#x2191;` | ↑ | Cross-temporal recall | ~4 |
| `&#x22A1;` | ⊡ | Stability | ~4 |
| `&#x21AA;` | ↪ | Epistemic might/must | ~4 |
| `&#x227A;` | ≺ | Preference | ~4 |
| `&#x21A6;` | ↦ | Normative mapping | ~4 |
| `&#x2264;` | ≤ | Essence/Ground | ~4 |
| `&#x2291;` | ⊑ | Ground | ~4 |
| `&#x2261;` | ≡ | Propositional identity | ~2 |
| `&#x3BB;` / `&#x03BB;` | λ | Lambda abstraction | ~4 |
| `&#x21D2;` | ⇒ | Reduction | ~2 |
| `&#x25BC;` | ▼ | Downward arrow (UI nav) | 4 |

Total: **~70+ HTML entity uses** across 3 slides (S4, A1b Logos Operators, A1b Appendix Operators).

These entities are typically wrapped in `<span class="font-serif">` or `<code>` tags to control
rendering style — another inconsistency.

## Pattern 3: `setup/katex.ts` Macros (defined but never invoked)

```typescript
export default defineKatexSetup(() => {
  return {
    trust: true,
    strict: false,
    macros: {
      '\\boxright': '\\mathrel{\\Box\\htmlStyle{margin-left:-0.55em}{\\rightarrow}}',
      '\\diamondright': '\\mathrel{\\Diamond\\htmlStyle{margin-left:-0.55em}{\\rightarrow}}',
      '\\circleright': '\\mathrel{\\bigcirc\\htmlStyle{margin-left:-0.55em}{\\rightarrow}}',
      '\\dotcircleright': '\\mathrel{\\odot\\htmlStyle{margin-left:-0.55em}{\\rightarrow}}',
    },
  }
})
```

These macros use `\htmlStyle` with negative `margin-left` to visually "merge" separate KaTeX glyphs
into compound operators. This is a **CSS kerning hack** — not a true compound glyph — and produces
noticeably different visual output than the SVG-based `LogosOp` component.

These macros are **never called** in `slides.md` because there is no `$...$` or `$$...$$` math in
the slides, and the `KaTex.vue` component wrapper is also never used.

## Pattern 4: `KaTex.vue` Component (defined but never used in slides.md)

This component wraps KaTeX rendering with SVG placeholder substitution for the same four compound
operators. It handles both inline and display math. Despite being the most sophisticated approach
(combining KaTeX typesetting with precise SVG glyphs), it is **completely unused** in `slides.md`.

---

# Inconsistencies Identified

| Issue | Description |
|---|---|
| **Three rendering paths** | Same logical symbols rendered via LogosOp, HTML entities, or (potentially) KaTeX — no single pipeline |
| **Dead KaTeX infrastructure** | `KaTex.vue` and `setup/katex.ts` macros built but not used |
| **SVG geometry duplicated** | `LogosOp.vue` and `KaTex.vue` define identical SVG paths for the 4 compound operators |
| **HTML entities are opaque** | `&#x25A1;` is not readable in source; Unicode literals would be more maintainable |
| **Inconsistent font context** | Some entities in `<span class="font-serif">`, some in `<code>`, some bare |
| **\htmlStyle macro fragility** | The kerning hack (`margin-left:-0.55em`) is font/size sensitive and inconsistent with SVG glyphs |
| **No inline math** | Despite KaTeX being available via `$...$` syntax, the slides use zero inline math notation |

---

# Recommended Approach

## For This Specific Application

The slides are a **business pitch deck**, not a math paper. The formalism appears only in a few
"operator catalog" slides as visual reference — not in running mathematical prose. This constrains
the recommendation significantly.

### Recommendation: Consolidate on `LogosOp` + Unicode Literals, Drop KaTeX

**Rationale:**

1. **No inline math is used or needed.** The `$...$` KaTeX path is appropriate for mathematical
   prose. These slides list operators in structured HTML divs, not in running text. KaTeX is
   architectural overkill for this use case.

2. **`LogosOp` is the right tool for compound operators.** It produces clean, scalable SVG glyphs
   that are visually correct and consistent. The four compound operators (boxright, diamondright,
   circleright, dotcircleright) genuinely cannot be represented cleanly with standard Unicode or
   KaTeX kerning hacks.

3. **Replace HTML entities with Unicode literals.** Replace `&#x2227;` with `∧` directly in source.
   Modern HTML/Vue handles Unicode fine, and the source becomes readable. Wrap in a shared CSS class
   for consistent font rendering rather than ad-hoc `class="font-serif"` spans.

4. **Remove or repurpose the dead infrastructure.** `KaTex.vue` and the `\htmlStyle` macros in
   `setup/katex.ts` should either be removed (if no inline math is planned) or documented as
   future-use. The duplicated SVG geometry should live in one place only.

### Implementation

**Step 1: Create a single CSS class for logic symbols**
```css
/* In style or tailwind config */
.logos-symbol { font-family: serif; }
```

**Step 2: Replace all HTML entities with Unicode literals**
```html
<!-- Before -->
<span class="font-serif">&#x2227;, &#x2228;, &#xAC;</span>

<!-- After -->
<span class="logos-symbol">∧, ∨, ¬</span>
```

**Step 3: Keep `LogosOp` for the four compound operators**
No change needed — this is already the correct approach.

**Step 4: Consolidate SVG definitions**
Remove the duplicated SVG paths from `KaTex.vue` or point both components to a shared constant.

**Step 5: Remove or archive dead infrastructure**
- Either delete `KaTex.vue` and the macros from `setup/katex.ts`
- Or add a comment documenting that these are reserved for slides with inline math content

---

# Evidence and Examples

## Why KaTeX macros are inferior to LogosOp SVGs here

The `\htmlStyle` kerning hack:
```
\mathrel{\Box\htmlStyle{margin-left:-0.55em}{\rightarrow}}
```

Produces: □ and → drawn separately then overlapped with negative margin. This is fragile — it
depends on the rendered font metrics. On different zoom levels or export (PDF), the alignment will
shift. The `LogosOp` SVG version draws both shapes in a single coordinated viewBox with precise
geometry, which is visually superior and robust.

## Why Slidev's built-in `$...$` math is not the answer

Slidev's native KaTeX path (`$\Box\to$`) would work for standard math symbols but:
- Cannot produce compound glyphs (boxright etc.) without the `\htmlStyle` hack
- Would require replacing all operator list divs with math mode text, which changes visual layout
- Is designed for mathematical prose, not styled HTML operator catalogs

## Slidev + KaTeX official capability

Per official docs (sli.dev/features/latex and sli.dev/custom/config-katex):
- `$...$` inline and `$$...$$` block math are supported natively
- Custom macros configurable in `setup/katex.ts` via `defineKatexSetup`
- `trust: true` required for `\htmlStyle` usage
- KaTeX 0.16.44 is the installed version (current/stable)

---

# Confidence Level

**High** for the inventory and diagnosis of current usage.

**Medium-High** for the recommendation. The recommendation to stay with LogosOp + Unicode literals
is well-grounded given the pitch deck use case. The main uncertainty is whether the user plans to
add inline math notation to these slides in the future — if so, the KaTex.vue infrastructure would
be worth activating rather than removing.

---

# Sources

- [LaTeX | Slidev](https://sli.dev/features/latex)
- [Configure KaTeX | Slidev](https://sli.dev/custom/config-katex)
- [Supported Functions · KaTeX](https://katex.org/docs/supported.html)
- [KaTeX Options](https://katex.org/docs/options.html)
