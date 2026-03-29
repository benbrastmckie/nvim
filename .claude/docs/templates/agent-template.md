# <Agent Name> Agent

**Agent Type**: <agent-type>  
**Delegation Depth**: <depth>  
**Timeout**: <timeout>s  
**Status**: Active

---

## Purpose

[Brief description of what this agent does]

**Responsibilities**:
- [Responsibility 1]
- [Responsibility 2]
- [Responsibility 3]

---

## Inputs Required

```json
{
  "parameter_1": {
    "type": "string",
    "description": "Description of parameter 1",
    "required": true
  },
  "parameter_2": {
    "type": "integer",
    "description": "Description of parameter 2",
    "required": false,
    "default": 10
  }
}
```

---

## Inputs Forbidden

The following inputs must NOT be provided to this agent:

- `conversation_history`: [Reason why forbidden]
- `full_system_state`: [Reason why forbidden]
- `unstructured_context`: [Reason why forbidden]

---

## 8-Stage Workflow

### Stage 1: Input Validation

**Objective**: Validate all input parameters and prerequisites

**Tasks**:
1. Validate required parameters provided
2. Validate parameter types and formats
3. Check prerequisites (files exist, dependencies met)
4. Validate delegation depth (must be < 3)
5. Return error if validation fails

**Validation**:
- [ ] All required parameters present
- [ ] All parameters have correct types
- [ ] All prerequisites met
- [ ] Delegation depth valid

---

### Stage 2: Context Loading

**Objective**: Load required context files on-demand

**Tasks**:
1. Read `.claude/context/index.json` to discover available context
2. Load only required context files:
   - [Context file 1]: [Reason needed]
   - [Context file 2]: [Reason needed]
3. Parse context files for relevant information
4. Validate context loaded successfully

**Context Files**:
- `.claude/context/standards/<standard>.md`
- `.claude/context/agents/<agent-context>.md`

**Validation**:
- [ ] Context index loaded
- [ ] Required context files loaded
- [ ] Context parsed successfully

---

### Stage 3: Core Execution

**Objective**: [Description of core work this agent performs]

**Tasks**:
1. [Core task 1]
2. [Core task 2]
3. [Core task 3]
4. [Core task 4]

**Delegation** (if applicable):
- Delegate to `<subagent-name>` for [specific work]
- Validate subagent return format
- Handle subagent errors

**Validation**:
- [ ] Core work completed successfully
- [ ] All outputs generated
- [ ] Subagent delegations successful (if applicable)

---

### Stage 4: Output Generation

**Objective**: Generate outputs in required formats

**Tasks**:
1. Format primary output (e.g., report, plan, summary)
2. Generate secondary outputs (e.g., metrics, logs)
3. Validate output completeness
4. Validate output format

**Output Format**:
- **Primary Output**: [Format description]
- **Secondary Outputs**: [Format description]

**Validation**:
- [ ] Primary output generated
- [ ] Secondary outputs generated (if applicable)
- [ ] Outputs follow required formats

---

### Stage 5: Artifact Creation

**Objective**: Create artifacts in task directory

**Tasks**:
1. Create task directory: `specs/<task-number>_<topic>/`
2. Create artifact subdirectories (reports/, plans/, summaries/, etc.)
3. Write artifacts to disk:
   - [Artifact 1]: `<path>`
   - [Artifact 2]: `<path>`
4. Validate artifacts created successfully

**Artifact Structure**:
```
specs/<task-number>_<topic>/
  ├── <artifact-type>/
  │   └── <artifact-name>.md
  └── ...
```

**Validation**:
- [ ] Task directory created
- [ ] All artifacts written to disk
- [ ] Artifacts are non-empty
- [ ] Artifacts follow required formats

---

### Stage 6: Return Formatting

**Objective**: Format return following subagent-return-format.md

**Tasks**:
1. Create return object with required fields:
   - `status`: "completed" | "partial" | "failed"
   - `summary`: Brief description of work done
   - `artifacts`: Array of artifact objects
   - `metadata`: Session ID, duration, delegation info
   - `errors`: Array of error objects (if any)
   - `next_steps`: Recommended next actions
2. Validate return format
3. Ensure summary is concise (<100 tokens)

**Return Format**:
```json
{
  "status": "completed",
  "summary": "Brief description of work done",
  "artifacts": [
    {
      "type": "artifact-type",
      "path": "path/to/artifact",
      "summary": "Brief artifact description"
    }
  ],
  "metadata": {
    "session_id": "sess_<timestamp>_<random>",
    "duration_seconds": 120,
    "agent_type": "<agent-type>",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "command", "agent"]
  },
  "errors": [],
  "next_steps": "Recommended next actions"
}
```

**Validation**:
- [ ] Return format matches subagent-return-format.md
- [ ] All required fields present
- [ ] Summary is concise (<100 tokens)
- [ ] Artifacts array populated

