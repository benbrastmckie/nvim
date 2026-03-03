# Kripke Semantics Overview

> **Note**: This file describes standard Kripke semantics for modal logic. For the actual
> Logos implementation using task-based semantics, see [task-semantics.md](task-semantics.md).

## Overview
Semantic foundations for bimodal logic using Kripke models with two accessibility relations.

## Kripke Models for Bimodal Logic

### Model Structure
A bimodal Kripke model M = (W, R₁, R₂, V) where:
- **W**: Set of possible worlds
- **R₁**: First accessibility relation (for □₁)
- **R₂**: Second accessibility relation (for □₂)
- **V**: Valuation function (assigns truth values to propositions at worlds)

### Satisfaction Relation
- **M, w ⊨ p**: Proposition p is true at world w
- **M, w ⊨ □₁φ**: φ is true at all R₁-accessible worlds from w
- **M, w ⊨ □₂φ**: φ is true at all R₂-accessible worlds from w
- **M, w ⊨ ◇₁φ**: φ is true at some R₁-accessible world from w
- **M, w ⊨ ◇₂φ**: φ is true at some R₂-accessible world from w

## LEAN 4 Representation

### Model Definition
```lean
structure BimodalModel where
  World : Type
  R1 : World → World → Prop
  R2 : World → World → Prop
  V : PropVar → World → Prop
```

### Satisfaction Relation
```lean
def satisfies (M : BimodalModel) (w : M.World) : Formula → Prop
  | Formula.var p => M.V p w
  | Formula.box1 φ => ∀ w', M.R1 w w' → satisfies M w' φ
  | Formula.box2 φ => ∀ w', M.R2 w w' → satisfies M w' φ
  | Formula.diamond1 φ => ∃ w', M.R1 w w' ∧ satisfies M w' φ
  | Formula.diamond2 φ => ∃ w', M.R2 w w' ∧ satisfies M w' φ
```

## Frame Properties
- **Reflexivity**: ∀w, R w w
- **Transitivity**: ∀w₁ w₂ w₃, R w₁ w₂ → R w₂ w₃ → R w₁ w₃
- **Symmetry**: ∀w₁ w₂, R w₁ w₂ → R w₂ w₁
- **Euclidean**: ∀w₁ w₂ w₃, R w₁ w₂ → R w₁ w₃ → R w₂ w₃

## Validity and Satisfiability
- **Valid**: True in all models at all worlds
- **Satisfiable**: True in some model at some world
- **Frame Valid**: True in all models based on a frame class

## References
- Kripke semantics for modal logic
- Bimodal logic model theory
- LEAN mathlib model theory
