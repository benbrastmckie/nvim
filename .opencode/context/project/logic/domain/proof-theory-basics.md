# Proof Theory Basics

**Created**: 2026-02-27
**Purpose**: Fundamental concepts of proof theory

---

## Proof Systems

### Hilbert Systems

- Many axiom schemas
- Few rules (typically modus ponens)
- Proofs: Linear sequences of formulas

**Example (propositional)**:
- A1: phi -> (psi -> phi)
- A2: (phi -> (psi -> chi)) -> ((phi -> psi) -> (phi -> chi))
- A3: (not phi -> not psi) -> (psi -> phi)
- MP: From phi and phi -> psi, derive psi

### Natural Deduction

- Few axioms (typically none)
- Many introduction/elimination rules
- Proofs: Tree structure

**Rules**:
```
      [A]
       :
       B
    -------  (->I)
    A -> B

    A -> B    A
    -----------  (->E)
         B
```

### Sequent Calculus

- Sequents: Gamma |- Delta
- Structural rules + logical rules
- Cut elimination

**Key rules**:
```
    Gamma, A |- A, Delta     (Identity)

    Gamma |- A, Delta    Gamma, A |- Delta
    --------------------------------------  (Cut)
              Gamma |- Delta
```

## Properties

### Soundness

If Gamma |- phi then Gamma |= phi
(Provable implies valid)

### Completeness

If Gamma |= phi then Gamma |- phi
(Valid implies provable)

### Consistency

Not (|- phi and |- not phi)

### Cut Elimination

Every proof with cut can be transformed to a cut-free proof.

**Consequences**:
- Subformula property
- Decidability (for some logics)
- Interpolation

## Modal Proof Theory

### Labeled Sequents

Add world labels:
- w: phi (phi holds at w)
- wRv (w relates to v)

### Display Logic

Structural connectives for modalities:
- bullet A displays Box A
- Circle A displays Diamond A

### Hypersequents

Multiple sequents with structure:
G | Gamma |- Delta | H

## Normalization

### Beta Reduction

In typed lambda calculus / natural deduction:
```
(\x.M)N -->_beta M[N/x]
```

### Strong Normalization

All reduction sequences terminate.

### Church-Rosser

Confluence: If M -> N1 and M -> N2, then exists P with N1 -> P and N2 -> P.

## Relevance to Logos

### Soundness/Completeness

Core metalogical results for Bimodal logic:
- Soundness proven in `Bimodal.Metalogic.Soundness`
- Completeness via canonical model construction

### Cut Elimination

For sequent calculus formulations:
- Implies subformula property
- Useful for proof search

### Labeling

World labels correspond to:
- Task identities
- Frame points
- Semantic evaluation contexts
