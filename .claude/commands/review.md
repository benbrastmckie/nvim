---
description: Review code and create analysis reports
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git:*), TaskCreate, TaskUpdate, AskUserQuestion
argument-hint: [SCOPE] [--create-tasks]
model: sonnet
---

# /review Command

Analyze codebase, identify issues, and optionally create tasks for fixes.

## Arguments

- `$1` - Optional scope: file path, directory, or "all"
- `--create-tasks` - Create tasks for identified issues

## Execution

### 1. Parse Arguments

```
scope = $1 or "all"
create_tasks = "--create-tasks" in $ARGUMENTS
```

Determine review scope:
- If file path: Review that file
- If directory: Review all files in directory
- If "all": Review entire codebase

### 1.5. Load Review State

Read existing state file or initialize if missing:

```bash
# Read or create specs/reviews/state.json
if [ -f specs/reviews/state.json ]; then
  review_state=$(cat specs/reviews/state.json)
else
  # Initialize with empty state
  mkdir -p specs/reviews
  echo '{"_schema_version":"1.0.0","_comment":"Review state tracking","_last_updated":"","reviews":[],"statistics":{"total_reviews":0,"last_review":"","total_issues_found":0,"total_tasks_created":0}}' > specs/reviews/state.json
fi
```

### 2. Gather Context

**For Lua files (.lua):**
- Run project-specific lint/check commands to verify correctness
- Check for TODO/FIXME comments
- Identify incomplete configurations
- Check module organization

**For general code:**
- Check for TODO/FIXME comments
- Identify code smells
- Check for security issues
- Review error handling

**For documentation:**
- Check for outdated information
- Identify missing documentation
- Verify links work

### 2.5. Roadmap Integration

Run `roadmap-integration.sh` to parse ROADMAP.md, cross-reference with project state, and annotate completed items:

```bash
# Run roadmap integration: parse, cross-reference, and annotate
roadmap_output=$(bash .claude/scripts/roadmap-integration.sh \
  --roadmap specs/ROADMAP.md \
  --state specs/state.json \
  --annotate)

# Extract structured data for downstream use
roadmap_state=$(echo "$roadmap_output" | jq '.roadmap_state')
roadmap_matches=$(echo "$roadmap_output" | jq '.roadmap_matches')
annotation_summary=$(echo "$roadmap_output" | jq '.annotation_summary')
annotations_made=$(echo "$annotation_summary" | jq '.annotations_made')
```

**Error handling**: If `roadmap-integration.sh` fails or is not found, log warning and continue review without roadmap integration:

```bash
if [ ! -f .claude/scripts/roadmap-integration.sh ]; then
  echo "Warning: roadmap-integration.sh not found -- skipping roadmap integration" >&2
  roadmap_state='{"phases":[],"status_tables":[]}'
  roadmap_matches='[]'
  annotations_made=0
fi
```

**Context loaded by the script**:
- Parses ROADMAP.md phase headers, checkboxes, and status tables
- Queries state.json for completed tasks
- Checks archive/state.json for archived completed tasks
- Applies high-confidence annotations to ROADMAP.md (Step 2.5.3 logic)

### 2.6. Parse Task Order

**Context**: Load @.claude/context/formats/task-order-format.md for parsing patterns.

Read `specs/TODO.md` and extract the Task Order section if present.

**1. Extract Task Order lines:**
```bash
# Find lines between "## Task Order" and "## Tasks"
task_order_start=$(grep -n "^## Task Order$" specs/TODO.md | head -1 | cut -d: -f1)
task_order_end=$(grep -n "^## Tasks$" specs/TODO.md | head -1 | cut -d: -f1)

if [ -z "$task_order_start" ]; then
  # No Task Order section -- set exists=false and skip
  task_order_state='{"exists": false}'
else
  # Extract lines between headers (exclusive of both)
  task_order_lines=$(sed -n "$((task_order_start+1)),$((task_order_end-1))p" specs/TODO.md)
fi
```

