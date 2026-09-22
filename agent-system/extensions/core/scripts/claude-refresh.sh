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
#   Widened self-exclusion for the build-waiter reaper pass (run_build_waiter_pass, below): a
#   reaper for the bounded-build-waiter poll-loop idiom must exclude not only its own pid/ppid
#   (as above) but also its own process group and its full ancestor chain up to PID 1 -- a caller
#   that itself matches the very poll-loop shape being reaped (an orchestrating shell awaiting
#   this refresh invocation, for instance) must never be signaled. That pass takes its OWN
#   `ps -eo` snapshot (its own field list, adding `pgid`) rather than widening SNAPSHOT_PS_FIELDS
#   above -- see that pass's own header comment for the full rationale, matching the
#   independent-snapshot precedent every non-Claude pass in this script already follows. Its
#   detection, like every predicate in this file, reads structured `ps` columns only -- never a
#   name-substring process search or `ps | grep` -- because a name-matching cleanup command is
#   exactly the defect class this pass exists to reap (see that pass's header comment for the
#   incident it fixes).
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
#   LEAN_TREE_MEMBER_DETAILS[i] -- one string, newline-separated "pid|role|mem|swap|age" lines
#                                  (root, then server if present, then each worker), for the
#                                  per-PID reporting table -- no 2D bash arrays are used anywhere
#                                  in this script, matching its existing style
detect_lean_candidate_trees() {
    LEAN_TREE_ROOT_PID=()
    LEAN_TREE_SERVER_PID=()
    LEAN_TREE_WORKER_PIDS=()
    LEAN_TREE_MEM_KB=()
    LEAN_TREE_MEMBER_DETAILS=()

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
        local swap_kb role_label age member_details=""
        for m in "${member_idxs[@]}"; do
            swap_kb=$(get_vmswap_kb "${row_pid[$m]}")
            mem_total=$((mem_total + row_rss[m] + swap_kb))

            case "${row_kind[$m]}" in
                serve) role_label="lake serve" ;;
                server) role_label="lean --server" ;;
                worker) role_label="lean --worker" ;;
            esac
            age=$(get_process_age "${row_etimes[$m]}")
            member_details="${member_details}${row_pid[$m]}|${role_label}|$(format_memory "${row_rss[$m]}")|$(format_memory "$swap_kb")|${age}"$'\n'
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
        LEAN_TREE_MEMBER_DETAILS+=("$member_details")
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

# Shared SIGTERM->sleep->SIGKILL escalation helper. Extracted verbatim (same signals, same
# sleep duration, same messages, same outcome boundaries) from the Claude pass's original inline
# termination loop body, so BOTH passes share one escalation implementation rather than
# duplicating it -- required for the Lean pass's per-tree ordered termination (workers -> server
# -> `lake serve`) below, and used unchanged by the Claude pass's own loop, which now calls this
# instead of inlining the same five lines.
#
# Return codes (never a plain boolean -- the caller must distinguish three outcomes to reproduce
# the original loop's exact counting behavior):
#   0 -- terminated (graceful SIGTERM, or escalated to SIGKILL)
#   1 -- failed (permission denied on SIGTERM, or the escalated SIGKILL itself failed)
#   2 -- already gone before this call touched it (the original loop's `continue` fired before
#        either its `terminated` or `failed` counter was touched; callers must not count this as
#        either)
#
# Callers MUST invoke this from an `if`/`||`/`&&` context (never as a bare statement) since a
# return of 1 or 2 is an expected, common outcome, not a script-ending error -- a bare invocation
# under this script's `set -e` would otherwise abort the whole script on the very first
# already-gone or permission-denied PID.
terminate_pid() {
    local pid="$1"

    if ! kill -0 "$pid" 2>/dev/null; then
        echo "  PID $pid: already gone"
        return 2
    fi

    if kill -15 "$pid" 2>/dev/null; then
        sleep 0.5

        if kill -0 "$pid" 2>/dev/null; then
            if kill -9 "$pid" 2>/dev/null; then
                echo "  PID $pid: terminated (forced)"
                return 0
            else
                echo "  PID $pid: failed to terminate"
                return 1
            fi
        else
            echo "  PID $pid: terminated (graceful)"
            return 0
        fi
    else
        echo "  PID $pid: failed to signal (permission denied?)"
        return 1
    fi
}

print_help() {
    echo "Usage: $0 [--force|--dry-run]"
    echo ""
    echo "Runs five passes every invocation, in this fixed order: Claude-process reclamation,"
    echo "Lean LSP process-tree reclamation, orphaned build-waiter poll-loop reaping, zombie"
    echo "(unreaped-child) reporting, and MCP server fan-out reporting. The first two terminate"
    echo "only under --force; the build-waiter pass terminates whenever --dry-run is not set,"
    echo "unaffected by --force (age-threshold-only gate); the last two never terminate anything."
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
    echo "  BUILD_WAITER_REAP_MIN         Idle-reclamation threshold in minutes for the"
    echo "                                orphaned build-waiter poll-loop pass (default: 60)"
    echo "  BUILD_WAITER_CEILING_MIN      Secondary ceiling in minutes for a build-waiter whose"
    echo "                                embedded writer PID may have been reused (default: 240)"
}

# Run the existing Claude-process orphan pass: report (default/--dry-run) or terminate
# (--force). This is the ORIGINAL candidacy/exclusion/termination logic, extracted from main()
# unchanged in every observable respect (output lines, ordering, counting) except that its two
# early-exit sites now `return` instead of `exit`, so the separately-gated Lean pass below can
# always run afterward regardless of which branch this pass takes. The termination loop now
# calls the shared terminate_pid() helper instead of inlining the escalation, but reproduces its
# exact counting behavior (terminated/failed/already-gone) via terminate_pid()'s three-way return
# code -- see that function's own comment for why a bare invocation would be unsafe under `set -e`.
run_claude_pass() {
    local FORCE="$1"
    local DRY_RUN="$2"

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
        return 0
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
        # Return here - skill will prompt with AskUserQuestion and re-run with --force if confirmed
        return 0
    fi

    # Force mode - execute cleanup
    echo ""
    echo -e "${GREEN}Terminating orphaned processes...${NC}"

    local terminated=0
    local failed=0

    for pid in "${orphan_pids[@]}"; do
        local rc
        if terminate_pid "$pid"; then
            rc=0
        else
            rc=$?
        fi
        case "$rc" in
            0) terminated=$((terminated + 1)) ;;
            1) failed=$((failed + 1)) ;;
            2) ;; # already gone; not counted, matching the original loop's behavior
        esac
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

