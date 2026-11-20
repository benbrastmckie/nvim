#!/usr/bin/env bash
# roadmap-integration.sh - Render specs/ROADMAP.md, the whole file, from specs/state.json
#
# Format spec: context/formats/roadmap-format.md (the generation contract this script
# implements). Caller contract: context/patterns/roadmap-update.md.
#
# Usage:
#   roadmap-integration.sh [--print]                 Emit the whole rendered file to stdout
#                                                      (default)
#   roadmap-integration.sh --regenerate [--dry-run]   Write the rendered file in place
#   roadmap-integration.sh --prune [--dry-run]        DEPRECATED alias for --regenerate: a file
#                                                      rendered from live state accumulates no
#                                                      terminal cruft, so there is nothing left
#                                                      for a separate prune pass to remove
#
# Options:
#   --roadmap PATH     Path to ROADMAP.md (default: the store's roadmap_context.output_path
#                       under the repo root, else specs/ROADMAP.md)
#   --state PATH       Path to state.json (default: specs/state.json under the repo root)
#   --dry-run          With --regenerate/--prune: print a diff, write nothing
#   --help             Show this usage and exit 0
#
# The file is generated in full: an intro (primary_goals, a milestone status table), one section
# per roadmap_milestones entry in array order, then rules, conventions and repo context from
# roadmap_context plus the open tasks that sit in no batch. Nothing is read back out of the file
# being written, and this script exercises no judgment: which milestones exist, what belongs in
# which batch and in what order are all decided upstream and stored in state.
#
# Every invocation that reaches mode dispatch -- i.e. passes argument validation -- prints one
# always-present machine-readable stderr marker, on success AND on failure:
#   <!-- roadmap-generation mode=M tasks=N topics=T runs=R pruned=P retained=A -->
# runs= is the number of batches under milestones that are not closed; pruned= and retained= are
# always 0. This never affects the exit code -- it is a diagnostic, not a failure signal. --help
# and a usage/argument-validation error happen before mode dispatch and print only their own
# message instead. A failure after that point additionally emits one named stderr line
# ("ERROR: roadmap-integration.sh failed (mode=M) at line L: exit status N") before the marker.
#
# Destructive-overwrite refusal (PERMANENT property): --regenerate and --prune overwrite a file
# only when its first line is the generated sentinel (lib/roadmap-preflight-lib.sh), and create
# one only when the target is absent and the store holds at least one milestone. Any other file
# is hand-authored content this script cannot reproduce: the write is refused loudly -- a named
# reason on stderr, non-zero exit, no write -- and the refusal names
# migrate-roadmap-to-milestones.sh, which moves that content into state and a retained-prose
# file first.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
source "${SCRIPT_DIR}/lib/status-vocabulary.sh"
# roadmap-preflight-lib.sh is the sole owner of the layout-classification vocabulary
# (CLASSIC_HEADERS, the fence helpers, detect_layout) -- see that file's header for why it was
# extracted rather than left inline. Never re-inline a copy here.
source "${SCRIPT_DIR}/lib/roadmap-preflight-lib.sh"
# roadmap-entries-lib.sh answers "which batches are open" and "where does the roadmap render to"
# for both store shapes; this script keeps no jq of its own for either question.
source "${SCRIPT_DIR}/lib/roadmap-entries-lib.sh"

ROADMAP_PATH="${PROJECT_ROOT}/specs/ROADMAP.md"
ROADMAP_PATH_EXPLICIT=0
STATE_PATH="${PROJECT_ROOT}/specs/state.json"
MODE="print"
MODE_FLAG_COUNT=0
DRY_RUN=0

usage() {
  sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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
      ROADMAP_PATH="$2"; ROADMAP_PATH_EXPLICIT=1; shift 2 ;;
    --state)
      STATE_PATH="$2"; shift 2 ;;
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

if [[ ! -f "$STATE_PATH" ]]; then
  echo "ERROR: --state path does not exist: $STATE_PATH" >&2
  exit 1
