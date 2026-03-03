# Preflight/Postflight Workflow Standards

**Version**: 2.0  
**Updated**: 2026-01-07  
**Purpose**: Command-level status update patterns  
**Audience**: Command developers, workflow designers

---

## Overview

**ARCHITECTURAL CHANGE (2026-01-07)**: Preflight and postflight are now **command responsibilities**, not subagent responsibilities.

**Before (v1.0)**: Commands → Subagents (with preflight/postflight in subagent specs)  
**After (v2.0)**: Commands (with preflight/postflight) → Subagents (core work only)

**Root Cause**: Commands delegated to subagents and relied on subagents to update status. This created a fragile dependency where LLMs could skip or reorder preflight/postflight steps.

**Solution**: Move status update responsibility to command files where execution can be enforced through validation gates.

### Core Principles

1. **Commands Own Status Updates**: Commands delegate to status-sync-manager, not subagents
2. **Preflight Timing**: Status updates MUST occur BEFORE work begins
3. **Postflight Timing**: Status and artifact updates MUST occur BEFORE returning to caller
4. **Validation Gates**: Delegate → Wait → Verify → Proceed
5. **Defense in Depth**: Verify status updates on disk after delegation

---

## Command-Level Preflight Pattern

### Purpose

Commands update task status to "in_progress" BEFORE delegating to subagents, ensuring immediate status visibility.

### Timing Requirement

**CRITICAL**: Preflight MUST complete BEFORE delegation to subagent.

```
✅ CORRECT:
  Preflight (update status to "in_progress")
    ↓
  Delegate (to subagent for core work)
    ↓
  Postflight (update status to "completed")

❌ WRONG:
  Delegate (to subagent)
    ↓
  Preflight (in subagent spec) ← UNRELIABLE
```

### Pattern

```xml
<stage id="1.5" name="Preflight">
  <action>Update status to [IN_PROGRESS] before delegating to subagent</action>
  <process>
    1. Generate session_id for tracking:
       - session_id="sess_$(date +%s)_$(head -c 6 /dev/urandom | base64 | tr -dc 'a-z0-9')"
       - Store for later use
    
    2. Delegate to status-sync-manager:
       task(
         subagent_type="status-sync-manager",
         prompt="{
           \"operation\": \"update_status\",
           \"task_number\": ${task_number},
           \"new_status\": \"{in_progress_status}\",
           \"timestamp\": \"$(date -I)\",
           \"session_id\": \"${session_id}\",
           \"delegation_depth\": 1,
           \"delegation_path\": [\"orchestrator\", \"{command}\", \"status-sync-manager\"]
         }",
         description="Update task ${task_number} status to {IN_PROGRESS}"
       )
    
    3. Validate status-sync-manager return:
       a. Parse return as JSON
       b. Extract status field: sync_status=$(echo "$sync_return" | jq -r '.status')
       c. If sync_status != "completed":
          - Log error: "Preflight failed: status-sync-manager returned ${sync_status}"
          - Extract error message: error_msg=$(echo "$sync_return" | jq -r '.errors[0].message')
          - Return error to user: "Failed to update status: ${error_msg}"
          - ABORT - do NOT proceed to delegation
       d. Verify files_updated includes specs/TODO.md and specs/state.json
    
    4. Verify status was actually updated (defense in depth):
       actual_status=$(jq -r --arg num "$task_number" \
         '.active_projects[] | select(.project_number == ($num | tonumber)) | .status' \
         specs/state.json)
       
       If actual_status != "{in_progress_status}":
         - Log error: "Preflight verification failed"
         - Log: "Expected: {in_progress_status}, Actual: ${actual_status}"
         - Return error to user: "Status update verification failed"
         - ABORT - do NOT proceed to delegation
    
    5. Log preflight success and proceed to delegation
  </process>
  <validation>
    - status-sync-manager returned "completed" status
    - specs/TODO.md and specs/state.json were updated
    - specs/state.json status field verified on disk
  </validation>
  <checkpoint>Status verified before delegation</checkpoint>
</stage>
```

### Status Values

| Command | Preflight Status |
|---------|-----------------|
| /research | "researching" |
| /plan | "planning" |
| /revise | "revising" |
| /implement | "implementing" |

### Example (research.md)

