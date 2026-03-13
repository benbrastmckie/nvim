# Early Metadata Pattern

**Created**: 2026-01-28
**Purpose**: Ensure metadata files exist even when agents are interrupted
**Audience**: Agent developers

---

## Overview

Agents currently write metadata files only as a final step (Stage 6-7). If interrupted before reaching that stage (e.g., MCP AbortError, timeout, Claude Code abort), no metadata is written, leaving tasks stuck in intermediate status.

This pattern ensures metadata files are created early and updated incrementally, preserving progress even on interruption.

---

## The Problem

**Current Flow** (problematic):
```
Stage 1-5: Execute work
Stage 6: Write metadata file  <-- INTERRUPTED HERE = NO METADATA
Stage 7: Return summary
```

**Failure modes**:
- MCP AbortError terminates agent before Stage 6
- Timeout kills agent mid-execution
- Claude Code's shared AbortController cascade (Issue #6594)
- Any unexpected termination before metadata write

**Impact**: Task stuck in "researching" or "implementing" status with no artifact or progress information.

---

## The Solution

**Proposed Flow**:
```
Stage 0: Create metadata file with status="in_progress"
Stage 1-5: Execute work (update metadata incrementally on milestones)
Stage 6: Update metadata file with final status
Stage 7: Return summary
```

---

## Stage 0: Initial Metadata Creation

**When**: Immediately upon agent start, BEFORE any substantive work.

**What to write**:

```json
{
  "status": "in_progress",
  "started_at": "{ISO8601 timestamp}",
  "artifacts": [],
  "partial_progress": {
    "stage": "initializing",
    "details": "Agent started, beginning work"
  },
  "metadata": {
    "session_id": "{from delegation context}",
    "agent_type": "{agent-type}",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research|implement", "{agent-name}"]
  }
}
```

**Key fields**:
- `status: "in_progress"` - Indicates work has started
- `started_at` - ISO8601 timestamp for duration calculation
- `partial_progress` - Tracks where work got to before any failure
- `metadata.session_id` - Links to overall session for traceability

---

## Incremental Progress Updates

Update the metadata file at significant milestones:

### For Research Agents

| Milestone | partial_progress.stage | partial_progress.details |
|-----------|------------------------|--------------------------|
| After Stage 2 | "strategy_determined" | "Determined search strategy: {type}" |
| After major search | "searches_completed" | "Completed {N} searches, found {M} results" |
| After synthesis | "synthesis_completed" | "Synthesized {N} findings" |
| After report written | "report_created" | "Report written to {path}" |

### For Implementation Agents

| Milestone | partial_progress.stage | partial_progress.details |
|-----------|------------------------|--------------------------|
| After plan loaded | "plan_loaded" | "Loaded {N}-phase plan, resuming from phase {P}" |
| After each phase | "phase_{N}_completed" | "Phase {N} completed: {phase_name}" |
| After verification | "verification_completed" | "Build/tests passed" |
| After summary written | "summary_created" | "Summary written to {path}" |

### Update Pattern

```json
{
  "status": "in_progress",
  "started_at": "{original timestamp}",
  "artifacts": [
    {
      "type": "report",
      "path": "specs/259_proof/reports/research-001.md",
      "summary": "Partial research report (in progress)"
    }
  ],
  "partial_progress": {
    "stage": "searches_completed",
    "details": "Completed 3 searches, found 5 theorems. Starting synthesis.",
    "phases_completed": 0,
    "phases_total": 3
  },
  "metadata": {
    "session_id": "{session_id}",
    "agent_type": "lean-research-agent",
    "delegation_depth": 1,
    "delegation_path": ["..."]
  }
}
```

---

## Final Metadata Update

When work completes successfully, update metadata with final status:

```json
{
  "status": "researched|implemented",
  "started_at": "{original timestamp}",
  "artifacts": [
    {
      "type": "report|implementation",
      "path": "...",
      "summary": "..."
    }
  ],
  "completion_data": {
    "completion_summary": "...",
    "roadmap_items": ["..."]
  },
  "metadata": {
    "session_id": "...",
    "agent_type": "...",
    "duration_seconds": 123,
    "delegation_depth": 1,
    "delegation_path": ["..."]
  },
  "next_steps": "..."
}
```

**Note**: Remove `partial_progress` field on successful completion.

---

## How Skills Handle Partial Metadata

When skill postflight reads metadata with `status: "in_progress"`:

1. **Interpret as interrupted**: Agent was terminated before completion
2. **Keep task status unchanged**: Do not transition to next status
3. **Log the interruption**: Record to errors.json with type="delegation_interrupted"
4. **Extract partial_progress**: Use to determine resume point
5. **Preserve artifacts**: If any artifacts were created, link them
6. **Display guidance**: Tell user to run command again to resume

### Skill Postflight Pattern

```markdown
### Handling Interrupted Agents

If metadata file contains `status: "in_progress"`:

1. Extract `partial_progress.stage` and `partial_progress.details`
2. Keep task status unchanged (still "researching" or "implementing")
3. Log error to errors.json:
   ```json
   {
     "type": "delegation_interrupted",
     "message": "Agent interrupted at stage: {stage}",
     "context": {
       "session_id": "...",
       "partial_progress": {...}
     },
     "recovery": {
       "suggested_action": "Run command again to resume",
       "auto_recoverable": true
     }
   }
   ```
4. Display to user:
   "Agent interrupted at {stage}. Run /research N or /implement N to resume."
```

---

## Agent Integration Template

Add this to agent execution flow after Stage 1 (Parse Delegation Context):

```markdown
### Stage 0: Initialize Early Metadata

**CRITICAL**: Create metadata file BEFORE any substantive work.

1. Ensure task directory exists:
   ```bash
   mkdir -p "specs/OC_{NNN}_{SLUG}"
   ```

2. Write initial metadata:
   ```json
   {
     "status": "in_progress",
     "started_at": "{ISO8601}",
     "artifacts": [],
     "partial_progress": {
       "stage": "initializing",
       "details": "Agent started, parsing delegation context"
     },
     "metadata": {
       "session_id": "{from delegation context}",
       "agent_type": "{agent-name}",
       "delegation_depth": 1,
       "delegation_path": ["..."]
     }
   }
   ```

3. **Why this matters**: If agent is interrupted at ANY point after this,
   the metadata file will exist and skill postflight can detect the interruption.
```

---

## Benefits

1. **No lost progress**: Metadata always exists after Stage 0
2. **Resume enabled**: partial_progress indicates where to continue
3. **Traceability**: session_id links interrupted work to original command
4. **Graceful degradation**: Skills can handle partial metadata appropriately
5. **User clarity**: Clear guidance on how to resume

---

## Related Documentation

- `.claude/context/core/formats/return-metadata-file.md` - Metadata file schema
- `.claude/context/core/patterns/checkpoint-execution.md` - Checkpoint pattern
- `.claude/rules/error-handling.md` - Error logging patterns
