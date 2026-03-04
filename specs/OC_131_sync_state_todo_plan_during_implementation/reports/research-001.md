# Research Report: Task #131

**Task**: OC_131 - Synchronize state.json, TODO.md, and plan files during /implement execution
**Date**: 2026-03-04
**Language**: meta
**Focus**: Implementation workflow status synchronization

## Summary

The OpenCode system already has infrastructure for status synchronization between state.json, TODO.md, and plan files, but there is a gap in enforcement. The `general-implementation-agent` includes a Phase Checkpoint Protocol that should update phase statuses ([IN PROGRESS], [COMPLETED], [PARTIAL]) in plan files, but this is not explicitly mandated in the `/implement` command specification. The solution requires strengthening the implement.md command specification to require phase status updates and ensuring the skill-implementer workflow enforces this synchronization throughout the implementation lifecycle.

## Findings

### 1. Existing Infrastructure is Comprehensive

The system already has sophisticated mechanisms for status synchronization:

**A. skill-status-sync (`.opencode/skills/skill-status-sync/SKILL.md`)**
- Direct execution skill for atomic status synchronization
- Handles updates across both specs/TODO.md and specs/state.json
- Uses jq patterns from `jq-escaping-workarounds.md`

**B. Checkpoint Patterns (`.opencode/context/core/checkpoints/`)**
- `checkpoint-gate-in.md`: Validates preconditions and updates status before delegation
- `checkpoint-gate-out.md`: Validates returns and updates status with artifacts
- Clear status transition rules documented

**C. Postflight Control (`.opencode/context/core/patterns/postflight-control.md`)**
- Marker file protocol at `specs/.postflight-pending`
- Ensures workflow continues through postflight operations
- Prevents premature termination

**D. File Metadata Exchange (`.opencode/context/core/patterns/file-metadata-exchange.md`)**
- Structured metadata passing between agents and skills
- Metadata written to `specs/{N}_{SLUG}/.return-meta.json`
- Enables postflight artifact linking

### 2. Plan File Status Markers Already Defined

Plan files include status markers in phase headers:
```markdown
### Phase 1: Foundation & Formats [COMPLETED]

**Status**: [COMPLETED]
**Estimated effort**: 1 hour
```

The standard plan format from `.opencode/context/core/formats/plan-format.md` includes:
- `[NOT STARTED]` - Phase not yet begun
- `[IN PROGRESS]` - Phase currently being executed
- `[COMPLETED]` - Phase finished successfully
- `[PARTIAL]` - Phase blocked or incomplete

### 3. General Implementation Agent Already Has Phase Protocol

The `general-implementation-agent.md` (Stage 4) includes:

**Phase Checkpoint Protocol**:
1. **Read plan file**, identify current phase
2. **Update phase status** to `[IN PROGRESS]` in plan file
3. **Execute phase steps** as documented
4. **Update phase status** to `[COMPLETED]` or `[BLOCKED]` or `[PARTIAL]`
5. **Git commit** with message: `task {N} phase {P}: {phase_name}`
6. **Proceed to next phase** or return if blocked

This ensures:
- Resume point is always discoverable from plan file
- Git history reflects phase-level progress
- Failed phases can be retried from beginning

### 4. The Gap: /implement Command Specification

While the agent has the protocol, the `/implement` command specification in `.opencode/commands/implement.md` does not explicitly enforce phase status updates during execution. The current workflow shows:

**Step 6: Execute phases** (from implement.md):
```markdown
For each phase with status `[NOT STARTED]` or `[PARTIAL]` (skip `[COMPLETED]`):

1. **Track changes** - Capture baseline git state before phase execution
2. Update phase status to `[IN PROGRESS]` in the plan file
3. Execute the phase steps
4. Verify the phase (run verification steps from the plan)
5. Update phase status to `[COMPLETED]` in the plan file
6. **Commit phase changes** - Stage and commit only files modified in this phase
7. Briefly report phase completion before moving to next
```

This is actually correct! But there may be an execution gap where the agent isn't consistently following this protocol, or the skill-implementer isn't verifying these updates occur.

### 5. State Synchronization is Already Automated

The system automatically synchronizes:
- `specs/state.json`: Machine-readable source of truth
- `specs/TODO.md`: User-facing source of truth

