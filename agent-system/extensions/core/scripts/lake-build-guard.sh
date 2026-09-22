#!/usr/bin/env bash
#
# lake-build-guard.sh - Serialize concurrent `lake build` invocations against one Lean package,
# let a waiting session consume an already-completed build's result instead of launching a
# redundant one, and optionally bound the build in a systemd user scope so a runaway elaboration
# cannot drive the machine into swap.
#
# WHAT THIS GUARDS: N agent sessions (or shells) invoking `lake build` concurrently against the
# SAME Lean package. Without serialization each session launches its own full Lake build,
# multiplying elaboration cost and, in the worst case, driving the machine into swap when several
# heavyweight `lean` processes run at once.
#
# WHAT THIS DELIBERATELY DOES NOT DO (non-goals, recorded so a future reader does not treat them
# as omissions):
#   - It does not wire itself into any call site. lean-sorry-census.sh, skill-lake-repair, or any
#     other consumer must opt in explicitly by invoking `lake-build-guard.sh build ...` -- that
#     wiring is separate, dependent work.
#   - It does not touch LEAN_NUM_THREADS (see "Recorded dead ends" below).
#   - It does not coordinate across machines, run as a daemon, or persist any state beyond the
#     lock/result/log/capture files under the resolved project's own .lake/ directory.
#
# FAMILY CONVENTIONS (for a future latex-build-guard.sh or similar sibling): this script sets,
# but does not itself instantiate, a shared shape for a family of build guards --
#   - subcommand shape: `status` (detect only) / `preflight` (resource check only) / `build`
#     (the guarded wrapper) -- three separable modes so a caller can adopt detection before
#     committing to the wrapper.
#   - exit-code shape (REVISED): the guard validates the wrapped command's own argument vector
#     BEFORE dispatch and refuses an unrecognized or empty one in the reserved usage band (77
#     here -- see the LAKE_SUBCOMMAND ALLOWLIST section below). The "passes the wrapped command's
#     exit code through untouched" guarantee therefore applies only to a command vector the guard
#     actually recognized: passthrough WITHOUT prior validation is exactly what produces a false
#     pass -- dispatching an unrecognized vector to the wrapped tool and reporting whatever it
#     happens to exit, even when no corresponding work ran.
#   - silent-when-no-conflict (QUALIFIED): silence is correct for the clean/no-conflict path in
#     every mode. A REPLAYED result is NOT a no-conflict path: it MUST announce itself with a
#     stable, documented stderr marker prefix (see REPLAY below), because a caller otherwise
#     cannot distinguish a replay from a fresh run without passing --no-share.
#   - degrade audibly, never silently: a missing optional dependency (flock, systemd-run, PSI)
#     produces a visible stderr notice and a fallback behavior, never a crash and never silence.
#     The REPLAY marker follows this same fixed `lake-build-guard:`-prefixed stderr house style.
#   - result sharing keys on scope, not staleness alone (NEW): a guard that shares a completed
#     result MUST key that decision on a normalized form of the wrapped command's own argument
#     vector, in addition to input staleness. Inputs unchanged does not imply the requested work
#     is the same requested work -- see scope_key below.
#
# RECORDED DEAD ENDS (do not re-attempt these as a "quick fix" for build concurrency):
#   - Lake 5.0.0 exposes no `-j`/`--jobs` flag (confirmed against a live `lake build --help`).
#   - `lean`'s own `-j, --threads` flag is not forwarded by Lake; Lake exposes no lean-level
#     thread override at all.
#   - LEAN_NUM_THREADS was experimentally FALSIFIED as a build-concurrency lever, not merely
#     unverified: a controlled A/B against a real Lean project held the module graph constant
#     and varied only this variable; the maximum concurrent descendant `lean` process count was
#     1 in BOTH arms. The variable sizes a single `lean` process's OWN internal elaboration
#     thread pool, not Lake's job scheduler. This script MUST NOT read, set, export, or document
#     LEAN_NUM_THREADS as a concurrency lever -- every other appearance of the string in this
#     file is documentation of that fact, never an assignment.
#
# LAKE SUBCOMMAND ALLOWLIST (build mode; see LAKE_SUBCOMMANDS below):
#   build mode validates lake_args[0] against a hardcoded allowlist before dispatch, rather than
#   probing `lake --help` dynamically. A dynamic probe would acquire lake's help-format stability
#   as a new dependency and, worse, would validate nothing at all against the fake `lake` this
#   script's own test harness substitutes on PATH (which ignores its arguments and always echoes
#   fixed markers) -- every build-mode case would then fail validation.
#   PROVENANCE: enumerated from a live `lake --help`, Lake 5.0.0-src+2fcce72 / Lean 4.27.0-rc1.
#   RE-VERIFY AND UPDATE THIS LIST after any Lake upgrade that adds or renames subcommands.
#   ESCAPE HATCH: LAKE_BUILD_GUARD_EXTRA_SUBCOMMANDS (space-separated, see TEST SEAMS below) lets
#   a caller accept a newly-added Lake subcommand immediately, without waiting on a source-store
#   update to this allowlist. A flag-shaped first token (e.g. `--version`) is never a subcommand
#   and is always rejected, allowlist or no: `lake --version` runs no build, yet completing it
#   would finalize a shareable `state=complete` record for work that never happened.
#
# USAGE:
#   lake-build-guard.sh status    [--dir DIR] [--verbose]
#   lake-build-guard.sh preflight [--dir DIR] [--memory-high VAL] [--memory-max VAL] [--verbose]
#   lake-build-guard.sh build     [--dir DIR] [--timeout SECS] [--memory-bound]
#                                 [--memory-high VAL] [--memory-max VAL] [--defer-on-pressure]
#                                 [--no-share] [--verbose] [--] [LAKE ARGS...]
#   lake-build-guard.sh --help
#
# WAITING ON AN IN-FLIGHT GUARDED BUILD: read `holder_pid` from the result record (or from
#   `status --verbose`, see cmd_status() below), then poll that PID directly:
#     while kill -0 "$holder_pid" 2>/dev/null; do sleep 1; done
#   Do NOT use `pgrep -f "lake-build-guard.sh build"` (or any `pgrep -f` variant naming this
#   script) to wait -- a polling shell whose own argv happens to contain that same string
#   self-matches its own `pgrep -f` and the loop never terminates. This is the same self-match
#   pitfall cmd_status() itself avoids by never scanning the process table (see the comment
#   immediately above cmd_status() below); `kill -0` on the recorded holder PID is the only
#   idiom that does not carry it.
#
# TERMINAL RECORD GUARANTEE: run_as_holder() installs an EXIT/INT/TERM trap immediately after
# writing the in-flight record, so every TRAPPABLE exit path out of it -- a normal return, an
# internal `set -e` abort, SIGINT, or SIGTERM -- finalizes the record to a TERMINAL state before
# the process disappears: state=complete on the normal path, state=aborted (with an
# abort_reason=INT|TERM|EXIT field and a forced non-zero exit_status) on any of the others. A
# waiter or `result` caller therefore never observes an in_flight record whose holder_pid is dead
# from a trappable cause. PROCESS-GROUP DELIVERY NUANCE: bash defers running a trap until the
# current foreground child returns, so a caller that wants prompt finalization on kill must send
# the signal to the guard's own PROCESS GROUP, not merely to holder_pid alone -- the guard process
# is its own process group leader once launched under `setsid` (holder_pid then also names that
# pgid), and killing only the shell while its `lake` child is still running leaves bash blocked in
# wait() until that child dies on its own. SIGKILL LIMITATION: SIGKILL cannot be trapped, so a
# holder killed with -9 still leaves an untouched in_flight record; this is an accepted gap, not
# an oversight -- see `result`'s orphan detection (state=orphaned, reported when a record is
# in_flight but the lock file itself is free) for how a caller distinguishes that case without
# scanning the process table. `holder_pid` remains the documented liveness handle either way:
# `kill -0 "$holder_pid"`.
#
# EXIT CODES:
#   build mode:     0 and any code the underlying `lake` returns are passed through untouched, for
#                   a recognized lake subcommand (see LAKE SUBCOMMAND ALLOWLIST above). Guard-
#                   specific failures use the reserved band 75-79:
#                     75  lock-wait timeout (no build launched, no result shared)
#                     76  deferred on memory pressure with --defer-on-pressure (build not launched)
#                     77  usage error (bad flags/subcommand, INCLUDING an unrecognized or missing
#                         lake subcommand in build mode -- no build is attempted in that case)
#                     78  no Lean project found (no lakefile.lean/lakefile.toml above --dir)
#                     79  a required capability was missing (e.g. no `lake` on PATH)
#                   NOTE (reserved-band collision, documented honestly): `lake` itself could in
#                   principle also exit in the 75-79 range. A caller that needs to distinguish
#                   "the guard refused" from "lake itself returned 75-79" should call
#                   `status`/`preflight` separately rather than relying on the numeric code alone.
#   status mode:    0   no in-flight guarded build (no output)
#                   10  an in-flight guarded build was detected (one-line report on stdout)
#   preflight mode: 0   no memory pressure detected (no output)
#                   11  memory pressure detected (report on stderr)
#
# STALENESS POLICY (result sharing -- see compute_fingerprint()/compute_scope_key()/
# decide_sharing() below for the implementation; this is the authoritative statement of the
# policy itself). REVISED: the policy now governs both source-tree change AND build scope -- the
# prior text below governed source change alone and never claimed to cover scope; scope_key
# (condition 5) closes that gap.
#   A session that acquires the build lock -- whether immediately (no contention) or after
#   waiting on a concurrent holder -- may REPLAY a prior build's result (stdout, stderr, exit
#   status) instead of running its own, but only when ALL of the following hold -- failing ANY
#   one falls through to running a real build, which is always safe:
#     1. state == complete.  An `in_flight` OR `aborted` record means its holder never reached a
#        normal, successful finish -- `in_flight` means it died before any trap could run (e.g.
#        SIGKILL, see the TERMINAL RECORD GUARANTEE above), `aborted` means a trap caught a
#        terminating signal or shell exit and finalized the record itself. Either way this is an
#        ABANDONED LOCK. `flock` releases automatically on process exit, so the lock itself
#        becomes acquirable with no PID bookkeeping required; the tell is the record's own
#        non-`complete` state, and such a record is NEVER shared.
#     2. The record's POST-build fingerprint equals the WAITER's CURRENT fingerprint -- i.e. the
#        tree has not moved since that build finished. This is the "result predates the waiter's
#        own edits" guard.
#     3. The record's scope_key equals the WAITER's OWN scope key -- a hash of the invocation's
#        lake argument vector (see compute_scope_key() below). A scoped build (e.g. `build
#        Foo.Bar`) and a full build (`build`) over an identical, unchanged tree are DIFFERENT
#        requested work and must never share a result; a missing or empty recorded scope_key
#        (e.g. a hand-written or pre-scope-key record) is treated as NOT shareable (fail closed).
#     4. The record is younger than a configurable max age (default 900s / 15 minutes).
#     5. --no-share was not passed.
#   A replayed result announces itself: cmd_build() emits one `lake-build-guard: REPLAY:` line on
#   stderr, naming the holder pid, the result's age, and the recorded exit status, immediately
#   before replaying -- see the FAMILY CONVENTIONS silent-when-no-conflict qualification above.
#   Fingerprint asymmetry is deliberate and conservative in only one direction: the check must
#   NEVER report "unchanged" when content actually changed (a real content write always moves
#   mtime, so default `stat` mode never misses a real change except the narrow edge noted below);
#   it MAY spuriously report "changed" after a bare `touch` (which Lake's own staleness tracking
#   ignores, since Lake hashes content, not mtime) -- that costs only a fallback to a real
#   `lake build`, which Lake then no-ops on its own. `stat` mode reads mtime at nanosecond
#   resolution (`stat -c '%y'`, not the whole-second `%Y`) specifically so a same-second edit
#   (a realistic case for a fast agent edit-then-build loop, not merely a rare "restore") is
#   still distinguished, as long as the filesystem records sub-second mtimes (ext4/xfs/btrfs/
#   tmpfs all do; a filesystem that truncates to whole seconds narrows this back to the coarser
#   edge). The residual edge in default `stat` mode is a restore (or edit) that reproduces an
#   identical size AND identical nanosecond-resolution mtime; a caller that cannot accept that
#   edge should set LAKE_BUILD_GUARD_FINGERPRINT=hash to hash file contents instead of metadata.
#
# TEST SEAMS (overridable via environment, `:-`-defaulted, following claude-refresh.sh's
# `_pid_is_alive` precedent -- production behavior is unchanged unless a variable is exported):
#   LAKE_BUILD_GUARD_LAKE_BIN     - the `lake` binary to invoke. Default: resolved via PATH.
#                                   MUST be resolved via PATH (never a hardcoded absolute path)
#                                   so a test suite can substitute a fake `lake`.
#   LAKE_BUILD_GUARD_PSI_PATH     - path to the PSI memory-pressure file.
#                                   Default: /proc/pressure/memory
#   LAKE_BUILD_GUARD_MEMINFO_PATH - path to the meminfo file. Default: /proc/meminfo
#   LAKE_BUILD_GUARD_FINGERPRINT  - fingerprint mode, "stat" (default) or "hash".
#   LAKE_BUILD_GUARD_MEMORY_BOUND - "1" is equivalent to passing --memory-bound.
#   LAKE_BUILD_GUARD_EXTRA_SUBCOMMANDS - space-separated list of additional lake subcommands to
#                                   accept in build mode, beyond the LAKE_SUBCOMMANDS allowlist
#                                   (see LAKE SUBCOMMAND ALLOWLIST above). Default: empty. Unlike
#                                   the other seams above, this one is also a production escape
#                                   hatch, not test-only: it unblocks a caller hitting a
#                                   newly-added Lake subcommand without a source-store update.
#
set -euo pipefail