fi
# ─── Always-present marker + named failure diagnostics, installed immediately after argument
# validation so every invocation that reaches this point -- success or failure -- is covered.
# --help and the argument-validation errors above already print their own message and exit
# before this point, so they are deliberately out of scope. ──────────────────────────────────
MARKER_EMITTED=0
# RUNS_COUNT -- the number of batches under milestones that are not closed, read through
# lib/roadmap-entries-lib.sh.
RUNS_COUNT=0
PRUNED_COUNT=0
RETAINED_COUNT=0
# ROADMAP_LAYOUT -- set by mode_regenerate before any write, so write_or_diff can name the
# layout in its OUTCOME: line.
ROADMAP_LAYOUT=""

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
# marker on a failure, so an abort is never silent.
trap 'echo "ERROR: roadmap-integration.sh failed (mode=$MODE) at line $LINENO: exit status $?" >&2' ERR

# ─── Output path and batch count, both through the accessor ─────────────────────────────────
# The output path comes from the store (roadmap_context.output_path, default specs/ROADMAP.md)
# unless --roadmap named one.
if [[ "$ROADMAP_PATH_EXPLICIT" -eq 0 ]]; then
  __rel_out="$(roadmap_entries_output_path "$STATE_PATH")"
  if [[ "$__rel_out" == /* || "$__rel_out" == ".." || "$__rel_out" == ../* \
        || "$__rel_out" == */../* || "$__rel_out" == */.. ]]; then
    echo "ERROR: roadmap_context.output_path must be a repository-relative path, got '${__rel_out}'" >&2
    exit 1
  fi
  ROADMAP_PATH="${PROJECT_ROOT}/${__rel_out}"
fi
if jq -e 'has("roadmap_milestones")' "$STATE_PATH" >/dev/null 2>&1; then
  RUNS_COUNT="$(roadmap_entries_batches "$STATE_PATH" | wc -l | tr -d ' ')"
fi

# ─── Terminal-set filter (status-vocabulary.sh anchors the enum; the terminal subset below is
# the same three values generate-task-order.sh's get_active_tasks() excludes) ──────────────────
TERMINAL_JQ='["completed","abandoned","expanded"]'

# ─── Active (non-terminal) task list, sorted ascending by project_number ───────────────────────
active_tasks_json="$(jq -c --argjson terminal "$TERMINAL_JQ" \
  '[.active_projects[] | select(([.status] | inside($terminal)) | not)] | sort_by(.project_number)' \
  "$STATE_PATH")"

active_ids_json="$(jq -c '[.[].project_number]' <<<"$active_tasks_json")"

# task_count/topic_count are computed here, before mode dispatch, so a failure anywhere in mode
# dispatch still has real values for the EXIT trap's marker.
task_count="$(jq -r 'length' <<<"$active_tasks_json")"
topic_count="$(jq -r '.[] | .topic' <<<"$active_tasks_json" 2>/dev/null | sort -u | sed '/^null$/d' | wc -l | tr -d ' ')"

# ─── status_token <project_number> ──────────────────────────────────────────────────────────
# Precedence: HOLD > IN FLIGHT > BLOCKED > PARTIAL > EXT-BLOCKED > blocked:N[,M...] > ready
# EXT-BLOCKED is schema-backed (the task entry's roadmap_ext_blocked boolean field) -- rendered
# in every mode, including --print, since it is a state field like any other, not an
# authored-only retention value.
status_token() {
  local task_json="$1" status blocked_csv ext_blocked
  status="$(jq -r '.status' <<<"$task_json")"
  case "$status" in
    hold) echo "HOLD"; return ;;
    implementing) echo "IN FLIGHT"; return ;;
    blocked) echo "BLOCKED"; return ;;
    partial) echo "PARTIAL"; return ;;
  esac
  ext_blocked="$(jq -r '.roadmap_ext_blocked // false' <<<"$task_json")"
  if [[ "$ext_blocked" == "true" ]]; then
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

