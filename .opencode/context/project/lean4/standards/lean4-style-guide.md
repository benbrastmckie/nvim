# Lean 4 Style Guide

## Naming Conventions

### Theorems and Lemmas
- Use `snake_case`
- Prefix with namespace: `Nat.add_comm`
- Include key hypotheses in name: `add_pos_of_pos_of_pos`

### Variables and Functions
- Local variables: `x`, `y`, `n`, `m`
- Hypotheses: `h`, `h1`, `h2` or descriptive `hpos`, `hlt`
- Types: `α`, `β` for generic types
- Functions: `f`, `g` or descriptive

### Type Classes
- Use `PascalCase`: `Monoid`, `Ring`, `OrderedSemiring`

## Formatting

### Indentation
- 2 spaces per level
- Align tactic blocks

### Line Length
- Target ~100 characters
- Break long expressions at operators

### Blank Lines
- One blank line between top-level definitions
- No blank lines within proof blocks

## Proof Structure

### Term Mode vs Tactic Mode
Prefer tactic mode for:
- Complex proofs with many steps
- Proofs requiring case analysis

Prefer term mode for:
- Simple one-liner proofs
- Definitional equalities

### Tactic Block Format
```lean
theorem foo : P := by
  intro h
  apply lemma
  exact h
```

### Case Analysis Format
```lean
cases h with
| left hl =>
  simp [hl]
| right hr =>
  exact hr
```

## Documentation

### Doc Comments
```lean
/-- Brief description of the theorem.

More details if needed.
-/
theorem myTheorem : P := ...
```

### Module Documentation
```lean
/-!
# Module Title

Brief overview of this module.

## Main definitions
- `Foo`: description
- `Bar`: description

## Main theorems
- `foo_bar`: description
-/
```

## Import Organization

1. Standard library
2. Mathlib (alphabetical)
3. Project imports (alphabetical)

```lean
import Init.Data.List
import Mathlib.Data.Nat.Basic
import Mathlib.Data.List.Sort
import MyProject.Basic
```

## Common Patterns

### Hypothesis Extraction
```lean
-- Prefer
obtain ⟨h1, h2⟩ := h

-- Over
have h1 := h.1
have h2 := h.2
```

### Tactic Chaining
```lean
-- For short sequences
simp only [h1, h2]; ring

-- For longer sequences, use separate lines
simp only [h1, h2]
ring
```

### Anonymous Constructors
```lean
-- Prefer
⟨a, b, c⟩

-- Over
Prod.mk a (Prod.mk b c)
```
