# Implementation Plan: Update present/ Extension Metadata for Deck

- **Task**: 212 - update_present_extension_metadata_for_deck
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: Task #211 [COMPLETED]
- **Research Inputs**: None
- **Artifacts**: plans/01_update-metadata.md (this file)
- **Standards**:
  - .claude/context/core/formats/plan-format.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

Update the present/ extension configuration files to register the newly moved deck components from task 211. This involves adding deck-agent, skill-deck, and /deck command to the manifest.json provides arrays, adding deck context entries to index-entries.json, updating path references in deck-agent.md, and revising EXTENSION.md to reflect both grant and presentation capabilities.

## Goals & Non-Goals

**Goals**:
- Register deck components in manifest.json provides arrays
- Add deck context entries to index-entries.json with correct load_when conditions
- Update deck-agent.md context references from filetypes to present
- Revise EXTENSION.md title and add deck documentation section

**Non-Goals**:
- Modifying the actual deck-agent functionality
- Changing grant-related configuration
- Creating new context files

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| JSON syntax error in manifest.json | Medium | Low | Validate JSON after edit |
| Incorrect index-entries.json format | Medium | Low | Follow existing grant entry format |
| Missing context path updates | Low | Medium | Search for all @context references in deck-agent |

## Implementation Phases

### Phase 1: Update manifest.json [NOT STARTED]

**Goal**: Add deck components to the provides arrays

**Tasks**:
- [ ] Add "deck-agent.md" to provides.agents array (alongside grant-agent.md)
- [ ] Add "skill-deck" to provides.skills array (alongside skill-grant)
- [ ] Add "deck.md" to provides.commands array (alongside grant.md)
- [ ] Validate resulting JSON is syntactically correct

**Timing**: 10 minutes

**Files to modify**:
- `.claude/extensions/present/manifest.json` - Add 3 array entries

**Verification**:
- JSON validates with no syntax errors
- All 3 new entries present in correct arrays

---

### Phase 2: Update deck-agent.md Context References [NOT STARTED]

**Goal**: Change all context path references from filetypes to present

**Tasks**:
- [ ] Search for all `@context/project/filetypes/patterns/` references
- [ ] Replace with `@context/project/present/patterns/`
- [ ] Verify no stale filetypes references remain

**Timing**: 10 minutes

**Files to modify**:
- `.claude/extensions/present/agents/deck-agent.md` - Update context references

**Verification**:
- No `filetypes` references remain in file
- All `@context/project/present/patterns/` references point to valid context subdomain

---

### Phase 3: Update index-entries.json [NOT STARTED]

**Goal**: Add deck context entries following existing grant entry format

**Tasks**:
- [ ] Add entry for pitch-deck-structure.md with:
  - path: "project/present/patterns/pitch-deck-structure.md"
  - domain: "project", subdomain: "present"
  - load_when: languages ["deck"], agents ["deck-agent"], commands ["/deck"]
- [ ] Add entry for touying-pitch-deck-template.md with:
  - path: "project/present/patterns/touying-pitch-deck-template.md"
  - domain: "project", subdomain: "present"
  - load_when: languages ["deck"], agents ["deck-agent"], commands ["/deck"]
- [ ] Validate JSON syntax

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/present/index-entries.json` - Add 2 new entries

**Verification**:
- JSON validates with no syntax errors
- Both new entries present with correct structure
- load_when conditions reference deck-agent and /deck command

---

### Phase 4: Update EXTENSION.md [NOT STARTED]

**Goal**: Revise extension documentation to cover both grant and deck capabilities

**Tasks**:
- [ ] Change title from "Grant Extension" to "Present Extension" or "Grant & Deck Extension"
- [ ] Update description to mention both capabilities
- [ ] Add Deck section with:
  - Language routing table entry for deck language
  - Skill-agent mapping for skill-deck -> deck-agent
  - Deck workflow description
  - Key components (YC structure, touying, themes)
  - Context imports for deck patterns
- [ ] Ensure grant section remains intact

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/present/EXTENSION.md` - Add deck documentation section

**Verification**:
- Title reflects both capabilities
- Deck section documents routing, skill mapping, and workflow
- Grant section unchanged
- All context imports use correct present/ paths

---

## Testing & Validation

- [ ] All JSON files (manifest.json, index-entries.json) pass validation
- [ ] No stale `filetypes` path references in deck-agent.md
- [ ] Extension can be loaded without errors
- [ ] Context discovery queries for deck-agent return both deck pattern files

## Artifacts & Outputs

- plans/01_update-metadata.md (this file)
- Modified: `.claude/extensions/present/manifest.json`
- Modified: `.claude/extensions/present/EXTENSION.md`
- Modified: `.claude/extensions/present/index-entries.json`
- Modified: `.claude/extensions/present/agents/deck-agent.md`

## Rollback/Contingency

If extension loading fails after changes:
1. Check JSON syntax in manifest.json and index-entries.json with jq
2. Verify all path references exist
3. Restore from git if needed: `git checkout -- .claude/extensions/present/`
