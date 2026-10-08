#!/usr/bin/env bash
# roadmap-integration.sh - Generate the mechanically-derivable sections of specs/ROADMAP.md
#
# Format spec: context/formats/roadmap-format.md (the generation contract this script
# implements). Caller contract: context/patterns/roadmap-update.md.
#
# Usage:
#   roadmap-integration.sh [--print]                 Emit generated sections to stdout (default)
#   roadmap-integration.sh --regenerate [--dry-run]   Rebuild ## Open work and ## Next in place
#   roadmap-integration.sh --prune [--dry-run]        Drop terminal tasks / all-terminal Run lines
#
# Options:
#   --roadmap PATH     Path to ROADMAP.md (default: specs/ROADMAP.md under the repo root)
#   --state PATH       Path to state.json (default: specs/state.json under the repo root)
#   --max-tasks N      Coverage-appendix chunk size per wave (default: 8, matches
#                       commands/orchestrate.md's MAX_TASKS)
#   --dry-run          With --regenerate/--prune: print a diff, write nothing
#   --help             Show this usage and exit 0
#
# --print never touches disk; it has no authored-retention input (it does not read an existing
# ROADMAP.md), so its EXT-BLOCKED tokens are never emitted -- that token is authored-only and
# surfaces only via --regenerate/--prune's retention parser.
#
# Every invocation, every mode, prints one always-present machine-readable stderr marker:
#   <!-- roadmap-generation mode=M tasks=N topics=T runs=R pruned=P retained=A -->
# This never affects the exit code -- it is a diagnostic, not a failure signal.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
source "${SCRIPT_DIR}/lib/status-vocabulary.sh"

ROADMAP_PATH="${PROJECT_ROOT}/specs/ROADMAP.md"
STATE_PATH="${PROJECT_ROOT}/specs/state.json"
MODE="print"
MODE_FLAG_COUNT=0
DRY_RUN=0
MAX_TASKS=8

usage() {
  sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --print)
      MODE="print"; MODE_FLAG_COUNT=$((MODE_FLAG_COUNT + 1)); shift ;;
    --regenerate)
      MODE="regenerate"; MODE_FLAG_COUNT=$((MODE_FLAG_COUNT + 1)); shift ;;
    --prune)
      MODE="prune"; MODE_FLAG_COUNT=$((MODE_FLAG_COUNT + 1)); shift ;;
    --roadmap)
      ROADMAP_PATH="$2"; shift 2 ;;
    --state)
      STATE_PATH="$2"; shift 2 ;;
    --max-tasks)
      MAX_TASKS="$2"; shift 2 ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    --help|-h)
      usage; exit 0 ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$MODE_FLAG_COUNT" -gt 1 ]]; then
  echo "ERROR: only one of --print, --regenerate, --prune may be given (got $MODE_FLAG_COUNT)" >&2
  exit 1
fi

if ! [[ "$MAX_TASKS" =~ ^[0-9]+$ ]] || [[ "$MAX_TASKS" -lt 1 ]]; then
  echo "ERROR: --max-tasks must be a positive integer, got '$MAX_TASKS'" >&2
  exit 1
fi

if [[ ! -f "$STATE_PATH" ]]; then
  echo "ERROR: --state path does not exist: $STATE_PATH" >&2
  exit 1
fi

# ─── Terminal-set filter (status-vocabulary.sh anchors the enum; the terminal subset below is
# the same three values generate-task-order.sh's get_active_tasks() excludes) ──────────────────
TERMINAL_JQ='["completed","abandoned","expanded"]'

# ─── Active (non-terminal) task list, sorted ascending by project_number ───────────────────────
active_tasks_json="$(jq -c --argjson terminal "$TERMINAL_JQ" \
  '[.active_projects[] | select(([.status] | inside($terminal)) | not)] | sort_by(.project_number)' \
  "$STATE_PATH")"

active_ids_json="$(jq -c '[.[].project_number]' <<<"$active_tasks_json")"

active_topics_json="$(jq -c '.active_topics // []' "$STATE_PATH")"

# ─── Wave membership: parse generate-task-order.sh --print's Dependency Waves table ─────────────
# Consumed as a read-only subprocess only -- that script runs build_graph/compute_waves
# unconditionally at file scope (cannot be sourced). No wave/DAG algorithm is reimplemented here.
declare -A WAVE_OF
wave_header_found=0
in_table=0
wave_output="$("${SCRIPT_DIR}/generate-task-order.sh" --print)"
while IFS= read -r line; do
  if [[ "$in_table" -eq 0 ]]; then
    if [[ "$line" == '**Dependency Waves**:' ]]; then
      wave_header_found=1
      in_table=1
    fi
    continue
  fi
  case "$line" in
    '| Wave |'*|'|-'*)
      continue ;;
    '|'*)
      if [[ "$line" =~ ^\|\ ([0-9]+)\ \|\ ([0-9,]+)\  ]]; then
        wave_num="${BASH_REMATCH[1]}"
        IFS=',' read -ra __tids <<<"${BASH_REMATCH[2]}"
        for __t in "${__tids[@]}"; do
          WAVE_OF["$__t"]="$wave_num"
        done
      fi
      ;;
    *)
      break ;;
  esac
