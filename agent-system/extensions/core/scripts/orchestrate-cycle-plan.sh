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
# --focus "<text>" carries the user's own free-form "$2+" text typed on the /orchestrate command
# line (see commands/orchestrate.md); it is composed with any task's research_questions field
# (neither silently replaces the other — see section (l)) and threaded into every dispatched
# phase's dispatch file as a "User focus:" block, and surfaced per row under --dry-run.
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
#   idle_overlap_ledger, cycle_modified_files. PLUS TWO genuinely NEW fields this script introduces
#   (per-task force_phases consumption, a feature gap no prior stage closed):
#   force_phases_remaining (map task_number(string) -> ordered array of not-yet-dispatched forced
#   phases, canonical research/plan/implement order, popped as each forced phase is dispatched);
#   forced_round_seeded (map task_number(string) -> true, once `force_phases_remaining[t]` has ever
#   been seeded for t THIS run — the marker `//` alone cannot supply, since it cannot distinguish
#   "never forced this run" from "forced this run, queue since popped to []": see section (f)'s
#   three-way branch, the "stop after the last forced phase" fix).
# PLUS THREE MORE new fields (Phase 5's Decision 2 aux_dispatch[] emission): aux_pending (map
#   task_number(string) -> {kind, ...} | absent — written by orchestrate-cycle-postflight.sh,
#   read and cleared here), blocker_escalation_count and drift_inspection_count (maps
#   task_number(string) -> int, the per-task per-invocation caps MAX_BLOCKER_ESCALATIONS/
#   MAX_DRIFT_INSPECTIONS below).
# PLUS ONE MORE new field (the in-session plan cache — "do not charge for a read"): plan_cache,
#   shaped `{dispatch_seq_counter: int, plan: <plan object>}` or `null`. Written here ONLY when a
#   composition actually built >=1 dispatch row (i.e. actually charged); read at entry, before
#   any composition side effect, to detect and replay an unconsumed prior composition without
#   re-charging. Cleared unconditionally by orchestrate-cycle-postflight.sh on any postflight
#   outcome (reaching postflight at all is proof the cached plan was consumed).
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
# Output contract (emit direction — STRUCTURAL, not per-call-site): immediately after sourcing
# common.sh, this script runs `exec 3>&1 1>&2`, dup'ing the process's original stdout to fd 3 and
# repointing fd 1 (plain, unredirected stdout) at the original stderr for the rest of the
# process's life. The single-line plan JSON is the ONLY thing ever written to fd 3 (in
# emit_and_exit(), both dry-run and live), and every other write in this file — diagnostics,
# the --dry-run human table, any collaborator's uncaptured output — lands on fd 1/2, i.e.
# stderr, by construction. This means no per-call-site `>&2` bookkeeping is needed anywhere else
# in the file: a future addition that forgets to redirect still cannot reach the data channel.
# (Prior to this, individual call sites — e.g. skill_preflight_update — carried their own `>&2`;
# that per-site stopgap is now redundant and has been removed in favor of this entry-point
# redirect.) This governs only what the script EMITS; `run_capture_stdout` above governs what it
# INGESTS from its own collaborators and is a separate, complementary mechanism.
#
# --dry-run design (absorbs the retired orchestrate-dry-run-report.sh — see that script's own
# retirement in this task): runs the IDENTICAL read-only decision pass (admission, classification,
# forced phases, a read-only lock PROBE via `task-lock.sh check` — never `acquire`) and prints the
# SAME plan JSON the live path would emit, with dispatch_file/model forced to null on every
# dispatch row (nothing was actually built), on fd 3 — plus a compact human table on STDERR,
# rendered by reading back that SAME already-printed JSON object and nothing else (no second
# computation, no independent formatting of any decision). fd 3 stays pure, single-line JSON in
# BOTH modes, so a machine caller never needs to distinguish dry-run from live output shape; the
# table exists purely for a human running `/orchestrate --dry-run` at a terminal, where stderr
# renders inline with stdout (fd 1, which after the entry-point redirect IS stderr). Table
# sections, in order: `-- Dispatch --` (task, phase, agent),
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
#     [--force-phases "research,plan,implement"] [--clean] [--lit] [--compare] [--hard] [--fast]
#     [--model M] [--allow-self-modifying] [--allow-scope-collision]
#     [--dry-run] <task_number> [<task_number> ...]
#   --state-file is always required. --session is required EXCEPT under --dry-run, where it is
#   optional: an internal, never-persisted identity is synthesized when omitted (mt_save() is
#   unconditionally a no-op under --dry-run, so the synthesized session_id's derived
#   mt_state_file path is never created).
#
# `--compare` is forwarded into `build_args` (as `--compare`, mirroring `--lit`) ONLY for an
# implement-phase candidate (`$g = "implement"`) — it is meaningless for research/plan dispatches
# and is never forwarded to them.
#
# `--state-file F` is the CANONICAL specs/state.json (or a fixture copy in tests) — the same
# STATE_FILE every sibling script (orchestrate-batch-admit.sh, orchestrate-triage-classify.sh)
# reads. This script separately derives its OWN per-invocation bookkeeping file at the fixed path
# `<dirname F>/.orchestrator-multi-state-${session_id}.json` (mirroring Stage MT-1's
# `specs/.orchestrator-multi-state-${session_id}.json` naming exactly when F is specs/state.json).
# `--team`/`--team-size` are REJECTED as unrecognized flags (usage error, exit 2) — team mode is
# withdrawn; no `team` key is ever emitted on a dispatch row.
#
# Decision 2 (originating plan's Phase 5) — aux_dispatch[]: a SIBLING array, never widening
# `dispatch[]`'s own `phase` vocabulary (which stays exactly {research, plan, implement} so the
# `--phase` contract of orchestrate-cycle-postflight.sh is never touched by an aux row). Rows are
# `{task, kind, agent, model, dispatch_file, orchestrator_mode: false}` with
# `kind ∈ {drift-inspection, blocker-research, plan-revision, divergence-audit}` and a FIXED
# `agent` chosen by `orchestrate-build-aux-dispatch.sh`'s own emitting logic (`fork`, `fork`,
# `reviser-agent`, and the task's own already-resolved `research_agents[t]` respectively) — never
# resolved through `command-route-agent.sh`. Emitted from `aux_pending[task]` (written by
# orchestrate-cycle-postflight.sh's WORK (k) — divergence-audit under hard mode, drift-inspection
# or blocker-research under base mode) and from the blocker-research/drift-inspection CHAIN
# (`${TASK_DIR}/.blocker-research.json` / `.drift-inspection.json`, written by a PRIOR cycle's own
# aux dispatch once it actually runs), which take priority over a fresh `aux_pending` entry for
# the SAME task this cycle and produce a `plan-revision` row instead. Aux rows never reach
# `orchestrate-cycle-postflight.sh` and never contribute to `failed_tasks` — their only effect is
# a written file or a revised plan, which the NEXT cycle's ordinary status-derived dispatch picks
# up. Computed in the SAME shared decision section as everything else (both --dry-run and live
# render the identical choice of kind/target per task); only the dispatch-file WRITE, the
# `aux_pending`/marker-file consumption, and the two per-task escalation counters
# (`blocker_escalation_count`/`drift_inspection_count`, capped at `MAX_BLOCKER_ESCALATIONS`=2 /
# `MAX_DRIFT_INSPECTIONS`=1 per task per invocation — i.e. per `mt_state_file`, which is fresh
# every `/orchestrate` invocation, matching single-task's own "reset each invocation" caps) are
# live-only side effects.
#
# Output: a single line of compact JSON on the process's ORIGINAL stdout — fd 3 from this
# script's own perspective after its entry-point `exec 3>&1 1>&2`; a caller invoking this script
# normally (without itself touching fd 3) observes it as plain stdout, unchanged from the
# caller's point of view:
#   {cycle: int, dispatch: [{task, phase, agent, model, dispatch_file, force}],
#    aux_dispatch: [{task, kind, agent, model, dispatch_file, orchestrator_mode: false}],
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

# ── Structural output-channel discipline (emit direction) ──────────────────────────────────────
# fd 3 is THE data channel for the rest of this script's life: it is dup'd from the original
# stdout once, here, at entry, and every subsequent stdout write (fd 1) — ours or any callee we
# invoke without an explicit capture — lands on the original stderr instead. This replaces the
# earlier per-call-site `>&2` stopgap (see the removed redirect on the skill_preflight_update
# call below) with a structural guarantee: no future addition anywhere in this file, and no
# uncaptured callee output, can leak into the plan-JSON payload, because there is no longer a
# plain stdout for it to leak into. The sole intentional write to fd 3 is the plan-JSON emit in
# emit_and_exit(). Command substitution ($(...)) is unaffected — it privately rebinds fd 1 inside
# its own subshell, so every existing `x=$(...)` capture in this script keeps working exactly as
# before this redirect. Note this governs only what this script EMITS; run_capture_stdout below
# governs what it INGESTS from its own collaborators, and is a separate, complementary mechanism.
exec 3>&1 1>&2

# ── Stream-discipline helper ────────────────────────────────────────────────────────────────────
# Every orchestrate-* helper this script shells out to contracts stdout for its JSON/NDJSON payload
# and stderr for human diagnostics. Capturing such a helper with `2>&1` folds the diagnostics into
# the payload, and the `jq` that parses it then fails (or, for the NDJSON consumers that branch on
# exit status, silently ingests a garbage row while still reporting success). This runs a helper
# with the streams kept apart: stdout lands in the caller's named variable, stderr is forwarded to
# our own stderr so nothing is lost, and the helper's exit status is preserved for the caller's
# `if`. The forwarded text is also left in CAPTURE_DIAG for failure-branch warning messages.
CAPTURE_DIAG=""
run_capture_stdout() {
  local __outvar="$1"; shift
  local __diag_file __out __rc=0
  __diag_file=$(mktemp "${TMPDIR:-/tmp}/orchestrate-capture.XXXXXX")
  __out=$("$@" 2>"$__diag_file") || __rc=$?
  CAPTURE_DIAG=$(cat "$__diag_file" 2>/dev/null || true)
  rm -f "$__diag_file"
  [ -n "$CAPTURE_DIAG" ] && printf '%s\n' "$CAPTURE_DIAG" >&2
  printf -v "$__outvar" '%s' "$__out"
  return "$__rc"
}
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
if ! . "${SCRIPT_DIR}/lib/file-scope-overlap.sh" 2>/dev/null; then
  echo "ERROR: orchestrate-cycle-plan.sh: could not source ${SCRIPT_DIR}/lib/file-scope-overlap.sh." >&2
  exit 2
fi
if ! . "${SCRIPT_DIR}/lib/deploy-baseline-lib.sh" 2>/dev/null; then
  echo "ERROR: orchestrate-cycle-plan.sh: could not source ${SCRIPT_DIR}/lib/deploy-baseline-lib.sh." >&2
  exit 2
fi
if ! . "${SCRIPT_DIR}/lib/task-lookup-lib.sh" 2>/dev/null; then
  echo "ERROR: orchestrate-cycle-plan.sh: could not source ${SCRIPT_DIR}/lib/task-lookup-lib.sh." >&2
  exit 2
fi
if ! . "${SCRIPT_DIR}/lib/deploy-ledger-lib.sh" 2>/dev/null; then
  echo "ERROR: orchestrate-cycle-plan.sh: could not source ${SCRIPT_DIR}/lib/deploy-ledger-lib.sh." >&2
  exit 2
fi

MAX_INFRA_FAILURES=3
# Decision 2 (Phase 5) — aux_dispatch[] escalation caps, ported verbatim from single-task Stage
# 2/5a/6's own values; per-task per-invocation (i.e. per mt_state_file, fresh every /orchestrate
# invocation — matching single-task's own "reset each invocation" semantics).
MAX_BLOCKER_ESCALATIONS=2
MAX_DRIFT_INSPECTIONS=1

