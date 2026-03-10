# Functors and Natural Transformations

**Created**: 2026-02-27
**Purpose**: Functors and natural transformations for categorical semantics

---

## Functors

### Covariant Functor

F: C -> D assigns:
- Objects: A |-> F(A)
- Morphisms: (f: A -> B) |-> (F(f): F(A) -> F(B))

**Preservation laws**:
- F(id_A) = id_F(A)
- F(g . f) = F(g) . F(f)

### Contravariant Functor

F: C^op -> D (equivalently, reverses morphism direction):
- (f: A -> B) |-> (F(f): F(B) -> F(A))
- F(g . f) = F(f) . F(g)

### Important Functors

| Functor | From | To | Description |
|---------|------|----|-----------|
| Forgetful | Grp | Set | Forget group structure |
| Free | Set | Grp | Free group on set |
| Hom(A, -) | C | Set | Representable functor |
| Hom(-, B) | C^op | Set | Contravariant hom |

## Natural Transformations

### Definition

Given functors F, G: C -> D, a natural transformation eta: F => G assigns:
- For each object A in C, a morphism eta_A: F(A) -> G(A)

**Naturality square**: For any f: A -> B:
```
F(A) --F(f)--> F(B)
 |              |
eta_A         eta_B
 |              |
 v              v
G(A) --G(f)--> G(B)
```
Commutes: eta_B . F(f) = G(f) . eta_A

### Natural Isomorphism

A natural transformation where each component eta_A is an isomorphism.

## Functor Categories

The category [C, D] has:
- Objects: Functors F: C -> D
- Morphisms: Natural transformations

## In Lean/Mathlib

```lean
-- Functor definition
structure Functor (C D : Type*) [Category C] [Category D] where
  obj : C -> D
  map : {X Y : C} -> (X --> Y) -> (obj X --> obj Y)
  map_id : map (𝟙 X) = 𝟙 (obj X)
  map_comp : map (f >> g) = map f >> map g

-- Natural transformation
structure NatTrans (F G : Functor C D) where
  app : (X : C) -> (F.obj X --> G.obj X)
  naturality : app Y >> G.map f = F.map f >> app X
```

## Application to Modal Logic

- Modal operators as functors
- Frame morphisms as natural transformations
- Adjunctions for necessity/possibility duality
