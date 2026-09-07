#!/usr/bin/env bash
#
# claude-refresh.sh - Identify and terminate orphaned Claude Code processes
#
# Usage: ./claude-refresh.sh [--force|--dry-run]
#
# Options:
#   --force      Skip confirmation prompt and terminate immediately
#   --dry-run    Preview mode: identical to the no-flag path, with an explicit banner
#   (none)       Show status and exit (skill handles confirmation via AskUserQuestion)
#
# Safety mechanism (read this before touching the predicates below):
#   A single atomic `ps -eo` snapshot is taken once per invocation. Every exclusion
#   decision is made from data already present in that snapshot -- there is no second,
#   later re-query of a candidate PID, so there is no window in which a transient PID
#   from the snapshot can have already exited and be misjudged as "not excluded".
#   Four independently-callable predicates decide candidacy/exclusion:
#     - is_claude_executable_comm: a candidate must match a narrow allow-list on its
#       `comm` (executable identity), never on an argv substring. This is what keeps a
#       system daemon that merely MENTIONS "claude" in one of its own flags (e.g. an
#       OOM-killer's process-name preference regex) from ever being considered a
#       candidate at all.
#     - is_system_slice_cgroup: a candidate whose cgroup is under `/system.slice/` is
#       excluded -- defense-in-depth against a system service ever being selected, even
#       if some future daemon's comm happened to collide with the allow-list.
#     - is_owned_by_current_uid: a candidate not owned by the invoking user's UID is
#       excluded -- defense-in-depth against a different user's/service's process.
#     - is_live_inhibitor_target: a candidate identified as holding a
#       `systemd-inhibit ... tail --pid=<N>` sleep-inhibitor is excluded when `<N>` (a
#       DIFFERENT process than the candidate -- the session it protects) is still
#       alive. This is the one predicate that legitimately performs a live check, and
#       it never re-checks the candidate's own liveness, so it introduces no race.
#   Plus zero-query self-exclusion: any row whose pid or ppid equals this script's own
#   PID ($$, known at parse time) is skipped without any further check.
#
#   Deliberate trade-off, stated explicitly so this is not "fixed" back toward argv
#   matching later: this design trades recall for safety. A leaked/orphaned process
#   that this allow-list fails to recognize survives (false negative); that is strictly
#   preferable to ever terminating a live system daemon or another live session's
#   process (false positive). Do not widen `is_claude_executable_comm` to match on a
#   bare argv substring -- that is exactly the defect this rewrite removes.
#
#   If the platform's `ps` does not support the `cgroup` column (or the invocation
#   fails), this script refuses to run rather than silently falling back to the old,
#   unsafe argv-substring behavior. See validate_cgroup_support() below.
#
#   Invariant ruling -- VmSwap accounting and the single-snapshot argument above:
#   get_vmswap_kb() performs a per-candidate read of /proc/PID/status, taken AFTER the
#   snapshot above, which is the first thing in this script to touch a live PID rather
#   than the frozen `ps -eo` snapshot. Ruling: this does NOT breach the race-freedom
#   argument above. (a) It is reporting-only -- its result feeds no `if` that decides
#   active/orphan/excluded status; every candidacy and exclusion decision is still made
#   exclusively from the original snapshot, unchanged. (b) It is performed strictly
#   after a row's classification has already been fixed from the snapshot, so nothing
#   downstream of the read can change which branch a row took. (c) A candidate that
#   exited between the snapshot and this read yields an empty `/proc` read, which
#   get_vmswap_kb() normalizes to `0` -- never an error, and never a misclassification,
#   because classification has already happened. Residual risk, named rather than left
#   silent: if the original PID exits and the kernel reuses that PID number for an
#   unrelated process before this read runs, the swap figure reported for that row could
#   be attributed to the wrong process. This is accepted because the consequence is
#   purely cosmetic -- a display/accumulation number -- and it never gates a termination
#   decision; the four predicates above remain the sole authority over what gets killed.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Current invoking UID, computed once. Used by is_owned_by_current_uid.
CURRENT_UID="$(id -u)"

# --- Snapshot field-index map (single `ps -eo` reading, no second live re-query) ---
# $1 pid   $2 ppid   $3 uid   $4 tty   $5 etimes   $6 rss   $7 comm   $8 cgroup   $9..NF args
# (cgroup is requested at an explicit 200-column width so a long cgroup path is never
# silently truncated by ps's default fixed column width; args is captured by `read`'s
# "last variable gets the remainder of the line" behavior, so no awk field arithmetic
# is needed for it.)
SNAPSHOT_PS_FIELDS='pid,ppid,uid,tty,etimes,rss,comm,cgroup:200,args'

