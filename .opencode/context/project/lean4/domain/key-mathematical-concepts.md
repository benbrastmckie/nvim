# Key Mathematical Concepts in LEAN 4

## Overview
This file defines key mathematical concepts used in LEAN 4, with a focus on type theory and its applications in formalizing mathematics.

## Core Concepts

### Type Theory
LEAN 4 is based on a version of dependent type theory called the Calculus of Inductive Constructions (CIC).

- **Types as Propositions**: The Curry-Howard correspondence states that propositions are types and proofs are terms of that type.
- **Dependent Types**: Types that can depend on values. For example, `Vector α n` is the type of vectors with elements of type `α` and length `n`.

### Homotopy Type Theory (HoTT)
HoTT is an extension of type theory that uses ideas from homotopy theory to provide a new foundation for mathematics.

- **Univalence Axiom**: States that equivalent types are equal.
- **Higher Inductive Types (HITs)**: Inductive types with higher-dimensional constructors.

## Business Rules
1. All mathematical concepts must be defined in terms of the underlying type theory.
2. The use of classical logic should be minimized in favor of constructive logic.

## Relationships
- **Depends on**: Calculus of Inductive Constructions
- **Used by**: `mathlib`

## Examples
```lean
-- Dependent Type Example
def head (n : Nat) (v : Vector α n) : α :=
  v.head

-- Curry-Howard Example
def modus_ponens {p q : Prop} (h₁ : p → q) (h₂ : p) : q :=
  h₁ h₂
```