done <<<"$wave_output"

if [[ "$wave_header_found" -eq 0 ]]; then
  echo "ERROR: generate-task-order.sh --print did not emit a **Dependency Waves**: table" >&2
  exit 1
fi

# ─── status_token <project_number> ──────────────────────────────────────────────────────────
# Precedence: HOLD > IN FLIGHT > BLOCKED > PARTIAL > blocked:N[,M...] > ready
# (EXT-BLOCKED has no schema source; it is never produced here, only retained by
# --regenerate/--prune's authored-override parser.)
status_token() {
  local task_json="$1" status blocked_csv
  status="$(jq -r '.status' <<<"$task_json")"
  case "$status" in
    hold) echo "HOLD"; return ;;
    implementing) echo "IN FLIGHT"; return ;;
    blocked) echo "BLOCKED"; return ;;
    partial) echo "PARTIAL"; return ;;
  esac
  blocked_csv="$(jq -r --argjson active "$active_ids_json" \
    '[.dependencies[]? | select(. as $d | $active | index($d) != null)] | sort | join(",")' \
    <<<"$task_json")"
  if [[ -z "$blocked_csv" ]]; then
    echo "ready"
  else
    echo "blocked:${blocked_csv}"
  fi
}

# ─── token_rank <token> ─────────────────────────────────────────────────────────────────────
# Within-block ordering: closed-vocabulary tokens before blocked:N tokens, before ready.
token_rank() {
  case "$1" in
    HOLD) echo 0 ;;
    "IN FLIGHT") echo 1 ;;
    BLOCKED) echo 2 ;;
    PARTIAL) echo 3 ;;
    EXT-BLOCKED) echo 4 ;;
    blocked:*) echo 5 ;;
    ready) echo 6 ;;
    *) echo 7 ;;
  esac
}

# ─── topic_title <slug> ─────────────────────────────────────────────────────────────────────
# Sentence case: hyphens to spaces, only the first character capitalized. Matches the live
# file's convention (NOT task-order-format.md's per-word title case).
topic_title() {
  local slug="${1//-/ }"
  echo "${slug^}"
}