# Run the new, independently-gated Lean LSP process-tree pass: report (default/--dry-run) or
# terminate (--force). Participates in the SAME --dry-run/--force contract as the Claude pass
# above without adding a flag of its own, and always runs after run_claude_pass() regardless of
# which branch that pass took (see main()'s restructure comment). Shares only two things with
# the Claude pass: the terminate_pid() escalation helper, and the is_system_slice_cgroup/
# is_owned_by_current_uid exclusion predicates (both reused unmodified) -- candidacy, snapshot,
# and tree-wide gating are entirely separate (detect_lean_candidate_trees()).
run_lean_pass() {
    local FORCE="$1"
    local DRY_RUN="$2"

    detect_lean_candidate_trees

    local n_trees="${#LEAN_TREE_ROOT_PID[@]}"

    echo ""
    echo -e "${GREEN}Lean LSP Process-Tree Reclamation${NC}"
    echo "=================================="

    # No idle Lean LSP process trees found -- an explicit, non-alarming line, never silence.
    if [ "$n_trees" -eq 0 ]; then
        echo ""
        echo "No idle Lean LSP process trees found."
        return 0
    fi

    local total_mem_kb=0
    local i
    for ((i = 0; i < n_trees; i++)); do
        total_mem_kb=$((total_mem_kb + LEAN_TREE_MEM_KB[i]))
    done

    # Default mode (no --force) - show status and return, or --dry-run - same, with a banner.
    # Identical no-flag/--dry-run equivalence as the Claude pass: --dry-run adds the banner, the
    # no-flag path is otherwise the same report. Neither path signals any process -- this is the
    # pass's --dry-run-clean guarantee.
    if ! $FORCE; then
        if $DRY_RUN; then
            echo ""
            echo -e "${BLUE}[DRY RUN]${NC} Preview only -- no processes will be terminated."
        fi
        echo ""
        echo "Found $n_trees idle Lean LSP process tree(s) using $(format_memory "$total_mem_kb"):"

        for ((i = 0; i < n_trees; i++)); do
            echo ""
            echo "Tree $((i + 1)) (root PID ${LEAN_TREE_ROOT_PID[$i]}, $(format_memory "${LEAN_TREE_MEM_KB[$i]}")):"
            printf "  %-8s %-16s %-12s %-12s %s\n" "PID" "Role" "Memory" "Swap" "Age"
            printf "  %-8s %-16s %-12s %-12s %s\n" "-----" "----------------" "-------" "-------" "-------"

            while IFS= read -r member_line; do
                [ -z "$member_line" ] && continue || true
                local mpid mrole mmem mswap mage
                IFS='|' read -r mpid mrole mmem mswap mage <<< "$member_line"
                printf "  %-8s %-16s %-12s %-12s %s\n" "$mpid" "$mrole" "$mmem" "$mswap" "$mage"
            done <<< "${LEAN_TREE_MEMBER_DETAILS[$i]}"
        done

        echo ""
        echo "Total memory that can be reclaimed: $(format_memory "$total_mem_kb")"
        echo ""
        # Return here - skill will prompt with AskUserQuestion and re-run with --force if confirmed
        return 0
    fi

    # Force mode - terminate every candidate tree strictly workers -> server -> `lake serve`.
    # Multiple trees are handled one at a time, each fully ordered (siblings within a tree, i.e.
    # multiple workers, may be signaled in any order relative to each other -- only the
    # cross-role ordering is a documented guarantee).
    echo ""
    echo -e "${GREEN}Terminating idle Lean LSP process trees...${NC}"

    local terminated=0
    local failed=0

    for ((i = 0; i < n_trees; i++)); do
        local -a ordered_pids=()
        local wpid
        for wpid in ${LEAN_TREE_WORKER_PIDS[$i]}; do
            ordered_pids+=("$wpid")
        done
        if [ -n "${LEAN_TREE_SERVER_PID[$i]}" ]; then
            ordered_pids+=("${LEAN_TREE_SERVER_PID[$i]}")
        fi
        ordered_pids+=("${LEAN_TREE_ROOT_PID[$i]}")

        local pid rc
        for pid in "${ordered_pids[@]}"; do
            if terminate_pid "$pid"; then
                rc=0
            else
                rc=$?
            fi
            case "$rc" in
                0) terminated=$((terminated + 1)) ;;
                1) failed=$((failed + 1)) ;;
                2) ;; # already gone; not counted
            esac
        done
    done

    echo ""
    echo -e "${GREEN}Lean LSP Reclamation Complete${NC}"
    echo "=============================="
    echo "Terminated: $terminated processes"
    echo "Failed:     $failed processes"
    echo "Memory reclaimed: ~$(format_memory "$total_mem_kb")"
}

