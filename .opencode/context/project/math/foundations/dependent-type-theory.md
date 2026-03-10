# Dependent Type Theory

## Overview

Dependent type theory extends simple type theory by allowing types to depend on terms. This enables precise specifications, proof-relevant mathematics, and serves as the foundation for proof assistants like Lean.

## Core Concepts

### Dependent Types

Types that depend on terms:
- Pi types: (x : A) -> B(x) (dependent functions)
- Sigma types: (x : A) x B(x) (dependent pairs)

### Judgment Forms

- Type formation: A : Type
- Term formation: a : A
- Type equality: A = B
- Term equality: a = b : A

## Pi Types (Dependent Functions)

### Formation

```
     A : Type    x : A |- B : Type
     --------------------------------
          (x : A) -> B : Type
```

### Introduction

```
     x : A |- b : B
     ----------------------
     fun x => b : (x : A) -> B
```

### Elimination

```
     f : (x : A) -> B    a : A
     ---------------------------
          f a : B[a/x]
```

### Computation

(fun x => b) a = b[a/x]

## Sigma Types (Dependent Pairs)

### Formation

```
     A : Type    x : A |- B : Type
     --------------------------------
          (x : A) x B : Type
```

### Introduction

```
     a : A    b : B[a/x]
     ----------------------
     (a, b) : (x : A) x B
```

### Elimination

```
     p : (x : A) x B
     -----------------    -----------------
     p.1 : A              p.2 : B[p.1/x]
```

### Computation

(a, b).1 = a and (a, b).2 = b

## Identity Types

### Formation

```
     A : Type    a : A    b : A
     ----------------------------
          a = b : Type
```

### Introduction (Reflexivity)

```
     a : A
     -------------
     refl : a = a
```

### Elimination (J)

Path induction: transport along equalities.

## Universes

### Type Hierarchy

```
Type 0 : Type 1 : Type 2 : ...
```

### Universe Polymorphism

Definitions can be universe-polymorphic.

## Inductive Types

### Definition

Introduce new types by specifying constructors:

```lean
inductive Nat : Type
  | zero : Nat
  | succ : Nat -> Nat
```

### Elimination

Pattern matching and recursion.

## Propositions as Types

### Curry-Howard Correspondence

| Logic | Type Theory |
|-------|-------------|
| Proposition | Type |
| Proof | Term |
| Implication | Function type |
| Conjunction | Product type |
| Disjunction | Sum type |
| Universal | Pi type |
| Existential | Sigma type |

## Lean 4 Specifics

### Syntax

```lean
-- Dependent function type
def dependent_func : (n : Nat) -> Fin n -> Nat := fun n i => n

-- Dependent pair type
def dependent_pair : (n : Nat) x Fin n := (5, 3)

-- Identity type
theorem eq_example : 2 + 2 = 4 := rfl
```

### Type Classes

Overloading via type class resolution.

### Tactics

Proof construction via interactive tactics.

## Applications

### Verified Programming

- Specifications as types
- Programs as proofs
- Correctness by construction

### Mathematics

- Formal proofs
- Constructive mathematics
- Homotopy type theory

### Certified Systems

- Verified compilers
- Cryptographic protocols
- Safety-critical systems

## References

- Nordstrom et al.: Programming in Martin-Lof's Type Theory
- Univalent Foundations: Homotopy Type Theory
- Lean documentation
