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

# MAX_PROBE_INVOCATIONS (named constant, per Mode B's bounded-search requirement): the hard cap
# on how many times THIS invocation of orchestrate-suggest-next-batch.sh will shell out to the
# real orchestrate-batch-admit.sh. Mode A's own shrink loop is already self-bounding (each round
# strictly removes at least one member from a set no larger than MAX_TASKS, so at most MAX_TASKS
# rounds), but shares this same counter and cap as one uniform safety net rather than a second,
# mode-specific limit. Reaching the cap is rendered EXPLICITLY (via this function's reserved
# return code 9, checked by every caller) — never a silent truncation of the search.
MAX_PROBE_INVOCATIONS=20
PROBE_INVOCATION_COUNT=0

# ── probe_candidate_set(): the ONE shared admission-probe function. Both Mode A and Mode B call
#    this and only this to establish admissibility — never a local re-derivation. Populates the
#    caller-visible variable named by $1 with the raw NDJSON verdicts (one line per candidate,
#    orchestrate-batch-admit-v6 schema) and returns the real script's own exit status, EXCEPT
#    when the MAX_PROBE_INVOCATIONS cap above is reached: the real admission script is then not
#    invoked at all, and this function returns 9 (a reserved, non-admission-script exit code
#    no caller mistakes for a real verdict stream). ─────────────────────────────────────────────
probe_candidate_set() {
  local __outvar="$1"; shift
  local __phase_map="$1"; shift
  local -a __candidates=("$@")
  PROBE_INVOCATION_COUNT=$((PROBE_INVOCATION_COUNT + 1))
  if [ "$PROBE_INVOCATION_COUNT" -gt "$MAX_PROBE_INVOCATIONS" ]; then
    printf -v "$__outvar" '%s' ""
    return 9
  fi
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

TASK_LOCK_SCRIPT="${SCRIPT_DIR}/task-lock.sh"

# ── resolve_noop_token(): Decision 3's status-no-op restriction, read directly off
#    update-task-status.sh's own closed map_status() vocabulary (never re-derived
#    independently) -- which (operation, target_status) pair, if any, resolves to the task's
#    CURRENT state.json status as a no-op replay. Prints "operation target_status" and returns
#    0 when resolvable; returns 1 (nothing printed) when the current status has no resolving
#    token at all -- which is the real, closed-vocabulary case for "not_started" (and for the
#    terminal statuses, which never reach here because they are excluded from readiness). ──────
resolve_noop_token() {
  local status_lc
  status_lc="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')"
  case "$status_lc" in
    researching)  echo "preflight research" ;;
    researched)   echo "postflight research" ;;
    planning)     echo "preflight plan" ;;
    planned)      echo "postflight plan" ;;
    implementing) echo "preflight implement" ;;
    partial)      echo "postflight partial" ;;
    blocked)      echo "postflight blocked" ;;
    pr_ready)     echo "preflight pr_ready" ;;
    hold)         echo "preflight hold" ;;
    *) return 1 ;;
  esac
}