# --- Test seams (see header) ---
LAKE_BUILD_GUARD_LAKE_BIN="${LAKE_BUILD_GUARD_LAKE_BIN:-}"
LAKE_BUILD_GUARD_PSI_PATH="${LAKE_BUILD_GUARD_PSI_PATH:-/proc/pressure/memory}"
LAKE_BUILD_GUARD_MEMINFO_PATH="${LAKE_BUILD_GUARD_MEMINFO_PATH:-/proc/meminfo}"
LAKE_BUILD_GUARD_FINGERPRINT="${LAKE_BUILD_GUARD_FINGERPRINT:-stat}"
LAKE_BUILD_GUARD_MEMORY_BOUND="${LAKE_BUILD_GUARD_MEMORY_BOUND:-0}"
LAKE_BUILD_GUARD_EXTRA_SUBCOMMANDS="${LAKE_BUILD_GUARD_EXTRA_SUBCOMMANDS:-}"

# --- Internal defaults (never hardcoded byte/GB constants -- ratios and percentages only) ---
DEFAULT_LOCK_TIMEOUT=600      # seconds a waiter blocks before giving up (exit 75)
DEFAULT_SHARE_MAX_AGE=900     # seconds a completed result stays eligible for sharing
DEFAULT_MEMORY_HIGH="60%"     # systemd MemoryHigh=, a fraction of MemTotal, never a byte literal
DEFAULT_MEMORY_MAX="80%"      # systemd MemoryMax=, a fraction of MemTotal, never a byte literal
PSI_SOME_AVG10_THRESHOLD="10.0"
PSI_FULL_AVG10_THRESHOLD="5.0"
MEM_AVAILABLE_RATIO_THRESHOLD=10   # percent of MemTotal; below this is "pressure"
SWAP_USED_RATIO_THRESHOLD=50       # percent of SwapTotal in use; above this is "pressure"

