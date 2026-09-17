#!/usr/bin/env bash
# orchestrate-predispatch-review.sh — Shared pre-dispatch dependency and file_scope REVIEW stage
# for /orchestrate.
#
# Purpose: reads specs/state.json directly — the only place raw, unfiltered dependencies[] is
# still visible before commands/orchestrate.md's compact STAGE 0 multi-task block discards
# out-of-batch edges to build its intra-batch-only dependency graph — and reports FIVE classes of
# pre-dispatch defect, by task number and path, BEFORE that discard happens:
#
#   Class A (dependency edge classification): every RAW dependencies[] entry on every candidate,
#     classified into intra_batch (no finding), out_of_batch_live, out_of_batch_terminal,
#     archived_satisfied, or nonexistent. archived_satisfied (a dependency that was completed and
#     then archived by /todo) reports at informational volume, never as nonexistent, since it is
#     satisfied rather than a hazard. Satisfies context/patterns/batch-orchestration-guardrails.md's
#     Non-Negotiable 3, which requires warning loudly on every dropped edge and distinguishing
#     these subcases rather than discarding all identically — including the terminal subcase, since
#     Non-Negotiable 3 draws no exception for a terminal target.
#   Class B (metadata defects): dependencies/file_scope/title/topic present as a literal `null`
#     on a candidate, instead of the schema's documented default (`[]` for the two array
#     fields — see context/reference/state-management-schema.md). Only a literal null is
#     flagged, never a genuinely absent key — an absent key is handled transparently everywhere
#     by the existing `// []` idiom and is not the anomaly this class exists to surface. As of
#     this script's authoring, a live survey of every field on every active_projects[] entry
#     found ZERO literal nulls anywhere in specs/state.json — Defect 2 is a real but currently
#     DORMANT class (the originally-cited example tasks have all since gone terminal); this
#     class re-derives its findings live at run time rather than hardcoding against that stale
#     citation, so it will fire again the moment a null resurfaces.
#   Class C (self-modification / declaration coarseness): re-presents
#     orchestrate-batch-admit.sh's defer_reason == "self_modifying" verdicts, adding a diagnosis
#     of whether the candidate's OWN file_scope covers the matched critical path only because it
#     declares a directory prefix broader than that specific file, and suggests the narrower
#     alternative when so. The verdict itself is not new information; the coarseness diagnosis
#     is.
#   Class D (missing cross-batch serializing edges): re-presents
#     orchestrate-batch-admit.sh's defer_reason == "file_scope_collision" &&
#     collision_scope == "cross_batch" verdicts, and suggests (never writes) the specific
#     serializing dependencies[] edge that would close the gap. As of v4, also surfaces
#     `corroborated_by` when it names "session_registry" (a live registered session
#     independently corroborates the colliding task).
#   Class E (session-registry contention, NEW in v4): re-presents orchestrate-batch-admit.sh's
#     defer_reason == "session_active" verdicts verbatim — a live registered session's own
#     unioned file_scope overlaps the candidate's, and the state.json collision scan (Class D's
#     source) found no hit. Requires the caller to have passed --session-id (see below); without
#     it, batch-admit's own D6 degradation means this class reports nothing to report, not a
#     dropped finding.
#
# This is a REVIEW stage, not a fifth admission gate: it never excludes, never defers, and never
# writes to state.json on its default (report-only) path. Exclusion/deferral authority for
# Classes C/D stays exactly where it already is — the existing runtime wave-split check at
# dispatch time (orchestrate-batch-admit.sh, called directly by commands/orchestrate.md and by
# skills/skill-orchestrate/SKILL.md Stage MT-3); this script never substitutes for it. Classes
# C/D are re-presentations of that existing verdict — this script is a CONSUMER of, never a fork
# of, the admission predicate (explicit task non-goal: neither the admission predicate's verdict
# schema nor its collision algorithm is changed here).
#
# Usage:
#   orchestrate-predispatch-review.sh [--repair] [--session-id SID] <task_number> [<task_number> ...]
#
# Default invocation (no --repair) is read-only and report-only: it never writes to
# specs/state.json under any circumstance, exit code included. It prints a human-readable report
# with one section per defect class, each explicitly stating "0 findings" when a class has
# nothing to report — never an omitted or silently-empty section.
#
# --repair (direct-invocation ONLY — see below) writes ONLY Class B array-field normalization: a
# literal `null` on `dependencies` or `file_scope` becomes `[]`, and only when the current value
# is a literal null (a present, non-null value is never overwritten). It never writes `title` or
# `topic` — those get a WARN with the suggested value instead, because generate-todo.sh already
# owns a derived-title convention and repair must not invent a second, competing derivation (and
# no automated topic derivation exists at all — generate-task-order.sh already buckets untagged
# tasks under "Uncategorized" at render time; that is a rendering fallback, not a value this
# script should write back). --repair NEVER adds, removes, or rewrites any dependencies[] edge,
# even when a candidate has a repairable null on that same field — normalizing null to [] is a
# type-safety fix with exactly one correct outcome; choosing *which* edge to add is a judgment
# call outside this script's scope. --repair prints a full before/after diff of every field it
# changes and exits non-zero only on write failure, never merely because findings existed.
#
# --repair is reachable ONLY by direct human invocation of this script: it is deliberately NOT
# plumbed through any /orchestrate flag (parse-command-args.sh is not modified by this task), so
# no /orchestrate invocation — autonomous or interactive — can ever reach it. This is the
# deliberate design choice satisfying the task's constraint against autonomous silent rewrites,
# not an incidental limitation. The default report-only path prints the exact --repair command
# an operator can copy-paste whenever a repairable Class B finding exists, so the repair route is
# discoverable without being automatic.
#
# State-write atomicity: the --repair write now routes through state-write.sh, the single
# mutex-guarded specs/state.json writer every other writer in this codebase shares (see
# scripts/state-write.sh's own header for the full acquire -> mktemp -> jq transform -> jq empty
# validate -> mv -> release sequence). This supersedes the script's original reasoning for
# skipping the specs/.scope-lock mutex on the grounds that --repair is direct-invocation-only and
# therefore unlikely to race a concurrent writer in practice: --repair now serializes like every
# other writer, so that reasoning no longer needs to hold. An optional `--session-id SID` flag
# attributes the mutex acquisition; if omitted, a session_id is generated inline using the same
# portable pattern command-gate-in.sh uses.
#
# `--session-id SID` has a SECOND, independent purpose (as of v4 batch-admit): when the caller
# explicitly supplies it, this script forwards it VERBATIM to orchestrate-batch-admit.sh's
# subprocess call below, activating that script's session-registry contention input (Class E).
# The auto-generated fallback above is NEVER forwarded — only an explicitly-supplied id is,
# since a fabricated id that was never registered would be a pointless self-exclusion key. When
# the caller supplies none, batch-admit's own D6 degradation fires visibly and Class E simply
# reports what it can (which may be nothing, since the session pass never ran).
#
# Forbidden calls (this script is read-only on its default path; --repair is the one narrow,
# direct-invocation-only exception described above, and even it never touches any of these):
#   - task-lock.sh acquire / heartbeat / release
#   - update-task-status.sh
#   - generate-todo.sh
#   - skill-base.sh write functions (skill_preflight_update, skill_postflight_update, etc.)
#   - reconcile-task-status.sh (without --dry-run)
#   - the Agent or Skill tool, or anything that dispatches one
#   - any dependencies[] edge add/remove/rewrite, even under --repair
# This script reads ONLY specs/state.json directly, plus — for Classes C/D only — one subprocess
# call to orchestrate-batch-admit.sh for the SAME candidate set, never a second, independently
# re-derived collision computation (Context Flatness Constraint; canonical-collision-algorithm
# non-goal).
#
# Exit codes:
#   0 - a report was printed (regardless of how many findings — findings are data, not errors,
#       matching orchestrate-batch-admit.sh's and orchestrate-triage-classify.sh's convention).
#       Also 0 after a successful --repair write, and 0 for a --repair run that found nothing to
#       normalize.
#   2 - usage error (zero <task_number> arguments, a non-integer task_number, or jq missing), or
#       state.json unavailable/unparseable, or (--repair only) state-write.sh reported a failure
#       (mutex ABORT, jq transform failure, or invalid-JSON validation failure -- state.json is
#       left untouched on every one of those paths; see state-write.sh's own exit-code table).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/task-lookup-lib.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
STATE_FILE="$PROJECT_ROOT/specs/state.json"

