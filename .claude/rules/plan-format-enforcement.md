---
paths: specs/**/plans/**
---

# Plan Format Checklist

Full specification: `.claude/context/formats/plan-format.md`

**Required metadata fields**: Task, Status, Effort, Dependencies, Research Inputs, Artifacts, Standards, Type (Markdown block, not YAML frontmatter).

**Required sections**: Overview, Goals & Non-Goals, Risks & Mitigations, Implementation Phases, Testing & Validation, Artifacts & Outputs, Rollback/Contingency.

**Phase heading format**: `### Phase N: {name} [STATUS]` -- status lives ONLY in the heading. Valid markers: `[NOT STARTED]`, `[IN PROGRESS]`, `[COMPLETED]`, `[PARTIAL]`, `[BLOCKED]`. No emojis.
