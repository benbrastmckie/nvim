# Research Report: Task #187

**Task**: 187 - port_memory_extension_to_claude
**Date**: 2026-03-11
**Focus**: Complete file-by-file porting checklist with exact transformations for .opencode/ to .claude/
**Session**: sess_1773360000_a7b8c9

## Summary

This report provides a comprehensive file-by-file porting checklist for migrating the memory extension from `.opencode/extensions/memory/` to `.claude/extensions/memory/`. All source files have been audited, transformations documented, and dependencies verified. Task 179 (data directory bug) is now COMPLETED, enabling correct `.memory/` placement at repo root.

---

## Findings

### 1. Source File Inventory

**Total files to port**: 24 files across 6 directories

| Directory | File Count | Purpose |
|-----------|------------|---------|
| Root | 5 | manifest.json, EXTENSION.md, index-entries.json, settings-fragment.json, README.md |
| commands/ | 2 | learn.md, README.md |
| skills/skill-memory/ | 2 | SKILL.md, README.md |
| context/project/memory/ | 5 | learn-usage.md, memory-setup.md, memory-troubleshooting.md, knowledge-capture-usage.md, README.md |
| context/ | 1 | README.md |
| data/.memory/ | 9 | Vault skeleton (templates, indices, READMEs) |

### 2. File-by-File Porting Checklist

#### Root Directory Files

| Source File | Target File | Transformations |
|-------------|-------------|-----------------|
| `manifest.json` | `manifest.json` | See detailed transformations below |
| `EXTENSION.md` | `EXTENSION.md` | Update merge section ID, fix context @-references |
| `index-entries.json` | `index-entries.json` | Update path prefixes, add skill-memory load_when |
| `settings-fragment.json` | **DELETE** | Claude Code uses .mcp.json, not settings merge |
| `README.md` | `README.md` | No changes needed |

#### manifest.json Transformations

```diff
- "merge_targets": {
-   "opencode_md": {
-     "source": "EXTENSION.md",
-     "target": ".opencode/AGENTS.md",
-     "section_id": "extension_oc_memory"
-   },
-   "settings": {
-     "source": "settings-fragment.json",
-     "target": ".opencode/settings.local.json"
-   },
-   "index": {
-     "source": "index-entries.json",
-     "target": ".opencode/context/index.json"
-   }
- }
+ "merge_targets": {
+   "claudemd": {
+     "source": "EXTENSION.md",
+     "target": ".claude/CLAUDE.md",
+     "section_id": "extension_memory"
+   },
+   "index": {
+     "source": "index-entries.json",
+     "target": ".claude/context/index.json"
+   }
+ }
```

**Key changes**:
1. `opencode_md` -> `claudemd`
2. Target: `.opencode/AGENTS.md` -> `.claude/CLAUDE.md`
3. Section ID: `extension_oc_memory` -> `extension_memory`
4. **REMOVE** entire `settings` merge target (Claude Code uses .mcp.json at project root)
5. Index target: `.opencode/context/index.json` -> `.claude/context/index.json`

#### EXTENSION.md Transformations

| Line | Current | Target |
|------|---------|--------|
| Section heading | `## Memory Extension` | `## Memory Extension` (no change) |
| Context @-references | `@.opencode/context/project/memory/...` | `@.claude/context/project/memory/...` |
| MCP section | `execute("search", {...})` pattern | Update for obsidian-claude-code-mcp |

**Full content update needed for**:
- MCP Integration section (rewrite for Claude Code approach)
- Context Imports section (update @-references)
- Memory Vault Structure (`.memory/` at repo root - already correct)

#### index-entries.json Transformations

Current paths use relative format. Update all paths to match .claude pattern:

```diff
- "path": "project/memory/learn-usage.md",
+ "path": "project/memory/learn-usage.md",  // Same - already canonical
```

**Add load_when for skill-memory**:
```json
{
  "path": "project/memory/learn-usage.md",
  "description": "Usage guide for /learn command and memory management",
  "load_when": {
    "skills": ["skill-memory"],
    "commands": ["/learn"]
  },
  "line_count": 300
}
```

#### commands/ Directory

| Source File | Target File | Transformations |
|-------------|-------------|-----------------|
| `learn.md` | `learn.md` | No path changes needed (uses skill: "skill-memory") |
| `README.md` | `README.md` | Update parent directory link |

