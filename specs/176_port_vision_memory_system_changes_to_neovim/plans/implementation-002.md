---
task_number: 176
task_name: port_vision_memory_system_changes_to_neovim
version: 1
created: 2026-03-11T01:05:00Z
status: planned
total_effort: 2-3 hours
phases_count: 4
---

# Implementation Plan: Update Memory Extension Configuration

## Overview

This plan updates the existing memory extension at `.opencode/extensions/memory/` to use the Vision architecture. The memory extension already exists and is complete - this plan only makes path configuration changes.

**Key Change**: Move memory vault from `.opencode/memory/` to `.memory/` (repo root) and update all path references.

---

## Prerequisites

- Memory extension exists at `.opencode/extensions/memory/`
- Memory vault currently at `.opencode/memory/`
- Research completed: `specs/176_port_vision_memory_system_changes_to_neovim/reports/research-002.md`

---

## Phase 1: Move Memory Vault Directory

**Estimated Effort**: 15 minutes  
**Dependencies**: None  
**Risk Level**: Very Low

### Objective
Move the memory vault from `.opencode/memory/` to `.memory/` in the repository root.

### Steps

1. **Verify current state**
   ```bash
   ls -la .opencode/memory/
   # Should show: README.md, .obsidian/, 00-Inbox/, 10-Memories/, 20-Indices/, 30-Templates/
   ```

2. **Move the directory**
   ```bash
   git mv .opencode/memory .memory
   ```
   
   **Why git mv**: Preserves git history (shows as rename, not delete+create)

3. **Verify the move**
   ```bash
   ls -la .memory/
   # Should show same contents as before
   
   ls .opencode/memory 2>/dev/null
   # Should show: "No such file or directory"
   ```

4. **Stage the change**
   ```bash
   git add -A
   git status
   # Should show: renamed: .opencode/memory/{file} -> .memory/{file}
   ```

### Success Criteria
- [ ] `.memory/` directory exists in repo root
- [ ] `.memory/` contains all previous contents (README, .obsidian, subdirs)
- [ ] `.opencode/memory/` no longer exists
- [ ] Git shows rename operations (not deletions)

### Rollback
If issues occur:
```bash
git reset HEAD
git mv .memory .opencode/memory
```

---

## Phase 2: Update Extension Commands and Skills

**Estimated Effort**: 45 minutes  
**Dependencies**: Phase 1  
**Risk Level**: Low

### Objective
Update path references in the command and skill files from `.opencode/memory/` to `.memory/`.

### Files to Update

#### 2.1: commands/learn.md

**Changes needed**: 4 path references

**Current**:
```xml
<reads>
  - specs/{NNN}_*/ (task mode - artifact directories)
  - .opencode/memory/30-Templates/memory-template.md
  - .opencode/memory/10-Memories/ (for ID generation)
</reads>

<writes>
  - .opencode/memory/10-Memories/*.md (new memory files)
  - .opencode/memory/20-Indices/index.md (updated links)
</writes>
```

**Update to**:
```xml
<reads>
  - specs/{NNN}_*/ (task mode - artifact directories)
  - .memory/30-Templates/memory-template.md
  - .memory/10-Memories/ (for ID generation)
</reads>

<writes>
  - .memory/10-Memories/*.md (new memory files)
  - .memory/20-Indices/index.md (updated links)
</writes>
```

#### 2.2: skills/skill-memory/SKILL.md

**Changes needed**: 8 path references

**Context References** (lines 16-18):
```yaml
# Change from:
- Path: `@.opencode/memory/30-Templates/memory-template.md`
- Path: `@.opencode/memory/20-Indices/index.md`

# To:
- Path: `@.memory/30-Templates/memory-template.md`
- Path: `@.memory/20-Indices/index.md`
```

**Shell Commands**:

Line 56:
```bash
# Change from:
count=$(ls -1 .opencode/memory/10-Memories/MEM-${today}-*.md 2>/dev/null | wc -l)
# To:
count=$(ls -1 .memory/10-Memories/MEM-${today}-*.md 2>/dev/null | wc -l)
```

Line 81:
```bash
# Change from:
  grep -l -i "$keyword" .opencode/memory/10-Memories/*.md 2>/dev/null
# To:
  grep -l -i "$keyword" .memory/10-Memories/*.md 2>/dev/null
```

Line 141:
```bash
# Change from:
filepath=".opencode/memory/10-Memories/${filename}"
# To:
filepath=".memory/10-Memories/${filename}"
```

Line 185:
```bash
# Change from:
echo "- [${title}](../10-Memories/${filename})" >> .opencode/memory/20-Indices/index.md
# To:
echo "- [${title}](../10-Memories/${filename})" >> .memory/20-Indices/index.md
```

Line 302-305 (Task Mode):
```bash
# Change from:
cat > ".opencode/memory/10-Memories/${filename}" << EOF

# To:
cat > ".memory/10-Memories/${filename}" << EOF
```

