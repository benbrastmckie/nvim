---
description: Review code and create analysis reports
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git:*), TaskCreate, TaskUpdate, AskUserQuestion
argument-hint: [SCOPE] [--create-tasks]
model: opus
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
- Run `nvim --headless` to check for errors
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

**Context**: Load @.claude/context/formats/roadmap-format.md for parsing patterns.

**Ensure specs/ROADMAP.md exists** before parsing. If the file does not exist, create it with the default template:
```markdown
# Project Roadmap

## Phase 1: Current Priorities (High Priority)

- [ ] (No items yet -- add roadmap items here)

## Success Metrics

- (Define success metrics here)
```

Parse `specs/ROADMAP.md` to extract:
1. **Phase headers**: `## Phase {N}: {Title} ({Priority})`
2. **Checkboxes**: `- [ ]` (incomplete) and `- [x]` (complete)
3. **Status tables**: Pipe-delimited rows with Component/Status/Location
4. **Priority markers**: `(High Priority)`, `(Medium Priority)`, `(Low Priority)`

Build `roadmap_state` structure:
```json
{
  "phases": [
    {
      "number": 1,
      "title": "Proof Quality and Organization",
      "priority": "High",
      "checkboxes": {
        "total": 15,
        "completed": 3,
        "items": [
          {"text": "Audit proof dependencies", "completed": false},
          {"text": "Create proof architecture guide", "completed": true}
        ]
      }
    }
  ],
  "status_tables": [
    {
      "component": "Soundness",
      "status": "PROVEN",
      "location": "nvim/lua/plugins/lsp.lua"
    }
  ]
}
```

**Error handling**: If ROADMAP.md doesn't exist or fails to parse, log warning and continue review without roadmap integration.

### 2.5.2. Cross-Reference Roadmap with Project State

**Context**: Load @.claude/context/patterns/roadmap-update.md for matching strategy.

Cross-reference roadmap items with project state to identify completed work:

**1. Query TODO.md for completed tasks:**
```bash
# Find completed task titles
grep -E '^\#\#\#.*\[COMPLETED\]' specs/TODO.md
```

**2. Query state.json for completion data:**
```bash
# Get completed tasks with dates
jq '.active_projects[] | select(.status == "completed")' specs/state.json
```

**3. Check file existence for mentioned paths:**
```bash
# For each path in roadmap items, check if exists
# E.g., docs/architecture/proof-structure.md
```

**4. Count TODOs in Lua files:**
```bash
# Current TODO count for metrics
grep -r "TODO" nvim/lua/ --include="*.lua" | wc -l
```

**Match roadmap items to completed work:**

| Match Type | Confidence | Action |
|------------|------------|--------|
| Item contains `(Task {N})` | High | Auto-annotate |
| Item text matches task title | Medium | Suggest annotation |
| Item's file path exists | Medium | Suggest annotation |
| Partial keyword match | Low | Report only |

Build `roadmap_matches` list:
```json
[
  {
    "roadmap_item": "Create proof architecture guide",
    "phase": 1,
    "match_type": "title_match",
    "confidence": "medium",
    "matched_task": 628,
    "completion_date": "2026-01-15"
  }
]
```

### 2.5.3. Annotate Completed Roadmap Items

For high-confidence matches, update ROADMAP.md to mark items as complete.

**Annotation format** (per roadmap-format.md):
```markdown
- [x] {item text} *(Completed: Task {N}, {DATE})*
```

**Edit process for checkboxes:**

1. For each high-confidence match:
   ```
   old_string: "- [ ] Create proof architecture guide"
   new_string: "- [x] Create proof architecture guide *(Completed: Task 628, 2026-01-15)*"
   ```

2. Use Edit tool with exact string matching

**Edit process for status tables:**

1. For components verified as complete:
   ```
   old_string: "| **Soundness** | PARTIAL |"
   new_string: "| **Soundness** | PROVEN |"
   ```

**Safety rules:**
- Skip items already annotated (contain `*(Completed:`)
- Preserve existing formatting and indentation
- One edit per item (no batch edits)
- Log skipped items for report

