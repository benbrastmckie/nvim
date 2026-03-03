# Report Artifact Standard

**Scope:** Research, analysis, verification, and review reports produced by /research, /review, /analyze, and related agents.

## Metadata (required)
- **Task**: `{id} - {title}`
- **Started**: `{ISO8601}` when work begins
- **Completed**: `{ISO8601}` when work completes
- **Effort**: `{estimate}`
- **Priority**: `High | Medium | Low`
- **Dependencies**: `{list or None}`
- **Sources/Inputs**: bullet list of inputs consulted
- **Artifacts**: list of produced artifacts (paths)
- **Standards**: status-markers.md, artifact-management.md, tasks.md, this file

**Note**: Status metadata (e.g., `[RESEARCHING]`, `[COMPLETED]`) belongs in specs/TODO.md and specs/state.json only, NOT in research reports. Reports are artifacts that document findings, not workflow state.

## Structure
1. **Executive Summary** – 4-6 bullets.
2. **Context & Scope** – what is being evaluated, constraints.
3. **Findings** – ordered or bulleted list with evidence; include status markers for subsections if phases are tracked.
4. **Decisions** – explicit decisions made.
5. **Recommendations** – prioritized list with owners/next steps.
6. **Risks & Mitigations** – optional but recommended.
7. **Appendix** – references, data, links.

## Timestamps
- Include **Started** timestamp when research/analysis begins
- Include **Completed** timestamp when report is finalized
- Do not use emojis
- Do not include status markers (status tracked in specs/TODO.md and specs/state.json only)

## Writing Guidance
- Be objective, cite sources/paths.
- Keep headings at most level 3 inside the report.
- Prefer bullet lists over prose for findings/recommendations.
- Ensure lazy directory creation: create `reports/` only when writing the first report file.

## Example Skeleton
```
# Research Report: {title}
- **Task**: {id} - {title}
- **Started**: 2025-12-22T10:00:00Z
- **Completed**: 2025-12-22T13:00:00Z
- **Effort**: 3 hours
- **Priority**: High
- **Dependencies**: None
- **Sources/Inputs**: ...
- **Artifacts**: ...
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report.md

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

## Appendix
- References: ...
```
