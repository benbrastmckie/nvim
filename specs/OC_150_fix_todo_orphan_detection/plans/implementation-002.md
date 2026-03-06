# Implementation Plan: Fix /todo Orphan Detection for Completed Tasks

- **Task**: 150 - fix_todo_orphan_detection_completed_tasks
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/OC_150_fix_todo_orphan_detection/reports/research-001.md
- **Artifacts**: plans/implementation-002.md (this file)
- **Standards**:
  - .opencode/context/core/formats/plan-format.md
  - .opencode/context/core/standards/status-markers.md
  - .opencode/context/core/standards/documentation-standards.md
  - .opencode/context/core/standards/task-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Fix the /todo command's orphan detection to properly identify and archive completed/abandoned tasks that appear in TODO.md but have been manually removed from state.json. Currently, tasks like OC_138, OC_139, OC_140 are marked [COMPLETED] in TODO.md with directories in specs/, but are not being archived because they are missing from state.json's active_projects array.

### Research Integration

This plan integrates findings from research-001.md which identified a critical gap in Stage 3 (DetectOrphans): the logic only considers tasks in state.json with status "completed" or "abandoned", ignoring TODO.md entries with status markers. The fix requires scanning TODO.md for completed/abandoned entries and cross-referencing with both state.json and filesystem to identify orphans.

## Goals & Non-Goals

**Goals**:
- [ ] Extend Stage 3 (DetectOrphans) to scan TODO.md for completed/abandoned tasks not in state.json
- [ ] Update Stage 9 (InteractivePrompts) to prompt for TODO.md orphan archival
- [ ] Extend Stage 10 (ArchiveTasks) to handle TODO.md orphan archival to archive/
- [ ] Ensure Stage 11 (UpdateTODO) properly removes archived TODO.md entries
- [ ] Test with real orphans (OC_138, OC_139, OC_140)

**Non-Goals**:
- [ ] Modifying the state.json schema or data structure
- [ ] Changing how normal (state.json tracked) tasks are archived
- [ ] Adding new archive file formats or CHANGE_LOG.md structure changes
- [ ] Refactoring unrelated stages (1-2, 4-8, 12-16)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Regex parsing TODO.md may miss edge cases | Medium | Medium | Test with multiple task number formats (OC_N and N), use robust patterns with escape sequences for markdown markers |
| Archive state.json may not exist initially | Low | Low | Add existence check before writing, create archive directory structure if missing |
| Orphan detection duplicates existing logic | Low | High | Refactor to share directory scanning logic between Stage 3 and TODO.md scanning |
| TODO.md format changes break parsing | Low | Low | Document parsing assumptions, make patterns flexible for whitespace variations |

## Implementation Phases

### Phase 1: Update Stage 3 - DetectOrphans with TODO.md Scanning [NOT STARTED]

**Goal**: Add TODO.md scanning to detect completed/abandoned tasks not tracked in state.json

**Tasks**:
- [ ] Add Step 3.x to Stage 3: Scan TODO.md for orphan entries
- [ ] Implement regex pattern to extract task headers: `### (OC_)?(\d+)\.`
- [ ] Implement regex pattern to extract status: `- \*\*Status\*\*: \[(COMPLETED|ABANDONED)\]`
- [ ] Cross-reference TODO.md tasks with state.json active_projects
- [ ] Build `todo_md_orphans` array for tasks in TODO.md but not state.json with completed/abandoned status
- [ ] Verify directories exist in specs/ before flagging as orphans

**Timing**: 1 hour

**Verification**:
- Pattern matches OC_138, OC_139, OC_140 in current TODO.md
- `todo_md_orphans` array populated correctly with task numbers and statuses
- No false positives for active tasks in state.json

### Phase 2: Update Stage 9 - InteractivePrompts for TODO.md Orphans [NOT STARTED]

**Goal**: Add interactive prompts for TODO.md orphan archival approval

**Tasks**:
- [ ] Add Step 9.x: Present TODO.md orphans to user
- [ ] Display formatted list: "Found {N} completed/abandoned tasks in TODO.md not tracked in state.json"
- [ ] Show each orphan with project number, status, and directory path
- [ ] Use AskUserQuestion to prompt: "Archive these TODO.md orphans?"
- [ ] Store user decision in `archive_todo_orphans` flag
- [ ] Allow selective archival via multiSelect if multiple orphans found

**Timing**: 30 minutes