usage() {
  cat <<'USAGE'
Usage: orchestrate-cycle-plan.sh --session SID --state-file F [--invocation-count N]
         [--force-phases "research,plan,implement"] [--focus "<text>"] [--clean] [--lit]
         [--compare] [--hard] [--fast] [--model M] [--allow-self-modifying]
         [--allow-scope-collision] [--dry-run] [--no-plan-cache]
         <task_number> [<task_number> ...]

--state-file is always required. --session is required EXCEPT under --dry-run, where an
internal, never-persisted identity is synthesized when omitted. --no-plan-cache disables the
in-session plan-cache replay (both the read and the write) for this invocation; every
composition re-evaluates fresh and charges normally. Intended for debugging and for this
script's own test suite's non-cache groups -- not needed in ordinary /orchestrate use.
--focus is the user's free-form "$2+" text typed after the task number(s) on the /orchestrate
command line (see commands/orchestrate.md). It is composed with any task-level
research_questions (neither silently replaces the other) and threaded into every dispatched
phase's dispatch file as a labelled "User focus:" block; a --dry-run report also surfaces it per
row so it can be checked before a live run.
USAGE
}

# ─── Flag parsing ──────────────────────────────────────────────────────────────────────────────
session_id=""
state_file_arg=""
invocation_count_override=""
force_phases_arg=""
focus_prompt=""
clean_flag="false"
lit_flag="false"
compare_flag="false"
hard_mode="false"
effort_flag=""
model_flag=""
allow_self_modifying="false"
allow_scope_collision="false"
dry_run="false"
no_plan_cache="false"
task_args=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --session) session_id="${2:-}"; shift 2 ;;
    --state-file) state_file_arg="${2:-}"; shift 2 ;;
    --invocation-count) invocation_count_override="${2:-}"; shift 2 ;;
    --force-phases) force_phases_arg="${2:-}"; shift 2 ;;
    --focus) focus_prompt="${2:-}"; shift 2 ;;
    --clean) clean_flag="true"; shift ;;
    --lit) lit_flag="true"; shift ;;
    --compare) compare_flag="true"; shift ;;
    --hard) hard_mode="true"; effort_flag="hard"; shift ;;
    --fast) effort_flag="fast"; shift ;;
    --model) model_flag="${2:-}"; shift 2 ;;
    --allow-self-modifying) allow_self_modifying="true"; shift ;;
    --allow-scope-collision) allow_scope_collision="true"; shift ;;
    --dry-run) dry_run="true"; shift ;;
    --no-plan-cache) no_plan_cache="true"; shift ;;
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

if [ -z "$state_file_arg" ]; then
  echo "ERROR: orchestrate-cycle-plan.sh: --state-file is required." >&2
  usage >&2
  exit 2
fi

# --session is required in live mode (every downstream side effect -- the lock layer, the
# session registry, dispatch bookkeeping -- is keyed on it), but is OPTIONAL under --dry-run:
# mt_save() above is unconditionally a no-op when dry_run=true, so the mt_state_file path this
# session_id derives (below) is never created regardless of its value. When --dry-run is given
# with no --session, synthesize an internal, never-persisted identity so every downstream
# session_id-keyed read still has a well-formed (if synthetic) value to work with.
if [ -z "$session_id" ]; then
  if [ "$dry_run" = "true" ]; then
    session_id="dryrun-$$-$(date +%s)"
  else
    echo "ERROR: orchestrate-cycle-plan.sh: --session is required (except under --dry-run)." >&2
    usage >&2
    exit 2
  fi
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

