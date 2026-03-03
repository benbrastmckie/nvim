# Proof Debt Policy

## Overview

This file formalizes the project's approach to **proof debt** in Lean 4 proofs. Proof debt encompasses:
- **Sorries**: Incomplete proofs marked with `sorry` tactic
- **Axioms**: Explicit unproven assumptions declared with `axiom` keyword

Both represent unverified mathematical claims that propagate transitively through dependencies and block publication.

**Cross-references**:
- Lean proof conventions: `project/lean4/standards/proof-conventions-lean.md`
- Sorry/axiom registry: `docs/project-info/sorry-registry.md`
- Boneyard documentation: `Theories/Bimodal/Boneyard/README.md`

## Philosophy

Sorries and axioms are **mathematical debt**, fundamentally different from technical debt:
- Each represents an **unverified mathematical claim** that may be false
- Both propagate: using a lemma with `sorry` or depending on an `axiom` inherits that debt
- **Never acceptable in publication-ready proofs** (axioms require explicit disclosure)

### Unified Proof Debt Concept

| Term | Definition |
|------|------------|
| **Proof Debt** | Umbrella term for unverified mathematical claims (sorries + axioms) |
| **Sorry** | Implicit proof gap marked with `sorry` tactic |
| **Axiom** | Explicit unproven assumption declared with `axiom` keyword |
| **Transitive Freedom** | No proof debt (direct or inherited) in dependency chain |
| **Publication Ready** | Transitively free of sorries; axioms either eliminated or explicitly disclosed |

### Key Differences

| Property | Sorry | Axiom |
|----------|-------|-------|
| Visibility | Implicit (proof gap) | Explicit (declared assumption) |
| Intent | Always temporary | Sometimes intentional design choice |
| Publication | Cannot publish | Can publish with disclosure |
| Remediation | Must resolve | Must resolve or disclose |

### Transitive Proof Debt Inheritance

Proof debt propagates through the dependency graph. If theorem A uses lemma B which contains `sorry` or depends on `axiom`, then:
- A is **also unproven** (mathematically)
- A **inherits** B's proof debt
- Any claim about A must acknowledge B's sorry or axiom

**Transitively debt-free** means: the theorem AND all its transitive dependencies contain no sorries and no undisclosed axioms. This is the ONLY valid state for publication.

```lean
-- Check transitive freedom with:
#check @MyTheorem  -- Hover shows axioms used; sorry appears as axiom
```

**Publication requirement**: All theorems claimed as proven must be transitively sorry-free. Axioms must be explicitly disclosed or eliminated. NO EXCEPTIONS.

**Reporting requirement**: When proof debt exists anywhere in the dependency chain, reports and plans must:
1. Identify all sorries and axioms (direct and inherited)
2. Document why each exists
3. Specify the remediation path
4. Note impact on dependent theorems

## Characterizing Sorries in Reports and Plans

When documenting sorries in research reports, implementation plans, or summaries, follow this framing:

**Guiding Principle**: Document what exists, explain WHY it exists, specify the remediation path - never call a sorry acceptable.

### Required Elements

1. **State the fact**: "This file contains N sorries"
2. **Categorize each**: Which category from the taxonomy below
3. **Explain the reason**: Why does this sorry exist
4. **Specify remediation**: What would remove it (even if not planned)
5. **Note transitivity**: What depends on this sorry

### Prohibited Framing

Do NOT use these phrases:
- "acceptable sorry" / "sorry is acceptable"
- "acceptable limitation"
- "sorry is fine" / "okay to have sorry"
- "sorry count is acceptable"
- "<N sorries acceptable"

### Required Framing

USE these phrases instead:
- "tolerated during development"
- "technical debt requiring documentation"
- "blocks publication if not resolved"
- "inherited by all dependents"

### Example Transformations

| Prohibited | Required |
|------------|----------|
| "1 sorry is acceptable" | "1 sorry remains (construction assumption) - documented, blocks transitive sorry-freedom" |
| "sorry state acceptable for publication" | "publication requires resolving all N sorries or documenting as explicit axioms" |
| "<5 acceptable" | "target: 0 sorries; current: N sorries (categorized in sorry-registry.md)" |
| "acceptable architectural limitation" | "documented architectural debt - remediation path: [specific approach]" |

