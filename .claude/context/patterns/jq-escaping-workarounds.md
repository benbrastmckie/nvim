# jq Escaping Workarounds

This document describes workarounds for jq command escaping issues caused by Claude Code's Bash tool (Issue #1132).

## Bug Description

Claude Code's Bash tool has two escaping issues that affect jq commands (both variants of Issue #1132):

### Issue 1: Pipe Injection

Claude Code injects `< /dev/null` into commands containing pipe operators (`|`) inside quoted strings in certain positions. This corrupts jq filter expressions like `map(select(.type != "X"))`, causing parse errors.

### Issue 2: `!=` Operator Escaping

Claude Code escapes the `!=` operator as `\!=`, which jq cannot parse. This affects all jq commands using inequality comparisons.

### Symptoms

When running jq commands with `!=` or pipe patterns:

```
jq: error: syntax error, unexpected INVALID_CHARACTER, expecting $end
```

The error occurs because:
1. The pipe in `map(select(.type == "research" | not))` triggers `< /dev/null` injection
2. The `!=` operator gets escaped as `\!=` which is invalid jq syntax

### Affected Patterns

```bash
# BROKEN - triggers < /dev/null injection AND != escaping
artifacts: ((.artifacts // []) | map(select(.type == "research" | not))) + [...]

# BROKEN - != escaping only
select(.type == "plan" | not)
```

### Why It Happens

The Claude Code Bash tool escape mechanism:
1. Interprets `|` in quoted jq expressions as a shell pipe in certain contexts
2. Escapes `!=` as `\!=` (likely treating it as a shell history expansion)

Both bugs are marked NOT_PLANNED upstream (as of January 2026).

## Recommended Solution: Use `| not` Pattern

**PRIMARY SOLUTION**: Replace `!=` with `== "X" | not`:

```bash
# SAFE - use "| not" pattern instead of !=
select(.type == "plan" | not)

# Instead of:
select(.type == "plan" | not)  # BROKEN - gets escaped as \!=
```

This pattern works because:
- It avoids the `!=` operator entirely
- The `|` in `== "X" | not` is inside the jq filter context, not triggering shell pipe injection

## Working Patterns

### Two-Step Approach (Recommended)

Split artifact updates into separate jq calls, using `| not` pattern:

```bash
# Step 1: Update status and timestamps (no artifact manipulation)
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researched" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    researched: $ts
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# Step 2: Update artifacts - filter out old type using "| not" pattern, add new
jq --arg path "$artifact_path" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    ([(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "research" | not)] + [{"path": $path, "type": "research"}])' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
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
  )' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
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
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# Step 2: Add artifact
jq --arg path "$artifact_path" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    ([(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "research" | not)] + [{"path": $path, "type": "research"}])' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
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
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# Step 2: Add artifact
jq --arg path "$artifact_path" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    ([(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "plan" | not)] + [{"path": $path, "type": "plan"}])' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
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
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# Step 2: Add artifact
jq --arg path "$artifact_path" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    ([(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "summary" | not)] + [{"path": $path, "type": "summary"}])' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

### Task Recovery (from archive)

```bash
# Step 1: Extract task from archive
task_json=$(jq '.archived_projects[] | select(.project_number == '$task_number')' specs/archive/state.json)

# Step 2: Add to active projects
jq --argjson task "$task_json" \
  '.active_projects += [$task]' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# Step 3: Remove from archive
jq 'del(.archived_projects[] | select(.project_number == '$task_number'))' \
  specs/archive/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/archive/state.json
```

### Task Abandon (to archive)

```bash
# Step 1: Extract task to archive
task_json=$(jq '.active_projects[] | select(.project_number == '$task_number')' specs/state.json)

# Step 2: Add to archive
jq --argjson task "$task_json" \
  '.archived_projects += [$task]' specs/archive/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/archive/state.json

# Step 3: Remove from active
jq 'del(.active_projects[] | select(.project_number == '$task_number'))' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

## Testing Checklist

Before using jq patterns in production:

1. [ ] Test command in isolation with sample data
2. [ ] Verify no `INVALID_CHARACTER` errors
3. [ ] Confirm output JSON is valid
4. [ ] Check artifact array contains expected entries

### Test Script

```bash
# Create test state.json
cat > specs/tmp/test-state.json << 'EOF'
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
artifact_path="specs/100_test/reports/01_research-findings.md"

# Step 1
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researched" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    researched: $ts
  }' specs/tmp/test-state.json > specs/tmp/test-out.json && mv specs/tmp/test-out.json specs/tmp/test-state.json

# Step 2
jq --arg path "$artifact_path" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    ([(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "research" | not)] + [{"path": $path, "type": "research"}])' \
  specs/tmp/test-state.json

# Expected output should show status "researched" and artifact added
```

## Postflight Scripts

Reusable shell scripts are available in `.claude/scripts/` that encapsulate correct jq patterns:

| Script | Purpose |
|--------|---------|
| `postflight-research.sh TASK_NUM ARTIFACT_PATH [SUMMARY]` | Update state.json after research completion |
| `postflight-plan.sh TASK_NUM ARTIFACT_PATH [SUMMARY]` | Update state.json after plan creation |
| `postflight-implement.sh TASK_NUM ARTIFACT_PATH [SUMMARY]` | Update state.json after implementation |

Example usage:
```bash
.claude/scripts/postflight-plan.sh 607 "specs/607_task/plans/02_implementation-plan.md" "9-phase implementation plan"
```

## References

- Claude Code Issue #1132: Bash tool escaping bug
- `.claude/context/patterns/inline-status-update.md` - Status update patterns
- `.claude/rules/state-management.md` - State management rules
- `.claude/scripts/postflight-*.sh` - Reusable postflight scripts
