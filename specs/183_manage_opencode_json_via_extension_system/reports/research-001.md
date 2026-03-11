# Research Report: Manage opencode.json via Extension System

**Task**: 183 - Manage opencode.json via extension system
**Date**: 2026-03-11
**Focus**: Design fully managed opencode.json with extension lifecycle semantics
**Status**: Research Complete

## Summary

The extension system already has robust merge infrastructure for AGENTS.md, settings.json, and index.json. Adding opencode.json management requires: (1) a base opencode.json template with core agents, (2) a new `opencode_json` merge target type, (3) merge/unmerge functions for the JSON agent definitions, and (4) backup strategy for existing files.

## Current Extension System Architecture

### Merge Target Types (Existing)

| Target Key | Source Format | Target File | Merge Strategy |
|------------|---------------|-------------|----------------|
| `opencode_md` | Markdown | `.opencode/AGENTS.md` | Section injection with markers |
| `settings` | JSON | `.opencode/settings.json` | Deep merge with tracking |
| `index` | JSON | `.opencode/context/index.json` | Array append with dedup |

### Key Implementation Files

- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Main API
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - Merge strategies
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` - File copying
- `lua/neotex/plugins/ai/shared/extensions/state.lua` - State tracking
- `lua/neotex/plugins/ai/shared/extensions/config.lua` - System configuration

### Current Manifest Structure (web extension)

```json
{
  "name": "web",
  "provides": {
    "agents": ["web-implementation-agent.md", "web-research-agent.md"],
    ...
  },
  "merge_targets": {
    "opencode_md": {
      "source": "EXTENSION.md",
      "target": ".opencode/AGENTS.md",
      "section_id": "extension_oc_web"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".opencode/context/index.json"
    }
  }
}
```

## Problem Analysis

### Current State

1. Agent files (e.g., `web-research-agent.md`) are copied to `.opencode/agent/subagents/`
2. AGENTS.md gets extension sections injected with markers
3. **opencode.json is NOT managed** — references to `{file:...}` must be manually configured

### Failure Mode

1. User loads core agent system
2. User loads web extension — agent files installed
3. User reloads core — extension files removed
4. **opencode.json still references deleted files → startup fails**

### Root Cause

opencode.json contains `{file:.opencode/agent/subagents/web-research-agent.md}` references that were manually added. The extension system installs/removes the agent files but doesn't touch opencode.json.

## Proposed Solution

### 1. Base opencode.json Template

Create a core `opencode.json` template that gets installed when the core agent system loads:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "default_agent": "build",
  "agent": {
    "build": {
      "mode": "primary",
      "prompt": "...",
      "tools": {...}
    },
    "plan": {...},
    "task-planner": {
      "prompt": "{file:.opencode/agent/subagents/planner-agent.md}",
      ...
    },
    "general-research": {
      "prompt": "{file:.opencode/agent/subagents/general-research-agent.md}",
      ...
    },
    "general-implementation": {
      "prompt": "{file:.opencode/agent/subagents/general-implementation-agent.md}",
      ...
    },
    "meta-builder": {
      "prompt": "{file:.opencode/agent/subagents/meta-builder-agent.md}",
      ...
    },
    "code-reviewer": {
      "prompt": "...",
      ...
    }
  },
  "command": {...},
  "tools": {...}
}
```

**Core agents** (always present):
- build (primary, inline prompt)
- plan (primary, inline prompt)
- task-planner (file ref to planner-agent.md)
- general-research (file ref)
- general-implementation (file ref)
- meta-builder (file ref)
- code-reviewer (inline prompt)

### 2. New Merge Target: `opencode_json`

Add a new merge target type to extension manifests:

```json
{
  "merge_targets": {
    "opencode_json": {
      "source": "opencode-agents.json",
      "target": "opencode.json",
      "merge_key": "agent"
    }
  }
}
```

Where `opencode-agents.json` contains:

```json
{
  "agent": {
    "web-research": {
      "description": "Research web development tasks",
      "mode": "subagent",
      "prompt": "{file:.opencode/agent/subagents/web-research-agent.md}",
      "tools": {...}
    },
    "web-implementation": {
      "description": "Implement web changes",
      "mode": "subagent",
      "prompt": "{file:.opencode/agent/subagents/web-implementation-agent.md}",
      "tools": {...}
    }
  }
}
```

### 3. Merge Strategy for opencode.json

