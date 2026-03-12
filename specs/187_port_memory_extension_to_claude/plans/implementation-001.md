# Implementation Plan: Task #187

- **Task**: 187 - port_memory_extension_to_claude
- **Status**: [NOT STARTED]
- **Effort**: 2-3 hours
- **Dependencies**: None (Task 179 data directory bug already completed)
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**:
  - .claude/context/core/formats/plan-format.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

Port the memory extension from `.opencode/extensions/memory/` to `.claude/extensions/memory/`, adapting all path references, merge targets, and MCP configuration to Claude Code patterns. The research identified 24 files across 6 directories to port, with key transformations including manifest.json merge target updates (opencode_md -> claudemd), removal of settings-fragment.json (Claude Code uses .mcp.json), and a full rewrite of memory-setup.md for Claude Code's MCP approach.

### Research Integration

From research-001.md:
- Task 179 (data directory bug) is COMPLETED, enabling correct `.memory/` placement at repo root
- No /learn command conflict exists in .claude/ commands
- manifest.json requires opencode_md -> claudemd transformation
- settings-fragment.json should be DELETED (not ported)
- memory-setup.md requires full rewrite for Claude Code MCP patterns

## Goals & Non-Goals

**Goals**:
- Port all 23 files (24 minus settings-fragment.json) to .claude/extensions/memory/
- Transform manifest.json to use claudemd merge target
- Update all @-references from .opencode/ to .claude/
- Rewrite memory-setup.md for Claude Code MCP configuration
- Maintain full functionality of /learn command and skill-memory

**Non-Goals**:
- Modifying the .memory/ vault structure (already correct)
- Adding new features to the memory system
- Porting settings-fragment.json (Claude Code uses .mcp.json at project root)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Missed .opencode/ references | Medium | Medium | Run grep verification after port |
| Extension loader incompatibility | High | Low | Follow existing .claude/extensions/nvim/ pattern exactly |
| MCP configuration mismatch | Medium | Low | Document both obsidian-claude-code-mcp and @dsebastien fallback |

## Implementation Phases

### Phase 1: Create Directory Structure and Port Root Files [NOT STARTED]

**Goal**: Establish extension directory structure and port core configuration files

**Tasks**:
- [ ] Create `.claude/extensions/memory/` directory
- [ ] Create subdirectories: `commands/`, `skills/skill-memory/`, `context/`, `context/project/`, `context/project/memory/`, `data/`
- [ ] Port and transform `manifest.json`:
  - Change `opencode_md` -> `claudemd`
  - Change target `.opencode/AGENTS.md` -> `.claude/CLAUDE.md`
  - Change section_id `extension_oc_memory` -> `extension_memory`
  - Remove `settings` merge target entirely
  - Update index target path
- [ ] Port `EXTENSION.md` with @-reference updates (`.opencode/` -> `.claude/`)
- [ ] Port `index-entries.json` (paths already canonical, verify)
- [ ] Port `README.md` (no changes expected)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/memory/manifest.json` - Create with transformations
- `.claude/extensions/memory/EXTENSION.md` - Port with path updates
- `.claude/extensions/memory/index-entries.json` - Port (verify paths)
- `.claude/extensions/memory/README.md` - Port unchanged

**Verification**:
- `jq . .claude/extensions/memory/manifest.json` validates
- `jq . .claude/extensions/memory/index-entries.json` validates
- No `.opencode/` references in ported files: `grep -r ".opencode" .claude/extensions/memory/`

---

### Phase 2: Port Command and Skill Files [NOT STARTED]

**Goal**: Port /learn command and skill-memory definitions

**Tasks**:
- [ ] Port `commands/learn.md` (check for any @-references to update)
- [ ] Port `commands/README.md` (update parent directory link)
- [ ] Port `skills/skill-memory/SKILL.md`:
  - Update context @-references from `@.opencode/context/...` to `@.claude/context/...` or canonical `@project/memory/...`
  - Verify vault paths remain `.memory/` (correct)
  - Verify task directory pattern remains `specs/{NNN}_{SLUG}/`
- [ ] Port `skills/skill-memory/README.md` (update parent link)
- [ ] Create `skills/README.md` if needed

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/memory/commands/learn.md` - Port
- `.claude/extensions/memory/commands/README.md` - Port with link update
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Port with @-reference updates
- `.claude/extensions/memory/skills/skill-memory/README.md` - Port with link update

**Verification**:
- No `.opencode/` references: `grep -r ".opencode" .claude/extensions/memory/commands/ .claude/extensions/memory/skills/`
- Skill file has correct context references

---

### Phase 3: Port Context Documentation [NOT STARTED]

**Goal**: Port context documentation with memory-setup.md full rewrite

