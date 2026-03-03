# Proof Readability Criteria

## Overview
This file establishes guidelines for writing clear and understandable proofs in LEAN 4.

## Quality Criteria

### Clarity
- The proof should be easy to follow and understand.

### Conciseness
- The proof should be as short as possible without sacrificing clarity.

### Explicitness
- The proof should not rely on implicit arguments or "magic" tactics.

## Validation Rules

### Clarity
- **Rule**: The proof must be easy to follow.
  **Check**: Have another person review the proof.
  **Failure Action**: Refactor the proof to improve clarity.

### Conciseness
- **Rule**: The proof must be concise.
  **Check**: Look for opportunities to shorten the proof.
  **Failure Action**: Refactor the proof to be more concise.

## Examples

**Pass Example**:
```lean
theorem myTheorem (p q : Prop) (h : p) : p ∨ q := by
  apply Or.inl
  exact h
```

**Fail Example**:
```lean
theorem myTheorem (p q : Prop) (h : p) : p ∨ q := by
  -- This proof is unnecessarily long and complex.
  cases (em p) with
  | inl hp => exact Or.inl hp
  | inr hnp => cases (em q) with
    | inl hq => exact Or.inr hq
    | inr hnq => sorry -- This should not happen
```
