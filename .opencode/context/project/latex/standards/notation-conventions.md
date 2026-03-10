# Notation Conventions

## Custom Notation Package Overview

A custom notation package (e.g., `notation.sty`) provides consistent notation for LaTeX documentation. Always use project macros rather than raw LaTeX symbols.

## Structural Notation

### Tuple Notation
| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| Tuple | `\tuple{...}` | ⟨...⟩ | Ordered structures (frames, spaces) |

Use `\tuple{}` for structured mathematical objects:
- Frames: `\tuple{W, R}`
- Models: `\tuple{F, V}`
- Algebraic structures: `\tuple{A, +, \cdot}`

### Anti-Pattern: Bare Parentheses for Structures

**Do not use bare parentheses** for structured mathematical objects. Always use `\tuple{}`.

| Correct | Incorrect | Context |
|---------|-----------|---------|
| `\tuple{S, \leq}` | `(S, \leq)` | Ordered set |
| `\tuple{W, R}` | `(W, R)` | Kripke frame |
| `\tuple{F, V}` | `(F, V)` | Model |
| `\tuple{A, +, \cdot}` | `(A, +, \cdot)` | Algebraic structure |

**Rationale**: The `\tuple{}` macro produces angled brackets that visually distinguish structured objects from ordinary groupings or function arguments.

## Logical Notation

### Propositional Connectives
| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| Negation | `\neg` | ¬ | Logical not |
| Conjunction | `\land` | ∧ | Logical and |
| Disjunction | `\lor` | ∨ | Logical or |
| Implication | `\to` | → | Material conditional |
| Biconditional | `\iff` | ⟺ | If and only if |

### Modal Operators
| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| Necessity | `\Box` | □ | Necessarily |
| Possibility | `\Diamond` | ◇ | Possibly |

### Semantic Relations
| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| Satisfies | `\models` | ⊨ | Truth/satisfaction |
| Entails | `\vdash` | ⊢ | Syntactic derivability |
| Semantic brackets | `\sem{t}` | ⟦t⟧ | Denotation |

## Set Notation

### Basic Set Operations
| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| Set | `\set{...}` | {…} | Set braces |
| Element | `\in` | ∈ | Membership |
| Subset | `\subseteq` | ⊆ | Inclusion |
| Union | `\cup` | ∪ | Set union |
| Intersection | `\cap` | ∩ | Set intersection |

### Biconditional "iff"

| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| If and only if | `\iff` | *iff* | Biconditional in prose |

**Important**: Always use the `\iff` macro rather than plain text `iff` in definition bodies, theorems, proofs, and remarks:

```latex
% CORRECT: Using \iff macro
A set is closed \iff its complement is open.

% INCORRECT: Plain text "iff"
A set is closed iff its complement is open.
```

The macro provides consistent italic formatting and proper surrounding spacing.

## Type-Theoretic Notation

### Typing vs Set Membership

When declaring the type of a mathematical object, prefer colon (`:`) over set membership (`\in`).

| Notation | Meaning | Preferred Context |
|----------|---------|-------------------|
| `x : A` | x has type A | Type declarations, function signatures |
| `x \in A` | x is a member of set A | Set-theoretic assertions, subset relations |

**Default preference**: Use `:` for typing judgments (e.g., stating that an element belongs to a space, a world belongs to a world set, or a function has a particular signature).

### Examples

| Correct | Incorrect | Context |
|---------|-----------|---------|
| `w : W` | `w \in W` | Declaring world type |
| `f : A \to B` | `f \in A \to B` | Function signature |
| `\sigma : D \to W` | `\sigma \in D \to W` | History type |

### When to Use Set Notation

Set membership notation (`\in`) is appropriate when:

1. **Explicit subset relations**: "Let $A \subseteq S$ with $s \in A$"
2. **Set comprehension results**: "$s \in \{t : S \mid \phi(t)\}$"
3. **Cardinality/counting arguments**: "$|{x \in S : P(x)}| = n$"
4. **Set-theoretic operations**: "$s \in A \cap B$", "$s \in A \cup B$"

**Rule of thumb**: Use `:` for type declarations (what kind of thing is it?), use `\in` for set membership assertions (is it in this particular set?).

## Code Cross-References

| Concept | Macro | Usage |
|---------|-------|-------|
| Source reference | `\srcref{Module}{def}` | Reference to implementation |
| File reference | `\fileref{path}` | Reference to source file |

### Example
```latex
See \srcref{Core.Semantics}{evaluate} for the implementation.
```

## Usage Guidelines

1. **Always use macros**: Never type `\Box` directly; define and use custom macros
2. **Consistent spacing**: Macros handle spacing automatically
3. **Semantic meaning**: Choose macros by meaning, not appearance
4. **Cross-references**: Always link to implementations when available
5. **Prefer `+` over `\oplus`**: When context makes the operation clear (e.g., within a semilattice discussion), use plain `+` rather than `\oplus`

## Meta-Variables

| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| Formula A | `\metaA` | A | Meta-variable for formulas |
| Formula B | `\metaB` | B | Meta-variable for formulas |
| Formula φ | `\metaphi` | φ | Greek meta-variable |
| Formula ψ | `\metapsi` | ψ | Greek meta-variable |

## Variable Naming

### Object Language Variables
| Variable | Usage | Example |
|----------|-------|---------|
| v₁, v₂, v₃, ... | Object language variables (bound by quantifiers) | `$v_1, v_2, v_3, \ldots$` |

### Metalanguage Variables
| Variable | Usage | Example |
|----------|-------|---------|
| x, y, z | General metalanguage variables | `$x, y, z$` |
| t, s | Time points or elements | `$t < s$` |
| τ, σ | Functions or assignments | `$\tau : A \to B$` |

**Important**: Maintain clear separation between object language and metalanguage variables.
