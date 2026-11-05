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

(The identifier set equals the two theorem declarations below -- the block's `abbrev`
definitions, including the admissibility fact `gPast_adm` the probe also proves, are context,
not goals. No other identifier is backticked in this block, because the snapshot tool reads
every backticked token here as a Goal.)

- `comm` -- commutativity of addition.
- `assoc` -- associativity of addition.

**Non-Goals**:

- None.

## Lean Challenge Statements

```lean
theorem comm (n m : Nat) : n + m = m + n := sorry

theorem assoc (n m k : Nat) : (n + m) + k = n + (m + k) := sorry
```
