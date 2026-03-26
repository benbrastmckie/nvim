# Research Report: Task #289

**Task**: 289 - Scope extension loader and project context boundaries
**Generated**: 2026-03-25
**Updated**: 2026-03-25
**Source**: /meta interview (auto-generated), revised per user direction
**Status**: Pre-populated from interview context, revised

---

## Context Summary

**Purpose**: Clarify the separation of concerns between agent context (managed by extension loader) and project context (user-managed in .context/)
**Scope**: Extension loader behavior, .context/ directory, .memory/ parallel loading
**Affected Components**: Extension loader Lua code, .context/index.json, agent context discovery
**Domain**: meta
**Language**: meta

## Task Requirements

The context system has three layers with different management strategies:

### 1. Agent Context (.claude/context/) — Managed by Extension Loader

The extension loader **copies and merges** context files into `.claude/context/`. This includes:

- **Core context files**: Agent system patterns, templates, reference docs
- **Extension context files**: Language-specific context from each loaded extension (from `.claude/extensions/*/context/`)

The extension loader's job is to assemble a complete `.claude/context/` directory containing everything the agent system needs. Extensions contribute their context files by copying them into this directory during loading. After task 287, this also includes neovim standards and hooks files that were moved to the nvim extension.

### 2. Project Context (.context/) — User-Managed via index.json

Project-specific conventions live in a top-level `.context/` directory, **outside** `.claude/`. This is for:

- Project-specific conventions (coding style, naming rules)
- Domain knowledge specific to THIS project that no extension covers
- Any project-level information that isn't part of the agent system or an extension

A `.context/index.json` file manages these entries. This directory starts empty and is populated by the user as needed. The extension loader does NOT touch `.context/`.

### 3. Project Memory (.memory/) — Independent, Loaded Alongside .context/

The `.memory/` directory stores persistent information about the project that agents have learned over time. `.context/` and `.memory/` are independent systems — neither manages nor references the other. Both are loaded in parallel when agents need project-specific knowledge: `.context/` provides static conventions and domain standards, while `.memory/` provides dynamic learned information.

### Key Distinction

| Aspect | Agent Context | Project Context | Project Memory |
|--------|--------------|-----------------|----------------|
| Location | `.claude/context/` | `.context/` | `.memory/` |
| Managed by | Extension loader | User via index.json | Agents over time |
| Contains | Core + extension agent files | Project conventions | Learned facts |
| Lifecycle | Rebuilt on extension load | Persistent, user-managed | Persistent, agent-managed |
| Relationship | Independent | Independent | Independent |

All three are loaded in parallel when agents need comprehensive context.

### Changes Required

1. **Extension loader** (keeps current copy/merge behavior):
   - Continues copying core context to `.claude/context/`
   - Continues copying extension context to `.claude/context/` on load
   - No change to current behavior — this is the correct approach

2. **Verify extension loader does NOT touch .context/**:
   - Ensure no code path writes to `.context/`
   - `.context/` is user-managed only

3. **Agent context discovery** (updated for three sources):
   - Core + extension context: read from `.claude/context/` (as today)
   - Project context: query `.context/index.json` (new)
   - Project memory: load `.memory/` files in parallel (existing, independent)

## Integration Points

- **Component Type**: Directory structure, agent loading patterns
- **Affected Area**: Context discovery, extension loading, project configuration
- **Action Type**: clarify and verify
- **Related Files**:
  - Extension loader (Lua code — verify, no changes expected)
  - `.context/index.json` (new, from task 286)
  - `.memory/` directory (existing, independent system)
  - `.claude/context/index.json` (existing, for agent context)

## Dependencies

- Task #288: Flatten .claude/context/ structure (context structure must be stable first)

## Interview Context

### User-Provided Information
The key insight is that context has three audiences: the agent system (core + extensions, managed by the loader), the project (conventions, managed by user via index.json), and project memory (learned facts, managed by agents). The extension loader should continue copying/merging — the change is clarifying that project context lives separately in .context/ with its own index.json. Separately, .memory/ provides dynamic project knowledge. These two project-level systems (.context/ and .memory/) are independent and loaded in parallel — neither manages the other.

### Effort Assessment
- **Estimated Effort**: 2 hours
- **Complexity Notes**: Primarily verification and documentation. Extension loader behavior stays the same. Main work is ensuring the three-layer architecture is correctly reflected in discovery patterns.

---

*This research report was auto-generated during task creation via /meta command.*
*Revised 2026-03-25 to reflect clarified three-layer context architecture.*
*For deeper investigation, run `/research 289 [focus]` with a specific focus prompt.*
