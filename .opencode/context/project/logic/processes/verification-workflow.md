# Proof Verification Workflow

## Overview

This document describes the proof verification processes used in the Logos/Theory LEAN 4 codebase, including derivability checking, soundness verification, and proof quality assessment.

## When to Use

- When verifying a newly constructed proof
- When checking proof correctness after refactoring
- When validating soundness of the proof system
- When assessing proof quality and readability

## Prerequisites

- Understanding of the TM proof system (modal + temporal logic)
- Familiarity with LEAN 4 type checking and compilation
- Knowledge of soundness and completeness concepts
- Understanding of proof system inference rules

## Context Dependencies

- `logic/processes/proof-construction.md` - Proof construction workflow
- `logic/processes/modal-proof-strategies.md` - Modal proof patterns
- `logic/processes/temporal-proof-strategies.md` - Temporal proof patterns
- `lean4/standards/proof-conventions.md` - Proof style standards

---

## Verification Levels

### Level 1: Syntactic Verification (Type Checking)

**What**: LEAN 4 compiler verifies that the proof type-checks.

**How**: Run `lake build` to compile the proof.

**Checks**:
- Type signatures match
- All tactics succeed
- No `sorry` placeholders (unless documented)
- All imports resolve

**Example**:
```bash
lake build Logos/Core/Theorems/Perpetuity/Principles.lean
```

**Success Criteria**: Zero compilation errors.

---

### Level 2: Semantic Verification (Soundness)

**What**: Verify that the proof system is sound (provable formulas are valid).

**How**: Check that all axioms are semantically valid and inference rules preserve validity.

**Checks**:
- All axioms are valid in the intended semantics
- All inference rules preserve validity
- No circular reasoning in axiom justifications

**Example**: Soundness theorem in `Logos/Core/Metalogic/Soundness.lean`
```lean
theorem soundness {Γ : Context} {φ : Formula} (d : Derivable Γ φ) :
    ∀ (M : TaskModel) (w : M.World) (σ : Assignment M),
      (∀ ψ ∈ Γ, M.satisfies w σ ψ) → M.satisfies w σ φ
```

**Success Criteria**: Soundness theorem proven for all inference rules.

---

### Level 3: Completeness Verification (Optional)

**What**: Verify that the proof system is complete (valid formulas are provable).

**How**: Construct canonical model and prove truth lemma.

**Checks**:
- Canonical model construction is well-defined
- Truth lemma holds for all formulas
- Completeness theorem proven

**Example**: Completeness infrastructure in `Logos/Core/Metalogic/Completeness.lean`

**Success Criteria**: Completeness theorem proven (or documented as future work).

---

### Level 4: Quality Verification (Readability)

**What**: Verify that the proof is readable, maintainable, and follows conventions.

**How**: Manual review against quality checklist.

**Checks**:
- Proof follows component-based methodology
- Variable names are descriptive
- Comments explain strategy
- Helper lemmas are extracted when appropriate
- Proof is concise but clear

**Success Criteria**: Proof passes quality checklist (see below).

---

## Inference Rules Verification

The TM proof system has 7 inference rules. Each must be verified for soundness.

### Rule 1: Assumption

**Rule**: If `φ ∈ Γ`, then `Γ ⊢ φ`

**LEAN Definition**:
```lean
| assumption (Γ : Context) (φ : Formula) (h : φ ∈ Γ) : Derivable Γ φ
```

**Soundness**: If φ is in the context Γ and all formulas in Γ are satisfied, then φ is satisfied.

**Verification**: Trivial - assumptions are satisfied by hypothesis.

---

### Rule 2: Weakening

**Rule**: If `Γ ⊢ φ` and `Γ ⊆ Δ`, then `Δ ⊢ φ`

**LEAN Definition**:
```lean
| weakening (Γ Δ : Context) (φ : Formula) 
    (d : Derivable Γ φ) (h : Γ ⊆ Δ) : Derivable Δ φ
```

**Soundness**: If φ is derivable from Γ and Γ ⊆ Δ, then φ is derivable from Δ (monotonicity).

**Verification**: If all formulas in Γ are satisfied and Γ ⊆ Δ, then all formulas in Γ are satisfied in Δ.

---

### Rule 3: Axiom

**Rule**: For any axiom A, `⊢ A`

**LEAN Definition**:
```lean
| axiom (Γ : Context) (φ : Formula) (a : Axiom φ) : Derivable Γ φ
```

