# Bilattice Theory

## Overview

Bilattices are algebraic structures with two lattice orderings, used in multi-valued logic, paraconsistent reasoning, and knowledge representation.

## Definition

### Basic Bilattice

A bilattice (B, <=t, <=k) consists of:
- Set B
- Truth ordering <=t (lattice)
- Knowledge ordering <=k (lattice)

### Standard Example: FOUR

The four-valued bilattice with elements:
- **T** (true)
- **F** (false)
- **Both** (contradictory)
- **Neither** (unknown)

Truth ordering: F <t Neither <t Both, F <t T <t Both
Knowledge ordering: Neither <k T <k Both, Neither <k F <k Both

## Operations

### Truth Operations

- **meet_t**: Greatest lower bound in truth ordering
- **join_t**: Least upper bound in truth ordering

### Knowledge Operations

- **meet_k**: Greatest lower bound in knowledge ordering
- **join_k**: Least upper bound in knowledge ordering

### Negation

Swaps T and F while preserving knowledge:
- neg(T) = F
- neg(F) = T
- neg(Both) = Both
- neg(Neither) = Neither

### Conflation

Swaps Both and Neither while preserving truth:
- conf(T) = T
- conf(F) = F
- conf(Both) = Neither
- conf(Neither) = Both

## Key Properties

### Interlacing

The orderings satisfy:
- meet_t and join_t are monotone in <=k
- meet_k and join_k are monotone in <=t

### De Morgan Properties

```
neg(a meet_t b) = neg(a) join_t neg(b)
neg(a join_t b) = neg(a) meet_t neg(b)
```

## Distributive Bilattices

### Definition

Both orderings form distributive lattices.

### Properties

In distributive bilattices:
- Negation is an isomorphism
- Additional algebraic laws hold

## Applications

### Paraconsistent Logic

Handle contradictory information without explosion:
- Both allows contradiction without trivializing
- Neither handles incompleteness

### Default Reasoning

Knowledge ordering for belief revision:
- Prefer more informative answers
- Handle incomplete information

### Database Nulls

Four-valued treatment of null values:
- T: True in database
- F: False in database
- Neither: Unknown/missing
- Both: Conflicting sources

## Lean 4 Representation

```lean
structure Bilattice (B : Type) where
  truth_lat : Lattice B
  know_lat : Lattice B
  interlacing : Interlacing truth_lat know_lat

structure FOUR where
  val : Bool x Bool
  -- (true, true) = Both
  -- (true, false) = T
  -- (false, true) = F
  -- (false, false) = Neither
```

## Relationship to Logic

### Four-Valued Logic

Belnap's useful four-valued logic:
- T: told true
- F: told false
- Both: told both
- Neither: told neither

### Fitting's Interpretation

For logic programming:
- Extending two-valued models
- Handling negation-as-failure
- Three-valued stable models

## References

- Fitting: Bilattices and the Semantics of Logic Programming
- Belnap: A Useful Four-Valued Logic
- Arieli and Avron: Reasoning with Logical Bilattices