# NOTE: the per-candidate active_projects read this section used to bind once (all_projects_json)
# has moved inside scripts/lib/task-lookup-lib.sh's task_lookup_entry, which now owns both the
# active-projects lookup and the archive-fallback lookup behind lookup_project() below — the
# single-shared-library requirement (Phase 1) outweighs the one-read-instead-of-N micro-
# optimization the old inline binding bought; every lookup_project() call re-reads STATE_FILE via
# jq, same as it already did for the archive branch before this change.

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
# Extracted to scripts/lib/task-lookup-lib.sh (sourced above) so the archive-normalization rule
# lives in exactly one place; lookup_project below is kept as a thin wrapper so no call site
# changes in this phase.
lookup_project() {
  # Usage: lookup_project <project_number> — echoes the matching record (or nothing). Thin
  # wrapper over task_lookup_entry (active projects win; the archive is consulted only when the
  # number is absent from them).
  task_lookup_entry "$1" "$STATE_FILE"
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
  | .redeploy_skip_notices //= []
  | .consecutive_no_dispatch_cycles //= 0
  | .verify_deploy_baseline_notices //= []
  | .defer_ledger //= []
  | .detected_defects //= []
  | .forward_progress_violated //= false
  | .idle_overlap_ledger //= []
  | .cycle_modified_files //= []
  | .force_phases_remaining //= {}
  | .forced_round_seeded //= {}
  | .aux_pending //= {}
  | .blocker_escalation_count //= {}
  | .drift_inspection_count //= {}
  | .plan_cache //= null
  ' <<<"$mt_json")

# ─── Item (b): in-session plan cache — replay check (must run before ANY composition side ────
# effect: the seed/eligibility pass, the first mt_save below, any budget increment, any loop-guard
# flush). `plan_cache` is `{dispatch_seq_counter: int, plan: <plan object>}` or `null`, written by
# emit_and_exit() below ONLY when a composition actually built >=1 dispatch row (i.e. actually
# charged). If the CURRENT `dispatch_seq_counter` (read fresh from mt_json, before this
# composition touches anything) still equals the value the cache was written at, then NOTHING has
# been dispatched since that composition — no postflight ever ran to consume it and advance the
# counter (orchestrate-cycle-postflight.sh clears plan_cache unconditionally on any postflight
# outcome, so a run that reached postflight can never replay a stale plan). Replay the cached plan
# verbatim to fd 3 and exit 0 without composing, without touching cycle_counts, and without
# flushing the durable loop-guard file — this invocation costs nothing. A genuine cycle (one where
# something WAS consumed since) always falls through to the real composition below and charges
# exactly one, as before. Skipped entirely under --dry-run (mt_json is always freshly "{}" there,
# by construction above) and under the --no-plan-cache escape hatch.
if [ "$dry_run" != "true" ] && [ "$no_plan_cache" != "true" ]; then
  plan_cache_present=$(echo "$mt_json" | jq -r '.plan_cache != null')
  if [ "$plan_cache_present" = "true" ]; then
    plan_cache_seq=$(echo "$mt_json" | jq -r '.plan_cache.dispatch_seq_counter')
    current_seq=$(echo "$mt_json" | jq -r '.dispatch_seq_counter // 0')
    if [ "$plan_cache_seq" = "$current_seq" ]; then
      cached_plan=$(echo "$mt_json" | jq -c '.plan_cache.plan')
      echo "[orchestrate] PLAN CACHE REPLAY: dispatch_seq_counter=${current_seq} unchanged since the last composition that built it -- nothing was dispatched (no postflight ran to consume it and advance the counter), so this composition is replayed verbatim from cache. No cycle is charged and the durable loop-guard file is not flushed." >&2
      printf '%s\n' "$cached_plan" >&3
      exit 0
    fi
  fi
fi

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
declare -a out_aux_dispatch_rows=()
declare -a out_deferred_rows=()
declare -a out_blocked_rows=()

emit_and_exit() {
  local cycle_val="$1"
  local dispatch_json aux_dispatch_json deferred_json blocked_json stop_json
  if [ "${#out_dispatch_rows[@]}" -gt 0 ]; then
    dispatch_json="[$(IFS=,; echo "${out_dispatch_rows[*]}")]"
  else
    dispatch_json="[]"
  fi
  if [ "${#out_aux_dispatch_rows[@]}" -gt 0 ]; then
    aux_dispatch_json="[$(IFS=,; echo "${out_aux_dispatch_rows[*]}")]"
  else
    aux_dispatch_json="[]"
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
    --argjson aux_dispatch "$aux_dispatch_json" \
    --argjson deferred "$deferred_json" --argjson blocked "$blocked_json" --argjson stop "$stop_json" \
    '{cycle: $cycle, dispatch: $dispatch, aux_dispatch: $aux_dispatch, deferred: $deferred, blocked: $blocked, stop: $stop}')

  # Item (b): write plan_cache ONLY when this composition actually built >=1 dispatch row (i.e.
  # actually charged the per-task budget) -- a no-dispatch composition already charges nothing
  # and MUST stay uncached, so it always re-evaluates fresh next time (state may have changed
  # even though nothing was dispatched). Keyed by dispatch_seq_counter's value AFTER this
  # composition (every row-charging site above already minted/advanced it), so a subsequent
  # invocation's pre-composition read of the SAME still-unchanged value is proof nothing was
  # dispatched since -- see the replay check near the top of this script for the read side.
  #
  # Decision (D3), Phase 1 (--focus): the cache key stays dispatch_seq_counter ALONE, with no
  # --focus component added to it. --dry-run bypasses both the cache read and this write
  # entirely (see the `[ "$dry_run" != "true" ]` guard immediately below), and in a live run
  # --focus is fixed for the whole invocation (parsed once, into the read-only $focus_prompt
  # variable, at the top of this script) -- so a cache replay can only ever replay the same
  # composition, built with the same focus value, it was originally cached with.
  if [ "$dry_run" != "true" ] && [ "$no_plan_cache" != "true" ] && \
     { [ "${#out_dispatch_rows[@]}" -gt 0 ] || [ "${#out_aux_dispatch_rows[@]}" -gt 0 ]; }; then
    mt_set --argjson plan "$plan_json" \
      '.plan_cache = {dispatch_seq_counter: (.dispatch_seq_counter // 0), plan: $plan}'
    mt_save
  fi

  printf '%s\n' "$plan_json" >&3
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
        echo "$plan_json" | jq -r '.dispatch[] | "#\(.task)  phase=\(.phase)  agent=\(.agent)\(if .focus == "" then "" else "  focus=\(.focus)" end)"'
      fi
      echo ""
      echo "-- Aux Dispatch --"
      if [ "$(echo "$plan_json" | jq '.aux_dispatch | length')" -eq 0 ]; then
        echo "0 aux-dispatched."
      else
        echo "$plan_json" | jq -r '.aux_dispatch[] | "#\(.task)  kind=\(.kind)  agent=\(.agent)"'
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
# (see the header note on re-siting). orchestrate-cycle-postflight.sh DOES populate
# cycle_modified_files (the composer landed); this checkpoint is live, not a no-op. ─────────────
#
# Durable redeploy ledger: before the first expensive call below, this checkpoint now consults a
# cross-invocation ledger (lib/deploy-ledger-lib.sh, specs/.orchestrator-deploy-ledger.json by
# default) and can skip the whole deploy+verify body on positive evidence -- a hash skip for the
# ordinary unchanged-content case, or an attributed-recency skip for a task whose own file_scope
# is the orchestrator source store (the hash always changes for that class, by construction). See
# context/patterns/batch-orchestration-guardrails.md's "Durable redeploy ledger" paragraph for the
# full contract; `deployed_critical_paths` below keeps its own, narrower within-invocation role
# unchanged.
#
# Failure contract (the same three-branch (a)/(b)/(c) contract
# context/patterns/batch-orchestration-guardrails.md's "### The Inter-Cycle Redeploy Checkpoint"
# subsection documents, and command-gate-out.sh's rc==6 handler already implements, EXTENDED by
# the confirmation/attribution filters below):
#   (a) deploy-headless.sh exit 1 or 2 (the deploy did not land) -- unconditional defer, no
#       baseline consultation. Exit 3 is deliberately EXCLUDED from this branch: it means the
#       deploy LANDED but inline verification reported failures, which belongs to the
#       baseline-relative comparison below, not here.
#   (b)/(c) deploy landed (exit 0 or 3) -- compare pre/post verify-deploy.sh --findings snapshots
#       (via lib/deploy-baseline-lib.sh, which also folds a verify-deploy.sh exit 2 into the
#       single FINDING gate0 [SENTINEL] line per the documented exit-2 resolution rule). A
#       candidate new finding (present post, absent pre) is then passed through TWO additive
#       filters, in order, before it is allowed to defer anything:
#         1. CONFIRMATION (deploy_baseline_confirm_new_findings): re-run verify-deploy.sh once
#            more, on a now-settled machine, and keep only candidate findings that REPRODUCE. A
#            candidate that does not reproduce was flaky -- most concretely, a load-sensitive
#            test flaking under the load THIS checkpoint's own full deploy + full verify just
#            generated (see lib/deploy-baseline-lib.sh's load-sensitivity note) -- and is dropped.
#         2. ATTRIBUTION (deploy_baseline_unattributable_findings): of the confirmed findings,
#            drop any that POSITIVELY name an identifier absent from this batch's own
#            `cycle_modified_files` -- i.e. a red gate this batch could not have caused. This is
#            the SAME "pre-existing, unrelated red gate must not defer the batch" philosophy
#            branch (c) already embodies, extended from *temporally* pre-existing (branch (c)'s
#            original scope: identical in both snapshots) to *causally* unattributable (a NEW
#            finding this batch still did not cause). Fail-safe direction: a finding naming no
#            identifier at all is NEVER dropped by this filter and stays blocking.
#       Only findings surviving BOTH filters ("blocking") defer (b), naming themselves in the
#       stderr warning and the defer_ledger detail (Defect B). An empty blocking set -- whether
#       because new_findings was empty outright (original branch (c)) or because every candidate
#       was shown flaky/unrelated (the new filtered sub-branch) -- proceeds loudly with a
#       recorded verify_deploy_baseline_notices entry; the notice's own fields distinguish the
#       two cases (see the `filtered` marker below) so they are never confused with each other.
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

    # ── Durable redeploy ledger consult (Decisions 4-5) ─────────────────────────────────────────
    # Consulted BEFORE the first expensive call (deploy_findings_snapshot below). Fail-safe
    # throughout: a CANNOTVERIFY hash state or an unreadable ledger both degrade to a "run"
    # decision inside deploy_ledger_decide, never to a false skip. See
    # context/patterns/batch-orchestration-guardrails.md's "Durable redeploy ledger" paragraph.
    ledger_file="$(deploy_ledger_path "$PROJECT_ROOT")"
    hash_state_json="$(deploy_ledger_hash_state "$PROJECT_ROOT" "$CRITICAL_PATHS_FILE" 2>/dev/null)" || hash_state_json=""
    ledger_json="$(deploy_ledger_read "$ledger_file" 2>/dev/null)" || ledger_json=""

    # deploy_pending override (Decision 5): any batch task whose OWN .return-meta.json carries
    # deploy_pending:true forces the decision to `run`, so a skip can never starve the postflight
    # completion-deploy gate's backstop.
    deploy_pending_any="false"
    for _dp_t in $(mt_get_json '.task_numbers' | jq -r '.[]' 2>/dev/null || true); do
      _dp_entry="$(lookup_project "$_dp_t" 2>/dev/null || true)"
      if [ -n "$_dp_entry" ] && [ "$_dp_entry" != "null" ]; then
        _dp_pname="$(echo "$_dp_entry" | jq -r '.project_name // ""' 2>/dev/null || true)"
        if [ -n "$_dp_pname" ]; then
          _dp_dir="${PROJECT_ROOT}/$(task_lookup_dir "$_dp_t" "$_dp_pname" "$PROJECT_ROOT")"
          _dp_meta="${_dp_dir}/.return-meta.json"
          if [ -f "$_dp_meta" ]; then
            _dp_flag="$(jq -r '.deploy_pending // false' "$_dp_meta" 2>/dev/null || true)"
            [ "$_dp_flag" = "true" ] && deploy_pending_any="true"
          fi
        fi
      fi
    done

    ledger_decision_json="$(deploy_ledger_decide "$ledger_json" "$hash_state_json" "$(date +%s)" "$cycle_modified_files_json" "$(mt_get_json '.task_numbers')" "$deploy_pending_any")"
    ledger_decision="$(echo "$ledger_decision_json" | jq -r '.decision')"

    if [ "$ledger_decision" = "run" ]; then
    pre_findings=$(deploy_findings_snapshot "$SCRIPT_DIR/verify-deploy.sh")

    deploy_exit=0
    bash "$SCRIPT_DIR/deploy-headless.sh" >&2 || deploy_exit=$?

    if [ "$deploy_exit" -eq 1 ] || [ "$deploy_exit" -eq 2 ]; then
      # Branch (a): the redeploy itself failed to land -- NO baseline consultation, do not
      # re-attempt. See the header comment above for why exit 3 is excluded from this branch.
      echo "[orchestrate] REDEPLOY CHECKPOINT WARNING: deploy-headless.sh exited $deploy_exit -- the deploy did not land; deferring remaining tasks. Fix the deploy failure, redeploy manually, then re-run /orchestrate on the remaining task numbers." >&2
      mt_set --argjson tn "$(mt_get_json '.task_numbers')" --argjson ft "$(mt_get_json '.failed_tasks')" '
        .deferred_deploy_checkpoint = ((.deferred_deploy_checkpoint + ($tn - $ft)) | unique)'
      mt_set --argjson entry "$(jq -n -c --argjson c "$cycle_count" --argjson e "$deploy_exit" '{task:null, defer_reason:"deploy_checkpoint", collision_scope:null, cycle:$c, detail:("deploy-headless.sh exit " + ($e|tostring))}')" '.defer_ledger += [$entry]'
      if [ -n "$hash_state_json" ]; then
        deploy_ledger_write "$ledger_file" "$hash_state_json" "deploy_failed" "$(mt_get_json '.task_numbers')" "$session_id" "$cycle_count" \
          || echo "[orchestrate] REDEPLOY CHECKPOINT WARNING: failed to write the durable deploy ledger at $ledger_file (non-fatal)." >&2
      fi
    else
      # Deploy landed (exit 0 or 3) -- reachable from exit 3 for the first time. A fresh,
      # FULL (non-`--skip-slow`) post-redeploy findings snapshot is taken independently of
      # deploy-headless.sh's own internal `--skip-slow` verify -- exactly as before this phase --
      # so the baseline comparison below sees slow-gate findings too, not only the fast subset
      # deploy-headless.sh itself checked. deploy_findings_snapshot's FINDING-line vocabulary is
      # empty if and only if verify-deploy.sh exited 0 (see its own FAILURES-eq-0 exit-0 rule),
      # so an empty post_findings is a reliable, cheaper stand-in for a separately-captured exit
      # code; post_exit below is derived from that emptiness (and the exit-2 sentinel marker)
      # purely for the diagnostic notice field, not as a second live invocation.
      #
      # DEFECT A -- this documented full-depth choice is DELIBERATE, not an oversight, and is
      # PRESERVED here, not silently lowered: deploy-headless.sh's OWN internal verify-deploy.sh
      # call runs `--skip-slow` (defers gate 8, the shell test suite, and nothing else), so a
      # `deploy_exit -eq 0` ("landed_verify_clean") only ever certifies the FAST subset. Taking
      # this pre/post pair at full depth independently is what lets the baseline comparison see
      # slow-gate (gate 8) findings too. The asymmetry against deploy-headless.sh's own fast
      # verify is no longer silently resolved in either direction: see the fast/full depth
      # disagreement report below, fired exactly when `deploy_exit -eq 0` yet the full-depth
      # comparison still finds a genuine blocking finding.
      # The pre/post pair itself MUST stay at IDENTICAL depth (both full, no `--skip-slow` on
      # either side) -- an asymmetric pair would make every gate-8 finding look "new" simply
      # because pre never looked for it, which is a strictly worse bug than the depth mismatch
      # against deploy-headless.sh being reported at all.
      post_findings=$(deploy_findings_snapshot "$SCRIPT_DIR/verify-deploy.sh")
      matched_paths_json=$(echo "$matched_json" | jq -c '[.[].path]')
      if [ -z "$post_findings" ]; then
        post_exit=0
        mt_set --argjson mp "$matched_paths_json" '.deployed_critical_paths = ((.deployed_critical_paths + $mp) | unique)'
        echo "[orchestrate] REDEPLOY CHECKPOINT: deploy-headless.sh succeeded; verify-deploy.sh clean." >&2
        if [ -n "$hash_state_json" ]; then
          deploy_ledger_write "$ledger_file" "$hash_state_json" "clean" "$(mt_get_json '.task_numbers')" "$session_id" "$cycle_count" \
            || echo "[orchestrate] REDEPLOY CHECKPOINT WARNING: failed to write the durable deploy ledger at $ledger_file (non-fatal)." >&2
        fi
      else
        post_exit=1
        printf '%s\n' "$post_findings" | grep -q '\[SENTINEL\]' && post_exit=2
        new_findings=$(deploy_baseline_new_findings "$pre_findings" "$post_findings")
        if [ -z "$new_findings" ]; then
          # Branch (c): every post-redeploy finding was already present pre-redeploy -- proceed,
          # loudly, and record a baseline notice. UNCHANGED (PRESERVE) -- this is the original,
          # temporally-pre-existing case; it never reaches the confirmation/attribution filters
          # below because there is no candidate new finding to filter in the first place.
          echo "[PRE-EXISTING VERIFY-DEPLOY FAILURE - findings predate this redeploy, 0 newly introduced; batch continuing]" >&2
          echo "<!-- verify-deploy-baseline pre=$(echo "$pre_findings" | grep -c .) post=$(echo "$post_findings" | grep -c .) new=0 proceeded=true -->" >&2
          mt_set --argjson mp "$matched_paths_json" '.deployed_critical_paths = ((.deployed_critical_paths + $mp) | unique)'
          mt_set --argjson entry "$(jq -n -c --argjson c "$cycle_count" --argjson pre "$(echo "$pre_findings" | grep -c .)" --argjson post "$(echo "$post_findings" | grep -c .)" --argjson pe "$post_exit" '{cycle:$c, gate:"verify-deploy.sh", pre_findings:$pre, post_findings:$post, new_findings:0, post_exit:$pe, filtered:false}')" '.verify_deploy_baseline_notices += [$entry]'
          if [ -n "$hash_state_json" ]; then
            deploy_ledger_write "$ledger_file" "$hash_state_json" "pre_existing" "$(mt_get_json '.task_numbers')" "$session_id" "$cycle_count" \
              || echo "[orchestrate] REDEPLOY CHECKPOINT WARNING: failed to write the durable deploy ledger at $ledger_file (non-fatal)." >&2
          fi
        else
          # At least one CANDIDATE new finding relative to the pre-redeploy baseline. DEFECT C:
          # before this candidate is allowed to defer the whole batch, run it through the
          # confirmation filter (drop findings that do not reproduce on a fresh, now-settled
          # re-run -- flaky) and then the attribution filter (drop confirmed findings that
          # positively name an identifier absent from this batch's own cycle_modified_files --
          # unrelated). Only the survivors ("blocking") may defer. This confirmation snapshot is
          # taken at the SAME full depth as the pre/post pair (never `--skip-slow`) so it is
          # comparing like with like -- exactly one extra verify-deploy.sh call, fired only on
          # this rare would-be-defer path.
          confirm_findings=$(deploy_findings_snapshot "$SCRIPT_DIR/verify-deploy.sh")
          confirmed_new=$(deploy_baseline_confirm_new_findings "$new_findings" "$confirm_findings")
          flaky_findings=$(comm -23 <(printf '%s\n' "$new_findings" | sort -u) <(printf '%s\n' "$confirmed_new" | sort -u))
          unrelated_findings=$(deploy_baseline_unattributable_findings "$confirmed_new" "$cycle_modified_files_json")
          blocking=$(comm -23 <(printf '%s\n' "$confirmed_new" | sort -u) <(printf '%s\n' "$unrelated_findings" | sort -u))

          if [ -z "$blocking" ]; then
            # Branch (c)-equivalent: every candidate new finding was shown flaky or unrelated to
            # this batch's own modified_files -- proceed loudly, exactly like the original
            # branch (c), but with a notice that carries WHAT was filtered and WHY (`filtered:
            # true` is the distinguishing marker so this sub-branch is never confused with the
            # original, temporally-pre-existing branch (c) above).
            echo "[orchestrate] REDEPLOY CHECKPOINT: every new verify-deploy.sh finding vs. the pre-redeploy baseline was confirmed flaky or unrelated to this batch's own modified files; batch continuing." >&2
            [ -n "$flaky_findings" ] && { echo "  flaky (did not reproduce on re-run):" >&2; printf '%s\n' "$flaky_findings" | sed 's/^/    /' >&2; }
            [ -n "$unrelated_findings" ] && { echo "  unrelated (names an identifier absent from this batch's modified files):" >&2; printf '%s\n' "$unrelated_findings" | sed 's/^/    /' >&2; }
            mt_set --argjson mp "$matched_paths_json" '.deployed_critical_paths = ((.deployed_critical_paths + $mp) | unique)'
            mt_set --argjson entry "$(jq -n -c \
              --argjson c "$cycle_count" \
              --argjson pre "$(echo "$pre_findings" | grep -c .)" \
              --argjson post "$(echo "$post_findings" | grep -c .)" \
              --argjson nfc "$(printf '%s\n' "$new_findings" | grep -c .)" \
              --argjson pe "$post_exit" \
              --arg flaky "$flaky_findings" \
              --argjson flakyc "$(printf '%s\n' "$flaky_findings" | grep -c .)" \
              --arg unrelated "$unrelated_findings" \
              --argjson unrelatedc "$(printf '%s\n' "$unrelated_findings" | grep -c .)" \
              '{cycle:$c, gate:"verify-deploy.sh", pre_findings:$pre, post_findings:$post, new_findings:$nfc, post_exit:$pe, filtered:true, flaky_count:$flakyc, flaky_findings:$flaky, unrelated_count:$unrelatedc, unrelated_findings:$unrelated, blocking_count:0}')" '.verify_deploy_baseline_notices += [$entry]'
            if [ -n "$hash_state_json" ]; then
              deploy_ledger_write "$ledger_file" "$hash_state_json" "filtered" "$(mt_get_json '.task_numbers')" "$session_id" "$cycle_count" \
                || echo "[orchestrate] REDEPLOY CHECKPOINT WARNING: failed to write the durable deploy ledger at $ledger_file (non-fatal)." >&2
            fi
          else
            # Branch (b): at least one CONFIRMED, ATTRIBUTABLE finding relative to the
            # pre-redeploy baseline -- defer, do not re-attempt. Name the specific blocking
            # finding(s) in both the stderr warning and the defer_ledger detail, so the operator
            # can act without re-running the whole gate to discover what was new (Defect B) --
            # printing the FILTERED `blocking` set, never the raw pre-filter `new_findings`.
            echo "[orchestrate] REDEPLOY CHECKPOINT WARNING: verify-deploy.sh exit $post_exit with new findings vs. pre-redeploy baseline (confirmed reproducible and attributable to this batch); deferring remaining tasks. Fix the deploy/verify failure, redeploy manually, then re-run /orchestrate on the remaining task numbers." >&2
            printf '%s\n' "$blocking" | sed 's/^/    /' >&2
            # DEFECT A depth-disagreement report: deploy_exit -eq 0 means deploy-headless.sh's
            # own internal --skip-slow verify already reported landed_verify_clean (a fast PASS)
            # for THIS same tree -- yet the full-depth comparison still finds a blocking finding.
            # That is a depth disagreement (the finding lives in the slow gate --skip-slow
            # deferred), not a contradiction between two verdicts of the same depth; say so.
            depth_disagreement=false
            if [ "$deploy_exit" -eq 0 ]; then
              depth_disagreement=true
              echo "  [orchestrate] DEPTH NOTE: deploy-headless.sh's own --skip-slow verify passed (fast PASS); the finding(s) above come from the full-depth (slow-gate) verify this checkpoint runs independently -- a depth disagreement, not a contradiction." >&2
            fi
            mt_set --argjson tn "$(mt_get_json '.task_numbers')" --argjson ft "$(mt_get_json '.failed_tasks')" '
              .deferred_deploy_checkpoint = ((.deferred_deploy_checkpoint + ($tn - $ft)) | unique)'
            mt_set --argjson entry "$(jq -n -c --argjson c "$cycle_count" --arg nf "$blocking" --argjson nfc "$(printf '%s\n' "$blocking" | grep -c .)" --argjson dd "$depth_disagreement" '{task:null, defer_reason:"deploy_checkpoint", collision_scope:null, cycle:$c, detail:("verify-deploy.sh new findings vs. pre-redeploy baseline (" + ($nfc|tostring) + ", confirmed+attributable): " + $nf), depth_disagreement:$dd}')" '.defer_ledger += [$entry]'
            if [ -n "$hash_state_json" ]; then
              deploy_ledger_write "$ledger_file" "$hash_state_json" "blocking" "$(mt_get_json '.task_numbers')" "$session_id" "$cycle_count" \
                || echo "[orchestrate] REDEPLOY CHECKPOINT WARNING: failed to write the durable deploy ledger at $ledger_file (non-fatal)." >&2
            fi
          fi
        fi
      fi
    fi
  else
    # Durable redeploy ledger: skip_hash or skip_attributed -- positive ledger evidence says this
    # exact content (or, for skip_attributed, this batch's own edits to it) was already verified
    # recently enough. Bypass the whole deploy/verify body via this if/else wrapper (never an
    # early exit), so the trailing cycle_modified_files reset and mt_save below still run. See
    # context/patterns/batch-orchestration-guardrails.md's "Durable redeploy ledger" paragraph.
    ledger_reason="$(echo "$ledger_decision_json" | jq -r '.reason')"
    ledger_age="$(echo "$ledger_decision_json" | jq -r '.age_sec')"
    ledger_prev_outcome="$(echo "$ledger_json" | jq -r '.verify_outcome // "unknown"')"
    ledger_agg_short="$(echo "$ledger_json" | jq -r '(.aggregate // "unknown") | .[0:12]')"
    ledger_attributing_json="$(echo "$ledger_decision_json" | jq -c '.attributing_tasks')"
    echo "[orchestrate] REDEPLOY CHECKPOINT: skipped (${ledger_decision}) -- ledger shows aggregate ${ledger_agg_short} verified ${ledger_prev_outcome} ${ledger_age}s ago by task(s) ${ledger_attributing_json}; ${ledger_reason}" >&2
    mt_set --argjson entry "$(jq -n -c \
      --argjson c "$cycle_count" \
      --arg d "$ledger_decision" \
      --arg r "$ledger_reason" \
      --argjson age "$ledger_age" \
      --arg o "$ledger_prev_outcome" \
      --argjson changed "$(echo "$ledger_decision_json" | jq -c '.changed_paths')" \
      --argjson attributing "$ledger_attributing_json" \
      '{cycle:$c, decision:$d, reason:$r, age_sec:$age, ledger_outcome:$o, changed_paths:$changed, attributing_tasks:$attributing}')" \
      '.redeploy_skip_notices += [$entry]'
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

# ── (a2) Per-run cycle-budget contract (Decision (a)): `cycle_counts[t]` starts at a value of
# zero every run and is NEVER seeded from the durable per-task guard file's `cycle_count` any
# more -- the `//= {}` default on `.cycle_counts` (above) already gives every named task a
# starting value of zero on first sight this invocation, and that is now the WHOLE seeding story
# for budgeting. `cycle_count` in the durable guard file is no longer read or written by this
# script for budgeting purposes; re-running /orchestrate is the explicit, only way to continue
# past a per-run-exhausted budget (see the MAX_CYCLES block below). `cycle_count` itself is left
# alone in the guard file's JSON schema as inert historical data (never read, never written by
# this engine any more) -- an old guard file needs no migration, and any OTHER caller of
# `--flush`/`--seed` (e.g. a future single-task resume) keeps working against it unchanged.
#
# What DOES still need durable, cross-invocation seeding: `dispatch_seq_counter`. Unlike the
# budget, a dispatch_seq value must NEVER repeat within a task across separate /orchestrate runs
# (a repeat would let a new run's dispatch file silently collide with a prior run's still-live
# one) -- so this loop seeds `mt_json.dispatch_seq_counter` to the MAX of its current value and
# every named task's own durable guard-file value, via `orchestrate-loop-guard-init.sh --seed`
# (READ-ONLY, `mkdir -p`-free, safe under --dry-run). Taking a running max rather than a `//=`
# first-sight assignment is deliberately idempotent regardless of how many times this loop runs
# (e.g. once per cycle of the same run) -- it can only ever move the counter up, never down, and
# a candidate whose durable value is already <= the in-session value (the common case on a
# second-or-later cycle of the same run, since the live charge site below flushes durably on
# every real dispatch) is a no-op.
#
# Also seeds `pending_dispatch_seed[$t]` (Item (b)'s durable, CROSS-invocation counterpart to the
# in-session plan_cache above): the recorded `{seq, phase, forced, dispatch_file, recorded_at}`
# of the last dispatch this task's durable guard file charged, or absent if none/never-recorded.
# Consumed at the charge site below, in the live per-task dispatch loop. UNCHANGED by the per-run
# cycle-budget contract above -- this ledger's own durability is orthogonal to the cycle-count
# budget.
#
# Unwind-support capture (`orchestrate-unwind-dispatch.sh`'s Phase 1 pre-image): also seeds
# `pd_prior_dsc[$t]`, the durable `dispatch_seq_counter` value as it stood BEFORE this run's own
# `--flush-seq` calls (both this task's own, at the live per-task charge site below, and any
# earlier aux-dispatch-emission flush for the SAME task, which runs between this loop and the live
# per-task loop). This loop is the earliest point in the whole script that reads a task's durable
# guard file, so capturing here — rather than re-reading `--seed` again immediately before the
# live charge site's own `--flush-seq` call — is what "move the read to before the earliest
# durable write" means in practice for this script.
declare -A pending_dispatch_seed=()
declare -A pd_prior_dsc=()
for t in "${task_args[@]}"; do
  [ -z "${project_names[$t]:-}" ] && continue
  _task_dir_abs="${PROJECT_ROOT}/$(task_lookup_dir "$t" "${project_names[$t]}" "$PROJECT_ROOT")"
  _seed_out=$(bash "$SCRIPT_DIR/orchestrate-loop-guard-init.sh" --seed "$_task_dir_abs" 2>/dev/null) || _seed_out=""
  _seeded_dsc=$(printf '%s' "$_seed_out" | jq -r '.dispatch_seq_counter // 0' 2>/dev/null) || _seeded_dsc=0
  case "$_seeded_dsc" in ''|*[!0-9]*) _seeded_dsc=0 ;; esac
  mt_set --argjson d "$_seeded_dsc" '.dispatch_seq_counter = ([.dispatch_seq_counter, $d] | max)'
  pd_prior_dsc[$t]="$_seeded_dsc"
  _seed_pending=$(printf '%s' "$_seed_out" | jq -c '.pending_dispatch // null' 2>/dev/null) || _seed_pending="null"
  [ "$_seed_pending" != "null" ] && pending_dispatch_seed[$t]="$_seed_pending"
