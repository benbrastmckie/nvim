---
task_number: 176
task_name: port_vision_memory_system_changes_to_neovim
version: 1
created: 2026-03-10T21:00:00Z
status: planned
total_effort: 4-6 hours
phases_count: 5
---

# Implementation Plan: Port Vision Memory System Changes

## Overview

This plan implements the memory system architecture changes from the Vision repository into the neovim configuration. The primary change is moving the memory vault from `.opencode/memory/` to `.memory/` in the repository root, along with creating necessary skills, context files, and configuration updates.

## Objectives

1. Move memory vault to `.memory/` directory (outside agent systems)
2. Create `skill-memory` for memory vault management
3. Create memory context documentation
4. Create memory extension definition
5. Update all path references across the codebase
6. Ensure `/learn` command works with new paths

---

## Phase 1: Prepare Directory Structure and Move Memory Vault

**Estimated Effort**: 30-45 minutes  
**Dependencies**: None  
**Risk Level**: Low

### Objective
Create the new `.memory/` directory structure and move existing memory vault contents from `.opencode/memory/`.

### Steps

1. **Create new directory structure**
   ```bash
   mkdir -p .memory/{00-Inbox,10-Memories,20-Indices,30-Templates}
   ```

2. **Move memory vault contents**
   - Move `.opencode/memory/00-Inbox/README.md` → `.memory/00-Inbox/README.md`
   - Move `.opencode/memory/10-Memories/*.md` → `.memory/10-Memories/`
   - Move `.opencode/memory/20-Indices/*.md` → `.memory/20-Indices/`
   - Move `.opencode/memory/30-Templates/*.md` → `.memory/30-Templates/`
   - Move `.opencode/memory/.obsidian/` → `.memory/.obsidian/`

3. **Update README.md**
   - Update `.memory/README.md` path references from `.opencode/memory/` to `.memory/`
   - Update directory structure diagram

4. **Create symlink for compatibility** (optional but recommended)
   ```bash
   ln -s ../.memory .opencode/memory
   ```

5. **Update .gitignore**
   - Ensure `.memory/.obsidian/` is ignored
   - Ensure `.memory/*.sqlite` is ignored

### Success Criteria
- [ ] `.memory/` directory exists in repo root
- [ ] All memory files moved to `.memory/`
- [ ] Obsidian config preserved in `.memory/.obsidian/`
- [ ] `.memory/README.md` updated with correct paths
- [ ] Git status shows files moved (not deleted + created)

### Rollback
If issues occur:
```bash
# Restore from git
git checkout -- .opencode/memory/
rm -rf .memory/
```

---

## Phase 2: Create skill-memory

**Estimated Effort**: 45-60 minutes  
**Dependencies**: Phase 1  
**Risk Level**: Low

### Objective
Create the memory management skill that handles memory creation, search, classification, and indexing.

### Steps

1. **Create skill directory**
   ```bash
   mkdir -p .opencode/skills/skill-memory
   ```

2. **Create SKILL.md** (port from Vision)
   - Copy content from `/home/benjamin/Projects/Logos/Vision/.opencode/skills/skill-memory/SKILL.md`
   - Verify all paths reference `.memory/` (not `.opencode/memory/`)
   - Update context references:
     - `@.memory/30-Templates/memory-template.md`
     - `@.memory/20-Indices/index.md`
     - `@.opencode/context/project/memory/learn-usage.md`

3. **Create README.md**
   - Create `.opencode/skills/skill-memory/README.md`
   - Document skill purpose and usage
   - Reference parent skill README

4. **Verify path updates**
   - Check shell commands use `.memory/10-Memories/`
   - Check file creation paths use `.memory/10-Memories/`
   - Check index update path uses `.memory/20-Indices/index.md`
   - Check git add uses `.memory/`

### Success Criteria
- [ ] `.opencode/skills/skill-memory/SKILL.md` exists with correct paths
- [ ] `.opencode/skills/skill-memory/README.md` exists
- [ ] All path references use `.memory/` format
- [ ] SKILL.md passes validation (no syntax errors)

### Files to Create
- `.opencode/skills/skill-memory/SKILL.md` (~390 lines)
- `.opencode/skills/skill-memory/README.md`

---

## Phase 3: Create Memory Context Documentation

**Estimated Effort**: 30-45 minutes  
**Dependencies**: Phase 1  
**Risk Level**: Low

### Objective
Create context documentation for the memory system in `.opencode/context/project/memory/`.

### Steps

1. **Create context directory**
   ```bash
   mkdir -p .opencode/context/project/memory
   ```

2. **Create README.md**
   - Overview of memory system
   - Directory structure
   - Usage basics

3. **Create learn-usage.md**
   - Document `/learn` command usage
   - Standard mode examples
   - Task mode examples
   - Interactive options

4. **Create memory-setup.md**
   - MCP server setup instructions
   - Obsidian configuration
   - API key configuration
   - Plugin installation

5. **Create memory-troubleshooting.md**
   - Common issues and solutions
   - Path errors
   - Permission issues
   - Git workflow problems

