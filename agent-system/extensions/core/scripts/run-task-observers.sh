#!/usr/bin/env bash
# run-task-observers.sh - The advisory, non-blocking post-task observer invoker.
#
# ADVISORY CONTRACT (verbatim, not negotiable): an observer can never change task status, never
# fail a dispatch, never block. Its return code is RECORDED AS AN EVENT (one `task_observer_run`
# line in specs/events.jsonl, via events-append.sh) and otherwise IGNORED. A missing,
# non-executable, crashing, or hanging observer script produces a deviation event and nothing
# else. This script always `exit 0` -- see the final line's own comment for why.
#
# ORDERING GUARANTEE THIS SCRIPT DEPENDS ON: the caller (orchestrate-cycle-postflight.sh) MUST
# invoke this script only AFTER that dispatch's own issue-log and metrics records have been
# written to the task directory -- an observer reading an incomplete record makes the whole seam
# worthless. This script does not and cannot enforce that ordering itself; it is purely a
# property of its own call site.
#
# Usage:
#   run-task-observers.sh --task N --task-type T --topic P --task-dir D --session S --status ST \
#     [--dry-run]
#
# --task-type and --topic may both be empty (either may legitimately be unset on a task row); a
# task with both empty resolves to zero observer matches and this script exits 0 silently.
#
# --dry-run: print one `would invoke observer <name> (<script>) matched_on=<k>` line per match to
# stderr, append no event, invoke nothing, exit 0.
#
# Resolution is delegated entirely to scripts/lib/manifest-routing-lib.sh's
# routing_resolve_observers() (a resolve-ALL, fan-out ladder -- distinct from and never folded
# into that library's two first-match-wins ladders). See that function's own header for the
# matching contract (prefix-aware on both topic and task_type, match-if-either).
#
# STRICT-MODE CLASS (context/standards/shell-strict-mode.md): deliberately `set -uo pipefail`,
# not Class A `-e`. Every observer invocation's nonzero/timeout exit is itself the signal this
# script exists to record (as an event), not an error to abort on -- the opposite of Class A's
# admission test. `-e` would abort the whole script the moment one observer among several
# crashed or timed out, silently skipping every observer after it in the resolved list; that is
# exactly the "an observer can never block/fail the seam for others" guarantee this file's own
# header forbids giving up.

set -uo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: run-task-observers.sh --task N --task-type T --topic P --task-dir D --session S \
  --status ST [--dry-run]
USAGE
  exit 1
}

task_number=""
task_type=""
topic=""
task_dir_arg=""
session_id=""
resting_status=""
dry_run=0

while [ $# -gt 0 ]; do
  case "$1" in
    --task) task_number="${2:-}"; shift 2 ;;
    --task-type) task_type="${2:-}"; shift 2 ;;
    --topic) topic="${2:-}"; shift 2 ;;
    --task-dir) task_dir_arg="${2:-}"; shift 2 ;;
    --session) session_id="${2:-}"; shift 2 ;;
    --status) resting_status="${2:-}"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    -h|--help) usage ;;
    *) echo "error: unknown argument: $1" >&2; usage ;;
  esac
done

if [ -z "$task_number" ] || [ -z "$task_dir_arg" ] || [ -z "$session_id" ] || [ -z "$resting_status" ]; then
  echo "error: --task, --task-dir, --session, and --status are all required" >&2
  usage
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1

# D6: manifest root resolution must be cwd-independent -- never inherit a caller-relative
# default, so a sandbox fixture exercising this script from any cwd resolves the same tree.
: "${ROUTE_MANIFEST_ROOT:="${PROJECT_ROOT}/.claude"}"
export ROUTE_MANIFEST_ROOT
# shellcheck source=lib/manifest-routing-lib.sh
source "${SCRIPT_DIR}/lib/manifest-routing-lib.sh"

case "$task_dir_arg" in
  /*) task_dir="$task_dir_arg" ;;
  *) task_dir="${PROJECT_ROOT}/${task_dir_arg}" ;;
esac

# --- Select the timeout binary once (D3): prefer `timeout`, then `gtimeout`, else none. ---
timeout_bin=""
if command -v timeout >/dev/null 2>&1; then
  timeout_bin="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  timeout_bin="gtimeout"
fi

while IFS=$'\t' read -r _ extension_name observer_name observer_script matched_on timeout_seconds; do
  [ -n "$observer_name" ] || continue

  if [ "$dry_run" -eq 1 ]; then
    echo "would invoke observer ${observer_name} (${observer_script}) matched_on=${matched_on}" >&2
    continue
  fi

  # D1: script resolves by BASENAME against the deployed .claude/scripts/ directory.
  script_basename="$(basename "$observer_script")"
  resolved_script="${PROJECT_ROOT}/.claude/scripts/${script_basename}"

  rc=""
  timed_out="false"
  skipped=""
  duration="0"

  if [ ! -e "$resolved_script" ]; then
    rc=""
    skipped="missing_script"
  elif [ ! -x "$resolved_script" ]; then
    rc=""
    skipped="not_executable"
  elif [ -z "$timeout_bin" ]; then
    rc=""
    skipped="no_timeout_binary"
  else
    capture_file="$(mktemp 2>/dev/null || echo /tmp/run-task-observers.$$)"
    start_ts=$(date +%s 2>/dev/null || echo 0)
    "$timeout_bin" "${timeout_seconds:-30}" "$resolved_script" \
      "$task_number" "$task_type" "$topic" "$task_dir" "$session_id" "$resting_status" \
      >"$capture_file" 2>&1
    rc=$?
    end_ts=$(date +%s 2>/dev/null || echo 0)
    duration=$((end_ts - start_ts))
    rm -f "$capture_file" 2>/dev/null || true
    if [ "$rc" = "124" ]; then
      timed_out="true"
    fi
  fi

  if [ -n "$skipped" ]; then
    category="deviation"
    rc_json="null"
    message="observer ${observer_name} skipped (${skipped})"
  elif [ "$rc" = "0" ]; then
    category="success"
    rc_json="0"
    message="observer ${observer_name} completed (rc=0)"
  else
    category="deviation"
    rc_json="$rc"
    message="observer ${observer_name} exited rc=${rc}"
  fi

  detail_json=$(jq -c -n \
    --arg observer "$observer_name" \
    --arg extension "$extension_name" \
    --arg script "$script_basename" \
    --arg matched_on "$matched_on" \
    --argjson rc "$rc_json" \
    --argjson timed_out "$timed_out" \
    --argjson timeout_seconds "${timeout_seconds:-30}" \
    --arg skipped "$skipped" \
    '{observer: $observer, extension: $extension, script: $script, matched_on: $matched_on,
      rc: $rc, timed_out: $timed_out, timeout_seconds: $timeout_seconds} +
     (if $skipped == "" then {} else {skipped: $skipped} end)' 2>/dev/null)

  bash "${SCRIPT_DIR}/events-append.sh" \
    --event-type "task_observer_run" \
    --category "$category" \
    --session "$session_id" \
    --task "$task_number" \
    --duration "$duration" \
    --message "$message" \
    --detail-json "$detail_json" \
    >/dev/null 2>&1 || echo "Note: task-observer event recording failed (non-fatal)" >&2
done < <(routing_resolve_observers "$topic" "$task_type")

# Returning a child rc here would flip the non-blocking contract for any caller running under
# `set -e` -- the same reasoning skill_run_extension_hook's own `return 0` already records.
exit 0
