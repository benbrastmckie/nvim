#!/usr/bin/env bash
# orchestrate-suggest-next-batch.sh — Next-admissible-batch suggestion (Mode A) and
# alternatives-on-conflict (Mode B) for /orchestrate, both established EXCLUSIVELY by invoking
# the real `orchestrate-batch-admit.sh` predicate and reading its verdicts.
#
# Purpose: at the end of an orchestration (Mode A), suggest the next most natural batch of tasks
# to run after clearing context — a batch that `orchestrate-batch-admit.sh` would ACTUALLY ADMIT
# together, so the user can open a fresh session and run it directly. When an orchestration is
# instead REFUSED for conflicting with an in-flight one (Mode B), suggest nearby task sets drawn
# from the orchestration queue that could run in parallel instead. Both modes share one
# admission-probe function; neither mode ever re-derives, approximates, or forks the collision
# predicate itself.
#
# ── (a) Binding constraint ──────────────────────────────────────────────────────────────────────
# Admissibility is established ONLY by invoking `orchestrate-batch-admit.sh` and reading its
# NDJSON verdicts. A second, locally-reimplemented copy of that predicate would inevitably drift
# from the real one, and a suggestion the real script then refuses at actual dispatch time is
# worse than offering no suggestion at all. This script therefore contains NO directory-prefix
# overlap comparison, no hand-rolled copy of the shared overlap predicate's jq helper functions,
# and does not source the shared overlap-predicate library the real admission script and its
# siblings source (see `context/patterns/file-footprint-overlap.md` for that canonical
# predicate) — every overlap fact this script consumes arrives as a structured field on a
# verdict object (`defer_reason`, `collision_scope`, `colliding_task_number`, `overlapping_path`,
# `absent_scope_advisory`, `designated_absent_candidate`), never computed here.
#
# ── (b) Self-modification-hazard disposition ────────────────────────────────────────────────────
# This script is NOT added to `context/reference/orchestrator-critical-paths.json`. It fails the
# reachability half of that list's two-conjunctive admission test (reachable on the MT dispatch
# path AND decision-relevant): this script runs strictly AFTER, or entirely independently of, the
# admission/wave/lock decisions of the invocation it reports on — it never feeds back into one.
# This is the same disposition already recorded for its Move 5 sibling,
# `orchestrate-conclusion-aggregate.sh`; see `context/patterns/batch-orchestration-guardrails.md`'s
# Exclusion Table for the shared row.
#
# ── (c) Edge-direction convention (Decision 1) ──────────────────────────────────────────────────
# When the edge-proposing step (Mode A and Mode B both delegate to it) proposes a serializing
# `dependencies[]` edge for a colliding pair, the LOWER `project_number` is always rendered as the
# predecessor: `--depends-on-add` is called on the HIGHER-numbered task, which is the task that
# *gains* the dependency. This is a deterministic RENDERING choice only, chosen for consistency
# with `orchestrate-predispatch-review.sh`'s existing Class D display convention and the
# self-modification tie-breaker's ascending-first convention. It is explicitly NOT a claim that
# task numbering reveals a pre-existing truth about which task logically precedes the other —
# `context/patterns/multi-task-operations.md` warns against exactly that inference.
#
# ── (d) Propose-by-default / --write-edges split (Decision 2) ──────────────────────────────────
# In its default form, the edge-proposing step only PRINTS the exact
# `update-task-status.sh ... --depends-on-add=[...]` command alongside the ordered-sequence
# suggestion — it never mutates `specs/state.json` unasked. The explicit `--write-edges` flag
# performs that write, then RE-INVOKES the real admission probe over the same candidate set and
# shows both members flip to `admit`. Neither form may ever silently drop a colliding pair from
# the suggestion.
#
# ── (e) Suggestions are time-stamped claims, not guarantees (Decision 6) ────────────────────────
# Every rendered suggestion states plainly that the set was admissible WHEN SUGGESTED and should
# be re-verified at actual dispatch time — the real admission check at dispatch remains the sole
# source of truth. Mode A and Mode B both leave `specs/state.json` unchanged in their default
# (non-`--write-edges`) form.
#
# Usage:
#   orchestrate-suggest-next-batch.sh --next-batch --session-id <id> [--max-tasks <N>] [--write-edges]
#       Mode A: build the ready-candidate pool from specs/state.json, select a candidate set by
#       the documented selection doctrine, and render the first set the real admission script
#       admits (or an ordered sequence, for a colliding pair, per the edge-proposing step).
#   orchestrate-suggest-next-batch.sh --alternatives --session-id <id> [--max-tasks <N>] [--write-edges]
#       Mode B: read the live orchestration queue (`task-lock.sh queue-list`) and search, bounded,
#       for a candidate set disjoint from every live queue entry — for use when an orchestration
#       was just refused by the blocking `queue-check` gate.
#   orchestrate-suggest-next-batch.sh --help
#       Show this usage and exit 0.
#
# Exactly one of --next-batch, --alternatives, --help is required; supplying zero, more than one,
# or an unrecognized flag is a usage error (exit 2) with a loud stderr line naming the problem —
# never a silent default to either mode.
#
# --session-id <id>: forwarded verbatim to `orchestrate-batch-admit.sh --session-id` on every
# probe this script makes, so the session-registry contention input stays active. Required for
# both --next-batch and --alternatives (omitting it degrades the real admission script's own
# session-registry input — see that script's own header); NOT required for --help.
#
# --max-tasks <N>: truncation cap for the selected candidate set, default 8 (MAX_TASKS, per
# `context/patterns/batch-orchestration-guardrails.md`'s batch-size cap). Territory-mandatory
# members are always ordered first, so a trim never splits a mandatory group off the end.
#
# --write-edges: see (d) above. Default off.
#
# Exit codes:
#   0 - a suggestion (or ordered sequence) was rendered, OR the ready/candidate pool was
#       genuinely empty and an explicit "no suggestible batch" line was printed. A candidate pool
#       reaching empty is NEVER a nonzero exit.
#   2 - usage error (missing/duplicate mode, unrecognized flag, non-integer --max-tasks, or
#       --session-id missing for a mode that requires it).
#   3 - specs/state.json unavailable (missing or unparseable), or `orchestrate-batch-admit.sh`
#       could not be located/invoked — a documented, non-usage failure. Fails loud; never
#       silently suggests nothing.

