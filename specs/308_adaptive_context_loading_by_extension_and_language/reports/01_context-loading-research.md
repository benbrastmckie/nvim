# Research Report: Task #308

**Task**: 308 - adaptive_context_loading_by_extension_and_language
**Started**: 2026-03-26T00:00:00Z
**Completed**: 2026-03-26T00:30:00Z
**Effort**: Medium (3-5 hours estimated implementation)
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of .claude/context/, .claude/extensions/, Lua loader
**Artifacts**: This report
**Standards**: report-format.md

## Executive Summary

- The context loading system uses `index.json` with `load_when` conditions (agents, languages, commands, always) to filter entries
- Core-index-entries.json contains 95 entries with completely empty `load_when` arrays (all three dimensions empty)
- The merged index.json has been partially updated with proper entries (76 total, only 1 with `always: true`)
- jq queries correctly filter by conditions, but entries with empty arrays are NEVER returned (not "always returned" as stated in task)
- The real issue is that empty arrays mean "never match" not "always match" - these 95 core files are effectively orphaned

## Context & Scope

### What Was Researched

1. Current index.json schema and load_when structure
2. Extension loader behavior (install-extension.sh, loader.lua)
3. jq query patterns used by agents and skills
4. Line counts and budget implications
5. Current state of core vs extension index entries

### Key Discovery: Problem Reversal

**The task description states**: "empty load_when conditions cause ALL context files to load unconditionally"

**Actual behavior**: Empty load_when arrays cause context files to NEVER load via jq queries. The current jq patterns use `select(.load_when.agents[]? == "agent-name")` which only matches entries that have the agent in their array - empty arrays never match.

This means 95 core files (~29,373 lines) are effectively inaccessible via standard query patterns.

## Findings

### 1. Index Schema Structure

**File**: `.claude/context/index.schema.json`

```json
{
  "load_when": {
    "agents": ["array of agent names"],
    "commands": ["array of command names"],
    "languages": ["array of language names"],
    "always": true  // optional - explicit always-load flag
  }
}
```

The schema correctly defines `always: true` as the explicit way to mark universally-loaded files.

### 2. Current Index State

| File | Total Entries | Empty load_when | With always:true |
|------|---------------|-----------------|------------------|
| core-index-entries.json | 95 | 95 (100%) | 0 |
| index.json (merged) | 76 | 2 | 1 (README.md) |

**Discrepancy**: The merged index.json has fewer entries than core-index-entries.json, suggesting a recent regeneration or different source.

### 3. Line Count Analysis

| Category | Line Count |
|----------|------------|
| Core entries with empty load_when | 29,373 lines |
| Current merged index total | 10,968 lines |
| Entries matching `language=meta` | 420 lines |
| Entries with `always: true` | 100 lines |

### 4. Query Patterns in Use

**From agents and skills**:
```bash
# Query by agent - returns ONLY entries with agent in array
jq -r '.entries[] | select(.load_when.agents[]? == "planner-agent") | .path'

# Query by language - returns ONLY entries with language in array
jq -r '.entries[] | select(.load_when.languages[]? == "neovim") | .path'

# Query always-load - returns ONLY entries with always: true
jq -r '.entries[] | select(.load_when.always == true) | .path'
```

**Problem**: No mechanism to return entries with empty arrays. They are effectively invisible.

### 5. Extension Loader Behavior

**File**: `lua/neotex/plugins/ai/shared/extensions/loader.lua`

The Lua loader handles file copying but does NOT perform index merging. Index merging is done by:

**File**: `.claude/scripts/install-extension.sh`

The script:
1. Reads extension's `index-entries.json`
2. Merges into main `index.json` using jq
3. Sets `subdomain` based on extension name
4. Preserves `load_when` from extension entries

### 6. Well-Configured Extensions

Extensions like `typst`, `neovim`, `founder`, and `present` have properly configured `load_when`:
- Every entry specifies at least one language
- Most specify relevant agents
- Some specify commands

Example (typst extension):
```json
{
  "load_when": {
    "languages": ["typst"],
    "agents": ["typst-implementation-agent"]
  }
}
```

## Decisions

### Confirmed Understanding

