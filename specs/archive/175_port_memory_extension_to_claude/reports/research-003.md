# Research Report: Task #175 - Claude Code Integration and Recent Changes Review

**Task**: 175 - port_memory_extension_to_claude
**Started**: 2026-03-10T00:00:00Z
**Completed**: 2026-03-10T01:00:00Z
**Effort**: 1-2 hours (implementation)
**Dependencies**: Task 179 (data directory loading bug - PLANNED, not implemented)
**Sources/Inputs**: Codebase exploration, web research (Claude Code MCP docs, Obsidian MCP plugins), git history (tasks 174-180)
**Artifacts**: specs/175_port_memory_extension_to_claude/reports/research-003.md
**Standards**: report-format.md

---

## Executive Summary

- Claude Code uses `.mcp.json` (project root) for MCP server configuration, NOT `.claude/settings.local.json` - this is a significant difference from the `.opencode/` system that uses `settings.local.json`
- The `obsidian-claude-code-mcp` plugin (by iansinnott) is a superior alternative to `@dsebastien/obsidian-cli-rest-mcp` for Claude Code because it uses native WebSocket auto-discovery on port 22360, eliminating the need for API keys and REST API plugin setup
- Task 179 (data directory loading bug) is still PLANNED - the `copy_data_dirs` function incorrectly places data at `.opencode/memory/` instead of `.memory/` at repo root - this bug also affects the .claude port
- The `.claude/` extension system has no `settings` merge target pattern (unlike `.opencode/`), so MCP configuration must use `.mcp.json` at project root instead
- Recent tasks (177, 178, 180) revealed path naming issues and MCP port misconfigurations that should inform the port design

---

## Context & Scope

This is the third research report for task 175, focused on:
1. Best practices for Obsidian + Claude Code integration
2. Comparing MCP server options available in the ecosystem
3. Reviewing recent git commits (tasks 174-180) that affect design decisions
4. Identifying Claude Code-specific configuration differences from OpenCode

---

## Findings

### 1. Claude Code MCP Configuration is Fundamentally Different

**Critical finding**: Claude Code does NOT use `.claude/settings.local.json` for MCP servers.

| Aspect | OpenCode | Claude Code |
|--------|----------|-------------|
| MCP config location | `.opencode/settings.local.json` | `.mcp.json` (project root) |
| MCP config scope | Inside agent dir | Project root (version-controlled) |
| Config format | `{mcpServers: {...}}` | `{mcpServers: {...}}` (same JSON format) |
| Alternative location | N/A | `~/.claude.json` (user-level) |
| CLI management | N/A | `claude mcp add/remove/list` |

**Source**: Official Claude Code docs at https://code.claude.com/docs/en/mcp

**Key implications for the port**:
1. The `settings-fragment.json` merge target (`settings.local.json`) will NOT work for Claude Code
2. MCP configuration should instead target `.mcp.json` at project root
3. The manifest's `merge_targets.settings` section needs to be reworked or the MCP config approach changed entirely

**Configuration scopes in Claude Code**:
- **local** (default): Stored in `~/.claude.json` under project path, private to user
- **project**: Stored in `.mcp.json` at project root, shared via version control
- **user**: Stored in `~/.claude.json`, available across all projects

### 2. Alternative MCP Server: obsidian-claude-code-mcp

The current `.opencode/` memory extension uses `@dsebastien/obsidian-cli-rest-mcp` which requires:
- Installing the Obsidian Local REST API plugin
- Getting an API key
- Setting the OBSIDIAN_API_KEY environment variable
- Running the MCP server via npx

A newer, Claude Code-native alternative exists: `obsidian-claude-code-mcp` (by iansinnott).

| Feature | @dsebastien/obsidian-cli-rest-mcp | obsidian-claude-code-mcp |
|---------|-----------------------------------|--------------------------|
| Transport | REST API (stdio MCP wrapper) | Native WebSocket + HTTP/SSE |
| Auto-discovery | No (manual config) | Yes (Claude Code auto-detects) |
| API key needed | Yes (OBSIDIAN_API_KEY) | No |
| Extra plugin | Local REST API (coddingtonbear) | Built-in MCP server |
| Port | 27124 | 22360 |
| Claude Code support | Via npx wrapper | Native, first-class |
| Claude Desktop support | Via npx | Via mcp-remote bridge |
| File operations | search, read, write, list | view, str_replace, create, insert |
| Workspace tools | No | get_current_file, get_workspace_files |

**Recommendation**: Consider offering BOTH options in the `.claude/` port:
- `obsidian-claude-code-mcp` as the primary/recommended approach (simpler setup, native integration)
- `@dsebastien/obsidian-cli-rest-mcp` as fallback (broader compatibility, works without Obsidian plugin)

