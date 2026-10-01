---
description: Archive completed, abandoned, and expanded tasks
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git:*), Bash(mv:*), Bash(mkdir:*), Bash(ls:*), Bash(find:*), Bash(jq:*), TaskCreate, TaskUpdate, AskUserQuestion
argument-hint: "[--dry-run]"
model: sonnet
---

# /todo Command

Archive completed, abandoned, and expanded tasks to clean up active task list.

## Arguments

- `--dry-run` - Show what would be archived without making changes

## Execution

### 1. Parse Arguments

```
dry_run = "--dry-run" in $ARGUMENTS
```

`/todo` has no `command-gate-in.sh` call and no `session_id` of its own — generate one once
near the top of this run, following the same self-generating fallback used elsewhere
(`manage-topics.sh`; also formerly used by the now-quarantined `archive-task` script under
`scripts/deprecated/`), and thread that single value through every `state-write.sh` call below:
```bash
source .claude/scripts/lib/common.sh
session_id="$(common_session_id)"
```

### 2. Scan for Archivable Tasks

Read specs/state.json and identify:
- Tasks with status = "completed"
- Tasks with status = "abandoned"
- Tasks with status = "expanded"

Read specs/TODO.md and cross-reference:
- Entries marked [COMPLETED]
- Entries marked [ABANDONED]
- Entries marked [EXPANDED]

**VERIFIED, not guarded**: this selection and Step 5A's archive-write jq (`.completed_projects =
... select(.status == "completed" or .status == "expanded") ...` /
`.archived_projects = ... select(.status == "abandoned") ...`) both POSITIVE-match only
`completed`/`abandoned`/`expanded`, so a `hold`-status task is excluded from the archive set by
construction at two independent points -- no redundant hold-specific guard is added.

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

For each archivable task, collect into `candidate_tasks[]`:
- project_number
- project_name (slug)
- status
- completion/abandonment date
- artifact paths

**Subtasks-defer guard**: partition `candidate_tasks[]` into `archivable_tasks[]` (proceeds) and
`deferred_expanded[]` (held back for a later `/todo` run). An expanded parent is deferred while
any task listed in its `subtasks[]` is still present in `active_projects` with a non-terminal
status — this lets a subtask still being worked read its parent's artifacts in place. Use a
`case` statement for status classification. READ
`.claude/context/patterns/jq-escaping-workarounds.md` before writing the classification logic
below — it carries the safe jq/shell escaping patterns this guard depends on (never `!=`):

```bash
archivable_tasks=()
deferred_expanded=()
deferred_expanded_nums=()
deferred_expanded_detail=()   # one entry per deferred parent, naming WHICH subtask(s) block it
                               # and why (Decision 6 mitigation -- a reporting improvement only;
                               # the blocking case statement below is unchanged, and a held
                               # subtask continues to block exactly as every other non-terminal
                               # status does)

for task in "${candidate_tasks[@]}"; do
  status=$(echo "$task" | jq -r '.status')
  project_num=$(echo "$task" | jq -r '.project_number')

  case "$status" in
    expanded)
      # A missing, null, or empty subtasks array means nothing is blocking - archive normally.
      subtasks=$(echo "$task" | jq -c '.subtasks // []')
      subtask_count=$(echo "$subtasks" | jq 'length')
      if [ "$subtask_count" -eq 0 ]; then
        archivable_tasks+=("$task")
        continue
      fi

      blocking_count=0
      for subtask_num in $(echo "$subtasks" | jq -r '.[]'); do
        subtask_status=$(jq -r --argjson n "$subtask_num" \
          '.active_projects[] | select(.project_number == $n) | .status' \
          specs/state.json)

        # An empty result means the subtask is already archived - not blocking.
        if [ -z "$subtask_status" ]; then
          continue
        fi

        # AUDITED (not a three-category gap like commands/orchestrate.md's STAGE 0 arm): this
        # case statement governs archival CANDIDACY of the PARENT via its subtasks' statuses --
        # it is not a dispatch gate a held task needs to "reach". A held subtask correctly falls
        # to the `*)` catch-all below and continues to block its parent's archival exactly as any
        # other non-terminal status does (Decision 6: correct as-is -- a parent with paused work
        # genuinely is not done). Nothing to restructure here; the Decision 6 mitigation is the
        # reporting-detail addition above/below, not a change to this classification.
        case "$subtask_status" in
          completed|abandoned|expanded)
            # Terminal - not blocking.
            ;;
          *)
            # Any other status blocks.
            ((blocking_count++))
            ;;
        esac
      done

      if [ "$blocking_count" -gt 0 ]; then
        deferred_expanded+=("$task")
        deferred_expanded_nums+=("$project_num")
        # Reporting-only detail pass (Decision 6 mitigation): names which subtask(s) are
        # blocking and, for a held one specifically, its hold_reason -- so the operator reads
        # "subtask 123 is held (reason: ...)" rather than a generic "still active" line. This is
        # a SEPARATE pass over the same subtasks[] already resolved above; it does not re-decide
        # blocking and does not alter the case statement above.
        detail_parts=()
        for subtask_num in $(echo "$subtasks" | jq -r '.[]'); do
          d_status=$(jq -r --argjson n "$subtask_num" \
            '.active_projects[] | select(.project_number == $n) | .status' \
            specs/state.json)
          [ -z "$d_status" ] && continue
          case "$d_status" in
            completed|abandoned|expanded) ;;
            hold)
              d_reason=$(jq -r --argjson n "$subtask_num" \
                '.active_projects[] | select(.project_number == $n) | .hold_reason // "no reason recorded"' \
                specs/state.json)
              detail_parts+=("subtask $subtask_num is held (reason: $d_reason)")
              ;;
            *)
              detail_parts+=("subtask $subtask_num is $d_status")
              ;;
          esac
        done
        deferred_expanded_detail+=("$project_num: $(IFS='; '; echo "${detail_parts[*]}")")
      else
        archivable_tasks+=("$task")
      fi
      ;;
    *)
      # Non-expanded tasks pass through untouched.
      archivable_tasks+=("$task")
      ;;
  esac
