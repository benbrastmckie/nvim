# LEAN 4 Tactic Development Patterns - Quick Reference

**Source:** `docs/project-info/TACTIC_DEVELOPMENT.md`  
**Purpose:** Essential patterns for implementing custom tactics in Logos TM logic

## 1. Tactic Development Approaches

### Decision Tree: Which Approach to Use?

```
Is the tactic a simple sequence of existing tactics?
├─ YES → Use macro-based approach (Pattern 1)
└─ NO → Does it need pattern matching on goal structure?
    ├─ YES → Use elab_rules (Pattern 2) [YES] RECOMMENDED
    └─ NO → Does it need iteration/search?
        ├─ YES → Use direct TacticM (Pattern 3)
        └─ NO → Use macro-based approach (Pattern 1)
```

### Pattern 1: Macro-Based Tactics (Simple Sequences)

**Use when:** Tactic is a fixed sequence of existing tactics

```lean
-- Example: apply_axiom - delegates to axiom application
macro "apply_axiom" ax:ident : tactic =>
  `(tactic| apply Derivable.axiom; apply $ax)

-- Example: modal_t - applies specific axiom
macro "modal_t" : tactic =>
  `(tactic| apply Derivable.axiom; apply Axiom.modal_t)
```

**Pros:** Simple, declarative, easy to maintain  
**Cons:** No custom logic, no pattern matching

### Pattern 2: elab_rules (Pattern-Matched Tactics) [YES] RECOMMENDED

**Use when:** Need to match goal structure and construct proof terms

```lean
import Lean.Elab.Tactic
open Lean Elab Tactic Meta

/-- Apply modal axiom MT: `□φ → φ` -/
elab_rules : tactic
  | `(tactic| modal_t) => do
    -- STEP 1: Get goal and its type
    let goal ← getMainGoal
    let goalType ← goal.getType
    
    -- STEP 2: Pattern match on Derivable Γ φ
    match goalType with
    | .app (.app (.const ``Derivable _) context) formula =>
      
      -- STEP 3: Check formula is □φ → φ
      match formula with
      | .app (.app (.const ``Formula.imp _) lhs) rhs =>
        
        match lhs with
        | .app (.const ``Formula.box _) innerFormula =>
          
          -- STEP 4: Verify innerFormula == rhs
          if ← isDefEq innerFormula rhs then
            -- STEP 5: Construct proof term
            let axiomProof ← mkAppM ``Axiom.modal_t #[innerFormula]
            let proof ← mkAppM ``Derivable.axiom #[axiomProof]
            
            -- STEP 6: Assign proof to goal
            goal.assign proof
          else
            throwError "modal_t: expected `□φ → φ` pattern"
        
        | _ => throwError "modal_t: expected □_ on left side"
      
      | _ => throwError "modal_t: expected implication"
    
    | _ => throwError "modal_t: goal must be derivability relation"
```

**Key Operations:**
- `getMainGoal` - Get current goal (MVarId)
- `goal.getType` - Get goal's type (Expr)
- `.app f x` - Pattern match function application
- `.const name _` - Pattern match constant reference
- `isDefEq e1 e2` - Check definitional equality
- `mkAppM name args` - Create function application with implicit inference
- `goal.assign proof` - Close goal with proof term

**Pros:** Full control, pattern matching, custom error messages  
**Cons:** More verbose, requires understanding Expr representation

### Pattern 3: Direct TacticM (Complex Iteration/Search)

**Use when:** Need iteration, backtracking, or complex control flow

```lean
/-- Search context for matching assumption -/
def assumptionSearch : TacticM Unit := do
  let goal ← getMainGoal
  let goalType ← goal.getType
  
  -- Get local context (assumptions)
  let lctx ← getLCtx
  
  -- Iterate through assumptions
  for localDecl in lctx do
    if localDecl.isImplementationDetail then continue
    
    let assumptionType ← instantiateMVars localDecl.type
    
    -- Check if assumption matches goal
    if ← isDefEq assumptionType goalType then
      goal.assign localDecl.toExpr
      return
  
  throwError "assumption_search: no matching assumption found"

elab "assumption_search" : tactic => assumptionSearch
```

**Key Operations:**
- `getLCtx` - Get local context (assumptions)
- `instantiateMVars` - Resolve metavariables
- `localDecl.toExpr` - Convert local declaration to expression

**Pros:** Full flexibility, iteration, backtracking  
**Cons:** Most complex, requires deep understanding of TacticM

## 2. Aesop Integration for TM Automation

### Declaring Custom Rule Sets

```lean
-- Declare TM-specific rule set
declare_aesop_rule_sets [TMLogic]
```

### Marking Axioms as Safe Rules

```lean
@[aesop safe [TMLogic]]
theorem modal_t_derivable (φ : Formula) :
  Derivable [] (Formula.box φ).imp φ := by
  apply Derivable.axiom
  exact Axiom.modal_t φ
