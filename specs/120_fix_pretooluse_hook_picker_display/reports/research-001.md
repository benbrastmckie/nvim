# Research Report: Task #120

**Task**: 120 - fix_pretooluse_hook_picker_display
**Started**: 2026-03-03T00:00:00Z
**Completed**: 2026-03-03T00:30:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Local source code analysis (parser.lua, entries.lua, previewer.lua, settings.json)
**Artifacts**: - specs/120_fix_pretooluse_hook_picker_display/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- The `build_hook_dependencies` function in parser.lua uses a regex pattern `([^/%s]+%.sh)` that only matches `.sh` file references in hook commands, causing inline `bash -c '...'` hooks (like the PreToolUse hook) to be invisible in the picker display
- The fix requires two changes: (1) extend `build_hook_dependencies` to detect inline-command hooks and represent them as synthetic entries, and (2) update `create_hooks_entries` to propagate `is_local` for these synthetic entries so the `*` marker displays correctly
- The PreToolUse and PostToolUse events in settings.json both use inline bash commands with no `.sh` file reference, making both events currently invisible in the picker

## Context & Scope

The Telescope-based Claude Commands picker displays hook events grouped under a `[Hook Events]` heading. Each event shows a `*` prefix when any of its hooks are defined in the local project's settings.json. The bug is that events whose hooks use inline `bash -c '...'` commands (rather than referencing `.sh` script files) never get recognized, so they never appear in the picker at all.

## Findings

### Existing Configuration

The project's settings.json at `.claude/settings.json` defines 7 hook events:

| Event | Hook Format | Detected? |
|-------|-------------|-----------|
| PreToolUse | `bash -c '...'` (inline) | No |
| PostToolUse | `bash -c '...'` (inline) | No |
| SessionStart | `bash .claude/hooks/*.sh` (file ref) | Yes |
| Stop | `bash .claude/hooks/*.sh` (file ref) | Yes |
| UserPromptSubmit | `bash .claude/hooks/*.sh` (file ref) | Yes |
| SubagentStop | `bash .claude/hooks/*.sh` (file ref) | Yes |
| Notification | `bash .claude/hooks/*.sh` (file ref) | Yes |

### Root Cause Analysis

The data flow for hook event display is:

```
settings.json
    |
    v
parser.build_hook_dependencies(hooks, settings_path)
    |  - Reads settings.hooks
    |  - For each event -> config -> hooks -> command:
    |      extracts hook_name via: command:match("([^/%s]+%.sh)")
    |      This regex ONLY matches filenames ending in .sh
    |  - Populates hook_events[event_name] = {hook_name1, hook_name2, ...}
    |  - Also populates hook.events for matching hooks
    |
    v
entries.create_hooks_entries(structure)
    |  - Iterates hook_events (only events with non-empty hook lists appear)
    |  - For each event, looks up hooks by name from structure.hooks
    |  - Passes matched hooks to format_hook_event()
    |
    v
entries.format_hook_event(event_name, indent_char, event_hooks)
    |  - Checks if any hook in event_hooks has is_local == true
    |  - Sets prefix to "*" if local hook found, " " otherwise
    |
    v
Display string: "*  ├─ PreToolUse    Before tool execution"
                 or
                 "   ├─ PreToolUse    Before tool execution"
```

**The critical failure point** is at `build_hook_dependencies` line 355:

```lua
local hook_name = hook_config.command:match("([^/%s]+%.sh)")
```

For an inline command like:
```
bash -c 'FILE=$(echo "$CLAUDE_TOOL_INPUT" | jq -r ".file_path // empty" 2>/dev/null); ...'
```

There is no `.sh` filename to match. The regex returns `nil`, so no hook_name is added to `hook_events["PreToolUse"]`. Since `hook_events["PreToolUse"]` stays as an empty table `{}`, and `create_hooks_entries` iterates `hook_events`, the event IS present in the iteration BUT has zero hooks. However, examining the code more carefully:

```lua
hook_events[event_name] = {}  -- Line 349: initialized as empty table

for _, config in ipairs(event_configs) do  -- Line 351
  if config.hooks then  -- Line 352
    for _, hook_config in ipairs(config.hooks) do  -- Line 353
      if hook_config.command then  -- Line 354
        local hook_name = hook_config.command:match("([^/%s]+%.sh)")  -- Line 355
        if hook_name then  -- Line 356
          table.insert(hook_events[event_name], hook_name)  -- Line 357
        end
      end
    end
  end
end
```

So `hook_events["PreToolUse"]` = `{}` (empty array). In `create_hooks_entries`:

```lua
if vim.tbl_count(hook_events) > 0 then  -- Line 503: TRUE (other events populate it)
  ...
  for i, event_name in ipairs(sorted_event_names) do  -- Line 510
    local event_hook_names = hook_events[event_name]  -- Line 511: {} for PreToolUse
    local event_hooks = {}  -- Line 513
    for _, hook_name in ipairs(event_hook_names) do  -- Line 514: never iterates
      ...
    end
    -- event_hooks stays empty
    -- format_hook_event gets empty event_hooks
    -- has_local_hook stays false -> prefix = " "
  end
end
```