done
mt_save

# ── AUX DECISION (Decision 2, Phase 5): choose, for every task named on the command line, which
# aux_dispatch[] row (if any) this cycle emits — read-only, computed identically for --dry-run and
# live (the shared-decision-section mandate this script's header already states). A task's
# blocker-research/drift-inspection CHAIN (its own dispatch file's JSON output, written by a PRIOR
# cycle's aux dispatch once it actually ran) takes priority over a fresh `aux_pending[t]` entry for
# the SAME task this cycle, and always produces a `plan-revision` row. Mutual exclusion between
# `drift-inspection` (base mode) and `divergence-audit` (hard mode) is asserted defensively even
# though it already holds by construction (postflight only ever writes one or the other, gated on
# the SAME `hard_mode` flag this whole invocation shares). ─────────────────────────────────────
declare -A aux_emit_kind=()             # t -> drift-inspection|blocker-research|plan-revision|divergence-audit
declare -A aux_emit_target=()
declare -A aux_emit_verbatim_goal=()
declare -A aux_emit_blocker_desc=()
declare -A aux_emit_revision_reason=()  # plan-revision only: blocker|drift
declare -A aux_emit_findings_summary=()
declare -A aux_emit_drift_pct=()
declare -A aux_emit_drift_summary=()
declare -A aux_emit_plan_path=()
declare -A aux_clear_pending=()         # t -> true: clear aux_pending[t] in the live-only half
declare -A aux_consume_blocker_file=()  # t -> true: rm .blocker-research.json in the live-only half
declare -A aux_consume_drift_file=()    # t -> true: rm .drift-inspection.json in the live-only half

