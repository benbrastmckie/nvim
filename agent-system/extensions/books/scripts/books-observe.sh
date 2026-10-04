#!/usr/bin/env bash
# books-observe.sh -- the books extension's post-task observer: writes ONE OBSERVATION record
# per books-topic task, joining the generic per-task records (issues.jsonl, metrics.jsonl) with
# books-specific facts, so "is the books convention actually working?" is answerable from
# accumulated evidence. See context/project/books/standards/observation-record.md for the full
# schema this script implements against -- every field name below is read off that document,
# never re-derived here.
#
# OBSERVER EXECUTION CONTRACT (context/project/books/standards/observation-record.md,
# docs/guides/creating-extensions.md's "Post-Task Observers" section): invoked by
# run-task-observers.sh with exactly six positional arguments, in this fixed order:
#
#   $1 task_number   $2 task_type   $3 topic   $4 task_dir   $5 session_id   $6 resting_status
#
# Usage (live mode -- the only mode this script's Phase-3 authoring implements; --backfill is
# added in a later revision):
#   books-observe.sh TASK_NUMBER TASK_TYPE TOPIC TASK_DIR SESSION_ID RESTING_STATUS
#
# Usage (backfill mode):
#   books-observe.sh --backfill TASK_NUMBER
#
# ADVISORY AND NON-BLOCKING, NOT NEGOTIABLE. This script can never change task status, never
# fail a dispatch, never block orchestration -- run-task-observers.sh records this script's own
# exit code as one task_observer_run event and otherwise ignores it entirely. Every live-mode
# invocation therefore ALWAYS exits 0, whatever it did or did not manage to read or write. The
# ONLY exit code besides 0 is a true usage error in THIS script's own arguments (exit 2),
# matching books-gate.sh's own usage-error convention.
#
# NO JQ DEPENDENCY FOR JSON EMISSION (D4 in the implementation plan this script was built
# against). The observer may run inside an arbitrary consuming repository where `jq` is not
# guaranteed. The FINAL record is always assembled by plain string concatenation (the
# json_string/json_array helpers below, following books-gate.sh's own established idiom) and
# never requires jq to run. `jq`, when present, is used only as an optional enhancement on the
# READ side (parsing issues.jsonl/metrics.jsonl and, if it ever exists, the RUN log) -- its
# absence degrades those groups to a documented, coarser fallback rather than refusing.
#
# OMIT, NEVER ZERO (D5). A field this script cannot derive is DROPPED from the record -- never a
# fabricated 0 or null-as-zero. Where the standard names a sentinel string explicitly (the
# literal "absent"), that string is used instead of omission for exactly the fields the standard
# names (vacuous_passes, snapshot_delta).
#
# CUMULATIVE, OVERWRITE-ON-EACH-RUN DESIGN. The canonical record is ONE FILE PER TASK
# (book.observation.json, beside .decisions.json -- D1). Because the observer can fire more than
# once per task (any resting state can trigger it, and a task can reach more than one resting
# state across its lifecycle), each live-mode run OVERWRITES the canonical file with the fullest
# picture derivable AT THAT MOMENT from the task's accumulated issues.jsonl/metrics.jsonl/commit
# history -- never appends a second canonical file. The digest log
# (specs/books-evidence/observations.jsonl) IS append-only: one line per run, so a reader wanting
# "the current state" takes the LAST line for a given task, while a reader wanting history over
# time keeps every line.
#
# BOOK_REQUIRES CHURN / VALIDATED-BY COMMIT RANGE. Both mechanically-computed books facts below
# derive from the task's OWN commit range, found by the same commit-subject-grep convention
# dispatch-metrics.sh's --backfill mode already uses and documents
# (context/formats/dispatch-metrics.md's Trap (d)): subjects matching `task {N}:` / `task {N}
# phase {P}:`. This inherits that documented limitation verbatim -- a reused task number across
# vault operations can over-match -- rather than attempting a stronger-than-precedent fix here.
#
# PROBE OWNERSHIP BOUNDARY (D3). This extension ships no snapshot probe. The observer tests for
# an executable `books/tool/book-snapshot.sh` in the consuming repository and invokes
# `--diff A B --json` only when it exists; "absent" otherwise. Nothing here creates, requires, or
# depends on that path existing.
#
# Exit codes:
#   0 - always, in live mode (the advisory role). Read the written record, not the exit code.
#   2 - usage error in THIS script's own arguments (wrong positional count, unknown flag).
#
# No interactive prompts. No network. No build triggered.

