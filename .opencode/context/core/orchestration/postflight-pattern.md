# Postflight Pattern

**Version**: 1.0
**Purpose**: Standard postflight validation steps after agent execution

---

## Overview

Postflight executes after agent return:

1. Validate return structure
2. Verify artifacts exist
3. Update status to completed variant
4. Link artifacts
5. Create git commit

---

## Example: /plan Postflight

```bash
# 1. Validate return
if ! echo "$return" | jq empty; then
  echo "Invalid JSON"
  exit 1
fi

# 2. Verify artifacts
for path in $(echo "$return" | jq -r '.artifacts[].path'); do
  test -f "$path" || echo "Missing artifact: $path"
done

# 3. Update status
jq --arg status "planned" --arg ts "$timestamp" \
  '(.active_projects[] | select(.project_number == ($num | tonumber))) |= . + {
    status: $status,
    last_updated: $ts
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# 4. Link artifact in specs/TODO.md
# 5. Commit
```

---

## Related Documentation

- `orchestration-core.md`
- `orchestration-validation.md`
- `state-management.md`
