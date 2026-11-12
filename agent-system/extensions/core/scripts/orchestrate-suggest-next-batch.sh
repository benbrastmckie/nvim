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
# ROUND_LAST_VERDICTS: set by run_candidate_round() (below) on a stable all-admit round --
# the raw NDJSON verdicts for that round, for the caller to render via render_verdict_evidence().
# A plain script-level global, same convention as CAPTURE_DIAG above.
ROUND_LAST_VERDICTS=""
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

# MAX_BATCH_OPTIONS (D1, Defect 2): the hard cap on how many distinct, labelled batch options
# mode_next_batch() (Mode A only -- Mode B's mode_alternatives() keeps its existing single-pool
# behavior, per the plan's Non-Goals) renders in one invocation. Set to 3, one per
# selection-doctrine criterion (shared territory, topic cohesion, graph width) that
# select_candidates_for_criterion() implements. Bounded, more than one, each independently
# probe-verified through the shared MAX_PROBE_INVOCATIONS budget below -- this constant never
# raises that budget, it only bounds how many criteria get a turn at it.
MAX_BATCH_OPTIONS=3

# PROBE_CAP_HIT: set true by run_candidate_round() the moment MAX_PROBE_INVOCATIONS is reached
# (it already prints the explicit cap-reached line at that point). mode_next_batch()'s
# multi-option loop below checks this after every option to stop issuing further options once
# the shared probe budget is exhausted, rather than silently truncating the option list.
PROBE_CAP_HIT=false

# REPORTED_PAIRS (D5): a script-level, INVOCATION-scoped associative set of every file_scope-
# colliding pair ("${lower}:${higher}" keys) already reported via propose_edge_for_pair() --
# "invocation" meaning this one run of orchestrate-suggest-next-batch.sh, never just one
# suggest_from_candidates() call. This is deliberately a plain script global rather than a
# `local` declared inside suggest_from_candidates(): mode_next_batch()'s Phase 2 multi-option
# loop (below) calls suggest_from_candidates() once per criterion within the SAME script
# invocation, and a pair spanning two different criteria' candidate sets (e.g. a
# territory-colliding pair that also appears inside the "width" option's wider pool) must still
# be reported only once across every option -- never once per option. Reset is never needed:
# each script invocation starts with this empty and exits before any second invocation could
# reuse the process.
declare -A REPORTED_PAIRS=()

# ── probe_candidate_set(): the ONE shared admission-probe function. Both Mode A and Mode B call
#    this and only this to establish admissibility — never a local re-derivation. Populates the
#    caller-visible variable named by $1 with the raw NDJSON verdicts (one line per candidate,
#    orchestrate-batch-admit-v7 schema) and returns the real script's own exit status, EXCEPT
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

