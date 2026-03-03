# Bilateral Propositions

## Overview

Bilateral propositions extend classical propositions by distinguishing exact verifiers from exact falsifiers. This enables hyperintensional semantics where logically equivalent sentences may differ in meaning.

**Key Innovation**: Bilateral propositions with exact verification semantics validate Simplification of Disjunctive Antecedents (SDA) without validating Strengthening the Antecedent (STA).

For related concepts, see:
- [counterfactual-semantics.md](counterfactual-semantics.md) - Counterfactual truth conditions using bilateral propositions
- [bilateral-semantics.md](bilateral-semantics.md) - Complete truthmaker semantics framework

---

## Closed Sets

### Definition

**Definition (Closed Set)**: A set of states X is closed iff the fusion of any nonempty subset of X belongs to X.

Formally:
```
X is closed  iff  for all Y subset X, if Y is nonempty then \/Y in X
```

**Properties**:
- Closure under arbitrary nonempty fusion
- If s in X and t in X, then s.t in X
- The null state need not belong to closed sets

**Intuition**: Closed sets represent complete ways for something to be verified or falsified. If states s and t each verify a proposition, their fusion s.t also verifies it.

---

## Bilateral Proposition Structure

### Definition

**Definition (Bilateral Proposition)**: An ordered pair (V, F) where:
- V (verifiers) is a set of states closed under fusion
- F (falsifiers) is a set of states closed under fusion

**Constraints**:
- **Exclusive**: States in V are incompatible with states in F
  ```
  For all v in V and f in F: not (v o f)
  ```
- **Exhaustive**: Every possible state is compatible with some state in V or F
  ```
  For all s in P: exists v in V (s o v) or exists f in F (s o f)
  ```

### Intuition

- **Verifiers**: States that make the proposition true
- **Falsifiers**: States that make the proposition false
- **Exclusive**: A state cannot both verify and falsify
- **Exhaustive**: Every possible state can be extended to determine truth value

---

## Exact Verification Semantics

### Definition

**Definition (Exact Verification)**: State s exactly verifies proposition (V, F) iff s in V.

**Definition (Exact Falsification)**: State s exactly falsifies proposition (V, F) iff s in F.

**Notation**:
- |phi|^+ = exact verifiers for phi
- |phi|^- = exact falsifiers for phi

### Truth at Worlds

A bilateral proposition (V, F) is true at world state w iff:
```
exists v in V such that v <= w
```

A world state makes a proposition true if it contains some exact verifier.

### Hyperintensional Distinction

Bilateral propositions are **hyperintensional**: two propositions can have the same truth value at all possible worlds yet differ in their verifier/falsifier structure.

This enables distinguishing:
- "P or not-P" (always true but verified differently)
- Counterfactual dependence on specific verifiers

---

## Propositional Operations

### Product (Tensor)

**Definition (Product)**:
```
X tensor Y = { s.t | s in X, t in Y }
```

The product contains all fusions of elements from X and Y.

**Properties**:
- Preserves closure: if X and Y are closed, X tensor Y is closed
- Non-commutative in general for ordered operations

### Sum (Oplus)

**Definition (Sum)**:
```
X oplus Y = X union Y union (X tensor Y)
```

The sum includes elements from X, elements from Y, and all their fusions.

**Properties**:
- Contains X and Y as subsets
- Closed under fusion if X and Y are closed

### Conjunction

**Definition (Conjunction of Bilateral Propositions)**:
```
(V, F) and (V', F') = (V tensor V', F oplus F')
```

**Verifiers**: To verify A and B, verify both A and B (fusion of verifiers)
**Falsifiers**: To falsify A and B, falsify A or B or both (sum of falsifiers)

### Disjunction

**Definition (Disjunction of Bilateral Propositions)**:
```
(V, F) or (V', F') = (V oplus V', F tensor F')
```

**Verifiers**: To verify A or B, verify A or B or both (sum of verifiers)
**Falsifiers**: To falsify A or B, falsify both A and B (fusion of falsifiers)

### Negation

**Definition (Negation of Bilateral Propositions)**:
```
neg(V, F) = (F, V)
```

Negation swaps verifiers and falsifiers.

**Properties**:
- Double negation: neg(neg(V, F)) = (V, F)
- Exclusive/Exhaustive preserved under negation

---

## Summary of Operations

| Operation | Verifiers | Falsifiers |
|-----------|-----------|------------|
| (V, F) and (V', F') | V tensor V' | F oplus F' |
| (V, F) or (V', F') | V oplus V' | F tensor F' |
| neg(V, F) | F | V |

---

## Hyperintensional Motivation

### SDA without STA

Bilateral propositions enable validating:

**Valid (SDA)**: (A or B) boxright C |- A boxright C

Without validating:

**Invalid (STA)**: A boxright C |- (A and B) boxright C

### Key Insight

In similarity semantics, SDA fails because the closest (A or B)-world might differ from the closest A-world.

In exact verification semantics:
- A disjunction is verified by verifying either disjunct
- So every verifier for (A or B) is either a verifier for A or a verifier for B
- Therefore outcomes of imposing (A or B) include outcomes of imposing A

This validates SDA.

But:
- A verifier for A need not be a verifier for (A and B)
- Verifying (A and B) requires also verifying B
- So outcomes of imposing A may not include outcomes of imposing (A and B)

This blocks STA.

---

## Formal Notation Table

| Symbol | Meaning |
|--------|---------|
| (V, F) | Bilateral proposition with verifiers V and falsifiers F |
| V | Set of exact verifiers |
| F | Set of exact falsifiers |
| |phi|^+ | Exact verifiers for phi |
| |phi|^- | Exact falsifiers for phi |
| X tensor Y | Product: { s.t | s in X, t in Y } |
| X oplus Y | Sum: X union Y union (X tensor Y) |
| s o t | s and t are compatible |
| <= | Parthood relation |
| s.t | Fusion of states s and t |

---

## References

- Fine (2017, 2017a): Truthmaker semantics foundations
- Brast-McKie (2021): Defense of bilateral propositions for counterfactuals
- Yablo (2014): Aboutness and verification
