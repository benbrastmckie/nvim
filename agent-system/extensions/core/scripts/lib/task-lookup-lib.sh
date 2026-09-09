#!/usr/bin/env bash
# task-lookup-lib.sh - Single source of truth for archive-aware task lookup.
#
# `/todo` moves every terminal task (completed/abandoned/expanded) OUT of `.active_projects` and
# into the sibling `archive/state.json`, and MOVES its task directory from `specs/{NNN}_{slug}`
# to `specs/archive/{NNN}_{slug}`. Any consumer that only ever reads `.active_projects` or only
# ever derives `specs/{NNN}_{slug}` therefore treats an archived task as nonexistent, or scatters
# a new round's artifacts into a fresh, wrong, empty directory. This is the ONE place the
# archive-normalization rule, the active-wins lookup, and the archived-directory fallback are
# defined as executable data -- every consumer sources this file rather than hand-copying the
# jq. The current consumer list is found live via
# `grep -rl 'task-lookup-lib.sh' agent-system/extensions` (the same self-verifying "grep for
# sourcers" mechanism phase-heading-patterns.sh's and status-vocabulary.sh's consumers are found
# by).
#
# Modeled on scripts/lib/phase-heading-patterns.sh and scripts/lib/status-vocabulary.sh's shape:
# idempotent source guard, exported functions, doc header naming consumers and the discovery
# mechanism.
#
# Usage: `source` this file, then call:
#   - `task_lookup_archived_projects_json <state_file>` to get the flattened, normalized archive
#     array as JSON on stdout.
#   - `task_lookup_entry <project_number> <state_file>` to echo the matching record (active wins).
#   - `task_lookup_is_active <project_number> <state_file>` to test active-vs-archived-only.
#   - `task_lookup_dir <project_number> <project_name> <repo_root>` to resolve the task's
#     existing directory (active, then archive, then the active path as a last resort for a
#     brand-new task).
#
# Read-only throughout: no function in this file ever writes `archive/state.json` or moves a
# directory. Un-archiving is out of scope everywhere this library is used.

# No idempotent source guard: this file defines only functions (no top-level side effects), so
# re-sourcing it is already a harmless no-op -- matching status-vocabulary.sh and
# phase-heading-patterns.sh, neither of which carries a guard either.

# ─── task_lookup_archived_projects_json <state_file> ───────────────────────────────────────────
# Reads `${state_file%state.json}archive/state.json`, flattens `completed_projects` and
# `archived_projects` into one array, and normalizes `.status`: completed/abandoned/expanded are
# preserved verbatim; any other archive-only status (e.g. `orphan_archived`) maps to "completed",
# since an orphan recovery is applied to already-finished work and there is no in-flight orphan
# to wait on. Emits "[]" (and returns 0) when the archive file is absent or unreadable -- this is
# an extraction of orchestrate-cycle-plan.sh's pre-existing inline jq, transcribed verbatim, not
# a rewrite.
task_lookup_archived_projects_json() {
  local state_file="$1"
  local archive_state_file="${state_file%state.json}archive/state.json"
  local result
  if [ -f "$archive_state_file" ]; then
    result=$(jq -c '
      [ ((.completed_projects // [])[], ((.archived_projects // [])[])) |
        .status = (if (.status | IN("completed", "abandoned", "expanded")) then .status else "completed" end) ]
    ' "$archive_state_file" 2>/dev/null) || result='[]'
  else
    result='[]'
  fi
  printf '%s\n' "$result"
}

# ─── task_lookup_entry <project_number> <state_file> ───────────────────────────────────────────
# Echoes the matching record (or nothing) on stdout. Active projects win; the archive is
# consulted only when the number is absent from `.active_projects`, so a task that somehow
# appears in both is still governed by its live entry.
task_lookup_entry() {
  local project_number="$1"
  local state_file="$2"
  local all_projects_json archived_projects_json found
  all_projects_json=$(jq -c '.active_projects // []' "$state_file" 2>/dev/null) || all_projects_json='[]'
  found=$(echo "$all_projects_json" | jq -c --argjson n "$project_number" '.[] | select(.project_number == $n)' 2>/dev/null | head -1)
  if [ -z "$found" ]; then
    archived_projects_json=$(task_lookup_archived_projects_json "$state_file")
    found=$(echo "$archived_projects_json" | jq -c --argjson n "$project_number" '.[] | select(.project_number == $n)' 2>/dev/null | head -1)
  fi
  echo "$found"
}

# ─── task_lookup_is_active <project_number> <state_file> ───────────────────────────────────────
# Exit 0 iff <project_number> is present in `.active_projects`; exit 1 otherwise (including when
# it is present only in the archive, or in neither). This is the predicate the archive-absent
# status-write skip needs: a task's status may only be WRITTEN when it is active.
task_lookup_is_active() {
  local project_number="$1"
  local state_file="$2"
  local all_projects_json
  all_projects_json=$(jq -c '.active_projects // []' "$state_file" 2>/dev/null) || all_projects_json='[]'
  echo "$all_projects_json" | jq -e --argjson n "$project_number" 'any(.[]; .project_number == $n)' >/dev/null 2>&1
}

# ─── task_lookup_dir <project_number> <project_name> <repo_root> ──────────────────────────────
# Prints, on stdout, the repo-root-relative task directory to use: `specs/{NNN}_{project_name}`
# when that directory already exists, else `specs/archive/{NNN}_{project_name}` when THAT
# directory exists, else the active path unchanged (so a brand-new task with no directory yet on
# either side resolves exactly as it always has). Never touches disk.
task_lookup_dir() {
  local project_number="$1"
  local project_name="$2"
  local repo_root="$3"
  local padded active_rel archive_rel
  padded=$(printf "%03d" "$project_number")
  active_rel="specs/${padded}_${project_name}"
  archive_rel="specs/archive/${padded}_${project_name}"
  if [ -d "${repo_root}/${active_rel}" ]; then
    printf '%s\n' "$active_rel"
  elif [ -d "${repo_root}/${archive_rel}" ]; then
    printf '%s\n' "$archive_rel"
  else
    printf '%s\n' "$active_rel"
  fi
}
