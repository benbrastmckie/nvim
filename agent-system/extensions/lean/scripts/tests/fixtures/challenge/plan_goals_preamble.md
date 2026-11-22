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
not goals. Only a bullet's leading identifier run contributes goal names, so the backticked
`abbrev` and `gPast_adm` tokens in this preamble paragraph -- and any backticked identifier in a
bullet's trailing prose -- are never harvested.)

- `comm` -- commutativity of addition.
- `assoc` -- associativity of addition.

**Non-Goals**:

- None.

## Lean Challenge Statements

```lean
theorem comm (n m : Nat) : n + m = m + n := sorry

theorem assoc (n m k : Nat) : (n + m) + k = n + (m + k) := sorry
```