### Transitive Inheritance in Reports

ALL sorries propagate transitively through imports. When reporting on a theorem:

1. **Direct sorries**: Sorries in the theorem's proof
2. **Inherited sorries**: Sorries in any lemma the theorem uses
3. **Publication status**: "Transitively sorry-free" or "Depends on N sorries in [files]"

**Critical**: A theorem claimed as "proven" in a publication MUST be transitively sorry-free.

## Characterizing Axioms in Reports and Plans

When documenting axioms in research reports, implementation plans, or summaries, follow this framing:

**Guiding Principle**: Axioms are technical debt requiring structural proof - never call an axiom acceptable.

### Required Elements

1. **State the fact**: "This file depends on N axioms"
2. **Categorize each**: Which category from the taxonomy below
3. **Explain the reason**: Why does this axiom exist
4. **Specify remediation**: Structural proof approach to eliminate it
5. **Note transitivity**: What inherits this axiom dependency

### Prohibited Framing

Do NOT use these phrases:
- "acceptable axiom" / "axiom is acceptable"
- "axiom-based solution"
- "add axiom to solve"
- "axiom count is acceptable"
- "N acceptable axioms"

### Required Framing

USE these phrases instead:
- "axiom as technical debt"
- "axiom requires structural proof"
- "eliminates need for axiom"
- "zero-axiom approach"
- "axiom to be removed via [specific approach]"
- "inherits axiom dependency"
- "publication requires axiom disclosure or elimination"

### Example Transformations

| Prohibited | Required |
|------------|----------|
| "1 axiom is acceptable" | "1 axiom remains (construction assumption) - documented, requires structural proof" |
| "add axiom to solve this" | "this gap reveals need for completed saturation construction" |
| "acceptable axiom count" | "target: 0 axioms; current: N axioms (categorized in sorry-registry.md)" |
| "axiom-based approach" | "structural proof approach (eliminates axiom dependency)" |

### Transitive Inheritance in Reports

ALL axioms propagate transitively through imports. When reporting on a theorem:

1. **Direct axioms**: Axioms declared in the theorem's module
2. **Inherited axioms**: Axioms in any lemma the theorem uses
3. **Publication status**: "Axiom-free" or "Depends on N axioms in [files] - requires disclosure"

**Critical**: A theorem published without disclosure MUST be transitively axiom-free.

## Sorry Categories

### 1. Construction Assumptions (Tolerated During Development - Technical Debt)
Treated as axiomatic within the current architecture. **This is still mathematical debt that must be documented and tracked.** Example:
```lean
-- Theories/Bimodal/Metalogic/Bundle/Construction.lean
-- In the single-family simplification, we accept this as axiomatic
sorry  -- modal_backward direction
```

### 2. Development Placeholders (Must Resolve)
Temporary gaps with clear resolution paths. Track in `sorry-registry.md`.

### 3. Documentation Examples (Excluded from Counts)
Intentional sorries in `Examples/` or demonstration code. Not counted in metrics.

### 4. Fundamental Obstacles (Boneyard Candidates)
Approaches that cannot work. Must archive to Boneyard with documentation. Example: `IsLocallyConsistent` only captures soundness, not negation-completeness.

## Axiom Categories

### 1. Construction Assumptions (Technical Debt - Requires Structural Proof)
Required by current architecture but should be eliminated via completed construction. Example:
```lean
-- Theories/Bimodal/Metalogic/Bundle/SaturatedConstruction.lean
-- Required by single-family simplification; complete saturation eliminates this
axiom singleFamily_modal_backward_axiom : ...
```

### 2. Existence Assumptions (Technical Debt - Requires Lindenbaum Proof)
Assert existence without proof. Elimination requires Lindenbaum extension or similar. Example:
```lean
-- Asserts existence of saturated world state; proof requires Lindenbaum
axiom someWorldState_exists : ...
```

### 3. Documentation Examples (Excluded from Counts)
Intentional axioms in `Examples/` or demonstration code. Not counted in metrics.

### 4. Fundamental Obstacles (Rare - Archive with Documentation)
Cannot be proven structurally within Lean type system. Must document why and archive if approach is fundamentally flawed.

## Remediation Paths

### Path A: Proof Completion
Fill the gap with valid proof. Preferred when mathematically feasible.

