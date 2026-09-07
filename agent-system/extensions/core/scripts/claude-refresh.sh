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

# --- Lean LSP reclamation pass: independently-gated predicates and snapshot ---
#
# This is a SEPARATE, independently-gated detection pass for orphaned Lean LSP process trees.
# lean-lsp-mcp spawns `lake serve` -> `lean --server` -> one `lean --worker` per open file, with
# no idle timeout or LRU eviction of its own (lean_lsp_mcp/client_utils.py's _close_client is
# called only at shutdown/explicit eviction, never on an idle timer -- confirmed by reading the
# installed package source). This pass shares NOTHING with the Claude pass's candidacy logic
# above: `is_claude_executable_comm` is never touched by it, `is_system_slice_cgroup` and
# `is_owned_by_current_uid` are reused UNMODIFIED as defense-in-depth, and it takes its own
# `ps -C lake,lean` snapshot rather than widening `SNAPSHOT_PS_FIELDS` (which would force every
# existing fake-`ps` test fixture to emit an extra column for a feature explicitly scoped as
# separate).
#
# Why three predicates, not comm alone: live verification (see the research report) shows `ps`'s
# `comm` field for all three Lean-family processes is just `lake` or `lean` -- the three-way
# distinction (`lake serve` vs `lean --server` vs `lean --worker`) exists only in `args`. This
# mirrors `is_claude_executable_comm`'s own `node` branch shape (comm gate + argv substring gate).
#
# Why the TTY gate cannot be reused here: live inspection showed `lake serve`/`lean --server`
# retain a non-`?` controlling tty inherited from their spawning pty even when fully orphaned;
# only `lean --worker` children show `?`. The Lean pass therefore gates candidacy on
# comm+args+cpu+age (added in a later phase), never on tty.
#
# Zombie exclusion is deliberate, not accidental: `ps` renders a defunct row's comm as
# `lake <defunct>` (observed live), which the exact `case "$comm" in lake) ...` match below
# already rejects -- signaling an already-dead zombie reclaims nothing; only its parent's `wait()`
# can reap it. Do not "fix" this into a substring match later; it would defeat the exclusion.
is_lean_serve_comm() {
    local comm="$1"
    local args="${2:-}"

    case "$comm" in
        lake)
            # Matches the leanclient-spawned shape
            # (`.../bin/lake serve -- -Dserver.reportDelayMs=0`); rejects other `lake`
            # subcommands such as `lake build` or `lake exe cache get`, which
            # leanclient/base_client.py also invokes via subprocess.run.
            case "$args" in
                *" serve"*)
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

is_lean_server_comm() {
    local comm="$1"
    local args="${2:-}"

    case "$comm" in
        lean)
            case "$args" in
                *--server*)
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

is_lean_worker_comm() {
    local comm="$1"
    local args="${2:-}"

    case "$comm" in
        lean)
            case "$args" in
                *--worker*)
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

# Idle-reclamation threshold (minutes) for the Lean pass, independent of anything the Claude
# pass uses. Default: 240 minutes, matching this repo's existing reap-threshold precedent
# (ORCHESTRATOR_SESSION_REAP_MIN, TASK_LOCK_REAP_MIN). Deliberately conservative: the single
# observed 13h-idle data point that motivated this pass argues for something well below 13h but
# still generous, since a threshold set too low costs a rebuild (lean-lsp-mcp respawns
# automatically on the next tool call) rather than any data loss. Override via
# LEAN_LSP_IDLE_THRESHOLD_MIN for a different posture.
LEAN_LSP_IDLE_THRESHOLD_MIN="${LEAN_LSP_IDLE_THRESHOLD_MIN:-240}"

# --- Lean snapshot field-index map (separate, independently-gated `ps -C lake,lean` reading) ---
# $1 pid   $2 ppid   $3 uid   $4 etimes   $5 rss   $6 pcpu   $7 cgroup   $8 comm   $9..NF args
# (cgroup is requested at the same explicit 200-column width as SNAPSHOT_PS_FIELDS above, for the
# same long-cgroup-path reason; args is again captured by `read`'s "last variable gets the
# remainder of the line" behavior.)
#
# NOTE: `-C` must not be combined with `-e` in the same invocation -- `ps -eo ... -C lake,lean`
# silently ignores the `-C` filter and returns the whole process table; `ps -C lake,lean -o ...`
# is the correct, order-sensitive form (verified live).
LEAN_SNAPSHOT_PS_FIELDS='pid,ppid,uid,etimes,rss,pcpu,cgroup:200,comm,args'

