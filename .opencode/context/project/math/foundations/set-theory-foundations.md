# Set Theory Foundations

**Created**: 2026-02-27
**Purpose**: Set-theoretic foundations for formal mathematics

---

## Basic Set Operations

### Operations

| Operation | Notation | Definition |
|-----------|----------|------------|
| Union | A cup B | {x : x in A or x in B} |
| Intersection | A cap B | {x : x in A and x in B} |
| Difference | A \ B | {x : x in A and x not in B} |
| Complement | A^c | {x : x not in A} |
| Power set | P(A) | {S : S subset A} |

### Relations

- **Subset**: A subset B iff (x in A implies x in B)
- **Proper subset**: A proper_subset B iff A subset B and A != B
- **Equality**: A = B iff A subset B and B subset A

## Functions

### Definition

A function f: A -> B is a subset of A x B such that:
- For each a in A, exists unique b in B with (a,b) in f

### Properties

| Property | Definition |
|----------|------------|
| Injective | f(x) = f(y) implies x = y |
| Surjective | For all b in B, exists a in A with f(a) = b |
| Bijective | Injective and surjective |

### Constructions

- **Composition**: (g . f)(x) = g(f(x))
- **Inverse**: f^(-1)(b) = a iff f(a) = b
- **Image**: f(S) = {f(x) : x in S}
- **Preimage**: f^(-1)(T) = {x : f(x) in T}

## Cardinality

### Finite Sets

|A| = n means A has exactly n elements

### Infinite Cardinalities

- **Countable**: |A| = |N| (aleph_0)
- **Uncountable**: |A| > |N|
- **Continuum**: |R| = 2^(aleph_0)

### Comparison

- |A| <= |B| iff exists injection A -> B
- |A| = |B| iff exists bijection A -> B

## Axiom Systems

### ZFC Axioms

1. **Extensionality**: Sets with same elements are equal
2. **Empty set**: Empty set exists
3. **Pairing**: {a, b} exists
4. **Union**: Union of set of sets exists
5. **Power set**: P(A) exists
6. **Infinity**: Infinite set exists
7. **Separation**: {x in A : phi(x)} exists
8. **Replacement**: Image of set under function is a set
9. **Foundation**: No infinite descending in-chains
10. **Choice**: Every family of nonempty sets has a choice function

## In Lean/Mathlib

```lean
-- Set operations
def union (s t : Set A) : Set A := {x | x in s or x in t}
def inter (s t : Set A) : Set A := {x | x in s and x in t}

-- Function properties
def Injective (f : A -> B) : Prop := forall x y, f x = f y -> x = y
def Surjective (f : A -> B) : Prop := forall b, exists a, f a = b
def Bijective (f : A -> B) : Prop := Injective f and Surjective f
```

## Application in Logos

- Kripke frames as sets with relations
- Modal semantics uses power sets
- Cardinality bounds for models
- Choice principle for completeness proofs