**Track changes:**
```json
{
  "annotations_made": 3,
  "items_skipped": 2,
  "skipped_reasons": ["already_annotated", "low_confidence"]
}
```

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

**2. Parse metadata:**

Extract timestamp and goal from the Task Order lines:

| Element | Regex | Capture Groups |
|---------|-------|----------------|
| Timestamp | `^\*Updated (\d{4}-\d{2}-\d{2})\. (.+)\*$` | (1) date, (2) changelog |
| Goal | `^\*\*Goal\*\*: (.+)$` | (1) goal text |

**3. Parse category subsections:**

For each line matching `^### (\d+)\. (.+?)(?:\s+--\s+(.+))?$`:
- Capture (1) category number, (2) category name, (3) optional subtitle
- Collect all lines until the next `###` header or end of section

**4. Parse task entries within each category:**

| Entry Type | Regex | Captures |
|------------|-------|----------|
| Ordered | `^\d+\.\s+\*\*(\d+)\*\*\s+\[([A-Z ]+)\]\s+--\s+(.+)$` | (1) task number, (2) status, (3) description |
| Unordered | `^-\s+\*\*(\d+)\*\*\s+\[([A-Z ]+)\]\s+--\s+(.+)$` | (1) task number, (2) status, (3) description |

For each matched entry, also check for inline dependency notes:
- Regex: `\(depends on ([\d,\s]+)\)`
- Extract referenced task numbers as array

**5. Parse dependency chains from code blocks:**

Within each category, find lines between `` ``` `` markers. For each line in a code block, extract all arrow pairs:
- Regex: `(\d+)\s*[→->]+\s*(\d+)` (matches both Unicode arrow and ASCII)
- Build ordered chain: `[63, 58, 59, 60]` from `63 → 58 → 59 → 60`

**6. Build dependency graph:**

From dependency chains and inline dependency notes, construct an adjacency list where each key maps to its prerequisite tasks:
```
For chain [63, 58, 59, 60]:
  63 -> [] (no prerequisites)
  58 -> [63]
  59 -> [58]
  60 -> [59]

For inline "(depends on 18)":
  20 -> [18]
```

**7. Build `task_order_state` structure:**

```json
{
  "exists": true,
  "timestamp": "2026-03-24",
  "changelog": "Task 272 completed. Created 5 tasks for /review Task Order management feature.",
  "goal": "Add Task Order section management to /review command.",
  "categories": [
    {
      "number": 1,
      "name": "Task Order Feature",
      "subtitle": "dependency chain",
      "dependency_chain": [272, 273, 274, 275, 276],
      "tasks": [
        {
          "task_number": 272,
          "status": "COMPLETED",
          "description": "Define Task Order schema and format specification",
          "list_type": "ordered",
          "inline_deps": []
        },
        {
          "task_number": 273,
          "status": "NOT STARTED",
          "description": "Add Task Order parsing to /review command (depends: 272)",
          "list_type": "ordered",
          "inline_deps": [272]
        }
      ]
    },
    {
      "number": 2,
      "name": "Other Tasks",
      "subtitle": null,
      "dependency_chain": [],
      "tasks": [
        {
          "task_number": 87,
          "status": "RESEARCHED",
          "description": "Investigate terminal directory change in wezterm",
          "list_type": "unordered",
          "inline_deps": []
        }
      ]
    }
  ],
  "all_task_numbers": [272, 273, 274, 275, 276, 87, 78],
  "dependency_graph": {
    "272": [],
    "273": [272],
    "274": [273],
    "275": [273],
    "276": [274, 275]
  }
}
```

**Error handling**: If `## Task Order` does not exist in TODO.md, set `task_order_state.exists = false` and continue review without Task Order operations. Downstream sections (pruning, insertion, interactive management) check `task_order_state.exists` before operating.

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
  "file_path": "nvim/lua/plugins/lsp.lua",
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

#### 5.5.2. Extract Grouping Indicators

For each issue, extract grouping indicators:

| Indicator | Extraction Rule |
|-----------|-----------------|
| `file_section` | Path prefix up to first-level directory (e.g., `nvim/lua/plugins/` from `nvim/lua/plugins/lsp.lua:42`) |
| `issue_type` | Map severity: Critical/High -> "fix", Medium -> "quality", Low -> "improvement". For roadmap: "roadmap" |
| `priority` | Direct from severity (Critical=4, High=3, Medium=2, Low=1) or phase priority |
| `key_terms` | Extract significant words (>4 chars, not stopwords) from description |

