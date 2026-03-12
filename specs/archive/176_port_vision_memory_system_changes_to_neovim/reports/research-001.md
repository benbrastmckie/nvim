# Research Report: Vision Memory System Changes Port

**Task**: OC_176 - Port Vision memory system changes to neovim configuration
**Research Date**: 2026-03-10
**Researcher**: Claude Code

---

## Executive Summary

The Vision repository has successfully implemented a memory management system that stores memories in an Obsidian-compatible vault. The key architectural change was moving the memory vault from `.opencode/memory/` to `.memory/` (in the repository root), similar to how `specs/` is located outside both agent systems (.opencode/ and .claude/). This provides cleaner separation of concerns and better compatibility with research agents.

This report documents all changes made in Vision that need to be ported to the neovim configuration repository.

---

## Key Changes in Vision

### 1. Directory Structure Change (Primary Change)

**Before**: `.opencode/memory/`
**After**: `.memory/`

The memory vault was moved to the repository root to:
- Match the `specs/` location pattern (outside agent systems)
- Provide better compatibility with research agents that expect `.memory/` in repo root
- Achieve cleaner separation between agent configuration and data storage

### 2. Files Changed in Vision

Two git commits implemented the changes:

#### Commit 1: `6b2a40b` - "refactor: Move memory vault from .opencode/memory/ to .memory/"

**Files modified**:
- `.memory` (symlink removed)
- `.memory/00-Inbox/README.md` (moved)
- `.memory/10-Memories/README.md` (moved)
- `.memory/10-Memories/test-pitch-deck-structure.md` (moved)
- `.memory/20-Indices/README.md` (moved)
- `.memory/20-Indices/index.md` (moved)
- `.memory/30-Templates/README.md` (moved)
- `.memory/30-Templates/memory-template.md` (moved)
- `.memory/README.md` (moved and updated)
- `.opencode/context/project/memory/learn-usage.md` (updated paths)
- `.opencode/context/project/memory/memory-setup.md` (updated paths)
- `.opencode/context/project/memory/memory-troubleshooting.md` (updated paths)
- `.opencode/settings.local.json` (updated paths)

#### Commit 2: `277dcb2` - "docs: Update all references to memory vault location"

**Files modified**:
- `.opencode/AGENTS.md` - Updated path references
- `.opencode/commands/learn.md` - Updated state_management paths
- `.opencode/commands/todo.md` - Updated state_management paths
- `.opencode/extensions.json` - Updated data_skeleton_files and installed_dirs
- `.opencode/skills/skill-memory/SKILL.md` - Updated all path references
- `.opencode/skills/skill-todo/SKILL.md` - Updated path references

### 3. Path Reference Changes

All path references were changed from `.opencode/memory/` to `.memory/`:

| Context | Before | After |
|---------|--------|-------|
| Memory files | `.opencode/memory/10-Memories/*.md` | `.memory/10-Memories/*.md` |
| Index | `.opencode/memory/20-Indices/index.md` | `.memory/20-Indices/index.md` |
| Templates | `.opencode/memory/30-Templates/` | `.memory/30-Templates/` |
| Inbox | `.opencode/memory/00-Inbox/` | `.memory/00-Inbox/` |
| Obsidian config | `.opencode/memory/.obsidian/` | `.memory/.obsidian/` |

### 4. Configuration Changes in extensions.json

The memory extension's `data_skeleton_files` and `installed_dirs` arrays were updated:

**Before**:
```json
"data_skeleton_files": [
  ".opencode/memory/00-Inbox/README.md",
  ".opencode/memory/10-Memories/README.md",
  ".opencode/memory/20-Indices/README.md",
  ".opencode/memory/20-Indices/index.md",
  ".opencode/memory/30-Templates/README.md",
  ".opencode/memory/30-Templates/memory-template.md",
  ".opencode/memory/README.md"
],
"installed_dirs": [
  ".opencode/skills/skill-memory",
  ".opencode/context/project/memory",
  ".opencode/memory",
  ".opencode/memory/00-Inbox",
  ".opencode/memory/10-Memories",
  ".opencode/memory/20-Indices",
  ".opencode/memory/30-Templates"
]
```

