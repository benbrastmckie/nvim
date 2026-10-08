#!/usr/bin/env bash
# update-phase-status.sh - Update a single phase heading status in a plan file
# Usage: .claude/scripts/update-phase-status.sh TASK_NUMBER PROJECT_NAME PHASE_NUMBER NEW_STATUS [SESSION_ID]
#
# NEW_STATUS values: IN_PROGRESS, NOT_STARTED, COMPLETED, COMPLETED_WITH_EXCLUSIONS, PARTIAL, BLOCKED
# (this case statement's six values are kept in exact correspondence with
# scripts/lib/phase-heading-patterns.sh's PHASE_STATUS_ENUM array -- see the sourcing block below;
# if the two ever disagree, the library's enum is authoritative and this case statement is wrong)
# Outputs: Updated plan file path on success, empty on failure/no-op
#
# Phase heading format: ### Phase N: {name} [STATUS] -- see context/formats/plan-format.md's
# "Canonical phase-heading shape" subsection for the full grammar. This script is the ONE
# deliberately parameter-driven consumer of that grammar: unlike every other consumer (which
# scans a whole plan file for headings), this script is handed a specific phase_number by its
# caller and must therefore validate that argument itself before building a lookup, rather than
# discovering non-conformance by scanning.
#
# Exit codes: 0 - success or idempotent no-op; 1 - validation error (bad arguments, phase not
# found, non-conforming phase_number argument, replacement verification failure); 5 - environment
# error (scripts/lib/phase-heading-patterns.sh could not be found).
#
# Logs transitions to: .agent-logs/phase-transitions.log
#
# --- Mechanized task-lock / session-registry heartbeat refresh ---
#
# WHY THIS MECHANISM CANNOT BE SKIPPED: an empirical incident transcript showed the prose
# heartbeat instructions once documented in agents/general-implementation-agent.md's Stage 4D
# (`task-lock.sh heartbeat` / `session-heartbeat`, four lines below the `update-phase-status.sh`
# call) fired 0 times across 8 real phase transitions, while THIS script's own invocation fired
# 16/16 in the same run. This script is the single command an implementation agent must invoke to
# move a phase heading -- the transition is not representable any other way -- so putting the
# refresh INSIDE this script means the only way to skip the heartbeat is to skip the phase
# transition itself. See `context/patterns/task-lock.md` for the full contract.
#
# SESSION_ID IS DERIVED, NOT REQUIRED: rather than accepting session_id as a mandatory argument
# (which would still have to be typed by the same agent prose already proven not to execute, and
# would re-open the `printf "%03d" "{task_number}"` brace-placeholder landmine an unsubstituted
# caller template could trigger), this script reads session_id from the task's own
# `.lock/holder.json` -- state it has already resolved the path to via $plan_dir/$task_dir. This
# means NO caller change and NO agent prose is required for the heartbeat to fire: every existing
# 4-argument call site inherits the behavior for free, closing every absent-caller gap at once.
# An OPTIONAL 5th positional `session_id` argument is still accepted, but only as an assertion: if
# supplied and it disagrees with the value read from holder.json, the heartbeat is skipped and a
# `noop:session-mismatch` trace line is written naming both values -- it is never required for the
# heartbeat to fire.
#
# NEVER BLOCKS, NEVER SILENT: every heartbeat/session-heartbeat invocation and every no-op path
# writes one line to `.agent-logs/heartbeat-trace.log` (line grammar documented at
# `phase_heartbeat_pulse()` in `scripts/lib/phase-heartbeat-lib.sh` below), and the entire block
# can neither alter this script's exit code nor write to its stdout -- verified by Phase 4's
# fixture test asserting byte-identical stdout and exit 0 across every no-op class. Set
# `PHASE_HEARTBEAT_DISABLE` to any non-empty value to skip the block entirely (a fixture-harness
# / emergency-rollback opt-out that restores the exact pre-mechanization behavior with no code
# revert).
#
# EXTRACTED INTO A SHARED LIBRARY (scripts/lib/phase-heartbeat-lib.sh): the implementation below
# used to be an inlined function here; it is now `phase_heartbeat_pulse()` in that library, with
# an explicit-parameter signature, so dispatch-boundary callers
# (orchestrate-build-dispatch.sh, orchestrate-cycle-postflight.sh) can pulse the identical
# mechanism without duplicating it. This script's own call site below is unchanged in output:
# same trace-log path, same line shape, same no-op/error classifiers, same opt-out.

set -euo pipefail

task_number="${1:-}"
project_name="${2:-}"
phase_number="${3:-}"
new_status="${4:-}"
caller_session_id="${5:-}"

