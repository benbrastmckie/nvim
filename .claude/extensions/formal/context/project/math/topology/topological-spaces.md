# Topological Spaces

## Overview

Topological spaces provide the foundation for continuity, convergence, and geometric structure. They are essential for analysis, domain theory, and logical semantics.

## Definition

### Topological Space

A topological space (X, T) consists of:
- Set X (points)
- Collection T of subsets (open sets)

**Axioms**:
- Empty set and X are in T
- Arbitrary unions of sets in T are in T
- Finite intersections of sets in T are in T

### Lean 4 Definition

```lean
class TopologicalSpace (X : Type) where
  isOpen : Set X -> Prop
  isOpen_univ : isOpen Set.univ
  isOpen_inter : isOpen s -> isOpen t -> isOpen (s inter t)
  isOpen_sUnion : (forall t in S, isOpen t) -> isOpen (sUnion S)
```

## Key Concepts

### Closed Sets

Complements of open sets:

```lean
def isClosed (s : Set X) : Prop := isOpen (compl s)
```

### Interior and Closure

```lean
-- Interior: largest open subset
def interior (s : Set X) : Set X :=
  sUnion {t | isOpen t and t subset s}

-- Closure: smallest closed superset
def closure (s : Set X) : Set X :=
  sInter {t | isClosed t and s subset t}
```

### Neighborhoods

N is a neighborhood of x if there exists open U with x in U subset N.

## Continuity

### Continuous Functions

f: X -> Y is continuous if preimages of open sets are open:

```lean
def Continuous (f : X -> Y) : Prop :=
  forall s, isOpen s -> isOpen (f^(-1) s)
```

### Homeomorphisms

Bijective continuous functions with continuous inverse.

## Special Topologies

### Discrete Topology

Every subset is open.

### Indiscrete Topology

Only empty set and X are open.

### Subspace Topology

Induced topology on subsets.

### Product Topology

Basis: products of open sets.

### Quotient Topology

Largest topology making quotient map continuous.

## Separation Axioms

### T0 (Kolmogorov)

For any two points, some open set contains one but not the other.

### T1

Points are closed.

### T2 (Hausdorff)

Distinct points have disjoint neighborhoods.

### T3 (Regular)

Points and closed sets have disjoint neighborhoods.

### T4 (Normal)

Disjoint closed sets have disjoint neighborhoods.

## Compactness

### Definition

Every open cover has a finite subcover.

```lean
def IsCompact (s : Set X) : Prop :=
  forall C, (forall t in C, isOpen t) -> s subset sUnion C ->
    exists F : Finset (Set X), F subset C and s subset sUnion F
```

### Key Theorems

- Continuous image of compact is compact
- Closed subset of compact is compact
- Compact subset of Hausdorff is closed

## Connectedness

### Definition

Not the union of two disjoint non-empty open sets.

### Path Connectedness

Any two points joined by a continuous path.

## Mathlib Imports

```lean
import Mathlib.Topology.Basic
import Mathlib.Topology.Separation
import Mathlib.Topology.Compactness.Basic
import Mathlib.Topology.Connected.Basic
```

## Applications

- Analysis: Continuity, limits
- Logic: Topological semantics
- Domain theory: Scott topology
- Algebraic geometry: Zariski topology

## References

- Munkres: Topology
- Mathlib documentation
- General Topology (Kelley)