for t in "${task_args[@]}"; do
  [ -z "${project_names[$t]:-}" ] && continue
  aux_task_dir_abs="${PROJECT_ROOT}/$(task_lookup_dir "$t" "${project_names[$t]}" "$PROJECT_ROOT")"
  aux_blocker_file="${aux_task_dir_abs}/.blocker-research.json"
  aux_drift_file="${aux_task_dir_abs}/.drift-inspection.json"

  if [ -f "$aux_blocker_file" ] && jq empty "$aux_blocker_file" 2>/dev/null; then
    aux_emit_kind[$t]="plan-revision"
    aux_emit_revision_reason[$t]="blocker"
    aux_emit_blocker_desc[$t]=$(jq -r '.blocker_desc // "Unspecified blocker"' "$aux_blocker_file" 2>/dev/null) || aux_emit_blocker_desc[$t]="Unspecified blocker"
    aux_emit_findings_summary[$t]=$(jq -r '.summary // "No findings"' "$aux_blocker_file" 2>/dev/null) || aux_emit_findings_summary[$t]="No findings"
    aux_emit_plan_path[$t]=$(ls -1 "${aux_task_dir_abs}/plans/"*.md 2>/dev/null | sort -V | tail -1) || aux_emit_plan_path[$t]=""
    aux_consume_blocker_file[$t]="true"
    continue
  fi
  if [ -f "$aux_drift_file" ] && jq empty "$aux_drift_file" 2>/dev/null; then
    aux_consume_drift_file[$t]="true"
    aux_drift_pct=$(jq -r '.drift_pct // 0' "$aux_drift_file" 2>/dev/null) || aux_drift_pct=0
    aux_drift_over=$(awk -v p="$aux_drift_pct" 'BEGIN{ printf (p+0 > 0.30) ? "true" : "false" }' 2>/dev/null) || aux_drift_over="false"
    if [ "$aux_drift_over" = "true" ]; then
      aux_emit_kind[$t]="plan-revision"
      aux_emit_revision_reason[$t]="drift"
      aux_emit_drift_pct[$t]="$aux_drift_pct"
      aux_emit_drift_summary[$t]=$(jq -r '.summary // "No summary"' "$aux_drift_file" 2>/dev/null) || aux_emit_drift_summary[$t]="No summary"
      aux_emit_plan_path[$t]=$(ls -1 "${aux_task_dir_abs}/plans/"*.md 2>/dev/null | sort -V | tail -1) || aux_emit_plan_path[$t]=""
    else
      echo "[orchestrate] Drift check passed. Continuing." >&2
    fi
    continue
  fi

  aux_pending_json=$(mt_get_json --arg t "$t" '.aux_pending[$t] // null')
  [ "$aux_pending_json" = "null" ] && continue
  aux_kind=$(echo "$aux_pending_json" | jq -r '.kind // ""')

  if [ "$aux_kind" = "drift-inspection" ] && [ "$hard_mode" = "true" ]; then
    aux_clear_pending[$t]="true"
    continue
  fi
  if [ "$aux_kind" = "divergence-audit" ] && [ "$hard_mode" != "true" ]; then
    aux_clear_pending[$t]="true"
    continue
  fi

  case "$aux_kind" in
    drift-inspection)
      aux_cnt=$(mt_get --arg t "$t" '.drift_inspection_count[$t] // 0')
      if [ "$aux_cnt" -ge "$MAX_DRIFT_INSPECTIONS" ]; then
        echo "[orchestrate] MAX_DRIFT_INSPECTIONS ($MAX_DRIFT_INSPECTIONS) reached for task #$t this invocation — skipping the drift-inspection aux dispatch." >&2
        aux_clear_pending[$t]="true"
        continue
      fi
      aux_emit_kind[$t]="drift-inspection"
      aux_emit_plan_path[$t]=$(ls -1 "${aux_task_dir_abs}/plans/"*.md 2>/dev/null | sort -V | tail -1) || aux_emit_plan_path[$t]=""
      aux_clear_pending[$t]="true"
      ;;
    blocker-research)
      aux_cnt=$(mt_get --arg t "$t" '.blocker_escalation_count[$t] // 0')
      if [ "$aux_cnt" -ge "$MAX_BLOCKER_ESCALATIONS" ]; then
        echo "[orchestrate] MAX_BLOCKER_ESCALATIONS ($MAX_BLOCKER_ESCALATIONS) reached for task #$t. Manual intervention required. Suggest: (1) /research $t, (2) /revise $t, (3) /implement $t." >&2
        aux_clear_pending[$t]="true"
        continue
      fi
      aux_emit_kind[$t]="blocker-research"
      aux_emit_blocker_desc[$t]=$(echo "$aux_pending_json" | jq -r '.blocker_desc // "Unspecified blocker"')
      aux_clear_pending[$t]="true"
      ;;
    divergence-audit)
      aux_emit_kind[$t]="divergence-audit"
      aux_emit_target[$t]=$(echo "$aux_pending_json" | jq -r '.target // "unknown"')
      aux_emit_verbatim_goal[$t]=$(echo "$aux_pending_json" | jq -r '.verbatim_goal // ""')
      aux_clear_pending[$t]="true"
      ;;
    *)
      aux_clear_pending[$t]="true"
      continue
      ;;
  esac
done

# ── AUX EMISSION (Decision 2, Phase 5): build every aux_dispatch[] row decided above IMMEDIATELY,
# here, at the true top of the cycle — BEFORE the all-terminal check, the no-eligible circuit
# breaker, and every other early `emit_and_exit` call below. This placement is load-bearing, not
# cosmetic: a task can become failed_tasks/terminal-for-this-cycle PRECISELY BECAUSE it needs an
# aux escalation (a `blocked` verdict is charged to `failed_tasks` by
# orchestrate-cycle-postflight.sh's own WORK (j) in the SAME cycle its `blocker-research` signal
# is recorded), so building aux rows any later than this would let the all-terminal short-circuit
# silently swallow the very escalation that task needs. `--dry-run` renders the identical choice
# with no side effects; the live branch performs the real dispatch-file build, counter increments,
# and aux_pending/chain-marker consumption -- neither needs `skill-base.sh` or a `cd`, since
# `orchestrate-build-aux-dispatch.sh` resolves its own `SKILL_REPO_ROOT` independently as a
# subprocess. ─────────────────────────────────────────────────────────────────────────────────
aux_fixed_agent() {
  local kind="$1" t="$2"
  case "$kind" in
    drift-inspection|blocker-research) echo "fork" ;;
    plan-revision) echo "reviser-agent" ;;
    divergence-audit) mt_get --arg t "$t" '.research_agents[$t] // "general-research-agent"' ;;
    *) echo "" ;;
  esac
}

if [ "$dry_run" = "true" ]; then
  for t in "${task_args[@]}"; do
    [ -z "${aux_emit_kind[$t]:-}" ] && continue
    aux_agent=$(aux_fixed_agent "${aux_emit_kind[$t]}" "$t")
    out_aux_dispatch_rows+=("$(jq -n -c --argjson t "$t" --arg k "${aux_emit_kind[$t]}" --arg a "$aux_agent" \
      '{task: $t, kind: $k, agent: $a, model: null, dispatch_file: null, orchestrator_mode: false}')")
  done
else
  for t in "${task_args[@]}"; do
    [ -z "${aux_emit_kind[$t]:-}" ] && continue
    aux_kind="${aux_emit_kind[$t]}"
    aux_dispatch_seq=$(mt_get '(.dispatch_seq_counter // 0) + 1')
    aux_dispatch_start_ts=$(date -u +%s)
    mt_set --argjson seq "$aux_dispatch_seq" '.dispatch_seq_counter = $seq'
    # Durable dispatch_seq_counter persistence (same guarantee as the main per-task dispatch
    # loop below, and the SAME reason this call site cannot instead use skill-base.sh's
    # skill_orchestrate_mint_dispatch_seq: this whole aux-emission section runs BEFORE
    # skill-base.sh is sourced later in this script -- see this section's own header comment
    # ("neither needs skill-base.sh or a cd"). --flush-seq is the uniform mechanism used at BOTH
    # mint sites instead, so a repeated dispatch_seq across separate /orchestrate runs can never
    # happen regardless of which loop minted it.
    aux_task_dir_abs="${PROJECT_ROOT}/$(task_lookup_dir "$t" "${project_names[$t]}" "$PROJECT_ROOT")"
    bash "$SCRIPT_DIR/orchestrate-loop-guard-init.sh" --flush-seq "$aux_task_dir_abs" "$aux_dispatch_seq" >/dev/null 2>&1 || true

    build_aux_args=(--session "$session_id" --seq "$aux_dispatch_seq" --dispatch-start-ts "$aux_dispatch_start_ts")
    case "$aux_kind" in
      drift-inspection)
        build_aux_args+=(--plan-path "${aux_emit_plan_path[$t]:-}")
        ;;
      blocker-research)
        build_aux_args+=(--blocker-desc "${aux_emit_blocker_desc[$t]:-Unspecified blocker}")
        ;;
      plan-revision)
        build_aux_args+=(--revision-reason "${aux_emit_revision_reason[$t]}" --plan-path "${aux_emit_plan_path[$t]:-}")
        if [ "${aux_emit_revision_reason[$t]}" = "blocker" ]; then
          build_aux_args+=(--blocker-desc "${aux_emit_blocker_desc[$t]:-Unspecified blocker}" --findings-summary "${aux_emit_findings_summary[$t]:-No findings}")
        else
          build_aux_args+=(--drift-pct "${aux_emit_drift_pct[$t]:-0}" --drift-summary "${aux_emit_drift_summary[$t]:-No summary}")
        fi
        ;;
      divergence-audit)
        aux_research_agent=$(mt_get --arg t "$t" '.research_agents[$t] // "general-research-agent"')
        build_aux_args+=(--target "${aux_emit_target[$t]:-unknown}" --verbatim-goal "${aux_emit_verbatim_goal[$t]:-}" --research-agent "$aux_research_agent")
        ;;
    esac

    if run_capture_stdout aux_dispatch_json bash "$SCRIPT_DIR/orchestrate-build-aux-dispatch.sh" "$t" "$aux_kind" "${build_aux_args[@]}"; then
      aux_build_exit=0
    else
      aux_build_exit=$?
    fi
    if [ "$aux_build_exit" -ne 0 ]; then
      echo "[orchestrate] WARNING: orchestrate-build-aux-dispatch.sh failed for task #$t kind=$aux_kind (exit $aux_build_exit): ${CAPTURE_DIAG:-$aux_dispatch_json}" >&2
      continue
    fi
    aux_file=$(echo "$aux_dispatch_json" | jq -r '.dispatch_file')
    aux_agent=$(echo "$aux_dispatch_json" | jq -r '.agent')
    aux_model=$(echo "$aux_dispatch_json" | jq -r '.model')
    [ -z "$aux_model" ] && aux_model_json="null" || aux_model_json="\"$aux_model\""

    out_aux_dispatch_rows+=("$(jq -n -c --argjson t "$t" --arg k "$aux_kind" --arg a "$aux_agent" \
      --argjson m "$aux_model_json" --arg df "$aux_file" \
      '{task: $t, kind: $k, agent: $a, model: $m, dispatch_file: $df, orchestrator_mode: false}')")

    case "$aux_kind" in
      drift-inspection)
        aux_new_cnt=$(mt_get --arg t "$t" '((.drift_inspection_count[$t] // 0) + 1)')
        mt_set --arg t "$t" --argjson v "$aux_new_cnt" '.drift_inspection_count[$t] = $v'
        ;;
      blocker-research)
        aux_new_cnt=$(mt_get --arg t "$t" '((.blocker_escalation_count[$t] // 0) + 1)')
        mt_set --arg t "$t" --argjson v "$aux_new_cnt" '.blocker_escalation_count[$t] = $v'
        ;;
    esac
  done
  # Consume aux_pending[t] and any chain marker file for every task decided above, whether a row
  # was actually built or the cap/mutual-exclusion guard suppressed it — a suppressed entry must
  # not be re-evaluated every subsequent cycle of this SAME invocation.
  for t in "${task_args[@]}"; do
    if [ "${aux_clear_pending[$t]:-}" = "true" ]; then
      mt_set --arg t "$t" 'del(.aux_pending[$t])'
    fi
    if [ "${aux_consume_blocker_file[$t]:-}" = "true" ]; then
      aux_task_dir_abs2="${PROJECT_ROOT}/$(task_lookup_dir "$t" "${project_names[$t]}" "$PROJECT_ROOT")"
      rm -f "${aux_task_dir_abs2}/.blocker-research.json"
    fi
    if [ "${aux_consume_drift_file[$t]:-}" = "true" ]; then
      aux_task_dir_abs2="${PROJECT_ROOT}/$(task_lookup_dir "$t" "${project_names[$t]}" "$PROJECT_ROOT")"
      rm -f "${aux_task_dir_abs2}/.drift-inspection.json"
    fi
  done
  mt_save