# Take the Lean-scoped process snapshot. Fails loudly (non-zero exit, explicit message) rather
# than silently degrading if `ps` itself fails, mirroring take_snapshot() above. An EMPTY result
# (no lake/lean processes running at all) is the NORMAL case, not an error -- `ps -C` with zero
# matches exits 1 with empty stdout/stderr, which is distinguished below from a genuine `ps`
# failure (which always emits a non-empty error message).
take_lean_snapshot() {
    local out
    local rc=0
    out=$(ps -C lake,lean -o "$LEAN_SNAPSHOT_PS_FIELDS" --no-headers 2>&1) || rc=$?
    if [ "$rc" -ne 0 ] && [ -n "$out" ]; then
        echo "ERROR: 'ps -C lake,lean -o $LEAN_SNAPSHOT_PS_FIELDS' failed:" >&2
        echo "$out" >&2
        exit 1
    fi
    printf '%s\n' "$out"
}

# --- Lean tree-wide idle gate ---
# Returns 0 (true) when a SINGLE snapshot row (already comm+args-classified as lake-serve/
# lean-server/lean-worker) is individually idle: `pcpu` at/near zero AND `etimes` at/beyond the
# configurable threshold. Called once per tree MEMBER by detect_lean_candidate_trees() below; a
# tree as a whole is a reclamation candidate only if EVERY member independently passes this gate
# -- one freshly-spawned or actively-computing member protects the entire tree, not just itself.
#
# pcpu handling: ps's `pcpu` column (procps-ng) is a decaying-average percentage rendered as a
# decimal (e.g. "0.3", "3.0", "555"). This script's other numeric helpers (format_memory,
# get_vmswap_kb) are integer-only by convention (no bc/jq dependency); the same convention is
# followed here by comparing only the pre-decimal portion via bash's `${pcpu%%.*}` parameter
# expansion. A value like "0.3" truncates to "0" (treated as idle -- a genuinely idle process
# occasionally reports a small nonzero decaying average, and 240-minute-default etimes gating is
# the primary discriminator, not sub-1% pcpu noise); a value like "3.0" truncates to "3" (treated
# as busy). This is documented, not incidental: it means anything reporting 1% or more CPU is
# never considered idle, while sub-1% readings defer entirely to the etimes threshold.
lean_row_is_idle() {
    local etimes="$1"
    local pcpu="$2"
    local pcpu_int="${pcpu%%.*}"

    # Defensive guard: a malformed/empty field must never be misjudged as "idle" by an arithmetic
    # fallback. This should not happen from a well-formed ps row, but is not assumed.
    [[ "$pcpu_int" =~ ^[0-9]+$ ]] || return 1
    [[ "$etimes" =~ ^[0-9]+$ ]] || return 1

    if [ "$pcpu_int" -gt 0 ]; then
        return 1
    fi

    local threshold_seconds=$((LEAN_LSP_IDLE_THRESHOLD_MIN * 60))
    [ "$etimes" -ge "$threshold_seconds" ]
}