**Verification**:
- Prompt displays correctly with orphan task details
- User can approve/reject archival
- Selected orphans tracked for processing

### Phase 3: Update Stage 10 - ArchiveTasks for TODO.md Orphans [NOT STARTED]

**Goal**: Extend archival logic to handle TODO.md orphans (tasks not in state.json)

**Tasks**:
- [ ] Add Step 10.x: Archive TODO.md orphans
- [ ] For each approved TODO.md orphan:
  - Extract project name from TODO.md task header
  - Extract completion_summary from TODO.md if available
  - Build minimal archive entry with available metadata
  - Add to specs/archive/state.json completed_projects array
  - Move directory from specs/ to specs/archive/
  - Set archived_at timestamp
- [ ] Update Stage 10 commit message to include TODO.md orphan count
- [ ] Handle case where orphan has no directory (warn but proceed)

**Timing**: 45 minutes

**Verification**:
- Archive entries created with correct structure
- Directories moved to specs/archive/
- Archive state.json updated with orphan entries
- CHANGE_LOG.md tracks orphan archival

### Phase 4: Update Stage 11 - UpdateTODO Cleanup [NOT STARTED]

**Goal**: Ensure TODO.md entries are removed for both regular and TODO.md orphans

**Tasks**:
- [ ] Verify Step 11.x removes TODO.md entries for archived orphans
- [ ] Ensure regex pattern matches both `### OC_{N}. ` and `### {N}. ` formats
- [ ] Handle multi-line task entries (header through next task or section end)
- [ ] Verify next_project_number is not decremented (orphan removal shouldn't affect numbering)
- [ ] Add validation that removed entries match expected pattern

**Timing**: 30 minutes

**Verification**:
- Archived TODO.md entries removed cleanly
- File structure preserved (no partial removals)
- Adjacent entries unaffected

### Phase 5: Testing and Validation [NOT STARTED]

**Goal**: Verify the fix works with real-world orphans

**Tasks**:
- [ ] Run /todo --dry-run to preview changes
- [ ] Confirm OC_138, OC_139, OC_140 detected as TODO.md orphans
- [ ] Verify orphan detection doesn't flag active tasks
- [ ] Test archive operation (or simulate with dry-run review)
- [ ] Verify CHANGE_LOG.md updated with orphan archival entries
- [ ] Verify TODO.md entries removed for archived orphans
- [ ] Run /todo again to confirm no remaining orphans

**Timing**: 15 minutes

**Verification**:
- All real orphans (OC_138, OC_139, OC_140) properly detected
- Archive entries match expected format
- No regressions in existing task archival flow

## Testing & Validation

- [ ] **Test Scenario 1**: TODO.md orphan only (task completed in TODO.md, not in state.json, directory exists)
  - Expected: Detected and offered for archival
- [ ] **Test Scenario 2**: State.json orphan only (task completed in state.json, not in TODO.md)
  - Expected: Detected and offered for archival (existing behavior preserved)
- [ ] **Test Scenario 3**: Both orphan types present
  - Expected: Both detected and archived together
- [ ] **Test Scenario 4**: No orphans (normal operation)
  - Expected: No orphans detected, normal archival flow continues
- [ ] **Test Scenario 5**: Edge case - orphan without directory
  - Expected: Warning displayed, archival skipped or partially completed

## Artifacts & Outputs

- Modified file: `.opencode/skills/skill-todo/SKILL.md` - Updated with TODO.md orphan detection
- Plan artifact: `specs/OC_150_fix_todo_orphan_detection/plans/implementation-002.md` (this file)
- Summary: `specs/OC_150_fix_todo_orphan_detection/summaries/implementation-summary-YYYYMMDD.md` (post-implementation)
- Archived tasks: `specs/archive/OC_138_*`, `specs/archive/OC_139_*`, `specs/archive/OC_140_*`
- Updated CHANGE_LOG.md with orphan archival entries

## Rollback/Contingency

**If implementation fails**:
1. Restore skill-todo/SKILL.md from git: `git checkout .opencode/skills/skill-todo/SKILL.md`
2. No state.json changes made during failed implementation (changes applied only on successful /todo execution)
3. Re-run /todo after fix to complete archival of real orphans
4. Document failure in task summary and update CHANGE_LOG.md with attempt notes

**If partial failure** (some orphans archived, others not):
1. Check specs/archive/state.json for consistency
2. Manually move any stranded directories
3. Update CHANGE_LOG.md manually if needed
4. Complete orphaned archival in follow-up session