**2. Parse metadata (wave+tree format):**

Extract timestamp and goal from the Task Order lines:

| Element | Regex | Capture Groups |
|---------|-------|----------------|
| Timestamp | `^\*Updated (\d{4}-\d{2}-\d{2})\. (.+)\*$` | (1) date, (2) changelog |
| Goal | `^\*\*Goal\*\*: (.+)$` | (1) goal text |

**3. Parse wave table:**

Find lines in the wave summary table (between `| Wave |` header and blank line after table):
- Table header regex: `^\| Wave \| Tasks \| Blocked by \|$`
- Table row regex: `^\| (\d+) \| ([\d, ]+) \| ([\d, ]*|-{1,2}) \|$`
  - Capture (1) wave number, (2) comma-separated task numbers, (3) blocking wave numbers or `--`

Build wave list:
```json
[
  {"wave": 1, "tasks": [101, 102], "blocked_by": []},
  {"wave": 2, "tasks": [103], "blocked_by": [1]}
]
```

**4. Parse dependency tree entries:**

After the wave table, find lines matching the tree format:
- Root task (no indent): `^(\d+)\s+\[([A-Z ]+)\]\s+(.+)$`
  - Capture (1) task number, (2) status, (3) title/description
- Child task (indented with `├──` or `└──`): `^[│\s]*[├└]──\s+(\d+)\s+\[([A-Z ]+)\]\s+(.+)$`
  - Capture (1) task number, (2) status, (3) title/description
  - Parent is the nearest ancestor at a lower indentation level

Build tree entries:
```json
[
  {"task_number": 101, "status": "COMPLETED", "description": "Define schema", "depth": 0, "parent": null},
  {"task_number": 102, "status": "NOT STARTED", "description": "Add parsing", "depth": 1, "parent": 101},
  {"task_number": 87, "status": "RESEARCHED", "description": "Investigate wezterm", "depth": 0, "parent": null}
]
```

**5. Build `task_order_state` structure:**

```json
{
  "exists": true,
  "timestamp": "2026-03-24",
  "changelog": "Archived 3 tasks. Regenerated Task Order.",
  "goal": "Complete modal logic completeness proof.",
  "waves": [
    {"wave": 1, "tasks": [101, 87], "blocked_by": []},
    {"wave": 2, "tasks": [102], "blocked_by": [1]}
  ],
  "tree_entries": [
    {"task_number": 101, "status": "COMPLETED", "description": "Define schema", "depth": 0, "parent": null},
    {"task_number": 102, "status": "NOT STARTED", "description": "Add parsing", "depth": 1, "parent": 101},
    {"task_number": 87, "status": "RESEARCHED", "description": "Investigate wezterm", "depth": 0, "parent": null}
  ],
  "all_task_numbers": [101, 102, 87]
}
```

**Error handling**: If `## Task Order` does not exist in TODO.md, set `task_order_state.exists = false` and continue review without Task Order operations. Downstream sections (pruning, interactive management) check `task_order_state.exists` before operating.

### 3. Analyze Findings

Categorize issues:
- **Critical**: Broken functionality, security vulnerabilities
- **High**: Missing features, significant bugs
- **Medium**: Code quality issues, incomplete implementations
- **Low**: Style issues, minor improvements

### 4. Create Review Report

Write to `specs/reviews/review-{DATE}.md`:

```markdown
# Code Review Report

**Date**: {ISO_DATE}
**Scope**: {scope}
**Reviewed by**: Claude

## Summary

- Total files reviewed: {N}
- Critical issues: {N}
- High priority issues: {N}
- Medium priority issues: {N}
- Low priority issues: {N}

## Critical Issues

### {Issue Title}
**File**: `path/to/file:line`
**Description**: {what's wrong}
**Impact**: {why it matters}
**Recommended fix**: {how to fix}

## High Priority Issues

{Same format}

## Medium Priority Issues

{Same format}

## Low Priority Issues

{Same format}

## Code Quality Metrics

| Metric | Value | Status |
|--------|-------|--------|
| TODO count | {N} | {Info} |
| FIXME count | {N} | {OK/Warning} |
| Build status | {Pass/Fail} | {Status} |

## Roadmap Progress

### Completed Since Last Review
- [x] {item} *(Completed: Task {N}, {DATE})*
- [x] {item} *(Completed: Task {N}, {DATE})*

### Current Focus
| Phase | Priority | Current Goal | Progress |
|-------|----------|--------------|----------|
| Phase 1 | High | Audit proof dependencies | 3/15 items |
| Phase 2 | Medium | Define SetDerivable | 0/8 items |

### Recommended Next Tasks
1. {Task recommendation} (Phase {N}, {Priority})
2. {Task recommendation} (Phase {N}, {Priority})

## Recommendations

1. {Priority recommendation}
2. {Secondary recommendation}
```

**Note**: Populate `## Roadmap Progress` using `roadmap_state` and `roadmap_matches` from Section 2.5. Use `roadmap_state.phases` to build the Current Focus table and `roadmap_matches` for completed-since-last-review entries.

### 4.5. Update Review State

After creating the review report, update `specs/reviews/state.json`:

1. **Generate review entry:**
```json
{
  "review_id": "review-{DATE}",
  "date": "{ISO_DATE}",
  "scope": "{scope}",
  "report_path": "specs/reviews/review-{DATE}.md",
  "summary": {
    "files_reviewed": {N},
    "critical_issues": {N},
    "high_issues": {N},
    "medium_issues": {N},
    "low_issues": {N}
  },
  "tasks_created": [],
  "registries_updated": []
}
```

2. **Add entry to reviews array**
3. **Update statistics:**
   - Increment `total_reviews`
   - Update `last_review` date
   - Add issue counts to `total_issues_found`
4. **Update `_last_updated` timestamp**

### 5. Task Proposal Mode

The review command always presents task proposals after analysis. The `--create-tasks` flag controls the interaction mode:

**Default (no flag)**: Proceed to Section 5.5 for interactive group selection via AskUserQuestion.

**With `--create-tasks` flag**: Auto-create tasks for all Critical/High severity issues without prompting:

```
For each Critical/High issue:
  /task "Fix: {issue title}" --task-type={inferred_task_type} --priority={severity}
```

Link tasks to review report.

**Update state:** Add created task numbers to the `tasks_created` array in the review entry:
```json
"tasks_created": [601, 602, 603]
```

Also increment `statistics.total_tasks_created` by the count of new tasks.

**Note**: When `--create-tasks` is used, skip Section 5.5 interactive selection.

### 5.5. Issue Grouping and Task Recommendations

Group review issues and roadmap items into coherent task proposals, then present for interactive selection.

#### 5.5.1. Collect All Issues

Combine issues from review findings and incomplete roadmap items:

**From Review Findings** (Section 3-4):
```json
{
  "source": "review",
  "file_path": "src/plugins/lsp.lua",
  "line": 42,
  "severity": "high",
  "description": "Missing case in pattern match",
  "impact": "May cause incomplete evaluation",
  "recommended_fix": "Add wildcard case handler"
}
```

**From Roadmap Items** (Section 2.5):
```json
{
  "source": "roadmap",
  "file_path": null,
  "phase": 1,
  "priority": "high",
  "description": "Audit proof dependencies",
  "item_text": "Audit proof dependencies for Soundness.lean"
}
```

Build `all_issues` as a JSON array combining both sources.

#### 5.5.2-5.5.5. Issue Grouping (via issue-grouping.sh)

Pipe `all_issues` through `issue-grouping.sh` to extract indicators, cluster, post-process, and score groups:

```bash
# Run issue grouping: extracts indicators, clusters, post-processes, and scores
grouped_issues=$(echo "$all_issues" | bash .claude/scripts/issue-grouping.sh)

# Handle empty results
if [ -z "$grouped_issues" ] || [ "$grouped_issues" = "[]" ]; then
  grouped_issues="[]"
fi
```

**Error handling**: If `issue-grouping.sh` fails or is not found, fall back to ungrouped individual issues:

```bash
if [ ! -f .claude/scripts/issue-grouping.sh ]; then
  echo "Warning: issue-grouping.sh not found -- using ungrouped issues" >&2
  grouped_issues="[]"
fi
```

The script implements the full clustering pipeline (Steps 5.5.2-5.5.5):
- Extracts `file_section`, `issue_type`, `priority`, and `key_terms` indicators per issue
- Clusters by primary match (same file_section + issue_type) then secondary match (2+ shared key_terms + same priority)
- Post-processes: merges small groups (<2 items), caps at 10 groups, generates labels and metadata
- Scores groups and returns sorted by descending score

Output is a JSON array of group objects with `label`, `item_count`, `severity_breakdown`, `file_list`, `max_priority`, `total_score`, and `items` fields.

#### 5.5.6-5.5.7. Tiered Selection (via tier-selection.sh)

Use `tier-selection.sh` to generate AskUserQuestion prompts for each selection tier:

**Tier 1: Group selection**

```bash
# Generate Tier 1 prompt
tier1_prompt=$(echo "$grouped_issues" | bash .claude/scripts/tier-selection.sh --mode tier1)

# Present to user via AskUserQuestion using tier1_prompt fields:
#   question, header, multiSelect, options
# Capture selected indices (0-based) as comma-separated string: e.g., "0,2,3"
selected_groups="0,2"  # (replace with actual user selection)
```

If the user selects nothing (empty selection), skip to Section 6.

**Tier 2: Granularity selection**

```bash
# Generate Tier 2 prompt for selected groups
tier2_prompt=$(echo "$grouped_issues" | bash .claude/scripts/tier-selection.sh \
  --mode tier2 \
  --selected-groups "$selected_groups")

# Present to user via AskUserQuestion using tier2_prompt fields
# Capture user choice: "grouped", "individual", or "manual"
granularity="grouped"  # (replace with actual user selection)
```

**Tier 3: Manual selection (only if granularity == "manual")**

```bash
if [ "$granularity" = "manual" ]; then
  tier3_prompt=$(echo "$grouped_issues" | bash .claude/scripts/tier-selection.sh \
    --mode tier3 \
    --selected-groups "$selected_groups")

  # Present to user via AskUserQuestion using tier3_prompt fields
  # Capture selected issue indices as comma-separated string
  # Extract selected issues from tier3_prompt._source_items using selected indices
fi
```

**Error handling**: If `tier-selection.sh` fails or is not found, fall back to a simple AskUserQuestion with raw issue descriptions.

### 5.6. Task Creation from Selection

Create tasks based on selection and granularity choices from Sections 5.5.6 and 5.5.7.

#### 5.6.1. Grouped Task Creation

When "Keep as grouped tasks" is selected, create one task per group:

**Task fields:**
```json
{
  "title": "{group_label}: {item_count} issues",
  "description": "{combined issue descriptions with file:line references}",
  "task_type": "{majority_task_type}",
  "priority": "{max_priority_in_group}"
}
```

**Task type inference by majority file type in group:**
| File pattern | Task Type |
|--------------|-----------|
| `*.lua` | general |
| `*.md`, `*.json`, `.claude/**` | meta |
| `*.tex` | latex |
| `*.typ` | typst |
| Other | general |

**Description format:**
```markdown
Review issues from {scope} review on {DATE}:

1. [{severity}] {file}:{line} - {description}
   Impact: {impact}
   Fix: {recommended_fix}

2. [{severity}] {file}:{line} - {description}
   ...

Related files: {file_list}
```