done
```

`deferred_expanded_nums[]` (bare project numbers) is consumed by Step 5B's `del()` filter below,
so a deferred parent's archive-list entry is held back WITHOUT the parent being deleted from
`active_projects`. Step 5A (archive/state.json insertion) and Step 5D (directory move) both
iterate `archivable_tasks[]` — the guard-filtered list — never a freshly-recomputed status match.

### 3.5. Scan Roadmap for Task References (Structured Matching)

**Do NOT auto-create `specs/ROADMAP.md`** if it is absent before scanning. An absent roadmap is
"no roadmap tracked" -- a supported state, not a repair trigger; `roadmap-integration.sh` itself
treats absence this way (exits 0, emits the `roadmap_absent` warning below, and does not
recreate the file). Re-creating the file here, ahead of the script call, would silently defeat
that contract and make any deliberate deletion of the roadmap never stick.

**IMPORTANT**: Meta tasks (task_type: "meta") are excluded from ROADMAP.md matching since they
modify system infrastructure rather than project deliverables. Expanded tasks are excluded for a
structural reason: an expanded task has no `completion_summary` of its own by construction (its
subtasks carry the deliverables), so a future reader must not "fix" this by requiring one.
`roadmap-integration.sh` has no `task_type` filter and no abandoned-status branch of its own (see
its header's "Caller contract" section), so this exclusion partition is entirely `/todo`'s
responsibility -- the script cannot do it for us.

**Step 3.5.1: Separate roadmap-excluded and roadmap-eligible tasks**:
```bash
# Separate archivable tasks: excluded from ROADMAP.md matching vs. eligible for it
roadmap_excluded_tasks=()
roadmap_eligible_tasks=()

for task in "${archivable_tasks[@]}"; do
  task_type=$(echo "$task" | jq -r '.task_type // "general"')
  task_status=$(echo "$task" | jq -r '.status')
  if [ "$task_type" = "meta" ] || [ "$task_status" = "expanded" ]; then
    roadmap_excluded_tasks+=("$task")
  else
    roadmap_eligible_tasks+=("$task")
  fi
done
```

**Step 3.5.2: Parse-only invocation of `roadmap-integration.sh`**:

This step replaces `/todo`'s own checkbox-only, table-blind grep matcher entirely. Calling the
shared script in parse-only mode (no `--annotate`) gives `/todo` full table-row-aware parsing,
the complete `roadmap_matches[]` list (with `confidence`, `match_type`, and for table rows
`line_index`/`raw_line`/`status_index`), and the always-on `roadmap_structure`/`parseable`/
`warnings` diagnostics -- with zero duplicate parsing code. `/todo` never implements matching
itself from this point forward; it only ever constructs an input and reads a payload.

```bash
# Parse-only call: no --annotate. Capture the invocation's own exit status immediately -- do not
# rely solely on the file-existence guard below, mirroring commands/review.md's Step 2.5 pattern.
roadmap_exit=0
roadmap_output=$(bash .claude/scripts/roadmap-integration.sh \
  --roadmap specs/ROADMAP.md \
  --state specs/state.json) || roadmap_exit=$?
```

**Step 3.5.3: Extract structured fields for downstream use**:
```bash
roadmap_state=$(echo "$roadmap_output" | jq '.roadmap_state')
roadmap_matches_raw=$(echo "$roadmap_output" | jq '.roadmap_matches')
roadmap_structure=$(echo "$roadmap_output" | jq '.roadmap_structure')
roadmap_warnings=$(echo "$roadmap_output" | jq '.warnings')
annotation_summary=$(echo "$roadmap_output" | jq '.annotation_summary')
high_confidence_matches=$(echo "$annotation_summary" | jq '.high_confidence_matches')
silent_noop=$(echo "$annotation_summary" | jq '.silent_noop')
```

**Error handling** (identical contract to `commands/review.md`'s Step 2.5): if
`roadmap-integration.sh` is missing, exits non-zero, or produces empty output, log a visible
warning and fall back to the same fully-defined defaults. Both "script missing" and "script
present but failed" must surface the same warning and fallback -- neither is allowed to fail
silently, and no downstream branch is left reading an unbound variable:

```bash
if [ ! -f .claude/scripts/roadmap-integration.sh ]; then
  echo "Warning: roadmap-integration.sh not found -- skipping roadmap integration" >&2
  roadmap_state='{"phases":[],"status_tables":[]}'
  roadmap_matches_raw='[]'
  roadmap_structure='{"phases":0,"checkboxes":0,"table_rows":0,"parseable":false}'
  roadmap_warnings='[]'
  high_confidence_matches=0
  silent_noop=false
  roadmap_no_match=false
