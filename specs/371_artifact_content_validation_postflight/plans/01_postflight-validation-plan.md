# Implementation Plan: Artifact Content Validation in Postflight

- **Task**: 371 - Add artifact content validation to skill postflight stages
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/371_artifact_content_validation_postflight/reports/01_postflight-validation-research.md
- **Artifacts**: plans/01_postflight-validation-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Skill postflight stages currently validate only `.return-meta.json` metadata, not the actual artifact content. This plan creates a reusable validation script that checks reports, plans, and summaries against their format standards (required metadata fields, required sections, phase heading format), then integrates that script into the three skill postflight flows as a non-blocking validation step between metadata parsing and status update.

### Research Integration

The research report (01_postflight-validation-research.md) mapped all required metadata fields and sections for each artifact type, identified identical insertion points across all three skills (between Stage 6 and Stage 7), confirmed that validation should be non-blocking (warn and continue), and recommended auto-fix for missing metadata fields only. The format requirements matrix and existing script conventions from the research are used directly in this plan.

### Roadmap Alignment

No ROAD_MAP.md found.

## Goals & Non-Goals

**Goals**:
- Create `.claude/scripts/validate-artifact.sh` that validates report, plan, and summary artifacts against their format standards
- Support `--fix` flag for auto-repair of missing metadata fields
- Integrate validation into skill-researcher, skill-planner, and skill-implementer postflight stages
- Surface validation failures as non-blocking warnings visible to the user

**Non-Goals**:
- Generating missing section content (requires agent-level work, out of scope for a bash script)
- Fixing section ordering within artifacts
- Validating extension-specific artifact formats
- Making validation failures block the postflight pipeline

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Auto-fix corrupts artifact content | H | L | Auto-fix only inserts new metadata lines after the last existing one; never modifies existing content |
| Format standards evolve and validation becomes stale | M | M | Define required fields/sections as arrays at top of script with comments pointing to format files |
| Validation adds latency to postflight | L | L | grep-based checks are sub-second; no performance concern |
| Edge cases in artifact parsing (empty files, binary) | M | L | Guard with file existence and readability checks before any parsing |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Create Validation Script [NOT STARTED]

**Goal**: Build `.claude/scripts/validate-artifact.sh` that validates all three artifact types with structured output and optional auto-fix.

**Tasks**:
- [ ] Create script skeleton with shebang, strict mode, usage docs, and argument parsing (artifact_path, artifact_type, --fix, --strict flags)
- [ ] Implement shared validation functions: `log_error()`, `log_warning()`, `log_info()`, file existence check, non-empty check, H1 title heading check
- [ ] Implement metadata field validation per artifact type using the format requirements matrix from research:
  - Report: Task, Started, Completed, Effort, Dependencies, Sources/Inputs, Artifacts, Standards
  - Plan: Task, Status, Effort, Dependencies, Research Inputs, Artifacts, Standards, Type
  - Summary: Task, Status, Started, Completed, Artifacts, Standards
- [ ] Implement required section validation per artifact type:
  - Report: Executive Summary, Context & Scope, Findings, Decisions, Recommendations
  - Plan: Overview, Goals & Non-Goals, Risks & Mitigations, Implementation Phases, Testing & Validation, Artifacts & Outputs, Rollback/Contingency
  - Summary: Overview, What Changed, Decisions, Impacts, Follow-ups, References
- [ ] Implement plan-specific checks: at least one `### Phase` heading, Status marker in metadata
- [ ] Implement `--fix` mode: insert missing Standards, Artifacts, and Effort metadata lines after last existing metadata line
- [ ] Implement structured output format: `[PASS]`/`[FAIL]` summary line with counts, indented `[ERROR]`/`[WARN]` detail lines
- [ ] Implement exit codes: 0 (valid), 1 (errors found), 2 (auto-fixed), 3 (file not found), 4 (unknown type)

