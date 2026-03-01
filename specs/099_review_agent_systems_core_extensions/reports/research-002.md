# Research Report: Task #99 (Supplementary)

**Task**: 99 - review_agent_systems_core_extensions
**Started**: 2026-03-01T00:00:00Z
**Completed**: 2026-03-01T02:00:00Z
**Effort**: 3-5 hours
**Dependencies**: None
**Sources/Inputs**: Codebase exploration, Claude Code official documentation (skills, subagents, plugins, CLI reference), previous research-001.md and implementation-001.md
**Artifacts**: specs/099_review_agent_systems_core_extensions/reports/research-002.md
**Standards**: report-format.md

## Executive Summary

- The previous plan proposed symlink-based extensions; the user requires DIRECT INTEGRATION instead
- Claude Code's native plugin system (`--plugin-dir`, `.claude-plugin/plugin.json`) provides a formal mechanism for packaging and loading extension components, but operates at session-launch time and requires CLI flags
- The recommended architecture uses a **hybrid approach**: extensions stored as self-contained directories with manifest files, loaded into the active `.claude/` system via file copying (not symlinks) when activated through `<leader>ac`
- The existing `<leader>ac` picker infrastructure (parser.lua, sync.lua, scan.lua) already implements global-to-local artifact copying, providing a proven foundation for extension loading
- The `index.json` context discovery system needs extension-aware path resolution to support context files that live in extension directories

## Context & Scope

This is supplementary research addressing the user's revised requirements. The user rejected the symlink-based extension approach from research-001.md and implementation-001.md, requesting instead:

1. `nvim/.claude/` as the core system with ALL general capabilities
2. An `extensions/` directory storing self-contained extension packs
3. `<leader>ac` integration that DIRECTLY INTEGRATES extension components into the active core system

This research explores integration mechanisms, project-local configuration, loading/unloading workflows, and `<leader>ac` UI integration.

## Findings

### 1. Claude Code Component Discovery Mechanisms

Claude Code discovers components through filesystem scanning at specific well-known paths. Understanding this is critical for determining how extensions must integrate.

#### Discovery Hierarchy (highest priority first)

