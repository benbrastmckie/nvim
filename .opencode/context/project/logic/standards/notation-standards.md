# Modal Logic Notation Standards

## Overview

This document defines the notation standards for modal and temporal logic in the Logos/Theory LEAN 4 codebase. These standards ensure consistency across formulas, proofs, and documentation.

## When to Use

- When defining new formulas or operators
- When writing proofs involving modal or temporal operators
- When documenting theorems and axioms
- When creating examples or tutorials

## Prerequisites

- Understanding of modal logic semantics (necessity □, possibility ◇)
- Understanding of temporal logic semantics (past H/P, future G/F)
- Familiarity with LEAN 4 syntax and notation declarations

## Context Dependencies

- `lean4/domain/lean4-syntax.md` - LEAN 4 syntax reference
- `lean4/standards/lean4-style-guide.md` - General LEAN 4 style conventions
- `logic/standards/naming-conventions.md` - Naming conventions for logic constructs

---

## Core Operators

### Propositional Operators

| Operator | Symbol | LEAN Notation | Unicode | Description |
|----------|--------|---------------|---------|-------------|
| Atom | p, q, r | `Formula.atom "p"` | - | Propositional variables |
| Bottom | ⊥ | `Formula.bot` | U+22A5 | Falsity/contradiction |
| Implication | → | `φ.imp ψ` | U+2192 | Material implication |
| Negation | ¬ | `φ.neg` | U+00AC | Derived: `φ → ⊥` |
| Conjunction | ∧ | `φ.and ψ` | U+2227 | Derived: `¬(φ → ¬ψ)` |
| Disjunction | ∨ | `φ.or ψ` | U+2228 | Derived: `¬φ → ψ` |

**Naming Convention**: Use descriptive function names (`imp`, `neg`, `and`, `or`) with method syntax.

**Example**:
```lean
-- Good: Method syntax with descriptive names
def example_formula : Formula := (atom "p").imp (atom "q")
def negation_example : Formula := (atom "p").neg

-- Avoid: Non-standard abbreviations
def example_formula : Formula := p → q  -- Requires custom syntax
```

### Modal Operators (S5 Modal Logic)

| Operator | Symbol | LEAN Notation | Unicode | Description |
|----------|--------|---------------|---------|-------------|
| Necessity | □ | `Formula.box φ` | U+25A1 | Metaphysical necessity |
| Possibility | ◇ | `φ.diamond` | U+25C7 | Derived: `¬□¬φ` |

**Naming Convention**: 
- Primitive: `box` (following Mathlib convention)
- Derived: `diamond` (descriptive dual)
- **Never use**: `necessity`, `possibility` (too verbose)

**Unicode Notation**:
```lean
-- Prefix notation for box (precedence 80)
prefix:80 "□" => Formula.box

-- Diamond is derived, no prefix notation needed
-- Use method syntax: φ.diamond
```

**Example**:
```lean
-- Good: Using box and diamond
theorem modal_t (φ : Formula) : ⊢ (φ.box.imp φ) := by sorry
theorem box_diamond_dual (φ : Formula) : φ.diamond = φ.neg.box.neg := rfl

-- Avoid: Verbose names
theorem necessity_implies_truth (φ : Formula) : ⊢ (φ.necessity.imp φ) := by sorry
```

### Temporal Operators (Linear Temporal Logic)

| Operator | Symbol | LEAN Notation | Unicode | Description |
|----------|--------|---------------|---------|-------------|
| Universal Past | H | `Formula.all_past φ` | - | "φ has always been true" |
| Universal Future | G | `Formula.all_future φ` | - | "φ will always be true" |
| Existential Past | P | `φ.some_past` | - | Derived: `¬H¬φ` |
| Existential Future | F | `φ.some_future` | - | Derived: `¬G¬φ` |
| Always (Eternal) | △ | `φ.always` | U+25B3 | Derived: `Hφ ∧ φ ∧ Gφ` |
| Sometimes | ▽ | `φ.sometimes` | U+25BD | Derived: `¬△¬φ` |

**Naming Convention**:
- Primitives: `all_past`, `all_future` (descriptive, clear quantification)
- Derived existentials: `some_past`, `some_future` (parallel to universals)
- Derived eternals: `always`, `sometimes` (intuitive English)
- **Deprecated**: `sometime_past`, `sometime_future` (use `some_past`, `some_future`)

**Unicode Notation**:
```lean
-- Triangle notation for eternal operators
prefix:80 "△" => Formula.always     -- Upward triangle
prefix:80 "▽" => Formula.sometimes  -- Downward triangle
```