# LAKE_SUBCOMMANDS: hardcoded allowlist for build-mode subcommand validation (see LAKE SUBCOMMAND
# ALLOWLIST in the header above for the full rationale, provenance, and the
# LAKE_BUILD_GUARD_EXTRA_SUBCOMMANDS escape hatch). Enumerated from a live `lake --help` against
# Lake 5.0.0-src+2fcce72 / Lean 4.27.0-rc1. RE-VERIFY AND UPDATE after a Lake upgrade.
LAKE_SUBCOMMANDS="new init build query exe check-build test check-test lint check-lint clean env lean update pack unpack upload cache script scripts run translate-config serve"

print_help() {
  cat <<'EOF'
lake-build-guard.sh - serialize concurrent `lake build` invocations, share results with waiters,
and optionally bound builds in a systemd user memory scope.

Usage:
  lake-build-guard.sh status    [--dir DIR] [--verbose]
  lake-build-guard.sh preflight [--dir DIR] [--memory-high VAL] [--memory-max VAL] [--verbose]
  lake-build-guard.sh build     [--dir DIR] [--timeout SECS] [--memory-bound]
                                [--memory-high VAL] [--memory-max VAL] [--defer-on-pressure]
                                [--no-share] [--verbose] [--] [LAKE ARGS...]
  lake-build-guard.sh --help

Global options:
  --dir DIR, -d DIR      Directory to resolve the Lean project from (default: $PWD).
  --timeout SECS         (build only) Seconds to wait for the lock before giving up. Default 600.
  --memory-bound         (build only) Wrap the build in `systemd-run --user --scope` with a
                          memory ceiling. Equivalent to LAKE_BUILD_GUARD_MEMORY_BOUND=1.
  --memory-high VAL      MemoryHigh= value passed to systemd-run (default 60%).
  --memory-max VAL       MemoryMax= value passed to systemd-run (default 80%).
  --defer-on-pressure    (build only) Exit 76 without launching if memory pressure is detected,
                          instead of the default warn-and-proceed behavior.
  --no-share             (build only) Never replay a prior result; always run a real build.
  --verbose              Emit diagnostic detail on stderr.
  --help, -h             Show this message.

Build-mode subcommand validation:
  build mode requires a recognized lake subcommand as LAKE ARGS[0] (e.g. `build`, `test`,
  `check-build`, ...); an unrecognized, flag-shaped, or missing subcommand exits 77 before any
  build is attempted. Set LAKE_BUILD_GUARD_EXTRA_SUBCOMMANDS (space-separated) to accept
  additional subcommands without a source-store update to the built-in allowlist.

Result sharing and the REPLAY marker:
  A completed result is replayed only for an equivalently-scoped build (an identical lake
  argument vector) over an unchanged tree. A replayed run announces itself on stderr with the
  stable, documented prefix `lake-build-guard: REPLAY:`, naming the holder pid, the result's age,
  and its recorded exit status. To assert that a genuine build ran rather than a replay: grep
  stderr for the absence of that marker, or pass --no-share to force a real build.

Waiting on an in-flight guarded build:
  Read `holder_pid` from the result record (or from `status --verbose`), then poll it directly:
    while kill -0 "$holder_pid" 2>/dev/null; do sleep 1; done
  Do NOT use `pgrep -f "lake-build-guard.sh build"` to wait -- a polling shell whose own argv
  contains that same string self-matches its own `pgrep -f` and the loop never terminates.

Exit codes:
  build mode:     0 / lake's own code (for a recognized subcommand) on success; 75 lock-wait
                   timeout; 76 deferred on pressure; 77 usage error (including an unrecognized,
                   flag-shaped, or missing lake subcommand); 78 no Lean project found; 79 required
                   capability missing.
  status mode:    0 no in-flight build (no output); 10 in-flight build detected (report on stdout).
  preflight mode: 0 no pressure (no output); 11 pressure detected (report on stderr).

See the header comment in this file for the full staleness policy, dead-end record, and test-seam
documentation.
EOF
}

