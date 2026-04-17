# Research Report: Task #472

**Task**: 472 - fix_lean_mcp_script_permissions
**Started**: 2026-04-16T23:58:00Z
**Completed**: 2026-04-16T23:59:30Z
**Effort**: 10 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase (filesystem inspection, loader.lua, helpers.lua, manifest.json)
**Artifacts**: specs/472_fix_lean_mcp_script_permissions/reports/01_script-permissions-fix.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Both `setup-lean-mcp.sh` and `verify-lean-mcp.sh` in `.claude/extensions/core/scripts/` are `-rw-r--r--` (no execute bit), while all other scripts in that directory are `-rwxr-xr-x`.
- The deployed copies at `.claude/scripts/` have identical incorrect permissions (`-rw-r--r--`), confirming the loader copies source permissions verbatim.
- The fix is a two-command `chmod +x` on both source files; a subsequent extension reload will propagate the correct permissions to the deployed copies.

## Context & Scope

Task 472 was created as a follow-up from review task 469. The two Lean MCP helper scripts have shebangs (`#!/usr/bin/env bash`) but are missing execute permissions, making them non-runnable from the shell. The root cause is that the scripts were committed without execute bits set.

## Findings

### Codebase Patterns

**Source permissions (`.claude/extensions/core/scripts/`)**

| File | Permissions |
|------|-------------|
| `setup-lean-mcp.sh` | `-rw-r--r--` (WRONG) |
| `verify-lean-mcp.sh` | `-rw-r--r--` (WRONG) |
| All other `.sh` files | `-rwxr-xr-x` (correct) |

**Deployed permissions (`.claude/scripts/`)**

| File | Permissions |
|------|-------------|
| `setup-lean-mcp.sh` | `-rw-r--r--` (WRONG) |
| `verify-lean-mcp.sh` | `-rw-r--r--` (WRONG) |
| All other `.sh` files | `-rwxr-xr-x` (correct) |

Both scripts have `#!/usr/bin/env bash` shebangs (confirmed by `head -1` inspection).

**Loader mechanism (`lua/neotex/plugins/ai/shared/extensions/loader.lua`)**

The `copy_file()` function in `loader.lua` (lines 14-37) reads source content, writes to target, then calls `helpers.copy_file_permissions(source_path, target_path)` when `preserve_perms=true`. The `copy_scripts()` function (line 253) always passes `preserve_perms=true` for scripts listed in `manifest.provides.scripts`.

The `copy_file_permissions()` function in `helpers.lua` (lines 32-38) uses `vim.fn.getfperm(src)` to read permissions and `vim.fn.setfperm(dest, perms)` to apply them. This is a verbatim copy: if the source lacks the execute bit, the deployed copy will too.

**Manifest listing**

Both scripts appear in `manifest.json` under `provides.scripts`:
```
"setup-lean-mcp.sh",
"verify-lean-mcp.sh",
```

This confirms they will be processed by `copy_scripts()` on next extension load.

### Recommendations

1. `chmod +x` both source files in `.claude/extensions/core/scripts/`:
   ```bash
   chmod +x /home/benjamin/.config/nvim/.claude/extensions/core/scripts/setup-lean-mcp.sh
   chmod +x /home/benjamin/.config/nvim/.claude/extensions/core/scripts/verify-lean-mcp.sh
   ```

2. Also fix the already-deployed copies directly (since the loader only runs on reload):
   ```bash
   chmod +x /home/benjamin/.config/nvim/.claude/scripts/setup-lean-mcp.sh
   chmod +x /home/benjamin/.config/nvim/.claude/scripts/verify-lean-mcp.sh
   ```

3. Verify with `ls -la` after the fix.

4. Commit the source file permission changes so git tracks them.

The entire fix requires no code changes -- only file permission updates.

## Decisions

- Fix both source and deployed copies in the same operation (not just source), since the loader only runs when an extension is explicitly reloaded.
- No changes to loader.lua or helpers.lua needed: the permission-propagation logic is correct; the bug is solely in the source files.

## Risks & Mitigations

- **Risk**: Forgetting to fix deployed copies means scripts remain non-executable until next loader run.
  - **Mitigation**: Fix both locations simultaneously as part of implementation.
- **Risk**: git does not track execute bits on some configurations.
  - **Mitigation**: Run `git ls-files --stage` after commit to confirm mode `100755` is stored.

## Context Extension Recommendations

None for this meta task.

## Appendix

### Files Inspected

- `/home/benjamin/.config/nvim/.claude/extensions/core/scripts/` - source scripts directory
- `/home/benjamin/.config/nvim/.claude/scripts/` - deployed scripts directory
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/loader.lua` - copy engine
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/utils/helpers.lua` - permission helpers
- `/home/benjamin/.config/nvim/.claude/extensions/core/manifest.json` - extension manifest