elif [[ "$roadmap_exit" -ne 0 ]] || [[ -z "$roadmap_output" ]]; then
  echo "Warning: roadmap-integration.sh exited $roadmap_exit or produced empty output -- skipping roadmap integration" >&2
  roadmap_state='{"phases":[],"status_tables":[]}'
  roadmap_matches_raw='[]'
  roadmap_structure='{"phases":0,"checkboxes":0,"table_rows":0,"parseable":false}'
  roadmap_warnings='[]'
  high_confidence_matches=0
  silent_noop=false
  roadmap_no_match=false
fi
```

**Step 3.5.4: Eligibility filter -- where meta/expanded exclusion is enforced**:

`roadmap-integration.sh` has no `task_type` filter of its own (see its header's "Caller
contract"), so `/todo` reduces the raw match list to only the tasks Step 3.5.1 classified as
eligible. Everything downstream of this step consumes `roadmap_eligible_matches[]`, never
`roadmap_matches_raw`:

```bash
roadmap_eligible_nums=$(printf '%s\n' "${roadmap_eligible_tasks[@]}" | jq -s '[.[] | .project_number]')
roadmap_eligible_matches=$(echo "$roadmap_matches_raw" | jq --argjson eligible "$roadmap_eligible_nums" \
  '[.[] | select(.matched_task as $t | $eligible | index($t) != null)]')
```

**Step 3.5.5: `roadmap_no_match` -- distinct silent-zero signal**:

Distinguishes "eligible completed tasks and open roadmap items both existed, but nothing
matched" from "there was legitimately nothing to compare". Derived from data already in scope
above -- no new script call, no new matcher tier. `roadmap_open_checkbox_count` is the count of
still-open (`- [ ]`) items across `roadmap_state`, null-safe against the fallback shape:

```bash
roadmap_open_checkbox_count=$(echo "$roadmap_state" | jq \
  '[.phases[].checkboxes.items[]? | select(.completed == false)] | length')
roadmap_no_match=false
if [ "${#roadmap_eligible_tasks[@]}" -gt 0 ] && \
   [ "$(echo "$roadmap_eligible_matches" | jq 'length')" -eq 0 ] && \
   [ "$roadmap_open_checkbox_count" -gt 0 ]; then
  roadmap_no_match=true
fi
```

`roadmap_no_match` is defined unconditionally on the main path above. It must ALSO be defined
`false` in both error-handling fallback blocks below (Step 3.5.3's "script missing" and "script
present but failed" branches), matching the existing treatment of `high_confidence_matches` /
`silent_noop`, so no downstream branch ever reads an unbound variable.

Track:
- `roadmap_excluded_tasks[]` - Array of tasks excluded from ROADMAP.md matching (meta tasks, and
  expanded tasks since they have no `completion_summary` of their own by construction)
- `roadmap_eligible_tasks[]` - Array of tasks eligible for ROADMAP.md matching
- `roadmap_structure` / `roadmap_warnings` - The always-on structure signal and warning codes
  from `roadmap-integration.sh`, present in every mode
- `roadmap_eligible_matches[]` - The script's `roadmap_matches[]`, filtered to eligible tasks --
  the sole input to Step 4's dry-run output and Step 5.5's annotation
- `high_confidence_matches` / `silent_noop` - From `annotation_summary`, always defined even
  though no annotation has run yet (parse-only mode reports 0/false, never an unbound variable)
- `roadmap_no_match` - True iff eligible completed tasks existed, none matched any roadmap item,
  and at least one open roadmap checkbox remains; always defined, never left unbound

**Match Types** (the shared script's vocabulary -- both checkbox and table-row matching are live
paths in the script, regardless of which shape the file currently has. This repository's actual
`ROADMAP.md` is currently checkbox-based with zero table rows (a parse-only run reports
`checkboxes: 12, table_rows: 0`), but a future table-based roadmap would populate
`roadmap_eligible_matches[]` from the table-row path exactly the same way -- neither format is
dead code):
- `confidence`: `high` (auto-annotate candidate), `medium`, or `low` (report only)
- `match_type`: `explicit_task_ref`, `explicit_roadmap_item`, `exact_title_match`,
  `title_match`, or `keyword_match` -- see the script's `find_match` heuristic
- Checkbox-sourced matches carry no `source` key; table-row-sourced matches carry
  `source: "status_table"` plus `line_index`/`raw_line`/`status_index`, which the annotation
  step (Step 5.5) uses to locate and safely rewrite the matched row in place

### 4. Dry Run Output (if --dry-run)

```
Tasks to archive:

Completed:
- #{N1}: {title} (completed {date})
- #{N2}: {title} (completed {date})

Abandoned:
- #{N3}: {title} (abandoned {date})

Expanded:
- #{N10}: {title} (expanded {date})

Deferred (expanded, subtasks still active): {N}
- #{N11}: {title} ({blocking_count} subtask(s) still active)
  - {deferred_expanded_detail[] entry for N11} (Decision 6 mitigation: names a held blocking
    subtask specifically, e.g. "subtask 123 is held (reason: Awaiting upstream API decision)",
    rather than folding it into the generic count above)

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
    - {roadmap_item text} (confidence: high, match_type: explicit_roadmap_item)
    - {roadmap_item text 2} (confidence: high, match_type: explicit_task_ref)

Task #{N2} ({project_name}):
  Summary: "{completion_summary}"
  Matches:
    - {roadmap_item text} (confidence: high, match_type: exact_title_match)

Task #{N3} ({project_name}) [abandoned]:
  Matches:
    - {roadmap_item text} -> *(Task {N} abandoned)*

Total roadmap items to update: {N}
- Completed: {N} (from roadmap_high_confidence_matches / roadmap_completed_annotated)
- Abandoned: {N}

Total tasks: {N}
Total orphans: {N} (specs: {N}, archive: {N})
Total misplaced: {N}

Run without --dry-run to archive.
```

**Roadmap section inclusion is a five-way branch, never a bare "found nothing" omission**:
- `roadmap_structure.parseable == true`, `roadmap_eligible_matches[]` is empty, AND
  `roadmap_no_match == false`: omit the "Roadmap updates" section entirely -- legitimately
  nothing to do.
- `roadmap_warnings` contains `roadmap_absent` (checked before the generic unparseable case
  below, since an absent roadmap also carries `parseable == false` but is a distinct, non-error
  condition): print
  `Note: no ROADMAP.md tracked (specs/ROADMAP.md is absent) -- roadmap integration skipped; this is a supported state, not an error`
  (matching `commands/review.md`'s wording verbatim), and skip the generic unparseable message
  below entirely for this run.
- `roadmap_structure.parseable == false` (and `roadmap_absent` did NOT fire): **always** print,
  regardless of match count:
  `Warning: roadmap structure unrecognized (0 phases, 0 checkboxes, 0 table rows) -- see roadmap_structure in the payload`
  (matching `commands/review.md`'s wording verbatim).
- `roadmap_silent_noop == true` (from Step 3.5's `annotation_summary.silent_noop` -- i.e. high
  confidence matches exist but none would apply): print
  `Warning: roadmap annotation no-op ({roadmap_high_confidence_matches} high-confidence match(es), 0 applied) -- see skipped_reasons in the payload`.
- `roadmap_no_match == true` (eligible completed tasks and open roadmap items both existed, but
  no task's `roadmap_items` matched any of them): print
  `No roadmap items matched this run's {N} eligible completed task(s) against {M} open roadmap item(s) -- no task populated roadmap_items; see completion_data.roadmap_items`
  where `{N}` = `${#roadmap_eligible_tasks[@]}` and `{M}` = `roadmap_open_checkbox_count`.

**Invariant**: omission of the "Roadmap updates" section is permitted only when the roadmap
parsed successfully (`parseable == true`) AND there were genuinely no eligible matches AND
`roadmap_no_match == false`. An unparseable roadmap is never reportable as a successful (or
silent) annotation pass.

If no expanded parents were deferred (`deferred_expanded[]` is empty), omit the "Deferred" section.

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

Bootstrap `specs/archive/state.json` if this is the first archive operation (via `--init`, so
the fresh-create is mutex-guarded and staged exactly like every other state-file write):
```bash
[ -f specs/archive/state.json ] || bash .claude/scripts/state-write.sh \
  '{ "archived_projects": [], "completed_projects": [] }' \
  --init --state-file specs/archive/state.json --session-id "$session_id"
```

Move each task in `archivable_tasks[]` (the guard-filtered list from Step 3 — never a
freshly-recomputed status match, so deferred expanded parents are excluded) from state.json
`active_projects` to archive/state.json `completed_projects` (for completed AND expanded tasks)
or `archived_projects` (for abandoned tasks). Expanded tasks join `completed_projects` — there is
no third array. All task fields are preserved and an `archived_at` timestamp is added:
```bash
archivable_tasks_json=$(printf '%s\n' "${archivable_tasks[@]}" | jq -s '.')
bash .claude/scripts/state-write.sh \
  '.completed_projects = ([$tasks[] | select(.status == "completed" or .status == "expanded") | .archived_at = $ts] + .completed_projects) |
   .archived_projects = ([$tasks[] | select(.status == "abandoned") | .archived_at = $ts] + .archived_projects)' \
  --state-file specs/archive/state.json \
  --session-id "$session_id" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson tasks "$archivable_tasks_json"
```

