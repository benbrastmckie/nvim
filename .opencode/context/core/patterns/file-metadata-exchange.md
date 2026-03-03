# File-Based Metadata Exchange Patterns

## Overview

This document provides patterns for reading and writing metadata files between agents and skills. These patterns avoid console JSON output and enable reliable structured data exchange.

## Path Conventions

### Metadata File Location

```
specs/{N}_{SLUG}/.return-meta.json
```

Where:
- `{N}` = Task number (unpadded integer)
- `{SLUG}` = Task slug (snake_case from project_name)

### Deriving the Path

```bash
# Given task_number and task data from specs/state.json
task_number=259
task_slug=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .project_name' \
  specs/state.json)

metadata_path="specs/${task_number}_${task_slug}/.return-meta.json"
```

## Writing Metadata (Agent Side)

### Pattern 1: Direct JSON Write

For simple metadata without complex escaping:

```bash
# Ensure directory exists
mkdir -p "specs/${task_number}_${task_slug}"

# Write metadata using heredoc
cat > "specs/${task_number}_${task_slug}/.return-meta.json" << 'METADATA_EOF'
{
  "status": "researched",
  "artifacts": [
    {
      "type": "report",
      "path": "specs/259_prove_completeness/reports/research-001.md",
      "summary": "Research report with theorem findings"
    }
  ],
  "metadata": {
    "session_id": "sess_1736700000_abc123",
    "agent_type": "lean-research-agent",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research", "lean-research-agent"]
  }
}
METADATA_EOF
```

### Pattern 2: jq Construction (With Variables)

When you need to interpolate variables (uses Task 599 jq escaping workarounds):

```bash
# Build metadata with jq
# IMPORTANT: Use separate jq commands to avoid escaping issues

# Step 1: Create base structure
jq -n \
  --arg status "researched" \
  --arg next "Run /plan ${task_number} to create implementation plan" \
  '{status: $status, next_steps: $next}' > /tmp/meta_base.json

# Step 2: Add artifacts array
jq \
  --arg path "${artifact_path}" \
  --arg type "report" \
  --arg summary "${artifact_summary}" \
  '. + {artifacts: [{type: $type, path: $path, summary: $summary}]}' \
  /tmp/meta_base.json > /tmp/meta_with_artifacts.json

# Step 3: Add metadata object
jq \
  --arg sid "${session_id}" \
  --arg agent "lean-research-agent" \
  --argjson depth 1 \
  '. + {metadata: {session_id: $sid, agent_type: $agent, delegation_depth: $depth}}' \
  /tmp/meta_with_artifacts.json > "specs/${task_number}_${task_slug}/.return-meta.json"

# Cleanup temp files
rm -f /tmp/meta_base.json /tmp/meta_with_artifacts.json
```

### Pattern 3: OpenCode Write Tool

For agents using OpenCode tools directly:

```
Use the Write tool to create the metadata file:
- Path: specs/{N}_{SLUG}/.return-meta.json
- Content: Valid JSON matching the schema
```

## Reading Metadata (Skill Side)

### Pattern 1: Full Object Read

```bash
metadata_file="specs/${task_number}_${task_slug}/.return-meta.json"

if [ -f "$metadata_file" ]; then
    # Read entire metadata
    metadata=$(cat "$metadata_file")

    # Extract fields
    status=$(echo "$metadata" | jq -r '.status')
    next_steps=$(echo "$metadata" | jq -r '.next_steps // ""')
else
    echo "Error: Metadata file not found at $metadata_file"
    status="failed"
fi
```

### Pattern 2: Field Extraction

```bash
metadata_file="specs/${task_number}_${task_slug}/.return-meta.json"

# Safe field extraction with defaults
status=$(jq -r '.status // "failed"' "$metadata_file" 2>/dev/null)
session_id=$(jq -r '.metadata.session_id // ""' "$metadata_file" 2>/dev/null)
agent_type=$(jq -r '.metadata.agent_type // ""' "$metadata_file" 2>/dev/null)

# Extract first artifact
artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file" 2>/dev/null)
artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file" 2>/dev/null)
artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file" 2>/dev/null)

# Extract all artifacts as array
artifacts=$(jq -c '.artifacts // []' "$metadata_file" 2>/dev/null)
```