# --- Project-root / path resolution -----------------------------------------------------------

# Walk up from $1 (a directory) looking for the NEAREST lakefile.lean or lakefile.toml. MUST NOT
# use `git rev-parse --show-toplevel` -- a Lean package is frequently a subdirectory of a larger
# repo (confirmed multi-package-per-repo layouts exist), and a git-root lock would
# over-serialize unrelated sibling packages.
resolve_project_root() {
  local dir="$1"
  dir="$(cd "$dir" 2>/dev/null && pwd)" || return 1
  while :; do
    if [ -f "$dir/lakefile.lean" ] || [ -f "$dir/lakefile.toml" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    if [ "$dir" = "/" ]; then
      return 1
    fi
    dir="$(dirname "$dir")"
  done
}

# Resolve the `lake` binary via PATH only (never an absolute hardcoded path), so a test suite can
# substitute a fake `lake` on PATH ahead of the real one.
resolve_lake_bin() {
  if [ -n "$LAKE_BUILD_GUARD_LAKE_BIN" ]; then
    printf '%s\n' "$LAKE_BUILD_GUARD_LAKE_BIN"
    return 0
  fi
  command -v lake 2>/dev/null
}

# Derive and create the guard's paths under <root>/.lake/. No absolute path outside <root> is
# ever hardcoded here.
init_guard_paths() {
  local root="$1"
  GUARD_LAKE_DIR="$root/.lake"
  LOCK_PATH="$GUARD_LAKE_DIR/build-guard.lock"
  RESULT_PATH="$GUARD_LAKE_DIR/build-guard.result"
  LOG_PATH="$GUARD_LAKE_DIR/build-guard.log"
  STDOUT_CAPTURE_PATH="$GUARD_LAKE_DIR/build-guard.stdout"
  STDERR_CAPTURE_PATH="$GUARD_LAKE_DIR/build-guard.stderr"
  mkdir -p "$GUARD_LAKE_DIR"
}

# --- flock availability (probed once at startup; degrade audibly, never silently) --------------

have_flock() {
  command -v flock >/dev/null 2>&1
}

# --- Fingerprinting -----------------------------------------------------------------------------

# List the files that participate in the tree fingerprint: every *.lean source under the
# project root (excluding .lake/), plus the package manifest files. .lake/ is excluded because
# it holds build OUTPUT, not source.
collect_fingerprint_files() {
  local root="$1"
  find "$root" -type f -name '*.lean' -not -path "$root/.lake/*" 2>/dev/null
  local f
  for f in lakefile.lean lakefile.toml lake-manifest.json lean-toolchain; do
    if [ -f "$root/$f" ]; then
      printf '%s\n' "$root/$f"
    fi
  done
}

# Compute a fingerprint of the project tree. Two modes:
#   stat (default): hashes a sorted `path size mtime` triple list -- cheap, and never misses a
#     real content change (a content write always moves mtime), though a restore that reproduces
#     an identical size AND mtime is a known, documented edge (see the staleness policy above).
#   hash (opt-in via LAKE_BUILD_GUARD_FINGERPRINT=hash): hashes file contents directly, closing
#     that edge at the cost of reading every file.
# Run in a subshell with pipefail disabled locally so a transient `find`/`stat` warning (e.g. a
# permission-denied subdirectory) cannot abort the whole script under the outer set -eo pipefail.
compute_fingerprint() {
  local root="$1"
  local mode="${LAKE_BUILD_GUARD_FINGERPRINT:-stat}"
  (
    set +o pipefail
    collect_fingerprint_files "$root" | sort | while IFS= read -r f; do
      [ -f "$f" ] || continue
      if [ "$mode" = "hash" ]; then
        sha256sum "$f" 2>/dev/null
      else
        stat -c '%n %s %y' "$f" 2>/dev/null
      fi
    done | sha256sum | awk '{print $1}'
  )
}

# Compute a scope key: a hash of the invocation's own lake argument vector (Defect B fix -- see
# "result sharing keys on scope, not staleness alone" in FAMILY CONVENTIONS above). Hashes a
# NUL-separated join, NEVER a space-joined string, so argument boundaries stay unambiguous (e.g.
# `build A B` and `build "A B"` must not collide). `printf '%s\0' "$@"` on a zero-length "$@"
# still produces well-defined input to sha256sum (the hash of the empty byte stream).
compute_scope_key() {
  (
    set +o pipefail
    printf '%s\0' "$@" | sha256sum | awk '{print $1}'
  )
}

# --- Result record I/O ---------------------------------------------------------------------------
# Flat key=value record, one key per line. Read via grep (never sourced), so record content is
# never executed as shell.

get_record_field() {
  local field="$1" file="$2"
  [ -f "$file" ] || return 1
  grep "^${field}=" "$file" 2>/dev/null | tail -n 1 | cut -d= -f2-
}

write_inflight_record() {
  local pre_fp="$1" scope_key="$2"
  {
    echo "state=in_flight"
    echo "holder_pid=$$"
    echo "start_epoch=$(date +%s)"
    echo "end_epoch="
    echo "pre_fingerprint=$pre_fp"
    echo "post_fingerprint="
    echo "scope_key=$scope_key"
    echo "lake_bin=$LAKE_BIN"
    echo "exit_status="
    echo "log_path=$LOG_PATH"
  } > "$RESULT_PATH"
}

# $3 (state, default "complete") and $4 (abort_reason) let the terminal-record trap (see
# _abort_record_trap() below) reuse this same writer for a non-normal terminal state instead of
# duplicating the record shape in a second function -- see the TERMINAL RECORD GUARANTEE header
# note. abort_reason is written only when state != complete, so an ordinary completed record's
# shape is byte-for-byte unchanged from before this field existed.
finalize_record() {
  local exit_status="$1" post_fp="$2" state="${3:-complete}" abort_reason="${4:-}"
  local start_epoch pre_fp scope_key
  start_epoch="$(get_record_field start_epoch "$RESULT_PATH" || true)"
  pre_fp="$(get_record_field pre_fingerprint "$RESULT_PATH" || true)"
  scope_key="$(get_record_field scope_key "$RESULT_PATH" || true)"
  {
    echo "state=$state"
    echo "holder_pid=$$"
    echo "start_epoch=$start_epoch"
    echo "end_epoch=$(date +%s)"
    echo "pre_fingerprint=$pre_fp"
    echo "post_fingerprint=$post_fp"
    echo "scope_key=$scope_key"
    echo "lake_bin=$LAKE_BIN"
    echo "exit_status=$exit_status"
    echo "log_path=$LOG_PATH"
    if [ "$state" != "complete" ]; then
      echo "abort_reason=$abort_reason"
    fi
  } > "$RESULT_PATH"
}

# --- Terminal-record trap (TERMINAL RECORD GUARANTEE, see header) -------------------------------
# _RECORD_FINALIZED is a GLOBAL (never `local`) so it is visible to _abort_record_trap() no matter
# which call frame is active when a trap fires -- a `local` here would be dynamically scoped to
# run_as_holder()'s own extent, which is fragile to rely on across a signal-delivery boundary.
_RECORD_FINALIZED=false

# Finalizes the in-flight record as state=aborted on any trappable exit path that reaches here
# before the normal, successful finalize_record() call in run_as_holder() has run. Idempotent via
# the _RECORD_FINALIZED flag: a normal completion sets it true (see run_as_holder()) so this
# handler is a no-op on the exit that follows. Signal codes:
#   INT  -> exit_status=130 (128+2), the conventional SIGINT code
#   TERM -> exit_status=143 (128+15), the conventional SIGTERM code
#   EXIT (bare, e.g. a `set -e` abort) -> the shell's own pending "$?", forced to 1 if it was 0 --
#     exit_status is NEVER left empty on a terminal record (see the plan's Decision 1).
# Uses `|| true` / `${var:-}` defaults throughout: this runs with `set -u` still active and must
# never itself fail or reference an unset variable mid-signal-handling.
_abort_record_trap() {
  local sig="$1" pending_rc="${2:-1}"

  if [ "${_RECORD_FINALIZED:-false}" = "true" ]; then
    return 0
  fi
  _RECORD_FINALIZED=true
  trap - EXIT INT TERM

  local exit_status
  case "$sig" in
    INT)  exit_status=130 ;;
    TERM) exit_status=143 ;;
    *)
      exit_status="${pending_rc:-1}"
      if [ -z "$exit_status" ] || { [ "$exit_status" -eq 0 ] 2>/dev/null; }; then
        exit_status=1
      fi
      ;;
  esac

  local post_fp
  post_fp="$(compute_fingerprint "${ROOT:-.}" 2>/dev/null || true)"
  finalize_record "$exit_status" "$post_fp" aborted "$sig" || true

  case "$sig" in
    INT)  exit 130 ;;
    TERM) exit 143 ;;
    *)    exit "$exit_status" ;;
  esac
}

