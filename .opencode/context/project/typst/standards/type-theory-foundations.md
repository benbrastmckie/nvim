# Type Theory Foundations Standard

## Overview

This standard establishes consistent treatment of dependent type theory (DTT) as foundational while using set notation for convenience in Typst documents.

The approach follows **Lean/Mathlib documentation style**: present mathematics using familiar set-theoretic notation while acknowledging that all concepts have precise type-theoretic interpretations in the underlying dependent type theory.

---

## Foundational Position

### Core Principle

**Dependent Type Theory is foundational; set notation is presentational.**

Set-theoretic concepts are definable within type theory:
- Predicates are functions $P : A \to \text{Prop}$
- Subsets are subtypes $\{x : A \mid P(x)\} := \Sigma_{x:A} P(x)$
- Relations are functions $R : A \to B \to \text{Prop}$
- Universal quantification corresponds to Pi types
- Existential quantification corresponds to Sigma types

This means documents can be understood type-theoretically, with set notation serving as convenient shorthand.

### Convention Statement

Documents should reference this convention in the preface:

> The mathematical content is presented using standard notation familiar from set theory. These concepts have precise type-theoretic interpretations. We follow the Lean/Mathlib documentation style: definitions specify types explicitly, while proofs and informal discussion use conventional notation.

---

## Four-Layer Approach

### Layer 1: Preface Declaration

The preface contains a single explicit statement about the DTT foundation. This is not repeated in every chapter; instead, each chapter may include a brief reminder in its introduction.

### Layer 2: Type Annotations in Definitions

Formal definitions should include type annotations for the carrier and operations.

**Pattern**:
```typst
#definition("Preorder")[
  A *preorder* on a type $A$ is a relation $\leq : A \to A \to \text{Prop}$ satisfying:
  1. *Reflexivity*: $a \leq a$ for all $a : A$
  2. *Transitivity*: if $a \leq b$ and $b \leq c$, then $a \leq c$
]
```

**Key elements**:
- "on a type $A$" instead of "on a set $A$"
- Operations shown as function types: $\leq : A \to A \to \text{Prop}$
- Quantified variables use typing notation: "for all $a : A$"

### Layer 3: Strategic DTT Highlights

Include DTT remarks at strategic points where they aid understanding:

1. **Definition introductions**: When a concept has interesting type-theoretic character
2. **Implementation connections**: When connecting to implementations
3. **Dependent types**: When types genuinely depend on values
4. **Constructive considerations**: When classical vs constructive matters

**Pattern**:
```typst
#remark[
  In type theory, `Preorder` and `PartialOrder` are type classes. The ordering
  is denoted `LE.le` (for $\leq$) and `LT.lt` (for $<$).
]
```

### Layer 4: Code References

Include explicit code references where they illuminate the mathematical content.

**Pattern**:
```typst
#remark[
  In implementation, `Monotone f` is defined compositionally.
  Many lemmas help prove functions are monotone.
]
```

---

## Translation Table

| Set-Theoretic | Type-Theoretic | Usage |
|---------------|----------------|-------|
| Set $A$ | Type $A$ | Use "type" in definitions |
| $x \in A$ | $x : A$ | Use $x : A$ in formal definitions |
| Subset $S \subseteq A$ | Subtype $\{x : A \mid P(x)\}$ | "subset" informally, "subtype" precisely |
| Function $f : A \to B$ | Function type $A \to B$ | Same notation |
| $\forall x \in A. P(x)$ | $\Pi_{x:A} P(x)$ | Use "$\forall x : A$" (hybrid) |
| $\exists x \in A. P(x)$ | $\Sigma_{x:A} P(x)$ | Use "$\exists x : A$" (hybrid) |
| Family $(A_i)_{i \in I}$ | Dependent type $B : I \to \mathcal{U}$ | Note dependent type character |
| Relation $R \subseteq A \times B$ | $R : A \to B \to \text{Prop}$ | Use function notation in definitions |
| Empty set $\emptyset$ | Empty type $\bot$ | Set notation acceptable |
| Singleton $\{*\}$ | Unit type $\mathbb{1}$ | Set notation acceptable |

---

## Examples of Properly Written Definitions

### Order-Theoretic Definition

```typst
#definition("Partial Order")[
  A *partial order* on a type $A$ is a preorder $\leq : A \to A \to \text{Prop}$ that also satisfies:
  3. *Antisymmetry*: if $a \leq b$ and $b \leq a$, then $a = b$

  A type equipped with a partial order is called a *partially ordered type* or *poset*.
]
```

### Algebraic Definition

```typst
#definition("Monoid")[
  A *monoid* $(M, \cdot, e)$ consists of:
  - A type $M$
  - A binary operation $\cdot : M \to M \to M$
  - An identity element $e : M$

  satisfying associativity and identity laws.
]

#remark[
  In implementations, monoids are defined via type classes. The operation
  is denoted multiplicatively (`*`) or additively (`+`).
]
```

### Topological Definition

```typst
#definition("Topology")[
  A *topology* on a type $X$ is a collection $\tau$ of predicates $U : X \to \text{Prop}$
  (called *open sets*) satisfying the standard axioms.
]

#remark[
  Open sets can be viewed as predicates: $U : X \to \text{Prop}$ assigns to each
  point a proposition "this point is in $U$". The extension $\{x : X \mid U(x)\}$
  is the corresponding subtype.
]
```

---

## What NOT to Do

### Avoid Over-Verbosity

Do NOT add DTT remarks to every definition. The goal is strategic placement, not exhaustive annotation.

**Too verbose**:
```typst
#definition("Upper Bound")[
  An element $u : A$ is an *upper bound* of a subset $S$...
]
#remark[
  In type theory, "an element $u : A$" means $u$ is a term of type $A$,
  and "a subset $S$" means a predicate $S : A \to \text{Prop}$. The
  definition can be expressed as $\forall s : A, S(s) \to s \leq u$.
]
```

**Appropriate**:
```typst
#definition("Upper Bound")[
  An element $u : A$ is an *upper bound* of $S \subseteq A$ if $s \leq u$
  for all $s \in S$.
]
```

The type-theoretic interpretation is clear from the preface convention; no per-definition remark is needed for standard material.

### Avoid Pure Type-Theoretic Notation in Proofs

Keep proofs in standard mathematical style. The DTT annotations belong in definitions and strategic remarks, not throughout every proof step.

---

## Quality Checklist

When reviewing a chapter for DTT consistency:

- [ ] Introduction acknowledges DTT context (brief)
- [ ] Key definitions use "type $A$" rather than "set $A$"
- [ ] Operations shown with function types where appropriate
- [ ] At least one implementation reference per major section
- [ ] DTT remarks placed strategically, not exhaustively
- [ ] Set notation preserved for proofs and informal discussion
- [ ] No broken cross-references
