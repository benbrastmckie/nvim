# Artifact Numbering and Versioning — Full Detail

Reactive companion to `rules/artifact-formats.md`'s compact "Unified Sequential Numbering" and
"Versioning" sections. The eager core keeps the format string, the round concept's one-line
definition, and the per-type one-line versioning rule in full; this file carries the worked
example and the per-type elaboration.

## Unified Sequential Numbering — Round Concept, Full Detail

All artifact types share a single sequence number per task within a "round" of work:

**Round Concept**: A research report starts a new round, and the corresponding plan and summary
share that round's number:
- **Research**: Advances the sequence (reads `next_artifact_number`, uses it, increments).
- **Plan**: Uses current round (`next_artifact_number - 1`).
- **Summary**: Uses current round (`next_artifact_number - 1`).

**Format**: `{NN}_{slug}.md` — e.g. `01_initial-research.md`, `01_implementation-plan.md`,
`01_execution-summary.md`.

**Key Principle**: All artifacts from the same research round share the same base number.

**Example Flow**:
```
Round 1:
  /research 309  -> creates 01_report.md (next_artifact_number becomes 2)
  /plan 309      -> creates 01_plan.md (uses round 1)
  /implement 309 -> creates 01_summary.md (uses round 1)

Round 2 (after blocker/revision):
  /research 309  -> creates 02_report.md (next_artifact_number becomes 3)
  /plan 309      -> creates 02_plan.md (uses round 2)
```

## Versioning — Per-Type Detail

### Research Reports
- `01_initial-research.md`, `02_deep-dive-analysis.md`
- Multiple reports for same task allowed
- Later reports supplement earlier ones

### Plans
- `02_design-approach.md`, `03_revised-design.md`
- A new plan version revises the prior approach
- Previous plan versions are preserved for history (never deleted on revision)

### Summaries
- `04_implementation-summary.md`
- One per completion
- Includes all phases
