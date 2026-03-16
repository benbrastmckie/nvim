# Implementation Plan: Move Deck Elements to Present Extension

- **Task**: 211 - move_deck_elements_to_present
- **Status**: [COMPLETED]
- **Effort**: 1-2 hours
- **Dependencies**: Task #210 [COMPLETED]
- **Research Inputs**: None
- **Artifacts**: plans/01_move-deck-files.md (this file)
- **Standards**:
  - .claude/context/core/formats/plan-format.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

Move deck-related files from the filetypes/ extension to the present/ extension as part of the extension reorganization. This task performs file moves only using `git mv` to preserve history. Internal reference updates are handled in separate follow-up tasks (212-213). The present/ extension already has existing directories for agents, commands, and skills from grant components, so these directories exist and files will be added alongside existing content.

## Goals & Non-Goals

**Goals**:
- Move all deck-related files from filetypes/ to present/ extension
- Preserve git history using `git mv`
- Create necessary directory structure (context/project/present/patterns/)
- Verify all files moved successfully

**Non-Goals**:
- Update internal file references (handled in task 212)
- Update manifest.json or index-entries.json (handled in task 213)
- Modify file contents in any way

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| File already exists at target | Medium | Low | Check target before moving |
| Missing source file | Medium | Low | Verify source existence first |
| Directory creation failure | Low | Low | Use mkdir -p for safety |

## Implementation Phases

### Phase 1: Create Target Directory Structure [COMPLETED]

**Goal**: Ensure all target directories exist before moving files.

**Tasks**:
- [ ] Create `context/project/present/patterns/` directory in present/ extension
- [ ] Verify agents/, commands/, skills/ directories exist (they do from grant components)

**Timing**: 5 minutes

**Files to create**:
- `.claude/extensions/present/context/project/present/patterns/` (directory)

**Verification**:
- Directory exists and is empty or ready to receive files

---

### Phase 2: Move Agent and Command Files [COMPLETED]

**Goal**: Move deck-agent.md and deck.md command using git mv.

**Tasks**:
- [ ] Move `agents/deck-agent.md` from filetypes/ to present/
- [ ] Move `commands/deck.md` from filetypes/ to present/
- [ ] Verify both files exist at target locations

**Timing**: 10 minutes

**Source files**:
- `.claude/extensions/filetypes/agents/deck-agent.md`
- `.claude/extensions/filetypes/commands/deck.md`

**Target files**:
- `.claude/extensions/present/agents/deck-agent.md`
- `.claude/extensions/present/commands/deck.md`

**Verification**:
- Source files no longer exist in filetypes/
- Target files exist in present/
- `git status` shows renamed files

---

### Phase 3: Move Skill Directory [COMPLETED]

**Goal**: Move the skill-deck skill directory to present/ extension.

**Tasks**:
- [ ] Move entire `skills/skill-deck/` directory from filetypes/ to present/
- [ ] Verify skill directory and contents exist at target

**Timing**: 10 minutes

**Source**:
- `.claude/extensions/filetypes/skills/skill-deck/` (directory with SKILL.md)

**Target**:
- `.claude/extensions/present/skills/skill-deck/`

**Verification**:
- Skill directory no longer exists in filetypes/
- Skill directory exists in present/ with all contents
- SKILL.md file present in target

---

### Phase 4: Move Context Pattern Files [COMPLETED]

**Goal**: Move pitch deck pattern files to present/ extension context.

**Tasks**:
- [ ] Move `pitch-deck-structure.md` from filetypes/patterns to present/patterns
- [ ] Move `touying-pitch-deck-template.md` from filetypes/patterns to present/patterns
- [ ] Verify both pattern files exist at target locations

**Timing**: 10 minutes

**Source files**:
- `.claude/extensions/filetypes/context/project/filetypes/patterns/pitch-deck-structure.md`
- `.claude/extensions/filetypes/context/project/filetypes/patterns/touying-pitch-deck-template.md`

**Target files**:
- `.claude/extensions/present/context/project/present/patterns/pitch-deck-structure.md`
- `.claude/extensions/present/context/project/present/patterns/touying-pitch-deck-template.md`

**Verification**:
- Source files no longer exist in filetypes/patterns/
- Target files exist in present/patterns/
- File contents unchanged (git mv preserves content)

---

### Phase 5: Verify All Moves and Stage Changes [COMPLETED]

**Goal**: Confirm all files moved correctly and stage for commit.

**Tasks**:
- [ ] Run `git status` to verify all moves detected as renames
- [ ] Verify no source files remain in filetypes/ for deck components
- [ ] Verify all target files exist in present/ extension
- [ ] Stage all changes with `git add`

**Timing**: 5 minutes

**Verification**:
- `git status` shows 5 renamed files (2 agents/commands, 1 skill dir, 2 patterns)
- All deck-related files in present/ extension
- No deck-related files remaining in filetypes/

## Testing & Validation

- [ ] Verify deck-agent.md exists at `.claude/extensions/present/agents/deck-agent.md`
- [ ] Verify deck.md command exists at `.claude/extensions/present/commands/deck.md`
- [ ] Verify skill-deck/ directory exists at `.claude/extensions/present/skills/skill-deck/`
- [ ] Verify pitch-deck-structure.md exists at `.claude/extensions/present/context/project/present/patterns/`
- [ ] Verify touying-pitch-deck-template.md exists at `.claude/extensions/present/context/project/present/patterns/`
- [ ] `git status` confirms all moves staged correctly

## Artifacts & Outputs

- plans/01_move-deck-files.md (this file)
- summaries/01_move-deck-files-summary.md (post-implementation)
- Moved files in `.claude/extensions/present/`

## Rollback/Contingency

If moves fail or need to be reverted:
1. Use `git checkout HEAD -- .claude/extensions/filetypes/` to restore source files
2. Use `git checkout HEAD -- .claude/extensions/present/` to restore target state
3. Remove any partially created directories
4. Re-run implementation from the beginning
