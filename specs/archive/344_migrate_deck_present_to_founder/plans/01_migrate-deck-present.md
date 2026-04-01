# Implementation Plan: Migrate Deck from Present to Founder

- **Task**: 344 - migrate_deck_present_to_founder
- **Status**: [IMPLEMENTING]
- **Effort**: 1.5 hours
- **Dependencies**: 341, 342, 343 (founder extension and deck skills -- already completed)
- **Research Inputs**: reports/01_migrate-deck-present.md
- **Artifacts**: plans/01_migrate-deck-present.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Remove all deck functionality from the `present/` extension and ensure the `founder/` extension is fully self-contained for deck operations. This involves moving 3 context files, deleting 10 files, editing 4 files in present/, editing 5 files in founder/, and editing 1 file in filetypes/. After migration, `present/` becomes a grant-writing-only extension.

### Research Integration

Research report (01_migrate-deck-present.md) provided a complete file inventory, cross-reference analysis, and phased migration checklist covering all 23 operations.

## Goals & Non-Goals

**Goals**:
- Move deck context files (pitch-deck-structure, touying-pitch-deck-template, yc-compliance-checklist) from present/ to founder/
- Delete all deck artifacts from present/ (agent, skill, command, workflow, examples)
- Update all cross-references in founder/ agents, index-entries, and skills
- Update filetypes/ index-entries to reference founder agents
- Clean present/ config files (manifest.json, EXTENSION.md, index-entries.json, README.md)

**Non-Goals**:
- Adding new deck functionality to founder/
- Modifying founder's existing deck skills, agents, or templates
- Creating grant examples in present/examples/ (can be a separate task)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Broken @-references after file move | High | Medium | Move files before updating references; verify with grep |
| Stale merged index.json after extension changes | Medium | Medium | Reload extensions after migration |
| README.md edit misses a deck reference | Low | Low | grep for "deck" in present/ after all edits |
| filetypes extension routing breaks | Low | Low | Update filetypes index-entries in dedicated phase |

## Implementation Phases

### Phase 1: Move context files and delete deck artifacts [COMPLETED]

**Goal:** Physically relocate shared context files to founder/ and remove all deck-only files from present/.

**Tasks:**
- [ ] Create target directory `.claude/extensions/founder/context/project/founder/patterns/` if it does not exist
- [ ] `git mv` pitch-deck-structure.md from present/context/project/present/patterns/ to founder/context/project/founder/patterns/
- [ ] `git mv` touying-pitch-deck-template.md from present/context/project/present/patterns/ to founder/context/project/founder/patterns/
- [ ] `git mv` yc-compliance-checklist.md from present/context/project/present/patterns/ to founder/context/project/founder/patterns/
- [ ] `git rm` present/agents/deck-agent.md
- [ ] `git rm -r` present/skills/skill-deck/
- [ ] `git rm` present/commands/deck.md
- [ ] `git rm` present/context/project/present/domain/deck-workflow.md
- [ ] `git rm -r` present/examples/ (all deck examples, README)

**Timing:** 15 minutes

**Files to modify:**
- `.claude/extensions/present/context/project/present/patterns/pitch-deck-structure.md` - move
- `.claude/extensions/present/context/project/present/patterns/touying-pitch-deck-template.md` - move
- `.claude/extensions/present/context/project/present/patterns/yc-compliance-checklist.md` - move
- `.claude/extensions/present/agents/deck-agent.md` - delete
- `.claude/extensions/present/skills/skill-deck/SKILL.md` - delete
- `.claude/extensions/present/commands/deck.md` - delete
- `.claude/extensions/present/context/project/present/domain/deck-workflow.md` - delete
- `.claude/extensions/present/examples/` - delete directory

**Verification:**
- Files exist at new founder/ paths
- No deck files remain in present/ (except config files to edit in Phase 2)

---

### Phase 2: Edit present/ configuration files [COMPLETED]

**Goal:** Remove all deck references from present/ config files so it becomes grant-only.

**Tasks:**
- [ ] Edit `present/manifest.json`: remove deck-agent.md from agents array, skill-deck from skills array, deck.md from commands array
- [ ] Edit `present/EXTENSION.md`: remove deck from description, skill-agent mapping table, commands table, and language routing table
- [ ] Edit `present/index-entries.json`: remove 4 deck entries (pitch-deck-structure, touying-pitch-deck-template, yc-compliance-checklist, deck-workflow)
- [ ] Edit `present/README.md`: remove all deck sections (pitch deck generation, deck troubleshooting, deck references)