# --- Orphaned build-waiter poll-loop reaper: independently-gated, own snapshot ---
#
# A third, independently-gated pass. Reaps orphaned build-waiter poll loops -- the bounded-
# build-waiter idiom (context/patterns/bounded-build-waiter.md) once its writer PID is dead, plus
# the legacy self-match name-poll shape that idiom replaces. This pass exists because of a second
# observed instance of the exact defect class the header comment at the top of this script
# documents for the Claude pass: an ad-hoc process-name-substring cleanup command (searching for
# `until grep`, piped into a `kill`) matched ITS OWN command line (the pattern it searched for was
# present in its own argv) and killed its own shell (exit 144) -- twice. This pass is the
# correct-by-construction fix: it takes its OWN atomic `ps -eo` snapshot (never a name-substring
# process search or `ps | grep`), and its self-exclusion set
# covers not just pid/ppid (the Claude/Lean passes' zero-query idiom above) but also this script's
# own process group and its full ancestor chain up to PID 1 -- all read from that one frozen
# snapshot, with no second query. If this pass's own row ($$) is missing from the snapshot, it
# fails closed: one warning, nothing reaped.
#
# Gate class: age-threshold-only (see BUILD_WAITER_REAP_MIN/BUILD_WAITER_CEILING_MIN below),
# and this is the first pass in this script whose destructive action is NOT gated by $FORCE --
# see run_build_waiter_pass()'s own termination-call-site comment for why that is deliberate, not
# an oversight.
#
# Two signature families (never widened to a generic "any idle bash loop" heuristic):
#   Family A (canonical): `timeout N bash -c 'while kill -0 "$1" ...; do sleep N; done' _ "$pid"`
#     -- the bounded-build-waiter idiom itself. The embedded trailing PID is the writer; if that
#     writer is dead (per the overridable `_pid_is_alive` seam above) OR the waiter has passed the
#     secondary ceiling (BUILD_WAITER_CEILING_MIN, a PID-reuse backstop), it is a candidate once
#     also idle past BUILD_WAITER_REAP_MIN.
#   Family B (legacy/name-match): `until grep -q ...` sentinel polls and `until ! ps aux | grep
#     -q ...` self-match polls -- the incident class this task fixes. These carry no writer PID,
#     so they are candidates on idle+age alone, past BUILD_WAITER_REAP_MIN.
#
# Detection is from structured `ps -eo` columns only -- never a name-substring process search or
# `ps | grep` -- so this pass cannot repeat the self-match defect it exists to reap.
BUILD_WAITER_SNAPSHOT_PS_FIELDS='pid,ppid,pgid,uid,etimes,pcpu,cgroup:200,comm,args'

# Idle-reclamation threshold (minutes): a Family B waiter (or a Family A waiter with a still-live
# writer, below the ceiling) is a candidate once idle at/beyond this age. Default 60 minutes: the
# observed orphans ran 24-55 minutes at 0% CPU, and a legitimate foreground wait is bounded by the
# Bash tool's own cap while a canonical detached waiter is bounded by its own `timeout`, so this
# clears legitimate waits with margin while still catching the leak class within an hour. Override
# via the environment, following the LEAN_LSP_IDLE_THRESHOLD_MIN precedent.
BUILD_WAITER_REAP_MIN="${BUILD_WAITER_REAP_MIN:-60}"

# Secondary ceiling (minutes): a Family A waiter whose embedded writer PID has been reused by an
# unrelated process (so `_pid_is_alive` reports "alive" for the wrong reason) is still reaped once
# idle past this much higher bound, matching the Lean/session-reap precedent
# (LEAN_LSP_IDLE_THRESHOLD_MIN/ORCHESTRATOR_SESSION_REAP_MIN default of 240). Override via the
# environment.
BUILD_WAITER_CEILING_MIN="${BUILD_WAITER_CEILING_MIN:-240}"

# Take the build-waiter-scoped process snapshot -- its OWN `ps -eo` call with its OWN field list
# (adding `pgid` to the columns every other pass already reads), following the Lean/zombie/MCP
# passes' established precedent of never widening SNAPSHOT_PS_FIELDS for a new pass's extra
# column. Fails loudly (non-zero exit, explicit message) rather than silently degrading if `ps`
# itself fails, mirroring every other take_*_snapshot() above.
take_build_waiter_snapshot() {
    local out
    if ! out=$(ps -eo "$BUILD_WAITER_SNAPSHOT_PS_FIELDS" --no-headers 2>&1); then
        echo "ERROR: 'ps -eo $BUILD_WAITER_SNAPSHOT_PS_FIELDS' failed:" >&2
        echo "$out" >&2
        exit 1
    fi
    printf '%s\n' "$out"
}

# --- Shell-executable-identity gate ---
# Returns 0 (true) only when `comm` is exactly `bash` or `sh` -- the executable-identity gate is
# on `comm`, never on argv, mirroring is_claude_executable_comm's own comm-first discipline above.
is_shell_comm() {
    local comm="$1"
    case "$comm" in
        bash|sh)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# --- Build-waiter family classifier ---
# Classifies a row's argv into Family A, Family B, or neither (see the pass header comment above
# for both shapes). For Family A, extracts the trailing embedded writer PID with a bash regex --
# the same is_live_inhibitor_target idiom used above, never a second live process-search query.
# Sets the global BUILD_WAITER_EMBEDDED_PID as an additional output (always cleared first;
# populated only on a Family A match). A Family A-shaped argv whose trailing token does not parse
# as a PID is classified as neither (fails closed -- excluded, not misclassified as Family B).
BUILD_WAITER_EMBEDDED_PID=""

build_waiter_family() {
    local args="$1"
    BUILD_WAITER_EMBEDDED_PID=""

    if [[ "$args" == *"kill -0"* && "$args" == *"sleep"* ]]; then
        if [[ "$args" =~ ([0-9]+)[[:space:]]*$ ]]; then
            BUILD_WAITER_EMBEDDED_PID="${BASH_REMATCH[1]}"
            echo "A"
        else
            echo ""
        fi
        return 0
    fi

    if [[ ( "$args" == *"until"* || "$args" == *"while"* ) && "$args" == *"grep -q"* && "$args" == *"sleep"* ]]; then
        echo "B"
        return 0
    fi

    echo ""
}

