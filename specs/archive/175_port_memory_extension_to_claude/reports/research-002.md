# Research Report: Task #175 - Memory System Changes Update

**Task**: 175 - port_memory_extension_to_claude  
**Original Research**: 2026-03-10T00:30:00Z  
**Update Research**: 2026-03-11T01:20:00Z  
**Effort**: 30 minutes (review only)  
**Sources/Inputs**: 
- Task 176 implementation plan: `specs/176_port_vision_memory_system_changes_to_neovim/plans/implementation-002.md`
- Current state of `.opencode/extensions/memory/`
- Original research: `specs/175_port_memory_extension_to_claude/reports/research-001.md`

---

## Executive Summary

Since the original research for task 175 was completed, **significant architectural changes** have been made to the memory system in `.opencode/` (via task 176). The memory vault has been moved from `.opencode/memory/` to `.memory/` (repository root) following the "Vision" architecture pattern.

**Critical Finding**: When porting the memory extension to `.claude/`, it should use `.memory/` (repo root) rather than `.claude/memory/` as originally planned.

---

## Key Changes Since Original Research

### 1. Memory Vault Location Changed

| Aspect | Original Research (Mar 10) | Current State (Mar 11) |
|--------|---------------------------|------------------------|
| **Vault Location** | `.opencode/memory/` | `.memory/` (repo root) |
| **Architecture** | Nested in agent config | Vision-style, repo-level |
| **Extension Path** | `.opencode/extensions/memory/` | Unchanged |

**Impact**: The original research assumed the port would create `.claude/memory/`. The updated understanding is that the ported extension should also use `.memory/` at the repo root.

### 2. Files Updated in Task 176

The following files in `.opencode/extensions/memory/` were updated to use `.memory/` paths:

| File | Changes | Status |
|------|---------|--------|
| `commands/learn.md` | 4 path references updated | [✓] Complete |
| `skills/skill-memory/SKILL.md` | 8 path references updated | [✓] Complete |
| `context/project/memory/learn-usage.md` | 4 path references updated | [✓] Complete |
| `context/project/memory/memory-setup.md` | 2 path references updated | [✓] Complete |
| `context/project/memory/memory-troubleshooting.md` | 6 path references updated | [✓] Complete |
| `data/memory/README.md` | 2 path references updated | [✓] Complete |
| `EXTENSION.md` | 1 path reference updated | [✓] Complete |

**Total**: ~27 path reference changes across 7 files

### 3. Manifest.json Still References .opencode/

The `manifest.json` merge targets still reference `.opencode/` paths:

```json
{
  "merge_targets": {
    "opencode_md": {
      "target": ".opencode/AGENTS.md"
    },
    "settings": {
      "target": ".opencode/settings.local.json"
    },
    "index": {
      "target": ".opencode/context/index.json"
    }
  }
}
```

This is correct because the extension is still located in `.opencode/extensions/memory/`. When porting to `.claude/`, these would change to `.claude/CLAUDE.md`, etc.

---

## Updated Porting Strategy

### Original Strategy (from research-001.md)

1. Copy `.opencode/extensions/memory/` to `.claude/extensions/memory/`
2. Replace `.opencode/memory/` with `.claude/memory/`
3. Update manifest merge targets

### Revised Strategy (incorporating Vision changes)

1. **Copy extension directory**: `cp -r .opencode/extensions/memory/ .claude/extensions/memory/`
2. **Update paths to use `.memory/`**: 
   - Replace `.opencode/memory/` with `.memory/`
   - The extension already uses `.memory/` (from task 176 updates)
3. **Update manifest.json**:
   - Change merge target paths from `.opencode/` to `.claude/`
   - Change section_id from `extension_oc_memory` to `extension_memory`
   - Change merge target key from `opencode_md` to `claudemd`
4. **Update documentation**:
   - Replace `OC_N` format with plain `N` format in documentation
   - Update any remaining `.opencode/` references to `.claude/`

### Key Path Mapping

| Source Path (.opencode/) | Ported Path (.claude/) | Notes |
|--------------------------|------------------------|-------|
| `.opencode/memory/` | `.memory/` | Same target - repo root |
| `.opencode/AGENTS.md` | `.claude/CLAUDE.md` | Config file merge target |
| `.opencode/settings.local.json` | `.claude/settings.local.json` | Settings merge target |
| `.opencode/context/index.json` | `.claude/context/index.json` | Index merge target |

---

## Implications for Port

### What Stays the Same

1. **Memory vault location**: Both systems now use `.memory/` at repo root
2. **Vault structure**: Same Obsidian-compatible structure (10-Memories/, 20-Indices/, etc.)
3. **Commands**: `/learn` command works identically
4. **MCP integration**: Same obsidian-memory server configuration
5. **Extension structure**: Same manifest, commands, skills, context layout

### What Changes

1. **Manifest merge targets**: Update from `.opencode/` to `.claude/`
2. **Section IDs**: `extension_oc_memory` -> `extension_memory`
3. **Config key**: `opencode_md` -> `claudemd`
4. **Task format**: `OC_N` -> `N` in documentation references

### Shared Memory Vault Consideration

Since both systems would use `.memory/` at the repo root:
- [ ] **Decision needed**: Should `.opencode/` and `.claude/` share the same memory vault?
- **Pros**: Single source of truth, memories work across both systems
- **Cons**: Potential conflicts if both systems active simultaneously
- **Recommendation**: Yes, share the vault - use same `.memory/` location

---

## Verification Commands

After porting, verify:

```bash
# 1. Check no old .opencode/memory paths remain
grep -r "\.opencode/memory" .claude/extensions/memory/ \
  --include="*.md" --include="*.json"
# Should return nothing

# 2. Check new paths are correct
grep -r "\.memory/" .claude/extensions/memory/ \
  --include="*.md" --include="*.json" | wc -l
# Should show ~27 references

# 3. Verify manifest.json
cat .claude/extensions/memory/manifest.json | jq '.merge_targets'
# Should show .claude/ paths, not .opencode/
```

---

## References

- **Original Research**: `specs/175_port_memory_extension_to_claude/reports/research-001.md`
- **Task 176 Plan**: `specs/176_port_vision_memory_system_changes_to_neovim/plans/implementation-002.md`
- **Source Extension**: `.opencode/extensions/memory/`
- **Current Memory Vault**: `.memory/` (repo root)

---

## Decisions Required

| Decision | Options | Recommendation |
|----------|---------|----------------|
| Shared vault? | Yes / No | Yes - use `.memory/` for both systems |
| Port timing? | After task 176 completes / Now | Can proceed now - task 176 is complete |
| Data migration? | Copy existing memories / Fresh start | Copy if any memories exist in `.opencode/memory/` |

---

**Report Status**: Complete  
**Next Step**: Update implementation plan to reflect `.memory/` path usage instead of `.claude/memory/`
