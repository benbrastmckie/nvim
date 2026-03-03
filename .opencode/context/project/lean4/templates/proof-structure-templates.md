# Proof Structure Templates

## Overview
This file offers templates for common proof structures in LEAN 4.

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

## Best Practices
- Choose the appropriate template for your proof.
- Fill in the `sorry`s with your proof.