Status values are mapped (from `state-management.md`):
| TODO.md Marker | state.json status |
|----------------|-------------------|
| [NOT STARTED] | not_started |
| [RESEARCHING] | researching |
| [RESEARCHED] | researched |
| [PLANNING] | planning |
| [PLANNED] | planned |
| [IMPLEMENTING] | implementing |
| [COMPLETED] | completed |
| [BLOCKED] | blocked |
| [ABANDONED] | abandoned |
| [PARTIAL] | partial |

The `/implement` command (Step 5) updates these when transitioning to IMPLEMENTING:
- Edit `specs/state.json`: set `status` to `"implementing"`
- Edit `specs/TODO.md`: change marker to `[IMPLEMENTING]`

And (Step 8) when completing:
- Edit `specs/state.json`: set `status` to `"completed"`
- Edit `specs/TODO.md`: change `[IMPLEMENTING]` to `[COMPLETED]`

### 6. Workflow Patterns Show Expected Behavior

The `workflows.md` diagram shows:
```
│ For each phase: │
│ ┌─────────────┐ │
│ │ Mark IN     │ │
│ │ PROGRESS    │ │
│ ├─────────────┤ │
│ │ Execute     │ │
│ │ steps       │ │
│ ├─────────────┤ │
│ │ Mark        │ │
│ │ COMPLETED   │ │
│ ├─────────────┤ │
│ │ Git commit  │ │
│ │ phase       │ │
│ └─────────────┘ │
```

This confirms the expected behavior matches what needs to be implemented.

## Recommendations

### 1. **Verify Current Implementation Compliance**

Audit recent task implementations (OC_125-OC_130) to check if plan file phase statuses are being updated correctly. This will reveal if the issue is:
- The specification exists but isn't being followed
- The agent isn't consistently applying the protocol
- There's a technical barrier preventing updates

### 2. **Strengthen skill-implementer Verification**

The `skill-implementer/SKILL.md` postflight stage should verify:
- Phase status markers in plan file match expected states
- All completed phases are marked [COMPLETED]
- Current phase is either [COMPLETED] or [PARTIAL]

### 3. **Add Explicit Phase Sync to implement.md**

Add explicit sub-steps in Step 6 of `/implement` command:
```markdown
**Phase Execution Requirements**:
1. **Mark phase starting**: Update phase heading to `[IN PROGRESS]`
2. **Execute steps**: Perform all file operations and verification
3. **Mark phase complete**: Update phase heading to `[COMPLETED]`
4. **Update partial_progress**: Track phase completion in metadata
5. **Per-phase commit**: Commit with message `task OC_N phase P: name`

**Note**: Phase status in plan file is the source of truth for resume points.
```

### 4. **Add Recovery Mechanism for Plan Sync**

If a phase completes but status wasn't updated (detected in postflight), implement recovery:
```markdown
### Postflight Verification
1. Read plan file phases
2. Verify completed phases match metadata.phases_completed
3. If mismatch detected:
   - Update plan file to match actual state
   - Log warning about sync issue
4. Update TODO.md if needed
```

### 5. **Consider Tool Support for Phase Updates**

If manual phase updates are unreliable, consider:
- A helper function/script for phase status updates
- Validation in skill postflight that enforces phase status consistency
- A `/status` command for manual status correction (skill-status-sync already exists)

## Risks & Considerations

- **Agent Compliance**: Even with updated specifications, agents may not consistently follow phase status protocols. Enforcement in skill postflight is critical.

- **Resume Point Accuracy**: If phase statuses aren't updated, resume functionality may start from wrong phase. This is already mitigated by agent's resume scanning logic.

- **Overhead**: Adding verification steps may increase implementation time slightly, but the tradeoff for accurate state tracking is worth it.

- **Existing Tasks**: Tasks currently in flight may have incorrect phase statuses. A migration or manual correction may be needed.

## Next Steps

Run `/plan OC_131` to create an implementation plan that:
1. Audits current plan file compliance in recent tasks
2. Updates `/implement` command specification with explicit phase sync requirements
3. Enhances `skill-implementer` postflight to verify phase status consistency
4. Tests the enhanced workflow on a sample task
5. Documents the phase synchronization protocol

The foundation is solid - this is primarily an enforcement and verification enhancement rather than a new system architecture.
