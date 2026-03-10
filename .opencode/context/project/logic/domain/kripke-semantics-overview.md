# Kripke Semantics Overview

## Overview
Semantic foundations for modal logic using Kripke models with accessibility relations.

## Kripke Models for Modal Logic

### Model Structure
A Kripke model M = (W, R, V) where:
- **W**: Set of possible worlds
- **R**: Accessibility relation (for necessity operator)
- **V**: Valuation function (assigns truth values to propositions at worlds)

### Bimodal Extension
A bimodal Kripke model M = (W, R1, R2, V) where:
- **R1**: First accessibility relation (for box1)
- **R2**: Second accessibility relation (for box2)

### Satisfaction Relation
- **M, w |= p**: Proposition p is true at world w
- **M, w |= box phi**: phi is true at all R-accessible worlds from w
- **M, w |= diamond phi**: phi is true at some R-accessible world from w

## LEAN 4 Representation

### Model Definition
```lean
structure KripkeModel where
  World : Type
  R : World -> World -> Prop
  V : PropVar -> World -> Prop
```

### Bimodal Model
```lean
structure BimodalModel where
  World : Type
  R1 : World -> World -> Prop
  R2 : World -> World -> Prop
  V : PropVar -> World -> Prop
```

### Satisfaction Relation
```lean
def satisfies (M : KripkeModel) (w : M.World) : Formula -> Prop
  | Formula.var p => M.V p w
  | Formula.box phi => forall w', M.R w w' -> satisfies M w' phi
  | Formula.diamond phi => exists w', M.R w w' and satisfies M w' phi
```

## Frame Properties

### Standard Frame Classes
- **Reflexivity**: forall w, R w w
- **Transitivity**: forall w1 w2 w3, R w1 w2 -> R w2 w3 -> R w1 w3
- **Symmetry**: forall w1 w2, R w1 w2 -> R w2 w1
- **Euclidean**: forall w1 w2 w3, R w1 w2 -> R w1 w3 -> R w2 w3

### Corresponding Modal Logics
| Frame Class | Axioms | Logic |
|-------------|--------|-------|
| Reflexive | T: box p -> p | T |
| Transitive | 4: box p -> box box p | K4 |
| Reflexive + Transitive | T, 4 | S4 |
| Reflexive + Transitive + Symmetric | T, 4, B | S5 |
| Reflexive + Transitive + Euclidean | T, 4, 5 | S5 |

## Validity and Satisfiability
- **Valid**: True in all models at all worlds
- **Satisfiable**: True in some model at some world
- **Frame Valid**: True in all models based on a frame class

## References
- Kripke semantics for modal logic (Kripke, 1959, 1963)
- Modal Logic (Blackburn, de Rijke, Venema)
- Handbook of Modal Logic
