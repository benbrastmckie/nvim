#!/usr/bin/env bash
# orchestrate-cycle-plan.sh — Per-cycle dispatch-plan composer for multi-task /orchestrate.
#
# Purpose: absorbs skill-orchestrate/SKILL.md's Stage MT-3 (status refresh, all-terminal check,
# eligibility, classification, admission) and Stage MT-4's PRE-dispatch half (per-task force-phase
# consumption, task-directory creation, lock acquire, dispatch_seq mint, preflight status write,
# and the orchestrate-build-dispatch.sh call) into one script the thin lead calls once per cycle.
# Everything from "After all Agent tool calls complete" onward (per-task postflight, commits, the
# handoff/`.return-meta.json` read, and cycle_modified_files accumulation) is NOT this script's
# job — that is a separate, not-yet-built postflight composer. This script only ever DECIDES and
# PREPARES a dispatch plan; it never invokes the Agent or Skill tool itself.
#
# Two-function structure (mandated design, see the originating plan's Phase 1): a single decision
# pass computes the WHOLE cycle's plan with no live side effects beyond a read-only lock PROBE;
# a second, live-only pass applies side effects (directory creation, real lock acquire,
# dispatch_seq mint, preflight write, the orchestrate-build-dispatch.sh call) and enriches the
# decision's dispatch rows with real dispatch_file/model values. --dry-run runs ONLY the first
# pass and renders its output directly — there is exactly one computation of every admission
# verdict, never two independently-maintained renderings.
#
# mt_state_file field list this script reads and/or writes (byte-identical names to
# skill-orchestrate/SKILL.md's Stage MT-1 initialization list — Stage MT-1 itself is UNCHANGED by
# this script and remains the field list's canonical initializer for the live path; this script
# additionally self-initializes any field found missing, via non-destructive `//=`, so it also
# runs standalone against a freshly-touched or nonexistent file, e.g. for --dry-run or tests):
#   session_id, task_numbers, cycle_counts, max_cycles_per_task, failed_tasks, completed_tasks,
#   current_statuses, task_dirs, research_agents, implement_agents, descriptions, infra_failures,
#   dispatch_start_ts, dispatch_seq_counter, dispatch_seq, deferred_self_modifying,
#   deferred_deploy_checkpoint, deployed_critical_paths, consecutive_no_dispatch_cycles,
#   verify_deploy_baseline_notices, defer_ledger, detected_defects, forward_progress_violated,
#   idle_overlap_ledger, cycle_modified_files. PLUS ONE genuinely NEW field this script introduces
#   (per-task force_phases consumption, a feature gap no prior stage closed):
#   force_phases_remaining (map task_number(string) -> ordered array of not-yet-dispatched forced
#   phases, canonical research/plan/implement order, popped as each forced phase is dispatched).
# Stage MT-5 (multi-task postflight/report, untouched by this task) still reads every one of the
# pre-existing fields above; this script never renames or drops one.
#
# Decision 1 (originating plan's Phase 1) — per-task cumulative cycle budget: the batch-wide
# scalars `max_cycles`/`cycle_count` are REPLACED by `max_cycles_per_task`/`cycle_counts`, both
# maps keyed by task_number(string). `cycle_counts[t]` is a LIVE, in-memory-this-invocation mirror
# of a DURABLE per-task counter whose real home is the pre-existing, gitignored, reap-exempt
# `${TASK_DIR}/.orchestrator-loop-guard` file's own `cycle_count` field (read/written via
# `orchestrate-loop-guard-init.sh --seed`/`--flush` — see that script's header). This is
# deliberate: `mt_state_file` itself is minted fresh every `/orchestrate` invocation (a new
# `session_id` each time), so a field living ONLY there could never be cumulative across
# invocations — exactly the trap `test-session-runtime-files.sh` Case 3 exists to catch for the
# single-task engine's own `cycle_count`. Routing a single task through this batch path must not
# become a silent way to bypass that same budget. `max_cycles_per_task[t]` is instead re-derived
# FRESH every invocation from the CURRENT run's `--hard` flag (13 under hard mode, 5 otherwise —
# ported verbatim from single-task Stage 2), matching single-task's own non-persisted MAX_CYCLES
# computation; it is never seeded from the durable file and is always overwritten, never `//=`.
#
# Bare-vs-suffixed session_id invariant (load-bearing; get this wrong and the lock layer, the
# session registry, and a dispatched agent's own heartbeat desync from each other):
#   - BARE `$session_id` (the `--session` value passed to THIS script): task-lock.sh acquire/
#     check/heartbeat, orchestrate-batch-admit.sh --session-id, and the IMPLEMENT dispatch's own
#     --session/context.session_id (general-implementation-agent's per-phase heartbeat presents
#     this exact value against holder.json).
#   - SUFFIXED `${session_id}_${task_num}`: skill_preflight_update's session_id argument, and the
#     RESEARCH/PLAN dispatches' --session/context.session_id.
#
# --dry-run design (absorbs the retired orchestrate-dry-run-report.sh — see that script's own
# retirement in this task): runs the IDENTICAL read-only decision pass (admission, classification,
# forced phases, a read-only lock PROBE via `task-lock.sh check` — never `acquire`) and prints the
# SAME plan JSON the live path would emit, with dispatch_file/model forced to null on every
# dispatch row (nothing was actually built), on stdout — plus a compact human table on STDERR,
# rendered by reading back that SAME already-printed JSON object and nothing else (no second
# computation, no independent formatting of any decision). stdout stays pure, single-line JSON in
# BOTH modes, so a machine caller never needs to distinguish dry-run from live output shape; the
# table exists purely for a human running `/orchestrate --dry-run` at a terminal, where stderr
# renders inline with stdout. Table sections, in order: `-- Dispatch --` (task, phase, agent),
# `-- Deferred --` (task, reason), `-- Blocked --` (task, reason), `-- Stop --` (reason: message,
# or a none-line). Mutates nothing: no mt_state_file write, no directory creation, no lock
# acquire, no dispatch_seq mint, no preflight status write, no orchestrate-build-dispatch.sh call,
# no deploy-headless.sh/verify-deploy.sh call. Every deferred row's `reason` is the admission or
# triage verdict's OWN string, relayed verbatim — never reconstructed. This file never asserts, in
# its own words, that self-modifying work must be isolated to a solo invocation — the two retired
# phrases making that claim are absent here by construction (grep-enforced by this task's own test
# suite) and must stay absent from any future edit to this header or its code.
#
# Inter-cycle redeploy checkpoint — timing note (a deliberate re-siting, not a behavioral change):
# the original Stage MT-3 step 7 ran AFTER a cycle's own dispatch + per-task postflight commits,
# consulting THAT SAME cycle's `cycle_modified_files`. This script runs strictly BEFORE the Agent
# tool dispatches of ITS OWN cycle (it only decides and prepares them), so it cannot consult a
# same-cycle `cycle_modified_files` that does not exist yet. This script therefore runs the
# checkpoint at the START of each invocation instead, consuming `cycle_modified_files` accumulated
# by the PRIOR cycle's (not-yet-built) postflight composer, then resets the field to `[]` for the
# new cycle. Read the field's own doc comment at its `//=` initialization site below for the exact
# mechanism. The checkpoint's own overlap/idempotence/fire/three-way-outcome logic is otherwise
# byte-for-byte the ported Stage MT-3 step 7 algorithm — see
# context/patterns/batch-orchestration-guardrails.md's "### The Inter-Cycle Redeploy Checkpoint"
# subsection for the full narrative (referenced here, not restated).
#
# MAX_CYCLES_MT budget guard — also re-sited to the TOP of this script (mirroring the original
# `while cycle_count < MAX_CYCLES_MT` loop CONDITION, which is checked before a loop body runs at
# all, not after): when the guard trips, this script does NO other work this invocation (no status
# refresh, no eligibility, no admission) and returns `stop` immediately.
#
# Usage:
#   orchestrate-cycle-plan.sh --session SID --state-file F [--invocation-count N]
#     [--force-phases "research,plan,implement"] [--clean] [--lit] [--hard] [--fast]
#     [--model M] [--allow-self-modifying] [--allow-scope-collision] [--continue-budget]
#     [--dry-run] <task_number> [<task_number> ...]
#
# `--state-file F` is the CANONICAL specs/state.json (or a fixture copy in tests) — the same
# STATE_FILE every sibling script (orchestrate-batch-admit.sh, orchestrate-triage-classify.sh)
# reads. This script separately derives its OWN per-invocation bookkeeping file at the fixed path
# `<dirname F>/.orchestrator-multi-state-${session_id}.json` (mirroring Stage MT-1's
# `specs/.orchestrator-multi-state-${session_id}.json` naming exactly when F is specs/state.json).
# `--team`/`--team-size` are REJECTED as unrecognized flags (usage error, exit 2) — team mode is
# withdrawn; no `team` key is ever emitted on a dispatch row.
#
# Output: a single line of compact JSON on stdout:
#   {cycle: int, dispatch: [{task, phase, agent, model, dispatch_file, force}],
#    deferred: [{task, reason}], blocked: [{task, reason}], stop: null | {reason, message}}
# `model`/`dispatch_file` are `null` on every dispatch row in --dry-run mode (nothing was built),
# and are the real resolved values in the live path. `force` (Phase 7 addition of the task that
# built orchestrate-cycle-postflight.sh) is `true` only when this row's phase was popped off that
# task's own `force_phases_remaining` queue THIS cycle -- the only point in the pipeline where
# that fact is still observable, since the queue is popped before this row is built. Consumed by
# Stage MT-4's postflight call as `--force-invoked`, mirroring single-task Stage 5's own
# `force_invoked` (A2) semantics for the monotonic-max status clamp and the forced-dispatch
# artifact-round advance.
#
# Exit codes:
#   0 - a plan was printed on stdout, regardless of its dispatch/deferred/blocked/stop contents
#       (verdicts are data, not errors — mirrors orchestrate-batch-admit.sh's and
#       orchestrate-triage-classify.sh's convention).
#   2 - usage error (missing/invalid flags, zero task_number arguments, a non-integer
#       task_number, an unrecognized flag including --team/--team-size, an invalid
#       --force-phases token) or environment error (jq missing, --state-file unreadable).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
if ! . "${SCRIPT_DIR}/lib/file-scope-overlap.sh" 2>/dev/null; then
  echo "ERROR: orchestrate-cycle-plan.sh: could not source ${SCRIPT_DIR}/lib/file-scope-overlap.sh." >&2
  exit 2
