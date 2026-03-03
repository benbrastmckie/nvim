# Aesop Integration Guide

**Purpose**: Guide for integrating with Aesop automated theorem prover

**Last Updated**: December 16, 2025

---

## Overview

Aesop is an automated theorem prover for LEAN 4 that uses a best-first search strategy with customizable rule sets. It's particularly effective for routine proofs and can be extended with domain-specific rules.

**Integration**: Aesop is built into LEAN 4 and available as a tactic

---

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

---

## Aesop Rule Sets

### Default Rule Set

The default rule set includes:
- Basic logic rules (intro, cases, split)
- Equality rules (rfl, subst)
- Simplification rules (simp)
- Common tactics (assumption, contradiction)

### Custom Rule Sets

```lean
-- Define custom rule set
declare_aesop_rule_set [MyRuleSet]

-- Add rules to rule set
attribute [aesop safe apply] my_theorem
attribute [aesop norm simp] my_simp_lemma
attribute [aesop unsafe 50% apply] my_heuristic
```

### Rule Priorities

```yaml
rule_priorities:
  safe:
    description: "Always apply, never backtrack"
    priority: 100%
    examples:
      - intro
      - cases
      - rfl
      
  norm:
    description: "Normalization rules"
    priority: 90%
    examples:
      - simp
      - unfold
      
  unsafe:
    description: "Heuristic rules, may need backtracking"
    priority: "0-100%"
    examples:
      - apply (with specific lemma)
      - constructor
```

---

## Integration Patterns

### Pattern 1: Try Aesop First

```yaml
pattern: "Try Aesop before other tactics"

implementation:
  1. Try aesop with timeout
  2. If succeeds, done
  3. If fails, try other tactics
  
example:
  theorem example : P → Q := by
    try aesop
    -- fallback tactics
    intro h
    ...
```

### Pattern 2: Aesop for Subgoals

```yaml
pattern: "Use Aesop to solve routine subgoals"

implementation:
  1. Apply main tactic
  2. Use aesop for generated subgoals
  
example:
  theorem example : P ∧ Q → R := by
    intro ⟨hp, hq⟩
    constructor
    · aesop  -- solve first subgoal
    · aesop  -- solve second subgoal
```

### Pattern 3: Aesop with Custom Rules

```yaml
pattern: "Use Aesop with domain-specific rules"

implementation:
  1. Define custom rule set
  2. Add domain-specific lemmas
  3. Use aesop with rule set
  
example:
  -- Define rule set for modal logic
  declare_aesop_rule_set [ModalLogic]
  
  attribute [aesop safe apply (rule_sets [ModalLogic])] 
    necessitation
    distribution
    
  theorem example : □(P → Q) → □P → □Q := by
    aesop (rule_sets [ModalLogic])
```

---

## Aesop Options

### Terminal Mode

```lean
-- Only succeed if goal is completely solved
theorem example : P → P := by
  aesop (options := { terminal := true })
```

### Max Depth

```lean
-- Limit search depth
theorem example : P → P := by
  aesop (options := { maxDepth := 10 })
```

### Timeout

```lean
-- Set timeout in milliseconds
theorem example : P → P := by
  aesop (options := { timeout := 5000 })
```

### Rule Sets

```lean
-- Use specific rule sets
theorem example : P → P := by
  aesop (rule_sets [RuleSet1, RuleSet2])
```

---

## Integration with Specialists

### Proof Optimizer

```yaml
use_case: "Simplify proofs using Aesop"

process:
  1. Identify proof that could be simplified
  2. Try replacing tactics with aesop
  3. If succeeds and shorter, use aesop
  4. Otherwise, keep original proof
  
example:
  before:
    theorem example (h : P ∧ Q) : Q ∧ P := by
      intro ⟨hp, hq⟩
      constructor
      · exact hq
      · exact hp
      
  after:
    theorem example (h : P ∧ Q) : Q ∧ P := by
      aesop
```

### Tactic Recommender

```yaml
use_case: "Suggest aesop when appropriate"

heuristics:
  suggest_aesop_when:
    - Goal is routine (logic, equality)
    - Multiple subgoals are similar
    - Proof is repetitive
    - Custom rule set available
    
  dont_suggest_when:
    - Goal requires creativity
    - Goal is domain-specific without rules
    - Aesop likely to timeout
```

### Test Generator

```yaml
use_case: "Use Aesop to validate test properties"

process:
  1. Generate test property
  2. Try proving with aesop
  3. If succeeds, property is trivial (skip)
  4. If fails, property is interesting (keep)
  
example:
  -- Test if property is non-trivial
  def is_nontrivial (prop : Prop) : Bool :=
    try
      by aesop (options := { timeout := 1000 })
      false  -- proved by aesop, trivial
    catch
      true   -- not proved, non-trivial
```

---

## Performance Considerations

