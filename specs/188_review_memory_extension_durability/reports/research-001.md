# Research Report: Task #188

**Task**: 188 - review_memory_extension_durability
**Started**: 2026-03-12T16:30:00Z
**Completed**: 2026-03-12T17:15:00Z
**Effort**: 2-3 hours
**Dependencies**: None
**Sources/Inputs**: Codebase exploration (extension loader, merge module, skill definitions, manifest files)
**Artifacts**: specs/188_review_memory_extension_durability/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Extension loader uses merge-copy semantics for data directories - existing files are NEVER overwritten
- Both Claude and OpenCode extensions target the SAME `.memory/` vault at project root - shared storage by design
- Memory ID format `MEM-{today}-{sequence}` relies on filesystem scanning for sequence generation, which has race condition potential but low practical risk
- MCP server configuration differs between systems (Claude uses port 22360, OpenCode uses port 27124 with API key) - concurrent MCP usage could conflict
- Primary durability risks: concurrent write operations, MCP port collision, and incomplete sequence ID generation algorithm

## Context & Scope

This research investigates durability and reliability concerns for the memory extension system when used across both Claude Code and OpenCode AI systems. The focus areas are:

1. Overwrite risks during extension loading
2. Dual-system storage conflicts (shared `.memory/` vault)
3. Memory ID uniqueness across systems
4. Extension loader behavior and safeguards

## Findings

### 1. Extension Loader Data Directory Behavior

**Location**: `lua/neotex/plugins/ai/shared/extensions/loader.lua`

The extension loader implements **merge-copy semantics** for data directories:

```lua
-- Lines 294-317 from loader.lua
-- Copy data directories (merge-copy semantics - only copy non-existing files)
function M.copy_data_dirs(manifest, source_dir, project_dir)
  -- ...
  for _, rel_path in ipairs(files) do
    local source_path = source_data_path .. "/" .. rel_path
    local target_path = target_data_path .. "/" .. rel_path

    -- Only copy if target file doesn't already exist (preserve user data)
    if vim.fn.filereadable(target_path) ~= 1 then
      -- copy file
    end
  end
end
```

**Key Finding**: Loading either extension will NOT overwrite existing `.memory/` vault content. Only skeleton files that don't exist are copied.

**Conflict Check (Lines 369-391)**: The `check_conflicts()` function explicitly marks data directories with `merge = true` flag, indicating informational (not blocking) conflicts.

### 2. Dual-System Storage Architecture

**Critical Finding**: Both extensions target the SAME `.memory/` directory at project root.

From manifest files:
- `.claude/extensions/memory/manifest.json`: `"data": [".memory"]`
- `.opencode/extensions/memory/manifest.json`: `"data": [".memory"]`

Data directories are copied to `{project_dir}/.memory/`, NOT to `{project_dir}/.claude/.memory/` or `{project_dir}/.opencode/.memory/`. This means:

1. Both systems share the same vault
2. Memories created by one system are visible to the other
3. Index files are shared (`20-Indices/index.md`)
4. Template files are shared (`30-Templates/memory-template.md`)

**Design Intent**: This appears intentional - unified memory across AI systems.

### 3. Memory ID Generation Analysis

**Format**: `MEM-{today}-{sequence}` (e.g., `MEM-2026-03-12-001`)

**Sequence Generation (from SKILL.md)**: The skill file describes the CREATE operation but does NOT specify the sequence generation algorithm in detail. The template uses `MEM-{{date}}-{{sequence}}` placeholders.

**Implicit Algorithm** (inferred from SKILL.md context):
- Scan `.memory/10-Memories/` for existing files
- Extract date and sequence from filenames
- Increment sequence for new memories on same date

**Race Condition Risk**: If Claude Code and OpenCode run simultaneously:
1. Both scan `.memory/10-Memories/`
2. Both see same highest sequence (e.g., 003)
3. Both generate `MEM-2026-03-12-004`
4. Both attempt to write - one overwrites the other

**Risk Assessment**: Medium-low in practice because:
- Memory creation is interactive (user must confirm each segment)
- Unlikely to have two sessions creating memories at the exact same moment
- File write would fail or succeed atomically (no partial corruption)

### 4. MCP Server Configuration Differences

**Claude Extension** (manifest.json):
```json
"mcp_servers": {
  "obsidian-memory": {
    "command": "npx",
    "args": ["-y", "@anthropic-ai/obsidian-claude-code-mcp@latest"],
    "env": {
      "OBSIDIAN_WS_PORT": "22360"
    }
  }
}
```

**OpenCode Extension** (manifest.json):
```json
"mcp_servers": {
  "obsidian-memory": {
    "command": "npx",
    "args": ["-y", "@dsebastien/obsidian-cli-rest-mcp@latest"],
    "env": {
      "OBSIDIAN_API_KEY": "${OBSIDIAN_API_KEY}",
      "OBSIDIAN_PORT": "27124"
    }
  }
}
```

**Key Differences**:
1. Different MCP packages (anthropic vs dsebastien)
2. Different ports (22360 vs 27124)
3. OpenCode requires API key, Claude uses WebSocket

**Conflict Risk**: Low if ports don't conflict. However, if both systems try to connect to Obsidian simultaneously, behavior depends on plugin implementation.

### 5. Extension Loading Flow Analysis

