# Implementation Plan: Upgrade Agent System for Claude Code v2.1.88+

**Task**: 326 - Upgrade agent system for Claude Code v2.1.88+
**Date**: 2026-03-31
**Session**: sess_1774920952_2bc213
**Based on**: [01_command-loading-fix.md](../reports/01_command-loading-fix.md)

## Overview

Migrate 14 commands in `.claude/commands/` to be fully compatible with Claude Code v2.1.88+. The primary failure is that the `Skill` tool is missing from permissions, preventing all command/skill invocation. Secondary issues include stale model IDs, built-in name collisions, missing frontmatter, and deprecated tool references. This plan fixes issues in priority order so the most impactful change lands first and can be verified immediately.

## Phase 1: Fix Permissions and Environment
**Status**: [NOT STARTED]
**Estimated effort**: 10 minutes
**Files modified**:
- `.claude/settings.json` (project-level)
- `~/.claude/settings.json` (global)

### Steps

1. **Add `Skill` to project settings allow-list**

   In `.claude/settings.json`, add `"Skill"` to the `permissions.allow` array. This is the single most likely fix for all commands failing to load.

2. **Add `Skill` to global settings allow-list**

   In `~/.claude/settings.json`, add `"Skill"` to the `permissions.allow` array.

3. **Replace `TodoWrite` with Task tools in both settings files**

   In both settings files, replace `"TodoWrite"` with `"TaskCreate"` and `"TaskUpdate"` in the `permissions.allow` array. `TodoWrite` is deprecated in v2.1.16+.

4. **Set `SLASH_COMMAND_TOOL_CHAR_BUDGET` environment variable**

   In `.claude/settings.json`, add or update the `env` block:
   ```json
   "env": {
     "SLASH_COMMAND_TOOL_CHAR_BUDGET": "50000"
   }
   ```
   This ensures all 29 command/skill descriptions fit without truncation. If an `env` block already exists in global settings, merge rather than overwrite.

### Verification

- Restart Claude Code (new session)
- Type `/` and confirm that custom commands appear in autocomplete
- Try invoking `/task` or `/research` to confirm the Skill tool is permitted
- If commands still do not load, check Claude Code debug logs for error messages

## Phase 2: Update Model IDs Across All Commands
**Status**: [NOT STARTED]
**Estimated effort**: 15 minutes
**Files modified**:
- `.claude/commands/errors.md`
- `.claude/commands/fix-it.md`
- `.claude/commands/implement.md`
- `.claude/commands/meta.md` (2 occurrences)
- `.claude/commands/plan.md`
- `.claude/commands/research.md`
- `.claude/commands/review.md`
- `.claude/commands/revise.md`
- `.claude/commands/spawn.md`
- `.claude/commands/task.md`
- `.claude/commands/todo.md`

### Steps

1. **Replace stale model ID in frontmatter**

   In all 11 files listed above, replace:
   ```yaml
   model: claude-opus-4-5-20251101
   ```
   with:
   ```yaml
   model: opus
   ```
   The `opus` alias always resolves to the latest Opus model, ensuring forward compatibility.

2. **Handle `meta.md` double occurrence**

   `meta.md` has 2 occurrences of the stale model ID (likely one in frontmatter and one in body text or a subagent reference). Replace both with `opus`.

3. **Update `Co-Authored-By` lines in command templates** (optional, low priority)

   Several commands contain hardcoded `Co-Authored-By: Claude Opus 4.5` in their git commit templates. These should be updated to reflect the current model. Files affected:
   - `implement.md` (2 occurrences)
   - `plan.md` (1 occurrence)
   - `research.md` (1 occurrence)
   - `review.md` (1 occurrence)
   - `revise.md` (2 occurrences)

   Replace `Claude Opus 4.5` with `Claude Opus 4.6 (1M context)` in these template strings.

### Verification

- Open any modified command file and confirm frontmatter shows `model: opus`
- Invoke a command (e.g., `/research 326`) and confirm it runs without model validation errors

