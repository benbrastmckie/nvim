# Implementation Summary: Task #183

**Completed**: 2026-03-11
**Duration**: ~45 minutes

## Changes Made

Implemented opencode.json management in the extension system, allowing extensions to add/remove agent definitions during load/unload. The core agent system now installs a base opencode.json template with core agent definitions, and extensions contribute their agent definitions via a new `opencode_json` merge target.

## Files Modified

### Core Lua Modules
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - Added `merge_opencode_agents()` and `unmerge_opencode_agents()` functions for tracked-key merge/unmerge of agent definitions
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Added `opencode_json` processing to `process_merge_targets()` and `reverse_merge_targets()` functions
- `lua/neotex/plugins/ai/opencode/core/init.lua` - Created new file with `install_base_opencode_json()` function for template installation with backup strategy

### Templates
- `.opencode/templates/opencode.json` - Created base template with core agent definitions (build, plan, task-planner, general-research, general-implementation, meta-builder, code-reviewer). Tools use lowercase bool objects (`{"read": true, "write": false}`), not arrays.

### Extension Agent Definitions (11 new files)
- `.claude/extensions/epidemiology/opencode-agents.json`
- `.claude/extensions/filetypes/opencode-agents.json`
- `.claude/extensions/formal/opencode-agents.json`
- `.claude/extensions/latex/opencode-agents.json`
- `.claude/extensions/lean/opencode-agents.json`
- `.claude/extensions/nix/opencode-agents.json`
- `.claude/extensions/nvim/opencode-agents.json`
- `.claude/extensions/python/opencode-agents.json`
- `.claude/extensions/typst/opencode-agents.json`
- `.claude/extensions/web/opencode-agents.json`
- `.claude/extensions/z3/opencode-agents.json`

### Extension Manifests (11 updated files)
- All extension `manifest.json` files updated to include `opencode_json` merge target pointing to their respective `opencode-agents.json`

## Verification

- Merge module loads without errors: Passed
- OpenCode extensions module loads without errors: Passed
- OpenCode core module loads without errors: Passed
- `install_base_opencode_json` installs template: Passed
- Managed state tracked via sidecar file (`opencode.json.managed`): Passed
- `merge_opencode_agents` adds agent keys: Passed
- `unmerge_opencode_agents` removes tracked keys: Passed
- Backup strategy creates `.user-backup` for unmanaged files: Passed
- All JSON files valid (tools as objects, not arrays): Passed
- Template installed automatically on "Load Core Agent System": Passed

## Architecture

### Merge Strategy
- Uses tracked-key merge/unmerge pattern (similar to settings merge)
- Agent keys are added only if they don't exist (no overwrite)
- Unmerge removes only the keys that were previously added
- Supports both `{agent: {...}}` object format and bare object format in source files

### Template Installation
- Checks for sidecar file `opencode.json.managed` to detect managed state
  (opencode schema rejects `_managed_by` as an unrecognized top-level key)
- If file exists and is managed: overwrite with template, recreate sidecar
- If file exists and is not managed: backup to `opencode.json.user-backup`, install template, create sidecar
- If file doesn't exist: install template, create sidecar
- **Automatically triggered** via `on_load_all` callback in opencode picker config

### Extension Lifecycle
- On "Load Core Agent System": `install_base_opencode_json()` runs automatically
- On extension load: `merge_opencode_agents` adds agent definitions to opencode.json
- On extension unload: `unmerge_opencode_agents` removes tracked keys
- Core agents are preserved across extension load/unload cycles

### opencode.json Schema Notes
- `tools` field must be an object with lowercase keys and booleans: `{"read": true, "write": false}`
  Arrays like `["Read", "Write"]` are rejected by opencode schema validation
- `mode` valid values: `"primary"`, `"subagent"`, `"all"` (not `"default"`)
- Top-level unrecognized keys (like `_managed_by`) are rejected by schema validation

## Notes

- Agent definitions in extensions use `{file:.opencode/agent/subagents/...}` paths that reference the location after extension agents are copied
- The `agents_subdir` configuration for OpenCode is `agent/subagents`, so extension agents are copied there
- `opencode.json.managed` sidecar file must be preserved alongside `opencode.json`; deleting it causes the next "Load Core Agent System" to backup and reinstall the template