# --- Lean tree assembly and tree-wide candidacy gate ---
# Parses take_lean_snapshot()'s frozen rows into pid-keyed, comm-classified data, assembles each
# `lake serve` -> `lean --server` -> N x `lean --worker` tree via `ppid` links entirely in-memory
# (no live re-query -- the same single-atomic-snapshot philosophy as the Claude pass, applied to
# this separately-gated pass's own snapshot), and populates the LEAN_TREE_* arrays below for
# every tree that passes the tree-wide gate. `is_system_slice_cgroup`/`is_owned_by_current_uid`
# are reused UNMODIFIED against every Lean row, exactly as the Claude pass uses them, per the
# dispatch's "reuse as defense in depth" instruction.
#
# Edge cases (named, not accidental): a `lake serve` with no discovered `lean --server` child is
# still eligible when idle (tree = {root only} -- a done-but-not-yet-torn-down `lake serve` with
# no server is itself reclaimable); a server with zero workers (no files open) is likewise still
# eligible when idle (tree = {root, server}).
#
# Uses parallel indexed arrays throughout, no associative arrays, matching this script's existing
# style (no bash-4-only features required). Safe to call standalone/repeatedly (e.g. from tests):
# it only reads take_lean_snapshot()'s output and this function's own local/global arrays, and
# never signals a process.
#
# Populated on return (indexed 0..N-1, one entry per ELIGIBLE tree; all four arrays are reset at
# the start of every call):
#   LEAN_TREE_ROOT_PID[i]    -- the tree's `lake serve` pid
#   LEAN_TREE_SERVER_PID[i]  -- the tree's `lean --server` pid, or "" if none was found
#   LEAN_TREE_WORKER_PIDS[i] -- space-separated `lean --worker` pids (may be empty)
#   LEAN_TREE_MEM_KB[i]      -- combined rss+VmSwap across every member, in KB (reporting only)
detect_lean_candidate_trees() {
    LEAN_TREE_ROOT_PID=()
    LEAN_TREE_SERVER_PID=()
    LEAN_TREE_WORKER_PIDS=()
    LEAN_TREE_MEM_KB=()

    local snapshot
    snapshot=$(take_lean_snapshot)

    local -a row_pid=() row_ppid=() row_uid=() row_etimes=() row_rss=() row_pcpu=() row_cgroup=()
    local -a row_kind=()  # serve|server|worker (rows failing all three predicates are dropped)

    while IFS= read -r line; do
        [ -z "$line" ] && continue || true

        local pid ppid uid etimes rss pcpu cgroup comm args
        read -r pid ppid uid etimes rss pcpu cgroup comm args <<< "$line"

        # Zero-query self-exclusion, same rationale as the Claude pass above.
        if [ "$pid" = "$$" ] || [ "$ppid" = "$$" ]; then
            continue
        fi

        local kind=""
        if is_lean_serve_comm "$comm" "$args"; then
            kind="serve"
        elif is_lean_server_comm "$comm" "$args"; then
            kind="server"
        elif is_lean_worker_comm "$comm" "$args"; then
            kind="worker"
        else
            continue
        fi

        row_pid+=("$pid"); row_ppid+=("$ppid"); row_uid+=("$uid")
        row_etimes+=("$etimes"); row_rss+=("$rss"); row_pcpu+=("$pcpu")
        row_cgroup+=("$cgroup"); row_kind+=("$kind")
    done <<< "$snapshot"

    local n="${#row_pid[@]}"
    local i j

    for ((i = 0; i < n; i++)); do
        [ "${row_kind[$i]}" = "serve" ] || continue

        local root_pid="${row_pid[$i]}"
        local server_idx=-1
        local -a worker_idxs=()

        for ((j = 0; j < n; j++)); do
            if [ "${row_kind[$j]}" = "server" ] && [ "${row_ppid[$j]}" = "$root_pid" ]; then
                server_idx=$j
                break
            fi
        done

        if [ "$server_idx" -ge 0 ]; then
            local server_pid="${row_pid[$server_idx]}"
            for ((j = 0; j < n; j++)); do
                if [ "${row_kind[$j]}" = "worker" ] && [ "${row_ppid[$j]}" = "$server_pid" ]; then
                    worker_idxs+=("$j")
                fi
            done
        fi

        # Tree-wide gate: EVERY member (root + server if present + all workers) must pass
        # idle+exclusion. A single non-passing member disqualifies the whole tree.
        local -a member_idxs=("$i")
        [ "$server_idx" -ge 0 ] && member_idxs+=("$server_idx")
        member_idxs+=("${worker_idxs[@]}")

        local tree_ok=true
        local m
        for m in "${member_idxs[@]}"; do
            if is_system_slice_cgroup "${row_cgroup[$m]}"; then
                tree_ok=false
                break
            fi
            if ! is_owned_by_current_uid "${row_uid[$m]}"; then
                tree_ok=false
                break
            fi
            if ! lean_row_is_idle "${row_etimes[$m]}" "${row_pcpu[$m]}"; then
                tree_ok=false
                break
            fi
        done

        if ! $tree_ok; then
            continue
        fi

        # Reporting-only, same invariant ruling as the header comment above documents for the
        # Claude pass: this per-member get_vmswap_kb() read happens strictly AFTER tree_ok has
        # already been decided from the frozen snapshot above, so it cannot influence which tree
        # is selected as a candidate -- it only affects the displayed/accumulated memory figure.
        local mem_total=0
        local swap_kb
        for m in "${member_idxs[@]}"; do
            swap_kb=$(get_vmswap_kb "${row_pid[$m]}")
            mem_total=$((mem_total + row_rss[m] + swap_kb))
        done

        local worker_pids=""
        for j in "${worker_idxs[@]}"; do
            worker_pids="${worker_pids:+$worker_pids }${row_pid[$j]}"
        done

        LEAN_TREE_ROOT_PID+=("$root_pid")
        if [ "$server_idx" -ge 0 ]; then
            LEAN_TREE_SERVER_PID+=("${row_pid[$server_idx]}")
        else
            LEAN_TREE_SERVER_PID+=("")
        fi
        LEAN_TREE_WORKER_PIDS+=("$worker_pids")
        LEAN_TREE_MEM_KB+=("$mem_total")
    done
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
    echo ""
    echo "Environment:"
    echo "  LEAN_LSP_IDLE_THRESHOLD_MIN   Idle-reclamation threshold in minutes for the"
    echo "                                separately-gated Lean LSP process-tree pass"
    echo "                                (default: 240)"
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
