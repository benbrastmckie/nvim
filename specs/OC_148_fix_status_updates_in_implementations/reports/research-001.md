# Research Report: Fix Status Updates During Implementation Phases

- **Task**: OC_148 - fix_status_updates_in_implementations
- **Started**: 2026-03-05T20:00:00Z
- **Completed**: 2026-03-05T21:30:00Z
- **Effort**: 2 hours
- **Priority**: High
- **Dependencies**: None
- **Sources/Inputs**:
  - `.opencode/skills/skill-implementer/SKILL.md` - Skill specification with preflight/postflight stages
  - `.opencode/agent/subagents/general-implementation-agent.md` - Agent execution flow
  - `.opencode/skills/skill-researcher/SKILL.md` - Reference for comparison (has detailed postflight)
  - `.opencode/skills/skill-planner/SKILL.md` - Reference for comparison (has detailed postflight)
  - `.opencode/commands/implement.md` - Command specification
  - `.opencode/context/core/standards/status-markers.md` - Status transition definitions
  - `specs/OC_137_investigate_and_fix_planner_agent_format_compliance_issue/plans/implementation-002.md` - Example plan with phase statuses
  - `specs/TODO.md` - Current task status tracking
  - `specs/state.json` - Current state tracking
- **Artifacts**: specs/OC_148_fix_status_updates_in_implementations/reports/research-001.md (this report)
- **Standards**: report-format.md, status-markers.md, return-metadata-file.md

## Executive Summary

- **Gap 1**: skill-implementer SKILL.md has preflight stage that mentions updating status to implementing, but lacks explicit jq/bash commands to actually perform the update (unlike skill-researcher and skill-planner which have detailed postflight instructions)
- **Gap 2**: general-implementation-agent.md documents marking phases [IN PROGRESS] at Stage 4A, but this is agent-side logic that may not be synchronized with skill-level status updates
- **Gap 3**: skill-implementer postflight mentions updating state but lacks detailed jq patterns for status transitions (implementing -> completed/partial)
- **Gap 4**: No explicit TODO.md status update instructions in skill-implementer postflight (skill-researcher has Stage 6a for this)
- **Gap 5**: implement.md command (lines 65-68) describes updating status to IMPLEMENTING, but this may duplicate or conflict with skill-implementer preflight

## Context & Scope

This research investigates status update gaps observed during OC_147 implementation where:
1. Phase statuses were not marked [IN PROGRESS] before starting work
2. Task status was not updated to [IMPLEMENTING] before starting
3. Task status was not updated to [COMPLETED] after finishing all phases

The scope covers the entire implementation workflow chain:
- Command level: implement.md
- Skill level: skill-implementer/SKILL.md
- Agent level: general-implementation-agent.md

## Findings

### Finding 1: skill-implementer Preflight Lacks Detailed Status Update Commands

**Location**: `.opencode/skills/skill-implementer/SKILL.md`, lines 68-77

**Current State**:
```markdown
2. **Preflight**:
   - Validate task and status using {return_metadata} and {postflight_control}.
   - **Display Task Header**: Print the following header...
   - Update status to implementing.
   - Create postflight marker file.
```

**Gap**: The phrase "Update status to implementing" appears as a high-level instruction but lacks the actual jq/bash implementation commands found in skill-researcher (lines 105-114) and skill-planner (lines 108-117).

**Comparison with skill-researcher** (lines 105-114):
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researched" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    researched: $ts
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

**Impact**: The skill-implementer preflight may not actually update the task status to "implementing" in state.json, leaving the task in its previous state (e.g., "planned") during implementation.

### Finding 2: skill-implementer Postflight Lacks Detailed Status Transition Logic

**Location**: `.opencode/skills/skill-implementer/SKILL.md`, lines 80-88

**Current State**:
```markdown
4. **Postflight**: Read metadata file and update state + TODO using {file_metadata} and {jq_workarounds}.
   - Link summary artifact and commit.
   - Clean up marker and metadata files.
5. **PostflightVerification**: Verify phase status consistency...
```

**Gap**: Unlike skill-researcher (lines 94-176) and skill-planner (lines 94-179), skill-implementer lacks detailed postflight stage breakdown with specific jq commands for:
- Reading metadata file
- Updating state.json status to "completed" or "partial"
- Updating TODO.md status marker
- Linking artifacts in state.json
- Linking artifacts in TODO.md

**Impact**: The postflight status updates may not be consistently applied, leading to tasks remaining in "implementing" status even after completion.

### Finding 3: general-implementation-agent Has Phase Status Logic But No Task Status Updates

**Location**: `.opencode/agent/subagents/general-implementation-agent.md`

**Current State**:
- Stage 4A (lines 145-146): "Edit plan file: Change phase status to [IN PROGRESS]"
- Stage 4D (lines 173-174): "Edit plan file: Change phase status to [COMPLETED]"
- Stage 7 (lines 259-301): Write metadata file with status

**Gap**: The agent handles phase-level status updates in the plan file but does NOT update the overall task status in state.json or TODO.md. According to the status-markers.md standard, the agent should not directly update state files - this is the skill's responsibility via postflight.

