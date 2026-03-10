# Logic Context README

## Purpose

Canonical proof principles, notation, and strategies for mathematical logic (modal, temporal, epistemic). This directory provides domain knowledge for formal logic research agents.

## Terminology Conventions

### Sentence Letters (Preferred Term)

In all logic documentation, use **"sentence letter"** instead of "propositional atom" or "propositional variable":

| Preferred Term | Avoid | Usage |
|----------------|-------|-------|
| sentence letter | propositional atom | Documentation, comments, descriptions |
| sentence letters | propositional variables | Plural references |
| sentence letter | atomic proposition | When referring to syntax |

**Rationale**: "Sentence letter" is the standard term in philosophical logic and modal logic literature. It clearly indicates a syntactic placeholder for a declarative sentence.

## Directory Structure

| Directory | Content |
|-----------|---------|
| `domain/` | Core concepts: Kripke semantics, metalogic, proof theory, task semantics |
| `processes/` | Proof strategies: modal proofs, temporal proofs, construction patterns |
| `standards/` | Conventions: naming, notation, proof conventions |

## Canonical Files

### Domain Files
- `domain/kripke-semantics-overview.md` - Kripke frame semantics for modal logic
- `domain/metalogic-concepts.md` - Soundness, completeness, decidability
- `domain/proof-theory-concepts.md` - Sequent calculus, natural deduction
- `domain/bilateral-semantics.md` - Bilateral assertion/denial
- `domain/bilateral-propositions.md` - Bilateral proposition structures
- `domain/counterfactual-semantics.md` - Counterfactual conditional semantics
- `domain/lattice-theory-concepts.md` - Lattice structures in logic
- `domain/mereology-foundations.md` - Part-whole relations
- `domain/spatial-domain.md` - Spatial logic
- `domain/task-semantics.md` - Task-based semantics
- `domain/topological-foundations-domain.md` - Topological logic

### Process Files
- `processes/modal-proof-strategies.md` - Modal logic proof patterns
- `processes/temporal-proof-strategies.md` - Temporal logic proof patterns
- `processes/proof-construction.md` - General proof construction
- `processes/verification-workflow.md` - Verification processes

### Standards Files
- `standards/proof-conventions.md` - Proof writing conventions
- `standards/notation-standards.md` - Mathematical notation standards
- `standards/naming-conventions.md` - Identifier naming conventions

## Usage Guidance

- Agents should load this README first to understand available context
- Load specific domain files based on research topic
- Load process files for proof strategy guidance
- Load standards files for convention compliance
