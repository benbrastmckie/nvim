# Implementation Plan: Task #192

- **Task**: 192 - bypass_opencode_permission_requests
- **Status**: [NOT STARTED]
- **Effort**: 10 hours
- **Dependencies**: None
- **Research Inputs**: specs/192_bypass_opencode_permission_requests/reports/research-001.md; specs/192_bypass_opencode_permission_requests/reports/research-002.md; specs/192_bypass_opencode_permission_requests/reports/research-003.md
- **Artifacts**: plans/implementation-003.md (this file)
- **Standards**: .opencode/context/core/formats/plan-format.md; .opencode/context/core/standards/status-markers.md; .opencode/context/core/standards/documentation-standards.md; .opencode/context/core/standards/task-management.md
- **Type**: meta
- **Lean Intent**: true

## Overview

This unified plan addresses both root causes of opencode permission requests: (1) plugin-level permission UI that displays permission dialogs, and (2) /tmp/ directory access triggers that generate permission events. The solution combines disabling permission events in opencode.nvim with migrating all temporary file usage from /tmp/ to specs/tmp/ for consistency across both .claude/ and .opencode/ systems.

Claude Code and opencode are completely separate systems with independent permission architectures. The user has Claude Code configured with `--dangerously-skip-permissions` (working correctly), but opencode has no equivalent CLI flag. Permission requests in opencode must be addressed through plugin configuration and eliminating external directory access patterns.

### Research Integration

