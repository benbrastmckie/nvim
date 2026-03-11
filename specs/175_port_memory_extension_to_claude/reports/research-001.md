# Research Report: Task #175

**Task**: 175 - port_memory_extension_to_claude
**Started**: 2026-03-10T00:00:00Z
**Completed**: 2026-03-10T00:30:00Z
**Effort**: 1-2 hours (implementation)
**Dependencies**: Task 174 (memory extension for .opencode/) - completed
**Sources/Inputs**: Codebase exploration of .opencode/extensions/memory/, .claude/extensions/, shared extension loader
**Artifacts**: specs/175_port_memory_extension_to_claude/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- The memory extension in `.opencode/extensions/memory/` is a complete, well-structured extension with commands, skills, context, and data directories
- The `.claude/` extension system is structurally very similar to `.opencode/` but has specific naming differences in manifest merge targets, config files, and agent directory layout
- Porting requires updating 4 key areas: manifest.json merge targets, path references in all files (`.opencode/` to `.claude/`), config file names (`AGENTS.md` to `CLAUDE.md`, `opencode_md` to `claudemd`), and command naming (`/learn` exists as a standalone command in `.claude/` as `/fix-it` equivalent)
- The shared extension loader already handles both systems generically - no loader changes needed
- Data directory (memory vault) will be placed at `.claude/memory/` following the same pattern as `.opencode/memory/`

## Context & Scope

This research examines what changes are needed to port the memory extension from `.opencode/extensions/memory/` to `.claude/extensions/memory/`, focusing on structural differences between the two agent systems.

## Findings

### 1. Extension Structure Comparison

Both systems use an identical extension directory layout:

```
extensions/{name}/
  manifest.json
  EXTENSION.md
  index-entries.json
  commands/
  skills/
  context/
  data/           (memory-specific)
```

The shared extension loader (`lua/neotex/plugins/ai/shared/extensions/`) handles both systems via parameterized configuration. No loader modifications are needed.

### 2. Key Structural Differences

| Aspect | .opencode/ | .claude/ | Impact |
|--------|-----------|----------|--------|
| Main config file | AGENTS.md | CLAUDE.md | Merge target change |
| Config file reference | `opencode_md` | `claudemd` | manifest.json key name |
| Settings file target | `settings.local.json` | `settings.local.json` | Same - no change needed |
| Agents directory | `agent/subagents/` | `agents/` | Not applicable (memory has no agents) |
| Section ID prefix | `extension_oc_` | `extension_` | Section ID in manifest |
| Settings merge target | `.opencode/settings.local.json` | `.claude/settings.local.json` | Path update |

### 3. Files Requiring Path Updates

Every file that references `.opencode/` paths needs updating to `.claude/`:

**manifest.json** - Critical changes:
- `merge_targets.opencode_md` key -> `merge_targets.claudemd`
- `merge_targets.opencode_md.target`: `.opencode/AGENTS.md` -> `.claude/CLAUDE.md`
- `merge_targets.opencode_md.section_id`: `extension_oc_memory` -> `extension_memory`
- `merge_targets.settings.target`: `.opencode/settings.local.json` -> `.claude/settings.local.json`
- `merge_targets.index.target`: `.opencode/context/index.json` -> `.claude/context/index.json`

**EXTENSION.md** - Path updates:
- Memory vault structure path: `.opencode/memory/` -> `.claude/memory/`
- All references to `.opencode/` paths

**skills/skill-memory/SKILL.md** - Path updates:
- Template reference: `@.opencode/memory/30-Templates/` -> `@.claude/memory/30-Templates/`
- Index reference: `@.opencode/memory/20-Indices/` -> `@.claude/memory/20-Indices/`
- Context reference: `@.opencode/context/project/memory/` -> `@.claude/context/project/memory/`
- All bash code paths: `.opencode/memory/` -> `.claude/memory/`
- Git commit paths: `git add .opencode/memory/` -> `git add .claude/memory/`

**commands/learn.md** - Path updates:
- State reads/writes paths: `.opencode/memory/` -> `.claude/memory/`

**index-entries.json** - Path updates:
- All `.opencode/context/project/memory/` -> use canonical format `project/memory/` (already correct pattern)