**After**:
```json
"data_skeleton_files": [
  ".memory/00-Inbox/README.md",
  ".memory/10-Memories/README.md",
  ".memory/20-Indices/README.md",
  ".memory/20-Indices/index.md",
  ".memory/30-Templates/README.md",
  ".memory/30-Templates/memory-template.md",
  ".memory/README.md"
],
"installed_dirs": [
  ".opencode/skills/skill-memory",
  ".opencode/context/project/memory",
  ".opencode/memory",
  ".memory/00-Inbox",
  ".memory/10-Memories",
  ".memory/20-Indices",
  ".memory/30-Templates"
]
```

Note: `.opencode/memory` remains in `installed_dirs` (points to symlink for compatibility).

### 5. Skill Updates

The `skill-memory/SKILL.md` had multiple path updates:

**Context References**:
- `@.opencode/memory/30-Templates/memory-template.md` -> `@.memory/30-Templates/memory-template.md`
- `@.opencode/memory/20-Indices/index.md` -> `@.memory/20-Indices/index.md`

**Shell commands**:
- `ls -1 .opencode/memory/10-Memories/` -> `ls -1 .memory/10-Memories/`
- `grep -l -i "$keyword" .opencode/memory/10-Memories/*.md` -> `grep -l -i "$keyword" .memory/10-Memories/*.md`
- `filepath=".opencode/memory/10-Memories/${filename}"` -> `filepath=".memory/10-Memories/${filename}"`
- `echo "- [${title}](../10-Memories/${filename})" >> .opencode/memory/20-Indices/index.md` -> `echo "- [${title}](../10-Memories/${filename})" >> .memory/20-Indices/index.md`
- `cat > ".opencode/memory/10-Memories/${filename}"` -> `cat > ".memory/10-Memories/${filename}"`
- `git add .opencode/memory/` -> `git add .memory/`

The `skill-todo/SKILL.md` was also updated for memory creation paths.

### 6. Command Updates

**learn.md** - Updated state_management section:
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

**todo.md** - Updated state_management section similarly.

### 7. Documentation Updates

**AGENTS.md** - Updated Memory Vault Structure diagram:
```
-.opencode/memory/
+.memory/
 +-- .obsidian/           # Obsidian configuration
 +-- 00-Inbox/            # Quick capture for new memories
```

**memory-setup.md**, **learn-usage.md**, **memory-troubleshooting.md** - All updated with new paths.

---

## Current State of Neovim Configuration

The neovim configuration currently has:

1. **Memory vault location**: `.opencode/memory/` (needs to move to `.memory/`)
2. **Skills**: `skill-learn` (for tag scanning) exists, but NOT `skill-memory` (for memory management)
3. **Commands**: `/learn` command exists but references wrong paths
4. **Extensions**: No `extensions.json` file exists
5. **Context**: No memory context files exist

### Files Currently Present in Neovim:

**Memory vault** (at `.opencode/memory/`):
- `.opencode/memory/README.md`
- `.opencode/memory/00-Inbox/README.md`
- `.opencode/memory/10-Memories/README.md`
- `.opencode/memory/10-Memories/MEM-2026-03-05-*.md` (3 memory files)
- `.opencode/memory/20-Indices/README.md`
- `.opencode/memory/20-Indices/index.md`
- `.opencode/memory/30-Templates/README.md`
- `.opencode/memory/30-Templates/memory-template.md`
- `.opencode/memory/.obsidian/` (Obsidian config directory)

**Commands**:
- `.opencode/commands/learn.md` (needs path updates)

**Skills**:
- `.opencode/skills/skill-learn/SKILL.md` (different from skill-memory)

---

## Implementation Requirements

### Required Changes for Neovim

1. **Move directory structure**:
   - Move `.opencode/memory/` to `.memory/`
   - Update `.opencode/memory/README.md` to reference `.memory/`

2. **Create skill-memory** (missing in neovim):
   - Create `.opencode/skills/skill-memory/SKILL.md` (copy from Vision)
   - Create `.opencode/skills/skill-memory/README.md`

