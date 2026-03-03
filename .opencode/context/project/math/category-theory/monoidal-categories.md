# Monoidal Categories

**Created**: 2026-02-27
**Purpose**: Monoidal structure and enriched categories

---

## Monoidal Categories

### Definition

A monoidal category (C, x, I) consists of:
- A category C
- A bifunctor x : C x C -> C (tensor product)
- A unit object I
- Natural isomorphisms (coherence):
  - Associator: (A x B) x C ~ A x (B x C)
  - Left unitor: I x A ~ A
  - Right unitor: A x I ~ A

**Coherence**: Pentagon and triangle diagrams commute.

### Symmetric Monoidal

Additional structure:
- Braiding: A x B ~ B x A
- Symmetric: braiding^2 = id

### Examples

| Category | Tensor | Unit |
|----------|--------|------|
| Set | Cartesian product | Singleton |
| Vect_K | Tensor product | K |
| Cat | Product category | 1 |
| [0,inf] | + | 0 |
| [0,inf] | max | 0 |

## Enriched Categories

### Definition

A V-enriched category (for monoidal V) has:
- Objects as usual
- Hom-objects: Hom(A,B) in V (not Set)
- Composition: Hom(B,C) x Hom(A,B) -> Hom(A,C) in V
- Identity: I -> Hom(A,A) in V

### Important Enrichments

| Base V | Enriched Category | Meaning |
|--------|------------------|---------|
| 2 = {0,1} | Preorders | A <= B iff Hom(A,B) = 1 |
| [0,inf] | Metric spaces | d(A,B) = Hom(A,B) |
| Pos | Order-enriched | Hom has ordering |
| Cat | 2-categories | Hom is a category |

## Quantale-Enriched Categories

### Quantales

A quantale (Q, *, e) is a complete lattice with:
- Monoid operation *
- Unit e
- Distribution: a * (sup B) = sup(a * b : b in B)

### Enrichment

Q-categories generalize:
- Metric spaces ([0,inf]-categories)
- Preorders (2-categories)
- Probabilistic metrics

## Application in Logos

### Spatial Semantics

- Quantale-enriched categories for mereology
- Distance-like semantics for proximity
- Closure operators from enrichment

### Modal Semantics

- Enriched presheaves for semantics
- Day convolution for modalities
- Profunctors for relations

## In Lean/Mathlib

```lean
-- Monoidal category
class MonoidalCategory (C : Type*) [Category C] where
  tensorObj : C -> C -> C
  tensorHom : (X1 --> Y1) -> (X2 --> Y2) -> (X1 x X2 --> Y1 x Y2)
  tensorUnit : C
  associator : (X x Y) x Z ~ X x (Y x Z)
  leftUnitor : I x X ~ X
  rightUnitor : X x I ~ X
  -- coherence conditions
```
