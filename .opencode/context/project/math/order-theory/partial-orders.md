# Partial Orders

## Overview

Partial orders are fundamental structures in mathematics and computer science, providing the foundation for lattice theory, domain theory, and order-theoretic reasoning.

## Definition

### Partial Order

A partial order (P, <=) consists of:
- Set P
- Binary relation <= satisfying:

**Axioms**:
- **Reflexivity**: x <= x
- **Antisymmetry**: x <= y and y <= x implies x = y
- **Transitivity**: x <= y and y <= z implies x <= z

### Lean 4 Definition

```lean
class PartialOrder (P : Type) extends Preorder P where
  le_antisymm : forall a b, a <= b -> b <= a -> a = b
```

## Related Structures

### Preorder

Reflexive and transitive (no antisymmetry):

```lean
class Preorder (P : Type) where
  le : P -> P -> Prop
  le_refl : forall a, le a a
  le_trans : forall a b c, le a b -> le b c -> le a c
```

### Total Order

Linear order where all elements are comparable:
- forall x y, x <= y or y <= x

### Strict Order

Derived strict relation:
- x < y iff x <= y and x != y

## Key Concepts

### Upper and Lower Bounds

- **Upper bound** of S: u such that s <= u for all s in S
- **Lower bound** of S: l such that l <= s for all s in S

### Supremum and Infimum

- **Supremum** (sup): Least upper bound
- **Infimum** (inf): Greatest lower bound

### Chains and Antichains

- **Chain**: Totally ordered subset
- **Antichain**: No two elements comparable

## Well-Founded Orders

### Definition

An order is well-founded if every non-empty subset has a minimal element.

Equivalently: No infinite descending chains.

### Lean 4 Definition

```lean
def WellFounded (r : A -> A -> Prop) : Prop :=
  forall a, Acc r a

structure WellFoundedOrder (P : Type) extends PartialOrder P where
  wf : WellFounded (< on P)
```

### Applications

- Termination proofs
- Induction principles
- Recursion foundations

## Key Theorems

### Zorn's Lemma

If every chain has an upper bound, there exists a maximal element.

```lean
theorem zorns_lemma {P : Type} [PartialOrder P]
    (h : forall C : Set P, IsChain C -> exists ub, forall x in C, x <= ub) :
    exists m, forall x, m <= x -> x = m
```

### Fixed Point Theorems

On complete partial orders:
- Knaster-Tarski: Monotone functions have fixed points
- Kleene: Continuous functions have least fixed points

## Order-Preserving Maps

### Monotone Functions

f is monotone if x <= y implies f(x) <= f(y):

```lean
def Monotone (f : P -> Q) : Prop :=
  forall a b, a <= b -> f a <= f b
```

### Order Embeddings

Injective monotone functions with monotone inverse.

### Order Isomorphisms

Bijective order-preserving maps with order-preserving inverse.

## Mathlib Imports

```lean
import Mathlib.Order.Basic
import Mathlib.Order.WellFounded
import Mathlib.Order.Zorn
import Mathlib.Order.FixedPoints
```

## Common Patterns

### Defining Order Structure

```lean
instance : PartialOrder MyType where
  le := myLe
  le_refl := myRefl
  le_trans := myTrans
  le_antisymm := myAntisymm
```

### Proving Well-Foundedness

1. Define measure function to natural numbers
2. Show measure decreases
3. Transfer well-foundedness

## References

- Davey and Priestley: Introduction to Lattices and Order
- Mathlib documentation
- Set Theory (Kunen)
