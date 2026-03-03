# jq Escaping Workarounds

This document describes workarounds for jq command escaping issues caused by OpenCode's Bash tool (Issue #1132).

## Bug Description

OpenCode's Bash tool injects `< /dev/null` into commands containing pipe operators (`|`) inside quoted strings in certain positions. This corrupts jq filter expressions like `map(select(.type != "X"))`, causing parse errors.

### Symptoms

When running jq commands with `map(select(.field != "value"))` patterns:

```
jq: error: syntax error, unexpected INVALID_CHARACTER, expecting $end
```

The error occurs because the pipe in `map(select(.type != "research"))` triggers the bug when positioned after an array accessor like `.artifacts`.

### Affected Pattern

```bash
# BROKEN - triggers < /dev/null injection
artifacts: ((.artifacts // []) | map(select(.type != "research"))) + [...]
```

### Why It Happens

The OpenCode Bash tool escape mechanism interprets `|` in quoted jq expressions as a shell pipe in certain contexts, leading to malformed command execution. The bug is marked NOT_PLANNED upstream (as of January 2026).

## Working Patterns

### Two-Step Approach (Recommended)

Split artifact updates into separate jq calls:

```bash
# Step 1: Update status and timestamps (no artifact manipulation)
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researched" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    researched: $ts
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# Step 2: Update artifacts - filter out old type, add new
jq --arg path "$artifact_path" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    ([(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type != "research")] + [{"path": $path, "type": "research"}])' \
  specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

### del() Approach (Alternative)

Use `del()` instead of `map(select(!=))`:

```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researched" \
   --arg path "$artifact_path" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= (
    del(.artifacts[] | select(.type == "research")) |
    . + {
      status: $status,
      last_updated: $ts,
      researched: $ts,
      artifacts: ((.artifacts // []) + [{"path": $path, "type": "research"}])
    }
  )' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

## Pattern Templates

### Research Postflight

```bash
# Step 1: Update status
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researched" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    researched: $ts
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# Step 2: Add artifact
jq --arg path "$artifact_path" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    ([(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type != "research")] + [{"path": $path, "type": "research"}])' \
  specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

### Planning Postflight

```bash
# Step 1: Update status
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "planned" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    planned: $ts
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# Step 2: Add artifact
jq --arg path "$artifact_path" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    ([(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type != "plan")] + [{"path": $path, "type": "plan"}])' \
  specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

### Implementation Postflight

```bash
# Step 1: Update status
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "completed" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    completed: $ts
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# Step 2: Add artifact
jq --arg path "$artifact_path" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    ([(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type != "summary")] + [{"path": $path, "type": "summary"}])' \
  specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

### Task Recovery (from archive)

```bash
# Step 1: Extract task from archive
task_json=$(jq '.archived_projects[] | select(.project_number == '$task_number')' specs/archive/state.json)

# Step 2: Add to active projects
jq --argjson task "$task_json" \
  '.active_projects += [$task]' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# Step 3: Remove from archive
jq 'del(.archived_projects[] | select(.project_number == '$task_number'))' \
  specs/archive/state.json > /tmp/state.json && mv /tmp/state.json specs/archive/state.json
```

### Task Abandon (to archive)

```bash
# Step 1: Extract task to archive
task_json=$(jq '.active_projects[] | select(.project_number == '$task_number')' specs/state.json)

# Step 2: Add to archive
jq --argjson task "$task_json" \
  '.archived_projects += [$task]' specs/archive/state.json > /tmp/state.json && mv /tmp/state.json specs/archive/state.json

# Step 3: Remove from active
jq 'del(.active_projects[] | select(.project_number == '$task_number'))' \
  specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

## Testing Checklist

Before using jq patterns in production:

1. [ ] Test command in isolation with sample data
2. [ ] Verify no `INVALID_CHARACTER` errors
3. [ ] Confirm output JSON is valid
4. [ ] Check artifact array contains expected entries

### Test Script

```bash
# Create test specs/state.json
cat > /tmp/test-specs/state.json << 'EOF'
{
  "active_projects": [
    {
      "project_number": 100,
      "project_name": "test_task",
      "status": "researching",
      "artifacts": []
    }
  ]
}
EOF

# Test the two-step pattern
task_number=100
artifact_path="specs/100_test/reports/research-001.md"

# Step 1
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researched" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    researched: $ts
  }' /tmp/test-specs/state.json > /tmp/test-out.json && mv /tmp/test-out.json /tmp/test-specs/state.json

# Step 2
jq --arg path "$artifact_path" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    ([(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type != "research")] + [{"path": $path, "type": "research"}])' \
  /tmp/test-specs/state.json

# Expected output should show status "researched" and artifact added
```

## Postflight Scripts

Reusable shell scripts are available in `.opencode/scripts/` that encapsulate correct jq patterns:

| Script | Purpose |
|--------|---------|
| `postflight-research.sh TASK_NUM ARTIFACT_PATH [SUMMARY]` | Update specs/state.json after research completion |
| `postflight-plan.sh TASK_NUM ARTIFACT_PATH [SUMMARY]` | Update specs/state.json after plan creation |
| `postflight-implement.sh TASK_NUM ARTIFACT_PATH [SUMMARY]` | Update specs/state.json after implementation |

Example usage:
```bash
.opencode/scripts/postflight-plan.sh 607 "specs/607_task/plans/implementation-001.md" "9-phase implementation plan"
```

## References

- OpenCode Issue #1132: Bash tool escaping bug
- `.opencode/context/core/patterns/inline-status-update.md` - Status update patterns
- `.opencode/rules/state-management.md` - State management rules
- `.opencode/scripts/postflight-*.sh` - Reusable postflight scripts