6. **Port content from Vision**
   - Reference `/home/benjamin/Projects/Logos/Vision/.opencode/context/project/memory/`
   - Update paths in documentation
   - Adapt for neovim context

### Success Criteria
- [ ] `.opencode/context/project/memory/` directory exists
- [ ] All 4 documentation files created
- [ ] Files reference correct `.memory/` paths
- [ ] Documentation is comprehensive and clear

### Files to Create
- `.opencode/context/project/memory/README.md`
- `.opencode/context/project/memory/learn-usage.md`
- `.opencode/context/project/memory/memory-setup.md`
- `.opencode/context/project/memory/memory-troubleshooting.md`

---

## Phase 4: Update Commands and Documentation

**Estimated Effort**: 45-60 minutes  
**Dependencies**: Phase 2  
**Risk Level**: Low

### Objective
Update existing commands and documentation to reference the new `.memory/` paths.

### Steps

1. **Update .opencode/commands/learn.md**
   - Update state_management section
   - Change reads from `.opencode/memory/` to `.memory/`
   - Change writes from `.opencode/memory/` to `.memory/`
   - Update delegation logic if needed
   - Note: May need to distinguish between:
     - `skill-learn` (tag scanning - keep existing)
     - `skill-memory` (memory vault - new delegation)

2. **Update .opencode/AGENTS.md**
   - Find Memory Vault Structure section
   - Update diagram: `.opencode/memory/` → `.memory/`
   - Update any path references in memory system description

3. **Update .opencode/skills/skill-learn/SKILL.md** (if needed)
   - Clarify distinction from skill-memory
   - Add cross-reference to skill-memory
   - Ensure no path conflicts

4. **Review other files**
   - Check `.opencode/commands/todo.md` for memory references
   - Check other skills for memory path references
   - Update any found references

### Success Criteria
- [ ] `learn.md` references `.memory/` paths
- [ ] `AGENTS.md` shows correct memory structure
- [ ] No references to `.opencode/memory/` remain (except symlink)
- [ ] Command delegation logic is clear

### Files to Update
- `.opencode/commands/learn.md`
- `.opencode/AGENTS.md`
- `.opencode/skills/skill-learn/SKILL.md` (clarification only)

---

## Phase 5: Create Memory Extension and Configuration

**Estimated Effort**: 45-60 minutes  
**Dependencies**: Phases 1-3  
**Risk Level**: Medium

### Objective
Create the memory extension definition and extensions.json configuration.

### Steps

1. **Create extension directory structure**
   ```bash
   mkdir -p .opencode/extensions/memory/{agents,skills,context}
   ```

2. **Create manifest.json**
   - Define extension metadata
   - Specify version, description, dependencies
   - Define provides: agents, skills, commands, context

3. **Create extension skill-memory** (extension version)
   - May need to create `.opencode/extensions/memory/skills/skill-memory/SKILL.md`
   - This is the SOURCE version that gets loaded by other repos

4. **Create extensions.json**
   - Define memory extension entry
   - Set correct source_dir path
   - Configure data_skeleton_files with `.memory/` paths
   - Configure installed_dirs with correct paths
   - Set up MCP server configuration for obsidian-memory

5. **Configure MCP server**
   - Add obsidian-memory MCP server to extensions.json
   - Configure OBSIDIAN_API_KEY environment variable
   - Set OBSIDIAN_PORT to 27124

### Extension Configuration

**data_skeleton_files**:
```json
[
  ".memory/00-Inbox/README.md",
  ".memory/10-Memories/README.md",
  ".memory/20-Indices/README.md",
  ".memory/20-Indices/index.md",
  ".memory/30-Templates/README.md",
  ".memory/30-Templates/memory-template.md",
  ".memory/README.md"
]
```

**installed_dirs**:
```json
[
  ".opencode/skills/skill-memory",
  ".opencode/context/project/memory",
  ".opencode/memory",
  ".memory/00-Inbox",
  ".memory/10-Memories",
  ".memory/20-Indices",
  ".memory/30-Templates"
]
```

### Success Criteria
- [ ] `.opencode/extensions/memory/` directory exists
- [ ] `manifest.json` created with proper metadata
- [ ] `extensions.json` created at `.opencode/extensions.json`
- [ ] Memory extension configured with correct paths
- [ ] MCP server configuration included
- [ ] source_dir points to neovim extension location

### Files to Create
- `.opencode/extensions.json`
- `.opencode/extensions/memory/manifest.json`
- `.opencode/extensions/memory/skills/skill-memory/SKILL.md` (source version)

---

## Phase 6: Verification and Testing

**Estimated Effort**: 30-45 minutes  
**Dependencies**: Phases 1-5  
**Risk Level**: Low

### Objective
Verify all changes work correctly and the memory system functions as expected.

### Steps

1. **Path Verification**
   ```bash
   # Check for old paths
   grep -r "\.opencode/memory/" .opencode/ --include="*.md" --include="*.json" --include="*.sh"
   # Should only find references in context about the move
   ```