### 3. Task 179: Data Directory Bug (NOT YET FIXED)

**Status**: PLANNED (implementation plan exists, not executed)

Two bugs identified:

**Bug 1**: `init.lua:297` passes `target_dir` instead of `project_dir` to `copy_data_dirs()`:
```lua
-- Current (broken):
local data_files, data_dirs = loader_mod.copy_data_dirs(ext_manifest, source_dir, target_dir)
-- Fix:
local data_files, data_dirs = loader_mod.copy_data_dirs(ext_manifest, source_dir, project_dir)
```
Result: Data goes to `.opencode/memory/` or `.claude/memory/` instead of project root.

**Bug 2**: Manifest says `"memory"` but docs reference `.memory/`:
```json
// Current:
"data": ["memory"]
// Fix:
"data": [".memory"]
```

**Impact on port**: If task 179 is NOT implemented before the port:
- The `.claude/` port will inherit the same bugs
- Data will go to `.claude/memory/` instead of `.memory/`
- The port should either fix the bugs simultaneously or note the dependency

### 4. Recent Git History Analysis (Tasks 174-180)

| Task | Status | Key Finding for Port |
|------|--------|---------------------|
| 174 | completed | Initial study - extension structure is well-documented |
| 175 | researched | This task - original research identified path mapping |
| 176 | completed | Vault moved from `.opencode/memory/` to `.memory/` (repo root) |
| 177 | completed | Removed model preferences from agents (ProviderModelNotFoundError fix) |
| 178 | completed | MCP port was 3000 (wrong), fixed to 27124 |
| 179 | planned | Data directory loading bugs (TWO bugs) - NOT FIXED YET |
| 180 | researched | Path naming issues in opencode.json (agents/ vs agent/subagents/) |

**Key takeaways**:
- Task 176 already updated all `.opencode/extensions/memory/` files to use `.memory/` paths
- Task 177 removed hardcoded model preferences from all agents (avoid in .claude port)
- Task 178 confirmed MCP port should be 27124 for REST API approach
- Task 179 bugs affect both systems and should be addressed

### 5. Claude Code Extension Patterns

The `.claude/` extension system has these differences from `.opencode/`:

| Pattern | .opencode/ | .claude/ |
|---------|-----------|----------|
| Extension dir | `.opencode/extensions/` | `.claude/extensions/` |
| Agents dir | `agent/subagents/` | `agents/` |
| Config merge | `opencode_md` -> `AGENTS.md` | `claudemd` -> `CLAUDE.md` |
| Section prefix | `extension_oc_` | `extension_` |
| Settings merge | `settings.local.json` | NOT APPLICABLE for MCP |
| Index merge | `context/index.json` | `context/index.json` (same) |
| Data dir | Via `copy_data_dirs` (buggy) | Via `copy_data_dirs` (same bug) |

**Existing .claude extensions follow a consistent pattern** (checked nvim, lean, python, etc.):
- `manifest.json` with `claudemd` key (not `opencode_md`)
- `EXTENSION.md` with section content
- `index-entries.json` with canonical paths
- No `settings` merge target (none of the existing .claude extensions have one)

### 6. MCP Configuration Strategy for Claude Code Port

Since Claude Code uses `.mcp.json` (not `settings.local.json`), the port has three options:

**Option A: `.mcp.json` merge target** (NEW)
- Add a new merge target type for `.mcp.json`
- Extension loader would need to understand `.mcp.json` format
- Most architecturally correct but requires loader changes

**Option B: Manual MCP setup**
- Document MCP setup in context files only
- User runs `claude mcp add obsidian-memory ...` manually
- Simplest, no loader changes needed
- Matches how other Claude Code MCP servers are configured

**Option C: obsidian-claude-code-mcp auto-discovery**
- Use the newer plugin that auto-discovers vaults
- No MCP configuration needed in project at all
- User installs Obsidian plugin and it just works
- Simplest user experience

**Recommendation**: Option C as primary approach with Option B as documented fallback. Remove the `settings` merge target from the .claude manifest entirely.

### 7. Command Naming: /learn

The `.claude/` system currently has `/fix-it` (renamed from `/learn`). The memory extension adds `/learn` as a memory management command.

**No conflict exists** - `/learn` for memory is distinct from `/fix-it` for tag scanning.

However, note that Claude Code now has a `/learn` built-in command (or may in the future). Need to verify this does not conflict.

Checked: Claude Code does not have a built-in `/learn` command as of current version. The name is safe.