# --- Sharing decision (waiter path) --------------------------------------------------------------
# Every one of the five conditions in the header's staleness policy must pass, or this falls
# through to a real build -- see the header comment for the full rationale.
decide_sharing() {
  local waiter_fp="$1" waiter_scope_key="$2"
  local max_age="${LAKE_BUILD_GUARD_SHARE_MAX_AGE:-$DEFAULT_SHARE_MAX_AGE}"

  [ -f "$RESULT_PATH" ] || return 1

  local state
  state="$(get_record_field state "$RESULT_PATH" || true)"
  [ "$state" = "complete" ] || return 1

  local post_fp
  post_fp="$(get_record_field post_fingerprint "$RESULT_PATH" || true)"
  [ -n "$post_fp" ] && [ "$post_fp" = "$waiter_fp" ] || return 1

  # Scope condition (Defect B): a missing or empty recorded scope_key is treated as NOT
  # shareable -- fail closed, per the header's staleness policy condition 3.
  local record_scope_key
  record_scope_key="$(get_record_field scope_key "$RESULT_PATH" || true)"
  [ -n "$record_scope_key" ] && [ "$record_scope_key" = "$waiter_scope_key" ] || return 1

  local end_epoch
  end_epoch="$(get_record_field end_epoch "$RESULT_PATH" || true)"
  [ -n "$end_epoch" ] || return 1

  local now age
  now="$(date +%s)"
  age=$(( now - end_epoch ))
  [ "$age" -ge 0 ] && [ "$age" -lt "$max_age" ] || return 1

  return 0
}

# Replay a shared result's captured stdout/stderr bytes verbatim -- no guard-emitted bytes are
# added on this path either.
replay_shared_result() {
  cat "$STDOUT_CAPTURE_PATH" 2>/dev/null || true
  cat "$STDERR_CAPTURE_PATH" 1>&2 2>/dev/null || true
}

# --- systemd-run / cgroup bounding (opt-in) -------------------------------------------------------

# Presence of the binary does not imply the user session has cgroup delegation, so probe with one
# cheap real invocation in addition to `command -v`.
have_systemd_run() {
  command -v systemd-run >/dev/null 2>&1 || return 1
  systemd-run --user --scope --quiet --collect -- true >/dev/null 2>&1
}

# --- Memory pressure (PSI + swap-in-use; never bare MemAvailable alone) --------------------------
# Bare availability is insufficient: a machine can report ample-looking MemAvailable while tens
# of gigabytes of swap are in use and the machine is thrash-bound rather than crash-bound -- that
# failure presents as "everything is slow", not as an OOM, which is why it goes undiagnosed by a
# MemAvailable-only check.
PRESSURE_REASONS=()

