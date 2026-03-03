# Modal Logic Naming Conventions

## Overview

This document defines naming conventions for modal and temporal logic constructs in the Logos/Theory LEAN 4 codebase. These conventions ensure consistency and clarity across definitions, theorems, and proofs.

## When to Use

- When naming new theorems, lemmas, or definitions
- When creating axiom schema instances
- When defining semantic structures
- When writing helper functions or tactics

## Prerequisites

- Understanding of modal and temporal logic terminology
- Familiarity with LEAN 4 naming conventions
- Knowledge of the TM proof system structure

## Context Dependencies

- `logic/standards/notation-standards.md` - Notation conventions
- `logic/standards/proof-conventions.md` - Proof style conventions
- `lean4/standards/lean4-style-guide.md` - General LEAN 4 style guide

---

## General Naming Principles

### 1. Descriptive Over Concise

**Principle**: Use descriptive names that convey meaning, even if longer.

```lean
-- Good: Descriptive names
theorem modal_k_distribution (φ ψ : Formula) : ⊢ (□(φ → ψ) → (□φ → □ψ)) := by sorry
theorem temporal_necessitation (φ : Formula) : ⊢ φ → ⊢ Gφ := by sorry

-- Avoid: Cryptic abbreviations
theorem mk_dist (φ ψ : Formula) : ⊢ (□(φ → ψ) → (□φ → □ψ)) := by sorry
theorem tn (φ : Formula) : ⊢ φ → ⊢ Gφ := by sorry
```

### 2. Consistency Across Similar Constructs

**Principle**: Use parallel naming for parallel concepts.

```lean
-- Good: Parallel naming
theorem modal_k_dist (φ ψ : Formula) : ⊢ (□(φ → ψ) → (□φ → □ψ)) := by sorry
theorem temp_k_dist (φ ψ : Formula) : ⊢ (G(φ → ψ) → (Gφ → Gψ)) := by sorry

-- Avoid: Inconsistent naming
theorem modal_k_distribution (φ ψ : Formula) : ⊢ (□(φ → ψ) → (□φ → □ψ)) := by sorry
theorem temporal_k (φ ψ : Formula) : ⊢ (G(φ → ψ) → (Gφ → Gψ)) := by sorry
```

### 3. Domain Prefixes

**Principle**: Use domain prefixes to categorize theorems.

| Prefix | Domain | Example |
|--------|--------|---------|
| `modal_` | Modal logic (□, ◇) | `modal_t`, `modal_4`, `modal_b` |
| `temp_` | Temporal logic (H, G, P, F) | `temp_4`, `temp_a`, `temp_l` |
| `prop_` | Propositional logic | `prop_k`, `prop_s` |
| `perpetuity_` | Perpetuity principles | `perpetuity_1`, `perpetuity_2` |

---

## Axiom Naming

### Axiom Schema Names

**Pattern**: `<domain>_<identifier>` where identifier is a standard abbreviation.

```lean
-- Modal axioms (S5)
| modal_t (φ : Formula) : Axiom (φ.box.imp φ)                    -- T: reflexivity
| modal_4 (φ : Formula) : Axiom (φ.box.imp φ.box.box)            -- 4: transitivity
| modal_b (φ : Formula) : Axiom (φ.imp φ.diamond.box)            -- B: symmetry
| modal_5_collapse (φ : Formula) : Axiom (φ.box.diamond.imp φ.box)  -- 5: collapse

-- Temporal axioms
| temp_4 (φ : Formula) : Axiom (Gφ → GGφ)                        -- T4: temporal transitivity
| temp_a (φ : Formula) : Axiom (φ → GPφ)                         -- TA: temporal connectedness
| temp_l (φ : Formula) : Axiom (△φ → GHφ)                        -- TL: temporal introspection

-- Propositional axioms
| prop_k (φ ψ χ : Formula) : Axiom ((φ → (ψ → χ)) → ((φ → ψ) → (φ → χ)))  -- K: distribution
| prop_s (φ ψ : Formula) : Axiom (φ → (ψ → φ))                   -- S: weakening
| ex_falso (φ : Formula) : Axiom (⊥ → φ)                         -- EFQ: explosion
| peirce (φ ψ : Formula) : Axiom (((φ → ψ) → φ) → φ)             -- Peirce's law
```

