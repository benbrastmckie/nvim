# Teammate C: Critic Analysis — Formalism Rendering Approach

**Task**: 368 — Custom Formalism Rendering in Slidev Presentation
**Date**: 2026-04-07
**Scope**: Critical analysis of the rendering approach in `/strategy/02-deck/slidev/`

---

## Key Findings

The presentation uses **two entirely separate rendering mechanisms** for the same four custom operators (`boxright`, `diamondright`, `circleright`, `dotcircleright`), plus **three distinct rendering approaches** for other symbols. No single mechanism is canonical. The approaches are partially inconsistent, and the `KaTex.vue` component appears unused in the actual slides despite being the most sophisticated implementation.

---

## Inconsistencies Found

### 1. Dual Definition of the Same Four Operators (Critical)

The four custom operators are defined twice, in parallel, with different SVG geometry:

**LogosOp.vue** (standalone Vue component):
```
vertical-align: -0.1em
```

**KaTex.vue** (inline SVG within KaTeX post-processing):
```
vertical-align: -0.15em
```

These differ in vertical alignment by 0.05em — a small but visible baseline shift when the same operator appears adjacent to other math or text. No slides currently use `KaTex.vue` directly; all four slides using these operators use `<LogosOp op="..."/>` inline in HTML. The `KaTex.vue` component's SVG injection machinery is thus dead code in the current presentation.

### 2. Three Distinct Rendering Approaches in slides.md

**Approach A — LogosOp Vue component** (slides S4, A1b):
```html
<LogosOp op="boxright"/>
```
Used on lines 218, 223, 695, 696. Renders SVG inline via Vue component.

**Approach B — HTML Unicode entities** (slides S4, A1b):
```html
&#x25A1;, &#x25C7;
```
Used on lines 218, 681, 693. Plain Unicode glyphs for `□` and `◇`. These are NOT the compound arrow forms — they are the bare modal operators without the directional arrow component.

**Approach C — KaTeX via setup/katex.ts macros** (potentially available):
```latex
\boxright
```
Defined in `setup/katex.ts` using `htmlStyle` margin hack. This approach is available inside `$$...$$` or `$...$` math blocks, but **no math blocks appear anywhere in slides.md**. The macro definitions in `setup/katex.ts` are completely unused.

### 3. Inconsistent Mixing of LogosOp with Unicode on Same Line (Slide S4, Line 218)

```html
<LogosOp op="boxright"/>, <LogosOp op="diamondright"/>, &#x25A1;, &#x25C7;
```

`boxright` renders as a custom SVG glyph (□→ compound), while `&#x25A1;` renders as the bare Unicode `□` in whatever font the browser picks. These are *different things* (compound vs. bare), so this is semantically intentional — but visually they appear side-by-side in a way that mixes font-rendered Unicode with SVG-rendered graphics, producing inconsistent sizing, weight, and baseline alignment. There is no visual unification.

### 4. Slide A1b (line 695-696) Uses Different Inline Font Size

```html
<span style="font-size: 12px;"><LogosOp op="boxright"/>, <LogosOp op="diamondright"/></span>
```

Slide S4 (line 218) has no such font-size constraint:
```html
<span class="font-serif"> <LogosOp op="boxright"/>, ...
```

The same operator renders at different sizes in different slides. This is presentational inconsistency, not semantic inconsistency, but it creates visual discord in a professional pitch.

---

## Fragility Analysis

### 1. Placeholder Collision Risk in KaTex.vue

The substitution pattern in `KaTex.vue` uses `\text{##SVG0##}`, `\text{##SVG1##}`, etc. as placeholders. The loop replaces one occurrence at a time (using `while (expr.includes(macro))`), incrementing `i` per replacement, then does a string replace on the rendered KaTeX HTML.

**Edge cases that can break this:**

- **KaTeX escapes or transforms `##SVG0##`**: KaTeX's `\text{}` is treated as a text node. KaTeX may HTML-escape the `#` characters or wrap them in spans. If the rendered output is `##SVG0##` as literal characters embedded in KaTeX span markup, the final `rendered.replace(key, svg)` should work — but only if the placeholder survives KaTeX processing character-for-character. This is not validated.

- **Multiple identical operators**: If the same operator (e.g., `\boxright`) appears twice, the first `while` loop iteration handles both by repeatedly replacing, incrementing `i` each time. This is correct but produces `##SVG0##`, `##SVG1##` for two instances of the same operator. The logic is subtly non-obvious and the final replacement must match the exact string KaTeX outputs.