So PreToolUse DOES appear in the picker (because `hook_events["PreToolUse"]` is `{}`, not nil), but it shows with a space prefix (not `*`) and with 0 hooks in the previewer. The previewer then shows "Registered Hooks: 0 hook(s)".

**Correction**: Actually, looking again at the data flow -- PreToolUse DOES show in the event list since `hook_events["PreToolUse"]` exists as an empty table. The bug is more precisely:

1. PreToolUse event appears but without the `*` marker (no hooks matched -> no is_local check possible)
2. The previewer shows "Registered Hooks: 0 hook(s)" with no hook details

### Two-Part Problem

**Problem 1**: `build_hook_dependencies` cannot represent inline hooks. There is no `.sh` file to reference, no entry in the `hooks` array, and no name to use for lookup.

**Problem 2**: `format_hook_event` determines `has_local_hook` by checking `hook.is_local` on resolved hook objects. Since inline hooks never create hook objects, there is nothing to check.

### Recommended Fix Approach

The fix should add an **inline hook detection path** in `build_hook_dependencies` that:

1. When the `.sh` regex fails, checks if the command is a non-empty inline command
2. Creates a synthetic hook name representing the inline command (e.g., `"[inline]"` or a descriptor derived from the command)
3. Stores these synthetic names in `hook_events[event_name]`
4. Creates synthetic hook entries that can be resolved in `create_hooks_entries`

**Approach A (Minimal - Recommended)**: Detect inline commands and create synthetic hook entries directly in `build_hook_dependencies`. This keeps changes localized.

```lua
-- In build_hook_dependencies, after the .sh match fails:
if hook_name then
  table.insert(hook_events[event_name], hook_name)
else
  -- Inline command: create synthetic entry
  local inline_name = "[inline:" .. event_name .. ":" .. idx .. "]"
  table.insert(hook_events[event_name], inline_name)
  -- Add synthetic hook to the hooks array
  table.insert(hooks, {
    name = inline_name,
    description = "Inline command hook",
    filepath = settings_path,
    is_local = is_local,  -- determined by which settings file was read
    events = { event_name },
    is_inline = true,
  })
end
```

**Challenge with is_local**: The `build_hook_dependencies` function receives a single `settings_path` but does not know if it is local or global. However, looking at `get_extended_structure` (parser.lua lines 713-717):

```lua
local settings_path = project_dir .. "/" .. base_dir .. "/" .. settings_file
if vim.fn.filereadable(settings_path) ~= 1 then
  settings_path = global_dir .. "/" .. base_dir .. "/" .. settings_file
end
```

This means only ONE settings file is read (local first, then fallback to global). But for the `*` marker to work correctly, we need to know whether the settings file is local or global. The current code only reads one file.

**Recommended approach**: Pass an `is_local` boolean to `build_hook_dependencies` based on which settings file was found, OR determine it within the function by comparing the path to the project directory.

**Approach B (Alternative - More Robust)**: Instead of creating synthetic hooks, modify the detection to work at the event level. Since the purpose is to show `*` when a hook event is defined in the local project's settings.json, we can:

1. In `build_hook_dependencies`, also track which events came from the local settings file
2. Pass this event-level locality information alongside `hook_events`
3. In `format_hook_event`, check event-level locality in addition to hook-level locality

This approach is more robust because it directly answers the question "does this event have configuration in the local settings.json?" rather than trying to map inline commands to synthetic hook objects.

**Recommended Implementation (Approach B)**:

1. Modify `build_hook_dependencies` to also return `event_is_local`:
   ```lua
   -- Return both hook_events and event_locality
   return hook_events, event_is_local
   ```

2. Modify `get_extended_structure` to pass both through the structure:
   ```lua
   hook_events, event_is_local = M.build_hook_dependencies(hooks, settings_path)
   -- ...
   return {
     ...
     hook_events = hook_events,
     event_is_local = event_is_local,
     ...
   }
   ```

3. Modify `format_hook_event` to accept event-level locality:
   ```lua
   local function format_hook_event(event_name, indent_char, event_hooks, is_event_local)
     local has_local_hook = is_event_local or false
     if not has_local_hook and event_hooks then
       for _, hook in ipairs(event_hooks) do
         ...
   ```

4. Modify `create_hooks_entries` to pass locality to `format_hook_event`.

**Combined Approach (A + B, Best)**: Do both:
- Track event-level locality for the `*` marker (solves the display bug)
- Create synthetic inline hook entries for the previewer (so previewer shows hook details)
- Keep the is_local flag on synthetic hooks consistent with the settings file origin

### Implementation Details

**File changes required**:

1. **parser.lua** (`build_hook_dependencies`):
   - Add `is_local` parameter
   - Add inline command detection (fallback when `.sh` match fails)
   - Create synthetic hook entries for inline commands
   - Track event-level locality
   - Return both `hook_events` and `event_is_local`

2. **parser.lua** (`get_extended_structure`):
   - Track whether settings_path is local or global
   - Pass `is_local` to `build_hook_dependencies`
   - Add `event_is_local` to returned structure

3. **entries.lua** (`format_hook_event`):
   - Add `is_event_local` parameter
   - Use it as primary indicator for `*` marker (before checking individual hooks)

4. **entries.lua** (`create_hooks_entries`):
   - Pass `structure.event_is_local` data to `format_hook_event`

5. **previewer.lua** (`preview_hook_event`):
   - Handle synthetic inline hook entries gracefully (show command snippet instead of filepath)

### Synthetic Hook Naming

For inline hooks, use a descriptive synthetic name:
- Format: `[inline]` or `inline-{index}`
- Truncate the command to first 40 chars for display in previewer
- Store the full command string in a `command` field on the synthetic hook

### Settings File Locality Detection

In `get_extended_structure`, the locality is already determined:

```lua
local settings_path = project_dir .. "/" .. base_dir .. "/" .. settings_file
local is_local_settings = vim.fn.filereadable(settings_path) == 1
if not is_local_settings then
  settings_path = global_dir .. "/" .. base_dir .. "/" .. settings_file
end
hook_events = M.build_hook_dependencies(hooks, settings_path, is_local_settings)
```

**Edge case**: When `project_dir == global_dir` (working inside ~/.config/nvim), settings are always "local". This is already handled by similar logic in `parse_with_fallback`.

### Existing Patterns to Follow

The codebase uses a consistent pattern for local/global detection:
- Commands: `command.is_local` set in `parse_with_fallback`
- Skills: `skill.is_local` set in `parse_skills_with_fallback`
- Agents: `agent.is_local` set in `parse_agents_with_fallback`
- Hooks: `hook.is_local` set in `parse_hooks_with_fallback`
- Root files: `root_file.is_local` set in `scan_root_files`

The hook event display should follow the same convention. The `*` prefix means "exists in local project".

## Decisions

- **Approach**: Combined A+B (synthetic hooks for previewer + event-level locality for `*` marker)
- **Synthetic hook naming**: Use `[inline]` prefix with truncated command
- **API change**: `build_hook_dependencies` gets a new `is_local` parameter and returns a second value `event_is_local`
- **Backward compatibility**: The second return value is optional; existing callers that only capture one return value are unaffected

## Risks & Mitigations

- **Risk**: Breaking existing hook detection for `.sh`-based hooks
  - **Mitigation**: The `.sh` regex path is unchanged; inline detection is a fallback that only triggers when the regex returns nil

- **Risk**: Synthetic hook entries confusing other parts of the codebase
  - **Mitigation**: Mark synthetic hooks with `is_inline = true` flag; only `create_hooks_entries` and `preview_hook_event` need to handle them

- **Risk**: Multiple settings files (local + global) both defining the same event
  - **Mitigation**: Current code only reads one settings file (local first, then global fallback). This behavior is preserved. If both need to be merged in the future, the locality tracking already supports it.

## Context Extension Recommendations

- **Topic**: Hook event processing and inline command hooks
- **Gap**: No existing context file documents the hook event data flow or the distinction between file-reference and inline-command hooks
- **Recommendation**: Consider adding a section to the plugin-spec or neovim-api context file documenting the settings.json hook format and the picker's hook event display logic

## Appendix

### Files Analyzed

- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/parser.lua` - Core parser with `build_hook_dependencies` (line 334)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - Entry creation with `format_hook_event` (line 16) and `create_hooks_entries` (line 498)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua` - Preview rendering with `preview_hook_event` (line 319)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` - Directory scanning utilities
- `/home/benjamin/.config/nvim/.claude/settings.json` - Project settings with hook definitions
- `/home/benjamin/.config/nvim/.claude/settings.local.json` - Local settings (no hooks defined)

### Key Code Locations

| Function | File | Line | Purpose |
|----------|------|------|---------|
| `build_hook_dependencies` | parser.lua | 334 | Parses settings.json hooks, extracts hook names |
| `get_extended_structure` | parser.lua | 683 | Orchestrates parsing, determines settings file path |
| `format_hook_event` | entries.lua | 16 | Formats hook event display with `*` prefix |
| `create_hooks_entries` | entries.lua | 498 | Creates picker entries for hook events |
| `preview_hook_event` | previewer.lua | 319 | Renders hook event preview panel |

### Regex Analysis

Current pattern: `([^/%s]+%.sh)`
- `[^/%s]+` - One or more chars that are not `/` or whitespace
- `%.sh` - Literal `.sh`
- This matches: `post-command.sh`, `tts-notify.sh`, `wezterm-notify.sh`
- This does NOT match: `bash -c '...'`, empty strings, commands without `.sh` files
