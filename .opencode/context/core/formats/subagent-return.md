# Subagent Return Format Standard

**IMPORTANT - FILE-BASED METADATA EXCHANGE (v2)**:
As of Task 600, agents write metadata to files instead of returning JSON to the console. This enables reliable structured data exchange without console pollution. The schema below is now written to `specs/{N}_{SLUG}/.return-meta.json`, NOT returned as console output.

See `.opencode/context/core/formats/return-metadata-file.md` for the file-based protocol.

**CRITICAL WARNING - ANTI-STOP PATTERN**:
Do NOT use `"status": "completed"` - it triggers OpenCode to stop execution prematurely. Use contextual values like `"researched"`, `"planned"`, `"implemented"` instead. See `.opencode/context/core/patterns/anti-stop-patterns.md` for full documentation.

## Overview

**v2 Pattern (Current)**:
1. Agents write structured metadata to `specs/{N}_{SLUG}/.return-meta.json`
2. Agents return brief text summaries (3-6 bullets) to console
3. Skills read metadata file during postflight
4. Skills handle status updates, artifact linking, and git commits

**Legacy Pattern (v1)**:
All subagents MUST return valid JSON matching this schema. This was enforced by:
1. **Orchestrator Stage 3**: Appends explicit JSON format instruction to all subagent invocations
2. **Orchestrator Stage 4**: Validates return is valid JSON with required fields
3. **Subagent Specification**: Each agent's markdown file defines this return format

**NOTE**: The JSON schema below is still used, but now written to a file instead of console output.

## Schema

All subagents MUST return this JSON structure:

```json
{
  "status": "researched|planned|implemented|synced|linked|committed|tasks_created|partial|failed|blocked",
  "summary": "Brief 2-5 sentence summary (<100 tokens)",
  "artifacts": [
    {
      "type": "plan|report|summary|implementation|documentation",
      "path": "relative/path/to/artifact.md",
      "summary": "Brief description of artifact"
    }
  ],
  "metadata": {
    "session_id": "sess_1735460684_a1b2c3",
    "duration_seconds": 123,
    "agent_type": "planner|researcher|implementer|...",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "plan", "planner"]
  },
  "errors": [
    {
      "type": "validation|execution|timeout|...",
      "message": "Clear error description",
      "recoverable": true|false,
      "recommendation": "How to fix or retry"
    }
  ],
  "next_steps": "What user should do next (if applicable)"
}
```

## Field Specifications

### status (required)
**Type**: enum
**Values**: Contextual success values + `partial`, `failed`, `blocked`

**Success values** (use instead of "completed" to avoid triggering stop behavior):
- `researched`: Research task completed, report created
- `planned`: Planning task completed, plan created
- `implemented`: Implementation task completed, code/files created
- `synced`: Status sync operation completed (preflight/postflight)
- `linked`: Artifact linking operation completed
- `committed`: Git commit operation completed
- `tasks_created`: Meta/task creation operation completed

**Non-success values**:
- `partial`: Task partially completed, some artifacts created, can resume
- `failed`: Task failed, no usable artifacts, cannot resume
- `blocked`: Task blocked by external dependency, can retry later

**Rationale**: The value "completed" was removed because OpenCode interprets it as a stop signal, causing workflow commands to halt prematurely after skill returns. Contextual values describe *what* was achieved rather than generic completion.

### summary (required)
**Type**: string  
**Constraints**: <100 tokens (~400 characters)  
**Description**: Brief 2-5 sentence summary of what was done  
**Purpose**: Protects orchestrator context window from bloat

### artifacts (required)
**Type**: array of objects  
**Can be empty**: Yes (if status=failed or blocked)  
**Description**: List of files created by agent

**Artifact object**:
```json
{
  "type": "plan|report|summary|implementation|documentation",
  "path": "relative/path/from/project/root",
  "summary": "Brief description"
}
```

### metadata (required)
**Type**: object  
**Required fields**:
- `session_id`: Must match expected session_id from delegation
- `agent_type`: Name of agent (planner, researcher, etc.)
- `delegation_depth`: Current depth in delegation chain
- `delegation_path`: Full path from orchestrator to this agent

**Optional fields**:
- `duration_seconds`: How long agent took
- `phase_count`: Number of phases (for plans)
- `estimated_hours`: Effort estimate (for plans)
- `findings_count`: Number of findings (for research)

### errors (optional)
**Type**: array of objects  
**Required if**: status != completed  
**Description**: List of errors encountered

**Error object**:
```json
{
  "type": "validation|execution|timeout|permission|...",
  "message": "Clear, actionable error message",
  "recoverable": true|false,
  "recommendation": "How to fix or what to do next"
}
```

### next_steps (optional)
**Type**: string  
**Description**: What user should do next (e.g., "Run /implement 244")

## Validation Rules

### Orchestrator Validation (Stage 6)

1. **JSON Validity**: Return must be valid JSON
2. **Required Fields**: status, summary, artifacts, metadata must be present
3. **Status Enum**: status must be a contextual success value (researched, planned, implemented, synced, linked, committed, tasks_created) or partial, failed, blocked
4. **Session ID Match**: metadata.session_id must match expected session_id
5. **Summary Length**: summary must be <100 tokens
6. **Artifacts Exist**: If status is a success value (not partial/failed/blocked), all artifact paths must exist on disk

### Validation Failures

If validation fails:
1. Log error to errors.json
2. Return failed status to user
3. Include validation errors in response
4. Recommendation: "Fix {agent} subagent return format"