3. **Update learn command**:
   - Update `.opencode/commands/learn.md` path references
   - Change delegation from skill-learn to skill-memory for memory operations
   - Note: `skill-learn` in neovim does tag scanning (FIX:/NOTE:/TODO:/QUESTION:), which is different from Vision's `skill-memory`

4. **Update skill-learn**:
   - Keep tag scanning functionality
   - May need to clarify distinction from skill-memory

5. **Create context files** (missing in neovim):
   - `.opencode/context/project/memory/learn-usage.md`
   - `.opencode/context/project/memory/memory-setup.md`
   - `.opencode/context/project/memory/memory-troubleshooting.md`
   - `.opencode/context/project/memory/README.md`

6. **Update AGENTS.md**:
   - Update memory vault path references

7. **Create extensions.json** (missing in neovim):
   - Define memory extension configuration
   - Include proper data_skeleton_files and installed_dirs

### Special Considerations

1. **Extension Loading**: The neovim configuration is the SOURCE of the memory extension (loaded in other repos via `<leader>ao`). The extension definition should be in `.opencode/extensions/memory/`.

2. **Skill Distinction**: Neovim has `skill-learn` (tag scanner) which is different from Vision's `skill-memory` (memory vault manager). Both may be needed.

3. **Backward Compatibility**: Vision maintained a symlink `.opencode/memory -> .memory/` for compatibility. Neovim should consider similar approach during transition.

4. **Obsidian Integration**: The `.memory/.obsidian/` directory contains user-specific settings and should be in `.gitignore`.

---

## Files to Port from Vision

### Must Port:
1. `.opencode/skills/skill-memory/SKILL.md`
2. `.opencode/skills/skill-memory/README.md`
3. `.opencode/context/project/memory/learn-usage.md`
4. `.opencode/context/project/memory/memory-setup.md`
5. `.opencode/context/project/memory/memory-troubleshooting.md`
6. `.opencode/context/project/memory/README.md`

### Must Update:
1. `.opencode/memory/README.md` -> move to `.memory/README.md`
2. `.opencode/commands/learn.md` - path updates and delegation logic
3. `.opencode/AGENTS.md` - path updates
4. Create `extensions.json` with memory extension config

### Must Move:
1. Entire `.opencode/memory/` directory to `.memory/`

---

## Verification Checklist

After implementation:

- [ ] `.memory/` directory exists in repo root
- [ ] `.memory/` contains: 00-Inbox/, 10-Memories/, 20-Indices/, 30-Templates/, README.md
- [ ] `.opencode/skills/skill-memory/SKILL.md` exists with correct paths
- [ ] `.opencode/commands/learn.md` references `.memory/` paths
- [ ] `.opencode/AGENTS.md` shows `.memory/` in structure diagram
- [ ] `.opencode/context/project/memory/` documentation exists
- [ ] `extensions.json` contains memory extension with correct paths
- [ ] `/learn` command works correctly with new paths
- [ ] Memory files are created in `.memory/10-Memories/`
- [ ] Index updates go to `.memory/20-Indices/index.md`

---

## Complexity Assessment

**Effort**: 4-6 hours (as estimated)

**Breakdown**:
- Directory move and file creation: 1-2 hours
- Path reference updates across all files: 1-2 hours
- Testing and verification: 1-2 hours
- Documentation review: 30-60 minutes

**Risk Level**: Low
- Purely structural changes
- No logic modifications
- Can be done incrementally
- Easy to verify

---

## Next Steps

1. Create implementation plan with detailed steps
2. Execute directory move
3. Port skill-memory and context files
4. Update all path references
5. Create extensions.json
6. Test /learn command functionality
7. Verify memory creation and indexing works

---

## References

- Vision commits: `6b2a40b`, `277dcb2`
- Vision repository: `/home/benjamin/Projects/Logos/Vision/`
- Neovim configuration: `/home/benjamin/.config/nvim/`
- Related tasks: OC_174 (study opencode memory), OC_175 (port to claude)
