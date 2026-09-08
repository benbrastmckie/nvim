#!/usr/bin/env bash
# system-defect-record.sh - Turn a detected agent-system defect into a durable, deduplicated
# event_type: "system_defect" / category: "deviation" row on specs/events.jsonl.
#
# Encodes (never re-derives) the predicate, recursion guard, and dedup rule from
# context/patterns/system-defect-discrimination.md. See that document for the full contract this
# script is a thin, house-style wrapper implementing.
#
# Usage:
#   system-defect-record.sh --defect-class CLASS --detecting-site SITE --message "..." \
#     (--attributed-path PATH | --dispatched-agent NAME) \
#     [--attributed-path PATH] [--dispatched-agent NAME] [--task N] [--session SESSION_ID] \
#     [--cwd PATH] [--cc-session-id VALUE] [--extra-detail-json '{...}']
#
# Required:
#   --defect-class CLASS   One of the fourteen Signal A instances (see the discrimination document's
#                           Signal A table) -- validated against a closed enum, failing loudly on
#                           an unknown value.
#   --detecting-site SITE  Free-text identifying the call site (e.g.
#                           "skill-orchestrate/SKILL.md:cycle-postflight-tier-c").
#   --message "..."        Short human-readable one-line summary.
#   --attributed-path / --dispatched-agent
#                           At least one is required (Signal B attribution). When both are given,
#                           --attributed-path wins. --attributed-path may be a deploy path
#                           (.claude/X or .claude/extensions/<ext>/X) -- it is transformed to its
#                           source-store equivalent automatically. --dispatched-agent NAME is
#                           resolved mechanically to agent-system/extensions/<ext>/agents/<NAME>.md
#                           by globbing the source store.
#
# Optional:
#   --task N                Bare (unpadded) task/project number, threaded through to
#                            events-append.sh unchanged.
#   --session SESSION_ID    sess_{timestamp}_{random} value. When absent, one is synthesized
#                            (see D5 below) and the real Claude Code session id, if any, should be
#                            passed separately via --cc-session-id.
#   --cwd PATH               Invoking working directory (provenance only; never redirects the
#                            write -- see the header note on PROJECT_ROOT below).
#   --cc-session-id VALUE    Claude Code's native session UUID (hook stdin's .session_id),
#                            threaded through as the correlation key when --session is omitted.
#   --extra-detail-json '{...}'
#                            Additional JSON object merged into the detail payload (validated as
#                            parseable JSON first), so a future detector can extend the payload
#                            without reshaping this interface.
#
# --cwd is a provenance field only (mirrors events-append.sh exactly): this script derives its own
# PROJECT_ROOT from its own on-disk SCRIPT_DIR, guarded by deploy-root-guard.sh, and NEVER computes
# or accepts an events.jsonl path. A hook firing in another repo invokes that repo's own deployed
# .claude/scripts/ copy and therefore writes to that repo's own store naturally.
#
# NOT RUNNABLE FROM THE SOURCE STORE: deploy-root-guard.sh (sourced below, and again transitively
# inside events-append.sh) fails loudly when invoked from agent-system/extensions/core/scripts/.
# Deploy first (bash .claude/scripts/deploy-headless.sh, or the picker's [Reload All]/[Regenerate]), then
# exercise the deployed .claude/scripts/system-defect-record.sh copy.
#
# D5 session-id fallback: events-append.sh requires --session. When --session is omitted, this
# script synthesizes one via the shared lib/common.sh common_session_id (sess_<epoch>_<6hex>,
# the codebase's single-source generator -- rules/git-workflow.md) -- and threads any real Claude
# Code UUID through --cc-session-id unchanged as the correlation key. Never invents a fake sess_
# value that could collide with a real one -- the synthesized value is freshly random.
#
# Exit codes:
#   0 - Recorded, or deliberately suppressed with a logged reason.
#       stdout: the event_id (recorded), or "SUPPRESSED:<reason>" (suppressed; reason is
#       "recursion_guard" or "duplicate").
#   1 - Argument/validation error (missing required argument, unknown --defect-class, malformed
#       --extra-detail-json).
#   2 - Refused: recursion status indeterminate. The critical-paths data file is missing or
#       unparseable -- the guard degrades LOUDLY and refuses to record, never silently, never
#       fail-open. Nothing is written.
#   3 - Refused: Signal B attribution unresolvable. Neither --attributed-path nor
#       --dispatched-agent resolved to a path under agent-system/extensions/**. Log only per the
#       discrimination document's governing rule ("detection without attribution must log only,
#       never offer/create a task"). Nothing is written.
#
# Every call site MUST invoke this script non-fatally:
#   bash .claude/scripts/system-defect-record.sh ... >/dev/null 2>&1 || \
#     echo "Note: system-defect recording failed (non-fatal)" >&2
# A recorder failure (any nonzero exit, or the process itself failing) must never break the
# dispatch that invoked it.