**learn.md recently modified** (per git status):
- Added `**Input**: $ARGUMENTS`
- Improved mode detection (string pattern check before filesystem check)
- No .opencode-specific paths to update

#### skills/skill-memory/ Directory

| Source File | Target File | Transformations |
|-------------|-------------|-----------------|
| `SKILL.md` | `SKILL.md` | Update context @-references, vault paths |
| `README.md` | `README.md` | Update parent directory link |

**SKILL.md recently modified** (per git status):
- Added MANDATORY INTERACTIVE REQUIREMENT warnings
- Added paginated file selection for directory mode
- Added `.memory/10-Memories/README.md` regeneration to index maintenance

**Transformations needed**:

| Section | Current | Target |
|---------|---------|--------|
| Context References | `@.opencode/context/project/memory/...` | Remove .opencode prefix, use canonical `@project/memory/...` |
| Vault paths | `.memory/` (correct) | No change |
| Task directory | `specs/{NNN}_{SLUG}/` | No change |
| Git commit message | `Co-Authored-By: Claude Opus 4.5` | No change |

#### context/project/memory/ Directory

| Source File | Target File | Key Transformations |
|-------------|-------------|---------------------|
| `learn-usage.md` | `learn-usage.md` | Update vault path references |
| `memory-setup.md` | `memory-setup.md` | **FULL REWRITE** for Claude Code MCP |
| `memory-troubleshooting.md` | `memory-troubleshooting.md` | Update for Claude Code context |
| `knowledge-capture-usage.md` | `knowledge-capture-usage.md` | Minor path updates |
| `README.md` | `README.md` | Update navigation links |

**memory-setup.md requires full rewrite**:
- Current: Documents `@dsebastien/obsidian-cli-rest-mcp` with Local REST API plugin
- Target: Document `obsidian-claude-code-mcp` (primary) with fallback to @dsebastien
- Remove: References to `settings.local.json` merge
- Add: `.mcp.json` manual configuration instructions

#### data/.memory/ Directory (Vault Skeleton)

