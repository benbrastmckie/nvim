# Task Review Mode

This file is the complete and only specification for `/task`'s Review Mode (`--review`). It was
extracted verbatim from `commands/task.md`'s former `## Review Mode (--review)` section,
including its `### Review Mode Constraints` and `### Standards Reference (--review mode)`
subsections. It MUST be followed exactly when `/task --review` is dispatched.

---

## Review Mode (--review)

Parse task number after --review (e.g., `--review 597`):

### Step 1: Validate Task Exists

**Lookup task via jq**:
```bash
task_number="{N from arguments}"
task_data=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber))' \
  specs/state.json)

if [ -z "$task_data" ]; then
  echo "Error: Task $task_number not found in active projects"
  exit 1
fi

# Review Mode does not source command-gate-in.sh, so it has no session_id of its own --
# generate one once for the whole review run, following the same self-generating fallback
# used by Sync Mode above.
source .claude/scripts/lib/common.sh
session_id="$(common_session_id)"

# Extract task metadata
slug=$(echo "$task_data" | jq -r '.project_name')
status=$(echo "$task_data" | jq -r '.status')
task_type=$(echo "$task_data" | jq -r '.task_type // "general"')
```

### Step 2: Load Task Artifacts

**Find task directory** (handle both legacy unpadded and new padded formats):
```bash
PADDED_NUM=$(printf "%03d" "$task_number")
# Check padded format first (new), then unpadded (legacy)
if [ -d "specs/${PADDED_NUM}_${slug}" ]; then
  task_dir="specs/${PADDED_NUM}_${slug}"
elif [ -d "specs/${task_number}_${slug}" ]; then
  task_dir="specs/${task_number}_${slug}"
else
  task_dir=""  # No directory exists yet
fi
```

**Find and load plan file**:
```bash
plan_file=""
if [ -n "$task_dir" ]; then
  plan_dir="${task_dir}/plans"
  plan_file=$(ls -t "$plan_dir"/*.md 2>/dev/null | head -1)
fi

if [ -z "$plan_file" ]; then
  echo "No implementation plan found for task $task_number"
  echo "Recommendation: Run /plan $task_number to create a plan"
  # Continue - can still report on task status
fi
```

**Find and load summary file** (if exists):
```bash
summary_file=""
if [ -n "$task_dir" ]; then
  summary_dir="${task_dir}/summaries"
  summary_file=$(ls -t "$summary_dir"/*-summary.md 2>/dev/null | head -1)
fi
```

**Find research reports** (for context):
```bash
research_files=""
if [ -n "$task_dir" ]; then
  reports_dir="${task_dir}/reports"
  research_files=$(ls "$reports_dir"/*.md 2>/dev/null | grep -v README)
fi
```

### Step 3: Parse Plan Phases

**Extract phase statuses from plan file**:
```bash
# Sourced from the shared anchor (scripts/lib/phase-heading-patterns.sh) rather than re-derived
# inline -- see context/formats/plan-format.md's "Canonical phase-heading shape" subsection.
. .claude/scripts/lib/phase-heading-patterns.sh

# Parse phase headings with status markers
# Format: ### Phase N: Name [STATUS]
phases=$(grep -E "$PHASE_HEADING_ERE" "$plan_file" 2>/dev/null)

# Non-conforming guard: a non-conforming heading is named in output rather than silently
# skipped from the categorization set below.
if has_nonconforming_phase_headings "$plan_file"; then
  warn_nonconforming "$plan_file" "task-review" || true
fi

# Build phase analysis (use extract_phase_number per heading, never a truncated prefix):
# - phase_number
# - phase_name
# - status: [NOT STARTED], [IN PROGRESS], [COMPLETED], [COMPLETED WITH EXCLUSIONS], [PARTIAL], [BLOCKED]
```

**Categorize phases**:
- **Completed**: Phases with `[COMPLETED]` status
- **Completed with Exclusions**: Phases with `[COMPLETED WITH EXCLUSIONS]` status
- **In Progress**: Phases with `[IN PROGRESS]` status
- **Not Started**: Phases with `[NOT STARTED]` status
- **Partial**: Phases with `[PARTIAL]` status
- **Blocked**: Phases with `[BLOCKED]` status

### Step 4: Generate Review Summary

**Display task overview**:
```
## Task Review: #{N} - {slug}

**Status**: {status from state.json}
**Task Type**: {task_type}

### Artifacts Found
- Plan: {path or "Not found"}
- Summary: {path or "Not found"}
- Research: {count} report(s)

### Phase Analysis
| Phase | Name | Status |
|-------|------|--------|
| 1 | {name} | [COMPLETED] |
| 2 | {name} | [IN PROGRESS] |
| 3 | {name} | [NOT STARTED] |

### Completion Assessment
- Total phases: {N}
- Completed: {N}
- Remaining: {N}
```

### Step 5: Identify Incomplete Work

For each incomplete phase, extract:
- Phase number and name
- Phase goal (from **Goal**: line in plan)
- Estimated effort (if available)
- Dependencies (if any)

### Step 6: Generate Follow-up Task Suggestions

**For each incomplete phase, generate suggestion**:
```markdown
### Suggested Follow-up Tasks

1. **Complete phase {P} of task {N}: {phase_name}**
   - Goal: {extracted phase goal}
   - Effort: {inherited or "TBD"}
   - Task Type: {inherited from parent}
   - Ref: Parent task #{N}
```

**No suggestions if**:
- All phases are `[COMPLETED]`
- No plan file exists

### Step 7: Interactive User Selection