set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: system-defect-record.sh --defect-class CLASS --detecting-site SITE --message "..." \
  (--attributed-path PATH | --dispatched-agent NAME) \
  [--attributed-path PATH] [--dispatched-agent NAME] [--task N] [--session SESSION_ID] \
  [--cwd PATH] [--cc-session-id VALUE] [--extra-detail-json '{...}']

Required:
  --defect-class CLASS    One of: OFF_SCHEMA_STATUS|ARTIFACTS_SHAPE_MISMATCH|HANDOFF_MISLOCATED|
                           META_MISSING_AFTER_NARRATION|ARTIFACTS_MISSING_ON_SUCCESS|
                           HANDOFF_STALE_OR_ABSENT|SOURCE_STORE_BOUNDARY_VIOLATION|
                           TASK_REFERENCE_IN_DELIVERABLE|ARTIFACT_FORMAT_VIOLATION|
                           STATE_SYNC_DIVERGENCE|SESSION_LOCK_CONTENTION|
                           HOOK_REGEX_BOUNDARY_DEFECT|DEPLOY_ORPHAN_DRIFT|
                           AMBIENT_BINDING_MISMATCH
  --detecting-site SITE   Free-text identifying the call site
  --message "..."         Short human-readable one-line summary
  --attributed-path PATH / --dispatched-agent NAME
                          At least one is required (Signal B attribution)

Optional:
  --task N                 Bare (unpadded) task/project number
  --session SESSION_ID     sess_{timestamp}_{random} value (synthesized when absent -- see D5)
  --cwd PATH                Invoking working directory (provenance only)
  --cc-session-id VALUE     Claude Code's native session UUID
  --extra-detail-json '{...}'
                             Additional JSON object merged into the detail payload

Exit codes: 0 recorded/suppressed, 1 argument error, 2 recursion status indeterminate,
3 Signal B attribution unresolvable. See this script's header for the full contract.
USAGE
  exit 1
}

# --- Argument parsing ---
defect_class=""
detecting_site=""
message=""
attributed_path_arg=""
dispatched_agent_arg=""
task_arg=""
session_arg=""
cwd_arg=""
cc_session_arg=""
extra_detail_json=""

if [ $# -eq 0 ]; then
  usage
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --defect-class) defect_class="${2:-}"; shift 2 ;;
    --detecting-site) detecting_site="${2:-}"; shift 2 ;;
    --message) message="${2:-}"; shift 2 ;;
    --attributed-path) attributed_path_arg="${2:-}"; shift 2 ;;
    --dispatched-agent) dispatched_agent_arg="${2:-}"; shift 2 ;;
    --task) task_arg="${2:-}"; shift 2 ;;
    --session) session_arg="${2:-}"; shift 2 ;;
    --cwd) cwd_arg="${2:-}"; shift 2 ;;
    --cc-session-id) cc_session_arg="${2:-}"; shift 2 ;;
    --extra-detail-json) extra_detail_json="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "error: unknown argument: $1" >&2; usage ;;
  esac
done

# --- Validate required arguments ---
if [ -z "$defect_class" ] || [ -z "$detecting_site" ] || [ -z "$message" ]; then
  echo "error: --defect-class, --detecting-site, and --message are all required" >&2
  usage
fi

if [ -z "$attributed_path_arg" ] && [ -z "$dispatched_agent_arg" ]; then
  echo "error: at least one of --attributed-path or --dispatched-agent is required" >&2
  usage
fi

# --- Validate --defect-class against the closed, fourteen-value enum (fail loudly, write nothing) ---
case "$defect_class" in
  OFF_SCHEMA_STATUS|ARTIFACTS_SHAPE_MISMATCH|HANDOFF_MISLOCATED|META_MISSING_AFTER_NARRATION|\
  ARTIFACTS_MISSING_ON_SUCCESS|HANDOFF_STALE_OR_ABSENT|SOURCE_STORE_BOUNDARY_VIOLATION|\
  TASK_REFERENCE_IN_DELIVERABLE|ARTIFACT_FORMAT_VIOLATION|STATE_SYNC_DIVERGENCE|\
  SESSION_LOCK_CONTENTION|HOOK_REGEX_BOUNDARY_DEFECT|DEPLOY_ORPHAN_DRIFT|\
  AMBIENT_BINDING_MISMATCH) ;;
  *)
    echo "error: invalid --defect-class '$defect_class' (must be one of the fourteen Signal A instances -- see context/patterns/system-defect-discrimination.md)" >&2
    exit 1
    ;;
