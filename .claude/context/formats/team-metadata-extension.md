# Team Metadata Extension

Schema for team execution metadata in return-meta.json files.

## Overview

When team mode is enabled, the return metadata includes additional fields tracking team execution details.

## Schema

```json
{
  "status": "researched|planned|implemented|partial|failed",
  "summary": "Brief description of outcome",
  "artifacts": [...],
  "team_execution": {
    "enabled": true,
    "wave_count": 1,
    "teammates_spawned": 3,
    "teammates_completed": 3,
    "teammates_failed": 0,
    "max_parallelism": 2,
    "debugger_invocations": 0,
    "token_usage_multiplier": 5.0,
    "degraded_to_single": false,
    "degradation_reason": null
  },
  "teammate_results": [
    {
      "name": "ResearcherA",
      "role": "Primary Angle",
      "status": "completed",
      "confidence": "high",
      "output_path": "specs/NNN_SLUG/reports/RR_teammate-a-findings.md",
      "duration_seconds": 120
    }
  ],
  "synthesis": {
    "conflicts_found": 2,
    "conflicts_resolved": 2,
    "gaps_identified": 0,
    "wave_2_triggered": false
  },
  "metadata": {
    "session_id": "sess_...",
    "agent_type": "skill-team-research"
  }
}
```

## Field Definitions

### team_execution

| Field | Type | Description |
|-------|------|-------------|
| `enabled` | boolean | Whether team mode was requested |
| `wave_count` | integer | Number of waves executed |
| `teammates_spawned` | integer | Total teammates spawned across all waves |
| `teammates_completed` | integer | Teammates that completed successfully |
| `teammates_failed` | integer | Teammates that failed or timed out |
| `max_parallelism` | integer | Maximum concurrent teammates (team_size) |
| `debugger_invocations` | integer | Number of debugger teammates spawned |
| `token_usage_multiplier` | number | Estimated token multiplier vs single-agent |
| `degraded_to_single` | boolean | Whether fell back to single-agent |
| `degradation_reason` | string | Reason for degradation (if applicable) |

### teammate_results

Array of individual teammate outcomes:

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Teammate identifier (e.g., "ResearcherA") |
| `role` | string | Assigned angle/role |
| `status` | string | `completed`, `failed`, `timeout` |
| `confidence` | string | Self-reported confidence (`high`, `medium`, `low`) |
| `output_path` | string | Path to teammate output file |
| `duration_seconds` | integer | Execution time |

### synthesis

| Field | Type | Description |
|-------|------|-------------|
| `conflicts_found` | integer | Number of conflicts detected |
| `conflicts_resolved` | integer | Number of conflicts resolved |
| `gaps_identified` | integer | Number of coverage gaps found |
| `wave_2_triggered` | boolean | Whether Wave 2 was needed |

## Graceful Degradation

When team mode is unavailable:

```json
{
  "team_execution": {
    "enabled": true,
    "degraded_to_single": true,
    "degradation_reason": "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS not set"
  }
}
```

## Usage

Skills write this metadata to `specs/{NNN}_{SLUG}/.return-meta.json`.

Commands read this metadata in GATE OUT to:
1. Verify team execution completed
2. Log team metrics
3. Report synthesis results to user