**Soundness**: All axioms must be semantically valid.

**Verification**: Each axiom is verified separately:
- **Propositional axioms** (prop_k, prop_s, prop_efq, prop_peirce): Valid in classical logic
- **Modal axioms** (modal_t, modal_4, modal_b): Valid in S5 (equivalence relation)
- **Temporal axioms** (temp_4, temp_a, temp_l): Valid in linear time
- **Bimodal axioms** (modal_future, temp_future): Valid in task semantics

---

### Rule 4: Modus Ponens

**Rule**: If `Γ ⊢ φ → ψ` and `Γ ⊢ φ`, then `Γ ⊢ ψ`

**LEAN Definition**:
```lean
| modus_ponens (Γ : Context) (φ ψ : Formula)
    (d1 : Derivable Γ (φ.imp ψ)) (d2 : Derivable Γ φ) : Derivable Γ ψ
```

**Soundness**: If `φ → ψ` and φ are both satisfied, then ψ is satisfied.

**Verification**: Standard modus ponens soundness - if φ implies ψ and φ holds, then ψ holds.

---

### Rule 5: Modal K

**Rule**: If `[□Γ] ⊢ φ`, then `Γ ⊢ □φ`

**LEAN Definition**:
```lean
| modal_k (Γ : Context) (φ : Formula)
    (d : Derivable (Γ.map Formula.box) φ) : Derivable Γ φ.box
```

**Soundness**: If φ is derivable from boxed assumptions, then □φ is derivable from unboxed assumptions.

**Verification**: If φ holds in all worlds accessible from w when all assumptions in Γ hold in all worlds, then □φ holds at w when all assumptions in Γ hold at w.

---

### Rule 6: Temporal K

**Rule**: If `[GΓ] ⊢ φ`, then `Γ ⊢ Gφ`

**LEAN Definition**:
```lean
| temp_k (Γ : Context) (φ : Formula)
    (d : Derivable (Γ.map Formula.all_future) φ) : Derivable Γ φ.all_future
```

**Soundness**: If φ is derivable from future assumptions, then Gφ is derivable from present assumptions.

**Verification**: If φ holds at all future times when all assumptions in Γ hold at all future times, then Gφ holds now when all assumptions in Γ hold now.

---

### Rule 7: Temporal Duality

**Rule**: If `⊢ φ`, then `⊢ swap_temporal φ`

**LEAN Definition**:
```lean
| temporal_duality (φ : Formula)
    (d : Derivable [] φ) : Derivable [] φ.swap_temporal
```

**Soundness**: Swapping past and future operators preserves validity in task semantics.

**Verification**: Task semantics has symmetric structure where swapping all_past ↔ all_future preserves validity.

---

## Derivability Checking Workflow

### Step 1: Parse the Proof

**Action**: Understand the proof structure and identify all inference rule applications.

**Questions**:
- Which inference rules are used?
- Are all rule applications valid?
- Are all axioms justified?

---

### Step 2: Check Type Signatures

**Action**: Verify that all type signatures match.

**Checks**:
- Context types match (Γ, Δ)
- Formula types match (φ, ψ)
- Derivability types match (`Derivable Γ φ`)

**Example**:
```lean
-- Check: Does this type-check?
have h : ⊢ φ.box.imp φ.always := perpetuity_1 φ
--       ^^^^^^^^^^^^^^^^^^^^^^^^
--       Type: Derivable [] (φ.box.imp φ.always)
```

---

### Step 3: Verify Axiom Applications

**Action**: Check that all axiom applications are correct.

**Checks**:
- Axiom matches the formula exactly
- Axiom is semantically valid
- Axiom is in the approved axiom list

**Example**:
```lean
-- Verify: Is this axiom application correct?
have mt : ⊢ φ.box.imp φ :=
  Derivable.axiom [] _ (Axiom.modal_t φ)
--                      ^^^^^^^^^^^^^^^^^^
--                      Axiom: MT (□φ → φ) - Valid in S5
```

---

### Step 4: Verify Inference Rule Applications

**Action**: Check that all inference rule applications are valid.

**Checks**:
- Rule premises are satisfied
- Rule conclusion matches the goal
- Rule is sound

**Example**:
```lean
-- Verify: Is this modus ponens application correct?
have h : ⊢ ψ := Derivable.modus_ponens [] φ ψ h1 h2
--              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
--              Premises: h1 : ⊢ φ → ψ, h2 : ⊢ φ
--              Conclusion: ⊢ ψ
--              Valid: Yes (standard modus ponens)
```