# --- Row-level idle gate ---
# Returns 0 (true) when a row is individually idle: `pcpu` truncated to its integer portion is 0,
# AND `etimes` is at/beyond a caller-supplied threshold (in minutes). Reuses lean_row_is_idle's
# integer-truncation idiom (see that function's own comment for the rationale) rather than calling
# it directly, since this pass's threshold is independently configurable
# (BUILD_WAITER_REAP_MIN/BUILD_WAITER_CEILING_MIN), not LEAN_LSP_IDLE_THRESHOLD_MIN.
build_waiter_row_is_idle() {
    local etimes="$1"
    local pcpu="$2"
    local threshold_min="$3"
    local pcpu_int="${pcpu%%.*}"

    [[ "$pcpu_int" =~ ^[0-9]+$ ]] || return 1
    [[ "$etimes" =~ ^[0-9]+$ ]] || return 1

    if [ "$pcpu_int" -gt 0 ]; then
        return 1
    fi

    local threshold_seconds=$((threshold_min * 60))
    [ "$etimes" -ge "$threshold_seconds" ]
}

# --- Self-exclusion set: own pgid + full ancestor chain, from ONE frozen snapshot ---
# Widens self-exclusion from pid/ppid (the Claude/Lean passes' zero-query idiom above) to pid,
# ppid, pgid, AND the full ancestor chain up to PID 1 -- because a reaper for a poll-loop idiom
# specifically must not signal its own shell OR any shell in its own ancestor chain (a caller that
# itself matches Family B's shape, for instance, such as an orchestrating shell awaiting this very
# refresh invocation). Re-parses the same snapshot string the caller already has (cheap, one-time
# cost per invocation) so this function stays self-contained and independently testable with a
# synthetic snapshot string, matching every take_*_snapshot()/detect_*() function's own-parsing
# style above. Populates two globals:
#   BUILD_WAITER_SELF_PGID     -- this script's own pgid (from the row where pid == $$)
#   BUILD_WAITER_ANCESTOR_PIDS -- space-separated pids from $$ up to (not including) PID 1
# Returns non-zero, with both globals left empty, if the $$ row is not present in the snapshot --
# the caller's contract is to fail closed (reap nothing, print one warning) in that case, never to
# guess or fall back to a second query.
BUILD_WAITER_SELF_PGID=""
BUILD_WAITER_ANCESTOR_PIDS=""

build_self_exclusion_set() {
    local snapshot="$1"

    BUILD_WAITER_SELF_PGID=""
    BUILD_WAITER_ANCESTOR_PIDS=""

    local -a all_pid=() all_ppid=() all_pgid=()
    local line
    while IFS= read -r line; do
        [ -z "$line" ] && continue || true
        local pid ppid pgid uid etimes pcpu cgroup comm args
        read -r pid ppid pgid uid etimes pcpu cgroup comm args <<< "$line"
        all_pid+=("$pid"); all_ppid+=("$ppid"); all_pgid+=("$pgid")
    done <<< "$snapshot"

    local n="${#all_pid[@]}"
    local i self_idx=-1
    for ((i = 0; i < n; i++)); do
        if [ "${all_pid[$i]}" = "$$" ]; then
            self_idx=$i
            break
        fi
    done

    if [ "$self_idx" -lt 0 ]; then
        return 1
    fi

    BUILD_WAITER_SELF_PGID="${all_pgid[$self_idx]}"

    local cur_pid="$$"
    local hops=0
    local ancestors=""
    while [ "$cur_pid" != "1" ] && [ "$hops" -lt 50 ]; do
        local found=-1
        for ((i = 0; i < n; i++)); do
            if [ "${all_pid[$i]}" = "$cur_pid" ]; then
                found=$i
                break
            fi
        done
        [ "$found" -ge 0 ] || break
        ancestors="${ancestors:+$ancestors }$cur_pid"
        cur_pid="${all_ppid[$found]}"
        hops=$((hops + 1))
    done

    BUILD_WAITER_ANCESTOR_PIDS="$ancestors"
    return 0
}

