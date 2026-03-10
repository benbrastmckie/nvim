# Proof Conventions

## Overview

Canonical proof style conventions for modal and temporal logic.

## Proof Structure

### Basic Template

```lean
/--
[Theorem description with semantic interpretation]
[Proof strategy or key insight]
-/
theorem theorem_name (phi psi : Formula) : |- (phi.box.imp psi.box) := by
  -- Step 1: [Description]
  have h1 : |- ... := by
    [tactic proof]

  -- Step 2: [Description]
  have h2 : |- ... := by
    [tactic proof]

  -- Step 3: [Combine]
  exact [final expression]
```

## Style Guidelines

### Use Descriptive Step Comments

Good:
```lean
-- Step 1: Apply modal K axiom
have h1 : |- box(phi -> psi) -> (box phi -> box psi) :=
  Derivable.axiom [] _ (Axiom.modal_k_dist phi psi)
```

### Use Intermediate `have` Statements

Break complex proofs into named steps for clarity.

### Name Hypotheses Meaningfully

Use descriptive names like `h_deriv`, `h_ax`, `ih_imp` rather than `h1`, `h2`, `h3`.

## Axiom Application

### Direct Application

```lean
theorem modal_t_instance (phi : Formula) : |- (phi.box.imp phi) :=
  Derivable.axiom [] _ (Axiom.modal_t phi)
```

### Axiom Composition

Chain multiple axioms using transitivity helpers:
```lean
exact imp_trans h1 h2
```

## Inference Rules

### Modus Ponens

```lean
apply Derivable.modus_ponens [] phi psi
* exact h_imp
* exact h_phi
```

### Necessitation

**Important**: Only applies to theorems (empty context)

```lean
have h_box : |- box phi := by
  apply Derivable.necessitation
  exact h_theorem  -- must have empty context
```

## Documentation

### Theorem Docstrings

Include:
1. Theorem statement in natural language
2. Semantic interpretation
3. Proof strategy

Example:
```lean
/--
Modal K Distribution: `box(phi -> psi) -> (box phi -> box psi)`.

If it is necessary that phi implies psi, then if phi is necessary,
psi must also be necessary.

**Proof Strategy**: Direct application of modal K distribution axiom.
-/
```

## Common Pitfalls

### Pitfall 1: Applying Necessitation to Assumptions

Wrong: `[phi] |- box phi` via necessitation
Correct: Necessitation requires empty context

### Pitfall 2: Confusing |- and |=

|- is provability (syntax)
|= is validity (semantics)

### Pitfall 3: Ignoring Context Constraints

Check that axiom/rule preconditions are satisfied.

## Success Criteria

- [ ] Descriptive step comments
- [ ] Intermediate `have` statements
- [ ] Meaningful hypothesis names
- [ ] Explicit axiom applications
- [ ] Correct inference rule usage
- [ ] Semantic interpretation in docstrings