1. **Empty arrays = never match** (current behavior, correct interpretation)
2. **`always: true` = universal loading** (schema supports this)
3. **Extensions are well-configured** - the issue is core entries only

### Design Implications

The task description's proposed solutions need adjustment:

| Proposed Solution | Assessment |
|-------------------|------------|
| "Change empty-array semantics so empty = never-load" | Already the case - no change needed |
| "Require explicit 'always: true' for universal files" | Correct approach - add to core entries |
| "Language-gate validation warnings" | Valuable - add to extension loader |
| "Context budget system" | Useful enhancement for prioritization |
| "Filter OUT unmatched entries" | Already happening - jq patterns work correctly |

## Recommendations

### 1. Update Core Index Entries

The 95 entries in `core-index-entries.json` need classification into one of:

| Category | Action | Estimated Count |
|----------|--------|-----------------|
| Universal (always needed) | Add `always: true` | ~5-10 files |
| Agent-specific | Add to `load_when.agents` | ~30-40 files |
| Language-specific | Add to `load_when.languages` | ~20-30 files |
| Command-specific | Add to `load_when.commands` | ~20-30 files |

### 2. Implement Tiered Loading

Recommended priority order:
1. `always: true` entries (critical patterns)
2. Agent-match entries
3. Language-match entries
4. Command-match entries

Combined query pattern:
```bash
jq -r '.entries[] |
  select(
    (.load_when.always == true) or
    (.load_when.agents[]? == $agent) or
    (.load_when.languages[]? == $lang) or
    (.load_when.commands[]? == $cmd)
  ) | .path'
```

### 3. Add Budget Enforcement

Line counts already exist in entries. Add budget-aware loading:

```bash
# Calculate budget before loading
jq '[.entries[] | select(...) | .line_count] | add'

# Stop loading when budget exceeded
budget_remaining=5000
while read entry; do
  lines=$(jq -r '.line_count' <<< "$entry")
  if [ $((budget_remaining - lines)) -lt 0 ]; then
    break
  fi
  # Load entry...
  budget_remaining=$((budget_remaining - lines))
done < <(jq -c '.entries[]' index.json)
```

### 4. Add Validation Script

Create `.claude/scripts/validate-index.sh`:
- Warn on entries with all-empty load_when
- Verify all paths exist
- Check for duplicate paths
- Report budget estimates per agent/language

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Breaking existing workflows | Gradual migration with deprecation warnings |
| Over-classification (too restrictive) | Start with broad categories, refine over time |
| Index bloat | Use symlinks for extension entries (already done) |
| Query performance | Keep jq queries simple, avoid nested filters |

## Implementation Scope

### Files to Modify

1. `.claude/context/core-index-entries.json` - Add load_when to all 95 entries
2. `.claude/context/index.json` - Regenerate from core + extensions
3. `.claude/scripts/install-extension.sh` - Add validation warnings
4. `.claude/scripts/validate-index.sh` - Create new validation script
5. Agent files - Update context discovery section with combined query

### Migration Path

1. **Phase 1**: Audit 95 core entries, classify by relevance
2. **Phase 2**: Update core-index-entries.json with load_when
3. **Phase 3**: Add validation to extension installer
4. **Phase 4**: Implement budget-aware loading (optional)

### Estimated Effort

| Phase | Effort |
|-------|--------|
| Classification audit | 1-2 hours |
| Update core entries | 1-2 hours |
| Validation script | 30 minutes |
| Budget system | 1-2 hours (optional) |
| **Total** | 3-5 hours |

## Appendix

### Search Queries Used

```bash
# Count entries by load_when state
jq '[.entries[] | select((.load_when.agents | length) == 0 and ...)]'

# Total line counts
jq '[.entries[] | .line_count] | add'

# Test query patterns
jq -r '.entries[] | select(.load_when.languages[]? == "meta") | .path'
```

### Key Files Referenced

- `.claude/context/index.schema.json` - Schema definition
- `.claude/context/core-index-entries.json` - Core entries (needs updates)
- `.claude/context/index.json` - Merged runtime index
- `.claude/scripts/install-extension.sh` - Extension merger
- `.claude/context/patterns/context-discovery.md` - Query patterns
- `.claude/extensions/*/index-entries.json` - Extension entries (well-configured)
