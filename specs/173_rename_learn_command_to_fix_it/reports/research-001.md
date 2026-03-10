# Research Report: Task #173

**Task**: 173 - Rename /learn command to /fix-it
**Started**: 2026-03-10
**Completed**: 2026-03-10
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase search (Grep, Glob, Read)
**Artifacts**: specs/173_rename_learn_command_to_fix_it/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- 7 files in `.claude/` need modification (command, skill, CLAUDE.md, docs, examples)
- 1 directory rename needed (skill-learn -> skill-fix-it)
- 1 file rename needed (commands/learn.md -> commands/fix-it.md)
- The `.opencode/` system already completed an equivalent rename (/learn -> /fix), providing a proven reference pattern
- No Lua keybindings or picker entries reference /learn -- only .claude/ system files are affected

## Context & Scope

Task 173 requires renaming the `/learn` command to `/fix-it` across the `.claude/` system. The scope includes the command definition file, skill directory, CLAUDE.md references, documentation files, and example files. Archive/historical files (specs/archive/) should NOT be modified as they represent historical records.

## Findings

### Files Requiring Modification

#### 1. Command File (RENAME)

**File**: `.claude/commands/learn.md` -> `.claude/commands/fix-it.md`

References to update inside the file:
- Line 8: `# /learn Command` -> `# /fix-it Command`
- Line 258: `/learn` (usage example)
- Line 261: `/learn nvim/lua/Layer1/` (usage example)
- Line 264: `/learn docs/04-Metalogic.tex` (usage example)
- Line 267: `/learn nvim/lua/ .claude/agents/` (usage example)

The frontmatter (description, allowed-tools, argument-hint, model) does not reference "learn" and needs no changes.

#### 2. Skill Directory (RENAME)

**Directory**: `.claude/skills/skill-learn/` -> `.claude/skills/skill-fix-it/`

**File**: `SKILL.md` - References to update:
- Line 2: `name: skill-learn` -> `name: skill-fix-it`
- Line 3: description mentions "Invoke for /learn command" -> "Invoke for /fix-it command"
- Line 7: `# Learn Skill (Direct Execution)` -> `# Fix-It Skill (Direct Execution)`
- Line 940: git commit message uses `learn:` prefix -> `fix-it:` prefix

#### 3. CLAUDE.md (Inner .claude/ system)

**File**: `.claude/CLAUDE.md`

References to update:
- Line 83: Command reference table entry `/learn` -> `/fix-it`
- Line 191: Multi-task creation compliance table `/learn` -> `/fix-it`

#### 4. Documentation - README

**File**: `.claude/docs/README.md`

References to update:
- Line 29: Tree entry `learn-flow-example.md` -> `fix-it-flow-example.md`
- Line 75: Link text "Learn Flow Example" -> "Fix-It Flow Example" and link target

#### 5. Documentation - User Guide

**File**: `.claude/docs/guides/user-guide.md`

References to update:
- Line 27: TOC entry `[/learn](#learn-command)` -> `[/fix-it](#fix-it-command)`
- Line 427: Section header `### /learn Command` -> `### /fix-it Command`
- Line 432: Usage syntax `/learn [PATH...]` -> `/fix-it [PATH...]`
- Line 456-457: Examples `/learn` and `/learn Theories/Modal/` -> `/fix-it`
- Line 509: Quick reference table entry

#### 6. Documentation - Multi-Task Creation Standard

**File**: `.claude/docs/reference/standards/multi-task-creation-standard.md`

References to update:
- Line 20: Table entry `/learn`
- Line 28: Example comment `# Example: /learn tag discovery`
- Line 55: Text `**Example from /learn**:`
- Line 358: Compliance table entry `/learn`
- Line 376: Section header `### /learn`
- Line 388: File reference `.claude/commands/learn.md`

#### 7. Documentation - Flow Example (RENAME)

**File**: `.claude/docs/examples/learn-flow-example.md` -> `.claude/docs/examples/fix-it-flow-example.md`

This file contains ~40 references to `/learn` and `skill-learn`. All need updating. Key references:
- Title and description text
- Diagram labels referencing `learn.md` and `skill-learn`
- All usage examples
- File path references

### Files NOT Requiring Modification