esac

# --- Validate --extra-detail-json parses before any further work ---
extra_detail_arg="$extra_detail_json"
if [ -z "$extra_detail_arg" ]; then
  extra_detail_arg='{}'
else
  if ! echo "$extra_detail_arg" | jq -e 'type == "object"' > /dev/null 2>&1; then
    echo "error: --extra-detail-json is not valid JSON (or not a JSON object): $extra_detail_arg" >&2
    exit 1
  fi
fi

# --- Validate --task is an integer if given ---
if [ -n "$task_arg" ]; then
  if ! [[ "$task_arg" =~ ^[0-9]+$ ]]; then
    echo "error: --task must be a bare integer, got: $task_arg" >&2
    exit 1
  fi
fi

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
# Fail CLOSED (never fall back to an inline copy or skip the check) if the shared overlap-
# predicate lib is unsourceable -- same idiom as orchestrate-batch-admit.sh and task-lock.sh.
if ! . "${SCRIPT_DIR}/lib/file-scope-overlap.sh" 2>/dev/null; then
  echo "[SYSTEM-DEFECT RECORDER] REFUSING: could not source ${SCRIPT_DIR}/lib/file-scope-overlap.sh (recursion status indeterminate). No record written." >&2
  exit 2
fi
CRITICAL_PATHS_FILE="$SCRIPT_DIR/../context/reference/orchestrator-critical-paths.json"
STATE_FILE="$PROJECT_ROOT/specs/state.json"

# ─── Signal B: attribution resolution ────────────────────────────────────────────────────────
# .claude/X -> agent-system/extensions/core/X ; .claude/extensions/<ext>/X -> agent-system/extensions/<ext>/X
transform_deploy_to_source() {
  local p="$1"
  case "$p" in
    .claude/extensions/*)
      local rest="${p#.claude/extensions/}"
      echo "agent-system/extensions/${rest}"
      ;;
    .claude/*)
      local rest="${p#.claude/}"
      echo "agent-system/extensions/core/${rest}"
      ;;
    *)
      echo "$p"
      ;;
  esac
}

resolved_path=""
if [ -n "$attributed_path_arg" ]; then
  resolved_path="$(transform_deploy_to_source "$attributed_path_arg")"
elif [ -n "$dispatched_agent_arg" ]; then
  shopt -s nullglob
  agent_matches=("$PROJECT_ROOT"/agent-system/extensions/*/agents/"${dispatched_agent_arg}.md")
  shopt -u nullglob
  if [ "${#agent_matches[@]}" -gt 0 ] && [ -f "${agent_matches[0]}" ]; then
    resolved_path="${agent_matches[0]#"$PROJECT_ROOT"/}"
  fi
fi

