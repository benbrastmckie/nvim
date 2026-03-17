# Handoff Artifact Schema

## Overview

Handoff artifacts enable graceful context exhaustion recovery by providing minimal, structured context for successor teammates. When a teammate approaches context limits, they write a handoff document that the lead agent uses to spawn a successor.

**Design Principle**: Plan FOR context exhaustion, not against it. Handoffs are expected events, not failures.

## File Location

```
specs/{N}_{SLUG}/handoffs/phase-{P}-handoff-{TIMESTAMP}.md
```

Where:
- `{N}` = Task number (unpadded)
- `{SLUG}` = Task slug in snake_case
- `{P}` = Phase number (unpadded)
- `{TIMESTAMP}` = ISO8601 timestamp (e.g., `20260212T143022Z`)

Example: `specs/259_configure_feature/handoffs/phase-3-handoff-20260212T143022Z.md`

## Directory Structure

```
specs/{N}_{SLUG}/
├── reports/          # Research reports
├── plans/            # Implementation plans
├── summaries/        # Implementation summaries
├── progress/         # Progress tracking files
└── handoffs/         # Handoff artifacts
    ├── phase-2-handoff-20260212T100000Z.md
    ├── phase-2-handoff-20260212T120000Z.md  # Second handoff in same phase
    └── phase-3-handoff-20260212T140000Z.md
```

## Handoff Document Template

The handoff document must be **one screen maximum** (~40 lines). It uses progressive disclosure - successor reads only what they need.

```markdown
# Phase {P} Handoff - {timestamp}

## Immediate Next Action
{Single specific step - not a list. Be concrete about what to do next.}

## Current State
- **File**: {absolute path to file being worked on}
- **Location**: Line {N}, after {function/section name}
- **Work state**: {current state, expected output, or progress indicator}

## Key Decisions Made
1. {Decision}: {Brief rationale (one sentence)}
2. {Decision}: {Brief rationale}

## What NOT to Try
1. {Approach}: {Why it failed (one sentence)}
2. {Approach}: {Why it failed}

## Critical Context (max 5 items)
- {Essential fact 1}
- {Essential fact 2}
- {Essential fact 3}

## References (read only if stuck)
- Plan: {path}, Phase {P}
- Research: {path}, Section {X}
- Related file: {path}
```

### Section Guidelines

**Immediate Next Action**:
- Must be a single, specific step
- Should be actionable without reading anything else
- Example: "Add the error handling block after the validation function"
- NOT: "Continue working on the feature" (too vague)

**Current State**:
- Precise location in the codebase
- Include relevant function/class being modified
- For code: Include expected output or behavior being implemented

**Key Decisions Made**:
- Only decisions that affect the successor's approach
- Include rationale to prevent re-evaluation
- Max 3-4 decisions

**What NOT to Try**:
- Approaches that were attempted and failed
- Include brief reason to prevent retries
- Max 3-4 items

**Critical Context**:
- Facts the successor needs but might not discover
- API names, type constraints, edge cases
- Max 5 items

**References**:
- Paths to documents for deeper context
- Successor reads these ONLY if stuck
- Keep to 2-3 references maximum

## Handoff Artifact Type

Add `handoff` as a valid artifact type in metadata:

```json
{
  "artifacts": [
    {
      "type": "handoff",
      "path": "specs/259_configure_feature/handoffs/phase-3-handoff-20260212T143022Z.md",
      "summary": "Context exhaustion handoff for phase 3 with state and approach constraints"
    }
  ]
}
```

## Integration with partial_progress

When writing a handoff, the metadata file includes `handoff_path` in `partial_progress`:

```json
{
  "status": "partial",
  "partial_progress": {
    "stage": "context_exhaustion_handoff",
    "details": "Approaching context limit. Handoff written with current state.",
    "handoff_path": "specs/259_configure_feature/handoffs/phase-3-handoff-20260212T143022Z.md",
    "phases_completed": 2,
    "phases_total": 4
  }
}
```

## Handoff Triggers

Teammates should write handoffs when:
1. Context estimate reaches ~80% (based on tool call volume and file reads)
2. About to attempt an operation that might push over the limit
3. Completing any objective (natural boundary for clean handoff)
4. Finding themselves re-reading the same context repeatedly (signal of pressure)

## Successor Pattern

Successors read the handoff document, NOT full history. The lead spawns successors with minimal context:

1. **Quick Start**: Immediate Next Action + Current State (read first)
2. **If Stuck**: Key Decisions + What NOT to Try
3. **Escape Hatch**: References section (read only if truly stuck)

## Example: Code Implementation Handoff

```markdown
# Phase 3 Handoff - 20260212T143022Z

## Immediate Next Action
Add the `validate_input` function call before the data processing block on line 145.

## Current State
- **File**: /home/user/project/src/handlers/data_processor.lua
- **Location**: Line 142, inside `process_batch` function
- **Work state**: Input validation framework set up, need to integrate with main processing loop

## Key Decisions Made
1. Use lazy validation: Only validate fields actually accessed - reduces overhead
2. Return early on first error: Fail fast rather than collecting all errors

## What NOT to Try
1. Async validation: Added complexity without performance benefit for typical batch sizes
2. Schema-based validation: Overkill for current field set, can add later if needed

## Critical Context (max 5 items)
- `process_batch` is called from `main_handler` with batches of 100-1000 items
- Validation errors should preserve the item index for debugging
- The `validate_input` function signature is `(item, index) -> bool, string?`

## References (read only if stuck)
- Plan: specs/259_configure_feature/plans/02_implementation-plan.md, Phase 3
- Research: specs/259_configure_feature/reports/01_research-findings.md, Section "Validation Patterns"
```

## Related Documentation

- [Return Metadata Format](return-metadata-file.md) - Metadata schema (includes handoff_path)
- [Progress File Schema](progress-file.md) - Progress tracking
- [Error Handling Rule](../../rules/error-handling.md) - Context exhaustion recovery
