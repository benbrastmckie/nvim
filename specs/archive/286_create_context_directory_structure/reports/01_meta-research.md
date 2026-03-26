# Research Report: Task #286

**Task**: 286 - Create .context/ directory structure and index.json schema
**Generated**: 2026-03-25
**Updated**: 2026-03-25
**Source**: /meta interview (auto-generated), revised after project context audit
**Status**: Pre-populated from interview context, revised

---

## Context Summary

**Purpose**: Create a lightweight .context/ directory for user-defined project conventions
**Scope**: New .context/ directory at project root with index.json schema
**Affected Components**: New directory structure, index schema design
**Domain**: meta
**Language**: meta

## Task Requirements

Create the `.context/` directory for **user-defined project conventions only**. This directory does NOT receive files migrated from `.claude/context/project/` — those files belong to either the core agent system or specific extensions (see task 287 audit).

### What .context/ Is For

- Project-specific conventions (e.g., "we use 4-space indent", "our API naming conventions")
- Domain knowledge specific to THIS project that no extension covers
- User-managed, persistent, not rebuilt by any loader

### What .context/ Is NOT For

- Agent system patterns → `.claude/context/`
- Extension-specific domain knowledge → `.claude/extensions/*/context/`
- Learned facts from work → `.memory/`
- User preferences → Claude auto-memory

### Directory Structure

```
.context/
├── index.json              # Discovery index for project conventions
└── README.md               # Documents purpose and usage
```

The directory starts essentially **empty** (just the schema and README). Content is added by the user as needed.

### index.json Schema Design

```json
{
  "version": "1.0",
  "generated": "ISO8601",
  "scope": "project",
  "entries": []
}
```

Key design points:
- `scope: "project"` to distinguish from core context
- Simpler than `.claude/context/index.json` — no domain/subdomain fields
- Paths are relative to `.context/`
- Agents query this alongside `.memory/` for project-specific knowledge (both independent systems, loaded in parallel)

## Integration Points

- **Component Type**: directory structure, JSON schema
- **Affected Area**: project root, .context/
- **Action Type**: create
- **Related Files**:
  - `.claude/context/index.json` (reference schema)
  - `.claude/context/index.schema.json` (JSON schema definition)

## Dependencies

None — this task is foundational.

## Interview Context

### User-Provided Information
Audit of `.claude/context/project/` revealed that all 17 files belong to either the core agent system (12 files) or the nvim extension (5 files). Zero files are truly project conventions. Therefore `.context/` starts empty and exists for future user-defined conventions. It is loaded alongside `.memory/` — both are independent systems providing project-specific knowledge in parallel.

### Effort Assessment
- **Estimated Effort**: 1 hour (reduced — simpler than originally scoped)
- **Complexity Notes**: Straightforward directory and schema creation. No file migration involved.

---

*This research report was auto-generated during task creation via /meta command.*
*Revised 2026-03-25 after audit showed no project files need migration to .context/.*
*For deeper investigation, run `/research 286 [focus]` with a specific focus prompt.*
