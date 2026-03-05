# Implementation Plan: Design and Implement `/remember` Command for Intelligent Memory Management

- **Task**: OC_136 - Design and implement `/remember` command for intelligent memory management
- **Status**: [NOT STARTED]
- **Effort**: 7-9 hours
- **Dependencies**: None
- **Research Inputs**: 
  - specs/OC_136_design_and_implement_remember_command_for_intelligent_memory_management/reports/research-001.md
  - specs/OC_136_design_and_implement_remember_command_for_intelligent_memory_management/reports/research-002.md
  - specs/OC_136_design_and_implement_remember_command_for_intelligent_memory_management/reports/research-003.md
  - specs/OC_136_design_and_implement_remember_command_for_intelligent_memory_management/reports/research-004.md
- **Artifacts**: plans/implementation-003.md (this file)
- **Standards**:
  - .opencode/context/core/formats/plan-format.md
  - .opencode/context/core/standards/status-markers.md
  - .opencode/context/core/standards/documentation-standards.md
  - .opencode/context/core/standards/task-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This implementation plan creates a simple-but-effective memory management system using an Obsidian-compatible vault at `.opencode/memory/`. The approach leverages MCP (Model Context Protocol) servers for lookup and storage, avoiding complex custom indexing. The system provides a `/remember` command that accepts text or file paths, analyzes content, compares with existing memories, and proposes additions via interactive checkbox confirmation (similar to the `/learn` command pattern).

**Core Philosophy**: Start simple, get it working, then iterate. Phase 1 delivers minimal viable functionality; future phases can add advanced features like auto-tagging and semantic search.

### Research Integration

**research-001.md**: Comprehensive analysis of memory management patterns, identifying key requirements for content analysis, deduplication, and interactive workflows.

**research-002.md**: Analysis of OC_135 revert impact revealing that skills must use direct execution pattern (like skill-learn) rather than thin wrapper + agent delegation. This informs the skill architecture.

**research-003.md**: Obsidian integration research showing advantages of plain Markdown, bidirectional links, and AI ecosystem compatibility. Recommends hybrid indexing for vaults under 1,000 memories.

**research-004.md**: Simplified design specification recommending `.opencode/memory/` vault structure, MCP server integration, `--remember` flag for `/research`, and minimal viable implementation.

## Goals & Non-Goals

### Goals
- [ ] Create `.opencode/memory/` vault with proper Obsidian configuration
- [ ] Implement `/remember` command with checkbox-based interactive confirmation
- [ ] Support adding new memories and updating existing similar memories
- [ ] Integrate with MCP server for memory search and retrieval
- [ ] Add `--remember` flag to `/research` command for memory-augmented research

### Non-Goals
- Complex custom indexing systems (use MCP built-in search)
- Automatic content analysis and tagging (Phase 2+)
- Semantic search and vector embeddings (Phase 3+)
- PARA method integration (Phase 4+)
- Memory freshness scoring (Phase 5+)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| MCP server not available | High | Medium | Graceful degradation - skip memory search, proceed with direct file access |
| User doesn't have Obsidian | High | Low | Document Obsidian requirement; direct file access still works without MCP |
| Vault grows beyond 1,000 memories | Medium | Low | Document best practices for manual organization; transition to Phase 3+ if needed |
| Git conflicts in index.md | Low | Medium | Simple list structure makes merges easy; document conflict resolution |
| Checkbox UI confusion | Low | Low | Clear documentation of multi-select behavior with examples |
| Context injection failures in planning | High | High | Manually verify plan format compliance; this plan demonstrates correct format |

## Implementation Phases

### Phase 1: Vault Structure and Configuration [COMPLETED]

**Started**: 2026-03-06T10:30:00Z  
**Completed**: 2026-03-06T10:35:00Z

**Goal**: Create `.opencode/memory/` vault directory structure with Obsidian configuration

**Tasks**:
- [ ] Create vault directory structure with `.obsidian/` config
- [ ] Write `app.json`, `appearance.json`, `core-plugins.json` configuration files
- [ ] Create `00-Inbox/`, `10-Memories/`, `20-Indices/`, `30-Templates/` directories
- [ ] Write `memory-template.md` with YAML frontmatter
- [ ] Create `index.md` with navigation links
- [ ] Write `README.md` with vault documentation
- [ ] Create `memory-setup.md` with MCP server instructions

**Timing**: 1-2 hours

### Phase 2: Basic /remember Command with Checkbox Confirmation [COMPLETED]

**Started**: 2026-03-06T10:36:00Z  
**Completed**: 2026-03-06T10:45:00Z

**Goal**: Implement `/remember` command with checkbox-based multi-select confirmation (similar to `/learn`)