**Impact**: Even if phases are correctly marked, the overall task status transition from "implementing" to "completed" depends entirely on skill-implementer's postflight, which lacks detailed instructions.

### Finding 4: implement.md Command Has Duplicate Status Update Description

**Location**: `.opencode/commands/implement.md`, lines 65-68

**Current State**:
```markdown
### 5. Update status to IMPLEMENTING

Edit `specs/state.json`: set `status` to `"implementing"`, update `last_updated`.

Edit `specs/TODO.md`: change current status marker to `[IMPLEMENTING]` on the `### OC_N.` entry.
```

**Gap**: This describes status updates at the command level, but the actual implementation is delegated to skill-implementer. This creates potential confusion about where the update should happen:
- Option A: Command updates status before invoking skill
- Option B: Skill updates status in preflight
- Current: Both describe it, but neither has clear implementation

**Impact**: Risk of double-updates or missed updates depending on which layer actually performs the work.

### Finding 5: Missing TODO.md Status Update in skill-implementer Postflight

**Location**: `.opencode/skills/skill-implementer/SKILL.md`

**Comparison**:
- skill-researcher has Stage 6a (lines 117-123): "Update TODO.md Status"
- skill-planner has Stage 6a (lines 120-126): "Update TODO.md Status"
- skill-implementer has NO equivalent stage

**Gap**: skill-implementer lacks explicit instructions to update TODO.md status markers during both preflight (to [IMPLEMENTING]) and postflight (to [COMPLETED] or [PARTIAL]).

**Impact**: TODO.md may show outdated status even when state.json is correctly updated.

### Finding 6: Phase Status Verification Exists But May Not Correct Initial Status

**Location**: `.opencode/skills/skill-implementer/SKILL.md`, lines 89-103

**Current State**:
```markdown
## Phase Verification Details

**Purpose**: Ensure plan.md phase status markers stay synchronized...

**Recovery Logic**:
- If metadata.phases_completed > plan [COMPLETED] phases: Update plan to mark additional phases as [COMPLETED]
- If metadata.phases_completed < plan [COMPLETED] phases: Log warning but don't downgrade
```

**Gap**: The verification logic focuses on correcting completed phases but does NOT address phases that should be [IN PROGRESS]. If the agent fails to mark a phase as [IN PROGRESS] before starting, this verification won't catch it.

**Impact**: Phases may show [NOT STARTED] while work is actively happening.

## Decisions

### Decision 1: Single Source of Truth for Status Updates
**Decision**: Status updates should happen in skill-implementer, NOT in implement.md command.

**Rationale**:
- Command should focus on validation and delegation
- Skill has access to postflight patterns and metadata
- Consistent with skill-researcher and skill-planner architecture
- Avoids duplication and race conditions

### Decision 2: skill-implementer Needs Detailed Postflight Stages
**Decision**: Add explicit Stage 5-10 to skill-implementer postflight, matching skill-researcher pattern.

**Rationale**:
- Ensures consistent status update behavior across all workflow skills
- Provides clear implementation instructions
- Enables proper error handling at each stage

### Decision 3: Phase [IN PROGRESS] Updates Belong in Agent
**Decision**: Keep phase-level [IN PROGRESS] marking in general-implementation-agent (Stage 4A).

**Rationale**:
- Agent has direct knowledge of which phase is executing
- Plan file is the resume point source of truth
- Skill-level verification can catch missed updates

### Decision 4: Add Preemptive Phase Status Check to skill-implementer
**Decision**: Add a preflight stage to skill-implementer that verifies the current phase is marked [IN PROGRESS] before delegation.

**Rationale**:
- Catches cases where agent fails to update phase status
- Provides early warning for status synchronization issues
- Can auto-correct or warn about status mismatches

## Recommendations

### Priority 1: Add Detailed Preflight to skill-implementer

**File**: `.opencode/skills/skill-implementer/SKILL.md`
**Lines**: 68-77 (Preflight section)

**Add explicit jq commands**:
```bash
# Update state.json to implementing
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "implementing" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    implementing: $ts
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# Update TODO.md to [IMPLEMENTING]
# (Use Edit tool to change status marker)
```

### Priority 2: Add Detailed Postflight Stages to skill-implementer

**File**: `.opencode/skills/skill-implementer/SKILL.md`
**Lines**: 80-88 (Postflight section)

**Expand to include** (matching skill-researcher pattern):
- Stage 5: Parse Subagent Return (read metadata file)
- Stage 6: Update Task Status in state.json (implementing -> completed/partial)
- Stage 6a: Update TODO.md Status (change marker to [COMPLETED] or [PARTIAL])
- Stage 7: Link Artifacts in state.json
- Stage 7a: Update TODO.md Artifacts
- Stage 8: Git Commit
- Stage 9: Cleanup
- Stage 10: Return Brief Summary

### Priority 3: Remove Duplicate Status Update from implement.md

**File**: `.opencode/commands/implement.md`
**Lines**: 65-68

**Change from**:
```markdown
### 5. Update status to IMPLEMENTING

Edit `specs/state.json`: set `status` to `"implementing"`, update `last_updated`.