set -euo pipefail

# ─── json_string / json_array helpers (books-gate.sh's established no-jq idiom) ────────────────
json_string() {
  printf '%s' "${1-}" \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' \
    | awk 'BEGIN{printf "\""} NR>1{printf "\\n"} {printf "%s", $0} END{printf "\""}'
}

json_array() {
  # JSON array of STRINGS from the remaining arguments, no jq dependency.
  local first=1 item
  printf '['
  for item in "$@"; do
    [ "$first" -eq 1 ] || printf ', '
    first=0
    printf '%s' "$(json_string "$item")"
  done
  printf ']'
}

json_raw_array() {
  # JSON array built from ALREADY-VALID JSON fragments (objects/arrays/scalars) passed as
  # arguments -- never re-escapes its inputs. Used to assemble arrays of pre-built object
  # fragments (e.g. one promotion/burden entry per element).
  local first=1 item
  printf '['
  for item in "$@"; do
    [ "$first" -eq 1 ] || printf ', '
    first=0
    printf '%s' "$item"
  done
  printf ']'
}

has_jq() { command -v jq >/dev/null 2>&1; }

# Frozen enums (standards/observation-record.md's "Seven Dimensions" / "Polarity Rule").
DIMENSION_ENUM="maintainability cross_pollination guardrails_qa token_cost_efficiency readability intuitive_exposure compiling_composing"

# ─── Argument dispatch ──────────────────────────────────────────────────────────────────────────
if [ "${1:-}" = "--backfill" ]; then
  echo "books-observe.sh: --backfill is not yet implemented in this revision" >&2
  exit 2
fi

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '/^# Usage/,/^# No interactive prompts/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
fi

