# Lean4 Context README

## Purpose
Lean-specific context for Logos. Use these files for language, tooling, tactic patterns, and Lean readability. For proof principles and notation, defer to the canonical Logic context.

## Canonical Sources
- Logic proof conventions: `project/logic/standards/proof-conventions.md`
- Logic notation: `project/logic/standards/notation-standards.md`
- Artifact/status standards: `core/system/artifact-management.md`, `core/standards/status-markers.md`

## Lean-Specific Files
- Standards: `standards/lean4-style-guide.md`, `standards/proof-conventions-lean.md`, `standards/proof-readability-criteria.md`
- Patterns: `patterns/tactic-patterns.md`
- Processes: `processes/end-to-end-proof-workflow.md`, `processes/project-structure-best-practices.md`
- Templates: `templates/definition-template.md`, `templates/new-file-template.md`, `templates/proof-structure-templates.md`
- Tools: `tools/aesop-integration.md`, `tools/leansearch-api.md`, `tools/loogle-api.md`, `tools/lsp-integration.md`, `tools/mcp-tools-guide.md`
- Domain: `domain/dependent-types.md`, `domain/key-mathematical-concepts.md`, `domain/lean4-syntax.md`, `domain/mathlib-overview.md`

## Usage Guidance
- Start with Logic standards for proof principles; layer Lean overlays from this directory.
- Prefer minimal context loads (Level 1/2) per task; include Lean files only when implementing Lean proofs or tactics.
- Keep links pointing to this directory (not legacy `context/lean4` roots).
