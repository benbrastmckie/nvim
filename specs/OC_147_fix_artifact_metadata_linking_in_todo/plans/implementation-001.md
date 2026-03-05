# Implementation Plan: Fix Artifact Metadata Linking in TODO.md

- **Task**: OC_147 - fix_artifact_metadata_linking_in_todo
- **Status**: [NOT STARTED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: 
  - specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-001.md
  - specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-002.md
  - specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-003.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**:
  - .opencode/context/core/formats/plan-format.md
  - .opencode/context/core/standards/status-markers.md
  - .opencode/context/core/standards/documentation-standards.md
  - .opencode/context/core/standards/task-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan addresses the systemic issue where research reports are not being properly linked in TODO.md artifacts sections. The root cause is a gap in skill-researcher SKILL.md which lacks detailed postflight instructions found in skill-implementer. This affects ALL research tasks, not just OC_147.

The implementation involves two parallel tracks: (1) fixing the systemic skill specification gap to prevent future occurrences, and (2) fixing the specific OC_147 data inconsistencies (missing research-002.md and research-003.md links, mismatched state.json artifacts array).

### Research Integration

This plan integrates findings from three research reports:
- **research-001.md**: Identified the root cause as inconsistent skill postflight implementations
- **research-002.md**: Compared .claude/ vs .opencode/ systems, identified missing context files
- **research-003.md**: Detailed specific fixes needed for skill-researcher SKILL.md and OC_147 data

## Goals & Non-Goals

**Goals**:
- Update skill-researcher SKILL.md with complete postflight patterns matching skill-implementer
- Add missing context files (file-metadata-exchange.md, jq-escaping-workarounds.md) to skill-researcher
- Fix OC_147 TODO.md to link all three research reports (001, 002, 003)
- Sync OC_147 state.json artifacts array with actual report files
- Update skill-planner SKILL.md with same postflight patterns (preventive)
- Establish standardized TODO.md artifact linking format

**Non-Goals**:
- Rewriting agent definitions (general-research-agent.md works correctly)
- Changing the metadata file schema (already correct)
- Modifying the core metadata flow architecture (working correctly)
- Fixing non-research tasks (out of scope for this plan)
- Creating new context files (using existing ones from skill-implementer)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Editing SKILL.md breaks existing /research functionality | High | Medium | Test with a new test task after each skill update; keep backups |
| jq patterns have escaping issues in postflight | Medium | Medium | Use tested patterns from jq-escaping-workarounds.md; validate with test data |
| TODO.md format inconsistencies across tasks | Low | High | Standardize on OC_141 format; document the standard |
| Multiple .return-meta.json files orphaned | Low | Medium | Audit all specs/*/.return-meta.json files during Phase 5 |
| Phase dependencies cause delays | Low | Low | Phases 1-3 can proceed in parallel; Phases 4-5 depend on earlier phases |

## Implementation Phases

### Phase 1: Fix skill-researcher SKILL.md - Add Missing Context Files [NOT STARTED]

**Goal**: Add file-metadata-exchange.md and jq-escaping-workarounds.md to skill-researcher context_injection

**Tasks**:
- [ ] Read `.opencode/skills/skill-researcher/SKILL.md` (current: 90 lines)
- [ ] Edit Lines 18-26: Add missing context files to context_injection section
- [ ] Add `return-metadata-file.md` with variable `return_metadata`
- [ ] Add `postflight-control.md` with variable `postflight_control`
- [ ] Add `file-metadata-exchange.md` with variable `file_metadata`
- [ ] Add `jq-escaping-workarounds.md` with variable `jq_workarounds`
- [ ] Verify context_injection now matches skill-implementer pattern
- [ ] Write updated SKILL.md file

**Files to Modify**:
- `.opencode/skills/skill-researcher/SKILL.md` (Lines 18-26)

**Timing**: 45 minutes

**Success Criteria**:
- skill-researcher context_injection includes all 4 files (report-format.md, return-metadata-file.md, status-markers.md, file-metadata-exchange.md, jq-escaping-workarounds.md)
- Variables match skill-implementer naming convention
- File validates without XML/markdown syntax errors

---

### Phase 2: Fix skill-researcher SKILL.md - Expand Postflight Instructions [NOT STARTED]

**Goal**: Replace vague "Update state and link artifacts" with detailed postflight steps using context file patterns

**Tasks**:
- [ ] Read updated `.opencode/skills/skill-researcher/SKILL.md`
- [ ] Edit Lines 42-44: Expand Stage 4 (Postflight) action description
- [ ] Add Stage 5 (PostflightVerification) matching skill-implementer pattern
- [ ] Add detailed "Postflight" subsection after Line 90 with explicit steps:
  - Read metadata file using {file_metadata} patterns
  - Extract artifact path, type, summary from metadata
  - Update state.json status and artifacts array using {jq_workarounds}
  - Update TODO.md with artifact link in format: `- **Research**: [path](path) - summary`
  - Git commit with message: "task {N}: research complete"
  - Cleanup: Remove .return-meta.json file
- [ ] Add "PostflightVerification" subsection with validation steps
- [ ] Write updated SKILL.md file
- [ ] Verify SKILL.md now matches skill-implementer comprehensiveness

**Files to Modify**:
- `.opencode/skills/skill-researcher/SKILL.md` (Lines 42-44, after Line 90)

**Timing**: 60 minutes

**Dependencies**: Phase 1 complete

**Success Criteria**:
- Postflight stage has detailed action descriptions referencing {file_metadata} and {jq_workarounds}
- New PostflightVerification stage added
- Execution Flow section includes detailed postflight steps (4-5 substeps)
- SKILL.md file size increases from ~90 lines to ~110-120 lines

---

### Phase 3: Fix OC_147 TODO.md - Add Missing Research Links [NOT STARTED]

**Goal**: Update OC_147 TODO.md entry to link all three research reports with proper format and summaries

**Tasks**:
- [ ] Read `specs/TODO.md` lines 9-31 (OC_147 entry)
- [ ] Edit Line 30: Update research-001.md link format to include summary
  - Change from: `[specs/OC_147_.../reports/research-001.md](specs/OC_147_.../reports/research-001.md)`
  - Change to: `[research-001.md](OC_147_.../reports/research-001.md) - Comprehensive research report identifying root cause...`
- [ ] Add after Line 30: research-002.md link with summary
  - Format: `- **Research**: [research-002.md](OC_147_.../reports/research-002.md) - Comparative analysis of .claude/ vs .opencode/ metadata passing`
- [ ] Add after research-002.md: research-003.md link with summary
  - Format: `- **Research**: [research-003.md](OC_147_.../reports/research-003.md) - Deep dive investigation of OC_147 specific linking problems`
- [ ] Verify all three research reports are now linked in TODO.md
- [ ] Write updated TODO.md file

**Files to Modify**:
- `specs/TODO.md` (OC_147 entry, Line 30 and after)

**Timing**: 30 minutes

**Dependencies**: None (can proceed in parallel with Phases 1-2)

**Success Criteria**:
- OC_147 TODO.md entry links all three research reports (001, 002, 003)
- Each link includes descriptive summary
- Link format matches OC_141 pattern: `[filename.md](path) - summary`
- No broken markdown syntax

---

### Phase 4: Fix OC_147 state.json - Sync Artifacts Array [NOT STARTED]

**Goal**: Update OC_147 state.json artifacts array to include all three research reports

**Tasks**:
- [ ] Read `specs/state.json` lines 11-17 (OC_147 artifacts array)
- [ ] Verify current state: only research-001.md listed
- [ ] Edit artifacts array: Add research-002.md entry
  - Type: "research"
  - Path: "specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-002.md"
  - Summary: "Comparative analysis of .claude/ vs .opencode/ metadata passing mechanisms"
- [ ] Edit artifacts array: Add research-003.md entry
  - Type: "research"
  - Path: "specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-003.md"
  - Summary: "Deep dive investigation of OC_147 specific linking problems and systemic fixes"
- [ ] Verify JSON syntax is valid (no trailing commas, proper brackets)
- [ ] Write updated state.json file

**Files to Modify**:
- `specs/state.json` (OC_147 entry, artifacts array)

**Timing**: 30 minutes

**Dependencies**: Phase 3 complete (to ensure TODO.md links match state.json artifacts)

**Success Criteria**:
- OC_147 artifacts array includes all three research reports
- Each artifact has correct type, path, and summary fields
- JSON validates without syntax errors
- Paths match actual file locations

---

### Phase 5: Update skill-planner SKILL.md - Apply Same Patterns [NOT STARTED]

**Goal**: Apply same postflight pattern updates to skill-planner to prevent future planning task issues

**Tasks**:
- [ ] Read `.opencode/skills/skill-planner/SKILL.md` (current: ~93 lines)
- [ ] Edit context_injection section: Add missing context files
  - Add `return-metadata-file.md` with variable `return_metadata`
  - Add `postflight-control.md` with variable `postflight_control`
  - Add `file-metadata-exchange.md` with variable `file_metadata`
  - Add `jq-escaping-workarounds.md` with variable `jq_workarounds`
- [ ] Edit Postflight stage: Expand action description to use {file_metadata} and {jq_workarounds}
- [ ] Add PostflightVerification stage (optional but recommended)
- [ ] Add detailed postflight instructions in Execution Flow section
- [ ] Write updated SKILL.md file

**Files to Modify**:
- `.opencode/skills/skill-planner/SKILL.md`

**Timing**: 45 minutes

**Dependencies**: Phase 1-2 complete (use same pattern established for skill-researcher)

**Success Criteria**:
- skill-planner context_injection includes all required context files
- Postflight stage has detailed action descriptions
- SKILL.md comprehensiveness matches skill-implementer

---

### Phase 6: Cleanup and Verification [NOT STARTED]

**Goal**: Cleanup orphaned metadata files and verify all fixes work correctly

**Tasks**:
- [ ] Verify `specs/OC_147_fix_artifact_metadata_linking_in_todo/.return-meta.json` exists
- [ ] Remove `.return-meta.json` file (postflight should have cleaned it up)
- [ ] Audit all `specs/*/.return-meta.json` files across project
- [ ] List orphaned metadata files (tasks with status != researching but .return-meta.json exists)
- [ ] Create list of orphaned files for future cleanup (do not delete yet)
- [ ] Test /research command on a test task to verify skill-researcher still works
- [ ] Verify OC_147 TODO.md displays correctly in markdown preview
- [ ] Verify OC_147 state.json loads without JSON errors

**Files to Modify**:
- `specs/OC_147_fix_artifact_metadata_linking_in_todo/.return-meta.json` (delete)

**Timing**: 30 minutes

**Dependencies**: Phases 1-5 complete

**Success Criteria**:
- OC_147 .return-meta.json cleaned up
- Orphaned metadata files identified and documented
- /research command functional on test task
- No JSON syntax errors in modified files
- All three research reports accessible via TODO.md links

## Testing & Validation

- [ ] Validate skill-researcher SKILL.md XML/markdown syntax (no parsing errors)
- [ ] Validate skill-planner SKILL.md XML/markdown syntax
- [ ] Validate specs/TODO.md markdown syntax and link formats
- [ ] Validate specs/state.json JSON syntax
- [ ] Test /research command on new task to verify skill still functions
- [ ] Verify all OC_147 research report links resolve correctly
- [ ] Verify OC_147 artifacts array in state.json matches TODO.md links
- [ ] Confirm no orphaned .return-meta.json files remain for completed tasks

## Artifacts & Outputs

- `.opencode/skills/skill-researcher/SKILL.md` - Updated with complete postflight patterns
- `.opencode/skills/skill-planner/SKILL.md` - Updated with complete postflight patterns
- `specs/TODO.md` - OC_147 entry with all three research report links
- `specs/state.json` - OC_147 entry with complete artifacts array
- `specs/OC_147_fix_artifact_metadata_linking_in_todo/plans/implementation-001.md` - This plan
- `specs/OC_147_fix_artifact_metadata_linking_in_todo/.return-meta.json` - Cleaned up (deleted)

## Rollback/Contingency

**If skill-researcher update breaks /research command**:
1. Restore SKILL.md from git history: `git checkout HEAD -- .opencode/skills/skill-researcher/SKILL.md`
2. Identify specific change causing issue via git diff
3. Apply fixes more carefully, testing each change
4. Consider creating backup SKILL.md before modifications

**If TODO.md edits cause markdown parsing errors**:
1. Restore TODO.md from git: `git checkout HEAD -- specs/TODO.md`
2. Re-apply changes more carefully with syntax validation
3. Use markdown linter to verify syntax before committing

**If state.json edits cause JSON syntax errors**:
1. Restore state.json from git: `git checkout HEAD -- specs/state.json`
2. Use jq to validate JSON before writing: `jq . specs/state.json`
3. Re-apply artifact additions with careful comma placement

**If .return-meta.json cleanup is premature**:
1. File can be restored from git if needed: `git checkout HEAD -- specs/OC_147_.../.return-meta.json`
2. Or recreated manually with correct content

## Notes

### Context File References

The following context files are critical for postflight operations and must be included in skill context_injection:

1. **return-metadata-file.md** - Defines .return-meta.json schema and location
2. **postflight-control.md** - Marker file protocol for coordination
3. **file-metadata-exchange.md** - File I/O patterns for reading metadata
4. **jq-escaping-workarounds.md** - jq command patterns for state.json updates

### TODO.md Artifact Link Format Standard

Based on OC_141 working example, the standard format is:
```markdown
- **Research**: [research-NNN.md]({task_path}/reports/research-NNN.md) - Brief summary
- **Plan**: [implementation-NNN.md]({task_path}/plans/implementation-NNN.md) - Brief summary
- **Summary**: [implementation-summary-YYYYMMDD.md]({task_path}/summaries/...) - Brief summary
```

### Path Format Note

.opencode/ uses unpadded task numbers: `specs/{N}_{SLUG}/`
.claude/ uses zero-padded: `specs/{NNN}_{SLUG}/`

This plan maintains the .opencode/ unpadded format for consistency with existing conventions.
