# Implementation Plan: Task 178

- **Task**: 178 - fix_memory_extension_mcp_port
- **Status**: [NOT STARTED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/178_fix_memory_extension_mcp_port/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Fix the memory extension's `--remember` flag by correcting the MCP server port configuration. The research command currently attempts to connect to port 3000, but the Obsidian CLI REST plugin runs on port 27124. This plan addresses port updates, MCP configuration, and documentation requirements.

### Research Integration

Research findings confirm:
1. Port mismatch: research.md uses port 3000, should use 27124
2. Missing MCP configuration in ~/.claude/settings.local.json
3. Need for Obsidian CLI REST plugin setup documentation

## Goals & Non-Goals

**Goals**:
- Update `.opencode/commands/research.md` to use port 27124
- Update `.claude/commands/research.md` to use port 27124 (if applicable)
- Create `~/.claude/settings.local.json` with MCP server configuration
- Document user setup steps for Obsidian CLI REST plugin

**Non-Goals**:
- Installing Obsidian or the plugin (user responsibility)
- Changing MCP protocol implementation
- Modifying the memory extension itself
- Creating new research functionality beyond port fix

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| File already has correct port | Low | Medium | Verify current content before editing |
| Multiple port references | Medium | High | Search for all "3000" occurrences in file |
| settings.local.json already exists | Low | Medium | Append or merge, don't overwrite |
| User doesn't have Obsidian installed | High | Low | Document as prerequisite, not requirement |

## Implementation Phases

### Phase 1: Update .opencode/commands/research.md [NOT STARTED]

**Goal**: Fix MCP server port from 3000 to 27124

**Tasks**:
- [ ] Read `.opencode/commands/research.md` to identify all port 3000 references
- [ ] Search for "localhost:3000" or "127.0.0.1:3000" patterns
- [ ] Update all occurrences to use port 27124
- [ ] Verify changes don't break other URL patterns

**Timing**: 10 minutes

**Files to modify**:
- `.opencode/commands/research.md` - Change port 3000 to 27124 in MCP connection strings

**Verification**:
- grep for "3000" should return no results (or unrelated uses)
- grep for "27124" should show correct MCP references

**Rollback**:
```bash
git checkout .opencode/commands/research.md
```

---

### Phase 2: Update .claude/commands/research.md [NOT STARTED]

**Goal**: Ensure .claude version also uses correct port

**Tasks**:
- [ ] Read `.claude/commands/research.md` to check for MCP port references
- [ ] If port 3000 found, update to 27124
- [ ] If no MCP code exists yet, note for future integration
- [ ] Verify consistency between .opencode and .claude versions

**Timing**: 10 minutes

**Files to modify**:
- `.claude/commands/research.md` - Port 3000 to 27124 (if applicable)

**Verification**:
- Compare .opencode and .claude versions for consistency
- Document any differences in approach

**Rollback**:
```bash
git checkout .claude/commands/research.md
```

---

### Phase 3: Create MCP Configuration [NOT STARTED]

**Goal**: Create settings.local.json with MCP server configuration

**Tasks**:
- [ ] Check if `~/.claude/settings.local.json` exists
- [ ] Create or update file with MCP server config:
  ```json
  {
    "mcpServers": {
      "obsidian-memory": {
        "command": "npx",
        "args": ["-y", "@dsebastien/obsidian-cli-rest-mcp@latest"],
        "env": {
          "OBSIDIAN_API_KEY": "YOUR_API_KEY_HERE",
          "OBSIDIAN_PORT": "27124"
        }
      }
    }
  }
  ```
- [ ] Ensure proper JSON formatting
- [ ] Add comment/header noting this is user-specific config

**Timing**: 10 minutes

**Files to create/modify**:
- `~/.claude/settings.local.json` - Add MCP server configuration

**Verification**:
- Validate JSON syntax: `jq empty ~/.claude/settings.local.json`
- Check mcpServers.obsidian-memory structure is correct

**Rollback**:
```bash
rm ~/.claude/settings.local.json  # if newly created
# OR restore from backup if modified
```

---

### Phase 4: Documentation Update [NOT STARTED]

**Goal**: Document user setup requirements

**Tasks**:
- [ ] Read `.opencode/context/project/memory/memory-setup.md`
- [ ] Add or verify section on Obsidian CLI REST plugin installation
- [ ] Document API key retrieval steps
- [ ] Add verification command examples
- [ ] Link to troubleshooting guide

**Timing**: 15 minutes

**Files to modify**:
- `.opencode/context/project/memory/memory-setup.md` - Add setup documentation

**Verification**:
- Document includes all 3 setup steps from research
- Commands are copy-paste ready
- Links to related docs work

**Rollback**:
```bash
git checkout .opencode/context/project/memory/memory-setup.md
```

---

### Phase 5: Testing and Verification [NOT STARTED]

**Goal**: Verify all fixes work correctly

**Tasks**:
- [ ] Start Obsidian with vault: `obsidian .memory/`
- [ ] Test MCP connection: `curl -H "Authorization: Bearer YOUR_API_KEY" http://127.0.0.1:27124/vault/`
- [ ] Test research with --remember: `/research 20 --remember`
- [ ] Check that memory search returns results (if vault has content)
- [ ] Verify graceful degradation when MCP unavailable

**Timing**: 5 minutes

**Files to verify**:
- All modified files from previous phases
- Connection test output

**Verification**:
- curl command returns valid JSON
- /research command executes without MCP errors
- Memory results included in research when available

---

## Testing & Validation

- [ ] Port 3000 references updated to 27124 in both research.md files
- [ ] settings.local.json exists with correct MCP configuration
- [ ] JSON syntax valid in settings.local.json
- [ ] memory-setup.md includes user setup steps
- [ ] MCP connection test passes with curl
- [ ] /research --remember executes without errors
- [ ] Memory search results appear in research reports when available

## Artifacts & Outputs

- Updated `.opencode/commands/research.md` with port 27124
- Updated `.claude/commands/research.md` with port 27124 (if applicable)
- New/updated `~/.claude/settings.local.json` with MCP config
- Updated `.opencode/context/project/memory/memory-setup.md` with setup docs

## Rollback/Contingency

**Complete Rollback**:
```bash
# Restore all modified files
git checkout .opencode/commands/research.md
git checkout .claude/commands/research.md
git checkout .opencode/context/project/memory/memory-setup.md
rm ~/.claude/settings.local.json  # if created by this plan
```

**Partial Rollback by Phase**:
- Phase 1: `git checkout .opencode/commands/research.md`
- Phase 2: `git checkout .claude/commands/research.md`
- Phase 3: Remove or restore settings.local.json
- Phase 4: `git checkout .opencode/context/project/memory/memory-setup.md`

**Contingency Plans**:
- If port 3000 is used elsewhere legitimately: Document each use case
- If settings.local.json already has other configs: Merge instead of overwrite
- If tests fail: Check Obsidian is running and plugin is enabled

---

## Post-Implementation Checklist

- [ ] All phases completed
- [ ] Git commits created for each phase
- [ ] Testing verification passed
- [ ] Documentation updated
- [ ] Task status updated to completed
- [ ] Implementation summary recorded
