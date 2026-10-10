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
# Every invocation that reaches mode dispatch -- i.e. passes argument validation -- prints one
# always-present machine-readable stderr marker, on success AND on failure:
#   <!-- roadmap-generation mode=M tasks=N topics=T runs=R pruned=P retained=A -->
# This never affects the exit code -- it is a diagnostic, not a failure signal. --help and a
# usage/argument-validation error happen before mode dispatch and print only their own message
# instead. A failure after that point additionally emits one named stderr line
# ("ERROR: roadmap-integration.sh failed (mode=M) at line L: exit status N") before the marker.
#
# Destructive-overwrite refusal (PERMANENT property, not a transitional guard): --regenerate and
# --prune both classify the existing ROADMAP.md's section vocabulary (detect_layout: "classic",
# "stage", or "unknown") before touching the file, and refuse loudly -- a named reason on
# stderr, non-zero exit, no write -- on any vocabulary this script cannot round-trip. This never
# becomes "proceed and hope": an unrecognised layout is never guessed at or overwritten with a
# fixed template.

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

# ─── Always-present marker + named failure diagnostics, installed immediately after argument
# validation so every invocation that reaches this point -- success or failure -- is covered.
# --help and the argument-validation errors above already print their own message and exit
# before this point, so they are deliberately out of scope (Decision 3). ─────────────────────
MARKER_EMITTED=0
RUNS_COUNT=0
PRUNED_COUNT=0
RETAINED_COUNT=0

# emit_marker -- prints the six-field stderr marker exactly once, reading every counter with a
# 0 default so it is safe to fire before task_count/topic_count/RUNS_COUNT/PRUNED_COUNT/
# RETAINED_COUNT have been computed (i.e. a failure early in mode dispatch).
emit_marker() {
  [[ "$MARKER_EMITTED" -eq 1 ]] && return 0
  MARKER_EMITTED=1
  echo "<!-- roadmap-generation mode=${MODE} tasks=${task_count:-0} topics=${topic_count:-0} runs=${RUNS_COUNT:-0} pruned=${PRUNED_COUNT:-0} retained=${RETAINED_COUNT:-0} -->" >&2
}
trap emit_marker EXIT

# ERR fires before the shell exits under set -e, so this line always precedes the EXIT trap's
# marker on a failure -- the diagnosability fix for sub-fault 1 (a silent, undiagnosable abort).
trap 'echo "ERROR: roadmap-integration.sh failed (mode=$MODE) at line $LINENO: exit status $?" >&2' ERR

# ─── Terminal-set filter (status-vocabulary.sh anchors the enum; the terminal subset below is
# the same three values generate-task-order.sh's get_active_tasks() excludes) ──────────────────
TERMINAL_JQ='["completed","abandoned","expanded"]'

# ─── Active (non-terminal) task list, sorted ascending by project_number ───────────────────────
active_tasks_json="$(jq -c --argjson terminal "$TERMINAL_JQ" \
  '[.active_projects[] | select(([.status] | inside($terminal)) | not)] | sort_by(.project_number)' \
  "$STATE_PATH")"

active_ids_json="$(jq -c '[.[].project_number]' <<<"$active_tasks_json")"

active_topics_json="$(jq -c '.active_topics // []' "$STATE_PATH")"

# task_count/topic_count are computed here (rather than at the bottom of the file, where the
# marker used to be emitted) so a failure anywhere in mode dispatch still has real values for
# the EXIT trap's marker, instead of relying on the ${:-0} default for every invocation.
task_count="$(jq -r 'length' <<<"$active_tasks_json")"
topic_count="$(jq -r '.[] | .topic' <<<"$active_tasks_json" 2>/dev/null | sort -u | sed '/^null$/d' | wc -l | tr -d ' ')"

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

# ─── Retention maps, populated by --regenerate's retention parser only (stay empty for
# --print, which has no authored-retention input). Declared here, globally, so status_token
# and render_open_work can consult them uniformly in every mode. ───────────────────────────────
declare -A RETAIN_DESC=()
declare -A RETAIN_ANNOT=()
declare -A RETAIN_EXT=()

