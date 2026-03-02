# Proof Readability Criteria

## Overview

This file establishes guidelines for writing clear and understandable proofs in Lean 4.

## Quality Criteria

### Clarity

- The proof should be easy to follow and understand.
- Each step should have a clear purpose.
- Complex reasoning should be broken into named intermediate steps.

### Conciseness

- The proof should be as short as possible without sacrificing clarity.
- Avoid redundant steps or unnecessary case splits.
- Use appropriate automation to eliminate boilerplate.

### Explicitness

- The proof should not rely on implicit arguments or "magic" tactics.
- Key steps should be explicitly named and documented.
- Automation should be bounded and commented.

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

## Best Practices

### Use Named Intermediate Steps

```lean
theorem complex_proof : P := by
  have step1 : A := by ...
  have step2 : B := by ...
  have step3 : C := by ...
  exact final_step step1 step2 step3
```

### Document Intent

```lean
theorem completeness : Valid phi -> Provable phi := by
  -- Strategy: Use canonical model construction
  intro h
  -- Build maximal consistent sets
  have mcs := build_mcs h
  -- Apply truth lemma
  apply truth_lemma mcs
```

### Bound Automation

```lean
-- Good: Bounded automation with explanation
simp only [add_comm, mul_comm]  -- Commutativity rewrites

-- Bad: Unbounded automation
simp  -- What does this do?
```
