# Inline Status Update Patterns

Reusable patterns for updating task status directly in skills without invoking skill-status-sync.

## Preflight Patterns

### Research Preflight

Update task to "researching" before starting research:

```bash
# Update specs/state.json
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researching" \
   --arg sid "$session_id" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    session_id: $sid
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

Then update specs/TODO.md status marker using Edit tool:
- Find: `[NOT STARTED]` or `[RESEARCHED]` (for re-research)
- Replace with: `[RESEARCHING]`

### Planning Preflight

Update task to "planning" before creating plan:

```bash
# Update specs/state.json
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "planning" \
   --arg sid "$session_id" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    session_id: $sid
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

Then update specs/TODO.md: `[RESEARCHED]` → `[PLANNING]`

### Implementation Preflight

Update task to "implementing" before starting implementation:

```bash
# Update specs/state.json
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "implementing" \
   --arg sid "$session_id" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    session_id: $sid,
    started: $ts
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

Then update specs/TODO.md: `[PLANNED]` → `[IMPLEMENTING]`

---

## Postflight Patterns

### Research Postflight

Update task to "researched" after successful research:

```bash
# Step 1: Update status and timestamps
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researched" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    researched: $ts
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# Step 2: Add artifact (avoids jq escaping bug - see jq-escaping-workarounds.md)
jq --arg path "$artifact_path" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    ([(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type != "research")] + [{"path": $path, "type": "research"}])' \
  specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

Then update specs/TODO.md:
- `[RESEARCHING]` → `[RESEARCHED]`
- Add/update research artifact link

### Planning Postflight

Update task to "planned" after successful planning:

```bash
# Step 1: Update status and timestamps
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "planned" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    planned: $ts
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# Step 2: Add artifact (avoids jq escaping bug - see jq-escaping-workarounds.md)
jq --arg path "$artifact_path" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    ([(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type != "plan")] + [{"path": $path, "type": "plan"}])' \
  specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

Then update specs/TODO.md:
- `[PLANNING]` → `[PLANNED]`
- Add plan artifact link

### Implementation Postflight (Completed)

Update task to "completed" after successful implementation:

```bash
# Step 1: Update status and timestamps
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "completed" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    completed: $ts
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# Step 2: Add artifact (avoids jq escaping bug - see jq-escaping-workarounds.md)
jq --arg path "$artifact_path" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    ([(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type != "summary")] + [{"path": $path, "type": "summary"}])' \
  specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

Then update specs/TODO.md:
- `[IMPLEMENTING]` → `[COMPLETED]`
- Add summary artifact link

### Implementation Postflight (Partial)

Keep task as "implementing" when partially complete:

```bash
# Update specs/state.json with progress note
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg phase "$completed_phase" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    last_updated: $ts,
    resume_phase: ($phase | tonumber + 1)
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

specs/TODO.md stays as `[IMPLEMENTING]`.

---

## specs/TODO.md Edit Patterns

### Finding Task Entry

```bash
# Get line number of task header
line=$(grep -n "^### $task_number\." specs/TODO.md | cut -d: -f1)
```

### Status Marker Patterns

| Transition | Find | Replace |
|------------|------|---------|
| Start research | `[NOT STARTED]` | `[RESEARCHING]` |
| Re-research | `[RESEARCHED]` | `[RESEARCHING]` |
| Complete research | `[RESEARCHING]` | `[RESEARCHED]` |
| Start planning | `[RESEARCHED]` | `[PLANNING]` |
| Complete planning | `[PLANNING]` | `[PLANNED]` |
| Start implementation | `[PLANNED]` | `[IMPLEMENTING]` |
| Complete implementation | `[IMPLEMENTING]` | `[COMPLETED]` |

### Adding Artifact Links

Research artifact:
```markdown
- **Research**: [research-001.md](specs/{N}_{SLUG}/reports/research-001.md)
```

Plan artifact:
```markdown
- **Plan**: [implementation-001.md](specs/{N}_{SLUG}/plans/implementation-001.md)
```

Summary artifact:
```markdown
- **Summary**: [implementation-summary-{DATE}.md](specs/{N}_{SLUG}/summaries/implementation-summary-{DATE}.md)
```

---

## Error Handling

### Safe Update Pattern

Always use temp file to avoid corruption:

```bash
jq '...' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

### Verification After Update

```bash
# Verify status was updated
status=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber)) | .status' \
  specs/state.json)

if [ "$status" != "expected_status" ]; then
  echo "ERROR: Status update failed"
  # Handle error
fi
```

---

## References

- jq escaping workarounds: `@.opencode/context/core/patterns/jq-escaping-workarounds.md`
- Skill lifecycle pattern: `@.opencode/context/core/patterns/skill-lifecycle.md`
- State management rules: `@.opencode/rules/state-management.md`
- Artifact formats: `@.opencode/rules/artifact-formats.md`