if [ $# -lt 6 ]; then
  echo "books-observe.sh: expected 6 positional arguments (task_number task_type topic task_dir session_id resting_status), got $#" >&2
  echo "  usage: books-observe.sh TASK_NUMBER TASK_TYPE TOPIC TASK_DIR SESSION_ID RESTING_STATUS" >&2
  exit 2
fi

task_number="$1"
task_type="$2"
topic="$3"
task_dir="$4"
# Both fields below are part of the fixed six-positional observer contract (see header); neither
# is consumed by the current observation-record.md schema, but both are accepted and named here
# (rather than left as bare $5/$6) so a future schema revision that does read them needs no
# argument-parsing change.
# shellcheck disable=SC2034
session_id="$5"
# shellcheck disable=SC2034
resting_status="$6"

# From here on, EVERY failure path fails soft -- live mode always exits 0 (see header). A `trap`
# is not used because every risky operation below is already individually guarded (`|| true`,
# `2>/dev/null`, `if`/`[ ]` tests) rather than relying on an exit trap to paper over `set -e`.

# ─── Resolve the repository root from task_dir (never from cwd -- run-task-observers.sh does ───
# ─── not cd into task_dir before invoking this script) ──────────────────────────────────────────
repo_root=""
if [ -d "$task_dir" ]; then
  repo_root="$(cd "$task_dir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" || repo_root=""
fi
[ -z "$repo_root" ] && repo_root="$(pwd)"

recorded_at="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || true)"
[ -z "$recorded_at" ] && recorded_at="1970-01-01T00:00:00Z"

issues_file="${task_dir}/issues.jsonl"
metrics_file="${task_dir}/metrics.jsonl"
record_path="${task_dir}/book.observation.json"
digest_log="${repo_root}/specs/books-evidence/observations.jsonl"
digest_lock="${repo_root}/specs/books-evidence/.observations.lock"

issues_present=false
metrics_present=false
[ -f "$issues_file" ] && issues_present=true
[ -f "$metrics_file" ] && metrics_present=true

# ════════════════════════════════════════════════════════════════════════════════════════════
# THE JOIN (GENERIC HALF) -- group issues.jsonl by tags.dimension/tags.polarity; aggregate
# metrics.jsonl's dispatch count, phases, outcomes, wall-clock. Omit any group whose source file
# is absent. Paired burdens (burdens_created[]/burdens_lifted[]) default to [] regardless.
# ════════════════════════════════════════════════════════════════════════════════════════════
issue_counts_json=""
dimension_signals_json=""
unrecognized_tags_json="[]"
burdens_created_json="[]"
burdens_lifted_json="[]"

if [ "$issues_present" = "true" ]; then
  if has_jq; then
    dims_argjson="[\"$(printf '%s' "$DIMENSION_ENUM" | sed 's/ /","/g')\"]"
    issues_agg="$(jq -c -s --argjson dims "$dims_argjson" '
      {
        issue_counts: {
          by_kind: (group_by(.kind) | map({key: (.[0].kind // "unknown"), value: length}) | from_entries),
          by_severity: (group_by(.severity) | map({key: (.[0].severity // "unknown"), value: length}) | from_entries),
          by_class: (group_by(.class) | map({key: (.[0].class // "unknown"), value: length}) | from_entries)
        },
        by_dimension_polarity: (
          [ .[] | . as $e | (($e.tags.dimension // [])[]) as $d
            | select([$dims[]] | index($d) != null)
            | {dimension: $d, polarity: ($e.tags.polarity // "unknown")} ]
          | group_by(.dimension)
          | map({key: .[0].dimension, value: (group_by(.polarity) | map({key: .[0].polarity, value: length}) | from_entries)})
          | from_entries
        ),
        untagged_count: ([ .[] | select(((.tags.dimension // []) | length) == 0) ] | length),
        unrecognized_tags: (
          [ .[] | . as $e | (($e.tags.dimension // [])[]) | select(([$dims[]] | index(.)) == null)
            | {entry_id: $e.entry_id, field: "dimension", value: .} ]
          + [ .[] | select(.tags.polarity != null and (.tags.polarity != "positive" and .tags.polarity != "negative"))
              | {entry_id: .entry_id, field: "polarity", value: .tags.polarity} ]
        ),
        burdens_created: ([ .[] | select((.tags.burden // "") == "created")
          | {description: (.what_happened // ""), dimension: (((.tags.dimension // [])[0]) // null), convention_decision: (.tags.convention_decision // null)}
          | with_entries(select(.value != null)) ]),
        burdens_lifted: ([ .[] | select((.tags.burden // "") == "lifted")
          | {description: (.what_happened // ""), dimension: (((.tags.dimension // [])[0]) // null), convention_decision: (.tags.convention_decision // null)}
          | with_entries(select(.value != null)) ])
      }
    ' "$issues_file" 2>/dev/null)" || issues_agg=""

    if [ -n "$issues_agg" ]; then
      issue_counts_json="$(printf '%s' "$issues_agg" | jq -c '.issue_counts' 2>/dev/null)" || issue_counts_json=""
      by_dim_pol="$(printf '%s' "$issues_agg" | jq -c '.by_dimension_polarity' 2>/dev/null)" || by_dim_pol="{}"
      untagged_count="$(printf '%s' "$issues_agg" | jq -r '.untagged_count' 2>/dev/null)" || untagged_count=0
      if [ "$by_dim_pol" != "{}" ] && [ -n "$by_dim_pol" ]; then
        dimension_signals_json="{\"by_dimension_polarity\": ${by_dim_pol}, \"untagged_count\": ${untagged_count}}"
      fi
      urt="$(printf '%s' "$issues_agg" | jq -c '.unrecognized_tags' 2>/dev/null)" || urt="[]"
      [ -n "$urt" ] && [ "$urt" != "[]" ] && unrecognized_tags_json="$urt"
      bc="$(printf '%s' "$issues_agg" | jq -c '.burdens_created' 2>/dev/null)" || bc="[]"
      [ -n "$bc" ] && burdens_created_json="$bc"
      bl="$(printf '%s' "$issues_agg" | jq -c '.burdens_lifted' 2>/dev/null)" || bl="[]"
      [ -n "$bl" ] && burdens_lifted_json="$bl"
    fi
  else
    echo "books-observe.sh: jq not found -- degraded fallback for issues.jsonl: only by_kind counts via grep, dimension_signals/unrecognized_tags/burdens omitted (see observation-record.md's omit-never-zero rule)" >&2
    win_n="$(grep -c '"kind":"win"' "$issues_file" 2>/dev/null || true)"
    issue_n="$(grep -c '"kind":"issue"' "$issues_file" 2>/dev/null || true)"
    [ -z "$win_n" ] && win_n=0
    [ -z "$issue_n" ] && issue_n=0
    issue_counts_json="{\"by_kind\": {\"issue\": ${issue_n}, \"win\": ${win_n}}}"
  fi
fi

dispatch_count_json=""
phases_json=""
outcomes_json=""
wall_clock_total_json=""

if [ "$metrics_present" = "true" ]; then
  if has_jq; then
    metrics_agg="$(jq -c -s '
      {
        dispatch_count: length,
        phases: ( [ .[] | select(.phases_completed != null and .phases_total != null) ]
                  | if length > 0 then (.[-1] | {completed: .phases_completed, total: .phases_total}) else null end ),
        outcomes: (group_by(.outcome) | map({key: (.[0].outcome // "unknown"), value: length}) | from_entries),
        wall_clock_seconds_total: ( [ .[] | .wall_clock_seconds ] | map(select(. != null))
                                    | if length > 0 then add else null end )
      }
    ' "$metrics_file" 2>/dev/null)" || metrics_agg=""
    if [ -n "$metrics_agg" ]; then
      dispatch_count_json="$(printf '%s' "$metrics_agg" | jq -r '.dispatch_count' 2>/dev/null)" || dispatch_count_json=""
      pj="$(printf '%s' "$metrics_agg" | jq -c '.phases' 2>/dev/null)" || pj="null"
      [ "$pj" != "null" ] && phases_json="$pj"
      oj="$(printf '%s' "$metrics_agg" | jq -c '.outcomes' 2>/dev/null)" || oj="null"
      [ "$oj" != "null" ] && [ "$oj" != "{}" ] && outcomes_json="$oj"
      wj="$(printf '%s' "$metrics_agg" | jq -r '.wall_clock_seconds_total' 2>/dev/null)" || wj="null"
      [ "$wj" != "null" ] && wall_clock_total_json="$wj"
    fi
  else
    echo "books-observe.sh: jq not found -- degraded fallback for metrics.jsonl: dispatch_count via line count only, phases/outcomes/wall_clock omitted" >&2
    dispatch_count_json="$(wc -l < "$metrics_file" 2>/dev/null | tr -d ' ')" || dispatch_count_json=""
  fi
fi

generic_fields=()
generic_fields+=("\"issues_present\": ${issues_present}")
generic_fields+=("\"metrics_present\": ${metrics_present}")
[ -n "$issue_counts_json" ] && generic_fields+=("\"issue_counts\": ${issue_counts_json}")
[ -n "$dispatch_count_json" ] && generic_fields+=("\"dispatch_count\": ${dispatch_count_json}")
[ -n "$phases_json" ] && generic_fields+=("\"phases\": ${phases_json}")
[ -n "$outcomes_json" ] && generic_fields+=("\"outcomes\": ${outcomes_json}")
[ -n "$wall_clock_total_json" ] && generic_fields+=("\"wall_clock_seconds_total\": ${wall_clock_total_json}")

generic_json="{"
_first=1
for f in "${generic_fields[@]+"${generic_fields[@]}"}"; do
  [ "$_first" -eq 1 ] || generic_json+=", "
  _first=0
  generic_json+="$f"
done
generic_json+="}"

# ════════════════════════════════════════════════════════════════════════════════════════════
# THE TASK'S OWN COMMIT RANGE -- shared by both mechanically-computed books facts below.
# ════════════════════════════════════════════════════════════════════════════════════════════
commit_hashes=""
if git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  commit_hashes="$(git -C "$repo_root" log --reverse --format='%H' -E \
    --grep="^task ${task_number}:" --grep="^task ${task_number} phase " 2>/dev/null)" || commit_hashes=""
fi

# ════════════════════════════════════════════════════════════════════════════════════════════
# BOOKS FACT 1 -- book_requires churn. Pure git diff/grep over .lean files in the task's own
# commit range. No probe, no build.
# ════════════════════════════════════════════════════════════════════════════════════════════
book_requires_churn_json=""
if [ -n "$commit_hashes" ]; then
  br_added=0
  br_removed=0
  while IFS= read -r h; do
    [ -z "$h" ] && continue
    a="$(git -C "$repo_root" show "$h" -- '*.lean' 2>/dev/null | grep -cE '^\+[^+].*book_requires' || true)"
    r="$(git -C "$repo_root" show "$h" -- '*.lean' 2>/dev/null | grep -cE '^-[^-].*book_requires' || true)"
    [ -z "$a" ] && a=0
    [ -z "$r" ] && r=0
    br_added=$((br_added + a))
    br_removed=$((br_removed + r))
  done <<< "$commit_hashes"
  if [ "$br_added" -gt 0 ] || [ "$br_removed" -gt 0 ]; then
    book_requires_churn_json="{\"added\": ${br_added}, \"removed\": ${br_removed}}"
  fi
fi

# ════════════════════════════════════════════════════════════════════════════════════════════
# BOOKS FACT 2 -- escalations and Validated-by marker promotions, by Decision's durable heading
# name. git diff of docs/book-convention.md (and its documented siblings) over the task's commit
# range, scoped to "- **Validated by**:" lines, with heading lookback.
# ════════════════════════════════════════════════════════════════════════════════════════════
validated_by_promotions=()
validated_by_files="docs/book-convention.md docs/architecture-decisions.md docs/fault-frame-design.md"

extract_validated_by_pairs() {
  awk '
    /^## Decision/ { heading = $0; sub(/^## /, "", heading); next }
    /^- \*\*Validated by\*\*:/ { if (heading != "") print heading "\t" $0 }
  '
}

if [ -n "$commit_hashes" ]; then
  while IFS= read -r h; do
    [ -z "$h" ] && continue
    for vf in $validated_by_files; do
      after_content="$(git -C "$repo_root" show "${h}:${vf}" 2>/dev/null || true)"
      [ -z "$after_content" ] && continue
      before_content="$(git -C "$repo_root" show "${h}^:${vf}" 2>/dev/null || true)"

      declare -A before_map=()
      if [ -n "$before_content" ]; then
        while IFS=$'\t' read -r b_heading b_marker; do
          [ -z "$b_heading" ] && continue
          before_map["$b_heading"]="$b_marker"
        done <<< "$(printf '%s\n' "$before_content" | extract_validated_by_pairs)"
      fi

      while IFS=$'\t' read -r a_heading a_marker; do
        [ -z "$a_heading" ] && continue
        prev="${before_map[$a_heading]:-}"
        if [ -n "$prev" ] && [ "$prev" != "$a_marker" ]; then
          entry="{\"decision\": $(json_string "$a_heading"), \"from\": $(json_string "$prev"), \"to\": $(json_string "$a_marker"), \"commit\": $(json_string "$h")}"
          validated_by_promotions+=("$entry")
        fi
      done <<< "$(printf '%s\n' "$after_content" | extract_validated_by_pairs)"
      unset before_map
    done
  done <<< "$commit_hashes"
fi

validated_by_json=""
if [ "${#validated_by_promotions[@]}" -gt 0 ]; then
  validated_by_json="$(json_raw_array "${validated_by_promotions[@]}")"
fi

# ════════════════════════════════════════════════════════════════════════════════════════════
# PROBE-DEPENDENT GROUPS -- strictly present-or-"absent". verification_tiers, certifier_outcomes,
# and the supplied half of vacuous_passes are read from specs/books-evidence/runs.jsonl WHEN IT
# EXISTS, filtered to this task; omitted/"absent" otherwise, never a zeroed tally. The repo-side
# RUN log's own schema and writer belong to the consuming repository
# (book-evidence-run-v1.md) -- this extension reads it, never writes it, and its exact shape has
# not been built anywhere real as of this script's authoring (see observation-record.md).
# ════════════════════════════════════════════════════════════════════════════════════════════
run_log="${repo_root}/specs/books-evidence/runs.jsonl"
verification_tiers_json=""
certifier_outcomes_json=""
vacuous_passes_json="\"absent\""

if [ -f "$run_log" ] && has_jq; then
  run_agg="$(jq -c -s --argjson task "$task_number" '
    [ .[] | select((.caller_context.task // null) == $task) ] as $mine
    | {
        count: ($mine | length),
        tiers: ( $mine | group_by(.tier) | map({
            key: (.[0].tier // "unknown"),
            value: { count: length, outcomes: (group_by(.outcome) | map({key: (.[0].outcome // "unknown"), value: length}) | from_entries),
                      total_seconds: ([ .[] | .duration_seconds ] | map(select(. != null)) | if length > 0 then add else null end) }
          }) | from_entries ),
        certifier_outcome_classes: ( [ $mine[] | select(.tier == "certify") | .certifier_class ] | map(select(. != null)) | group_by(.) | map({key: .[0], value: length}) | from_entries ),
        refusals: ( [ $mine[] | select(.tier == "certify" and (.refusal // null) != null) | .refusal ] ),
        warnings: ( [ $mine[] | select((.warning // null) != null) | .warning ] ),
        vacuous: ( [ $mine[] | select((.vacuous // false) == true or .outcome == "pass_vacuous")
                     | {tier: (.tier // "unknown"), detail: (.detail // ""), source: "runs.jsonl"} ] )
      }
  ' "$run_log" 2>/dev/null)" || run_agg=""

  if [ -n "$run_agg" ]; then
    mine_count="$(printf '%s' "$run_agg" | jq -r '.count' 2>/dev/null)" || mine_count=0
    if [ "$mine_count" != "0" ] && [ -n "$mine_count" ]; then
      tiers_json="$(printf '%s' "$run_agg" | jq -c '.tiers' 2>/dev/null)" || tiers_json="{}"
      [ "$tiers_json" != "{}" ] && verification_tiers_json="$tiers_json"

      classes_json="$(printf '%s' "$run_agg" | jq -c '.certifier_outcome_classes' 2>/dev/null)" || classes_json="{}"
      refusals_json="$(printf '%s' "$run_agg" | jq -c '.refusals' 2>/dev/null)" || refusals_json="[]"
      warnings_json="$(printf '%s' "$run_agg" | jq -c '.warnings' 2>/dev/null)" || warnings_json="[]"
      certifier_outcomes_json="{\"outcome_classes\": ${classes_json}, \"refusals\": ${refusals_json}, \"warnings\": ${warnings_json}}"

      vac_json="$(printf '%s' "$run_agg" | jq -c '.vacuous' 2>/dev/null)" || vac_json="[]"
      if [ "$vac_json" != "[]" ]; then
        vacuous_passes_json="$vac_json"
      else
        vacuous_passes_json="[]"
      fi
    fi
  fi
fi

# ════════════════════════════════════════════════════════════════════════════════════════════
# SNAPSHOT BEFORE/AFTER DELTA -- the conventional probe path (D3). Test for executability;
# invoke --diff A B --json when present; "absent" otherwise. Never synthesize a snapshot.
# ════════════════════════════════════════════════════════════════════════════════════════════
snapshot_probe="${repo_root}/books/tool/book-snapshot.sh"
snapshot_delta_json="\"absent\""
if [ -x "$snapshot_probe" ] && [ -n "$commit_hashes" ]; then
  first_commit="$(printf '%s\n' "$commit_hashes" | head -1)"
  last_commit="$(printf '%s\n' "$commit_hashes" | tail -1)"
  before_ref="${first_commit}^"
  if git -C "$repo_root" rev-parse --verify "$before_ref" >/dev/null 2>&1; then
    snap_out="$("$snapshot_probe" --diff "$before_ref" "$last_commit" --json 2>/dev/null)" || snap_out=""
    if [ -n "$snap_out" ]; then
      if has_jq; then
        if printf '%s' "$snap_out" | jq -e . >/dev/null 2>&1; then
          snapshot_delta_json="$snap_out"
        fi
      else
        snapshot_delta_json="$snap_out"
      fi
    fi
  fi
fi

# ════════════════════════════════════════════════════════════════════════════════════════════
# ASSEMBLE THE RECORD -- plain string concatenation only (D4: no jq dependency for emission).
# ════════════════════════════════════════════════════════════════════════════════════════════
fields=()
fields+=("\"schema_version\": \"observation-v1\"")
fields+=("\"task\": ${task_number}")
fields+=("\"recorded_at\": $(json_string "$recorded_at")")
[ -n "$topic" ] && fields+=("\"topic\": $(json_string "$topic")")
[ -n "$task_type" ] && fields+=("\"task_type\": $(json_string "$task_type")")
fields+=("\"backfilled\": false")
fields+=("\"generic\": ${generic_json}")
[ -n "$book_requires_churn_json" ] && fields+=("\"book_requires_churn\": ${book_requires_churn_json}")
[ -n "$validated_by_json" ] && fields+=("\"validated_by_promotions\": ${validated_by_json}")
[ -n "$verification_tiers_json" ] && fields+=("\"verification_tiers\": ${verification_tiers_json}")
[ -n "$certifier_outcomes_json" ] && fields+=("\"certifier_outcomes\": ${certifier_outcomes_json}")
fields+=("\"vacuous_passes\": ${vacuous_passes_json}")
fields+=("\"snapshot_delta\": ${snapshot_delta_json}")
fields+=("\"burdens_created\": ${burdens_created_json}")
fields+=("\"burdens_lifted\": ${burdens_lifted_json}")
[ -n "$dimension_signals_json" ] && fields+=("\"dimension_signals\": ${dimension_signals_json}")
[ "$unrecognized_tags_json" != "[]" ] && fields+=("\"unrecognized_tags\": ${unrecognized_tags_json}")
fields+=("\"record_path\": $(json_string "$record_path")")

record_json="{"
_first=1
for f in "${fields[@]}"; do
  [ "$_first" -eq 1 ] || record_json+=", "
  _first=0
  record_json+="$f"
done
record_json+="}"

if has_jq; then
  pretty="$(printf '%s' "$record_json" | jq '.' 2>/dev/null)" && [ -n "$pretty" ] && record_json="$pretty"
fi

# ─── Write the canonical record (atomic rename) and the derived digest line ────────────────────
wrote_record=false
if [ -d "$task_dir" ]; then
  tmp_path="${record_path}.tmp.$$"
  if printf '%s\n' "$record_json" > "$tmp_path" 2>/dev/null; then
    if mv -f "$tmp_path" "$record_path" 2>/dev/null; then
      wrote_record=true
    else
      rm -f "$tmp_path" 2>/dev/null || true
    fi
  fi
fi

if [ "$wrote_record" = "true" ]; then
  digest_dir="$(dirname "$digest_log")"
  mkdir -p "$digest_dir" 2>/dev/null || true
  if [ -d "$digest_dir" ]; then
    signal_count=0
    [ -n "$dimension_signals_json" ] && signal_count=1
    digest_line="{\"task\": ${task_number}, \"recorded_at\": $(json_string "$recorded_at"), \"record_path\": $(json_string "$record_path"), \"backfilled\": false, \"has_dimension_signals\": $([ "$signal_count" -eq 1 ] && echo true || echo false)}"
    (
      flock -x 200 2>/dev/null || true
      printf '%s\n' "$digest_line" >> "$digest_log" 2>/dev/null || true
    ) 200>"$digest_lock" 2>/dev/null || true
  fi
  echo "books-observe.sh: wrote ${record_path}"
else
  echo "books-observe.sh: could not write ${record_path} (task_dir absent or unwritable) -- advisory, non-fatal" >&2
fi
exit 0