fi

MAX_INFRA_FAILURES=3

usage() {
  cat <<'USAGE'
Usage: orchestrate-cycle-plan.sh --session SID --state-file F [--invocation-count N]
         [--force-phases "research,plan,implement"] [--clean] [--lit] [--hard] [--fast]
         [--model M] [--allow-self-modifying] [--allow-scope-collision] [--continue-budget]
         [--dry-run] <task_number> [<task_number> ...]
USAGE
}

# ─── Flag parsing ──────────────────────────────────────────────────────────────────────────────
session_id=""
state_file_arg=""
invocation_count_override=""
force_phases_arg=""
clean_flag="false"
lit_flag="false"
hard_mode="false"
effort_flag=""
model_flag=""
allow_self_modifying="false"
allow_scope_collision="false"
continue_budget="false"
dry_run="false"
task_args=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --session) session_id="${2:-}"; shift 2 ;;
    --state-file) state_file_arg="${2:-}"; shift 2 ;;
    --invocation-count) invocation_count_override="${2:-}"; shift 2 ;;
    --force-phases) force_phases_arg="${2:-}"; shift 2 ;;
    --clean) clean_flag="true"; shift ;;
    --lit) lit_flag="true"; shift ;;
    --hard) hard_mode="true"; effort_flag="hard"; shift ;;
    --fast) effort_flag="fast"; shift ;;
    --model) model_flag="${2:-}"; shift 2 ;;
    --allow-self-modifying) allow_self_modifying="true"; shift ;;
    --allow-scope-collision) allow_scope_collision="true"; shift ;;
    --continue-budget) continue_budget="true"; shift ;;
    --dry-run) dry_run="true"; shift ;;
    --team|--team-size|--team=*|--team-size=*)
      echo "ERROR: orchestrate-cycle-plan.sh: --team/--team-size are withdrawn — team mode is deleted." >&2
      exit 2
      ;;
    --help|-h) usage; exit 0 ;;
    --*)
      echo "ERROR: orchestrate-cycle-plan.sh: unrecognized flag: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      task_args+=("$1")
      shift
      ;;
  esac
done

if [ -z "$session_id" ] || [ -z "$state_file_arg" ]; then
  echo "ERROR: orchestrate-cycle-plan.sh: --session and --state-file are required." >&2
  usage >&2
  exit 2
fi

if [ "${#task_args[@]}" -eq 0 ]; then
  echo "ERROR: orchestrate-cycle-plan.sh requires at least one <task_number> argument." >&2
  exit 2
fi

for arg in "${task_args[@]}"; do
  case "$arg" in
    ''|*[!0-9]*)
      echo "ERROR: orchestrate-cycle-plan.sh: '$arg' is not a non-negative integer task_number." >&2
      exit 2
      ;;
  esac
done

if [ -n "$invocation_count_override" ]; then
  case "$invocation_count_override" in
    ''|*[!0-9]*)
      echo "ERROR: orchestrate-cycle-plan.sh: '--invocation-count $invocation_count_override' is not a non-negative integer." >&2
      exit 2
      ;;
  esac
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: orchestrate-cycle-plan.sh: jq is not available." >&2
  exit 2
fi

