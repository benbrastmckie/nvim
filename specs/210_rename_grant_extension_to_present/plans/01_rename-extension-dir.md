# Implementation Plan: Rename Grant Extension to Present

- **Task**: 210 - rename_grant_extension_to_present
- **Status**: [COMPLETE]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: None
- **Artifacts**: plans/01_rename-extension-dir.md (this file)
- **Standards**:
  - .claude/context/core/standards/plan.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

This task renames the grant extension directory from `.claude/extensions/grant/` to `.claude/extensions/present/` and updates the core manifest.json fields to reflect the new name. This is the foundational rename that all subsequent tasks (211-219) depend on. The scope is deliberately limited to the directory rename and manifest field updates only - internal file contents and references are handled in later tasks.

## Goals & Non-Goals

**Goals**:
- Rename `.claude/extensions/grant/` directory to `.claude/extensions/present/` using git mv
- Update manifest.json `name` field from "grant" to "present"
- Update manifest.json `language` field from "grant" to "present"
- Update manifest.json `merge_targets.claudemd.section_id` from "extension_grant" to "extension_present"
- Preserve git history through proper use of git mv

**Non-Goals**:
- Renaming `context/project/grant/` subdirectory (task 214)
- Updating EXTENSION.md content (task 211)
- Updating agent file content or filename (tasks 212, 215)
- Updating skill content or directory (tasks 213, 216)
- Updating command file content or filename (tasks 217, 218)
- Updating index-entries.json or opencode-agents.json (task 219)

## Risks & Mitigations

- **Risk**: Git mv fails if destination exists. **Mitigation**: Verify destination does not exist before rename.
- **Risk**: Manifest.json edit introduces syntax error. **Mitigation**: Verify JSON validity after edit.
- **Risk**: Subsequent tasks reference old path. **Mitigation**: This is expected; later tasks handle internal references.

## Implementation Phases

### Phase 1: Directory Rename [COMPLETED]

**Goal**: Rename the extension directory using git mv to preserve history.

**Tasks**:
- [ ] Verify `.claude/extensions/present/` does not exist
- [ ] Execute `git mv .claude/extensions/grant .claude/extensions/present`
- [ ] Verify rename succeeded with `ls -la .claude/extensions/`

**Timing**: 10 minutes

**Files to modify**:
- `.claude/extensions/grant/` -> `.claude/extensions/present/` (rename)

**Verification**:
- `.claude/extensions/present/` exists
- `.claude/extensions/grant/` no longer exists
- `git status` shows rename operation

---

### Phase 2: Update manifest.json [COMPLETED]

**Goal**: Update the three manifest.json fields to reflect the new extension name.

**Tasks**:
- [ ] Update `name` field from "grant" to "present"
- [ ] Update `language` field from "grant" to "present"
- [ ] Update `merge_targets.claudemd.section_id` from "extension_grant" to "extension_present"
- [ ] Validate JSON syntax with `jq . manifest.json`

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/present/manifest.json` - Update 3 fields

**Verification**:
- `jq '.name' manifest.json` returns "present"
- `jq '.language' manifest.json` returns "present"
- `jq '.merge_targets.claudemd.section_id' manifest.json` returns "extension_present"

---

### Phase 3: Verification [COMPLETED]

**Goal**: Confirm all changes are correct and consistent.

**Tasks**:
- [ ] Verify directory structure matches expected layout
- [ ] Verify manifest.json contains all updated fields
- [ ] Check git status shows expected changes (rename + edit)
- [ ] Confirm no references to old "grant" name in manifest.json

**Timing**: 10 minutes

**Verification**:
- All checks pass
- Ready for git commit

## Testing & Validation

- [ ] `test -d .claude/extensions/present` returns success
- [ ] `test ! -d .claude/extensions/grant` returns success
- [ ] `jq -e '.name == "present"' .claude/extensions/present/manifest.json` returns success
- [ ] `jq -e '.language == "present"' .claude/extensions/present/manifest.json` returns success
- [ ] `jq -e '.merge_targets.claudemd.section_id == "extension_present"' .claude/extensions/present/manifest.json` returns success

## Artifacts & Outputs

- plans/01_rename-extension-dir.md (this file)
- summaries/01_rename-extension-summary.md (post-implementation)

## Rollback/Contingency

If the rename needs to be reverted:
1. `git mv .claude/extensions/present .claude/extensions/grant`
2. Restore manifest.json fields to original values
3. `git checkout -- .claude/extensions/grant/manifest.json` if needed