2. **Directory Structure Verification**
   ```bash
   # Verify .memory/ exists
   ls -la .memory/
   # Verify subdirectories
   ls .memory/{00-Inbox,10-Memories,20-Indices,30-Templates}/
   ```

3. **File Creation Test**
   ```bash
   # Test memory file creation path
   touch .memory/10-Memories/TEST-verify.md
   ls .memory/10-Memories/TEST-verify.md
   rm .memory/10-Memories/TEST-verify.md
   ```

4. **Skill Validation**
   - Verify skill-memory SKILL.md loads without errors
   - Check context references resolve correctly
   - Verify no syntax errors in shell commands

5. **Command Review**
   - Review `/learn` command logic
   - Ensure delegation to skill-memory is correct
   - Verify state_management paths are accurate

6. **Documentation Review**
   - Read through context/project/memory/ files
   - Verify instructions are clear and accurate
   - Check all paths in documentation

### Success Criteria
- [ ] No `.opencode/memory/` references remain (except symlink)
- [ ] All `.memory/` paths resolve correctly
- [ ] Skills load without errors
- [ ] Documentation is accurate
- [ ] Git status is clean (all changes staged/committed)

### Test Commands
```bash
# Path check
grep -r "\.opencode/memory/" .opencode/ --include="*.md" --include="*.json"

# Structure check
find .memory/ -type f -name "*.md" | head -20

# Git check
git status
```

---

## Risk Analysis

### Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Path references missed | Medium | Medium | Comprehensive grep search in Phase 6 |
| Git history loss | Low | Low | Use git mv for moves, preserve history |
| Extension loading failure | Medium | High | Test extension configuration carefully |
| Skill delegation confusion | Medium | Medium | Clear documentation distinguishing skill-learn vs skill-memory |
| MCP server misconfiguration | Low | Medium | Follow Vision's working configuration |
| Symlink issues | Low | Low | Test on both Linux and macOS |

### Contingency Plans

**If path updates are incomplete**:
- Run comprehensive search: `grep -r "\.opencode/memory/" .opencode/`
- Update any missed references
- Re-verify

**If extension doesn't load**:
- Check JSON syntax in extensions.json
- Verify source_dir path exists
- Check manifest.json format

**If skill delegation fails**:
- Review learn.md delegation logic
- Ensure skill-memory exists and is valid
- Check for naming conflicts

---

## Dependencies Summary

```
Phase 1: Prepare Directory Structure
    |
    v
Phase 2: Create skill-memory
    |
    v
Phase 3: Create Memory Context Documentation
    |
    v
Phase 4: Update Commands and Documentation
    |
    v
Phase 5: Create Memory Extension and Configuration
    |
    v
Phase 6: Verification and Testing
```

All phases are sequential due to path dependencies.

---

## Total Effort Estimate

| Phase | Effort |
|-------|--------|
| Phase 1: Directory Structure | 30-45 min |
| Phase 2: Create skill-memory | 45-60 min |
| Phase 3: Context Documentation | 30-45 min |
| Phase 4: Update Commands | 45-60 min |
| Phase 5: Extension Config | 45-60 min |
| Phase 6: Verification | 30-45 min |
| **Total** | **4-6 hours** |

---

## Verification Checklist

Post-implementation verification:

- [ ] `.memory/` directory exists in repo root with correct structure
- [ ] `.opencode/skills/skill-memory/` exists with SKILL.md and README.md
- [ ] `.opencode/context/project/memory/` has 4 documentation files
- [ ] `.opencode/extensions.json` exists with memory extension
- [ ] `.opencode/commands/learn.md` references `.memory/` paths
- [ ] `.opencode/AGENTS.md` shows `.memory/` in structure diagram
- [ ] No references to `.opencode/memory/` in active code (except symlink)
- [ ] Memory files can be created in `.memory/10-Memories/`
- [ ] Index updates work in `.memory/20-Indices/index.md`
- [ ] Git status is clean
- [ ] All changes committed with appropriate messages

---

## References

- Research Report: `specs/176_port_vision_memory_system_changes_to_neovim/reports/research-001.md`
- Vision Repository: `/home/benjamin/Projects/Logos/Vision/`
- Vision Commit 6b2a40b: "refactor: Move memory vault from .opencode/memory/ to .memory/"
- Vision Commit 277dcb2: "docs: Update all references to memory vault location"
- Related Tasks: OC_174 (study opencode memory), OC_175 (port to claude)

---

## Notes

1. **Symlink Strategy**: Vision used a symlink `.opencode/memory -> .memory/` for backward compatibility. This is recommended but optional.

2. **Skill Distinction**: Neovim has `skill-learn` (tag scanner for FIX:/NOTE:/TODO:/QUESTION:) which is DIFFERENT from the new `skill-memory` (memory vault manager). Both should coexist.

3. **Extension Source**: The neovim config IS the source of the memory extension. When other repos use `<leader>ao`, they load from neovim's `.opencode/extensions/memory/`.

4. **Testing Approach**: Test incrementally after each phase to catch issues early.

5. **Git Strategy**: Commit after each phase for granular history and easy rollback.
