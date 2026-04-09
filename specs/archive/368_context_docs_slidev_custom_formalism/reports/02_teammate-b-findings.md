# Teammate B Findings: Alternative Approaches to Formalism Rendering in Slidev

## Key Findings

### Current Implementation Analysis

The Logos slidev deck uses two redundant rendering mechanisms for custom operators:

1. **`KaTex.vue`** - A wrapper around `katex.renderToString()` that pre-processes SVG operator placeholders before passing to KaTeX, then post-processes to replace placeholder tokens with actual SVG strings. Used in `$...$ ` style inline math with custom operators like `\boxright`, `\diamondright`, etc.

2. **`LogosOp.vue`** - A direct SVG component that renders compound shape+arrow glyphs (boxright, diamondright, circleright, dotcircleright) as inline SVG elements. Used directly in HTML sections of slides via `<LogosOp op="boxright"/>`.

**The fundamental problem**: The four compound operators (box→, diamond→, circle→, dot-circle→) are not representable in standard LaTeX/KaTeX because they are composite glyphs (shape + connecting arrow as one unit). This is what forces the SVG workaround.

### Slidev's Built-in KaTeX Support

Slidev has native LaTeX support powered by KaTeX via:
- Inline math: `$expression$`
- Block math: `$$expression$$`
- Configuration via `./setup/katex.ts` using `defineKatexSetup`

The `setup/katex.ts` approach supports:
- `macros` option: Define custom `\commands` as LaTeX string expansions
- `maxExpand`: Control macro recursion depth
- `trust`: Enable HTML extension commands (`\htmlClass`, `\htmlStyle`, `\htmlId`, `\htmlData`)
- `globalGroup`: Allow `\def`/`\newcommand` to persist across math blocks

### What KaTeX Macros CAN Do

KaTeX macros can define shorthand for complex expressions:
```typescript
// setup/katex.ts
export default defineKatexSetup(() => ({
  macros: {
    '\\necessary': '\\Box',        // standard modal operators
    '\\possible': '\\Diamond',     // available via KaTeX built-in
    '\\boxright': '??',            // NO SOLUTION - not a standard glyph
  }
}))
```

Standard operators that work in KaTeX natively:
- `\Box` / `\Diamond` (modal necessity/possibility)
- `\square`, `\lozenge` (same symbols, different sizing)
- `\leq`, `\sqsubseteq` for normative operators
- All classical logic: `\land`, `\lor`, `\neg`, `\top`, `\bot`, `\forall`, `\exists`, `\lambda`

**Critical limitation**: KaTeX macros expand to LaTeX, not HTML or SVG. You cannot embed raw SVG through macro expansion alone. The `\htmlClass` etc. commands only wrap content in styled spans - they do not allow injecting arbitrary SVG.

### KaTeX Trust + htmlClass Option

KaTeX supports `\htmlClass`, `\htmlStyle`, `\htmlId`, `\htmlData` with `trust: true`. These let you:
- Add CSS classes to math spans
- Apply inline styles
- Attach data attributes

However, these are for *styling existing math content*, not for injecting SVG elements. There is no KaTeX mechanism to produce an SVG glyph from within a macro definition.

### MDC (Markdown Components) Syntax

Slidev supports MDC via `mdc: true` in frontmatter. MDC syntax:
- Inline: `:ComponentName{prop="value"}`
- Block: `::ComponentName{prop="value"}`

This is cleaner than raw HTML `<LogosOp op="boxright"/>` but accomplishes the same thing - it still calls the Vue component. It would simplify authoring but doesn't change the underlying architecture.

Example with MDC enabled:
```markdown
---
mdc: true
---

The counterfactual operator :LogosOp{op="boxright"} connects antecedent to consequent.
```

vs. current:
```html
The counterfactual operator <LogosOp op="boxright"/> connects antecedent to consequent.
```

### Markdown Transformer Approach

Slidev supports `./setup/transformers.ts` to define regex-based text transformations on slide markdown before rendering. This could enable shorthand notation:

```typescript
// setup/transformers.ts
import { defineTransformersSetup } from '@slidev/types'

export default defineTransformersSetup(() => ({
  pre: [(ctx) => {
    // Replace [[boxright]] shorthand with component HTML
    ctx.s.replace(/\[\[boxright\]\]/g, '<LogosOp op="boxright"/>')
    ctx.s.replace(/\[\[diamondright\]\]/g, '<LogosOp op="diamondright"/>')
  }]
}))
```

This would allow authoring like `[[boxright]]` in any context (inside or outside KaTeX). However, it adds complexity and cannot work inside KaTeX expressions (KaTeX processes its own input separately).

### Related Tool Approaches

**reveal.js**: Supports MathJax with custom macros defined in the Macros configuration object. MathJax has richer extensibility than KaTeX including custom output renderers, but reveal.js doesn't offer a cleaner solution to the SVG-composite-glyph problem.

**Marp**: LaTeX support is more limited than Slidev/KaTeX. No custom component system equivalent to Vue in Slidev.

**Typst**: A newer typesetting language (GitHub issue #2157 requests Slidev support). Typst has first-class support for custom operators and better SVG integration than KaTeX, but would require a major dependency shift and Slidev integration is not yet native.

---

## Alternative Approaches Evaluated

### Approach 1: Pure KaTeX Macros (Partial)
**Idea**: Define all standard modal/temporal/epistemic/normative operators as KaTeX macros in `setup/katex.ts`. Remove `KaTex.vue` component and use native `$...$` syntax throughout.

**Verdict**: Viable for ~90% of operators. The four compound operators (boxright, diamondright, circleright, dotcircleright) cannot be rendered via KaTeX macros alone since they require SVG composite glyphs. These would still need Vue components.

**Benefit**: Eliminates the `KaTex.vue` wrapper entirely. Standard operators render with better baseline alignment and consistent font metrics.

### Approach 2: KaTeX Macros + Single SVG Component
**Idea**: Keep a single `LogosOp.vue` for the four composite SVG operators. Use native KaTeX `$...$` for all standard operators. Define KaTeX macros for any shorthand needed.

**Verdict**: This is a cleaner architecture than current. It reduces the dual-path rendering to one canonical path. The `KaTex.vue` component is eliminated; standard syntax handles everything except the 4 compound operators.

**Tradeoff**: Mixing `$...$` (KaTeX) with `<LogosOp/>` (HTML component) in the same line requires the author to switch contexts. The current `<KaTex expr="..."/>` component unifies both contexts at the cost of the SVG-placeholder hack.

### Approach 3: Single Unified Vue Component (Current Approach Refined)
**Idea**: Keep `KaTex.vue` but simplify it. Move SVG definitions to a shared config file. Consider merging `LogosOp.vue` into `KaTex.vue` to eliminate redundancy.

**Verdict**: The redundancy between `KaTex.vue` and `LogosOp.vue` is the main problem. These components define the same 4 SVGs twice. A single consolidated component would be cleaner.

### Approach 4: CSS Font / Unicode Approach
**Idea**: Define a custom web font that includes the composite glyphs as Unicode Private Use Area characters. Reference them via KaTeX macros or CSS.

**Verdict**: Technically possible but impractical. Creating a custom font just for 4 symbols is significant overhead, requires font tooling, and the glyphs would not match the color theme dynamically (SVGs use `currentColor`).

### Approach 5: Markdown Transformer Shorthand
**Idea**: Use `setup/transformers.ts` to define shorthand like `[[boxright]]` that transforms to component calls.

**Verdict**: This adds a third mechanism (KaTeX + Vue component + transformer shorthand). Makes authoring less predictable and harder for collaborators to understand. Not recommended.

### Approach 6: Typst Integration
**Idea**: Migrate mathematical content to Typst syntax (once Slidev support lands).

**Verdict**: Premature. No stable Slidev-Typst integration exists. Would require rewriting all formalism in a new language.

---

## Recommended Approach

**Approach 2: KaTeX Macros + Single Minimal SVG Component**

The most consistent and maintainable architecture is:

1. **Eliminate `KaTex.vue`** - Remove the wrapper component and its SVG-placeholder hack
2. **Keep `LogosOp.vue`** (possibly rename to `Op.vue` or `FormalOp.vue`) as the sole SVG renderer for the 4 composite operators
3. **Use native `$...$` KaTeX syntax** for all standard logical operators
4. **Configure `setup/katex.ts`** with macros for frequently used shorthand:
   ```typescript
   export default defineKatexSetup(() => ({
     macros: {
       '\\nec': '\\Box',
       '\\pos': '\\Diamond',
       // Temporal operators (letter-based, already single chars in KaTeX)
       // Epistemic, normative - same
     }
   }))
   ```
5. **Authoring pattern**:
   - Standard operators: `$\Box \phi \land \Diamond \psi$` (native KaTeX)
   - Composite glyphs: `<LogosOp op="boxright"/>` in HTML context or `:LogosOp{op="boxright"}` with MDC

**Why this is better than the current approach**:
- Removes the SVG-placeholder hack in `KaTex.vue` (fragile string replacement)
- Eliminates code duplication (same 4 SVGs defined in both components)
- Native KaTeX renders with superior font metrics and MathML accessibility
- Single responsibility: `LogosOp.vue` handles only what KaTeX can't

**Remaining limitation**: The composite operators still cannot appear inline within a KaTeX expression. They must sit adjacent to math spans in HTML context. This is a fundamental constraint of KaTeX, not something any Slidev-level approach can resolve without custom KaTeX extensions (which would require forking KaTeX).

---

## Evidence / Examples

### Native KaTeX Standard Operators
All of the following work in native Slidev `$...$` syntax:
- `$\Box\phi$`, `$\Diamond\psi$` - modal operators
- `$\square$`, `$\lozenge$` - alternative sizing
- `$\land, \lor, \neg, \top, \bot$` - classical
- `$\forall x, \exists x, \lambda x$` - quantifiers
- `$\leq, \sqsubseteq$` - ordering/normative

### Composite Glyphs (SVG Required)
These have no LaTeX equivalent and require SVG:
- `\boxright` (□→): box connected to arrow
- `\diamondright` (◇→): diamond connected to arrow
- `\circleright` (○→): circle connected to arrow
- `\dotcircleright` (⊙→): dot-circle connected to arrow

These are custom Logos notation for counterfactual/causal operators and are not in any standard math font.

### KaTeX Macro Example
```typescript
// setup/katex.ts
import { defineKatexSetup } from '@slidev/types'
export default defineKatexSetup(() => ({
  macros: {
    '\\nec': '\\Box',
    '\\pos': '\\Diamond',
    '\\impl': '\\rightarrow',
    '\\bicond': '\\leftrightarrow',
  },
  trust: false,  // No need for HTML trust for standard macros
}))
```

### MDC Syntax Comparison
```markdown
<!-- Current (raw HTML) -->
<LogosOp op="boxright"/> p \rightarrow q

<!-- With MDC enabled -->
:LogosOp{op="boxright"} $p \rightarrow q$
```

---

## Confidence Level

**High** for the following conclusions:
- KaTeX macros alone cannot replace SVG components for composite glyphs (confirmed by KaTeX docs and architecture)
- KaTeX `\htmlClass`/`\htmlStyle` do not support embedding SVG (confirmed)
- Native `$...$` handles all standard operators (confirmed by KaTeX supported functions list)
- The dual `KaTex.vue` + `LogosOp.vue` pattern is redundant (confirmed by code review)
- Recommended approach (Approach 2) is technically sound

**Medium** for:
- MDC syntax maturity and stability (had breaking changes in 2024 per GitHub issues)
- Exact authoring ergonomics tradeoff between `<LogosOp/>` and mixed `$...$` + `<LogosOp/>`

**Low** for:
- Typst integration timeline (depends on Slidev upstream)
- Whether a custom KaTeX extension could embed SVG in math flow (would require deep KaTeX internals knowledge)
