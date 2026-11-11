#!/usr/bin/env bash
# events-append.sh - Append one validated event line to the unified specs/events.jsonl store
#
# Usage:
#   events-append.sh --event-type TYPE --category CAT --session SESSION_ID \
#     [--task N] [--checkpoint NAME] [--duration SECONDS] --message "..." \
#     [--detail-json '{"...":"..."}'] [--error-ref ERR_ID] [--cwd PATH] \
#     [--cc-session-id VALUE]
#
# Single responsibility: build one validated JSON line via `jq -c -n` (never string
# concatenation) and append it to specs/events.jsonl, creating the file lazily on first
# use. The append is guarded by `flock` on specs/.events.lock as defense-in-depth beyond
# POSIX small-write (O_APPEND) atomicity.
#
# After the local append, this script also attempts a second, non-fatal promotion of the same
# line to the cross-repo central log via scripts/lib/central-log-lib.sh's central_log_promote
# (only a category == "blocker" line is promoted). This CLI's own documented exit codes and its
# stdout contract (exactly the event_id) are unchanged by that promotion -- it is best-effort and
# can never fail or alter this script's own behavior. See context/formats/issue-log.md's
# "Central Cross-Repo Log" section for the full contract.
#
# See context/formats/events-format.md for the full field contract and
# context/schemas/events-schema.json for the formal JSON Schema.
#
# Exit codes:
#   0 - Success (line appended)
#   1 - Error (missing/invalid arguments, invalid --category, malformed --detail-json)
#
# Outputs:
#   stdout: the event_id of the appended line
#   stderr: diagnostic/error messages

set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: events-append.sh --event-type TYPE --category CAT --session SESSION_ID \
  [--task N] [--checkpoint NAME] [--duration SECONDS] --message "..." \
  [--detail-json '{"...":"..."}'] [--error-ref ERR_ID] [--cwd PATH] \
  [--cc-session-id VALUE]

Required:
  --event-type TYPE     Open string naming the specific kind of event
  --category CAT        One of: deviation|blocker|milestone|success
  --session SESSION_ID  sess_{timestamp}_{random} value
  --message "..."       Short human-readable one-line summary

Optional:
  --task N              Bare (unpadded) task/project number
  --checkpoint NAME      Lifecycle checkpoint name (e.g. preflight, GATE_IN, phase_2)
  --duration SECONDS    Duration in seconds (number)
  --detail-json '{...}' Open JSON object payload (must be valid JSON)
  --error-ref ERR_ID     Optional cross-link to an errors.json entry id
  --cwd PATH             Invoking working directory (absolute path); written as null when
                         absent (backward compatible). Never auto-detected -- the caller
                         supplies it explicitly (e.g. from hook stdin's .cwd field).
  --cc-session-id VALUE  Claude Code's own native session UUID from hook stdin's
                         .session_id field; written as null when absent. Distinct from
                         --session (the agent-system's sess_{timestamp}_{random} id) --
                         neither replaces the other. Never auto-detected.
USAGE
  exit 1
}

# --- Argument parsing ---
event_type=""
category=""
session_id=""
task=""
checkpoint=""
duration=""
message=""
detail_json=""
error_ref=""
cwd=""
cc_session_id=""

while [ $# -gt 0 ]; do
  case "$1" in
    --event-type) event_type="${2:-}"; shift 2 ;;
    --category) category="${2:-}"; shift 2 ;;
    --session) session_id="${2:-}"; shift 2 ;;
    --task) task="${2:-}"; shift 2 ;;
    --checkpoint) checkpoint="${2:-}"; shift 2 ;;
    --duration) duration="${2:-}"; shift 2 ;;
    --message) message="${2:-}"; shift 2 ;;
    --detail-json) detail_json="${2:-}"; shift 2 ;;
    --error-ref) error_ref="${2:-}"; shift 2 ;;
    --cwd) cwd="${2:-}"; shift 2 ;;
    --cc-session-id) cc_session_id="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "error: unknown argument: $1" >&2; usage ;;
  esac
done

# --- Validate required arguments ---
if [ -z "$event_type" ] || [ -z "$category" ] || [ -z "$session_id" ] || [ -z "$message" ]; then
  echo "error: --event-type, --category, --session, and --message are all required" >&2
  usage
fi