# --- argument parsing: --repair ahead of positional task_number validation ---
repair_mode=false
session_id=""
session_id_explicit=false
task_args=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repair)
      repair_mode=true
      shift
      ;;
    --session-id)
      session_id="${2:-}"
      session_id_explicit=true
      shift 2
      ;;
    --session-id=*)
      session_id="${1#--session-id=}"
      session_id_explicit=true
      shift
      ;;
    *)
      task_args+=("$1")
      shift
      ;;
  esac
done

if [ -z "$session_id" ]; then
  session_id="$(common_session_id)"
fi
# NOTE: this auto-generated fallback exists ONLY for --repair's state-write.sh mutex
# attribution (unchanged, pre-existing purpose) -- it is NEVER forwarded to
# orchestrate-batch-admit.sh's subprocess call below (see admit_session_id_args), because a
# fabricated id that was never actually registered via `session-register` would be pointless as
# a self-exclusion key and could mislead a reader of the NDJSON into thinking a real caller
# session was involved. Only an EXPLICITLY-supplied --session-id (session_id_explicit=true) is
# forwarded; when the caller supplies none, orchestrate-batch-admit.sh's own D6 degradation
# fires visibly -- the honest outcome for a caller that never told us its real identity.

if [ "${#task_args[@]}" -eq 0 ]; then
  echo "ERROR: orchestrate-predispatch-review.sh requires at least one <task_number> argument." >&2
  exit 2