```

### Implementing tm_auto Tactic

```lean
/-- Comprehensive TM automation using Aesop -/
macro "tm_auto" : tactic =>
  `(tactic| aesop (rule_sets [TMLogic]))
```

### Rule Types

| Attribute | Purpose | When to Use |
|-----------|---------|-------------|
| `@[aesop safe]` | Always apply (preserves correctness) | Axioms, valid theorems |
| `@[aesop norm simp]` | Normalization/simplification | Rewrite rules, simplifications |
| `@[aesop unsafe]` | May diverge (use cautiously) | Heuristic rules |
| `@[aesop safe forward]` | Forward chaining | Inference rules (MP, MK, TK) |

### Example: Forward Reasoning

```lean
@[aesop safe forward [TMLogic]]
theorem modal_k_forward (φ ψ : Formula) 
    (h1 : Derivable Γ (Formula.box (φ.imp ψ)))
    (h2 : Derivable Γ (Formula.box φ)) : 
  Derivable Γ (Formula.box ψ) := by
  exact Derivable.modal_k h1 h2
```

## 3. Common Tactic Patterns in Logos

### Pattern: Apply Axiom with Pattern Matching

```lean
elab "modal_4_tactic" : tactic => do
  let goal ← getMainGoal
  let goalType ← goal.getType
  
  match goalType with
  | .app (.app (.const ``Derivable _) context) formula =>
    match formula with
    | .app (.app (.const ``Formula.imp _) lhs) rhs =>
      match lhs with
      | .app (.const ``Formula.box _) innerFormula =>
        match rhs with
        | .app (.const ``Formula.box _) (.app (.const ``Formula.box _) innerFormula2) =>
          if ← isDefEq innerFormula innerFormula2 then
            let axiomProof ← mkAppM ``Axiom.modal_4 #[innerFormula]
            let proof ← mkAppM ``Derivable.axiom #[axiomProof]
            goal.assign proof
          else
            throwError "modal_4_tactic: expected □φ → □□φ pattern"
        | _ => throwError "modal_4_tactic: expected □□φ on right"
      | _ => throwError "modal_4_tactic: expected □φ on left"
    | _ => throwError "modal_4_tactic: expected implication"
  | _ => throwError "modal_4_tactic: goal must be derivability relation"
```

### Pattern: Apply Inference Rule (Creates Subgoals)

```lean
elab "modal_k_tactic" : tactic => do
  let goal ← getMainGoal
  
  -- Apply modal K rule: from □(φ → ψ) and □φ, derive □ψ
  let subgoals ← goal.apply (← mkConstWithFreshMVars ``Derivable.modal_k)
  
  -- Replace main goal with subgoals
  replaceMainGoal subgoals
```

### Pattern: Bounded Proof Search (MVP: Delegate to tm_auto)

```lean
/-- Bounded modal proof search (MVP delegates to tm_auto) -/
macro "modal_search" : tactic =>
  `(tactic| tm_auto)

/-- Bounded temporal proof search (MVP delegates to tm_auto) -/
macro "temporal_search" : tactic =>
  `(tactic| tm_auto)
```

**Note:** Full proof search implementation requires backtracking and depth limits (see TACTIC_DEVELOPMENT.md Section 3 Pattern 4).

## 4. Key Metaprogramming Modules

```lean
import Lean.Elab.Tactic      -- Tactic elaboration
import Lean.Meta.Basic       -- Meta-level operations
import Lean.Meta.Tactic.Simp -- Simplification
```

### Essential Types and Functions

| Type/Function | Purpose |
|--------------|---------|
| `MVarId` | Goal identifier (metavariable) |
| `Expr` | Expression/term representation |
| `TacticM` | Monad for tactic execution |
| `MetaM` | Monad for meta-level operations |
| `getMainGoal` | Get current goal |
| `MVarId.assign` | Assign proof term to goal |
| `mkAppM` | Create function application |
| `mkConst` | Create constant reference |
| `isDefEq` | Check definitional equality |
| `getLCtx` | Get local context (assumptions) |

## 5. Testing Patterns

### Unit Test Structure