# --- Validate --category against the closed enum (fail loudly, write nothing) ---
case "$category" in
  deviation|blocker|milestone|success) ;;
  *)
    echo "error: invalid --category '$category' (must be one of: deviation|blocker|milestone|success)" >&2
    exit 1
    ;;
esac

# --- Validate --detail-json parses before any write ---
if [ -n "$detail_json" ]; then
  if ! echo "$detail_json" | jq -e 'type == "object"' > /dev/null 2>&1; then
    echo "error: --detail-json is not valid JSON (or not a JSON object): $detail_json" >&2
    exit 1
  fi
fi

# --- Validate --duration is numeric if given ---
if [ -n "$duration" ]; then
  if ! [[ "$duration" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "error: --duration must be a non-negative number, got: $duration" >&2
    exit 1
  fi
fi

# --- Validate --task is an integer if given ---
if [ -n "$task" ]; then
  if ! [[ "$task" =~ ^[0-9]+$ ]]; then
    echo "error: --task must be a bare integer, got: $task" >&2
    exit 1
  fi
fi

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
# central-log-lib.sh is sourced defensively: a fixture or scratch tree that copies this script
# without its (newer) library dependency must degrade to a true no-op promotion, never crash --
# the same silent-no-op posture the library's own central_log_promote already guarantees for
# every OTHER failure mode (missing binary, unresolvable owning repo, ...). Never `set -e`-fatal
# on a missing file.
if [ -f "${SCRIPT_DIR}/lib/central-log-lib.sh" ]; then
  source "${SCRIPT_DIR}/lib/central-log-lib.sh"
else
  central_log_promote() { return 0; }
fi
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
EVENTS_FILE="$PROJECT_ROOT/specs/events.jsonl"
LOCK_FILE="$PROJECT_ROOT/specs/.events.lock"

# --- Generate event_id and timestamp ---
timestamp_ms=$(date -u +%s%3N)
random6=$(tr -dc 'a-zA-Z0-9' < /dev/urandom 2>/dev/null | head -c 6 || true)
if [ -z "$random6" ] || [ "${#random6}" -lt 6 ]; then
  # Fallback if /dev/urandom is unavailable or too slow to yield 6 chars
  random6=$(printf '%06x' "$RANDOM$RANDOM" | tail -c 6)
fi
event_id="evt_${timestamp_ms}_${random6}"
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

# --- Build the line via jq -c -n (never string concatenation) ---
detail_arg="$detail_json"
if [ -z "$detail_arg" ]; then
  detail_arg='{}'
fi

line=$(jq -c -n \
  --arg event_id "$event_id" \
  --arg event_type "$event_type" \
  --arg category "$category" \
  --arg timestamp "$timestamp" \
  --arg session_id "$session_id" \
  --arg task "$task" \
  --arg checkpoint "$checkpoint" \
  --arg duration "$duration" \
  --arg message "$message" \
  --argjson detail "$detail_arg" \
  --arg error_ref "$error_ref" \
  --arg cwd "$cwd" \
  --arg cc_session_id "$cc_session_id" \
  '{
    event_id: $event_id,
    event_type: $event_type,
    category: $category,
    timestamp: $timestamp,
    duration_seconds: (if $duration == "" then null else ($duration | tonumber) end),
    session_id: $session_id,
    task: (if $task == "" then null else ($task | tonumber) end),
    checkpoint: (if $checkpoint == "" then null else $checkpoint end),
    message: $message,
    detail: $detail,
    error_ref: (if $error_ref == "" then null else $error_ref end),
    cwd: (if $cwd == "" then null else $cwd end),
    cc_session_id: (if $cc_session_id == "" then null else $cc_session_id end)
  }')

# --- Append with a single write, guarded by flock (defense-in-depth) ---
(
  flock -x 200
  printf '%s\n' "$line" >> "$EVENTS_FILE"
) 200> "$LOCK_FILE"

# --- Non-fatal promotion to the cross-repo central log (scripts/lib/central-log-lib.sh). This
#     is a second, best-effort append that can never change this script's own exit code or
#     stdout contract (stdout stays exactly the event_id below). See
#     context/formats/issue-log.md's "Central Cross-Repo Log" section for the envelope and the
#     promotion filter (only category == "blocker" is promoted). ---
central_log_promote "events.jsonl" "$line" || true

echo "$event_id"
exit 0