**Tasks**:
- [ ] Create `.opencode/commands/remember.md` command specification
- [ ] Implement input parsing (text vs file path detection)
- [ ] Build ID generation logic (MEM-YYYY-MM-DD-NNN format)
- [ ] Create `.opencode/skills/skill-remember/SKILL.md` with checkbox confirmation
- [ ] Implement similar memory search using MCP
- [ ] Add checkbox options: Add new, Update existing, Edit content, Skip
- [ ] Handle multiple selection scenarios
- [ ] Write memory files to `10-Memories/`
- [ ] Update `index.md` with new memory links
- [ ] Implement git commit workflow

**Timing**: 2-3 hours

### Phase 3: MCP Server Integration and --remember Flag [COMPLETED]

**Started**: 2026-03-06T10:46:00Z  
**Completed**: 2026-03-06T10:55:00Z

**Goal**: Document MCP setup and integrate memory search into research workflow

**Tasks**:
- [ ] Create `.opencode/docs/mcp-setup.md` with installation instructions
- [ ] Create MCP config template for obsidian-cli-rest plugin
- [ ] Modify `.opencode/commands/research.md` to detect `--remember` flag
- [ ] Implement memory search step in research workflow
- [ ] Add "Prior Knowledge from Memory Vault" section to research reports
- [ ] Test end-to-end flow with MCP server
- [ ] Add graceful degradation when MCP unavailable

**Timing**: 2-3 hours

### Phase 4: Integration Testing and Documentation [NOT STARTED]

**Goal**: Test complete workflow and document usage

**Tasks**:
- [ ] Test adding text memory with checkbox confirmation
- [ ] Test adding file memory and updating existing
- [ ] Test skip option cancels without creating files
- [ ] Test research with `--remember` flag
- [ ] Create `.opencode/docs/remember-usage.md` with examples
- [ ] Create `.opencode/docs/memory-troubleshooting.md`
- [ ] Update `.opencode/README.md` with memory system section
- [ ] Verify git workflow works correctly

**Timing**: 1-2 hours

## Testing & Validation

- [ ] Can add text memory: `/remember "test content"` with checkbox confirmation
- [ ] Can add file memory: `/remember /path/to/file.md` with preview
- [ ] ID auto-increments correctly for same date
- [ ] Checkbox displays 4 options with multi-select support
- [ ] "Add as new" creates file in correct location
- [ ] "Update existing" appends to selected memory file
- [ ] "Edit content" allows modification before save
- [ ] "Skip" cancels without creating files
- [ ] Index.md updated with new links automatically
- [ ] Git commit created with descriptive message
- [ ] `--remember` flag triggers memory search in research
- [ ] MCP integration works for search and retrieval
- [ ] Graceful handling when MCP unavailable
- [ ] Documentation links work correctly

## Artifacts & Outputs

- `.opencode/memory/.obsidian/app.json` - Obsidian app configuration
- `.opencode/memory/.obsidian/appearance.json` - Theme settings
- `.opencode/memory/.obsidian/core-plugins.json` - Enabled plugins
- `.opencode/memory/30-Templates/memory-template.md` - Memory entry template
- `.opencode/memory/20-Indices/index.md` - Master index
- `.opencode/memory/README.md` - Vault documentation
- `.opencode/docs/memory-setup.md` - MCP server setup guide
- `.opencode/commands/remember.md` - Command specification
- `.opencode/skills/skill-remember/SKILL.md` - Direct execution skill
- `.opencode/docs/remember-usage.md` - Usage examples
- `.opencode/docs/memory-troubleshooting.md` - Troubleshooting guide
- `specs/OC_136_design_and_implement_remember_command_for_intelligent_memory_management/summaries/implementation-summary-YYYYMMDD.md` - Final summary

## Rollback/Contingency

If implementation must be reverted:

1. **Remove created files**:
   - Delete `.opencode/memory/` directory
   - Delete `.opencode/commands/remember.md`
   - Delete `.opencode/skills/skill-remember/`
   - Delete `.opencode/docs/memory-*.md`

2. **Revert state changes**:
   - Remove plan artifact from state.json
   - Update TODO.md to remove completed items

3. **Git cleanup**:
   - Revert commits related to memory system
   - Or manually delete files and commit removal

4. **No data loss risk**: Memory vault is additive only; removing it doesn't affect other OpenCode functionality

---

## Revision History

- **v001**: Initial plan with simple yes/no confirmation
- **v002**: Changed to checkbox-based multi-select (similar to /learn) - **NON-COMPLIANT FORMAT**
- **v003**: Reformatted to follow plan-format.md specification exactly (this version)

## Next Steps

After plan approval, run `/implement OC_136` to begin Phase 1 implementation.

**Phase 1 can begin immediately** - no blockers or external dependencies required.
