#!/usr/bin/env bash
#
# generate-task-order.sh - Generate the Task Order section for TODO.md
#
# Usage:
#   generate-task-order.sh --print
#       Print the generated Task Order section to stdout.
#
#   generate-task-order.sh --update-todo TODO_FILE STATE_FILE [--goal "text"]
#       Replace the ## Task Order section in TODO_FILE using data from STATE_FILE.
#       Preserves the existing Goal line unless --goal is specified.
#
# The generated section contains:
#   1. A timestamp line
#   2. A Goal line (preserved from existing or provided via --goal)
#   3. A Dependency Waves table (computed via Kahn's algorithm)
#   4. Topic-grouped dependency tree sections (DFS, deps shown below their dependents)
#
# Format spec: .claude/context/formats/task-order-format.md
#
# Topic assignment: Tasks without a "topic" field in state.json appear in
# ### Uncategorized. To assign topics, add a "topic" field to each task entry
# in state.json and add project-specific topic values to the top-level
# "active_topics" array. No heuristic is provided here; topic assignment is
# project-specific and handled by downstream tools (e.g., /task, /meta).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TODO_FILE="${PROJECT_ROOT}/specs/TODO.md"
STATE_FILE="${PROJECT_ROOT}/specs/state.json"

# normalize_topic: canonical topic form (lowercase kebab-case).
# CANONICAL DEFINITION -- keep byte-identical across manage-topics.sh and both
# generate-task-order.sh copies (core extension + .opencode). No task-number references.
# NOTE: .opencode/ write-side topic-assignment parity (no manage-topics.sh, no
# topic-assignment-pattern.md, no /task topic step) is OUT OF SCOPE here -- this is a
# render-side-only mirror of the .claude/ renderer fix. Write-side parity for .opencode/
# is a recommended follow-up, flagged but not implemented in this change.
normalize_topic() {
  local t="${1,,}"
  t="${t//_/-}"
  t="$(printf '%s' "$t" | tr -s '[:space:]' '-')"
  t="$(printf '%s' "$t" | tr -s '-')"
  t="${t#-}"; t="${t%-}"
  printf '%s' "$t"
}