check_memory_pressure() {
  PRESSURE_REASONS=()

  if [ -r "$LAKE_BUILD_GUARD_PSI_PATH" ]; then
    local some_line full_line some_avg10 full_avg10
    some_line="$(grep '^some' "$LAKE_BUILD_GUARD_PSI_PATH" 2>/dev/null || true)"
    if [ -n "$some_line" ]; then
      some_avg10="$(printf '%s\n' "$some_line" | grep -oE 'avg10=[0-9.]+' | cut -d= -f2)"
      if [ -n "$some_avg10" ] && awk -v v="$some_avg10" -v t="$PSI_SOME_AVG10_THRESHOLD" 'BEGIN{exit !(v+0>t+0)}'; then
        PRESSURE_REASONS+=("PSI 'some' avg10=${some_avg10} exceeds threshold ${PSI_SOME_AVG10_THRESHOLD}")
      fi
    fi
    full_line="$(grep '^full' "$LAKE_BUILD_GUARD_PSI_PATH" 2>/dev/null || true)"
    if [ -n "$full_line" ]; then
      full_avg10="$(printf '%s\n' "$full_line" | grep -oE 'avg10=[0-9.]+' | cut -d= -f2)"
      if [ -n "$full_avg10" ] && awk -v v="$full_avg10" -v t="$PSI_FULL_AVG10_THRESHOLD" 'BEGIN{exit !(v+0>t+0)}'; then
        PRESSURE_REASONS+=("PSI 'full' avg10=${full_avg10} exceeds threshold ${PSI_FULL_AVG10_THRESHOLD}")
      fi
    fi
  else
    if [ "${VERBOSE:-false}" = "true" ]; then
      echo "lake-build-guard: --verbose: PSI path unavailable ($LAKE_BUILD_GUARD_PSI_PATH); falling back to the meminfo-only signal" >&2
    fi
  fi

  if [ -r "$LAKE_BUILD_GUARD_MEMINFO_PATH" ]; then
    local mem_total mem_avail swap_total swap_free
    mem_total="$(awk '/^MemTotal:/{print $2}' "$LAKE_BUILD_GUARD_MEMINFO_PATH" 2>/dev/null || true)"
    mem_avail="$(awk '/^MemAvailable:/{print $2}' "$LAKE_BUILD_GUARD_MEMINFO_PATH" 2>/dev/null || true)"
    swap_total="$(awk '/^SwapTotal:/{print $2}' "$LAKE_BUILD_GUARD_MEMINFO_PATH" 2>/dev/null || true)"
    swap_free="$(awk '/^SwapFree:/{print $2}' "$LAKE_BUILD_GUARD_MEMINFO_PATH" 2>/dev/null || true)"

    if [ -n "$mem_total" ] && [ -n "$mem_avail" ] && [ "$mem_total" -gt 0 ] 2>/dev/null; then
      local avail_ratio=$(( mem_avail * 100 / mem_total ))
      if [ "$avail_ratio" -lt "$MEM_AVAILABLE_RATIO_THRESHOLD" ]; then
        PRESSURE_REASONS+=("MemAvailable/MemTotal = ${avail_ratio}% is below threshold ${MEM_AVAILABLE_RATIO_THRESHOLD}%")
      fi
    fi
    if [ -n "$swap_total" ] && [ "$swap_total" -gt 0 ] 2>/dev/null && [ -n "$swap_free" ]; then
      local swap_used_ratio=$(( (swap_total - swap_free) * 100 / swap_total ))
      if [ "$swap_used_ratio" -gt "$SWAP_USED_RATIO_THRESHOLD" ]; then
        PRESSURE_REASONS+=("swap-in-use = ${swap_used_ratio}% of SwapTotal exceeds threshold ${SWAP_USED_RATIO_THRESHOLD}%")
      fi
    fi
  fi

  [ "${#PRESSURE_REASONS[@]}" -gt 0 ]
}

# --- status mode: lock-holder-state detection, never a naive process match ----------------------
# Primary check is race-free: attempt a non-blocking flock on the lock file. Lock free -> no
# guarded build in flight. Lock held -> exit 10 with a one-line report. This is deliberately
# NEVER driven by `pgrep lean` or `pgrep -f 'lake build'`: during research, four long-lived
# `lean --worker`/`lean --server` LSP processes were observed live in the same project directory,
# and a naive argv/comm match would have reported a build that did not exist. Because detection
# here is anchored purely on lock-holder state (not on scanning ambient processes at all), a
# caller's own argv mentioning "lake build", or an ambient `lean`-comm LSP worker, can never
# cause a false positive -- there is no process table scan on this path at all.
#
# This is also why a CALLER waiting on an in-flight guarded build must not invent its own
# `pgrep -f` scan either: see "WAITING ON AN IN-FLIGHT GUARDED BUILD" in the header above for the
# `kill -0 "$holder_pid"` idiom and the self-match pitfall it avoids -- the same self-match class
# this function's own design sidesteps by never scanning the process table.

cmd_status() {
  if ! have_flock; then
    echo "lake-build-guard: flock not found on PATH; cannot determine lock state" >&2
    exit 0
  fi

  local fd
  exec {fd}<>"$LOCK_PATH"

  if flock -n "$fd"; then
    exit 0
  fi

  local holder_pid
  holder_pid="$(get_record_field holder_pid "$RESULT_PATH" 2>/dev/null || true)"
  echo "lake-build-guard: in-flight guarded build detected (holder pid ${holder_pid:-unknown})"

  if [ "${VERBOSE:-false}" = "true" ]; then
    report_verbose_descendants "${holder_pid:-}"
  fi

  exit 10
}

# --- Supplementary --verbose diagnostics: descendants of the recorded holder PID only -----------
# Single atomic `ps` snapshot per invocation (the claude-refresh.sh discipline) -- every decision
# below reads that one snapshot; no candidate PID is ever re-queried. Matches on `comm`
# (executable identity), never on an argv substring. Refuses loudly (exit 79) rather than
# falling back to an unsafe argv match if this platform's `ps` cannot produce the required
# columns.

take_ps_snapshot() {
  local out
  if ! out=$(ps -eo pid,ppid,comm,args --no-headers 2>&1); then
    echo "ERROR: 'ps -eo pid,ppid,comm,args' failed:" >&2
    echo "$out" >&2
    exit 79
  fi
  printf '%s\n' "$out"
}

# Zero-query self-exclusion: pid or ppid equal to this script's own $$/$PPID (both known at parse
# time) is excluded before any further predicate runs.
is_self_row() {
  local pid="$1" ppid="$2"
  [ "$pid" = "$$" ] || [ "$ppid" = "$$" ]
}

# True when candidate pid is holder_pid itself or a descendant of it, walking the ppid chain
# through the already-captured snapshot (no re-query).
is_descendant_of_holder() {
  local snapshot="$1" holder_pid="$2" candidate_pid="$3"
  local pid="$candidate_pid" hops=0
  while [ -n "$pid" ] && [ "$pid" != "1" ] && [ "$hops" -lt 50 ]; do
    if [ "$pid" = "$holder_pid" ]; then
      return 0
    fi
    pid="$(printf '%s\n' "$snapshot" | awk -v p="$pid" '$1==p{print $2; exit}')"
    hops=$((hops + 1))
  done
  return 1
}

