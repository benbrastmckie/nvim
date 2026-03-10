# Notation Standards

## Overview

Notation standards for modal and temporal logic formulas.

## Core Operators

### Propositional Operators

| Operator | Symbol | Description |
|----------|--------|-------------|
| Sentence letter | p, q, r | Atomic formulas |
| Bottom | bot | Falsity |
| Implication | -> | Material implication |
| Negation | not | Derived: phi -> bot |
| Conjunction | and | Derived |
| Disjunction | or | Derived |

### Modal Operators

| Operator | Symbol | Description |
|----------|--------|-------------|
| Necessity | box | Metaphysical necessity |
| Possibility | diamond | Derived: not box not phi |

### Temporal Operators

| Operator | Symbol | Description |
|----------|--------|-------------|
| Universal Past | H | Always was |
| Universal Future | G | Always will be |
| Existential Past | P | Sometimes was |
| Existential Future | F | Sometimes will be |
| Always (Eternal) | delta | H phi and phi and G phi |

## Precedence

| Level | Operators |
|-------|-----------|
| 80 | box, diamond, H, G, P, F |
| 70 | not |
| 60 | and |
| 50 | or |
| 40 | -> |

## Variable Naming

| Type | Variables |
|------|-----------|
| Formulas | phi, psi, chi |
| Sentence letters | p, q, r, s |
| Contexts | Gamma, Delta |
| Models | M, N |
| Frames | F |
| Worlds | w, v, u |
| Times | t, s |

## Parenthesization

### Minimal Parentheses

Use precedence to minimize:
```
box p -> q       -- Parsed as: (box p) -> q
not box p and q  -- Parsed as: (not (box p)) and q
```

### Clarity Parentheses

Add for readability when helpful:
```
box(p and q) -> (box p and box q)
```

## Documentation

### Inline Formulas

Use backticks: `box phi -> phi`

### Axiom Documentation

Include:
1. Axiom name
2. Formula pattern
3. Semantic interpretation

## Terminology

Use "sentence letter" instead of:
- "propositional atom"
- "propositional variable"
- "atomic proposition"

## Success Criteria

- [ ] Consistent operator symbols
- [ ] Correct precedence usage
- [ ] Standard variable names
- [ ] Minimal parentheses
- [ ] Clear documentation
- [ ] Correct terminology