**B. Update state.json**

Remove archived tasks from active_projects array using `del()` pattern (avoids Issue #1132 with
`!=` operator). **This filter must also subtract any deferred expanded parents**
(`deferred_expanded_nums[]` from Step 3's subtasks-defer guard) — the blanket status match alone
is wrong here: without the subtraction, a parent the guard deferred is still deleted from
`active_projects` even though its archive-list entry was held back, silently losing the task.
Use `index(...) == null` (never `!=`) to express the subtraction:
```bash
# Use del() instead of map(select(.status != "completed" and .status != "abandoned" and .status != "expanded"))
# This pattern is Issue #1132-safe
# deferred_json must default to [] when nothing was deferred.
deferred_json=$(printf '%s\n' "${deferred_expanded_nums[@]:-}" | jq -R 'select(length > 0) | tonumber' | jq -s '.')
bash .claude/scripts/state-write.sh \
  '
  del(.active_projects[] | select(
    (.status == "completed" or .status == "abandoned" or .status == "expanded")
    and (. as $item | ($deferred | index($item.project_number)) == null)
  ))' \
  --session-id "$session_id" \
  --argjson deferred "$deferred_json"
```
(`. as $item | ...` is required here: without it, `index(.project_number)` evaluates `.` against
`$deferred` itself after the pipe — not against the array element being tested — and jq errors
with "Cannot index array with string". Verified against a representative state.json.)

**C. Update TODO.md**

Remove archived task entries from main sections.

**D. Move Project Directories to Archive**

**CRITICAL**: This step MUST be executed - do not skip it.

For each task in `archivable_tasks[]` (completed, abandoned, or expanded — deferred expanded
parents excluded by the same guard-filtered list as Step 5A):
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

  # Add entry to archive/state.json. The archive target is reached via state-write.sh's
  # --state-file flag.
  bash .claude/scripts/state-write.sh \
     '.completed_projects += [{
       project_number: ($num | tonumber),
       project_name: $name,
       status: "orphan_archived",
       archived: $date,
       source: "orphan_recovery",
       detected_artifacts: $arts
     }]' \
     --state-file specs/archive/state.json \
     --session-id "$session_id" \
     --arg num "$project_num" \
     --arg name "$project_name" \
     --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     --argjson arts "$artifacts"

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