| Level | Location | Scope |
|-------|----------|-------|
| Enterprise | Managed settings | Organization-wide |
| Personal | `~/.claude/{skills,agents,commands}/` | All projects |
| Project | `.claude/{skills,agents,commands}/` | Current project |
| Plugin | `<plugin>/skills/` (via `--plugin-dir`) | Where enabled |
| Nested | `packages/*/`.claude/skills/` | Subdirectory discovery |
| Additional | `--add-dir` paths | Session-scoped |

**Key insight**: Claude Code scans `.claude/commands/`, `.claude/skills/`, `.claude/agents/`, and `.claude/rules/` at the project level. Files MUST be in these standard directories to be discovered. There is no "include path" or "search path" mechanism for custom locations.

#### What this means for extensions

Extension components MUST ultimately reside in (or be copied into) the standard `.claude/` directories to be usable by Claude Code. Options:

| Approach | Mechanism | Pros | Cons |
|----------|-----------|------|------|
| **File copying** | Copy extension files into `.claude/` on load | Reliable discovery, no runtime dependencies | Disk duplication, harder to track origin |
| **Plugin system** | Use `--plugin-dir` at session start | Native Claude Code support, namespaced | Requires session restart, CLI flag management |
| **Symlinks** | Create symlinks in `.claude/` pointing to extensions/ | No duplication, easy to track | User rejected this approach |
| **`--add-dir`** | Add extension dir as additional working directory | Skills auto-discovered | Only loads skills, not full .claude/ integration |

**Recommended**: File copying for commands/skills/agents/rules/context (proven by existing sync.lua infrastructure). Consider plugin system integration as a future enhancement.

### 2. Existing Infrastructure Analysis

The Neovim `<leader>ac` picker system already has sophisticated sync infrastructure that can be adapted for extension loading.

#### Current `sync.lua` Capabilities

The `load_all_globally()` function in `sync.lua` already:
- Scans all artifact types from a source directory (global_dir)
- Copies files to a target directory (project_dir) preserving structure
- Handles nested subdirectories recursively (lib/, docs/, skills/)
- Preserves file permissions for shell scripts
- Provides merge-only mode (copy new files only) vs full sync (replace existing)
- Reports detailed sync counts by category
- Prompts user for confirmation before operations

**This is essentially an extension loader already**. The only difference is the source: currently it loads from `~/.config/nvim/.claude/` (global), and for extensions it would load from `extensions/{name}/`.

#### Current `scan.lua` Capabilities

- `scan_directory_for_sync(global_dir, local_dir, subdir, extension, recursive)` - Compares source and target, reports copy/replace actions
- `merge_artifacts(local, global)` - Deduplication with local-priority override
- `get_global_dir()` - Configurable source directory

#### Current `parser.lua` Capabilities

- `get_extended_structure()` - Scans commands, skills, agents, hooks, root files from both project and global dirs
- `parse_with_fallback(project_dir, global_dir)` - Local-priority merging
- Already handles the two-tier discovery pattern

### 3. Integration Mechanism: File Copying with Metadata Tracking

The recommended approach is **file copying with manifest-based tracking**.

#### Extension Directory Structure

```
extensions/                          # Lives alongside .claude/ (sibling)
├── registry.json                    # Tracks available + active extensions per project
├── lean/                            # Self-contained extension pack
│   ├── manifest.json                # Extension metadata, dependencies, file listing
│   ├── commands/                    # Commands to integrate
│   │   ├── lake.md
│   │   └── lean.md
│   ├── skills/                      # Skills to integrate
│   │   ├── skill-lean-research/
│   │   │   └── SKILL.md
│   │   ├── skill-lean-implementation/
│   │   │   └── SKILL.md
│   │   ├── skill-lake-repair/
│   │   │   └── SKILL.md
│   │   └── skill-lean-version/
│   │       └── SKILL.md
│   ├── agents/                      # Agents to integrate
│   │   ├── lean-research-agent.md
│   │   └── lean-implementation-agent.md
│   ├── rules/                       # Rules to integrate
│   │   └── lean4.md
│   ├── context/                     # Context files to integrate
│   │   └── project/
│   │       └── lean4/
│   │           ├── domain/
│   │           ├── patterns/
│   │           ├── standards/
│   │           └── tools/
│   ├── scripts/                     # Scripts to integrate
│   │   ├── setup-lean-mcp.sh
│   │   └── verify-lean-mcp.sh
│   └── settings-fragment.json       # MCP servers, permissions to merge
├── latex-research/                  # Another extension
│   ├── manifest.json
│   ├── skills/
│   │   └── skill-latex-research/
│   │       └── SKILL.md
│   └── agents/
│       └── latex-research-agent.md
└── neovim/                          # Neovim extension (always active in nvim)
    ├── manifest.json
    └── ...
