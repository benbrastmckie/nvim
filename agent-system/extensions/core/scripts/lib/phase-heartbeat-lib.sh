#!/usr/bin/env bash
# phase-heartbeat-lib.sh - Shared implementation of the mechanized task-lock /
# session-registry heartbeat refresh, extracted from update-phase-status.sh's
# heartbeat_after_phase_transition() so dispatch-boundary callers (orchestrate-build-dispatch.sh,
# orchestrate-cycle-postflight.sh) can pulse the SAME mechanism without duplicating it.
#
# WHY THIS EXISTS: Piece 1 of the honest-session-liveness task diagnosed the heartbeat silence
# as a design gap, not a routing regression -- the mechanism itself (this function) is correct
# and fully wired, but it previously fired only from inside update-phase-status.sh, so a task
# routed to one of the 13 (of 14) phase-heading-owning implementation agents that never call
# update-phase-status.sh got zero heartbeat coverage for its entire implementation phase. See
# `context/patterns/task-lock.md`'s "Heartbeat Coverage Is Per-Caller, Not Repo-Wide" section
# for the full diagnosis, the probe, and the adoption inventory. DO NOT build a second
# heartbeat mechanism elsewhere -- extend this one's reach by adding a new caller instead.
#
# Usage: source this file, then call:
#   phase_heartbeat_pulse <repo_root> <task_dir> <task_number> <phase_label> <caller_session_id>
#
# Arguments:
#   repo_root         - absolute path to the repository root
#   task_dir          - absolute path to the task directory (specs/{NNN}_{SLUG})
#   task_number       - unpadded task number (used only in the trace line, not for path lookup)
#   phase_label       - the phase number for a real phase transition (e.g. "3", "3.1"), OR a
#                        non-numeric dispatch-boundary label (e.g. "dispatch-start",
#                        "dispatch-end") -- kept separable from real phase numbers in the trace
#                        log by construction, since a real phase_number token is always numeric.
#   caller_session_id - optional; when non-empty, asserted against holder.json's session_id (see
#                        "SESSION_ID IS DERIVED, NOT REQUIRED" below). Pass "" when the caller
#                        has no session_id of its own to assert and wants to rely purely on the
#                        value derived from holder.json.
#
# SESSION_ID IS DERIVED, NOT REQUIRED: this function reads session_id from the task's own
# `.lock/holder.json` rather than requiring the caller to supply it (closing every absent-caller
# gap at once, with no caller-side prose dependency). The optional caller_session_id argument is
# only an assertion: if supplied and it disagrees with the value read from holder.json, the
# heartbeat is skipped and a `noop:session-mismatch` trace line is written naming both values.
#
# NEVER BLOCKS, NEVER SILENT: every invocation and every no-op path writes exactly one line per
# subcommand to `.agent-logs/heartbeat-trace.log` (line grammar below), and the entire function
# can neither alter the caller's exit code nor write to its stdout -- callers MUST redirect this
# function's own stdout to /dev/null and suffix with `|| true`, exactly as documented at each
# call site. Set PHASE_HEARTBEAT_DISABLE to any non-empty value to skip the function entirely
# (fixture-harness / emergency-rollback escape hatch; restores exact pre-mechanization behavior).
#
# Trace log: one line per subcommand appended to ${repo_root}/.agent-logs/heartbeat-trace.log,
# shape (byte-identical to the pre-extraction inline function):
#   [<ISO8601>] task <N> phase <P> <subcommand>: <ok|noop:<reason>|error:<reason>> session=<sid> sid_source=<derived|argument> msg=<...>