`/todo` never implements checkbox or table-row rewriting itself: it constructs a filtered input
and reads a payload from `roadmap-integration.sh`. Completed-task annotation is delegated
entirely to the script's `--annotate` mode; abandoned-task annotation stays `/todo`-owned, since
the script has no code path for it at all (see the script's header "Caller contract").

**1. Build the filtered snapshot -- MUST be captured from Step 3.5's pre-archival data**:

Step 5.5 runs *after* Step 5 archival. By then, archived tasks have already been removed from
`active_projects` and moved into `specs/archive/state.json`. An `--annotate` call pointed at the
live `specs/state.json` at this point would therefore see none of the tasks being archived --
the snapshot must instead be synthesized from `roadmap_eligible_tasks[]`, captured at Step 3.5
*before* Step 5's archival mutated state:

```bash
# Scratch directory for the snapshot -- input only, never a write target. Removed via trap.
snapshot_dir=$(mktemp -d)
trap 'rm -rf "$snapshot_dir"' EXIT

# Filter Step 3.5's pre-archival roadmap_eligible_tasks[] to completed-status entries only.
# (Abandoned-status entries are handled by /todo's own branch in step 3 below, not by the script.)
completed_eligible_json=$(printf '%s\n' "${roadmap_eligible_tasks[@]}" | jq -s '[.[] | select(.status == "completed")]')
jq -n --argjson projects "$completed_eligible_json" '{"active_projects": $projects}' > "${snapshot_dir}/state.json"
```

Two safety rules govern this snapshot:
- **Input only, never written back**: the snapshot is passed solely as `--state`; the real
  `specs/state.json` is never touched by this step.
- **No sibling archive on purpose**: `roadmap-integration.sh` resolves its archive input as the
  sibling `${STATE_PATH%state.json}archive/state.json` (see the script's header). Since
  `${snapshot_dir}/archive/state.json` does not exist, previously archived tasks are deliberately
  excluded from this run's annotation -- only this run's newly-completed tasks are ever
  annotated. This is documented, load-bearing behavior, not an accident to work around.

**2. Invoke the script in `--annotate` mode against the real ROADMAP.md, filtered snapshot as state**:
```bash
annotate_output=$(bash .claude/scripts/roadmap-integration.sh \
  --roadmap specs/ROADMAP.md \
  --state "${snapshot_dir}/state.json" \
  --annotate) || true

annotate_summary=$(echo "$annotate_output" | jq '.annotation_summary')
roadmap_completed_annotated=$(echo "$annotate_summary" | jq '.annotations_made')
roadmap_items_skipped=$(echo "$annotate_summary" | jq '.items_skipped')
roadmap_skipped_reasons=$(echo "$annotate_summary" | jq '.skipped_reasons')
roadmap_high_confidence_matches=$(echo "$annotate_summary" | jq '.high_confidence_matches')
roadmap_silent_noop=$(echo "$annotate_summary" | jq '.silent_noop')
```

**3. Abandoned-task annotation -- `/todo`-owned, gated on `parseable`**:

The script has no abandoned-status branch at all (its `COMPLETED_TASKS` query only ever selects
`status == "completed"`). `/todo` retains this annotation itself, gated on the same
`roadmap_structure.parseable` flag Step 3.5 captured: when `parseable` is `false`, do not attempt
the annotation -- emit Step 4's `roadmap_absent` note (if the roadmap is absent) or its
unparseable warning (otherwise) instead of silently no-op'ing.

For each abandoned task in `roadmap_eligible_matches[]` (Step 3.5), skip if the matched line
already contains `*(Task {N} abandoned:` or `*(Completed:`, else:
```
Edit old_string: "- [ ] {item_text}"
     new_string: "- [ ] {item_text} *(Task {N} abandoned: {short_reason})*"
```
Track `roadmap_abandoned_annotated` as the count of these edits applied.

**4. Track changes for output reporting**:
- `roadmap_completed_annotated` - from the script's `annotation_summary.annotations_made`
- `roadmap_abandoned_annotated` - from `/todo`'s own abandoned-path count (step 3 above)
- `roadmap_items_skipped` / `roadmap_skipped_reasons` - from the script's `annotation_summary`
- `roadmap_high_confidence_matches` / `roadmap_silent_noop` - from the script's
  `annotation_summary`, so a no-op annotate run can never be indistinguishable from success

**Safety Rules**:
- Enforced by `roadmap-integration.sh` for the completed-task path: skip items already containing
  `*(Completed:` (checkbox and table-row branches both check this at the exact captured line, not
  by text search); one edit per item; the table-row branch additionally guards against a stale
  `line_index`/`raw_line` mismatch before writing.
- Remain `/todo`'s own responsibility for the abandoned-task path: skip items already containing
  `*(Task {N} abandoned:` or `*(Completed:`; preserve existing formatting and indentation; one
  edit per item; never remove existing content.

### 5.7. Vault Operation (when next_project_number > 1000)

When `next_project_number` exceeds 1000, initiate vault archival operation to reset task numbering.

**Step 5.7.1: Detect vault threshold**:
```bash
next_num=$(jq -r '.next_project_number' specs/state.json)
if [ "$next_num" -gt 1000 ]; then
  vault_needed=true
fi
```

**Step 5.7.2: Identify tasks to renumber**:
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

**Step 5.7.3: User confirmation**:

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

**Step 5.7.4: Create vault directory**:
```bash
vault_count=$(jq -r '.vault_count // 0' specs/state.json)
new_vault_num=$((vault_count + 1))
vault_dir_name=$(printf "%02d-vault" "$new_vault_num")
vault_path="specs/vault/${vault_dir_name}"

mkdir -p "$vault_path"
mv "specs/archive" "${vault_path}/archive"
# A file rename, not a state write -- correctly outside state-write.sh's remit.
mv "${vault_path}/archive/state.json" "${vault_path}/state.json"
```

**Step 5.7.5: Create vault meta.json**:
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

**Step 5.7.6: Reinitialize archive**. The fresh-create archive target is reached via
`state-write.sh`'s `--init` mode:
```bash
mkdir -p "specs/archive"
bash .claude/scripts/state-write.sh '{ "completed_projects": [] }' \
  --init --state-file specs/archive/state.json --session-id "$session_id"
```

**Step 5.7.7: Renumber tasks > 1000**:

For each task with project_number > 1000:
1. Update state.json project_number (subtract 1000)
2. Update artifact paths (4-digit dir -> 3-digit dir)
3. Update dependencies arrays
4. Rename task directories
5. Update TODO.md entries

**Step 5.7.8: Reset state**:
```bash
# Calculate new next_project_number
max_active=$(jq -r '[.active_projects[].project_number] | max // 0' specs/state.json)
new_next_num=$((max_active + 1))

# Update state.json
bash .claude/scripts/state-write.sh \
   '.next_project_number = $new_next |
    .vault_count = (.vault_count // 0) + 1 |
    .vault_history = (.vault_history // []) + [{
      vault_number: $vault_num,
      vault_dir: $vault_path,
      created_at: $created
    }]' \
   --session-id "$session_id" \
   --argjson new_next "$new_next_num" \
   --argjson vault_num "$new_vault_num" \
   --arg vault_path "$vault_path/" \
   --arg created "$current_timestamp"
```

The vault-transition record lives in `state.json` `.vault_history[]` and
`specs/vault/{NN}-vault/meta.json` only — TODO.md does not carry a transition marker, because
`generate-todo.sh` fully overwrites TODO.md on every run (no read-modify-write of the existing
file), so any hand-inserted marker is erased by the next regeneration. See Step 6.5.2 for the
identical rationale applied to `repository_health`.

Track vault operations for output:
- `vault_created`: true/false
- `vault_path`: path to new vault
- `tasks_renumbered`: count of tasks renumbered
- `new_next_project_number`: reset value

### 5.8. Reap Stale Session Runtime Files

`/todo` also sweeps the `specs/` root for stale session-scoped
`specs/.orchestration/.orchestrator-multi-state-{session_id}.json` and
`specs/.orchestration/.return-meta-multi-{session_id}.json` files via `reap-session-runtime-files.sh`, and
`specs/.sessions/` for stale in-flight orchestration session registry entries via
`task-lock.sh session-reap` — the same two calls `/refresh` already makes (see
`commands/refresh.md`'s "Stale Session-Scoped Orchestration Files" and "Stale Session Registry
Entries" subsections for the full class description and threshold derivation). `/todo` is run
far more often than `/refresh`, so wiring these two reaps into every live invocation closes the
gap where litter accumulates unbounded between manual `/refresh` runs.

Both calls reuse the `dry_run` boolean already parsed in Step 1: on `--dry-run`, each script runs
with `--dry-run` and reports what it would reap; on a live run, each reaps and reports what it
reaped. Each script's own per-item output (filename/session id/age for the orchestration-file
sweep; session id/command/task numbers/age/reason for the registry sweep) is echoed verbatim,
matching `/refresh`'s own "echo verbatim" convention for these same two calls.

This stage is **non-blocking**: a nonzero exit or a missing script is logged and stepped over,
never failing `/todo`. Both `ORCHESTRATOR_SESSION_REAP_MIN` and `SESSION_REGISTRY_REAP_MIN`
(default 240 minutes each) are honored unchanged, so an in-flight batch orchestration run is
never reaped out from under itself. `/refresh`'s own invocation of these same two scripts is
untouched by this addition.

Because every path either script reaps is gitignored (see
`.claude/context/standards/orchestrator-runtime-files.md`'s Class Table), Step 6's staging below
is a fixed explicit path list and needs no git interaction for these deletions — the reap simply
runs ahead of Step 6's commit in the same invocation, not inside it.

### 6. Git Commit

Stage and commit together via `.claude/scripts/git-commit-scoped.sh`, the single sanctioned
implementation of path-scoped, mutex-serialized committing (never a bare `git add` plus a bare
`git commit`). This archival operation legitimately spans many tasks' rows in one commit, so
`--honest-index-rows` (which flags OTHER tasks' rows unexpectedly swept into a single task-scoped
commit) does not apply here:

```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "todo: archive {N} completed tasks" \
  --session "${session_id}" \
  -- specs/
```

Include roadmap, orphan, and misplaced counts in message as applicable:
```bash
# If roadmap items updated, orphans tracked, and misplaced moved:
bash .claude/scripts/git-commit-scoped.sh --message "todo: archive {N} tasks, update {R} roadmap items, track {M} orphans, move {P} misplaced" --session "${session_id}" -- specs/

# If roadmap items updated only:
bash .claude/scripts/git-commit-scoped.sh --message "todo: archive {N} tasks, update {R} roadmap items" --session "${session_id}" -- specs/

# If roadmap items updated and orphans tracked:
bash .claude/scripts/git-commit-scoped.sh --message "todo: archive {N} tasks, update {R} roadmap items, track {M} orphaned directories" --session "${session_id}" -- specs/

# If orphans tracked and misplaced moved (no roadmap):
bash .claude/scripts/git-commit-scoped.sh --message "todo: archive {N} tasks, track {M} orphans, move {P} misplaced directories" --session "${session_id}" -- specs/

# If only orphans tracked (no roadmap):
bash .claude/scripts/git-commit-scoped.sh --message "todo: archive {N} tasks and track {M} orphaned directories" --session "${session_id}" -- specs/

# If only misplaced moved (no roadmap):
bash .claude/scripts/git-commit-scoped.sh --message "todo: archive {N} tasks and move {P} misplaced directories" --session "${session_id}" -- specs/
```

Where `{R}` = roadmap_completed_annotated + roadmap_abandoned_annotated (total roadmap items updated).

### 6.5. Sync Repository Metrics

Update repository-wide metrics in state.json via the standalone health-assessment probe. All
probe logic (file enumeration, the `bash -n`/`jq empty` structural checks, the existence filter
that keeps a moved-but-unstaged tracked file from inflating the count, TODO/FIXME counting, and
`status` derivation) lives in `scripts/assess-repo-health.sh` — see that script's header for the
full contract, including why `build_errors` answers "is the tree structurally sound" rather than
"does this project's own build/lint/test command pass", and why it can emit JSON `null`
("not measured") rather than guessing `0` or `1`. This stage is a thin call site over that script.

**Why this stage runs after Step 6's commit, not before it**: Step 5's archival, Step 5D's
directory moves, and Step 5.7's vault operation all leave the git index behind the worktree until
Step 6 commits — a metrics probe run any earlier measures paths the tree has already left behind.
`assess-repo-health.sh` is independently existence-safe as of the `phantom_paths` fix (a moved but
still-tracked-at-its-old-path candidate no longer inflates `build_errors`), but re-sequencing is
still required on top of that fix: existence-safety protects against a stale git *index* entry,
not against measuring a worktree state this run is about to change again. Running the probe after
this run's own commit is the only way its `repository_health` describes the tree `/todo` actually
produced.

**Step 6.5.1: Compute current metrics**:
```bash
health_json=$(bash .claude/scripts/assess-repo-health.sh)
```

**Step 6.5.2: Update state.json repository_health**:

`repository_health` lives in `state.json` only — TODO.md frontmatter does not mirror it, because
`generate-todo.sh` fully overwrites TODO.md on every run (no read-modify-write of the existing
file) and no consumer of a hand-authored TODO.md-frontmatter debt/health YAML block exists
anywhere under `agent-system/extensions/**`.
```bash
bash .claude/scripts/state-write.sh \
   '.repository_health = $health' \
   --session-id "$session_id" \
   --argjson health "$health_json"
```

**Step 6.5.3: Commit the metrics update**:

This is its own narrowly-scoped commit, separate from Step 6's archival commit, via
`.claude/scripts/git-commit-scoped.sh` (the single sanctioned implementation of path-scoped,
mutex-serialized committing — `git-commit-scoped.sh` is stage+commit-atomic with no "stage only"
mode, so this cannot be folded back into Step 6 without re-introducing the pre-commit measurement
this re-sequencing exists to avoid). `--honest-index-rows` is inapplicable here for the opposite
reason it is inapplicable to Step 6: this commit touches nothing task-scoped at all.
```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "todo: sync repository metrics" \
  --session "${session_id}" \
  -- specs/state.json
```

If this commit fails while Step 6's own commit already succeeded, the run leaves no state lost —
only `repository_health` one run stale, since the next `/todo` invocation recomputes it from
scratch. This is the same non-blocking treatment `rules/error-handling.md` gives every git
failure, and it is strictly better than the prior pre-commit-probe behavior, which baked a
*wrong* value permanently into the same commit as the archival it was supposed to describe.

**Step 6.5.4: Report metrics sync**:
Track for output:
- `metrics_todo_count`: Current TODO count (`$health_json`'s `todo_count`)
- `metrics_fixme_count`: Current FIXME count (`$health_json`'s `fixme_count`)
- `metrics_build_errors`: Current build errors, or "not measured" when `$health_json`'s
  `build_errors` is JSON `null`
- `metrics_phantom_paths`: Current phantom-path count (`$health_json`'s `phantom_paths`) — a
  nonzero value is visible to the operator here rather than buried in state.json
- `metrics_synced`: true/false indicating if sync was performed

### 7. Output

Use grouped counts instead of listing individual items:

```
Archived {N} tasks

Tasks: {C} completed, {A} abandoned, {E} expanded
Directories: {D} moved

{If any expanded parents were deferred:}
Deferred: {F} expanded parent(s) held back (subtasks still active)

{If orphans or misplaced processed:}
Cleanup: {O} orphans tracked, {P} misplaced moved

{If roadmap updated:}
Roadmap: {R} items updated ({roadmap_completed_annotated} completed, {roadmap_abandoned_annotated} abandoned)

{If roadmap_structure.parseable == false:}
Warning: roadmap structure unrecognized (0 phases, 0 checkboxes, 0 table rows) -- see roadmap_structure in the payload

{If roadmap_silent_noop == true:}
Warning: roadmap annotation no-op ({roadmap_high_confidence_matches} high-confidence match(es), 0 applied) -- see skipped_reasons in the payload

{If roadmap_no_match == true:}
No roadmap items matched this run's {N} eligible completed task(s) against {M} open roadmap item(s) -- no task populated roadmap_items; see completion_data.roadmap_items

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
| Deferred | deferred_expanded[] is non-empty |
| Cleanup | orphans_tracked > 0 OR misplaced_moved > 0 |
| Roadmap | roadmap_completed_annotated + roadmap_abandoned_annotated > 0, OR `parseable == false`, OR `roadmap_silent_noop == true`, OR `roadmap_no_match == true` |

Same four-way branch as Step 4's dry-run output:
- `roadmap_structure.parseable == true`, zero items were annotated, AND `roadmap_no_match ==
  false`: omit the "Roadmap" section -- legitimately nothing to do.
- `roadmap_structure.parseable == false`: **always** print the unparseable warning line above,
  regardless of annotation counts.
- `roadmap_silent_noop == true`: print the annotation-no-op warning line above.
- `roadmap_no_match == true`: print the no-match line above.

**Invariant**: omission is permitted only when the roadmap parsed successfully AND
`roadmap_no_match == false`. An unparseable roadmap is never reportable by `/todo` as a
successful annotation pass.

**Reference material**: the archival-status definitions, orphan and misplaced-directory
categories, roadmap annotation formats and safety rules, and jq/shell escaping rules that
Steps 2.5, 2.6, 3, and 5.5 depend on live in
`.claude/context/patterns/todo-archival-reference.md`. READ that file before executing any of
those steps.
