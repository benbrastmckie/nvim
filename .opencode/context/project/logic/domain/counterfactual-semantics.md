# Counterfactual Semantics

## Overview

Counterfactual semantics provides truth conditions for subjunctive conditionals ("If A were the case, then C would be the case"). This document describes an imposition-based semantics where counterfactual evaluation depends on minimal changes to world states, formalized through mereological structure on states.

**Key Innovation**: Unlike similarity-based approaches (Lewis), imposition is defined purely in mereological and modal terms via maximal compatible parts.

For related concepts, see:
- [bilateral-semantics.md](bilateral-semantics.md) - Task relation and world histories
- [bilateral-propositions.md](bilateral-propositions.md) - Exact verification semantics

---

## State Spaces

### Mathematical Structure

**Definition (State Space)**: A state space is a complete lattice S = (S, <=) where:
- S is the set of states
- <= is the parthood relation
- Every set of states X has a unique least upper bound (fusion)

**Key Operations**:
- **Fusion of X**: \/X (least upper bound)
- **Null state**: [] = \/{} (fusion of empty set, the least element)
- **Full state**: [*] = \/S (fusion of all states)
- **Binary fusion**: s.t = \/{s,t}

**Intuition**: States represent "some things being a specific way" - they are static and typically partial, concerning a limited way for certain things to be at an instant.

---

## Modalized State Spaces

### Definition

**Definition (Modalized State Space)**: A modalized state space is S^<> = (S, P, <=) where:
- (S, <=) is a state space
- P is a subset of S (the possible states)

**Constraints on P**:
- **Nonempty**: P is nonempty
- **Possibility**: If s in P and t <= s, then t in P (parts of possible states are possible)

### Compatibility and World States

**Definition (Compatibility)**: States s and t are compatible (s o t) iff s.t is in P.

**Definition (World States)**:
```
W = { w in P | for all s, if s o w then s <= w }
```

World states are maximal possible states that include all compatible states as parts.

**Definition (World Space)**: A modalized state space satisfying:
- If s in P, then s <= w for some w in W

This identifies possible states with parts of world states.

---

## Imposition

### t-Compatible Parts

**Definition (t-Compatible Part)**:
```
s <=_t w  iff  s <= w  and  s o t
```

A t-compatible part of w is a part of w that is compatible with t.

### Maximal Compatible Parts

**Definition (Maximal Compatible Parts)**:
```
w_t = { s <=_t w | for all r <=_t w, if s <= r then r = s }
```

Maximal t-compatible parts of w are t-compatible parts not properly contained in any other t-compatible part.

### The Imposition Relation

**Definition (Imposition)**:
```
t |>_w u  iff  u in W  and  exists s in w_t such that s.t <= u
```

An outcome u of imposing t on w is any world state that includes both t and some maximal t-compatible part of w.

**Intuition**: Outcome world states result from minimally changing a given world state to include an imposed state. Outcomes need not be unique.

**Key Property**: Imposition is defined, not primitive. This differs from Fine's original formulation.

---

## Counterfactual Semantic Clauses

### Evaluation Context

Truth is evaluated at world-time pairs (alpha, x) where:
- alpha is a world history (function from times to world states)
- x is a time point

### Satisfaction Relation

For extensional sentences:
```
M, alpha, x |= q        iff  exists s <= alpha(x) such that s in |q|^+
M, alpha, x |= neg A    iff  M, alpha, x |/= A
M, alpha, x |= A and B  iff  M, alpha, x |= A  and  M, alpha, x |= B
M, alpha, x |= A or B   iff  M, alpha, x |= A  or  M, alpha, x |= B
```

### Counterfactual Clause

**Definition (Counterfactual Truth)**:
```
M, alpha, x |= phi boxright C  iff
  M, beta, x |= C  whenever  t in |phi|^+  and  t |>_{alpha(x)} beta(x)
```

