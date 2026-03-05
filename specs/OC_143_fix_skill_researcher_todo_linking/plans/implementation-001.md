# Implementation Plan: Task #143

- **Task**: 143 - Fix skill-researcher TODO.md linking regression
- **Status**: [COMPLETED]
- **Effort**: 1-2 hours
- **Dependencies**: None
- **Research Inputs**: specs/OC_143_fix_skill_researcher_todo_linking/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: .opencode/context/core/formats/plan-format.md, .opencode/context/core/standards/status-markers.md, .opencode/context/core/standards/documentation-standards.md, .opencode/context/core/standards/task-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Fix the regression in skill-researcher where research reports are not being linked in TODO.md by adding the missing `metadata_file_path` parameter to the Stage 3 delegation prompt. This will allow general-research-agent to write its return metadata to the correct location, enabling postflight to successfully parse and link artifacts.

### Research Integration

Research identified the root cause as missing `metadata_file_path` parameter in skill-researcher/SKILL.md Stage 3 delegation prompt (lines 80-89). The general-research-agent expects this parameter to know where to write `.return-meta.json`. Without it, postflight cannot parse artifacts and link them in TODO.md. Working patterns in extension skills (skill-nix-research, skill-web-research) correctly include this parameter.

## Goals & Non-Goals

**Goals**:
- Add `metadata_file_path` parameter to skill-researcher Stage 3 delegation prompt
- Ensure format matches general-research-agent expectations
- Verify TODO.md artifact linking works after fix

**Non-Goals**:
- Changing general-research-agent behavior
- Modifying TODO.md linking logic in orchestrator
- Refactoring other parts of skill-researcher

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Wrong path format | High | Low | Follow exact pattern from working skills (skill-nix-research, skill-web-research) |
| Missed prompt location | High | Low | Stage 3 delegation is clearly identified in research findings |
| Testing shows linking still broken | Medium | Low | Verify end-to-end by triggering actual research task |

## Implementation Phases

### Phase 1: Fix Delegation Prompt and Validate [COMPLETED]

**Goal**: Add `metadata_file_path` parameter to skill-researcher SKILL.md Stage 3 delegation prompt and verify the fix works

**Tasks**:
- [x] Read skill-researcher/SKILL.md lines 75-95 to locate Stage 3 delegation prompt
- [x] Copy existing delegation prompt as backup comment
- [x] Add `metadata_file_path: "specs/OC_{N}_{project_name}/.return-meta.json"` to the JSON delegation data
- [x] Ensure the format matches working patterns from skill-nix-research or skill-web-research
- [x] Validate JSON structure is syntactically correct
- [x] Update status from [NOT STARTED] to [IN PROGRESS]

**Testing & Validation**:
- [x] Validated JSON structure is syntactically correct
- [x] Verified format matches general-research-agent expectations (lines 124-140)
- [ ] End-to-end test: Create test task and trigger research
- [ ] Verify `.return-meta.json` is created at expected path
- [ ] Verify TODO.md is updated with research report link
- [x] Mark task status as [COMPLETED] in plan

**Timing**: 1-2 hours

## Artifacts & Outputs

- Modified file: `.opencode/skills/skill-researcher/SKILL.md`
- Updated Stage 3 delegation prompt with `metadata_file_path` parameter
- Validated working TODO.md linking through end-to-end test

## Rollback/Contingency

**Rollback Plan**:
1. The original prompt structure is preserved in a comment before modification
2. If validation fails, restore original prompt from comment
3. Re-evaluate path format if general-research-agent still fails to write metadata
4. Check general-research-agent documentation for any parameter format changes

**Contingency**:
- If single parameter fix doesn't resolve issue, investigate if additional parameters are needed
- Compare full delegation payload between working and broken skills
- Review general-research-agent.md for any recent changes to expected parameters