fi

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

# task_has_forced_phase <t> — Decision (a): the exemption predicate that lets a terminal task
# with a pending forced phase reach eligible_tasks, without reordering section (f)'s seeding and
# consumption. Returns 0 (has a pending forced phase) when EITHER the CLI supplied
# --force-phases this invocation (canonical_force_phases_json, computed well above, before
# is_terminal_status is even defined) OR this task already carries a non-empty
# force_phases_remaining[] queue seeded on a prior cycle. Returns 1 otherwise. Only an
# explicitly forced phase may exempt a terminal task from the two guarded `continue`s below —
# ordinary (unforced) dispatch must never reach a terminal task, which is exactly why this
# predicate, not a broader terminal-status change, is the fix.
task_has_forced_phase() {
  local t="$1"
  if [ "$(echo "$canonical_force_phases_json" | jq 'length')" -gt 0 ]; then
    return 0
  fi
  local remaining
  remaining=$(mt_get_json --arg t "$t" '.force_phases_remaining[$t] // []')
  [ "$(echo "$remaining" | jq 'length')" -gt 0 ]
}

# ── (b) All-terminal check ───────────────────────────────────────────────────────────────────────
# Contract: only an explicitly forced phase may admit a terminal task past this check. An
# `/orchestrate` invocation with no forcing flag on a fully terminal set must still stop here.
all_done=true
for t in "${task_args[@]}"; do
  if is_terminal_status "${current_statuses[$t]}" && ! task_has_forced_phase "$t"; then continue; fi
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
# Same contract as (b) immediately above: only an explicitly forced phase may admit a terminal
# task into eligible_tasks; ordinary dispatch never can.
declare -a eligible_tasks=()
declare -A budget_blocked_tasks=()
for t in "${task_args[@]}"; do
  if is_terminal_status "${current_statuses[$t]}" && ! task_has_forced_phase "$t"; then continue; fi
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
  # infra_failures. There is no budget-override flag any more, for this gate or for MAX_CYCLES
  # below -- re-invoking /orchestrate is the only way to continue.
  if [ "${infra_failure_counts[$t]:-0}" -ge "$MAX_INFRA_FAILURES" ]; then
    out_blocked_rows+=("$(jq -n -c --argjson t "$t" --argjson n "${infra_failure_counts[$t]}" --argjson m "$MAX_INFRA_FAILURES" '{task: $t, reason: ("MAX_INFRA_FAILURES reached (" + ($n|tostring) + "/" + ($m|tostring) + " corroborated Agent-tool transport/API failures)")}')")
    continue
  fi

  # Decision (a) — per-RUN cycle budget (this candidate's own cycle_counts[t], starting at zero
  # every run per the (a2) contract above, against max_cycles_per_task[t], re-derived fresh this
  # invocation from --hard). There is no budget-override flag any more, and no override branch:
  # an exhausted per-run budget is a hard stop for this run, and re-invoking /orchestrate (which
  # starts a fresh run, hence a fresh zero-valued cycle count) is the explicit, only way to
  # continue. This replaces the former archive-the-durable-guard-and-reset override branch, which
  # is retired along with the flag that used to authorize it.
  _task_cycle_count=$(mt_get --arg t "$t" '.cycle_counts[$t] // 0')
  _task_max_cycles=$(mt_get --arg t "$t" '.max_cycles_per_task[$t] // 0')
  if [ "$_task_cycle_count" -ge "$_task_max_cycles" ]; then
    budget_blocked_tasks[$t]=1
    out_blocked_rows+=("$(jq -n -c --argjson t "$t" --argjson n "$_task_cycle_count" --argjson m "$_task_max_cycles" '{task: $t, reason: ("MAX_CYCLES reached (" + ($n|tostring) + "/" + ($m|tostring) + " work cycles for this run); re-invoke /orchestrate to continue")}')")
    continue
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
    stop_message="Every remaining task has reached its own per-task work-cycle budget for this run; re-invoke /orchestrate to continue."
  elif [ "$any_stuck" = "true" ]; then
    stop_reason="no_eligible_stuck"
    stop_message="No task is eligible this cycle (all remaining tasks are waiting on in-progress predecessors); waiting for next cycle."
  fi
  emit_and_exit "$cycle_count"
fi

# ── (e) Classification (triage-classify.sh, called once, reused for both phase-map and grouping) ──
triage_classify_args=(mt)
[ -n "${effort_flag:-}" ] && triage_classify_args=(--effort "$effort_flag" mt)
if run_capture_stdout triage_ndjson bash "$SCRIPT_DIR/orchestrate-triage-classify.sh" "${triage_classify_args[@]}" "${eligible_tasks[@]}"; then
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
      # not_started is EFFORT-CONDITIONAL (research-first default, inverted from plan-first --
      # see orchestrate-triage-classify.sh's own header table and the identical live jq row this
      # fallback must stay in lockstep with; the Group 13 parity fixture in
      # tests/test-orchestrate-cycle-plan.sh asserts both effort variants agree with the live
      # classifier). researching stays in the research arm -- that row is load-bearing for the
      # needs_research return path (a task a planner sent back for research must re-enter
      # research, not plan) and is NEVER skipped by --fast (only not_started reads effort).
      # researched/planning are unaffected by effort and still route to plan.
      not_started) if [ "${effort_flag:-}" = "fast" ]; then triage_group[$t]="plan"; else triage_group[$t]="research"; fi ;;
      researching) triage_group[$t]="research" ;;
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
    mt_set --arg t "$t" --argjson q "$canonical_force_phases_json" \
      '.force_phases_remaining[$t] //= $q | .forced_round_seeded[$t] //= true'
  done
fi

declare -A effective_group=()
declare -A forced_this_cycle=()
for t in "${eligible_tasks[@]}"; do
  remaining=$(echo "$mt_json" | jq -c --arg t "$t" '.force_phases_remaining[$t] // []')
  remaining_len=$(echo "$remaining" | jq 'length')
  seeded_this_run=$(echo "$mt_json" | jq -r --arg t "$t" '.forced_round_seeded[$t] // false')
  if [ "$remaining_len" -gt 0 ]; then
    # Queue non-empty -- today's behavior, unchanged.
    forced_phase=$(echo "$remaining" | jq -r '.[0]')
    effective_group[$t]="$forced_phase"
    forced_this_cycle[$t]="true"
  elif [ "$seeded_this_run" = "true" ]; then
    # Queue empty AND this run itself seeded it (as opposed to a task that was simply never
    # forced this run) -- every phase this run's --research/--plan/--implement flag named has
    # already been dispatched. This is THE fix: stop, do not fall through to triage_group[$t]'s
    # ordinary status-derived routing. See the bucketing step below for the blocked[] row this
    # verdict produces.
    effective_group[$t]="forced_round_complete"
    forced_this_cycle[$t]="false"
  else
    # Never forced this run (no --force-phases flag was given, or this task was not named by
    # it) -- ordinary status-derived routing, byte-for-byte unchanged from before this fix.
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
if run_capture_stdout admit_ndjson bash "$SCRIPT_DIR/orchestrate-batch-admit.sh" "${admit_args[@]}" "${eligible_tasks[@]}"; then
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
    forced_round_complete)
      # Phase 3 (stop after the last forced phase): this run's --force-phases queue for this task
      # was seeded THIS run and has since been emptied by dispatching every phase it named --
      # never routed by status. Sits here in the bucketing step, strictly BEFORE the lock probe,
      # dispatch_seq mint, skill_preflight_update, orchestrate-build-dispatch.sh and the cycle
      # charge below -- so no lock, no dispatch file, no status write and no cycle charge happen
      # for this task this cycle, by construction (this `continue` exits the loop before any of
      # them run). Decision (D4): blocked[], not a new top-level excluded[] array -- blocked[]
      # already carries no-defect-just-a-rule reasons (see MAX_CYCLES above) and needs no schema
      # change in orchestrate-cycle-postflight.sh or SKILL.md Moves 2-4 (both already treat any
      # blocked[] row as an inert, non-fatal per-task terminal-for-this-cycle outcome).
      out_blocked_rows+=("$(jq -n -c --argjson t "$t" \
        '{task: $t, reason: "forced round complete: every phase named by this run'"'"'s --research/--plan/--implement flag has been dispatched; this task is terminal for this run. Re-invoke /orchestrate to continue."}')")
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

  # Phase 5 (artifact-based admission): a forced implement with NO plan artifact -- blocked, not
  # dispatched. PRECEDENCE (stated once, honored by construction): the `forced_round_complete`
  # case arm above already `continue`d any task whose forced queue emptied THIS run, so a task
  # reaching this point was either never forced, or is still mid-queue -- the two exclusion paths
  # (Phase 3's forced-round-complete and this Phase 5 no-plan check) can never both claim the same
  # candidate in the same cycle. Sits strictly BEFORE the lock probe, dispatch_seq mint,
  # skill_preflight_update and orchestrate-build-dispatch.sh below, so no lock, dispatch file, or
  # status write happens for a candidate excluded here.
  if [ "$g" = "implement" ] && [ "${forced_this_cycle[$t]:-false}" = "true" ]; then
    _p5_task_dir_abs="${PROJECT_ROOT}/$(task_lookup_dir "$t" "${project_names[$t]}" "$PROJECT_ROOT")"
    if ! ls "${_p5_task_dir_abs}/plans/"*.md >/dev/null 2>&1; then
      out_blocked_rows+=("$(jq -n -c --argjson t "$t" '{task: $t, reason: "no plan artifact; run --plan first"}')")
      continue
    fi
  fi

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
# Phase 5 (artifact-based plan admission): the `plan)` arm below takes a THIRD argument,
# task_number, so it can check for an existing plan artifact and choose reviser-agent (revise) vs.
# planner-agent (author) accordingly -- the whole admission rule for plan is "always admitted;
# which agent depends only on whether plans/*.md already exists", never a status check. Every
# call site below is updated to pass task_number as the new third positional argument;
# command-route-agent.sh (the `research`/`implement` path) is UNCHANGED and never consulted for
# `plan` -- confirmed by this arm's own early `return` before reaching that source line.
resolve_agent() {
  local op="$1" ttype="$2" tasknum="${3:-}"
  case "$op" in
    plan)
      if [ -n "$tasknum" ] && [ -n "${project_names[$tasknum]:-}" ]; then
        local _ra_task_dir_abs
        _ra_task_dir_abs="${PROJECT_ROOT}/$(task_lookup_dir "$tasknum" "${project_names[$tasknum]}" "$PROJECT_ROOT")"
        if ls "${_ra_task_dir_abs}/plans/"*.md >/dev/null 2>&1; then
          echo "reviser-agent"; return
        fi
      fi
      echo "planner-agent"; return
      ;;
  esac
  local default_agent="general-research-agent"
  [ "$op" = "implement" ] && default_agent="general-implementation-agent"
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/command-route-agent.sh" "$op" "$ttype" "$default_agent" "${effort_flag:-}"
  echo "$AGENT_NAME"
}

