# Lawvere Metric Spaces

## Overview

Lawvere metric spaces reinterpret metric spaces as categories enriched over the extended non-negative reals. This reveals deep connections between metric geometry and category theory.

## The Enriching Category

### Extended Positive Reals

The monoidal category ([0, infinity], >=, +, 0):
- Objects: Non-negative real numbers (including infinity)
- Morphisms: a >= b (a "reaches" b)
- Tensor: Addition (a + b)
- Unit: 0

### Monoidal Structure

- Symmetric monoidal
- Not cartesian (sum, not product)

## Lawvere Metric Space

### Definition

A category enriched over ([0, infinity], >=, +, 0):
- Objects: Points X
- Hom(x,y): Distance d(x,y) in [0, infinity]
- Composition: d(y,z) + d(x,y) >= d(x,z) (triangle inequality)
- Identity: 0 >= d(x,x) (reflexivity)

### Comparison to Classical Metrics

| Lawvere Metric | Classical Metric |
|----------------|------------------|
| d(x,y) in [0, infinity] | d(x,y) in [0, infinity) |
| d(x,x) = 0 | d(x,x) = 0 |
| d(x,y) + d(y,z) >= d(x,z) | d(x,y) + d(y,z) >= d(x,z) |
| d(x,y) may differ from d(y,x) | d(x,y) = d(y,x) |
| d(x,y) = 0 doesn't imply x = y | d(x,y) = 0 implies x = y |

## Properties

### Asymmetric Distances

Lawvere metrics allow asymmetry:
- d(x,y) may differ from d(y,x)
- Models directed distances

### Zero Distance

d(x,y) = 0 doesn't require x = y:
- Points can be "0-close" but distinct
- Captures quotient structures

### Infinite Distance

d(x,y) = infinity is allowed:
- Points may be "unreachable"
- Handles disconnected spaces

## Enriched Functors

### Contractions

A 1-Lipschitz map f: X -> Y:
- d_Y(f(x), f(x')) <= d_X(x, x')

### Non-Expansive Maps

Maps that don't increase distance.

## Cauchy Completeness

### Cauchy Sequences

Categorically: Forward Cauchy sequences as left modules.

### Cauchy Completion

Universal construction adding limits of Cauchy sequences.

### Connection to Colimits

Cauchy limits are enriched weighted colimits.

## Applications

### Computer Science

- Program metrics
- Quantitative semantics
- Approximate equivalence

### Logic

- Quantitative logic
- Fuzzy reasoning
- Metric semantics

### Optimization

- Cost functions
- Resource consumption
- Algorithm analysis

## Key Theorems

### Yoneda Embedding

Every Lawvere metric space embeds in its space of modules.

### Completion

Every Lawvere metric space has a Cauchy completion.

### Adjunctions

Distance-preserving functors form adjunctions.

## References

- Lawvere: Metric Spaces, Generalized Logic, and Closed Categories
- Bonsangue et al.: Generalized Metric Spaces
- Rutten: Relators and Metric Bisimulations
