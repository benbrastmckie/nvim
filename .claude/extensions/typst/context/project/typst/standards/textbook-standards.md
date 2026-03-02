# Textbook Standards

## Overview

These standards ensure consistency, rigor, and accessibility for Typst textbook documents.

---

## Definition Ordering Principle

**CRITICAL**: Every mathematical term must be defined before its first use.

### Requirements

1. **Forward References Prohibited**: No term may appear in a definition, theorem statement, or proof before it has been formally defined.

2. **Within-Chapter Ordering**: Sections within a chapter must progress from foundational to dependent concepts.

3. **Cross-Chapter References**: When referencing a term from another chapter:
   - Use explicit cross-reference: "see Definition 2.3"
   - Only reference earlier chapters (lower numbers) or explicitly stated prerequisites

4. **Intuitive Previews Allowed**: Brief informal descriptions may precede formal definitions if clearly marked:
   - "Informally, a lattice is..."
   - "We will make this precise below..."

### Audit Procedure

Before completing any chapter:
1. List all defined terms in order of appearance
2. Verify each term's definition precedes all uses
3. Check all cross-references point to earlier material

---

## Motivation Requirements

Each major concept requires motivation before its formal definition.

### Patterns

**Pattern 1: Problem-Solution**
```
Why do we need X? [1-2 paragraphs]
- Describe the problem X solves
- Show limitation of existing tools
- Introduce X as the solution

#definition("X")[...]
```

**Pattern 2: Examples First**
```
Consider these examples: [specific instances]
What do they have in common? [pattern]
This leads us to the general notion.

#definition("X")[...]
```

**Pattern 3: Historical Context**
```
In [year], [mathematician] asked: [question]
This question led to the development of X.

#definition("X")[...]
```

### Minimum Requirements

- **Definitions**: At least 2 sentences of motivation
- **Theorems**: State why the result matters before proving it
- **Chapters**: Opening section explains chapter's role in the textbook

### Formatting Guidelines

**Rule**: Integrate motivating discussion naturally into surrounding prose. Do NOT use explicit italic headers like `_Motivation_` or `_Intuition_` before definitions.

**Rationale**: Explicit section headers create visual separation that breaks the natural flow of exposition. Mathematics textbooks present motivation as part of the narrative, not as labeled metadata.

**Correct** (inline motivation):
```typst
In first-order logic, we can write schematic expressions like
"for all predicates $P$, $P(x) or not P(x)$" --- but the variable $P$ here is
not bound by the object language. Dependent type theory collapses this distinction.

#definition("Universe Polymorphism")[
  ...
]
```

**Incorrect** (explicit header):
```typst
_Motivation_: In first-order logic, we can write schematic expressions like...

#definition("Universe Polymorphism")[
  ...
]
```

---

## Professional Tone Standards

### Voice

- **Third person** preferred: "One can show..." rather than "You can show..."
- **First person plural** for shared reasoning: "We proceed by induction..."
- **Passive voice** for established results: "It is well-known that..."

### Terminology

| Avoid | Prefer |
|-------|--------|
| "obviously" | "it follows that" |
| "clearly" | "by inspection" or omit |
| "trivial" | "straightforward" |
| "easy" | "routine" |

### Mathematical Precision

- Quantifiers explicit: "for all x in X" not "for x in X"
- Set membership clear: "where x is an element of X" or "for x in X"
- Implications marked: "if...then..." or "implies"

---

## Chapter Structure

Each chapter follows a consistent structure.

### Required Sections

1. **Introduction** (1-2 pages)
   - Motivation for the chapter topic
   - Prerequisites stated explicitly
   - Chapter outline
   - Connections to other chapters (where applicable)

2. **Core Sections** (variable)
   - Each section: definitions, examples, theorems
   - End-of-section summary for long sections

3. **Exercises** (2-3 pages)
   - Graded difficulty: basic, intermediate, advanced
   - Some exercises connect to applications
   - Hints provided for advanced exercises

### Section Numbering

```
Chapter 2: Order Theory
  2.1 Preorders and Partial Orders
  2.2 Bounds and Extrema
  ...
  2.6 Exercises
```

---

## Exercise Standards

### Difficulty Levels

- **Basic** (marked with no symbol): Direct application of definitions
- **Intermediate** (marked with *): Requires combining multiple concepts
- **Advanced** (marked with **): Challenging; may require insight

### Exercise Types

1. **Verification**: "Show that X satisfies properties A, B, C."
2. **Computation**: "Compute X for the following examples."
3. **Proof**: "Prove that..."
4. **Counterexample**: "Give an example showing that..."
5. **Application**: "Explain how this applies to..."

### Format

```typst
#exercise[
  Let $(X, leq)$ be a partial order. Show that if $x$ and $y$ are both
  least elements of $X$, then $x = y$.
]

#exercise("*")[
  Prove that every finite non-empty partial order has a minimal element.
]
```

---

## Notation Standards

### Symbol Consistency

All notation must be defined in notation files (shared or project-specific).

### Common Conventions

| Domain | Convention |
|--------|------------|
| Sets | Uppercase italic: $A$, $B$, $X$ |
| Elements | Lowercase italic: $a$, $b$, $x$ |
| Functions | Lowercase italic: $f$, $g$, $h$ |
| Categories | Bold: **Set**, **Grp** |
| Structures | Calligraphic: $cal(M)$, $cal(F)$ |

---

## Quality Checklist

Before finalizing a chapter:

- [ ] All terms defined before use
- [ ] Every definition has motivation
- [ ] Examples follow definitions
- [ ] Theorems have proofs (or references)
- [ ] Exercises span difficulty levels
- [ ] Cross-references are correct
- [ ] Notation is consistent with shared-notation.typ
- [ ] Chapter compiles without errors
