# Counterfactual Semantics

## Overview

Counterfactual conditionals ("If A had been the case, B would have been the case") require special semantic treatment beyond material implication. This document covers exact verification approaches to counterfactual semantics.

## Standard Approaches

### Stalnaker-Lewis Semantics

**Selection Function Approach**:
- f(phi, w) = the closest phi-world to w
- phi > psi is true at w iff psi is true at f(phi, w)

**Similarity Sphere Approach**:
- Closest phi-worlds in nested similarity spheres
- Variably strict conditional

### Problems

1. **Strengthening the Antecedent (STA)**: Invalidated but sometimes desired
2. **Simplification of Disjunctive Antecedents (SDA)**: Desired but invalid in Lewis semantics

## Exact Verification Approach

### Key Insight

Use bilateral propositions with exact verifiers to analyze counterfactuals:
- Antecedent analyzed via its exact verifiers
- Each verifier determines possible outcomes

### Truth Conditions

phi boxright psi is true iff:
For every exact verifier v of phi, imposing v results in psi being true.

### Imposing States

**Process**:
1. Take current world w
2. Remove parts incompatible with v
3. Add v
4. Complete to a world

## Validating SDA

### Why SDA Holds

(A or B) boxright C |- A boxright C

**Proof**: Every verifier for (A or B) is either:
- A verifier for A, or
- A verifier for B

So outcomes from (A or B) include all outcomes from A.

### Why STA Fails

A boxright C |- (A and B) boxright C is INVALID

**Counterexample**: Verifying A alone may give different outcomes than verifying (A and B).

## Related Logics

### Counterfactual Logic

**Axioms**:
- Reflexivity: phi boxright phi
- Weakening Consequent: (phi boxright psi) and (psi -> chi) -> (phi boxright chi)

**Invalid**:
- Transitivity: (phi boxright psi) and (psi boxright chi) does NOT imply (phi boxright chi)
- Contraposition: (phi boxright psi) does NOT imply (not psi boxright not phi)

## Applications

### Causal Reasoning

- Interventions as "imposing" states
- Structural equation models

### Legal and Moral Reasoning

- Responsibility and causation
- "But for" counterfactuals

## References

- Lewis (1973): Counterfactuals
- Stalnaker (1968): A theory of conditionals
- Fine (2012): Counterfactuals without possible worlds
- Brast-McKie (2021): Bilateral truthmaker semantics
