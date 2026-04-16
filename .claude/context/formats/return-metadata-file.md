# Return Metadata File Schema

## Overview

Agents write structured metadata to files instead of returning JSON to the console. This enables reliable data exchange without console pollution and avoids the limitation where Claude treats JSON output as conversational text.

## File Location

```
specs/{NNN}_{SLUG}/.return-meta.json
```

Where:
- `{N}` = Task number (unpadded)
- `{SLUG}` = Task slug in snake_case

Example: `specs/1_setup_lsp_config/.return-meta.json`

## Schema

```json
{
  "status": "researched|planned|implemented|partial|failed|blocked",
  "artifacts": [
    {
      "type": "report|plan|summary|implementation",
      "path": "specs/001_setup_lsp_config/reports/01_lsp-config-research.md",
      "summary": "Brief 1-sentence description of artifact"
    }
  ],
  "next_steps": "Run /plan 1 to create implementation plan",
  "metadata": {
    "session_id": "sess_1736700000_abc123",
    "agent_type": "general-research-agent",
    "duration_seconds": 180,
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research", "general-research-agent"]
  },
  "memory_candidates": [
    {
      "content": "Description of reusable knowledge",
      "category": "TECHNIQUE|PATTERN|CONFIG|WORKFLOW|INSIGHT",
      "source_artifact": "specs/001_setup_lsp_config/reports/01_lsp-config-research.md",
      "confidence": 0.85,
      "suggested_keywords": ["keyword1", "keyword2"]
    }
  ],
  "errors": [
    {
      "type": "validation|execution|timeout",
      "message": "Error description",
      "recoverable": true,
      "recommendation": "How to fix"
    }
  ]
}
```

## Field Specifications

### status (required)

**Type**: enum
**Values**: Contextual success values or error states

| Value | Description |
|-------|-------------|
| `in_progress` | Work started but not finished (early metadata, see below) |
| `researched` | Research completed successfully |
| `planned` | Plan created successfully |
| `implemented` | Implementation completed successfully |
| `partial` | Partially completed, can resume |
| `failed` | Failed, cannot resume without fix |
| `blocked` | Blocked by external dependency |

**Note**: Never use `"completed"` - it triggers Claude stop behavior.

**Early Metadata Pattern**: Agents should write metadata with `status: "in_progress"` at the START
of execution (Stage 0), then update to the final status on completion. This ensures metadata exists
even if the agent is interrupted. See `.claude/context/patterns/early-metadata-pattern.md`.

### artifacts (required)

**Type**: array of objects

Each artifact object:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | `report`, `plan`, `summary`, `implementation` |
| `path` | string | Yes | Relative path from project root |
| `summary` | string | Yes | Brief 1-sentence description |

### next_steps (optional)

**Type**: string
**Description**: What the user/orchestrator should do next

### metadata (required)

**Type**: object

| Field | Required | Description |
|-------|----------|-------------|
| `session_id` | Yes | Session ID from delegation context |
| `agent_type` | Yes | Name of agent (e.g., `general-research-agent`) |
| `duration_seconds` | No | Execution time |
| `delegation_depth` | Yes | Nesting depth in delegation chain |
| `delegation_path` | Yes | Array of delegation steps |

Additional optional fields for specific agent types:
- `findings_count` - Number of research findings
- `phases_completed` - Implementation phases completed
- `phases_total` - Total implementation phases

### started_at (optional)

**Type**: string (ISO8601 timestamp)
**Include if**: status is `in_progress` (early metadata)

Timestamp when agent started execution. Used to calculate duration on completion or detect
long-running interrupted agents.

### partial_progress (optional)

**Type**: object
**Include if**: status is `in_progress` or `partial`

Tracks progress for interrupted or partially completed work:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `stage` | string | Yes | Current execution stage (e.g., "strategy_determined", "phase_2_completed") |
| `details` | string | Yes | Human-readable description of progress |
| `phases_completed` | number | No | For implementation agents: phases completed |
| `phases_total` | number | No | For implementation agents: total phases |

**Purpose**: Enables skill postflight to determine resume point and provide user guidance when
an agent is interrupted before completion.

### completion_data (optional)

**Type**: object
**Include if**: status is `implemented` (required for successful implementations)