```lean
-- Test axiom application
example (P : Formula) : [] ⊢ (Formula.box P).imp P := by
  modal_t

-- Test inference rule
example (P Q : Formula) : 
  [Formula.box (P.imp Q), Formula.box P] ⊢ Formula.box Q := by
  modal_k_tactic

-- Test automation
example (P : Formula) : [] ⊢ (Formula.box P).imp P := by
  tm_auto
```

### Edge Case Coverage

```lean
-- Test error handling
example (P Q : Formula) : [] ⊢ P.imp Q := by
  modal_t  -- Should fail with clear error message
```

## 6. Common Pitfalls

[FAIL] **Forgetting to open namespaces**
```lean
-- Wrong
elab "my_tactic" : tactic => do
  let goal ← Lean.Elab.Tactic.getMainGoal  -- Verbose

-- Right
open Lean Elab Tactic Meta
elab "my_tactic" : tactic => do
  let goal ← getMainGoal  -- Clean
```

[FAIL] **Not checking definitional equality**
```lean
-- Wrong
if innerFormula == rhs then ...  -- Syntactic equality only

-- Right
if ← isDefEq innerFormula rhs then ...  -- Definitional equality
```

[FAIL] **Missing error messages**
```lean
-- Wrong
match goalType with
| .app ... => ...
| _ => throwError "failed"  -- Unhelpful

-- Right
| _ => throwError "modal_t: goal must be derivability relation, got {goalType}"
```

[FAIL] **Using macro when elab_rules is needed**
```lean
-- Wrong (can't pattern match in macro)
macro "modal_t" : tactic => ...  -- Can't inspect goal structure

-- Right
elab_rules : tactic
  | `(tactic| modal_t) => do ...  -- Full pattern matching
```

## 7. Logos-Specific Tactics (Implemented)

| Tactic | Purpose | Pattern |
|--------|---------|---------|
| `apply_axiom` | Apply TM axiom | Macro |
| `modal_t` | Apply MT axiom | Macro |
| `modal_k_tactic` | Apply MK rule | elab_rules |
| `temporal_k_tactic` | Apply TK rule | elab_rules |
| `modal_4_tactic` | Apply M4 axiom | elab_rules |
| `modal_b_tactic` | Apply MB axiom | elab_rules |
| `temp_4_tactic` | Apply T4 axiom | elab_rules |
| `temp_a_tactic` | Apply TA axiom | elab_rules |
| `assumption_search` | Search context | TacticM |
| `tm_auto` | Aesop automation | Macro |
| `modal_search` | Modal proof search (MVP) | Macro (delegates to tm_auto) |
| `temporal_search` | Temporal proof search (MVP) | Macro (delegates to tm_auto) |

**Status:** All 12 tactics implemented (Task 7 complete)

### Concrete Examples from Logos Codebase

#### Example 1: Simple Axiom Application
**File:** `Logos/Core/Theorems/Propositional.lean`

```lean
/-- Identity theorem: φ → φ -/
theorem imp_refl (φ : Formula) : Derivable [] (φ.imp φ) := by
  apply Derivable.axiom
  exact Axiom.prop_s φ φ
```

**Pattern:** Direct axiom application with `apply` and `exact`

#### Example 2: Modus Ponens Chain
**File:** `Logos/Core/Theorems/Combinators.lean`

```lean
/-- Implication transitivity: (φ → ψ) → ((ψ → χ) → (φ → χ)) -/
theorem imp_trans (φ ψ χ : Formula) : 
    Derivable [] ((φ.imp ψ).imp ((ψ.imp χ).imp (φ.imp χ))) := by
  apply Derivable.mp
  · apply Derivable.mp
    · apply Derivable.axiom
      exact Axiom.prop_k (ψ.imp χ) ψ χ
    · apply Derivable.axiom
      exact Axiom.prop_s φ ψ χ
  · apply Derivable.axiom
    exact Axiom.prop_k φ (ψ.imp χ) (φ.imp χ)
```

**Pattern:** Nested `apply Derivable.mp` for chained modus ponens

#### Example 3: Using Deduction Theorem
**File:** `Logos/Core/Theorems/Propositional.lean`

```lean
/-- Ex Contradictione Quodlibet: from A and ¬A, derive B -/
theorem ecq (A B : Formula) : Derivable [A, A.neg] B := by
  apply Derivable.mp
  · exact efq_derivable A B
  · apply Derivable.assume
    right
    rfl
