# Research Report: Task #484

**Task**: 484 - Wire project-overview components into extension system
**Started**: 2026-04-20T23:00:00Z
**Completed**: 2026-04-20T23:15:00Z
**Effort**: Medium
**Dependencies**: Task 482 (detection rule), Task 483 (skill + command)
**Sources/Inputs**:
- Codebase audit of `.claude/extensions/core/` source files
- Installed files in `.claude/` working directories
- `.claude/extensions.json` tracking records
- `.claude/CLAUDE.md` and merge-source `claudemd.md`
- `.claude/extensions/core/index-entries.json`
- `.claude/extensions/core/manifest.json`
**Artifacts**:
- specs/484_wire_project_overview_components/reports/01_wire-components.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Tasks 482/483 created the extension source files correctly (rule, skill, command) and updated `manifest.json` provides sections, but the files were NOT installed to the working `.claude/` directories
- The `extensions.json` installed_files/installed_dirs tracking for core does not include the new skill, command, or updated rule
- The `claudemd.md` merge-source needs a `/project-overview` entry in both the Command Reference table and Skill-to-Agent Mapping table
- The `index-entries.json` does not need new entries (the detection rule is auto-applied via path glob, not context discovery; the skill is direct-execution)
- The `update-project.md` (both source and installed) needs updating to reference the `/project-overview` automated workflow
- The installed detection rule at `.claude/rules/project-overview-detection.md` is stale (still says `/task "Generate..."` instead of `/project-overview`)

## Context & Scope

Task 484 is the final wiring step after tasks 482 (detection rule) and 483 (skill + command). The goal is to ensure all new components are properly registered in the extension system so that:
1. The loader installs them to the correct working directories
2. The generated CLAUDE.md documents the new command and skill
3. The extensions.json tracks them for uninstall/reinstall
4. The update-project.md guide references the new automated workflow

## Findings

### 1. Manifest.json (DONE - No Changes Needed)

The `manifest.json` already has all three new items in `provides`:
- `provides.commands` includes `"project-overview.md"`
- `provides.rules` includes `"project-overview-detection.md"`
- `provides.skills` includes `"skill-project-overview"`

### 2. Extensions.json installed_files (NEEDS UPDATE)

The `core` entry in `extensions.json` is missing these installed items:

**Missing from `installed_files`:**
- `".claude/commands/project-overview.md"`
- `".claude/rules/project-overview-detection.md"`
- `".claude/skills/skill-project-overview/SKILL.md"`

**Missing from `installed_dirs`:**
- `".claude/skills/skill-project-overview"`

### 3. Installed Files Not Copied (NEEDS FILE COPY)

The actual installed working files need to exist:
- `.claude/commands/project-overview.md` -- does NOT exist (needs copy from extension source)
- `.claude/skills/skill-project-overview/SKILL.md` -- does NOT exist (needs copy from extension source)
- `.claude/rules/project-overview-detection.md` -- EXISTS but is stale (needs overwrite from extension source)

The extension source at `.claude/extensions/core/rules/project-overview-detection.md` has the correct content (references `/project-overview`), but the installed version at `.claude/rules/project-overview-detection.md` still references the old `/task "Generate..."` approach.

### 4. CLAUDE.md Merge Source (NEEDS UPDATE)

The `claudemd.md` merge-source needs updates in two locations:

**4a. Command Reference table** -- Add `/project-overview` row:

Current table does not include `/project-overview`. Needs a new row:
```
| `/project-overview` | `/project-overview` | Interactive project overview generation |
```

**4b. Skill-to-Agent Mapping table** -- Add `skill-project-overview` row:

Current table does not include `skill-project-overview`. Needs a new row:
```
| skill-project-overview | (direct execution) | - | Interactive project overview generation |
```

**4c. "New repository setup" paragraph** -- Update to reference `/project-overview`:

The current text says:
> run `/task "Generate project-overview.md for this repository"` to create a project-specific version

Should be updated to reference `/project-overview` as the primary command, with `/task` as fallback.

### 5. Index Entries (NO CHANGES NEEDED)

The context index does NOT need new entries for:
- **Detection rule**: Rules are auto-loaded based on their `paths:` frontmatter glob, not via `index.json`
- **Skill SKILL.md**: Skills are loaded via the Skill tool invocation, not context discovery
- **Command project-overview.md**: Commands are loaded via `/` invocation, not context discovery

