# Implementation Plan: Wire project-overview components

- **Task**: 484 - Wire project-overview components into extension system
- **Status**: [IMPLEMENTING]
- **Effort**: 1 hour
- **Dependencies**: Task 482 (detection rule), Task 483 (skill + command)
- **Research Inputs**: specs/484_wire_project_overview_components/reports/01_wire-components.md
- **Artifacts**: plans/01_wire-components.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This task wires the project-overview components created by tasks 482 and 483 into the extension system. The work involves copying missing installed files from extension sources, updating extensions.json tracking, editing the CLAUDE.md merge-source to register the new command and skill, and updating the update-project.md guide. No new index entries are needed since rules use path globs and skills use direct invocation.

### Research Integration

The research report (01_wire-components.md) audited all integration points and confirmed: manifest.json is already correct, index-entries.json needs no changes, the installed detection rule is stale and needs overwriting, and the CLAUDE.md merge-source needs three edits (command table row, skill table row, setup paragraph update).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this task. This is internal extension wiring that completes the project-overview feature chain (482 -> 483 -> 484).

## Goals & Non-Goals

**Goals**:
- Install missing command, skill, and updated rule files to working .claude/ directories
- Register all installed files in extensions.json for proper tracking
- Add /project-overview to CLAUDE.md command and skill tables via merge-source
- Update update-project.md to reference the automated /project-overview workflow

**Non-Goals**:
- Modifying the generated .claude/CLAUDE.md directly (it regenerates from merge-source)
- Adding context index entries (not needed for rules or skills)
- Changing manifest.json (already correct)
- Regenerating CLAUDE.md (happens automatically on next extension load)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Malformed extensions.json after edit | M | L | Follow exact existing array patterns; validate JSON after edit |
| Merge-source table formatting breaks CLAUDE.md generation | M | L | Match existing row format exactly |
| Stale installed rule causes incorrect behavior | L | L | Phase 1 overwrites it first |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Install missing files and update extensions.json [COMPLETED]

**Goal**: Copy extension source files to working directories and register them in extensions.json tracking.

**Tasks**:
- [ ] Copy `.claude/extensions/core/commands/project-overview.md` to `.claude/commands/project-overview.md`
- [ ] Create `.claude/skills/skill-project-overview/` directory
- [ ] Copy `.claude/extensions/core/skills/skill-project-overview/SKILL.md` to `.claude/skills/skill-project-overview/SKILL.md`
- [ ] Overwrite `.claude/rules/project-overview-detection.md` with `.claude/extensions/core/rules/project-overview-detection.md`
- [ ] Add `.claude/commands/project-overview.md` to extensions.json core installed_files
- [ ] Add `.claude/rules/project-overview-detection.md` to extensions.json core installed_files
- [ ] Add `.claude/skills/skill-project-overview/SKILL.md` to extensions.json core installed_files
- [ ] Add `.claude/skills/skill-project-overview` to extensions.json core installed_dirs
- [ ] Validate extensions.json is valid JSON after edits

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/commands/project-overview.md` - Create (copy from extension source)
- `.claude/skills/skill-project-overview/SKILL.md` - Create (copy from extension source)
- `.claude/rules/project-overview-detection.md` - Overwrite with extension source
- `.claude/extensions.json` - Add installed_files and installed_dirs entries

**Verification**:
- All three installed files exist and match their extension source
- extensions.json parses as valid JSON
- New entries appear in the correct arrays

---

### Phase 2: Update CLAUDE.md merge-source [COMPLETED]

**Goal**: Add /project-overview command and skill-project-overview entries to the claudemd.md merge-source, and update the "New repository setup" paragraph.

**Tasks**:
- [ ] Add `/project-overview` row to the Command Reference table in `extensions/core/merge-sources/claudemd.md`
- [ ] Add `skill-project-overview` row to the Skill-to-Agent Mapping table in `extensions/core/merge-sources/claudemd.md`
- [ ] Update "New repository setup" paragraph to reference `/project-overview` as primary command

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/core/merge-sources/claudemd.md` - Add command row, skill row, update setup paragraph

**Verification**:
- Command table contains `/project-overview` row with correct format
- Skill table contains `skill-project-overview` row with correct format
- Setup paragraph mentions `/project-overview`

---

### Phase 3: Update update-project.md guide [COMPLETED]

**Goal**: Update both the extension source and installed versions of update-project.md to reference the /project-overview automated workflow.

**Tasks**:
- [ ] Update `.claude/extensions/core/context/repo/update-project.md` to reference `/project-overview` as the recommended workflow
- [ ] Update installed `.claude/context/repo/update-project.md` to match the source changes

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/core/context/repo/update-project.md` - Add /project-overview reference
- `.claude/context/repo/update-project.md` - Match source changes

**Verification**:
- Both files reference `/project-overview`
- Both files are consistent with each other
- Manual process is preserved as fallback/reference

## Testing & Validation

- [ ] extensions.json parses as valid JSON (`python3 -m json.tool .claude/extensions.json`)
- [ ] All three installed files exist: command, skill, rule
- [ ] Installed detection rule references `/project-overview` (not old `/task` approach)
- [ ] Merge-source command table has `/project-overview` row
- [ ] Merge-source skill table has `skill-project-overview` row
- [ ] Both update-project.md files reference `/project-overview`

## Artifacts & Outputs

- plans/01_wire-components.md (this file)
- summaries/01_wire-components-summary.md (after implementation)

## Rollback/Contingency

All changes are to tracked files in git. Revert with `git checkout -- .claude/extensions.json .claude/extensions/core/merge-sources/claudemd.md .claude/extensions/core/context/repo/update-project.md .claude/context/repo/update-project.md` and delete the newly created files (`.claude/commands/project-overview.md`, `.claude/skills/skill-project-overview/`).
