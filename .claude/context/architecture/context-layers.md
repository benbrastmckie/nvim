# Context Layer Architecture

**Created**: 2026-03-25
**Purpose**: Define the three independent context layers and their management boundaries
**Audience**: Agents, extension loader, system developers

---

## Overview

The system uses three independent context layers. Each has a distinct owner, lifecycle, and query mechanism. They are loaded in parallel when agents need comprehensive knowledge.

## Layer Definitions

| Aspect | Agent Context | Project Context | Project Memory |
|--------|--------------|-----------------|----------------|
| **Location** | `.claude/context/` | `.context/` | `.memory/` |
| **Managed by** | Extension loader | User (via index.json) | Agents over time |
| **Contains** | Core patterns + extension domain knowledge | Project-specific conventions | Learned facts and observations |
| **Lifecycle** | Rebuilt each time extensions are loaded | Persistent, user-edited | Persistent, agent-appended |
| **Query** | `.claude/context/index.json` | `.context/index.json` | Direct file reads |
| **Touched by loader** | Yes (copy + merge) | No | No |

## Layer Details

### 1. Agent Context (.claude/context/)

The extension loader assembles this directory during extension loading:

- **Core files**: Agent system patterns, templates, reference docs (always present)
- **Extension files**: Language-specific context copied from `.claude/extensions/*/context/` during load

The loader calls `copy_context_dirs()` to copy extension context into `.claude/context/` and `append_index_entries()` to merge extension entries into the single `index.json`. After loading, all agent context (core + extensions) is queryable from one index.

All write operations use `target_dir` derived from `config.base_dir` (which is `.claude/`). The loader has no code path that references or writes to `.context/` or `.memory/`.

### 2. Project Context (.context/)

User-managed directory for project-specific conventions not covered by any extension. Governed by its own `index.json` with the same schema as the agent context index.

Starts empty. The user populates it with project conventions (coding style, naming rules, domain terminology) as needed. The extension loader does not touch this directory.

### 3. Project Memory (.memory/)

Agent-managed directory for persistent learned information. Independent from `.context/` -- neither manages nor references the other. Both are loaded in parallel when agents need project knowledge.

## Verification Summary

Confirmed by code review (2026-03-25) of the extension loader source:

- `loader.lua`: All target paths derive from `target_dir` parameter (the `.claude/` base directory). Functions `copy_context_dirs`, `copy_simple_files`, `copy_skill_dirs`, `copy_scripts` all write within this base. `copy_data_dirs` writes to `project_dir` but only for declared data directories, not `.context/`.
- `merge.lua`: `append_index_entries` operates on a `target_path` parameter pointing to `.claude/context/index.json`. No `.context/` references.
- `config.lua`: `base_dir` is set to `.claude` (or `.opencode`). No `.context/` configuration.
- Grep for `.context/` across all 8 files in the extensions module: zero matches.
