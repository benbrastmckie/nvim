# Proof Debt Policy

## Overview

This file formalizes the approach to **proof debt** in Lean 4 proofs. Proof debt encompasses:
- **Sorries**: Incomplete proofs marked with `sorry` tactic
- **Axioms**: Explicit unproven assumptions declared with `axiom` keyword

Both represent unverified mathematical claims that propagate transitively through dependencies.

## Completion Gates

### Zero-Debt Completion Requirement (MANDATORY)

**For any Lean task to be marked `[COMPLETED]`:**
1. **Zero sorries** in modified/created files - NO exceptions
2. **No new axioms** introduced - NO exceptions
3. **Build passes** with `lake build` - NO exceptions

**This is a HARD REQUIREMENT, not a guideline.** If a proof cannot be completed:
- Do NOT introduce sorry and mark task completed
- Do NOT defer sorry resolution to a follow-up task
- Mark the phase `[BLOCKED]` with documentation
- Document what is blocking progress

### Soft vs Hard Blockers

**Hard Blocker**:
- Proof cannot be completed with current approach
- Theorem may be false or needs different formulation
- Missing prerequisite lemma not in scope

**NOT a Blocker (continue or handoff)**:
- Context exhaustion (write handoff, successor continues)
- Timeout (mark [PARTIAL], next /implement resumes)
- MCP tool transient failure (retry, continue)

## Forbidden Patterns

### Sorry Deferral: STRICTLY FORBIDDEN

**Examples of FORBIDDEN patterns**:
```lean
-- FORBIDDEN: "We'll fix this sorry in task 999"
sorry  -- TODO: complete in follow-up task

-- FORBIDDEN: "Temporary sorry, tracked elsewhere"
sorry  -- tracked, will resolve later
```

**What to do instead**:
1. If proof is stuck: Mark phase `[BLOCKED]`
2. If approach is wrong: Recommend plan revision
3. If scope is too large: Recommend task expansion

### New Axiom Introduction: STRICTLY FORBIDDEN

**Examples of FORBIDDEN patterns**:
```lean
-- FORBIDDEN: New axiom to skip proof
axiom my_assumption : forall x, P x

-- FORBIDDEN: Axiom as workaround
axiom construction_exists : exists s, IsValid s
```

**What to do instead**:
- Find structural proof approach
- If impossible, mark phase `[BLOCKED]` with explanation

## Philosophy

Sorries and axioms are **mathematical debt**, fundamentally different from technical debt:
- Each represents an **unverified mathematical claim** that may be false
- Both propagate: using a lemma with `sorry` or depending on an `axiom` inherits that debt
- **Never acceptable in publication-ready proofs**

### Key Differences

| Property | Sorry | Axiom |
|----------|-------|-------|
| Visibility | Implicit (proof gap) | Explicit (declared assumption) |
| Intent | Always temporary | Sometimes intentional design choice |
| Publication | Cannot publish | Can publish with disclosure |
| Remediation | Must resolve | Must resolve or disclose |

## Sorry Categories

### 1. Construction Assumptions (Tolerated During Development)
Treated as axiomatic within the current architecture. Still mathematical debt.

### 2. Development Placeholders (Must Resolve)
Temporary gaps with clear resolution paths.

### 3. Documentation Examples (Excluded from Counts)
Intentional sorries in examples or demonstration code.

### 4. Fundamental Obstacles
Approaches that cannot work. Must archive with documentation.

## Axiom Categories

### 1. Construction Assumptions (Technical Debt)
Required by current architecture but should be eliminated via completed construction.

### 2. Existence Assumptions (Technical Debt)
Assert existence without proof. Elimination requires specific proof approach.

### 3. Documentation Examples (Excluded from Counts)
Intentional axioms in examples or demonstration code.

## Remediation Paths

### Path A: Proof Completion
Fill the gap with valid proof. Preferred when mathematically feasible.

### Path B: Architectural Refactoring
Change approach to avoid the gap entirely.

### Path C: Archive with Documentation
Archive fundamentally flawed code with documentation of why it failed.

## Usage Checklist

### Sorries
- [ ] No new `sorry` added without documentation
- [ ] Construction assumptions documented in code comments
- [ ] Transitive dependencies checked for critical proofs

### Axioms
- [ ] No new `axiom` added without documentation
- [ ] Axiom purpose and remediation path documented
- [ ] Transitive dependencies checked (what inherits this axiom?)
- [ ] Structural proof approach identified