# truncate_word_boundary <text> <budget> -- shared bash-side counterpart to build_graph's
# wb_truncate jq helper (~line 155 area): truncates <text> to at most <budget> characters,
# backing off to the last space at or before (budget - 3) and appending "..." so the TOTAL
# length (content + marker) never exceeds budget. Ported verbatim from the core copy
# (agent-system/extensions/core/scripts/generate-task-order.sh) as part of the render-side
# slice-safety fix -- see that file's copy for the full rationale comment.
#
# Idempotent against an already-marked input: if <text> already ends with "..." (e.g. it is the
# already-truncated output of the primary 65-char slice, being cut again to a smaller
# cross-topic budget), the existing marker is stripped before re-cutting so the result never
# carries a doubled "......" marker.
truncate_word_boundary() {
  local text="$1" budget="$2"
  local marker="..."
  local mlen=${#marker}

  if [[ ${#text} -le $budget ]]; then
    printf '%s' "$text"
    return
  fi

  if [[ "$text" == *"$marker" ]]; then
    text="${text%"$marker"}"
    if [[ ${#text} -le $budget ]]; then
      printf '%s' "$text"
      return
    fi
  fi

  local cut=$(( budget - mlen ))
  (( cut < 0 )) && cut=0
  local sliced="${text:0:$cut}"
  if [[ "$sliced" == *' '* ]]; then
    sliced="${sliced% *}"
  fi
  printf '%s%s' "$sliced" "$marker"
}

# ============================================================================
# Parse Arguments
# ============================================================================

MODE=""
GOAL_OVERRIDE=""
TODO_ARG=""
STATE_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --print)
      MODE="print"
      shift
      ;;
    --update-todo)
      MODE="update"
      shift  # consume --update-todo
      TODO_ARG="${1:-}"
      [[ $# -gt 0 ]] && shift
      STATE_ARG="${1:-}"
      [[ $# -gt 0 ]] && shift
      ;;
    --goal)
      shift  # consume --goal
      GOAL_OVERRIDE="${1:-}"
      [[ $# -gt 0 ]] && shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: generate-task-order.sh --print | --update-todo TODO STATE [--goal TEXT]" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$MODE" ]]; then
  echo "Usage: generate-task-order.sh --print | --update-todo TODO STATE [--goal TEXT]" >&2
  exit 1
fi

if [[ "$MODE" == "update" ]]; then
  [[ -n "$TODO_ARG" ]] && TODO_FILE="$TODO_ARG"
  [[ -n "$STATE_ARG" ]] && STATE_FILE="$STATE_ARG"
fi

# Validate files
if [[ ! -f "$STATE_FILE" ]]; then
  echo "ERROR: state.json not found at $STATE_FILE" >&2
  exit 1
fi

if [[ "$MODE" == "update" && ! -f "$TODO_FILE" ]]; then
  echo "ERROR: TODO.md not found at $TODO_FILE" >&2
  exit 1
fi

# ============================================================================
# Data Extraction
# ============================================================================

# get_active_tasks: outputs lines of format TASK_NUM|STATUS|DEP1,DEP2,...
get_active_tasks() {
  jq -r '.active_projects[] |
    select(.status == "completed" | not) |
    select(.status == "abandoned" | not) |
    select(.status == "expanded" | not) |
    "\(.project_number)|\(.status)|\(.dependencies // [] | map(tostring) | join(","))"
  ' "$STATE_FILE"
}

# get_description: returns short description for a task number (from preloaded task_desc map)
get_description() {
  local task_num="$1"
  local desc="${task_desc[$task_num]:-}"
  if [[ -z "$desc" ]]; then
    desc="(no description)"
  fi
  echo "$desc"
}

# ============================================================================
# Build In-Memory Graph
# ============================================================================

# Associative arrays for graph data
declare -A task_status     # task_num -> status string (raw from state.json)
declare -A task_deps       # task_num -> space-separated active dep IDs
declare -A task_successors # task_num -> space-separated active successor IDs (inverse of task_deps)
declare -A task_desc       # task_num -> description
declare -a all_task_nums   # ordered list of all active task IDs

build_graph() {
  local raw_data
  raw_data=$(get_active_tasks)

  # Preload all task descriptions in one jq call using @base64 encoding to avoid newline issues
  #
  # Source-string selection and slicing -- ported verbatim from the core copy
  # (agent-system/extensions/core/scripts/generate-task-order.sh), see that file's copy of this
  # comment for the full per-step rationale:
  #   1. (.title // .description // .project_name) -- prefer a purpose-written .title.
  #   2. ltrimstr(" ") -- drop one accidental leading space.
  #   3. gsub("`";""), gsub("\\*";""), gsub("_";""), gsub("\\[";"") -- strip inline-markup
  #      hazard characters before slicing.
  #   4. gsub("\n";" ") -- normalize embedded newlines to spaces INSIDE jq.
  #   5. wb_truncate(65) -- truncate only when over budget, word-boundary backoff plus marker,
  #      reserved within the budget.
  local desc_data
  desc_data=$(jq -r '
    def wb_truncate(budget):
      if (length > budget) then
        (.[0:(budget - 3)] | sub(" [^ ]*$"; "")) + "..."
      else
        .
      end;
    .active_projects[] |
    select(.status == "completed" | not) |
    select(.status == "abandoned" | not) |
    select(.status == "expanded" | not) |
    "\(.project_number)|\(
      (.title // .description // .project_name)
      | ltrimstr(" ")
      | gsub("`"; "")
      | gsub("\\*"; "")
      | gsub("_"; "")
      | gsub("\\["; "")
      | gsub("\n"; " ")
      | wb_truncate(65)
    )"
  ' "$STATE_FILE" 2>/dev/null)

  # Load descriptions into task_desc map
  # Read line by line; description may not contain | (we split on first | only). Newlines were
  # already normalized to spaces inside the jq program above.
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local tn="${line%%|*}"
    local desc="${line#*|}"
    [[ -n "$tn" ]] && task_desc["$tn"]="$desc"
  done <<< "$desc_data"

  # First pass: collect all task numbers and their raw deps
  declare -A raw_deps_map
  while IFS='|' read -r task_num status deps; do
    [[ -z "$task_num" ]] && continue
    all_task_nums+=("$task_num")
    task_status["$task_num"]="$status"
    raw_deps_map["$task_num"]="$deps"
  done <<< "$raw_data"

  # Build set of active task numbers for fast lookup
  declare -A active_set
  for tn in "${all_task_nums[@]}"; do
    active_set["$tn"]=1
  done

  # Second pass: compute clean deps (only deps that are still active)
  for tn in "${all_task_nums[@]}"; do
    local deps="${raw_deps_map[$tn]:-}"
    local clean_deps=""
    if [[ -n "$deps" ]]; then
      IFS=',' read -ra dep_array <<< "$deps"
      for dep in "${dep_array[@]}"; do
        [[ -z "$dep" ]] && continue
        # Only include if dep is still an active task
        if [[ -n "${active_set[$dep]+x}" ]]; then
          clean_deps="${clean_deps} ${dep}"
        fi
      done
    fi
    task_deps["$tn"]="${clean_deps# }"  # trim leading space
  done
}

# build_successors_map: inverts task_deps to build task_successors
# For each task T with deps D1 D2..., add T as a successor of each Di.
build_successors_map() {
  for tn in "${all_task_nums[@]}"; do
    local deps="${task_deps[$tn]:-}"
    if [[ -n "$deps" ]]; then
      read -ra dep_array <<< "$deps"
      for dep in "${dep_array[@]}"; do
        [[ -z "$dep" ]] && continue
        task_successors["$dep"]="${task_successors[$dep]:-} ${tn}"
      done
    fi
  done
  # Trim leading spaces from all entries (use :- to handle tasks with no successors)
  for tn in "${all_task_nums[@]}"; do
    task_successors["$tn"]="${task_successors[$tn]:-}"
    task_successors["$tn"]="${task_successors[$tn]# }"
  done
}

# ============================================================================
# Topic Loading
# ============================================================================

declare -A task_topic      # task_num -> topic string
declare -a active_topics_order=()  # canonical topic order from state.json

load_topics() {
  # Load topic field from state.json into task_topic associative array
  local topics_data
  topics_data=$(jq -r '.active_projects[] |
    select(.status == "completed" | not) |
    select(.status == "abandoned" | not) |
    select(.status == "expanded" | not) |
    "\(.project_number)|\(.topic // "")"
  ' "$STATE_FILE" 2>/dev/null)

  while IFS='|' read -r tn topic; do
    [[ -z "$tn" ]] && continue
    task_topic["$tn"]="${topic}"
  done <<< "$topics_data"

  # Load active_topics canonical order from state.json top-level array
  local at_data
  at_data=$(jq -r '.active_topics // [] | .[]' "$STATE_FILE" 2>/dev/null)
  while IFS= read -r t; do
    [[ -z "$t" ]] && continue
    active_topics_order+=("$t")
  done <<< "$at_data"
}

# ============================================================================
# Kahn's Algorithm: Compute Wave Assignments
# ============================================================================

declare -A wave_assignment  # task_num -> wave number

compute_waves() {
  declare -A in_degree    # task_num -> count of active deps
  declare -A successors   # dep_id -> space-separated list of tasks that depend on it

  # Initialize in-degree from clean deps
  for tn in "${all_task_nums[@]}"; do
    local deps="${task_deps[$tn]:-}"
    local count=0
    if [[ -n "$deps" ]]; then
      read -ra dep_array <<< "$deps"
      count="${#dep_array[@]}"
      for dep in "${dep_array[@]}"; do
        [[ -z "$dep" ]] && continue
        successors["$dep"]="${successors[$dep]:-} ${tn}"
      done
    fi
    in_degree["$tn"]=$count
  done

  # Kahn's BFS wave computation
  local -a queue=()
  local wave=1

  # Initialize queue with zero-in-degree tasks
  for tn in "${all_task_nums[@]}"; do
    if [[ "${in_degree[$tn]}" -eq 0 ]]; then
      queue+=("$tn")
    fi
  done

  while [[ ${#queue[@]} -gt 0 ]]; do
    local -a next_queue=()

    # Assign current wave to all tasks in queue
    for tn in "${queue[@]}"; do
      wave_assignment["$tn"]=$wave
    done

    # Process dependents
    for tn in "${queue[@]}"; do
      for succ in ${successors[$tn]:-}; do
        [[ -z "$succ" ]] && continue
        in_degree["$succ"]=$((${in_degree[$succ]} - 1))
        if [[ "${in_degree[$succ]}" -eq 0 ]]; then
          next_queue+=("$succ")
        fi
      done
    done

    queue=("${next_queue[@]+"${next_queue[@]}"}")
    wave=$((wave + 1))
  done

  # Detect cycles: any unassigned task has a cycle
  for tn in "${all_task_nums[@]}"; do
    if [[ -z "${wave_assignment[$tn]+x}" ]]; then
      echo "WARNING: Task $tn not assigned to a wave (possible circular dependency)" >&2
      wave_assignment["$tn"]=99  # assign to a placeholder wave
    fi
  done
}

# ============================================================================
# Union-Find: Connected Components
# ============================================================================

declare -A cc_parent  # task_num -> parent representative

# cc_find: find root representative with path compression
cc_find() {
  local x="$1"
  while [[ "${cc_parent[$x]:-$x}" != "$x" ]]; do
    # Path compression: point directly to grandparent
    local gp="${cc_parent[${cc_parent[$x]}]:-${cc_parent[$x]}}"
    cc_parent["$x"]="$gp"
    x="${cc_parent[$x]}"
  done
  echo "$x"
}

# cc_union: merge two components
cc_union() {
  local rx ry
  rx=$(cc_find "$1")
  ry=$(cc_find "$2")
  if [[ "$rx" != "$ry" ]]; then
    cc_parent["$rx"]="$ry"
  fi
}

compute_connected_components() {
  # Initialize: each task is its own component
  for tn in "${all_task_nums[@]}"; do
    cc_parent["$tn"]="$tn"
  done

  # Union tasks with their active dependencies
  for tn in "${all_task_nums[@]}"; do
    local deps="${task_deps[$tn]:-}"
    if [[ -n "$deps" ]]; then
      read -ra dep_array <<< "$deps"
      for dep in "${dep_array[@]}"; do
        [[ -z "$dep" ]] && continue
        [[ -n "${task_status[$dep]+x}" ]] && cc_union "$tn" "$dep"
      done
    fi
  done
}

# ============================================================================
# Generate Grouped Section by Topic
# ============================================================================

# Global tracking arrays for generate_grouped_section (avoids nameref in recursive functions)
declare -A _topic_section_visited=()   # tasks visited in current topic section
declare -A _globally_visited=()        # tasks visited across all topic sections
declare _current_section_topic=""      # current topic being rendered

# generate_grouped_section: renders topic sections with fenced code blocks
generate_grouped_section() {
  echo "**Grouped by Topic** (indented = depends on parent):"
  echo ""

  # Build ordered list of topics to render
  # Use active_topics_order if available, then add any extra topics found in tasks
  # Topics are grouped by canonical form (see normalize_topic above): the grouping
  # key is the normalized lowercase-kebab-case topic string, so e.g. "Literature",
  # "literature", and separator variants of the same topic collapse into a single
  # section (the heading is title-cased for display below).
  local -a topics_to_render=()
  declare -A seen_topics=()
  if [[ ${#active_topics_order[@]} -gt 0 ]]; then
    for t in "${active_topics_order[@]}"; do
      local t_key
      t_key="$(normalize_topic "$t")"
      if [[ -z "${seen_topics[$t_key]+x}" ]]; then
        topics_to_render+=("$t_key")
        seen_topics["$t_key"]=1
      fi
    done
  fi

  # Collect any topics in tasks that aren't in active_topics_order
  for tn in "${all_task_nums[@]}"; do
    local tp="${task_topic[$tn]:-}"
    local tp_key
    tp_key="$(normalize_topic "$tp")"
    if [[ -n "$tp" && -z "${seen_topics[$tp_key]+x}" ]]; then
      topics_to_render+=("$tp_key")
      seen_topics["$tp_key"]=1
    fi
  done

  # Reset global tracking
  _globally_visited=()

  for topic in "${topics_to_render[@]}"; do
    # Collect tasks for this topic (sorted numerically)
    local -a topic_tasks=()
    for tn in $(printf '%s\n' "${all_task_nums[@]}" | sort -n); do
      local tp="${task_topic[$tn]:-}"
      [[ "$(normalize_topic "$tp")" == "$topic" ]] && topic_tasks+=("$tn")
    done

    [[ ${#topic_tasks[@]} -eq 0 ]] && continue

    # Format topic heading: capitalize first letter of each word, replace - with space
    local heading
    heading=$(echo "$topic" | sed 's/-/ /g; s/\b\(.\)/\u\1/g')

    echo "### ${heading}"
    echo ""

    # Reset per-section visited tracking
    _topic_section_visited=()
    _current_section_topic="$topic"

    # Print root tasks first (tasks with no active deps = wave-1 unblocked tasks)
    # Then fall through to any remaining unvisited tasks (cross-topic deps may create orphans)
    for tn in "${topic_tasks[@]}"; do
      local tn_deps="${task_deps[$tn]:-}"
      if [[ -z "$tn_deps" && -z "${_topic_section_visited[$tn]+x}" ]]; then
        _print_topic_node "$tn" 0
      fi
    done
    # Print any remaining unvisited topic tasks that weren't reachable from roots
    for tn in "${topic_tasks[@]}"; do
      if [[ -z "${_topic_section_visited[$tn]+x}" ]]; then
        _print_topic_node "$tn" 0
      fi
    done

    echo ""
  done

  # Uncategorized fallback for tasks without a topic field
  local -a uncategorized_tasks=()
  for tn in $(printf '%s\n' "${all_task_nums[@]}" | sort -n); do
    local tp="${task_topic[$tn]:-}"
    if [[ -z "$tp" ]]; then
      uncategorized_tasks+=("$tn")
    fi
  done

  if [[ ${#uncategorized_tasks[@]} -gt 0 ]]; then
    echo "### Uncategorized"
    echo ""
    _current_section_topic=""
    _topic_section_visited=()
    # Print uncategorized roots first (no active deps)
    for tn in "${uncategorized_tasks[@]}"; do
      local tn_deps="${task_deps[$tn]:-}"
      if [[ -z "$tn_deps" && -z "${_globally_visited[$tn]+x}" ]]; then
        _print_topic_node "$tn" 0
      fi
    done
    # Then any remaining unvisited uncategorized tasks
    for tn in "${uncategorized_tasks[@]}"; do
      if [[ -z "${_globally_visited[$tn]+x}" ]]; then
        _print_topic_node "$tn" 0
      fi
    done
    echo ""
  fi
}

# _print_topic_node: DFS node printer for topic-grouped sections
# Uses global _topic_section_visited, _globally_visited, _current_section_topic
_print_topic_node() {
  local task_num="$1"
  local depth="$2"

  local prefix=""
  if [[ "$depth" -gt 0 ]]; then
    local pad
    pad=$(printf '%*s' $(( (depth - 1) * 2 )) '')
    prefix="${pad}  └─ "
  fi

  local status_raw="${task_status[$task_num]:-not_started}"
  local status_display
  status_display=$(format_status "$status_raw")

  local desc="${task_desc[$task_num]:-}"
  [[ -z "$desc" ]] && desc="(no description)"

  # Cross-topic: if this task was already visited globally (in another topic section)
  if [[ -n "${_globally_visited[$task_num]+x}" && "$depth" -gt 0 ]]; then
    local task_topic_val="${task_topic[$task_num]:-}"
    if [[ -n "$task_topic_val" && "$(normalize_topic "$task_topic_val")" != "$_current_section_topic" ]]; then
      # Shorten desc to a 40-char budget via truncate_word_boundary (defined near
      # normalize_topic above), ported from the core copy -- idempotent against $desc already
      # carrying a marker from the primary 65-char slice.
      local short_desc
      short_desc="$(truncate_word_boundary "$desc" 40)"
      echo "${prefix}${task_num} [${status_display}] — (${task_topic_val}: ${short_desc}) (see above)"
    else
      echo "${prefix}${task_num} [${status_display}] — ${desc} (see above)"
    fi
    return
  fi

  echo "${prefix}${task_num} [${status_display}] — ${desc}"
  _topic_section_visited["$task_num"]=1
  _globally_visited["$task_num"]=1

  # Print this task's active successors (tasks that depend on this task, indented below)
  # Skip successors that belong to a different topic -- they'll appear under their own heading
  local deps="${task_successors[$task_num]:-}"
  if [[ -n "$deps" ]]; then
    local sorted_deps
    sorted_deps=$(echo "$deps" | tr ' ' '\n' | sort -n | tr '\n' ' ')
    read -ra dep_array <<< "$sorted_deps"
    for dep in "${dep_array[@]}"; do
      [[ -z "$dep" ]] && continue
      if [[ -n "${task_status[$dep]+x}" ]]; then
        local dep_topic="${task_topic[$dep]:-}"
        if [[ -n "$_current_section_topic" && -n "$dep_topic" && "$(normalize_topic "$dep_topic")" != "$_current_section_topic" ]]; then
          continue
        fi
        _print_topic_node "$dep" $((depth + 1))
      fi
    done
  fi
}

# ============================================================================
# Generate Wave Table
# ============================================================================

generate_wave_table() {
  # Find max wave
  local max_wave=0
  for tn in "${all_task_nums[@]}"; do
    local w="${wave_assignment[$tn]:-0}"
    [[ "$w" -gt "$max_wave" ]] && max_wave=$w
  done

  if [[ "$max_wave" -eq 0 ]]; then
    return
  fi

  echo "**Dependency Waves**:"
  echo "| Wave | Tasks | Blocked by | Topics |"
  echo "|------|-------|------------|--------|"

  for (( w=1; w<=max_wave; w++ )); do
    # Collect tasks in this wave (sorted numerically)
    local tasks_in_wave=()
    for tn in "${all_task_nums[@]}"; do
      [[ "${wave_assignment[$tn]:-0}" -eq $w ]] && tasks_in_wave+=("$tn")
    done

    [[ ${#tasks_in_wave[@]} -eq 0 ]] && continue

    # Sort tasks numerically
    local sorted_tasks
    sorted_tasks=$(printf '%s\n' "${tasks_in_wave[@]}" | sort -n | tr '\n' ',' | sed 's/,$//')

    # Compute "Blocked by" = union of active deps for tasks in this wave
    declare -A blocking_set=()
    for tn in "${tasks_in_wave[@]}"; do
      local deps="${task_deps[$tn]:-}"
      if [[ -n "$deps" ]]; then
        read -ra dep_array <<< "$deps"
        for dep in "${dep_array[@]}"; do
          [[ -n "$dep" ]] && blocking_set["$dep"]=1
        done
      fi
    done

    local blocked_by="--"
    if [[ ${#blocking_set[@]} -gt 0 ]]; then
      blocked_by=$(printf '%s\n' "${!blocking_set[@]}" | sort -n | tr '\n' ',' | sed 's/,$//')
    fi

    # Compute Topics column: distinct topics in this wave, truncated to 3
    declare -A topic_set=()
    for tn in "${tasks_in_wave[@]}"; do
      local tp="${task_topic[$tn]:-}"
      [[ -n "$tp" ]] && topic_set["$tp"]=1
    done

    local topics_str="--"
    if [[ ${#topic_set[@]} -gt 0 ]]; then
      # Order by canonical topic order if available
      local -a ordered_topics=()
      for ct in "${active_topics_order[@]}"; do
        [[ -n "${topic_set[$ct]+x}" ]] && ordered_topics+=("$ct")
      done
      # Add any topics not in canonical order
      for tp in "${!topic_set[@]}"; do
        local found=0
        for ct in "${active_topics_order[@]}"; do
          [[ "$ct" == "$tp" ]] && found=1
        done
        [[ "$found" -eq 0 ]] && ordered_topics+=("$tp")
      done

      if [[ ${#ordered_topics[@]} -gt 3 ]]; then
        topics_str="${ordered_topics[0]}, ${ordered_topics[1]}, ${ordered_topics[2]}, ..."
      else
        topics_str=$(printf '%s, ' "${ordered_topics[@]}" | sed 's/, $//')
      fi
    fi

    echo "| $w | $sorted_tasks | $blocked_by | $topics_str |"
  done
}

# ============================================================================
# Generate Dependency Tree via DFS
# ============================================================================

declare -A visited_in_tree  # tracks tasks already fully printed

# Format status for display (convert state.json status to display format)
format_status() {
  local raw="$1"
  case "$raw" in
    not_started)  echo "NOT STARTED" ;;
    researching)  echo "RESEARCHING" ;;
    researched)   echo "RESEARCHED" ;;
    planning)     echo "PLANNING" ;;
    planned)      echo "PLANNED" ;;
    implementing) echo "IMPLEMENTING" ;;
    completed)    echo "COMPLETED" ;;
    blocked)      echo "BLOCKED" ;;
    abandoned)    echo "ABANDONED" ;;
    partial)      echo "PARTIAL" ;;
    expanded)     echo "EXPANDED" ;;
    *)            echo "$(echo "$raw" | tr '[:lower:]' '[:upper:]')" ;;
  esac
}

# Print tree entry for a task at given indent depth
# depth 0: no prefix; depth 1: "  └─ "; depth 2: "    └─ "; etc.
print_tree_node() {
  local task_num="$1"
  local depth="$2"

  local prefix=""
  if [[ "$depth" -gt 0 ]]; then
    # Build indent: (depth-1)*2 spaces + "  └─ "
    local pad
    pad=$(printf '%*s' $(( (depth - 1) * 2 )) '')
    prefix="${pad}  └─ "
  fi

  local status_raw="${task_status[$task_num]:-not_started}"
  local status_display
  status_display=$(format_status "$status_raw")

  local desc
  desc="${task_desc[$task_num]:-}"
  if [[ -z "$desc" ]]; then
    desc="(no description)"
  fi

  # Check if already visited (diamond dep)
  if [[ -n "${visited_in_tree[$task_num]+x}" && "$depth" -gt 0 ]]; then
    echo "${prefix}${task_num} [${status_display}] — ${desc} (see above)"
    return
  fi

  echo "${prefix}${task_num} [${status_display}] — ${desc}"
  visited_in_tree["$task_num"]=1

  # Print this task's active successors (tasks that depend on this task, indented below)
  local deps="${task_successors[$task_num]:-}"
  if [[ -n "$deps" ]]; then
    # Sort successors numerically for consistent output
    local sorted_deps
    sorted_deps=$(echo "$deps" | tr ' ' '\n' | sort -n | tr '\n' ' ')
    read -ra dep_array <<< "$sorted_deps"
    for dep in "${dep_array[@]}"; do
      [[ -z "$dep" ]] && continue
      # Only print if successor is in our active set
      if [[ -n "${task_status[$dep]+x}" ]]; then
        print_tree_node "$dep" $((depth + 1))
      fi
    done
  fi
}

generate_dependency_tree() {
  # Find root tasks: tasks with no active dependencies
  local -a roots=()
  for tn in "${all_task_nums[@]}"; do
    local deps="${task_deps[$tn]:-}"
    if [[ -z "$deps" ]]; then
      roots+=("$tn")
    fi
  done

  # Also include tasks whose deps are all at lower waves (handled by visited set)
  # Sort roots numerically for consistent output
  local sorted_roots
  sorted_roots=$(printf '%s\n' "${roots[@]}" | sort -n)

  echo "**Dependency Tree** (indented = depends on parent):"
  echo ""

  # Print tree for each root
  while IFS= read -r root; do
    [[ -z "$root" ]] && continue
    print_tree_node "$root" 0
  done <<< "$sorted_roots"

  # Print any tasks not yet visited (may have deps but none are active roots)
  # This handles cases where all a task's deps are terminal (so it's effectively a root)
  # but was not caught by the above (shouldn't happen normally, but just in case)
  for tn in $(printf '%s\n' "${all_task_nums[@]}" | sort -n); do
    if [[ -z "${visited_in_tree[$tn]+x}" ]]; then
      print_tree_node "$tn" 0
    fi
  done

}

# ============================================================================
# Read Existing Goal Line
# ============================================================================

read_existing_goal() {
  if [[ ! -f "$TODO_FILE" ]]; then
    echo ""
    return
  fi

  # Find the Task Order section and look for Goal line
  local in_section=0
  local goal_line=""
  while IFS= read -r line; do
    if [[ "$line" =~ ^##\ Task\ Order$ ]]; then
      in_section=1
      continue
    fi
    if [[ "$in_section" -eq 1 && "$line" =~ ^##\  ]]; then
      break  # Next section, stop
    fi
    if [[ "$in_section" -eq 1 && "$line" =~ ^\*\*Goal\*\*:\ (.+)$ ]]; then
      goal_line="${BASH_REMATCH[1]}"
      break
    fi
  done < "$TODO_FILE"
  echo "$goal_line"
}

# ============================================================================
# Generate Complete Section
# ============================================================================

generate_section() {
  local goal_text="$1"
  local today
  today=$(date -u +%Y-%m-%d)

  echo "## Task Order"
  echo ""
  echo "*Updated ${today}. Generated from state.json dependency graph.*"
  echo ""
  if [[ -n "$goal_text" ]]; then
    echo "**Goal**: ${goal_text}"
    echo ""
  fi

  generate_wave_table
  echo ""

  generate_grouped_section
}

# ============================================================================
# Section Replacement in TODO.md
# ============================================================================

replace_section() {
  local new_content="$1"
  local tmp_file
  tmp_file=$(mktemp)

  # Find Task Order section boundaries
  local section_start=0
  local section_end=0
  local line_num=0

  while IFS= read -r line; do
    line_num=$((line_num + 1))
    if [[ "$line" =~ ^##\ Task\ Order$ ]]; then
      section_start=$line_num
    fi
    if [[ "$section_start" -gt 0 && "$section_end" -eq 0 && "$line_num" -gt "$section_start" ]]; then
      if [[ "$line" =~ ^##\  ]]; then
        section_end=$line_num
        break
      fi
    fi
  done < "$TODO_FILE"

  if [[ "$section_start" -eq 0 ]]; then
    echo "WARNING: ## Task Order section not found in $TODO_FILE — cannot replace" >&2
    return 1
  fi

  # section_end is either the line number of the next ## heading, or 0 (EOF)
  # Write: lines before section_start, new content, lines from section_end onward

  # Write lines 1 to (section_start - 1)
  if [[ "$section_start" -gt 1 ]]; then
    head -n "$((section_start - 1))" "$TODO_FILE" > "$tmp_file"
  else
    : > "$tmp_file"
  fi

  # Write new section content (echo adds one trailing newline)
  echo "$new_content" >> "$tmp_file"

  # Add blank line separator before next section heading
  if [[ "$section_end" -gt 0 ]]; then
    echo "" >> "$tmp_file"
    tail -n +"${section_end}" "$TODO_FILE" >> "$tmp_file"
  fi

  # Replace original file
  mv "$tmp_file" "$TODO_FILE"
}

# ============================================================================
# Main
# ============================================================================

# Build graph data
build_graph

if [[ ${#all_task_nums[@]} -eq 0 ]]; then
  echo "INFO: No active non-terminal tasks found in $STATE_FILE" >&2
  exit 0
fi

# Build successors map (inverse of task_deps: dep -> tasks that depend on it)
build_successors_map

# Load topic assignments from state.json
load_topics

# Compute waves
compute_waves

# Compute connected components (used for implicit grouping within topic sections)
compute_connected_components

# Determine goal text
if [[ -n "$GOAL_OVERRIDE" ]]; then
  GOAL_TEXT="$GOAL_OVERRIDE"
elif [[ "$MODE" == "update" ]]; then
  GOAL_TEXT=$(read_existing_goal)
else
  GOAL_TEXT=""
fi

# Generate the section content
SECTION_CONTENT=$(generate_section "$GOAL_TEXT")

if [[ "$MODE" == "print" ]]; then
  echo "$SECTION_CONTENT"
elif [[ "$MODE" == "update" ]]; then
  replace_section "$SECTION_CONTENT"
  echo "OK: Task Order section updated in $TODO_FILE"
fi
