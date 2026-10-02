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
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    researched: $ts
  }' \
  --session-id "$session_id" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg status "researched"

# Step 2: Update artifacts - filter out old type using "| not" pattern, add new
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    ([(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "research" | not)] + [{"path": $path, "type": "research"}])' \
  --session-id "$session_id" \
  --arg path "$artifact_path"
```

### del() Approach (Alternative)

Use `del()` instead of `map(select(!=))`:

```bash
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')) |= (
    del(.artifacts[] | select(.type == "research")) |
    . + {
      status: $status,
      last_updated: $ts,
      researched: $ts,
      artifacts: ((.artifacts // []) + [{"path": $path, "type": "research"}])
    }
  )' \
  --session-id "$session_id" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg status "researched" \
  --arg path "$artifact_path"
```

## Pattern Templates

### Research Postflight

**Provenance note**: this template's `researched` field is modelled in `state-schema.json` as an
informational-only ISO8601 timestamp (see `context/reference/state-management-schema.md`'s
Project Entry Fields table), but no currently-live skill sets it today.
`skill-status-sync/SKILL.md`'s actual `postflight_update` operation sets only `status` and
`last_updated`. This template -- and the other `researched: $ts` occurrences above illustrating
the jq-escaping idiom -- are retained as documentation of a prior write pattern, not as the
current live write path.

```bash
# Step 1: Update status
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    researched: $ts
  }' \
  --session-id "$session_id" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg status "researched"

# Step 2: Add artifact
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    ([(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "research" | not)] + [{"path": $path, "type": "research"}])' \
  --session-id "$session_id" \
  --arg path "$artifact_path"
```

### Planning Postflight

```bash
# Step 1: Update status
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    planned: $ts
  }' \
  --session-id "$session_id" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg status "planned"

# Step 2: Add artifact
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    ([(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "plan" | not)] + [{"path": $path, "type": "plan"}])' \
  --session-id "$session_id" \
  --arg path "$artifact_path"
```

### Implementation Postflight

```bash
# Step 1: Update status
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    completed: $ts
  }' \
  --session-id "$session_id" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg status "completed"

# Step 2: Add artifact
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    ([(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "summary" | not)] + [{"path": $path, "type": "summary"}])' \
  --session-id "$session_id" \
  --arg path "$artifact_path"
```

### Task Recovery (from archive)

```bash
# Step 1: Extract task from archive
task_json=$(jq '.archived_projects[] | select(.project_number == '$task_number')' specs/archive/state.json)

# Step 2: Add to active projects
bash .claude/scripts/state-write.sh \
  '.active_projects += [$task]' \
  --session-id "$session_id" \
  --argjson task "$task_json"

# Step 3: Remove from archive. The archive target is reached via state-write.sh's --state-file
# flag; the del()-not-map(select(!=)) escaping workaround this section demonstrates is unchanged.
bash .claude/scripts/state-write.sh \
  'del(.archived_projects[] | select(.project_number == ($num | tonumber)))' \
  --state-file specs/archive/state.json \
  --session-id "$session_id" \
  --arg num "$task_number"
```

### Task Abandon (to archive)

```bash
# Step 1: Extract task to archive
task_json=$(jq '.active_projects[] | select(.project_number == '$task_number')' specs/state.json)

# Step 2: Add to archive. The archive target is reached via state-write.sh's --state-file flag.
bash .claude/scripts/state-write.sh \
  '.archived_projects += [$task]' \
  --state-file specs/archive/state.json \
  --session-id "$session_id" \
  --argjson task "$task_json"

# Step 3: Remove from active
bash .claude/scripts/state-write.sh \
  'del(.active_projects[] | select(.project_number == '$task_number'))' \
  --session-id "$session_id"
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

## State Updates

State updates now go through `.claude/scripts/update-task-status.sh` (preflight/postflight
variants), which encapsulates the correct jq patterns internally. See
`.claude/rules/state-management.md` for the state-first update pipeline this script implements.

## References

- Claude Code Issue #1132: Bash tool escaping bug
- `.claude/context/patterns/inline-status-update.md` - Status update patterns
- `.claude/rules/state-management.md` - State management rules
- `.claude/scripts/update-task-status.sh` - State-first status update script