- **Macro substring collisions**: `\boxright` contains no other macro as a substring, so this specific set is safe. But adding `\box` as a new macro would cause `\boxright` to be partially matched first if iteration order is wrong. The current operator names avoid this, but it is an undocumented constraint.

- **Operator in a subscript/superscript context**: `\text{##SVG0##}` inside a subscript context (`_{...}`) would be scaled by KaTeX. The SVG is 1em tall — if KaTeX scales the text node, the SVG injection point will be inside a scaled span and the 1em height will itself be scaled. This produces incorrect sizing.

### 2. KaTeX `htmlStyle` Macro Approach (setup/katex.ts)

The macro `\boxright` is defined as:
```
\mathrel{\Box\htmlStyle{margin-left:-0.55em}{\rightarrow}}
```

This works only when `trust: true` is set (already done). But:

- `htmlStyle` is a KaTeX extension, not standard TeX. If KaTeX removes or renames it, the macro silently breaks and outputs malformed HTML.
- The `-0.55em` negative margin is a visual hack calibrated for one specific font size. In a presentation, if the surrounding font size changes (slide zoom, PDF export, different screen DPI), the overlap may be too tight or too loose.
- KaTeX does not guarantee that `htmlStyle` produces accessible HTML — it injects raw style attributes into the output tree.

### 3. `v-html` XSS Risk (Low in This Context)

Both `LogosOp.vue` (via `v-html="ops[op].paths"`) and `KaTex.vue` (via `v-html="html"`) use `v-html`. In `LogosOp.vue`, the SVG content is hardcoded in the component itself, so there is no user input injection risk. In `KaTex.vue`, the `expr` prop comes from the template author (trusted), so the risk is low for a local presentation — but it is architecturally unsound for any deployment where slide content comes from untrusted sources.

---

## Maintenance Risks

### 1. KaTeX Version Coupling

**`setup/katex.ts`** relies on:
- `htmlStyle` command (extension, non-standard)
- `trust: true` option
- The macro expansion mechanism

**`KaTex.vue`** relies on:
- KaTeX's `renderToString` output format — specifically that `\text{##SVG0##}` produces a text node with the literal string `##SVG0##` (not escaped or transformed)
- The output HTML structure being replaceable with raw string substitution

A KaTeX minor version bump that changes `\text{}` output escaping or wrapping would silently break the SVG injection — with no error, just missing operators.

### 2. Two Maintenance Surfaces for the Same Four Operators

Adding a fifth operator (e.g., `\squareright`) requires updates in **four places**:
1. `LogosOp.vue` — `ops` object
2. `KaTex.vue` — `svgOperators` object
3. `setup/katex.ts` — `macros` object
4. Any slides using the operator

There is no single source of truth. SVG geometry is duplicated with slight differences already (the vertical-align discrepancy). Future contributors have no way to know which definition is authoritative.

### 3. The KaTex.vue Component is Unused Dead Code

Despite being the most complex piece of infrastructure, `KaTex.vue` is not imported or used anywhere in `slides.md`. No `<KaTex>` tags appear in the file. The component exists, defines all four SVG operators with different geometry than `LogosOp.vue`, and is silently unreachable. This is a maintenance liability: future contributors may believe it is the intended rendering path and start using it, introducing the baseline inconsistency.

### 4. setup/katex.ts Macros Are Also Unused

No `$...$` or `$$...$$` math blocks appear anywhere in `slides.md`. The KaTeX macro definitions in `setup/katex.ts` are dead code. The operators have no path into actual KaTeX rendering.

---

## Missing Coverage

### 1. Operators Rendered as Plain Text or Unicode

The following operators appear in the slides as HTML Unicode entities or plain text, without any custom rendering:

| Operator | Current rendering | Slide | Notes |
|----------|------------------|-------|-------|
| `□` (necessity) | `&#x25A1;` | S4, A1b | Bare Unicode, font-dependent |
| `◇` (possibility) | `&#x25C7;` | S4, A1b | Bare Unicode, font-dependent |
| `≤` (essence/ground) | `&#x2264;` | A1b | Math operator as HTML entity |
| `⊑` | `&#x2291;` | A1b | Subset/ground as HTML entity |
| `↩` (epistemic) | `&#x21AA;` | S4, A1b | Unicode arrow, no custom rendering |
| `↦` (normative) | `&#x21A6;` | S4, A1b | Unicode map-to, no custom rendering |
| `⊣` (cross-temporal) | `&#x22A1;` | S4 | Box-times, may not be right glyph |
| `↓, ↑` (store/recall) | `&#x2193;, &#x2191;` | S4, A1b | Generic arrows |
| `≺` (preference) | `&#x227A;` | S4, A1b | Precedes symbol |