# ── select_candidates_for_criterion(): the ONE parameterized implementation of each of the
#    three selection-doctrine passes from
#    context/patterns/batch-orchestration-guardrails.md's "Batching Is the Default" — shared
#    file territory, topic cohesion, graph width — applied to an already-READY pool (see
#    build_ready_pool() above). select_candidates() below composes all three (chaining each
#    pass's own assigned members forward as the next pass's $exclude_csv, exactly reproducing
#    its pre-refactor behavior) to build ONE combined candidate list; Phase 2's multi-option
#    Mode A render (mode_next_batch()) calls this directly, once per criterion, with
#    exclude_csv="" each time -- so each criterion stands on its own as a complete, independent
#    selection over the WHOLE ready pool, never a remainder-after-other-passes slice. No pass's
#    algorithm is implemented twice.
#
#    $1 criterion: territory|topic|width. $2 exclude_csv: comma-separated task numbers to omit
#    from this pass's own output (used only by select_candidates()'s internal chaining; the
#    standalone per-option caller always passes ""). Remaining args: the ready pool.
#
#    territory: territory-mandatory groups (exact file_scope string-set intersection, grouped
#    by transitive closure -- a SELECTION pre-filter only, never the directory-prefix overlap
#    predicate that actually establishes admissibility; that always comes from
#    probe_candidate_set() / orchestrate-batch-admit.sh), size > 1, roots visited ascending,
#    members sorted ascending within each group.
#    topic: topic-cohesion groups (by the `topic` field), size > 1, same ordering convention.
#    width: the plain ready pool in ascending order, no grouping at all -- "graph width" taken
#    at face value, since (per the ORIGINAL Pass 3 comment this preserves) two ready tasks can
#    never be connected by a dependencies[] edge to each other within a ready-only pool (a
#    predecessor would have to be "completed" -- terminal, hence excluded from readiness), so
#    the width-vs-chain nuance of the doctrine's third criterion never actually applies here.
#
#    Every branch truncates its OWN output to MAX_TASKS before returning. This is exactly what
#    a standalone per-option caller wants; it is also safe for select_candidates()'s composed
#    use, because the composed list only ever draws its own first MAX_TASKS entries overall, a
#    span that can never run past the first MAX_TASKS entries of any one pass's own (already
#    MAX_TASKS-truncated) output. ─────────────────────────────────────────────────────────────
select_candidates_for_criterion() {
  local criterion="$1"; shift
  local exclude_csv="$1"; shift
  local -a ready=("$@")
  [ "${#ready[@]}" -eq 0 ] && return 0

  declare -A excluded=()
  if [ -n "$exclude_csv" ]; then
    local -a __excl_arr=()
    IFS=',' read -ra __excl_arr <<< "$exclude_csv"
    local __e
    for __e in "${__excl_arr[@]}"; do
      [ -n "$__e" ] && excluded[$__e]=1
    done
  fi

  if [ "$criterion" = "width" ]; then
    local t count=0
    for t in "${ready[@]}"; do
      [ -n "${excluded[$t]:-}" ] && continue
      [ "$count" -ge "$MAX_TASKS" ] && break
      echo "$t"
      count=$((count + 1))
    done
    return 0
  fi

  if [ "$criterion" != "territory" ] && [ "$criterion" != "topic" ]; then
    echo "ERROR: orchestrate-suggest-next-batch.sh: select_candidates_for_criterion: unknown criterion '$criterion' (expected territory|topic|width)." >&2
    return 1
  fi

  local ready_csv
  ready_csv=$(printf '%s\n' "${ready[@]}" | jq -R -s -c 'split("\n") | map(select(length>0) | tonumber)')

  # NOTE: the record separator here is 0x1F (ASCII unit separator), NOT @tsv's tab -- `read`
  # treats tab (like space and newline) as an IFS-WHITESPACE character, which COLLAPSES
  # consecutive delimiters and silently swallows an empty middle field (bash's documented
  # behavior for an IFS whitespace character, confirmed: `IFS=$'\t' read -r a b c <<< $'x\t\tz'`
  # yields a="x" b="z" c="" -- b absorbs z, the empty middle field vanishes). A task with an
  # empty topic (common: `topic` is frequently null) would otherwise misalign topic_of/fs_of
  # whenever it sits between two populated fields. 0x1F is never whitespace to `read`, so an
  # empty field is preserved exactly like any non-whitespace IFS character (e.g. comma) would.
  declare -A fs_of=() topic_of=()
  local t topic fs
  while IFS=$'\x1f' read -r t topic fs; do
    [ -z "$t" ] && continue
    topic_of[$t]="$topic"
    fs_of[$t]="$fs"
  done < <(jq -r --argjson ready "$ready_csv" '
    .active_projects[]
    | select(([.project_number] - $ready | length) == 0)
    | [.project_number, (.topic // ""), ((.file_scope // []) | join(","))]
    | map(tostring)
    | join("\u001f")
  ' "$STATE_FILE")

  if [ "$criterion" = "territory" ]; then
    declare -A parent=()
    local i
    for i in "${ready[@]}"; do parent[$i]="$i"; done
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

    local j found a_entry
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
    for r in $(printf '%s\n' "${!group_members[@]}" | sort -n); do
      local -a members=()
      read -ra members <<< "${group_members[$r]}"
      [ "${#members[@]}" -le 1 ] && continue
      local -a sorted_members=()
      while IFS= read -r m; do sorted_members+=("$m"); done < <(printf '%s\n' "${members[@]}" | sort -n)
      for t in "${sorted_members[@]}"; do
        [ -n "${excluded[$t]:-}" ] && continue
        ordered+=("$t")
      done
    done

    local count=0
    for t in "${ordered[@]}"; do
      [ "$count" -ge "$MAX_TASKS" ] && break
      echo "$t"
      count=$((count + 1))
    done
    return 0
  fi

  # criterion == topic
  declare -A topic_members=()
  for t in "${ready[@]}"; do
    [ -n "${excluded[$t]:-}" ] && continue
    topic="${topic_of[$t]:-}"
    [ -z "$topic" ] && continue
    topic_members[$topic]="${topic_members[$topic]:-}${topic_members[$topic]:+ }$t"
  done
  local -a ordered=()
  for topic in "${!topic_members[@]}"; do
    local -a tmembers=()
    read -ra tmembers <<< "${topic_members[$topic]}"
    [ "${#tmembers[@]}" -le 1 ] && continue
    local -a sorted_tmembers=()
    while IFS= read -r m; do sorted_tmembers+=("$m"); done < <(printf '%s\n' "${tmembers[@]}" | sort -n)
    for t in "${sorted_tmembers[@]}"; do
      ordered+=("$t")
    done
  done

  local count=0
  for t in "${ordered[@]}"; do
    [ "$count" -ge "$MAX_TASKS" ] && break
    echo "$t"
    count=$((count + 1))
  done
}

# ── select_candidates(): composes select_candidates_for_criterion()'s three passes -- shared
#    file territory > topic cohesion > graph width -- into ONE combined, ordered candidate
#    list, territory-mandatory members ordered first so a trim never splits a mandatory group
#    off the end. Byte-for-byte the same selection this function produced before the Phase 2
#    refactor: each pass's own newly-assigned members are chained forward as the next pass's
#    exclude_csv, exactly reproducing the original "remaining, unassigned ready tasks only"
#    behavior pass 2 and pass 3 depended on. Used by suggest_from_pool() (both Mode A's
#    single-selection callers and Mode B, which keeps this single-pool behavior
#    unchanged -- see the plan's Non-Goals). ─────────────────────────────────────────────────────
select_candidates() {
  local -a ready=("$@")
  [ "${#ready[@]}" -eq 0 ] && return 0

  local -a ordered=()
  declare -A seen=()
  local t exclude_csv

  while IFS= read -r t; do
    [ -z "$t" ] && continue
    if [ -z "${seen[$t]:-}" ]; then
      ordered+=("$t")
      seen[$t]=1
    fi
  done < <(select_candidates_for_criterion territory "" "${ready[@]}")

  exclude_csv="$(printf '%s\n' "${!seen[@]}" | paste -sd, -)"
  while IFS= read -r t; do
    [ -z "$t" ] && continue
    if [ -z "${seen[$t]:-}" ]; then
      ordered+=("$t")
      seen[$t]=1
    fi
  done < <(select_candidates_for_criterion topic "$exclude_csv" "${ready[@]}")

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
#    token at all. "not_started" is NO LONGER that case: update-task-status.sh now carries a
#    dedicated no-op-only `preflight:edge_only` pair for exactly this status (added to close the
#    admission gap this function's header used to describe as genuine -- see that script's own
#    `--depends-on-add` header-comment section for the full rationale). The fallback branch
#    below still exists and still fires for the TERMINAL statuses (which never reach here because
#    they are excluded from readiness) and for any future status this vocabulary has not yet
#    mapped -- it is a general safety net, not a "not_started" placeholder any more. ─────────────
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
    # edge_only is the no-op-only, edge-only vehicle update-task-status.sh added specifically
    # because no real transition ever resolves to "not_started" -- it is never a settable
    # lifecycle target, only the --depends-on-add carrier for a pre-lifecycle task.
    not_started)  echo "preflight edge_only" ;;
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
#    above), falls back to propose-only for this pair LOUDLY -- never silently dropping it from
#    the suggestion. "not_started" is no longer the case that forces this fallback: it now has
#    its own resolving token (`preflight edge_only`) via resolve_noop_token() above, so only a
#    genuinely unmapped status (or a write refused for some other reason, e.g. a cycle) falls
#    back here. Returns 0 only when the write happened AND the re-probe confirmed both admit; 1
#    otherwise (propose-only). ─────────────────────────────────────────────────────────────────
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

# ── run_candidate_round(): one probe + edge-proposing-pass + admit/defer bucketing round --
#    the single shared body suggest_from_candidates()'s main shrink-and-retry loop AND its
#    Defect-1 conflict-free-subset second pass (below) both call, so the edge-proposing logic
#    (and D5's reported-pairs dedup) exists in exactly one place rather than twice. Reads/writes
#    the script-global associative set REPORTED_PAIRS (declared once near
#    MAX_PROBE_INVOCATIONS above -- D5 needs this shared across every suggest_from_candidates()
#    call within one script invocation, including mode_next_batch()'s Phase 2 multi-option
#    loop, so a pair is never reported twice even when it surfaces inside two different
#    options' candidate sets), plus the CALLER's own `local` variables `ever_admitted`
#    (associative, task_number keys), `pairs_this_call` (associative, "${lower}:${higher}"
#    keys -- a PER-CALL subset of REPORTED_PAIRS, so one option's conflict-free-subset second
#    pass never pulls in a lower member reported by some OTHER option earlier in the same
#    script invocation) and `any_sequence_rendered`, by bash's ordinary dynamic variable
#    visibility across a call stack -- this function is only ever called from inside
#    suggest_from_candidates(), where all three of the latter are declared `local` before any
#    call site, and this function never redeclares any of them locally itself.
#
#    On a stable all-admit round (nothing deferred, no pair handled this round), leaves the
#    round's raw verdicts in the script-global ROUND_LAST_VERDICTS for the caller to render via
#    render_verdict_evidence() and returns 2 -- the caller renders the joint `/orchestrate` line
#    itself, since the exact wording differs between the main loop's primary suggestion and the
#    second pass's additive one. On a probe-invocation-cap hit, prints the existing explicit
#    cap-reached line itself (so both call sites render it identically) and returns 9 with the
#    outvar empty. On a hard admit-script failure, prints the existing ERROR line and exits 3
#    directly (as the pre-refactor inline body did). Otherwise (some non-pair defer happened,
#    or a pair was handled but candidates remain) writes this round's admitted-but-not-yet-
#    stable set to the caller-named outvar $1 (newline-separated, possibly empty) and returns
#    0 -- the caller shrinks to this set and probes again, exactly as the pre-refactor inline
#    loop body did. ───────────────────────────────────────────────────────────────────────────
run_candidate_round() {
  local __next_outvar="$1"; shift
  local -a __round_candidates=("$@")
  local verdicts phase_map probe_rc
  phase_map="$(derive_phase_map "${__round_candidates[@]}")"
  probe_candidate_set verdicts "$phase_map" "${__round_candidates[@]}"
  probe_rc=$?
  if [ "$probe_rc" -eq 9 ]; then
    echo "Alternatives/batch search stopped: the probe-invocation cap (MAX_PROBE_INVOCATIONS=${MAX_PROBE_INVOCATIONS}) was reached before this candidate set stabilized. Re-run the suggester to continue from a fresh cap budget."
    PROBE_CAP_HIT=true
    printf -v "$__next_outvar" '%s' ""
    return 9
  elif [ "$probe_rc" -ne 0 ]; then
    echo "ERROR: orchestrate-suggest-next-batch.sh: orchestrate-batch-admit.sh failed while probing candidate set [${__round_candidates[*]}]." >&2
    exit 3
  fi

  # Edge-proposing pass: handle every in_batch file_scope_collision pair in this round's
  # verdicts BEFORE the plain admit/defer bucketing below. The reported_pairs check makes this
  # loop safe to run again from the second pass over a subset that may re-surface the same
  # pair's lower member (D5: a pair is never reported twice in one invocation).
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
    if [ -n "${REPORTED_PAIRS["${lower}:${higher}"]:-}" ]; then
      continue
    fi
    propose_edge_for_pair "$lower" "$higher"
    any_sequence_rendered=true
    REPORTED_PAIRS["${lower}:${higher}"]=1
    # pairs_this_call (CALLER's own `local`, distinct from the script-global REPORTED_PAIRS
    # above): tracks only the pairs reported during THIS suggest_from_candidates() call, so its
    # own conflict-free-subset second pass below never pulls in a lower member from some OTHER
    # option's candidate set merely because that unrelated pair happened to be reported earlier
    # in this same script invocation.
    pairs_this_call["${lower}:${higher}"]=1
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
    ROUND_LAST_VERDICTS="$verdicts"
    printf -v "$__next_outvar" '%s' ""
    return 2
  fi

  for tn in "${next_remaining[@]:-}"; do
    [ -n "$tn" ] && ever_admitted["$tn"]=1
  done
  printf -v "$__next_outvar" '%s' "$(printf '%s\n' "${next_remaining[@]:-}")"
  return 0
}

# ── suggest_from_candidates(): the ONE shared probe+render engine, over an ALREADY-SELECTED
#    candidate list (the caller has already applied whatever selection doctrine it wants --
#    select_candidates()'s composed three-pass doctrine for suggest_from_pool() below, or
#    select_candidates_for_criterion()'s single-criterion selection for mode_next_batch()'s
#    Phase 2 multi-option loop). Probes the result through run_candidate_round() -- handling
#    any in_batch file_scope_collision pair via propose_edge_for_pair() before falling back to
#    the plain shrink-and-retry for every other defer reason -- until either a stable all-admit
#    set is found, the pool is exhausted, or MAX_PROBE_INVOCATIONS is reached (reserved return
#    code 9, rendered explicitly, never a silent truncation).
#
#    Defect 1 fix: a colliding pair handled by the main loop is now ADDITIVE information
#    alongside a probe-verified joint batch, never a replacement for one. When the main loop's
#    shrink-and-retry exhausts the pool (every remaining candidate consumed into a reported
#    pair, nothing left to probe as a stable set) WITHOUT ever reaching a stable all-admit
#    round, a conflict-free-subset second pass probes the union of (a) every member admitted in
#    ANY main-loop round and (b) the LOWER member of each reported pair (per Decision 1's
#    rendering convention) through the same run_candidate_round() -- never a local overlap
#    comparison -- so the ordered-sequence suggestion(s) already rendered are joined by a real,
#    probe-verified joint batch whenever one is admissible. Returns 0 when at least one sequence
#    line and/or a joint batch line was rendered; 1 only when nothing at all could be suggested
#    from this candidate list. ─────────────────────────────────────────────────────────────────
suggest_from_candidates() {
  local -a candidates=("$@")
  [ "${#candidates[@]}" -eq 0 ] && return 1

  local any_sequence_rendered=false
  declare -A ever_admitted=()
  declare -A pairs_this_call=()
  local round_rc next_list
  local -a remaining=("${candidates[@]}") next_arr=()

  while [ "${#remaining[@]}" -gt 0 ]; do
    run_candidate_round next_list "${remaining[@]}"
    round_rc=$?
    if [ "$round_rc" -eq 2 ]; then
      local IFS=', '
      echo "/orchestrate ${remaining[*]}"
      unset IFS
      render_verdict_evidence "$ROUND_LAST_VERDICTS"
      echo "  (verified admissible when suggested, against the current queue/registry;"
      echo "   re-run this suggester, or re-dispatch and let the real admission check at"
      echo "   dispatch time, to re-verify before acting)"
      return 0
    elif [ "$round_rc" -eq 9 ]; then
      return 1
    fi
    next_arr=()
    while IFS= read -r t; do
      [ -n "$t" ] && next_arr+=("$t")
    done <<< "$next_list"
    remaining=("${next_arr[@]}")
  done

  # Defect-1 conflict-free-subset second pass (see function header above): only reached when
  # the main loop above exhausted the pool without rendering a stable joint batch.
  if [ "$any_sequence_rendered" = true ]; then
    local -a lowers=()
    local key
    if [ "${#pairs_this_call[@]}" -gt 0 ]; then
      for key in "${!pairs_this_call[@]}"; do
        lowers+=("${key%%:*}")
      done
    fi
    local -a admitted_members=()
    if [ "${#ever_admitted[@]}" -gt 0 ]; then
      for key in "${!ever_admitted[@]}"; do
        admitted_members+=("$key")
      done
    fi
    local -a subset=()
    if [ "${#admitted_members[@]}" -gt 0 ] || [ "${#lowers[@]}" -gt 0 ]; then
      while IFS= read -r t; do
        [ -n "$t" ] && subset+=("$t")
      done < <(printf '%s\n' "${admitted_members[@]:-}" "${lowers[@]:-}" | sort -n -u)
    fi

    while [ "${#subset[@]}" -gt 0 ]; do
      run_candidate_round next_list "${subset[@]}"
      round_rc=$?
      if [ "$round_rc" -eq 2 ]; then
        local IFS=', '
        echo "/orchestrate ${subset[*]}"
        unset IFS
        render_verdict_evidence "$ROUND_LAST_VERDICTS"
        echo "  (additive to the ordered sequence(s) above -- a colliding pair is never a"
        echo "   replacement for a joint batch. Verified admissible when suggested, against"
        echo "   the current queue/registry; re-run this suggester, or re-dispatch and let"
        echo "   the real admission check at dispatch time, to re-verify before acting)"
        return 0
      elif [ "$round_rc" -eq 9 ]; then
        break
      fi
      next_arr=()
      while IFS= read -r t; do
        [ -n "$t" ] && next_arr+=("$t")
      done <<< "$next_list"
      subset=("${next_arr[@]}")
    done
  fi

  [ "$any_sequence_rendered" = true ] && return 0
  return 1
}

# ── suggest_from_pool(): thin wrapper preserving the pre-Phase-2 entry point -- applies
#    select_candidates()'s composed three-pass doctrine to the given pool, then hands the
#    result to suggest_from_candidates(). Used by mode_alternatives() (Mode B keeps its
#    existing single-pool behavior unchanged, per the plan's Non-Goals) and by this script's
#    own test suite's expectations for the single-selection entry point. ───────────────────────
suggest_from_pool() {
  local -a pool=("$@")
  [ "${#pool[@]}" -eq 0 ] && return 1

  local -a candidates=()
  local t
  while IFS= read -r t; do
    [ -n "$t" ] && candidates+=("$t")
  done < <(select_candidates "${pool[@]}")
  [ "${#candidates[@]}" -eq 0 ] && return 1

  suggest_from_candidates "${candidates[@]}"
}

# ── mode_next_batch(): Mode A. Pool = the full ready pool. Read-only: specs/state.json is
#    never written in this default (non-`--write-edges`) form.
#
#    Defect 2 fix: renders up to MAX_BATCH_OPTIONS distinct, labelled, probe-verified batch
#    options -- one per selection-doctrine criterion (shared territory, topic cohesion, graph
#    width), each independently selected via select_candidates_for_criterion() (criterion-only,
#    no cross-criterion exclusion -- see that function's header) and independently probed via
#    suggest_from_candidates(). A criterion whose own candidate pool is empty is skipped; an
#    option whose candidate SET duplicates an already-rendered option's set is skipped rather
#    than printed twice (D1). PROBE_INVOCATION_COUNT/MAX_PROBE_INVOCATIONS stay the one shared
#    counter and cap across all three options (D2); reaching the cap mid-render prints the
#    existing explicit cap-reached line (from inside run_candidate_round) plus one additional
#    line stating the option list was cut short by the cap, retains whatever already rendered,
#    and stops -- never a silent truncation of the option list. ───────────────────────────────
mode_next_batch() {
  local -a ready=()
  local t
  while IFS= read -r t; do
    [ -n "$t" ] && ready+=("$t")
  done < <(build_ready_pool)

  if [ "${#ready[@]}" -eq 0 ]; then
    echo "No suggestible batch: the ready-candidate pool is empty (no non-terminal,"
    echo "non-hold/implementing/blocked/partial task with every dependency completed)."
    exit 0
  fi

  declare -A criterion_label=(
    [territory]="shared territory -- a file_scope territory-mandatory group"
    [topic]="topic cohesion -- a shared-topic group"
    [width]="graph width -- the widest independent set in the ready pool"
  )
  local -a criteria=(territory topic width)
  local -a rendered_set_csvs=()
  local criterion options_rendered=0 any_option_rendered=false
  local -a crit_candidates=()

  for criterion in "${criteria[@]}"; do
    [ "$options_rendered" -ge "$MAX_BATCH_OPTIONS" ] && break

    crit_candidates=()
    while IFS= read -r t; do
      [ -n "$t" ] && crit_candidates+=("$t")
    done < <(select_candidates_for_criterion "$criterion" "" "${ready[@]}")
    [ "${#crit_candidates[@]}" -eq 0 ] && continue

    local csv dup=false seen_csv
    csv="$(printf '%s\n' "${crit_candidates[@]}" | sort -n -u | paste -sd, -)"
    for seen_csv in "${rendered_set_csvs[@]:-}"; do
      [ "$seen_csv" = "$csv" ] && dup=true
    done
    if [ "$dup" = true ]; then
      continue
    fi

    echo ""
    echo "Option $((options_rendered + 1)) -- ${criterion_label[$criterion]}:"
    if suggest_from_candidates "${crit_candidates[@]}"; then
      any_option_rendered=true
      rendered_set_csvs+=("$csv")
      options_rendered=$((options_rendered + 1))
    fi

    if [ "$PROBE_CAP_HIT" = true ]; then
      echo ""
      echo "Batch-option search stopped: the shared probe-invocation cap was reached while"
      echo "rendering option $((options_rendered)); the option list is cut short by the cap"
      echo "rather than silently truncated. ${options_rendered} option(s) above were rendered"
      echo "before the cap was reached. Re-run the suggester to continue from a fresh cap"
      echo "budget."
      break
    fi
  done

  if [ "$any_option_rendered" = false ]; then
    echo "No suggestible batch: every candidate drawn from a ready pool of ${#ready[@]} task(s)"
    echo "deferred this round, for every selection-doctrine criterion tried; re-run after the"
    echo "deferring condition(s) clear."
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
