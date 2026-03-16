# Implementation Plan: Cleanup Filetypes Extension After Deck Migration

- **Task**: 213 - cleanup_filetypes_extension_after_deck_migration
- **Status**: [NOT STARTED]
- **Effort**: 0.5-1 hour
- **Dependencies**: Task 212 (deck components moved to present/ extension)
- **Research Inputs**: specs/213_cleanup_filetypes_extension_after_deck_migration/reports/01_cleanup-filetypes-research.md
- **Artifacts**: plans/02_cleanup-filetypes-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Remove all deck-related references from the filetypes/ extension after deck components have been migrated to the present/ extension. This cleanup ensures the filetypes extension only contains document/spreadsheet/presentation conversion capabilities, with no orphaned deck references.

### Research Integration

Research identified 7 specific items to remove across 3 files:
- manifest.json: 3 entries (agent, skill, command)
- EXTENSION.md: ~65 lines (table rows, sections, examples)
- index-entries.json: 2 entries (pitch-deck-structure.md, touying-pitch-deck-template.md)

## Goals & Non-Goals

**Goals**:
- Remove deck-agent.md from manifest.json agents array
- Remove skill-deck from manifest.json skills array
- Remove deck.md from manifest.json commands array
- Remove skill-deck row from EXTENSION.md Skill-Agent Mapping table
- Remove /deck command examples from EXTENSION.md Command Usage section
- Remove entire "Pitch Deck Generation" section from EXTENSION.md
- Remove deck pattern rows from EXTENSION.md Context Documentation table
- Remove pitch-deck-structure.md entry from index-entries.json
- Remove touying-pitch-deck-template.md entry from index-entries.json

**Non-Goals**:
- Modifying the present/ extension (already complete in task 212)
- Removing actual deck files (deck-agent.md, skill-deck, deck.md) - these were already migrated
- Modifying context files (pitch-deck-structure.md, touying-pitch-deck-template.md) - these were already migrated

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Missing a reference | Low | Low | Verify with grep after cleanup |
| Breaking JSON syntax | Medium | Low | Validate JSON after edits |
| Removing wrong content | Medium | Low | Use exact string matching |

## Implementation Phases

### Phase 1: Update manifest.json [NOT STARTED]

**Goal**: Remove deck entries from the manifest.json provides section

**Tasks**:
- [ ] Remove `"deck-agent.md"` from agents array (line 13)
- [ ] Remove `"skill-deck"` from skills array (line 19)
- [ ] Remove `"deck.md"` from commands array (line 25)
- [ ] Validate JSON syntax

**Timing**: 10 minutes

**Files to modify**:
- `.claude/extensions/filetypes/manifest.json` - Remove 3 array elements

**Verification**:
- `jq . manifest.json` succeeds (valid JSON)
- No "deck" entries in provides section

---

### Phase 2: Update EXTENSION.md [NOT STARTED]

**Goal**: Remove all deck documentation from EXTENSION.md

**Tasks**:
- [ ] Remove skill-deck row from Skill-Agent Mapping table (line 13)
- [ ] Remove /deck command examples from Command Usage section (lines 64-67)
- [ ] Remove entire "Pitch Deck Generation" section (lines 115-166)
- [ ] Remove deck pattern rows from Context Documentation table (lines 177-178)

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/filetypes/EXTENSION.md` - Remove ~65 lines

**Verification**:
- No "deck" references remain in file
- Markdown structure valid
- Tables properly formatted

---

### Phase 3: Update index-entries.json [NOT STARTED]

**Goal**: Remove deck context entries from index-entries.json

**Tasks**:
- [ ] Remove entry for pitch-deck-structure.md (lines 77-85)
- [ ] Remove entry for touying-pitch-deck-template.md (lines 86-94)
- [ ] Fix trailing comma if needed
- [ ] Validate JSON syntax

**Timing**: 10 minutes

**Files to modify**:
- `.claude/extensions/filetypes/index-entries.json` - Remove 2 entries

**Verification**:
- `jq . index-entries.json` succeeds (valid JSON)
- No entries referencing deck-agent or /deck command

---

### Phase 4: Final Verification [NOT STARTED]

**Goal**: Confirm complete removal of deck references

**Tasks**:
- [ ] Search for remaining "deck" references in filetypes extension
- [ ] Verify no orphaned references
- [ ] Confirm extension still loads correctly

**Timing**: 5 minutes

**Verification**:
- `grep -r "deck" .claude/extensions/filetypes/` returns no matches
- Extension manifest validates
- No broken references

## Testing & Validation

- [ ] `jq . .claude/extensions/filetypes/manifest.json` - Valid JSON
- [ ] `jq . .claude/extensions/filetypes/index-entries.json` - Valid JSON
- [ ] `grep -ri "deck" .claude/extensions/filetypes/` - No matches
- [ ] Manual review of EXTENSION.md formatting

## Artifacts & Outputs

- plans/02_cleanup-filetypes-plan.md (this file)
- summaries/03_cleanup-filetypes-summary.md (after implementation)

## Rollback/Contingency

All changes are file edits in version control. Rollback via:
```bash
git checkout HEAD -- .claude/extensions/filetypes/
```