| Source Path | Target Path | Transformations |
|-------------|-------------|-----------------|
| `data/.memory/` | `data/.memory/` | No path change (task 179 fixed) |
| `00-Inbox/README.md` | Same | No changes |
| `10-Memories/README.md` | Same | No changes |
| `20-Indices/index.md` | Same | Update topic path (`meta/` -> keep, it's generic) |
| `20-Indices/README.md` | Same | No changes |
| `30-Templates/memory-template.md` | Same | No changes |
| `30-Templates/README.md` | Same | No changes |
| `README.md` | Same | No changes |

**index.md topic section**:
```markdown
### meta/
<!-- System building and .opencode/ changes -->
```
Change to:
```markdown
### meta/
<!-- System building and .claude/ changes -->
```

### 3. Files to DELETE (Not Ported)

| File | Reason |
|------|--------|
| `settings-fragment.json` | Claude Code uses `.mcp.json` at project root, not settings merge |

### 4. Command Conflict Check: /learn

**Result**: NO CONFLICT

Verified locations checked:
- `.claude/commands/` - No `learn.md` exists
- `.claude/CLAUDE.md` - No `/learn` command listed
- `.claude/rules/` - No reference to `/learn`

The existing `/fix-it` command (formerly `/learn` in some other context) is for tag scanning, not memory management. The memory extension's `/learn` command is distinct.

**Note**: Claude Code built-in commands do not include `/learn` as of current version.

### 5. Dependency Status: Task 179

**Status**: COMPLETED (archived 2026-03-10)

**Summary of fix**:
1. `init.lua:297`: Changed `target_dir` to `project_dir` in `copy_data_dirs` call
2. `manifest.json`: Changed data array from `["memory"]` to `[".memory"]`
3. Source directory renamed: `data/memory/` -> `data/.memory/`

**Implication for port**: The `.claude/` port can use `".memory"` in manifest data field, and the extension loader will correctly copy to `/.memory/` at project root.

### 6. Claude Code-Specific Adaptations Beyond Path Swaps

| Adaptation | Details |
|------------|---------|
| MCP Configuration | Use `.mcp.json` at project root (NOT merge target) |
| Primary MCP Server | `obsidian-claude-code-mcp` (native WebSocket, no API key) |
| Fallback MCP Server | `@dsebastien/obsidian-cli-rest-mcp` with manual `claude mcp add` |
| Settings Merge | REMOVE entirely (Claude Code doesn't use settings.local.json) |
| Agent Model Preferences | None (per task 177 - avoid ProviderModelNotFoundError) |

### 7. MCP Configuration for Claude Code

**Primary approach (obsidian-claude-code-mcp)**:
1. Install Obsidian plugin from Community Plugins
2. Claude Code auto-discovers via WebSocket on port 22360
3. No configuration needed

**Fallback approach (@dsebastien method)**:
1. Install Local REST API plugin in Obsidian
2. Set `OBSIDIAN_API_KEY` environment variable
3. Add to `.mcp.json` at project root:

```json
{
  "mcpServers": {
    "obsidian-memory": {
      "command": "npx",
      "args": ["-y", "@dsebastien/obsidian-cli-rest-mcp@latest"],
      "env": {
        "OBSIDIAN_API_KEY": "${OBSIDIAN_API_KEY}",
        "OBSIDIAN_PORT": "27124"
      }
    }
  }
}
```

Or use Claude CLI:
```bash
claude mcp add obsidian-memory --scope project \
  -- npx -y @dsebastien/obsidian-cli-rest-mcp@latest
```

---

## Complete Porting Checklist

### Phase 1: Copy Structure

- [ ] Create `.claude/extensions/memory/` directory
- [ ] Create subdirectories: `commands/`, `skills/skill-memory/`, `context/`, `context/project/`, `context/project/memory/`, `data/`

### Phase 2: Port Root Files

- [ ] Port `manifest.json` with merge target transformations
- [ ] Port `EXTENSION.md` with @-reference updates
- [ ] Port `index-entries.json` with path updates
- [ ] Port `README.md` (no changes)
- [ ] **Skip** `settings-fragment.json` (not applicable to Claude Code)

### Phase 3: Port Command Files

- [ ] Port `commands/learn.md` (minimal changes, check @-references)
- [ ] Port `commands/README.md` (update parent link)

### Phase 4: Port Skill Files

- [ ] Port `skills/skill-memory/SKILL.md` (update context @-references)
- [ ] Port `skills/skill-memory/README.md` (update parent link)

### Phase 5: Port Context Files

- [ ] Port `context/README.md` (update navigation)
- [ ] Port `context/project/memory/README.md` (update navigation)
- [ ] Port `context/project/memory/learn-usage.md` (minor updates)
- [ ] **Rewrite** `context/project/memory/memory-setup.md` for Claude Code
- [ ] Port `context/project/memory/memory-troubleshooting.md` (update context)
- [ ] Port `context/project/memory/knowledge-capture-usage.md` (minor updates)

### Phase 6: Port Data Directory

- [ ] Copy `data/.memory/` structure (all subdirectories and files)
- [ ] Update `data/.memory/20-Indices/index.md` topic comment

### Phase 7: Verification

- [ ] Verify manifest.json validates with `jq .`
- [ ] Verify index-entries.json validates with `jq .`
- [ ] Check no `.opencode/` paths remain in any ported file
- [ ] Verify EXTENSION.md section_id matches manifest
- [ ] Test extension loading (if extension loader available)

---

## Recommendations

1. **Port in single commit**: All 23 ported files should be committed together for atomic change
2. **memory-setup.md first**: The MCP documentation rewrite is the most complex change; draft it early
3. **Test with grep**: After porting, run `grep -r ".opencode" .claude/extensions/memory/` to catch any missed references
4. **Update EXTENSION.md last**: It requires the most content changes beyond simple path substitution

---

## References

- Prior research: `specs/175_port_memory_extension_to_claude/reports/research-003.md`
- Task 179 summary: `specs/archive/179_fix_memory_extension_data_directory_loading/summaries/implementation-summary-20260310.md`
- Reference .claude extension: `.claude/extensions/nvim/` (for manifest pattern)
- Claude Code MCP docs: https://code.claude.com/docs/en/mcp
- obsidian-claude-code-mcp: https://github.com/iansinnott/obsidian-claude-code-mcp

---

## Next Steps

Create implementation plan with:
1. Phase 1: Directory structure and root files
2. Phase 2: Commands and skills
3. Phase 3: Context documentation (including memory-setup.md rewrite)
4. Phase 4: Data directory and verification
