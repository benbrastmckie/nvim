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

The Bimodal Reference Manual's actual Lean-citation commands, defined in `template.typ`, are
`leansrc` and `leanref` (documented here as the canonical example; a project may name its own
equivalents differently, but should follow this shape):

| Command | Usage | Output |
|---------|-------|--------|
| `leansrc(module, name)` | `leansrc("Metalogic.Soundness", "soundness")` | Block-level attribution: a blockquote-style line reading `Metalogic.Soundness.soundness.`, placed on its own line after a colon-terminated sentence. |
| `leanref(name)` | `leanref("soundness")` | Inline monospace identifier, no path -- for a declaration mentioned in running prose. |

A file or directory cited as a file, not as a declaration, uses a plain backtick-quoted,
repo-root-relative path (for example `` `FormalSystem/Syntax/Formula.lean` ``) instead of either
command above -- never a module-relative path, which cannot be resolved against the repository
root.

`srcref(module, name)` and `coderef(name)` are an earlier, superseded naming for the same two
roles; no project currently calls either. Prefer `leansrc`/`leanref` (or an equivalent pair
following this doc's usage/output shape) for new work.

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