Many of these are rendered in a `font-serif italic` span, which means their appearance depends entirely on which serif font the browser/Slidev loads. On systems without a good serif math font, glyphs will be substituted with whatever the OS provides, creating inconsistent visual results across machines.

### 2. No Rendering for Mixed Math+Operator Expressions

There is no mechanism to render expressions like `A \boxright B` where `A` and `B` are mathematical expressions and `\boxright` is the custom operator. The current approach only renders the operator symbol in isolation. A full formalism slide would require the KaTeX+SVG injection path (KaTex.vue) to be working and in use.

### 3. No Fallback for Missing `op` Values in LogosOp.vue

`LogosOp.vue` has a fallback: `<span v-else>{{ op }}</span>` — it renders the string name of the operator if the key is not found. This is a silent failure mode: a typo in `op="boxrigt"` would render the text "boxrigt" rather than throwing any error.

---

## Accessibility Concerns

### 1. SVG Operators Have No `aria-label` or `title`

The SVG rendered by `LogosOp.vue` has no `aria-label`, `role="img"`, or `<title>` element. Screen readers will either skip the SVG or read nothing meaningful. For a professional investor presentation that may be shared as an HTML file, this is a gap.

### 2. Unicode Entities Are Better for Accessibility

Ironically, the `&#x25A1;` approach is more accessible than the SVG approach: screen readers can interpret Unicode code points using their math or symbol dictionaries. The SVG approach trades accessibility for visual fidelity.

### 3. PDF Export May Fail to Render Custom SVGs Correctly

Slidev's PDF export (Playwright-based) should capture SVGs, but the `v-html` inline SVG injection approach in `KaTex.vue` (post-KaTeX rendering) is not well-tested against PDF export pipelines. The `LogosOp.vue` direct SVG is safer for PDF export. This is an unvalidated assumption.

---

## Portability

### 1. Not Portable Away from Slidev+Vue

The entire approach is Vue-component-specific:
- `LogosOp.vue` requires a Vue template rendering context
- `KaTex.vue` requires Vue + KaTeX as a JS import
- The Slidev `setup/katex.ts` mechanism (`defineKatexSetup`) is Slidev-specific

If the presentation is migrated to Reveal.js, Quarto, or any non-Vue framework, all custom operator rendering must be rebuilt from scratch. There are no portable fallbacks (e.g., LaTeX macros, MathJax configurations).

### 2. KaTex.vue Imports KaTeX Directly (Duplicating Slidev's Bundle)

`KaTex.vue` imports `katex` directly: `import katex from 'katex'`. Slidev also bundles KaTeX for its native math rendering. This means KaTeX is potentially bundled twice if `KaTex.vue` is ever actually used in a rendered slide, increasing bundle size unnecessarily.

---

## Performance Concerns

### 1. Runtime SVG Injection in KaTex.vue is Computed Per-Render

The `html` computed property in `KaTex.vue` runs:
1. String-replace loop over all operators
2. `katex.renderToString()` — synchronous, but not free for complex expressions
3. String-replace loop over all placeholders in the rendered HTML

For a static presentation with no reactive math inputs, this computed value is effectively constant — but Vue will recompute it on any reactive dependency change. For the current use case (no reactivity), this is not a real concern. For a hypothetical interactive use, it would recompute on every keystroke if `expr` were a `v-model`.

---

## Confidence Level

**High confidence** on:
- KaTex.vue is unused (confirmed by searching all of slides.md — zero `<KaTex` tags found)
- setup/katex.ts macros are unused (no `$...$` math blocks in slides.md)
- The vertical-align discrepancy between LogosOp.vue (-0.1em) and KaTex.vue (-0.15em)
- The four-place maintenance surface problem
- Font-dependency of Unicode entity rendering

**Medium confidence** on:
- KaTeX placeholder survival through renderToString (requires runtime testing to confirm)
- PDF export behavior for inline SVGs
- Screen reader behavior for the SVG operators

**Low confidence** on**:
- Whether `htmlStyle` in setup/katex.ts is intended as a fallback or was the original approach before LogosOp.vue was created — git history would clarify intent
