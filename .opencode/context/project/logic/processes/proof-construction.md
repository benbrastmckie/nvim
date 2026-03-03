# Proof Construction Workflow

## Overview

This document describes the standard workflow for constructing proofs in the Logos/Theory LEAN 4 codebase, with emphasis on the **component-based methodology** used throughout the modal, temporal, and bimodal logic proof libraries.

## When to Use

- When starting a new proof in the Logos/Theory codebase
- When refactoring an existing proof for clarity
- When teaching proof construction techniques
- When planning complex multi-step proofs

## Prerequisites

- Understanding of the target logic (modal, temporal, or bimodal)
- Familiarity with relevant axioms and helper lemmas
- Knowledge of LEAN 4 proof tactics
- Understanding of proof composition patterns

## Context Dependencies

- `lean4/processes/end-to-end-proof-workflow.md` - General LEAN 4 workflow
- `logic/processes/modal-proof-strategies.md` - Modal proof patterns
- `logic/processes/temporal-proof-strategies.md` - Temporal proof patterns
- `lean4/standards/proof-conventions.md` - Proof style standards

---

## The Component-Based Methodology

### Core Principle

**Complex proofs are built from simple components**. The Logos/Theory codebase demonstrates this principle consistently across 25+ examples.

### Three-Layer Architecture

1. **Axioms** (Foundation layer)
   - MT, M4, MB (modal)
   - T4, TA, TL (temporal)
   - MF, TF (bimodal)
   - prop_k, prop_s (propositional)

2. **Helper Lemmas** (Composition layer)
   - `imp_trans`: Implication transitivity
   - `combine_imp_conj`: Conjunction assembly
   - `identity`: Identity combinator
   - `box_to_future`, `box_to_past`, `box_to_present`: Component extractors

3. **Composition Patterns** (Assembly layer)
   - Chaining: Sequential axiom application
   - Assembly: Combining multiple components
   - Duality: Transforming theorems via symmetry
   - Contraposition: Negation-based transformation

---

## Standard 5-Step Workflow

### Step 1: Analyze Goal

**Action**: Understand the structure of the theorem to prove.

**Questions to Ask**:
- What is the main connective? (→, ∧, ∨, ¬, □, ◇, G, H, △, ▽)
- Can the goal be decomposed into simpler subgoals?
- What axioms are relevant to this structure?
- Are there similar theorems already proven?

**Example**: For goal `□φ → △φ` (P1):
- Main connective: `→` (implication)
- Right side: `△φ = Hφ ∧ (φ ∧ Gφ)` (conjunction of 3 components)
- Relevant axioms: MF, TF, MT (for extracting components from □φ)
- Similar theorem: None (this is a fundamental principle)

**Output**: Clear understanding of goal structure and potential decomposition.

---

### Step 2: Decompose into Subgoals

**Action**: Break the complex goal into manageable components.

**Decomposition Strategies**:

1. **Conjunction Decomposition**: `A ∧ B` → prove `A` and `B` separately
2. **Implication Chaining**: `A → C` → find intermediate `B` such that `A → B` and `B → C`
3. **Definitional Expansion**: Expand defined operators (◇, F, P, △, ▽)
4. **Structural Recursion**: Break nested operators into layers

**Example**: For `□φ → △φ`:
```
Goal: □φ → △φ
Expand: □φ → Hφ ∧ (φ ∧ Gφ)
Decompose into 3 subgoals:
  1. □φ → Hφ (past component)
  2. □φ → φ (present component)
  3. □φ → Gφ (future component)
```

**Output**: List of subgoals that are simpler than the original goal.

---

### Step 3: Build Components

**Action**: Prove each subgoal separately using axioms and helper lemmas.

**Component Construction Techniques**:

#### Technique 1: Direct Axiom Application

When a subgoal matches an axiom exactly, apply it directly.