case "$resolved_path" in
  agent-system/extensions/*) ;;
  *)
    echo "[SYSTEM-DEFECT RECORDER] REFUSING: Signal B attribution unresolvable (attributed-path='${attributed_path_arg}' dispatched-agent='${dispatched_agent_arg}' did not resolve to a path under agent-system/extensions/**). Log only, no record." >&2
    exit 3
    ;;
esac

# ─── Recursion guard ──────────────────────────────────────────────────────────────────────────
# Degrades LOUDLY (never silently, never fail-open) when the data file is missing or unparseable.
if [ ! -f "$CRITICAL_PATHS_FILE" ]; then
  echo "[SYSTEM-DEFECT RECORDER] REFUSING: recursion status indeterminate (critical-paths data file not found at $CRITICAL_PATHS_FILE). No record written." >&2
  exit 2
fi

critical_raw_json="$(jq -c '.' "$CRITICAL_PATHS_FILE" 2>/dev/null)" || {
  echo "[SYSTEM-DEFECT RECORDER] REFUSING: recursion status indeterminate (critical-paths data file at $CRITICAL_PATHS_FILE is unparseable). No record written." >&2
  exit 2
}
if [ -z "$critical_raw_json" ] || [ "$critical_raw_json" = "null" ]; then
  echo "[SYSTEM-DEFECT RECORDER] REFUSING: recursion status indeterminate (critical-paths data file at $CRITICAL_PATHS_FILE parsed to empty/null). No record written." >&2
  exit 2
fi

scope_roots_json="$(jq -c '.scope_roots // []' <<<"$critical_raw_json" 2>/dev/null)" || scope_roots_json="[]"
guard_crit_json="$(jq -c '[.critical_paths[]? | select(.recursion_guard == true) | {path, label}]' <<<"$critical_raw_json" 2>/dev/null)" || guard_crit_json="[]"

# Normalize the attributed path by stripping any leading scope_roots prefix before matching
# (registry entries are scope-root-relative; attributed paths are repo-relative).
normalized_attributed_path="$(jq -rn --arg p "$resolved_path" --argjson roots "$scope_roots_json" '
  ($roots | map(. as $r | select($p == $r or ($p | startswith($r + "/"))))) as $hit |
  if ($hit | length) > 0 then ($p | ltrimstr(($hit[0]) + "/")) else $p end
')"

sm_hit="$(jq -cn \
  --argjson cscope "[\"$normalized_attributed_path\"]" \
  --argjson crit "$guard_crit_json" \
  "${FILE_SCOPE_OVERLAP_JQ_DEFS}"'
  self_mod_match($cscope; $crit)
')"

if [ "$sm_hit" != "null" ]; then
  hit_label="$(jq -r '.label // .path' <<<"$sm_hit")"
  echo "[SYSTEM-DEFECT RECORDER] SUPPRESSED: attributed path '$resolved_path' matches a recursion-guarded pipeline file ('$hit_label') -- not recording a defect against the recording pipeline itself." >&2
  echo "SUPPRESSED:recursion_guard"
  exit 0
fi

# ─── Dedup rule ───────────────────────────────────────────────────────────────────────────────
defect_key="${defect_class}:${resolved_path}"

matches_json="$("${SCRIPT_DIR}/events-query.sh" --event-type system_defect --format json-array 2>/dev/null | \
  jq -c --arg key "$defect_key" '[.[] | select((.detail.defect_key // "") == $key)]')" || matches_json='[]'
if [ -z "$matches_json" ]; then
  matches_json='[]'
fi

# state.json can be large (hundreds of tasks); read it via --slurpfile (a file argument) rather
# than --argjson over a captured bash variable, which would blow past ARG_MAX on this repo.
if [ -f "$STATE_FILE" ]; then
  is_duplicate="$(jq -n \
    --argjson matches "$matches_json" \
    --slurpfile state_arr "$STATE_FILE" \
    '
    def is_terminal: ascii_downcase as $s | ($s == "completed" or $s == "abandoned" or $s == "expanded");
    (($state_arr[0].active_projects) // []) as $all |
    ([$matches[] | .detail.linked_task_number // empty]) as $linked_nums |
    ([$linked_nums[] as $ln | ($all[] | select(.project_number == $ln) | (.status // "")) ]) as $linked_statuses |
    ([$linked_statuses[] | select(is_terminal | not)] | length) > 0
    ' 2>/dev/null)" || is_duplicate="false"
else
  is_duplicate="false"
fi

if [ "$is_duplicate" = "true" ]; then
  echo "[SYSTEM-DEFECT RECORDER] SUPPRESSED: duplicate of an already-tracked defect (defect_key='$defect_key' has a non-terminal linked task). Not recording." >&2
  echo "SUPPRESSED:duplicate"
  exit 0
fi

# ─── Build the detail payload (jq -c -n only, never string concatenation) ───────────────────
detail_json="$(jq -c -n \
  --arg defect_class "$defect_class" \
  --arg attributed_source_path "$resolved_path" \
  --arg detecting_site "$detecting_site" \
  --arg dispatched_agent "$dispatched_agent_arg" \
  --arg defect_key "$defect_key" \
  --argjson extra "$extra_detail_arg" \
  '{
    defect_class: $defect_class,
    attributed_source_path: $attributed_source_path,
    detecting_site: $detecting_site,
    dispatched_agent: (if $dispatched_agent == "" then null else $dispatched_agent end),
    defect_key: $defect_key,
    linked_task_number: null
  } * $extra')"

# ─── D5: session-id fallback ──────────────────────────────────────────────────────────────────
# Uses the shared common_session_id (lib/common.sh, already sourced above) rather than an inline
# copy -- the codebase's single-source-of-truth generator (see that function's own header) for
# the same sess_<epoch>_<6hex> form this script's own header comment documents.
if [ -z "$session_arg" ]; then
  session_arg="$(common_session_id)"
fi

# ─── Append via events-append.sh, relative to this script's own SCRIPT_DIR ───────────────────
# Never compute or pass an events.jsonl path -- events-append.sh derives PROJECT_ROOT itself.
append_args=(
  --event-type system_defect
  --category deviation
  --session "$session_arg"
  --message "$message"
  --detail-json "$detail_json"
)
[ -n "$task_arg" ] && append_args+=(--task "$task_arg")
[ -n "$cwd_arg" ] && append_args+=(--cwd "$cwd_arg")
[ -n "$cc_session_arg" ] && append_args+=(--cc-session-id "$cc_session_arg")

"${SCRIPT_DIR}/events-append.sh" "${append_args[@]}"