Contains fields needed for task completion processing. Skills extract this data during postflight to update state.json.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `completion_summary` | string | Yes | 1-3 sentence description of what was accomplished |
| `roadmap_items` | array of strings | No | Explicit ROADMAP.md item texts this task addresses (non-meta tasks only) |
| `claudemd_suggestions` | string | Yes (meta only) | Description of .claude/ changes made, or `"none"` if no .claude/ files modified |

**Notes**:
- `completion_summary` is mandatory for all `implemented` status returns
- `claudemd_suggestions` is mandatory for meta tasks (language: "meta")
- `roadmap_items` is optional and only relevant for non-meta tasks
- Skills propagate these fields to state.json for use by `/todo` command

### memory_candidates (optional)

**Type**: array of objects (0-3 items)
**Include if**: Agent discovered reusable patterns, techniques, or insights during execution

Structured memory candidates emitted by agents for downstream processing. Candidates are stored in state.json task entries and consumed by `/todo` during archival.

Each candidate object:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `content` | string | Yes | Description of the reusable knowledge (~300 tokens max) |
| `category` | string | Yes | One of: `TECHNIQUE`, `PATTERN`, `CONFIG`, `WORKFLOW`, `INSIGHT` |
| `source_artifact` | string | Yes | Path to the artifact that produced this candidate |
| `confidence` | number | Yes | Float 0-1 indicating reusability confidence |
| `suggested_keywords` | array of strings | Yes | Keywords for memory index retrieval |

**Category Definitions**:
- `TECHNIQUE` - A reusable debugging, testing, or problem-solving technique
- `PATTERN` - A code or architecture pattern discovered in the codebase
- `CONFIG` - A configuration discovery (tool settings, flags, options)
- `WORKFLOW` - A workflow or process insight (command sequences, operational patterns)
- `INSIGHT` - A general insight about the project, domain, or tooling

**Confidence Scoring Guidance**:
- >= 0.8: Clearly reusable patterns or configurations with broad applicability
- 0.5-0.8: Potentially useful techniques or workflows, context-dependent
- < 0.5: Speculative insights, may not generalize

**Notes**:
- Agents emit 0-3 candidates per execution; absence is valid behavior
- Skill postflight propagates candidates to state.json task entries with append semantics
- `/todo` consumes candidates during archival (task 447 scope)
- The field uses `// []` fallback in all jq reads for backward compatibility

### errors (optional)

**Type**: array of objects
**Include if**: status is `partial`, `failed`, or `blocked`

Each error object:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Error category |
| `message` | string | Yes | Human-readable error message |
| `recoverable` | boolean | Yes | Whether retry may succeed |
| `recommendation` | string | Yes | How to fix or proceed |

## Agent Instructions

### Writing Metadata

At the end of execution, agents MUST:

1. Create the metadata file:
```bash
mkdir -p "specs/${padded_num}_${task_slug}"
```

2. Write the JSON:
```json
// Write to specs/{NNN}_{SLUG}/.return-meta.json
{
  "status": "researched",
  "artifacts": [...],
  "metadata": {...}
}
```

3. Return a brief summary (NOT JSON) to the console:
```
Research completed for task 1:
- Found 5 relevant implementation patterns
- Identified configuration strategy using modular approach
- Created report at specs/001_setup_lsp_config/reports/01_lsp-config-research.md
```

### Reading Metadata (Skill Postflight)

Skills read the metadata file during postflight:

```bash
# Read metadata file
metadata_file="specs/${padded_num}_${task_slug}/.return-meta.json"
if [ -f "$metadata_file" ]; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary' "$metadata_file")
fi
```

### Cleanup

After postflight, delete the metadata file:

```bash
rm -f "specs/${padded_num}_${task_slug}/.return-meta.json"
```

## Examples

### Research Success

```json
{
  "status": "researched",
  "artifacts": [
    {
      "type": "report",
      "path": "specs/001_setup_lsp_config/reports/01_lsp-config-research.md",
      "summary": "Research report with 5 plugin patterns and configuration strategy"
    }
  ],
  "next_steps": "Run /plan 1 to create implementation plan",
  "metadata": {
    "session_id": "sess_1736700000_abc123",
    "agent_type": "general-research-agent",
    "duration_seconds": 180,
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research", "general-research-agent"],
    "findings_count": 5
  }
}
```