# ─── Whole-file render ──────────────────────────────────────────────────────────────────────
#
# The file is rendered in three parts, in this order: an intro (primary goals, a milestone status
# table whose first column links to each milestone section, a link to the last section); one
# dashboard section per milestone in array order; then rules, conventions and repo context.
# Nothing is read back from the file being written, the batch `rationale` field is never
# rendered, and generate-task-order.sh is never consulted.
#
# MS_RENDER_JQ computes the whole structure in one jq pass and emits a line protocol, fields
# separated by the unit separator (U+001F):
#   L<US>text              a literal output line
#   BS / BE                start / end of a block of task rows (sorted by token rank, then number)
#   O<US>num               an open task row: its token comes from status_token()
#   X<US>num<US>tok<US>d   a task row whose token is already decided (`done`, `missing`)
# A member counts as done when it is terminal in active_projects, or absent from active_projects
# and present in the sibling archive/state.json. Counts are derived here on every render and are
# never stored.
# shellcheck disable=SC2016  # $-prefixed names below are jq variables, not shell expansions
MS_RENDER_JQ='
def clean: tostring | gsub("[\t\n\r\u001f]+"; " ");
def cell: clean | gsub("\\|"; "\\|");
def anchor: "milestone-" + (ascii_downcase | gsub("[^a-z0-9_-]"; "-"));
def L(s): "L\u001f" + s;
def frac(a; b): (a | tostring) + "/" + (b | tostring);
def review_text:
  (.review // {}) as $r
  | ($r.state // "none")
    + (if ($r.ref // "") == "" then "" else " on `" + ($r.ref | clean) + "`" end)
    + (if ($r.request // "") == "" then "" else ", " + ($r.request | clean) end)
    + (if ($r.updated // "") == "" then "" else " (updated " + ($r.updated | clean) + ")" end);
def listsec(h; items):
  if (items | length) > 0
  then L("### " + h), L(""), (items[] | L("- " + clean)), L("")
  else empty end;
def bsection($titles):
  if (.open | length) == 0 then
    L("**Batch " + (.n | tostring) + "** (done) -- " + (.description | clean)), L("")
  else
    L("**Batch " + (.n | tostring) + "** -- " + (.description | clean)
      + (if (.done | length) > 0
         then " (" + frac(.done | length; .ids | length) + " done)" else "" end)),
    L(""), L("```"),
    L("/orchestrate " + (.open | map(tostring) | join(", "))
      + (if .flags == "" then "" else " " + (.flags | clean) end)),
    "BS",
    ( . as $b | .ids[]
      | if IN($b.open[]) then "O\u001f" + tostring
        elif IN($b.done[]) then "X\u001f" + tostring + "\u001fdone\u001f" + ($titles[tostring] // "" | clean)
        else "X\u001f" + tostring + "\u001fmissing\u001f" end ),
    "BE", L("```"), L("")
  end;
def msection($titles):
  L("<a id=\"" + (.id | anchor) + "\"></a>"),
  L("## " + .id + ": " + (.title | clean)), L(""),
  ( if .status == "closed" then
      L("Closed" + (if .closed == "" then "" else " " + .closed end)
        + (if .t == 0 then "" else " -- " + frac(.t_done; .t) + " tasks done" end)
        + " -- review: " + .review
        + (if .note == "" then "" else " -- " + (.note | clean) end)),
      L("")
    else
      (if .aim == "" then empty else L(.aim | clean), L("") end),
      L("- **Progress**: " + .status + " -- "
        + (if .b == 0 then "no batches yet"
           else frac(.b_done; .b) + " batches, " + frac(.t_done; .t) + " tasks done" end)
        + (if .note == "" then "" else " -- " + (.note | clean) end)),
      L("- **Review**: " + .review),
      (if .gate == "" then empty else L("- **Gate**: " + (.gate | clean)) end),
      L(""),
      (.batches[] | bsection($titles))
    end );

($arch[0] // {}) as $a
| (.active_projects // []) as $ap
| [ ($a.archived_projects // [])[], ($a.completed_projects // [])[], ($a.abandoned_projects // [])[] ] as $archived
| [$ap[].project_number] as $apnums
| ( [$ap[] | select(.status | IN($terminal[])) | .project_number]
    + [$archived[].project_number | select(IN($apnums[]) | not)] | unique ) as $done
| [$ap[] | select(.status | IN($terminal[]) | not) | .project_number] as $open
| ( reduce ($ap[], $archived[]) as $t ({};
      ($t.project_number | tostring) as $k
      | if has($k) then . else .[$k] = ($t.title // $t.project_name // "") end) ) as $titles
| [ (.roadmap_milestones // [])[]
    | . as $m
    | [ ($m.batches // []) | to_entries[]
        | (.value.task_ids // []) as $ids
        | { n: (.key + 1),
            description: (.value.description // ""),
            flags: (.value.flags // ""),
            ids: $ids,
            open: [$ids[] | select(IN($open[]))],
            done: [$ids[] | select(IN($done[]))] } ] as $bs
    | { id: ($m.id | tostring),
        title: ($m.title // ""),
        aim: ($m.aim // ""),
        gate: ($m.gate // ""),
        status: ($m.progress.status // "planned"),
        closed: ($m.progress.closed // ""),
        note: ($m.progress.note // ""),
        review: ($m | review_text),
        review_state: ($m.review.state // "none"),
        review_request: ($m.review.request // ""),
        batches: $bs,
        b: ($bs | length),
        b_done: ([$bs[] | select((.open | length) == 0)] | length),
        t: ([$bs[].ids[]] | unique | length),
        t_done: ([$bs[].done[]] | unique | length) } ] as $ms
| ( (.primary_goals // []) | if type == "array" then map(select(type == "string" and length > 0)) else [] end ) as $pg
| ( if ($pg | length) > 0 then $pg
    else [(.active_goal // "") | select(type == "string" and length > 0)] end ) as $goals
| (.roadmap_context // {}) as $c
| ( $open - [$ms[] | select(.status == "closed" | not) | .batches[].ids[]] | sort ) as $unscheduled
| ( L($sentinel), L("# Roadmap"), L(""),
    ($goals[] | L("- " + clean)),
    (if ($goals | length) > 0 then L("") else empty end),
    ( if ($ms | length) > 0 then
        L("| Milestone | Status | Tasks done | Review |"),
        L("|---|---|---|---|"),
        ( $ms[]
          | L("| [" + ((.id + ": " + .title) | cell) + "](#" + (.id | anchor) + ") | "
              + (if .status == "closed"
                 then "closed" + (if .closed == "" then "" else " " + .closed end)
                 else .status end)
              + " | " + (if .t == 0 then "-" else frac(.t_done; .t) end)
              + " | " + (.review_state
                         + (if .review_request == "" then "" else " (" + (.review_request | cell) + ")" end))
              + " |") ),
        L("")
      else L("_No milestones recorded._"), L("") end ),
    L("See also: [Rules, conventions and repo context](#roadmap-context)"), L(""),
    ($ms[] | msection($titles)),
    L("<a id=\"roadmap-context\"></a>"),
    L("## Rules, conventions and repo context"), L(""),
    listsec("Repository"; ($c.overview // [])),
    listsec("Rules"; ($c.rules // [])),
    listsec("Conventions"; ($c.conventions // [])),
    ( if ($unscheduled | length) > 0 then
        L("### Open tasks in no batch"), L(""), L("```"),
        "BS", ($unscheduled[] | "O\u001f" + tostring), "BE",
        L("```"), L("")
      else empty end ) )
'

# format_task_row NUM TOKEN DESC ANNOT -> one member line: "{num} {token}" padded to 20 columns,
# the description truncated so the line stays within 100 characters before any annotation.
format_task_row() {
  local num="$1" tok="$2" desc="$3" annot="$4" prefix width avail trimmed
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
  if [[ -n "$annot" ]]; then
    printf '%s%s   <- %s\n' "$prefix" "$trimmed" "$annot"
  else
    printf '%s\n' "${prefix}${trimmed}" | sed 's/[[:space:]]*$//'
  fi
}

# render_milestone_file -> the whole generated file on stdout.
render_milestone_file() {
  local us=$'\x1f' archive_path arch_file plan
  archive_path="$(dirname "$STATE_PATH")/archive/state.json"
  arch_file="/dev/null"
  if [[ -f "$archive_path" ]] && jq -e 'type == "object"' "$archive_path" >/dev/null 2>&1; then
    arch_file="$archive_path"
  fi

  plan="$(jq -r --slurpfile arch "$arch_file" --argjson terminal "$TERMINAL_JQ" \
    --arg sentinel "$ROADMAP_GENERATED_SENTINEL" "$MS_RENDER_JQ" "$STATE_PATH")"

  # One jq pass loads every open task's display fields and its JSON (status_token's input).
  local -A task_json=() task_desc=() task_annot=()
  local num desc annot json
  while IFS="$us" read -r num desc annot json; do
    [[ -n "$num" ]] || continue
    task_json["$num"]="$json"
    task_desc["$num"]="$desc"
    task_annot["$num"]="$annot"
  done < <(jq -r '.[] | [(.project_number | tostring),
      ((.title // .project_name // "") | tostring | gsub("[\t\n\r\u001f]+"; " ")),
      ((.roadmap_annotation // "") | tostring | gsub("[\t\n\r\u001f]+"; " ")),
      tojson] | join("\u001f")' <<<"$active_tasks_json")

  local kind a b c rows="" tok
  while IFS="$us" read -r kind a b c; do
    case "$kind" in
      L) printf '%s\n' "$a" ;;
      BS) rows="" ;;
      O)
        tok="$(status_token "${task_json[$a]}")"
        rows+="$(token_rank "$tok")${us}${a}${us}${tok}${us}${task_desc[$a]}${us}${task_annot[$a]}"$'\n'
        ;;
      X)
        rows+="$(token_rank "$b")${us}${a}${us}${b}${us}${c}${us}"$'\n'
        ;;
      BE)
        local _rank rnum rtok rdesc rannot
        while IFS="$us" read -r _rank rnum rtok rdesc rannot; do
          [[ -n "$rnum" ]] || continue
          format_task_row "$rnum" "$rtok" "$rdesc" "$rannot"
        done < <(printf '%s' "$rows" | sort -t"$us" -k1,1n -k2,2n)
        ;;
    esac
  done <<<"$plan" | cat -s
}

mode_print() {
  render_milestone_file
}

# refuse_non_generated VERDICT -> prints a named, loud refusal to stderr (the reason, the
# file's actual ## headers, and the migration that resolves it) and returns 1. PERMANENT
# property -- see roadmap-format.md's destructive-overwrite-refusal subsection.
refuse_non_generated() {
  local verdict="$1" reason=""
  case "$verdict" in
    classic) reason="it is a hand-authored file in the classic eight-header layout" ;;
    stage) reason="it is a hand-authored file in the stage layout" ;;
    *) reason="its first line is not the generated sentinel and its layout is not recognised" ;;
  esac
  {
    echo "ERROR: --${MODE} refuses to write ${ROADMAP_PATH}: ${reason} (verdict: ${verdict})."
    echo "       This script overwrites only a file it generated, whose first line is:"
    echo "         ${ROADMAP_GENERATED_SENTINEL}"
    echo "       Run migrate-roadmap-to-milestones.sh (--dry-run first) to move this file's content"
    echo "       into state and a retained-prose file; it then writes the generated file itself."
    echo "       Actual headers in this file:"
    # A file with no "## " header at all makes grep's own no-match the normal case here, not a
    # failure.
    grep -n '^## ' "$ROADMAP_PATH" | sed 's/^/         /' || true
  } >&2
  return 1
}

# write_or_diff NEW_CONTENT -> --dry-run prints a unified diff and writes nothing; otherwise
# writes NEW_CONTENT to a staging file and mv's it into place atomically.
#
# Also emits one named OUTCOME: line to stderr, alongside (not instead of) the EXIT trap's
# frozen marker -- this line precedes that marker since it is printed here, before this
# function returns and the script proceeds to exit. The marker's six count fields are
# byte-identical between a changed write and a no-op write, so this line is the only
# discriminator a caller has between "rewrote" and "left unchanged" without diffing the file
# itself. Content comparison uses `cmp -s` against the staging file already materialized here,
# not a fresh read -- see roadmap-format.md's Stderr Marker and Failure Diagnostics subsection.
write_or_diff() {
  local new_content="$1" tmp changed_desc
  if [[ "$DRY_RUN" -eq 1 ]]; then
    local base="$ROADMAP_PATH"
    [[ -f "$base" ]] || base="/dev/null"
    tmp="$(mktemp)"
    printf '%s\n' "$new_content" >"$tmp"
    if cmp -s "$base" "$tmp"; then
      changed_desc="no content change"
    else
      changed_desc="content would change"
    fi
    echo "OUTCOME: --${MODE} --dry-run diffed ${ROADMAP_PATH}; wrote nothing (layout=${ROADMAP_LAYOUT}, ${changed_desc})" >&2
    diff -u "$base" "$tmp" || true
    rm -f "$tmp"
  else
    tmp="$(mktemp "$(dirname "$ROADMAP_PATH")/.roadmap-integration.XXXXXX")"
    printf '%s\n' "$new_content" >"$tmp"
    if [[ -f "$ROADMAP_PATH" ]] && cmp -s "$ROADMAP_PATH" "$tmp"; then
      changed_desc=""
    else
      changed_desc="content changed"
    fi
    mv "$tmp" "$ROADMAP_PATH"
    if [[ -n "$changed_desc" ]]; then
      echo "OUTCOME: --${MODE} rewrote ${ROADMAP_PATH} (layout=${ROADMAP_LAYOUT}, ${changed_desc})" >&2
    else
      echo "OUTCOME: --${MODE} left ${ROADMAP_PATH} unchanged (layout=${ROADMAP_LAYOUT}, no content change)" >&2
    fi
  fi
}

mode_regenerate() {
  local verdict new_content
  verdict="$(roadmap_preflight_classify "$ROADMAP_PATH")"
  ROADMAP_LAYOUT="$verdict"
  PRUNED_COUNT=0
  RETAINED_COUNT=0

  case "$verdict" in
    generated) ;;
    absent)
      if ! jq -e '(.roadmap_milestones // []) | length > 0' "$STATE_PATH" >/dev/null 2>&1; then
        echo "NOTE: no roadmap at ${ROADMAP_PATH} and no milestone in state; --regenerate is a supported no-op." >&2
        return 0
      fi
      ROADMAP_LAYOUT="generated"
      ;;
    *)
      refuse_non_generated "$verdict"
      return 1
      ;;
  esac

  new_content="$(render_milestone_file)"
  [[ -n "$new_content" ]] || { echo "ERROR: render produced no output" >&2; return 1; }
  mkdir -p "$(dirname "$ROADMAP_PATH")"
  write_or_diff "$new_content"
}

# mode_prune -- DEPRECATED ALIAS for --regenerate. A file rendered wholly from live state
# cannot accumulate terminal cruft, so there is nothing left for a separate prune pass to
# remove. Prints one named stderr deprecation note, then reassigns $MODE to "regenerate" and
# dispatches to mode_regenerate -- every downstream message (the stderr marker's mode= field,
# the OUTCOME: line, a refusal's named reason) is therefore indistinguishable from a direct
# --regenerate invocation. The flag itself stays accepted and the stderr marker's pruned= field
# stays present (always 0), so every existing caller keeps working unchanged.
mode_prune() {
  echo "NOTE: --prune is deprecated: a file rendered from live state accumulates no terminal cruft; running --regenerate instead." >&2
  MODE="regenerate"
  mode_regenerate
}

case "$MODE" in
  print)
    output="$(mode_print)"
    printf '%s\n' "$output"
    ;;
  regenerate) mode_regenerate ;;
  prune) mode_prune ;;
esac
