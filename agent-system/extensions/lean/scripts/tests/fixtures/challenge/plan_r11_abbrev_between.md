- **Task**: {N} - test
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: None
- **Artifacts**: plans/01_test.md
- **Standards**: plan-format.md
- **Type**: lean

## Goals & Non-Goals

**Goals**:

- `comm` and `assoc` -- commutativity and associativity of natural number addition.

**Non-Goals**:

- None.

## Lean Challenge Statements

```lean
theorem comm (n m : Nat) : n + m = m + n := sorry

abbrev Doubled (n : Nat) : Nat := n + n

theorem assoc (n m k : Nat) : (n + m) + k = n + (m + k) := sorry
```
