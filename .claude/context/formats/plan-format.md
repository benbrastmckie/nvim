# Plan Artifact Standard

**Scope:** All plan artifacts produced by /plan, /revise, /implement (phase planning), /review (when drafting follow-on work), and related agents.

## Metadata (Markdown block, required)
- Use a single **Status** field with status markers (`[NOT STARTED]`, `[IN PROGRESS]`, `[BLOCKED]`, `[ABANDONED]`, `[COMPLETED]`) per status-markers.md.
- Do **not** use YAML front matter. Use a Markdown metadata block at the top of the plan.
- Required fields: Task, Status, Effort, Dependencies, Research Inputs, Artifacts, Standards, Type.
- Status timestamps belong where transitions happen (e.g., in phases or a short Started/Completed line under the status). Avoid null placeholder fields.
- Standards must reference this file plus status-markers.md, artifact-management.md, and tasks.md.

### Example Metadata Block
```
# Implementation Plan: {title}
- **Task**: {id} - {title}
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: None
- **Artifacts**: plans/MM_{short-slug}.md
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: markdown
```

## Plan Metadata Schema

Plans may include a `plan_metadata` object in state.json tracking plan characteristics:

```json
{
  "phases": 5,
  "total_effort_hours": 8,
  "complexity": "medium",
  "research_integrated": true,
  "plan_version": 1,
  "reports_integrated": [
    {
      "path": "reports/01_{short-slug}.md",
      "integrated_in_plan_version": 1,
      "integrated_date": "2026-01-05"
    }
  ]
}
```

**Field Descriptions**:
- `phases`: Number of implementation phases in plan
- `total_effort_hours`: Total estimated effort across all phases
- `complexity`: Plan complexity (simple, medium, complex)
- `research_integrated`: Boolean indicating if research was incorporated
- `plan_version`: Plan version number (1 for initial, increments with revisions)
- `reports_integrated`: Array tracking which research reports were integrated into which plan versions

**reports_integrated Schema**:
- `path`: Relative path to research report (e.g., "reports/01_{short-slug}.md")
- `integrated_in_plan_version`: Plan version that integrated this report
- `integrated_date`: Date report was integrated (YYYY-MM-DD format)

**Backward Compatibility**: Plans without `reports_integrated` field use empty array default.

## Structure
1. **Overview** – 2-4 sentences: problem, scope, constraints, definition of done. May include "Research Integration" subsection listing integrated reports.
2. **Goals & Non-Goals** – bullets.
3. **Risks & Mitigations** – bullets.
4. **Implementation Phases** – under `## Implementation Phases` with each phase at level `###` and including a status marker at the end of the heading.
5. **Testing & Validation** – bullets/tests to run.
6. **Artifacts & Outputs** – enumerate expected outputs with paths.
7. **Rollback/Contingency** – brief plan if changes must be reverted.

## Implementation Phases (format)
- Heading: `### Phase N: {name} [STATUS]`
- Under each phase include:
  - **Goal:** short statement
  - **Tasks:** bullet checklist
  - **Timing:** expected duration or window
  - **Owner:** (optional)
  - **Started/Completed/Blocked/Abandoned:** timestamp lines when status changes (ISO8601). Do not leave null placeholders.

## Status Marker Requirements
- Use markers exactly as defined in status-markers.md.
- Every phase starts as `[NOT STARTED]` and progresses through valid transitions.
- Include timestamps when transitions occur; avoid null/empty metadata fields.
- Do not use emojis in headings or markers.

## Writing Guidance
- Keep phases small (1-2 hours each) per task-breakdown guidelines.
- Be explicit about dependencies and external inputs.
- Include lazy directory creation guardrail: commands/agents create the project root and `plans/` only when writing this artifact; do not pre-create `reports/` or `summaries/`.
- Keep language concise and directive; avoid emojis and informal tone.

## Example Skeleton
```
# Implementation Plan: {title}
- **Task**: {id} - {title}
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: None
- **Artifacts**: plans/MM_{short-slug}.md (this file)
- **Standards**: plan.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: markdown

## Overview
{summary}

## Goals & Non-Goals
- **Goals**: ...
- **Non-Goals**: ...

## Risks & Mitigations
- Risk: ... Mitigation: ...

## Implementation Phases
### Phase 1: {name} [NOT STARTED]
- **Goal:** ...
- **Tasks:**
  - [ ] ...
- **Timing:** ...

### Phase 2: ... [NOT STARTED]
...

## Testing & Validation
- [ ] ...

## Artifacts & Outputs
- plans/MM_{short-slug}.md
- summaries/NN_{short-slug}-summary.md

## Rollback/Contingency
- ...
```