### Implementation Success (Non-Meta)

```json
{
  "status": "implemented",
  "artifacts": [
    {
      "type": "implementation",
      "path": "src/config/server-setup.ext",
      "summary": "Server configuration with 4 integrations"
    },
    {
      "type": "summary",
      "path": "specs/1_setup_lsp_config/summaries/01_lsp-config-summary.md",
      "summary": "Implementation summary with verification results"
    }
  ],
  "completion_data": {
    "completion_summary": "Configured 4 server integrations with automated installation. Implemented keybindings for common actions.",
    "roadmap_items": ["Configure server integrations"]
  },
  "memory_candidates": [
    {
      "content": "When configuring multiple server integrations, use a shared base config table and merge per-server overrides with vim.tbl_deep_extend. This avoids duplication and makes adding new servers trivial.",
      "category": "PATTERN",
      "source_artifact": "specs/001_setup_lsp_config/summaries/01_lsp-config-summary.md",
      "confidence": 0.85,
      "suggested_keywords": ["lsp", "server-config", "vim.tbl_deep_extend", "merge"]
    }
  ],
  "next_steps": "Review implementation and verify with /test",
  "metadata": {
    "session_id": "sess_1736700000_def456",
    "agent_type": "general-implementation-agent",
    "duration_seconds": 3600,
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "implement", "general-implementation-agent"],
    "phases_completed": 4,
    "phases_total": 4
  }
}
```

### Early Metadata (In Progress)

Written at Stage 0, before substantive work begins:

```json
{
  "status": "in_progress",
  "started_at": "2026-01-28T10:30:00Z",
  "artifacts": [],
  "partial_progress": {
    "stage": "initializing",
    "details": "Agent started, parsing delegation context"
  },
  "metadata": {
    "session_id": "sess_1736700000_abc123",
    "agent_type": "general-research-agent",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research", "general-research-agent"]
  }
}
```

### Planning Success

Written by planner-agent after successful plan creation:

```json
{
  "status": "planned",
  "artifacts": [
    {
      "type": "plan",
      "path": "specs/001_setup_lsp_config/plans/01_lsp-config-plan.md",
      "summary": "Implementation plan with 4 phases and dependency analysis"
    }
  ],
  "next_steps": "Run /implement 1 to execute the plan",
  "metadata": {
    "session_id": "sess_1736700000_abc123",
    "agent_type": "planner-agent",
    "duration_seconds": 240,
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "plan", "planner-agent"]
  }
}
```

### Implementation Partial

Written when implementation is interrupted or fails mid-execution:

```json
{
  "status": "partial",
  "artifacts": [
    {
      "type": "summary",
      "path": "specs/001_setup_lsp_config/summaries/01_lsp-config-summary.md",
      "summary": "Partial implementation summary with 2 of 4 phases completed"
    }
  ],
  "partial_progress": {
    "stage": "phase_2_completed",
    "details": "Phases 1-2 completed, phase 3 failed due to build error",
    "phases_completed": 2,
    "phases_total": 4
  },
  "errors": [
    {
      "type": "execution",
      "message": "Build failed: missing dependency in configuration",
      "recoverable": true,
      "recommendation": "Install dependency and run /implement 1 to resume from phase 3"
    }
  ],
  "metadata": {
    "session_id": "sess_1736700000_ghi789",
    "agent_type": "general-implementation-agent",
    "duration_seconds": 1800,
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "implement", "general-implementation-agent"],
    "phases_completed": 2,
    "phases_total": 4
  }
}
```

For other scenarios (meta tasks, blocked), combine the schema fields above. Meta tasks add `claudemd_suggestions` to `completion_data`.

**Note**: The file-based metadata format supersedes the earlier console-based `subagent-return.md` pattern. See that file for historical context only.

## Related Documentation

- `.claude/context/formats/subagent-return.md` - Original console-based format
- `.claude/context/patterns/postflight-control.md` - Marker file protocol
- `.claude/context/patterns/file-metadata-exchange.md` - File I/O patterns
- `.claude/context/patterns/early-metadata-pattern.md` - Early metadata creation pattern
- `.claude/rules/state-management.md` - State update patterns
- `.claude/rules/error-handling.md` - Error types including mcp_abort_error and delegation_interrupted
