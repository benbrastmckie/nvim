# Modal Proof Strategies (S5 Modal Logic)

## Overview

This document describes six core proof strategies for S5 modal logic in the Logos/Theory LEAN 4 codebase. These strategies demonstrate how to construct proofs involving necessity (□) and possibility (◇) operators using axioms, helper lemmas, and composition patterns.

## When to Use

- When proving theorems involving □ (necessity) and ◇ (possibility) operators
- When working with S5 characteristic axioms (MT, M4, MB)
- When building nested modal operators (□□φ, ◇◇φ, etc.)
- When combining modal and propositional reasoning

## Prerequisites

- Understanding of S5 modal logic semantics (equivalence relation on possible worlds)
- Familiarity with modal axioms:
  - **MT** (reflexivity): `□φ → φ`
  - **M4** (transitivity): `□φ → □□φ`
  - **MB** (symmetry): `φ → □◇φ`
- Knowledge of helper lemmas: `imp_trans`, `identity`, `combine_imp_conj`
- Basic LEAN 4 proof tactics

## Context Dependencies

- `lean4/domain/lean4-syntax.md` - LEAN 4 syntax reference
- `lean4/standards/proof-conventions.md` - Proof style conventions
- `logic/processes/proof-construction.md` - General proof workflow
- `lean4/patterns/tactic-patterns.md` - Tactic usage patterns

---

## Strategy 1: Necessity Chains (M4 Iteration)

### Pattern

Build arbitrarily long necessity chains using the M4 axiom (`□φ → □□φ`). This demonstrates how to compose axiom applications using implication transitivity.

### Core Technique

Use `imp_trans` from Perpetuity.lean to chain M4 applications.

### Example: Two-Step Chain (`□φ → □□□φ`)

```lean
example (φ : Formula) : ⊢ φ.box.imp φ.box.box.box := by
  -- Step 1: First M4 application (□φ → □□φ)
  have h1 : ⊢ φ.box.imp φ.box.box :=
    Derivable.axiom [] _ (Axiom.modal_4 φ)
  
  -- Step 2: Second M4 application (□□φ → □□□φ)
  have h2 : ⊢ φ.box.box.imp φ.box.box.box :=
    Derivable.axiom [] _ (Axiom.modal_4 φ.box)
  
  -- Step 3: Compose using transitivity (□φ → □□φ → □□□φ)
  exact imp_trans h1 h2
```

### Semantic Intuition

If φ is necessary (true in all possible worlds), then it's necessarily necessary, and so on. Each application of M4 adds another layer of necessity, reflecting the transitive structure of the accessibility relation in S5.

### When to Use

- Proving theorems with nested necessity operators
- Building `□□...□φ` from `□φ`
- Demonstrating transitive properties of necessity

### Related Strategies

- **Combined Modal-Propositional Reasoning** (Strategy 6) - For mixing modal and propositional steps
- **S5 Characteristic Theorems** (Strategy 4) - For exploiting S5-specific properties

### Source Reference

`Archive/ModalProofStrategies.lean` lines 74-84

---

## Strategy 2: Possibility Proofs (Definitional Conversions)

### Pattern

Work with possibility `◇φ` defined as `¬□¬φ`. This strategy demonstrates how to convert between necessity and possibility using definitional equality and propositional reasoning.

### Core Technique

Use definitional equality (`rfl`) when formula structure matches exactly, or use propositional reasoning for manipulation.

### Key Definition

```lean
def diamond (φ : Formula) : Formula := neg (Formula.box (neg φ))
-- ◇φ = ¬□¬φ (possibility is dual of necessity)
```

### Example: Definitional Equality

```lean
example (φ : Formula) : φ.diamond = φ.neg.box.neg := rfl
```

### Example: Necessity Implies Possibility (`□φ → ◇φ`)

```lean
example (φ : Formula) : ⊢ φ.box.imp φ.diamond := by
  -- Step 1: MB axiom (φ → □◇φ)
  have h1 : ⊢ φ.imp φ.diamond.box :=
    Derivable.axiom [] _ (Axiom.modal_b φ)
  
  -- Step 2: MT axiom (□◇φ → ◇φ)
  have h2 : ⊢ φ.diamond.box.imp φ.diamond :=
    Derivable.axiom [] _ (Axiom.modal_t φ.diamond)
  
  -- Step 3: Compose (φ → □◇φ → ◇φ)
  have h3 : ⊢ φ.imp φ.diamond := imp_trans h1 h2
  
  -- Step 4: Lift to modal context (requires modal K)
  sorry  -- Full proof requires modal K application + context management
```

### Semantic Intuition

Possibility is the dual of necessity. What's necessary is possible (by reflexivity), and what's possible is not necessarily impossible. The definition `◇φ = ¬□¬φ` captures this duality.

### When to Use

- Converting between □ and ◇ operators
- Proving dual properties (e.g., `□φ → ◇φ`)
- Working with negations of modal formulas

### Related Strategies

- **S5 Characteristic Theorems** (Strategy 4) - For exploiting duality in S5
- **Combined Modal-Propositional Reasoning** (Strategy 6) - For complex negation handling

