# Aesop Integration Guide

## Overview

Aesop is an automated theorem prover for Lean 4 that uses a best-first search strategy with customizable rule sets. It's particularly effective for routine proofs.

## Basic Usage

### Simple Aesop Tactic

```lean
theorem example (h : P ∧ Q) : Q ∧ P := by
  aesop
```

### Aesop with Options

```lean
theorem example (h : P ∧ Q) : Q ∧ P := by
  aesop (options := { terminal := true })
```

### Aesop with Rule Sets

```lean
theorem example (h : P ∧ Q) : Q ∧ P := by
  aesop (rule_sets [MyRuleSet])
```

## Rule Types

### Safe Rules

```lean
-- Always apply, never backtrack
attribute [aesop safe apply] intro_rule
attribute [aesop safe cases] cases_rule
```

### Norm Rules

```lean
-- Normalization rules
attribute [aesop norm simp] simp_rule
attribute [aesop norm unfold] unfold_rule
```

### Unsafe Rules

```lean
-- Heuristic rules with priority
attribute [aesop unsafe 80% apply] high_priority_rule
attribute [aesop unsafe 50% apply] medium_priority_rule
```

## Custom Rule Sets

```lean
-- Define custom rule set
declare_aesop_rule_set [MyRuleSet]

-- Add rules to rule set
attribute [aesop safe apply (rule_sets [MyRuleSet])] my_theorem
attribute [aesop norm simp (rule_sets [MyRuleSet])] my_simp_lemma
```

## Options

### Terminal Mode

```lean
-- Only succeed if goal is completely solved
aesop (options := { terminal := true })
```

### Max Depth

```lean
-- Limit search depth
aesop (options := { maxDepth := 10 })
```

### Timeout

```lean
-- Set timeout in milliseconds
aesop (options := { timeout := 5000 })
```

## Best Practices

### When to Use Aesop

**Good Use Cases**:
- Routine logical reasoning
- Equality proofs (rfl, subst)
- Simple arithmetic (with appropriate rules)
- Repetitive subgoals
- Proofs with custom rule sets

**Bad Use Cases**:
- Creative proofs requiring insight
- Complex domain-specific reasoning (without rules)
- Proofs requiring specific lemma applications
- Very large search spaces

### Performance Optimization

1. **Set Timeouts**: Always set reasonable timeouts
2. **Limit Depth**: Limit search depth for complex goals
3. **Use Terminal Mode**: For complete proofs only

## References

- [Aesop Documentation](https://github.com/leanprover-community/aesop)
