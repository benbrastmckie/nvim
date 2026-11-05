- **Task**: {N} - test
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: None
- **Artifacts**: plans/01_test.md
- **Standards**: plan-format.md
- **Type**: lean

## Goals & Non-Goals

**Non-Goals**:

- `shouldNotBeHarvested` -- must not be treated as a Goal; this fixture deliberately carries no
  `**Goals**` label at all, so `**Non-Goals**` must not itself establish the Goals range.

## Lean Challenge Statements

```lean
theorem shouldNotBeHarvested (n : Nat) : n = n := sorry
```