Line 383-384 (Git Commit):
```bash
# Change from:
git add .opencode/memory/

# To:
git add .memory/
```

### Verification
```bash
# Verify no old paths remain
grep -n "\.opencode/memory" .opencode/extensions/memory/commands/learn.md
grep -n "\.opencode/memory" .opencode/extensions/memory/skills/skill-memory/SKILL.md
# Should return nothing
```

### Success Criteria
- [ ] commands/learn.md updated (4 changes)
- [ ] skills/skill-memory/SKILL.md updated (8 changes)
- [ ] No `.opencode/memory` references remain in these files
- [ ] All paths now reference `.memory/`

---

## Phase 3: Update Extension Documentation

**Estimated Effort**: 30 minutes  
**Dependencies**: Phase 1  
**Risk Level**: Very Low

### Objective
Update path references in extension documentation files.

### Files to Update

#### 3.1: data/memory/README.md

**Changes needed**: 2 references

Line 12 - Directory structure diagram:
```markdown
# Change from:
```
.opencode/memory/
+-- .obsidian/           # Obsidian configuration
```

# To:
```
.memory/
+-- .obsidian/           # Obsidian configuration
```
```

Line 49 - Vault opening instructions:
```markdown
# Change from:
2. Open this `.opencode/memory/` as a vault

# To:
2. Open this `.memory/` as a vault
```

#### 3.2: EXTENSION.md

**Changes needed**: 1 reference

Line 49 - Directory structure diagram:
```markdown
# Change from:
```
.opencode/memory/
+-- .obsidian/           # Obsidian configuration
```

# To:
```
.memory/
+-- .obsidian/           # Obsidian configuration
```
```

### Success Criteria
- [ ] data/memory/README.md updated (2 changes)
- [ ] EXTENSION.md updated (1 change)
- [ ] Directory diagrams show `.memory/`
- [ ] Setup instructions reference `.memory/`

---

## Phase 4: Update Context Documentation

**Estimated Effort**: 30 minutes  
**Dependencies**: Phase 1  
**Risk Level**: Very Low

### Objective
Update path references in context/project/memory/ documentation files.

### Files to Update

#### 4.1: context/project/memory/learn-usage.md

**Changes needed**: 4 references

Line 55:
```markdown
# Change from:
**Add as new memory**: Creates a new memory file in `.opencode/memory/10-Memories/`

# To:
**Add as new memory**: Creates a new memory file in `.memory/10-Memories/`
```

Line 118:
```markdown
# Change from:
4. **Commit regularly** - `git add .opencode/memory/ && git commit`

# To:
4. **Commit regularly** - `git add .memory/ && git commit`
```

Line 124:
```bash
# Change from:
git add .opencode/memory/

# To:
git add .memory/
```

Line 189 - See Also section (optional, if present):
```markdown
# Update any cross-references
```

#### 4.2: context/project/memory/memory-setup.md

**Changes needed**: 2 references

Line 10:
```markdown
# Change from:
- `.opencode/memory/` vault created

# To:
- `.memory/` vault created
```

Line 22:
```markdown
# Change from:
3. Select `.opencode/memory/` directory

# To:
3. Select `.memory/` directory
```

#### 4.3: context/project/memory/memory-troubleshooting.md

**Changes needed**: 6 references

Line 15:
```markdown
# Change from:
   - Open `.opencode/memory/` as vault

# To:
   - Open `.memory/` as vault
```

Line 28:
```markdown
# Change from:
   - Check `.opencode/memory/10-Memories/` for files

# To:
   - Check `.memory/10-Memories/` for files
```

Line 45:
```markdown
# Change from:
- Git merge conflicts in `.opencode/memory/20-Indices/index.md`

# To:
- Git merge conflicts in `.memory/20-Indices/index.md`
```

Line 52:
```markdown
# Change from:
   - Ensure write access to `.opencode/memory/`

# To:
   - Ensure write access to `.memory/`
```

Line 58:
```markdown
# Change from:
- "No vault found" when opening `.opencode/memory/`

# To:
- "No vault found" when opening `.memory/`
```

Lines 64-65:
```bash
# Change from:
   .opencode/memory/
   ls -la .opencode/memory/
   ls -la .opencode/memory/10-Memories/

# To:
   .memory/
   ls -la .memory/
   ls -la .memory/10-Memories/
```

### Success Criteria
- [ ] context/project/memory/learn-usage.md updated
- [ ] context/project/memory/memory-setup.md updated
- [ ] context/project/memory/memory-troubleshooting.md updated
- [ ] All git commands reference `.memory/`
- [ ] All directory references updated

---

## Phase 5: Verification and Testing

**Estimated Effort**: 30 minutes  
**Dependencies**: Phases 1-4  
**Risk Level**: Very Low

### Objective
Verify all changes are correct and the memory system will work properly.

### Steps