```

**Pattern:** Combining `Derivable.mp` with `Derivable.assume` for context reasoning

#### Example 4: Modal Reasoning
**File:** `Logos/Core/Theorems/ModalS5.lean`

```lean
/-- Modal T: □φ → φ -/
theorem modal_t_derivable (φ : Formula) : 
    Derivable [] (Formula.box φ |>.imp φ) := by
  apply Derivable.axiom
  exact Axiom.modal_t φ
```

**Pattern:** Direct modal axiom application

#### Example 5: Complex Proof with Helper Lemmas
**File:** `Logos/Core/Theorems/Propositional.lean`

```lean
/-- Reverse contraposition: (¬A → ¬B) → (B → A) -/
theorem rcp {Γ : List Formula} {A B : Formula} 
    (h : Derivable Γ (A.neg.imp B.neg)) : 
    Derivable Γ (B.imp A) := by
  apply Derivable.mp
  · apply Derivable.mp
    · exact theorem_flip A.neg B.neg
    · exact h
  · exact dni B
```

**Pattern:** Using previously proven theorems as lemmas

#### Example 6: Inductive Proof
**File:** `Logos/Core/Metalogic/Soundness.lean`

```lean
/-- Soundness: If Γ ⊢ φ, then Γ ⊨ φ -/
theorem soundness {Γ : List Formula} {φ : Formula} 
    (h : Derivable Γ φ) : 
    Γ ⊨ φ := by
  intro M w h_valid
  induction h with
  | axiom ax =>
    exact axiom_valid ax M w
  | assume h_mem =>
    exact h_valid φ h_mem
  | mp h_imp h_ant ih_imp ih_ant =>
    exact ih_imp M w h_valid (ih_ant M w h_valid)
```

**Pattern:** Structural induction on derivation with case analysis

#### Example 7: Using tm_auto Tactic
**File:** `LogosTest/Core/Automation/TacticsTest.lean`

```lean
/-- Test tm_auto on simple propositional goal -/
example (p q : Formula) : 
    Derivable [] (p.imp (q.imp p)) := by
  tm_auto
```

**Pattern:** Automated proof search with Aesop integration

#### Example 8: Context-Based Reasoning
**File:** `Logos/Core/Theorems/Propositional.lean`

```lean
/-- Ex Contradictione Quodlibet: from A and ¬A, derive B -/
theorem ecq (A B : Formula) : Derivable [A, A.neg] B := by
  apply Derivable.mp
  · exact efq_derivable A B
  · apply Derivable.assume
    right  -- Select second element from context
    rfl
```

**Pattern:** Using `Derivable.assume` to extract formulas from context, with `left`/`right` to navigate list membership

#### Example 9: Unfolding Definitions
**File:** `Logos/Core/Theorems/Propositional.lean`

```lean
/-- Law of Excluded Middle: ⊢ A ∨ ¬A -/
def lem (A : Formula) : ⊢ A.or A.neg := by
  -- A ∨ ¬A = ¬A → ¬A (by definition of disjunction)
  unfold Formula.or
  -- Now goal is: ⊢ A.neg.imp A.neg
  exact identity A.neg
```

**Pattern:** Using `unfold` to expand derived operators to their primitive definitions

#### Example 10: Pattern Matching on Goal Structure
**File:** `Logos/Core/Automation/Tactics.lean` (conceptual)

```lean
elab "modal_t_tactic" : tactic => do
  let goal ← getMainGoal
  let goalType ← goal.getType
  
  match goalType with
  | .app (.app (.const ``Derivable _) context) formula =>
    match formula with
    | .app (.app (.const ``Formula.imp _) lhs) rhs =>
      match lhs with
      | .app (.const ``Formula.box _) innerFormula =>
        if ← isDefEq innerFormula rhs then
          let axiomProof ← mkAppM ``Axiom.modal_t #[innerFormula]
          let proof ← mkAppM ``Derivable.axiom #[axiomProof]
          goal.assign proof
        else
          throwError "modal_t: expected □φ → φ pattern"
      | _ => throwError "modal_t: expected □_ on left side"
    | _ => throwError "modal_t: expected implication"
  | _ => throwError "modal_t: goal must be derivability relation"
```

**Pattern:** Full elab_rules with pattern matching and error handling

## References

- Full guide: `docs/project-info/TACTIC_DEVELOPMENT.md`
- Metaprogramming: `docs/development/METAPROGRAMMING_GUIDE.md`
- LEAN 4 Metaprogramming Book: https://leanprover-community.github.io/lean4-metaprogramming-book/
- Aesop Documentation: https://github.com/leanprover-community/aesop