set -euo pipefail

usage() {
  sed -n '2,94p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# --- Paths (sourced BEFORE argument parsing, including --help — same universal-refusal
#     convention as every sibling Move 5 script: this script is not runnable from the source
#     store under any flag, not even --help. See deploy-root-guard.sh for the dual deployed-tree
#     (.claude/scripts/ vs .opencode/scripts/) tolerance this resolution relies on.) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1

if [ $# -eq 0 ]; then
  usage
  exit 2
fi

MODE=""
session_id_arg=""
max_tasks_arg=""
# shellcheck disable=SC2034 # consumed by the edge-proposing step's --write-edges branch
write_edges_flag=false

while [ $# -gt 0 ]; do
  case "$1" in
    --next-batch)
      if [ -n "$MODE" ]; then
        echo "ERROR: orchestrate-suggest-next-batch.sh: exactly one of --next-batch, --alternatives, --help is required (got a second mode flag: --next-batch)." >&2
        exit 2
      fi
      MODE="next-batch"
      shift
      ;;
    --alternatives)
      if [ -n "$MODE" ]; then
        echo "ERROR: orchestrate-suggest-next-batch.sh: exactly one of --next-batch, --alternatives, --help is required (got a second mode flag: --alternatives)." >&2
        exit 2
      fi
      MODE="alternatives"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --session-id)
      session_id_arg="${2:-}"
      shift 2
      ;;
    --session-id=*)
      session_id_arg="${1#--session-id=}"
      shift
      ;;
    --max-tasks)
      max_tasks_arg="${2:-}"
      shift 2
      ;;
    --max-tasks=*)
      max_tasks_arg="${1#--max-tasks=}"
      shift
      ;;
    --write-edges)
      # shellcheck disable=SC2034 # consumed by the edge-proposing step's --write-edges branch
      write_edges_flag=true
      shift
      ;;
    *)
      echo "ERROR: orchestrate-suggest-next-batch.sh: unrecognized argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "ERROR: orchestrate-suggest-next-batch.sh: exactly one of --next-batch, --alternatives, --help is required." >&2
  usage
  exit 2