---

### Step 5: Check for Circular Reasoning

**Action**: Verify that the proof doesn't use circular reasoning.

**Checks**:
- No theorem uses itself in its proof
- No axiom is justified by a theorem that uses that axiom
- Dependency graph is acyclic

---

### Step 6: Verify Completeness

**Action**: Check that the proof is complete (no `sorry` placeholders).

**Checks**:
- No `sorry` in the proof
- All subgoals are proven
- All helper lemmas are proven

**Exception**: Documented `sorry` placeholders for future work are acceptable if:
- Clearly marked with comments
- Documented in SORRY_REGISTRY.md
- Have a resolution plan

---

## Soundness Verification Workflow

### Step 1: Verify Axiom Soundness

**Action**: Check that all axioms are semantically valid.

**Process**:
1. For each axiom, state the semantic validity claim
2. Prove the claim using the model-theoretic semantics
3. Document the proof in the soundness module

**Example**: Modal T axiom (MT)
```lean
-- Axiom: □φ → φ
-- Semantic claim: If φ holds in all accessible worlds, then φ holds in the current world
-- Proof: By reflexivity of the accessibility relation in S5
```

---

### Step 2: Verify Inference Rule Soundness

**Action**: Check that all inference rules preserve validity.

**Process**:
1. For each rule, state the soundness claim
2. Prove the claim by structural induction on derivations
3. Document the proof in the soundness module

**Example**: Modus ponens soundness
```lean
-- Rule: If Γ ⊢ φ → ψ and Γ ⊢ φ, then Γ ⊢ ψ
-- Soundness: If (φ → ψ) and φ are satisfied, then ψ is satisfied
-- Proof: By definition of implication satisfaction
```

---

### Step 3: Prove Main Soundness Theorem

**Action**: Prove that derivability implies validity.

**Theorem**:
```lean
theorem soundness {Γ : Context} {φ : Formula} (d : Derivable Γ φ) :
    ∀ (M : TaskModel) (w : M.World) (σ : Assignment M),
      (∀ ψ ∈ Γ, M.satisfies w σ ψ) → M.satisfies w σ φ
```

**Proof Strategy**: Structural induction on the derivation `d`, using axiom soundness and rule soundness for each case.

---

## Proof Quality Checklist

### Structural Quality

- [ ] **Decomposition**: Complex goals are decomposed into manageable subgoals
- [ ] **Component-based**: Proof uses component-based methodology
- [ ] **Composition**: Components are composed using helper lemmas
- [ ] **No duplication**: Reusable components are extracted as helper lemmas

### Readability Quality

- [ ] **Comments**: Proof has explanatory comments for each major step
- [ ] **Variable names**: Descriptive names (e.g., `h_past`, `mf`, `ta`)
- [ ] **Formatting**: Consistent indentation and spacing
- [ ] **Structure**: Clear separation between steps

### Correctness Quality

- [ ] **Type-checks**: Proof compiles without errors
- [ ] **No sorry**: All subgoals are proven (or documented)
- [ ] **Axioms justified**: All axiom applications are correct
- [ ] **Rules valid**: All inference rule applications are valid

### Efficiency Quality

- [ ] **Helper lemmas**: Pre-proven helpers are reused
- [ ] **Duality**: Temporal duality is used when appropriate
- [ ] **Conciseness**: Proof is as concise as possible while remaining clear
- [ ] **No redundancy**: No unnecessary steps

---

## Verification Example: P1 Proof

### Proof to Verify

```lean
theorem perpetuity_1 (φ : Formula) : ⊢ φ.box.imp φ.always := by
  have h_past : ⊢ φ.box.imp φ.all_past := box_to_past φ
  have h_present : ⊢ φ.box.imp φ := box_to_present φ
  have h_future : ⊢ φ.box.imp φ.all_future := box_to_future φ
  exact combine_imp_conj_3 h_past h_present h_future
```

### Verification Steps

#### 1. Syntactic Verification
- [YES] Type-checks: `⊢ φ.box.imp φ.always` matches theorem signature
- [YES] No `sorry` placeholders
- [YES] All imports resolve

#### 2. Semantic Verification
- [YES] Helper lemmas are sound:
  - `box_to_past`: Uses temporal duality on `box_to_future` (sound)
  - `box_to_present`: Uses MT axiom (sound in S5)
  - `box_to_future`: Uses MF + MT (both sound)