**context/project/memory/*.md** (4 files) - Path updates:
- `memory-setup.md`: `.opencode/memory/` -> `.claude/memory/`, MCP config references
- `learn-usage.md`: `.opencode/memory/` -> `.claude/memory/`, research command syntax (`OC_N` -> `N`)
- `memory-troubleshooting.md`: `.opencode/memory/` -> `.claude/memory/`, all debug commands
- `knowledge-capture-usage.md`: `.opencode/memory/` -> `.claude/memory/`, task references (`OC_N` -> `N`)

**data/memory/** - No changes needed (content is path-agnostic, vault skeleton)

### 4. Command Naming Considerations

The `.opencode/` system has:
- `/fix` command (tag scanning) - equivalent to `.claude/`'s `/fix-it`
- `/learn` command (memory management) - **no equivalent in `.claude/` yet**

The memory extension adds `/learn` as a new command. In `.claude/`, this is safe - there is no existing `/learn` command. The `.opencode/` `/learn` command was renamed from the original tag-scanning `/learn` to `/fix`, so in the `.opencode/` context, `/learn` now exclusively means memory management.

### 5. Task Reference Format

The `.opencode/` system uses `OC_N` task number format in some documentation (e.g., `/research OC_136 --remember`). The `.claude/` system uses plain `N` format (e.g., `/research 136`). Documentation files should be updated accordingly.

### 6. Settings Fragment

The `settings-fragment.json` contains MCP server configuration for `obsidian-memory`. This is the same format for both systems and can be copied directly. The merge target path just needs updating from `.opencode/settings.local.json` to `.claude/settings.local.json`.

### 7. Data Directory Handling

The extension loader's `copy_data_dirs()` function copies data to `{target_dir}/{data_name}`:
- For `.opencode/`: target_dir = `.opencode/`, result = `.opencode/memory/`
- For `.claude/`: target_dir = `.claude/`, result = `.claude/memory/`

This works correctly with no code changes needed. The merge-copy semantics (only copy non-existing files) preserves any existing user memories.

### 8. No Agent Files Needed

The memory extension uses "direct execution" (no separate agent file). The skill-memory SKILL.md contains all execution logic. This is consistent with how both systems handle direct-execution skills.

## Recommendations

### Porting Strategy: Modified Copy

1. **Copy entire directory**: `cp -r .opencode/extensions/memory/ .claude/extensions/memory/`
2. **Bulk path replacement**: `sed -i 's/.opencode/.claude/g'` on all .md and .json files
3. **Fix manifest.json manually**: Update merge target keys and section IDs
4. **Fix task references**: Replace `OC_N` format with plain `N` format in documentation
5. **Review each file**: Verify no `.opencode/`-specific patterns remain

### File-by-File Checklist

| File | Action | Changes |
|------|--------|---------|
| manifest.json | Rewrite | merge_targets keys, paths, section_id |
| EXTENSION.md | Update paths | `.opencode/` -> `.claude/`, section header |
| settings-fragment.json | Copy as-is | No changes needed |
| index-entries.json | Verify canonical paths | Should already use `project/memory/` format |
| commands/learn.md | Update paths | State reads/writes paths |
| skills/skill-memory/SKILL.md | Update paths + refs | All `.opencode/` refs, git paths |
| context/project/memory/*.md | Update paths + refs | All 4 files need path + task format updates |
| data/memory/** | Copy as-is | Vault skeleton is path-agnostic |

### Verification

After porting, use existing validation:
```bash
.claude/scripts/validate-wiring.sh --all
```

And test loading via `<leader>ac` picker.

## Decisions

- The `/learn` command name is appropriate for `.claude/` since no conflict exists
- Data directory goes to `.claude/memory/` (consistent with `.opencode/memory/` pattern)
- MCP server configuration is identical between systems
- No new agents needed (skill uses direct execution)

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Missing path references after bulk replace | Manual review of each file post-replacement |
| `OC_N` task format remnants | Search for `OC_` pattern in all ported files |
| Obsidian vault path in MCP setup docs | Update setup guide to reference `.claude/memory/` |
| Shared memory vault between systems | Each system has its own vault; no sharing needed |

## Appendix

### Search Queries Used

1. `find .opencode/extensions/memory/ -type f` - Enumerated all extension files
2. `ls .claude/extensions/` - Listed existing Claude extensions for pattern reference
3. Read `python/manifest.json` as reference extension
4. Read `shared/extensions/config.lua` - Confirmed config differences
5. Read `shared/extensions/loader.lua` - Confirmed data directory handling
6. Read `shared/extensions/init.lua` - Confirmed load flow passes target_dir for data

### References

- `.opencode/extensions/memory/` - Source extension (20+ files)
- `.claude/extensions/python/` - Reference Claude extension structure
- `lua/neotex/plugins/ai/shared/extensions/config.lua` - System config differences
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` - Data directory copy semantics
- `.claude/extensions/README.md` - Extension architecture documentation
