# Proof Construction Workflow

## Overview

General workflow and best practices for constructing formal proofs in modal and temporal logic.

## Proof Planning

### 1. Analyze the Goal

- Identify the main logical structure
- Determine which connectives/operators dominate
- Check for applicable axioms

### 2. Identify Available Tools

- List applicable axioms
- List applicable inference rules
- Note any special properties of the logic

### 3. Choose Strategy

- Direct proof vs indirect proof
- Forward vs backward reasoning
- Induction vs case analysis

## Proof Development Phases

### Phase 1: Sketch

1. Write informal proof idea
2. Identify key lemmas needed
3. Note potential difficulties

### Phase 2: Formalization

1. Convert to formal notation
2. State intermediate lemmas precisely
3. Check well-formedness

### Phase 3: Detail

1. Fill in all proof steps
2. Justify each inference
3. Handle all cases

### Phase 4: Verification

1. Check all steps mechanically
2. Verify axiom applications
3. Confirm rule applications

## Best Practices

### Modular Proofs

- Break into independent lemmas
- Minimize dependencies
- Maximize reusability

### Clear Documentation

- State theorem and its intuition
- Explain proof strategy
- Comment non-obvious steps

### Defensive Proofs

- Check assumptions explicitly
- Verify preconditions
- Handle edge cases

## Common Proof Patterns

### Implication Introduction

To prove phi -> psi:
1. Assume phi
2. Derive psi
3. Conclude phi -> psi

### Universal Elimination

Given for all x, phi(x):
1. Instantiate with specific term t
2. Obtain phi(t)

### Existential Introduction

To prove exists x, phi(x):
1. Find witness term t
2. Prove phi(t)
3. Conclude exists x, phi(x)

### Proof by Contradiction

To prove phi:
1. Assume not phi
2. Derive contradiction
3. Conclude phi

## Lean 4 Proof Tactics

### Common Tactics

- `intro`: Introduction rule
- `apply`: Apply hypothesis or theorem
- `exact`: Provide exact term
- `have`: Introduce intermediate step
- `simp`: Simplification
- `cases`: Case analysis

### Modal/Temporal Tactics

- Pattern-specific tactics for axiom application
- Custom automation for common patterns

## Quality Criteria

### Correctness

- Every step justified
- No gaps in reasoning
- All cases covered

### Clarity

- Readable structure
- Meaningful names
- Appropriate comments

### Efficiency

- Minimal proof length
- Reuse of lemmas
- Avoid redundancy

## References

- How to Prove It (Velleman)
- Proof Theory (Troelstra, Schwichtenberg)
- Certified Programming with Dependent Types (Chlipala)