**On Load**:
1. Read target opencode.json
2. Read extension's opencode-agents.json
3. For each agent key in extension:
   - If key doesn't exist in target → add it
   - Track added keys for unload
4. Write updated opencode.json

**On Unload**:
1. Read target opencode.json
2. Get tracked agent keys from state
3. Remove those keys from `agent` object
4. Write updated opencode.json

**Implementation** (new function in merge.lua):

```lua
function M.merge_opencode_agents(target_path, fragment)
  local target = read_json(target_path) or {}
  target.agent = target.agent or {}

  local tracked_keys = {}

  for key, value in pairs(fragment.agent or {}) do
    if target.agent[key] == nil then
      target.agent[key] = value
      table.insert(tracked_keys, key)
    end
  end

  write_json(target_path, target)
  return true, { keys = tracked_keys }
end

function M.unmerge_opencode_agents(target_path, tracked)
  local target = read_json(target_path) or {}
  if not target.agent then return true end

  for _, key in ipairs(tracked.keys or {}) do
    target.agent[key] = nil
  end

  write_json(target_path, target)
  return true
end
```

### 4. Backup Strategy

**On Core Load**:
1. Check if `opencode.json` exists
2. If exists and not managed:
   - Backup to `opencode.json.user-backup`
   - Log: "Existing opencode.json backed up"
3. Install base template

**Detection of "managed" state**:
Add a marker to managed opencode.json:
```json
{
  "_managed_by": "neotex-extensions",
  "_managed_version": "1.0.0",
  ...
}
```

If `_managed_by` field exists, the file is managed. Otherwise, backup before overwriting.

### 5. Core Agent System Changes

The "core agent system" loader needs to:

1. Copy core agent files to `.opencode/agent/subagents/`
2. **NEW**: Install base `opencode.json` (with backup)
3. Copy other core files (AGENTS.md, context/, etc.)

Location of base template:
- `.opencode/templates/opencode.json` (or similar)

## Files to Modify

### Extension System (Lua)

1. `merge.lua`:
   - Add `merge_opencode_agents()`
   - Add `unmerge_opencode_agents()`

2. `init.lua`:
   - Add `opencode_json` to `process_merge_targets()`
   - Add reverse in `reverse_merge_targets()`

3. `config.lua`:
   - No changes needed (target path from manifest)

### Extension Manifests

Each extension that provides agents needs:

1. New file: `opencode-agents.json` with agent definitions
2. Updated `manifest.json` with `opencode_json` merge target

### Core Agent System

1. Create base template: `.opencode/templates/opencode.json`
2. Update core loader to install template with backup

## Migration Path

### Phase 1: Add Infrastructure

1. Implement merge/unmerge functions
2. Update init.lua to process new merge target
3. Test with manual extension

### Phase 2: Create Base Template

1. Extract core agents from Website's opencode.json
2. Create `.opencode/templates/opencode.json`
3. Update core loader

### Phase 3: Update Extensions

For each extension with agents:
1. Create `opencode-agents.json`
2. Add `opencode_json` to manifest

### Phase 4: Test Full Lifecycle

1. Load core → base opencode.json installed
2. Load web → web agents added
3. Unload web → web agents removed
4. Reload core → back to base state

## Considerations

### Merge Conflicts

If user manually edits opencode.json and adds an agent with the same key as an extension:
- Extension load will skip (key exists)
- This is safe — user's version preserved

### Command and Other Sections

Extensions might want to add commands too. Future extension:
```json
{
  "merge_targets": {
    "opencode_json": {
      "source": "opencode-agents.json",
      "target": "opencode.json",
      "merge_keys": ["agent", "command"]
    }
  }
}
```

For now, focus on `agent` key only.

### Project-Specific Customizations

Users can still add custom agents to opencode.json. The extension system:
- Only manages keys it adds
- Preserves user-added keys
- Tracks what it added for clean removal

## Recommendations

1. **Start with `agent` merging only** — commands can be added later
2. **Use tracked keys pattern** — matches existing settings/index approach
3. **Install base template on core load** — not on first extension load
4. **Backup existing files** — preserve user work
5. **Add `_managed_by` marker** — detect managed vs manual files

## Next Steps

1. Create implementation plan with phased approach
2. Implement merge infrastructure in Lua
3. Create base opencode.json template
4. Update web and other extensions
5. Test full lifecycle
