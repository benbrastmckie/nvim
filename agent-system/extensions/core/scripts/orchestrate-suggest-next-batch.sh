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

# Phase 1 ships the CLI skeleton only; Mode A's and Mode B's own bodies (readiness pool,
# phase-map derivation, selection doctrine, edge-proposing step, alternatives search, and
# rendering) land in later phases of this task's plan.
case "$MODE" in
  next-batch)
    echo "ERROR: orchestrate-suggest-next-batch.sh: --next-batch is not yet implemented (skeleton phase)." >&2
    exit 3
    ;;
  alternatives)
    echo "ERROR: orchestrate-suggest-next-batch.sh: --alternatives is not yet implemented (skeleton phase)." >&2
    exit 3
    ;;
esac
