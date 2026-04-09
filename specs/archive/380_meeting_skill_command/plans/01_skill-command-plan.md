# Implementation Plan: Create skill-meeting and meeting.md command

- **Task**: 380 - Create skill-meeting and meeting.md command
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: meeting-agent.md (exists)
- **Research Inputs**: specs/380_meeting_skill_command/reports/01_skill-command-research.md
- **Artifacts**: plans/01_skill-command-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create two markdown files in the founder extension that wire up the meeting workflow: a thin skill wrapper (SKILL.md) that routes to meeting-agent, and a command definition (meeting.md) that handles input detection, task creation, and delegation. Both files follow established patterns from skill-legal and legal.md but are simpler due to the autonomous nature of meeting-agent (no forcing questions, no mode selection).

### Research Integration

Research report (01_skill-command-research.md) identified three key simplifications over the /legal pattern: (1) no STAGE 0 forcing questions since the file IS the input, (2) three input types instead of four (file path, task number, --update), and (3) direct delegation after task creation instead of stopping. The 11-stage skill execution flow is preserved with minimal field changes.

### Roadmap Alignment

No ROAD_MAP.md found.

## Goals & Non-Goals

**Goals**:
- Create SKILL.md that follows the 11-stage skill-legal pattern with meeting-specific fields
- Create meeting.md command with input detection, task creation, and direct delegation
- Support three input types: file path, task number, --update flag
- Ensure delegation context passes notes_path and update_only to meeting-agent

**Non-Goals**:
- Modifying meeting-agent.md (already exists and is complete)
- Adding extension manifest entries (separate concern)
- Implementing CSV tracker logic (handled by meeting-agent)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Pattern drift from skill-legal | M | L | Research report provides exact field mappings |
| Missing notes_path on task resume | M | M | Store notes_path in state.json task entry at creation |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Create SKILL.md [COMPLETED]

**Goal**: Create the thin skill wrapper that routes meeting requests to meeting-agent

**Tasks**:
- [ ] Create `.claude/extensions/founder/skills/skill-meeting/SKILL.md` following skill-legal pattern
- [ ] Set frontmatter: name=skill-meeting, description, allowed-tools (Task, Bash, Edit, Read, Write)
- [ ] Write trigger conditions (direct: /meeting command, /research on meeting task; implicit: meeting-related patterns)
- [ ] Implement 11-stage execution flow with meeting-specific changes:
  - Stage 1: Validate task_number, extract notes_path and update_only (no contract_type/mode/forcing_data)
  - Stage 4: Delegation context with notes_path, update_only instead of forcing_data
  - Stage 5: Invoke meeting-agent via Task tool
  - Stage 11: Return summary with investor_name, meeting_date, action_items, CSV status
- [ ] Include context pointers section (subagent-return.md reference)
- [ ] Include error handling section

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/founder/skills/skill-meeting/SKILL.md` - New file, ~300 lines

**Verification**:
- File exists and follows 11-stage pattern
- Frontmatter matches skill-legal format
- Delegation context includes notes_path and update_only
- No forcing_data references

---

### Phase 2: Create meeting.md command [COMPLETED]

**Goal**: Create the /meeting command definition with input detection, task creation, and direct delegation

**Tasks**:
- [ ] Create `.claude/extensions/founder/commands/meeting.md` following legal.md structure
- [ ] Set frontmatter: description, allowed-tools (Skill, Bash, Read, Edit, AskUserQuestion), argument-hint showing three input types
- [ ] Write overview section explaining autonomous file-processing behavior
- [ ] Define syntax table with three input types (file path, task number, --update)
- [ ] Skip STAGE 0 entirely (no forcing questions needed)
- [ ] Implement CHECKPOINT 1 (GATE IN):
  - Session ID generation
  - Input type detection (--update flag, numeric task number, file path)
  - File path handling: verify exists, extract investor name from filename, create task
  - Task number handling: load existing, validate founder language
  - --update handling: verify file exists, verify YAML frontmatter, delegate with update_only=true
  - Task creation with task_type="meeting" and notes_path stored in state.json
  - TODO.md entry creation
  - Git commit for task creation
  - Direct delegation (do NOT stop after task creation)
- [ ] Implement STAGE 2 (DELEGATE): invoke skill-meeting with task_number, notes_path, update_only, session_id
- [ ] Implement CHECKPOINT 2 (GATE OUT): verify status, display meeting results

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/founder/commands/meeting.md` - New file, ~350 lines

**Verification**:
- File exists with correct frontmatter
- No STAGE 0 forcing questions present
- Three input types handled (file path, task number, --update)
- Command proceeds directly to delegation after task creation
- notes_path stored in state.json task entry

## Testing & Validation

- [ ] SKILL.md follows 11-stage pattern matching skill-legal structure
- [ ] meeting.md handles all three input types correctly
- [ ] No forcing questions in either file
- [ ] Delegation context includes notes_path and update_only fields
- [ ] Command proceeds directly to delegation (does not stop after task creation)
- [ ] Task creation stores notes_path in state.json for resume support

## Artifacts & Outputs

- `.claude/extensions/founder/skills/skill-meeting/SKILL.md` - Skill wrapper (~300 lines)
- `.claude/extensions/founder/commands/meeting.md` - Command definition (~350 lines)

## Rollback/Contingency

Delete both files. No existing files are modified, so rollback is trivial removal of the two new files.