# ─── render_open_work ────────────────────────────────────────────────────────────────────────
# Emits the ## Open work body (topic blocks only, no section header) to stdout.
render_open_work() {
  local -a ordered_topics=()
  local -A seen_topic=()
  local t
  while IFS= read -r t; do
    [[ -n "$t" ]] || continue
    ordered_topics+=("$t")
    seen_topic["$t"]=1
  done < <(jq -r '.[]' <<<"$active_topics_json")

  # Append-extras: topics present on a task but absent from active_topics, first-encountered order
  local extra
  while IFS= read -r extra; do
    [[ -n "$extra" ]] || continue
    if [[ -z "${seen_topic[$extra]+set}" ]]; then
      ordered_topics+=("$extra")
      seen_topic["$extra"]=1
      echo "WARNING: topic '${extra}' has tasks but is absent from state.json active_topics; appending as its own block" >&2
    fi
  done < <(jq -r '[.[].topic | select(. != null)] | unique | .[]' <<<"$active_tasks_json")

  local has_uncategorized
  has_uncategorized="$(jq -r '[.[] | select(.topic == null)] | length' <<<"$active_tasks_json")"
  if [[ "$has_uncategorized" -gt 0 ]]; then
    ordered_topics+=("__uncategorized__")
  fi

  local topic first_block=1
  for topic in "${ordered_topics[@]}"; do
    local tasks_in_topic
    if [[ "$topic" == "__uncategorized__" ]]; then
      tasks_in_topic="$(jq -c '[.[] | select(.topic == null)]' <<<"$active_tasks_json")"
    else
      tasks_in_topic="$(jq -c --arg topic "$topic" '[.[] | select(.topic == $topic)]' <<<"$active_tasks_json")"
    fi
    local count
    count="$(jq -r 'length' <<<"$tasks_in_topic")"
    [[ "$count" -gt 0 ]] || continue

    [[ "$first_block" -eq 1 ]] || echo
    first_block=0

    local title="Uncategorized"
    [[ "$topic" == "__uncategorized__" ]] || title="$(topic_title "$topic")"

    echo "**${title} (${count})**"
    echo '```'

    # Compute (rank, task_number, token, description) rows, sort, then render each line.
    local tn task_json tok rank desc
    while IFS= read -r tn; do
      task_json="$(jq -c --argjson n "$tn" '.[] | select(.project_number == $n)' <<<"$active_tasks_json")"
      tok="$(status_token "$task_json")"
      rank="$(token_rank "$tok")"
      desc="$(jq -r '.title // .project_name' <<<"$task_json")"
      printf '%s|%s|%s|%s\n' "$rank" "$tn" "$tok" "$desc"
    done < <(jq -r '.[].project_number' <<<"$tasks_in_topic") | sort -t'|' -k1,1n -k2,2n | \
    while IFS='|' read -r _rank num tok desc; do
      # Truncate description so "{num} {tok}  {desc}" stays <= 100 chars before any annotation.
      local prefix width avail trimmed
      prefix="$(printf '%s %s' "$num" "$tok")"
      width=${#prefix}
      if [[ "$width" -lt 20 ]]; then
        printf -v prefix '%-20s' "$prefix"
      else
        prefix="${prefix}  "
      fi
      avail=$((100 - ${#prefix}))
      trimmed="$desc"
      if [[ "${#trimmed}" -gt "$avail" && "$avail" -gt 3 ]]; then
        trimmed="${trimmed:0:$((avail - 3))}..."
      fi
      printf '%s%s\n' "$prefix" "$trimmed"
    done

    echo '```'
  done
}

# ─── render_coverage_appendix ───────────────────────────────────────────────────────────────
# Dispatchable tasks (token == "ready") not named by any caller-supplied Run line, chunked per
# wave at --max-tasks. covered_ids_json is a JSON array of task numbers already in a Run block;
# in --print mode (no existing file read) this is always empty, so the appendix lists every
# ready task.
render_coverage_appendix() {
  local covered_ids_json="$1"
  # Build the ready set directly: status_token == "ready" and not already covered.
  local -a ready_ids=()
  local tn task_json
  while IFS= read -r tn; do
    task_json="$(jq -c --argjson n "$tn" '.[] | select(.project_number == $n)' <<<"$active_tasks_json")"
    if [[ "$(status_token "$task_json")" == "ready" ]]; then
      if ! jq -e --argjson n "$tn" '. as $c | $c | index($n) != null' <<<"$covered_ids_json" >/dev/null 2>&1; then
        ready_ids+=("$tn")
      fi
    fi
  done < <(jq -r '.[].project_number' <<<"$active_tasks_json")

  [[ "${#ready_ids[@]}" -gt 0 ]] || return 0

  # Group by wave (unassigned tasks get wave "0", sorted last isn't required -- numeric sort is fine).
  local -A by_wave=()
  local id w
  for id in "${ready_ids[@]}"; do
    w="${WAVE_OF[$id]:-0}"
    by_wave["$w"]="${by_wave[$w]:-} $id"
  done

  echo
  echo "**Coverage appendix (uncovered tasks)**:"
  echo '```'
  local wave_keys
  wave_keys="$(printf '%s\n' "${!by_wave[@]}" | sort -n)"
  while IFS= read -r w; do
    [[ -n "$w" ]] || continue
    # shellcheck disable=SC2206 # word-splitting on space-joined ids is intentional here
    local -a ids=(${by_wave[$w]})
    local i=0
    while [[ "$i" -lt "${#ids[@]}" ]]; do
      local chunk=("${ids[@]:$i:$MAX_TASKS}")
      local joined
      joined="$(IFS=', '; echo "${chunk[*]}")"
      echo "/orchestrate ${joined}"
      i=$((i + MAX_TASKS))
    done
  done <<<"$wave_keys"
  echo '```'
}

mode_print() {
  render_open_work
  render_coverage_appendix '[]'
}

mode_regenerate() {
  echo "ERROR: --regenerate is not yet implemented (Phase 4). Target: ${ROADMAP_PATH} (dry_run=${DRY_RUN})" >&2
  exit 1
}

mode_prune() {
  echo "ERROR: --prune is not yet implemented (Phase 4). Target: ${ROADMAP_PATH} (dry_run=${DRY_RUN})" >&2
  exit 1
}

case "$MODE" in
  print) output="$(mode_print)" ;;
  regenerate) mode_regenerate ;;
  prune) mode_prune ;;
esac

printf '%s\n' "$output"

task_count="$(jq -r 'length' <<<"$active_tasks_json")"
topic_count="$(jq -r '.[] | .topic' <<<"$active_tasks_json" 2>/dev/null | sort -u | sed '/^null$/d' | wc -l | tr -d ' ')"
echo "<!-- roadmap-generation mode=${MODE} tasks=${task_count} topics=${topic_count} runs=0 pruned=0 retained=0 -->" >&2
