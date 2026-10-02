# Inline Status Update Patterns

> **Note**: The primary status update path is `skill_preflight_update()` / `skill_postflight_update()` from `skill-base.sh`, which call `update-task-status.sh`. The jq patterns below document the underlying operations and serve as reference for debugging and recovery scenarios.

Reusable patterns for updating task status directly in skills without invoking skill-status-sync.

**IMPORTANT**: All artifact filtering uses `select(.type == "X" | not)` instead of `select(.type != "X")` to avoid Claude Code Issue #1132 which escapes `!=` as `\!=`. See `jq-escaping-workarounds.md` for details.

## Preflight Patterns

### Research Preflight

Update task to "researching" before starting research:

```bash
# Update state.json
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    session_id: $sid
  }' \
  --session-id "$session_id" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg status "researching" \
  --arg sid "$session_id"
```

Then update TODO.md status marker using Edit tool:
- Find: `[NOT STARTED]` or `[RESEARCHED]` (for re-research)
- Replace with: `[RESEARCHING]`

### Planning Preflight

Update task to "planning" before creating plan:

```bash
# Update state.json
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    session_id: $sid
  }' \
  --session-id "$session_id" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg status "planning" \
  --arg sid "$session_id"
```

Then update TODO.md: `[RESEARCHED]` → `[PLANNING]`

### Implementation Preflight

Update task to "implementing" before starting implementation:

```bash
# Update state.json
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    session_id: $sid,
    started: $ts
  }' \
  --session-id "$session_id" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg status "implementing" \
  --arg sid "$session_id"
```

Then update TODO.md: `[PLANNED]` → `[IMPLEMENTING]`

---

## Postflight Patterns

### Research Postflight

Update task to "researched" after successful research:

**Provenance note**: `researched` is modelled in `state-schema.json` as an informational-only
ISO8601 timestamp (preserved for no-information-loss reasons -- see
`context/reference/state-management-schema.md`'s Project Entry Fields table), but no currently-live
skill sets it. `skill-status-sync/SKILL.md`'s actual `postflight_update` operation sets only
`status` and `last_updated`, omitting `researched`. Treat this snippet as documented-but-superseded,
not as the current write path.

```bash
# Step 1: Update status and timestamps
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    researched: $ts
  }' \
  --session-id "$session_id" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg status "researched"

# Step 2: Add artifact (avoids jq escaping bug - see jq-escaping-workarounds.md)
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    ([(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "research" | not)] + [{"path": $path, "type": "research"}])' \
  --session-id "$session_id" \
  --arg path "$artifact_path"
```

Then update TODO.md:
- `[RESEARCHING]` → `[RESEARCHED]`
- Add/update research artifact link

### Planning Postflight

Update task to "planned" after successful planning:

```bash
# Step 1: Update status and timestamps
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    planned: $ts
  }' \
  --session-id "$session_id" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg status "planned"

# Step 2: Add artifact (avoids jq escaping bug - see jq-escaping-workarounds.md)
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    ([(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "plan" | not)] + [{"path": $path, "type": "plan"}])' \
  --session-id "$session_id" \
  --arg path "$artifact_path"
```

Then update TODO.md:
- `[PLANNING]` → `[PLANNED]`
- Add plan artifact link

### Implementation Postflight (Completed)

Update task to "completed" after successful implementation:

```bash
# Step 1: Update status and timestamps
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    completed: $ts
  }' \
  --session-id "$session_id" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg status "completed"

# Step 2: Add artifact (avoids jq escaping bug - see jq-escaping-workarounds.md)
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    ([(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "summary" | not)] + [{"path": $path, "type": "summary"}])' \
  --session-id "$session_id" \
  --arg path "$artifact_path"
```

Then update TODO.md:
- `[IMPLEMENTING]` → `[COMPLETED]`
- Add summary artifact link

### Implementation Postflight (Partial)

Keep task as "implementing" when partially complete:

```bash
# Update state.json with progress note
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    last_updated: $ts,
    resume_phase: ($phase | tonumber + 1)
  }' \
  --session-id "$session_id" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg phase "$completed_phase"
```

**Provenance note**: `resume_phase` is modelled in `state-schema.json` (legacy/secondary field,
preserved for no-information-loss reasons -- see `context/reference/state-management-schema.md`'s
Project Entry Fields table), but no currently-live skill executes this exact snippet.
`skill-status-sync/SKILL.md`'s actual `postflight_update` operation sets only `status` and
`last_updated`; the live partial-resume path is the handoff-file-based `continuation_context`
mechanism (`agents/general-implementation-agent.md`), not `resume_phase`. Treat this snippet as
documented-but-superseded, not as the current write path.

TODO.md stays as `[IMPLEMENTING]`.

---

## TODO.md Edit Patterns

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

Use count-aware artifact linking format per `.claude/rules/state-management.md` "Artifact Linking Format".

**Detection and insertion logic**:

1. **Read existing task entry** to detect current artifact links
2. **If no `- **{Type}**:` line exists**: Insert inline format
3. **If existing inline (single link)**: Convert to multi-line with both old and new
4. **If existing multi-line (2+ links)**: Append new item to list

#### Single Artifact (inline format)

Research artifact:
```markdown
- **Research**: [01_research-findings.md]({NNN}_{SLUG}/reports/01_research-findings.md)
```

Plan artifact:
```markdown
- **Plan**: [02_implementation-plan.md]({NNN}_{SLUG}/plans/02_implementation-plan.md)
```

Summary artifact:
```markdown
- **Summary**: [MM_{short-slug}-summary.md]({NNN}_{SLUG}/summaries/MM_{short-slug}-summary.md)
```

#### Multiple Artifacts (multi-line list format)

Research artifacts (2+):
```markdown
- **Research**:
  - [01_research-findings.md]({NNN}_{SLUG}/reports/01_research-findings.md)
  - [02_supplemental.md]({NNN}_{SLUG}/reports/02_supplemental.md)
```

Plan artifacts (2+):
```markdown
- **Plan**:
  - [01_initial-plan.md]({NNN}_{SLUG}/plans/01_initial-plan.md)
  - [02_revised-plan.md]({NNN}_{SLUG}/plans/02_revised-plan.md)
```

Summary artifacts (2+):
```markdown
- **Summary**:
  - [01_phase1-summary.md]({NNN}_{SLUG}/summaries/01_phase1-summary.md)
  - [02_final-summary.md]({NNN}_{SLUG}/summaries/02_final-summary.md)
```

#### Conversion Example (inline to multi-line)

When adding second artifact to existing inline:
```
old_string: - **Research**: [01_findings.md](path/01_findings.md)
new_string: - **Research**:
  - [01_findings.md](path/01_findings.md)
  - [02_supplemental.md](path/02_supplemental.md)
```

---

## Error Handling

### Safe Update Pattern

Always route through `state-write.sh`, the single mutex-guarded `specs/state.json` writer —
it owns the private `mktemp` staging, acquire/stage/transform/validate/mv/release sequence,
and fail-closed mutex serialization internally, so callers never hand-roll staging themselves:

```bash
bash .claude/scripts/state-write.sh '...' --session-id "$session_id"
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

- jq escaping workarounds: `@.claude/context/patterns/jq-escaping-workarounds.md`
- Skill lifecycle pattern: `@.claude/context/patterns/skill-lifecycle.md`
- State management rules: `@.claude/rules/state-management.md`
- Artifact formats: `@.claude/rules/artifact-formats.md`
