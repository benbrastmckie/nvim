# Implementation Plan: Update Present Manifest and Metadata

- **Task**: 407 - update_present_manifest_and_metadata
- **Status**: [IMPLEMENTING]
- **Effort**: 0.5 hours
- **Dependencies**: 403 (completed), 405 (completed)
- **Research Inputs**: specs/407_update_present_manifest_and_metadata/reports/01_present-manifest-metadata.md
- **Artifacts**: plans/01_present-manifest-metadata.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Update three present extension metadata files to reflect the 3-agent split (slides-research-agent, pptx-assembly-agent, slidev-assembly-agent) that replaced the former slides-agent in tasks 403/405. Changes are limited to manifest.json agent declarations, EXTENSION.md skill-agent table, and index-entries.json stale references plus one missing entry for ucsf-institutional.json. All routing entries are already correct and need no changes.

### Research Integration

Research confirmed: (1) manifest.json provides.agents still lists deleted slides-agent.md, (2) EXTENSION.md shows single slides-agent row, (3) two index-entries.json entries have stale slides-agent in load_when.agents, (4) ucsf-institutional.json exists on disk but lacks an index entry. Routing section is already correct -- skill-slides handles internal dispatch.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task advances the "Subagent-return reference cleanup" roadmap item indirectly by eliminating stale agent references in extension metadata files.

## Goals & Non-Goals

**Goals**:
- Replace slides-agent.md with 3 new agents in manifest.json provides.agents
- Update EXTENSION.md skill-agent table to show 3-agent dispatch
- Fix 2 stale slides-agent references in index-entries.json
- Add missing ucsf-institutional.json entry to index-entries.json

**Non-Goals**:
- Modifying routing entries (already correct)
- Adding index entries for academic-clean.json or clinical-teal.json themes (pre-date this task)
- Creating or modifying agent definition files (done in task 403)
- Modifying skill-slides SKILL.md (done in task 405)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| JSON syntax error after editing | H | L | Validate all JSON with jq after each edit |
| Stale slides-agent references elsewhere | M | L | Grep entire extension for slides-agent after edits |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Update manifest.json [COMPLETED]

**Goal**: Replace slides-agent.md with the 3 new agent filenames in provides.agents.

**Tasks**:
- [ ] Edit `.claude/extensions/present/manifest.json` line 8: replace `"slides-agent.md"` with `"slides-research-agent.md", "pptx-assembly-agent.md", "slidev-assembly-agent.md"`
- [ ] Validate JSON with `jq . manifest.json`

**Timing**: 5 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/manifest.json` - provides.agents array

**Verification**:
- `jq '.provides.agents' manifest.json` lists 7 agents with no slides-agent.md
- `jq . manifest.json` exits 0

---

### Phase 2: Update EXTENSION.md [COMPLETED]

**Goal**: Replace single slides-agent row with 3-agent dispatch rows in the skill-agent table.

**Tasks**:
- [ ] Replace the `skill-slides | slides-agent` row (line 13) with 3 rows:
  - `skill-slides | slides-research-agent | opus | Research talk material synthesis`
  - `skill-slides | pptx-assembly-agent | opus | PowerPoint presentation assembly`
  - `skill-slides | slidev-assembly-agent | opus | Slidev presentation assembly`

**Timing**: 5 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/EXTENSION.md` - Skill-Agent Mapping table

**Verification**:
- EXTENSION.md contains 3 skill-slides rows with correct agent names
- No remaining references to `slides-agent` (without prefix)

---

### Phase 3: Update index-entries.json [NOT STARTED]

**Goal**: Fix 2 stale agent references and add the missing ucsf-institutional.json entry.

**Tasks**:
- [ ] Update `presentation-types.md` entry (line 349): change `"agents": ["slides-agent"]` to `"agents": ["slides-research-agent", "pptx-assembly-agent", "slidev-assembly-agent"]`
- [ ] Update `talk-structure.md` entry (line 363): change `"agents": ["slides-agent"]` to `"agents": ["slides-research-agent", "pptx-assembly-agent", "slidev-assembly-agent"]`
- [ ] Add new entry for `project/present/talk/themes/ucsf-institutional.json` with agents `["pptx-assembly-agent", "slidev-assembly-agent"]`
- [ ] Validate JSON with `jq . index-entries.json`
- [ ] Grep extension directory for any remaining `slides-agent` references

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/index-entries.json` - 2 existing entries + 1 new entry

**Verification**:
- `jq . index-entries.json` exits 0
- `grep -r "slides-agent" .claude/extensions/present/` returns no matches (excluding git history)
- New ucsf-institutional.json entry present in entries array

## Testing & Validation

- [ ] `jq . .claude/extensions/present/manifest.json` validates successfully
- [ ] `jq . .claude/extensions/present/index-entries.json` validates successfully
- [ ] `grep -rn "slides-agent" .claude/extensions/present/` returns zero matches
- [ ] manifest.json provides.agents contains exactly 7 entries
- [ ] index-entries.json has entries for both presentation-types.md and talk-structure.md with 3 new agent names
- [ ] index-entries.json has entry for ucsf-institutional.json

## Artifacts & Outputs

- `.claude/extensions/present/manifest.json` - Updated provides.agents
- `.claude/extensions/present/EXTENSION.md` - Updated skill-agent table
- `.claude/extensions/present/index-entries.json` - Fixed stale refs + new theme entry

## Rollback/Contingency

All 3 files are in git. Run `git checkout -- .claude/extensions/present/manifest.json .claude/extensions/present/EXTENSION.md .claude/extensions/present/index-entries.json` to revert all changes.