# ── Phase 1 (focus-prompt threading): compose ONE --focus value from up to two labelled
# segments, shared verbatim by both the --dry-run row builder below and section (l)'s live
# build_args composition, so there is exactly one computation of this value, never two
# independently-maintained ones. Order: "From the user: <focus_prompt>" (any phase, whenever
# --focus was non-empty) then "Research questions: <joined research_questions>" (research phase
# only). The "Research questions:" label is added ONLY when the user segment is also present —
# with no --focus given, a research task's own research_questions renders as the bare joined
# string, byte-for-byte identical to the pre-Phase-1 output (see Decision D1/D2 in the plan).
compose_focus() {
  local task_num="$1" phase="$2"
  local user_seg="" research_seg="" rq=""
  if [ -n "$focus_prompt" ]; then
    user_seg="From the user: ${focus_prompt}"
  fi
  if [ "$phase" = "research" ]; then
    rq=$(jq -r --argjson num "$task_num" \
      '.active_projects[] | select(.project_number == $num) | .research_questions // [] | if (type == "array") then . else [] end | join("; ")' \
      "$STATE_FILE" 2>/dev/null) || rq=""
    if [ -n "$rq" ]; then
      if [ -n "$user_seg" ]; then
        research_seg="Research questions: ${rq}"
      else
        research_seg="$rq"
      fi
    fi
  fi
  if [ -n "$user_seg" ] && [ -n "$research_seg" ]; then
    printf '%s\n%s' "$user_seg" "$research_seg"
  elif [ -n "$user_seg" ]; then
    printf '%s' "$user_seg"
  else
    printf '%s' "$research_seg"
  fi
}

# ── Sibling territory (base mode AND hard mode; the task that carries concurrent-sibling
# territory into base-mode dispatch briefs) — a dispatch file is the ONLY channel that reaches a
# dispatched agent once it is running: a message sent to a live dispatch does not arrive until
# after it finishes (see context/patterns/dispatch-report-not-termination.md). Before this task,
# `--territory` was populated ONLY for a hard-mode implement candidate's own H1/H7 "which files do
# I own within my own plan" fact — cross-TASK concurrency within one batch (two DIFFERENT tasks
# dispatched the same cycle, onto the SAME shared working tree) was invisible to every dispatch,
# in every mode, because nothing computed or carried it. This section closes that gap: it builds a
# `concurrent_siblings` payload for EVERY dispatch this cycle builds, in EVERY mode, whenever the
# cycle schedules more than one task. A single-task cycle schedules no siblings, so
# `build_sibling_territory` returns the empty string and the resulting dispatch file is
# byte-identical to one built before this feature existed (the Phase 3 fixture's regression case).
#
# Payload shape (passed opaquely to orchestrate-build-dispatch.sh's own --territory flag, which
# already renders whatever JSON it is given under "## Territory" — see that script's own header;
# this script never re-implements that rendering):
#   {"concurrent_siblings": [{"task_number": N, "phase": "research"|"plan"|"implement",
#     "file_scope": [...]|null, "scope_declared": true|false,
#     "scope_granularity": "file"|"coarse"|"undeclared",
#     "entries": [{"path": "...", "granularity": "file"|"directory"|"glob"}, ...],
#     "note": "..."|null}, ...],
#    "concurrency_note": "..."}
#
# Granularity (Decision 3 of the originating plan): a `file_scope` entry is "directory" when it
# ends in "/" or already names an existing directory relative to the repo root, "glob" when it
# contains `*`, `?`, or `[`, else "file". A sibling's roll-up `scope_granularity` is "file" only
# when every entry is "file"; any directory/glob entry makes it "coarse"; an absent, null, or
# empty `file_scope` makes it "undeclared" — rendered explicitly, never dropped from the list, per
# Decision 3: a sibling with no declared scope is exactly the failure mode both incidents in this
# task's own description trace back to. A "coarse" or "undeclared" sibling's `note` field warns
# that it may touch any file (within its declared directory/glob, or anywhere at all when
# undeclared); a "file"-granularity sibling's `note` is `null`.
#
# Absent-file_scope ADMISSION POSTURE is explicitly NOT decided here (Decision 4): whether an
# absent or coarse `file_scope` should defer admission in the first place belongs to the separate,
# already-filed work scoped to `orchestrate-batch-admit.sh`'s own admission gate. This payload only
# REPRESENTS the absence/coarseness so a dispatched agent can see and react to it; this task
# consumes whatever that separate work rules and does not edit `orchestrate-batch-admit.sh`.
#
# aux_dispatch[] rows (built earlier, above, by orchestrate-build-aux-dispatch.sh — see the AUX
# EMISSION section) are DELIBERATELY EXCLUDED from `concurrent_siblings`, confirmed rather than
# assumed: that builder has no `--territory` plumbing at all, and every aux kind
# (blocker-research, drift-inspection, plan-revision, divergence-audit) is a short, single-purpose
# research/revision call that never loops over a task's own `file_scope` editing files the way an
# implement dispatch does — the file-collision risk this payload guards against does not apply to
# it. A future task may extend `--territory` plumbing to that builder; this one does not.
#
# Sequencing rationale (Decision 5) is deliberately GENERIC, never per-pair: nothing in this
# codebase computes non-idempotence between two specific tasks, so `concurrency_note` carries one
# fixed procedural instruction (re-read a shared file immediately before editing it, stage only
# this task's own hunks, never run a reverting git-snapshot.sh, treat a foreign-scope build
# failure as possibly a sibling's in-flight edit rather than your own regression, and STOP-and-
# report on foreign work only after a `git log` self-check) instead of a fabricated claim about
# which specific pair of tasks will actually collide.
#
# Over-inclusion is intentional (Decision 6): a dispatch file is built before later same-cycle
# siblings acquire their own locks, so a sibling later deferred by this same live loop may still
# be named here. The wording says "scheduled concurrently this cycle", never "running" — naming a
# sibling that ends up deferred is a false positive an agent can dismiss with one `git log` check;
# silently omitting one that IS running is the failure mode this whole task exists to close.
_sibling_territory_classify_entry() {
  # <path> -> echoes "file" | "directory" | "glob" (Decision 3's granularity vocabulary).
  local path="$1"
  case "$path" in
    */) echo "directory"; return ;;
    *[*?\[]*) echo "glob"; return ;;
  esac
  if [ -d "${PROJECT_ROOT}/${path}" ]; then
    echo "directory"
  else
    echo "file"
  fi
}

