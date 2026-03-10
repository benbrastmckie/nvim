# Topological Foundations for Logic

## Overview

Topology provides semantic foundations for various logics, from intuitionistic logic to modal logic. This document covers topological concepts relevant to logical semantics.

## Basic Topological Concepts

### Topological Space

A topological space (X, T) consists of:
- **X**: Set of points
- **T**: Topology (collection of open sets)

**Axioms**:
- Empty set and X are open
- Arbitrary unions of open sets are open
- Finite intersections of open sets are open

### Key Constructions

- **Interior**: int(A) = largest open set contained in A
- **Closure**: cl(A) = smallest closed set containing A
- **Boundary**: bd(A) = cl(A) \ int(A)

## Topological Semantics for Modal Logic

### Interior/Closure Interpretation

- **box phi**: true at points in int(|phi|)
- **diamond phi**: true at points in cl(|phi|)

This gives S4 modal logic:
- box phi -> phi (T axiom, from int(A) subset A)
- box phi -> box box phi (4 axiom, from int(int(A)) = int(A))

### Completeness

S4 is complete with respect to:
- All topological spaces
- The real line with standard topology
- The Cantor space

## Intuitionistic Logic

### Heyting Algebras

The open sets of a topological space form a Heyting algebra:
- Meet: Intersection
- Join: Union
- Implication: int(complement(A) union B)

### Topological Models

An intuitionistic model:
- Base: topological space
- Valuation: assigns open sets to propositions
- Truth: local truth in open sets

### Kripke Connection

Topological models generalize Kripke models:
- Points correspond to possible worlds
- Open sets correspond to upward-closed sets

## Stone Duality

### Stone Spaces

Boolean algebras correspond to Stone spaces:
- Compact, Hausdorff, zero-dimensional
- Ultrafilters as points
- Clopen sets as elements

### Duality Theorems

- Boolean algebras <-> Stone spaces
- Distributive lattices <-> Spectral spaces
- Heyting algebras <-> Esakia spaces

## Applications in Logic

### Spatial Logic

Topological operators for spatial reasoning:
- Interior: "strictly inside"
- Closure: "in or on boundary"

### Domain Theory

Scott topology on partial orders:
- Open sets: upward-closed, Scott-open
- Continuous functions: computability

### Sheaf Semantics

Topological sheaves for intuitionistic logic:
- Local truth
- Gluing conditions

## Formal Representation

### LEAN 4 Approach

```lean
-- Topological space structure
class TopologicalSpace (X : Type) where
  isOpen : Set X -> Prop
  isOpen_univ : isOpen Set.univ
  isOpen_inter : isOpen s -> isOpen t -> isOpen (s inter t)
  isOpen_sUnion : (forall t in S, isOpen t) -> isOpen (sUnion S)

-- Interior operator
def interior (s : Set X) : Set X :=
  sUnion {t | isOpen t and t subset s}

-- Closure operator
def closure (s : Set X) : Set X :=
  sInter {t | isClosed t and s subset t}
```

## References

- Johnstone: Stone Spaces
- Davey and Priestley: Introduction to Lattices and Order
- Aiello et al.: Handbook of Spatial Logics
