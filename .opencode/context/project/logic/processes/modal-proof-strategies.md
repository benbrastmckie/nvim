# Modal Proof Strategies

## Overview

Strategies and patterns for proving theorems in modal logic systems. Covers common proof techniques, axiom application, and reasoning patterns.

## Proof Approaches

### Direct Proof

Apply axioms and inference rules directly:
1. Identify the goal formula structure
2. Select applicable axioms
3. Apply inference rules
4. Chain reasoning steps

### Proof by Contraposition

For phi -> psi, prove not psi -> not phi:
1. Assume not psi
2. Derive not phi
3. Apply contraposition equivalence

### Proof by Cases

For disjunctive premises:
1. Split into cases
2. Prove goal from each case
3. Combine using disjunction elimination

## Axiom Application Patterns

### K Axiom Pattern

box(phi -> psi) -> (box phi -> box psi)

**Usage**: Distribute necessity over implication
**Pattern**: Have box(phi -> psi) and box phi, want box psi

### T Axiom Pattern

box phi -> phi

**Usage**: What is necessary is actual
**Pattern**: Have box phi, want phi

### 4 Axiom Pattern

box phi -> box box phi

**Usage**: Iterate necessity
**Pattern**: Have box phi, want box box phi

### B Axiom Pattern

phi -> box diamond phi

**Usage**: What is actual is necessarily possible
**Pattern**: Have phi, want box diamond phi

## Inference Rule Patterns

### Necessitation Rule

From |- phi derive |- box phi

**Requirement**: phi must be a theorem (no assumptions)
**Common error**: Applying to formulas derived from assumptions

### Modus Ponens

From phi and phi -> psi derive psi

**Pattern**: Standard implication elimination

## Common Proof Structures

### Necessity Chain

Prove box^n phi from box phi using 4 axiom:
```
box phi -> box box phi (4 axiom)
box box phi -> box box box phi (4 axiom applied to box phi)
...
```

### Modal K Distribution

Prove box psi from box(phi -> psi) and box phi:
```
1. box(phi -> psi)         -- premise
2. box phi                  -- premise
3. box(phi -> psi) -> (box phi -> box psi)  -- K axiom
4. box phi -> box psi       -- modus ponens (1,3)
5. box psi                  -- modus ponens (2,4)
```

### Reflexive Frame Reasoning

In reflexive frames (T axiom holds):
```
1. box phi -> phi          -- T axiom
2. phi -> diamond phi      -- T dual (can be derived)
```

## Proof Search Strategies

### Forward Chaining

Start from premises, apply rules toward goal:
1. List all premises
2. Apply applicable inference rules
3. Repeat until goal reached or stuck

### Backward Chaining

Start from goal, work backward:
1. Identify goal structure
2. Find rules that produce goal
3. Recursively prove subgoals

### Tableaux Method

Build semantic tableaux:
1. Negate goal
2. Apply tableau rules
3. Check for closure

## Common Pitfalls

### Incorrect Necessitation

Wrong: From assumptions derive box phi
Correct: Only theorems can be necessitated

### Forgetting Frame Assumptions

Wrong: Use T axiom in non-reflexive frames
Correct: Check which axioms are valid in the frame class

### Confusing Object and Metalanguage

Wrong: Mix provability and validity
Correct: Clearly distinguish |- and |=

## References

- Modal Logic (Blackburn, de Rijke, Venema)
- Handbook of Modal Logic
- Hughes and Cresswell: A New Introduction to Modal Logic
