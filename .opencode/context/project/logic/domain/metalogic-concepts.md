# Soundness and Completeness

## Overview
Metatheoretic properties connecting proof theory and semantics. Soundness states that provability implies validity; completeness is the converse.

## Soundness

### Statement
If a formula is provable, then it is valid in all models.

```lean
theorem soundness (phi : Formula) : Provable phi -> valid phi
```

### Proof Approach
1. Show all axioms are valid
2. Show inference rules preserve validity
3. Induction on derivation structure

### Axiom Validity
Each axiom schema must be shown to be valid:
- K axiom valid in all frames
- T axiom valid in reflexive frames
- 4 axiom valid in transitive frames
- B axiom valid in symmetric frames

## Completeness

### Statement
If a formula is valid in all models, then it is provable.

```lean
theorem completeness (phi : Formula) : valid phi -> Provable phi
```

### Canonical Model Construction
The key to proving completeness is constructing a canonical model:

```lean
-- Maximal consistent set
def MaximalConsistentSet (Gamma : Set Formula) : Prop :=
  Consistent Gamma and forall phi, phi not in Gamma -> not Consistent (insert phi Gamma)

-- Canonical model
def CanonicalModel : KripkeModel where
  World := {Gamma : Set Formula | MaximalConsistentSet Gamma}
  R := fun Gamma Delta => forall phi, Formula.box phi in Gamma -> phi in Delta
  V := fun p Gamma => Formula.var p in Gamma.val
```

### Truth Lemma
Formula is in maximal consistent set iff satisfied in canonical model:
```lean
theorem truth_lemma (phi : Formula) (Gamma : CanonicalModel.World) :
    phi in Gamma.val <-> CanonicalModel, Gamma |= phi
```

### Lindenbaum's Lemma
Every consistent set can be extended to a maximal consistent set:
```lean
theorem lindenbaum (Gamma : Set Formula) (h : Consistent Gamma) :
    exists Delta, Gamma subset Delta and MaximalConsistentSet Delta
```

## Decidability

### Statement
There exists an algorithm to determine if a formula is provable.

### Finite Model Property
Many modal logics have the finite model property:
```lean
theorem finite_model_property (phi : Formula) :
    satisfiable phi -> exists (M : KripkeModel), Finite M.World and satisfiableInModel M phi
```

### Decidability via Filtration
Use filtration to construct finite models from infinite ones.

## Consistency

### Statement
There is no formula phi such that both phi and not phi are provable.

```lean
theorem consistency : not exists phi, Provable phi and Provable (neg phi)
```

## Compactness

### Statement
If every finite subset of a set of formulas is satisfiable, then the whole set is satisfiable.

```lean
theorem compactness (Gamma : Set Formula) :
    (forall Delta : Finset Formula, Delta subset Gamma -> satisfiable (conj Delta)) ->
    exists M : KripkeModel, exists w, forall phi in Gamma, M, w |= phi
```

## Interpolation

### Craig Interpolation
If phi -> psi is valid, there exists an interpolant using only common variables.

```lean
theorem craig_interpolation (phi psi : Formula) (h : valid (phi.imp psi)) :
    exists chi : Formula,
      (vars chi subset vars phi inter vars psi) and
      valid (phi.imp chi) and
      valid (chi.imp psi)
```

## Business Rules

1. **Prove soundness first**: Always easier than completeness
2. **Use canonical models**: Standard technique for completeness
3. **Check frame correspondence**: Different axioms need different frames
4. **Use filtration**: For finite model property
5. **Apply compactness**: For infinite satisfiability arguments

## Common Pitfalls

1. **Forgetting maximality**: Lindenbaum extension is crucial
2. **Not checking consistency**: Canonical model requires consistent sets
3. **Ignoring frame properties**: Completeness depends on frame class
4. **Assuming decidability**: Not all modal logics are decidable
5. **Confusing strong/weak completeness**: Different notions exist

## References

- Modal Logic (Blackburn, de Rijke, Venema) - Chapter 4
- Handbook of Modal Logic - Completeness sections
- Computability and Logic (Boolos, Burgess, Jeffrey)
