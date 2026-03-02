# Profunctors

## Overview

Profunctors (also called distributors or bimodules) generalize relations between sets to relations between categories. They provide a setting for generalized functors and relational reasoning.

## Definition

### Profunctor

A profunctor P: C -/-> D is a functor:
```
P: D^op x C -> Set
```

Equivalently:
- A D-C-bimodule
- A distributor from C to D

### Notation

Common notations:
- P: C -/-> D (profunctor arrow)
- P: C -|-> D (arrow with bar)
- C ⊸ D (linear logic style)

### Lean 4 Approach

```lean
def Profunctor (C D : Type) [Category C] [Category D] :=
  Functor (D^op x C) Set
```

## Composition

### Definition

For P: A -/-> B and Q: B -/-> C, the composite Q . P: A -/-> C is:

```
(Q . P)(c, a) = integral^b P(b, a) x Q(c, b)
```

The coend over B integrates over all possible intermediate objects.

### Identity

The identity profunctor Id_C: C -/-> C is the hom functor:
```
Id_C(c', c) = Hom_C(c, c')
```

## Examples

### Hom Profunctor

For any functor F: C -> D, there is a profunctor:
```
Hom_D(-, F-): C -/-> D
```

### Relations

Relations R: X -> Y (where X, Y are sets viewed as discrete categories):
- Profunctors generalize relations
- Composition generalizes relational composition

### Presheaves

Presheaves on C are profunctors from 1 to C.

## Representable Profunctors

### Left Representable

P: C -/-> D is left representable by F: C -> D if:
```
P(d, c) ≅ Hom_D(d, F(c))
```

### Right Representable

P: C -/-> D is right representable by G: D -> C if:
```
P(d, c) ≅ Hom_C(G(d), c)
```

### Functors as Profunctors

Every functor F: C -> D gives rise to profunctors:
- F_*: C -/-> D (forward profunctor)
- F^*: D -/-> C (backward profunctor)

## The Bicategory Prof

### Objects

Small categories.

### 1-Morphisms

Profunctors.

### 2-Morphisms

Natural transformations between profunctors.

### Structure

Prof is a bicategory with:
- Composition via coends
- Identities as hom functors

## Weighted Limits

### Definition

Limits weighted by profunctors:
- Weight W: J^op -> Set
- Limit: Universal W-weighted cone

### Application

Profunctor-weighted limits unify:
- Ordinary limits
- Indexed limits
- Enriched limits

## Applications

### Type Theory

- Relational parametricity
- Logical relations

### Database Theory

- Queries as profunctors
- Data migration

### Lens Theory

- Lenses as specific profunctors
- Optics generalization

## Key Theorems

### Yoneda for Profunctors

```
P(d, c) ≅ Nat(Hom_C(c, -), P(d, -))
```

### Adjunctions as Profunctors

An adjunction F -| G corresponds to:
```
Hom_D(-, F-) ≅ Hom_C(G-, -)
```

## References

- Benabou: Distributeurs
- Street: Fibrations and Yoneda's lemma
- Loregian: Coend Calculus