# ─── status_token <project_number> ──────────────────────────────────────────────────────────
# Precedence: HOLD > IN FLIGHT > BLOCKED > PARTIAL > EXT-BLOCKED > blocked:N[,M...] > ready
# EXT-BLOCKED has no schema source; it is only ever produced from RETAIN_EXT (populated by
# --regenerate's retention parser from the existing file). --print leaves RETAIN_EXT empty, so
# it never emits EXT-BLOCKED, exactly as documented.
status_token() {
  local task_json="$1" tn status blocked_csv
  tn="$(jq -r '.project_number' <<<"$task_json")"
  status="$(jq -r '.status' <<<"$task_json")"
  case "$status" in
    hold) echo "HOLD"; return ;;
    implementing) echo "IN FLIGHT"; return ;;
    blocked) echo "BLOCKED"; return ;;
    partial) echo "PARTIAL"; return ;;
  esac
  if [[ -n "${RETAIN_EXT[$tn]+set}" ]]; then
    echo "EXT-BLOCKED"
    return
  fi
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
      # Authored override (retained from the existing file) wins verbatim, no truncation;
      # otherwise truncate the title-derived fallback so "{num} {tok}  {desc}" stays <= 100
      # chars before any annotation.
      local prefix width avail trimmed
      prefix="$(printf '%s %s' "$num" "$tok")"
      width=${#prefix}
      if [[ "$width" -lt 20 ]]; then
        printf -v prefix '%-20s' "$prefix"
      else
        prefix="${prefix}  "
      fi
      if [[ -n "${RETAIN_DESC[$num]+set}" ]]; then
        trimmed="${RETAIN_DESC[$num]}"
      else
        avail=$((100 - ${#prefix}))
        trimmed="$desc"
        if [[ "${#trimmed}" -gt "$avail" && "$avail" -gt 3 ]]; then
          trimmed="${trimmed:0:$((avail - 3))}..."
        fi
      fi
      if [[ -n "${RETAIN_ANNOT[$num]+set}" ]]; then
        printf '%s%s   <- %s\n' "$prefix" "$trimmed" "${RETAIN_ANNOT[$num]}"
      else
        printf '%s%s\n' "$prefix" "$trimmed"
      fi
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

# ─── Section-boundary helpers (used only by --regenerate/--prune, which read the existing file) ─

# CLASSIC_HEADERS -- the eight literal headers roadmap-format.md's classic layout requires, in
# order. Anchors detect_layout's classic predicate and the refusal message's header listing.
CLASSIC_HEADERS=(
  "## Goal"
  "## Gate state"
  "## Next"
  "## Open work"
  "## Checks before and after every call"
  "## Settled decisions (do not re-litigate)"
  "## Standing rules"
  "## Unfiled observations (none worth a task yet)"
)

# body_has_orchestrate_fence BODY -> status 0 iff some fenced code block (a line that is exactly
# ``` optionally followed by a language tag, e.g. ```bash) within BODY contains at least one line
# matching ^/orchestrate ; status 1 otherwise. Used both by roadmap_has_orchestrate_fence (whole
# file, for detect_layout) and directly by mode_regenerate_stage (one already-split section body,
# to locate which retained section is the run-order section).
body_has_orchestrate_fence() {
  local body="$1"
  awk '
    /^```/ { in_fence = !in_fence; next }
    in_fence && /^\/orchestrate / { found = 1 }
    END { exit (found ? 0 : 1) }
  ' <<<"$body"
}

# roadmap_has_orchestrate_fence FILE -> body_has_orchestrate_fence applied to the whole file's
# content. Helper for detect_layout's stage predicate (checked before any section splitting).
roadmap_has_orchestrate_fence() {
  body_has_orchestrate_fence "$(cat "$1")"
}

# detect_layout FILE -> "classic" | "stage" | "unknown"
#
# This is the permanent destructive-overwrite-refusal gate (sub-fault 3): both write modes call
# this before touching the file, and refuse loudly rather than guess on anything this script
# cannot round-trip. Detection is structural, never exact-header matching, for "stage" -- the
# stage layout's own headers have already been observed to drift by hand-rename (Decision 1).
#
#   classic: every literal header in CLASSIC_HEADERS is present (exact match IS correct here --
#            the classic vocabulary is defined as exactly those eight headers, matched the same
#            way load_existing_sections' extract_section calls match them).
#   stage:   a header matching ^## Stage [0-9]+ exists, AND some section's body holds a fenced
#            /orchestrate block (roadmap_has_orchestrate_fence above) -- survives a cosmetic
#            rename of "## Run order at a glance" or "## Stage N -- ..." text.
#   unknown: neither predicate matches.
detect_layout() {
  local file="$1" h is_classic=1
  for h in "${CLASSIC_HEADERS[@]}"; do
    grep -qxF "$h" "$file" || { is_classic=0; break; }
  done
  if [[ "$is_classic" -eq 1 ]]; then
    echo "classic"
    return 0
  fi

  if grep -qE '^## Stage [0-9]+' "$file" && roadmap_has_orchestrate_fence "$file"; then
    echo "stage"
    return 0
  fi

  echo "unknown"
}

# refuse_unrecognised_layout MODE LAYOUT -> prints a named, loud refusal to stderr (listing the
# file's actual ## headers and the two recognised vocabularies) and returns 1. Called by both
# write modes before load_existing_sections / any write attempt. PERMANENT property, not a
# transitional guard -- see roadmap-format.md's destructive-overwrite-refusal subsection.
refuse_unrecognised_layout() {
  local mode="$1" layout="$2" reason=""
  case "$layout" in
    unknown)
      reason="its section headers match neither the classic eight-header vocabulary nor the stage-based structural predicate (a '## Stage N' header plus a fenced /orchestrate block)"
      ;;
    stage)
      reason="the stage-based layout is not yet round-tripped by --${mode}"
      ;;
  esac
  {
    echo "ERROR: --${mode} refuses to write ${ROADMAP_PATH}: ${reason}."
    echo "       Recognised vocabularies: classic (the eight literal headers in roadmap-format.md's"
    echo "       Section Order table) or stage (a '## Stage N' header plus a fenced /orchestrate block)."
    echo "       Actual headers in this file:"
    # A totally degenerate "unknown" file (zero "## " headers at all) makes grep's own no-match
    # the normal case here too, not a failure -- guarded the same way as covered_ids_from, found
    # by this phase's audit rather than assumed absent.
    grep -n '^## ' "$ROADMAP_PATH" | sed 's/^/         /' || true
  } >&2
  return 1
}

# extract_section FILE HEADER_LITERAL -> body between HEADER_LITERAL and the next `^## ` header
# (or EOF), EXCLUDING the header line itself but INCLUDING the blank line that immediately
# follows it. Trailing blank lines are stripped automatically by command-substitution capture
# at the call site -- callers reassemble with exactly one blank line between sections.
extract_section() {
  local file="$1" header="$2"
  awk -v hdr="$header" '
    BEGIN { printing = 0 }
    $0 == hdr { printing = 1; next }
    printing && /^## / { printing = 0 }
    printing { print }
  ' "$file"
}

# extract_preamble FILE -> lines between the `# Roadmap` title and the first `## ` header.
extract_preamble() {
  local file="$1"
  awk 'NR == 1 { next } /^## / { exit } { print }' "$file"
}

# strip_coverage_appendix -> reads a ## Next body on stdin, prints it back with any
# previously-generated coverage appendix (and the single blank line preceding it) removed, so
# --regenerate always rebuilds that block fresh rather than accumulating stale copies.
strip_coverage_appendix() {
  awk '
    /^\*\*Coverage appendix \(uncovered tasks\)\*\*:$/ { exit }
    { buf[NR] = $0 }
    END {
      n = NR
      if (n > 0 && buf[n] == "") n--
      for (i = 1; i <= n; i++) print buf[i]
    }
  '
}

# covered_ids_from BODY -> JSON array of every task number named in a "/orchestrate ..." line
# within BODY (used to compute which ready tasks are NOT yet covered by a retained Run line).
# No-match (an empty or /orchestrate-free BODY) is the normal, expected case for a classic
# ## Next body with no authored Run lines yet -- not a failure. The trailing `|| true` makes
# this pipeline's exit status always 0 (matching the pattern two lines below for RUNS_COUNT);
# jq still prints "[]" correctly from empty grep/sort output regardless of their own exit codes,
# since command substitution captures stdout independent of the exit status that `|| true`
# overrides. THE CRASH SITE: under `set -euo pipefail`, the leading grep's exit 1 on no-match
# previously propagated through this whole command substitution and killed the script.
covered_ids_from() {
  local body="$1"
  grep -E '^/orchestrate ' <<<"$body" | grep -oE '[0-9]+' | sort -nu | jq -R -s -c \
    'split("\n") | map(select(length > 0) | tonumber)' || true
}

# assemble_roadmap PREAMBLE GOAL GATE NEXT OPENWORK CHECKS DECISIONS RULES OBS -> the full file.
assemble_roadmap() {
  cat <<'_RM_ASSEMBLE_EOF_'
# Roadmap
_RM_ASSEMBLE_EOF_
  printf '%s\n\n## Goal\n%s\n\n## Gate state\n%s\n\n## Next\n%s\n\n## Open work\n%s\n\n## Checks before and after every call\n%s\n\n## Settled decisions (do not re-litigate)\n%s\n\n## Standing rules\n%s\n\n## Unfiled observations (none worth a task yet)\n%s\n' \
    "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9"
}

# write_or_diff NEW_CONTENT -> --dry-run prints a unified diff and writes nothing; otherwise
# writes NEW_CONTENT to a staging file and mv's it into place atomically.
write_or_diff() {
  local new_content="$1" tmp
  if [[ "$DRY_RUN" -eq 1 ]]; then
    tmp="$(mktemp)"
    printf '%s\n' "$new_content" >"$tmp"
    diff -u "$ROADMAP_PATH" "$tmp" || true
    rm -f "$tmp"
  else
    tmp="$(mktemp "$(dirname "$ROADMAP_PATH")/.roadmap-integration.XXXXXX")"
    printf '%s\n' "$new_content" >"$tmp"
    mv "$tmp" "$ROADMAP_PATH"
  fi
}

# parse_retention OPEN_WORK_BODY -> populates the global RETAIN_DESC/RETAIN_ANNOT/RETAIN_EXT
# maps from the EXISTING file's task lines. A task's description is treated as an authored
# override whenever it already has a line in the existing file at all (first-appearance is the
# only case that falls back to the title-derived render) -- see roadmap-format.md's Open work
# Grammar for the operational definition this implements.
parse_retention() {
  local body="$1" line num rest2 tok desc rest annot
  RETAIN_DESC=(); RETAIN_ANNOT=(); RETAIN_EXT=()
  while IFS= read -r line; do
    [[ "$line" =~ ^[0-9]+\  ]] || continue
    if [[ "$line" == *"   <- "* ]]; then
      annot="${line##*   <- }"
      rest="${line%   <- *}"
    else
      annot=""
      rest="$line"
    fi
    read -r num rest2 <<<"$rest"
    [[ -n "$num" ]] || continue
    # "IN FLIGHT" is the one two-word token in the closed vocabulary; every other token is a
    # single word (ready, HOLD, BLOCKED, PARTIAL, EXT-BLOCKED, blocked:N[,M...]).
    if [[ "$rest2" == "IN FLIGHT"[[:space:]]* ]]; then
      tok="IN FLIGHT"
      read -r desc <<<"${rest2#IN FLIGHT}"
    else
      read -r tok desc <<<"$rest2"
    fi
    RETAIN_DESC["$num"]="$desc"
    [[ -n "$annot" ]] && RETAIN_ANNOT["$num"]="$annot"
    [[ "$tok" == "EXT-BLOCKED" ]] && RETAIN_EXT["$num"]=1
  done <<<"$body"
}

# count_terminal_task_lines BODY -> number of task lines in BODY whose task number is NOT in
# the active (non-terminal) set -- i.e. how many --prune would remove from ## Open work.
count_terminal_task_lines() {
  local body="$1" count=0 line tn
  while IFS= read -r line; do
    if [[ "$line" =~ ^([0-9]+)\  ]]; then
      tn="${BASH_REMATCH[1]}"
      if ! jq -e --argjson n "$tn" '. as $a | $a | index($n) != null' <<<"$active_ids_json" >/dev/null 2>&1; then
        count=$((count + 1))
      fi
    fi
  done <<<"$body"
  echo "$count"
}

# count_pruned_next_ids BODY -> number of task-id occurrences across ## Next's Run lines that
# --prune would drop (terminal ids named in a /orchestrate line).
count_pruned_next_ids() {
  local body="$1" count=0 line ids_csv id
  while IFS= read -r line; do
    [[ "$line" =~ ^/orchestrate\  ]] || continue
    ids_csv="${line#/orchestrate }"
    ids_csv="${ids_csv%%   #*}"
    ids_csv="${ids_csv//[[:space:]]/}"
    IFS=',' read -ra __ids <<<"$ids_csv"
    for id in "${__ids[@]}"; do
      [[ -n "$id" ]] || continue
      if ! jq -e --argjson n "$id" '. as $a | $a | index($n) != null' <<<"$active_ids_json" >/dev/null 2>&1; then
        count=$((count + 1))
      fi
    done
  done <<<"$body"
  echo "$count"
}

# prune_open_work_body BODY -> BODY with every terminal task line removed, each surviving
# block's "(count)" header corrected, and any block left with zero surviving tasks dropped
# entirely (header + fences). Touches nothing else.
prune_open_work_body() {
  local body="$1" active_csv
  active_csv="$(jq -r 'join(",")' <<<"$active_ids_json")"
  awk -v active_csv="$active_csv" '
    BEGIN {
      n = split(active_csv, arr, ",")
      for (i = 1; i <= n; i++) active[arr[i]] = 1
    }
    { lines[++total] = $0 }
    END {
      out_n = 0
      i = 1
      while (i <= total) {
        line = lines[i]
        if (line == "```") {
          j = i + 1
          fence_n = 0
          kept = 0
          while (j <= total && lines[j] != "```") {
            if (match(lines[j], /^[0-9]+ /)) {
              tn = lines[j]
              sub(/ .*/, "", tn)
              if (tn in active) {
                fence[++fence_n] = lines[j]
                kept++
              }
            } else {
              fence[++fence_n] = lines[j]
            }
            j++
          }
          if (kept > 0) {
            if (out_n > 0 && match(out[out_n], /\([0-9]+\)\*\*$/)) {
              hdr = out[out_n]
              sub(/\([0-9]+\)\*\*$/, "(" kept ")**", hdr)
              out[out_n] = hdr
            }
            out[++out_n] = "```"
            for (k = 1; k <= fence_n; k++) out[++out_n] = fence[k]
            out[++out_n] = "```"
          } else if (out_n > 0) {
            out_n--
          }
          i = j + 1
          continue
        }
        out[++out_n] = line
        i++
      }
      for (k = 1; k <= out_n; k++) print out[k]
    }
  ' <<<"$body"
}

# prune_next_body BODY -> BODY with terminal task ids removed from each Run line's task list
# (dropping the whole line if every task it names is terminal); every other line (intro prose,
# why-this-order, an existing coverage appendix) passes through completely unchanged.
prune_next_body() {
  local body="$1" active_csv
  active_csv="$(jq -r 'join(",")' <<<"$active_ids_json")"
  awk -v active_csv="$active_csv" '
    BEGIN {
      n = split(active_csv, arr, ",")
      for (i = 1; i <= n; i++) active[arr[i]] = 1
    }
    {
      line = $0
      if (match(line, /^\/orchestrate /)) {
        rationale = ""
        core = line
        pos = index(line, "   # ")
        if (pos > 0) {
          rationale = substr(line, pos)
          core = substr(line, 1, pos - 1)
        }
        tasklist = core
        sub(/^\/orchestrate /, "", tasklist)
        gsub(/[ \t]/, "", tasklist)
        n2 = split(tasklist, ids, ",")
        joined = ""
        kept = 0
        for (k = 1; k <= n2; k++) {
          if (ids[k] in active) {
            if (joined != "") joined = joined ", "
            joined = joined ids[k]
            kept++
          }
        }
        if (kept == n2) {
          print line
        } else if (kept > 0) {
          print "/orchestrate " joined rationale
        }
        next
      }
      print line
    }
  ' <<<"$body"
}

# extract_open_work_trailer BODY -> any free-standing authored prose that follows the LAST
# fenced topic block in ## Open work (e.g. a "**342's hold**: ..." explanatory paragraph that
# is not itself inside a fence). --regenerate rebuilds the fenced blocks from scratch but must
# not discard this trailing prose; --prune's line-level pass already preserves it for free
# since it only ever touches lines inside a fence.
extract_open_work_trailer() {
  local body="$1"
  awk '
    { lines[++n] = $0; if ($0 == "```") last_fence = n }
    END {
      if (last_fence == 0 || last_fence >= n) { exit }
      for (i = last_fence + 1; i <= n; i++) print lines[i]
    }
  ' <<<"$body"
}

# load_existing_sections -> extracts every section of $ROADMAP_PATH into the globals
# RM_PREAMBLE/RM_GOAL/RM_GATE/RM_NEXT/RM_OPEN_WORK/RM_CHECKS/RM_DECISIONS/RM_RULES/RM_OBS.
load_existing_sections() {
  RM_PREAMBLE="$(extract_preamble "$ROADMAP_PATH")"
  RM_GOAL="$(extract_section "$ROADMAP_PATH" "## Goal")"
  RM_GATE="$(extract_section "$ROADMAP_PATH" "## Gate state")"
  RM_NEXT="$(extract_section "$ROADMAP_PATH" "## Next")"
  RM_OPEN_WORK="$(extract_section "$ROADMAP_PATH" "## Open work")"
  RM_CHECKS="$(extract_section "$ROADMAP_PATH" "## Checks before and after every call")"
  RM_DECISIONS="$(extract_section "$ROADMAP_PATH" "## Settled decisions (do not re-litigate)")"
  RM_RULES="$(extract_section "$ROADMAP_PATH" "## Standing rules")"
  RM_OBS="$(extract_section "$ROADMAP_PATH" "## Unfiled observations (none worth a task yet)")"
}

# ─── Vocabulary-agnostic section splitter/reassembler (stage layout only; classic keeps its own
# fixed-template load_existing_sections/assemble_roadmap pair above, untouched) ────────────────

# split_sections FILE -> populates RM_TITLE (the literal first line), RM_PREAMBLE_SPLIT (same
# contract as extract_preamble, reused directly), and the parallel arrays
# RM_SECTION_HEADERS[]/RM_SECTION_BODIES[], one entry per "^## " section in file order. A
# section's body excludes its header line but includes the blank line immediately following it
# (same contract as extract_section). Sections are located BY POSITION (line-number ranges from
# a single `grep -n '^## '` pass), never by re-matching header text -- unlike extract_section,
# this is safe even if two sections happen to share identical header text, which the classic
# layout's eight-literal-header vocabulary never does but a hand-authored stage layout could.
split_sections() {
  local file="$1"
  RM_TITLE="$(sed -n '1p' "$file")"
  RM_PREAMBLE_SPLIT="$(extract_preamble "$file")"
  RM_SECTION_HEADERS=()
  RM_SECTION_BODIES=()

  local -a header_lines=()
  local lineno rest
  while IFS=: read -r lineno rest; do
    [[ -n "$lineno" ]] || continue
    header_lines+=("$lineno")
  done < <(grep -n '^## ' "$file")

  [[ "${#header_lines[@]}" -gt 0 ]] || return 0

  local total_lines
  total_lines="$(wc -l < "$file")"

  local i start end body_start
  for ((i = 0; i < ${#header_lines[@]}; i++)); do
    start="${header_lines[$i]}"
    RM_SECTION_HEADERS+=("$(sed -n "${start}p" "$file")")
    if [[ $((i + 1)) -lt "${#header_lines[@]}" ]]; then
      end=$(( header_lines[i+1] - 1 ))
    else
      end="$total_lines"
    fi
    body_start=$((start + 1))
    if [[ "$body_start" -le "$end" ]]; then
      RM_SECTION_BODIES+=("$(sed -n "${body_start},${end}p" "$file")")
    else
      RM_SECTION_BODIES+=("")
    fi
  done
}

# assemble_stage_roadmap -> emits RM_TITLE, RM_PREAMBLE_SPLIT, then each
# RM_SECTION_HEADERS[i]/RM_SECTION_BODIES[i] pair in order -- the stage analogue of
# assemble_roadmap, with no fixed template: every retained section is emitted verbatim, none
# invented, none dropped. Caller splices a freshly rendered coverage appendix into the run-order
# section's body (in RM_SECTION_BODIES, in place) before calling this.
assemble_stage_roadmap() {
  printf '%s\n' "$RM_TITLE"
  printf '%s\n\n' "$RM_PREAMBLE_SPLIT"
  local i
  for ((i = 0; i < ${#RM_SECTION_HEADERS[@]}; i++)); do
    printf '%s\n%s\n\n' "${RM_SECTION_HEADERS[$i]}" "${RM_SECTION_BODIES[$i]}"
  done
}

mode_regenerate() {
  if [[ ! -f "$ROADMAP_PATH" ]]; then
    echo "NOTE: no roadmap tracked at ${ROADMAP_PATH}; --regenerate is a supported no-op." >&2
    RUNS_COUNT=0; PRUNED_COUNT=0; RETAINED_COUNT=0
    return 0
  fi

  local layout
  layout="$(detect_layout "$ROADMAP_PATH")"
  case "$layout" in
    classic) mode_regenerate_classic ;;
    stage) mode_regenerate_stage ;;
    *)
      refuse_unrecognised_layout regenerate unknown
      return 1
      ;;
  esac
}

# mode_regenerate_stage -- round-trips a stage-based roadmap: every "## " section is retained
# byte-for-byte except the run-order section (the first section whose body holds a fenced
# /orchestrate block, Decision 1's predicate), whose body gets its previously-generated coverage
# appendix stripped and a freshly rendered one appended. No other section is touched.
mode_regenerate_stage() {
  split_sections "$ROADMAP_PATH"
  RETAINED_COUNT="${#RM_SECTION_HEADERS[@]}"

  local run_order_idx=-1 i
  for ((i = 0; i < ${#RM_SECTION_HEADERS[@]}; i++)); do
    if body_has_orchestrate_fence "${RM_SECTION_BODIES[$i]}"; then
      run_order_idx="$i"
      break
    fi
  done

  if [[ "$run_order_idx" -ge 0 ]]; then
    local authored_run covered_ids_json new_coverage
    authored_run="$(strip_coverage_appendix <<<"${RM_SECTION_BODIES[$run_order_idx]}")"
    covered_ids_json="$(covered_ids_from "$authored_run")"
    RUNS_COUNT="$(grep -cE '^/orchestrate ' <<<"$authored_run" || true)"
    new_coverage="$(render_coverage_appendix "$covered_ids_json")"
    RM_SECTION_BODIES[$run_order_idx]="${authored_run}${new_coverage}"
  else
    RUNS_COUNT=0
  fi

  PRUNED_COUNT=0

  local new_content
  new_content="$(assemble_stage_roadmap)"
  new_content="$(cat -s <<<"$new_content")"

  write_or_diff "$new_content"
}

mode_regenerate_classic() {
  load_existing_sections

  parse_retention "$RM_OPEN_WORK"
  RETAINED_COUNT=$(( ${#RETAIN_DESC[@]} + ${#RETAIN_ANNOT[@]} + ${#RETAIN_EXT[@]} ))

  local authored_next covered_ids_json new_coverage new_open_work new_next new_content
  authored_next="$(strip_coverage_appendix <<<"$RM_NEXT")"
  covered_ids_json="$(covered_ids_from "$authored_next")"
  RUNS_COUNT="$(grep -cE '^/orchestrate ' <<<"$authored_next" || true)"

  local open_work_trailer
  open_work_trailer="$(extract_open_work_trailer "$RM_OPEN_WORK")"
  new_open_work=$'\n'"$(render_open_work)"
  if [[ -n "$open_work_trailer" ]]; then
    new_open_work="${new_open_work}"$'\n'"${open_work_trailer}"
  fi
  new_coverage="$(render_coverage_appendix "$covered_ids_json")"
  new_next="${authored_next}${new_coverage}"

  PRUNED_COUNT=0

  new_content="$(assemble_roadmap "$RM_PREAMBLE" "$RM_GOAL" "$RM_GATE" "$new_next" \
    "$new_open_work" "$RM_CHECKS" "$RM_DECISIONS" "$RM_RULES" "$RM_OBS")"
  new_content="$(cat -s <<<"$new_content")"

  write_or_diff "$new_content"
}

mode_prune() {
  if [[ ! -f "$ROADMAP_PATH" ]]; then
    echo "NOTE: no roadmap tracked at ${ROADMAP_PATH}; --prune is a supported no-op." >&2
    RUNS_COUNT=0; PRUNED_COUNT=0; RETAINED_COUNT=0
    return 0
  fi

  local layout
  layout="$(detect_layout "$ROADMAP_PATH")"
  case "$layout" in
    classic) mode_prune_classic ;;
    stage) mode_prune_stage ;;
    *)
      refuse_unrecognised_layout prune unknown
      return 1
      ;;
  esac
}

# mode_prune_stage -- drops terminal task ids from the run-order section's Run lines only
# (reusing prune_next_body unmodified: it only ever touches lines matching ^/orchestrate , so
# an in-fence "# Stage N" comment line passes through untouched, confirmed by this phase's test
# cases). Every other section is retained byte-for-byte. A stage layout has no "## Open work"
# section, so the Open-work half of classic --prune is a documented no-op here.
mode_prune_stage() {
  split_sections "$ROADMAP_PATH"

  local run_order_idx=-1 i
  for ((i = 0; i < ${#RM_SECTION_HEADERS[@]}; i++)); do
    if body_has_orchestrate_fence "${RM_SECTION_BODIES[$i]}"; then
      run_order_idx="$i"
      break
    fi
  done

  if [[ "$run_order_idx" -ge 0 ]]; then
    PRUNED_COUNT="$(count_pruned_next_ids "${RM_SECTION_BODIES[$run_order_idx]}")"
    RM_SECTION_BODIES[$run_order_idx]="$(prune_next_body "${RM_SECTION_BODIES[$run_order_idx]}")"
  else
    PRUNED_COUNT=0
  fi

  RUNS_COUNT=0
  RETAINED_COUNT=0

  local new_content
  new_content="$(assemble_stage_roadmap)"
  new_content="$(cat -s <<<"$new_content")"

  write_or_diff "$new_content"
}

mode_prune_classic() {
  load_existing_sections

  local pruned_ow pruned_next new_open_work new_next new_content
  pruned_ow="$(count_terminal_task_lines "$RM_OPEN_WORK")"
  pruned_next="$(count_pruned_next_ids "$RM_NEXT")"
  PRUNED_COUNT=$((pruned_ow + pruned_next))
  RUNS_COUNT=0
  RETAINED_COUNT=0

  new_open_work=$'\n'"$(prune_open_work_body "$RM_OPEN_WORK")"
  new_next=$'\n'"$(prune_next_body "$RM_NEXT")"

  new_content="$(assemble_roadmap "$RM_PREAMBLE" "$RM_GOAL" "$RM_GATE" "$new_next" \
    "$new_open_work" "$RM_CHECKS" "$RM_DECISIONS" "$RM_RULES" "$RM_OBS")"
  new_content="$(cat -s <<<"$new_content")"

  write_or_diff "$new_content"
}

case "$MODE" in
  print)
    output="$(mode_print)"
    printf '%s\n' "$output"
    ;;
  regenerate) mode_regenerate ;;
  prune) mode_prune ;;
esac