```

#### Where extensions/ Lives

Two viable locations:

| Location | Path | Pros | Cons |
|----------|------|------|------|
| **Sibling of .claude/** | `nvim/extensions/` | Clean separation, gitignore-friendly | Not inside .claude/ ecosystem |
| **Inside .claude/** | `nvim/.claude/extensions/` | Part of .claude/ system, travels with it | Could be scanned by Claude Code |

**Recommendation**: Inside `.claude/extensions/` -- keeps the entire system self-contained. Add `extensions/` to `.claude/.gitignore` pattern if extension content should not be committed. However, since extensions represent reusable packs that should be version-controlled in the global system, placing them at `.claude/extensions/` in the global nvim config makes sense.

#### Manifest Schema

```json
{
  "name": "lean",
  "version": "1.0.0",
  "description": "Lean 4 formal verification support",
  "dependencies": ["math"],
  "language": "lean",
  "provides": {
    "commands": ["lake.md", "lean.md"],
    "skills": ["skill-lean-research", "skill-lean-implementation", "skill-lake-repair", "skill-lean-version"],
    "agents": ["lean-research-agent.md", "lean-implementation-agent.md"],
    "rules": ["lean4.md"],
    "context": ["project/lean4/"],
    "scripts": ["setup-lean-mcp.sh", "verify-lean-mcp.sh"]
  },
  "settings_fragment": {
    "permissions": {
      "allow": ["mcp__lean-lsp__*"]
    },
    "enabledMcpjsonServers": ["lean-lsp"]
  },
  "mcp_servers": {
    "lean-lsp": {
      "required": true,
      "setup_script": "setup-lean-mcp.sh",
      "verify_script": "verify-lean-mcp.sh"
    }
  }
}
```

### 4. Loading and Unloading Workflow

#### Load Extension

When a user activates an extension through `<leader>ac`:

1. **Read manifest.json** from `extensions/{name}/`
2. **Check dependencies** -- activate required extensions first
3. **Copy components** into active `.claude/`:
   - `extensions/{name}/commands/*.md` -> `.claude/commands/`
   - `extensions/{name}/skills/skill-*/` -> `.claude/skills/`
   - `extensions/{name}/agents/*.md` -> `.claude/agents/`
   - `extensions/{name}/rules/*.md` -> `.claude/rules/`
   - `extensions/{name}/context/**` -> `.claude/context/`
   - `extensions/{name}/scripts/*.sh` -> `.claude/scripts/`
4. **Merge settings** -- merge `settings_fragment` into `settings.json` (additive only)
5. **Regenerate index.json** -- run `generate-context-index.sh` or append entries
6. **Update registry.json** -- mark extension as active, record file manifest
7. **Update CLAUDE.md** -- add extension's language routing, skill-agent mapping

The file manifest in registry.json tracks exactly which files were installed:

```json
{
  "extensions": {
    "lean": {
      "active": true,
      "loaded_at": "2026-03-01T12:00:00Z",
      "installed_files": [
        ".claude/commands/lake.md",
        ".claude/commands/lean.md",
        ".claude/skills/skill-lean-research/SKILL.md",
        ".claude/agents/lean-research-agent.md",
        ".claude/rules/lean4.md"
      ]
    }
  }
}
```

#### Unload Extension

When a user deactivates an extension:

1. **Read installed_files** from registry.json
2. **Remove each installed file** (only files listed in manifest, not user modifications)
3. **Check dependents** -- warn if other active extensions depend on this one
4. **Clean settings** -- remove settings_fragment entries from settings.json
5. **Regenerate index.json**
6. **Update registry.json** -- mark extension as inactive, clear installed_files
7. **Update CLAUDE.md** -- remove extension's entries

#### Conflict Detection

Before loading, check for conflicts:

- **Same-named file already exists**: Warn user, offer to skip or overwrite
- **Modified file would be overwritten**: Compare checksums, warn if local file differs from extension version
- **Dependency not available**: Error if required extension is missing

### 5. Project-Local Configuration

Extensions loaded for a specific project vs the global system need different handling.

#### Approach: Project-Specific Registry

Each project that uses Claude Code already has its own `.claude/` directory (created by `load_all_globally()`). The extension registry tracks state per-project:

**Global registry** (at `~/.config/nvim/.claude/extensions/registry.json`):
- Lists all AVAILABLE extensions
- Stores extension manifests/metadata
- Default activation state

**Project registry** (at `{project}/.claude/extensions/registry.json`):
- Which extensions are ACTIVE for this project
- Overrides global defaults
- Created on first extension toggle

When `<leader>ac` opens in a project:
1. Read global registry for available extensions
2. Read project registry for active state (falls back to global defaults)
3. Show combined view with project-specific status

### 6. `<leader>ac` Integration Design

#### Current `<leader>ac` Behavior

In normal mode: Opens ClaudeCommands picker (Telescope) showing all .claude/ artifacts organized by category (Commands, Skills, Agents, Hooks, etc.) with sync operations (Ctrl-l load, Ctrl-u update, Ctrl-s save).

In visual mode: Sends selection to Claude with prompt.

#### Proposed Extension Management UI

Option A: **Add "Extensions" section to existing picker**

Add an `[Extensions]` heading section to the existing ClaudeCommands picker, showing available extensions with active/inactive status. Toggle with Enter key.

```
[Commands]
  /task                    Create and manage tasks
  /research                Research task
  ...
[Skills]
  skill-researcher         General web/codebase research
  ...
[Extensions]                Extension packs
  lean       [active]       Lean 4 formal verification
  neovim     [active]       Neovim development
  latex      [inactive]     LaTeX document authoring
  typst      [inactive]     Typst document authoring
  logic      [inactive]     Mathematical logic
```

Pros: Single picker, consistent UX, no new keybinding needed
Cons: Mixes browsing with management, picker gets longer

Option B: **Dedicated extension picker on separate keybinding**

Create `<leader>ae` or add submenu to `<leader>ac` that opens a dedicated extension manager picker.

Pros: Clean separation of concerns, focused UI
Cons: Another keybinding to remember

Option C: **Submenu approach via which-key**

Add `<leader>ae` under the existing `<leader>a` (ai) group:
- `<leader>ac` -- Claude commands (existing)
- `<leader>ae` -- Claude extensions (new)

Pros: Discoverable via which-key, clean separation, no change to existing picker
Cons: Requires new Lua module for extension picker

**Recommendation**: Option C (submenu with `<leader>ae`). It preserves the existing `<leader>ac` behavior completely while adding a focused extension management UI. The which-key group already exists (`<leader>a` = ai), so adding `e` for extensions is natural.

#### Extension Picker Implementation

The extension picker would:
1. Scan `~/.config/nvim/.claude/extensions/` for available extensions
2. Read project-local registry for active/inactive state
3. Display in Telescope with:
   - Extension name
   - Active/inactive status (icon indicator)
   - Description from manifest
   - Language tag
   - Dependency info in preview
4. Actions:
   - Enter: Toggle active/inactive (runs load/unload workflow)
   - Ctrl-i: Show manifest details in preview
   - Ctrl-d: Show dependency tree
   - Ctrl-r: Reload extension (unload + load, picks up changes)

### 7. Settings Fragment Merging

Extensions may need to modify `settings.json` (e.g., adding MCP server permissions). This requires careful merging.

#### Merge Strategy

For `permissions.allow`: **Append** extension entries, tagged with source:
```json
{
  "permissions": {
    "allow": [
      "Bash(git:*)",
      "Read",
      "mcp__lean-lsp__*"
    ]
  }
}
```

The extension loader would:
1. Read current settings.json
2. Read extension's settings_fragment
3. Merge `permissions.allow` arrays (deduplicate)
4. Add `enabledMcpjsonServers` entries
5. Write merged settings.json
6. On unload: Remove only entries that came from the extension

**Tracking**: Store the original settings.json state before first extension load, or track per-extension additions in the registry.

### 8. Index.json Integration

Context files from extensions need to appear in index.json for agent discovery.

#### Approach: Regeneration on Load/Unload

After copying context files from an extension:
1. Run `generate-context-index.sh` to rebuild index.json
2. The script scans `.claude/context/` recursively and builds entries

Or, more efficiently:
1. Extension manifest includes pre-built index entries
2. On load: Append entries to index.json
3. On unload: Remove entries by path prefix match

**Manifest with index entries**:
```json
{
  "index_entries": [
    {
      "path": "project/lean4/domain/lean-tactics.md",
      "domain": "project",
      "subdomain": "lean4",
      "topics": ["lean", "tactics"],
      "summary": "Lean 4 tactic reference",
      "line_count": 200,
      "load_when": {
        "agents": ["lean-research-agent"],
        "languages": ["lean"]
      }
    }
  ]
}
```

### 9. CLAUDE.md Integration

Extensions may need to add entries to CLAUDE.md (language routing, skill-agent mapping, etc.).

#### Approach: Section Markers

CLAUDE.md already uses `<!-- SECTION: -->` markers. Extensions can define CLAUDE.md fragments that get inserted between markers:

```
<!-- SECTION: extension_lean -->
### Lean Extension
| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `lean` | WebSearch, WebFetch, Read, mcp__lean-lsp__* | Read, Write, Edit, Bash, mcp__lean-lsp__* |
<!-- END_SECTION: extension_lean -->
```

On load: Insert section. On unload: Remove section by markers.

### 10. Comparison with Claude Code Plugin System

Claude Code's native plugin system is highly relevant but serves a different use case:

| Aspect | Claude Code Plugins | Our Extension System |
|--------|--------------------|--------------------|
| Loading | `--plugin-dir` flag at session start | `<leader>ae` toggle during session |
| Scope | Session-scoped | Project-persistent |
| Namespacing | `plugin-name:skill-name` | Direct integration (no namespace) |
| Discovery | Automatic by Claude Code | Requires file copying into .claude/ |
| Hot reload | Restart required | Immediate (files already in .claude/) |
| Settings | Plugin's settings.json | Settings fragment merge |

**Future bridge**: We could generate a Claude Code plugin from an extension pack, allowing `claude --plugin-dir extensions/lean` as an alternative loading mechanism. This would give namespaced skills (`/lean:lake`) while our direct integration gives unnnamespaced ones (`/lake`).

## Decisions

1. **File copying over symlinks** -- user requirement, and it ensures Claude Code discovers all components through standard paths
2. **Extensions inside .claude/extensions/** -- keeps the entire system self-contained and portable
3. **`<leader>ae` for extension management** -- preserves existing `<leader>ac` behavior, discoverable via which-key
4. **Manifest-based tracking in registry.json** -- enables clean unloading by recording exactly which files were installed
5. **Pre-built index entries in manifest** -- avoids full index regeneration on every toggle, more efficient
6. **Section markers for CLAUDE.md integration** -- enables clean insertion/removal of extension-specific documentation
7. **Project-local registry** -- allows different projects to have different extensions active

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| File copy creates divergence from extension source | Medium - local modifications lost on reload | Track checksums, warn on overwrite of modified files |
| Large extensions slow down loading | Low - one-time copy operation | Lazy loading (only copy when first needed) |
| Settings.json merge conflicts | High - broken settings block Claude Code | Backup settings before merge, validate after merge |
| CLAUDE.md section markers get corrupted | Medium - manual cleanup needed | Validate marker pairs before/after operations |
| Extension unload misses files | Medium - orphaned files clutter system | Registry tracks all installed files, verify on unload |
| Claude Code restart needed for some changes | Medium - UX friction | Document which changes need restart vs immediate |
| Dependency chain causes cascading loads | Low - most extensions are independent | Topological sort, confirm before loading chain |

## Recommendations

### Implementation Priority

1. **Phase 1: Extension pack structure** -- Create manifest schema, build lean and neovim extension packs from existing ProofChecker/nvim components
2. **Phase 2: Load/unload engine** -- Lua module that reads manifests and copies files (adapt sync.lua patterns)
3. **Phase 3: Registry tracking** -- registry.json for state management and clean unloading
4. **Phase 4: `<leader>ae` picker** -- Telescope picker for extension management
5. **Phase 5: Settings/index/CLAUDE.md integration** -- Automated merge/regeneration on toggle
6. **Phase 6: Core additions from research-001** -- Port the 22 missing core context files independently of extension system

### Key Technical Decision: Copy vs Plugin

The file copying approach is recommended for the MVP because:
- It works with the current Claude Code discovery mechanism without modification
- It does not require CLI flags or session restarts
- It matches the user's "direct integration" requirement
- The existing sync.lua infrastructure provides a proven implementation pattern

However, the manifest schema should be designed to be compatible with Claude Code's plugin format, enabling a future path where extensions can ALSO be loaded as plugins.

## Appendix

### Search Methodology

1. Read previous research-001.md and implementation-001.md for baseline understanding
2. Explored nvim `.claude/` directory structure (settings.json, settings.local.json)
3. Read the complete `<leader>ac` picker implementation chain (init.lua -> parser.lua -> scan.lua -> sync.lua -> registry.lua)
4. Fetched official Claude Code documentation for skills, subagents, plugins, and CLI reference
5. Compared ProofChecker and nvim `.claude/` component inventories
6. Analyzed the existing global-to-local sync mechanism for adaptation to extension loading

### References

- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills) - Discovery hierarchy, skill frontmatter, auto-loading
- [Claude Code Subagents Documentation](https://code.claude.com/docs/en/sub-agents) - Agent definitions, built-in agents, custom agents
- [Claude Code Plugins Documentation](https://code.claude.com/docs/en/plugins) - Plugin structure, namespacing, distribution
- [Claude Code CLI Reference](https://code.claude.com/docs/en/cli-reference) - `--add-dir`, `--plugin-dir`, `--agents` flags
- `nvim/lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Existing global-to-local sync implementation
- `nvim/lua/neotex/plugins/ai/claude/commands/parser.lua` - Component discovery and two-tier merging
- `nvim/lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` - Directory scanning and artifact merging

### Key Files Examined

| File | Purpose | Relevance |
|------|---------|-----------|
| `.claude/settings.json` | Permissions, hooks, model config | Extension settings fragment target |
| `.claude/settings.local.json` | Local overrides, MCP servers | Extension MCP integration target |
| `parser.lua` | Component discovery from .claude/ dirs | Extension files must land in scanned dirs |
| `sync.lua` | Global-to-local artifact copying | Foundation for extension loading engine |
| `scan.lua` | Directory scanning, merging | Foundation for extension scanning |
| `registry.lua` | Artifact type definitions | Needs extension artifact type |
| `init.lua` (picker) | Telescope picker orchestration | Extension picker will follow same pattern |
| `which-key.lua` | Keybinding groups | `<leader>ae` registration point |
| `context/index.json` | Context file discovery | Extension context integration target |
