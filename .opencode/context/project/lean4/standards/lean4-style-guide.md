# LEAN 4 Style Guide

## Overview
This file defines the coding conventions for LEAN 4 to ensure consistency and readability.

## Quality Criteria

### Naming Conventions
- **Types**: `CamelCase`
- **Functions and Variables**: `camelCase`
- **Theorems**: `snake_case`

### Line Length
- Lines should not exceed 100 characters.

### Indentation
- Use 2 spaces for indentation.

## Validation Rules

### Naming Conventions
- **Rule**: All names must follow the naming conventions.
  **Check**: Use a linter to check for naming convention violations.
  **Failure Action**: Fix the naming convention violation.

### Line Length
- **Rule**: All lines must be less than 100 characters.
  **Check**: Use a linter to check for line length violations.
  **Failure Action**: Break the line into multiple lines.

## Examples

**Pass Example**:
```lean
def myFunctionName (myVariable : MyType) : MyOtherType :=
  -- ...
```

**Fail Example**:
```lean
def My_Function_Name (My_Variable : my_type) : my_other_type :=
  -- ...
```

---

# LEAN 4 Style Standards - Quick Reference

**Source:** `docs/development/LEAN_STYLE_GUIDE.md`  
**Purpose:** Essential coding conventions for LEAN 4 code generation in Logos project

## 1. Naming Conventions

### Quick Reference Table

| Element | Convention | Examples |
|---------|-----------|----------|
| **Types/Structures** | PascalCase | `Formula`, `TaskFrame`, `WorldHistory` |
| **Functions/Defs** | snake_case | `truth_at`, `swap_temporal`, `canonical_history` |
| **Theorems/Lemmas** | snake_case | `soundness`, `modal_t_valid`, `perpetuity_1` |
| **Variables (formulas)** | Greek letters | `φ`, `ψ`, `χ` (phi, psi, chi) |
| **Variables (contexts)** | Greek capitals | `Γ`, `Δ` (Gamma, Delta) |
| **Variables (models)** | Capitals | `M`, `N` (models), `F` (frames) |
| **Variables (times)** | Lowercase | `t`, `s` (times), `τ`, `σ` (histories) |

### Examples

```lean
-- Good
theorem soundness (Γ : Context) (φ : Formula) : Γ ⊢ φ → Γ ⊨ φ := ...
def truth_at (M : TaskModel F) (τ : WorldHistory F) (t : F.Time) : Formula → Prop := ...
structure TaskFrame where

-- Avoid
theorem Soundness ...           -- PascalCase for theorem
def TruthAt ...                 -- PascalCase for function
structure task_frame where      -- snake_case for type
```

## 2. Formatting Standards

### Line Length & Indentation
- **Max 100 characters per line**
- **2 spaces** for indentation (no tabs)
- **Flush-left** declarations (no indentation for `def`, `theorem`, `lemma`)

```lean
-- Good
theorem strong_completeness (Γ : Context) (φ : Formula) :
  Γ ⊨ φ → Γ ⊢ φ := by
  sorry

def truth_at (M : TaskModel F) (τ : WorldHistory F) (t : F.Time) :
  Formula → Prop
  | Formula.atom p => t ∈ τ.domain ∧ τ(t) ∈ M.valuation p
  | Formula.bot => False
```

### Spacing Rules
- **One blank line** between top-level declarations
- **Single space** around binary operators (`→`, `∧`, `∨`, `=`, `:=`)
- **No space** after `(`, `[`, `{` or before `)`, `]`, `}`
- **No trailing whitespace**

## 3. Unicode Operators

### Modal & Temporal Notation

```lean
-- Modal operators
□φ    -- Necessity (box)
◇φ    -- Possibility (diamond)

-- Temporal operators
△φ    -- Always/at all times (upward triangle, U+25B3)
▽φ    -- Sometimes/at some time (downward triangle, U+25BD)
```

**Usage:**
- Prefer prefix notation: `△p` over `p.always` for conciseness
- Mixed usage acceptable: both `△p` and `p.always` are valid
- Use consistently within a single theorem