## Examples

### Successful Plan
```json
{
  "status": "planned",
  "summary": "Created implementation plan for task 244 with 3 phases. Plan focuses on context reorganization, orchestrator streamlining, and command simplification. Estimated effort: 8 hours.",
  "artifacts": [
    {
      "type": "plan",
      "path": "specs/244_context_refactor/plans/implementation-001.md",
      "summary": "3-phase implementation plan"
    }
  ],
  "metadata": {
    "session_id": "sess_1735460684_a1b2c3",
    "duration_seconds": 245,
    "agent_type": "planner",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "plan", "planner"],
    "phase_count": 3,
    "estimated_hours": 8
  },
  "next_steps": "Run /implement 244 to execute the plan"
}
```

### Failed Research
```json
{
  "status": "failed",
  "summary": "Research failed due to network timeout when accessing LeanSearch API. No research artifacts created.",
  "artifacts": [],
  "metadata": {
    "session_id": "sess_1735460684_xyz789",
    "duration_seconds": 30,
    "agent_type": "lean-research-agent",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research", "lean-research-agent"]
  },
  "errors": [
    {
      "type": "timeout",
      "message": "LeanSearch API request timed out after 30s",
      "recoverable": true,
      "recommendation": "Check network connection and retry with /research 245"
    }
  ],
  "next_steps": "Retry after checking network connection"
}
```

### Partial Implementation
```json
{
  "status": "partial",
  "summary": "Completed phases 1-2 of 3. Phase 3 interrupted due to timeout. Implementation files created for phases 1-2.",
  "artifacts": [
    {
      "type": "implementation",
      "path": "src/module_a.lean",
      "summary": "Phase 1 implementation"
    },
    {
      "type": "implementation",
      "path": "src/module_b.lean",
      "summary": "Phase 2 implementation"
    },
    {
      "type": "summary",
      "path": "specs/246_feature/summaries/implementation-summary.md",
      "summary": "Partial implementation summary"
    }
  ],
  "metadata": {
    "session_id": "sess_1735460684_abc123",
    "duration_seconds": 7200,
    "agent_type": "lean-implementation-agent",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "implement", "lean-implementation-agent"]
  },
  "errors": [
    {
      "type": "timeout",
      "message": "Implementation timed out after 7200s during phase 3",
      "recoverable": true,
      "recommendation": "Resume with /implement 246 to continue from phase 3"
    }
  ],
  "next_steps": "Run /implement 246 to resume from phase 3"
}
```

## Enforcement Mechanism

### Problem Statement

When orchestrator invokes subagents via task tool (e.g., researcher, planner, implementer), OpenCode does NOT automatically follow the JSON return format specified in the agent's markdown file. This causes validation failures in orchestrator Stage 4 because subagents return plain text instead of the required JSON structure.

### Solution: Explicit JSON Format Instruction

Orchestrator Stage 3 (RegisterAndDelegate) appends the following instruction to all subagent invocations:

```
CRITICAL RETURN FORMAT REQUIREMENT:
You MUST return ONLY valid JSON matching the schema in subagent-return-format.md.
Do NOT return plain text, markdown narrative, or any other format.

Required JSON structure:
{
  "status": "<contextual-value>|partial|failed|blocked",
  "summary": "Brief 2-5 sentence summary (<100 tokens)",
  "artifacts": [{type, path, summary}, ...],
  "metadata": {session_id, duration_seconds, agent_type, delegation_depth, delegation_path},
  "errors": [{type, message, recoverable, recommendation}, ...],
  "next_steps": "What user should do next"
}

VALIDATION: Your return will be validated by orchestrator Stage 4. If you return
plain text instead of JSON, validation will fail with "Return is not valid JSON" error.
```

### Enforcement Flow

1. **User invokes command**: `/research 269`
2. **Orchestrator Stage 1**: Validates command and extracts task number
3. **Orchestrator Stage 2**: Determines target agent (researcher)
4. **Orchestrator Stage 3**: Invokes researcher via task tool with:
   - Prompt: `"Task: 269" + JSON_FORMAT_INSTRUCTION`
   - This ensures researcher knows to return JSON
5. **Researcher executes**: Reads task, conducts research, creates artifacts
6. **Researcher returns**: Valid JSON matching schema (not plain text)
7. **Orchestrator Stage 4**: Validates return:
   - Check JSON validity
   - Check required fields
   - Check artifacts exist on disk
   - Check artifacts are non-empty
8. **Orchestrator Stage 5**: Formats response for user

### Validation Failures

If subagent returns plain text instead of JSON:

```
Error: Subagent return validation failed

Subagent: researcher
Session: sess_1735460684_a1b2c3

Validation errors:
- Cannot parse return as JSON

Recommendation: Fix researcher subagent return format
```

### Benefits

1. **Prevents "phantom research"**: Ensures subagents return structured data with artifact paths
2. **Enables artifact validation**: Orchestrator can verify files exist and are non-empty
3. **Consistent format**: All subagents return same JSON structure
4. **Clear errors**: Validation failures provide actionable error messages
5. **Context window protection**: Summary field (<100 tokens) prevents bloat

### Implementation Notes

- **Enforcement point**: Orchestrator Stage 3 (RegisterAndDelegate)
- **Validation point**: Orchestrator Stage 4 (ValidateReturn)
- **Documentation**: See `.opencode/context/core/workflows/delegation-guide.md`
- **Impact**: Fixes critical validation failures affecting ALL workflow commands
