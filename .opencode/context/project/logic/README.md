# Logic Context README

## Purpose
Canonical proof principles, notation, and strategies for Logos logic (modal + temporal). Lean-specific overlays live in `project/lean4/`; this directory is the authoritative source for proof conventions and notation.

## Canonical Files
- Standards: `standards/proof-conventions.md`, `standards/notation-standards.md`, `standards/naming-conventions.md`
- Processes: `processes/modal-proof-strategies.md`, `processes/temporal-proof-strategies.md`, `processes/proof-construction.md`, `processes/verification-workflow.md`
- Domain: `domain/kripke-semantics-overview.md`, `domain/metalogic-concepts.md`, `domain/proof-theory-concepts.md`, `domain/task-semantics.md`

## Lean Overlay Boundaries
- Use this directory for logic principles and notation.
- Use `project/lean4/standards/proof-conventions-lean.md` for Lean syntax/tooling/readability.
- Lean tactics/patterns: `project/lean4/patterns/tactic-patterns.md`.

## Usage Guidance
- Agents should load logic standards for any proof principles; add Lean overlays only when executing Lean code.
- Keep references updated to `project/logic/...` paths (avoid legacy `context/logic` or `lean4` roots).
