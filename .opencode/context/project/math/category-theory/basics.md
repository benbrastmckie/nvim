# Category Theory Basics

## Overview

Category theory provides a unifying framework for mathematical structures. Categories capture the essence of composition and identity.

## Definition

### Category

A category C consists of:
- **Objects**: Collection Ob(C)
- **Morphisms**: For each pair A, B, a set Hom(A, B)
- **Composition**: g o f for f: A -> B and g: B -> C
- **Identity**: id_A for each object A

### Axioms

- **Associativity**: h o (g o f) = (h o g) o f
- **Identity**: id_B o f = f = f o id_A

### Lean 4 Definition

```lean
class Category (C : Type) where
  Hom : C -> C -> Type
  id : forall A, Hom A A
  comp : forall {A B C}, Hom B C -> Hom A B -> Hom A C
  id_comp : forall f : Hom A B, comp (id B) f = f
  comp_id : forall f : Hom A B, comp f (id A) = f
  assoc : forall (f : Hom A B) (g : Hom B C) (h : Hom C D),
          comp h (comp g f) = comp (comp h g) f
```

## Examples

### Concrete Categories

- **Set**: Sets and functions
- **Grp**: Groups and homomorphisms
- **Top**: Topological spaces and continuous maps
- **Vect_k**: Vector spaces over k and linear maps

### Thin Categories

- **Posets**: Objects are elements, morphism if a <= b
- At most one morphism between any two objects

## Functors

### Definition

A functor F: C -> D consists of:
- Object map: F(A) for each object A
- Morphism map: F(f) for each morphism f

### Axioms

- **Identity**: F(id_A) = id_{F(A)}
- **Composition**: F(g o f) = F(g) o F(f)

### Lean 4 Definition

```lean
structure Functor (C D : Type) [Category C] [Category D] where
  obj : C -> D
  map : forall {A B}, Hom A B -> Hom (obj A) (obj B)
  map_id : forall A, map (id A) = id (obj A)
  map_comp : forall f g, map (comp g f) = comp (map g) (map f)
```

## Natural Transformations

### Definition

A natural transformation alpha: F => G consists of:
- Components: alpha_A : F(A) -> G(A) for each object A

### Naturality Condition

For any f: A -> B:
```
alpha_B o F(f) = G(f) o alpha_A
```

### Lean 4 Definition

```lean
structure NatTrans (F G : Functor C D) where
  app : forall A, Hom (F.obj A) (G.obj A)
  naturality : forall (f : Hom A B),
               comp (app B) (F.map f) = comp (G.map f) (app A)
```

## Universal Properties

### Initial Object

Object I such that there is a unique morphism I -> A for each A.

### Terminal Object

Object T such that there is a unique morphism A -> T for each A.

### Products

Object A x B with projections pi_1, pi_2 satisfying universal property.

### Coproducts

Object A + B with injections i_1, i_2 satisfying universal property.

## Limits and Colimits

### Limits

Universal cones over diagrams:
- Products, equalizers, pullbacks

### Colimits

Universal cocones under diagrams:
- Coproducts, coequalizers, pushouts

## Adjunctions

### Definition

Functors F: C -> D and G: D -> C form an adjunction F -| G if:
```
Hom_D(F(A), B) ≅ Hom_C(A, G(B))
```
naturally in A and B.

### Unit and Counit

- Unit: eta: Id_C => GF
- Counit: epsilon: FG => Id_D

## Mathlib Imports

```lean
import Mathlib.CategoryTheory.Category.Basic
import Mathlib.CategoryTheory.Functor.Basic
import Mathlib.CategoryTheory.NatTrans
import Mathlib.CategoryTheory.Limits.Basic
import Mathlib.CategoryTheory.Adjunction.Basic
```

## References

- Mac Lane: Categories for the Working Mathematician
- Awodey: Category Theory
- Mathlib CategoryTheory documentation