# ── propose_edge_for_pair(): the edge-proposing step (Decisions 1-3). Given an in_batch
#    file_scope_collision pair, already ordered (lower, higher) per Decision 1, renders the
#    ordered-sequence suggestion and the exact --depends-on-add command. Under --write-edges,
#    performs the write and RE-PROBES the pair through the one shared probe_candidate_set()
#    function, showing both flip to admit -- never re-checking for cycles itself
#    (update-task-status.sh already refuses a cycle-introducing edge). A refused write, or a
#    higher task whose current status has no resolving no-op token (see resolve_noop_token()
#    above -- the genuine "not_started" gap: update-task-status.sh's map_status() has no
#    operation:target_status combination that resolves to "not_started", so a task still in
#    its initial status cannot receive this call today), falls back to propose-only for this
#    pair LOUDLY -- never silently dropping it from the suggestion. Returns 0 only when the
#    write happened AND the re-probe confirmed both admit; 1 otherwise (propose-only). ──────────
propose_edge_for_pair() {
  local lower="$1" higher="$2"
  local higher_status token op target display_cmd

  higher_status=$(jq -r --argjson n "$higher" '.active_projects[] | select(.project_number==$n) | .status' "$STATE_FILE")

  echo "/orchestrate ${lower}, then ${higher}  (ordered sequence -- file_scope collision)"
  echo "  task ${higher} would gain a dependency on task ${lower}; orchestrate-batch-admit.sh's"
  echo "  dependency-edge exemption is what makes this sequence admissible once that edge"
  echo "  exists (see this script's own header, disposition (a))."

  if ! token=$(resolve_noop_token "$higher_status"); then
    echo "  NOTE: task ${higher}'s current status '${higher_status}' has no resolving" >&2
    echo "  operation:target_status no-op token in update-task-status.sh, so the" >&2
    echo "  --depends-on-add call cannot be issued until it leaves that status. Add the" >&2
    echo "  edge by hand, or re-run this suggester after a status transition." >&2
    return 1
  fi
  read -r op target <<< "$token"
  display_cmd="bash .claude/scripts/update-task-status.sh ${op} ${higher} ${target} ${session_id_arg} --depends-on-add=[${lower}]"
  echo "  proposed edge: ${display_cmd}"

  if [ "$write_edges_flag" = true ]; then
    if bash "${SCRIPT_DIR}/update-task-status.sh" "$op" "$higher" "$target" "$session_id_arg" "--depends-on-add=[${lower}]" >/dev/null 2>&1; then
      echo "  edge written; re-probing [${lower}, ${higher}]..."
      local reprobe_verdicts reprobe_phase_map reprobe_rc
      reprobe_phase_map="$(derive_phase_map "$lower" "$higher")"
      probe_candidate_set reprobe_verdicts "$reprobe_phase_map" "$lower" "$higher"
      reprobe_rc=$?
      if [ "$reprobe_rc" -eq 0 ]; then
        render_verdict_evidence "$reprobe_verdicts"
        return 0
      else
        echo "  WARNING: re-probe after writing the edge failed (exit $reprobe_rc); verify manually." >&2
        return 1
      fi
    else
      echo "  WARNING: edge write refused by update-task-status.sh; falling back to propose-only" >&2
      echo "  for this pair." >&2
      return 1
    fi
  fi
  return 1
}

# ── suggest_from_pool(): the ONE shared selection+probe+render engine. Both Mode A (the full
#    ready pool) and Mode B (the ready pool minus every task covered by a live queue entry)
#    call this with their own input pool. Applies select_candidates()'s doctrine, then probes
#    the result through probe_candidate_set() -- handling any in_batch file_scope_collision
#    pair via propose_edge_for_pair() before falling back to the plain shrink-and-retry for
#    every other defer reason -- until either a stable all-admit set is found, the pool is
#    exhausted, or MAX_PROBE_INVOCATIONS is reached (reserved return code 9, rendered
#    explicitly, never a silent truncation). Returns 0 when at least one sequence block and/or a final
#    joint batch line was rendered; 1 when nothing could be suggested from this pool at all. ───
suggest_from_pool() {
  local -a pool=("$@")
  [ "${#pool[@]}" -eq 0 ] && return 1

  local -a candidates=()
  while IFS= read -r t; do
    [ -n "$t" ] && candidates+=("$t")
  done < <(select_candidates "${pool[@]}")
  [ "${#candidates[@]}" -eq 0 ] && return 1

  local any_sequence_rendered=false
  local verdicts phase_map probe_rc
  local -a remaining=("${candidates[@]}")
  while [ "${#remaining[@]}" -gt 0 ]; do
    phase_map="$(derive_phase_map "${remaining[@]}")"
    probe_candidate_set verdicts "$phase_map" "${remaining[@]}"
    probe_rc=$?
    if [ "$probe_rc" -eq 9 ]; then
      echo "Alternatives/batch search stopped: the probe-invocation cap (MAX_PROBE_INVOCATIONS=${MAX_PROBE_INVOCATIONS}) was reached before this candidate set stabilized. Re-run the suggester to continue from a fresh cap budget."
      return 1
    elif [ "$probe_rc" -ne 0 ]; then
      echo "ERROR: orchestrate-suggest-next-batch.sh: orchestrate-batch-admit.sh failed while probing candidate set [${remaining[*]}]." >&2
      exit 3
    fi

    # Edge-proposing pass: handle every in_batch file_scope_collision pair in this round's
    # verdicts BEFORE the plain admit/defer bucketing below.
    local -a handled_pair_members=()
    local line tn decision defer_reason collision_scope colliding already h lower higher
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      decision=$(echo "$line" | jq -r '.decision')
      [ "$decision" != "defer" ] && continue
      tn=$(echo "$line" | jq -r '.task_number')
      defer_reason=$(echo "$line" | jq -r '.defer_reason // ""')
      [ "$defer_reason" != "file_scope_collision" ] && continue
      collision_scope=$(echo "$line" | jq -r '.collision_scope // ""')
      [ "$collision_scope" != "in_batch" ] && continue
      colliding=$(echo "$line" | jq -r '.colliding_task_number // ""')
      [ -z "$colliding" ] && continue
      already=false
      for h in "${handled_pair_members[@]:-}"; do
        [ "$h" = "$tn" ] && already=true
      done
      [ "$already" = true ] && continue
      if [ "$tn" -lt "$colliding" ]; then lower="$tn"; higher="$colliding"; else lower="$colliding"; higher="$tn"; fi
      propose_edge_for_pair "$lower" "$higher"
      any_sequence_rendered=true
      handled_pair_members+=("$tn" "$colliding")
    done <<< "$verdicts"

    local -a next_remaining=() dropped_other=()
    local in_handled
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      tn=$(echo "$line" | jq -r '.task_number')
      decision=$(echo "$line" | jq -r '.decision')
      in_handled=false
      for h in "${handled_pair_members[@]:-}"; do
        [ "$h" = "$tn" ] && in_handled=true
      done
      [ "$in_handled" = true ] && continue
      if [ "$decision" = "admit" ]; then
        next_remaining+=("$tn")
      else
        dropped_other+=("$tn")
      fi
    done <<< "$verdicts"

    if [ "${#dropped_other[@]}" -eq 0 ] && [ "${#handled_pair_members[@]}" -eq 0 ]; then
      local IFS=', '
      echo "/orchestrate ${next_remaining[*]}"
      unset IFS
      render_verdict_evidence "$verdicts"
      echo "  (verified admissible when suggested, against the current queue/registry;"
      echo "   re-run this suggester, or re-dispatch and let the real admission check at"
      echo "   dispatch time, to re-verify before acting)"
      return 0
    fi
    remaining=("${next_remaining[@]}")
  done

  [ "$any_sequence_rendered" = true ] && return 0
  return 1
}