### Standard Axiom Abbreviations

| Abbreviation | Full Name | Description |
|--------------|-----------|-------------|
| `t` | T axiom | Reflexivity |
| `4` | 4 axiom | Transitivity |
| `b` | B axiom (Brouwer) | Symmetry |
| `5` | 5 axiom | S5 characteristic |
| `k` | K axiom (Kripke) | Distribution |
| `s` | S axiom | Weakening |
| `a` | A axiom | Temporal connectedness |
| `l` | L axiom | Temporal introspection |

---

## Theorem Naming

### Modal Theorems

**Pattern**: `modal_<property>` or `<operator>_<property>`

```lean
-- Good: Descriptive modal theorem names
theorem modal_k_dist (φ ψ : Formula) : ⊢ (□(φ → ψ) → (□φ → □ψ)) := by sorry
theorem box_and_dist (φ ψ : Formula) : ⊢ (□(φ ∧ ψ) ↔ (□φ ∧ □ψ)) := by sorry
theorem diamond_or_dist (φ ψ : Formula) : ⊢ (◇(φ ∨ ψ) ↔ (◇φ ∨ ◇ψ)) := by sorry
theorem box_diamond_dual (φ : Formula) : ⊢ (□φ ↔ ¬◇¬φ) := by sorry

-- Avoid: Non-descriptive names
theorem thm_42 (φ ψ : Formula) : ⊢ (□(φ → ψ) → (□φ → □ψ)) := by sorry
theorem box_theorem (φ ψ : Formula) : ⊢ (□(φ ∧ ψ) ↔ (□φ ∧ □ψ)) := by sorry
```

### Temporal Theorems

**Pattern**: `temp_<property>` or `<operator>_<property>`

```lean
-- Good: Descriptive temporal theorem names
theorem temp_k_dist (φ ψ : Formula) : ⊢ (G(φ → ψ) → (Gφ → Gψ)) := by sorry
theorem future_and_dist (φ ψ : Formula) : ⊢ (G(φ ∧ ψ) ↔ (Gφ ∧ Gψ)) := by sorry
theorem past_or_dist (φ ψ : Formula) : ⊢ (H(φ ∨ ψ) ↔ (Hφ ∨ Hψ)) := by sorry
theorem always_implies_future (φ : Formula) : ⊢ (△φ → Gφ) := by sorry

-- Avoid: Ambiguous names
theorem future_dist (φ ψ : Formula) : ⊢ (G(φ → ψ) → (Gφ → Gψ)) := by sorry  -- Unclear
theorem temporal_theorem (φ ψ : Formula) : ⊢ (G(φ ∧ ψ) ↔ (Gφ ∧ Gψ)) := by sorry  -- Too generic
```

### Propositional Theorems

**Pattern**: `prop_<property>` or descriptive name

```lean
-- Good: Descriptive propositional theorem names
theorem prop_identity (φ : Formula) : ⊢ (φ → φ) := by sorry
theorem double_negation (φ : Formula) : ⊢ (¬¬φ → φ) := by sorry
theorem modus_ponens_derivable (φ ψ : Formula) : ⊢ φ → ⊢ (φ → ψ) → ⊢ ψ := by sorry
theorem imp_trans (φ ψ χ : Formula) : ⊢ (φ → ψ) → ⊢ (ψ → χ) → ⊢ (φ → χ) := by sorry

-- Avoid: Cryptic names
theorem id (φ : Formula) : ⊢ (φ → φ) := by sorry
theorem dn (φ : Formula) : ⊢ (¬¬φ → φ) := by sorry
```

### Perpetuity Principles

**Pattern**: `perpetuity_<number>` or `perpetuity_<description>`

```lean
-- Good: Numbered perpetuity principles
theorem perpetuity_1 (φ : Formula) : ⊢ (□φ → △φ) := by sorry
theorem perpetuity_2 (φ : Formula) : ⊢ (▽φ → ◇φ) := by sorry
theorem perpetuity_3 (φ : Formula) : ⊢ (□φ → Gφ) := by sorry
theorem perpetuity_4 (φ : Formula) : ⊢ (Fφ → ◇φ) := by sorry
theorem perpetuity_5 (φ : Formula) : ⊢ (□φ → Hφ) := by sorry
theorem perpetuity_6 (φ : Formula) : ⊢ (Pφ → ◇φ) := by sorry

-- Alternative: Descriptive names
theorem necessity_implies_always (φ : Formula) : ⊢ (□φ → △φ) := by sorry
theorem sometimes_implies_possible (φ : Formula) : ⊢ (▽φ → ◇φ) := by sorry
```