### Source Reference

`Archive/ModalProofStrategies.lean` lines 144-174

---

## Strategy 3: Modal Modus Ponens (Modal K Rule)

### Pattern

From `□φ` and `□(φ → ψ)`, derive `□ψ`. This is the key rule for distributing necessity over derivations.

### Core Technique

Build derivations in boxed context `[□φ, □ψ, ...]`, then use `Derivable.modal_k` to lift the conclusion to `□φ`.

### Modal K Rule

If `[□Γ] ⊢ φ` then `Γ ⊢ □φ`

This rule allows "boxing" the conclusion when all assumptions are boxed.

### Example: Modal Modus Ponens Pattern

```lean
example (φ ψ : Formula) (h1 : ⊢ φ.box) (h2 : ⊢ (φ.imp ψ).box) : ⊢ ψ.box := by
  -- Step 1: Derive ψ from [φ, φ → ψ] using modus ponens
  have deriv_psi : [φ, φ.imp ψ] ⊢ ψ := by
    apply Derivable.modus_ponens [φ, φ.imp ψ] φ ψ
    · exact Derivable.assumption [φ, φ.imp ψ] (φ.imp ψ) (by simp)
    · exact Derivable.assumption [φ, φ.imp ψ] φ (by simp)
  
  -- Step 2: Apply modal K: [φ, φ → ψ] ⊢ ψ gives [□φ, □(φ → ψ)] ⊢ □ψ
  have boxed : [φ.box, (φ.imp ψ).box] ⊢ ψ.box :=
    Derivable.modal_k [φ, φ.imp ψ] ψ deriv_psi
  
  -- Step 3: Eliminate assumptions using h1 and h2
  sorry  -- Requires assumption elimination via substitution
```

### Semantic Intuition

If `φ → ψ` holds in all possible worlds and φ holds in all possible worlds, then ψ must hold in all possible worlds. This is the modal analog of modus ponens.

### When to Use

- Distributing necessity over implication
- Deriving boxed conclusions from boxed premises
- Building complex modal derivations with multiple assumptions

### Related Strategies

- **Necessity Chains** (Strategy 1) - For building nested necessity
- **Combined Modal-Propositional Reasoning** (Strategy 6) - For context management

### Source Reference

`Archive/ModalProofStrategies.lean` lines 213-233

---

## Strategy 4: S5 Characteristic Theorems

### Pattern

Prove theorems that are specific to S5 modal logic and distinguish it from weaker modal logics like K or T.

### Key S5 Axioms

- **MT** (reflexivity): `□φ → φ` - What's necessary is true
- **M4** (transitivity): `□φ → □□φ` - Necessity is transitive
- **MB** (symmetry): `φ → □◇φ` - Truths are necessarily possible

These three axioms characterize S5 as having an equivalence relation (reflexive, transitive, symmetric) on possible worlds.

### Example: Brouwer B Axiom (`φ → □◇φ`)

```lean
example (φ : Formula) : ⊢ φ.imp φ.diamond.box := by
  -- This is exactly the MB axiom
  exact Derivable.axiom [] _ (Axiom.modal_b φ)
```

### Example: S5 Positive Introspection Iteration

```lean
example (φ : Formula) : ⊢ φ.box.imp φ.box.box.box := by
  -- Compressed version using transitivity
  exact imp_trans
    (Derivable.axiom [] _ (Axiom.modal_4 φ))
    (Derivable.axiom [] _ (Axiom.modal_4 φ.box))
```

### Semantic Intuition

In S5, the accessibility relation is an equivalence relation. This means:
- **Reflexivity (MT)**: Every world can access itself
- **Transitivity (M4)**: If w1 accesses w2 and w2 accesses w3, then w1 accesses w3
- **Symmetry (MB)**: If w1 accesses w2, then w2 accesses w1

These properties make S5 particularly well-suited for reasoning about metaphysical necessity and logical truth.

### When to Use

- Proving S5-specific properties
- Exploiting equivalence relation structure
- Demonstrating characteristic S5 theorems

### Related Strategies

- **Possibility Proofs** (Strategy 2) - For working with duality
- **Necessity Chains** (Strategy 1) - For exploiting transitivity

### Source Reference

`Archive/ModalProofStrategies.lean` lines 265-305

---

## Strategy 5: Identity and Self-Reference

### Pattern

Derive the identity formula `φ → φ` from K and S combinators using the SKK combinator construction.

### Core Technique

SKK combinator construction where:
- **S combinator**: `(φ → ψ → χ) → (φ → ψ) → (φ → χ)` (prop_k axiom)
- **K combinator**: `φ → ψ → φ` (prop_s axiom)
- **Identity**: `I = SKK`

### Example: Identity via Helper

```lean
example (φ : Formula) : ⊢ φ.imp φ := identity φ
```

### Example: Modal Identity

```lean
example (φ : Formula) : ⊢ φ.box.imp φ.box := identity φ.box
```

### Example: Self-Reference in Modal Context (`□(φ → φ)`)