#### 5.6.2. Individual Task Creation

When "Expand into individual tasks" or manual selection is chosen:

**Task fields:**
```json
{
  "title": "{issue_description, truncated to 60 chars}",
  "description": "{full issue details}",
  "task_type": "{task_type_from_file}",
  "priority": "{priority_from_severity}"
}
```

**Priority mapping:**
| Severity | Priority |
|----------|----------|
| Critical | critical |
| High | high |
| Medium | medium |
| Low | low |

**Description format:**
```markdown
Review issue from {scope} review on {DATE}:

**File**: `{file}:{line}`
**Severity**: {severity}
**Description**: {description}
**Impact**: {impact}
**Recommended Fix**: {recommended_fix}
```

#### 5.6.3. State Updates

**1. Read current state:**
```bash
next_num=$(jq -r '.next_project_number' specs/state.json)
```

**2. Create slug from title:**
```bash
# Lowercase, replace spaces/special chars with underscore, truncate to 40 chars
slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g' | cut -c1-40)
```

**3. Infer topic from file path, then confirm via Mode C suggest-wrap:**

Use extension-aware path matching to infer topic, then present a 3-option confirm:

```bash
# Path heuristic (extension-aware)
inferred_topic=""
if echo "$file_path" | grep -qE "^\.claude/|^specs/"; then
  inferred_topic="agent-system"
elif echo "$file_path" | grep -qE "^lua/|^after/"; then
  inferred_topic="neovim"
elif echo "$file_path" | grep -qE "^home/|^modules/"; then
  inferred_topic="nix-config"
fi
```

If `inferred_topic` is non-empty, show Mode C confirm via AskUserQuestion:
```json
{
  "question": "Topic for this task?",
  "header": "Topic Confirm",
  "multiSelect": false,
  "options": [
    {"label": "Accept: {inferred_topic}", "description": "Use auto-inferred topic"},
    {"label": "Override...", "description": "Enter a different topic name"},
    {"label": "Skip (no topic)", "description": "Create task without a topic"}
  ]
}
```

- If user selects "Accept: {inferred_topic}" → `topic="$inferred_topic"`
- If user selects "Override..." → show free-text follow-up: `{"question": "Enter topic name (lowercase, kebab-case):"}` and capture result as `topic`
- If user selects "Skip (no topic)" → `topic=""`

If `inferred_topic` is empty, skip confirm entirely and set `topic=""`.

**4. Add task to state.json:**
```bash
jq --arg num "$next_num" --arg slug "$slug" --arg title "$title" \
   --arg desc "$description" --arg tt "$task_type" --arg prio "$priority" \
   --arg topic "$topic" \
   '.active_projects += [{
     "project_number": ($num | tonumber),
     "project_name": $slug,
     "status": "not_started",
     "task_type": $tt,
     "topic": (if ($topic == "" | not) then $topic else null end),
     "priority": $prio,
     "description": $title,
     "created": (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
   } | if .topic == null then del(.topic) else . end] |
   .next_project_number = (($num | tonumber) + 1)' \
   specs/state.json > specs/state.json.tmp && mv specs/state.json.tmp specs/state.json
```

**4b. Update active_topics via manage-topics.sh** (after task entry exists in state.json):
```bash
# Assign topic to the newly created task and add to active_topics (non-blocking)
if [[ -n "$topic" ]]; then
  bash .claude/scripts/manage-topics.sh set "$next_num" "$topic" \
    2>/dev/null || echo "Warning: manage-topics.sh set failed for task $next_num (non-fatal)" >&2
fi
```

**5. Regenerate TODO.md** from state.json after all task state.json writes complete:
```bash
bash .claude/scripts/generate-todo.sh \
  2>/dev/null || echo "Note: Failed to regenerate TODO.md (non-fatal)" >&2
```

