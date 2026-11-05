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

- `hnOpenMirror`, `hnStabMirror`, and `hn_stab` -- the modal frame construction's mirror lemmas.

**Non-Goals**:

- None.

## Lean Challenge Statements

```lean
theorem hnOpenMirror (n m : Nat) : n + m = m + n := sorry

theorem hnStabMirror (n m : Nat) : n * m = m * n := sorry

theorem hn_stab (n : Nat) : n + 0 = n := sorry
```
