# Research Report: Command Loading Failure in Claude Code v2.1.88+

**Task**: 326 - Upgrade agent system for Claude Code v2.1.88+
**Date**: 2026-03-30
**Session**: sess_1774919807_08893f

## Executive Summary

The 14 commands in `.claude/commands/` are not loading due to a combination of issues: (1) the `Skill` tool -- which now handles both commands and skills -- is missing from the project `settings.json` permissions allow-list, (2) two built-in commands (`/plan` and `/review`) shadow the custom commands of the same name, and (3) the stale model ID `claude-opus-4-5-20251101` used in 12 of 14 commands may contribute to silent load failures. Additionally, `TodoWrite` referenced in allowed-tools for several commands is deprecated in interactive sessions. The `refresh.md` command file has no frontmatter at all, which makes it invisible to the discovery system.

## Findings

### 1. Missing `Skill` Tool in Permissions Allow-List (Critical)

The project-level `settings.json` at `.claude/settings.json` has a `permissions.allow` array that does **not** include the `Skill` tool. Per the official tools reference, `Skill` requires permission (`Permission Required: Yes`). Without it in the allow-list, Claude Code cannot execute the Skill tool, which is the unified mechanism for invoking both commands and skills.

Current allow-list includes: `Bash(git:*)`, `Read`, `Write`, `Edit`, `Glob`, `Grep`, `WebSearch`, `WebFetch`, `Task`, `TodoWrite`, `mcp__lean-lsp__*` -- but no `Skill`.

The global `~/.claude/settings.json` also lacks `Skill` in its allow-list.

**Evidence**: The GitHub issue #9926 documented an identical symptom (zero commands loaded, silent failure) caused by configuration issues in settings.json. The debug logs showed "Slash commands included in SlashCommand tool:" with zero entries, despite valid `.md` files existing.

**Impact**: This single issue could explain why all 14 commands fail to appear in autocomplete or invocation.

### 2. Built-in Command Name Collisions (High)

Two built-in commands shadow custom commands:

| Custom Command | Built-in Command | Built-in Behavior |
|---|---|---|
| `/plan` | `/plan [description]` | Enters Claude Code's built-in Plan Mode |
| `/review` | `/review` | Deprecated built-in (now a plugin) |

Per the official docs: "if a skill and a command share the same name, the skill takes precedence." Since `/plan` is a built-in command (not a skill), the resolution order is unclear. The built-in `/review` is marked deprecated but still present.

**Recommendation**: Rename these two commands to avoid collision (e.g., `/plan` -> skill format with explicit `name:` field, or rename to `/plan-task`).

### 3. Stale Model ID `claude-opus-4-5-20251101` (Medium-High)

12 of 14 commands use `model: claude-opus-4-5-20251101` in their frontmatter. This model ID is from November 2025. The current valid model IDs and aliases are:

**Aliases** (recommended -- always resolve to latest):
- `opus` (currently Opus 4.6)
- `sonnet` (currently Sonnet 4.6)
- `haiku`
- `default`
- `opus[1m]`, `sonnet[1m]`
- `opusplan`

**Full model names**:
- `claude-opus-4-6`
- `claude-sonnet-4-6`

The `model` frontmatter field is documented as optional ("All fields are optional"). However, GitHub issue #29203 reports that `claude-opus-4-6` was not recognized despite API availability, suggesting model validation in Claude Code can be strict. An invalid model ID may cause the command to fail silently during initialization.

**Recommendation**: Replace `model: claude-opus-4-5-20251101` with `model: opus` (alias, always latest) or `model: claude-opus-4-6` (pinned).

### 4. Commands vs Skills Format: Both Still Work (Informational)

Per the official docs (March 2026): "Custom commands have been merged into skills. A file at `.claude/commands/deploy.md` and a skill at `.claude/skills/deploy/SKILL.md` both create `/deploy` and work the same way. Your existing `.claude/commands/` files keep working."

The `.claude/commands/*.md` format is still supported. Migration to `.claude/skills/*/SKILL.md` is not required but is recommended for new features (supporting files, `context: fork`, etc.).

**Key difference**: Skills in `.claude/skills/` support a directory structure with supporting files. Commands in `.claude/commands/` are single `.md` files. Both support the same frontmatter fields.

### 5. Description Budget and Context Loading (Medium)

The official docs state:
- Descriptions are capped at **250 characters** in the skill listing (truncated, not rejected)
- The total context budget for all skill descriptions is **1% of context window** (fallback: 8,000 characters)
- Can be overridden via `SLASH_COMMAND_TOOL_CHAR_BUDGET` environment variable

With 15 skills + 14 commands = 29 entries, at 250 chars each that is 7,250 chars max. The 1% budget on a 200K context window would be ~2,000 characters; on a 1M window, ~10,000 characters. This means with the default context window, **only ~8 entries** worth of descriptions can fit before truncation occurs.

**Impact**: Descriptions get truncated silently but commands still appear in the `/` menu. This would not cause commands to not load entirely, but could prevent Claude from auto-invoking them by matching descriptions. The `SLASH_COMMAND_TOOL_CHAR_BUDGET` environment variable is not currently set in any settings file.

### 6. Deprecated Tool References in Commands (Medium)

Several commands reference tools that are deprecated or renamed:

| Tool Referenced | Status | Replacement |
|---|---|---|
| `TodoWrite` | Deprecated in interactive sessions (v2.1.16+) | `TaskCreate`, `TaskUpdate`, `TaskList`, `TaskGet` |
| `SlashCommand` | Removed | `Skill` |
| `AskUserQuestion` | Still exists | Still valid |

