# Report Artifact Standard

**Scope:** Research, analysis, verification, and review reports produced by /research, /review, /analyze, and related agents.

## Metadata (required)
- **Task**: `{id} - {title}`
- **Started**: `{ISO8601}` when work begins
- **Completed**: `{ISO8601}` when work completes
- **Effort**: `{estimate}`
- **Dependencies**: `{list or None}`
- **Sources/Inputs**: bullet list of inputs consulted
- **Artifacts**: list of produced artifacts (paths)
- **Standards**: status-markers.md, artifact-management.md, tasks.md, this file

**Note**: Status metadata belongs in TODO.md and state.json only, not in reports. Include **Started**/**Completed** timestamps in metadata; do not use emojis.

## Structure
1. **Project Context (optional)** – dependency relationships if applicable (see below).
2. **Executive Summary** – 4-6 bullets.
3. **Context & Scope** – what is being evaluated, constraints.
4. **Findings** – ordered or bulleted list with evidence; include status markers for subsections if phases are tracked.
5. **Decisions** – explicit decisions made.
6. **Recommendations** – prioritized list with owners/next steps.
7. **Risks & Mitigations** – optional but recommended.
8. **Context Extension Recommendations (optional)** – identified gaps in project context documentation.
9. **Appendix** – references, data, links.

## Project Context (optional)

Include when dependency relationships are essential to the research topic. Omit for standalone topics. Fields: **Upstream Dependencies**, **Downstream Dependents**, **Alternative Paths**, **Potential Extensions** -- each a brief list of relevant modules/components.

## Writing Guidance
- Be objective, cite sources/paths.
- Keep headings at most level 3 inside the report.
- Prefer bullet lists over prose for findings/recommendations.
- Group Sources/Inputs by category when >5 items.
- Appendix must not duplicate Findings or Recommendations content.
- Omit code blocks that restate file contents cited by path.
- Ensure lazy directory creation: create `reports/` only when writing the first report file.

## Example Skeleton
```
# Research Report: {title}
- **Task**: {id} - {title}
- **Started**: 2025-12-22T10:00:00Z
- **Completed**: 2025-12-22T13:00:00Z
- **Effort**: 3 hours
- **Dependencies**: None
- **Sources/Inputs**: ...
- **Artifacts**: ...
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report.md

## Project Context (optional)
- **Upstream Dependencies**: `utils/helpers.lua`, `config/base.lua`
- **Downstream Dependents**: Plugin configurations, LSP setup
- **Alternative Paths**: None identified
- **Potential Extensions**: Additional filetype support, new keymaps

## Executive Summary
- ...

## Context & Scope
...

## Findings
- ...

## Decisions
- ...

## Recommendations
- ...

## Risks & Mitigations
- ...

## Context Extension Recommendations
- **Topic**: {topic not covered by existing context}
- **Gap**: {description of missing documentation}
- **Recommendation**: {suggested context file to create or update}

## Appendix
- References: ...
```

## Context Extension Recommendations Section

Include when research reveals undocumented topics, outdated context, or recurring patterns worth capturing. Omit for meta tasks or when no gaps are found. Each entry uses the format: `- **Topic**: ... / **Gap**: ... / **Recommendation**: ...`. Context gap task creation is currently disabled; document gaps for manual review only.
