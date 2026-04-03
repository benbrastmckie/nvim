---
paths: specs/**/plans/**
---

# Plan Format Checklist

When writing or modifying plan files, verify all requirements below are met.
Full specification: `.claude/context/formats/plan-format.md`

## Required Metadata (Markdown block at top, not YAML frontmatter)

- [ ] **Task**: {id} - {title}
- [ ] **Status**: [NOT STARTED] (use status-markers.md values)
- [ ] **Effort**: estimated duration
- [ ] **Dependencies**: task numbers or "None"
- [ ] **Research Inputs**: report path(s) or "None"
- [ ] **Artifacts**: plans/MM_{short-slug}.md (this file)
- [ ] **Standards**: list of referenced standard files
- [ ] **Type**: language identifier (meta, neovim, general, etc.)

## Required Sections

1. **Overview** -- 2-4 sentences: problem, scope, constraints, definition of done
2. **Goals & Non-Goals** -- bullets
3. **Risks & Mitigations** -- bullets
4. **Implementation Phases** -- see phase format below
5. **Testing & Validation** -- bullets/tests to run
6. **Artifacts & Outputs** -- enumerate expected outputs with paths
7. **Rollback/Contingency** -- brief revert plan

## Phase Format

Each phase under `## Implementation Phases`:

```
### Phase N: {name} [STATUS]
- **Goal:** short statement
- **Tasks:** bullet checklist
- **Timing:** expected duration
- **Depends on:** phase numbers or "none" (optional; absence = sequential)
```

Valid status markers: `[NOT STARTED]`, `[IN PROGRESS]`, `[COMPLETED]`, `[PARTIAL]`, `[BLOCKED]`

Phase status lives ONLY in the heading. Do not add separate Status lines per phase.
Do not use emojis in headings or markers.
