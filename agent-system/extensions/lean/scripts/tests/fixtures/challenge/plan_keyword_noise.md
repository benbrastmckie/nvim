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

- The identifier set equals the one `theorem` declaration below. It is written out as a
  `sorry`-bodied `abbrev` context in the block for exposition only, because
  `lean-challenge-snapshot.sh` counts only `theorem` declarations here. Prove `comm` for natural
  number addition.

**Non-Goals**:

- None.

## Lean Challenge Statements

```lean
theorem comm (n m : Nat) : n + m = m + n := sorry
```