report_verbose_descendants() {
  local holder_pid="$1"
  if [ -z "$holder_pid" ]; then
    echo "lake-build-guard: --verbose: no holder pid recorded in $RESULT_PATH" >&2
    return
  fi
  local snapshot
  snapshot="$(take_ps_snapshot)"
  echo "lake-build-guard: --verbose: process descendants of holder pid $holder_pid:" >&2
  local pid ppid comm args
  while read -r pid ppid comm args; do
    [ -z "$pid" ] && continue
    if is_self_row "$pid" "$ppid"; then
      continue
    fi
    if [ "$pid" = "$holder_pid" ] || is_descendant_of_holder "$snapshot" "$holder_pid" "$pid"; then
      printf '  pid=%s ppid=%s comm=%s\n' "$pid" "$ppid" "$comm" >&2
    fi
  done <<< "$snapshot"
}

# --- preflight mode -------------------------------------------------------------------------------

cmd_preflight() {
  if check_memory_pressure; then
    echo "lake-build-guard: memory pressure detected:" >&2
    local r
    for r in "${PRESSURE_REASONS[@]}"; do
      printf '  - %s\n' "$r" >&2
    done
    exit 11
  fi
  exit 0
}

# --- build mode ------------------------------------------------------------------------------------

# Run `"$LAKE_BIN" "$@"` (optionally wrapped in a systemd-run memory scope) in the FOREGROUND,
# tee-ing stdout and stderr each to their own capture file (for later replay) while still writing
# stdout to stdout and stderr to stderr unchanged -- no `&` anywhere on this invocation, no
# consumption of the caller's stdin. `--quiet --collect` on systemd-run is MANDATORY, not
# cosmetic: without it, systemd-run's own status chatter on stderr corrupts every
# `BUILD_OUTPUT="$(lake build 2>&1)"` call site this guard is meant to be droppable into.
run_lake_foreground() {
  local -a cmd
  if [ "${MEMORY_BOUND:-false}" = "true" ]; then
    if have_systemd_run; then
      cmd=(systemd-run --user --scope --quiet --collect \
        -p "MemoryHigh=${MEMORY_HIGH}" -p "MemoryMax=${MEMORY_MAX}" -- "$LAKE_BIN" "$@")
    else
      echo "lake-build-guard: systemd-run unavailable or lacks user-scope cgroup delegation; running build unbounded" >&2
      cmd=("$LAKE_BIN" "$@")
    fi
  else
    cmd=("$LAKE_BIN" "$@")
  fi

  : > "$STDOUT_CAPTURE_PATH"
  : > "$STDERR_CAPTURE_PATH"

  set +e
  "${cmd[@]}" \
    > >(tee "$STDOUT_CAPTURE_PATH") \
    2> >(tee "$STDERR_CAPTURE_PATH" >&2)
  local rc=$?
  wait
  set -e

  {
    echo "=== stdout ==="
    cat "$STDOUT_CAPTURE_PATH" 2>/dev/null || true
    echo "=== stderr ==="
    cat "$STDERR_CAPTURE_PATH" 2>/dev/null || true
  } > "$LOG_PATH"

  return "$rc"
}

run_as_holder() {
  local pre_fp scope_key
  pre_fp="$(compute_fingerprint "$ROOT")"
  scope_key="$(compute_scope_key "$@")"
  write_inflight_record "$pre_fp" "$scope_key"

  # TERMINAL RECORD GUARANTEE (see header): install the trap immediately after the in-flight
  # record exists, so every trappable exit from here on finalizes it. The EXIT trap captures "$?"
  # at trap-fire time (deferred expansion inside the single-quoted string), which is the shell's
  # pending exit status for a bare, non-signal exit (e.g. a `set -e` abort).
  _RECORD_FINALIZED=false
  trap '_abort_record_trap EXIT $?' EXIT
  trap '_abort_record_trap INT' INT
  trap '_abort_record_trap TERM' TERM

  set +e
  run_lake_foreground "$@"
  local rc=$?
  set -e

  local post_fp
  post_fp="$(compute_fingerprint "$ROOT")"
  finalize_record "$rc" "$post_fp"
  _RECORD_FINALIZED=true
  trap - EXIT INT TERM

  return "$rc"
}

cmd_build() {
  local timeout="$1"
  shift
  local -a args=("$@")

  # Preflight: default is warn-and-proceed; --defer-on-pressure exits 76 without launching.
  if check_memory_pressure; then
    if [ "${DEFER_ON_PRESSURE:-false}" = "true" ]; then
      echo "lake-build-guard: deferring build due to memory pressure (--defer-on-pressure):" >&2
      local r
      for r in "${PRESSURE_REASONS[@]}"; do
        printf '  - %s\n' "$r" >&2
      done
      exit 76
    else
      echo "lake-build-guard: memory pressure detected; proceeding anyway (pass --defer-on-pressure to defer instead)" >&2
    fi
  fi

  LAKE_BIN="$(resolve_lake_bin)"
  if [ -z "$LAKE_BIN" ]; then
    echo "lake-build-guard: 'lake' not found on PATH (and LAKE_BUILD_GUARD_LAKE_BIN not set)" >&2
    exit 79
  fi

  if ! have_flock; then
    echo "lake-build-guard: flock not found on PATH; running unserialized" >&2
    set +e
    run_lake_foreground "${args[@]}"
    local rc=$?
    set -e
    exit "$rc"
  fi

  # Compute our own fingerprint BEFORE attempting/waiting on the lock, so it reflects the tree
  # state at the moment we asked to build -- not whatever it drifts to while we wait, and not
  # whatever a competing holder's own build changes underneath us. Same reasoning applies to the
  # scope key: it is derived purely from our own argument vector (args), so it needs no lock.
  local current_fp current_scope_key
  current_fp="$(compute_fingerprint "$ROOT")"
  current_scope_key="$(compute_scope_key "${args[@]+"${args[@]}"}")"

  local lock_fd
  exec {lock_fd}<>"$LOCK_PATH"

  if ! flock -n "$lock_fd"; then
    # Someone else holds the lock right now: the waiter path.
    if ! flock -w "$timeout" "$lock_fd"; then
      echo "lake-build-guard: timed out after ${timeout}s waiting for the build lock" >&2
      exit 75
    fi
  fi

  # We now hold the lock, whether acquired immediately (no contention) or after waiting on a
  # concurrent holder. The sharing decision is checked on BOTH paths, not only the waiter path:
  # a fresh, matching, complete result should be replayed even for a fully sequential caller
  # that never actually contended the lock (e.g. two agents invoking `build` 30 seconds apart
  # with no tree changes between them) -- this is a strict superset of waiter-only sharing and
  # changes nothing about convoy-avoidance semantics for genuinely concurrent sessions, since a
  # freshly-started record with no prior complete build still correctly falls through to a real
  # build on the immediate-acquire path (decide_sharing requires state=complete).
  if [ "${NO_SHARE:-false}" != "true" ] && decide_sharing "$current_fp" "$current_scope_key"; then
    # Defect B (reporting): a replay is NOT a no-conflict path (see the FAMILY CONVENTIONS
    # silent-when-no-conflict qualification above) -- announce it on stderr, with the stable
    # `lake-build-guard: REPLAY:` marker prefix, BEFORE replaying. replay_shared_result() itself
    # stays untouched so the replayed stdout/stderr bytes remain byte-identical to the original
    # build's (cases 1/3 assert byte-equality on the fresh-build path only; this line never
    # appears there). No job count: see the plan's Decision 3 -- it is a property of `lake`'s own
    # output text, not of anything this guard records, and parsing it would couple the guard to a
    # format it deliberately passes through untouched. The caller reads it from the replayed
    # stdout instead, which is byte-identical to the original build's.
    local replay_holder_pid replay_end_epoch replay_exit_status replay_age
    replay_holder_pid="$(get_record_field holder_pid "$RESULT_PATH" 2>/dev/null || true)"
    replay_end_epoch="$(get_record_field end_epoch "$RESULT_PATH" 2>/dev/null || true)"
    replay_exit_status="$(get_record_field exit_status "$RESULT_PATH" 2>/dev/null || true)"
    replay_age=$(( $(date +%s) - ${replay_end_epoch:-0} ))
    echo "lake-build-guard: REPLAY: sharing result from holder pid ${replay_holder_pid:-unknown}, age ${replay_age}s, recorded exit status ${replay_exit_status:-unknown}" >&2
    replay_shared_result
    local shared_rc
    shared_rc="$(get_record_field exit_status "$RESULT_PATH" 2>/dev/null || true)"
    exit "${shared_rc:-1}"
  fi

  set +e
  run_as_holder "${args[@]}"
  local rc=$?
  set -e
  exit "$rc"
}

