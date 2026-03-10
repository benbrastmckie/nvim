# Mereology Foundations

## Overview

Mereology is the study of part-whole relations. It provides foundational concepts for state spaces, truthmaker semantics, and spatial reasoning.

## Basic Concepts

### Parthood Relation

**Primitive**: x <= y (x is part of y)

**Axioms**:
- Reflexivity: x <= x
- Antisymmetry: x <= y and y <= x implies x = y
- Transitivity: x <= y and y <= z implies x <= z

### Derived Relations

- **Proper part**: x < y iff x <= y and x != y
- **Overlap**: x o y iff exists z, z <= x and z <= y
- **Disjoint**: not (x o y)

## Mereological Operations

### Fusion (Sum)

The mereological sum of X is the smallest y containing all parts of X:
```
fusion(X) = the unique y such that:
  - for all x in X, x <= y
  - for all z, (for all x in X, x <= z) implies y <= z
```

### Product (Intersection)

When x and y overlap:
```
x meet y = the largest z such that z <= x and z <= y
```

### Complement

In classical mereology with a universal:
```
complement(x) = the fusion of all y disjoint from x
```

## Classical Extensional Mereology

### Axioms (CEM)

1. Transitivity of parthood
2. Unrestricted fusion: any non-empty collection has a fusion
3. Extensionality: objects with the same parts are identical

### Properties

- Atomic: Has minimal parts (atoms)
- Atomless: No atoms, infinitely divisible

## Applications in Logic

### State Spaces

States as mereological structures:
- Partial states as parts
- World states as maximal consistent fusions
- Compatibility via overlap

### Truthmaker Semantics

- Verifiers as states making propositions true
- Exact verification via parthood
- State fusion for conjunction

### Spatial Logic

- Regions as mereological individuals
- Connection predicates
- Topological relations

## Formal Representation

### LEAN 4 Approach

```lean
class Mereology (A : Type) where
  part : A -> A -> Prop
  refl : forall x, part x x
  antisymm : forall x y, part x y -> part y x -> x = y
  trans : forall x y z, part x y -> part y z -> part x z

class FusionMereology (A : Type) extends Mereology A where
  fusion : Set A -> A
  fusion_spec : forall X x, x in X -> part x (fusion X)
  fusion_min : forall X y, (forall x, x in X -> part x y) -> part (fusion X) y
```

## References

- Simons: Parts: A Study in Ontology
- Varzi: Mereology (Stanford Encyclopedia)
- Fine: Part-whole