---

## Helper Lemma Naming

### Implication Helpers

**Pattern**: `imp_<operation>` or `<operation>_imp`

```lean
-- Good: Descriptive implication helpers
theorem imp_trans (φ ψ χ : Formula) : ⊢ (φ → ψ) → ⊢ (ψ → χ) → ⊢ (φ → χ) := by sorry
theorem combine_imp_conj (φ ψ χ : Formula) : ⊢ (φ → ψ) → ⊢ (φ → χ) → ⊢ (φ → (ψ ∧ χ)) := by sorry
theorem imp_refl (φ : Formula) : ⊢ (φ → φ) := by sorry

-- Avoid: Non-descriptive names
theorem trans (φ ψ χ : Formula) : ⊢ (φ → ψ) → ⊢ (ψ → χ) → ⊢ (φ → χ) := by sorry
theorem combine (φ ψ χ : Formula) : ⊢ (φ → ψ) → ⊢ (φ → χ) → ⊢ (φ → (ψ ∧ χ)) := by sorry
```

### Conjunction/Disjunction Helpers

**Pattern**: `<operator>_<property>`

```lean
-- Good: Descriptive conjunction/disjunction helpers
theorem and_intro (φ ψ : Formula) : ⊢ φ → ⊢ ψ → ⊢ (φ ∧ ψ) := by sorry
theorem and_elim_left (φ ψ : Formula) : ⊢ (φ ∧ ψ) → ⊢ φ := by sorry
theorem and_elim_right (φ ψ : Formula) : ⊢ (φ ∧ ψ) → ⊢ ψ := by sorry
theorem or_intro_left (φ ψ : Formula) : ⊢ φ → ⊢ (φ ∨ ψ) := by sorry
theorem or_intro_right (φ ψ : Formula) : ⊢ ψ → ⊢ (φ ∨ ψ) := by sorry

-- Avoid: Cryptic names
theorem and_i (φ ψ : Formula) : ⊢ φ → ⊢ ψ → ⊢ (φ ∧ ψ) := by sorry
theorem and_e1 (φ ψ : Formula) : ⊢ (φ ∧ ψ) → ⊢ φ := by sorry
theorem and_e2 (φ ψ : Formula) : ⊢ (φ ∧ ψ) → ⊢ ψ := by sorry
```

### Negation Helpers

**Pattern**: `neg_<property>` or `<property>_neg`

```lean
-- Good: Descriptive negation helpers
theorem neg_intro (φ : Formula) : (⊢ φ → ⊢ ⊥) → ⊢ ¬φ := by sorry
theorem neg_elim (φ : Formula) : ⊢ ¬φ → ⊢ φ → ⊢ ⊥ := by sorry
theorem double_neg_intro (φ : Formula) : ⊢ φ → ⊢ ¬¬φ := by sorry
theorem double_neg_elim (φ : Formula) : ⊢ ¬¬φ → ⊢ φ := by sorry

-- Avoid: Ambiguous names
theorem neg_rule (φ : Formula) : (⊢ φ → ⊢ ⊥) → ⊢ ¬φ := by sorry
theorem dn (φ : Formula) : ⊢ ¬¬φ → ⊢ φ := by sorry
```

---

## Semantic Structure Naming

### Frame and Model Names

**Pattern**: `<description>_frame` or `<description>_model`

```lean
-- Good: Descriptive frame/model names
def trivial_frame {T : Type*} [LinearOrderedAddCommGroup T] : TaskFrame T := ...
def identity_frame (W : Type) {T : Type*} [LinearOrderedAddCommGroup T] : TaskFrame T := ...
def nat_frame {T : Type*} [LinearOrderedAddCommGroup T] : TaskFrame T := ...

def example_model (F : TaskFrame T) : TaskModel F := ...
def canonical_model (Γ : MaxConsistentSet) : TaskModel canonical_frame := ...

-- Avoid: Non-descriptive names
def frame1 {T : Type*} [LinearOrderedAddCommGroup T] : TaskFrame T := ...
def my_frame {T : Type*} [LinearOrderedAddCommGroup T] : TaskFrame T := ...
```

