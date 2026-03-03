# Bilateral Truthmaker Semantics

> **Scope**: Exact truthmaker semantics (bilateral semantics) as used in the Logos constitutive foundation.
> **Current as of**: 2026-02-21
> **Source**: Research on primary sources (IdentityAboutness.tex, counterfactual_worlds.tex)

## Overview

**Bilateral truthmaker semantics** (also called **exact truthmaker semantics**) is a hyperintensional semantic framework that evaluates sentences relative to states rather than possible worlds. Unlike possible worlds semantics where propositions are sets of worlds, bilateral semantics treats propositions as pairs of **verifier** and **falsifier** state sets.

**Key Innovation**: Verification and falsification are treated as equally fundamental, independent semantic relations. A state that verifies A must be "wholly relevant" to A---it cannot contain irrelevant parts.

### Primary Sources

- **Fine, K. (2016)** - "Angellic Content"
- **Fine, K. (2017)** - "A Theory of Truthmaker Content I & II"
- **Fine, K. (2017a)** - "Truthmaker Semantics"
- **Fine, K. (2017d)** - Modalized state spaces

---

## Core Concepts

### Exact Verification and Falsification

The bilateral framework distinguishes two fundamental semantic relations:

| Relation | Symbol | Notation | Meaning |
|----------|--------|----------|---------|
| Exact Verification | ⊩ | M, s ⊩ A | State s exactly verifies sentence A |
| Exact Falsification | ⊣ | M, s ⊣ A | State s exactly falsifies sentence A |

**Exactness Constraint**: States must be "wholly relevant" to the sentences they verify or falsify. A verifier cannot contain any parts that are irrelevant to the verified sentence.

### Non-Monotonicity

Unlike classical semantics, exact verification is **non-monotonic**: extending a verifier with additional material may lose relevance.

**Example**:
- Let t = the state of Julieta thinking
- Let d = the state of Julieta writing
- t exactly verifies "Julieta is thinking"
- t.d (the fusion of t and d) **fails** to exactly verify "Julieta is thinking" because d is irrelevant
- But t.d exactly verifies "Julieta is thinking and writing"

### Inclusive Semantics (Semantic Clauses)

The **inclusive** (or **convex**) semantics extends exact verification to allow fusions of verifiers to count as verifiers. This is the standard interpretation used in Logos.

| Connective | Verification | Falsification |
|------------|--------------|---------------|
| Atomic p | s ∈ |p|⁺ | s ∈ |p|⁻ |
| Negation ¬A | M, s ⊣ A | M, s ⊩ A |
| Conjunction A ∧ B | s = t.d where t ⊩ A and d ⊩ B | s ⊣ A or s ⊣ B or s ⊣ A ∨ B |
| Disjunction A ∨ B | s ⊩ A or s ⊩ B or s ⊩ A ∧ B | s = t.d where t ⊣ A and d ⊣ B |

**Key Features**:
- Negation swaps verification and falsification
- Conjunction verification requires fusion of component verifiers
- Disjunction falsification requires fusion of component falsifiers
- The inclusive semantics allows conjunctions to verify disjunctions (convexity)

---

## State Space Structure

### Definition

A **state space** S = ⟨S, ⊑⟩ is a complete lattice where:
- S is the set of **states**
- ⊑ is the **parthood relation** (a partial order)

### Key Elements

| Element | Symbol | Definition | Properties |
|---------|--------|------------|------------|
| Parthood | ⊑ | Primitive partial order | Reflexive, antisymmetric, transitive |
| Fusion | ⨆ X | Least upper bound of X | Unique for any X ⊆ S |
| Binary fusion | s.t | ⨆{s, t} | Commutative, associative |
| Null state | □ | ⨆ ∅ | Bottom element (fusion of empty set) |
| Full state | ∙ | ⨆ S | Top element (fusion of all states) |

### Modalized State Spaces

A **modalized state space** extends state spaces with possibility:

S^◇ = ⟨S, P, ⊑⟩

where:
- P ⊆ S is the set of **possible states**
- **Nonempty**: P ≠ ∅
- **Possibility Downward Closure**: If s ∈ P and t ⊑ s, then t ∈ P

