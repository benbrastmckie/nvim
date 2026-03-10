# Notation Conventions

## Notation Architecture

The project uses a two-tier notation system:

1. **shared-notation.typ** - Common notation across all documents
2. **{project}-notation.typ** - Project-specific extensions

### Import Pattern

Project-specific modules import and re-export shared notation:

```typst
// In project-notation.typ
#import "shared-notation.typ": *

// Add project-specific notation...
```

Chapters import from the project-specific module:

```typst
// In chapters/01-syntax.typ
#import "../template.typ": *
```

The template.typ imports notation, making it available to chapters.

---

## Shared Notation

### Modal Operators

| Symbol | Command | Description |
|--------|---------|-------------|
| `$square.stroked$` | `nec` | Necessity |
| `$diamond.stroked$` | `poss` | Possibility |

### Truth and Satisfaction

| Symbol | Command | Description |
|--------|---------|-------------|
| `$tack.r.double$` | `trueat` | Truth at / satisfaction |
| `$tack.r.double.not$` | `ntrueat` | Not true at |

### Proof Theory

| Symbol | Command | Description |
|--------|---------|-------------|
| `$tack.r$` | `proves` | Derivability |
| `$Gamma$` | `ctx` | Context |

### Meta-Variables

| Symbol | Command | Description |
|--------|---------|-------------|
| `$phi.alt$` | `metaphi` | Formula variable |
| `$psi$` | `metapsi` | Formula variable |
| `$chi$` | `metachi` | Formula variable |

### Model Notation

| Symbol | Command | Description |
|--------|---------|-------------|
| `$cal(M)$` | `model` | Model |
| `tuple(a, b, c)` | `tuple` | Angle-bracket tuple |
| `$:=$` | `define` | Definition |

### Propositional Connectives

| Symbol | Command | Description |
|--------|---------|-------------|
| `$arrow.r$` | `imp` | Implication |
| `$not$` | `lneg` | Negation |
| `$bot$` | `bottom` | Bottom |
| `$top$` | `top` | Top |

### Code Cross-References

| Command | Usage | Output |
|---------|-------|--------|
| `srcref(module, name)` | `srcref("Core.Syntax", "Formula")` | `Core.Syntax.Formula` |
| `coderef(name)` | `coderef("completeness_theorem")` | `completeness_theorem` |

---

## Project-Specific Notation

Each project can define additional notation. Examples:

### Temporal Operators

| Symbol | Command | Description |
|--------|---------|-------------|
| `$H$` | `allpast` | Always past (H) |
| `$G$` | `allfuture` | Always future (G) |
| `$P$` | `somepast` | Sometime past (P) |
| `$F$` | `somefuture` | Sometime future (F) |

### Frame Structure

| Symbol | Command | Description |
|--------|---------|-------------|
| `$cal(F)$` | `frame` | Frame |
| `$W$` | `worlds` | Worlds set |
| `$R$` | `relation` | Accessibility relation |

### Model Structure

| Symbol | Command | Description |
|--------|---------|-------------|
| `$V$` | `valuation` | Valuation function |
| `$"dom"$` | `domain` | Domain function |

### Metalanguage

| Command | Description |
|---------|-------------|
| `Iff` | Metalanguage biconditional (italic "iff") |
| `overset(base, top)` | Place text above symbol |

---

## Creating New Project Notation

When adding a new project:

1. Create `notation/{project}-notation.typ`
2. Import shared notation: `#import "shared-notation.typ": *`
3. Add project-specific commands
4. Update template.typ to import project notation
5. Document new commands in this file

### Example Structure

```typst
// project-notation.typ
#import "shared-notation.typ": *

// Project-specific operators
#let layerzero = $cal(L)_0$
#let layerone = $cal(L)_1$
// ... etc
```

---

## Best Practices

1. **Prefer semantic names** over cryptic abbreviations
2. **Document all commands** in conventions files
3. **Re-export shared notation** to avoid double imports
4. **Use consistent naming** (command name matches concept)
5. **Group related commands** under clear section headers