```lean
-- Subgoal: □φ → φ
have h_present : ⊢ φ.box.imp φ := 
  Derivable.axiom [] _ (Axiom.modal_t φ)  -- MT axiom
```

#### Technique 2: Axiom + Transitivity

When a subgoal requires chaining multiple axioms.

```lean
-- Subgoal: □φ → Gφ
have h_future : ⊢ φ.box.imp φ.all_future := by
  -- Step 1: MF gives □φ → □Gφ
  have mf : ⊢ φ.box.imp (φ.all_future.box) :=
    Derivable.axiom [] _ (Axiom.modal_future φ)
  -- Step 2: MT gives □Gφ → Gφ
  have mt : ⊢ (φ.all_future.box).imp φ.all_future :=
    Derivable.axiom [] _ (Axiom.modal_t φ.all_future)
  -- Step 3: Chain via imp_trans
  exact imp_trans mf mt
```

#### Technique 3: Temporal Duality

When a subgoal is the dual of a known theorem.

```lean
-- Subgoal: □φ → Hφ
have h_past : ⊢ φ.box.imp φ.all_past := by
  -- Step 1: Apply box_to_future to swap_temporal φ
  have h1 : ⊢ φ.swap_temporal.box.imp φ.swap_temporal.all_future :=
    box_to_future φ.swap_temporal
  -- Step 2: Apply temporal duality
  have h2 : ⊢ (φ.swap_temporal.box.imp φ.swap_temporal.all_future).swap_temporal :=
    Derivable.temporal_duality _ h1
  -- Step 3: Simplify using involution
  simp only [Formula.swap_temporal, Formula.swap_temporal_involution] at h2
  exact h2
```

#### Technique 4: Helper Lemma Reuse

When a subgoal matches a pre-proven helper lemma.

```lean
-- Subgoal: □φ → Gφ
have h_future : ⊢ φ.box.imp φ.all_future := box_to_future φ
```

**Output**: Proven subgoals (components) ready for composition.

---

### Step 4: Compose Components

**Action**: Combine the proven components to construct the final proof.

**Composition Techniques**:

#### Technique 1: Implication Chaining (`imp_trans`)

Chain two implications `A → B` and `B → C` to get `A → C`.

```lean
-- Chain: □φ → □Gφ → Gφ
exact imp_trans mf mt
```

#### Technique 2: Conjunction Assembly (`combine_imp_conj`)

Combine `P → A` and `P → B` to get `P → A ∧ B`.

```lean
-- Combine: □φ → □Gφ and □φ → G□φ to get □φ → □Gφ ∧ G□φ
exact combine_imp_conj mf tf
```

#### Technique 3: Three-Way Conjunction (`combine_imp_conj_3`)

Combine `P → A`, `P → B`, `P → C` to get `P → A ∧ (B ∧ C)`.

```lean
-- Combine: □φ → Hφ, □φ → φ, □φ → Gφ to get □φ → Hφ ∧ (φ ∧ Gφ)
exact combine_imp_conj_3 h_past h_present h_future
```

#### Technique 4: Nested Composition

Compose compositions for complex structures.

```lean
-- Build: □φ → □Gφ → □(GGφ) → □(GGGφ)
exact imp_trans (imp_trans h1 h2) h3
```

**Output**: Complete proof of the original goal.

---

### Step 5: Verify and Refactor

**Action**: Check the proof is correct and improve readability.

**Verification Checklist**:
- [ ] Proof compiles without errors
- [ ] All `sorry` placeholders removed
- [ ] Type signatures are correct
- [ ] Proof follows the intended strategy

**Refactoring Guidelines**:
1. **Extract helper lemmas**: If a component is reused, make it a separate lemma
2. **Add comments**: Explain each step's purpose
3. **Use descriptive names**: `h_past`, `h_present`, `h_future` instead of `h1`, `h2`, `h3`
4. **Simplify chains**: Use helper lemmas to reduce nesting

**Example Refactoring**:

Before:
```lean
theorem perpetuity_1 (φ : Formula) : ⊢ φ.box.imp φ.always := by
  have h1 : ⊢ φ.box.imp φ.all_past := by sorry
  have h2 : ⊢ φ.box.imp φ := Derivable.axiom [] _ (Axiom.modal_t φ)
  have h3 : ⊢ φ.box.imp φ.all_future := by sorry
  exact combine_imp_conj_3 h1 h2 h3
```

After:
```lean
theorem perpetuity_1 (φ : Formula) : ⊢ φ.box.imp φ.always := by
  -- always φ = φ.all_past.and (φ.and φ.all_future) = Hφ ∧ (φ ∧ Gφ)
  have h_past : ⊢ φ.box.imp φ.all_past := box_to_past φ
  have h_present : ⊢ φ.box.imp φ := box_to_present φ
  have h_future : ⊢ φ.box.imp φ.all_future := box_to_future φ
  exact combine_imp_conj_3 h_past h_present h_future
```

**Output**: Clean, readable, verified proof.

---

## Detailed Case Study: P1 Proof Construction

### Goal

Prove `□φ → △φ` (Perpetuity Principle 1: Necessary implies always)

### Step 1: Analyze Goal

```
Goal: □φ → △φ
Structure: Implication with modal left side, temporal right side
Right side expansion: △φ = Hφ ∧ (φ ∧ Gφ)
Relevant axioms: MF (□φ → □Gφ), TF (□φ → G□φ), MT (□φ → φ)
Strategy: Decompose △φ into 3 components, prove each from □φ
```

### Step 2: Decompose into Subgoals

```
Main goal: □φ → △φ
Expand: □φ → Hφ ∧ (φ ∧ Gφ)

Subgoal 1 (past): □φ → Hφ
Subgoal 2 (present): □φ → φ
Subgoal 3 (future): □φ → Gφ
```

### Step 3: Build Components

#### Component 1: Past (`□φ → Hφ`)

```lean
-- Strategy: Use temporal duality on box_to_future
have h_past : ⊢ φ.box.imp φ.all_past := by
  -- Apply box_to_future to swap_temporal φ
  have h1 : ⊢ φ.swap_temporal.box.imp φ.swap_temporal.all_future :=
    box_to_future φ.swap_temporal
  -- Apply temporal duality to swap G → H
  have h2 : ⊢ (φ.swap_temporal.box.imp φ.swap_temporal.all_future).swap_temporal :=
    Derivable.temporal_duality _ h1
  -- Simplify using involution
  simp only [Formula.swap_temporal, Formula.swap_temporal_involution] at h2
  exact h2
```

Or using the pre-proven helper:
```lean
have h_past : ⊢ φ.box.imp φ.all_past := box_to_past φ
```

#### Component 2: Present (`□φ → φ`)

```lean
-- Strategy: Direct MT axiom application
have h_present : ⊢ φ.box.imp φ := 
  Derivable.axiom [] _ (Axiom.modal_t φ)
```

Or using the helper:
```lean
have h_present : ⊢ φ.box.imp φ := box_to_present φ
```

#### Component 3: Future (`□φ → Gφ`)

```lean
-- Strategy: MF + MT chaining
have h_future : ⊢ φ.box.imp φ.all_future := by
  -- MF: □φ → □Gφ
  have mf : ⊢ φ.box.imp (φ.all_future.box) :=
    Derivable.axiom [] _ (Axiom.modal_future φ)
  -- MT: □Gφ → Gφ
  have mt : ⊢ (φ.all_future.box).imp φ.all_future :=
    Derivable.axiom [] _ (Axiom.modal_t φ.all_future)
  -- Chain: □φ → □Gφ → Gφ
  exact imp_trans mf mt
```

Or using the helper:
```lean
have h_future : ⊢ φ.box.imp φ.all_future := box_to_future φ
```