case "$state_file_arg" in
  /*) STATE_FILE="$state_file_arg" ;;
  *) STATE_FILE="$PROJECT_ROOT/$state_file_arg" ;;
esac

if [ ! -f "$STATE_FILE" ]; then
  echo "ERROR: orchestrate-cycle-plan.sh: state file not found at $STATE_FILE." >&2
  exit 2
fi

# Single read of STATE_FILE's active_projects array, bound once and reused by every per-candidate
# lookup below (status refresh, dependency resolution) — mirrors orchestrate-batch-admit.sh's and
# orchestrate-triage-classify.sh's own `$all`-binding idiom: a lookup against an already-bound
# array, rather than a fresh `.active_projects[] | select(...)` per call, is both cheaper (one
# read instead of N) and outside lint-task-lookup-adoption.sh's narrow-full-record-lookup pattern
# (which is anchored on the literal ".active_projects[]" substring appearing per-call).
all_projects_json=$(jq -c '.active_projects // []' "$STATE_FILE" 2>/dev/null) || all_projects_json='[]'

# Companion read of the ARCHIVE, resolved as STATE_FILE's sibling exactly the way
# roadmap-integration.sh resolves it (`${STATE_PATH%state.json}archive/state.json`), so a fixture
# state.json in a temp dir with no sibling archive degrades to an empty array rather than erroring.
#
# WHY THIS EXISTS: /todo moves every terminal task out of `.active_projects` and into the archive.
# An active task whose `dependencies[]` names an archived predecessor therefore had that
# dependency resolve to NOTHING — and the eligibility loop below reads an unresolvable dependency
# as "predecessor still in flight", so the task silently became permanently un-dispatchable. It
# did not even surface in `blocked[]`; it vanished from the plan, leaving only the aggregate
# `no_eligible_stuck` stop message. A COMPLETED dependency read as an UNFINISHED one purely
# because it had been archived. Both lookup_project call sites (the candidate's own status
# refresh, and dependency resolution) need the archive to see a terminal predecessor at all.
#
# Status normalization: archive membership IS terminality — /todo only ever archives
# completed/abandoned/expanded tasks, plus `orphan_archived` recovery entries it writes for
# already-finished task directories that lost their state entry. The real status is preserved
# verbatim for completed/abandoned/expanded so the eligibility loop's completed-vs-failed
# predecessor distinction still works; any other archive-only status (`orphan_archived`) maps to
# "completed", since an orphan recovery is applied to finished work and there is no in-flight
# orphan to wait on.
archive_state_file="${STATE_FILE%state.json}archive/state.json"
if [ -f "$archive_state_file" ]; then
  archived_projects_json=$(jq -c '
    [ ((.completed_projects // [])[], ((.archived_projects // [])[])) |
      .status = (if (.status | IN("completed", "abandoned", "expanded")) then .status else "completed" end) ]
  ' "$archive_state_file" 2>/dev/null) || archived_projects_json='[]'
else
  archived_projects_json='[]'
fi

lookup_project() {
  # Usage: lookup_project <project_number> — echoes the matching record (or nothing).
  # Active projects win; the archive is consulted only when the number is absent from them, so a
  # task that somehow appears in both is still governed by its live entry.
  local found
  found=$(echo "$all_projects_json" | jq -c --argjson n "$1" '.[] | select(.project_number == $n)' 2>/dev/null | head -1)
  if [ -z "$found" ]; then
    found=$(echo "$archived_projects_json" | jq -c --argjson n "$1" '.[] | select(.project_number == $n)' 2>/dev/null | head -1)
  fi
  echo "$found"
}

# Force-phases: split + validate against the closed set, up front (a corrupted delegation
# context, not a user typo — mirrors single-task Stage 2b's posture exactly).
declare -a force_phases_list=()
if [ -n "$force_phases_arg" ]; then
  IFS=',' read -ra _fp_split <<< "$force_phases_arg"
  for _fp in "${_fp_split[@]}"; do
    case "$_fp" in
      research|plan|implement) force_phases_list+=("$_fp") ;;
      *)
        echo "ERROR: orchestrate-cycle-plan.sh: --force-phases contains an invalid entry '${_fp}' (expected one of: research, plan, implement)." >&2
        exit 2
        ;;
    esac
  done
fi
# Canonicalize to research < plan < implement order regardless of typed order.
canonical_force_phases_json="[]"
if [ "${#force_phases_list[@]}" -gt 0 ]; then
  canonical_force_phases_json=$(printf '%s\n' "${force_phases_list[@]}" | jq -R -s -c '
    split("\n") | map(select(length > 0)) | unique |
    (["research","plan","implement"]) as $order |
    [ $order[] as $o | select(. as $x | ($x as $_ | . as $y | [$y] | index($o))) ] as $noop | .
    ' 2>/dev/null) || canonical_force_phases_json="[]"
fi
# The jq above is intentionally simple: dedupe then reorder against the fixed canonical list.
canonical_force_phases_json=$(jq -n -c --argjson given "$(printf '%s\n' "${force_phases_list[@]:-}" | jq -R -s -c 'split("\n") | map(select(length > 0)) | unique')" '
  ["research","plan","implement"] | map(select(. as $o | $given | index($o) != null))
' 2>/dev/null) || canonical_force_phases_json="[]"

# ─── mt_state_file: derived path, in-memory representation, non-destructive defaults ───────────
mt_state_file="$(dirname "$STATE_FILE")/.orchestrator-multi-state-${session_id}.json"

mt_json="{}"
if [ "$dry_run" != "true" ] && [ -f "$mt_state_file" ]; then
  mt_json=$(jq -c '.' "$mt_state_file" 2>/dev/null) || mt_json="{}"
fi

# Decision 1: the batch-wide `default_max_cycles = ntasks * 5` (capped 25) budget is RETIRED.
# `.cycle_count` below is KEPT, unchanged, for its pre-existing NON-budget role only — a
# batch-wide invocation-sequence counter used for the output `cycle` field and ledger `cycle:`
# audit stamps (`idle_overlap_ledger`, `defer_ledger`, `verify_deploy_baseline_notices`); no
# decision in this script has ever branched on it as a budget, and none does after this change.
# The per-task budget mechanism lives entirely in the NEW `.cycle_counts`/`.max_cycles_per_task`
# maps below — see the header's Decision 1 note for the full rationale.
per_task_max_cycles=5
[ "$hard_mode" = "true" ] && per_task_max_cycles=13

mt_json=$(jq -c \
  --arg sid "$session_id" \
  --argjson tasks "$(printf '%s\n' "${task_args[@]}" | jq -R -s -c 'split("\n") | map(select(length > 0) | tonumber)')" \
  '
  .session_id //= $sid
  | .task_numbers //= $tasks
  | .cycle_counts //= {}
  | .max_cycles_per_task //= {}
  | .cycle_count //= 0
  | .failed_tasks //= []
  | .completed_tasks //= []
  | .current_statuses //= {}
  | .task_dirs //= {}
  | .research_agents //= {}
  | .implement_agents //= {}
  | .descriptions //= {}
  | .infra_failures //= {}
  | .dispatch_start_ts //= {}
  | .dispatch_seq_counter //= 0
  | .dispatch_seq //= {}
  | .deferred_self_modifying //= []
  | .deferred_deploy_checkpoint //= []
  | .deployed_critical_paths //= []
  | .consecutive_no_dispatch_cycles //= 0
  | .verify_deploy_baseline_notices //= []
  | .defer_ledger //= []
  | .detected_defects //= []
  | .forward_progress_violated //= false
  | .idle_overlap_ledger //= []
  | .cycle_modified_files //= []
  | .force_phases_remaining //= {}
  ' <<<"$mt_json")

mt_save() {
  [ "$dry_run" = "true" ] && return 0
  printf '%s\n' "$mt_json" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"
}
mt_get() {
  local argc="$#"
  local filter="${!argc}"
  echo "$mt_json" | jq -r "${@:1:$((argc-1))}" "$filter"
}
mt_get_json() {
  local argc="$#"
  local filter="${!argc}"
  echo "$mt_json" | jq -c "${@:1:$((argc-1))}" "$filter"
}
# mt_set [jq-flag-args...] <filter> — the LAST argument is always the jq filter; every argument
# before it is passed through to jq verbatim (--arg/--argjson pairs). Mirrors every other script
# in this codebase's `jq ... > tmp && mv tmp file` idiom, just against an in-memory variable
# instead of a file (mt_save is what actually persists it, and is a no-op under --dry-run).
mt_set() {
  local argc="$#"
  local filter="${!argc}"
  mt_json=$(echo "$mt_json" | jq -c "${@:1:$((argc-1))}" "$filter")
}

mt_save

# Re-derive every task's max_cycles FRESH this invocation from the CURRENT --hard flag (never
# `//=` — a task must not stay pinned to whichever effort mode first saw it; mirrors single-task
# Stage 2's own non-persisted MAX_CYCLES computation).
for _mt_t in "${task_args[@]}"; do
  mt_set --arg t "$_mt_t" --argjson m "$per_task_max_cycles" '.max_cycles_per_task[$t] = $m'
done
mt_save

cycle_count=$(mt_get '.cycle_count')

stop_reason=""
stop_message=""
declare -a out_dispatch_rows=()   # each element: a compact JSON object
declare -a out_deferred_rows=()
declare -a out_blocked_rows=()

emit_and_exit() {
  local cycle_val="$1"
  local dispatch_json deferred_json blocked_json stop_json
  if [ "${#out_dispatch_rows[@]}" -gt 0 ]; then
    dispatch_json="[$(IFS=,; echo "${out_dispatch_rows[*]}")]"
  else
    dispatch_json="[]"
  fi
  if [ "${#out_deferred_rows[@]}" -gt 0 ]; then
    deferred_json="[$(IFS=,; echo "${out_deferred_rows[*]}")]"
  else
    deferred_json="[]"
  fi
  if [ "${#out_blocked_rows[@]}" -gt 0 ]; then
    blocked_json="[$(IFS=,; echo "${out_blocked_rows[*]}")]"
  else
    blocked_json="[]"
  fi
  if [ -n "$stop_reason" ]; then
    stop_json=$(jq -n -c --arg r "$stop_reason" --arg m "$stop_message" '{reason: $r, message: $m}')
  else
    stop_json="null"
  fi
  local plan_json
  plan_json=$(jq -n -c --argjson cycle "$cycle_val" --argjson dispatch "$dispatch_json" \
    --argjson deferred "$deferred_json" --argjson blocked "$blocked_json" --argjson stop "$stop_json" \
    '{cycle: $cycle, dispatch: $dispatch, deferred: $deferred, blocked: $blocked, stop: $stop}')
  printf '%s\n' "$plan_json"
  # --dry-run human table (STDERR only — stdout stays pure, single-line JSON in both modes, per
  # this script's own Output contract). Rendered by reading back plan_json ALONE: no second
  # computation, no independent formatting of any decision (Phase 6's mandate) — every line below
  # is a `jq -r` projection of the exact object just printed to stdout.
  if [ "$dry_run" = "true" ]; then
    {
      echo "=== /orchestrate --dry-run cycle plan ==="
      echo ""
      echo "-- Dispatch --"
      if [ "$(echo "$plan_json" | jq '.dispatch | length')" -eq 0 ]; then
        echo "0 dispatched."
      else
        echo "$plan_json" | jq -r '.dispatch[] | "#\(.task)  phase=\(.phase)  agent=\(.agent)"'
      fi
      echo ""
      echo "-- Deferred --"
      if [ "$(echo "$plan_json" | jq '.deferred | length')" -eq 0 ]; then
        echo "0 deferred."
      else
        echo "$plan_json" | jq -r '.deferred[] | "#\(.task)  reason: \(.reason)"'
      fi
      echo ""
      echo "-- Blocked --"
      if [ "$(echo "$plan_json" | jq '.blocked | length')" -eq 0 ]; then
        echo "0 blocked."
      else
        echo "$plan_json" | jq -r '.blocked[] | "#\(.task)  reason: \(.reason)"'
      fi
      echo ""
      echo "-- Stop --"
      echo "$plan_json" | jq -r 'if .stop == null then "(none — this cycle would proceed)" else "\(.stop.reason): \(.stop.message)" end'
    } >&2
  fi
  exit 0
}

# ── (k, part 1) Budget guard — Decision 1: no longer a single whole-invocation check here. Each
# task's OWN cycle_counts[t]/max_cycles_per_task[t] is checked per candidate inside (c) Eligibility
# below (mirroring the pre-existing MAX_INFRA_FAILURES per-task pattern exactly); the WHOLE-batch
# `stop_reason="max_cycles"` outcome is derived by the "No-eligible circuit breaker" section further
# down, which fires it only when EVERY non-terminal task was excluded specifically for budget
# exhaustion this cycle — the batch-of-one case reduces exactly to the old whole-invocation stop.

# ── (k, part 2) Inter-cycle redeploy checkpoint — consumes the PRIOR cycle's cycle_modified_files
# (see the header note on re-siting). Always a no-op today until the future postflight composer
# starts populating cycle_modified_files; the mechanism is otherwise complete and ready. ─────────
CRITICAL_PATHS_FILE="$SCRIPT_DIR/../context/reference/orchestrator-critical-paths.json"
cycle_modified_files_json=$(mt_get_json '.cycle_modified_files')
if [ "$cycle_modified_files_json" != "[]" ] && [ "$cycle_modified_files_json" != "null" ] && [ -f "$CRITICAL_PATHS_FILE" ]; then
  critical_expanded_json=$(jq -c '
    (.scope_roots // []) as $roots | (.critical_paths // []) as $paths |
    [ $roots[] as $r | $paths[] as $p | {path: ($r + "/" + $p.path), label: $p.label} ]
  ' "$CRITICAL_PATHS_FILE" 2>/dev/null) || critical_expanded_json='[]'
  deployed_json=$(mt_get_json '.deployed_critical_paths')
  matched_json=$(jq -n -c --argjson crit "$critical_expanded_json" --argjson mods "$cycle_modified_files_json" \
    --argjson deployed "$deployed_json" "$FILE_SCOPE_OVERLAP_JQ_DEFS"'
    [ $crit[] | select(.path as $cp | ($deployed | index($cp)) == null) |
      select(scopes_overlap_first([.path]; $mods) != null) ] | unique_by(.path)
  ' 2>/dev/null) || matched_json='[]'
  matched_count=$(echo "$matched_json" | jq 'length')
  if [ "$matched_count" -gt 0 ] && [ "$dry_run" != "true" ]; then
    echo "[orchestrate] REDEPLOY CHECKPOINT: this cycle's modified files touched $matched_count orchestrator-critical path(s):" >&2
    echo "$matched_json" | jq -r '.[] | "  - \(.path) (\(.label))"' >&2
    if pre_raw=$(bash "$SCRIPT_DIR/verify-deploy.sh" --findings --quiet 2>/dev/null); then :; fi
    pre_findings=$(printf '%s\n' "$pre_raw" | grep '^FINDING ' | sort -u) || true
    if bash "$SCRIPT_DIR/deploy-headless.sh" >&2; then
      if post_raw=$(bash "$SCRIPT_DIR/verify-deploy.sh" --findings --quiet 2>/dev/null); then
        post_exit=0
      else
        post_exit=$?
      fi
      post_findings=$(printf '%s\n' "$post_raw" | grep '^FINDING ' | sort -u) || true
      matched_paths_json=$(echo "$matched_json" | jq -c '[.[].path]')
      if [ "$post_exit" -eq 0 ]; then
        mt_set --argjson mp "$matched_paths_json" '.deployed_critical_paths = ((.deployed_critical_paths + $mp) | unique)'
        echo "[orchestrate] REDEPLOY CHECKPOINT: deploy-headless.sh succeeded; verify-deploy.sh clean." >&2
      else
        new_findings=$(comm -13 <(printf '%s\n' "$pre_findings") <(printf '%s\n' "$post_findings")) || true
        if [ -z "$new_findings" ]; then
          echo "[PRE-EXISTING VERIFY-DEPLOY FAILURE - findings predate this redeploy, 0 newly introduced; batch continuing]" >&2
          echo "<!-- verify-deploy-baseline pre=$(echo "$pre_findings" | grep -c .) post=$(echo "$post_findings" | grep -c .) new=0 proceeded=true -->" >&2
          mt_set --argjson mp "$matched_paths_json" '.deployed_critical_paths = ((.deployed_critical_paths + $mp) | unique)'
          mt_set --argjson entry "$(jq -n -c --argjson c "$cycle_count" --argjson pre "$(echo "$pre_findings" | grep -c .)" --argjson post "$(echo "$post_findings" | grep -c .)" --argjson pe "$post_exit" '{cycle:$c, gate:"verify-deploy.sh", pre_findings:$pre, post_findings:$post, new_findings:0, post_exit:$pe}')" '.verify_deploy_baseline_notices += [$entry]'
        else
          echo "[orchestrate] REDEPLOY CHECKPOINT WARNING: verify-deploy.sh exit $post_exit with new findings vs. pre-redeploy baseline; deferring remaining tasks. Fix the deploy/verify failure, redeploy manually, then re-run /orchestrate on the remaining task numbers." >&2
          mt_set --argjson tn "$(mt_get_json '.task_numbers')" --argjson ft "$(mt_get_json '.failed_tasks')" '
            .deferred_deploy_checkpoint = ((.deferred_deploy_checkpoint + ($tn - $ft)) | unique)'
          mt_set --argjson entry "$(jq -n -c --argjson c "$cycle_count" '{task:null, defer_reason:"deploy_checkpoint", collision_scope:null, cycle:$c, detail:"verify-deploy.sh new findings vs. pre-redeploy baseline"}')" '.defer_ledger += [$entry]'
        fi
      fi
    else
      deploy_exit=$?
      echo "[orchestrate] REDEPLOY CHECKPOINT WARNING: deploy-headless.sh exited $deploy_exit; deferring remaining tasks. Fix the deploy failure, redeploy manually, then re-run /orchestrate on the remaining task numbers." >&2
      mt_set --argjson tn "$(mt_get_json '.task_numbers')" --argjson ft "$(mt_get_json '.failed_tasks')" '
        .deferred_deploy_checkpoint = ((.deferred_deploy_checkpoint + ($tn - $ft)) | unique)'
      mt_set --argjson entry "$(jq -n -c --argjson c "$cycle_count" --argjson e "$deploy_exit" '{task:null, defer_reason:"deploy_checkpoint", collision_scope:null, cycle:$c, detail:("deploy-headless.sh exit " + ($e|tostring))}')" '.defer_ledger += [$entry]'
    fi
  fi
fi
# Reset for the cycle now starting — the future postflight composer accumulates fresh entries
# during THIS cycle's own dispatch, to be consulted by the NEXT invocation of this script.
mt_set '.cycle_modified_files = []'
mt_save

# ── (a) Status refresh + session heartbeat ───────────────────────────────────────────────────────
declare -A current_statuses=()
declare -A project_names=()
declare -A task_types=()
declare -A dependency_lists=()
declare -A infra_failure_counts=()
declare -A task_descriptions=()
for t in "${task_args[@]}"; do
  entry=$(lookup_project "$t") || entry=""
  if [ -z "$entry" ] || [ "$entry" = "null" ]; then
    current_statuses[$t]=""
    project_names[$t]=""
    task_types[$t]="general"
    dependency_lists[$t]="[]"
    infra_failure_counts[$t]=0
    task_descriptions[$t]=""
    continue
  fi
  current_statuses[$t]=$(echo "$entry" | jq -r '.status // ""')
  project_names[$t]=$(echo "$entry" | jq -r '.project_name // ""')
  task_types[$t]=$(echo "$entry" | jq -r '.task_type // "general"')
  dependency_lists[$t]=$(echo "$entry" | jq -c '.dependencies // []')
  task_descriptions[$t]=$(echo "$entry" | jq -r '.description // ""')
  infra_failure_counts[$t]=$(mt_get --arg t "$t" '.infra_failures[$t] // 0' 2>/dev/null) || infra_failure_counts[$t]=0
  mt_set --arg t "$t" --arg s "${current_statuses[$t]}" '.current_statuses[$t] = $s'
done
mt_save

if [ "$dry_run" != "true" ]; then
  bash "$SCRIPT_DIR/task-lock.sh" session-heartbeat "$session_id" 2>/dev/null || true
fi

# ── (a2) Seed per-task cycle_counts from the durable per-task guard file, on first sight of a
# task THIS invocation (idempotent across the SAME session's later cycles via `//=` — only a fresh
# session_id, i.e. a fresh mt_state_file, ever re-seeds). READ-ONLY (orchestrate-loop-guard-init.sh
# --seed never mutates or `mkdir -p`s), so this is safe under --dry-run — Decision 1's durable
# backing store is peeked, never written, until an actual LIVE dispatch flushes it back below.
for t in "${task_args[@]}"; do
  [ -z "${project_names[$t]:-}" ] && continue
  _padded=$(printf "%03d" "$t")
  _task_dir_abs="${PROJECT_ROOT}/specs/${_padded}_${project_names[$t]}"
  _seeded=$(bash "$SCRIPT_DIR/orchestrate-loop-guard-init.sh" --seed "$_task_dir_abs" 2>/dev/null | jq -r '.cycle_count // 0' 2>/dev/null) || _seeded=0
  case "$_seeded" in ''|*[!0-9]*) _seeded=0 ;; esac
  mt_set --arg t "$t" --argjson v "$_seeded" '.cycle_counts[$t] //= $v'
done
mt_save

is_terminal_status() {
  case "$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    completed|abandoned|expanded) return 0 ;;
    *) return 1 ;;
  esac
}

deferred_deploy_checkpoint_json=$(mt_get_json '.deferred_deploy_checkpoint')
failed_tasks_json=$(mt_get_json '.failed_tasks')
in_json_array() {
  # $1 = needle (int), $2 = json array
  jq -e --argjson n "$1" '. as $arr | ($arr | index($n)) != null' >/dev/null 2>&1 <<<"$2"
}

# ── (b) All-terminal check ───────────────────────────────────────────────────────────────────────
all_done=true
for t in "${task_args[@]}"; do
  if is_terminal_status "${current_statuses[$t]}"; then continue; fi
  if in_json_array "$t" "$failed_tasks_json"; then continue; fi
  if in_json_array "$t" "$deferred_deploy_checkpoint_json"; then continue; fi
  all_done=false
  break
done
if [ "$all_done" = "true" ]; then
  stop_reason="all_terminal"
  stop_message="Every task is terminal, failed, or excluded by the redeploy checkpoint; nothing left to do."
  emit_and_exit "$cycle_count"
fi

# ── (c) Eligibility ───────────────────────────────────────────────────────────────────────────────
declare -a eligible_tasks=()
declare -A budget_blocked_tasks=()
for t in "${task_args[@]}"; do
  if is_terminal_status "${current_statuses[$t]}"; then continue; fi
  if in_json_array "$t" "$failed_tasks_json"; then continue; fi
  if in_json_array "$t" "$deferred_deploy_checkpoint_json"; then continue; fi

  deps="${dependency_lists[$t]}"
  dep_count=$(echo "$deps" | jq 'length')
  all_preds_done=true
  has_failed_pred=false
  dangling_preds=""
  if [ "$dep_count" -gt 0 ]; then
    while IFS= read -r d; do
      [ -z "$d" ] && continue
      d_entry=$(lookup_project "$d") || d_entry=""
      d_status=$(echo "${d_entry:-null}" | jq -r '.status // ""' 2>/dev/null) || d_status=""
      if is_terminal_status "$d_status"; then
        if [ "$(echo "$d_status" | tr '[:upper:]' '[:lower:]')" != "completed" ]; then
          has_failed_pred=true
        fi
        continue
      fi
      if in_json_array "$d" "$failed_tasks_json"; then
        has_failed_pred=true
        continue
      fi
      # A dependency that resolves in NEITHER active_projects NOR the archive is dangling: the
      # number names no task this repo knows about (a hand-edited dependencies[], a vault
      # renumber, a deleted task). Never let it masquerade as "predecessor still in flight" and
      # drop the task silently — that is exactly how the archived-dependency defect stayed
      # invisible. Report it in blocked[] with the offending numbers named.
      if [ -z "$d_entry" ]; then
        dangling_preds="${dangling_preds:+${dangling_preds},}${d}"
        continue
      fi
      all_preds_done=false
    done < <(echo "$deps" | jq -r '.[]')
  fi

  if [ "$has_failed_pred" = "true" ]; then
    mt_set --arg t "$t" '.failed_tasks = ((.failed_tasks + [($t|tonumber)]) | unique)'
    out_blocked_rows+=("$(jq -n -c --argjson t "$t" '{task: $t, reason: "a predecessor dependency reached a non-completed terminal status or is itself failed; this task can never proceed"}')")
    continue
  fi
  if [ -n "$dangling_preds" ]; then
    out_blocked_rows+=("$(jq -n -c --argjson t "$t" --arg d "$dangling_preds" '{task: $t, reason: ("dependencies[] names task(s) " + $d + " that resolve in neither active_projects nor the archive; fix or drop the dangling edge before this task can be dispatched")}')")
    continue
  fi
  if [ "$all_preds_done" != "true" ]; then
    continue
  fi

  # MAX_INFRA_FAILURES accounting (WORK k, flat per task — see
  # context/patterns/infra-failure-discrimination.md): the counter itself is incremented only by
  # the (not-yet-built) postflight composer's corroborated-transport-failure detection, so this
  # is a dormant no-op today; the exclusion mechanism is ready for when it starts populating
  # infra_failures. --continue-budget authorizes proceeding past it, same as MAX_CYCLES_MT.
  if [ "${infra_failure_counts[$t]:-0}" -ge "$MAX_INFRA_FAILURES" ] && [ "$continue_budget" != "true" ]; then
    out_blocked_rows+=("$(jq -n -c --argjson t "$t" --argjson n "${infra_failure_counts[$t]}" --argjson m "$MAX_INFRA_FAILURES" '{task: $t, reason: ("MAX_INFRA_FAILURES reached (" + ($n|tostring) + "/" + ($m|tostring) + " corroborated Agent-tool transport/API failures); pass --continue-budget to authorize continuing")}')")
    continue
  fi

  # Decision 1 — per-task cumulative cycle budget (this task's own cycle_counts[t], seeded above
  # from the durable ${TASK_DIR}/.orchestrator-loop-guard file, against max_cycles_per_task[t],
  # re-derived fresh this invocation from --hard). Mirrors MAX_INFRA_FAILURES's own per-task shape
  # immediately above; --continue-budget authorizes proceeding past it exactly as it already does
  # for MAX_INFRA_FAILURES and (formerly) the whole-batch scalar.
  _task_cycle_count=$(mt_get --arg t "$t" '.cycle_counts[$t] // 0')
  _task_max_cycles=$(mt_get --arg t "$t" '.max_cycles_per_task[$t] // 0')
  if [ "$_task_cycle_count" -ge "$_task_max_cycles" ]; then
    if [ "$continue_budget" = "true" ]; then
      # budget-continuation-override (Decision 1, ported from single-task Stage 2's locked
      # `budget-continuation-override` region): archive the exhausted durable guard aside and
      # reset cycle_count to 0 IN PLACE, preserving every other field (dispatch_seq_counter,
      # detected_defects, ...) via orchestrate-loop-guard-init.sh --flush. Never touches disk
      # under --dry-run — the live path re-applies this on the next real invocation.
      if [ "$dry_run" != "true" ]; then
        _task_dir_abs="${PROJECT_ROOT}/specs/$(printf "%03d" "$t")_${project_names[$t]}"
        _guard_file="${_task_dir_abs}/.orchestrator-loop-guard"
        if [ -f "$_guard_file" ]; then
          _exhausted_dest="${_task_dir_abs}/.exhausted-loop-guard-$(date -u +%s).json"
          cp "$_guard_file" "$_exhausted_dest" 2>/dev/null || true
          echo "[orchestrate] BUDGET EXHAUSTED for task #$t (cycle_count=${_task_cycle_count}/${_task_max_cycles}) — --continue-budget authorized a fresh budget. Archived exhausted guard to ${_exhausted_dest}." >&2
        fi
        bash "$SCRIPT_DIR/orchestrate-loop-guard-init.sh" --flush "$_task_dir_abs" 0 >/dev/null 2>&1 || true
      fi
      mt_set --arg t "$t" '.cycle_counts[$t] = 0'
    else
      budget_blocked_tasks[$t]=1
      out_blocked_rows+=("$(jq -n -c --argjson t "$t" --argjson n "$_task_cycle_count" --argjson m "$_task_max_cycles" '{task: $t, reason: ("MAX_CYCLES reached (" + ($n|tostring) + "/" + ($m|tostring) + " work cycles for this task); pass --continue-budget to authorize continuing past the budget")}')")
      continue
    fi
  fi

  eligible_tasks+=("$t")
done
mt_save
failed_tasks_json=$(mt_get_json '.failed_tasks')

# ── No-eligible circuit breaker ──────────────────────────────────────────────────────────────────
if [ "${#eligible_tasks[@]}" -eq 0 ]; then
  any_stuck=false
  any_stuck_not_budget=false
  for t in "${task_args[@]}"; do
    is_terminal_status "${current_statuses[$t]}" && continue
    in_json_array "$t" "$failed_tasks_json" && continue
    in_json_array "$t" "$deferred_deploy_checkpoint_json" && continue
    any_stuck=true
    [ -z "${budget_blocked_tasks[$t]:-}" ] && any_stuck_not_budget=true
  done
  if [ "$any_stuck" = "true" ] && [ "$any_stuck_not_budget" != "true" ]; then
    # Decision 1: EVERY non-terminal task was excluded specifically for budget exhaustion this
    # cycle — the batch-wide stop this reduces to for a batch of one, matching single-task Stage
    # 2's own MAX_CYCLES refusal exactly.
    stop_reason="max_cycles"
    stop_message="Every remaining task has reached its own per-task work-cycle budget; pass --continue-budget to authorize continuing past the budget."
  elif [ "$any_stuck" = "true" ]; then
    stop_reason="no_eligible_stuck"
    stop_message="No task is eligible this cycle (all remaining tasks are waiting on in-progress predecessors); waiting for next cycle."
  fi
  emit_and_exit "$cycle_count"
fi

# ── (e) Classification (triage-classify.sh, called once, reused for both phase-map and grouping) ──
if triage_ndjson=$(bash "$SCRIPT_DIR/orchestrate-triage-classify.sh" mt "${eligible_tasks[@]}" 2>&1); then
  triage_exit=0
else
  triage_exit=$?
fi
declare -A triage_group=()
declare -A triage_reason=()
if [ "$triage_exit" -ne 0 ]; then
  echo "[orchestrate] WARNING: orchestrate-triage-classify.sh degraded (exit $triage_exit); falling back to the inline Phase-grouping table per task." >&2
  for t in "${eligible_tasks[@]}"; do
    st="${current_statuses[$t]}"
    case "$st" in
      not_started|researching) triage_group[$t]="research" ;;
      researched|planning) triage_group[$t]="plan" ;;
      planned|implementing|partial) triage_group[$t]="implement" ;;
      blocked) triage_group[$t]="needs_human" ;;
      *) triage_group[$t]="skip" ;;
    esac
    triage_reason[$t]="fallback classification (triage-classify.sh degraded): status ${st:-unknown}"
  done
else
  while IFS= read -r row; do
    [ -z "$row" ] && continue
    rt=$(echo "$row" | jq -r '.task_number')
    triage_group[$rt]=$(echo "$row" | jq -r '.group')
    triage_reason[$rt]=$(echo "$row" | jq -r '.reason')
  done <<< "$triage_ndjson"
fi

# ── (f) Per-task force_phases consumption ────────────────────────────────────────────────────────
# Lazily seed force_phases_remaining for any task first seen this invocation, from the CLI's
# uniform --force-phases value (canonicalized above). Idempotent: a task already carrying a
# (possibly now-shorter) queue from a prior cycle is never reseeded.
if [ "$(echo "$canonical_force_phases_json" | jq 'length')" -gt 0 ]; then
  for t in "${eligible_tasks[@]}"; do
    mt_set --arg t "$t" --argjson q "$canonical_force_phases_json" '.force_phases_remaining[$t] //= $q'
  done
fi

declare -A effective_group=()
declare -A forced_this_cycle=()
for t in "${eligible_tasks[@]}"; do
  remaining=$(echo "$mt_json" | jq -c --arg t "$t" '.force_phases_remaining[$t] // []')
  remaining_len=$(echo "$remaining" | jq 'length')
  if [ "$remaining_len" -gt 0 ]; then
    forced_phase=$(echo "$remaining" | jq -r '.[0]')
    effective_group[$t]="$forced_phase"
    forced_this_cycle[$t]="true"
  else
    effective_group[$t]="${triage_group[$t]:-skip}"
    forced_this_cycle[$t]="false"
  fi
done

# ── (d) Admission: build --phase-map from the (possibly force-overridden) effective group, call
# orchestrate-batch-admit.sh once for the whole eligible set ────────────────────────────────────
phase_map_pairs=()
for t in "${eligible_tasks[@]}"; do
  g="${effective_group[$t]}"
  case "$g" in
    research|plan|implement) phase_map_pairs+=("${t}:${g}") ;;
  esac
done
phase_map_arg=""
if [ "${#phase_map_pairs[@]}" -gt 0 ]; then
  phase_map_arg=$(IFS=,; echo "${phase_map_pairs[*]}")
fi

inv_count="${#eligible_tasks[@]}"
[ -n "$invocation_count_override" ] && inv_count="$invocation_count_override"

admit_args=(--invocation-count "$inv_count" --session-id "$session_id")
[ -n "$phase_map_arg" ] && admit_args+=(--phase-map "$phase_map_arg")
if admit_ndjson=$(bash "$SCRIPT_DIR/orchestrate-batch-admit.sh" "${admit_args[@]}" "${eligible_tasks[@]}" 2>&1); then
  admit_exit=0
else
  admit_exit=$?
fi

declare -A admit_decision=()
declare -A admit_defer_reason=()
declare -A admit_reason=()
if [ "$admit_exit" -ne 0 ]; then
  echo "[orchestrate] WARNING: orchestrate-batch-admit.sh degraded (exit $admit_exit); proceeding WITHOUT the cross-batch admission check this cycle." >&2
  for t in "${eligible_tasks[@]}"; do
    admit_decision[$t]="admit"
  done
else
  while IFS= read -r row; do
    [ -z "$row" ] && continue
    rt=$(echo "$row" | jq -r '.task_number')
    admit_decision[$rt]=$(echo "$row" | jq -r '.decision')
    admit_defer_reason[$rt]=$(echo "$row" | jq -r '.defer_reason // ""')
    admit_reason[$rt]=$(echo "$row" | jq -r '.reason // ""')

    idle_adv=$(echo "$row" | jq -c 'if (.idle_overlap_advisory != null) then .idle_overlap_advisory else null end')
    if [ "$idle_adv" != "null" ]; then
      mt_set --argjson entry "$(jq -n -c --argjson t "$rt" --argjson c "$cycle_count" --argjson a "$idle_adv" '{task:$t, colliding_task_number:$a.colliding_task_number, colliding_task_status:$a.colliding_task_status, overlapping_path:$a.overlapping_path, cycle:$c}')" '.idle_overlap_ledger += [$entry]'
    fi

    if [ "${admit_decision[$rt]}" = "defer" ]; then
      dr="${admit_defer_reason[$rt]}"
      bypass="false"
      if [ "$dr" = "self_modifying" ] && [ "$allow_self_modifying" = "true" ]; then
        bypass="true"
        echo "[orchestrate] BYPASS: --allow-self-modifying is active. Task #$rt dispatching this cycle anyway per explicit human-intent override." >&2
      fi
      if [ "$dr" = "file_scope_collision" ]; then
        cscope=$(echo "$row" | jq -r '.collision_scope // ""')
        if [ "$cscope" = "cross_batch" ] && [ "$allow_scope_collision" = "true" ]; then
          bypass="true"
          echo "[orchestrate] BYPASS: --allow-scope-collision is active. Task #$rt dispatching this cycle anyway per explicit human-intent override (cross-batch only)." >&2
        fi
      fi
      if [ "$bypass" = "true" ]; then
        admit_decision[$rt]="admit"
      else
        case "$dr" in
          self_modifying)
            mt_set --arg t "$rt" '.deferred_self_modifying = ((.deferred_self_modifying + [($t|tonumber)]) | unique)'
            mt_set --argjson entry "$(jq -n -c --argjson t "$rt" --argjson c "$cycle_count" --arg d "${admit_reason[$rt]}" '{task:$t, defer_reason:"self_modifying", collision_scope:null, cycle:$c, detail:$d}')" '.defer_ledger += [$entry]'
            ;;
          file_scope_collision)
            cscope=$(echo "$row" | jq -r '.collision_scope // ""')
            mt_set --argjson entry "$(jq -n -c --argjson t "$rt" --argjson c "$cycle_count" --arg s "$cscope" --arg d "${admit_reason[$rt]}" '{task:$t, defer_reason:"file_scope_collision", collision_scope:$s, cycle:$c, detail:$d}')" '.defer_ledger += [$entry]'
            ;;
          session_active)
            mt_set --argjson entry "$(jq -n -c --argjson t "$rt" --argjson c "$cycle_count" --arg d "${admit_reason[$rt]}" '{task:$t, defer_reason:"session_active", collision_scope:null, cycle:$c, detail:$d}')" '.defer_ledger += [$entry]'
            ;;
        esac
      fi
    fi
  done <<< "$admit_ndjson"
fi
mt_save

# ── Bucket eligible_tasks into dispatch-candidates / deferred / blocked / skip ───────────────────
declare -a dispatch_candidates=()
for t in "${eligible_tasks[@]}"; do
  g="${effective_group[$t]}"
  case "$g" in
    needs_human)
      mt_set --arg t "$t" '.failed_tasks = ((.failed_tasks + [($t|tonumber)]) | unique)'
      out_blocked_rows+=("$(jq -n -c --argjson t "$t" --arg r "${triage_reason[$t]:-handoff-triage needs_human}" '{task:$t, reason:$r}')")
      continue
      ;;
    skip|terminal|exit_partial|"")
      # exit_partial is a reserved verdict value orchestrate-triage-classify.sh defines but does
      # not currently emit from any row; excluded defensively here so an unexpected future emission
      # never falls through silently into a phase dispatch (the same defensive posture the retired
      # orchestrate-dry-run-report.sh applied to this same reserved value).
      continue
      ;;
  esac
  if [ "${admit_decision[$t]:-admit}" = "defer" ]; then
    out_deferred_rows+=("$(jq -n -c --argjson t "$t" --arg r "${admit_reason[$t]:-file_scope or self-modification admission defer}" '{task:$t, reason:$r}')")
    continue
  fi
  dispatch_candidates+=("$t")
done
mt_save

# ── Lock PROBE (read-only; part of the shared decision set — never `acquire` here) ───────────────
declare -a probed_dispatch=()
for t in "${dispatch_candidates[@]}"; do
  if lock_out=$(bash "$SCRIPT_DIR/task-lock.sh" check "$t" 2>/dev/null); then
    lock_exit=0
  else
    lock_exit=$?
  fi
  case "$lock_exit" in
    0|2)
      probed_dispatch+=("$t")
      ;;
    1)
      holder_session=$(printf '%s' "$lock_out" | grep -oE 'session=[^ ]*' | cut -d= -f2-) || true
      if [ "$holder_session" = "$session_id" ]; then
        probed_dispatch+=("$t")
      else
        out_deferred_rows+=("$(jq -n -c --argjson t "$t" '{task: $t, reason: "locked by another session; deferring to a later cycle"}')")
      fi
      ;;
    *)
      # Degraded lock check (exit 3): proceed optimistically — orchestration must still make
      # forward progress; the real acquire below is the final safety net.
      probed_dispatch+=("$t")
      ;;
  esac
done

# ── Convergence guard ─────────────────────────────────────────────────────────────────────────────
if [ "${#probed_dispatch[@]}" -eq 0 ] && [ "${#eligible_tasks[@]}" -gt 0 ]; then
  new_counter=$(( $(mt_get '.consecutive_no_dispatch_cycles') + 1 ))
  mt_set --argjson c "$new_counter" '.consecutive_no_dispatch_cycles = $c'
  mt_save
  if [ "$new_counter" -ge 3 ]; then
    stop_reason="convergence_guard"
    stop_message="$new_counter consecutive cycles with zero dispatched tasks; likely a tie-breaker defect, a deploy_checkpoint exclusion interacting with the batch, or an unexpected file_scope_collision/session_active chain. Pass --allow-self-modifying only if the tie-breaker itself is confirmed broken."
    emit_and_exit "$cycle_count"
  fi
else
  mt_set '.consecutive_no_dispatch_cycles = 0'
  mt_save
fi

# ── Resolve agent per candidate (needed for both dry-run rendering and live dispatch) ────────────
resolve_agent() {
  local op="$1" ttype="$2"
  case "$op" in
    plan) echo "planner-agent"; return ;;
  esac
  local default_agent="general-research-agent"
  [ "$op" = "implement" ] && default_agent="general-implementation-agent"
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/command-route-agent.sh" "$op" "$ttype" "$default_agent" "${effort_flag:-}"
  echo "$AGENT_NAME"
}

# ── H1: hard-mode per-phase dispatch selection (Phase 4 of the task that ported single-task
# features into the batch engine) — one blocking phase per task per cycle, selected by the SAME
# shared heading-scan machinery single-task Stage 4's H1 branch uses. Runs ONCE, here, in the
# shared decision section BEFORE the dry-run/live fork (never two independently-computed
# renderings — mirrors this script's own header mandate), so a hard-mode implement candidate's
# blocked-vs-dispatch bucketing is identical in both modes. Only the plan-file repair (the
# disputed-heading downgrade) is deferred to the live-only continuation below, since --dry-run
# must mutate nothing.
#
# The "exactly one blocking phase per cycle" property (H1's own name for this behavior) holds BY
# CONSTRUCTION and needs no second limiter: this script already builds at most one dispatch row
# per task per cycle (the per-task loops below iterate `probed_dispatch` once), so a hard-mode
# implement candidate never receives more than one phase-scoped dispatch in a single cycle.
#
# Scope Hypothesis confirmation (diffed end-to-end against SKILL.md's own
# "##### Hard branch: Per-Phase Dispatch (H1)" section): every region of that section is either
# ported below, already owned elsewhere in this script, or deliberately left out of THIS phase's
# scope, named here rather than silently dropped:
#   - Ported: the conformance gate, the heading-scan `next_phase` selection, the pre-dispatch
#     marker/handoff crosscheck (with the disputed-heading downgrade), and the H7 territory
#     literal — all four regions this phase's own task list names.
#   - Already owned elsewhere, unchanged by this port: `dispatch_seq` minting and
#     `skill_preflight_update` (the existing per-task live-dispatch loop below already does both,
#     unconditionally, for every implement row — not H1-specific); `phases_completed_before`
#     capture (superseded by `orchestrate-churn.sh`'s own `phases_completed_last` persistence,
#     Decision 3 / Phase 2); the phase-mission prompt text (ported into
#     `orchestrate-build-dispatch.sh`'s new `--phase-number`-gated "## Phase Mission" section).
#   - Deliberately NOT ported by this phase (named exclusions, not gaps): (1) the Agent tool
#     invocation table itself — this script only ever PREPARES a dispatch row; issuing the Agent
#     tool call is `SKILL.md` Stage MT-4's job (Phase 6). (2) The `elif last_skeleton` branch
#     (skeleton-exhaustion routing: `pr_ready` postflight, completion-summary propagation,
#     `.dispatch/`/loop-guard cleanup, `EXIT (success)`) — a Lean/formal skeleton-plan-specific
#     completion path outside this phase's task list; a hard-mode skeleton plan routed through the
#     batch engine today falls through to the "no open heading" branch below (ordinary dispatch)
#     rather than the single-task engine's specialized skeleton-completion handling. Recorded here
#     as a known, out-of-scope gap for a future phase/task, not a silent omission.
declare -A h1_blocked_reason=()      # t -> blocked-row reason string (H1 refusal)
declare -A h1_next_phase=()          # t -> selected phase number (only when actually dispatching)
declare -A h1_territory=()           # t -> H7 territory JSON literal (only when dispatching)
declare -A h1_disputed_plan_path=()  # t -> plan_path (live-only repair, paired with the next map)
declare -A h1_disputed_linenum=()    # t -> line number to downgrade to [PARTIAL]

if [ "$hard_mode" = "true" ]; then
  # shellcheck disable=SC1091
  . "$SCRIPT_DIR/lib/phase-heading-patterns.sh"
fi

for t in "${probed_dispatch[@]}"; do
  [ "$hard_mode" != "true" ] && continue
  [ "${effective_group[$t]}" != "implement" ] && continue
  h1_project_name="${project_names[$t]:-}"
  [ -z "$h1_project_name" ] && continue
  h1_padded=$(printf "%03d" "$t")
  h1_task_dir_abs="${PROJECT_ROOT}/specs/${h1_padded}_${h1_project_name}"
  h1_plan_path=$(ls -1 "${h1_task_dir_abs}/plans/"*.md 2>/dev/null | sort -V | tail -1) || h1_plan_path=""
  h1_handoff_file="${h1_task_dir_abs}/.orchestrator-handoff.json"
  if [ -f "$h1_handoff_file" ]; then
    h1_phases_completed=$(jq -r '.phases_completed // 0' "$h1_handoff_file" 2>/dev/null) || h1_phases_completed=0
  else
    h1_phases_completed=0
  fi
  case "$h1_phases_completed" in ''|*[!0-9]*) h1_phases_completed=0 ;; esac

  h1_next_phase_val=""
  h1_inconclusive="false"
  if [ -n "$h1_plan_path" ] && [ -f "$h1_plan_path" ]; then
    # --- resume-scan-conformance-gate: whole-file check BEFORE the filtered scan, ported
    # verbatim from single-task's own H1 branch (same sentinel name, same rationale: a
    # non-conforming heading is INVISIBLE to PHASE_HEADING_ERE, not merely unmatched). ---
    if has_nonconforming_phase_headings "$h1_plan_path"; then
      warn_nonconforming "$h1_plan_path" "orchestrate-cycle-plan-h1-next-phase" || true
      h1_inconclusive="true"
    else
      h1_next_heading=$(grep -E "${PHASE_HEADING_ERE} .*${PHASE_STATUS_OPEN_ERE}" "$h1_plan_path" | head -1) || true
      if [ -n "$h1_next_heading" ]; then
        h1_next_phase_val=$(extract_phase_number "$h1_next_heading") || h1_next_phase_val=""
        [ -z "$h1_next_phase_val" ] && h1_inconclusive="true"
      fi
    fi
  fi

  if [ "$h1_inconclusive" = "true" ]; then
    h1_blocked_reason[$t]="H1: non-conforming phase heading(s) in ${h1_plan_path} — the filtered resume scan cannot see them, so the true next phase is UNKNOWN. Fix the plan's heading grammar (see plan-format.md's canonical phase-heading shape) and re-run."
  elif [ -n "$h1_next_phase_val" ]; then
    # --- marker-handoff-crosscheck-predispatch: Defect 6, PRE-dispatch and dispatch-REFUSING
    # (distinct from base Stage 5's own POST-dispatch, diagnostic-and-downgrading crosscheck).
    # Ported verbatim from single-task's H1 branch, EXIT (partial) mapped to a blocked row per
    # Decision 4. ---
    h1_marker_completed_count=$(grep -cE "$PHASE_HEADING_DONE_ERE" "$h1_plan_path" 2>/dev/null || echo 0)
    if [ "$h1_marker_completed_count" != "$h1_phases_completed" ]; then
      h1_blocked_reason[$t]="H1: MARKER/HANDOFF MISMATCH — plan file shows ${h1_marker_completed_count} phase(s) marked [COMPLETED]/[COMPLETED WITH EXCLUSIONS], but the handoff's own phases_completed=${h1_phases_completed}. Not dispatching the successor over unconfirmed work."
      if [ "$h1_marker_completed_count" -gt "$h1_phases_completed" ]; then
        h1_disputed_line=$(grep -nE "$PHASE_HEADING_DONE_ERE" "$h1_plan_path" | sed -n "$((h1_phases_completed + 1))p")
        if [ -n "$h1_disputed_line" ]; then
          h1_disputed_plan_path[$t]="$h1_plan_path"
          h1_disputed_linenum[$t]="${h1_disputed_line%%:*}"
        fi
      fi
    else
      h1_next_phase[$t]="$h1_next_phase_val"
      # H7 territory literal, ported verbatim (Defect 5 — a woken PREDECESSOR dispatch resuming
      # outside this orchestrator's own control flow, never a same-cycle sibling-file conflict).
      h1_territory[$t]='{
    "owned_files": "derive from plan_path'"'"'s Phase '"$h1_next_phase_val"' \"Files to modify\" list",
    "read_only_files": [],
    "forbidden_files": [],
    "concurrency_note": "This declaration asserts only which files THIS dispatch owns. It does NOT assert exclusive access -- a still-live predecessor may exist. If you observe foreign commits, foreign uncommitted modifications, or a running build you did not start, STOP and report it rather than proceeding or dismissing it. See context/contracts/territory.md and context/patterns/dispatch-report-not-termination.md."
  }'
    fi
  fi
  # else: no OPEN heading found, not inconclusive -- falls through to ORDINARY status-derived
  # implement dispatch for this task below (no phase-number, no territory). Mirrors single-task's
  # own "all genuinely complete / not a skeleton plan" fallthrough, which defers to the
  # completion-claim gate rather than blocking or forcing a phase — orchestrate-cycle-postflight.sh
  # already owns that gate for the batch engine.
done

# Move every H1-refused candidate straight to blocked[] and out of BOTH per-mode loops below —
# never built as a dispatch row in either mode. Live-only: apply the disputed-heading downgrade
# to [PARTIAL] (a plan-file repair; --dry-run must mutate nothing).
declare -a probed_dispatch_post_h1=()
for t in "${probed_dispatch[@]}"; do
  if [ -n "${h1_blocked_reason[$t]:-}" ]; then
    out_blocked_rows+=("$(jq -n -c --argjson t "$t" --arg r "${h1_blocked_reason[$t]}" '{task: $t, reason: $r}')")
    if [ "$dry_run" != "true" ] && [ -n "${h1_disputed_linenum[$t]:-}" ]; then
      echo "[orchestrate] H1: downgrading disputed phase heading to [PARTIAL] in ${h1_disputed_plan_path[$t]} (line ${h1_disputed_linenum[$t]})" >&2
      sed -i -E "${h1_disputed_linenum[$t]}s/\[(COMPLETED|COMPLETED WITH EXCLUSIONS)\]/[PARTIAL]/" "${h1_disputed_plan_path[$t]}"
    fi
    continue
  fi
  probed_dispatch_post_h1+=("$t")
done

if [ "$dry_run" = "true" ]; then
  for t in "${probed_dispatch_post_h1[@]}"; do
    g="${effective_group[$t]}"
    agent=$(resolve_agent "$g" "${task_types[$t]}")
    dry_force_json="false"; [ "${forced_this_cycle[$t]:-false}" = "true" ] && dry_force_json="true"
    out_dispatch_rows+=("$(jq -n -c --argjson t "$t" --arg p "$g" --arg a "$agent" --argjson force "$dry_force_json" \
      '{task: $t, phase: $p, agent: $a, model: null, dispatch_file: null, force: $force}')")
  done
  emit_and_exit "$cycle_count"
fi

# =====================================================================================================
# LIVE-ONLY SIDE-EFFECT HALF (never reached under --dry-run)
# =====================================================================================================

# shellcheck disable=SC1091
source "$SCRIPT_DIR/skill-base.sh"
cd "$SKILL_REPO_ROOT"

new_cycle_count=$(( cycle_count + 1 ))

for t in "${probed_dispatch_post_h1[@]}"; do
  g="${effective_group[$t]}"
  project_name="${project_names[$t]}"
  if [ -z "$project_name" ]; then
    out_deferred_rows+=("$(jq -n -c --argjson t "$t" '{task: $t, reason: "task not found in state.json; cannot resolve project directory"}')")
    continue
  fi
  padded=$(printf "%03d" "$t")
  task_dir_rel="specs/${padded}_${project_name}"
  task_dir_abs="${SKILL_REPO_ROOT}/${task_dir_rel}"

  # (g) Task directory creation — the multi-task missing-directory gap. Ordered strictly before
  # the orchestrate-build-dispatch.sh call, which re-derives state directly from state.json/disk.
  if [ ! -d "$task_dir_abs" ]; then
    mkdir -p "$task_dir_abs"
    echo "[orchestrate] Created missing task directory: $task_dir_rel" >&2
  fi
  mt_set --arg t "$t" --arg d "$task_dir_rel" '.task_dirs[$t] = $d'

  # (h) Lock acquire — the real, mutating acquire; final safety net past the read-only probe above.
  if acquire_out=$(bash "$SCRIPT_DIR/task-lock.sh" acquire "$t" "$g" "$session_id" "/orchestrate (multi-task)" 2>&1); then
    acquire_exit=0
  else
    acquire_exit=$?
  fi
  if [ "$acquire_exit" -eq 1 ]; then
    echo "[orchestrate] WARNING: Task #$t is locked by another session; deferring to a later cycle." >&2
    out_deferred_rows+=("$(jq -n -c --argjson t "$t" '{task: $t, reason: "locked by another session at acquire time; deferring to a later cycle"}')")
    continue
  elif [ "$acquire_exit" -ne 0 ]; then
    echo "[orchestrate] WARNING: task-lock.sh acquire errored for task #$t (exit $acquire_exit): $acquire_out" >&2
    out_deferred_rows+=("$(jq -n -c --argjson t "$t" '{task: $t, reason: "task-lock.sh acquire errored; deferring to a later cycle"}')")
    continue
  fi

  # (i) dispatch_seq mint + dispatch_start_ts — one atomic multi-state write.
  task_dispatch_seq=$(mt_get '(.dispatch_seq_counter // 0) + 1')
  task_dispatch_start_ts=$(date -u +%s)
  mt_set --arg t "$t" --argjson ts "$task_dispatch_start_ts" --argjson seq "$task_dispatch_seq" \
    '.dispatch_start_ts[$t] = $ts | .dispatch_seq[$t] = $seq | .dispatch_seq_counter = $seq'

  # (f, continued) pop the forced phase now that it is actually being dispatched this cycle.
  if [ "${forced_this_cycle[$t]:-false}" = "true" ]; then
    mt_set --arg t "$t" '.force_phases_remaining[$t] = (.force_phases_remaining[$t][1:])'
  fi

  # Bare-vs-suffixed session_id invariant: research/plan use the suffixed form; implement uses
  # the bare form (see header comment).
  dispatch_session="${session_id}_${t}"
  [ "$g" = "implement" ] && dispatch_session="$session_id"

  # (j) Preflight status write.
  skill_preflight_update "$t" "$g" "$dispatch_session"

  # (l) orchestrate-build-dispatch.sh — Stage 3.5 Dispatch Prep's sole implementation.
  build_args=(--session "$dispatch_session" --seq "$task_dispatch_seq" --dispatch-start-ts "$task_dispatch_start_ts")
  [ "$clean_flag" = "true" ] && build_args+=(--clean)
  [ "$lit_flag" = "true" ] && build_args+=(--lit)
  [ "$hard_mode" = "true" ] && build_args+=(--hard)
  [ "${effort_flag:-}" = "fast" ] && build_args+=(--fast)
  [ -n "$model_flag" ] && build_args+=(--model "$model_flag")
  # H1 (Phase 4): only ever set for a hard-mode implement candidate whose heading-scan selected
  # a phase this cycle — absent from every base-mode call and from a hard-mode implement candidate
  # that fell through to ordinary status-derived dispatch (no open heading found, not inconclusive).
  if [ -n "${h1_next_phase[$t]:-}" ]; then
    build_args+=(--phase-number "${h1_next_phase[$t]}" --territory "${h1_territory[$t]}")
  fi
  if dispatch_json=$(bash "$SCRIPT_DIR/orchestrate-build-dispatch.sh" "$t" "$g" "${build_args[@]}" 2>&1); then
    build_exit=0
  else
    build_exit=$?
  fi
  if [ "$build_exit" -ne 0 ]; then
    echo "[orchestrate] WARNING: orchestrate-build-dispatch.sh failed for task #$t (exit $build_exit): $dispatch_json" >&2
    out_deferred_rows+=("$(jq -n -c --argjson t "$t" '{task: $t, reason: "orchestrate-build-dispatch.sh failed; deferring to a later cycle"}')")
    continue
  fi
  dispatch_file=$(echo "$dispatch_json" | jq -r '.dispatch_file')
  dispatch_model=$(echo "$dispatch_json" | jq -r '.model')
  [ -z "$dispatch_model" ] && dispatch_model_json="null" || dispatch_model_json="\"$dispatch_model\""

  agent=$(resolve_agent "$g" "${task_types[$t]}")
  if [ "$g" = "research" ]; then
    mt_set --arg t "$t" --arg a "$agent" '.research_agents[$t] = $a'
  elif [ "$g" = "implement" ]; then
    mt_set --arg t "$t" --arg a "$agent" '.implement_agents[$t] = $a'
  fi
  mt_set --arg t "$t" --arg d "${task_descriptions[$t]:-}" '.descriptions[$t] = $d'

  # Decision 1 — charge this task's per-task cycle budget now that a dispatch row for it is
  # actually being built this cycle (mirrors single-task Stage 7's "increment cycle_count after a
  # dispatch" idiom, scoped per task), and flush the new value back to the durable
  # ${TASK_DIR}/.orchestrator-loop-guard file so it survives past this ephemeral mt_state_file.
  task_new_cycle_count=$(mt_get --arg t "$t" '((.cycle_counts[$t] // 0) + 1)')
  mt_set --arg t "$t" --argjson v "$task_new_cycle_count" '.cycle_counts[$t] = $v'
  bash "$SCRIPT_DIR/orchestrate-loop-guard-init.sh" --flush "$task_dir_abs" "$task_new_cycle_count" >/dev/null 2>&1 || true

  # `force` (Phase 7 addition, orchestrate-cycle-postflight.sh's --force-invoked wiring): this is
  # the ONLY point in the whole per-cycle pipeline where "was this task's phase forced this
  # cycle" is known -- forced_this_cycle[$t] was computed above (per-candidate force_phases
  # consumption) and the queue is popped just above this row, so by the time Stage MT-4 reads
  # this row back the pop has already happened and the information would otherwise be lost.
  # Threading it through the row (rather than recomputing it downstream) is the same shape as
  # every other per-task field this row already carries.
  force_json="false"; [ "${forced_this_cycle[$t]:-false}" = "true" ] && force_json="true"
  out_dispatch_rows+=("$(jq -n -c --argjson t "$t" --arg p "$g" --arg a "$agent" --argjson dm "$dispatch_model_json" --arg df "$dispatch_file" --argjson force "$force_json" \
    '{task: $t, phase: $p, agent: $a, model: $dm, dispatch_file: $df, force: $force}')")
done

mt_set --argjson c "$new_cycle_count" '.cycle_count = $c'
mt_save

emit_and_exit "$new_cycle_count"