**Example**:
```lean
-- Good: Descriptive temporal names
theorem temp_4 (φ : Formula) : ⊢ (φ.all_future.imp φ.all_future.all_future) := by sorry
theorem always_implies_future (φ : Formula) : ⊢ (△φ → φ.all_future) := by sorry

-- Avoid: Ambiguous abbreviations
theorem temp_4 (φ : Formula) : ⊢ (φ.future.imp φ.future.future) := by sorry  -- Unclear
```

---

## Notation Precedence

### Operator Precedence Levels

| Precedence | Operators | Associativity |
|------------|-----------|---------------|
| 80 | □, ◇, △, ▽, H, G, P, F | Prefix |
| 70 | ¬ | Prefix |
| 60 | ∧ | Right |
| 50 | ∨ | Right |
| 40 | → | Right |

**Rationale**: Modal and temporal operators bind tightest, followed by negation, then conjunction, disjunction, and finally implication.

**Example**:
```lean
-- Precedence determines parsing
□p → q        -- Parsed as: (□p) → q
¬□p ∧ q       -- Parsed as: (¬(□p)) ∧ q
p → q ∨ r     -- Parsed as: p → (q ∨ r)
```

### Parenthesization Guidelines

**Minimal Parentheses**: Use precedence to minimize parentheses.

```lean
-- Good: Minimal parentheses
theorem example1 : ⊢ (□p → p) := by sorry
theorem example2 : ⊢ (□(p → q) → (□p → □q)) := by sorry

-- Avoid: Excessive parentheses
theorem example1 : ⊢ ((□p) → p) := by sorry
theorem example2 : ⊢ ((□(p → q)) → ((□p) → (□q))) := by sorry
```

**Clarity Parentheses**: Add parentheses when precedence is unclear or when improving readability.

```lean
-- Good: Clarity parentheses for nested operators
theorem example : ⊢ (□(p ∧ q) → (□p ∧ □q)) := by sorry

-- Acceptable: Extra parentheses for readability
theorem example : ⊢ ((p → q) → ((q → r) → (p → r))) := by sorry
```

---

## Formula Variable Naming

### Standard Variable Names

| Type | Variables | Usage |
|------|-----------|-------|
| Formulas | φ, ψ, χ | Primary formula variables (phi, psi, chi) |
| Atoms | p, q, r, s | Propositional atoms |
| Contexts | Γ, Δ | Proof contexts (Gamma, Delta) |
| Models | M, N | Task models |
| Frames | F | Task frames |
| Histories | τ, σ | World histories (tau, sigma) |
| Times | t, s, x, y | Time points or durations |

**Example**:
```lean
-- Good: Standard Greek letters for formulas
theorem soundness (Γ : Context) (φ : Formula) : Γ ⊢ φ → Γ ⊨ φ := by sorry

-- Avoid: Non-standard variable names
theorem soundness (ctx : Context) (form : Formula) : ctx ⊢ form → ctx ⊨ form := by sorry
```

### Subscripts and Primes

**Subscripts**: Use for indexed families or related formulas.

```lean
-- Good: Subscripts for indexed formulas
theorem example (φ₁ φ₂ φ₃ : Formula) : ⊢ (φ₁ → (φ₂ → φ₃)) := by sorry
```

**Primes**: Use for modified or related formulas.

```lean
-- Good: Primes for related formulas
theorem swap_involution (φ : Formula) : φ.swap_temporal.swap_temporal = φ := by sorry
```

---

## DSL Notation (Domain-Specific Language)

### Available DSL Syntax

The Logos/Theory provides optional DSL syntax for more readable formula construction:

```lean
-- DSL syntax declarations (from Formula.lean)
syntax "⊥" : term                             -- Falsity
syntax "~" term : term                        -- Negation
syntax term "&" term : term                   -- Conjunction
syntax term "|" term : term                   -- Disjunction
syntax term "->" term : term                  -- Implication
syntax "□" term : term                        -- Necessity
syntax "◇" term : term                        -- Possibility
syntax "H" term : term                        -- Universal past
syntax "G" term : term                        -- Universal future
syntax "P" term : term                        -- Existential past
syntax "F" term : term                        -- Existential future
```

### DSL Usage Guidelines

**When to Use DSL**:
- In examples and tutorials for readability
- In informal proofs or sketches
- When formula structure is the focus

**When to Use Method Syntax**:
- In formal theorem statements
- In library code and definitions
- When type inference is important

**Example**:
```lean
-- DSL syntax (good for examples)
example : ⊢ (□p -> p) := by sorry

-- Method syntax (good for library code)
theorem modal_t (φ : Formula) : ⊢ (φ.box.imp φ) := by sorry
```

---

## Axiom and Theorem Notation

### Axiom Schema Notation

**Standard Form**: Use descriptive names with formula parameters.

