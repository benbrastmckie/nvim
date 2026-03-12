# Research Report: Update Memory Extension Configuration

**Task**: OC_176 - Port Vision memory system changes to neovim configuration  
**Research Date**: 2026-03-10  
**Researcher**: Claude Code  
**Correction Note**: This is a CORRECTED research report. The memory extension ALREADY EXISTS at `.opencode/extensions/memory/`. The task is to UPDATE the extension configuration to match Vision's working setup.

---

## Executive Summary

The neovim configuration already has a complete memory extension at `.opencode/extensions/memory/`. The task is NOT to create new components, but to UPDATE the existing extension configuration to work like Vision by:

1. Moving the memory vault from `.opencode/memory/` to `.memory/` (repo root)
2. Updating all path references in extension files from `.opencode/memory/` to `.memory/`

The extension structure is complete and functional - it just needs path updates to match the Vision architecture.

---

## Current State Analysis

### Memory Extension Already Exists

The neovim configuration has a complete memory extension at:
```
.opencode/extensions/memory/
├── manifest.json              # Extension manifest
├── EXTENSION.md               # Extension documentation  
├── commands/learn.md          # /learn command
├── skills/skill-memory/       # Memory management skill
│   ├── SKILL.md
│   └── README.md
├── context/project/memory/    # Context documentation
│   ├── README.md
│   ├── learn-usage.md
│   ├── memory-setup.md
│   └── memory-troubleshooting.md
├── data/memory/               # Skeleton files for data
│   ├── README.md
│   ├── 00-Inbox/README.md
│   ├── 10-Memories/README.md
│   ├── 20-Indices/README.md
│   ├── 20-Indices/index.md
│   ├── 30-Templates/README.md
│   └── 30-Templates/memory-template.md
├── settings-fragment.json     # Settings merge fragment
└── index-entries.json         # Context index entries
```

### Problem: Path References Are Wrong

All files in the extension currently reference `.opencode/memory/` but should reference `.memory/` to match Vision's architecture.

**Files with old path references** (`.opencode/memory/` → need `.memory/`):

1. **commands/learn.md** (4 references):
   - Line 158: `.opencode/memory/30-Templates/memory-template.md`
   - Line 159: `.opencode/memory/10-Memories/`
   - Line 163: `.opencode/memory/10-Memories/*.md`
   - Line 164: `.opencode/memory/20-Indices/index.md`

2. **skills/skill-memory/SKILL.md** (6+ references):
   - Line 16: `@.opencode/memory/30-Templates/memory-template.md`
   - Line 17: `@.opencode/memory/20-Indices/index.md`
   - Line 56: `ls -1 .opencode/memory/10-Memories/`
   - Line 81: `grep -l -i "$keyword" .opencode/memory/10-Memories/*.md`
   - Line 141: `filepath=".opencode/memory/10-Memories/${filename}"`
   - Line 185: `echo "..." >> .opencode/memory/20-Indices/index.md`

3. **data/memory/README.md** (2 references):
   - Line 12: Directory structure shows `.opencode/memory/`
   - Line 49: "Open this `.opencode/memory/` as a vault"

4. **EXTENSION.md** (1 reference):
   - Line 49: Directory structure diagram shows `.opencode/memory/`

5. **context/project/memory/learn-usage.md** (4 references):
   - Line 55: "Creates a new memory file in `.opencode/memory/10-Memories/`"
   - Line 118: "`git add .opencode/memory/ && git commit`"
   - Line 124: "`git add .opencode/memory/`"

6. **context/project/memory/memory-setup.md** (2 references):
   - Line 10: "`.opencode/memory/` vault created"
   - Line 22: "Select `.opencode/memory/` directory"

7. **context/project/memory/memory-troubleshooting.md** (6 references):
   - Line 15: "Open `.opencode/memory/` as vault"
   - Line 28: "Check `.opencode/memory/10-Memories/` for files"
   - Line 45: "Git merge conflicts in `.opencode/memory/20-Indices/index.md`"
   - Line 52: "Ensure write access to `.opencode/memory/`"
   - Line 58: "No vault found" when opening `.opencode/memory/`"
   - Lines 64-65: Example commands using `.opencode/memory/`

---

## What Vision Did

Vision successfully made these changes:

### Commit 1: `6b2a40b` - Directory Move
- Moved entire `.opencode/memory/` directory to `.memory/`
- Updated `.memory/README.md` with new path

### Commit 2: `277dcb2` - Path Updates
Updated references in:
- `.opencode/AGENTS.md`
- `.opencode/commands/learn.md`
- `.opencode/commands/todo.md`
- `.opencode/extensions.json`
- `.opencode/skills/skill-memory/SKILL.md`
- `.opencode/skills/skill-todo/SKILL.md`

**Key insight**: Vision's extension is at `/home/benjamin/.config/nvim/.opencode/extensions/memory/` (this repo is the SOURCE), and Vision loads it via `<leader>ao`. The extension files in neovim need the same path updates that Vision made to its loaded copy.

---

## Required Changes

### 1. Move Memory Vault

```bash
# Move the actual memory vault
mv .opencode/memory .memory
```

This directory contains:
- `README.md` - Main documentation
- `.obsidian/` - Obsidian configuration
- `00-Inbox/` - Quick capture directory
- `10-Memories/` - Stored memories (3 existing files)
- `20-Indices/` - Navigation files
- `30-Templates/` - Memory templates

### 2. Update Path References in Extension Files