# --- Build-mode subcommand validation (Defect A) ------------------------------------------------
# Reject an unrecognized, flag-shaped, or absent lake subcommand in build mode BEFORE dispatch --
# see LAKE SUBCOMMAND ALLOWLIST in the header for the full rationale. Exit 77 (the existing usage-
# error code), matching the no-args/unknown-top-level-subcommand/unknown-option sites already
# using it.
validate_build_subcommand() {
  local -a vec=("$@")
  if [ "${#vec[@]}" -eq 0 ]; then
    echo "lake-build-guard: build mode requires a lake subcommand (e.g. 'build', 'test'); none was given" >&2
    print_help >&2
    exit 77
  fi

  local candidate="${vec[0]}"
  local allowed="$LAKE_SUBCOMMANDS $LAKE_BUILD_GUARD_EXTRA_SUBCOMMANDS"
  local sc
  for sc in $allowed; do
    if [ "$candidate" = "$sc" ]; then
      return 0
    fi
  done

  echo "lake-build-guard: unrecognized lake subcommand: '$candidate' (build mode requires a recognized lake subcommand as the first lake argument; see --help, or set LAKE_BUILD_GUARD_EXTRA_SUBCOMMANDS)" >&2
  exit 77
}

# --- Argument parsing / dispatch --------------------------------------------------------------------

main() {
  if [ $# -eq 0 ]; then
    print_help
    exit 77
  fi

  local mode=""
  case "$1" in
    --help|-h)
      print_help
      exit 0
      ;;
    status|preflight|build)
      mode="$1"
      shift
      ;;
    *)
      echo "lake-build-guard: unknown subcommand: $1" >&2
      print_help >&2
      exit 77
      ;;
  esac

  local dir="$PWD"
  local timeout="$DEFAULT_LOCK_TIMEOUT"
  MEMORY_BOUND=false
  if [ "$LAKE_BUILD_GUARD_MEMORY_BOUND" = "1" ]; then
    MEMORY_BOUND=true
  fi
  MEMORY_HIGH="$DEFAULT_MEMORY_HIGH"
  MEMORY_MAX="$DEFAULT_MEMORY_MAX"
  DEFER_ON_PRESSURE=false
  NO_SHARE=false
  VERBOSE=false
  local -a lake_args=()

  while [ $# -gt 0 ]; do
    case "$1" in
      --dir|-d)
        dir="$2"; shift 2 ;;
      --timeout)
        timeout="$2"; shift 2 ;;
      --memory-bound)
        MEMORY_BOUND=true; shift ;;
      --memory-high)
        MEMORY_HIGH="$2"; shift 2 ;;
      --memory-max)
        MEMORY_MAX="$2"; shift 2 ;;
      --defer-on-pressure)
        DEFER_ON_PRESSURE=true; shift ;;
      --no-share)
        NO_SHARE=true; shift ;;
      --verbose)
        VERBOSE=true; shift ;;
      --help|-h)
        print_help
        exit 0
        ;;
      --)
        shift
        lake_args+=("$@")
        break
        ;;
      --*)
        echo "lake-build-guard: unknown option: $1" >&2
        exit 77
        ;;
      *)
        lake_args+=("$1")
        shift
        ;;
    esac
  done

  # Defect A fix: validate the collected lake_args vector immediately after the parse loop
  # converges -- BOTH the `--)` branch and the bare catch-all `*)` branch above append to
  # lake_args, and this is the single point after both have had their chance to run. Placed
  # BEFORE resolve_project_root so a usage error surfaces as 77, not masked by a 78 "no Lean
  # project found" from a --dir that happens to be invalid too.
  if [ "$mode" = "build" ]; then
    validate_build_subcommand "${lake_args[@]+"${lake_args[@]}"}"
  fi

  if ! ROOT="$(resolve_project_root "$dir")"; then
    echo "lake-build-guard: no lakefile.lean or lakefile.toml found above '$dir'" >&2
    exit 78
  fi
  init_guard_paths "$ROOT"

  if [ "$VERBOSE" = "true" ]; then
    echo "lake-build-guard: --verbose: resolved project root: $ROOT" >&2
    echo "lake-build-guard: --verbose: lock path: $LOCK_PATH" >&2
  fi

  case "$mode" in
    status)
      cmd_status
      ;;
    preflight)
      cmd_preflight
      ;;
    build)
      cmd_build "$timeout" "${lake_args[@]}"
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
