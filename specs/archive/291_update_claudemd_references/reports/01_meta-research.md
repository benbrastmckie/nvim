# Research Report: Task #291

**Task**: 291 - Update CLAUDE.md and agent references for new paths
**Generated**: 2026-03-25
**Updated**: 2026-03-25
**Source**: /meta interview (auto-generated), revised after project context audit
**Status**: Pre-populated from interview context, revised

---

## Context Summary

**Purpose**: Update all documentation and code references to use new context paths
**Scope**: CLAUDE.md files, agent definitions, skill definitions
**Affected Components**: Documentation, agent/skill @-references
**Domain**: meta
**Language**: meta

## Task Requirements

After restructuring, update all references to context files throughout the codebase.

### Path Changes Summary

| Old Path | New Path | Reason |
|----------|----------|--------|
| `.claude/context/core/*` | `.claude/context/*` | Flattened (task 288) |
| `.claude/context/project/meta/*` | `.claude/context/meta/*` | Promoted to core (task 287) |
| `.claude/context/project/processes/*` | `.claude/context/processes/*` | Promoted to core (task 287) |
| `.claude/context/project/repo/*` | `.claude/context/repo/*` | Promoted to core (task 287) |
| `.claude/context/project/neovim/*` | `.claude/extensions/nvim/context/...` | Moved to nvim extension (task 287) |
| `.claude/context/project/hooks/*` | `.claude/extensions/nvim/context/...` | Moved to nvim extension (task 287) |

### Files to Update

1. **CLAUDE.md files**:
   - `~/.config/nvim/.claude/CLAUDE.md` — Context Discovery, Context Imports sections
   - `~/.config/nvim/CLAUDE.md` — Related Documentation section, references to standards

2. **Agent definitions** (`.claude/agents/*.md`):
   - Update all @-reference paths
   - grep for `@.claude/context/core/` and `@.claude/context/project/`

3. **Skill definitions** (`.claude/skills/*/SKILL.md`):
   - Update context loading instructions

4. **Command definitions** (`.claude/commands/*.md`):
   - Update any hardcoded context paths

5. **Rules** (`.claude/rules/*.md`):
   - Update context path references

6. **Context README**:
   - `.claude/context/README.md` — Rewrite for new structure

7. **Root CLAUDE.md references to neovim standards**:
   - Box-drawing, emoji-policy, documentation-policy, lua-assertion-patterns
   - These now come from the nvim extension, not `.claude/context/project/neovim/`

### Search and Replace Patterns

```bash
# Find all references to old paths
grep -r "@.claude/context/core/" .claude/
grep -r "@.claude/context/project/" .claude/
grep -r ".claude/context/core/" .claude/
grep -r ".claude/context/project/" .claude/
```

### Verification

After updates:
```bash
.claude/scripts/validate-wiring.sh --all
```

## Integration Points

- **Component Type**: documentation
- **Affected Area**: All .claude/ files with context references
- **Action Type**: update
- **Related Files**:
  - All files in `.claude/` with context path references

## Dependencies

- Task #290: Update context discovery patterns (patterns must be defined first)

## Interview Context

### User-Provided Information
Systematic search-and-replace task. The key difference from the original plan is that neovim standards files now live in the nvim extension rather than `.context/`, so references point to extension paths instead.

### Effort Assessment
- **Estimated Effort**: 1 hour
- **Complexity Notes**: Straightforward search and replace, but need to be thorough.

---

*This research report was auto-generated during task creation via /meta command.*
*Revised 2026-03-25 to reflect updated path changes after project context audit.*
*For deeper investigation, run `/research 291 [focus]` with a specific focus prompt.*