**6. Track in review state:**
```bash
# Add task numbers to review entry
jq --argjson tasks "[${task_nums}]" \
   '.reviews[-1].tasks_created = $tasks' \
   specs/reviews/state.json > specs/reviews/state.json.tmp && \
   mv specs/reviews/state.json.tmp specs/reviews/state.json

# Update statistics
jq --argjson count "${task_count}" \
   '.statistics.total_tasks_created += $count' \
   specs/reviews/state.json > specs/reviews/state.json.tmp && \
   mv specs/reviews/state.json.tmp specs/reviews/state.json
```

#### 5.6.4. Duplicate Prevention

Before creating each task, check for existing similar tasks:

```bash
# Check state.json for tasks with similar names or file paths
existing=$(jq -r '.active_projects[] | select(.project_name | contains("'"$slug"'"))' specs/state.json)
if [ -n "$existing" ]; then
  # Skip creation, log as duplicate
  echo "Skipping duplicate: $title (similar to existing task)"
fi
```

### 6. Update Registries (if applicable)

If reviewing specific domains, update relevant registries:
- `.claude/docs/registries/lean-files.md`
- `.claude/docs/registries/documentation.md`

### 6.5. Regenerate TODO.md

Regenerate TODO.md from state.json using `generate-todo.sh`. This regenerates the entire file including frontmatter, Task Order section, and all task entries.

**Skip condition**: If `task_order_state.exists == false` AND no tasks were created in Section 5.6, skip this section entirely.

**Run `generate-todo.sh`:**
```bash
# Regenerate TODO.md from state.json (non-fatal)
if [ -f ".claude/scripts/generate-todo.sh" ]; then
  bash ".claude/scripts/generate-todo.sh" \
    || { echo "Warning: TODO.md regeneration failed (non-fatal)" >&2; }
else
  echo "Note: generate-todo.sh not found -- skipping TODO.md regeneration" >&2
fi
```

**What the script does**:
- Reads current task statuses from `specs/state.json`
- Regenerates YAML frontmatter with correct next_project_number
- Builds wave assignment (topological sort by dependency level) via generate-task-order.sh --print
- Builds dependency tree entries with indentation
- Writes the complete `## Task Order` section in wave+tree format
- Writes all task entries in descending project_number order

**Track result**:
- `task_order_regenerated`: true if script ran successfully, false if skipped or failed

**Non-fatal**: If the script fails, log the warning and continue to Section 6.7. TODO.md regeneration failure does not block the review workflow.

### 6.6. (Removed)

Task insertion into the Task Order is now handled automatically by Section 6.5 (`generate-todo.sh`). The script reads `specs/state.json` directly, so any tasks created in Section 5.6 are already included in the regenerated TODO.md. No separate insertion step is needed.

### 6.7. Interactive Task Order Management

After Task Order regeneration (Section 6.5), optionally allow the user to update the goal statement.

#### 6.7.1. Skip Conditions

Skip this section entirely if ALL of the following are true:
- `task_order_state.exists == false` AND no tasks were created in Section 5.6
- `task_order_regenerated == false` (regeneration was skipped or failed)

```
if not task_order_state.exists and not task_order_regenerated:
  skip to Section 7
```

#### 6.7.2. Present Task Order Summary

Display a brief summary of Task Order changes made by Section 6.5:

```
Task Order: regenerated from state.json
- Tasks in order: {task_order_state.all_task_numbers.length}
- Waves: {task_order_state.waves.length}
- New tasks included: {tasks_created.length}
```

This gives the user context before the goal statement prompt.

#### 6.7.3. Goal Statement Update

**Condition**: Only present if Task Order regeneration ran (`task_order_regenerated == true`).

```json
{
  "question": "Update the Task Order goal statement?",
  "header": "Task Order Goal",
  "multiSelect": false,
  "options": [
    {
      "label": "Keep current",
      "description": "Goal: {task_order_state.goal}"
    },
    {
      "label": "Update goal",
      "description": "Enter a new goal statement for the Task Order"
    }
  ]
}
```