fi

if [ -z "$session_id_arg" ]; then
  echo "ERROR: orchestrate-suggest-next-batch.sh: --session-id is required for --${MODE}." >&2
  exit 2
fi

MAX_TASKS=8
if [ -n "$max_tasks_arg" ]; then
  if ! [[ "$max_tasks_arg" =~ ^[0-9]+$ ]]; then
    echo "ERROR: orchestrate-suggest-next-batch.sh: '--max-tasks $max_tasks_arg' is not a non-negative integer." >&2
    exit 2
  fi
  MAX_TASKS="$max_tasks_arg"
fi

STATE_FILE="$PROJECT_ROOT/specs/state.json"
if [ ! -f "$STATE_FILE" ] || ! jq -e . "$STATE_FILE" > /dev/null 2>&1; then
  echo "ERROR: orchestrate-suggest-next-batch.sh: $STATE_FILE is missing or unparseable; cannot compute a suggestion." >&2
  exit 3
fi

ADMIT_SCRIPT="${SCRIPT_DIR}/orchestrate-batch-admit.sh"
if [ ! -f "$ADMIT_SCRIPT" ]; then
  echo "ERROR: orchestrate-suggest-next-batch.sh: orchestrate-batch-admit.sh not found at $ADMIT_SCRIPT; cannot establish admissibility." >&2
  exit 3
fi

TRIAGE_SCRIPT="${SCRIPT_DIR}/orchestrate-triage-classify.sh"

# Reuse, never fork: is_terminal_status() (Decision 4's readiness predicate; the terminal-status
# check this script needs, sourced rather than re-transcribed).
if ! . "${SCRIPT_DIR}/lib/task-classification-lib.sh" 2>/dev/null; then
  echo "ERROR: orchestrate-suggest-next-batch.sh: could not source ${SCRIPT_DIR}/lib/task-classification-lib.sh." >&2
  exit 3
fi

# ── Stream-discipline helper (identical convention to orchestrate-cycle-plan.sh's own
#    run_capture_stdout: keeps a collaborator's stdout payload and stderr diagnostics apart, and
#    preserves its exit status) ──────────────────────────────────────────────────────────────────
CAPTURE_DIAG=""
run_capture_stdout() {
  local __outvar="$1"; shift
  local __diag_file __out __rc=0
  __diag_file=$(mktemp "${TMPDIR:-/tmp}/orchestrate-suggest-capture.XXXXXX")
  __out=$("$@" 2>"$__diag_file") || __rc=$?
  CAPTURE_DIAG=$(cat "$__diag_file" 2>/dev/null || true)
  rm -f "$__diag_file"
  [ -n "$CAPTURE_DIAG" ] && printf '%s\n' "$CAPTURE_DIAG" >&2
  printf -v "$__outvar" '%s' "$__out"
  return "$__rc"
}

# ── probe_candidate_set(): the ONE shared admission-probe function. Both Mode A and Mode B call
#    this and only this to establish admissibility — never a local re-derivation. Populates the
#    caller-visible variable named by $1 with the raw NDJSON verdicts (one line per candidate,
#    orchestrate-batch-admit-v6 schema) and returns the real script's own exit status. ──────────
probe_candidate_set() {
  local __outvar="$1"; shift
  local __phase_map="$1"; shift
  local -a __candidates=("$@")
  local -a __admit_args=(--invocation-count "${#__candidates[@]}" --session-id "$session_id_arg")
  [ -n "$__phase_map" ] && __admit_args+=(--phase-map "$__phase_map")
  run_capture_stdout "$__outvar" bash "$ADMIT_SCRIPT" "${__admit_args[@]}" "${__candidates[@]}"
}

