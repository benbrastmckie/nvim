---
description: Archive completed and abandoned tasks
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git:*), Bash(mv:*), Bash(mkdir:*), Bash(ls:*), Bash(find:*), Bash(jq:*), TaskCreate, TaskUpdate, AskUserQuestion
argument-hint: [--dry-run]
model: opus
---

# /todo Command

Archive completed and abandoned tasks to clean up active task list.

## Arguments

- `--dry-run` - Show what would be archived without making changes

## Execution

### 1. Parse Arguments

```
dry_run = "--dry-run" in $ARGUMENTS
```

### 2. Scan for Archivable Tasks

Read specs/state.json and identify:
- Tasks with status = "completed"
- Tasks with status = "abandoned"

Read specs/TODO.md and cross-reference:
- Entries marked [COMPLETED]
- Entries marked [ABANDONED]

### 2.5. Detect Orphaned Directories

Scan for project directories not tracked in any state file.

**CRITICAL**: This step MUST be executed to identify orphaned directories.

```bash
# Get orphaned directories in specs/ (not tracked anywhere)
orphaned_in_specs=()
for dir in specs/[0-9]*_*/; do
  [ -d "$dir" ] || continue
  project_num=$(basename "$dir" | cut -d_ -f1)

  # Check if in state.json active_projects
  in_active=$(jq -r --arg n "$project_num" \
    '.active_projects[] | select(.project_number == ($n | tonumber)) | .project_number' \
    specs/state.json 2>/dev/null)

  # Check if in archive/state.json completed_projects
  in_archive=$(jq -r --arg n "$project_num" \
    '.completed_projects[] | select(.project_number == ($n | tonumber)) | .project_number' \
    specs/archive/state.json 2>/dev/null)

  # If not in either, it's an orphan
  if [ -z "$in_active" ] && [ -z "$in_archive" ]; then
    orphaned_in_specs+=("$dir")
  fi
done

# Get orphaned directories in specs/archive/ (not tracked in archive/state.json)
orphaned_in_archive=()
for dir in specs/archive/[0-9]*_*/; do
  [ -d "$dir" ] || continue
  project_num=$(basename "$dir" | cut -d_ -f1)

  # Check if in archive/state.json completed_projects
  in_archive=$(jq -r --arg n "$project_num" \
    '.completed_projects[] | select(.project_number == ($n | tonumber)) | .project_number' \
    specs/archive/state.json 2>/dev/null)

  # If not tracked, it's an orphan
  if [ -z "$in_archive" ]; then
    orphaned_in_archive+=("$dir")
  fi
done

# Combined list for archival operations
orphaned_dirs=("${orphaned_in_specs[@]}" "${orphaned_in_archive[@]}")
```

Collect orphaned directories in two categories:
- `orphaned_in_specs[]` - Directories in specs/ not tracked anywhere (will be moved to archive/)
- `orphaned_in_archive[]` - Directories in archive/ not tracked in archive/state.json (already in archive/, need state entries)

Store counts and lists for later use.

### 2.6. Detect Misplaced Directories

