# Lean 4 Proof Conventions

## Overview

Lean-specific proof conventions covering naming, docstrings, tactic hygiene, sorry policy, file structure, and readability.

## Lean-Specific Conventions

### Docstrings and Proof Sketches

- Every public theorem/definition: docstring with statement + semantic interpretation.
- For non-trivial proofs: include a short proof strategy (2-5 bullets) and key lemmas used.
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

- Line length <= 100 characters; indent 2 spaces.
- Use `simp` lemmas locally with selective attributes; avoid broad `simp` pollution.
- Comment intent, not mechanics ("apply modal K distribution" vs. "apply" alone).

### Sorry Policy

- No `sorry` or `admit` in production code.
- If a temporary sorry is unavoidable during local work: add a docstring TODO, then remove before finalizing.

### Tests & Regeneration

- Add/maintain tests when proofs or semantics change.
- After significant refactors, run `lake build` and lint commands.

## Cross-References

- Lean style: `lean4-style-guide.md`
- Tactic patterns: `tactic-patterns.md`
- Proof readability criteria: `proof-readability-criteria.md`

## Usage Checklist

- [ ] Docstrings present with strategy for non-trivial proofs.
- [ ] Naming, indentation, and line length follow Lean style.
- [ ] Tactics are bounded and commented for intent.
- [ ] No `sorry`/`admit` in committed code.
- [ ] Tests/lints planned when proofs change.