**commands/learn.md** (4 changes):
```xml
<!-- Change from: -->
- .opencode/memory/30-Templates/memory-template.md
- .opencode/memory/10-Memories/
- .opencode/memory/10-Memories/*.md
- .opencode/memory/20-Indices/index.md

<!-- Change to: -->
- .memory/30-Templates/memory-template.md
- .memory/10-Memories/
- .memory/10-Memories/*.md
- .memory/20-Indices/index.md
```

**skills/skill-memory/SKILL.md** (6+ changes):
```yaml
# Change from:
- Path: `@.opencode/memory/30-Templates/memory-template.md`
- Path: `@.opencode/memory/20-Indices/index.md`
- count=$(ls -1 .opencode/memory/10-Memories/MEM-${today}-*.md 2>/dev/null | wc -l)
- grep -l -i "$keyword" .opencode/memory/10-Memories/*.md 2>/dev/null
- filepath=".opencode/memory/10-Memories/${filename}"
- echo "..." >> .opencode/memory/20-Indices/index.md
- cat > ".opencode/memory/10-Memories/${filename}"
- git add .opencode/memory/

# Change to:
- Path: `@.memory/30-Templates/memory-template.md`
- Path: `@.memory/20-Indices/index.md`
- count=$(ls -1 .memory/10-Memories/MEM-${today}-*.md 2>/dev/null | wc -l)
- grep -l -i "$keyword" .memory/10-Memories/*.md 2>/dev/null
- filepath=".memory/10-Memories/${filename}"
- echo "..." >> .memory/20-Indices/index.md
- cat > ".memory/10-Memories/${filename}"
- git add .memory/
```

**data/memory/README.md** (2 changes):
- Update directory structure diagram
- Update vault opening instructions

**EXTENSION.md** (1 change):
- Update directory structure diagram

**context/project/memory/*.md** (4 files, ~12 changes total):
- Update all path references
- Update git commands
- Update setup instructions

---

## Files to Update (Not Create)

### Must Update (Path Changes Only):
1. `.opencode/extensions/memory/commands/learn.md` - 4 references
2. `.opencode/extensions/memory/skills/skill-memory/SKILL.md` - 6+ references
3. `.opencode/extensions/memory/data/memory/README.md` - 2 references
4. `.opencode/extensions/memory/EXTENSION.md` - 1 reference
5. `.opencode/extensions/memory/context/project/memory/learn-usage.md` - 4 references
6. `.opencode/extensions/memory/context/project/memory/memory-setup.md` - 2 references
7. `.opencode/extensions/memory/context/project/memory/memory-troubleshooting.md` - 6 references

### Must Move:
1. `.opencode/memory/` → `.memory/` (entire directory with contents)

### No Changes Needed:
- `manifest.json` - Just defines extension structure
- `settings-fragment.json` - MCP server config is correct
- `index-entries.json` - Index paths are relative
- `README.md` files in skills/context - No path references

---

## Scope Clarification

### What Exists (No Action Needed):
- ✅ Memory extension structure at `.opencode/extensions/memory/`
- ✅ skill-memory with complete SKILL.md
- ✅ /learn command definition
- ✅ Context documentation files
- ✅ Data skeleton files
- ✅ Manifest and configuration
- ✅ MCP server configuration

### What Needs to Change:
- 🔧 Move `.opencode/memory/` to `.memory/`
- 🔧 Update path references in 7 extension files

---

## Complexity Assessment

**Corrected Effort**: 2-3 hours (not 4-6)

**Breakdown**:
- Move memory vault directory: 10 minutes
- Update commands/learn.md: 15 minutes
- Update skills/skill-memory/SKILL.md: 30 minutes
- Update data/memory/README.md: 10 minutes
- Update EXTENSION.md: 5 minutes
- Update context/project/memory/*.md: 45 minutes
- Testing and verification: 30 minutes

**Total**: ~2.5 hours

**Risk Level**: Very Low
- Simple find-and-replace operations
- No logic changes
- Easy to verify with grep

---

## Verification Checklist

After implementation:

- [ ] `.memory/` directory exists in repo root
- [ ] `.opencode/memory/` no longer exists (or is a symlink)
- [ ] No `.opencode/memory/` references in extension files
- [ ] All extension files reference `.memory/` correctly
- [ ] `.memory/` contains existing memory files
- [ ] Git status shows directory move (not delete+create)

**Verification Command**:
```bash
# Check for old paths (should return nothing)
grep -r "\.opencode/memory" .opencode/extensions/memory/ --include="*.md" --include="*.json"

# Check new paths exist
ls -la .memory/
ls -la .memory/10-Memories/
```

---

## Key Insight

The memory extension is a **working system** that just needs **path updates**. When other repos load this extension via `<leader>ao`, they will get the corrected paths and the system will work like Vision.

The extension's `data/memory/` directory contains skeleton files that get copied to the repo's `.memory/` directory when the extension is loaded. The skeleton files also need path updates so they reference the correct location.

---

## References

- Vision Repository: `/home/benjamin/Projects/Logos/Vision/`
- Vision Commits: `6b2a40b`, `277dcb2`
- Neovim Extension: `/home/benjamin/.config/nvim/.opencode/extensions/memory/`
- Previous (incorrect) Research: `research-001.md` (superseded by this report)

---

## Prior Research Correction

The initial research incorrectly assumed new components needed to be created. This corrected research shows that:

1. The memory extension **already exists** and is complete
2. The task is **configuration updates only**
3. No new files need to be created
4. The scope is smaller than initially estimated (2-3 hours vs 4-6 hours)