**Research-001.md (Permission Hooks)**:
Investigated PreToolUse hook mechanism for auto-allowing /tmp/* access. Hooks can return `{"permissionDecision": "allow"}` to bypass permission prompts. This approach was superseded by the cleaner specs/tmp/ migration.

**Research-002.md (specs/tmp/ Migration)**:
Analyzed the remaining 161 occurrences of /tmp/ in .claude/ files that need migration to specs/tmp/. The .opencode/ system was already migrated in task OC_156. Documented file priority groups and migration patterns.

**Research-003.md (Permission System Analysis)**:
Critical finding: Claude Code and opencode are separate systems. The `--dangerously-skip-permissions` flag only affects Claude Code, not opencode. The actual control for opencode permission UI is `events.permissions.enabled` in the plugin configuration. The deprecated `permission_requests = "notify"` setting does not prevent permission dialogs.

## Goals & Non-Goals

**Goals**:
- Disable permission UI in opencode.nvim by setting `events.permissions.enabled = false`
- Remove deprecated `permission_requests = "notify"` setting from opencode.lua
- Migrate all /tmp/ references in .claude/ commands to specs/tmp/
- Migrate all /tmp/ references in .claude/ scripts to specs/tmp/
- Migrate all /tmp/ references in .claude/ skills to specs/tmp/
- Migrate all /tmp/ references in .claude/ hooks to specs/tmp/
- Update documentation to reflect new temporary file patterns
- Ensure both .claude/ and .opencode/ use specs/tmp/ consistently
- Verify no permission prompts occur after implementation

**Non-Goals**:
- Modifying Claude Code configuration (already correctly configured)
- Adding opencode CLI flags (none exist for permission bypass)
- Implementing PreToolUse hooks (superseded by migration approach)
- Changing any logic or functionality beyond paths and settings
- Modifying files outside .claude/ directory (except opencode.lua)
- Creating new temporary file conventions (follow existing pattern)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Operations fail silently after disabling permission UI | Medium | Low | Monitor opencode behavior; permissions can be re-enabled quickly |
| Missed /tmp/ occurrences | Medium | Medium | Comprehensive grep search before and after migration |
| opencode.lua syntax errors | High | Low | Validate Lua syntax before saving; test plugin loads correctly |
| Concurrent file access issues | Low | Low | specs/tmp/ maintains same atomic semantics as /tmp/ |
| User confusion about separate permission systems | High | Medium | Document clearly that Claude Code and opencode are independent |
| Accidentally modifying wrong files | Medium | Low | Use version control; review all changes before committing |

## Implementation Phases

### Phase 1: Disable Permission UI in opencode.nvim [COMPLETED]

**Goal**: Update opencode.nvim plugin configuration to disable permission events

**Tasks**:
- [ ] Read current opencode.lua configuration
- [ ] Change `events.permissions.enabled` from `true` to `false`
- [ ] Remove or comment deprecated `permission_requests = "notify"` setting
- [ ] Validate Lua syntax is correct
- [ ] Reload Neovim configuration
- [ ] Test opencode to verify no permission UI appears

**Timing**: 30 minutes

**Files to modify**:
- `lua/neotex/plugins/ai/opencode.lua` - Line ~104: Change `enabled = true` to `enabled = false`

**Verification**:
- Lua syntax validation passes
- Plugin loads without errors
- opencode.nvim starts without permission dialogs
- `:lua print(vim.inspect(require("opencode.config").opts.events.permissions))` shows `enabled = false`

**Rollback**:
- Change `enabled = false` back to `enabled = true`
- Restore `permission_requests = "notify"` if needed

---

### Phase 2: Backup and Inventory [COMPLETED]

**Goal**: Create backup of affected files and complete inventory of all /tmp/ references

**Tasks**:
- [ ] Run comprehensive grep to find all /tmp/ occurrences in .claude/
- [ ] Create list of files to modify, grouped by priority
- [ ] Backup all files that will be modified
- [ ] Verify specs/tmp/ directory exists and is writable
- [ ] Document current state for rollback purposes

**Timing**: 45 minutes

**Files to modify**:
- Create backup archive of .claude/ directory

**Verification**:
- Backup archive exists and is restorable
- File inventory is complete (161 occurrences found)
- specs/tmp/ exists and has correct permissions (drwxr-xr-x)

---

### Phase 3: Migrate Core Commands [COMPLETED]

**Goal**: Update the most frequently used command files

**Tasks**:
- [ ] Update `.claude/commands/task.md` (9 occurrences of /tmp/)
  - Replace `/tmp/state.json` with `specs/tmp/state.json`
  - Replace jq temp file patterns
- [ ] Update `.claude/commands/todo.md` (3 occurrences)
  - Replace temp jq script patterns like `/tmp/todo_nonmeta_$$.jq`
- [ ] Update `.claude/commands/implement.md` (1 occurrence)
- [ ] Update `.claude/commands/revise.md` (2 occurrences)
- [ ] Validate each file still follows command documentation standards

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/commands/task.md`
- `.claude/commands/todo.md`
- `.claude/commands/implement.md`
- `.claude/commands/revise.md`

**Verification**:
- All 15 occurrences in command files updated
- Commands can be parsed without errors
- No remaining /tmp/ references in command files

---

### Phase 4: Migrate Scripts [COMPLETED]

**Goal**: Update postflight scripts and other shell scripts

**Tasks**:
- [ ] Update `.claude/scripts/postflight-research.sh` (3 occurrences)
- [ ] Update `.claude/scripts/postflight-plan.sh` (3 occurrences)
- [ ] Update `.claude/scripts/postflight-implement.sh` (3 occurrences)
- [ ] Check `.claude/scripts/install-extension.sh` for /tmp/ usage
- [ ] Check `.claude/scripts/uninstall-extension.sh` for /tmp/ usage
- [ ] Ensure all mv operations maintain atomic file semantics

**Timing**: 1 hour

**Files to modify**:
- `.claude/scripts/postflight-research.sh`
- `.claude/scripts/postflight-plan.sh`
- `.claude/scripts/postflight-implement.sh`
- `.claude/scripts/install-extension.sh` (if needed)
- `.claude/scripts/uninstall-extension.sh` (if needed)

**Verification**:
- Scripts are executable after modifications
- All /tmp/ references replaced with specs/tmp/
- Test each script with --help or dry-run if available

---

### Phase 5: Migrate Skills [COMPLETED]

**Goal**: Update skill definitions in SKILL.md files

**Tasks**:
- [ ] Update `.claude/skills/skill-researcher/SKILL.md` (5 occurrences)
- [ ] Update `.claude/skills/skill-implementer/SKILL.md` (4 occurrences)
- [ ] Update `.claude/skills/skill-planner/SKILL.md` (3 occurrences)
- [ ] Update `.claude/skills/skill-status-sync/SKILL.md` (3 occurrences)
- [ ] Verify skill examples still demonstrate correct patterns

**Timing**: 1 hour

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md`
- `.claude/skills/skill-implementer/SKILL.md`
- `.claude/skills/skill-planner/SKILL.md`
- `.claude/skills/skill-status-sync/SKILL.md`

**Verification**:
- All 15 occurrences in skills updated
- Skill documentation is coherent
- Examples use correct paths

---

### Phase 6: Migrate Hooks [NOT STARTED]

**Goal**: Update runtime hook files

**Tasks**:
- [ ] Update `.claude/hooks/tts-notify.sh` (3 occurrences)
  - Replace `/tmp/claude-tts-last-notify`
  - Replace `/tmp/claude-tts-notify.log`
  - Replace `/tmp/claude-tts-$$.wav`
- [ ] Verify hook still functions correctly after path changes

**Timing**: 30 minutes

**Files to modify**:
- `.claude/hooks/tts-notify.sh`

**Verification**:
- Hook file is executable
- All 3 /tmp/ references updated
- Hook can be sourced without errors

---

### Phase 7: Migrate Extensions [NOT STARTED]

**Goal**: Update extension-specific skill files

**Tasks**:
- [ ] Update `.claude/extensions/web/skills/skill-web-research/SKILL.md`
- [ ] Update `.claude/extensions/web/skills/skill-web-implementation/SKILL.md`
- [ ] Update `.claude/extensions/nix/skills/skill-nix-research/SKILL.md`
- [ ] Update `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md`
- [ ] Update `.claude/extensions/nvim/skills/skill-neovim-research/SKILL.md`
- [ ] Update `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md`
- [ ] Update `.claude/extensions/lean/skills/skill-lean-research/SKILL.md`
- [ ] Update `.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md`

**Timing**: 1 hour

**Files to modify**:
- All 8 extension skill files listed above

**Verification**:
- All occurrences in extension files updated
- Extension skill examples are correct

---

### Phase 8: Update Context Documentation [NOT STARTED]

**Goal**: Update pattern and workflow documentation to reflect new paths

**Tasks**:
- [ ] Update `.claude/context/core/patterns/inline-status-update.md`
- [ ] Update `.claude/context/core/patterns/jq-escaping-workarounds.md`
- [ ] Update `.claude/context/core/patterns/file-metadata-exchange.md`
- [ ] Update `.claude/context/core/patterns/postflight-control.md`
- [ ] Update `.claude/context/core/orchestration/preflight-pattern.md`
- [ ] Update `.claude/context/core/orchestration/postflight-pattern.md`
- [ ] Update `.claude/context/core/workflows/preflight-postflight.md`
- [ ] Update `.claude/context/project/processes/research-workflow.md`
- [ ] Update `.claude/context/project/processes/planning-workflow.md`
- [ ] Update `.claude/context/project/processes/implementation-workflow.md`

**Timing**: 1.5 hours

**Files to modify**:
- 10 documentation files listed above

**Verification**:
- All example code uses specs/tmp/ instead of /tmp/
- Documentation is internally consistent
- No /tmp/state.json references remain in docs

---

### Phase 9: Verification and Final Testing [NOT STARTED]

**Goal**: Verify complete implementation and test that no permission prompts occur

**Tasks**:
- [ ] Verify opencode.lua configuration:
  - `events.permissions.enabled` is `false`
  - Deprecated setting removed
  - Plugin loads without errors
- [ ] Run comprehensive grep to confirm zero remaining /tmp/ references in .claude/
- [ ] Test opencode operation:
  - Start opencode.nvim
  - Verify no permission dialogs appear
  - Perform file operations
- [ ] Test /task command (uses state.json operations)
- [ ] Test /research command
- [ ] Test /plan command
- [ ] Verify temporary files are created in specs/tmp/
- [ ] Verify specs/tmp/ files are properly cleaned up
- [ ] Validate all modified files are syntactically correct
- [ ] Compare .claude/ and .opencode/ consistency (both use specs/tmp/)

**Timing**: 1.5 hours

**Files to modify**:
- None (verification only)

**Verification**:
- opencode.lua has correct configuration
- Zero /tmp/ references remain in .claude/ (excluding documentation about external systems)
- No permission prompts appear during opencode operations
- Files are created in correct location (specs/tmp/)
- Both .claude/ and .opencode/ consistently use specs/tmp/
- System functions normally after implementation

---

## Testing & Validation

### Configuration Testing
- [ ] opencode.lua loads without Lua syntax errors
- [ ] `events.permissions.enabled` is set to `false`
- [ ] Deprecated `permission_requests` setting removed
- [ ] Plugin initializes correctly in Neovim

### Migration Testing
- [ ] Phase 2: Complete inventory with 161 occurrences documented
- [ ] Phase 3: All 15 command file occurrences migrated
- [ ] Phase 4: All 9+ script occurrences migrated
- [ ] Phase 5: All 15 skill occurrences migrated
- [ ] Phase 6: All 3 hook occurrences migrated
- [ ] Phase 7: All ~60 extension occurrences migrated
- [ ] Phase 8: All ~40 documentation occurrences updated
- [ ] Phase 9: Zero remaining /tmp/ references in .claude/

### Functional Testing
- [ ] No permission prompts during opencode operations
- [ ] Commands work correctly: /task, /research, /plan, /implement
- [ ] Scripts execute without errors: postflight scripts, hooks
- [ ] Atomic file operations preserved (temp file + mv pattern)
- [ ] Temporary files created in specs/tmp/
- [ ] Temporary files properly cleaned up after operations
- [ ] Rollback plan tested and functional

## Artifacts & Outputs

- `lua/neotex/plugins/ai/opencode.lua` - Updated with disabled permissions
- `.claude/` directory with all /tmp/ references migrated to specs/tmp/
- Backup archive of original .claude/ state
- Migration log documenting all files modified
- Verification report showing:
  - opencode.lua configuration correct
  - Zero remaining /tmp/ references
  - No permission prompts during testing

## Rollback/Contingency

### If opencode.lua changes cause issues:
1. Restore original opencode.lua from version control
2. Or manually change `enabled = false` back to `enabled = true`
3. Reload Neovim configuration
4. Verify opencode functions normally

### If /tmp/ migration causes issues:
1. Stop all operations and assess the issue
2. Restore from backup: Extract backup archive to restore original .claude/ state
3. Verify restoration: Run commands to ensure they work as before
4. Remove backup after confirming stability

### If specific files cause problems:
1. Restore only the problematic files from backup
2. Investigate the specific issue with those files
3. Fix and retry migration for those specific files
4. Keep other migrated files intact

### If permission prompts still appear:
1. Check that specs/tmp/ has correct permissions (755, user-owned)
2. Verify opencode.lua has `events.permissions.enabled = false`
3. Verify files are actually being created in specs/tmp/
4. Check for any remaining /tmp/ references that were missed
5. Consider that some operations may require permissions regardless of UI settings

### If atomic file operations break:
1. Verify specs/tmp/ is on the same filesystem as the target files
2. Check that mv operations use correct paths
3. Ensure temp files are created in correct location before move

## Migration Pattern Reference

### Standard Pattern Being Migrated:
```bash
# Before:
jq '...' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# After:
jq '...' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

### opencode.lua Configuration Change:
```lua
-- Before:
events = {
  enabled = true,
  reload = true,
  permissions = {
    enabled = true,  -- Shows permission UI
    idle_delay_ms = 1000,
  },
},
permission_requests = "notify",  -- DEPRECATED

-- After:
events = {
  enabled = true,
  reload = true,
  permissions = {
    enabled = false,  -- NO PERMISSION UI
  },
},
-- permission_requests removed
```

## Historical Context

This implementation combines findings from three research reports:

1. **Research-001**: Explored PreToolUse hooks as alternative approach
2. **Research-002**: Documented the /tmp/ to specs/tmp/ migration pattern (already done for .opencode/ in task OC_156)
3. **Research-003**: Discovered the critical difference between Claude Code and opencode permission systems, identifying `events.permissions.enabled` as the actual control for opencode permission UI

The specs/tmp/ migration approach was chosen over hooks because it is:
- Simpler and more maintainable
- Already proven in the .opencode/ system
- Eliminates permission triggers at the source
- Requires no ongoing hook maintenance

After this implementation, both agent systems (.claude/ and .opencode/) will:
- Use specs/tmp/ for all temporary files
- Have consistent temporary file conventions
- Minimize permission request triggers

The opencode.nvim plugin will have permission UI disabled, while Claude Code continues to use its --dangerously-skip-permissions flag.
