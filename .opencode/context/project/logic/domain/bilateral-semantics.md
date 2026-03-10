# Bilateral Semantics

## Overview

Bilateral semantics provides a framework for understanding propositions in terms of both their verifiers (what makes them true) and their falsifiers (what makes them false). This approach supports hyperintensional distinctions.

## Core Concepts

### States and Compatibility

- **State**: A partial specification of reality
- **Compatible states**: States that can coexist (s o t)
- **Fusion**: Combination of compatible states (s.t)
- **Parthood**: State s is part of w (s <= w)

### Bilateral Propositions

A bilateral proposition is a pair (V, F) where:
- V = set of exact verifiers
- F = set of exact falsifiers

Both V and F are closed under fusion.

## Semantic Clauses

### Sentence Letters

For sentence letter p:
- |p|^+ = exact verifiers assigned by valuation
- |p|^- = exact falsifiers assigned by valuation

### Complex Formulas

**Negation**:
- |not phi|^+ = |phi|^-
- |not phi|^- = |phi|^+

**Conjunction**:
- |phi and psi|^+ = |phi|^+ tensor |psi|^+
- |phi and psi|^- = |phi|^- oplus |psi|^-

**Disjunction**:
- |phi or psi|^+ = |phi|^+ oplus |psi|^+
- |phi or psi|^- = |phi|^- tensor |psi|^-

## Truth at Worlds

### Definition

phi is true at world w iff:
```
exists v in |phi|^+ such that v <= w
```

phi is false at world w iff:
```
exists f in |phi|^- such that f <= w
```

### Exclusivity and Exhaustivity

- **Exclusivity**: No world can have both a verifier and falsifier for the same proposition
- **Exhaustivity**: Every world has either a verifier or falsifier (or both via parts)

## Counterfactual Semantics

### Exact Verification for Counterfactuals

The counterfactual phi boxright psi is true iff:
For every exact verifier v of phi, the result of "imposing" v leads to psi being true.

### Imposing a State

The result of imposing state s at world w:
- Start with w
- Remove incompatible parts
- Add s
- Extend to a complete world

## Applications

### Hyperintensional Distinctions

Bilateral semantics can distinguish:
- "P or not-P" from "Q or not-Q" (different verifiers)
- Logically equivalent formulas with different subject matter

### Counterfactual Reasoning

- Validates intuitive patterns (SDA)
- Blocks problematic inferences (STA)

## References

- Fine: Truthmaker semantics
- Yablo: Aboutness
- Brast-McKie: Counterfactual semantics
