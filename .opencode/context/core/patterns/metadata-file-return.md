# Metadata File Return Pattern

**Version**: 1.0
**Created**: 2026-01-19
**Purpose**: Quick reference for agent return via metadata file
**Audience**: Agents, skill developers

---

## Overview

Agents write structured metadata to files instead of returning JSON to the console. This pattern:
- Avoids console pollution
- Enables reliable data exchange
- Prevents OpenCode interpreting JSON as conversational text

---

## File Location

```
specs/{N}_{SLUG}/.return-meta.json
```

Where:
- `{N}` = Task number (unpadded)
- `{SLUG}` = Task slug from specs/state.json project_name

Example: `specs/259_prove_completeness/.return-meta.json`

---

## Schema Quick Reference

```json
{
  "status": "researched|planned|implemented|partial|failed|blocked",
  "artifacts": [
    {
      "type": "report|plan|summary|implementation",
      "path": "specs/259_name/reports/research-001.md",
      "summary": "Brief 1-sentence description"
    }
  ],
  "next_steps": "Run /plan 259 to create implementation plan",
  "metadata": {
    "session_id": "sess_1736700000_abc123",
    "agent_type": "lean-research-agent",
    "duration_seconds": 180,
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research", "lean-research-agent"]
  },
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

---

## Required Fields

| Field | Required | Description |
|-------|----------|-------------|
| `status` | Yes | Contextual status value (NEVER "completed") |
| `artifacts` | Yes | Array (may be empty) |
| `metadata.session_id` | Yes | From delegation context |
| `metadata.agent_type` | Yes | Name of returning agent |
| `metadata.delegation_depth` | Yes | Nesting depth |
| `metadata.delegation_path` | Yes | Full delegation chain |

---

## Status Values

Use contextual status values based on operation:

| Operation | Success Status | Error Statuses |
|-----------|----------------|----------------|
| Research | `researched` | `partial`, `failed`, `blocked` |
| Planning | `planned` | `partial`, `failed`, `blocked` |
| Implementation | `implemented` | `partial`, `failed`, `blocked` |
| Status sync | `synced` | `failed` |
| Git commit | `committed` | `failed` |

**CRITICAL**: Never use "completed" - triggers OpenCode stop behavior.

---

## Agent Writing Pattern

```bash
# Ensure directory exists
mkdir -p "specs/${task_number}_${task_slug}"

# Write metadata file
cat > "specs/${task_number}_${task_slug}/.return-meta.json" << 'EOF'
{
  "status": "researched",
  "artifacts": [...],
  "metadata": {...}
}
EOF
```

Or use the Write tool:
```
Write tool:
  - Path: specs/{N}_{SLUG}/.return-meta.json
  - Content: Valid JSON matching schema
```

---

## Skill Reading Pattern

```bash
metadata_file="specs/${task_number}_${task_slug}/.return-meta.json"

if [ -f "$metadata_file" ]; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path' "$metadata_file")
fi
```

---

## Cleanup

Delete metadata file after successful postflight:

```bash
rm -f "specs/${task_number}_${task_slug}/.return-meta.json"
```

---

## Related Documentation

- @.opencode/context/core/formats/return-metadata-file.md - Full schema specification
- @.opencode/context/core/patterns/file-metadata-exchange.md - Read/write patterns
- @.opencode/context/core/patterns/anti-stop-patterns.md - Forbidden status values
- @.opencode/context/core/formats/subagent-return.md - Console return alternative