**When to use**: The sorry marks a genuine proof gap, not an architectural issue.

### Path B: Architectural Refactoring
Change approach to avoid the gap entirely.

**When to use**: The sorry or axiom reveals a flawed proof strategy. Example: Task 473 replaced syntactic world states with semantic approach, bypassing negation-completeness issues.

### Path C: Boneyard Archival
Archive fundamentally flawed code with documentation.

**When to use**:
- Multiple sorry/axiom attempts have failed
- The approach is mathematically impossible
- Preserving the learning is valuable

**Requirements**: Document in Boneyard README why the approach failed.

### Path D: Axiom Disclosure (Publication Only)
For publication when axiom cannot be eliminated, explicitly disclose as assumption.

**When to use**:
- Axiom represents genuine mathematical assumption (e.g., Choice)
- Full elimination not feasible within paper scope
- Assumption is standard in the field

**Requirements**: Document axiom in publication, explain why it cannot be proven.

## Discovery Protocol

When encountering proof debt during implementation:

### For Sorries

1. **Check sorry-registry.md** for existing context
2. **Assess category**: Is this a construction assumption, placeholder, or obstacle?
3. **Check transitive impact**: Does your work depend on this sorry?
4. **Decision tree**:
   - Construction assumption: Document reliance and continue
   - Fixable placeholder: Include fix if in scope, or create task
   - Fundamental obstacle: Flag for Boneyard archival
5. **Update registry** if you add or resolve any sorry

### For Axioms

1. **Check sorry-registry.md** for existing axiom documentation
2. **Assess category**: Is this a construction assumption, existence assumption, or documentation?
3. **Check transitive impact**: Does your work inherit this axiom dependency?
4. **Decision tree**:
   - Construction assumption: Document, continue; note need for structural proof
   - Existence assumption: Document, continue; note need for Lindenbaum proof
   - Documentation example: Ignore (excluded from counts)
   - Fundamental obstacle: Document why, consider alternative approaches
5. **Update registry** if you add or resolve any axiom

## Boneyard References

### Primary: `Theories/Bimodal/Boneyard/`
Contains deprecated completeness approaches with comprehensive README documenting:
- Why each approach was deprecated
- Key insights from failed attempts
- Related task numbers for traceability

### Overflow: `Boneyard/`
Root-level location for larger deprecated codebases.

### README Requirements
Every Boneyard addition must include:
- **What it contains**: Files and their purpose
- **Why deprecated**: Fundamental reason (not just "has sorries" or "has axioms")
- **Key insight**: What was learned
- **Related tasks**: For traceability

## Metrics Integration

### sorry_count Computation
Repository health uses this pattern (excludes Boneyard and Examples):
```bash
grep -r "sorry" Theories/ --include="*.lean" | grep -v "/Boneyard/" | grep -v "/Examples/" | wc -l
```

### axiom_count Computation
Repository health uses this pattern (excludes Boneyard and Examples):
```bash
grep -r "^axiom " Theories/ --include="*.lean" | grep -v "/Boneyard/" | grep -v "/Examples/" | wc -l
```

**Note**: Metrics count direct debt only, not transitive inheritance.

### Status Thresholds

#### Sorry Status
| Count | Status | Action |
|-------|--------|--------|
| <100 | good | Maintenance mode |
| 100-299 | manageable | Active reduction |
| >=300 | concerning | Prioritize resolution |

#### Axiom Status
| Count | Status | Action |
|-------|--------|--------|
| 0 | good | Publication-ready (for axiom-free claims) |
| 1-5 | manageable | Document and track; plan structural proofs |
| >5 | concerning | Prioritize elimination; review architecture |

## Usage Checklist

### Sorries
- [ ] No new `sorry` added without sorry-registry.md entry
- [ ] Construction assumptions documented in code comments
- [ ] Transitive dependencies checked for critical proofs
- [ ] Fundamental obstacles archived to Boneyard with README
- [ ] Metrics reflect only active development sorries

### Axioms
- [ ] No new `axiom` added without sorry-registry.md entry
- [ ] Axiom purpose and remediation path documented
- [ ] Transitive dependencies checked (what inherits this axiom?)
- [ ] Structural proof approach identified (even if not yet implemented)
- [ ] Publication status noted (requires disclosure or elimination)