Scan for project directories in specs/ that ARE tracked in archive/state.json (meaning they should be in archive/ but aren't).

**CRITICAL**: This is distinct from orphans - misplaced directories have correct state entries but are in the wrong location.

```bash
# Get misplaced directories (in specs/ but tracked in archive/state.json)
misplaced_in_specs=()
for dir in specs/[0-9]*_*/; do
  [ -d "$dir" ] || continue
  project_num=$(basename "$dir" | cut -d_ -f1)

  # Skip if already identified as orphan (not tracked anywhere)
  in_active=$(jq -r --arg n "$project_num" \
    '.active_projects[] | select(.project_number == ($n | tonumber)) | .project_number' \
    specs/state.json 2>/dev/null)

  # Check if tracked in archive/state.json (should be in archive/)
  in_archive=$(jq -r --arg n "$project_num" \
    '.completed_projects[] | select(.project_number == ($n | tonumber)) | .project_number' \
    specs/archive/state.json 2>/dev/null)

  # If in archive state but not in active state, it's misplaced
  if [ -z "$in_active" ] && [ -n "$in_archive" ]; then
    misplaced_in_specs+=("$dir")
  fi
done
```

Collect misplaced directories:
- `misplaced_in_specs[]` - Directories in specs/ that are tracked in archive/state.json (need physical move only, no state update)

Store count for later reporting.

### 3. Prepare Archive List

For each archivable task, collect:
- project_number
- project_name (slug)
- status
- completion/abandonment date
- artifact paths

### 3.5. Scan Roadmap for Task References (Structured Matching)

**Ensure specs/ROADMAP.md exists** before scanning. If the file does not exist, create it with the default template:
```markdown
# Project Roadmap

## Phase 1: Current Priorities (High Priority)

- [ ] (No items yet -- add roadmap items here)

## Success Metrics

- (Define success metrics here)
```

Use structured extraction from completion_summary fields, falling back to exact `(Task {N})` matching.

**IMPORTANT**: Meta tasks (task_type: "meta") are excluded from ROADMAP.md matching. They use `claudemd_suggestions` instead (see Step 3.6).

**Step 3.5.1: Separate meta and non-meta tasks**:
```bash
# Separate archivable tasks by task_type
meta_tasks=()
non_meta_tasks=()

for task in "${archivable_tasks[@]}"; do
  task_type=$(echo "$task" | jq -r '.task_type // .language // "general"')
  if [ "$task_type" = "meta" ]; then
    meta_tasks+=("$task")
  else
    non_meta_tasks+=("$task")
  fi
done
```

**Step 3.5.2: Extract non-meta completed tasks with summaries**:
```bash
# Only process non-meta tasks for ROADMAP.md matching
# Use file-based jq filter to avoid Issue #1132 with != operator
cat > specs/tmp/todo_nonmeta_$$.jq << 'EOF'
.active_projects[] |
select(.status == "completed") |
select((.task_type // .language) != "meta") |
select(.completion_summary != null) |
{
  number: .project_number,
  name: .project_name,
  summary: .completion_summary,
  roadmap_items: (.roadmap_items // [])
}
EOF
completed_with_summaries=$(jq -rf specs/tmp/todo_nonmeta_$$.jq specs/state.json)
rm -f specs/tmp/todo_nonmeta_$$.jq
```

**Step 3.5.3: Match non-meta tasks against ROADMAP.md**:
```bash
# Initialize roadmap tracking
roadmap_matches=()
roadmap_completed_count=0
roadmap_abandoned_count=0

# Only iterate non-meta tasks for roadmap matching
for task in "${non_meta_tasks[@]}"; do
  project_num=$(echo "$task" | jq -r '.project_number')
  status=$(echo "$task" | jq -r '.status')
  completion_summary=$(echo "$task" | jq -r '.completion_summary // empty')
  explicit_items=$(echo "$task" | jq -r '.roadmap_items[]?' 2>/dev/null)

  # Priority 1: Explicit roadmap_items (highest confidence)
  if [ -n "$explicit_items" ]; then
    while IFS= read -r item_text; do
      [ -z "$item_text" ] && continue
      # Escape special regex characters for grep
      escaped_item=$(printf '%s\n' "$item_text" | sed 's/[[\.*^$()+?{|]/\\&/g')
      line_info=$(grep -n "^\s*- \[ \].*${escaped_item}" specs/ROADMAP.md 2>/dev/null | head -1 || true)
      if [ -n "$line_info" ]; then
        line_num=$(echo "$line_info" | cut -d: -f1)
        roadmap_matches+=("${project_num}:${status}:explicit:${line_num}:${item_text}")
        if [ "$status" = "completed" ]; then
          ((roadmap_completed_count++))
        fi
      fi
    done <<< "$explicit_items"
    continue  # Skip other matching methods if explicit items found
  fi

  # Priority 2: Exact (Task N) reference matching
  matches=$(grep -n "(Task ${project_num})" specs/ROADMAP.md 2>/dev/null || true)
  if [ -n "$matches" ]; then
    while IFS= read -r match_line; do
      line_num=$(echo "$match_line" | cut -d: -f1)
      item_text=$(echo "$match_line" | cut -d: -f2-)
      roadmap_matches+=("${project_num}:${status}:exact:${line_num}:${item_text}")
      if [ "$status" = "completed" ]; then
        ((roadmap_completed_count++))
      elif [ "$status" = "abandoned" ]; then
        ((roadmap_abandoned_count++))
      fi
    done <<< "$matches"
    continue
  fi

  # Priority 3: Summary-based search (for tasks with completion_summary but no explicit items)
  # Only search unchecked items for key phrases from completion_summary
  if [ -n "$completion_summary" ] && [ "$status" = "completed" ]; then
    # Extract distinctive phrases (first 3 words of summary, excluding common words)
    # This is semantic matching, not keyword heuristic - uses actual completion context
    # Implementation note: Summary-based matching is optional enhancement
    # The explicit roadmap_items field is the primary mechanism
    :
  fi
done
```

Track:
- `meta_tasks[]` - Array of meta tasks (excluded from ROADMAP.md matching)
- `non_meta_tasks[]` - Array of non-meta tasks (matched against ROADMAP.md)
- `roadmap_matches[]` - Array of task:status:match_type:line_num:item_text tuples
- `roadmap_completed_count` - Count of completed task matches
- `roadmap_abandoned_count` - Count of abandoned task matches

**Match Types**:
- `explicit` - Matched via `roadmap_items` field (highest confidence)
- `exact` - Matched via `(Task {N})` reference in ROADMAP.md
- `summary` - Matched via completion_summary content search (optional, future enhancement)

### 3.6. Scan Meta Tasks for CLAUDE.md Suggestions

Meta tasks use `claudemd_suggestions` instead of ROADMAP.md updates. This step collects suggestions for user review.

**Step 3.6.1: Extract claudemd_suggestions from meta tasks**:
```bash
# Initialize CLAUDE.md suggestion tracking
claudemd_suggestions=()
claudemd_add_count=0
claudemd_update_count=0
claudemd_remove_count=0
claudemd_none_count=0

for task in "${meta_tasks[@]}"; do
  project_num=$(echo "$task" | jq -r '.project_number')
  project_name=$(echo "$task" | jq -r '.project_name')
  status=$(echo "$task" | jq -r '.status')

  # Extract claudemd_suggestions if present (use has() instead of != null for Issue #1132)
  has_suggestions=$(echo "$task" | jq -r 'has("claudemd_suggestions")')

  if [ "$has_suggestions" = "true" ]; then
    action=$(echo "$task" | jq -r '.claudemd_suggestions.action // "none"')
    section=$(echo "$task" | jq -r '.claudemd_suggestions.section // ""')
    rationale=$(echo "$task" | jq -r '.claudemd_suggestions.rationale // ""')
    content=$(echo "$task" | jq -r '.claudemd_suggestions.content // ""')
    removes=$(echo "$task" | jq -r '.claudemd_suggestions.removes // ""')

    # Track by action type
    case "$action" in
      add)
        ((claudemd_add_count++))
        ;;
      update)
        ((claudemd_update_count++))
        ;;
      remove)
        ((claudemd_remove_count++))
        ;;
      none)
        ((claudemd_none_count++))
        ;;
    esac

    # Store suggestion for display (JSON format for structured access)
    suggestion=$(jq -n \
      --arg num "$project_num" \
      --arg name "$project_name" \
      --arg status "$status" \
      --arg action "$action" \
      --arg section "$section" \
      --arg rationale "$rationale" \
      --arg content "$content" \
      --arg removes "$removes" \
      '{
        project_number: ($num | tonumber),
        project_name: $name,
        status: $status,
        action: $action,
        section: $section,
        rationale: $rationale,
        content: $content,
        removes: $removes
      }')
    claudemd_suggestions+=("$suggestion")
  else
    # Meta task without claudemd_suggestions - note for output
    # These are treated as implicit "none" (no CLAUDE.md changes suggested)
    ((claudemd_none_count++))
  fi
done
```

Track:
- `claudemd_suggestions[]` - Array of suggestion objects from meta tasks
- `claudemd_add_count` - Count of "add" action suggestions
- `claudemd_update_count` - Count of "update" action suggestions
- `claudemd_remove_count` - Count of "remove" action suggestions
- `claudemd_none_count` - Count of "none" action or missing suggestions

**Note**: Suggestions with action "none" are acknowledged but not displayed as actionable items in the output.

### 4. Dry Run Output (if --dry-run)

```
Tasks to archive:

Completed:
- #{N1}: {title} (completed {date})
- #{N2}: {title} (completed {date})

Abandoned:
- #{N3}: {title} (abandoned {date})

Orphaned directories in specs/ (will be moved to archive/): {N}
- {N4}_{SLUG4}/
- {N5}_{SLUG5}/

Orphaned directories in archive/ (need state tracking): {N}
- {N6}_{SLUG6}/
- {N7}_{SLUG7}/

Misplaced directories in specs/ (tracked in archive/, will be moved): {N}
- {N8}_{SLUG8}/
- {N9}_{SLUG9}/

Roadmap updates (from completion summaries):

Task #{N1} ({project_name}):
  Summary: "{completion_summary}"
  Matches:
    - [ ] {item text} (line {N}) [explicit]
    - [ ] {item text 2} (line {N}) [exact]

Task #{N2} ({project_name}):
  Summary: "{completion_summary}"
  Matches:
    - [ ] {item text} (line {N}) [exact]

Task #{N3} ({project_name}) [abandoned]:
  Matches:
    - [ ] {item text} (line {N}) [exact] -> *(Task {N} abandoned)*

Total roadmap items to update: {N}
- Completed: {N}
  - Explicit matches: {N}
  - Exact matches: {N}
- Abandoned: {N}

CLAUDE.md suggestions (from meta tasks):

Task #{N4} ({project_name}) [meta]:
  Action: ADD
  Section: {section}
  Rationale: {rationale}
  Content:
    {content preview, first 3 lines}

Task #{N5} ({project_name}) [meta]:
  Action: UPDATE
  Section: {section}
  Rationale: {rationale}
  Removes: {removes}
  Content:
    {content preview}

Task #{N6} ({project_name}) [meta]:
  Action: NONE
  Rationale: {rationale}

Total CLAUDE.md suggestions: {N}
- Add: {N}
- Update: {N}
- Remove: {N}
- None (no changes needed): {N}

Note: Interactive selection will prompt for which suggestions to apply via Edit tool.

Total tasks: {N}
Total orphans: {N} (specs: {N}, archive: {N})
Total misplaced: {N}

Run without --dry-run to archive.
```

If no roadmap matches were found (from Step 3.5), omit the "Roadmap updates" section.

If no CLAUDE.md suggestions were found (from Step 3.6), omit the "CLAUDE.md suggestions" section.

If CLAUDE.md suggestions exist, the "Note: Interactive selection..." line is always shown in dry-run.

Exit here if dry run.

### 4.5. Handle Orphaned Directories (if any found)

If orphaned directories were detected in Step 2.5:

**Use AskUserQuestion**:
```json
{
  "question": "Found {N} orphaned directories not tracked in state files. What would you like to do?",
  "header": "Orphans",
  "multiSelect": false,
  "options": [
    {"label": "Track all orphans", "description": "Move to archive/ and add state entries"},
    {"label": "Skip orphans", "description": "Only archive tracked tasks"},
    {"label": "Review list first", "description": "Show full list before deciding"}
  ]
}
```

**If "Review list first" selected**, display directory list then re-ask:
```json
{
  "question": "Track these {N} orphaned directories?",
  "header": "Confirm",
  "multiSelect": false,
  "options": [
    {"label": "Yes, track all", "description": "Move to archive/ and add state entries"},
    {"label": "No, skip", "description": "Only archive tracked tasks"}
  ]
}
```

**Store the user's decision** (track_orphans = true/false) for use in Step 5.

If no orphaned directories were found, skip this step and proceed.

### 4.6. Handle Misplaced Directories (if any found)

If misplaced directories were detected in Step 2.6:

**Use AskUserQuestion**:
```json
{
  "question": "Found {N} misplaced directories in specs/ (tracked in archive/state.json). Move them?",
  "header": "Misplaced",
  "multiSelect": false,
  "options": [
    {"label": "Move all", "description": "Move to archive/ (state already correct)"},
    {"label": "Skip", "description": "Leave in current location"}
  ]
}
```

**Store the user's decision** (move_misplaced = true/false) for use in Step 5F.

If no misplaced directories were found, skip this step and proceed.

### 5. Archive Tasks

**A. Update archive/state.json**

Ensure archive directory exists:
```bash
mkdir -p specs/archive/
```

Read or create specs/archive/state.json:
```json
{
  "archived_projects": [],
  "completed_projects": []
}
```

Move each task from state.json `active_projects` to archive/state.json `completed_projects` (for completed tasks) or `archived_projects` (for abandoned tasks).

**B. Update state.json**

Remove archived tasks from active_projects array using `del()` pattern (avoids Issue #1132 with `!=` operator):
```bash
# Use del() instead of map(select(.status != "completed" and .status != "abandoned"))
# This pattern is Issue #1132-safe
jq 'del(.active_projects[] | select(.status == "completed" or .status == "abandoned"))' \
  specs/state.json > specs/state.json.tmp && mv specs/state.json.tmp specs/state.json
```

**C. Update TODO.md**

Remove archived task entries from main sections.

**D. Move Project Directories to Archive**

**CRITICAL**: This step MUST be executed - do not skip it.

For each archived task (completed or abandoned):
```bash
# Variables from task data
project_number={N}
project_name={SLUG}

# Compute padded number for consistent directory naming
padded_num=$(printf "%03d" "$project_number")

# Check padded directory first, then fall back to unpadded for legacy
if [ -d "specs/${padded_num}_${project_name}" ]; then
  src="specs/${padded_num}_${project_name}"
elif [ -d "specs/${project_number}_${project_name}" ]; then
  src="specs/${project_number}_${project_name}"
else
  src=""
fi

# Always archive to padded directory
dst="specs/archive/${padded_num}_${project_name}"

if [ -n "$src" ] && [ -d "$src" ]; then
  mv "$src" "$dst"
  echo "Moved: $(basename "$src") -> archive/${padded_num}_${project_name}/"
  # Track this move for output reporting
else
  echo "Note: No directory for task ${project_number} (skipped)"
  # Track this skip for output reporting
fi
```

Track:
- directories_moved: list of successfully moved directories
- directories_skipped: list of tasks without directories

**E. Track Orphaned Directories (if approved in Step 4.5)**

If user selected "Track all orphans" (track_orphans = true):

**Step E.1: Move orphaned directories from specs/ to archive/**
```bash
for orphan_dir in "${orphaned_in_specs[@]}"; do
  dir_name=$(basename "$orphan_dir")
  mv "$orphan_dir" "specs/archive/${dir_name}"
  echo "Moved orphan: ${dir_name} -> archive/"
done
```

**Step E.2: Add state entries for ALL orphans (both moved and existing in archive/)**
```bash
for orphan_dir in "${orphaned_dirs[@]}"; do
  dir_name=$(basename "$orphan_dir")
  project_num=$(echo "$dir_name" | cut -d_ -f1)
  project_name=$(echo "$dir_name" | cut -d_ -f2-)

  # Determine archive path (after potential move)
  archive_path="specs/archive/${dir_name}"

  # Scan for existing artifacts
  artifacts="[]"
  [ -d "$archive_path/reports" ] && artifacts=$(echo "$artifacts" | jq '. + ["reports/"]')
  [ -d "$archive_path/plans" ] && artifacts=$(echo "$artifacts" | jq '. + ["plans/"]')
  [ -d "$archive_path/summaries" ] && artifacts=$(echo "$artifacts" | jq '. + ["summaries/"]')

  # Add entry to archive/state.json
  jq --arg num "$project_num" \
     --arg name "$project_name" \
     --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     --argjson arts "$artifacts" \
     '.completed_projects += [{
       project_number: ($num | tonumber),
       project_name: $name,
       status: "orphan_archived",
       archived: $date,
       source: "orphan_recovery",
       detected_artifacts: $arts
     }]' specs/archive/state.json > specs/archive/state.json.tmp \
  && mv specs/archive/state.json.tmp specs/archive/state.json

  echo "Added state entry for orphan: ${dir_name}"
done
```

Track orphan operations for output reporting:
- orphans_moved: count of directories moved from specs/ to archive/
- orphans_tracked: count of state entries added to archive/state.json

**F. Move Misplaced Directories (if approved in Step 4.6)**

If user selected "Move all" (move_misplaced = true):

```bash
# Move misplaced directories from specs/ to archive/
misplaced_moved=0
for dir in "${misplaced_in_specs[@]}"; do
  dir_name=$(basename "$dir")
  dst="specs/archive/${dir_name}"

  # Check if destination already exists
  if [ -d "$dst" ]; then
    echo "Warning: ${dir_name} already exists in archive/, skipping"
    continue
  fi

  mv "$dir" "$dst"
  echo "Moved misplaced: ${dir_name} -> archive/"
  ((misplaced_moved++))
done
```

**Note**: Unlike orphans, misplaced directories do NOT need state entries added - they are already correctly tracked in archive/state.json. Only the physical move is needed.

Track misplaced operations for output reporting:
- misplaced_moved: count of directories moved from specs/ to archive/

### 5.5. Update Roadmap for Archived Tasks

**Context**: Load @.claude/context/patterns/roadmap-update.md for matching strategy.

For each archived task with roadmap matches (from Step 3.5):

**1. Read current ROADMAP.md content**

**2. Parse match tuple** (from Step 3.5):
```bash
# roadmap_matches[] entries are: project_num:status:match_type:line_num:item_text
# Parse components
project_num=$(echo "$match" | cut -d: -f1)
status=$(echo "$match" | cut -d: -f2)
match_type=$(echo "$match" | cut -d: -f3)  # explicit, exact, or summary
line_num=$(echo "$match" | cut -d: -f4)
item_text=$(echo "$match" | cut -d: -f5-)
```

**3. For each match, determine if already annotated**:
```bash
# Skip if already has completion or abandonment annotation
if echo "$line_content" | grep -qE '\*(Completed:|\*(Abandoned:|\*(Task [0-9]+ abandoned:'; then
  echo "Skipped: Line $line_num already annotated"
  ((roadmap_skipped++))
  continue
fi
```

**4. Apply appropriate annotation based on match type**:

For completed tasks with **explicit** match (via roadmap_items):
```
Edit old_string: "- [ ] {item_text}"
     new_string: "- [x] {item_text} *(Completed: Task {N}, {DATE})*"
```

For completed tasks with **exact** match (via Task N reference):
```
Edit old_string: "- [ ] {item_text} (Task {N})"
     new_string: "- [x] {item_text} (Task {N}) *(Completed: Task {N}, {DATE})*"
```

For abandoned tasks (checkbox stays unchecked):
```
Edit old_string: "- [ ] {item_text} (Task {N})"
     new_string: "- [ ] {item_text} (Task {N}) *(Task {N} abandoned: {short_reason})*"
```

**5. Track changes**:
```json
{
  "roadmap_updates": {
    "completed_annotated": 2,
    "abandoned_annotated": 1,
    "skipped_already_annotated": 1,
    "by_match_type": {
      "explicit": 1,
      "exact": 1,
      "summary": 0
    }
  }
}
```

Track roadmap operations for output reporting:
- roadmap_completed_annotated: count of completed task items marked
- roadmap_abandoned_annotated: count of abandoned task items annotated
- roadmap_skipped: count of items skipped (already annotated)
- roadmap_by_match_type: breakdown by match type (explicit/exact/summary)

**Safety Rules** (from roadmap-update.md):
- Skip items already containing `*(Completed:` or `*(Task` annotations
- Preserve existing formatting and indentation
- One edit per item (no batch edits to same line)
- Never remove existing content

### 5.6. Interactive CLAUDE.md Suggestion Selection for Meta Tasks

For meta tasks with `claudemd_suggestions` (from Step 3.6), use interactive selection to apply suggestions via the Edit tool.

**Step 5.6.1: Filter actionable suggestions**:

Build list of suggestions where action is NOT "none":
```bash
actionable_suggestions=()
for suggestion in "${claudemd_suggestions[@]}"; do
  action=$(echo "$suggestion" | jq -r '.action')
  if [ "$action" != "none" ]; then
    actionable_suggestions+=("$suggestion")
  fi
done
```

If no actionable suggestions exist, skip to Step 5.6.5 (handle "none" actions only).

**Step 5.6.2: Interactive selection via AskUserQuestion**:

If `actionable_suggestions[]` has any entries:

```json
{
  "question": "Found {N} CLAUDE.md suggestions from meta tasks. Which should be applied?",
  "header": "CLAUDE.md Updates",
  "multiSelect": true,
  "options": [
    {"label": "Task #{N1}: {ACTION} to {section}", "description": "{rationale}"},
    {"label": "Task #{N2}: {ACTION} to {section}", "description": "{rationale}"},
    {"label": "Skip all", "description": "Don't apply any (display for manual review)"}
  ]
}
```

Build options dynamically from `actionable_suggestions[]`:
```bash
options=()
for suggestion in "${actionable_suggestions[@]}"; do
  project_num=$(echo "$suggestion" | jq -r '.project_number')
  action=$(echo "$suggestion" | jq -r '.action | ascii_upcase')
  section=$(echo "$suggestion" | jq -r '.section')
  rationale=$(echo "$suggestion" | jq -r '.rationale')

  label="Task #${project_num}: ${action} to ${section}"
  options+=("{\"label\": \"$label\", \"description\": \"$rationale\"}")
done
# Always add "Skip all" as last option
options+=("{\"label\": \"Skip all\", \"description\": \"Don't apply any suggestions (display only for manual review)\"}")
```

Store user selection for Step 5.6.3.

**Step 5.6.3: Apply selected suggestions via Edit tool**:

For each selected suggestion (excluding "Skip all"):

1. Parse suggestion data:
```bash
project_num=$(echo "$suggestion" | jq -r '.project_number')
action=$(echo "$suggestion" | jq -r '.action')
section=$(echo "$suggestion" | jq -r '.section')
content=$(echo "$suggestion" | jq -r '.content // empty')
removes=$(echo "$suggestion" | jq -r '.removes // empty')
```

2. Read current `.claude/CLAUDE.md` content

3. Apply Edit based on action type:

**For ADD action**:
- Find section header (e.g., "## {section}" or "### {section}")
- Edit: Insert content after the section header line
- old_string: The section header line + following newline
- new_string: The section header line + newline + content + newline

**For UPDATE action**:
- Edit: Replace `removes` text with `content`
- old_string: `{removes}`
- new_string: `{content}`

**For REMOVE action**:
- Edit: Remove the `removes` text
- old_string: `{removes}`
- new_string: "" (empty)

4. Track result for each edit:
```bash
applied_suggestions=()
failed_suggestions=()

# After each edit attempt:
if edit_succeeded; then
  applied_suggestions+=("${project_num}:${action}:${section}")
else
  failed_suggestions+=("${project_num}:${action}:${section}:${error_reason}")
fi
```

**Step 5.6.4: Display results of applied changes**:

```
CLAUDE.md suggestions applied: {N}
- Task #{N1}: Added {section}
- Task #{N2}: Updated {section}
- Task #{N3}: Removed {section}

{If any failed:}
Failed to apply {N} suggestions:
- Task #{N4}: Section "{section}" not found
- Task #{N5}: Text to remove not found in file

{If "Skip all" was selected:}
CLAUDE.md suggestions skipped by user: {N}
The following suggestions are available for manual review:
- Task #{N1}: ADD to {section} - {rationale}
- Task #{N2}: UPDATE {section} - {rationale}
```

**Step 5.6.5: Handle tasks with "none" action**:

For meta tasks with action "none" (or missing `claudemd_suggestions`), output brief acknowledgment:

```
Meta tasks with no CLAUDE.md changes:
- Task #{N1} ({project_name}): {rationale}
- Task #{N2} ({project_name}): No claudemd_suggestions field
```

Track suggestion operations for output reporting:
- claudemd_applied: count of successfully applied suggestions
- claudemd_failed: count of failed edit attempts
- claudemd_skipped: count of suggestions skipped by user selection
- claudemd_none_acknowledged: count of "none" action tasks acknowledged

### 5.7. Sync Repository Metrics

Update repository-wide metrics in both state.json and TODO.md header.

**Step 5.7.1: Compute current metrics**:
```bash
# Count TODOs in Lua files
todo_count=$(grep -r "TODO" nvim/lua/ --include="*.lua" | wc -l)

# Count FIXME markers
fixme_count=$(grep -r "FIXME" nvim/lua/ --include="*.lua" | wc -l)

# Get current timestamp
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Build errors (0 if nvim starts successfully)
if nvim --headless -c "quit" 2>/dev/null; then
  build_errors=0
else
  build_errors=1
fi
```

**Step 5.7.2: Update state.json repository_health**:
```bash
jq --arg todo "$todo_count" \
   --arg fixme "$fixme_count" \
   --arg ts "$ts" \
   --arg errors "$build_errors" \
   '.repository_health = {
     "last_assessed": $ts,
     "todo_count": ($todo | tonumber),
     "fixme_count": ($fixme | tonumber),
     "build_errors": ($errors | tonumber),
     "status": (if ($build_errors | tonumber) == 0 then "healthy" else "needs_attention" end)
   }' specs/state.json > specs/state.json.tmp && mv specs/state.json.tmp specs/state.json
```

**Step 5.7.3: Update TODO.md frontmatter**:

Read TODO.md and update the YAML frontmatter `technical_debt` section to match state.json:
```bash
# Using Edit tool to update TODO.md frontmatter
# old_string: current technical_debt block
# new_string: updated technical_debt block with current values
```

The technical_debt block should be updated to:
```yaml
technical_debt:
  todo_count: {todo_count}
  fixme_count: {fixme_count}
  build_errors: {build_errors}
  status: {status}
```

Also update `last_assessed` in repository_health:
```yaml
repository_health:
  overall_score: 90
  production_readiness: improved
  last_assessed: {ts}
```

**Step 5.7.4: Report metrics sync**:
Track for output:
- `metrics_todo_count`: Current TODO count
- `metrics_fixme_count`: Current FIXME count
- `metrics_build_errors`: Current build errors
- `metrics_synced`: true/false indicating if sync was performed

### 5.8. Vault Operation (when next_project_number > 1000)

When `next_project_number` exceeds 1000, initiate vault archival operation to reset task numbering.

**Step 5.8.1: Detect vault threshold**:
```bash
next_num=$(jq -r '.next_project_number' specs/state.json)
if [ "$next_num" -gt 1000 ]; then
  vault_needed=true
fi
```

**Step 5.8.2: Identify tasks to renumber**:
```bash
# Find active tasks with project_number > 1000
tasks_to_renumber=$(jq -r '
  .active_projects[] |
  select(.project_number > 1000) |
  {
    old_number: .project_number,
    new_number: (.project_number - 1000),
    project_name: .project_name
  }
' specs/state.json)

renumber_count=$(echo "$tasks_to_renumber" | jq -s 'length')
```

**Step 5.8.3: User confirmation**:

Use AskUserQuestion with vault operation details:
```json
{
  "question": "Task numbering has exceeded 1000. Initiate vault archival?",
  "header": "Vault Operation",
  "description": "Current next_project_number: {next_num}\nActive tasks to renumber: {renumber_count}\n\nThis will:\n1. Move specs/archive/ to specs/vault/{NN-vault}/\n2. Renumber tasks > 1000 by subtracting 1000\n3. Reset next_project_number",
  "options": [
    {"label": "Yes, proceed with vault operation", "value": "proceed"},
    {"label": "No, skip vault this time", "value": "skip"}
  ]
}
```

If user selects "skip", proceed to Step 6 (Git Commit).

**Step 5.8.4: Create vault directory**:
```bash
vault_count=$(jq -r '.vault_count // 0' specs/state.json)
new_vault_num=$((vault_count + 1))
vault_dir_name=$(printf "%02d-vault" "$new_vault_num")
vault_path="specs/vault/${vault_dir_name}"

mkdir -p "$vault_path"
mv "specs/archive" "${vault_path}/archive"
mv "${vault_path}/archive/state.json" "${vault_path}/state.json"
```

**Step 5.8.5: Create vault meta.json**:
```bash
current_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
archived_count=$(jq -r '.completed_projects | length' "${vault_path}/state.json" 2>/dev/null || echo "0")

jq -n \
  --arg vault_num "$new_vault_num" \
  --arg created_at "$current_timestamp" \
  --argjson archived_count "$archived_count" \
  --argjson final_task_num "$next_num" \
  '{
    vault_number: ($vault_num | tonumber),
    created_at: $created_at,
    archived_count: $archived_count,
    final_task_number: $final_task_num
  }' > "${vault_path}/meta.json"
```

**Step 5.8.6: Reinitialize archive**:
```bash
mkdir -p "specs/archive"
jq -n '{ "completed_projects": [] }' > "specs/archive/state.json"
```

**Step 5.8.7: Renumber tasks > 1000**:

For each task with project_number > 1000:
1. Update state.json project_number (subtract 1000)
2. Update artifact paths (4-digit dir -> 3-digit dir)
3. Update dependencies arrays
4. Rename task directories
5. Update TODO.md entries

**Step 5.8.8: Reset state**:
```bash
# Calculate new next_project_number
max_active=$(jq -r '[.active_projects[].project_number] | max // 0' specs/state.json)
new_next_num=$((max_active + 1))

# Update state.json
jq --argjson new_next "$new_next_num" \
   --argjson vault_num "$new_vault_num" \
   --arg vault_path "$vault_path/" \
   --arg created "$current_timestamp" \
   '.next_project_number = $new_next |
    .vault_count = (.vault_count // 0) + 1 |
    .vault_history = (.vault_history // []) + [{
      vault_number: $vault_num,
      vault_dir: $vault_path,
      created_at: $created
    }]' specs/state.json > specs/state.json.tmp
mv specs/state.json.tmp specs/state.json
```

**Step 5.8.9: Add transition comment to TODO.md**:
```bash
current_date=$(date +"%Y-%m-%d")
comment="<!-- Vault transition: ${current_date} - Archived to ${vault_path}/ -->"
# Insert after frontmatter
```

Track vault operations for output:
- `vault_created`: true/false
- `vault_path`: path to new vault
- `tasks_renumbered`: count of tasks renumbered
- `new_next_project_number`: reset value

### 6. Git Commit

```bash
git add specs/
git commit -m "todo: archive {N} completed tasks"
```

Include roadmap, orphan, and misplaced counts in message as applicable:
```bash
# If roadmap items updated, orphans tracked, and misplaced moved:
git commit -m "todo: archive {N} tasks, update {R} roadmap items, track {M} orphans, move {P} misplaced"

# If roadmap items updated only:
git commit -m "todo: archive {N} tasks, update {R} roadmap items"

# If roadmap items updated and orphans tracked:
git commit -m "todo: archive {N} tasks, update {R} roadmap items, track {M} orphaned directories"

# If orphans tracked and misplaced moved (no roadmap):
git commit -m "todo: archive {N} tasks, track {M} orphans, move {P} misplaced directories"

# If only orphans tracked (no roadmap):
git commit -m "todo: archive {N} tasks and track {M} orphaned directories"

# If only misplaced moved (no roadmap):
git commit -m "todo: archive {N} tasks and move {P} misplaced directories"
```

Where `{R}` = roadmap_completed_annotated + roadmap_abandoned_annotated (total roadmap items updated).

### 7. Output

Use grouped counts instead of listing individual items:

```
Archived {N} tasks

Tasks: {C} completed, {A} abandoned
Directories: {D} moved

{If orphans or misplaced processed:}
Cleanup: {O} orphans tracked, {P} misplaced moved

{If roadmap updated:}
Roadmap: {R} items updated

{If CLAUDE.md suggestions:}
CLAUDE.md: {applied}/{total} suggestions applied

Active tasks remaining: {N}

Next Steps:
1. Review archive at specs/archive/
2. Run /review for codebase analysis
```

**Section Inclusion Rules:**

| Section | Show When |
|---------|-----------|
| Tasks | Always (with counts) |
| Directories | directories_moved > 0 |
| Cleanup | orphans_tracked > 0 OR misplaced_moved > 0 |
| Roadmap | roadmap items updated |
| CLAUDE.md | claudemd_suggestions processed |

If no roadmap items were updated (no matches found in Step 3.5):
- Omit the "Roadmap updated" section

If no CLAUDE.md suggestions were collected (no meta tasks or all had "none" action):
- Omit the "CLAUDE.md suggestions applied/failed/skipped" sections

If all CLAUDE.md suggestions were successfully applied:
- Omit the "CLAUDE.md suggestions failed" section

If no suggestions were skipped (all selected or "Skip all" not chosen):
- Omit the "CLAUDE.md suggestions skipped" section

## Notes

### Task Archival
- Artifacts (plans, reports, summaries) are preserved in archive/{NNN}_{SLUG}/
- Tasks can be recovered with `/task --recover N`
- Archive is append-only (for audit trail)
- Run periodically to keep TODO.md and specs/ manageable

### Orphan Tracking

**Orphan Categories**:
1. **Orphaned in specs/** - Directories in `specs/` not tracked in any state file
   - Action: Move to archive/ AND add entry to archive/state.json
2. **Orphaned in archive/** - Directories in `specs/archive/` not tracked in archive/state.json
   - Action: Add entry to archive/state.json (no move needed)

**orphan_archived Status**:
- Orphaned directories receive status `"orphan_archived"` in archive/state.json
- The `source` field is set to `"orphan_recovery"` to distinguish from normal archival
- The `detected_artifacts` field lists any existing subdirectories (reports/, plans/, summaries/)

**Recovery**:
- Orphaned directories with state entries can be inspected in archive/
- Manual recovery is possible by moving directories and updating state files
- Use `/task --recover N` only for tracked tasks (not orphans)

### Misplaced Directories

**Definition**: Directories in `specs/` that ARE tracked in `archive/state.json`.

This indicates the directory was archived in state but never physically moved.

**Directory Categories Summary**:

| Category | Location | Tracked in state.json? | Tracked in archive/state.json? | Action |
|----------|----------|------------------------|--------------------------------|--------|
| Active | specs/ | Yes | No | Normal (no action) |
| Orphaned in specs/ | specs/ | No | No | Move + add state entry |
| Orphaned in archive/ | archive/ | No | No | Add state entry only |
| Misplaced | specs/ | No | Yes | Move only (state correct) |
| Archived | archive/ | No | Yes | Normal (no action) |

**Misplaced Directories**:
- Already have correct state entries in archive/state.json
- Only need to be physically moved to specs/archive/
- No state updates required

**Causes of Misplaced Directories**:
- Directory move failed silently during previous archival
- Manual state edits without corresponding directory moves
- System interrupted during archival process
- /todo command Step 5D not executing consistently

**Recovery**:
- Use `/task --recover N` to recover misplaced directories (they have valid state entries)
- After moving, the directory will be in the correct location matching its state

### Roadmap Updates

**Matching Strategy** (Structured Synchronization):

Roadmap matching uses structured data from completed tasks, not keyword heuristics:

1. **Explicit roadmap_items** (Priority 1, highest confidence):
   - Tasks can include a `roadmap_items` array in state.json
   - Contains exact item text to match against ROADMAP.md
   - Example: `"roadmap_items": ["Improve /todo command roadmap updates"]`

2. **Exact (Task N) references** (Priority 2):
   - Searches ROADMAP.md for `(Task {N})` patterns
   - Works with existing roadmap items that reference task numbers

3. **Summary-based search** (Future enhancement):
   - Uses `completion_summary` field to find semantically related items
   - Not currently implemented (placeholder for future)

**Producer/Consumer Workflow**:
- `/implement` is the **producer**: populates `completion_summary` and optional `roadmap_items`
- `/todo` is the **consumer**: extracts these fields via jq and matches against ROADMAP.md

**Annotation Formats**:

Completed tasks with explicit match:
```markdown
- [x] {item text} *(Completed: Task {N}, {DATE})*
```

Completed tasks with exact (Task N) match:
```markdown
- [x] {item text} (Task {N}) *(Completed: Task {N}, {DATE})*
```

Abandoned tasks (checkbox stays unchecked):
```markdown
- [ ] {item text} (Task {N}) *(Task {N} abandoned: {short_reason})*
```

**Safety Rules**:
- Skip items already annotated (contain `*(Completed:` or `*(Task` patterns)
- Preserve existing formatting and indentation
- One edit per item
- Never remove existing content

**Date Format**: ISO date (YYYY-MM-DD) from task completion/abandonment timestamp

**Abandoned Reason**: Truncated to first 50 characters of `abandoned_reason` field from state.json

**Well-Formed Completion Summaries**:

Good examples:
- "Implemented structured synchronization between task completion data and roadmap updates. Added completion_summary field to task schema."
- "Fixed modal logic proof for reflexive frames. Added missing transitivity lemma and updated test cases."
- "Created LaTeX documentation for Logos layer architecture with diagrams and examples."

The summary should:
- Be 1-3 sentences describing what was accomplished
- Focus on outcomes, not process
- Be specific enough to enable roadmap matching

### Interactive CLAUDE.md Application

**Overview**:
Meta tasks use `claudemd_suggestions` to propose documentation changes. Unlike ROADMAP.md updates (which are automatic), CLAUDE.md suggestions use interactive selection.

**Workflow**:
1. Actionable suggestions (ADD/UPDATE/REMOVE) are collected from completed meta tasks
2. User is presented with AskUserQuestion multiSelect prompt
3. Selected suggestions are applied via the Edit tool
4. Results show applied, failed, and skipped counts

**Action Types**:
- **ADD**: Inserts content after a section header
- **UPDATE**: Replaces existing text with new content
- **REMOVE**: Deletes specified text

**"Skip all" Option**:
Users can choose "Skip all" to decline automatic application. Suggestions are then displayed for manual review (preserving the previous behavior).

**Edit Failure Handling**:
If an Edit operation fails (section not found, text mismatch), the failure is logged and reported. The user can manually apply the suggestion afterward.

### jq Pattern Safety (Issue #1132)

**Problem**: Claude Code Issue #1132 causes jq commands with `!=` operators to fail with `INVALID_CHARACTER` or syntax errors when Claude generates them inline.

**Solution**: This command uses safe jq patterns throughout:

1. **File-based filters** for `!=` operators:
   ```bash
   # Instead of: jq 'select((.task_type // .language) != "meta")' file
   cat > specs/tmp/filter_$$.jq << 'EOF'
   select((.task_type // .language) != "meta")
   EOF
   jq -f specs/tmp/filter_$$.jq file && rm -f specs/tmp/filter_$$.jq
   ```

2. **`has()` for null checks**:
   ```bash
   # Instead of: jq 'select(.field != null)'
   jq 'select(has("field"))'
   ```

3. **`del()` for exclusion filters**:
   ```bash
   # Instead of: jq '.array |= map(select(.status != "completed"))'
   jq 'del(.array[] | select(.status == "completed"))'
   ```

**Reference**: See `.claude/context/patterns/jq-escaping-workarounds.md` for comprehensive patterns.
