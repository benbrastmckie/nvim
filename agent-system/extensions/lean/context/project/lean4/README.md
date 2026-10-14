# Lean 4 Context

This directory contains context files for Lean 4 theorem prover development.

## Structure

- `domain/` - Lean language fundamentals and Mathlib overview
- `patterns/` - Common proof and tactic patterns
- `tools/` - MCP tools guide, Lake integration
- `standards/` - Style guide and conventions

## Key Files

- `tools/mcp-tools-guide.md` - Essential MCP tool reference (ALWAYS load)
- `patterns/tactic-patterns.md` - Common tactics and when to use them
- `domain/mathlib-overview.md` - Mathlib library organization
- `standards/lean4-style-guide.md` - Coding style conventions
- `domain/hard-mode.md` - `--hard` routing, hard-mode agents, and behavioral contracts
- `tools/comparator-guide.md` - Comparator trust model: what a green result does and does not certify
- `domain/decidability-provenance.md` - What the MSO/Rabin decidability argument may be cited for, and the finite-model vs finite-presentation distinction
- `domain/metadata-trust-surfaces.md` - What an environment extension's rows can and cannot be trusted to record on v4.31.0: the public `persistentEnvExtensionsRef`/`lintersRef` registries, why `meta_imports` is not a trace, `getModuleEntries`' non-degrading `level`, and the verified API/command-kind tables
- `domain/ladder-counter-observables.md` - The five mechanisms that defeat a clipped-coordinate index of a deadline-ladder cell (three against index shapes, two against object-exhibited parameters), the five-part falsification gate each implies, and the parameter-origin rule as a NECESSARY condition (formula-derived clip and threshold; a modulus dominating every letter-definable sub-object period) with its sufficiency OPEN
- `patterns/measurement-harness-strictness.md` - Why a pure `let` binding a timed value floats its evaluation past the second clock read, producing a false `0ms` reading, and how to force it inside the measured window instead
- `context/project/books/patterns/record-maintenance.md` (books extension) - record-editing diagnostics map, for a `lean4`-typed task amending `docs/book-convention*`

## For Research

Load: `tools/mcp-tools-guide.md`, `domain/mathlib-overview.md`

## For Implementation

Load: `tools/mcp-tools-guide.md`, `patterns/tactic-patterns.md`