## Phase 3: Fix Frontmatter and Deprecated Tool References
**Status**: [NOT STARTED]
**Estimated effort**: 15 minutes
**Files modified**:
- `.claude/commands/refresh.md`
- `.claude/commands/errors.md`
- `.claude/commands/review.md`
- `.claude/commands/revise.md`
- `.claude/commands/todo.md`

### Steps

1. **Add frontmatter to `refresh.md`**

   `refresh.md` currently has no YAML frontmatter block. Add:
   ```yaml
   ---
   description: Manage Claude Code resources - terminate orphaned processes and clean up files
   allowed-tools: Bash, Read, Glob, AskUserQuestion
   ---
   ```
   This makes the command discoverable and grants it the tools it needs.

2. **Replace `TodoWrite` with `TaskCreate, TaskUpdate` in allowed-tools**

   In the following files, find `TodoWrite` in the `allowed-tools:` frontmatter line and replace it:

   | File | Current | Replacement |
   |------|---------|-------------|
   | `errors.md` | `TodoWrite, Task` | `TaskCreate, TaskUpdate, Task` |
   | `review.md` | `TodoWrite, AskUserQuestion` | `TaskCreate, TaskUpdate, AskUserQuestion` |
   | `revise.md` | `TodoWrite` | `TaskCreate, TaskUpdate` |
   | `todo.md` | `TodoWrite, AskUserQuestion` | `TaskCreate, TaskUpdate, AskUserQuestion` |

   Note: `task.md` does NOT reference `TodoWrite` in its allowed-tools (contrary to the research report), so no change is needed there.

### Verification

- Confirm `refresh.md` now has frontmatter by checking the first 4 lines
- Confirm `/refresh` appears in autocomplete
- Run `/refresh --dry-run` to verify it works
- Grep for `TodoWrite` in `.claude/commands/` -- should return zero results

## Phase 4: Resolve Name Collisions for `/plan` and `/review`
**Status**: [NOT STARTED]
**Estimated effort**: 30 minutes (requires user decision)
**Files modified** (depends on chosen option):
- Option A: `.claude/commands/plan.md` -> `.claude/commands/plan-task.md` (rename)
- Option A: `.claude/commands/review.md` -> `.claude/commands/review-code.md` (rename)
- All CLAUDE.md files and documentation referencing `/plan` and `/review`
- `.claude/agents/` files that reference these commands

### Decision Required

The user must choose between these approaches:

**Option A: Rename commands (recommended)**
- Rename `/plan` to `/plan-task` (avoids collision with built-in Plan Mode)
- Rename `/review` to `/review-code` (avoids collision with deprecated built-in)
- Update all references in CLAUDE.md, agent files, and other commands
- Pro: Clean separation, no ambiguity
- Con: Muscle memory change, documentation updates needed

**Option B: Keep current names, rely on precedence**
- Per Claude Code docs: "if a skill and a command share the same name, the skill takes precedence"
- However, `/plan` is a built-in *command*, not a skill, so precedence is unclear
- Pro: No renaming needed
- Con: May silently invoke built-in instead of custom command

**Option C: Convert to skills format with explicit `name:` field**
- Move `plan.md` to `.claude/skills/plan-task/SKILL.md` with `name: plan-task`
- Move `review.md` to `.claude/skills/review-code/SKILL.md` with `name: review-code`
- Pro: Future-proof, access to supporting files and `context: fork`
- Con: Most work, changes directory structure

### Steps (for Option A, pending user decision)

1. **Rename command files**
   ```bash
   mv .claude/commands/plan.md .claude/commands/plan-task.md
   mv .claude/commands/review.md .claude/commands/review-code.md
   ```

2. **Update references in CLAUDE.md files**

   Files to update (search for `/plan` and `/review` references):
   - `.claude/CLAUDE.md` - Command Reference table, Skill-to-Agent Mapping
   - `CLAUDE.md` (root) - Any references
   - `.claude/commands/research.md` - "Next: /plan {N}" output template
   - `.claude/commands/implement.md` - May reference /plan
   - `.claude/commands/revise.md` - May reference /plan
   - `.claude/agents/planner-agent.md` - May reference /plan command
   - `.claude/agents/code-reviewer-agent.md` - May reference /review command