```xml
<stage id="1.5" name="Preflight">
  <action>Update status to [RESEARCHING] before delegating to researcher</action>
  <process>
    1. Generate session_id
    2. Delegate to status-sync-manager with new_status: "researching"
    3. Validate return
    4. Verify status in specs/state.json
    5. Proceed to Stage 2 (Delegate to researcher)
  </process>
</stage>
```

---

## Command-Level Postflight Pattern

### Purpose

Commands update task status to "completed" and link artifacts AFTER subagent completes, ensuring artifacts are always linked.

### Timing Requirement

**CRITICAL**: Postflight MUST complete BEFORE returning to caller.

```
✅ CORRECT:
  Delegate (to subagent for core work)
    ↓
  Postflight (update status, link artifacts)
    ↓
  Return to caller

❌ WRONG:
  Delegate (to subagent)
    ↓
  Return to caller ← TOO EARLY
    ↓
  Postflight (in subagent spec) ← NEVER EXECUTED
```

### Pattern

```xml
<stage id="3.5" name="Postflight">
  <action>Update status to [COMPLETED] and link artifacts after subagent completes</action>
  <process>
    1. Extract artifacts from subagent return:
       artifacts_json=$(echo "$subagent_return" | jq -c '.artifacts')
       artifact_count=$(echo "$artifacts_json" | jq 'length')
    
    2. Validate artifacts exist on disk (CRITICAL):
       for artifact_path in $(echo "$artifacts_json" | jq -r '.[].path'); do
         if [ ! -f "$artifact_path" ]; then
           echo "ERROR: Artifact not found: $artifact_path"
           exit 1
         fi
         if [ ! -s "$artifact_path" ]; then
           echo "ERROR: Artifact is empty: $artifact_path"
           exit 1
         fi
       done
    
    3. Delegate to status-sync-manager:
       task(
         subagent_type="status-sync-manager",
         prompt="{
           \"operation\": \"update_status\",
           \"task_number\": ${task_number},
           \"new_status\": \"{completed_status}\",
           \"timestamp\": \"$(date -I)\",
           \"session_id\": \"${session_id}\",
           \"delegation_depth\": 1,
           \"delegation_path\": [\"orchestrator\", \"{command}\", \"status-sync-manager\"],
           \"validated_artifacts\": ${artifacts_json}
         }",
         description="Update task ${task_number} status to {COMPLETED} and link artifacts"
       )
    
    4. Validate status-sync-manager return:
       a. Parse return as JSON
       b. Extract status field: sync_status=$(echo "$sync_return" | jq -r '.status')
       c. If sync_status != "completed":
          - Log warning: "Postflight failed: status-sync-manager returned ${sync_status}"
          - Log: "Work completed but status update failed"
          - Continue (work is done, just status update failed)
       d. Verify files_updated includes specs/TODO.md and specs/state.json
    
    5. Verify status and artifact links (defense in depth):
       actual_status=$(jq -r --arg num "$task_number" \
         '.active_projects[] | select(.project_number == ($num | tonumber)) | .status' \
         specs/state.json)
       
       If actual_status != "{completed_status}":
         - Log warning: "Postflight verification failed - status not updated"
       
       for artifact_path in $(echo "$artifacts_json" | jq -r '.[].path'); do
         if ! grep -q "$artifact_path" specs/TODO.md; then
           echo "WARNING: Artifact not linked in specs/TODO.md: $artifact_path"
         fi
       done
    
    6. Delegate to git-workflow-manager for commit:
       task(
         subagent_type="git-workflow-manager",
         prompt="{
           \"scope_files\": [${artifact_paths}, \"specs/TODO.md\", \"specs/state.json\"],
           \"message_template\": \"task ${task_number}: {work_description}\",
           \"task_context\": {\"task_number\": ${task_number}},
           \"session_id\": \"${session_id}\"
         }"
       )
    
    7. Validate git-workflow-manager return (non-critical)
    
    8. Proceed to return
  </process>
  <validation>
    - Artifacts validated on disk before status update
    - status-sync-manager returned "completed" status
    - specs/state.json status field verified on disk
    - Artifact links verified in specs/TODO.md
    - Git commit created (or warning logged)
  </validation>
  <checkpoint>Status and artifacts verified before return</checkpoint>
</stage>
```

### Status Values

| Command | Postflight Status |
|---------|------------------|
| /research | "researched" |
| /plan | "planned" |
| /revise | "revised" |
| /implement | "completed" |

### Example (research.md)

