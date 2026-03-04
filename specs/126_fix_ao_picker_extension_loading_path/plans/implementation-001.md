# Implementation Plan: Task #126

**Task**: OC_126 - Fix <leader>ao picker to load extensions into correct subdirectory
**Version**: 001
**Created**: 2026-03-04
**Language**: meta

## Overview

Add `agents_subdir` configuration to the extension system and update the loader module to respect subdirectory paths. This will ensure OpenCode extensions load agents into `agent/subagents/` instead of the incorrect `agents/` directory, while maintaining backward compatibility with Claude's `agents/` structure.

## Phases

### Phase 1: Add agents_subdir to Extension Configuration

**Status**: [NOT STARTED]
**Estimated effort**: 30 minutes

**Objectives**:
1. Add `agents_subdir` parameter to extension config schema
2. Update Claude preset to use `"agents"`
3. Update OpenCode preset to use `"agent/subagents"`

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/config.lua` - Add agents_subdir to M.create(), M.claude(), and M.opencode()

**Steps**:
1. Add `agents_subdir` validation parameter to `M.create()` function
2. Add `agents_subdir` to the returned config table
3. Set `agents_subdir = "agents"` in `M.claude()`
4. Set `agents_subdir = "agent/subagents"` in `M.opencode()`

**Verification**:
- Verify config module returns correct agents_subdir for both Claude and OpenCode presets
- Run tests: `lua/neotex/plugins/ai/shared/extensions/config_spec.lua` (if exists)

---

### Phase 2: Update Loader Functions to Respect agents_subdir

**Status**: [NOT STARTED]
**Estimated effort**: 45 minutes

**Objectives**:
1. Modify `copy_simple_files()` to accept optional target subdirectory override
2. Add logic to use agents_subdir when category is "agents"
3. Ensure backward compatibility (default to category name if agents_subdir not provided)

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` - Update copy_simple_files() to handle agents_subdir

**Steps**:
1. Add optional `agents_subdir` parameter to `copy_simple_files()` signature
2. In the function, check if category is "agents" and agents_subdir is provided
3. If so, construct target path using agents_subdir instead of category name
4. For other categories, continue using category name directly
5. Update function documentation comments

**Verification**:
- Code review shows correct path construction logic
- Unit test shows correct paths are generated for both cases

---

### Phase 3: Wire Configuration Through to Loader Calls

**Status**: [NOT STARTED]
**Estimated effort**: 30 minutes

**Objectives**:
1. Update extension init.lua to pass agents_subdir to loader functions
2. Ensure agents category uses the configured subdirectory path
3. Maintain correct paths for other categories (commands, rules, scripts)

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Update load() function to pass agents_subdir

**Steps**:
1. Access `config.agents_subdir` in the `manager.load()` function
2. When calling `loader_mod.copy_simple_files()` for "agents" category, pass agents_subdir as the target subdirectory
3. Keep other categories (commands, rules) using default behavior
4. Update any error messages or logging that references paths

**Verification**:
- Review shows agents_subdir is correctly passed from config to loader
- Other categories remain unchanged

---

### Phase 4: Test and Validate Both Claude and OpenCode Paths

**Status**: [NOT STARTED]
**Estimated effort**: 1 hour

**Objectives**:
1. Verify Claude extensions still load to `.claude/agents/` (unchanged)
2. Verify OpenCode extensions now load to `.opencode/agent/subagents/`
3. Test extension load, unload, and reload operations
4. Check state file tracking is correct

**Test procedure**:

1. **Claude Test (control group)**:
   - Open a project with `.claude/` directory
   - Load an extension (e.g., `lean`)
   - Verify agents appear in `.claude/agents/`
   - Verify unload removes files from correct location

2. **OpenCode Test (target fix)**:
   - Open a project with `.opencode/` directory
   - Load an extension (e.g., `formal`)
   - Verify agents appear in `.opencode/agent/subagents/` (NOT in `agents/`)
   - Check extension state file tracks correct paths
   - Verify unload removes files from `agent/subagents/`
   - Verify reload works correctly

3. **Edge cases**:
   - Test loading same extension in both systems (different projects)
   - Test unloading extension loaded before the fix (should still work via tracked paths)

**Verification**:
- Both Claude and OpenCode extension loading works correctly
- Files are placed in correct subdirectories
- No regression in existing functionality

---

## Dependencies

- None (self-contained change within existing extension system)

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Breaking existing extension installations | State file tracks full paths; old installations will continue to unload from old paths. Only new loads affected. |
| Misaligned paths between load and unload | Both operations use same config source, so they'll always be consistent within a system. |
| Test environment contamination | Test in isolated project directories; clean up test extensions after verification. |
| Regression in other categories | Only "agents" category affected by change; commands, rules, skills, context, scripts use hardcoded paths still. |

## Success Criteria

- [ ] Extension config includes `agents_subdir` parameter for both Claude and OpenCode
- [ ] Claude preset uses `agents_subdir = "agents"`
- [ ] OpenCode preset uses `agents_subdir = "agent/subagents"`
- [ ] Loader functions respect agents_subdir when copying agent files
- [ ] OpenCode extensions load agents to `agent/subagents/` subdirectory
- [ ] Claude extensions continue loading agents to `agents/` directory (unchanged)
- [ ] Extension unload works correctly for both systems
- [ ] Extension reload works correctly for both systems