### Step 4: Compose Components

```lean
-- Combine all three components using combine_imp_conj_3
-- This gives: □φ → Hφ ∧ (φ ∧ Gφ) which is □φ → △φ
exact combine_imp_conj_3 h_past h_present h_future
```

### Step 5: Verify and Refactor

Final proof:
```lean
theorem perpetuity_1 (φ : Formula) : ⊢ φ.box.imp φ.always := by
  -- always φ = φ.all_past.and (φ.and φ.all_future) = Hφ ∧ (φ ∧ Gφ)
  have h_past : ⊢ φ.box.imp φ.all_past := box_to_past φ
  have h_present : ⊢ φ.box.imp φ := box_to_present φ
  have h_future : ⊢ φ.box.imp φ.all_future := box_to_future φ
  exact combine_imp_conj_3 h_past h_present h_future
```

**Verification**:
- [YES] Compiles without errors
- [YES] No `sorry` placeholders
- [YES] Type signatures correct
- [YES] Clear component structure
- [YES] Descriptive variable names
- [YES] Explanatory comment

---

## Common Composition Patterns

### Pattern 1: Sequential Chaining

**Use Case**: Building `A → C` from `A → B` and `B → C`

**Template**:
```lean
have h1 : ⊢ A.imp B := [proof of A → B]
have h2 : ⊢ B.imp C := [proof of B → C]
exact imp_trans h1 h2
```

**Example**: `□φ → □Gφ → Gφ`

---

### Pattern 2: Parallel Assembly

**Use Case**: Building `P → A ∧ B` from `P → A` and `P → B`

**Template**:
```lean
have h1 : ⊢ P.imp A := [proof of P → A]
have h2 : ⊢ P.imp B := [proof of P → B]
exact combine_imp_conj h1 h2
```

**Example**: `□φ → □Gφ ∧ G□φ`

---

### Pattern 3: Three-Way Assembly

**Use Case**: Building `P → A ∧ (B ∧ C)` from `P → A`, `P → B`, `P → C`

**Template**:
```lean
have h1 : ⊢ P.imp A := [proof of P → A]
have h2 : ⊢ P.imp B := [proof of P → B]
have h3 : ⊢ P.imp C := [proof of P → C]
exact combine_imp_conj_3 h1 h2 h3
```

**Example**: `□φ → Hφ ∧ (φ ∧ Gφ)` (P1)

---

### Pattern 4: Iterative Chaining

**Use Case**: Building long chains `A → B → C → D → E`

**Template**:
```lean
have h1 : ⊢ A.imp B := [axiom or lemma]
have h2 : ⊢ B.imp C := [axiom or lemma]
have h3 : ⊢ C.imp D := [axiom or lemma]
have h4 : ⊢ D.imp E := [axiom or lemma]
exact imp_trans (imp_trans (imp_trans h1 h2) h3) h4
```

**Example**: `□φ → □Gφ → □(GGφ) → □(GGGφ)`

---

### Pattern 5: Duality Transformation

**Use Case**: Deriving past theorem from future theorem

**Template**:
```lean
-- Prove future version for swap_temporal φ
have h_future : ⊢ φ.swap_temporal.[future_formula] := [proof]
-- Apply temporal duality
have h_dual : ⊢ (φ.swap_temporal.[future_formula]).swap_temporal :=
  Derivable.temporal_duality _ h_future
-- Simplify using involution
simp only [Formula.swap_temporal, Formula.swap_temporal_involution] at h_dual
exact h_dual
```

**Example**: `Hφ → HHφ` from `Gφ → GGφ`

---

## Axiom Application Patterns

### Pattern 1: Direct Application

When goal matches axiom exactly.

```lean
example (φ : Formula) : ⊢ φ.box.imp φ := by
  exact Derivable.axiom [] _ (Axiom.modal_t φ)
```

---

### Pattern 2: Axiom + Transitivity