fi

for arg in "${task_args[@]}"; do
  case "$arg" in
    ''|*[!0-9]*)
      echo "ERROR: orchestrate-predispatch-review.sh: '$arg' is not a non-negative integer task_number." >&2
      exit 2
      ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: orchestrate-predispatch-review.sh: jq is not available; cannot evaluate review." >&2
  exit 2
fi

if [ ! -f "$STATE_FILE" ]; then
  echo "ERROR: orchestrate-predispatch-review.sh: state file not found at $STATE_FILE." >&2
  exit 2
fi

candidates_json="[$(printf '%s\n' "${task_args[@]}" | paste -sd, -)]" || true

# ---------------------------------------------------------------------------
# Classes A and B: single read of STATE_FILE via --slurpfile, one jq program.
# ---------------------------------------------------------------------------
# Archive read for Class A: /todo moves every terminal task (completed/abandoned/expanded) OUT
# of `.active_projects` and into the sibling `archive/state.json`. Without this, a candidate's
# dependency that was satisfied and then archived resolved to a null $dep_entry and bucketed as
# "nonexistent" -- the loudest verdict this class has -- despite being satisfied. Sourced from
# scripts/lib/task-lookup-lib.sh (the single source of truth for archive-aware lookup), not a
# second hand-copied jq.
#
# Written to a temp file and read back via --slurpfile rather than passed as a jq --argjson
# command-line argument: a repo with a long-lived archive can flatten to a JSON string well past
# the OS argv/environment size limit (observed: ~960KB triggering "Argument list too long", exit
# 126, on a real archive/state.json), which --argjson embeds directly into jq's exec argv while
# --slurpfile reads from disk with no such ceiling. Mirrors orchestrate-triage-classify.sh's own
# use of the same library and the same tempfile pattern.
archived_projects_json="$(task_lookup_archived_projects_json "$STATE_FILE")"
archived_projects_tmpfile="$(mktemp "${TMPDIR:-/tmp}/orchestrate-predispatch-archived.XXXXXX")"
trap 'rm -f "$archived_projects_tmpfile"' EXIT
printf '%s' "$archived_projects_json" > "$archived_projects_tmpfile"

