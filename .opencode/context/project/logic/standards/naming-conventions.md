# Naming Conventions

## Overview

Naming standards for identifiers in modal and temporal logic formalization.

## Formula Variables

### Greek Letters

| Letter | Usage |
|--------|-------|
| phi | Primary formula |
| psi | Secondary formula |
| chi | Third formula |
| theta | Fourth formula |

### Subscripts

Use for indexed families:
- phi_1, phi_2, phi_3
- psi_n

## Sentence Letters

Use lowercase letters: p, q, r, s, t

Reserve x, y, z for metalanguage variables.

## Context Variables

| Letter | Usage |
|--------|-------|
| Gamma | Primary context |
| Delta | Secondary context |
| Sigma | Third context |

## Model Variables

| Letter | Usage |
|--------|-------|
| M | Primary model |
| N | Secondary model |
| F | Frame |

## World Variables

Use w, v, u for possible worlds.

## Time Variables

Use t, s for time points.

## Theorem Naming

### Pattern

`<domain>_<property>` or `<operator>_<property>`

### Examples

- `modal_k_dist` - Modal K distribution
- `temp_4` - Temporal 4 axiom
- `perpetuity_1` - First perpetuity principle
- `soundness` - Soundness theorem
- `completeness` - Completeness theorem

### Avoid

- Generic names: `theorem_42`
- Cryptic abbreviations: `mt`
- Ambiguous names: `lemma1`

## Function Naming

### Predicates

Use descriptive predicates:
- `IsAxiom`
- `Provable`
- `Valid`
- `Satisfies`

### Operations

Use clear operation names:
- `neg` (negation)
- `imp` (implication)
- `box` (necessity)
- `diamond` (possibility)

## Type Naming

### Structures

PascalCase:
- `Formula`
- `KripkeModel`
- `Context`
- `ProofTree`

### Type Classes

PascalCase with descriptive names:
- `Mereology`
- `TopologicalSpace`
- `BooleanAlgebra`

## File Naming

### Context Files

`<topic>-<category>.md`
- `kripke-semantics-overview.md`
- `proof-theory-concepts.md`
- `modal-proof-strategies.md`

### Source Files

PascalCase for Lean:
- `Formula.lean`
- `Derivation.lean`
- `Soundness.lean`

## Consistency Rules

1. Use consistent naming across related definitions
2. Match variable names in theorems to those in definitions
3. Use standard abbreviations consistently
4. Document any non-standard conventions
