# Category Theory Basics

**Created**: 2026-02-27
**Purpose**: Fundamental concepts of category theory for the Logos project

---

## Core Definitions

### Category

A category C consists of:
- A collection of **objects** (often denoted Ob(C))
- For each pair of objects A, B, a collection of **morphisms** Hom(A, B)
- **Composition**: For f: A -> B and g: B -> C, a morphism g . f: A -> C
- **Identity**: For each object A, an identity morphism id_A: A -> A

**Axioms**:
1. **Associativity**: (h . g) . f = h . (g . f)
2. **Identity**: f . id = f = id . f

### Morphisms

- **Monomorphism (mono)**: f . g = f . h implies g = h
- **Epimorphism (epi)**: g . f = h . f implies g = h
- **Isomorphism**: Has two-sided inverse

### Functors

A functor F: C -> D assigns:
- To each object A in C, an object F(A) in D
- To each morphism f: A -> B, a morphism F(f): F(A) -> F(B)

Preserving:
- Composition: F(g . f) = F(g) . F(f)
- Identity: F(id_A) = id_F(A)

## Common Categories

| Category | Objects | Morphisms |
|----------|---------|-----------|
| Set | Sets | Functions |
| Grp | Groups | Homomorphisms |
| Top | Topological spaces | Continuous maps |
| Vect_K | Vector spaces over K | Linear maps |
| Pos | Posets | Monotone maps |
| Cat | Small categories | Functors |

## In Lean/Mathlib

```lean
-- Mathlib category definition
class Category (C : Type*) where
  Hom : C -> C -> Type*
  id : (X : C) -> Hom X X
  comp : {X Y Z : C} -> Hom Y Z -> Hom X Y -> Hom X Z
  comp_id : ...
  id_comp : ...
  assoc : ...
```

## Relevance to Logos

Category theory provides:
- Semantic framework for modal logics
- Kripke frames as categories
- Adjunctions for modal/temporal operators
- Enriched categories for quantitative reasoning