**Example extracted indicators:**
```json
{
  "file_section": "nvim/lua/plugins/",
  "issue_type": "fix",
  "priority": 3,
  "key_terms": ["pattern", "match", "evaluation", "incomplete"]
}
```

#### 5.5.3. Clustering Algorithm

Group issues using file_section + issue_type as primary criteria:

```
groups = []

for each issue in all_issues:
  matched = false

  # Primary match: same file_section AND same issue_type
  for each group in groups:
    if issue.file_section == group.file_section AND issue.issue_type == group.issue_type:
      add issue to group.items
      matched = true
      break

  # Secondary match: 2+ shared key_terms AND same priority
  if not matched:
    for each group in groups:
      shared_terms = intersection(issue.key_terms, group.key_terms)
      if len(shared_terms) >= 2 AND issue.priority == group.priority:
        add issue to group.items
        update group.key_terms with union
        matched = true
        break

  # No match: create new group
  if not matched:
    new_group = {
      "file_section": issue.file_section,
      "issue_type": issue.issue_type,
      "priority": issue.priority,
      "key_terms": issue.key_terms,
      "items": [issue]
    }
    append new_group to groups
```

#### 5.5.4. Group Post-Processing

Apply size limits and generate labels:

**1. Combine small groups:**
Groups with <2 items are merged into nearest match or "Other" group.

**2. Cap total groups:**
Maximum 10 groups. If exceeded, merge lowest-priority groups.

**3. Generate group labels:**

| Condition | Label Format |
|-----------|--------------|
| Has file_section | "{directory} {issue_type}s" (e.g., "Bimodal fixes") |
| Same priority, no section | "{key_term} issues" (e.g., "Proof quality issues") |
| Roadmap items | "Roadmap: {phase_name}" |
| Mixed/Other | "Other {issue_type}s" |

**4. Calculate group metadata:**
```json
{
  "label": "Bimodal fixes",
  "item_count": 3,
  "severity_breakdown": {"critical": 1, "high": 2},
  "file_list": ["Soundness.lean", "Correctness.lean"],
  "max_priority": 3,
  "total_score": 11
}
```

#### 5.5.5. Score Groups for Ordering

Sort groups by combined score:

| Factor | Score |
|--------|-------|
| Contains critical issue | +10 |
| Contains high issue | +5 |
| Group max priority: Critical | +8 |
| Group max priority: High | +6 |
| Group max priority: Medium | +4 |
| Group max priority: Low | +2 |
| Number of items (capped at 5) | +N |
| Roadmap "Near Term" items | +3 |

Sort groups by descending score.

#### 5.5.6. Interactive Group Selection (Tier 1)

Present grouped task proposals via AskUserQuestion with multiSelect:

```json
{
  "question": "Which task groups should be created?",
  "header": "Review Task Proposals",
  "multiSelect": true,
  "options": [
    {
      "label": "[Group] {group_label} ({item_count} issues)",
      "description": "{severity_breakdown} | Files: {file_list}"
    }
  ]
}
```

**Option generation:**

For each group (sorted by score):
```json
{
  "label": "[Group] Bimodal fixes (3 issues)",
  "description": "Critical: 1, High: 2 | Files: Soundness.lean, Correctness.lean"
}
```