```lean
-- Good
theorem perpetuity_1 (φ : Formula) : ⊢ (□φ → △φ) := by sorry
theorem perpetuity_2 (φ : Formula) : ⊢ (▽φ → ◇φ) := by sorry

-- Avoid (inconsistent)
theorem perpetuity_1 (φ : Formula) : ⊢ (□φ → always φ) := by sorry
```

## 4. Code Comments with Formal Symbols

**Wrap formal symbols in backticks** for improved readability:

```lean
-- Good
-- MT axiom: `□φ → φ` (reflexivity of necessity)
-- Perpetuity principle P1: `□φ → △φ`
-- Soundness: if `Γ ⊢ φ` then `Γ ⊨ φ`

-- Acceptable (but less clear)
-- MT axiom: □φ → φ (reflexivity of necessity)
```

**Rationale:** Backticks improve visual clarity in VS Code tooltips and match markdown standards.

## 5. Import Organization

### Import Order
1. Standard library imports
2. Mathlib imports (when used)
3. Project imports (`Logos.*`)
4. Blank line between groups

```lean
-- Good
import Init.Data.List
import Mathlib.Order.Basic

import Logos.Syntax.Formula
import Logos.Syntax.Context
import Logos.ProofSystem.Axioms
```

## 6. Documentation Requirements

### Module Docstrings
Every file must begin with a module docstring:

```lean
/-!
# Task Frame Semantics

This module defines task frames and world histories for the bimodal logic TM.

## Main Definitions

* `TaskFrame` - A task frame consisting of world states, times, and task relation
* `WorldHistory` - A function from a convex set of times to world states

## Main Theorems

* `time_shift_invariance` - Truth is invariant under time shifts
-/
```

### Declaration Docstrings
Every public definition, theorem, and structure requires a docstring:

```lean
/-- The soundness theorem for TM: derivability implies semantic consequence.

If `Γ ⊢ φ` (φ is derivable from Γ), then `Γ ⊨ φ` (φ is a semantic consequence of Γ).
This is proven by induction on the derivation. -/
theorem soundness (Γ : Context) (φ : Formula) : Γ ⊢ φ → Γ ⊨ φ := by
  sorry
```

## 7. Common Patterns

### Pattern Matching
```lean
def complexity : Formula → Nat
  | Formula.atom _ => 1
  | Formula.bot => 1
  | Formula.imp φ ψ => φ.complexity + ψ.complexity + 1
  | Formula.box φ => φ.complexity + 1
```

### Tactic Proofs
```lean
theorem modal_t_implies_reflexive (φ : Formula) :
  ⊢ (φ.box.imp φ) := by
  apply Derivable.axiom
  apply Axiom.modal_t
```

### Intermediate Steps
```lean
theorem example_proof (φ ψ : Formula) (h : ⊢ φ.imp ψ) (h2 : ⊢ φ) : ⊢ ψ := by
  have h3 : [] ⊢ φ.imp ψ := h
  have h4 : [] ⊢ φ := h2
  exact Derivable.modus_ponens [] φ ψ h3 h4
```

## 8. Common Violations to Avoid

[FAIL] **PascalCase for functions/theorems**
```lean
def TruthAt ...                 -- Wrong
theorem Soundness ...           -- Wrong
```

[FAIL] **Tabs instead of spaces**
```lean
def example := by
	sorry                       -- Wrong (tab)
```

[FAIL] **Lines over 100 characters**
```lean
theorem strong_completeness (Γ : Context) (φ : Formula) : Γ ⊨ φ → Γ ⊢ φ := by sorry  -- Too long
```

[FAIL] **Missing docstrings**
```lean
theorem soundness (Γ : Context) (φ : Formula) : Γ ⊢ φ → Γ ⊨ φ := by  -- Missing docstring
  sorry
```

[FAIL] **Inconsistent operator notation**
```lean
theorem perpetuity_1 (φ : Formula) : ⊢ (□φ → always φ) := by sorry  -- Mix of □ and text
```

## References

- Full guide: `docs/development/LEAN_STYLE_GUIDE.md`
- Mathlib4 Style: https://leanprover-community.github.io/contribute/style.html
- LEAN 4 Docs: https://lean-lang.org/documentation/
