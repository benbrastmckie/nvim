# Scott Topology

## Overview

Scott topology is the canonical topology on partially ordered sets arising in domain theory. It captures computational approximation and provides semantics for programming languages.

## Definition

### Scott-Open Sets

A subset U of a poset is Scott-open if:
1. **Upward closed**: x in U and x <= y implies y in U
2. **Inaccessible by directed suprema**: For any directed D, if sup D in U, then some d in D is in U

### Lean 4 Definition

```lean
def IsScottOpen (U : Set P) : Prop :=
  IsUpperSet U and
  forall D, IsDirected D -> sSup D in U -> exists d in D, d in U
```

## Key Properties

### Basis

Scott-open sets form a topology:
- Union of Scott-open sets is Scott-open
- Finite intersection of Scott-open sets is Scott-open
- P is Scott-open, empty set is Scott-open

### Scott-Continuous Functions

f: P -> Q is Scott-continuous iff:
1. Monotone: x <= y implies f(x) <= f(y)
2. Preserves directed suprema: f(sup D) = sup f(D)

Equivalently: Preimages of Scott-open sets are Scott-open.

## Domain Theory

### CPOs (Complete Partial Orders)

Posets where every directed set has a supremum.

### Pointed CPOs

CPOs with a least element (bottom).

### Continuous Functions

Scott-continuous functions between CPOs.

## Approximation

### Way-Below Relation

x << y (x is way below y) if:
- For all directed D with y <= sup D, exists d in D with x <= d

### Continuous Domains

Every element is the supremum of elements way below it:
- x = sup {y | y << x}

## Fixed Points

### Least Fixed Point Theorem

On pointed CPOs, every Scott-continuous function has a least fixed point:

```lean
theorem lfp_exists {f : P -> P} (hf : ScottContinuous f) :
    exists x, f x = x and forall y, f y = y -> x <= y
```

### Computation

lfp(f) = sup {f^n(bottom) | n in N}

## Applications

### Denotational Semantics

- Programs as Scott-continuous functions
- Recursion via fixed points
- Types as domains

### Logic

- Kripke models on domains
- Truth as approximation
- Modal logic semantics

### Databases

- Partial information
- Query evaluation
- Datalog semantics

## Relationship to Other Topologies

### Comparison

- Coarser than Alexandrov topology
- Finer than discrete topology (usually)
- Not Hausdorff in general

### Specialization Order

The specialization preorder equals the original order:
- x <= y iff for all Scott-open U, y in U implies x in U

## Mathlib Approach

```lean
import Mathlib.Topology.Order.Basic
import Mathlib.Order.CompleteLattice
import Mathlib.Order.Directed

def scottTopology (P : Type) [CompleteLattice P] : TopologicalSpace P where
  isOpen := IsScottOpen
  isOpen_univ := scottOpen_univ
  isOpen_inter := scottOpen_inter
  isOpen_sUnion := scottOpen_sUnion
```

## References

- Abramsky and Jung: Domain Theory
- Amadio and Curien: Domains and Lambda-Calculi
- Gierz et al.: Continuous Lattices and Domains