**Use AskUserQuestion with multiSelect**:
```json
{
  "question": "Select follow-up tasks to create:",
  "header": "Follow-up Tasks",
  "multiSelect": true,
  "options": [
    {
      "label": "Phase 2: implement_validation_rules",
      "description": "Goal: {phase_goal} | Effort: {effort}"
    },
    {
      "label": "Phase 3: add_error_reporting",
      "description": "Goal: {phase_goal} | Effort: {effort}"
    }
  ]
}
```

**For >20 incomplete phases**, add "Select all" option:
```json
{
  "label": "Select all",
  "description": "Create tasks for all {N} incomplete phases"
}
```

**Selection handling**:
- Selected options → Create those specific tasks
- Empty selection → Exit without creating tasks (no separate "none" option needed)
- "Select all" selected → Create all suggested tasks

### Step 7.5: Read Parent Topic for Inheritance

Before creating follow-up tasks, read the parent task's topic:
```bash
parent_topic=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber)) | .topic // ""' \
  specs/state.json)
```

### Step 7.6: Fallback Topic Picker

If `parent_topic` is empty, the parent task has no topic. Invoke the Mode A universal
fallback per @.claude/context/patterns/topic-assignment-pattern.md (Mode A: Interactive,
batch variant — one topic shared by all follow-up tasks being created). There is no Skip
option; topic assignment is mandatory.
```bash
if [[ -z "$parent_topic" ]]; then
  mapfile -t existing_topics < <(bash .claude/scripts/manage-topics.sh list)
  # Follow @.claude/context/patterns/topic-assignment-pattern.md (Mode A: Interactive,
  # batch variant) to show the picker and capture the result in $parent_topic.
fi
```

AskUserQuestion:
```json
{
  "question": "Assign a topic to follow-up tasks (parent has none)?",
  "header": "Topic",
  "multiSelect": false,
  "options": [
    {"label": "<existing-topic-1>", "description": "Existing topic"},
    {"label": "<existing-topic-2>", "description": "Existing topic"},
    {"label": "New topic...", "description": "Free-text follow-up to name a new topic"}
  ]
}
```

- If user selects an existing topic → `parent_topic="$selected"`
- If user selects "New topic..." → free-text follow-up, capture as `parent_topic`

### Step 8: Create Selected Follow-up Tasks

For each selected task, use the Create Task jq pattern:

```bash
# Get next task number
next_num=$(jq -r '.next_project_number' specs/state.json)

# Create follow-up task
description="Complete phase {P} of task {parent_N}: {phase_name}. Goal: {phase_goal}. (Follow-up from task #{parent_N})"

# Update state.json. $parent_topic is non-empty by construction: either
# inherited from the parent task or assigned via the Mode A universal fallback (Step 7.6).
# The null-guard below is defensive only.
bash .claude/scripts/state-write.sh \
  '.next_project_number = ($next_num + 1) |
   .active_projects = [{
     "project_number": '$next_num',
     "project_name": "followup_{parent_N}_phase_{P}",
     "status": "not_started",
     "task_type": "'{task_type}'",
     "topic": (if ($topic == "" | not) then $topic else null end),
     "description": $desc,
     "parent_task": '{parent_N}',
     "created": $ts,
     "last_updated": $ts
   } | if .topic == null then del(.topic) else . end] + .active_projects' \
  --session-id "$session_id" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg desc "$description" \
  --arg topic "$parent_topic"

# After state.json write, assign topic via manage-topics.sh (non-blocking)
if [[ -n "$parent_topic" ]]; then
  bash .claude/scripts/manage-topics.sh set "$next_num" "$parent_topic" \
    2>/dev/null || echo "Warning: manage-topics.sh set failed for task $next_num (non-fatal)" >&2
fi
```

After all follow-up task state.json writes complete, **regenerate TODO.md**:
```bash
bash .claude/scripts/generate-todo.sh \
  2>/dev/null || echo "Note: Failed to regenerate TODO.md (non-fatal)" >&2
```

### Step 9: Output Results

**If tasks were created**:
```
Created {N} follow-up task(s):
  - Task #{X}: Complete phase 2 of task {N}: implement_validation_rules
  - Task #{Y}: Complete phase 3 of task {N}: add_error_reporting
```

**Git commit** (only if tasks were created), via `.claude/scripts/git-commit-scoped.sh`:
```
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {parent_N}: review - created {N} follow-up tasks" \
  --session "${session_id}" \
  --honest-index-rows {parent_N} \
  -- specs/TODO.md specs/state.json
```

**If no tasks created**:
```
Review complete. No follow-up tasks created.
```

### Review Mode Constraints

- **READ-ONLY** analysis until user explicitly selects tasks to create
- Does NOT modify the reviewed task's status
- Does NOT fix inconsistencies (use --sync for that)
- Does NOT auto-create tasks without user confirmation
- Gracefully handles missing artifacts (plan, summary, research)

### Standards Reference (--review mode)

This mode implements the multi-task creation pattern. See `.claude/docs/reference/standards/multi-task-creation-standard.md` for the complete standard.

**Compliance Level**: Partial (simplified for follow-up tasks)

| Component | Status | Notes |
|-----------|--------|-------|
| Discovery | Yes | Incomplete phases from plan file |
| Selection | Yes | Numbered list selection |
| Grouping | No | One task per phase |
| Dependencies | Partial | parent_task linking only |
| Ordering | No | Phase number is implicit order |
| Visualization | No | Not implemented |
| Confirmation | Yes | Explicit selection required |
| State Updates | Yes | Standard task creation |

**Note**: Topological sorting is not needed because follow-up tasks inherit natural ordering from plan phase numbers. The parent_task field provides traceability to the original task.

