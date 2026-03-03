# Mathlib Overview

## Overview
`mathlib` is the main community-driven library of formalized mathematics for LEAN 4. It is a vast and rapidly growing collection of definitions, theorems, and tactics.

## Key Libraries

- **`Data`**: Contains data structures and algorithms, such as lists, finite sets, and maps.
- **`Algebra`**: Includes abstract algebra concepts like groups, rings, and fields.
- **`Topology`**: Covers point-set topology, metric spaces, and topological groups.
- **`Analysis`**: Contains real and complex analysis, including calculus and measure theory.
- **`CategoryTheory`**: Provides a framework for category theory.

## Business Rules
1. All contributions to `mathlib` must adhere to the `mathlib` style guide.
2. All new theorems must be accompanied by a proof.
3. All new definitions must be accompanied by documentation.

## Relationships
- **Depends on**: LEAN 4
- **Used by**: The LEAN 4 community

## Examples

### Common Imports

```lean
-- Real numbers and basic operations
import Mathlib.Data.Real.Basic

-- Natural numbers and induction
import Mathlib.Data.Nat.Basic

-- Lists and finite sets
import Mathlib.Data.List.Basic
import Mathlib.Data.Finset.Basic

-- Topology and metric spaces
import Mathlib.Topology.MetricSpace.Basic

-- Abstract algebra
import Mathlib.Algebra.Group.Defs
import Mathlib.Algebra.Ring.Defs

-- Logic and order
import Mathlib.Order.Basic
import Mathlib.Logic.Basic
```

### Example Usage

#### Real Numbers
```lean
import Mathlib.Data.Real.Basic

-- Triangle inequality
example (x y : ℝ) : |x + y| ≤ |x| + |y| :=
  abs_add x y

-- Multiplication is commutative
example (x y : ℝ) : x * y = y * x :=
  mul_comm x y
```

#### Natural Numbers
```lean
import Mathlib.Data.Nat.Basic

-- Addition is associative
example (n m k : ℕ) : (n + m) + k = n + (m + k) :=
  Nat.add_assoc n m k

-- Zero is right identity
example (n : ℕ) : n + 0 = n :=
  Nat.add_zero n
```

#### Lists
```lean
import Mathlib.Data.List.Basic

-- List concatenation is associative
example (xs ys zs : List α) : (xs ++ ys) ++ zs = xs ++ (ys ++ zs) :=
  List.append_assoc xs ys zs

-- Length of concatenation
example (xs ys : List α) : (xs ++ ys).length = xs.length + ys.length :=
  List.length_append xs ys
```

#### Finite Sets
```lean
import Mathlib.Data.Finset.Basic

-- Union is commutative
example (s t : Finset α) : s ∪ t = t ∪ s :=
  Finset.union_comm

-- Membership in union
example (x : α) (s t : Finset α) : x ∈ s ∪ t ↔ x ∈ s ∨ x ∈ t :=
  Finset.mem_union
```

#### Groups
```lean
import Mathlib.Algebra.Group.Defs

-- Identity element property
example [Group G] (g : G) : g * 1 = g :=
  mul_one g

-- Inverse property
example [Group G] (g : G) : g * g⁻¹ = 1 :=
  mul_inv_self g
```

#### Metric Spaces
```lean
import Mathlib.Topology.MetricSpace.Basic

-- Distance is symmetric
example [MetricSpace α] (x y : α) : dist x y = dist y x :=
  dist_comm x y

-- Triangle inequality
example [MetricSpace α] (x y z : α) : dist x z ≤ dist x y + dist y z :=
  dist_triangle x y z
```

## Mathlib Usage in Logos Project

The Logos project primarily uses mathlib for:

### Data Structures
```lean
-- Lists for contexts (from Logos/Core/Syntax/Context.lean)
import Mathlib.Data.List.Basic

-- List membership and operations
def Context := List Formula

-- Using List.mem for context membership
theorem assume_mem {Γ : Context} {φ : Formula} (h : φ ∈ Γ) : 
    Derivable Γ φ := by
  apply Derivable.assume
  exact h
```

### Logic and Decidability
```lean
-- Decidable equality for formulas
inductive Formula : Type where
  | atom : String → Formula
  | bot : Formula
  | imp : Formula → Formula → Formula
  | box : Formula → Formula
  | all_past : Formula → Formula
  | all_future : Formula → Formula
  deriving Repr, DecidableEq  -- Uses mathlib's DecidableEq
```

### Common Mathlib Patterns in Logos

**Pattern 1: Using List operations**
```lean
-- Context weakening with List.append
theorem weakening {Γ Δ : List Formula} {φ : Formula} 
    (h : Derivable Γ φ) : 
    Derivable (Γ ++ Δ) φ := by
  induction h with
  | assume h_mem => 
    apply Derivable.assume
    exact List.mem_append_left Δ h_mem
  | axiom ax => exact Derivable.axiom ax
  | mp h_imp h_ant ih_imp ih_ant =>
    exact Derivable.mp ih_imp ih_ant
```

**Pattern 2: Using decidable equality**
```lean
-- Checking formula equality
def is_same_formula (φ ψ : Formula) : Bool :=
  φ == ψ  -- Uses derived DecidableEq instance
```

**Pattern 3: Using basic logic**
```lean
import Mathlib.Logic.Basic

-- Using classical logic for metalogical proofs
theorem soundness_complete {Γ : List Formula} {φ : Formula} :
    (Derivable Γ φ) ↔ (Γ ⊨ φ) := by
  constructor
  · exact soundness
  · exact completeness
```

### Key Mathlib Modules Used in Logos

| Module | Purpose in Logos |
|--------|------------------|
| `Mathlib.Data.List.Basic` | Context management (lists of formulas) |
| `Mathlib.Logic.Basic` | Classical logic for metalogic |
| `Mathlib.Order.Basic` | Ordering for complexity measures |
| `Mathlib.Init.Data.Nat.Basic` | Natural numbers for complexity |

### Note on Mathlib Dependencies

The Logos project intentionally minimizes mathlib dependencies to keep the core logic system self-contained. Most mathlib usage is for:
- Basic data structures (List)
- Decidability instances
- Classical logic in metalogical proofs

The core proof system (axioms, derivation rules) is defined independently without mathlib dependencies.