Commands referencing `TodoWrite` in their `allowed-tools`: `errors.md`, `review.md`, `revise.md`, `task.md`, `todo.md`.

**Impact**: Unknown whether referencing a deprecated tool in `allowed-tools` causes a load failure. At minimum, the tool is unavailable when the command runs.

### 7. `refresh.md` Has No Frontmatter (Low-Medium)

The file `.claude/commands/refresh.md` has no YAML frontmatter block at all (no `---` delimiters, no `description` field). Per the docs, `description` is "Recommended" and used for discovery. Without any frontmatter, the command may not be discoverable by Claude and will have no description in the skill listing.

### 8. Complete Frontmatter Reference (Informational)

All supported frontmatter fields for both commands and skills:

| Field | Required | Description |
|---|---|---|
| `name` | No | Display name (max 64 chars, lowercase/numbers/hyphens). Defaults to directory name (skills) or filename (commands). |
| `description` | Recommended | What the skill does (250 char cap for listing). |
| `argument-hint` | No | Autocomplete hint for expected arguments. |
| `disable-model-invocation` | No | `true` = only user can invoke. Default: `false`. |
| `user-invocable` | No | `false` = hidden from `/` menu. Default: `true`. |
| `allowed-tools` | No | Tools Claude can use without permission when active. |
| `model` | No | Model to use when active. Accepts aliases or full names. |
| `effort` | No | Override effort level: `low`, `medium`, `high`, `max`. |
| `context` | No | `fork` = run in subagent. |
| `agent` | No | Subagent type when `context: fork`. |
| `hooks` | No | Scoped lifecycle hooks. |
| `paths` | No | Glob patterns limiting activation. |
| `shell` | No | `bash` (default) or `powershell`. |

## Recommendations

### Priority 1: Fix Permissions (Immediate)

Add `Skill` to the permissions allow-list in **both** settings files:

**Project** (`.claude/settings.json`):
```json
"permissions": {
  "allow": [
    ...existing entries...,
    "Skill"
  ]
}
```

**Global** (`~/.claude/settings.json`):
```json
"permissions": {
  "allow": [
    ...existing entries...,
    "Skill"
  ]
}
```

### Priority 2: Update Model IDs (Immediate)

Replace `model: claude-opus-4-5-20251101` with `model: opus` in all 12 command files. Using the alias ensures forward compatibility when new models release.

### Priority 3: Fix Name Collisions (High)

Two options:
- **Option A** (preferred): Convert `/plan` and `/review` commands to skills in `.claude/skills/` with explicit `name:` fields that avoid collision (e.g., `name: plan-task`, `name: review-code`). Update CLAUDE.md documentation.
- **Option B**: Accept the collision and rely on `Skill(plan *)` permission patterns to distinguish. Risk: built-in `/plan` may always win.

### Priority 4: Fix `refresh.md` Frontmatter (Medium)

Add frontmatter to `refresh.md`:
```yaml
---
description: Manage Claude Code resources - terminate orphaned processes and clean up files
allowed-tools: Bash, Read, Glob
---
```

### Priority 5: Replace Deprecated Tool References (Medium)

Replace `TodoWrite` with `TaskCreate, TaskUpdate` in `allowed-tools` for: `errors.md`, `review.md`, `revise.md`, `task.md`, `todo.md`.

### Priority 6: Set Context Budget (Low)

Add to settings.json env block:
```json
"env": {
  "SLASH_COMMAND_TOOL_CHAR_BUDGET": "50000"
}
```

This ensures all 29 command/skill descriptions fit without truncation.

## Implementation Approach

**Phase 1: Configuration Fixes** (no code changes needed)
1. Add `Skill` to permissions in settings.json (both project and global)
2. Set `SLASH_COMMAND_TOOL_CHAR_BUDGET` in env

**Phase 2: Frontmatter Updates** (bulk edit across 14 files)
1. Replace `model: claude-opus-4-5-20251101` with `model: opus` in all commands
2. Add frontmatter to `refresh.md`
3. Replace `TodoWrite` with `TaskCreate, TaskUpdate` in allowed-tools
4. Replace `SlashCommand` references (if any remain) with `Skill`

**Phase 3: Name Collision Resolution**
1. Decide on naming strategy for `/plan` and `/review`
2. Either rename commands or convert to skills with distinct names
3. Update all references in CLAUDE.md, agents, and other commands

**Phase 4: Optional Migration to Skills Format**
1. Convert remaining `.claude/commands/*.md` to `.claude/skills/*/SKILL.md` for access to supporting files and `context: fork`
2. This is optional -- commands still work -- but recommended for long-term maintenance

## Sources

- [Extend Claude with skills - Claude Code Docs](https://code.claude.com/docs/en/skills) - Official skill/command format documentation
- [Tools reference - Claude Code Docs](https://code.claude.com/docs/en/tools-reference) - Complete tool list with permission requirements
- [Model configuration - Claude Code Docs](https://code.claude.com/docs/en/model-config) - Valid model IDs and aliases
- [Built-in commands - Claude Code Docs](https://code.claude.com/docs/en/commands) - Built-in command list showing `/plan` and `/review` conflicts
- [GitHub Issue #9926](https://github.com/anthropics/claude-code/issues/9926) - Slash commands not loading due to settings.json configuration
- [GitHub Issue #29203](https://github.com/anthropics/claude-code/issues/29203) - Model ID validation bug
- [Claude Code Merges Slash Commands Into Skills](https://medium.com/@joe.njenga/claude-code-merges-slash-commands-into-skills-dont-miss-your-update-8296f3989697) - Commands/skills unification context