**Tasks**:
- [ ] Port `context/README.md` (update navigation links)
- [ ] Port `context/project/memory/README.md` (update navigation)
- [ ] Port `context/project/memory/learn-usage.md` (minor path updates)
- [ ] Port `context/project/memory/knowledge-capture-usage.md` (minor updates)
- [ ] Port `context/project/memory/memory-troubleshooting.md` (update for Claude Code context)
- [ ] **Rewrite** `context/project/memory/memory-setup.md` for Claude Code:
  - Document `obsidian-claude-code-mcp` as primary (WebSocket on port 22360)
  - Document `@dsebastien/obsidian-cli-rest-mcp` as fallback
  - Remove references to `settings.local.json` merge
  - Add `.mcp.json` manual configuration instructions
  - Update testing instructions for Claude Code

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/memory/context/README.md` - Port with link updates
- `.claude/extensions/memory/context/project/memory/README.md` - Port
- `.claude/extensions/memory/context/project/memory/learn-usage.md` - Port
- `.claude/extensions/memory/context/project/memory/knowledge-capture-usage.md` - Port
- `.claude/extensions/memory/context/project/memory/memory-troubleshooting.md` - Port with updates
- `.claude/extensions/memory/context/project/memory/memory-setup.md` - Full rewrite

**Verification**:
- No `.opencode/` references in context files
- memory-setup.md documents both MCP server options
- All navigation links point to correct paths

---

### Phase 4: Port Data Directory [NOT STARTED]

**Goal**: Copy vault skeleton to .claude/extensions/memory/data/

**Tasks**:
- [ ] Copy entire `data/.memory/` structure
- [ ] Update `data/.memory/20-Indices/index.md` topic comment:
  - Change `<!-- System building and .opencode/ changes -->` to `<!-- System building and .claude/ changes -->`
- [ ] Verify all vault subdirectory READMEs (should need no changes)
- [ ] Port `data/README.md` if it exists

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/memory/data/.memory/` - Copy entire structure
- `.claude/extensions/memory/data/.memory/20-Indices/index.md` - Update comment
- `.claude/extensions/memory/data/README.md` - Port if exists

**Verification**:
- All vault subdirectories exist: `00-Inbox/`, `10-Memories/`, `20-Indices/`, `30-Templates/`
- Templates intact: `.memory/30-Templates/memory-template.md` exists
- No `.opencode/` references: `grep -r ".opencode" .claude/extensions/memory/data/`

---

### Phase 5: Verification and Cleanup [NOT STARTED]

**Goal**: Final verification that port is complete and correct

**Tasks**:
- [ ] Run comprehensive grep check: `grep -r ".opencode" .claude/extensions/memory/`
- [ ] Verify manifest.json validates: `jq . .claude/extensions/memory/manifest.json`
- [ ] Verify index-entries.json validates: `jq . .claude/extensions/memory/index-entries.json`
- [ ] Verify EXTENSION.md section_id matches manifest section_id
- [ ] Count files: verify 23 files ported (24 source minus settings-fragment.json)
- [ ] Verify no settings-fragment.json exists in target
- [ ] Test extension structure matches nvim extension pattern

**Timing**: 15 minutes

**Files to verify**:
- All 23 ported files in `.claude/extensions/memory/`

**Verification**:
- Zero `.opencode/` references in any ported file
- All JSON files validate
- File count matches expected (23 files)
- Extension structure mirrors `.claude/extensions/nvim/` pattern

---

## Testing & Validation

- [ ] JSON validation: All .json files parse without errors
- [ ] Reference check: No `.opencode/` paths remain in ported files
- [ ] Structure check: Directory structure matches other .claude extensions
- [ ] Manifest alignment: EXTENSION.md section_id matches manifest
- [ ] Data integrity: Vault skeleton complete with all subdirectories

## Artifacts & Outputs

- `.claude/extensions/memory/` - Complete extension directory
- `.claude/extensions/memory/manifest.json` - Transformed manifest
- `.claude/extensions/memory/EXTENSION.md` - Updated extension documentation
- `.claude/extensions/memory/commands/learn.md` - /learn command definition
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Memory skill definition
- `.claude/extensions/memory/context/project/memory/memory-setup.md` - Rewritten MCP setup guide
- `.claude/extensions/memory/data/.memory/` - Vault skeleton
- `specs/187_port_memory_extension_to_claude/summaries/implementation-summary-YYYYMMDD.md` - Completion summary

## Rollback/Contingency

If port fails or causes issues:
1. Delete `.claude/extensions/memory/` directory
2. Original `.opencode/extensions/memory/` remains unchanged
3. No state.json or TODO.md changes required for rollback