**Timing**: 2 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/validate-artifact.sh` - New file (~150-200 lines)

**Verification**:
- Script runs without errors on existing plan and report artifacts in specs/
- Script correctly detects missing sections when run on a deliberately incomplete artifact
- `--fix` flag adds missing metadata fields without corrupting existing content
- Exit codes match the documented specification

---

### Phase 2: Integrate into Skill Postflight Stages [NOT STARTED]

**Goal**: Add Stage 6a (Validate Artifact Content) to all three skill SKILL.md files between the existing Stage 6 (Parse Return) and Stage 7 (Update Status).

**Tasks**:
- [ ] Add Stage 6a to `skill-researcher/SKILL.md`: validate artifact when artifact_path is non-empty, status is "researched", and file exists; run with `--fix`; log warning on failure but continue
- [ ] Add Stage 6a to `skill-planner/SKILL.md`: same pattern, triggered when status is "planned"
- [ ] Add Stage 6a to `skill-implementer/SKILL.md`: same pattern, triggered when status matches success (completed/partial)
- [ ] Ensure consistent wording across all three SKILL.md files for the new stage
- [ ] Verify stage numbering remains consistent (subsequent stages do not need renumbering since this is 6a)

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - Add Stage 6a
- `.claude/skills/skill-planner/SKILL.md` - Add Stage 6a
- `.claude/skills/skill-implementer/SKILL.md` - Add Stage 6a

**Verification**:
- Each SKILL.md contains a Stage 6a section with validation logic
- The validation call uses `--fix` flag and is non-blocking (warns on failure, continues)
- Stage numbering is consistent and no existing stage references are broken

---

### Phase 3: Testing and Edge Case Handling [NOT STARTED]

**Goal**: Verify the validation script works correctly across real artifacts and edge cases, and fix any issues found.

**Tasks**:
- [ ] Test validation against existing artifacts in specs/ directories (real plans, reports, summaries)
- [ ] Create test cases for edge conditions: empty file, file with only whitespace, binary file, wrong artifact type argument
- [ ] Test `--fix` mode on an artifact with deliberately removed metadata fields; verify insertion is correct
- [ ] Test `--strict` mode treats warnings as errors (non-zero exit)
- [ ] Verify the script handles both relative and absolute paths correctly
- [ ] Fix any issues discovered during testing

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `.claude/scripts/validate-artifact.sh` - Bug fixes from testing (if needed)

**Verification**:
- All existing artifacts in specs/ pass validation (exit code 0)
- Edge cases produce correct exit codes and meaningful error messages
- Auto-fix does not corrupt any real artifact when run with `--fix`

## Testing & Validation

- [ ] `validate-artifact.sh` exits 0 on compliant plan artifacts
- [ ] `validate-artifact.sh` exits 0 on compliant report artifacts
- [ ] `validate-artifact.sh` exits 0 on compliant summary artifacts
- [ ] `validate-artifact.sh` exits 1 on artifact missing required sections
- [ ] `validate-artifact.sh` exits 3 on nonexistent file path
- [ ] `validate-artifact.sh` exits 4 on unknown artifact type
- [ ] `--fix` flag repairs missing metadata fields and exits 2
- [ ] All three SKILL.md files contain Stage 6a with non-blocking validation
- [ ] Running a real postflight flow does not break due to validation

## Artifacts & Outputs

- `.claude/scripts/validate-artifact.sh` - New validation script (~150-200 lines)
- `.claude/skills/skill-researcher/SKILL.md` - Updated with Stage 6a
- `.claude/skills/skill-planner/SKILL.md` - Updated with Stage 6a
- `.claude/skills/skill-implementer/SKILL.md` - Updated with Stage 6a
- `specs/371_artifact_content_validation_postflight/plans/01_postflight-validation-plan.md` - This plan
- `specs/371_artifact_content_validation_postflight/summaries/01_postflight-validation-summary.md` - Execution summary (after implementation)

## Rollback/Contingency

- The validation script is a new file with no dependencies; removing it reverts to the current behavior
- SKILL.md changes are additive (a new Stage 6a); removing the stage block restores original postflight flow
- Since validation is non-blocking, even a buggy script cannot break existing postflight behavior -- it only produces warnings
- If auto-fix proves unreliable, the `--fix` flag can be removed from the SKILL.md invocations without removing the validation itself