# Validate inputs. The optional 5th SESSION_ID argument is never required -- see the
# "SESSION_ID IS DERIVED, NOT REQUIRED" header comment above -- so it is deliberately absent
# from this required-argument check.
if [[ -z "$task_number" || -z "$project_name" || -z "$phase_number" || -z "$new_status" ]]; then
    echo "Usage: $0 TASK_NUMBER PROJECT_NAME PHASE_NUMBER STATUS [SESSION_ID]" >&2
    echo "  STATUS values: IN_PROGRESS, NOT_STARTED, COMPLETED, COMPLETED_WITH_EXCLUSIONS, PARTIAL, BLOCKED" >&2
    echo "  SESSION_ID (optional): asserted against holder.json's session_id; on mismatch the" >&2
    echo "    heartbeat refresh is skipped and traced, never required for the phase update itself." >&2
    exit 1
fi

# Normalize NEW_STATUS: case-insensitive input to canonical display form (with spaces)
case "$new_status" in
    IN_PROGRESS|in_progress|IN\ PROGRESS|in\ progress)
        new_status_display="IN PROGRESS" ;;
    NOT_STARTED|not_started|NOT\ STARTED|not\ started)
        new_status_display="NOT STARTED" ;;
    COMPLETED|completed)
        new_status_display="COMPLETED" ;;
    COMPLETED_WITH_EXCLUSIONS|completed_with_exclusions|COMPLETED\ WITH\ EXCLUSIONS|completed\ with\ exclusions)
        new_status_display="COMPLETED WITH EXCLUSIONS" ;;
    PARTIAL|partial)
        new_status_display="PARTIAL" ;;
    BLOCKED|blocked)
        new_status_display="BLOCKED" ;;
    *)
        echo "Unknown status: $new_status" >&2
        echo "Valid values: IN_PROGRESS, NOT_STARTED, COMPLETED, COMPLETED_WITH_EXCLUSIONS, PARTIAL, BLOCKED" >&2
        exit 1 ;;
esac

# Determine the script's working directory — find repo root by locating .claude/
# Script may be called from any working directory, so resolve relative to this script's location
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
. "${script_dir}/deploy-root-guard.sh" || exit 1

# --- Shared phase-heading pattern library ---
# Deploy-tree-first / source-store-fallback candidate list, matching every other consumer's
# resolution of this library. Never falls through to a locally-composed pattern: a missing
# library is a loud environment error (exit 5), not a silent degradation.
phase_lib_candidates=(
    "${repo_root}/.claude/scripts/lib/phase-heading-patterns.sh"
    "${repo_root}/agent-system/extensions/core/scripts/lib/phase-heading-patterns.sh"
)
phase_lib=""
for _candidate in "${phase_lib_candidates[@]}"; do
    if [[ -f "$_candidate" ]]; then
        phase_lib="$_candidate"
        break
    fi
done
if [[ -z "$phase_lib" ]]; then
    echo "Error: shared library phase-heading-patterns.sh not found at any of:" >&2
    for _candidate in "${phase_lib_candidates[@]}"; do
        echo "  $_candidate" >&2
    done
    exit 5
fi
# shellcheck disable=SC1090
. "$phase_lib"

# Validate the caller-supplied phase_number argument against the library's canonical bare-token
# grammar BEFORE building any lookup pattern from it. A non-conforming argument (e.g. "3a") must
# fail loudly with a named reason here, rather than silently falling through to a lookup grep
# that matches nothing and is reported merely as "phase not found" -- which would be
# indistinguishable from a genuinely absent phase number.
if ! grep -qE "$PHASE_NUMBER_TOKEN_ERE" <<< "$phase_number"; then
    echo "Error: phase_number argument '${phase_number}' is not a conforming phase-number token." >&2
    echo "       Expected an integer with at most one optional decimal sub-level (e.g. '3', '3.1')." >&2
    echo "       See context/formats/plan-format.md's 'Canonical phase-heading shape' subsection." >&2
    exit 1
fi

# --- phase_heartbeat_pulse: mechanized task-lock / session-registry refresh ---
#
# See the top-of-file header comment for the full rationale (why this cannot be skipped, why
# session_id is derived rather than required). The implementation itself now lives in
# scripts/lib/phase-heartbeat-lib.sh's phase_heartbeat_pulse() (extracted so dispatch-boundary
# callers can pulse the identical mechanism -- see context/patterns/task-lock.md's "Heartbeat
# Coverage Is Per-Caller, Not Repo-Wide" section). This script sources that library and calls
# the function exactly once below -- immediately after $plan_dir is resolved and validated, and
# BEFORE both the "Phase N not found" exit and the idempotency early-exit -- so that a no-op
# status update and an unmatched phase number both still refresh liveness (the caller is
# demonstrably alive and working the task in either case).
hb_lib_candidates=(
    "${repo_root}/.claude/scripts/lib/phase-heartbeat-lib.sh"
    "${repo_root}/agent-system/extensions/core/scripts/lib/phase-heartbeat-lib.sh"
)
hb_lib=""
for _hb_candidate in "${hb_lib_candidates[@]}"; do
    if [[ -f "$_hb_candidate" ]]; then
        hb_lib="$_hb_candidate"
        break
    fi