### Timeout Management

```yaml
timeouts:
  quick_check: 1000ms   # Quick check if aesop works
  normal: 5000ms        # Normal proof attempt
  deep_search: 30000ms  # Deep search for complex proofs
  
strategy:
  1. Try quick_check first
  2. If fails, try normal
  3. If still fails, try deep_search
  4. If still fails, give up
```

### Rule Set Optimization

```yaml
optimization:
  minimize_rules:
    - Only include necessary rules
    - Remove redundant rules
    - Prioritize fast rules
    
  specialize_rules:
    - Create domain-specific rule sets
    - Avoid generic rule sets for specific domains
    - Test rule set effectiveness
```

### Caching

```yaml
caching:
  cache_key:
    - Goal type
    - Available hypotheses
    - Rule set used
    
  cache_value:
    - Success/failure
    - Proof term (if success)
    - Time taken
    
  invalidation:
    - Rule set changed
    - Aesop version changed
    - Manual invalidation
```

---

## Best Practices

### When to Use Aesop

**Good Use Cases**:
- Routine logical reasoning (∧, ∨, →, ∃, ∀)
- Equality proofs (rfl, subst)
- Simple arithmetic (with appropriate rules)
- Repetitive subgoals
- Proofs with custom rule sets

**Bad Use Cases**:
- Creative proofs requiring insight
- Complex domain-specific reasoning (without rules)
- Proofs requiring specific lemma applications
- Very large search spaces

### Rule Set Design

1. **Start Small**: Begin with minimal rule set
2. **Add Incrementally**: Add rules as needed
3. **Test Effectiveness**: Measure success rate
4. **Prioritize Correctly**: Safe rules first, unsafe last
5. **Document Rules**: Explain why each rule is included

### Performance Optimization

1. **Set Timeouts**: Always set reasonable timeouts
2. **Limit Depth**: Limit search depth for complex goals
3. **Use Terminal Mode**: For complete proofs only
4. **Cache Results**: Cache successful/failed attempts
5. **Profile**: Measure time spent in aesop

### Integration with Other Tactics

1. **Try First**: Try aesop before manual tactics
2. **Fallback**: Have fallback tactics ready
3. **Combine**: Use aesop for subgoals
4. **Specialize**: Use custom rule sets for domains

---

## Aesop Rule Types

### Safe Rules

```lean
-- Always apply, never backtrack
attribute [aesop safe apply] intro_rule
attribute [aesop safe cases] cases_rule
attribute [aesop safe constructors] constructor_rule
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
attribute [aesop unsafe 20% apply] low_priority_rule
```

---

## Error Handling

### Aesop Failures

```yaml
failure_types:
  timeout:
    reason: "Search exceeded timeout"
    action: "Increase timeout or simplify goal"
    
  max_depth:
    reason: "Search exceeded max depth"
    action: "Increase depth or add better rules"
    
  no_applicable_rules:
    reason: "No rules apply to goal"
    action: "Add appropriate rules or use different tactic"
    
  backtracking_limit:
    reason: "Too much backtracking"
    action: "Improve rule priorities or use different tactic"
```

### Graceful Degradation

```yaml
degradation:
  if_aesop_fails:
    1. Log failure reason
    2. Try fallback tactics
    3. Return partial result
    4. Suggest manual intervention
```

---

## Example Rule Sets

### Modal Logic Rule Set

```lean
declare_aesop_rule_set [ModalLogic]

attribute [aesop safe apply (rule_sets [ModalLogic])]
  necessitation
  distribution
  modal_modus_ponens

attribute [aesop norm simp (rule_sets [ModalLogic])]
  box_and
  box_impl
  diamond_or
```

### List Rule Set

```lean
declare_aesop_rule_set [ListRules]

attribute [aesop safe apply (rule_sets [ListRules])]
  List.nil_append
  List.cons_append
  List.append_assoc

attribute [aesop norm simp (rule_sets [ListRules])]
  List.length_nil
  List.length_cons
  List.length_append
```

---

## Integration Checklist

- [ ] Understand Aesop rule types (safe, norm, unsafe)
- [ ] Define custom rule sets for domain
- [ ] Add domain-specific lemmas to rule sets
- [ ] Set appropriate timeouts
- [ ] Implement caching for aesop attempts
- [ ] Handle aesop failures gracefully
- [ ] Use aesop as first attempt for routine proofs
- [ ] Have fallback tactics ready
- [ ] Profile aesop performance
- [ ] Optimize rule sets based on success rate
- [ ] Document when to use aesop
- [ ] Test with various goal types

---

## References

- [Aesop Documentation](https://github.com/leanprover-community/aesop)
- [Aesop Paper](https://arxiv.org/abs/2310.16978)
- [LEAN 4 Tactics](https://leanprover.github.io/theorem_proving_in_lean4/tactics.html)
