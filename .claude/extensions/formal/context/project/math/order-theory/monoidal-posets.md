# Monoidal Posets

## Overview

Monoidal posets combine partial order structure with monoidal (tensor) structure. They appear in resource semantics, linear logic, and categorical logic.

## Definition

### Monoidal Poset

A monoidal poset (P, <=, tensor, I) consists of:
- Partial order (P, <=)
- Monoid structure (P, tensor, I)
- Compatibility: tensor is monotone in both arguments

### Axioms

- Partial order axioms (reflexivity, antisymmetry, transitivity)
- Monoid axioms (associativity, identity)
- **Monotonicity**: a <= b and c <= d implies a tensor c <= b tensor d

## Examples

### Sets with Cartesian Product

- P = Set
- tensor = cartesian product
- I = singleton set
- <= = subset

### Natural Numbers with Addition

- P = N
- tensor = +
- I = 0
- <= = standard ordering

### Resources

- Elements represent resources
- Tensor represents combination
- Order represents resource availability

## Key Properties

### Residuation

In a closed monoidal poset, tensor has a right adjoint:
- a tensor b <= c iff b <= a -o c

Where -o is the "linear implication" or residual.

### Lean 4 Definition

```lean
class MonoidalPoset (P : Type) extends PartialOrder P, Monoid P where
  mul_mono : forall a b c d, a <= b -> c <= d -> a * c <= b * d

class ResidualPoset (P : Type) extends MonoidalPoset P where
  residual : P -> P -> P
  residual_adj : forall a b c, a * b <= c <-> b <= residual a c
```

## Quantales

### Definition

A quantale is a complete lattice with a monoid structure where:
- Tensor distributes over arbitrary joins

### Relation to Logic

- Models linear logic
- Provides semantics for resource-sensitive reasoning

### Examples

- Power set with union and intersection
- Relations with composition

## Applications

### Linear Logic

Monoidal posets model:
- Multiplicative conjunction (tensor)
- Linear implication (residual)
- Resources as propositions

### Concurrent Systems

- Resources as tokens
- Tensor as parallel composition
- Order as resource consumption

### Domain Theory

- Continuous posets
- Algebraic domains
- Computation semantics

## Categorical Connection

### Monoidal Categories

Monoidal posets are thin monoidal categories:
- Objects: Elements of P
- Morphisms: Unique if a <= b
- Tensor product: Monoidal operation

### Enriched Categories

Categories enriched over monoidal posets:
- Weighted limits and colimits
- Metric-like structures

## References

- Rosenthal: Quantales and their Applications
- Vickers: Topology via Logic
- Girard: Linear Logic