When goal requires chaining axioms.

```lean
example (φ : Formula) : ⊢ φ.box.imp φ.box.box.box := by
  exact imp_trans
    (Derivable.axiom [] _ (Axiom.modal_4 φ))
    (Derivable.axiom [] _ (Axiom.modal_4 φ.box))
```

---

### Pattern 3: Axiom + Duality

When goal is dual of an axiom.

```lean
example (φ : Formula) : ⊢ φ.all_past.imp φ.all_past.all_past := by
  have h : ⊢ φ.swap_temporal.all_future.imp φ.swap_temporal.all_future.all_future :=
    Derivable.axiom [] _ (Axiom.temp_4 φ.swap_temporal)
  have h2 : ⊢ (φ.swap_temporal.all_future.imp φ.swap_temporal.all_future.all_future).swap_temporal :=
    Derivable.temporal_duality _ h
  simp [Formula.swap_temporal] at h2
  exact h2
```

---

### Pattern 4: Axiom + Modal K

When goal requires lifting to modal context.

```lean
example (φ : Formula) : ⊢ (φ.imp φ).box := by
  have h : ⊢ φ.imp φ := identity φ
  exact Derivable.modal_k [] (φ.imp φ) h
```

---

### Pattern 5: Multiple Axiom Composition

When goal requires combining multiple axioms.

```lean
example (φ : Formula) : ⊢ φ.box.imp φ.diamond := by
  have mt : ⊢ φ.box.imp φ := Derivable.axiom [] _ (Axiom.modal_t φ)
  have mb : ⊢ φ.imp φ.diamond.box := Derivable.axiom [] _ (Axiom.modal_b φ)
  have mt2 : ⊢ φ.diamond.box.imp φ.diamond := Derivable.axiom [] _ (Axiom.modal_t φ.diamond)
  exact imp_trans mt (imp_trans mb mt2)
```

---

## Success Criteria

You've successfully applied this workflow when:
- [ ] You can decompose complex goals into manageable subgoals
- [ ] You can identify which axioms and helper lemmas are relevant
- [ ] You can build components using axiom applications and chaining
- [ ] You can compose components using `imp_trans`, `combine_imp_conj`, etc.
- [ ] You can verify and refactor proofs for clarity
- [ ] Your proofs follow the component-based methodology

---

## Common Pitfalls and Solutions

### Pitfall 1: Trying to Prove Everything at Once

**Problem**: Attempting to prove complex goals in a single step.

**Solution**: Always decompose first. Break the goal into the smallest possible components.

---

### Pitfall 2: Not Recognizing Helper Lemmas

**Problem**: Re-proving components that already exist as helper lemmas.

**Solution**: Check `Logos/Core/Theorems/Perpetuity/Helpers.lean` for pre-proven components.

---

### Pitfall 3: Forgetting Temporal Duality

**Problem**: Proving past theorems from scratch when future versions exist.

**Solution**: Always check if the dual theorem exists. Use `swap_temporal` and `temporal_duality`.

---

### Pitfall 4: Poor Variable Naming

**Problem**: Using `h1`, `h2`, `h3` for all intermediate results.

**Solution**: Use descriptive names like `h_past`, `h_present`, `h_future` or `mf`, `mt`, `ta`.

---

### Pitfall 5: Missing Comments

**Problem**: Proofs without explanatory comments are hard to understand.

**Solution**: Add comments explaining each step's purpose and the overall strategy.

---

## Related Documentation

- **Modal Proof Strategies**: `logic/processes/modal-proof-strategies.md`
- **Temporal Proof Strategies**: `logic/processes/temporal-proof-strategies.md`
- **Verification Workflow**: `logic/processes/verification-workflow.md`
- **Helper Lemmas**: `Logos/Core/Theorems/Perpetuity/Helpers.lean`
- **LEAN 4 Workflow**: `lean4/processes/end-to-end-proof-workflow.md`
