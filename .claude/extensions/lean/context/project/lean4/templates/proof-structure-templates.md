# Proof Structure Templates

## Overview

This file offers templates for common proof structures in Lean 4.

## Templates

### Induction

```lean
theorem myTheorem (n : Nat) : P n := by
  induction n with
  | zero =>
    -- Base case
    sorry
  | succ n ih =>
    -- Inductive step
    sorry
```

### Case Analysis

```lean
theorem myTheorem (p : Prop) : P p := by
  cases (em p) with
  | inl hp =>
    -- Case 1: p is true
    sorry
  | inr hnp =>
    -- Case 2: p is false
    sorry
```

### Rewrite

```lean
theorem myTheorem (a b c : Nat) (h1 : a = b) (h2 : b = c) : a = c := by
  rw [h1, h2]
```

### Introduction

```lean
theorem myTheorem : ∀ x, P x → Q x := by
  intro x hP
  -- Now prove Q x using hP : P x
  sorry
```

### Exists Introduction

```lean
theorem myTheorem : ∃ x, P x := by
  use witness  -- Provide the witness
  -- Now prove P witness
  sorry
```

### Exists Elimination

```lean
theorem myTheorem (h : ∃ x, P x) : Q := by
  obtain ⟨x, hP⟩ := h
  -- Now prove Q using x and hP : P x
  sorry
```

### Conjunction

```lean
theorem myTheorem : P ∧ Q := by
  constructor
  · -- Prove P
    sorry
  · -- Prove Q
    sorry
```

### Disjunction

```lean
theorem myTheorem : P ∨ Q := by
  left  -- or right
  -- Prove P
  sorry
```

### Contradiction

```lean
theorem myTheorem (h : P) (hn : ¬P) : False := by
  exact hn h
```

### calc Block

```lean
theorem myTheorem (a b c : Nat) : a = c := by
  calc a = b := by sorry
       _ = c := by sorry
```

## Best Practices

- Choose the appropriate template for your proof.
- Fill in the `sorry`s with your proof.
- Name intermediate hypotheses meaningfully.
- Add comments explaining the proof strategy.
