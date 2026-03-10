# Temporal Proof Strategies

## Overview

Strategies and patterns for proving theorems in temporal logic systems. Covers linear temporal logic (LTL) and branching time logic (CTL) proof techniques.

## Temporal Operators

### Linear Time

- **G** (Globally/Always): phi holds at all future times
- **F** (Finally/Eventually): phi holds at some future time
- **H** (Historically): phi held at all past times
- **P** (Past): phi held at some past time

### Derived Operators

- F phi = not G not phi
- P phi = not H not phi

## Proof Approaches

### Induction on Time

For proving G phi:
1. Prove phi holds now
2. Prove: if phi holds at t, it holds at t+1
3. Conclude G phi by induction

### Fixed-Point Reasoning

Temporal operators as fixed points:
- G phi = phi and X(G phi)
- F phi = phi or X(F phi)

### Eventuality Arguments

For F phi:
1. Show phi must eventually hold
2. May use ranking functions or well-founded induction

## Axiom Application Patterns

### Temporal Distribution

G(phi -> psi) -> (G phi -> G psi)

**Usage**: Distribute globally over implication
**Pattern**: Similar to modal K axiom

### Temporal Reflexivity

G phi -> phi

**Usage**: What is always true is currently true
**Pattern**: Similar to modal T axiom

### Temporal Transitivity

G phi -> G G phi

**Usage**: Always implies always-always
**Pattern**: Similar to modal 4 axiom

## Common Proof Structures

### Liveness Proofs

Prove something eventually happens (F phi):
1. Identify enabling condition
2. Show progress is made
3. Conclude eventuality

### Safety Proofs

Prove invariant (G phi):
1. Show phi holds initially
2. Show phi is preserved by transitions
3. Conclude global invariance

### Until Reasoning

phi U psi (phi until psi):
- psi holds eventually
- phi holds until psi does

## Temporal Duality

### Past-Future Duality

Results about future operators transfer to past:
- G and H are duals
- F and P are duals

### Inference Rule

If |- phi, then |- phi.swap_temporal
(swap G/H and F/P throughout)

## Combined Modal-Temporal

### Perpetuity Principles

box phi -> delta phi
(necessity implies eternal truth)

where delta phi = H phi and phi and G phi

### Interaction Axioms

box G phi -> G box phi
(in appropriate combined systems)

## Proof Search Strategies

### Automata-Theoretic Approach

1. Translate formula to automaton
2. Check automaton properties
3. Translate back to proof

### Model Checking

1. Build state space
2. Verify property holds in all states
3. Extract proof from verification

## Common Pitfalls

### Forgetting Initial State

Wrong: Assume phi holds without checking initial case
Correct: Always verify the base case

### Circular Eventuality

Wrong: F phi because phi will happen after F phi
Correct: Need well-founded argument

### Past-Future Asymmetry

Some properties differ for past/future:
- Future is branching (in some models)
- Past is linear

## References

- Manna and Pnueli: The Temporal Logic of Reactive and Concurrent Systems
- Emerson: Temporal and Modal Logic
- Clarke, Grumberg, Peled: Model Checking
