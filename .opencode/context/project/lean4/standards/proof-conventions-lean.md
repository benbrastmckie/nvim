# Lean 4 Proof Conventions (Overlay)

## Overview
Lean-specific overlay that sits on top of the canonical logic conventions in `project/logic/standards/proof-conventions.md`. Use this file for Lean syntax, tooling, readability, and sorry policy guidance; defer to the logic canonical file for proof principles, strategy patterns, and notation rules.

- **Canonical base**: `project/logic/standards/proof-conventions.md`, `project/logic/standards/notation-standards.md`
- **Lean overlays**: naming, docstrings, tactic hygiene, sorry policy, file structure, and readability.
- **Status & Artifacts**: Status markers and artifact handling live in `core/standards/status-markers.md` and `core/system/artifact-management.md` (do not duplicate here).

## Lean-Specific Conventions

### Docstrings and Proof Sketches
- Every public theorem/definition: docstring with statement + semantic interpretation.
- For non-trivial proofs: include a short proof strategy (2–5 bullets) and key lemmas used.
- Prefer tactic mode for readability; term mode is fine when short and clear.

### Naming & Structure
- Use snake_case for theorem and lemma names; keep module namespaces shallow.
- One responsibility per file; avoid >400 lines per file.
- Group related lemmas and expose a concise public API from the module header.

### Tactic Hygiene
- Keep steps small with `have`/`calc`; name intermediates meaningfully.
- Use explicit tactics over opaque automation; when using automation (e.g., `aesop`), bound search and add comments for non-obvious steps.
- Avoid global `open` unless local; prefer `open scoped` for notations.

### Readability
- Line length ≤ 100 characters; indent 2 spaces.
- Use `simp` lemmas locally with selective attributes; avoid broad `simp` pollution.
- Comment intent, not mechanics ("apply modal K distribution" vs. "apply" alone).

### Sorry Policy (Lean)
- No `sorry` or `admit` in main; development branches must document registry links.
- If a temporary sorry is unavoidable during local work: add a docstring TODO and reference `docs/project-info/SORRY_REGISTRY.md`, then remove before merge.

### Tests & Regeneration
- Add/maintain tests in `LogosTest/` when proofs or semantics change.
- After significant refactors, run `lake build`, `lake exe test`, and lint commands.

## Cross-References
- Canonical proof principles and patterns: `project/logic/standards/proof-conventions.md`
- Notation: `project/logic/standards/notation-standards.md`
- Lean style: `project/lean4/standards/lean4-style-guide.md`
- Tactic patterns: `project/lean4/patterns/tactic-patterns.md`
- Proof readability criteria: `project/lean4/standards/proof-readability-criteria.md`

## Usage Checklist
- [ ] Use canonical logic conventions for proof principles; overlay Lean-only items here.
- [ ] Docstrings present with strategy for non-trivial proofs.
- [ ] Naming, indentation, and line length follow Lean style.
- [ ] Tactics are bounded and commented for intent.
- [ ] No `sorry`/`admit` in committed code; registry referenced if used temporarily.
- [ ] Tests/lints planned when proofs change.