### World States

**World states** are maximal compatible possible states:

W = {w ∈ P | ∀ s ∘ w (s ⊑ w)}

A state w is a world state iff every state compatible with w is already part of w.

### Proposition Structure

**Normal Contents**: Sets closed under fusion:
C_S = {X ⊆ S : ⨆ Y ∈ X for all nonempty Y ⊆ X}

**Normal Propositions**: Pairs of normal contents:
P_S = {⟨V, F⟩ : V, F ∈ C_S}

**Bilateral Propositions**: Normal propositions with additional constraints:
- **Exclusive**: States in V are incompatible with states in F
- **Exhaustive**: Every possible state is compatible with some state in V or F

---

## Hyperintensionality

### Definition

A theory is **hyperintensional** if it distinguishes propositions that are necessarily equivalent but differ in some other respect (e.g., subject-matter, relevance).

### Motivating Examples

1. **A vs. A ∨ (A ∧ B)**: Same modal profile, different subject-matter
2. **A ∨ ¬A vs. B ∨ ¬B**: Both necessary, different subject-matters
3. **"Hesperus is rising" vs. "Phosphorus is rising"**: Objectively the same, but may differ representationally

### Rejected Boolean Identities

The following classical Boolean identities **fail** in bilateral semantics due to subject-matter differences:

| Principle | Rejected Form | Reason |
|-----------|---------------|--------|
| #Necs | (A ∨ ¬A) ≡ (B ∨ ¬B) | Different subject-matters |
| #Imps | (A ∧ ¬A) ≡ (B ∧ ¬B) | Different impossible states |
| #Abs1 | A ≡ A ∨ (A ∧ B) | Different relevance relations |
| #Abs2 | A ≡ A ∧ (A ∨ B) | Different relevance relations |
| #Dist1 | A ∨ (B ∧ C) ≡ (A ∨ B) ∧ (A ∨ C) | Distribution fails for subject-matter |
| #Dist2 | A ∧ (B ∨ C) ≡ (A ∧ B) ∨ (A ∧ C) | Distribution fails for subject-matter |

### Propositional Identity

In bilateral semantics, **propositional identity** (A ≡ B) holds iff A and B have the same verifiers and the same falsifiers:

A ≡ B ⟺ A⁺ = B⁺ and A⁻ = B⁻

This is a finer-grained notion than necessary equivalence (□(A ↔ B)).

---

## Logic of Ground

### Two Orderings on Propositions

The bilateral framework supports two fundamental partial orderings on propositions, which can come apart (unlike in Boolean logic where they are converses):

#### 1. Conjunctive-Parthood (Essence)

A ⊑ B ≔ A ∧ B ≡ B

**Semantic characterization**:
- For every b ∈ B⁺ there is a ∈ A⁺ with a ⊑ b
- A⁻ ⊆ B⁻

**Intuition**: A is an "essential part" of B---B is constructed by conjoining A with other content.

#### 2. Disjunctive-Parthood (Ground)

A ≤ B ≔ A ∨ B ≡ B

**Semantic characterization**:
- For every b ∈ B⁻ there is a ∈ A⁻ with a ⊑ b
- A⁺ ⊆ B⁺

**Intuition**: A "grounds" B---B's truth is ensured by A's truth.

### Separation from Boolean Logic

In Boolean theories, these orderings are converses: A ⊑ B ⟺ B ≤ A.

In bilateral semantics, they can separate:
- A ⊑ A ∧ B is valid, but A ∧ B ≤ A may fail
- A ≤ A ∨ B is valid, but A ∨ B ⊑ A may fail

### Bilattice Structure

The space of normal propositions P_S forms a **non-interlaced bilattice**:

- **Two orderings**: essence (⊑) and ground (≤)
- Each ordering forms a complete lattice
- Negation exchanges the orderings: P ⊑ Q ⟺ ¬P ≤ ¬Q

This bilattice structure provides hyperintensional analogues of Boolean lattice operations.

### Valid Weakenings of Distribution

While distribution fails as an identity (≡), weaker forms hold as parthood relations:

| Principle | Form | Interpretation |
|-----------|------|----------------|
| A11 | A ∨ (B ∧ C) ≤ (A ∨ B) ∧ (A ∨ C) | Ground-parthood |
| A12 | A ∨ (B ∧ C) ⊑ (A ∨ B) ∧ (A ∨ C) | Essence-parthood |
| A13 | A ∧ (B ∨ C) ≤ (A ∧ B) ∨ (A ∧ C) | Ground-parthood |
| A14 | A ∧ (B ∨ C) ⊑ (A ∧ B) ∨ (A ∧ C) | Essence-parthood |

---

## Relationship to Possible Worlds Semantics

### Key Distinctions

| Aspect | Possible Worlds | Bilateral Semantics |
|--------|-----------------|---------------------|
| Basic entities | Possible worlds (points) | States (structured, with parts) |
| Propositions | Sets of worlds | Pairs of verifier/falsifier sets |
| Truth at world | w ∈ |A| | ∃ s ⊑ w : s ⊩ A |
| Falsity at world | w ∉ |A| | ∃ s ⊑ w : s ⊣ A |
| Hyperintensional | No | Yes |
| Subject-matter | Lost | Preserved |

### Deriving Worlds from States

In the Logos approach (counterfactual_worlds.tex), possible worlds are **constructed** from the state space:

1. **States** form a complete lattice ⟨S, ⊑⟩
2. **Task relation** s → t encodes possible transitions
3. **Possible states** are defined via connectivity: P = {s ∈ S | ∃ t(s ∼ t)}
4. **World states** are maximal compatible possible states: W = {w ∈ P | ∀ s ∘ w (s ⊑ w)}
5. **World histories** are functions α: T → W respecting the task relation: α(x) → α(x+1)

### Truth at World-Time Pairs

A sentence is **true at a world-time pair** (w, t) iff there exists a part of the world state at that time which exactly verifies the sentence:

w, t ⊨ A ⟺ ∃ s ⊑ w_t : s ⊩ A

**See also**: [task-semantics.md](task-semantics.md) for the full temporal semantics.

### Recovering Modal Logic

Standard modal operators can be defined:
- □A is true at w iff A is true at all accessible worlds
- ◇A is true at w iff A is true at some accessible world

The bilateral framework enriches this by preserving subject-matter information that possible worlds semantics loses.

---

## Notation Conventions

| Symbol | Meaning | LaTeX |
|--------|---------|-------|
| ⊑ | Parthood (states) or essence-parthood (propositions) | `\sqsubseteq` |
| ⨆ | Fusion (least upper bound) | `\bigsqcup` |
| ⊩ | Exact verification | `\Vdash` |
| ⊣ | Exact falsification | `\dashV` |
| □ | Null state | `\square` |
| ∙ | Full state | `\sqbullet` |
| ≡ | Propositional identity | `\equiv` |
| ≤ | Disjunctive-parthood (ground) | `\leq` |
| ∘ | Overlap/compatibility | `\circ` |
| . | Binary fusion | dot notation |

---

## Key References

### Primary Sources (Fine)

1. **Fine, K. (2016)** - "Angellic Content" - State semantics for analytic equivalence
2. **Fine, K. (2017)** - "A Theory of Truthmaker Content I" - Normal propositions
3. **Fine, K. (2017)** - "A Theory of Truthmaker Content II" - Bilattice structure
4. **Fine, K. (2017a)** - "Truthmaker Semantics" - Modalized state spaces
5. **Fine, K. (2012a, 2012b)** - Imposition semantics for counterfactuals

### Bilattice Theory

6. **Ginsberg, M. (1988, 1990)** - Bilattice foundations
7. **Fitting, M. (1989-2002)** - Distributive bilattice studies

### Logos Implementation

8. `latex/logos/constitutive.tex` - Constitutive chapter
9. IdentityAboutness.tex - Subject-matter and hyperintensionality paper
10. counterfactual_worlds.tex - Task-based construction of worlds

---

## Related Files

- [bilateral-propositions.md](bilateral-propositions.md) - Basic bilateral proposition structure
- [counterfactual-semantics.md](counterfactual-semantics.md) - Imposition and counterfactual evaluation
- `latex/logos/constitutive.tex` - Logos constitutive chapter