1. **Global Path Verification**
   ```bash
   # Search for any remaining old paths in extension
   grep -r "\.opencode/memory" .opencode/extensions/memory/ \
     --include="*.md" --include="*.json" --include="*.sh"
   
   # Should return nothing (or only comments about the change)
   ```

2. **Verify New Paths**
   ```bash
   # Check that new paths exist
   ls -la .memory/
   ls -la .memory/10-Memories/
   ls -la .memory/20-Indices/
   ```

3. **Check Extension Files**
   ```bash
   # Verify extension files exist
   ls .opencode/extensions/memory/commands/learn.md
   ls .opencode/extensions/memory/skills/skill-memory/SKILL.md
   ls .opencode/extensions/memory/data/memory/README.md
   ls .opencode/extensions/memory/EXTENSION.md
   ```

4. **Git Status Check**
   ```bash
   git status
   # Should show:
   # - renamed: .opencode/memory/ -> .memory/
   # - modified: .opencode/extensions/memory/commands/learn.md
   # - modified: .opencode/extensions/memory/skills/skill-memory/SKILL.md
   # - modified: .opencode/extensions/memory/data/memory/README.md
   # - modified: .opencode/extensions/memory/EXTENSION.md
   # - modified: .opencode/extensions/memory/context/project/memory/*.md
   ```

5. **Diff Review**
   ```bash
   # Review changes before commit
   git diff --cached
   ```

### Success Criteria
- [ ] No `.opencode/memory` references in extension files
- [ ] `.memory/` directory exists with all contents
- [ ] All 7 extension files updated
- [ ] Git shows clean rename + modifications
- [ ] Changes look correct in diff review

---

## Risk Analysis

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Missed path reference | Low | Medium | Comprehensive grep search in Phase 5 |
| Git history loss | Very Low | Low | Use `git mv` for directory move |
| Broken extension loading | Very Low | High | Extension structure unchanged, only paths |
| User confusion | Low | Low | Update all documentation consistently |

**Overall Risk**: Very Low
- Simple path string replacements
- No logic changes
- Easy to verify with grep
- Git preserves history with `git mv`

---

## Dependencies Summary

```
Phase 1: Move Memory Vault
    |
    v
Phase 2: Update Commands/Skills (depends on Phase 1)
    |
    v
Phase 3: Update Extension Documentation (depends on Phase 1)
    |
    v
Phase 4: Update Context Documentation (depends on Phase 1)
    |
    v
Phase 5: Verification (depends on Phases 1-4)
```

All file updates (Phases 2-4) can happen in parallel after Phase 1 completes.

---

## Effort Summary

| Phase | Effort |
|-------|--------|
| Phase 1: Move Memory Vault | 15 min |
| Phase 2: Update Commands/Skills | 45 min |
| Phase 3: Update Extension Docs | 30 min |
| Phase 4: Update Context Docs | 30 min |
| Phase 5: Verification | 30 min |
| **Total** | **2.5 hours** |

---

## Files Changed Summary

### Directory Moved:
- `.opencode/memory/` → `.memory/`

### Files Modified (7 total):
1. `.opencode/extensions/memory/commands/learn.md` (4 changes)
2. `.opencode/extensions/memory/skills/skill-memory/SKILL.md` (8 changes)
3. `.opencode/extensions/memory/data/memory/README.md` (2 changes)
4. `.opencode/extensions/memory/EXTENSION.md` (1 change)
5. `.opencode/extensions/memory/context/project/memory/learn-usage.md` (4 changes)
6. `.opencode/extensions/memory/context/project/memory/memory-setup.md` (2 changes)
7. `.opencode/extensions/memory/context/project/memory/memory-troubleshooting.md` (6 changes)

**Total**: ~27 path reference changes

---

## Verification Commands

```bash
# After implementation, run these to verify:

# 1. Check no old paths remain
grep -r "\.opencode/memory" .opencode/extensions/memory/ \
  --include="*.md" --include="*.json"

# 2. Verify new location exists
ls -la .memory/

# 3. Check git status
git status

# 4. Review changes
git diff --cached --stat
```

---

## Notes

1. **Extension Structure Unchanged**: The extension at `.opencode/extensions/memory/` keeps the same structure. Only path strings are updated.

2. **Vision Compatibility**: After these changes, when other repos load this extension via `<leader>ao`, they will get the corrected paths and the memory system will work like Vision.

3. **Data Skeleton**: The `data/memory/` directory contains skeleton files that get copied to `.memory/` when the extension is loaded. These skeleton files also need path updates (done in Phase 3).

4. **No Breaking Changes**: Existing memories in `.opencode/memory/` will be preserved in the move to `.memory/`.

5. **Git Best Practice**: Using `git mv` instead of `mv` preserves file history and shows the operation as a rename rather than delete+create.

---

## References

- Corrected Research: `specs/176_port_vision_memory_system_changes_to_neovim/reports/research-002.md`
- Vision Repository: `/home/benjamin/Projects/Logos/Vision/`
- Memory Extension: `/home/benjamin/.config/nvim/.opencode/extensions/memory/`