### History Names

**Pattern**: `<description>_history`

```lean
-- Good: Descriptive history names
def constant_history (F : TaskFrame T) (w : F.WorldState) : WorldHistory F := ...
def interval_history (F : TaskFrame T) (a b : T) : WorldHistory F := ...
def canonical_history (Γ : MaxConsistentSet) : WorldHistory canonical_frame := ...

-- Avoid: Generic names
def history1 (F : TaskFrame T) : WorldHistory F := ...
def h (F : TaskFrame T) : WorldHistory F := ...
```

---

## Metalogic Naming

### Soundness and Completeness

**Pattern**: `<property>` or `<property>_<variant>`

```lean
-- Good: Standard metalogic names
theorem soundness (Γ : Context) (φ : Formula) : Γ ⊢ φ → Γ ⊨ φ := by sorry
theorem weak_completeness (φ : Formula) : ⊨ φ → ⊢ φ := by sorry
theorem strong_completeness (Γ : Context) (φ : Formula) : Γ ⊨ φ → Γ ⊢ φ := by sorry

-- Avoid: Non-standard names
theorem sound (Γ : Context) (φ : Formula) : Γ ⊢ φ → Γ ⊨ φ := by sorry
theorem complete (φ : Formula) : ⊨ φ → ⊢ φ := by sorry
```

### Deduction Theorem

**Pattern**: `deduction_theorem` or `deduction_theorem_<variant>`

```lean
-- Good: Standard deduction theorem names
theorem deduction_theorem (Γ : Context) (φ ψ : Formula) : (φ :: Γ) ⊢ ψ → Γ ⊢ (φ → ψ) := by sorry
theorem deduction_theorem_converse (Γ : Context) (φ ψ : Formula) : Γ ⊢ (φ → ψ) → (φ :: Γ) ⊢ ψ := by sorry

-- Avoid: Cryptic names
theorem dt (Γ : Context) (φ ψ : Formula) : (φ :: Γ) ⊢ ψ → Γ ⊢ (φ → ψ) := by sorry
theorem ded_thm (Γ : Context) (φ ψ : Formula) : (φ :: Γ) ⊢ ψ → Γ ⊢ (φ → ψ) := by sorry
```

### Consistency and Maximality

**Pattern**: `<property>_<structure>`

```lean
-- Good: Descriptive consistency names
def Consistent (Γ : Context) : Prop := ¬(Γ ⊢ ⊥)
def MaxConsistent (Γ : Context) : Prop := Consistent Γ ∧ ∀ φ, φ ∉ Γ → ¬Consistent (φ :: Γ)

theorem lindenbaum_lemma (Γ : Context) (h : Consistent Γ) : 
  ∃ Δ : Context, Γ ⊆ Δ ∧ MaxConsistent Δ := by sorry

-- Avoid: Abbreviated names
def Cons (Γ : Context) : Prop := ¬(Γ ⊢ ⊥)
def MaxCons (Γ : Context) : Prop := Cons Γ ∧ ∀ φ, φ ∉ Γ → ¬Cons (φ :: Γ)
```

---

## Tactic and Automation Naming

### Custom Tactics

**Pattern**: `<action>_<target>` or `<domain>_<action>`

```lean
-- Good: Descriptive tactic names
syntax "modal_intro" : tactic
syntax "modal_elim" : tactic
syntax "temp_intro" : tactic
syntax "apply_axiom" ident : tactic

-- Avoid: Cryptic tactic names
syntax "mi" : tactic
syntax "me" : tactic
```

### Aesop Rules

**Pattern**: `<domain>_<property>_<direction>`

```lean
-- Good: Descriptive Aesop rule names
@[aesop safe apply]
theorem modal_t_forward (φ : Formula) : ⊢ □φ → ⊢ φ := by sorry

@[aesop safe apply]
theorem modal_4_forward (φ : Formula) : ⊢ □φ → ⊢ □□φ := by sorry

-- Avoid: Non-descriptive names
@[aesop safe apply]
theorem rule1 (φ : Formula) : ⊢ □φ → ⊢ φ := by sorry
```

---

## Variable Naming

### Formula Variables

**Standard Names**: Use Greek letters consistently.