**Selection handling:**

**"Keep current"**: No changes to goal statement.

**"Update goal"**: Generate 3-4 suggested goal statements based on current task titles and review findings:

```json
{
  "question": "Select a new goal statement:",
  "header": "New Goal",
  "multiSelect": false,
  "options": [
    {
      "label": "{auto_generated_goal_1}",
      "description": "Based on highest-wave tasks"
    },
    {
      "label": "{auto_generated_goal_2}",
      "description": "Based on overall task distribution"
    },
    {
      "label": "{auto_generated_goal_3}",
      "description": "Based on recent review findings"
    },
    {
      "label": "Keep current",
      "description": "Goal: {task_order_state.goal}"
    }
  ]
}
```

Apply selected goal by writing to state.json and regenerating TODO.md:
```bash
# Write active_goal to state.json
jq --arg goal "$selected_goal" '.active_goal = $goal' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# Regenerate TODO.md to render the updated goal
bash .claude/scripts/generate-todo.sh \
  2>/dev/null || echo "Note: Failed to regenerate TODO.md (non-fatal)" >&2
```

### 7. Git Commit

Commit review report, state files, task state, and any roadmap changes:

```bash
# Add review artifacts
git add specs/reviews/review-{DATE}.md specs/reviews/state.json

# Add roadmap if modified
if git diff --name-only | grep -q "specs/ROADMAP.md"; then
  git add specs/ROADMAP.md
fi

# Add task state if tasks were created
if git diff --name-only | grep -q "specs/state.json"; then
  git add specs/state.json specs/TODO.md
fi

# Add TODO.md if Task Order was regenerated (even if no tasks were created)
if git diff --name-only | grep -q "specs/TODO.md"; then
  git add specs/TODO.md
fi

git commit -m "$(cat <<'EOF'
review: {scope} code review

Roadmap: {annotations_made} items annotated
Tasks: {tasks_created} created ({grouped_count} grouped, {individual_count} individual)
Task Order: {regenerated_or_skipped} (regenerated from state.json / skipped)

Session: {session_id}

EOF
)"
```

This ensures review report, state tracking, task state, and roadmap updates are committed together.

## Standards Reference

This command implements the multi-task creation pattern. See `.claude/docs/reference/standards/multi-task-creation-standard.md` for the complete standard.

**Compliance Level**: Partial (required components, limited optional)

| Component | Status | Notes |
|-----------|--------|-------|
| Discovery | Yes | Code analysis + roadmap items |
| Selection | Yes | Tier-1 group selection, Tier-2 granularity |
| Grouping | Yes | file_section + issue_type clustering (via issue-grouping.sh) |
| Dependencies | Partial | Declared in state.json; Task Order generated by script |
| Ordering | No | Sequential creation |
| Visualization | No | Not implemented |
| Confirmation | Yes | Implicit via selection |
| State Updates | Yes | Atomic updates (Section 5.6.3) |

**Note**: TODO.md management uses `generate-todo.sh` (Section 6.5) for full regeneration. Dependencies are derived from `state.json` and rendered automatically in the wave+tree format. Goal statement override is available via Section 6.7.3.

### 8. Output

Use condensed format with issue counts and task summaries:

```
Review complete for: {scope}

Report: specs/reviews/review-{DATE}.md

Issues found: {total}
- Critical: {N}, High: {N}, Medium: {N}, Low: {N}

{If tasks created:}
Tasks created: {N}
- Task #{N1}: {title} ({count} issues)
- Task #{N2}: {title}

{If no tasks created:}
No tasks created.

Next Steps:
1. Review report for details
2. Run /implement {N} to address issues
```

**Section Inclusion Rules:**

| Section | Show When |
|---------|-----------|
| Issues found | Always |
| Tasks created | tasks_created > 0 |
| No tasks created | tasks_created == 0 |
| Next Steps | Always |