```lean
-- Good: Descriptive axiom names
| modal_t (φ : Formula) : Axiom (φ.box.imp φ)
| modal_4 (φ : Formula) : Axiom (φ.box.imp φ.box.box)
| modal_b (φ : Formula) : Axiom (φ.imp φ.diamond.box)

-- Avoid: Cryptic abbreviations
| mt (φ : Formula) : Axiom (φ.box.imp φ)  -- Too terse
```

### Theorem Naming

**Pattern**: `<domain>_<property>` or `<operator>_<property>`

```lean
-- Good: Descriptive theorem names
theorem modal_k_dist (φ ψ : Formula) : ⊢ (□(φ → ψ) → (□φ → □ψ)) := by sorry
theorem temp_k_dist (φ ψ : Formula) : ⊢ (G(φ → ψ) → (Gφ → Gψ)) := by sorry
theorem perpetuity_1 (φ : Formula) : ⊢ (□φ → △φ) := by sorry

-- Avoid: Non-descriptive names
theorem theorem_42 (φ : Formula) : ⊢ (□φ → △φ) := by sorry
```

---

## Documentation Standards

### Inline Formula References

**Use Backticks**: Wrap formulas in backticks for improved readability.

```lean
-- Good: Backticks for formula references
-- MT axiom: `□φ → φ` (reflexivity of necessity)
theorem modal_t (φ : Formula) : ⊢ (φ.box.imp φ) := by sorry

-- Acceptable: Without backticks in docstrings
/-!
The MT axiom states that □φ → φ (reflexivity).
-/
```

### Axiom Documentation

**Required Elements**:
1. Axiom name and abbreviation
2. Formula pattern
3. Semantic interpretation
4. References (if applicable)

**Example**:
```lean
/--
Modal T axiom: `□φ → φ` (reflexivity).

What is necessarily true is actually true.
Semantically: if φ holds at all possible worlds, it holds at the actual world.
-/
| modal_t (φ : Formula) : Axiom (Formula.box φ |>.imp φ)
```

---

## Temporal Duality Notation

### Swap Temporal Operator

**Definition**: `swap_temporal` swaps `all_past` ↔ `all_future` recursively.

```lean
def swap_temporal : Formula → Formula
  | atom s => atom s
  | bot => bot
  | imp φ ψ => imp φ.swap_temporal ψ.swap_temporal
  | box φ => box φ.swap_temporal
  | all_past φ => all_future φ.swap_temporal
  | all_future φ => all_past φ.swap_temporal
```

**Notation**: No special symbol; use method syntax `φ.swap_temporal`.

**Example**:
```lean
-- Temporal duality inference rule
| temporal_duality (φ : Formula)
    (d : DerivationTree [] φ) : DerivationTree [] φ.swap_temporal
```

---

## Common Patterns

### Modal Distribution

```lean
-- Modal K distribution: □(φ → ψ) → (□φ → □ψ)
theorem modal_k_dist (φ ψ : Formula) :
  ⊢ ((φ.imp ψ).box.imp (φ.box.imp ψ.box)) := by sorry
```

### Temporal Distribution

```lean
-- Temporal K distribution: G(φ → ψ) → (Gφ → Gψ)
theorem temp_k_dist (φ ψ : Formula) :
  ⊢ ((φ.imp ψ).all_future.imp (φ.all_future.imp ψ.all_future)) := by sorry
```

### Perpetuity Principles

```lean
-- Perpetuity principle P1: □φ → △φ
theorem perpetuity_1 (φ : Formula) : ⊢ (φ.box.imp △φ) := by sorry

-- Perpetuity principle P2: ▽φ → ◇φ
theorem perpetuity_2 (φ : Formula) : ⊢ (▽φ → φ.diamond) := by sorry
```

---

## Success Criteria

You've successfully applied these notation standards when:
- [ ] All modal operators use `box` and `diamond` consistently
- [ ] All temporal operators use `all_past`, `all_future`, `some_past`, `some_future`
- [ ] Formula variables use Greek letters (φ, ψ, χ)
- [ ] Axiom and theorem names are descriptive and follow conventions
- [ ] Inline formula references use backticks in comments
- [ ] Precedence is used to minimize parentheses
- [ ] DSL syntax is used appropriately (examples vs. library code)

---

## Related Documentation

- **Naming Conventions**: `logic/standards/naming-conventions.md`
- **Proof Conventions**: `logic/standards/proof-conventions.md`
- **Kripke Semantics**: `logic/standards/kripke-semantics.md`
- **LEAN 4 Style Guide**: `lean4/standards/lean4-style-guide.md`
- **Formula Syntax**: `Logos/Core/Syntax/Formula.lean`
- **Axiom Definitions**: `Logos/Core/ProofSystem/Axioms.lean`