#### .opencode/ Directory
The `.opencode/` system has its own `/learn` -> `/fix` rename already completed. The `.opencode/` files that still reference "learn" are:
- Historical memory files (MEM-*)
- Migration documentation
- These should be left as-is (they document the .opencode rename, not the .claude rename)

#### specs/archive/ Directory
Contains historical reports and plans that reference `/learn`. These are archival records and should NOT be modified.

#### specs/TODO.md
Only contains the task 173 description itself, which references `/learn` as part of the task description. This does not need updating.

#### specs/CHANGE_LOG.md
Already documents the .opencode `/learn` -> `/fix` rename. A new entry should be added for the .claude rename when implementation is done.

#### Root CLAUDE.md Files
Neither `/home/benjamin/.config/CLAUDE.md` nor `/home/benjamin/.config/nvim/CLAUDE.md` contain `/learn` or `skill-learn` references.

#### Lua/Neovim Files
No Lua keybinding files, picker configurations, or Neovim plugin files reference `/learn`. No changes needed in `lua/` or `after/` directories.

#### context/index.json
No entries reference "learn". No changes needed.

#### Agent Frontmatter
No agent files (`.claude/agents/`) reference `skill-learn`. No changes needed.

### Precedent: .opencode Rename

The `.opencode/` system already performed an equivalent rename (`/learn` -> `/fix`). Key learnings from that implementation (documented in `specs/CHANGE_LOG.md` and `MEM-2026-03-05-001-clean-break-command-renaming.md`):

1. Clean-break approach: No backwards compatibility, old command simply stops existing
2. Files affected: command file, skill directory, documentation, README
3. Verification: `grep -r "/learn" .opencode/` returns zero results after rename

### Recommendations

1. **Use clean-break approach** (no deprecation, no backwards compatibility wrapper)
2. **Rename files/directories first**, then update content references
3. **Implementation order**:
   - Phase 1: Rename command file (`learn.md` -> `fix-it.md`) and update its content
   - Phase 2: Rename skill directory (`skill-learn/` -> `skill-fix-it/`) and update SKILL.md
   - Phase 3: Update CLAUDE.md references
   - Phase 4: Rename and update documentation files (flow example, user guide, multi-task standard, README)
4. **Verification**: Run `grep -rn "/learn\|skill-learn" .claude/` after implementation to confirm zero references remain (excluding this research report)

## Decisions

- Archive files (specs/archive/) will NOT be modified
- The .opencode/ system files will NOT be modified (separate system, already has its own rename)
- Clean-break approach: no backwards compatibility for `/learn`

## Risks & Mitigations

- **Risk**: Missing a reference causing broken documentation links
  - **Mitigation**: Post-implementation grep verification
- **Risk**: Git history discontinuity from file renames
  - **Mitigation**: Use `git mv` for renames to preserve history

## Appendix

### Search Queries Used
- `grep -rn "/learn|skill-learn|learn\.md" .claude/`
- `grep -rn "learn" .claude/context/index.json`
- `grep -rn "/learn|skill-learn" .claude/agents/`
- `grep -rn "learn|fix.it" lua/neotex/` (for keybinding references)

### Complete File Inventory

| # | File/Directory | Action | Reference Count |
|---|---------------|--------|-----------------|
| 1 | `.claude/commands/learn.md` | Rename to `fix-it.md` + update content | 5 |
| 2 | `.claude/skills/skill-learn/` | Rename directory to `skill-fix-it/` | 1 (dir) |
| 3 | `.claude/skills/skill-fix-it/SKILL.md` | Update name, description, heading, commit msg | 4 |
| 4 | `.claude/CLAUDE.md` | Update command table + multi-task table | 2 |
| 5 | `.claude/docs/README.md` | Update tree entry + link | 2 |
| 6 | `.claude/docs/guides/user-guide.md` | Update TOC, section, examples, table | 7 |
| 7 | `.claude/docs/reference/standards/multi-task-creation-standard.md` | Update table entries, examples, section | 6 |
| 8 | `.claude/docs/examples/learn-flow-example.md` | Rename to `fix-it-flow-example.md` + update ~40 refs | ~40 |
| **Total** | | | **~67 references** |
