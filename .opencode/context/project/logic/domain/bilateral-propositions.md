# Bilateral Propositions

## Overview

Bilateral propositions extend classical propositions by distinguishing exact verifiers from exact falsifiers. This enables hyperintensional semantics where logically equivalent sentences may differ in meaning.

**Key Innovation**: Bilateral propositions with exact verification semantics validate Simplification of Disjunctive Antecedents (SDA) without validating Strengthening the Antecedent (STA).

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

## Bilateral Proposition Structure

### Definition

**Definition (Bilateral Proposition)**: An ordered pair (V, F) where:
- V (verifiers) is a set of states closed under fusion
- F (falsifiers) is a set of states closed under fusion

**Constraints**:
- **Exclusive**: States in V are incompatible with states in F
- **Exhaustive**: Every possible state is compatible with some state in V or F

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

## Propositional Operations

### Product (Tensor)

**Definition (Product)**:
```
X tensor Y = { s.t | s in X, t in Y }
```

### Sum (Oplus)

**Definition (Sum)**:
```
X oplus Y = X union Y union (X tensor Y)
```

### Conjunction

```
(V, F) and (V', F') = (V tensor V', F oplus F')
```

### Disjunction

```
(V, F) or (V', F') = (V oplus V', F tensor F')
```

### Negation

```
neg(V, F) = (F, V)
```

## Summary of Operations

| Operation | Verifiers | Falsifiers |
|-----------|-----------|------------|
| (V, F) and (V', F') | V tensor V' | F oplus F' |
| (V, F) or (V', F') | V oplus V' | F tensor F' |
| neg(V, F) | F | V |

## Hyperintensional Motivation

### SDA without STA

Bilateral propositions enable validating:

**Valid (SDA)**: (A or B) boxright C |- A boxright C

Without validating:

**Invalid (STA)**: A boxright C |- (A and B) boxright C

## References

- Fine (2017, 2017a): Truthmaker semantics foundations
- Brast-McKie (2021): Defense of bilateral propositions for counterfactuals
- Yablo (2014): Aboutness and verification