```xml
<stage id="3.5" name="Postflight">
  <action>Update status to [RESEARCHED] and link artifacts after researcher completes</action>
  <process>
    1. Extract artifacts from researcher return
    2. Validate artifacts exist on disk
    3. Delegate to status-sync-manager with new_status: "researched" and validated_artifacts
    4. Validate return
    5. Verify status and artifact links in specs/state.json and specs/TODO.md
    6. Delegate to git-workflow-manager for commit
    7. Proceed to Stage 4 (RelayResult)
  </process>
</stage>
```

---

## Subagent Responsibilities

### What Subagents DO

- ✅ Execute core work (research, planning, implementation)
- ✅ Create artifacts
- ✅ Validate artifacts before returning
- ✅ Return standardized result with artifacts array

### What Subagents DON'T DO

- ❌ Update status (command responsibility)
- ❌ Link artifacts to specs/TODO.md/specs/state.json (command responsibility)
- ❌ Create git commits (command responsibility)
- ❌ Delegate to status-sync-manager (command responsibility)

### Subagent Return Format

```json
{
  "status": "completed",
  "summary": "Work completed successfully",
  "artifacts": [
    {
      "type": "research_report",
      "path": "specs/123_topic/reports/research-001.md",
      "summary": "Research findings",
      "validated": true
    }
  ],
  "metadata": {
    "session_id": "sess_20260107_abc123",
    "duration_seconds": 120,
    "agent_type": "researcher"
  }
}
```

**Note**: Subagents return artifacts array, but do NOT link them. Commands handle linking via status-sync-manager.

---

## Validation Gates

### Purpose

Validation gates ensure work doesn't proceed without status updates and artifacts are verified before linking.

### Pattern

```
Delegate → Wait → Verify → Proceed
```

**NOT**:
```
Delegate → Proceed (without verification) ← WRONG
```

### Implementation

```xml
<validation_gate>
  <step_1>Delegate to subagent</step_1>
  <step_2>Wait for return</step_2>
  <step_3>Verify return (status, artifacts, metadata)</step_3>
  <step_4>Verify on disk (status in specs/state.json, artifacts exist)</step_4>
  <step_5>Proceed to next stage (only if verification passed)</step_5>
</validation_gate>
```

### Example

```xml
<preflight_gate>
  <delegate>Delegate to status-sync-manager</delegate>
  <wait>Wait for return</wait>
  <verify_return>Check status == "completed"</verify_return>
  <verify_disk>Check status in specs/state.json</verify_disk>
  <proceed>Proceed to delegation (only if verified)</proceed>
</preflight_gate>

<postflight_gate>
  <validate_artifacts>Check artifacts exist on disk</validate_artifacts>
  <delegate>Delegate to status-sync-manager</delegate>
  <wait>Wait for return</wait>
  <verify_return>Check status == "completed"</verify_return>
  <verify_disk>Check status and artifact links</verify_disk>
  <proceed>Proceed to return (only if verified)</proceed>
</postflight_gate>
```

---

## Migration Guide

### For Existing Subagents

**Step 1**: Remove preflight (step_0_preflight)

```xml
<!-- DELETE THIS SECTION -->
<step_0_preflight>
  <action>Update status to [IN_PROGRESS]</action>
  ...
</step_0_preflight>
```

**Step 2**: Remove postflight (step_N_postflight)

```xml
<!-- DELETE THIS SECTION -->
<step_4_postflight>
  <action>Update status to [COMPLETED] and link artifacts</action>
  ...
</step_4_postflight>
```

**Step 3**: Update process flow

```xml
<process_flow>
  <!-- REMOVE: step_0_preflight -->
  <step_1_core_work>
  <step_2_artifact_creation>
  <step_3_validation>
  <step_4_return>  <!-- RENAMED from step_5_return -->
  
  <note>
    ARCHITECTURAL CHANGE (2026-01-07):
    Preflight and postflight are now handled by command files.
    This subagent focuses on core work only.
  </note>
</process_flow>
```

**Step 4**: Update constraints

```xml
<constraints>
  <!-- REMOVE THESE -->
  <!-- <must>Invoke status-sync-manager for status updates</must> -->
  <!-- <must>Create git commits</must> -->
  
  <!-- ADD THESE -->
  <must>Return artifacts array with validated paths</must>
  <must_not>Update status (command responsibility)</must_not>
  <must_not>Create git commits (command responsibility)</must_not>
</constraints>
```

### For Existing Commands

