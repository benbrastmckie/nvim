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

**Note**: Status metadata (e.g., `[RESEARCHING]`, `[COMPLETED]`) belongs in TODO.md and state.json only, NOT in research reports. Reports are artifacts that document findings, not workflow state.

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

**Applicability**: Include this section when understanding dependencies or relationships is essential for the research topic. For simple reports or standalone topics, this section may be omitted.

**Purpose**: Provides early orientation on how the research topic fits into the codebase by documenting dependency relationships.

**Fields**:
- **Upstream Dependencies**: Existing modules, functions, or components this builds upon. Example: "Depends on `utils/helpers.lua`, `config/keymaps.lua`"
- **Downstream Dependents**: Existing or planned components that will use this. Example: "Enables `plugins/telescope.lua`, `config/lsp.lua`"
- **Alternative Paths**: Where this provides redundancy or different approaches. Example: "Alternative to the native LSP approach"
- **Potential Extensions**: New directions this enables or suggests. Example: "Could extend to support additional filetypes"

## Timestamps
- Include **Started** timestamp when research/analysis begins
- Include **Completed** timestamp when report is finalized
- Do not use emojis
- Do not include status markers (status tracked in TODO.md and state.json only)

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

**Purpose**: Identifies gaps in project context documentation discovered during research.

**When to Include**: Include this section when research reveals:
- Topics not covered by existing context files
- Outdated or incomplete context documentation
- Recurring patterns that would benefit from documentation

**When to Omit**: Omit this section for:
- Meta tasks (to avoid circular task creation)
- Simple tasks where no context gaps are identified
- Tasks where existing context is sufficient

**Entry Format**:
```markdown
- **Topic**: {specific topic or pattern discovered}
- **Gap**: {what is missing from current context}
- **Recommendation**: {suggested action - create new file or update existing}
```

**Example**:
```markdown
## Context Extension Recommendations

- **Topic**: telescope.nvim advanced picker creation
- **Gap**: No context file covers custom picker implementation patterns
- **Recommendation**: Create `project/neovim/patterns/telescope-pickers.md` or extend `project/neovim/tools/telescope-guide.md`

- **Topic**: Neovim floating window API
- **Gap**: `domain/neovim-api.md` does not cover floating window creation
- **Recommendation**: Add floating window section to `domain/neovim-api.md`
```

**Note**: Context gap task creation is currently disabled. Agents should document gaps in reports for future manual review rather than automatically creating tasks.