# ── mode_next_batch(): Mode A. Pool = the full ready pool. Read-only: specs/state.json is
#    never written in this default (non-`--write-edges`) form. ─────────────────────────────────
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

  if ! suggest_from_pool "${ready[@]}"; then
    echo "No suggestible batch: every candidate drawn from a ready pool of ${#ready[@]} task(s)"
    echo "deferred this round; re-run after the deferring condition(s) clear."
  fi
  exit 0
}

# ── mode_alternatives(): Mode B. Reads the live orchestration queue
#    (task-lock.sh queue-list) and excludes every task already covered by a LIVE entry from
#    the ready pool before handing the remainder to the same suggest_from_pool() engine Mode A
#    uses. An empty queue is a normal case, not an error. Read-only in its default form. ────────
mode_alternatives() {
  local queue_ndjson
  if ! run_capture_stdout queue_ndjson bash "$TASK_LOCK_SCRIPT" queue-list; then
    echo "ERROR: orchestrate-suggest-next-batch.sh: task-lock.sh queue-list failed; cannot search for alternatives." >&2
    exit 3
  fi

  declare -A covered=()
  local line live tn
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    live=$(echo "$line" | jq -r '.live // false')
    [ "$live" != "true" ] && continue
    while IFS= read -r tn; do
      [ -z "$tn" ] && continue
      covered[$tn]=1
    done < <(echo "$line" | jq -r '(.task_numbers // [])[] | tostring')
  done <<< "$queue_ndjson"

  local -a ready=()
  while IFS= read -r tn; do
    [ -n "$tn" ] && ready+=("$tn")
  done < <(build_ready_pool)

  local -a pool=()
  for tn in "${ready[@]}"; do
    [ -z "${covered[$tn]:-}" ] && pool+=("$tn")
  done

  if [ "${#pool[@]}" -eq 0 ]; then
    echo "No suggestible alternative: every ready-candidate task is already covered by a live"
    echo "orchestration queue entry (or the ready pool itself is empty)."
    exit 0
  fi

  if ! suggest_from_pool "${pool[@]}"; then
    echo "No suggestible alternative: every candidate drawn from the queue-excluded ready pool"
    echo "of ${#pool[@]} task(s) deferred this round; re-run after the deferring condition(s)"
    echo "clear, or once the live queue entry(ies) finish."
  fi
  exit 0
}

case "$MODE" in
  next-batch)
    mode_next_batch
    ;;
  alternatives)
    mode_alternatives
    ;;
esac