---

### Stage 7: Artifact Validation and Status Updates

**Objective**: Validate artifacts, update TODO.md, state.json, create git commit

**CRITICAL**: This stage must be implemented by all agents. Stage 7 failures cause system-wide reliability issues.

**Tasks**:
1. **Artifact Validation**:
   - Verify all artifacts exist on disk
   - Verify artifacts are non-empty
   - Verify artifacts contain required sections
   - Verify artifacts within size limits

2. **TODO.md Update**:
   - Add task entry to `specs/TODO.md`
   - Include task number, title, status, timestamps
   - Link to artifacts
   - Follow TODO.md format

3. **state.json Update**:
   - Update `specs/state.json` with task status
   - Include completion timestamp
   - Include artifact paths
   - Validate JSON format

4. **Git Commit**:
   - Stage all artifacts
   - Create commit with message: "task <number>: <brief-description>"
   - Include task number in commit message
   - Verify commit created successfully

5. **Timestamp Recording**:
   - Record completion timestamp
   - Include in TODO.md and state.json
   - Use ISO 8601 format

**Validation**:
- [ ] All artifacts validated successfully
- [ ] TODO.md updated with task entry
- [ ] state.json updated with task status
- [ ] Git commit created with artifacts
- [ ] Timestamps recorded in ISO 8601 format

**Error Handling**:
- If artifact validation fails: Return status "failed" with error details
- If TODO.md update fails: Log error but continue (non-critical)
- If state.json update fails: Log error but continue (non-critical)
- If git commit fails: Log error but continue (non-critical)

---

### Stage 8: Cleanup

**Objective**: Perform any necessary cleanup

**Tasks**:
1. Remove temporary files (if any)
2. Close file handles
3. Release resources
4. Log completion

**Validation**:
- [ ] Temporary files removed
- [ ] Resources released
- [ ] Completion logged

---

## Output Specification

### Success Response

```json
{
  "status": "completed",
  "summary": "Successfully completed <work-description>",
  "artifacts": [
    {
      "type": "<artifact-type>",
      "path": "specs/<task-number>_<topic>/<artifact-path>",
      "summary": "Brief artifact description"
    }
  ],
  "metadata": {
    "session_id": "sess_<timestamp>_<random>",
    "duration_seconds": 120,
    "agent_type": "<agent-type>",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "command", "agent"]
  },
  "errors": [],
  "next_steps": "Recommended next actions"
}
```

### Error Response

```json
{
  "status": "failed",
  "summary": "Failed to complete <work-description>: <error-reason>",
  "artifacts": [],
  "metadata": {
    "session_id": "sess_<timestamp>_<random>",
    "duration_seconds": 60,
    "agent_type": "<agent-type>",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "command", "agent"]
  },
  "errors": [
    {
      "type": "error-type",
      "message": "Detailed error message",
      "code": "ERROR_CODE",
      "recoverable": true,
      "recommendation": "How to fix this error"
    }
  ],
  "next_steps": "How to recover from this error"
}
```

---

## Validation Checklist

Use this checklist when creating a new agent:

### 8-Stage Workflow
- [ ] Stage 1 (Input Validation) implemented
- [ ] Stage 2 (Context Loading) implemented
- [ ] Stage 3 (Core Execution) implemented
- [ ] Stage 4 (Output Generation) implemented
- [ ] Stage 5 (Artifact Creation) implemented
- [ ] Stage 6 (Return Formatting) implemented
- [ ] **Stage 7 (Artifact Validation, Status Updates, Git Commits) implemented** ← CRITICAL
- [ ] Stage 8 (Cleanup) implemented

### Stage 7 Requirements
- [ ] Artifact validation implemented
- [ ] TODO.md update implemented
- [ ] state.json update implemented
- [ ] Git commit creation implemented
- [ ] Timestamp recording implemented
- [ ] Error handling for each Stage 7 task

### Return Format
- [ ] Return format matches subagent-return-format.md
- [ ] All required fields present
- [ ] Summary is concise (<100 tokens)
- [ ] Artifacts array populated
- [ ] Errors array populated (if errors occurred)

### Context Loading
- [ ] Loads context index first
- [ ] Loads only required context files
- [ ] Context loading is on-demand (not during routing)

### Testing
- [ ] Agent tested with valid inputs
- [ ] Agent tested with invalid inputs (error handling)
- [ ] Stage 7 execution verified (TODO.md, state.json, git commit)
- [ ] Artifacts validated successfully
- [ ] Return format validated

---

## See Also

- **Return Format**: `.claude/context/formats/subagent-return.md`
- **Context Index**: `.claude/context/index.json`
- **Command Template**: `.claude/docs/templates/command-template.md`

---

**Template Version**: 1.0
**Last Updated**: 2025-12-29
