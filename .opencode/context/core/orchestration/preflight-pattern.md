# Preflight Pattern

**Version**: 1.0
**Purpose**: Standard preflight validation steps for command execution

---

## Overview

Preflight executes before delegating to a skill/agent:

1. Validate task exists
2. Validate status transition
3. Update status to in-progress
4. Generate session ID

---

## Example: /research Preflight

```bash
# 1. Generate session ID
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"

# 2. Validate task exists
jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber))' \
  specs/state.json

# 3. Validate status
# (check status against allowed transitions)

# 4. Update status
jq --arg status "researching" --arg ts "$timestamp" \
  '(.active_projects[] | select(.project_number == ($num | tonumber))) |= . + {
    status: $status,
    last_updated: $ts
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

---

## Related Documentation

- `orchestration-core.md`
- `state-management.md`
- `@.opencode/context/core/patterns/inline-status-update.md`