**Step 1**: Add preflight stage (after Stage 1)

```xml
<stage id="1.5" name="Preflight">
  <action>Update status to [IN_PROGRESS]</action>
  <process>
    1. Generate session_id
    2. Delegate to status-sync-manager
    3. Validate return
    4. Verify status on disk
    5. Proceed to delegation
  </process>
</stage>
```

**Step 2**: Add postflight stage (after Stage 3)

```xml
<stage id="3.5" name="Postflight">
  <action>Update status to [COMPLETED] and link artifacts</action>
  <process>
    1. Extract artifacts from subagent return
    2. Validate artifacts on disk
    3. Delegate to status-sync-manager with validated_artifacts
    4. Validate return
    5. Verify status and artifact links on disk
    6. Delegate to git-workflow-manager
    7. Proceed to return
  </process>
</stage>
```

**Step 3**: Update delegation to pass session_id

```xml
<stage id="2" name="Delegate">
  <process>
    task(
      subagent_type="${target_agent}",
      prompt="...",
      session_id="${session_id}"  <!-- ADD THIS -->
    )
  </process>
</stage>
```

---

## Common Mistakes

### ❌ WRONG: Direct jq Commands in Commands

```bash
# DO NOT DO THIS in command files
jq --arg num "$task_number" \
  '.active_projects[] |= if .project_number == ($num | tonumber) then .status = "researched" else . end' \
  specs/state.json > /tmp/state.json.tmp
```

**Problem**: Bypasses status-sync-manager, doesn't link artifacts, not atomic.

### ❌ WRONG: Preflight/Postflight in Subagents

```xml
<!-- DO NOT DO THIS in subagent files -->
<step_0_preflight>
  <action>Update status to [RESEARCHING]</action>
  ...
</step_0_preflight>
```

**Problem**: LLMs can skip or reorder steps in subagent specs.

### ❌ WRONG: Skipping Validation Gates

```xml
<!-- DO NOT DO THIS -->
<stage id="1.5" name="Preflight">
  <process>
    Delegate to status-sync-manager
    <!-- Missing: Validate return -->
    <!-- Missing: Verify on disk -->
    Proceed to delegation  ← WRONG
  </process>
</stage>
```

**Problem**: No guarantee status was actually updated.

### ✅ CORRECT: Command-Level Preflight/Postflight

```xml
<stage id="1.5" name="Preflight">
  <process>
    1. Delegate to status-sync-manager
    2. Validate return
    3. Verify on disk
    4. Proceed to delegation (only if verified)
  </process>
</stage>

<stage id="3.5" name="Postflight">
  <process>
    1. Validate artifacts on disk
    2. Delegate to status-sync-manager with validated_artifacts
    3. Validate return
    4. Verify status and artifact links on disk
    5. Delegate to git-workflow-manager
    6. Proceed to return (only if verified)
  </process>
</stage>
```

**Result**: Guaranteed status updates and artifact linking.

---

## References

### Documentation

- **Implementation Plan**: `specs/IMPROVED_STATUS_UPDATE_FIX_PLAN.md`
- **Root Cause Investigation**: `specs/333_*/reports/root-cause-investigation-20260106.md`
- **status-sync-manager**: `.opencode/agent/subagents/status-sync-manager.md`
- **git-workflow-manager**: `.opencode/agent/subagents/git-workflow-manager.md`

### Working Examples

- **research.md**: Command with preflight/postflight (after Phase 1-2)
- **plan.md**: Command with preflight/postflight (after Phase 4)
- **researcher.md**: Simplified subagent (after Phase 3)
- **planner.md**: Simplified subagent (after Phase 4)

---

## Summary

**Key Change**: Commands now own status updates, not subagents.

**Benefits**:
- ✅ Guaranteed preflight (status updates immediately)
- ✅ Guaranteed postflight (artifacts always linked)
- ✅ No more manual fixes (like Task 326)
- ✅ Simpler subagents (focus on core work)
- ✅ Centralized status update logic
- ✅ Validation gates enforce workflow

**Pattern**:
```
Command Preflight → Subagent Work → Command Postflight → Return
```

**Remember**: ALWAYS delegate to status-sync-manager from commands, NEVER from subagents.

---

**Version History**:
- v1.0 (2026-01-05): Initial version with subagent-level preflight/postflight
- v2.0 (2026-01-07): Moved to command-level preflight/postflight (architectural change)