---

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| MCP approach | obsidian-claude-code-mcp (primary) | Native Claude Code support, no API key needed, auto-discovery |
| MCP config | Remove settings merge target | Claude Code uses .mcp.json, not settings.local.json |
| Vault location | `.memory/` (repo root) | Consistent with task 176 changes, shared between systems |
| Command name | `/learn` | No conflict in .claude system |
| Task 179 dependency | Should fix before or during port | Data directory bug affects both systems |
| Model preferences | None in agents | Per task 177 findings |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Task 179 data dir bug unfixed | Data goes to `.claude/memory/` not `.memory/` | Fix task 179 first, or fix simultaneously in port |
| obsidian-claude-code-mcp unavailable | Users can't use primary MCP approach | Document @dsebastien fallback with manual `claude mcp add` |
| Claude Code adds built-in /learn | Command name conflict | Monitor Claude Code releases, rename if needed |
| .mcp.json not auto-merged | Users must manually configure MCP | Document clear setup steps in memory-setup.md |
| Extension loader has no .mcp.json support | Can't auto-configure MCP on extension load | Use documentation-only approach for MCP setup |

---

## Updated Porting Strategy

### Phase 1: Copy and Adapt Extension Files

1. Copy `.opencode/extensions/memory/` to `.claude/extensions/memory/`
2. Update `manifest.json`:
   - Change `opencode_md` to `claudemd`
   - Change target from `.opencode/AGENTS.md` to `.claude/CLAUDE.md`
   - Change `section_id` from `extension_oc_memory` to `extension_memory`
   - **Remove** `settings` merge target entirely (Claude Code doesn't use it)
   - Change index target from `.opencode/context/index.json` to `.claude/context/index.json`
3. Update `index-entries.json`:
   - Change paths from `.opencode/context/` to canonical `project/memory/` format
4. Files already using `.memory/` paths (from task 176) need minimal changes
5. Remove any `OC_N` task format references, use plain `N`

### Phase 2: Update Documentation for Claude Code

1. `memory-setup.md`: Rewrite for Claude Code MCP configuration
   - Primary: obsidian-claude-code-mcp plugin (auto-discovery)
   - Fallback: `claude mcp add obsidian-memory --transport stdio -- npx -y @dsebastien/obsidian-cli-rest-mcp@latest`
2. `learn-usage.md`: Update command references for .claude system
3. `memory-troubleshooting.md`: Update for Claude Code context
4. `knowledge-capture-usage.md`: Update task format references

### Phase 3: Handle Data Directory (depends on task 179)

If task 179 is fixed first:
- Use `".memory"` in manifest `data` field
- Data automatically goes to repo root

If task 179 is NOT fixed:
- Option A: Fix the bug simultaneously (change `target_dir` to `project_dir` in init.lua)
- Option B: Use `"memory"` in manifest, document manual vault setup

### Phase 4: Update EXTENSION.md

- Update vault structure description
- Update MCP section for Claude Code
- Update skill-agent mapping table

---

## Appendix

### Search Queries Used

1. "Claude Code Obsidian MCP integration memory vault 2026"
2. "obsidian-claude-code-mcp vs obsidian-cli-rest-mcp differences"
3. "claude code settings.json MCP server configuration .claude directory"
4. Official Claude Code MCP docs: https://code.claude.com/docs/en/mcp
5. obsidian-claude-code-mcp GitHub: https://github.com/iansinnott/obsidian-claude-code-mcp
6. Starmorph integration guide: https://blog.starmorph.com/blog/obsidian-claude-code-integration-guide
7. Git log for tasks 174-180

### References

- [Claude Code MCP Documentation](https://code.claude.com/docs/en/mcp)
- [obsidian-claude-code-mcp](https://github.com/iansinnott/obsidian-claude-code-mcp) - Native Claude Code Obsidian plugin
- [Obsidian + Claude Code Integration Guide](https://blog.starmorph.com/blog/obsidian-claude-code-integration-guide) - Starmorph guide
- [@dsebastien/obsidian-cli-rest-mcp](https://github.com/dsebastien/obsidian-cli-rest) - REST API approach (current .opencode implementation)
- [Obsidian MCP servers discussion](https://forum.obsidian.md/t/obsidian-mcp-servers-experiences-and-recommendations/99936) - Community recommendations
- [3 Ways to Use Obsidian with Claude Code](https://awesomeclaude.ai/how-to/use-obsidian-with-claude) - Overview of approaches
- `.opencode/extensions/memory/` - Source extension (20+ files)
- `.claude/extensions/nvim/manifest.json` - Reference .claude extension
- `specs/179_fix_memory_extension_data_directory_loading/reports/research-002.md` - Data directory bug details
- `specs/180_investigate_opencode_claude_dependency/reports/research-001.md` - Path naming issues

---

**Report Status**: Complete
**Next Step**: Create implementation plan incorporating MCP configuration differences and task 179 dependency
