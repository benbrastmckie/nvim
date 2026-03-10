# Proof Theory Concepts

## Overview
Core proof-theoretic concepts for modal logic systems, including axioms, inference rules, and derived rules.

## Modal Logic Proof System

### Axioms
- **K Axiom (Necessity)**: box(p -> q) -> (box p -> box q)
- **K Axiom (Possibility)**: diamond(p -> q) -> (diamond p -> diamond q)
- **Dual Axioms**: box p <-> not diamond not p, diamond p <-> not box not p
- **Distribution**: Modal operators distribute over logical connectives

### Inference Rules
- **Modus Ponens**: From p and p -> q, infer q
- **Necessitation**: From |- p, infer |- box p
- **Uniform Substitution**: Replace sentence letters uniformly

### Derived Rules
- **Modal Modus Ponens**: From box p and box(p -> q), infer box q
- **Modal Transitivity**: From box p -> box q and box q -> box r, infer box p -> box r

## LEAN 4 Representation

### Formula Definition
```lean
inductive Formula : Type
  | var : PropVar -> Formula  -- Sentence letter
  | bot : Formula
  | imp : Formula -> Formula -> Formula
  | box : Formula -> Formula  -- Necessity

-- Derived connectives
def neg (phi : Formula) : Formula := phi.imp Formula.bot
def diamond (phi : Formula) : Formula := neg (Formula.box (neg phi))
```

### Provability Relation
```lean
inductive Provable : Formula -> Prop
  | modus_ponens {phi psi : Formula} :
      Provable phi -> Provable (phi.imp psi) -> Provable psi
  | necessitation {phi : Formula} :
      Provable phi -> Provable (Formula.box phi)
  | axiom {phi : Formula} :
      IsAxiom phi -> Provable phi
```

### Proof Trees
```lean
inductive ProofTree : Formula -> Type
  | axiom {phi : Formula} (h : IsAxiom phi) : ProofTree phi
  | modus_ponens {phi psi : Formula} :
      ProofTree phi -> ProofTree (phi.imp psi) -> ProofTree psi
  | necessitation {phi : Formula} :
      ProofTree phi -> ProofTree (Formula.box phi)
```

## Normal Forms

### Negation Normal Form (NNF)
Convert formula so negations only appear on atoms:
```lean
def toNNF : Formula -> Formula
  | Formula.var p => Formula.var p
  | Formula.bot => Formula.bot
  | Formula.imp phi psi => or (toNNF (neg phi)) (toNNF psi)
  | Formula.box phi => Formula.box (toNNF phi)
```

## Sequent Calculus

### Sequent Definition
```lean
structure Sequent where
  antecedent : List Formula  -- Gamma
  consequent : List Formula  -- Delta
```

### Cut Elimination
The cut rule is admissible: proofs with cut can be transformed to cut-free proofs.

## Deduction Theorem

### Statement
From Gamma, phi |- psi we can conclude Gamma |- phi -> psi.

### Limitation
Does NOT hold for necessitation: from |- phi we cannot conclude |- box phi using assumptions.

## Business Rules

1. **Use inductive types**: Define formulas and proofs inductively
2. **Separate syntax and semantics**: Keep proof theory distinct from model theory
3. **Implement proof search**: Provide both forward and backward reasoning
4. **Use sequent calculus**: For structural proof theory

## Common Pitfalls

1. **Confusing |- and |=**: Provability vs validity
2. **Applying necessitation incorrectly**: Requires no assumptions
3. **Forgetting uniform substitution**: Must replace all occurrences
4. **Not checking axiom instances**: Verify axiom schemas properly instantiated

## References

- Modal Logic textbooks (Blackburn, de Rijke, Venema)
- Proof Theory (Troelstra, Schwichtenberg)
- Handbook of Modal Logic