# Run the orphaned build-waiter poll-loop reaper. Always runs after run_lean_pass(), keeping the
# two destructive passes adjacent in main()'s fixed sequence, before the report-only zombie/MCP
# passes. Accepts the same ($FORCE, $DRY_RUN) calling convention as every other pass purely for
# call-site symmetry -- see the termination call site below for why $FORCE is never branched on.
run_build_waiter_pass() {
    local FORCE="$1"
    local DRY_RUN="$2"

    local snapshot
    snapshot=$(take_build_waiter_snapshot)

    echo ""
    echo -e "${GREEN}Orphaned Build-Waiter Poll Loops${NC}"
    echo "================================="

    if ! build_self_exclusion_set "$snapshot"; then
        echo ""
        echo "WARNING: this script's own process row was not found in the build-waiter snapshot" >&2
        echo "-- refusing to reap anything this invocation (fail-closed)." >&2
        return 0
    fi

    local -a ancestor_pids=()
    read -r -a ancestor_pids <<< "$BUILD_WAITER_ANCESTOR_PIDS"

    local -a candidate_pids=()
    local -a candidate_details=()
    local ceiling_seconds=$((BUILD_WAITER_CEILING_MIN * 60))

    local line
    while IFS= read -r line; do
        [ -z "$line" ] && continue || true

        local pid ppid pgid uid etimes pcpu cgroup comm args
        read -r pid ppid pgid uid etimes pcpu cgroup comm args <<< "$line"

        # Numeric-column validation: skip a malformed row rather than misreading it (fail
        # closed). Required because this suite's fake `ps` fixtures for OTHER passes may emit
        # rows in the wrong column shape for an unrecognized `-eo` field spec (see Phase 2's
        # scope hypothesis in the plan) -- this pass must never misinterpret such a row.
        [[ "$pid" =~ ^[0-9]+$ ]] || continue
        [[ "$ppid" =~ ^[0-9]+$ ]] || continue
        [[ "$pgid" =~ ^[0-9]+$ ]] || continue
        [[ "$uid" =~ ^[0-9]+$ ]] || continue
        [[ "$etimes" =~ ^[0-9]+$ ]] || continue
        [[ "$pcpu" =~ ^[0-9]+([.][0-9]+)?$ ]] || continue

        # Exclusions, in order: pid == $$, ppid == $$, pgid == self_pgid, pid in the ancestor
        # set, system-slice cgroup, foreign uid, non-shell comm.
        if [ "$pid" = "$$" ] || [ "$ppid" = "$$" ]; then
            continue
        fi
        if [ -n "$BUILD_WAITER_SELF_PGID" ] && [ "$pgid" = "$BUILD_WAITER_SELF_PGID" ]; then
            continue
        fi
        local is_ancestor=false
        local a
        for a in "${ancestor_pids[@]}"; do
            if [ "$pid" = "$a" ]; then
                is_ancestor=true
                break
            fi
        done
        $is_ancestor && continue
        is_system_slice_cgroup "$cgroup" && continue
        is_owned_by_current_uid "$uid" || continue
        is_shell_comm "$comm" || continue

        local family
        family=$(build_waiter_family "$args")
        [ -n "$family" ] || continue
        local embedded_pid="$BUILD_WAITER_EMBEDDED_PID"

        local is_candidate=false
        local reason=""
        if [ "$family" = "A" ]; then
            if build_waiter_row_is_idle "$etimes" "$pcpu" "$BUILD_WAITER_REAP_MIN"; then
                if ! _pid_is_alive "$embedded_pid"; then
                    is_candidate=true
                    reason="dead writer (pid $embedded_pid)"
                elif [ "$etimes" -ge "$ceiling_seconds" ]; then
                    is_candidate=true
                    reason="past ceiling (writer pid $embedded_pid still reports alive)"
                fi
            fi
        elif [ "$family" = "B" ]; then
            if build_waiter_row_is_idle "$etimes" "$pcpu" "$BUILD_WAITER_REAP_MIN"; then
                is_candidate=true
                reason="legacy name-match/sentinel poll, idle past threshold"
            fi
        fi

        $is_candidate || continue

        local age cmd_display
        age=$(get_process_age "$etimes")
        cmd_display=$(echo "$args" | cut -c1-50)

        candidate_pids+=("$pid")
        candidate_details+=("$pid|$family|$age|$reason|$cmd_display")
    done <<< "$snapshot"

    local n_candidates="${#candidate_pids[@]}"

    if [ "$n_candidates" -eq 0 ]; then
        echo ""
        echo "No orphaned build waiters found."
        return 0
    fi

    if $DRY_RUN; then
        echo ""
        echo -e "${BLUE}[DRY RUN]${NC} Preview only -- no processes will be terminated."
    fi

    echo ""
    echo "Found $n_candidates orphaned build-waiter poll loop(s):"
    echo ""
    printf "%-8s %-8s %-10s %-45s %s\n" "PID" "Family" "Age" "Reason" "Command"
    printf "%-8s %-8s %-10s %-45s %s\n" "-----" "------" "-------" "---------------------------------------------" "--------------------------------"

    local detail
    for detail in "${candidate_details[@]}"; do
        local dpid dfamily dage dreason dcmd
        IFS='|' read -r dpid dfamily dage dreason dcmd <<< "$detail"
        printf "%-8s %-8s %-10s %-45s %s\n" "$dpid" "$dfamily" "$dage" "$dreason" "$dcmd"
    done

    if $DRY_RUN; then
        return 0
    fi

    # Deliberate divergence from rows 1-2 (the interactive-confirm Claude/Lean process passes
    # above): this pass's gate is age-threshold-only, matching the age-threshold-only
    # spec-directory sweeps (rows 5-8 of the pass inventory), not the interactive-confirm process
    # passes. Reaping happens unconditionally whenever $DRY_RUN is unset, WHATEVER the value of
    # $FORCE -- $FORCE is accepted above only for call-site symmetry with
    # run_claude_pass/run_lean_pass/run_zombie_pass/run_mcp_fanout_pass and is never branched on
    # here. This is the first pass in this script whose destructive action is not gated by
    # $FORCE; both pass-inventory docs (refresh.md, SKILL.md) say so explicitly.
    echo ""
    echo -e "${GREEN}Terminating orphaned build-waiter poll loops...${NC}"

    local terminated=0
    local failed=0

    for pid in "${candidate_pids[@]}"; do
        local rc
        if terminate_pid "$pid"; then
            rc=0
        else
            rc=$?
        fi
        case "$rc" in
            0) terminated=$((terminated + 1)) ;;
            1) failed=$((failed + 1)) ;;
            2) ;; # already gone; not counted
        esac
    done

    echo ""
    echo "Terminated: $terminated processes"
    echo "Failed:     $failed processes"
}

# --- Unreaped-child (zombie) reporting pass: independently-gated, report-only ---
#
# A fourth, independently-gated pass. Unlike run_claude_pass()/run_lean_pass() above, this pass
# NEVER terminates anything under ANY flag combination -- there is no `$FORCE` branch at all,
# because a zombie can only be reaped by its own parent calling wait(); no external signal can
# reap one (sending a zombie a signal is a silent no-op -- it is already dead, only its exit
# status remains). Reporting this is still valuable: an unreaped zombie is a symptom of a parent
# that leaked a wait() call (lean-lsp-mcp never wait()s its `lake` child; speech-dispatcher has
# been observed leaking `sd_*` zombies over days), and surfacing it lets a human decide whether
# the owning daemon itself needs fixing -- this pass's job stops at reporting, not fixing.
#
# Takes its OWN independent `ps -eo` snapshot (ZOMBIE_SNAPSHOT_PS_FIELDS below) rather than
# widening SNAPSHOT_PS_FIELDS or LEAN_SNAPSHOT_PS_FIELDS, mirroring the Lean pass's own
# independent-snapshot precedent above: widening an existing fixed-width `read` would silently
# break every synthetic test fixture that reads a fixed field count for those OTHER passes.
ZOMBIE_SNAPSHOT_PS_FIELDS='pid,ppid,stat,etimes,comm'

