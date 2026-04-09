# Implementation Plan: Create meeting format context files

- **Task**: 378 - Create meeting format context files
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/378_meeting_format_context_files/reports/01_meeting-format-research.md
- **Artifacts**: plans/01_meeting-format-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: markdown
- **Lean Intent**: false

## Overview

Create two context files in the founder extension that the meeting-agent will load to guide meeting file generation and CSV tracker updates. The meeting-format template documents the complete YAML frontmatter schema (27 fields) and markdown body structure (10 sections) extracted from the Halcyon and Celero exemplar files. The csv-tracker pattern documents the 22-column CSV schema, field mapping to YAML frontmatter, array encoding rules, and update patterns.

### Research Integration

The research report analyzed two exemplar meeting files and one CSV tracker, extracting:
- Complete 27-field YAML frontmatter schema with types, nested object schemas, and enum values
- 10-section markdown body structure with heading hierarchy
- 22-column CSV schema with exact mapping to frontmatter fields
- File naming convention (YYYY-MM-DD_slug.md) and slug derivation rules
- Field source classification (user-provided, web-researched, agent-computed, defaults)

### Roadmap Alignment

No ROAD_MAP.md found.

## Goals & Non-Goals

**Goals**:
- Create a complete meeting file template that an agent can populate to produce files matching the Halcyon/Celero format exactly
- Create a CSV tracker reference that documents column schema, update patterns, and sync invariants
- Follow the existing founder extension template/pattern conventions (matching contract-analysis.md and contract-review.md style)

**Non-Goals**:
- Building the meeting-agent itself (separate task)
- Modifying the extension manifest or index.json (separate registration step)
- Creating validation logic or tooling around these formats

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Schema drift as more meetings are added | M | M | Document schema as extensible; note that new fields should be added to both template and CSV spec |
| Template too rigid for edge cases | L | L | Use clear placeholder markers and comments indicating optional sections |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Create meeting-format template [COMPLETED]

**Goal**: Create the meeting file template with complete YAML frontmatter schema and markdown body structure.

**Tasks**:
- [ ] Create directory structure if needed: `.claude/extensions/founder/context/project/founder/templates/`
- [ ] Write `meeting-format.md` with the following sections:
  - Title and description (what the template is for, when to use it)
  - Output file format (YYYY-MM-DD_slug.md naming convention with slug derivation rules)
  - Complete YAML frontmatter template in a fenced code block with all 27 fields, type annotations in comments, and placeholder values
  - Nested object schemas for `team[]` and `meetings[]` with field tables
  - Field source classification table (user-provided vs web-researched vs agent-computed vs defaults)
  - Pipeline stage enum values
  - Fit score scale description
  - Complete markdown body template in a fenced code block with all 10 sections and sub-sections
  - Section guidance explaining what goes in each section and what requires research vs comes from notes
  - Pre-delivery validation checklist

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/meeting-format.md` - New file

**Verification**:
- File exists and follows the convention of existing templates (contract-analysis.md style)
- All 27 frontmatter fields documented with types and examples
- All 10 body sections documented with structure guidance
- Placeholder markers are clear and agent-consumable

---

### Phase 2: Create csv-tracker pattern [COMPLETED]

**Goal**: Create the CSV tracker format reference documenting column schema, update patterns, and sync rules.

**Tasks**:
- [ ] Write `csv-tracker.md` in `.claude/extensions/founder/context/project/founder/patterns/` with the following sections:
  - Title and description (what the CSV tracker is, how it relates to meeting files)
  - Complete 22-column schema table with column name, YAML field mapping, type, and format notes
  - Derived columns documentation (Meeting Count, Last Meeting) with computation rules
  - Fields NOT in CSV (frontmatter-only fields) listed for clarity
  - Array encoding rules (YAML arrays joined with ", " for CSV; split on ", " when parsing back)
  - CSV quoting rules (fields containing commas must be quoted)
  - Update patterns:
    - New meeting file created -> add row
    - Existing meeting file updated -> update existing row
    - Derived field recomputation
  - Sync invariants (CSV must always reflect current frontmatter state)
  - Sort order convention (rows sorted by Last Touchpoint descending)
  - Example row showing a complete CSV entry

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/patterns/csv-tracker.md` - New file

**Verification**:
- File exists and follows the convention of existing patterns (contract-review.md style)
- All 22 columns documented with mapping to YAML fields
- Update patterns are clear and actionable for an agent
- Array encoding and quoting rules are explicit

## Testing & Validation

- [ ] Both files exist at their expected paths
- [ ] Template covers all 27 frontmatter fields from the research report
- [ ] CSV pattern covers all 22 columns from the research report
- [ ] Template body structure matches the Halcyon/Celero section hierarchy
- [ ] Files follow the existing founder extension template/pattern conventions

## Artifacts & Outputs

- `.claude/extensions/founder/context/project/founder/templates/meeting-format.md` - Meeting file template
- `.claude/extensions/founder/context/project/founder/patterns/csv-tracker.md` - CSV tracker pattern

## Rollback/Contingency

Both files are new additions with no existing dependencies. Rollback is simply deleting the two files. No other files are modified by this plan.
