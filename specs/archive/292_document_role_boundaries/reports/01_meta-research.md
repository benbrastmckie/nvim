# Research Report: Task #292

**Task**: 292 - Document role boundaries for .context/, .memory/, extensions, and auto-memory
**Generated**: 2026-03-25
**Updated**: 2026-03-25
**Source**: /meta interview (auto-generated), revised after project context audit
**Status**: Pre-populated from interview context, revised

---

## Context Summary

**Purpose**: Create clear documentation defining the purpose and boundaries of each context/memory layer
**Scope**: Documentation for .claude/context/, .context/, .memory/, extensions, and Claude Code auto-memory
**Affected Components**: Documentation files, CLAUDE.md
**Domain**: meta
**Language**: meta

## Task Requirements

Create comprehensive documentation that clearly defines the four-layer context architecture.

### Role Definitions

| System | Location | Managed By | Purpose | What Belongs Here |
|--------|----------|------------|---------|-------------------|
| `.claude/context/` | .claude/ | Extension loader | Core agent system patterns | Orchestration, formats, standards, templates for agents |
| Extensions | .claude/extensions/*/context/ | Extension loader | Domain-specific knowledge | Language standards, patterns, tools (e.g., nvim standards, lean4 domain docs) |
| `.context/` | Project root | User via index.json | Project conventions | Coding style, naming rules, domain knowledge not covered by extensions |
| `.memory/` | Project root | Agents over time | Learned project facts | Patterns, discoveries, decisions made during development |
| Claude auto-memory | ~/.claude/projects/ | Claude Code | Small behavioral gaps | User preferences, session corrections, behavioral adjustments |

### Key Relationships

- `.claude/context/` and extensions are **coupled** — the extension loader assembles both into `.claude/context/`
- `.context/` and `.memory/` are **independent** — loaded in parallel for project knowledge, neither references the other
- Claude auto-memory is **automatic** — separate from all project-managed systems

### Documentation to Create

1. **`.context/README.md`** (new):
   ```markdown
   # Project Context

   User-defined project conventions. This directory is NOT managed by the
   extension loader or any automated system.

   ## What Belongs Here
   - Project-specific coding conventions
   - Domain knowledge not covered by any extension
   - Standards specific to THIS project

   ## What Does NOT Belong Here
   - Agent system patterns (use .claude/context/)
   - Language-specific knowledge (use extensions)
   - Learned facts from work (use .memory/)
   - User preferences (handled by Claude auto-memory)
   ```

2. **`.memory/README.md`** (update existing):
   - Add role boundary section
   - Clarify: independent from .context/, loaded in parallel

3. **`.claude/context/README.md`** (update):
   - Document that extensions contribute files here via the loader
   - Clarify: agent system patterns + extension domain knowledge

4. **`.claude/CLAUDE.md`** (update):
   - Add "Context Architecture" section explaining all layers
   - Include the decision tree

### Decision Tree for New Content

```
Is this a language-specific standard, pattern, or tool reference?
  -> Yes: Add to the appropriate extension's context/
  -> No: Continue

Is this an agent system pattern (orchestration, format, workflow)?
  -> Yes: .claude/context/
  -> No: Continue

Is this a project convention or domain knowledge not covered by extensions?
  -> Yes: .context/
  -> No: Continue

Is this a fact learned during work (pattern, discovery, decision)?
  -> Yes: .memory/
  -> No: Continue

Is this a user preference or behavioral correction?
  -> Yes: Claude auto-memory (automatic)
  -> No: Probably doesn't need to be stored
```

## Integration Points

- **Component Type**: documentation
- **Affected Area**: README files, CLAUDE.md
- **Action Type**: create/update
- **Related Files**:
  - `.context/README.md` (new)
  - `.memory/README.md`
  - `.claude/context/README.md`
  - `.claude/CLAUDE.md`

## Dependencies

- Task #291: Update CLAUDE.md references (CLAUDE.md must be updated first)

## Interview Context

### User-Provided Information
The key insight is clear separation of concerns across four layers. Extensions own domain-specific knowledge (neovim standards, lean4 patterns, etc.) — this was the major revision from the original plan which assumed those files were "project context." The `.context/` directory is reserved for true project conventions that no extension covers. `.context/` and `.memory/` are independent systems loaded in parallel.

### Effort Assessment
- **Estimated Effort**: 1 hour
- **Complexity Notes**: Straightforward documentation task. Main work is writing clear, helpful content that reflects the four-layer architecture.

---

*This research report was auto-generated during task creation via /meta command.*
*Revised 2026-03-25 to include extensions as a distinct layer and clarify .context/ scope.*
*For deeper investigation, run `/research 292 [focus]` with a specific focus prompt.*