For ungrouped individual issues (if <2 items couldn't form groups):
```json
{
  "label": "[Individual] {issue_title, truncated to 50 chars}",
  "description": "{severity} | {file}:{line}"
}
```

**Selection handling:**
- Empty selection: No tasks created, proceed to Section 6
- Any selection: Proceed to Tier 2 granularity selection

#### 5.5.7. Granularity Selection (Tier 2)

For selected groups, ask how tasks should be created:

```json
{
  "question": "How should selected groups be created as tasks?",
  "header": "Task Granularity",
  "multiSelect": false,
  "options": [
    {
      "label": "Keep as grouped tasks",
      "description": "Creates {N} tasks (one per selected group)"
    },
    {
      "label": "Expand into individual tasks",
      "description": "Creates {M} tasks (one per issue in selected groups)"
    },
    {
      "label": "Show issues and select manually",
      "description": "See all issues in selected groups for manual selection"
    }
  ]
}
```

**Option handling:**

**"Keep as grouped tasks"**: Proceed to Section 5.6 with grouped task creation.

**"Expand into individual tasks"**: Proceed to Section 5.6 with individual task creation for all issues in selected groups.

**"Show issues and select manually"**: Present Tier 3 manual selection:

```json
{
  "question": "Select individual issues to create as tasks:",
  "header": "Issue Selection",
  "multiSelect": true,
  "options": [
    {
      "label": "{issue_description, truncated to 60 chars}",
      "description": "{severity} | {file}:{line} | From: {group_label}"
    }
  ]
}
```

After manual selection, proceed to Section 5.6 with individual task creation for selected issues.

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
| `nvim/**/*.lua` | neovim |
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

**3. Add task to state.json:**
```bash
jq --arg num "$next_num" --arg slug "$slug" --arg title "$title" \
   --arg desc "$description" --arg tt "$task_type" --arg prio "$priority" \
   '.active_projects += [{
     "project_number": ($num | tonumber),
     "project_name": $slug,
     "status": "not_started",
     "task_type": $tt,
     "priority": $prio,
     "description": $title,
     "created": (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
   }] | .next_project_number = (($num | tonumber) + 1)' \
   specs/state.json > specs/state.json.tmp && mv specs/state.json.tmp specs/state.json
```

**4. Update TODO.md:**
Add task entry following existing format in TODO.md frontmatter section.

**5. Track in review state:**
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

### 6.5. Prune Task Order

Remove completed, abandoned, and superseded tasks from the Task Order section in TODO.md.

**Skip condition**: If `task_order_state.exists == false`, skip this section entirely.

#### 6.5.1. Identify Tasks to Prune

Cross-reference `task_order_state.all_task_numbers` with current statuses from state.json:

```bash
# Build list of task numbers to prune
pruned_tasks=()
for task_num in ${task_order_state.all_task_numbers[@]}; do
  status=$(jq -r --argjson n "$task_num" \
    '.active_projects[] | select(.project_number == $n) | .status' \
    specs/state.json)
  case "$status" in
    completed|abandoned)
      pruned_tasks+=("$task_num")
      ;;
  esac
done

# Also check TODO.md status markers for [EXPANDED] tasks
for task_num in ${task_order_state.all_task_numbers[@]}; do
  if grep -qE "^\#\#\# ${task_num}\." specs/TODO.md | grep -q "\[EXPANDED\]"; then
    pruned_tasks+=("$task_num")
  fi
done
```

If `pruned_tasks` is empty, skip the rest of this section (nothing to prune).

#### 6.5.2. Remove Pruned Tasks from Categories

For each category in `task_order_state.categories`:

**1. Remove matching task entries:**

For each task entry in the category whose `task_number` is in `pruned_tasks`:
- Delete the entire line (ordered or unordered entry)

**2. Renumber ordered lists:**

If the category uses ordered lists (`1.`, `2.`, `3.`...), renumber remaining entries sequentially starting from 1 after removing pruned entries.

Example before pruning (task 272 completed):
```
1. **272** [COMPLETED] -- Define Task Order schema and format specification
2. **273** [COMPLETED] -- Add Task Order parsing to /review command (depends: 272)
3. **274** [NOT STARTED] -- Add Task Order pruning (depends: 273)
```

Example after pruning:
```
1. **273** [COMPLETED] -- Add Task Order parsing to /review command (depends: 272)
2. **274** [NOT STARTED] -- Add Task Order pruning (depends: 273)
```

**3. Remove empty categories:**

If a category has zero tasks remaining after pruning, remove the entire category subsection (header, dependency chain code block if present, and all content until the next `###` header or end of Task Order section).

#### 6.5.3. Update Dependency Chains

For each dependency chain code block in `task_order_state.categories`:

**1. Remove pruned task numbers from chains:**

For a simple linear chain like `272 → 273 → 274`:
- Remove pruned numbers and reconnect neighbors
- If 272 is pruned: result is `273 → 274`
- If 273 is pruned: result is `272 → 274`

**2. Handle branching chains:**

For branching chains like:
```
272 → 273 → 274 ─┐
           └ 275 ┴→ 276
```

Remove pruned tasks and reconnect:
- If 272 is pruned, the chain starts from 273
- If a branch point is pruned, connect its predecessors to its successors

**3. Remove degenerate chains:**

- If chain becomes a single task, remove the code block entirely (the task is already listed in the category entries)
- If chain becomes empty, remove the code block

#### 6.5.4. Update Inline Dependency References

For remaining task entries that reference pruned tasks in `(depends on ...)` notes:
- Remove pruned task numbers from the dependency list
- If all dependencies are pruned, remove the `(depends: ...)` suffix entirely

Example: `(depends: 272, 273)` with 272 pruned becomes `(depends: 273)`.

#### 6.5.5. Update Timestamp

Replace the existing timestamp line with an updated one noting the pruning:

```
old_string: "*Updated {old_date}. {old_changelog}*"
new_string: "*Updated {TODAY}. Pruned {N} completed/abandoned tasks: {comma_separated_task_numbers}.*"
```

Where `{TODAY}` is the current date in YYYY-MM-DD format and `{N}` is the count of pruned tasks.

#### 6.5.6. Write Updated Task Order

Use Edit tool to replace the Task Order section content in TODO.md. Reconstruct the full section from the modified `task_order_state`:

1. Timestamp line
2. Goal line (preserved unchanged)
3. For each remaining category:
   - Category header (`### {number}. {name}` with optional subtitle)
   - Dependency chain code block (if non-degenerate)
   - Task entries (ordered or unordered)

**Safety**: Read TODO.md before and after the edit to verify the Task Order section was correctly updated and no content outside the section was affected.

### 6.6. Insert New Tasks into Task Order

Add newly created review tasks to the Task Order section in TODO.md.

**Skip condition**: If no tasks were created in Section 5.6 (i.e., `tasks_created` is empty), skip this section entirely.

#### 6.6.1. Check Task Order Existence

```
if task_order_state.exists == false:
  if tasks_created is empty:
    # No Task Order and no new tasks -- skip entirely
    skip section
  else:
    # Tasks were created but no Task Order exists -- generate a new one
    # Use generation template from task-order-format.md
    proceed to 6.6.7 (Generate New Task Order)
else:
  # Task Order exists -- proceed with insertion
  proceed to 6.6.2
```

#### 6.6.2. Determine Category Placement

Map each new task to a Task Order category based on its source and severity:

| Source / Severity | Target Category | Fallback |
|-------------------|----------------|----------|
| Critical severity review issue | "Critical Path" or first numbered category | Create "Critical Path" as category 1 |
| High severity review issue | "Critical Path" or first numbered category | Create "Critical Path" as category 1 |
| Medium severity review issue | "Code Cleanup" | Create "Code Cleanup" with next available number |
| Low severity review issue | "Backlog" | Create "Backlog" with next available number |
| Roadmap-sourced task (from Section 2.5) | Matching roadmap phase category | "Deferred" or next available number |

**Matching logic:**

```
for each new_task in tasks_created:
  # Determine target category name
  if new_task.source == "roadmap":
    target_category = find_category_matching_roadmap_phase(new_task.phase)
    if target_category is null:
      target_category = "Deferred"
  else:
    case new_task.severity:
      "critical", "high" -> target_category = "Critical Path"
      "medium"           -> target_category = "Code Cleanup"
      "low"              -> target_category = "Backlog"

  # Find matching category in task_order_state.categories
  matched = find category where category.name contains target_category (case-insensitive)

  if matched:
    assign new_task to matched category
  else:
    # Category doesn't exist -- mark for creation
    assign new_task to pending_new_categories[target_category]
```

#### 6.6.3. Generate Task Entries

For each new task, generate an unordered (bullet) Task Order entry:

**Format**: `- **{task_number}** [NOT STARTED] -- {task title}`

```
for each new_task in tasks_created:
  entry = "- **{new_task.number}** [NOT STARTED] -- {new_task.title}"

  # Add inline dependency note if task has dependencies
  if new_task.dependencies is not empty:
    # Only include deps that are in task_order_state.all_task_numbers
    relevant_deps = intersection(new_task.dependencies, task_order_state.all_task_numbers)
    if relevant_deps is not empty:
      dep_list = join(relevant_deps, ", ")
      entry = entry + " (depends on {dep_list})"
```

#### 6.6.4. Insert into Existing Categories

For each existing category that has new tasks assigned:

1. Find the last task entry line in the category (last line matching ordered or unordered task entry regex)
2. Append new entries after the last task entry

```
for each category in task_order_state.categories:
  new_entries = tasks assigned to this category
  if new_entries is empty:
    continue

  # Find insertion point: after last task entry in category
  last_entry_line = last line in category matching:
    ^\d+\.\s+\*\*\d+\*\*  (ordered)
    or
    ^-\s+\*\*\d+\*\*       (unordered)

  # Use Edit tool to insert after last_entry_line
  old_string = "{last_entry_line}"
  new_string = "{last_entry_line}\n{new_entry_1}\n{new_entry_2}..."
```

**If category has no existing entries** (empty category): Insert entries after the category header line (and after any dependency chain code block).

#### 6.6.5. Create Missing Categories

For categories that need to be created (from `pending_new_categories`):

```
# Determine next available category number
max_cat_num = max(category.number for category in task_order_state.categories)
next_cat_num = max_cat_num + 1

for each (category_name, tasks) in pending_new_categories:
  # Generate category block
  category_block = """
### {next_cat_num}. {category_name}

{task_entry_1}
{task_entry_2}
..."""

  next_cat_num += 1

  # Insert before the ## Tasks header
  # Use Edit tool:
  old_string = "\n## Tasks"
  new_string = "\n{category_block}\n\n## Tasks"
```

#### 6.6.6. Update Dependency Chains

If new tasks have dependencies on tasks already in the Task Order:

```
for each new_task in tasks_created:
  if new_task.dependencies is empty:
    continue

  relevant_deps = intersection(new_task.dependencies, task_order_state.all_task_numbers)
  if relevant_deps is empty:
    continue

  # Find which category contains the dependency
  for each dep_num in relevant_deps:
    dep_category = find category containing dep_num

    # Check if dep_category has a dependency chain code block
    if dep_category has dependency_chain:
      # Append new task to end of chain if dep is the current tail
      if dep_num == last element in dependency_chain:
        # Extend chain: add " → {new_task.number}" to last line of code block
        # Use Edit tool on the code block line
    else:
      # Create a simple chain: dep_num → new_task.number
      # Insert code block after category header, before task entries
```

**Note**: Only create/extend chains when there is a clear linear dependency. For complex graphs, rely on inline dependency notes instead.

#### 6.6.7. Generate New Task Order (when none exists)

If `task_order_state.exists == false` but tasks were created:

```
# Build a minimal Task Order section
new_section = """
## Task Order

*Updated {YYYY-MM-DD}. Created {N} tasks from review.*

**Goal**: Address review findings.

### 1. Review Issues

{task_entries from tasks_created, as unordered bullets}
"""

# Insert between "# TODO" header and "## Tasks" header
# Use Edit tool:
old_string = "\n## Tasks"
new_string = "\n{new_section}\n\n## Tasks"
```

#### 6.6.8. Update Timestamp

Append or replace the timestamp line in the Task Order section:

```
new_task_nums = join(tasks_created.map(t => t.number), ", ")
new_timestamp = "*Updated {YYYY-MM-DD}. Added {N} new tasks from review: {new_task_nums}.*"

# Use Edit tool to replace existing timestamp
old_string = "*Updated {old_date}. {old_changelog}*"
new_string = "{new_timestamp}"
```

#### 6.6.9. Write Updated Task Order

Use Edit tool to apply all changes to TODO.md. If multiple edits are needed (category insertion, new categories, timestamp), apply them in order:

1. Update timestamp (Section 6.6.8)
2. Insert entries into existing categories (Section 6.6.4)
3. Create new categories (Section 6.6.5)
4. Update dependency chains (Section 6.6.6)

**Safety**: Read TODO.md after edits to verify the Task Order section is well-formed and no content outside the section was affected.

### 6.7. Interactive Task Order Management

After automated pruning (Section 6.5) and insertion (Section 6.6), present interactive prompts so the user can override category placement, declare dependencies, and update the goal statement.

#### 6.7.1. Skip Conditions

Skip this section entirely if ALL of the following are true:
- `task_order_state.exists == false` AND no new tasks were created in Section 5.6
- No changes were made by Section 6.5 (no pruning) and no changes by Section 6.6 (no insertions)

```
changes_made = (pruned_tasks.length > 0) or (tasks_created.length > 0)
if not changes_made and not task_order_state.exists:
  skip to Section 7
```

#### 6.7.2. Present Task Order Summary

Display a summary of all Task Order changes made so far:

```
Task Order changes:
- Pruned: {pruned_tasks.length} tasks ({pruned_task_numbers})
- Added: {tasks_created.length} tasks ({new_task_numbers})
- Categories: {list of current category names from task_order_state.categories}
```

This gives the user context before making interactive decisions.

#### 6.7.3. Category Placement Override

**Condition**: Only present if `tasks_created.length > 0` (new tasks were inserted by Section 6.6).

Ask user to confirm or override the automatic category assignments:

```json
{
  "question": "Confirm category placement for new tasks?",
  "header": "Task Order Categories",
  "multiSelect": false,
  "options": [
    {
      "label": "Accept defaults",
      "description": "Keep automatic category assignments from Section 6.6"
    },
    {
      "label": "Reassign categories",
      "description": "Choose categories for each new task individually"
    },
    {
      "label": "Skip Task Order update",
      "description": "Revert all Task Order changes from this review"
    }
  ]
}
```

**Selection handling:**

**"Accept defaults"**: Proceed to Section 6.7.4 with current category assignments unchanged.

**"Reassign categories"**: For each new task, present a category selection:

```json
{
  "question": "Which category for task #{N}: {title}?",
  "header": "Category for #{N}",
  "multiSelect": false,
  "options": [
    {
      "label": "Critical Path",
      "description": "Main dependency chain - highest priority work"
    },
    {
      "label": "Code Cleanup",
      "description": "Refactoring and technical debt"
    },
    {
      "label": "Experimental",
      "description": "Uncertain outcomes, exploratory work"
    },
    {
      "label": "Deferred",
      "description": "Postponed to a future review cycle"
    },
    {
      "label": "Backlog",
      "description": "Unordered, low priority"
    }
  ]
}
```

For each task, record the user's chosen category:
```
category_overrides[task.number] = selected_category
```

Then move tasks to user-specified categories:
```
for task_num, new_category in category_overrides:
  remove task_num from its current category in task_order_state
  add task_num to new_category in task_order_state
```

**"Skip Task Order update"**: Revert all Task Order modifications from Sections 6.5 and 6.6. Restore the original Task Order content from the pre-edit snapshot. Skip Sections 6.7.4 through 6.7.6 and proceed directly to Section 7.

#### 6.7.4. Dependency Updates

**Condition**: Only present if `tasks_created.length > 0` AND `task_order_state.tasks.length > tasks_created.length` (there are both new and existing tasks).

Ask whether new tasks depend on existing tasks:

```json
{
  "question": "Do any new tasks have dependencies on existing tasks?",
  "header": "Task Dependencies",
  "multiSelect": false,
  "options": [
    {
      "label": "No dependencies",
      "description": "New tasks are independent of existing Task Order tasks"
    },
    {
      "label": "Add dependencies",
      "description": "Specify which existing tasks new tasks depend on"
    },
    {
      "label": "Skip",
      "description": "Handle dependencies manually later"
    }
  ]
}
```

**Selection handling:**

**"No dependencies"**: Proceed to Section 6.7.5 with no dependency changes.

**"Add dependencies"**: For each new task, present a multiSelect of existing tasks:

```json
{
  "question": "Which tasks does #{N}: {title} depend on? (select all that apply)",
  "header": "Dependencies for #{N}",
  "multiSelect": true,
  "options": [
    {
      "label": "Task #{X}: {title}",
      "description": "[{status}] in {category_name}"
    }
  ]
}
```

Options are generated from all tasks currently in the Task Order (both pre-existing and newly added), excluding the task being configured. Sort options by category, then by task number.

For each task, record selected dependencies:
```
new_dependencies[task.number] = [selected_task_numbers]
```

**"Skip"**: Proceed to Section 6.7.5 with no dependency changes.

#### 6.7.5. Apply Interactive Changes

Apply all collected interactive changes to the Task Order:

**Step 1: Category reassignments**
```
for task_num, new_category in category_overrides:
  # Remove entry from old category
  old_category = find_category_containing(task_num)
  remove_entry(old_category, task_num)

  # Add entry to new category (create category if missing)
  if new_category not in task_order_state.categories:
    create_category(new_category, next_category_number)
  add_entry(new_category, task_num, task_title, task_status, task_deps)
```

**Step 2: Dependency chain updates**
```
for task_num, deps in new_dependencies:
  # Update the task entry's dependency list
  update_task_deps(task_num, deps)

  # Add to dependency chain code blocks
  for dep in deps:
    append_to_chain(dep, task_num)
```

**Step 3: Renumber categories if needed**

If categories were created or emptied during reassignment:
```
# Remove empty categories (no tasks remaining)
remove_empty_categories()

# Renumber remaining categories sequentially
renumber_categories(start=1)
```

**Step 4: Regenerate dependency chain code blocks**

Rebuild all dependency chain code blocks from the updated dependency graph:
```
chains = build_dependency_chains(task_order_state)
for category in task_order_state.categories:
  if category.has_dependencies:
    update_chain_block(category, chains)
```

**Step 5: Update timestamp**
```
new_timestamp = "*Updated {YYYY-MM-DD}. Interactive Task Order management applied.*"
```

**Step 6: Write to TODO.md**

Use Edit tool to apply all changes. Read TODO.md after edits to verify well-formedness.

#### 6.7.6. Goal Statement Update

**Condition**: Only present if significant changes were made:
- 5 or more tasks changed (pruned + added + reassigned), OR
- Critical Path category was modified (tasks added, removed, or moved in/out)

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

**"Update goal"**: Ask for the new goal text:

```json
{
  "question": "Enter the new Task Order goal statement:",
  "header": "New Goal",
  "multiSelect": false,
  "options": [
    {
      "label": "Custom goal",
      "description": "Type your goal statement"
    }
  ]
}
```

Since AskUserQuestion does not support free-text input, generate 3-4 suggested goal statements based on current Task Order content:

```json
{
  "question": "Select a new goal statement:",
  "header": "New Goal",
  "multiSelect": false,
  "options": [
    {
      "label": "{auto_generated_goal_1}",
      "description": "Based on Critical Path tasks"
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

Generate goal suggestions by analyzing:
- Critical Path task titles and themes
- Distribution of tasks across categories
- Review findings from Section 3

Apply selected goal:
```
task_order_state.goal = selected_goal
# Use Edit tool to replace goal line in TODO.md
old_string = "**Goal**: {old_goal}"
new_string = "**Goal**: {selected_goal}"
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

# Add TODO.md if Task Order was pruned (even if no tasks were created)
if git diff --name-only | grep -q "specs/TODO.md"; then
  git add specs/TODO.md
fi

git commit -m "$(cat <<'EOF'
review: {scope} code review

Roadmap: {annotations_made} items annotated
Tasks: {tasks_created} created ({grouped_count} grouped, {individual_count} individual)
Task Order: {pruned_count} pruned, {inserted_count} added, {reassigned_count} reassigned

Session: {session_id}

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
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
| Grouping | Yes | file_section + issue_type clustering |
| Dependencies | Yes | Interactive dependency selection (Section 6.7.4) |
| Ordering | No | Sequential creation |
| Visualization | No | Not implemented |
| Confirmation | Yes | Implicit via selection |
| State Updates | Yes | Atomic updates (Section 5.6.3) |

**Note**: Dependency support for Task Order tasks is provided via Section 6.7.4 (Interactive Dependency Updates). Direct dependency declaration between newly created review tasks at creation time is not yet supported.

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
