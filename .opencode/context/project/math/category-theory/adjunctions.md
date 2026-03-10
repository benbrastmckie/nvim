# Adjunctions

**Created**: 2026-02-27
**Purpose**: Adjoint functors and their applications

---

## Definition

An adjunction between categories C and D consists of:
- Functors F: C -> D (left adjoint) and G: D -> C (right adjoint)
- Natural bijection: Hom_D(F(A), B) ~ Hom_C(A, G(B))

Notation: F -| G

### Unit and Counit

- **Unit**: eta: Id_C => G . F
- **Counit**: epsilon: F . G => Id_D

**Triangle identities**:
- (epsilon . F) . (F . eta) = id_F
- (G . epsilon) . (eta . G) = id_G

## Examples

### Free-Forgetful

```
Free: Set -> Grp    (left adjoint)
Forget: Grp -> Set  (right adjoint)

Hom_Grp(Free(S), G) ~ Hom_Set(S, Forget(G))
```

### Product-Diagonal

```
Diagonal: C -> C x C
Product: C x C -> C

Hom(A, B x C) ~ Hom(A, B) x Hom(A, C)
```

### Exponential

In a cartesian closed category:
```
- x B: C -> C      (left adjoint)
(-)^B: C -> C      (right adjoint)

Hom(A x B, C) ~ Hom(A, C^B)
```

## Properties

### Uniqueness
Right adjoints (resp. left) are unique up to isomorphism.

### Preservation
- Left adjoints preserve colimits
- Right adjoints preserve limits

### Composition
Adjunctions compose:
If F -| G and F' -| G', then F' . F -| G . G'

## In Lean/Mathlib

```lean
structure Adjunction (F : C => D) (G : D => C) where
  unit : 𝟙 C => G o F
  counit : F o G => 𝟙 D
  left_triangle : ...
  right_triangle : ...
```

## Application to Modal Logic

### Necessity/Possibility

In Kripke semantics:
- Geometric morphisms (f^*, f_*)
- f^* -| f_* (direct/inverse image)
- Models necessity/possibility duality

### Temporal Operators

- Future/past modalities as adjoints
- Until/since as derived operators

## Galois Connections

An adjunction between posets (viewed as categories):
- f: P -> Q and g: Q -> P
- f(p) <= q iff p <= g(q)

Application: Interior/closure operators in topology