```lean
example (φ : Formula) : ⊢ (φ.imp φ).box := by
  -- Step 1: Get identity
  have h : ⊢ φ.imp φ := identity φ
  
  -- Step 2: Apply modal K with empty context (necessitation)
  exact Derivable.modal_k [] (φ.imp φ) h
```

### Semantic Intuition

The identity formula `φ → φ` is a tautology - it's true in all possible worlds. The necessitation principle states that theorems (provable formulas) are necessary, hence `⊢ φ` implies `⊢ □φ`.

### When to Use

- Building self-referential proofs
- Establishing identity as a foundation for other proofs
- Demonstrating the necessitation principle

### Related Strategies

- **Combined Modal-Propositional Reasoning** (Strategy 6) - For combinator usage
- **S5 Characteristic Theorems** (Strategy 4) - For necessitation patterns

### Source Reference

`Archive/ModalProofStrategies.lean` lines 342-376

---

## Strategy 6: Combined Modal-Propositional Reasoning

### Pattern

Weave modal and propositional axioms together to prove complex theorems that require both types of reasoning.

### Core Technique

Use `imp_trans` to chain modal and propositional implications, and use modal K to lift propositional derivations into modal context.

### Example: Weakening Under Necessity (`□φ → □(ψ → φ)`)

```lean
example (φ ψ : Formula) : ⊢ φ.box.imp (ψ.imp φ).box := by
  -- Step 1: Get propositional S axiom (weakening)
  have prop_s : ⊢ φ.imp (ψ.imp φ) :=
    Derivable.axiom [] _ (Axiom.prop_s φ ψ)
  
  -- Step 2: Derive [φ] ⊢ ψ → φ using prop_s and modus ponens
  have deriv : [φ] ⊢ ψ.imp φ := by
    apply Derivable.modus_ponens [φ] φ (ψ.imp φ)
    · -- Need: [φ] ⊢ φ → (ψ → φ)
      apply Derivable.weakening [] [φ] (φ.imp (ψ.imp φ)) prop_s
      intro x h; simp at h
    · exact Derivable.assumption [φ] φ (by simp)
  
  -- Step 3: Apply modal K to get [□φ] ⊢ □(ψ → φ)
  have boxed : [φ.box] ⊢ (ψ.imp φ).box :=
    Derivable.modal_k [φ] (ψ.imp φ) deriv
  
  -- Step 4: Build the implication (requires deduction theorem)
  sorry  -- Requires deduction theorem for implication introduction
```

### Semantic Intuition

Propositional reasoning holds in all possible worlds, so we can lift propositional theorems into modal context. The modal K rule provides the bridge between propositional and modal reasoning.

### When to Use

- Proving theorems that mix modal and propositional structure
- Lifting propositional reasoning into modal context
- Building complex derivations with multiple axiom types

### Related Strategies

- **Modal Modus Ponens** (Strategy 3) - For modal K rule application
- **Identity and Self-Reference** (Strategy 5) - For combinator usage

### Source Reference

`Archive/ModalProofStrategies.lean` lines 400-427

---

## Summary Table

| Strategy | Core Axiom | Helper Lemma | Primary Use Case |
|----------|-----------|--------------|------------------|
| Necessity Chains | M4 | `imp_trans` | Nested necessity operators |
| Possibility Proofs | MB, MT | Definitional equality | Dual reasoning with ◇ |
| Modal Modus Ponens | Modal K | Context management | Boxed derivations |
| S5 Theorems | MT, M4, MB | Composition | S5-specific properties |
| Identity | prop_k, prop_s | SKK construction | Self-reference, necessitation |
| Combined Reasoning | All axioms | `imp_trans` | Complex mixed proofs |

---

## Key Takeaways

1. **Composition is Key**: Complex modal proofs are built by composing simple axiom applications using `imp_trans` and other helper lemmas.

2. **Duality Matters**: Understanding the relationship between □ and ◇ (via `◇φ = ¬□¬φ`) is essential for many proofs.

3. **Modal K is Central**: The modal K rule is the primary mechanism for lifting propositional reasoning into modal context.

4. **S5 Structure**: The equivalence relation structure of S5 (reflexive, transitive, symmetric) enables powerful reasoning patterns not available in weaker modal logics.

5. **Helper Lemmas**: Pre-proven helper lemmas like `identity`, `imp_trans`, and `combine_imp_conj` significantly simplify proof construction.

---

## Success Criteria

You've successfully applied these strategies when:
- [ ] You can build necessity chains of arbitrary length using M4
- [ ] You can convert between necessity and possibility using definitional equality
- [ ] You can apply the modal K rule to lift derivations
- [ ] You can prove S5-specific theorems using MT, M4, and MB
- [ ] You can construct identity proofs using SKK combinators
- [ ] You can combine modal and propositional reasoning in a single proof

---

## Related Documentation

- **Temporal Proof Strategies**: `logic/processes/temporal-proof-strategies.md`
- **Proof Construction Workflow**: `logic/processes/proof-construction.md`
- **Helper Lemmas Reference**: `Logos/Core/Theorems/Perpetuity/Helpers.lean`
- **Modal Axioms**: `Logos/Core/ProofSystem/Axioms.lean`
- **Archive Examples**: `Archive/ModalProofStrategies.lean`