done
if [[ -n "$hb_lib" ]]; then
    # shellcheck disable=SC1090
    . "$hb_lib"
fi

# Find plan directory (padded task number with fallback to unpadded)
padded_num=$(printf "%03d" "$task_number")
plan_dir="${repo_root}/specs/${padded_num}_${project_name}/plans"

if [[ ! -d "$plan_dir" ]]; then
    # Try unpadded (legacy)
    plan_dir="${repo_root}/specs/${task_number}_${project_name}/plans"
fi

if [[ ! -d "$plan_dir" ]]; then
    echo "Plan directory not found for task $task_number (tried padded and unpadded)" >&2
    exit 1
fi

# Mechanized heartbeat refresh: fires here, once, before either the "Phase N not found" exit or
# the idempotency early-exit below -- both of those still represent forward progress on this
# task. Disabled entirely when PHASE_HEARTBEAT_DISABLE is set (fixture harness / rollback
# escape hatch), or silently skipped if the shared library could not be sourced (never a hard
# failure -- see phase-heartbeat-lib.sh's own "never blocks, never silent" contract). Never
# affects stdout or exit code (see the function's own header comment).
hb_task_dir="$(dirname "$plan_dir")"
if [[ -z "${PHASE_HEARTBEAT_DISABLE:-}" ]] && declare -f phase_heartbeat_pulse >/dev/null 2>&1; then
    phase_heartbeat_pulse "$repo_root" "$hb_task_dir" "$task_number" "$phase_number" "$caller_session_id" >/dev/null || true
fi

# Get latest plan file, version-ordered (not mtime-ordered).
# Prefer the MM_{short-slug}.md convention (artifact-formats.md); highest sequence wins.
# Fall back to a plain name sort only when no conforming file exists, so legacy-named
# plans never outrank a conforming one (a plain sort would rank "implementation-001.md"
# above "02_revised.md" because "i" sorts after "0").
plan_file=$(ls "$plan_dir"/[0-9][0-9]_*.md 2>/dev/null | sort | tail -1 || true)
if [[ -z "$plan_file" ]]; then
    plan_file=$(ls "$plan_dir"/*.md 2>/dev/null | sort | tail -1 || true)
fi
if [[ -z "$plan_file" ]]; then
    echo "No plan file found in $plan_dir" >&2
    exit 1
fi

plan_basename=$(basename "$plan_file")

# Find the exact line number of the phase heading. Built from the library's exported
# PHASE_HEADING_PREFIX ('^### Phase ') parameterized on the validated phase_number, rather than
# from a locally-composed "^### Phase " string.
# Use || true to prevent set -e from aborting when grep finds no match (exit code 1)
line_number=$(grep -n "${PHASE_HEADING_PREFIX}${phase_number}:" "$plan_file" 2>/dev/null | head -1 | cut -d: -f1 || true)

if [[ -z "$line_number" ]]; then
    echo "Phase ${phase_number} not found in $plan_file" >&2
    exit 1
fi

# Extract current status from that line using sed capture
current_status=$(sed -n "${line_number}s/.*\[\(.*\)\]$/\1/p" "$plan_file")

if [[ -z "$current_status" ]]; then
    echo "Could not extract status from phase ${phase_number} heading in $plan_file" >&2
    echo "Line ${line_number}: $(sed -n "${line_number}p" "$plan_file")" >&2
    exit 1
fi

# Idempotency check: if current status equals target status, exit 0 silently (no-op)
if [[ "$current_status" == "$new_status_display" ]]; then
    # Already at target status, no-op
    exit 0
fi

# Replace status on the specific line (line-specific replacement to avoid touching plan-level header)
sed -i "${line_number}s/\[.*\]/[${new_status_display}]/" "$plan_file"

# Verify the replacement succeeded
updated_line=$(sed -n "${line_number}p" "$plan_file")
updated_status=$(echo "$updated_line" | sed 's/.*\[\(.*\)\]$/\1/')

if [[ "$updated_status" != "$new_status_display" ]]; then
    echo "Failed to update phase ${phase_number} status in $plan_file" >&2
    echo "Wanted '${new_status_display}', got '${updated_status}'" >&2
    exit 1
fi

# Ensure log directory exists
log_dir="${repo_root}/.agent-logs"
mkdir -p "$log_dir"
log_file="${log_dir}/phase-transitions.log"

# Append log entry: [ISO8601] task N filename.md phase P: OLD_STATUS -> NEW_STATUS
timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "[${timestamp}] task ${task_number} ${plan_basename} phase ${phase_number}: ${current_status} -> ${new_status_display}" >> "$log_file"

# Output the updated plan file path on success
echo "$plan_file"