- [YES] Composition lemma is sound:
  - `combine_imp_conj_3`: Conjunction introduction (sound)

#### 3. Quality Verification
- [YES] Decomposition: Goal decomposed into 3 components (past, present, future)
- [YES] Component-based: Uses pre-proven helper lemmas
- [YES] Comments: Explanatory comment about `always` definition
- [YES] Variable names: Descriptive (`h_past`, `h_present`, `h_future`)
- [YES] Conciseness: 5 lines, clear and readable

#### 4. Completeness Verification
- [YES] All subgoals proven
- [YES] No circular reasoning
- [YES] Dependency graph is acyclic

**Verdict**: [PASS] Proof is verified and meets all quality standards.

---

## Common Verification Issues

### Issue 1: Type Mismatch

**Symptom**: Compilation error about type mismatch.

**Cause**: Formula structure doesn't match expected type.

**Solution**: Check that all formula constructors match exactly.

**Example**:
```lean
-- Error: Type mismatch
have h : ⊢ φ.box.imp φ.always := box_to_future φ
--                                ^^^^^^^^^^^^^^
--                                Expected: φ.box.imp φ.always
--                                Got: φ.box.imp φ.all_future

-- Fix: Use correct helper
have h : ⊢ φ.box.imp φ.always := perpetuity_1 φ
```

---

### Issue 2: Invalid Axiom Application

**Symptom**: Axiom doesn't match the formula.

**Cause**: Wrong axiom selected or formula structure incorrect.

**Solution**: Verify axiom definition matches the goal exactly.

**Example**:
```lean
-- Error: Axiom mismatch
have h : ⊢ φ.box.imp φ.box.box :=
  Derivable.axiom [] _ (Axiom.modal_t φ)
--                      ^^^^^^^^^^^^^^^^^^
--                      Axiom: □φ → φ (not □φ → □□φ)

-- Fix: Use correct axiom
have h : ⊢ φ.box.imp φ.box.box :=
  Derivable.axiom [] _ (Axiom.modal_4 φ)
--                      ^^^^^^^^^^^^^^^^^^
--                      Axiom: □φ → □□φ (correct)
```

---

### Issue 3: Circular Reasoning

**Symptom**: Theorem uses itself in its proof.

**Cause**: Dependency cycle in proof structure.

**Solution**: Restructure proof to break the cycle.

**Example**:
```lean
-- Error: Circular reasoning
theorem identity (φ : Formula) : ⊢ φ.imp φ := by
  have h : ⊢ φ.imp φ := identity φ  -- Uses itself!
  exact h

-- Fix: Prove from axioms
theorem identity (φ : Formula) : ⊢ φ.imp φ := by
  -- SKK combinator construction
  [proper proof from axioms]
```

---

### Issue 4: Undocumented Sorry

**Symptom**: `sorry` placeholder without explanation.

**Cause**: Incomplete proof without documentation.

**Solution**: Either complete the proof or document the `sorry` in SORRY_REGISTRY.md.

**Example**:
```lean
-- Error: Undocumented sorry
theorem example_theorem (φ : Formula) : ⊢ φ.box.imp φ.diamond := by
  sorry  -- No explanation!

-- Fix: Add documentation
theorem example_theorem (φ : Formula) : ⊢ φ.box.imp φ.diamond := by
  -- TODO: Requires modal K axiom for full proof
  -- See SORRY_REGISTRY.md entry #42
  -- Resolution plan: Add modal K axiom in Phase 2
  sorry
```

---

## Success Criteria

You've successfully verified a proof when:
- [ ] Proof compiles without errors (syntactic verification)
- [ ] All axioms and rules are sound (semantic verification)
- [ ] Proof is complete with no undocumented `sorry` (completeness verification)
- [ ] Proof passes quality checklist (quality verification)
- [ ] No circular reasoning detected
- [ ] All helper lemmas are verified

---

## Related Documentation

- **Proof Construction**: `logic/processes/proof-construction.md`
- **Modal Strategies**: `logic/processes/modal-proof-strategies.md`
- **Temporal Strategies**: `logic/processes/temporal-proof-strategies.md`
- **Soundness Module**: `Logos/Core/Metalogic/Soundness.lean`
- **Completeness Module**: `Logos/Core/Metalogic/Completeness.lean`
- **Sorry Registry**: `docs/project-info/SORRY_REGISTRY.md`