# `if VAR=$(cmd); then jq_exit=0; else jq_exit=$?; fi` rather than a bare `VAR=$(cmd)` followed
# by `jq_exit=$?`: a jq failure here is a routine, handled outcome (see the exit-2 branch just
# below) -- under `set -e` a bare failing assignment would abort the script before jq_exit could
# ever be captured, mirroring the fix applied to state-write.sh, task-lock.sh,
# git-commit-scoped.sh, and orchestrate-batch-admit.sh.
if ab_findings=$(jq -n -c \
  --argjson candidates "$candidates_json" \
  --slurpfile state_arr "$STATE_FILE" \
  --slurpfile archived_raw "$archived_projects_tmpfile" \
  '
  def is_terminal: ascii_downcase as $s | ($s == "completed" or $s == "abandoned" or $s == "expanded");

  (($state_arr[0].active_projects // []) + $archived_raw[0]) as $all |
  ($archived_raw[0] | map(.project_number)) as $archived_nums |
  $candidates as $cands |

  ( # Class A: raw dependency edge classification (never a filtered subset). $all is
    # active-projects-first (active wins, matching the task_lookup_entry contract) with the
    # archive appended, so a task present in both is still governed by its live entry.
    $cands[] as $c
    | ([$all[] | select(.project_number == $c)] | first) as $entry
    | select($entry != null)
    | ($entry.dependencies // [])[] as $d
    | select(($cands | index($d)) == null)
    | ([$all[] | select(.project_number == $d)] | first) as $dep_entry
    | (if $dep_entry == null then "nonexistent"
       elif ($archived_nums | index($d)) != null then "archived_satisfied"
       elif (($dep_entry.status // "") | is_terminal) then "out_of_batch_terminal"
       else "out_of_batch_live" end) as $bucket
    | {class: "A", task_number: $c, dependency: $d, bucket: $bucket,
       dependency_status: ($dep_entry.status // null)}
  ),
  ( # Class B: literal-null metadata defects on the four fields the Phase 1 schema survey
    # confirmed as array-typed-with-[]-default (dependencies, file_scope) or otherwise
    # documented as always-a-string (title, topic). A genuinely absent key is NOT flagged —
    # only a present-but-literal-null value is the anomaly this class exists to surface.
    $cands[] as $c
    | ([$all[] | select(.project_number == $c)] | first) as $entry
    | select($entry != null)
    | (["dependencies", "file_scope", "title", "topic"][]) as $field
    | select(($entry | has($field)) and ($entry[$field] == null))
    | {class: "B", task_number: $c, field: $field, project_name: ($entry.project_name // "")}
  )
  ' 2>&1); then
  jq_exit=0
else
  jq_exit=$?
fi
if [ "$jq_exit" -ne 0 ]; then
  echo "ERROR: orchestrate-predispatch-review.sh: failed to evaluate Class A/B findings against $STATE_FILE (jq exit $jq_exit): $ab_findings" >&2
  exit 2
fi

# ===========================================================================
# --repair mode: Class B array-field normalization only. Never prints the
# four-class report below — a focused, direct-invocation-only operation.
# ===========================================================================
if [ "$repair_mode" = true ]; then
  any_write=false
  if [ -n "$ab_findings" ]; then
    while IFS= read -r finding; do
      [ -z "$finding" ] && continue || true
      cls=$(printf '%s' "$finding" | jq -r '.class') || true
      [ "$cls" = "B" ] || continue
      pn=$(printf '%s' "$finding" | jq -r '.task_number') || true
      field=$(printf '%s' "$finding" | jq -r '.field') || true
      proj_name=$(printf '%s' "$finding" | jq -r '.project_name') || true
      case "$field" in
        dependencies|file_scope)
          any_write=true
          ;;
        title)
          derived="${proj_name//_/ }"
          if [ -n "$derived" ]; then
            first_char="$(printf '%s' "${derived:0:1}" | tr '[:lower:]' '[:upper:]')"
            derived="${first_char}${derived:1}"
          else
            derived="Task ${pn}"
          fi
          echo "WARN: #$pn has title: null — --repair does not write titles (single-value judgment call, not a normalization). Suggested value, matching generate-todo.sh's own derived-title fallback: \"$derived\"" >&2
          ;;
        topic)
          echo "WARN: #$pn has topic: null — --repair does not write topics (no automated derivation exists; generate-task-order.sh already buckets untagged tasks under \"Uncategorized\" at render time). Assign a topic manually in specs/state.json." >&2
          ;;
      esac
    done <<< "$ab_findings"
  fi

  if [ "$any_write" = false ]; then
    echo "--repair: nothing to normalize (no candidate has a literal-null dependencies or file_scope field)."
    exit 0
  fi

  # NOTE: `select(.project_number as $pn | ($cands | index($pn)) != null)` — NOT
  # `select(($cands | index(.project_number)) != null)`. The latter re-pipes "." into $cands
  # inside index()'s argument (`EXPR | index(ARG)` evaluates ARG against EXPR's output, not the
  # original "."), so `.project_number` would try to index the $cands ARRAY with a string and
  # jq would raise "Cannot index array with string \"project_number\"". Binding the scalar via
  # `as` first (as Class A/B above already does with `$d`) keeps "." on the task object.
  echo "--repair: before/after diff of every field this repair will change:"
  # `|| true`: this is a purely informational preview print, distinct from the actual
  # mutex-guarded write below via state-write.sh -- a jq hiccup here must never abort the script
  # before the real write is attempted.
  jq -r --argjson candidates "$candidates_json" '
    ($candidates) as $cands |
    .active_projects[] | select(.project_number as $pn | ($cands | index($pn)) != null) |
    select(.dependencies == null or .file_scope == null) |
    "  #\(.project_number): dependencies " + (.dependencies | tojson) + " -> " + ((.dependencies // []) | tojson) +
    "  ;  file_scope " + (.file_scope | tojson) + " -> " + ((.file_scope // []) | tojson)
  ' "$STATE_FILE" || true

  if ! "$SCRIPT_DIR/state-write.sh" \
    '($candidates) as $cands |
    (.active_projects[] | select(.project_number as $pn | ($cands | index($pn)) != null)) |=
      (.dependencies = (.dependencies // []) | .file_scope = (.file_scope // []))' \
    --session-id "$session_id" \
    --argjson candidates "$candidates_json"; then
    # state-write.sh itself already prints a distinguishing "transform failed" (exit 3) vs
    # "invalid JSON" (exit 4) vs "mutex ABORT" (exit 2) message and leaves specs/state.json
    # untouched on every one of those paths -- this is a pass-through, not a new error surface.
    echo "ERROR: orchestrate-predispatch-review.sh: --repair write failed via state-write.sh; specs/state.json left untouched (see message above)." >&2
    exit 2
  fi

  echo "--repair: specs/state.json updated via state-write.sh (mutex-guarded acquire -> mktemp -> jq transform -> jq empty validate -> mv -> release)."
  exit 0
fi

# ===========================================================================
# Report mode (default): Classes C and D consume orchestrate-batch-admit.sh's
# existing verdicts as a subprocess — never a re-derivation of the overlap predicate.
# ===========================================================================
admit_checked=true
admit_degraded_reason=""
admit_session_id_args=()
if [ "$session_id_explicit" = true ]; then
  admit_session_id_args=(--session-id "$session_id")
fi
admit_stderr_file=$(mktemp) || true
# `if VAR=$(cmd); then admit_exit=0; else admit_exit=$?; fi` rather than a bare `VAR=$(cmd)`
# followed by `admit_exit=$?`: orchestrate-batch-admit.sh exiting non-zero (e.g. its own usage or
# state-unavailable errors) is a routine, explicitly-handled outcome (see the admit_checked=false
# branch just below, which drives Classes C/D/E to a graceful SKIPPED report rather than aborting
# this script) -- under `set -e` a bare failing assignment would abort the whole script here,
# before that degradation path could ever run, losing even the Class A/B report already computed
# above. Mirrors the same fix applied earlier in this file and in the other Phase 6 scripts.
if admit_output=$(bash "$SCRIPT_DIR/orchestrate-batch-admit.sh" --invocation-count "${#task_args[@]}" "${admit_session_id_args[@]}" "${task_args[@]}" 2>"$admit_stderr_file"); then
  admit_exit=0
else
  admit_exit=$?
fi
admit_stderr=$(cat "$admit_stderr_file" 2>/dev/null) || true
rm -f "$admit_stderr_file"
if [ "$admit_exit" -ne 0 ]; then
  admit_checked=false
  admit_degraded_reason="orchestrate-batch-admit.sh exited $admit_exit: ${admit_stderr:-no stderr captured}"
fi

cd_findings=""
if [ "$admit_checked" = true ]; then
  verdicts_json=$(printf '%s\n' "$admit_output" | jq -s -c '.' 2>/dev/null) || true
  if [ -z "$verdicts_json" ]; then
    verdicts_json='[]'
  fi
  cd_findings=$(jq -n -c \
    --argjson verdicts "$verdicts_json" \
    --slurpfile state_arr "$STATE_FILE" \
    '
    def norm: rtrimstr("/");
    ($state_arr[0].active_projects // []) as $all |

    ( # Class C: self-modification, with declaration-coarseness diagnosis
      $verdicts[] as $v
      | select($v.decision == "defer" and $v.defer_reason == "self_modifying")
      | ($v.task_number) as $c
      | ([$all[] | select(.project_number == $c)] | first) as $entry
      | ($entry.file_scope // []) as $scope
      | ($v.critical_path) as $cp
      | ($cp | norm) as $ncp
      | ([$scope[] | select(
            (. | norm) as $ns
            | ($ns == $ncp) or ($ncp | startswith($ns + "/")) or ($ns | startswith($ncp + "/"))
          )] | first) as $matched_entry
      | select($matched_entry != null)
      | ($matched_entry | norm) as $nme
      | (($ncp != $nme) and ($ncp | startswith($nme + "/"))) as $is_coarse
      | {class: "C", task_number: $c, critical_path: $cp, critical_label: $v.critical_label,
         matched_scope_entry: $matched_entry, coarse: $is_coarse}
    ),
    ( # Class C-admitted: the hazard IS computed and IS carried on the verdict even when the
      # candidate is a SOLO self-modifying dispatch (admitted, not deferred -- defer_reason and
      # critical_path/critical_label exist only on the defer branch, so this never re-derives a
      # critical-path match; it reports the declared file_scope of the candidate instead, per
      # the Non-Goals of this phase). Never printing this row was the false negative this phase
      # fixes: a solo self_modifying:true admit used to render as "0 findings" even though the
      # hazard was live and carried on the verdict all along.
      $verdicts[] as $v
      | select($v.decision == "admit" and $v.self_modifying == true)
      | ($v.task_number) as $c
      | ([$all[] | select(.project_number == $c)] | first) as $entry
      | {class: "C-admitted", task_number: $c, file_scope: ($entry.file_scope // [])}
    ),
    ( # Class D: missing cross-batch serializing edge, suggested (never written)
      $verdicts[] as $v
      | select($v.decision == "defer" and $v.defer_reason == "file_scope_collision" and $v.collision_scope == "cross_batch")
      | ($v.task_number) as $c
      | (if $c > $v.colliding_task_number then $c else $v.colliding_task_number end) as $dependent
      | (if $c > $v.colliding_task_number then $v.colliding_task_number else $c end) as $predecessor
      | {class: "D", task_number: $c, colliding_task_number: $v.colliding_task_number,
         colliding_task_status: $v.colliding_task_status, overlapping_path: $v.overlapping_path,
         suggested_dependent: $dependent, suggested_predecessor: $predecessor,
         corroborated_by: ($v.corroborated_by // [])}
    ),
    ( # Class D-admitted: an admitted idle_overlap_advisory carries a real cross-batch overlap
      # that was NOT deferred (no execution evidence against the idle target) -- admitted, not
      # deferred, advisory. Fields relayed verbatim from the advisory the verdict already carries;
      # no new diagnosis, matching the existing convention already used by Class E below.
      $verdicts[] as $v
      | select($v.decision == "admit" and ($v.idle_overlap_advisory != null))
      | {class: "D-admitted", task_number: $v.task_number,
         colliding_task_number: $v.idle_overlap_advisory.colliding_task_number,
         colliding_task_status: $v.idle_overlap_advisory.colliding_task_status,
         overlapping_path: $v.idle_overlap_advisory.overlapping_path,
         collision_scope: $v.idle_overlap_advisory.collision_scope}
    ),
    ( # Class E (NEW in v4): session-registry contention -- re-presents
      # orchestrate-batch-admit.sh defer_reason == "session_active" verdicts verbatim; no new
      # diagnosis beyond what the verdict itself already carries.
      $verdicts[] as $v
      | select($v.decision == "defer" and $v.defer_reason == "session_active")
      | {class: "E", task_number: $v.task_number, session_id: $v.session_id,
         colliding_task_number: $v.colliding_task_number, overlapping_path: $v.overlapping_path,
         session_liveness_reason: $v.session_liveness_reason}
    )
    ' 2>&1) || true
fi

# ===========================================================================
# Report output — all four sections printed unconditionally, every time.
# ===========================================================================
echo "=== Pre-dispatch review ==="
echo ""
echo "Invocation: ${task_args[*]}"
echo ""

echo "-- Class A: Dependency edge classification --"
# Split into a primary (loud) list and a separate, clearly-labeled informational list for
# archived_satisfied edges, using this script's own established two-part convention (the
# "Deferred: ..." / "Admitted: ..." shape Classes C and D already use below) -- demotion, never
# suppression, per this script's never-silent design philosophy. A dependency satisfied by an
# archived task is not a hazard; the loud "nonexistent" wording is reserved for an edge
# resolvable nowhere.
class_a_lines=""
class_a_archived_lines=""
if [ -n "$ab_findings" ]; then
  class_a_lines=$(printf '%s\n' "$ab_findings" | jq -r '
    select(.class == "A" and .bucket != "archived_satisfied")
    | "#\(.task_number) depends on #\(.dependency): \(.bucket)" +
      (if .dependency_status then " (status: \(.dependency_status))" else "" end)
  ' 2>/dev/null) || true
  class_a_archived_lines=$(printf '%s\n' "$ab_findings" | jq -r '
    select(.class == "A" and .bucket == "archived_satisfied")
    | "#\(.task_number) depends on #\(.dependency): archived (satisfied)" +
      (if .dependency_status then " (status: \(.dependency_status))" else "" end)
  ' 2>/dev/null) || true
fi
if [ -z "$class_a_lines" ] && [ -z "$class_a_archived_lines" ]; then
  echo "0 findings (every raw dependency edge is intra-batch, or this invocation carries no out-of-batch/nonexistent/archived targets)."
else
  echo "Primary (live/terminal/nonexistent):"
  if [ -z "$class_a_lines" ]; then
    echo "  0 findings (every raw dependency edge is intra-batch, or resolves only to an archived-satisfied target)."
  else
    printf '%s\n' "$class_a_lines" | sed 's/^/  /'
  fi
  echo ""
  echo "Archived (satisfied):"
  if [ -z "$class_a_archived_lines" ]; then
    echo "  0 archived-satisfied edges (no candidate depends on a task resolved via the archive)."
  else
    printf '%s\n' "$class_a_archived_lines" | sed 's/^/  /'
  fi
fi
echo ""

# Class B's negative was swept for the same "0 findings" vs. "0 matched" conflation Classes C/D/E
# had: Class B derives its findings directly from state.json fields with no defer/admit filter of
# any kind, so its existing negative is already accurate as written and needed no change.
echo "-- Class B: Metadata defects (literal null on dependencies/file_scope/title/topic) --"
class_b_lines=""
if [ -n "$ab_findings" ]; then
  class_b_lines=$(printf '%s\n' "$ab_findings" | jq -r '
    select(.class == "B")
    | "#\(.task_number): field \"\(.field)\" is null"
  ' 2>/dev/null) || true
fi
if [ -z "$class_b_lines" ]; then
  echo "0 findings (no candidate has a literal-null dependencies/file_scope/title/topic field)."
else
  printf '%s\n' "$class_b_lines"
  repairable=$(printf '%s\n' "$ab_findings" | jq -r 'select(.class == "B" and (.field == "dependencies" or .field == "file_scope")) | .task_number' 2>/dev/null | sort -un | tr '\n' ' ') || true
  if [ -n "$repairable" ]; then
    echo ""
    echo "To normalize the dependencies/file_scope null field(s) above (never title/topic — those are WARN-only), run directly:"
    echo "  bash .claude/scripts/orchestrate-predispatch-review.sh --repair ${repairable}"
  fi
fi
echo ""

echo "-- Class C: Self-modification / declaration coarseness --"
if [ "$admit_checked" = false ]; then
  echo "SKIPPED (degraded: $admit_degraded_reason)"
else
  class_c_lines=""
  if [ -n "$cd_findings" ]; then
    class_c_lines=$(printf '%s\n' "$cd_findings" | jq -r '
      select(.class == "C")
      | "#\(.task_number): file_scope names orchestrator-critical path \(.critical_path) (\(.critical_label))" +
        (if .coarse then
           " -- declared scope entry \"\(.matched_scope_entry)\" is a directory prefix broader than the critical file; consider narrowing file_scope to \"\(.critical_path)\""
         else
           " -- declared scope entry \"\(.matched_scope_entry)\" already names the file exactly (not a coarse declaration)"
         end)
    ' 2>/dev/null) || true
  fi
  # Class C-admitted: never print a "0 findings" negative that was never tested against this
  # row set. A solo self_modifying:true candidate is ADMITTED (see orchestrate-batch-admit.sh's
  # own non-goal: Class C is a CONSUMER, never a fork, of that predicate) -- the hazard IS
  # computed and IS carried on the verdict either way, so it gets its own labelled row here,
  # styled on context/patterns/orchestrate-batch-results-template.md's own
  # "Admitted (idle overlap advisory)" section: admitted, not deferred, advisory.
  class_c_admitted_lines=""
  if [ -n "$cd_findings" ]; then
    class_c_admitted_lines=$(printf '%s\n' "$cd_findings" | jq -r '
      select(.class == "C-admitted")
      | "#\(.task_number): file_scope \(.file_scope | tojson) -- ADMITTED carrying self_modifying: true (hazard live, not deferred)"
    ' 2>/dev/null) || true
  fi
  if [ -z "$class_c_lines" ] && [ -z "$class_c_admitted_lines" ]; then
    echo "0 findings (no candidate carries the self-modification hazard, deferred or admitted)."
  else
    echo "Deferred (self-modification):"
    if [ -z "$class_c_lines" ]; then
      c_admitted_count=$(printf '%s\n' "$class_c_admitted_lines" | grep -c . || true)
      echo "  0 deferred for self-modification (${c_admitted_count} admitted carrying self_modifying: true)."
    else
      printf '%s\n' "$class_c_lines" | sed 's/^/  /'
    fi
    echo ""
    echo "Admitted (self-modification hazard):"
    if [ -z "$class_c_admitted_lines" ]; then
      echo "  0 admitted carrying self_modifying: true."
    else
      printf '%s\n' "$class_c_admitted_lines" | sed 's/^/  /'
    fi
  fi
fi
echo ""

echo "-- Class D: Missing cross-batch serializing edges --"
if [ "$admit_checked" = false ]; then
  echo "SKIPPED (degraded: $admit_degraded_reason)"
else
  class_d_lines=""
  if [ -n "$cd_findings" ]; then
    class_d_lines=$(printf '%s\n' "$cd_findings" | jq -r '
      select(.class == "D")
      | "#\(.task_number): file_scope collision with out-of-batch task #\(.colliding_task_number) (status: \(.colliding_task_status)) at \(.overlapping_path) -- suggest adding #\(.suggested_predecessor) as a dependencies[] entry on #\(.suggested_dependent) to serialize them" +
        (if ((.corroborated_by // []) | index("session_registry")) then " [corroborated by a live registered session]" else "" end)
    ' 2>/dev/null) || true
  fi
  # Class D-admitted: the identical "never print an untested negative" fix as Class C, for the
  # idle_overlap_advisory an ADMIT verdict can carry. Fields relayed verbatim from the advisory,
  # matching Class E's existing no-new-diagnosis convention.
  class_d_admitted_lines=""
  if [ -n "$cd_findings" ]; then
    class_d_admitted_lines=$(printf '%s\n' "$cd_findings" | jq -r '
      select(.class == "D-admitted")
      | "#\(.task_number): file_scope overlap with IDLE out-of-batch task #\(.colliding_task_number) (status: \(.colliding_task_status)) at \(.overlapping_path) -- ADMITTED (no execution evidence); add a dependencies[] edge if ordering between them matters"
    ' 2>/dev/null) || true
  fi
  if [ -z "$class_d_lines" ] && [ -z "$class_d_admitted_lines" ]; then
    echo "0 findings (no missing cross-batch serializing edges, deferred or admitted)."
  else
    echo "Deferred (missing serializing edge):"
    if [ -z "$class_d_lines" ]; then
      d_admitted_count=$(printf '%s\n' "$class_d_admitted_lines" | grep -c . || true)
      echo "  0 deferred for cross-batch collision (${d_admitted_count} admitted carrying an idle_overlap_advisory)."
    else
      printf '%s\n' "$class_d_lines" | sed 's/^/  /'
    fi
    echo ""
    echo "Admitted (idle cross-batch overlap):"
    if [ -z "$class_d_admitted_lines" ]; then
      echo "  0 admitted carrying an idle_overlap_advisory."
    else
      printf '%s\n' "$class_d_admitted_lines" | sed 's/^/  /'
    fi
  fi
fi
echo ""

echo "-- Class E: Session-registry contention (NEW in v4) --"
if [ "$admit_checked" = false ]; then
  echo "SKIPPED (degraded: $admit_degraded_reason)"
elif [ "$session_id_explicit" = false ]; then
  echo "SKIPPED (no --session-id supplied to this script; orchestrate-batch-admit.sh's session-registry input was itself skipped via its own D6 degradation)."
else
  class_e_lines=""
  if [ -n "$cd_findings" ]; then
    class_e_lines=$(printf '%s\n' "$cd_findings" | jq -r '
      select(.class == "E")
      | "#\(.task_number): live registered session \(.session_id) (liveness: \(.session_liveness_reason)) covers task #\(.colliding_task_number) whose file_scope overlaps this candidate at \(.overlapping_path)"
    ' 2>/dev/null) || true
  fi
  if [ -z "$class_e_lines" ]; then
    # Swept for the same "0 findings" vs. "0 matched" conflation Class C/D had: unlike them,
    # Class E's session_active reason exists ONLY on the defer branch of the admission predicate
    # (see orchestrate-batch-admit.sh's own session_contention arm) -- an admit verdict cannot
    # carry it at all, so there is no "admitted-with-this-hazard" case to under-report here. The
    # negative below is already accurate; restated to say so explicitly rather than silently.
    echo "0 deferred for session contention (this signal exists only on defer verdicts; no candidate's file_scope overlaps a live registered session's covered scope)."
  else
    printf '%s\n' "$class_e_lines"
  fi
fi

exit 0
