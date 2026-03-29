# Research Report: Task #314

**Task**: 314 - Create spreadsheet-agent
**Generated**: 2026-03-27
**Source**: /meta interview (auto-generated)
**Status**: Pre-populated from interview context

---

## Context Summary

**Purpose**: Create research agent for analyzing cost breakdown files
**Scope**: .claude/extensions/founder/agents/
**Affected Components**: Agent definition
**Domain**: founder extension
**Language**: meta

## Task Requirements

Create spreadsheet-agent.md following the agent template pattern:
- Parse input files (Typst, Markdown, plain text) containing cost data
- Extract structured financial data using forcing questions
- Calculate totals, percentages, and dependency chains
- Generate research report with raw JSON data blocks
- Follow the project-agent.md pattern for structured data collection

## Integration Points

- **Component Type**: Agent
- **Affected Area**: .claude/extensions/founder/agents/
- **Action Type**: Create
- **Related Files**:
  - .claude/extensions/founder/agents/project-agent.md (pattern reference)
  - .claude/extensions/founder/agents/market-agent.md (pattern reference)
  - .claude/context/templates/agent-template.md (template)
  - .claude/extensions/founder/context/project/founder/domain/spreadsheet-frameworks.md (domain context - Task 313)

## Agent Design

### Stage Flow
1. Parse delegation context (file path, task info)
2. Read input file (cost breakdown document)
3. Extract cost categories via pattern matching
4. Ask forcing questions for missing data:
   - Duration (months)
   - Personnel breakdown
   - Cost category allocations
   - Range estimates (min/max)
5. Calculate dependencies and totals
6. Generate research report with JSON data blocks
7. Write metadata file

### Output Format
Research report with:
- Cost summary table
- Category breakdowns
- Monthly/quarterly projections
- Raw JSON for downstream agents

## Dependencies

- Task #313: Requires spreadsheet domain context for cost category taxonomies

## Interview Context

### User-Provided Information
Agent should analyze files like logos-pre-seed-18m.typ and extract structured cost data for spreadsheet generation.

### Effort Assessment
- **Estimated Effort**: 3 hours
- **Complexity Notes**: Moderate-high - requires parsing logic and forcing question design

---

*This research report was auto-generated during task creation via /meta command.*
*For deeper investigation, run `/research 314 [focus]` with a specific focus prompt.*
