# Research Report: Task #290

**Task**: 290 - Update context discovery patterns for three-layer architecture
**Generated**: 2026-03-25
**Updated**: 2026-03-25
**Source**: /meta interview (auto-generated), revised after project context audit
**Status**: Pre-populated from interview context, revised

---

## Context Summary

**Purpose**: Update jq queries and discovery patterns for the three-layer context architecture
**Scope**: Modify context discovery to query .claude/context/, .context/, and .memory/
**Affected Components**: Context discovery patterns, agent context loading
**Domain**: meta
**Language**: meta

## Task Requirements

After the restructure, agents discover context from three independent sources loaded in parallel.

### Three-Layer Discovery

| Layer | Index | Path Prefix | Loaded When |
|-------|-------|-------------|-------------|
| Agent context | `.claude/context/index.json` | `.claude/context/` | Always (core + active extensions) |
| Project context | `.context/index.json` | `.context/` | When entries exist |
| Project memory | `.memory/` files | `.memory/` | When files exist |

### Updated Query Patterns

```bash
# Agent context (core + extensions, flattened after task 288)
jq -r '.entries[] | select(.load_when.agents[]? == "planner-agent") |
  ".claude/context/" + .path' .claude/context/index.json

# Project context (user conventions — may be empty)
jq -r '.entries[] | ".context/" + .path' .context/index.json 2>/dev/null

# Project memory (independent, loaded in parallel)
# .memory/ files are loaded directly, no index needed
```

Note: Extension context is merged INTO `.claude/context/index.json` by the extension loader, so it's covered by the first query. No separate extension query needed.

### Simplified from Original Plan

The original plan assumed `.context/` would hold migrated files from `.claude/context/project/`. Since the audit showed those files belong to core or extensions, `.context/` starts empty. Discovery patterns for `.context/` are still needed but will often return no results initially.

### Files to Update

1. **Context discovery pattern documentation**:
   - `.claude/context/patterns/context-discovery.md` (path updated after task 288 flatten)
   - Add three-layer query examples

2. **Agent instructions**:
   - Update context loading instructions in agent definitions
   - Add `.context/` and `.memory/` to discovery documentation

3. **CLAUDE.md Context Discovery section**:
   - Document three-layer architecture
   - Show query patterns for each layer

### Query Helper Function

```bash
#!/bin/bash
# .claude/scripts/query-context.sh
# Usage: query-context.sh --agent planner-agent

query_by_agent() {
  local agent=$1

  # Layer 1: Agent context (core + extensions)
  jq -r --arg a "$agent" '.entries[] | select(.load_when.agents[]? == $a) |
    ".claude/context/" + .path' .claude/context/index.json

  # Layer 2: Project context (if any)
  if [ -f .context/index.json ]; then
    jq -r '.entries[] | ".context/" + .path' .context/index.json
  fi

  # Layer 3: Project memory (loaded in parallel, independent)
  if [ -d .memory ]; then
    find .memory -name "*.md" -type f
  fi
}
```

## Integration Points

- **Component Type**: documentation, scripts
- **Affected Area**: Context discovery system
- **Action Type**: update
- **Related Files**:
  - `.claude/context/patterns/context-discovery.md`
  - `.claude/CLAUDE.md` (Context Discovery section)
  - Agent definition files

## Dependencies

- Task #288: Flatten .claude/context/ structure (paths must be finalized)
- Task #289: Scope extension loader (three-layer architecture must be defined)

## Interview Context

### User-Provided Information
Three independent layers loaded in parallel. Extension context is merged into `.claude/context/` by the loader, so no separate extension query is needed. `.context/` and `.memory/` are independent — neither references the other.

### Effort Assessment
- **Estimated Effort**: 2 hours
- **Complexity Notes**: Simpler than originally scoped since `.context/` starts empty. Mostly documentation and pattern updates.

---

*This research report was auto-generated during task creation via /meta command.*
*Revised 2026-03-25 for three-layer architecture (agent, project, memory).*
*For deeper investigation, run `/research 290 [focus]` with a specific focus prompt.*