phase_heartbeat_pulse() {
    local hb_repo_root="${1:-}" hb_task_dir="${2:-}" hb_task_number="${3:-}" hb_phase_label="${4:-}" hb_caller_session_id="${5:-}"
    local hb_lock_dir hb_holder hb_trace_log

    if [[ -n "${PHASE_HEARTBEAT_DISABLE:-}" ]]; then
        return 0
    fi

    hb_lock_dir="${hb_task_dir}/.lock"
    hb_holder="${hb_lock_dir}/holder.json"
    hb_trace_log="${hb_repo_root}/.agent-logs/heartbeat-trace.log"
    mkdir -p "${hb_repo_root}/.agent-logs" 2>/dev/null || true

    _hb_trace() {
        local sub="$1" verdict="$2" sid="$3" src="$4" msg="${5:-}"
        local ts
        ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null) || true
        msg="${msg//$'\n'/ }"
        echo "[${ts}] task ${hb_task_number} phase ${hb_phase_label} ${sub}: ${verdict} session=${sid} sid_source=${src} msg=${msg}" >> "$hb_trace_log" 2>/dev/null || true
    }

    if [[ ! -f "$hb_holder" ]]; then
        _hb_trace "heartbeat" "noop:no-holder" "" "derived" "no .lock/holder.json for task ${hb_task_number}"
        _hb_trace "session-heartbeat" "noop:no-holder" "" "derived" "no .lock/holder.json for task ${hb_task_number}"
        return 0
    fi

    local derived_sid
    derived_sid=$(jq -r '.session_id // empty' "$hb_holder" 2>/dev/null) || true
    if [[ -z "$derived_sid" ]]; then
        _hb_trace "heartbeat" "noop:unparseable-holder" "" "derived" "holder.json present but session_id unreadable"
        _hb_trace "session-heartbeat" "noop:unparseable-holder" "" "derived" "holder.json present but session_id unreadable"
        return 0
    fi

    local hb_sid hb_sid_source
    if [[ -n "$hb_caller_session_id" ]]; then
        if [[ "$hb_caller_session_id" != "$derived_sid" ]]; then
            _hb_trace "heartbeat" "noop:session-mismatch" "$hb_caller_session_id" "argument" "argument session_id=${hb_caller_session_id} disagrees with holder session_id=${derived_sid}"
            _hb_trace "session-heartbeat" "noop:session-mismatch" "$hb_caller_session_id" "argument" "argument session_id=${hb_caller_session_id} disagrees with holder session_id=${derived_sid}"
            return 0
        fi
        hb_sid="$hb_caller_session_id"
        hb_sid_source="argument"
    else
        hb_sid="$derived_sid"
        hb_sid_source="derived"
    fi

    local tl_candidates tl_path=""
    tl_candidates=(
        "${hb_repo_root}/.claude/scripts/task-lock.sh"
        "${hb_repo_root}/agent-system/extensions/core/scripts/task-lock.sh"
    )
    local _tl
    for _tl in "${tl_candidates[@]}"; do
        if [[ -f "$_tl" ]]; then
            tl_path="$_tl"
            break
        fi
    done
    if [[ -z "$tl_path" ]]; then
        _hb_trace "heartbeat" "error:task-lock-unresolved" "$hb_sid" "$hb_sid_source" "task-lock.sh not found at any candidate path"
        _hb_trace "session-heartbeat" "error:task-lock-unresolved" "$hb_sid" "$hb_sid_source" "task-lock.sh not found at any candidate path"
        return 0
    fi

    local hb_out hb_rc hb_verdict hb_reason
    hb_rc=0
    hb_out=$(bash "$tl_path" heartbeat "$hb_task_number" "$hb_sid" 2>&1) || hb_rc=$?
    if [[ "$hb_rc" -ne 0 ]]; then
        hb_verdict="error:exit-${hb_rc}"
    elif [[ "$hb_out" == *"no-op"* ]]; then
        case "$hb_out" in
            *"no lock held"*) hb_reason="no-lock" ;;
            *"held by a different session"*) hb_reason="session-mismatch" ;;
            *) hb_reason="unknown" ;;
        esac
        hb_verdict="noop:${hb_reason}"
    else
        hb_verdict="ok"
    fi
    _hb_trace "heartbeat" "$hb_verdict" "$hb_sid" "$hb_sid_source" "$hb_out"

    local sh_out sh_rc sh_verdict sh_reason
    sh_rc=0
    sh_out=$(bash "$tl_path" session-heartbeat "$hb_sid" 2>&1) || sh_rc=$?
    if [[ "$sh_rc" -ne 0 ]]; then
        sh_verdict="error:exit-${sh_rc}"
    elif [[ "$sh_out" == *"no-op"* ]]; then
        case "$sh_out" in
            *"no registry entry"*) sh_reason="no-entry" ;;
            *) sh_reason="unknown" ;;
        esac
        sh_verdict="noop:${sh_reason}"
    else
        sh_verdict="ok"
    fi
    _hb_trace "session-heartbeat" "$sh_verdict" "$hb_sid" "$hb_sid_source" "$sh_out"

    return 0
}