build_sibling_territory() {
  # build_sibling_territory <self_task> <sibling_task_number>...
  # Echoes the compact JSON object described in the header block above, or the empty string when
  # the sibling list is empty (caller skips the --territory flag entirely in that case — the
  # empty-value-skips-flag convention this script already uses everywhere else). Reuses
  # `lookup_project` (this script's own active+archive task lookup, defined above) rather than a
  # second hand-written jq query against $STATE_FILE — Finding 2/Rec 2 of the originating report:
  # no new discovery mechanism is needed.
  local self_t="$1"; shift
  local -a siblings=("$@")
  [ "${#siblings[@]}" -eq 0 ] && { printf ''; return 0; }

  local -a sibling_rows=()
  local s sib_phase sib_entry sib_scope_json sib_declared sib_gran sib_note path gran entries_json entry_json
  for s in "${siblings[@]}"; do
    # Defense in depth: every live call site already excludes $self_t from the list it builds,
    # but a self-referential entry here would be a confusing "you are your own sibling" payload,
    # so skip it defensively rather than trust every future call site to get the exclusion right.
    [ "$s" = "$self_t" ] && continue
    sib_phase="${effective_group[$s]:-unknown}"
    sib_entry=$(lookup_project "$s") || sib_entry=""
    if [ -z "$sib_entry" ] || [ "$sib_entry" = "null" ]; then
      sib_scope_json="null"
    else
      sib_scope_json=$(echo "$sib_entry" | jq -c '.file_scope // null')
    fi

    local -a sib_entries=()
    if [ "$sib_scope_json" = "null" ] || [ "$sib_scope_json" = "[]" ]; then
      sib_declared="false"
      sib_gran="undeclared"
      sib_note="No file_scope declared for this task -- it may touch any file in the repository."
    else
      sib_declared="true"
      sib_gran="file"
      while IFS= read -r path; do
        [ -z "$path" ] && continue
        gran=$(_sibling_territory_classify_entry "$path")
        [ "$gran" != "file" ] && sib_gran="coarse"
        sib_entries+=("$(jq -n -c --arg p "$path" --arg g "$gran" '{path: $p, granularity: $g}')")
      done < <(echo "$sib_scope_json" | jq -r '.[]')
      if [ "$sib_gran" = "coarse" ]; then
        sib_note="Declared file_scope includes a directory or glob entry -- this task may touch any file within it."
      else
        sib_note=""
      fi
    fi

    entries_json="[]"
    [ "${#sib_entries[@]}" -gt 0 ] && entries_json="[$(IFS=,; echo "${sib_entries[*]}")]"

    entry_json=$(jq -n -c --argjson t "$s" --arg p "$sib_phase" --argjson fs "$sib_scope_json" \
      --argjson decl "$([ "$sib_declared" = "true" ] && echo true || echo false)" \
      --arg g "$sib_gran" --argjson e "$entries_json" --arg note "$sib_note" \
      '{task_number: $t, phase: $p, file_scope: $fs, scope_declared: $decl, scope_granularity: $g,
        entries: $e, note: (if $note == "" then null else $note end)}')
    sibling_rows+=("$entry_json")
  done

  local siblings_json
  siblings_json="[$(IFS=,; echo "${sibling_rows[*]}")]"
  local note
  note='One or more sibling tasks are scheduled for dispatch THIS SAME /orchestrate cycle, on this same shared working tree. Before editing or committing any file: (1) re-read it immediately beforehand, in case a sibling has already changed it; (2) stage and commit only this task'"'"'s own hunks, never a directory or glob add; (3) never run git-snapshot.sh in its reverting default mode; (4) treat an unexpected build failure in a file outside your own file_scope as possibly a sibling'"'"'s in-flight edit, not necessarily your own regression; (5) if you observe a foreign commit, a foreign uncommitted modification, or a running build you did not start, STOP and report it -- after checking git log to confirm the work is not your own -- rather than proceeding or dismissing it as noise. See context/contracts/territory.md (Cross-Task Territory section) and context/patterns/dispatch-report-not-termination.md.'
  jq -n -c --argjson sibs "$siblings_json" --arg note "$note" '{concurrent_siblings: $sibs, concurrency_note: $note}'
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
  h1_task_dir_abs="${PROJECT_ROOT}/$(task_lookup_dir "$t" "$h1_project_name" "$PROJECT_ROOT")"
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
    agent=$(resolve_agent "$g" "${task_types[$t]}" "$t")
    dry_force_json="false"; [ "${forced_this_cycle[$t]:-false}" = "true" ] && dry_force_json="true"
    dry_focus=$(compose_focus "$t" "$g")
    out_dispatch_rows+=("$(jq -n -c --argjson t "$t" --arg p "$g" --arg a "$agent" --argjson force "$dry_force_json" --arg focus "$dry_focus" \
      '{task: $t, phase: $p, agent: $a, model: null, dispatch_file: null, force: $force, focus: $focus}')")
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
  task_dir_rel="$(task_lookup_dir "$t" "$project_name" "$SKILL_REPO_ROOT")"
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

  # Unwind-support capture (`orchestrate-unwind-dispatch.sh`'s Phase 1 pre-image): the LAST
  # read of this task's state.json entry before the preflight write below overwrites
  # status/last_updated/session_id. Empty string when the entry or field is absent (mirrors the
  # rest of this script's `// ""` convention). This is deliberately a fresh `lookup_project` call
  # rather than a reuse of the early `current_statuses[$t]` capture near the top of this script:
  # only this call site also has `last_updated`/`session_id` in scope, and nothing durably writes
  # this task's own state.json entry between here and `skill_preflight_update` below.
  _pd_prior_entry=$(lookup_project "$t") || _pd_prior_entry=""
  _pd_prior_status=$(printf '%s' "$_pd_prior_entry" | jq -r '.status // ""' 2>/dev/null) || _pd_prior_status=""
  _pd_prior_last_updated=$(printf '%s' "$_pd_prior_entry" | jq -r '.last_updated // ""' 2>/dev/null) || _pd_prior_last_updated=""
  _pd_prior_session_id=$(printf '%s' "$_pd_prior_entry" | jq -r '.session_id // ""' 2>/dev/null) || _pd_prior_session_id=""

  # (j) Preflight status write. update-task-status.sh confirms on stdout; the entry-point
  # `exec 3>&1 1>&2` redirect above already routes fd 1 (this call's stdout) to the diagnostic
  # stream structurally, so no per-call-site `>&2` is needed here any more.
  # Phase 4 (Decision (b)): a forced round on a terminal task must never regress its status.
  # "monotonic-max" is passed ONLY when this cycle's dispatch is forced; an ordinary dispatch
  # passes the empty string, preserving today's exact preflight-write behavior byte-for-byte.
  preflight_clamp_mode=""
  [ "${forced_this_cycle[$t]:-false}" = "true" ] && preflight_clamp_mode="monotonic-max"
  skill_preflight_update "$t" "$g" "$dispatch_session" "$preflight_clamp_mode"

  # (l) orchestrate-build-dispatch.sh — Stage 3.5 Dispatch Prep's sole implementation.
  build_args=(--session "$dispatch_session" --seq "$task_dispatch_seq" --dispatch-start-ts "$task_dispatch_start_ts")
  [ "$clean_flag" = "true" ] && build_args+=(--clean)
  [ "$lit_flag" = "true" ] && build_args+=(--lit)
  [ "$compare_flag" = "true" ] && [ "$g" = "implement" ] && build_args+=(--compare)
  [ "$hard_mode" = "true" ] && build_args+=(--hard)
  [ "${effort_flag:-}" = "fast" ] && build_args+=(--fast)
  [ -n "$model_flag" ] && build_args+=(--model "$model_flag")
  # Phase 3 (Defect 3): a forced dispatch against an already-terminal task must survive
  # skill_validate_input's terminal-state gate inside orchestrate-build-dispatch.sh. Empty-value-
  # skips-flag, same convention as every other flag above: an ordinary (unforced) dispatch never
  # sets forced_this_cycle[$t], so this never appends for it.
  [ "${forced_this_cycle[$t]:-false}" = "true" ] && build_args+=(--allow-terminal)
  # --phase-number (H1, Phase 4): only ever set for a hard-mode implement candidate whose
  # heading-scan selected a phase this cycle — absent from every base-mode call and from a
  # hard-mode implement candidate that fell through to ordinary status-derived dispatch (no open
  # heading found, not inconclusive). Unlike --territory immediately below, --phase-number stays
  # hard-mode-implement-only: it names a within-plan phase number that base mode's ordinary
  # status-derived dispatch has no equivalent of.
  [ -n "${h1_next_phase[$t]:-}" ] && build_args+=(--phase-number "${h1_next_phase[$t]}")
  # --territory: NO LONGER hard-mode-only (see the "Sibling territory" header block above this
  # loop for the full contract). Built fresh for THIS task from every OTHER task
  # `probed_dispatch_post_h1` schedules this same cycle, in every mode. When this task is also a
  # hard-mode implement candidate with its own H1/H7 owned-files literal, the sibling payload is
  # MERGED into that same JSON object under a `concurrent_siblings` key (Decision 1) rather than
  # replacing it, so hard mode gains this cross-task fact too instead of it staying a base-mode-only
  # feature by another name. Empty-value-skips-flag: a single-task cycle (no siblings) and no H1
  # territory together produce no --territory flag at all, byte-identical to a build before this
  # feature existed.
  declare -a _sibling_tasks=()
  for _sib_t in "${probed_dispatch_post_h1[@]}"; do
    [ "$_sib_t" != "$t" ] && _sibling_tasks+=("$_sib_t")
  done
  sibling_territory_json=$(build_sibling_territory "$t" "${_sibling_tasks[@]}")
  territory_arg=""
  if [ -n "${h1_territory[$t]:-}" ]; then
    if [ -n "$sibling_territory_json" ]; then
      territory_arg=$(jq -n -c --argjson base "${h1_territory[$t]}" --argjson sibs "$sibling_territory_json" \
        '$base + {concurrent_siblings: $sibs.concurrent_siblings}')
    else
      territory_arg="${h1_territory[$t]}"
    fi
  else
    territory_arg="$sibling_territory_json"
  fi
  [ -n "$territory_arg" ] && build_args+=(--territory "$territory_arg")
  # --focus wiring (Phase 1): compose the user's own --focus text (any phase, from
  # orchestrate-cycle-plan.sh's own --focus flag) with the task's research_questions
  # (research phase only, unchanged source field) via the shared compose_focus() helper --
  # exactly one computation of this value, reused by the --dry-run row builder above. Pass
  # --focus only when the composed value is non-empty (empty-value-skips-flag, the same
  # convention every other flag in this block already uses); orchestrate-build-dispatch.sh's
  # already-built, already phase-gated --focus flag renders it into the dispatch file's
  # "User focus:" block -- no code change inside that script is needed. A task with neither a
  # user focus string nor research_questions (an ordinary not_started->research dispatch, or a
  # non-research phase with no --focus given) passes no --focus flag at all -- byte-for-byte
  # no-op, matching the pre-Phase-1 behavior exactly.
  task_composed_focus=$(compose_focus "$t" "$g")
  if [ -n "$task_composed_focus" ]; then
    build_args+=(--focus "$task_composed_focus")
  fi
  if run_capture_stdout dispatch_json bash "$SCRIPT_DIR/orchestrate-build-dispatch.sh" "$t" "$g" "${build_args[@]}"; then
    build_exit=0
  else
    build_exit=$?
  fi
  if [ "$build_exit" -ne 0 ]; then
    echo "[orchestrate] WARNING: orchestrate-build-dispatch.sh failed for task #$t (exit $build_exit): ${CAPTURE_DIAG:-$dispatch_json}" >&2
    out_deferred_rows+=("$(jq -n -c --argjson t "$t" '{task: $t, reason: "orchestrate-build-dispatch.sh failed; deferring to a later cycle"}')")
    continue
  fi
  dispatch_file=$(echo "$dispatch_json" | jq -r '.dispatch_file')
  dispatch_model=$(echo "$dispatch_json" | jq -r '.model')
  [ -z "$dispatch_model" ] && dispatch_model_json="null" || dispatch_model_json="\"$dispatch_model\""

  agent=$(resolve_agent "$g" "${task_types[$t]}" "$t")
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
  #
  # Item (b), durable CROSS-invocation half (the in-session half is the plan_cache replay near
  # the top of this script, which already short-circuits the trivial "re-run this exact
  # composition with nothing new" case before this point is ever reached again within one
  # session). Before charging: does pending_dispatch_seed[$t] -- seeded above from the durable
  # guard file, i.e. potentially written by a DIFFERENT, now-defunct session -- describe THIS
  # exact row (same phase, same forced flag) AND does its recorded dispatch_file still exist on
  # disk (proof no postflight ever consumed it -- postflight clears pending_dispatch as its own
  # first act on any outcome)? If so, this is a replay of an already-charged-but-never-consumed
  # dispatch: reuse the recorded seq (so a postflight dispatch_seq check against that prior,
  # still-live attempt's own artifacts keeps matching), skip the increment, skip the --flush.
  # Otherwise charge as today and record the new pending_dispatch.
  _pd_forced_this_cycle="${forced_this_cycle[$t]:-false}"
  _pd_replay=false
  if [ -n "${pending_dispatch_seed[$t]:-}" ]; then
    _pd_phase=$(printf '%s' "${pending_dispatch_seed[$t]}" | jq -r '.phase // ""')
    _pd_forced=$(printf '%s' "${pending_dispatch_seed[$t]}" | jq -r '.forced // false')
    _pd_dispatch_file=$(printf '%s' "${pending_dispatch_seed[$t]}" | jq -r '.dispatch_file // ""')
    if [ "$_pd_phase" = "$g" ] && [ "$_pd_forced" = "$_pd_forced_this_cycle" ] && \
       [ -n "$_pd_dispatch_file" ] && [ -f "$_pd_dispatch_file" ]; then
      _pd_replay=true
    fi
  fi
  if [ "$_pd_replay" = "true" ]; then
    _pd_seq=$(printf '%s' "${pending_dispatch_seed[$t]}" | jq -r '.seq')
    mt_set --arg t "$t" --argjson seq "$_pd_seq" '.dispatch_seq[$t] = $seq'
    task_dispatch_seq="$_pd_seq"
    task_new_cycle_count=$(mt_get --arg t "$t" '(.cycle_counts[$t] // 0)')
    echo "[orchestrate] UNCONSUMED DISPATCH REPLAY: task #$t's $g dispatch (seq=$_pd_seq) was already charged by a prior invocation and never consumed (its recorded dispatch_file still exists on disk) -- reusing that charge instead of charging again." >&2
  else
    task_new_cycle_count=$(mt_get --arg t "$t" '((.cycle_counts[$t] // 0) + 1)')
    mt_set --arg t "$t" --argjson v "$task_new_cycle_count" '.cycle_counts[$t] = $v'
    # Per-run cycle-budget contract: durable `cycle_count` is no longer flushed here (the budget
    # itself never persists past this run). What DOES still need a durable flush is
    # `dispatch_seq_counter` -- this task's own mt_json.dispatch_seq_counter was already minted
    # (incremented) at section (i) above, at exactly `task_dispatch_seq`; persist that same value
    # now via --flush-seq so a LATER run's own (a2) seeding sees it and never mints a repeat.
    bash "$SCRIPT_DIR/orchestrate-loop-guard-init.sh" --flush-seq "$task_dir_abs" "$task_dispatch_seq" >/dev/null 2>&1 || true
    # Unwind-support pre-image (`orchestrate-unwind-dispatch.sh`'s Phase 1): the four `prior_*`
    # fields below are the ONLY input the unwind script needs beyond what pending_dispatch already
    # carried -- the pre-dispatch status triple (captured just above, immediately before
    # skill_preflight_update overwrote it) and the durable dispatch_seq_counter as it stood before
    # THIS charge's own --flush-seq call just above (captured earlier still, in the (a2)-adjacent
    # seed loop at the top of this script -- the earliest point that reads this task's durable
    # guard file this run). Recorded only on this non-replay path: a replay branch (above) reuses
    # an existing pending_dispatch record verbatim and must never overwrite its pre-image with the
    # CURRENT (already in-flight) status.
    _pd_prior_seq_counter="${pd_prior_dsc[$t]:-0}"
    _pd_record_json=$(jq -n -c --argjson seq "$task_dispatch_seq" --arg phase "$g" \
      --argjson forced "$_pd_forced_this_cycle" --arg df "$dispatch_file" \
      --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg prior_status "$_pd_prior_status" --arg prior_last_updated "$_pd_prior_last_updated" \
      --arg prior_session_id "$_pd_prior_session_id" --argjson prior_dsc "$_pd_prior_seq_counter" \
      '{seq: $seq, phase: $phase, forced: $forced, dispatch_file: $df, recorded_at: $ts,
        prior_status: $prior_status, prior_last_updated: $prior_last_updated,
        prior_session_id: $prior_session_id, prior_dispatch_seq_counter: $prior_dsc}')
    bash "$SCRIPT_DIR/orchestrate-loop-guard-init.sh" --record-pending "$task_dir_abs" "$_pd_record_json" >/dev/null 2>&1 || true
  fi

  # `force` (Phase 7 addition, orchestrate-cycle-postflight.sh's --force-invoked wiring): this is
  # the ONLY point in the whole per-cycle pipeline where "was this task's phase forced this
  # cycle" is known -- forced_this_cycle[$t] was computed above (per-candidate force_phases
  # consumption) and the queue is popped just above this row, so by the time Stage MT-4 reads
  # this row back the pop has already happened and the information would otherwise be lost.
  # Threading it through the row (rather than recomputing it downstream) is the same shape as
  # every other per-task field this row already carries.
  force_json="false"; [ "${forced_this_cycle[$t]:-false}" = "true" ] && force_json="true"
  out_dispatch_rows+=("$(jq -n -c --argjson t "$t" --arg p "$g" --arg a "$agent" --argjson dm "$dispatch_model_json" --arg df "$dispatch_file" --argjson force "$force_json" --arg focus "$task_composed_focus" \
    '{task: $t, phase: $p, agent: $a, model: $dm, dispatch_file: $df, force: $force, focus: $focus}')")
done

mt_set --argjson c "$new_cycle_count" '.cycle_count = $c'
mt_save

emit_and_exit "$new_cycle_count"