The existing `repo/update-project.md` index entry already covers the guide file.

### 6. Update-Project.md (NEEDS UPDATE)

Both the extension source and installed versions of `update-project.md` should be updated to:
- Reference `/project-overview` as the recommended automated workflow
- Keep the manual process as a fallback/reference
- Add a section noting the automated 3-stage workflow (scan, interview, task creation)

### 7. Generated CLAUDE.md (WILL AUTO-UPDATE)

The generated `.claude/CLAUDE.md` is produced by merging `claudemd.md` with extension sections. Once `claudemd.md` is updated (finding 4), the next extension load will regenerate CLAUDE.md correctly. No direct edits to `.claude/CLAUDE.md` are needed -- only the merge-source needs updating.

## Decisions

- **No new index entries**: Rules and skills do not need context index entries since they are loaded through their own mechanisms (path globs and Skill tool respectively)
- **Update merge-source only**: The generated CLAUDE.md should not be edited directly; only the merge-source at `extensions/core/merge-sources/claudemd.md` needs changes
- **Overwrite stale installed rule**: The installed detection rule needs to be replaced with the extension source version

## Recommendations

Implementation should follow this order:

### Phase 1: Install Missing Files
1. Copy `extensions/core/commands/project-overview.md` to `.claude/commands/project-overview.md`
2. Create `.claude/skills/skill-project-overview/` directory
3. Copy `extensions/core/skills/skill-project-overview/SKILL.md` to `.claude/skills/skill-project-overview/SKILL.md`
4. Overwrite `.claude/rules/project-overview-detection.md` with `extensions/core/rules/project-overview-detection.md`

### Phase 2: Update Extensions Tracking
5. Update `extensions.json` core section:
   - Add `.claude/commands/project-overview.md` to `installed_files`
   - Add `.claude/rules/project-overview-detection.md` to `installed_files`
   - Add `.claude/skills/skill-project-overview/SKILL.md` to `installed_files`
   - Add `.claude/skills/skill-project-overview` to `installed_dirs`

### Phase 3: Update CLAUDE.md Merge Source
6. Add `/project-overview` to Command Reference table in `claudemd.md`
7. Add `skill-project-overview` to Skill-to-Agent Mapping table in `claudemd.md`
8. Update "New repository setup" paragraph to reference `/project-overview`

### Phase 4: Update Guide Documentation
9. Update `extensions/core/context/repo/update-project.md` to reference `/project-overview`
10. Update installed `.claude/context/repo/update-project.md` to match

### Phase 5: Regenerate CLAUDE.md
11. The generated `.claude/CLAUDE.md` needs regeneration after merge-source changes (this happens automatically on next extension load, but may need manual regeneration for immediate effect)

## Risks & Mitigations

- **Risk**: Manually editing `extensions.json` could break the loader if format is wrong
  - **Mitigation**: Follow exact existing patterns for the installed_files and installed_dirs arrays
- **Risk**: CLAUDE.md merge-source table formatting must be exact for proper generation
  - **Mitigation**: Match existing row patterns exactly; verify with extension load after changes
- **Risk**: Stale installed rule could cause confusion if not overwritten
  - **Mitigation**: Phase 1 addresses this first before any other changes

## Appendix

### Files to Create/Copy
| Source | Target | Action |
|--------|--------|--------|
| `extensions/core/commands/project-overview.md` | `.claude/commands/project-overview.md` | Copy (new) |
| `extensions/core/skills/skill-project-overview/SKILL.md` | `.claude/skills/skill-project-overview/SKILL.md` | Copy (new) |
| `extensions/core/rules/project-overview-detection.md` | `.claude/rules/project-overview-detection.md` | Overwrite (stale) |

### Files to Edit
| File | Change |
|------|--------|
| `.claude/extensions.json` | Add installed_files and installed_dirs entries |
| `extensions/core/merge-sources/claudemd.md` | Add command + skill rows, update setup paragraph |
| `extensions/core/context/repo/update-project.md` | Add /project-overview reference |
| `.claude/context/repo/update-project.md` | Match source changes |

### Search Queries Used
- `grep -r "project-overview"` across `.claude/` directory tree
- File existence checks for installed skill, command, rule
- Diff comparison of installed vs source detection rule