Edit `specs/TODO.md`: change current status marker to `[IMPLEMENTING]` on the `### OC_N.` entry.
```

**To**:
```markdown
### 5. Invoke skill-implementer

The skill-implementer will update status to [IMPLEMENTING] during its preflight stage.
```

### Priority 4: Add Phase Status Pre-check to skill-implementer Preflight

**File**: `.opencode/skills/skill-implementer/SKILL.md`
**Add after line 77**:

```markdown
### 2a. Verify Phase Status

Before delegation, check that the current phase in the plan file is marked [IN PROGRESS]:
- Read plan file
- Find first non-[COMPLETED] phase
- Verify it shows [IN PROGRESS]
- If [NOT STARTED], update it to [IN PROGRESS] before delegation
- If mismatch detected, log warning
```

### Priority 5: Enhance Phase Verification in Postflight

**File**: `.opencode/skills/skill-implementer/SKILL.md`
**Lines**: 89-103

**Expand Recovery Logic** to include:
```markdown
**Additional Recovery Logic**:
- If current phase shows [NOT STARTED] but metadata shows progress: Update to [IN PROGRESS]
- If current phase shows [NOT STARTED] and metadata shows completion: Update to [COMPLETED]
- Log all corrections made for audit trail
```

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Double status updates if both command and skill update | Medium | Medium | Remove status update from implement.md (Priority 3) |
| Status update failures break workflow | High | Low | Add error handling in each postflight stage |
| Phase status and task status get out of sync | Medium | Medium | Add verification stage (Priority 4, 5) |
| jq command failures corrupt state.json | High | Low | Use temp file pattern (already in skill-researcher) |
| Agent doesn't mark phases [IN PROGRESS] | Medium | Medium | Add preflight verification (Priority 4) |

## Appendix: File References

### Key Files and Line Numbers

| File | Relevant Lines | Purpose |
|------|----------------|---------|
| `.opencode/skills/skill-implementer/SKILL.md` | 68-77 | Preflight (needs detail) |
| `.opencode/skills/skill-implementer/SKILL.md` | 80-88 | Postflight (needs expansion) |
| `.opencode/skills/skill-implementer/SKILL.md` | 89-103 | Phase verification (needs enhancement) |
| `.opencode/skills/skill-researcher/SKILL.md` | 94-176 | Reference postflight pattern |
| `.opencode/skills/skill-planner/SKILL.md` | 94-179 | Reference postflight pattern |
| `.opencode/agent/subagents/general-implementation-agent.md` | 145-146 | Phase [IN PROGRESS] marking |
| `.opencode/agent/subagents/general-implementation-agent.md` | 173-174 | Phase [COMPLETED] marking |
| `.opencode/commands/implement.md` | 65-68 | Duplicate status update description |
| `.opencode/context/core/standards/status-markers.md` | 109-120 | IMPLEMENTING status definition |

### Status Transition Flow (Expected)

```
[PLANNED] 
    |
    | (skill-implementer preflight)
    v
[IMPLEMENTING] -----> Phase 1 [IN PROGRESS]
    |                      |
    |                      | (agent Stage 4A)
    |                      v
    |              Phase 1 [COMPLETED]
    |                      |
    |              Phase 2 [IN PROGRESS]
    |                      |
    |                      ...
    v
[COMPLETED] (skill-implementer postflight)
```

### Status Transition Flow (Current - With Gaps)

```
[PLANNED] 
    |
    | (skill-implementer preflight - NO explicit update)
    v
[IMPLEMENTING?] -----> Phase 1 [NOT STARTED] (should be [IN PROGRESS])
    |                      |
    |                      | (agent Stage 4A - may work)
    |                      v
    |              Phase 1 [COMPLETED] (this works)
    |                      |
    |              Phase 2 [NOT STARTED] (should be [IN PROGRESS])
    |                      |
    |                      ...
    v
[IMPLEMENTING?] (should be [COMPLETED] - NO explicit update)
```

## Context Knowledge Candidates

### Candidate 1: Skill Postflight Pattern Standardization
**Type**: Pattern
**Domain**: workflow-skills
**Target Context**: `.opencode/context/core/patterns/skill-postflight.md` (new file)
**Content**: All workflow skills (researcher, planner, implementer) should follow the same postflight stage structure: Stage 5 (Parse), Stage 6 (Update state.json), Stage 6a (Update TODO.md), Stage 7 (Link artifacts), Stage 8 (Commit), Stage 9 (Cleanup), Stage 10 (Return).
**Source**: Comparison of skill-researcher, skill-planner, and skill-implementer
**Rationale**: Ensures consistent status synchronization across all workflow commands

### Candidate 2: Status Update Responsibility Separation
**Type**: Pattern
**Domain**: workflow-architecture
**Target Context**: `.opencode/context/core/patterns/status-update-responsibility.md` (new file)
**Content**: Commands validate and delegate; Skills perform preflight status updates and postflight status transitions; Agents execute work and update phase-level statuses in plan files. Never duplicate status updates across layers.
**Source**: Analysis of implement.md vs skill-implementer overlap
**Rationale**: Prevents double-updates and missed updates by establishing clear ownership