**Timing:** 30 minutes

**Files to modify:**
- `.claude/extensions/present/manifest.json` - edit
- `.claude/extensions/present/EXTENSION.md` - edit
- `.claude/extensions/present/index-entries.json` - edit
- `.claude/extensions/present/README.md` - edit

**Verification:**
- `grep -r "deck" .claude/extensions/present/` returns zero matches
- manifest.json is valid JSON
- index-entries.json is valid JSON

---

### Phase 3: Update founder/ and filetypes/ cross-references [COMPLETED]

**Goal:** Update all references that previously pointed to present/ deck artifacts so they point to founder/ equivalents.

**Tasks:**
- [ ] Edit `founder/agents/deck-research-agent.md`: update 3 @-references from present/ paths to founder/ paths
- [ ] Edit `founder/agents/deck-builder-agent.md`: update 3 @-references from present/ paths to founder/ paths
- [ ] Edit `founder/agents/deck-planner-agent.md`: update 3 @-references from present/ paths to founder/ paths
- [ ] Edit `founder/index-entries.json`: update 3 path entries from `project/present/patterns/` to `project/founder/patterns/`; remove `deck-agent` from agents arrays in those entries
- [ ] Edit `founder/skills/skill-deck-research/SKILL.md`: remove line referencing "present's skill-deck"
- [ ] Edit `filetypes/index-entries.json`: update `deck-agent` references to founder deck agents in pitch-deck-structure and touying-pitch-deck-template entries

**Timing:** 30 minutes

**Files to modify:**
- `.claude/extensions/founder/agents/deck-research-agent.md` - edit
- `.claude/extensions/founder/agents/deck-builder-agent.md` - edit
- `.claude/extensions/founder/agents/deck-planner-agent.md` - edit
- `.claude/extensions/founder/index-entries.json` - edit
- `.claude/extensions/founder/skills/skill-deck-research/SKILL.md` - edit
- `.claude/extensions/filetypes/index-entries.json` - edit

**Verification:**
- `grep -r "present.*deck\|deck.*present" .claude/extensions/founder/` returns zero matches
- `grep -r "deck-agent" .claude/extensions/` only matches founder/ agent file names (not as a load_when reference or present/ reference)
- All JSON files are valid

---

### Phase 4: Final verification [COMPLETED]

**Goal:** Confirm the migration is complete with no broken references.

**Tasks:**
- [ ] Run `grep -r "deck" .claude/extensions/present/` -- expect zero matches
- [ ] Run `grep -r "present.*patterns.*deck\|deck.*present.*patterns" .claude/extensions/founder/` -- expect zero matches
- [ ] Run `grep -r "deck-agent" .claude/extensions/` -- expect only founder/agents/ filenames
- [ ] Run `grep -r "skill-deck" .claude/extensions/present/` -- expect zero matches
- [ ] Validate present/manifest.json with jq
- [ ] Validate present/index-entries.json with jq
- [ ] Validate founder/index-entries.json with jq
- [ ] Validate filetypes/index-entries.json with jq

**Timing:** 15 minutes

**Verification:**
- All grep checks pass
- All JSON files parse without errors
- present/ contains only grant-writing artifacts

## Testing & Validation

- [ ] Zero "deck" references remain in present/ extension
- [ ] Zero "present" path references remain in founder/ deck agents and index entries
- [ ] All moved context files are readable at new founder/ paths
- [ ] All JSON config files (manifest.json, index-entries.json) parse correctly
- [ ] founder/ deck agents reference correct @-paths to founder/context/

## Artifacts & Outputs

- `specs/344_migrate_deck_present_to_founder/plans/01_migrate-deck-present.md` (this plan)
- `specs/344_migrate_deck_present_to_founder/summaries/01_migrate-deck-present-summary.md` (after implementation)

## Rollback/Contingency

All operations are git-tracked. If migration causes issues:
1. `git revert` the migration commit(s) to restore present/ deck files
2. The founder/ extension already has its own complete deck infrastructure, so reverting only re-adds duplicates to present/
3. No data loss risk since files are moved (not deleted) for context files, and founder/ already has replacement agents/skills/commands