# ── build_ready_pool(): Decision 4's readiness predicate. Emits one task_number per line,
#    ascending, for every specs/state.json active_projects entry that is (1) non-terminal
#    (is_terminal_status() false — sourced, never re-transcribed), (2) not itself
#    hold/implementing/blocked/partial (a status-exclusion set distinct from "terminal": a held
#    task is paused by a human, not finished; implementing/blocked/partial tasks are already
#    mid-dispatch or stuck and are not ready for a FRESH next-batch suggestion), and (3) every
#    dependencies[] entry is either absent from active_projects (already completed and
#    archived, or never existed as a live task — treated as satisfied) or itself "completed".
#    This is readiness only — a small, independent, local predicate. It never establishes
#    ADMISSIBILITY; that always comes from probe_candidate_set() below. ─────────────────────────
build_ready_pool() {
  local task_num status dep_statuses_csv all_ok dep_status
  while IFS=$'\t' read -r task_num status dep_statuses_csv; do
    [ -z "$task_num" ] && continue
    if is_terminal_status "$status"; then
      continue
    fi
    case "$(echo "$status" | tr '[:upper:]' '[:lower:]')" in
      hold|implementing|blocked|partial) continue ;;
    esac
    all_ok=true
    if [ -n "$dep_statuses_csv" ]; then
      local -a dep_statuses=()
      IFS=',' read -ra dep_statuses <<< "$dep_statuses_csv"
      for dep_status in "${dep_statuses[@]}"; do
        [ -z "$dep_status" ] && continue
        if [ "$(echo "$dep_status" | tr '[:upper:]' '[:lower:]')" != "completed" ]; then
          all_ok=false
          break
        fi
      done
    fi
    [ "$all_ok" = true ] && echo "$task_num"
  done < <(jq -r '
    (.active_projects | map({(.project_number|tostring): .status}) | add // {}) as $smap
    | .active_projects[]
    | [
        .project_number,
        .status,
        ((.dependencies // []) | map($smap[(.|tostring)] // "completed") | join(","))
      ]
    | @tsv
  ' "$STATE_FILE" | sort -n -k1,1)
}

# ── derive_phase_map(): shell out to orchestrate-triage-classify.sh mt (never re-derive the
#    status->group mapping inline), mirroring orchestrate-cycle-plan.sh's own composition.
#    Emits "task:group[,task:group...]" on stdout, filtered to research|plan|implement (the
#    same filter orchestrate-cycle-plan.sh applies before building --phase-map). ────────────────
derive_phase_map() {
  local -a __tasks=("$@")
  [ "${#__tasks[@]}" -eq 0 ] && return 0
  local __ndjson __rc=0
  if ! run_capture_stdout __ndjson bash "$TRIAGE_SCRIPT" mt "${__tasks[@]}"; then
    __rc=$?
    echo "WARNING: orchestrate-suggest-next-batch.sh: orchestrate-triage-classify.sh degraded (exit $__rc); proceeding with no --phase-map for this probe." >&2
    return 0
  fi
  local __line __t __g __pairs=()
  while IFS= read -r __line; do
    [ -z "$__line" ] && continue
    __t=$(echo "$__line" | jq -r '.task_number')
    __g=$(echo "$__line" | jq -r '.group')
    case "$__g" in
      research|plan|implement) __pairs+=("${__t}:${__g}") ;;
    esac
  done <<< "$__ndjson"
  [ "${#__pairs[@]}" -eq 0 ] && return 0
  local IFS=','
  echo "${__pairs[*]}"
}

# ── select_candidates(): the selection doctrine from
#    context/patterns/batch-orchestration-guardrails.md's "Batching Is the Default" — shared
#    file territory > topic cohesion > graph width — applied to an already-READY pool (see
#    build_ready_pool() above). Emits an ordered candidate list, one per line, truncated to
#    MAX_TASKS with territory-mandatory members ordered first so a trim never splits a
#    mandatory group off the end. NOTE: within a ready pool, two ready tasks can never be
#    connected by a dependencies[] edge to each other (a predecessor would have to be
#    "completed" -- terminal, hence excluded from readiness), so the width-vs-chain nuance of
#    the doctrine's third criterion never actually applies to a ready-pool-only selection; the
#    remaining, ungrouped candidates are therefore left in the pool's own ascending order. The
#    territory grouping below is a SELECTION pre-filter only (exact file_scope string-set
#    intersection, grouped by transitive closure) — never the directory-prefix overlap
#    predicate that actually establishes admissibility; that determination always comes from
#    probe_candidate_set() / orchestrate-batch-admit.sh. ─────────────────────────────────────────
select_candidates() {
  local -a ready=("$@")
  [ "${#ready[@]}" -eq 0 ] && return 0

  local ready_csv
  ready_csv=$(printf '%s\n' "${ready[@]}" | jq -R -s -c 'split("\n") | map(select(length>0) | tonumber)')

  declare -A fs_of=() topic_of=() parent=()
  local t topic fs
  while IFS=$'\t' read -r t topic fs; do
    [ -z "$t" ] && continue
    parent[$t]="$t"
    topic_of[$t]="$topic"
    fs_of[$t]="$fs"
  done < <(jq -r --argjson ready "$ready_csv" '
    .active_projects[]
    | select(([.project_number] - $ready | length) == 0)
    | [.project_number, (.topic // ""), ((.file_scope // []) | join(","))]
    | @tsv
  ' "$STATE_FILE")

  uf_find() {
    local x="$1"
    while [ "${parent[$x]}" != "$x" ]; do
      x="${parent[$x]}"
    done
    echo "$x"
  }
  uf_union() {
    local a b
    a="$(uf_find "$1")"
    b="$(uf_find "$2")"
    [ "$a" = "$b" ] && return 0
    parent[$a]="$b"
  }

  local i j found a_entry
  for i in "${ready[@]}"; do
    [ -z "${fs_of[$i]:-}" ] && continue
    for j in "${ready[@]}"; do
      [ "$i" = "$j" ] && continue
      [ -z "${fs_of[$j]:-}" ] && continue
      found=false
      local -a arr_i=()
      IFS=',' read -ra arr_i <<< "${fs_of[$i]}"
      for a_entry in "${arr_i[@]}"; do
        [ -z "$a_entry" ] && continue
        case ",${fs_of[$j]}," in
          *",${a_entry},"*) found=true; break ;;
        esac
      done
      [ "$found" = true ] && uf_union "$i" "$j"
    done
  done

  declare -A group_members=()
  local r
  for t in "${ready[@]}"; do
    r="$(uf_find "$t")"
    group_members[$r]="${group_members[$r]:-}${group_members[$r]:+ }$t"
  done

  local -a ordered=()
  declare -A seen=()

  # Pass 1: territory-mandatory groups (size > 1), roots visited in ascending order.
  for r in $(printf '%s\n' "${!group_members[@]}" | sort -n); do
    local -a members=()
    read -ra members <<< "${group_members[$r]}"
    [ "${#members[@]}" -le 1 ] && continue
    local -a sorted_members=()
    while IFS= read -r m; do sorted_members+=("$m"); done < <(printf '%s\n' "${members[@]}" | sort -n)
    for t in "${sorted_members[@]}"; do
      if [ -z "${seen[$t]:-}" ]; then
        ordered+=("$t")
        seen[$t]=1
      fi
    done
  done

  # Pass 2: topic-cohesion groups among remaining, unassigned ready tasks.
  declare -A topic_members=()
  for t in "${ready[@]}"; do
    [ -n "${seen[$t]:-}" ] && continue
    topic="${topic_of[$t]:-}"
    [ -z "$topic" ] && continue
    topic_members[$topic]="${topic_members[$topic]:-}${topic_members[$topic]:+ }$t"
  done
  for topic in "${!topic_members[@]}"; do
    local -a tmembers=()
    read -ra tmembers <<< "${topic_members[$topic]}"
    [ "${#tmembers[@]}" -le 1 ] && continue
    local -a sorted_tmembers=()
    while IFS= read -r m; do sorted_tmembers+=("$m"); done < <(printf '%s\n' "${tmembers[@]}" | sort -n)
    for t in "${sorted_tmembers[@]}"; do
      if [ -z "${seen[$t]:-}" ]; then
        ordered+=("$t")
        seen[$t]=1
      fi
    done
  done

  # Pass 3: everything else, pool-ascending order (see function header note on why no
  # width-vs-chain distinction applies within a ready-only pool).
  for t in "${ready[@]}"; do
    if [ -z "${seen[$t]:-}" ]; then
      ordered+=("$t")
      seen[$t]=1
    fi
  done

  local count=0
  for t in "${ordered[@]}"; do
    [ "$count" -ge "$MAX_TASKS" ] && break
    echo "$t"
    count=$((count + 1))
  done
}

# ── render_verdict_evidence(): one line per verdict, "admit" or "defer" with its reason —
#    shared rendering helper used by both Mode A's admitted-set evidence and Mode B's
#    alternative-evidence. ───────────────────────────────────────────────────────────────────────
render_verdict_evidence() {
  local verdicts_ndjson="$1"
  local line tn decision reason
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    tn=$(echo "$line" | jq -r '.task_number')
    decision=$(echo "$line" | jq -r '.decision')
    if [ "$decision" = "admit" ]; then
      echo "  - task ${tn}: admit"
    else
      reason=$(echo "$line" | jq -r '.reason // .defer_reason // "deferred"')
      echo "  - task ${tn}: defer (${reason})"
    fi
  done <<< "$verdicts_ndjson"
}

# ── mode_next_batch(): Mode A. Builds the ready pool, selects a candidate set by the doctrine
#    above, and probes it — repeatedly shrinking to the admitted subset — through the ONE
#    shared probe_candidate_set() function until every remaining member admits or the set is
#    exhausted. Read-only: specs/state.json is never written in this default form. ─────────────
mode_next_batch() {
  local -a ready=()
  while IFS= read -r t; do
    [ -n "$t" ] && ready+=("$t")
  done < <(build_ready_pool)

  if [ "${#ready[@]}" -eq 0 ]; then
    echo "No suggestible batch: the ready-candidate pool is empty (no non-terminal,"
    echo "non-hold/implementing/blocked/partial task with every dependency completed)."
    exit 0
  fi

  local -a candidates=()
  while IFS= read -r t; do
    [ -n "$t" ] && candidates+=("$t")
  done < <(select_candidates "${ready[@]}")

  if [ "${#candidates[@]}" -eq 0 ]; then
    echo "No suggestible batch: the selection doctrine produced an empty candidate set from a"
    echo "non-empty ready pool of ${#ready[@]} task(s)."
    exit 0
  fi

  local verdicts phase_map
  local -a remaining=("${candidates[@]}")
  while [ "${#remaining[@]}" -gt 0 ]; do
    phase_map="$(derive_phase_map "${remaining[@]}")"
    if ! probe_candidate_set verdicts "$phase_map" "${remaining[@]}"; then
      echo "ERROR: orchestrate-suggest-next-batch.sh: orchestrate-batch-admit.sh failed while probing candidate set [${remaining[*]}]." >&2
      exit 3
    fi
    local -a admitted=() deferred=()
    local line tn decision
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      tn=$(echo "$line" | jq -r '.task_number')
      decision=$(echo "$line" | jq -r '.decision')
      if [ "$decision" = "admit" ]; then
        admitted+=("$tn")
      else
        deferred+=("$tn")
      fi
    done <<< "$verdicts"

    if [ "${#deferred[@]}" -eq 0 ]; then
      local IFS=', '
      echo "/orchestrate ${admitted[*]}"
      unset IFS
      render_verdict_evidence "$verdicts"
      echo "  (verified admissible when suggested, against the current queue/registry;"
      echo "   re-run this suggester, or re-dispatch and let the real admission check at"
      echo "   dispatch time, to re-verify before acting)"
      return 0
    fi
    remaining=("${admitted[@]}")
  done

  echo "No suggestible batch: every candidate in the selected set [${candidates[*]}] deferred"
  echo "this round; re-run after the deferring condition(s) clear."
  exit 0
}

case "$MODE" in
  next-batch)
    mode_next_batch
    ;;
  alternatives)
    echo "ERROR: orchestrate-suggest-next-batch.sh: --alternatives is not yet implemented (skeleton phase)." >&2
    exit 3
    ;;
esac