# --- Predicate 1: executable-identity match (candidacy gate, not merely an exclusion) ---
# Returns 0 (true) only when this process IS a genuine Claude Code executable. Matching
# is on `comm` (the kernel-level executable identity), never on a substring anywhere in
# argv -- this is what makes a process that merely mentions "claude" in one of its own
# arguments (a system daemon's preference regex, a memory-tracker service's invocation
# path, this very script's own path) fail to match, without needing a bespoke exclusion
# for each such case individually.
is_claude_executable_comm() {
    local comm="$1"
    local args="${2:-}"

    case "$comm" in
        claude)
            return 0
            ;;
        node|nodejs)
            # node only qualifies when its argv additionally names a Claude CLI
            # entrypoint -- never on a bare "claude" substring elsewhere in argv.
            case "$args" in
                *claude-code*|*/claude|*/claude\ *)
                    return 0
                    ;;
                *)
                    return 1
                    ;;
            esac
            ;;
        *)
            return 1
            ;;
    esac
}

# --- Predicate 2: system-slice cgroup exclusion ---
# Returns 0 (true) when the candidate's cgroup is under /system.slice/, i.e. it is a
# system-managed service and must never be selected, regardless of anything else.
is_system_slice_cgroup() {
    local cgroup="$1"
    case "$cgroup" in
        *"/system.slice/"*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# --- Predicate 3: invoking-UID ownership ---
# Returns 0 (true) when the candidate's uid matches the invoking user's uid. A
# candidate owned by a different user/service (e.g. a system service's dedicated user)
# is excluded by the caller when this returns false.
is_owned_by_current_uid() {
    local uid="$1"
    [ "$uid" = "$CURRENT_UID" ]
}

# --- Predicate 4: inhibitor-target liveness ---
# Returns 0 (true) when this candidate's argv identifies it as a
# `systemd-inhibit ... tail --pid=<N>` sleep-inhibitor AND <N> -- a DIFFERENT process
# than the candidate itself, the session it protects -- is still alive. This is the
# only predicate that legitimately performs a live check, and it never re-checks the
# candidate's own liveness (which was already captured in the one snapshot), so it
# introduces no stale-snapshot race. Returns false (not excluded by this predicate) for
# any candidate whose argv does not carry a `--pid=<N>` inhibitor target at all.
#
# Note: with predicate 1's allow-list as narrow as documented above, a `systemd-inhibit`
# process's comm never matches it, so today's observed inhibitors are already excluded
# before reaching this predicate. It remains a required, independently-callable/testable
# layer of defense-in-depth (see the plan's Risks table) rather than dead code to be
# pruned -- do not remove it as "redundant". The liveness check itself is routed through
# an overridable seam below so a test can substitute a deterministic probe.
#
# Overridable liveness seam. Extracted verbatim from is_live_inhibitor_target so a test
# can substitute a deterministic probe for the kill -0 syscall without instrumenting the
# production predicate or teaching it that it is under test. Production behavior is
# equivalent to the previously-inlined form.
_pid_is_alive() {
    kill -0 "$1" 2>/dev/null
}

is_live_inhibitor_target() {
    local args="$1"
    local target_pid

    if [[ "$args" =~ --pid=([0-9]+) ]]; then
        target_pid="${BASH_REMATCH[1]}"
    else
        return 1
    fi

    _pid_is_alive "$target_pid"
}

# Function to get process age in human-readable format. Reads etimes from the
# already-captured snapshot -- no re-query of ps for a candidate PID.
get_process_age() {
    local elapsed="${1:-}"

    if [ -z "$elapsed" ]; then
        echo "unknown"
        return
    fi

    local hours=$((elapsed / 3600))
    local minutes=$(((elapsed % 3600) / 60))

    if [ "$hours" -gt 0 ]; then
        echo "${hours}h ${minutes}m"
    else
        echo "${minutes}m"
    fi
}

# Function to format memory size (no bc dependency)
format_memory() {
    local kb=$1
    if [ "$kb" -ge 1048576 ]; then
        local gb=$((kb / 1048576))
        local gb_frac=$(((kb % 1048576) * 10 / 1048576))
        echo "${gb}.${gb_frac} GB"
    elif [ "$kb" -ge 1024 ]; then
        local mb=$((kb / 1024))
        local mb_frac=$(((kb % 1024) * 10 / 1024))
        echo "${mb}.${mb_frac} MB"
    else
        echo "${kb} KB"
    fi
}

# Overridable /proc root seam. Mirrors the _pid_is_alive overridable-seam precedent above:
# production always resolves to the real /proc, while a test can point this at a synthetic
# fixture directory (e.g. PROC_ROOT="$WORKDIR/fakeproc") without instrumenting or otherwise
# teaching get_vmswap_kb() below that it is under test.
PROC_ROOT="${PROC_ROOT:-/proc}"

# Read VmSwap (kB) for a single PID from its /proc/<pid>/status, for reporting/accounting
# only -- see the header's invariant ruling for why this per-candidate read does not
# reopen the single-snapshot race-freedom argument. Echoes `0`, never an error, for either
# of two distinct benign cases: (1) the host has no swap configured, so the status file
# has no `VmSwap:` line at all; (2) the candidate PID already exited between the snapshot
# and this read, so the status file is unreadable. Neither case is a failure condition.
# Integer-only, no `bc`/`jq` dependency, consistent with format_memory() above. The
# `2>/dev/null` plus the empty-result fallback below leave no path where a nonzero
# awk/redirect status could propagate and abort the run under `set -euo pipefail`.
get_vmswap_kb() {
    local pid="$1"
    local kb
    kb=$(awk '/^VmSwap:/ {print $2; exit}' "$PROC_ROOT/$pid/status" 2>/dev/null || true)
    echo "${kb:-0}"
}

# Take the single atomic process snapshot. Fails loudly (non-zero exit, explicit
# message) rather than silently degrading if `ps` itself fails.
take_snapshot() {
    local out
    if ! out=$(ps -eo "$SNAPSHOT_PS_FIELDS" --no-headers 2>&1); then
        echo "ERROR: 'ps -eo $SNAPSHOT_PS_FIELDS' failed:" >&2
        echo "$out" >&2
        exit 1
    fi
    printf '%s\n' "$out"
}

# Refuse to run rather than silently falling back to an unsafe argv-substring match if
# this platform's `ps` does not support the cgroup column the safety predicates require.
validate_cgroup_support() {
    local self_cgroup
    self_cgroup=$(ps -eo cgroup:200 --no-headers -p "$$" 2>/dev/null | tr -d ' ') || true
    if [ -z "$self_cgroup" ]; then
        echo "ERROR: 'ps -o cgroup' returned no data for this process." >&2
        echo "This platform's ps may not support the cgroup column that claude-refresh.sh's" >&2
        echo "safety predicates require. Refusing to run rather than falling back to an" >&2
        echo "unsafe argv-substring match." >&2
        exit 1
    fi
}

print_help() {
    echo "Usage: $0 [--force|--dry-run]"
    echo ""
    echo "Options:"
    echo "  --force      Skip confirmation prompt and terminate immediately"
    echo "  --dry-run    Preview mode (identical to the no-flag path, with a DRY RUN banner)"
    echo "  (none)       Show status and exit (for use with /refresh command)"
}

main() {
    local FORCE=false
    local DRY_RUN=false

    for arg in "$@"; do
        case $arg in
            --force)
                FORCE=true
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            --help|-h)
                print_help
                exit 0
                ;;
            *)
                echo "Unknown option: $arg"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    validate_cgroup_support

    local snapshot
    snapshot=$(take_snapshot)

    local total_count=0 active_count=0 orphan_count=0
    local total_mem=0 active_mem=0 orphan_mem=0
    local orphan_pids=()
    local orphan_details=()

    while IFS= read -r line; do
        [ -z "$line" ] && continue || true

        local pid ppid uid tty etimes rss comm cgroup args swap_kb combined
        read -r pid ppid uid tty etimes rss comm cgroup args <<< "$line"

        # Zero-query self-exclusion: known at parse time, no second query, no race.
        if [ "$pid" = "$$" ] || [ "$ppid" = "$$" ]; then
            continue
        fi

        # Candidacy gate: must be identified as a genuine Claude executable.
        if ! is_claude_executable_comm "$comm" "$args"; then
            continue
        fi

        # Reporting-only VmSwap read (see header's invariant ruling): bounded to the
        # already-narrow comm-gated candidate set above, never the full process table.
        swap_kb=$(get_vmswap_kb "$pid")
        combined=$((rss + swap_kb))

        total_count=$((total_count + 1))
        total_mem=$((total_mem + combined))

        # tty == "?" is necessary-but-not-sufficient: true of every systemd-managed
        # process by construction, so it discriminates nothing on its own -- it is
        # combined with the exclusion predicates below, never used alone.
        if [ "$tty" != "?" ]; then
            active_count=$((active_count + 1))
            active_mem=$((active_mem + combined))
            continue
        fi

        # Orphan-candidate exclusions (defense-in-depth; see predicate docs above).
        if is_system_slice_cgroup "$cgroup"; then
            continue
        fi
        if ! is_owned_by_current_uid "$uid"; then
            continue
        fi
        if is_live_inhibitor_target "$args"; then
            continue
        fi

        # Survives every predicate: a genuine orphan.
        orphan_count=$((orphan_count + 1))
        orphan_mem=$((orphan_mem + combined))

        local age cmd_display
        age=$(get_process_age "$etimes")
        cmd_display=$(echo "$args" | cut -c1-50)

        orphan_pids+=("$pid")
        orphan_details+=("$pid|$(format_memory "$rss")|$(format_memory "$swap_kb")|$age|$cmd_display")
    done <<< "$snapshot"

    echo ""

    # No orphaned processes
    if [ "$orphan_count" -eq 0 ]; then
        echo -e "${GREEN}Claude Code Refresh${NC}"
        echo "==================="
        echo ""
        echo "No orphaned processes found."
        echo "All $active_count Claude processes are active sessions."
        exit 0
    fi

    # Default mode (no --force) - show status and exit, or --dry-run - same, with a banner.
    # The skill handles confirmation via AskUserQuestion.
    if ! $FORCE; then
        echo -e "${YELLOW}Claude Code Refresh${NC}"
        echo "==================="
        if $DRY_RUN; then
            echo ""
            echo -e "${BLUE}[DRY RUN]${NC} Preview only -- no processes will be terminated."
        fi
        echo ""
        echo "Found $orphan_count orphaned processes using $(format_memory "$orphan_mem"):"
        echo ""
        printf "%-8s %-12s %-12s %-10s %s\n" "PID" "Memory" "Swap" "Age" "Command"
        printf "%-8s %-12s %-12s %-10s %s\n" "-----" "-------" "-------" "-------" "--------------------------------"

        for detail in "${orphan_details[@]}"; do
            IFS='|' read -r pid mem swap age cmd <<< "$detail"
            printf "%-8s %-12s %-12s %-10s %s\n" "$pid" "$mem" "$swap" "$age" "$cmd"
        done

        echo ""
        echo "Total memory that can be reclaimed: $(format_memory "$orphan_mem")"
        echo ""
        # Exit here - skill will prompt with AskUserQuestion and re-run with --force if confirmed
        exit 0
    fi

    # Force mode - execute cleanup
    echo ""
    echo -e "${GREEN}Terminating orphaned processes...${NC}"

    local terminated=0
    local failed=0

    for pid in "${orphan_pids[@]}"; do
        # Check if process still exists
        if ! kill -0 "$pid" 2>/dev/null; then
            echo "  PID $pid: already gone"
            continue
        fi

        # Try SIGTERM first
        if kill -15 "$pid" 2>/dev/null; then
            sleep 0.5

            # Check if still running
            if kill -0 "$pid" 2>/dev/null; then
                # Force kill
                if kill -9 "$pid" 2>/dev/null; then
                    echo "  PID $pid: terminated (forced)"
                    terminated=$((terminated + 1))
                else
                    echo "  PID $pid: failed to terminate"
                    failed=$((failed + 1))
                fi
            else
                echo "  PID $pid: terminated (graceful)"
                terminated=$((terminated + 1))
            fi
        else
            echo "  PID $pid: failed to signal (permission denied?)"
            failed=$((failed + 1))
        fi
    done

    echo ""
    echo -e "${GREEN}Claude Code Refresh Complete${NC}"
    echo "============================"
    echo "Terminated: $terminated processes"
    echo "Failed:     $failed processes"
    echo "Memory reclaimed: ~$(format_memory "$orphan_mem")"
    echo ""
    echo "Active sessions preserved: $active_count"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