### Pattern 3: Validation Before Read

```bash
metadata_file="specs/${task_number}_${task_slug}/.return-meta.json"

# Check file exists and is valid JSON
if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    # File exists and is valid JSON
    status=$(jq -r '.status' "$metadata_file")

    # Validate required fields
    if [ -z "$status" ] || [ "$status" = "null" ]; then
        echo "Error: Invalid metadata - missing status"
        status="failed"
    fi
else
    echo "Error: Invalid or missing metadata file"
    status="failed"
fi
```

## Cleanup Patterns

### After Successful Postflight

```bash
# Remove metadata file after postflight completes
rm -f "specs/${task_number}_${task_slug}/.return-meta.json"
```

### With Verification

```bash
# Verify postflight succeeded before cleanup
if [ "$postflight_success" = "true" ]; then
    rm -f "specs/${task_number}_${task_slug}/.return-meta.json"
else
    # Keep metadata for debugging
    echo "Warning: Keeping metadata file for debugging"
fi
```

### Cleanup All Task Metadata

```bash
# Emergency cleanup - remove all .return-meta.json files
find specs -name ".return-meta.json" -delete
```

## Error Handling

### Missing Metadata File

```bash
metadata_file="specs/${task_number}_${task_slug}/.return-meta.json"

if [ ! -f "$metadata_file" ]; then
    # Agent may have failed before writing metadata
    # Check for partial artifacts
    if [ -d "specs/${task_number}_${task_slug}/reports" ]; then
        echo "Warning: Metadata missing but reports directory exists"
        status="partial"
    else
        echo "Error: Metadata file not found and no artifacts"
        status="failed"
    fi
fi
```

### Invalid JSON

```bash
if ! jq empty "$metadata_file" 2>/dev/null; then
    echo "Error: Metadata file is not valid JSON"
    # Try to salvage - check if artifact files exist
    cat "$metadata_file"  # Log the invalid content
    status="failed"
fi
```

### Missing Required Fields

```bash
# Validate all required fields
required_fields=("status" "artifacts" "metadata.session_id" "metadata.agent_type")
for field in "${required_fields[@]}"; do
    value=$(jq -r ".$field // empty" "$metadata_file" 2>/dev/null)
    if [ -z "$value" ]; then
        echo "Error: Missing required field: $field"
        status="failed"
        break
    fi
done
```

## Complete Skill Postflight Example

```bash
# Read metadata
metadata_file="specs/${task_number}_${task_slug}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    # Extract metadata
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
    session_id=$(jq -r '.metadata.session_id // ""' "$metadata_file")

    if [ "$status" = "researched" ] || [ "$status" = "planned" ] || [ "$status" = "implemented" ]; then
        # Update specs/state.json
        jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
           --arg status "$status" \
          '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
            status: $status,
            last_updated: $ts
          }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

        # Add artifact to specs/state.json (if present)
        if [ -n "$artifact_path" ]; then
            jq --arg path "$artifact_path" \
               --arg type "$(jq -r '.artifacts[0].type' "$metadata_file")" \
               --arg summary "$artifact_summary" \
              '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
                ([(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] ] +
                 [{"path": $path, "type": $type, "summary": $summary}])' \
              specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
        fi

        # Git commit
        git add -A
        git commit -m "task ${task_number}: complete ${status}

Session: ${session_id}

Co-Authored-By: OpenCode Opus 4.5 <noreply@anthropic.com>"

        # Cleanup
        rm -f "$metadata_file"
        rm -f specs/.postflight-pending
        rm -f specs/.postflight-loop-guard

        echo "Postflight complete: $status"
    else
        # Non-success status - keep metadata for debugging
        echo "Postflight skipped: status=$status"
    fi
else
    echo "Error: Invalid metadata file"
fi
```

## Related Documentation

- `.opencode/context/core/formats/return-metadata-file.md` - Metadata file schema
- `.opencode/context/core/patterns/postflight-control.md` - Postflight marker protocol
- `.opencode/rules/state-management.md` - State update patterns
- `.opencode/context/core/patterns/jq-escaping-workarounds.md` - jq escaping issues (Task 599)
