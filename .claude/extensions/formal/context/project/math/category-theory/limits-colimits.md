# Limits and Colimits

**Created**: 2026-02-27
**Purpose**: Universal constructions in category theory

---

## Limits

### Definition

A limit of a diagram D: J -> C is an object L with:
- Projection morphisms pi_j: L -> D(j) for each j in J
- Universal property: For any cone, unique factorization through L

### Common Limits

| Limit | Diagram Shape | Construction |
|-------|---------------|--------------|
| Terminal object | Empty | Unique object 1 |
| Product | Discrete pair | A x B |
| Equalizer | Parallel pair | Subobject where f = g |
| Pullback | Cospan A -> C <- B | Fiber product |

### Products

The product A x B with projections pi_1, pi_2 satisfies:
For any X with f: X -> A and g: X -> B, exists unique h: X -> A x B

```
       X
      / \
     f   g
    /     \
   v       v
   A <-pi1- AxB -pi2-> B
```

### Pullbacks

Given f: A -> C and g: B -> C, the pullback P satisfies:
```
P ----> B
|       |
|       g
v       v
A --f-> C
```

## Colimits

### Definition

A colimit is a limit in the opposite category C^op.

### Common Colimits

| Colimit | Diagram Shape | Construction |
|---------|---------------|--------------|
| Initial object | Empty | Unique object 0 |
| Coproduct | Discrete pair | A + B (disjoint union) |
| Coequalizer | Parallel pair | Quotient |
| Pushout | Span A <- C -> B | Amalgamated sum |

### Coproducts

The coproduct A + B with injections i_1, i_2 satisfies:
For any X with f: A -> X and g: B -> X, exists unique h: A + B -> X

## Preservation

- **Limit-preserving functors**: Right adjoints preserve limits
- **Colimit-preserving functors**: Left adjoints preserve colimits

## In Lean/Mathlib

```lean
-- Product in Mathlib
def prod (X Y : C) [HasProduct X Y] : C := ...

-- Universal property
def prod.lift (f : Z --> X) (g : Z --> Y) : Z --> X x Y := ...
```

## Application in Logos

- Products model conjunction
- Coproducts model disjunction
- Pullbacks model substitution
- Colimits model quotient structures