| Variable | Usage | Example |
|----------|-------|---------|
| φ, ψ, χ | Primary formulas | `theorem example (φ ψ : Formula) : ...` |
| p, q, r, s | Atomic propositions | `def p := Formula.atom "p"` |

```lean
-- Good: Standard Greek letters
theorem example (φ ψ χ : Formula) : ⊢ ((φ → ψ) → ((ψ → χ) → (φ → χ))) := by sorry

-- Avoid: Non-standard variable names
theorem example (a b c : Formula) : ⊢ ((a → b) → ((b → c) → (a → c))) := by sorry
theorem example (form1 form2 form3 : Formula) : ... := by sorry
```

### Context Variables

**Standard Names**: Use Greek letters Γ, Δ.

```lean
-- Good: Standard context names
theorem weakening (Γ Δ : Context) (φ : Formula) (h : Γ ⊢ φ) (h_sub : Γ ⊆ Δ) : Δ ⊢ φ := by sorry

-- Avoid: Non-standard context names
theorem weakening (ctx1 ctx2 : Context) (φ : Formula) : ... := by sorry
theorem weakening (c1 c2 : Context) (φ : Formula) : ... := by sorry
```

### Model and Frame Variables

**Standard Names**: Use M, N for models; F for frames; τ, σ for histories.

```lean
-- Good: Standard semantic variable names
theorem soundness (F : TaskFrame T) (M : TaskModel F) (τ : WorldHistory F) 
    (t : T) (ht : t ∈ τ.domain) (φ : Formula) : 
  ⊢ φ → truth_at M τ t ht φ := by sorry

-- Avoid: Non-standard semantic names
theorem soundness (frame : TaskFrame T) (model : TaskModel frame) (hist : WorldHistory frame)
    (time : T) (h : time ∈ hist.domain) (form : Formula) : ... := by sorry
```

---

## Deprecation Naming

### Deprecated Aliases

**Pattern**: Use `@[deprecated new_name (since := "YYYY-MM-DD")]`

```lean
-- Good: Deprecated alias with date
@[deprecated some_past (since := "2025-12-09")]
abbrev sometime_past := some_past

@[deprecated some_future (since := "2025-12-09")]
abbrev sometime_future := some_future

-- Avoid: Deprecated without date or replacement
@[deprecated]
abbrev old_name := new_name
```

---

## Module and Namespace Naming

### Module Names

**Pattern**: PascalCase matching file names

```lean
-- Good: Module names match file structure
namespace Logos.Core.Syntax
namespace Logos.Core.ProofSystem
namespace Logos.Core.Semantics
namespace Logos.Core.Metalogic

-- Avoid: Inconsistent module names
namespace Logos.syntax
namespace Logos.proof_system
```

### Namespace Organization

**Pattern**: Hierarchical namespaces matching directory structure

```lean
-- Good: Hierarchical namespace structure
namespace Logos
  namespace Core
    namespace Syntax
      -- Formula definitions
    end Syntax
    
    namespace ProofSystem
      -- Axioms and derivations
    end ProofSystem
  end Core
end Logos

-- Avoid: Flat namespace structure
namespace LogosSyntax
namespace LogosProofSystem
```

---

## Success Criteria

You've successfully applied these naming conventions when:
- [ ] All axioms use standard abbreviations (t, 4, b, 5, k, s, a, l)
- [ ] All theorems have descriptive names with domain prefixes
- [ ] All helper lemmas follow `<operation>_<property>` pattern
- [ ] All semantic structures use `_frame`, `_model`, `_history` suffixes
- [ ] All formula variables use Greek letters (φ, ψ, χ)
- [ ] All context variables use Γ, Δ
- [ ] All deprecated aliases include date and replacement
- [ ] All module names match file structure

---

## Related Documentation

- **Notation Standards**: `logic/standards/notation-standards.md`
- **Proof Conventions**: `logic/standards/proof-conventions.md`
- **Kripke Semantics**: `logic/standards/kripke-semantics.md`
- **LEAN 4 Style Guide**: `lean4/standards/lean4-style-guide.md`
- **Formula Definitions**: `Logos/Core/Syntax/Formula.lean`
- **Axiom Definitions**: `Logos/Core/ProofSystem/Axioms.lean`
- **Theorem Libraries**: `Logos/Core/Theorems/`