# Take the zombie-scoped process snapshot. Fails loudly (non-zero exit, explicit message) rather
# than silently degrading if `ps` itself fails, mirroring take_snapshot()/take_lean_snapshot()
# above. An EMPTY result is the normal, common case (no zombies at all), not an error.
take_zombie_snapshot() {
    local out
    if ! out=$(ps -eo "$ZOMBIE_SNAPSHOT_PS_FIELDS" --no-headers 2>&1); then
        echo "ERROR: 'ps -eo $ZOMBIE_SNAPSHOT_PS_FIELDS' failed:" >&2
        echo "$out" >&2
        exit 1
    fi
    printf '%s\n' "$out"
}

# --- Zombie-state predicate ---
# Returns 0 (true) only when a snapshot row's `stat` field identifies a defunct (zombie) process.
# Linux/procps renders a zombie's stat as exactly `Z` or `Z+` (the trailing `+` marks a
# foreground-process-group member) -- never any other combination -- so a substring match on `Z`
# is both sufficient and precise: no live state code (`S`, `R`, `D`, `T`, `I`, and their `s`/`l`/
# `<`/`N`/`+` suffixes) ever contains the letter `Z`. This is an independent detection axis from
# every existing predicate in this script -- it reads `stat`, a column none of the Claude-pass or
# Lean-pass predicates above ever consult.
zombie_row_is_defunct() {
    local stat="$1"
    case "$stat" in
        *Z*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Run the unreaped-child (zombie) reporting pass. Always runs after run_build_waiter_pass(), same
# unconditional-sequence convention main() already uses for the Claude/Lean/build-waiter passes.
# Accepts the same ($FORCE, $DRY_RUN) calling convention as the other passes purely for call-site
# symmetry -- $FORCE is intentionally never branched on inside this function, since there is no
# force-mode action for this pass to take (see the header comment above for why a zombie cannot
# be reaped by an external signal at all). $DRY_RUN only gates the `[DRY RUN]` banner line, so
# --dry-run and --force/no-flag output is identical apart from that one banner, exactly like the
# other passes' documented --dry-run/--force equivalence.
run_zombie_pass() {
    local FORCE="$1"
    local DRY_RUN="$2"

    local snapshot
    snapshot=$(take_zombie_snapshot)

    local -a all_pid=() all_comm=()
    local -a zpid=() zppid=() zetimes=() zcomm=()

    while IFS= read -r line; do
        [ -z "$line" ] && continue || true

        local pid ppid stat etimes comm
        read -r pid ppid stat etimes comm <<< "$line"

        all_pid+=("$pid")
        all_comm+=("$comm")

        if zombie_row_is_defunct "$stat"; then
            zpid+=("$pid")
            zppid+=("$ppid")
            zetimes+=("$etimes")
            zcomm+=("$comm")
        fi
    done <<< "$snapshot"

    local n_zombies="${#zpid[@]}"

    echo ""
    echo -e "${GREEN}Unreaped Child Process Report${NC}"
    echo "=============================="

    if [ "$n_zombies" -eq 0 ]; then
        echo ""
        echo "No unreaped child processes found."
        return 0
    fi

    if $DRY_RUN; then
        echo ""
        echo -e "${BLUE}[DRY RUN]${NC} Preview only -- this pass never terminates anything (a zombie"
        echo "can only be reaped by its own parent's wait() call, never by an external signal)."
    fi

    # Group by ppid, first-seen order. No associative arrays, matching this script's existing
    # style (parallel indexed arrays throughout).
    local -a parent_pids=()
    local i k already_seen ppid_i
    for ((i = 0; i < n_zombies; i++)); do
        ppid_i="${zppid[$i]}"
        already_seen=false
        for k in "${!parent_pids[@]}"; do
            if [ "${parent_pids[$k]}" = "$ppid_i" ]; then
                already_seen=true
                break
            fi
        done
        $already_seen || parent_pids+=("$ppid_i")
    done

    echo ""
    echo "Found $n_zombies unreaped child process(es) across ${#parent_pids[@]} parent(s)."
    echo "Zombie memory cost: 0 (a zombie retains only a PID slot and exit-status record -- no reclaimable pages)."

    local ppid parent_comm j
    for ppid in "${parent_pids[@]}"; do
        parent_comm="unknown (parent not present in this snapshot)"
        for ((j = 0; j < ${#all_pid[@]}; j++)); do
            if [ "${all_pid[$j]}" = "$ppid" ]; then
                parent_comm="${all_comm[$j]}"
                break
            fi
        done

        local -a child_pids=() child_comms=() child_ages=()
        local oldest_etimes=-1
        for ((i = 0; i < n_zombies; i++)); do
            [ "${zppid[$i]}" = "$ppid" ] || continue
            child_pids+=("${zpid[$i]}")
            child_comms+=("${zcomm[$i]}")
            child_ages+=("$(get_process_age "${zetimes[$i]}")")
            if [ "${zetimes[$i]}" -gt "$oldest_etimes" ]; then
                oldest_etimes="${zetimes[$i]}"
            fi
        done

        echo ""
        echo "Parent: $parent_comm (PID $ppid) -- ${#child_pids[@]} zombie child(ren), oldest age $(get_process_age "$oldest_etimes"):"
        printf "  %-8s %-24s %s\n" "PID" "Comm" "Age"
        printf "  %-8s %-24s %s\n" "-----" "------------------------" "-------"
        for ((i = 0; i < ${#child_pids[@]}; i++)); do
            printf "  %-8s %-24s %s\n" "${child_pids[$i]}" "${child_comms[$i]}" "${child_ages[$i]}"
        done
    done

    echo ""
}

# --- MCP server fan-out reporting pass: independently-gated, report-only ---
#
# A fifth, independently-gated pass. User-scope MCP servers declared in `~/.claude.json`'s
# top-level `mcpServers` object fan out into EVERY session unconditionally -- this is real,
# unavoidable per-session process/memory cost, not a bug, and this pass reports it live rather
# than guessing at it. It never terminates or reconfigures anything; there is no `$FORCE` branch
# here, mirroring run_zombie_pass() above.
#
# Attribution model (deliberately simple, not a generic cross-server heuristic): a process row is
# attributed to a server when its `args` contains that server's own registered key (read live
# from `~/.claude.json`, never hard-coded) as a case-insensitive substring -- e.g. server key
# "lean-lsp" matches an argv mentioning "lean-lsp-mcp"; server key "playwright" matches an argv
# mentioning "playwright-mcp" or "@playwright/mcp". This mirrors what live inspection actually
# shows for both currently registered servers.
#
# Session-count model: a server's matched rows are grouped into connected components by `ppid`
# chains -- a matched row whose `ppid` is ALSO a matched row belongs to the SAME session instance
# as that parent (e.g. playwright's node child inherits its exec parent's session); a matched row
# whose `ppid` is NOT itself matched (its parent is the invoking Claude session process) is its
# OWN session root. The number of distinct roots is the live session count -- computed fresh
# every invocation, never hard-coded.
MCP_SNAPSHOT_PS_FIELDS='pid,ppid,rss,args'

# Overridable seam for ~/.claude.json's path, mirroring the PROC_ROOT seam above -- lets a test
# point this at a synthetic fixture file without instrumenting the production function.
CLAUDE_JSON_PATH="${CLAUDE_JSON_PATH:-$HOME/.claude.json}"

# --- Per-server evidence-of-use discriminators (server-shaped, not a generic heuristic) ---
#
# playwright: the zero-evidence signal is the total ABSENCE of any chromium/headless_shell
# process anywhere on the system -- a live browser process is unambiguous, direct evidence the
# server is actually driving a page. Returns 0 (true, i.e. "evidence of use found") when at least
# one such process exists.
mcp_playwright_evidence_of_use() {
    ps -eo comm --no-headers 2>/dev/null | grep -qiE 'chromium|headless_shell'
}

# lean-lsp: evidence of use is the presence of its own `lake serve` tree, reusing
# take_lean_snapshot()/is_lean_serve_comm() exactly as the separately-gated Lean pass above
# defines them -- not a new detector. An ACTIVE or merely-idle-but-present tree both count as "in
# use" here; idleness is a decision for the Lean reclamation pass, not this advisory.
mcp_lean_lsp_evidence_of_use() {
    local snapshot line
    snapshot=$(take_lean_snapshot)
    while IFS= read -r line; do
        [ -z "$line" ] && continue || true
        local pid ppid uid etimes rss pcpu cgroup comm args
        read -r pid ppid uid etimes rss pcpu cgroup comm args <<< "$line"
        if is_lean_serve_comm "$comm" "$args"; then
            return 0
        fi
    done <<< "$snapshot"
    return 1
}

# Dispatch table: returns 0 ("in use", never flag) / 1 ("no evidence found", flag) / 2 ("no
# detector available for this server -- report as 'no use signal available', NEVER as unused").
# A server with no detector must never be silently treated as "unused" -- see the plan's Risks
# table (an over-generic heuristic false-flagging a legitimately idle server).
mcp_server_evidence_of_use() {
    local server_key="$1"
    case "$server_key" in
        playwright)
            if mcp_playwright_evidence_of_use; then return 0; else return 1; fi
            ;;
        lean-lsp)
            if mcp_lean_lsp_evidence_of_use; then return 0; else return 1; fi
            ;;
        *)
            return 2
            ;;
    esac
}

# Run the MCP server fan-out reporting pass. Always runs last, after run_zombie_pass(), same
# unconditional-sequence convention main() already uses. Accepts the same ($FORCE, $DRY_RUN)
# calling convention as the other passes purely for call-site symmetry -- $FORCE is intentionally
# never branched on inside this function, since there is no force-mode action to take (report-only,
# same rationale as run_zombie_pass()). $DRY_RUN only gates the `[DRY RUN]` banner line.
run_mcp_fanout_pass() {
    local FORCE="$1"
    local DRY_RUN="$2"

    echo ""
    echo -e "${GREEN}MCP Server Fan-Out Report${NC}"
    echo "=========================="

    # Fail loudly, not silently: an absent `jq` must never make this pass vanish without
    # explanation, matching take_snapshot()'s fail-loudly convention for a failed `ps`.
    if ! command -v jq >/dev/null 2>&1; then
        echo ""
        echo "ERROR: 'jq' is required for the MCP fan-out pass but was not found on PATH -- skipping this pass."
        return 0
    fi

    if [ ! -f "$CLAUDE_JSON_PATH" ]; then
        echo ""
        echo "No $CLAUDE_JSON_PATH found -- no user-scope MCP servers to report."
        return 0
    fi

    local server_keys
    server_keys=$(jq -r '.mcpServers // {} | keys[]' "$CLAUDE_JSON_PATH" 2>/dev/null)

    if [ -z "$server_keys" ]; then
        echo ""
        echo "No user-scope MCP servers registered in $CLAUDE_JSON_PATH."
        return 0
    fi

    if $DRY_RUN; then
        echo ""
        echo -e "${BLUE}[DRY RUN]${NC} Preview only -- this pass never changes any configuration."
    fi

    local snapshot
    if ! snapshot=$(ps -eo "$MCP_SNAPSHOT_PS_FIELDS" --no-headers 2>&1); then
        echo "ERROR: 'ps -eo $MCP_SNAPSHOT_PS_FIELDS' failed:" >&2
        echo "$snapshot" >&2
        exit 1
    fi

    local -a all_pid=() all_ppid=() all_rss=() all_args=()
    while IFS= read -r line; do
        [ -z "$line" ] && continue || true
        local pid ppid rss args
        read -r pid ppid rss args <<< "$line"
        all_pid+=("$pid"); all_ppid+=("$ppid"); all_rss+=("$rss"); all_args+=("$args")
    done <<< "$snapshot"

    local n_total="${#all_pid[@]}"
    local total_servers_mem=0
    local -a flagged_servers=()

    echo ""
    printf "%-16s %-10s %-10s %-12s %s\n" "Server" "Sessions" "Procs" "Memory" "Evidence"
    printf "%-16s %-10s %-10s %-12s %s\n" "----------------" "----------" "----------" "------------" "--------"

    local server_key
    while IFS= read -r server_key; do
        [ -z "$server_key" ] && continue || true

        local -a match_idx=()
        local i
        for ((i = 0; i < n_total; i++)); do
            local lc_args="${all_args[$i],,}"
            local lc_key="${server_key,,}"
            case "$lc_args" in
                *"$lc_key"*)
                    match_idx+=("$i")
                    ;;
            esac
        done

        local n_procs="${#match_idx[@]}"
        local server_mem=0
        local -a roots=()

        local idx pid swap_kb
        for idx in "${match_idx[@]}"; do
            pid="${all_pid[$idx]}"
            swap_kb=$(get_vmswap_kb "$pid")
            server_mem=$((server_mem + all_rss[idx] + swap_kb))

            # Walk the ppid chain upward while the parent is ALSO a matched row, to find this
            # row's session root (see header comment's session-count model).
            local cur_idx="$idx" cur_ppid root_pid found_parent j
            root_pid="${all_pid[$idx]}"
            while true; do
                cur_ppid="${all_ppid[$cur_idx]}"
                found_parent=""
                for j in "${match_idx[@]}"; do
                    if [ "${all_pid[$j]}" = "$cur_ppid" ]; then
                        found_parent="$j"
                        break
                    fi
                done
                if [ -n "$found_parent" ]; then
                    cur_idx="$found_parent"
                    root_pid="${all_pid[$cur_idx]}"
                else
                    break
                fi
            done
            roots+=("$root_pid")
        done

        # Deduplicate roots to get the live session count.
        local -a uniq_roots=()
        local r already ur
        for r in "${roots[@]}"; do
            already=false
            for ur in "${uniq_roots[@]}"; do
                [ "$ur" = "$r" ] && { already=true; break; }
            done
            $already || uniq_roots+=("$r")
        done
        local n_sessions="${#uniq_roots[@]}"

        # Invoked via `||` rather than as a bare statement: under this script's `set -e`, a bare
        # call whose return is 1 (or 2) would abort the whole script right here -- the same
        # set -e hazard the escalation helper defined earlier in this script guards against by
        # documenting that its own callers must use an if/||/&& context, never a bare invocation.
        local evidence_rc=0
        mcp_server_evidence_of_use "$server_key" || evidence_rc=$?

        # Evidence-column text: three distinct outcomes, per the plan's explicit requirement that
        # "no available signal" is reported as its own outcome, never conflated with "unused".
        local evidence_label
        case "$evidence_rc" in
            0) evidence_label="in use" ;;
            1) evidence_label="no evidence of use" ;;
            *) evidence_label="no use signal available" ;;
        esac

        printf "%-16s %-10s %-10s %-12s %s\n" "$server_key" "$n_sessions" "$n_procs" "$(format_memory "$server_mem")" "$evidence_label"
        total_servers_mem=$((total_servers_mem + server_mem))

        if [ "$evidence_rc" -eq 1 ]; then
            flagged_servers+=("$server_key")
        fi
    done <<< "$server_keys"

    echo ""
    echo "Total MCP server memory: $(format_memory "$total_servers_mem")"

    if [ "${#flagged_servers[@]}" -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}Scoping advisory${NC}"
        echo "-----------------"
        local flagged
        for flagged in "${flagged_servers[@]}"; do
            echo ""
            echo "'$flagged' shows no live evidence of use on this system right now. If this"
            echo "server is genuinely repo-local, consider registering it in project scope"
            echo "(.mcp.json) instead of user scope (~/.claude.json) -- project scope fans out"
            echo "only into projects that actually use it, not into every session unconditionally."
            echo ""
            echo "The real cost of project scope is workspace trust, not a subagent access"
            echo "barrier: a fresh clone (or any not-yet-trusted workspace) requires a one-time"
            echo "interactive approval before a project-scoped server is used, and a cloned"
            echo "repository cannot pre-authorize its own servers from inside the repo. That is a"
            echo "one-time setup cost, not a per-call or per-session obstacle -- once a workspace"
            echo "is trusted, project-scoped servers are fully reachable by dispatched subagents."
        done
        echo ""
        echo "See context/patterns/mcp-server-ownership.md for the full registration/permission"
        echo "model; that document also classifies some user-scope registrations as correct by"
        echo "design (a genuine machine capability, or a server needing per-project computed"
        echo "arguments), so this advisory is a prompt to reconsider, not a directive."
    fi

    echo ""
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

    # All five passes always run, in this order, regardless of what any of them find -- this is
    # the structural fix that makes the Lean pass (and every pass added since) reachable at all.
    # Restructured from the original main() (which had two early `exit 0` sites inside what is now
    # run_claude_pass()) into returning functions called unconditionally in sequence. The build-
    # waiter pass runs immediately after run_lean_pass(), keeping the two destructive passes
    # adjacent; it is the first pass here whose destructive action is not gated by $FORCE (see its
    # own header comment).
    run_claude_pass "$FORCE" "$DRY_RUN"
    run_lean_pass "$FORCE" "$DRY_RUN"
    run_build_waiter_pass "$FORCE" "$DRY_RUN"
    run_zombie_pass "$FORCE" "$DRY_RUN"
    run_mcp_fanout_pass "$FORCE" "$DRY_RUN"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