When `<leader>ac` or `<leader>ao` is pressed:

1. `shared/extensions/init.lua` - `manager.load()` is called
2. `loader.copy_data_dirs()` - Copies skeleton files with merge semantics
3. `merge.inject_section()` - Injects EXTENSION.md content into CLAUDE.md/AGENTS.md
4. `state.mark_loaded()` - Records installed files in `extensions.json`

**Protection Mechanisms**:
- Self-loading guard prevents loading into ~/.config/nvim itself
- Merge-copy semantics preserve user data
- Atomic rollback on failure (`pcall` wraps copy+merge operations)

### 6. Skill File Differences

**Claude SKILL.md** references:
- `@.claude/context/project/memory/learn-usage.md`

**OpenCode SKILL.md** references:
- `@.opencode/context/project/memory/learn-usage.md`

Content is nearly identical. Both define the same operations (UPDATE, EXTEND, CREATE) with the same semantics.

### 7. Data Template Comparison

Both extensions provide identical memory templates:
```markdown
---
id: MEM-{{date}}-{{sequence}}
title: "{{title}}"
date: {{date}}
tags: {{tags}}
topic: "{{topic}}"
source: "{{source}}"
last_updated: {{last_updated}}
---
```

Minor differences exist in README files (branding only).

## Identified Risks

### HIGH: Memory ID Collision During Concurrent Write

**Scenario**: Two AI sessions create memories simultaneously on the same day.

**Impact**: One memory overwrites another, causing data loss.

**Current Mitigation**: None explicit.

**Recommendation**: Implement timestamp-based unique ID or atomic sequence file:
```
MEM-{date}-{timestamp_ms}-{random_suffix}
# Example: MEM-2026-03-12-1710256800123-a7b
```

### MEDIUM: Index.md Concurrent Write Conflict

**Scenario**: Both systems update `20-Indices/index.md` simultaneously.

**Impact**: Index corruption or lost entries.

**Current Mitigation**: None.

**Recommendation**:
- Use file locking (flock)
- Or regenerate index from filesystem on each read

### LOW: MCP Server Port Conflict

**Scenario**: Both systems try to spawn MCP servers on same port.

**Impact**: One system fails to connect.

**Current Mitigation**: Different default ports (22360 vs 27124).

**Recommendation**: Document that only one MCP connection should be active at a time.

### LOW: Extension Reload Race

**Scenario**: User reloads extension while memory operation in progress.

**Impact**: Partial state, missing files.

**Current Mitigation**: Atomic rollback in loader.

**Recommendation**: Add operation lock file during memory writes.

## Recommendations

### 1. Unique Memory ID Generation (Priority: HIGH)

Replace `MEM-{date}-{sequence}` with collision-resistant format:
```
MEM-{date}-{unix_ms}-{random_4}
# Example: MEM-2026-03-12-1710256800123-a7b3
```

This eliminates race conditions entirely.

### 2. Atomic Index Updates (Priority: MEDIUM)

Either:
- Use file locking (`flock` in bash, equivalent in Lua)
- Regenerate index.md from filesystem state on each access
- Add retry logic with exponential backoff

### 3. System-Agnostic Documentation (Priority: LOW)

Update `.memory/README.md` to be system-agnostic:
```markdown
# Shared Memory Vault

This vault is shared between Claude Code and OpenCode systems.
Memories created by either system are accessible to both.
```

### 4. MCP Server Usage Documentation (Priority: LOW)

Add documentation clarifying:
- Only one AI system should use MCP at a time
- Fallback grep search works for both systems simultaneously
- Port conflicts are avoided by different default ports

### 5. Consider Vault Locking Mechanism (Priority: LOW)

For paranoid durability:
- Create `.memory/.lock` during write operations
- Other sessions wait or fall back to read-only
- Timeout after 30 seconds

## Context Extension Recommendations

None - this is a meta task about the extension system itself.

## Appendix

### Files Investigated

| File | Purpose |
|------|---------|
| `.claude/extensions/memory/manifest.json` | Claude extension manifest |
| `.opencode/extensions/memory/manifest.json` | OpenCode extension manifest |
| `lua/neotex/plugins/ai/shared/extensions/loader.lua` | Extension file copy engine |
| `lua/neotex/plugins/ai/shared/extensions/merge.lua` | Settings/index merge logic |
| `lua/neotex/plugins/ai/shared/extensions/init.lua` | Public API for loading |
| `.claude/extensions/memory/skills/skill-memory/SKILL.md` | Claude memory skill |
| `.opencode/extensions/memory/skills/skill-memory/SKILL.md` | OpenCode memory skill |

### Key Code Sections

**Merge-copy semantics** (loader.lua:300-301):
```lua
-- Only copy if target file doesn't already exist (preserve user data)
if vim.fn.filereadable(target_path) ~= 1 then
```

**Conflict detection with merge flag** (loader.lua:377-385):
```lua
table.insert(conflicts, {
  category = "data",
  file = data_name,
  path = target_data_dir,
  merge = true, -- Flag indicating this is a merge scenario, not overwrite
})
```

### Search Queries Used

1. `copy_data_dirs|extension.*load` - Extension loader behavior
2. `MEM-.*sequence|memory.*ID` - Memory ID generation
3. `sequence|counter|next.*id` - ID sequence tracking
4. Directory diffs between Claude and OpenCode extension data