**Expanded Form** (in purely mereological/modal terms):
```
M, alpha, x |= phi boxright C  iff
  for all t in |phi|^+ and beta in H_Z,
    if s.t <= beta(x) for some maximal t-compatible part s in alpha(x)_t,
    then M, beta, x |= C
```

**Intuition**: A counterfactual is true at world alpha at time x iff the consequent is true in any world beta at x where beta(x) results from minimally changing alpha(x) to make the antecedent true.

**Restriction**: Antecedents of counterfactuals are extensional sentences only (no nested counterfactuals or tense in antecedent).

---

## Valid Principles

### Counterfactual Logic CL

**Rule Schema**:
- R1: If Gamma |- C, then phi boxright Gamma |- phi boxright C

**Axiom Schemata**:

| Axiom | Formula | Name |
|-------|---------|------|
| C1 | phi boxright phi | Identity |
| C2 | phi, phi boxright A |- A | Counterfactual Modus Ponens |
| C3 | phi boxright psi, phi and psi boxright A |- phi boxright A | Weakened Transitivity |
| C4 | phi or psi boxright A |- phi and psi boxright A | |
| C5 | phi or psi boxright A |- phi boxright A | SDA (left) |
| C6 | phi or psi boxright A |- psi boxright A | SDA (right) |
| C7 | phi boxright A, psi boxright A, phi and psi boxright A |- phi or psi boxright A | |

**Derived Rules**:
- D1: phi boxright A, phi boxright B |- phi boxright A and B
- D2: If A |- B, then phi boxright A |- phi boxright B

### Simplification of Disjunctive Antecedents (SDA)

The logic validates SDA:
```
(phi or psi) boxright A  |-  phi boxright A
(phi or psi) boxright A  |-  psi boxright A
```

This captures the inference: "If Nixon or Agnew had pressed the button, there would have been a nuclear catastrophe" entails "If Nixon had pressed the button, there would have been a nuclear catastrophe."

---

## Invalid Principles

The following are NOT valid:

| Principle | Formula | Name |
|-----------|---------|------|
| #1 | phi, A |- phi boxright A | |
| #2 | phi boxright psi, psi boxright A |- phi boxright A | Transitivity |
| #9 | phi boxright A |- phi and psi boxright A | STA (Strengthening Antecedent) |
| #11 | phi boxright psi |- neg psi boxright neg phi | Contraposition |
| #12 | If Gamma, phi |- C, then Gamma |- phi boxright C | Deduction Theorem |

**Key Result**: CL validates SDA without validating STA. This is the central distinguishing feature of the logic.

---

## Modal Operators from Counterfactuals

### Metaphysical Necessity

**Definition**: Box A = top boxright A

This defines metaphysical necessity as: if the tautology were the case, A would be the case.

**Key Theorem (D8)**: Box phi <-> neg phi boxright bot

Necessity is equivalent to "if the negation were true, absurdity would follow."

### Modal Axioms

The logic validates S5 for Box without frame constraints:
- M3: A -> Box Diamond A
- M4: Box A -> Box Box A
- M5: Box(phi -> A) |- phi boxright A

---

## Formal Notation Table

| Symbol | Meaning |
|--------|---------|
| S | State space |
| <= | Parthood relation |
| P | Possible states |
| W | World states |
| s.t | Fusion of s and t |
| [] | Null state |
| [*] | Full state |
| s o t | s and t are compatible (s.t in P) |
| s <=_t w | s is t-compatible part of w |
| w_t | Set of maximal t-compatible parts of w |
| t |>_w u | u is outcome of imposing t on w |
| |phi|^+ | Exact verifiers for phi |
| |phi|^- | Exact falsifiers for phi |
| boxright | Counterfactual conditional |
| Box | Metaphysical necessity (top boxright A) |
| Diamond | Metaphysical possibility (neg Box neg A) |

---

## References

- Fine (2012a, 2012b): Original imposition semantics
- Fine (2017d, 2017, 2017a): Truthmaker semantics
- Lewis (1973): Similarity semantics critique
- Brast-McKie (2021): Bilateral propositions defense
