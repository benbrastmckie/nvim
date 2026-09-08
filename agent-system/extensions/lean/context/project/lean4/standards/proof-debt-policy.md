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

### What Comparator Adds (Advisory Today)

The zero-debt gate above is enforced today by `lean-implementation-agent.md`'s Final
Verification Stage, which runs exactly these checks: a sorry census
(`lean-sorry-census.sh`), a single-line grep for vacuous definitions (`:= True|Unit|trivial
|Trivial`), a grep for `^axiom ` declarations, an unsandboxed `lake build`, and a plan-compliance
spot-check that greps for a declaration named after each plan goal. Each has a specific hole:

- The plan-compliance grep only checks that a declaration NAMED `X` exists — it never checks
  that `X` states what the plan intended. A weakened statement (an added hypothesis, a
  specialized quantifier, a restated weaker claim) passes this gate silently.
- The `^axiom ` grep is a textual match on one source form. It does not see `sorryAx`, axioms
  reached transitively through imports, or axioms `native_decide` introduces.
- The vacuous-definition grep is single-line only; a multi-line vacuous definition requires
  manual review (already noted where the grep is defined).
- `lake build` elaborates but never replays into the kernel, and runs agent-authored Lean
  **unsandboxed**. Elaboration executes arbitrary code (`#eval`, `initialize`, `run_cmd`, macros,
  `native_decide` plugins).

Comparator (`agent-system/extensions/lean/scripts/lean-comparator-run.sh`, invoked via
`--compare`) closes each of these: it verifies that every declaration used in a named theorem's
*statement* is identical between a trusted Challenge and the Solution (closing the
plan-compliance hole), checks the *bodies* of named theorems against a transitive axiom
whitelist (closing the axiom-grep hole), and replays the Solution environment into the Lean
kernel inside a sandboxed build (closing both the vacuous-definition blind spot for the checked
declarations and the unsandboxed-build hole). See
`context/project/lean4/tools/comparator-guide.md` for what a green Comparator result does and
does not certify — in particular, it does not certify definition-hole solutions, and its
guarantee is conditional on assumptions this repository cannot fully verify (e.g. landrun
sandboxing correctly on the host). See
`context/project/lean4/domain/comparator-integration.md` for the clean-room runner's design
record (worktree trust chain, verdict vocabulary, sandbox/guard nesting).

**`--compare` is advisory only today.** A Comparator rejection is recorded and surfaced in the
implementation summary, but it does not set `verification_passed` false, does not downgrade task
status to partial, and does not block completion. The sorry census, the three greps
(plan-compliance, axiom, vacuous-definition), and the unsandboxed `lake build` above therefore
**remain the operative zero-debt gate** for any task
marked `[COMPLETED]` — nothing in this section should be read as describing a hard Comparator
gate that exists today. Promotion of `--compare` to a hard completion gate is a separate, later
decision to be made on evidence from real runs, not something this policy pre-empts.

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
-- FORBIDDEN: "We'll fix this sorry in task {N}"
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