3. **Update argument-hint if needed**

   The renamed files keep their content but now respond to `/plan-task` and `/review-code`.

4. **Add aliases or migration notice** (optional)

   Consider adding a brief note to CLAUDE.md: "Note: `/plan-task` replaces the former `/plan` command to avoid collision with Claude Code's built-in Plan Mode."

### Verification

- Type `/plan` and confirm it invokes Claude Code's built-in Plan Mode (not the custom command)
- Type `/plan-task` and confirm it invokes the custom planning command
- Type `/review-code` and confirm it invokes the custom review command
- Verify no broken references remain: `grep -r "/plan " .claude/` and `grep -r "/review " .claude/`

## Phase 5: Documentation and CLAUDE.md Updates
**Status**: [NOT STARTED]
**Estimated effort**: 20 minutes
**Files modified**:
- `.claude/CLAUDE.md`
- `CLAUDE.md` (root, if needed)
- `.claude/context/repo/project-overview.md` (if it references model versions)

### Steps

1. **Update model references in CLAUDE.md**

   In `.claude/CLAUDE.md`, the Skill-to-Agent Mapping table and commit convention examples reference "Claude Opus 4.5". Update to reflect current model.

2. **Update command reference table**

   If Phase 4 renamed commands, update the Command Reference table in `.claude/CLAUDE.md` to show the new names.

3. **Update commit convention examples**

   The git commit convention section shows `Co-Authored-By: Claude Opus 4.5`. Update to `Claude Opus 4.6 (1M context)`.

4. **Add compatibility note**

   Add a brief note to `.claude/CLAUDE.md` documenting the v2.1.88+ compatibility changes for future reference.

### Verification

- Read `.claude/CLAUDE.md` and confirm all model references are current
- Confirm command names in documentation match actual filenames
- Run `/task --sync` to verify the system is operational end-to-end

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Adding `Skill` to permissions does not fix command loading | Low | High | Research identified this as the primary cause based on matching GitHub issues. If it fails, check debug logs for alternative causes. |
| `model: opus` alias not recognized | Low | Medium | The alias is documented in official Claude Code docs. Fallback: use `claude-opus-4-6` (pinned). |
| Renaming `/plan` and `/review` breaks user workflows | Medium | Medium | User decision point in Phase 4. Can be deferred if other phases fix loading. |
| Global settings change affects other projects | Low | Low | The `Skill` permission is needed globally for any project using commands/skills. `TodoWrite` -> `TaskCreate`/`TaskUpdate` is a universal upgrade. |
| `SLASH_COMMAND_TOOL_CHAR_BUDGET` env var not recognized | Low | Low | Documented in official docs. Worst case: silently ignored, descriptions truncated as before. |

## Decision Points

1. **Phase 4 naming strategy**: The user should decide between Option A (rename to `/plan-task` and `/review-code`), Option B (keep names, accept collision risk), or Option C (convert to skills format). This decision can be deferred until after Phases 1-3 are verified working.

2. **Global settings changes**: Phase 1 modifies `~/.claude/settings.json` which affects all projects. The changes (adding `Skill`, replacing `TodoWrite`) are beneficial universally, but the user should be aware.

3. **Co-Authored-By updates**: Phase 2 step 3 and Phase 5 step 3 update hardcoded model names in commit templates. These are cosmetic but keep the system accurate. Can be skipped if time-constrained.

## Execution Order

Phases 1-3 are independent and address distinct issues, but should be executed in order so verification builds incrementally:
- **Phase 1** fixes the blocking issue (commands not loading at all)
- **Phase 2** prevents potential silent failures from invalid model IDs
- **Phase 3** fixes discoverability and deprecated tool issues
- **Phase 4** requires user input and can be deferred
- **Phase 5** is documentation cleanup that should follow all code changes
