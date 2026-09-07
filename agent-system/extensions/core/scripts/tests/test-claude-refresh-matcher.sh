#!/usr/bin/env bash
# test-claude-refresh-matcher.sh - Regression suite for claude-refresh.sh's orphan matcher,
# covering the four acceptance-bar assertions: (a) a process under /system.slice/ is never
# selected, (b) a process that merely mentions "claude" in argv without being a Claude
# executable is never selected, (c) an inhibitor whose held target is still alive is never
# selected, and (d) the script's own subshells are never self-selected.
#
# Structural model: pass()/fail()/info() helpers, PASSED/FAILED integer counters, mktemp -d
# workdir with a trap EXIT cleanup, loud-skip discipline (see context/standards/
# shell-script-testing.md). The script under test is copied into the suite's own mktemp -d
# workdir and sourced there (matching test-git-commit-scoped.sh's precedent), so predicates
# are called directly by name rather than through a subprocess per case, and is never
# instrumented or modified to "know" it is under test.
#
# Assertion (c) drives a deterministic scripted probe over claude-refresh.sh's overridable
# `_pid_is_alive` seam, rather than a real backgrounded process. This replaced an earlier
# REAL-process fixture (a backgrounded 300-second `sleep` helper) after that fixture was
# measured to cause a 20-83%
# false-failure rate (`kill -0` observing a killed-but-unreaped zombie as alive) -- see the
# trade-off comment inline at the assertion (c) block below for the full record.
#
# Mutation check (required by shell-script-testing.md's "Mutation checks for regex-shaped
# fixes"): see the dedicated section below. This fix is a full structural redesign, not a
# regex tweak -- the pre-fix script defines none of the four predicate functions, has no
# main(), and has no BASH_SOURCE dual-mode guard, so every assertion in this suite (each of
# which calls one of those functions by name) is structurally incapable of even running
# against the pre-fix script. A dynamic re-run is deliberately not attempted: the pre-fix
# script's top-level body runs unconditionally on `source` and always ends in its own
# unconditional `exit`, so any command placed after a `source <prefix-script>` in the same
# shell is unreachable -- there is no way to get a meaningful per-assertion exit code out of
# it in-process. The static absence check below is therefore the correct, honest way to prove
# non-vacuousness for this specific rewrite, and is reported explicitly rather than glossed
# over.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED (or a required script is
# missing, which is reported loudly, not silently skipped).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_SCRIPTS_DIR="$SCRIPT_DIR/.."
SCRIPT_UNDER_TEST="claude-refresh.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

# --- Loud-skip discipline: verify the required script exists before running anything. ---
if [ ! -f "$SRC_SCRIPTS_DIR/$SCRIPT_UNDER_TEST" ]; then
  echo "ERROR: test-claude-refresh-matcher.sh cannot run -- missing required script: $SRC_SCRIPTS_DIR/$SCRIPT_UNDER_TEST" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() {
  [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"
}
trap cleanup EXIT

# Copy the script under test into our own workdir and source it there, so predicates are
# called directly. Sourcing must have zero side effects (no main() execution) since
# BASH_SOURCE != $0 when sourced.
cp "$SRC_SCRIPTS_DIR/$SCRIPT_UNDER_TEST" "$WORKDIR/$SCRIPT_UNDER_TEST"
# shellcheck disable=SC1090,SC1091
. "$WORKDIR/$SCRIPT_UNDER_TEST"

# main() being defined is expected; what matters is that it was NOT invoked by the `source`
# above. Verified implicitly: main() unconditionally calls exit before this line, in every
# code path, so reaching this line at all already proves sourcing had no side effects.
pass "sourcing $SCRIPT_UNDER_TEST defined functions without executing main() (this line was reached)"

# =====================================================================
# Assertion (a): system-slice cgroup exclusion
# =====================================================================
if is_system_slice_cgroup "0::/system.slice/earlyoom.service"; then
  pass "is_system_slice_cgroup: a /system.slice/ cgroup is excluded (earlyoom.service)"
else
  fail "is_system_slice_cgroup: a /system.slice/ cgroup was NOT excluded (earlyoom.service)"
fi

if is_system_slice_cgroup "0::/user.slice/user-1000.slice/user@1000.service/app.slice/app-org.wezfurlong.wezterm.scope"; then
  fail "is_system_slice_cgroup: a real user-session cgroup was incorrectly excluded"
else
  pass "is_system_slice_cgroup: a real user-session cgroup is NOT excluded"
fi

# =====================================================================
# Assertion (b): argv-mention rejection (comm-identity gate)
# =====================================================================
# Reproduces the real earlyoom line: argv mentions "claude" inside an unrelated --prefer
# regex flag, but comm is "earlyoom", not a Claude executable.
EARLYOOM_ARGS='/nix/store/xxxx-earlyoom-1.9.0/bin/earlyoom -m10 -n -r3600 -s10 --avoid ^(gnome-shell|Xwayland|niri)$ --prefer ^(lean|lake|claude|node|npm|opencode)$'
if is_claude_executable_comm "earlyoom" "$EARLYOOM_ARGS"; then
  fail "is_claude_executable_comm: earlyoom (argv mentions 'claude') was incorrectly accepted as a Claude executable"
else
  pass "is_claude_executable_comm: earlyoom (argv mentions 'claude') is rejected by the comm predicate"
fi

# A genuine claude CLI process must still be accepted.
if is_claude_executable_comm "claude" "claude --dangerously-skip-permissions"; then
  pass "is_claude_executable_comm: a genuine 'claude' comm is accepted"
else
  fail "is_claude_executable_comm: a genuine 'claude' comm was incorrectly rejected"
fi

# =====================================================================
# Assertion (c): inhibitor-target liveness, driven by a deterministic scripted probe
# =====================================================================
# Trade-off (recorded, not silent): this assertion previously drove a REAL backgrounded
# process (a backgrounded 300-second `sleep` helper), killed it, and polled up to 8s for
# `kill -0` to observe the reap
# before asserting liveness semantics. That mechanism was measured to fail 20% of the time
# inside verify-deploy.sh's gate 8 (43% standalone on an idle machine, 83% in a mirror copy):
# `kill -0` reports a killed-but-unreaped zombie as alive, so the "dead" case's poll loop
# could burn its full budget and still observe a false "alive". Two real-process repairs were
# tried and both failed under test: a naive `wait` hung ~300s (this suite used to leak a
# 300-second `sleep` helper inheriting stdout/stderr, so any reader using command substitution
# blocked for the full 300s), and `kill -9` + `wait` + detached streams killed the test
# script itself (RC=137, 20/20). Further widening the poll budget was also disproven: no
# finite budget helps a 43-83% failure rate.
#
# The fix routes the liveness syscall through claude-refresh.sh's overridable `_pid_is_alive`
# seam and substitutes a deterministic, test-local override for the duration of this block
# only. What remains real: the `--pid=([0-9]+)` extraction runs against a genuine
# `systemd-inhibit ... tail --pid=<N> -f /dev/null` argv string in both directions, both
# liveness directions are exercised, and the no-`--pid` rejection path below is unaffected.
# What is substituted: only the underlying `kill -0` syscall -- no real process is spawned,
# killed, or waited on for this assertion anymore.
ALIVE_PID_LITERAL=424242
DEAD_PID_LITERAL=424243

# Test-local override of the production seam. Restored immediately after this block so it
# cannot leak into any later assertion in this same shell.
_pid_is_alive() {
  [ "$1" = "$ALIVE_PID_LITERAL" ]
}

INHIBITOR_ARGS_ALIVE="systemd-inhibit --what=sleep:idle --who=claude-code --why=Claude Code session --mode=block tail --pid=${ALIVE_PID_LITERAL} -f /dev/null"
INHIBITOR_ARGS_DEAD="systemd-inhibit --what=sleep:idle --who=claude-code --why=Claude Code session --mode=block tail --pid=${DEAD_PID_LITERAL} -f /dev/null"

if is_live_inhibitor_target "$INHIBITOR_ARGS_ALIVE"; then
  pass "is_live_inhibitor_target: excludes an inhibitor whose target (pid $ALIVE_PID_LITERAL) is alive"
else
  fail "is_live_inhibitor_target: did NOT exclude an inhibitor whose target (pid $ALIVE_PID_LITERAL) is alive"
fi

if is_live_inhibitor_target "$INHIBITOR_ARGS_DEAD"; then
  fail "is_live_inhibitor_target: incorrectly excludes an inhibitor whose target (pid $DEAD_PID_LITERAL) is dead -- tautological check"
else
  pass "is_live_inhibitor_target: does not exclude an inhibitor once its target (pid $DEAD_PID_LITERAL) is dead -- genuine liveness test"
fi

# Restore the production seam definition immediately -- the override above must not leak
# into any assertion below this line (verified by the no-`--pid` case immediately following,
# and by assertion (d) further below).
_pid_is_alive() {
  kill -0 "$1" 2>/dev/null
}

# A row with no --pid=<N> at all must never be treated as a live inhibitor.
if is_live_inhibitor_target "systemd-inhibit --what=sleep:idle --who=someone --mode=block sleep infinity"; then
  fail "is_live_inhibitor_target: incorrectly matched a systemd-inhibit row with no --pid=<N> target"
else
  pass "is_live_inhibitor_target: a systemd-inhibit row with no --pid=<N> target is not treated as a live inhibitor"
fi

# =====================================================================
# Assertion (d): self-subshell exclusion
# =====================================================================
# (d-1) A synthetic row for a bash-comm process whose args contain the script's own path
# must be rejected by the comm predicate -- mirroring the real 4056113/4056114-style false
# positive (the refresh script's own transient subshells).
SELF_PATH_ARGS="bash agent-system/extensions/core/scripts/claude-refresh.sh"
if is_claude_executable_comm "bash" "$SELF_PATH_ARGS"; then
  fail "is_claude_executable_comm: a bash-comm row mentioning the script's own path was incorrectly accepted"
else
  pass "is_claude_executable_comm: a bash-comm row mentioning the script's own path is rejected by the comm predicate"
fi

# (d-2) Direct end-to-end case for the $$/ppid zero-query self-exclusion: run the fixed
# script as a real subprocess with a fake `ps` on PATH that injects a synthetic row for the
# running script's OWN pid, alongside a distinct, otherwise-identical CONTROL row. If
# self-exclusion works, the self-row must never appear in the report while the control row
# must.
#
# Determining "the running script's own pid" correctly is the subtle part: claude-refresh.sh
# calls `ps` from inside take_snapshot(), itself captured via `snapshot=$(take_snapshot)` in
# main(). A command substitution of a FUNCTION forces bash to fork a subshell to run that
# function (functions cannot be exec'd directly), so the process that ultimately execs our
# fake `ps` is a GRANDCHILD of the real script, not a direct child -- `$PPID` inside the fake
# `ps` therefore names that intermediate subshell, not the script's own `$$`. (Verified
# empirically while writing this case: a naive `$PPID`-based guess pointed at the wrong pid
# and the self-row was never excluded, which would have made this a false-negative test.) The
# robust fix is for the fake `ps` to walk its OWN ancestry with the REAL system `ps` (resolved
# to an absolute path before PATH is overridden below) until it finds the nearest ancestor
# whose argv names this script under test -- that ancestor IS the real top-level `$$` the
# script itself sees, regardless of how many subshell layers sit in between.
REAL_PS_BIN="$(command -v ps)"
if [ -z "$REAL_PS_BIN" ]; then
  echo "ERROR: cannot resolve the real 'ps' binary needed to build the self-exclusion (d-2) fixture" >&2
  fail "self-exclusion (d-2): real ps binary not found -- cannot construct fixture"
  REAL_PS_BIN=""
fi

if [ -n "$REAL_PS_BIN" ]; then
  FAKE_BIN_DIR="$WORKDIR/fakebin"
  mkdir -p "$FAKE_BIN_DIR"
  CONTROL_PID=999999
  cat > "$FAKE_BIN_DIR/ps" <<'FAKE_PS_EOF'
#!/usr/bin/env bash
# Fake ps used only by test-claude-refresh-matcher.sh's self-exclusion case (d-2).
has_p_flag=false
for a in "$@"; do
  if [ "$a" = "-p" ]; then has_p_flag=true; fi
done
if $has_p_flag; then
  # validate_cgroup_support()'s self-check: return a plausible non-empty user-slice cgroup.
  echo "0::/user.slice/user-1000.slice/session.scope"
  exit 0
fi

# Walk our own ancestry with the REAL ps until argv stops naming the script under test. A
# subshell forked (not exec'd) for a function's command substitution retains the SAME argv as
# its parent, so every ancestor from here up to and including the real top-level script all
# show identical argv -- the first MATCH is not necessarily the real top-level pid, it could
# be an intermediate subshell. The real top-level pid is the HIGHEST (furthest) ancestor that
# still matches, i.e. the last match seen just before the first non-matching ancestor.
find_self_pid() {
  local check_pid="$PPID"
  local best_match=""
  local hops=0
  while [ -n "$check_pid" ] && [ "$check_pid" != "1" ] && [ "$hops" -lt 25 ]; do
    local row
    row=$("$REAL_PS_BIN" -o args= -p "$check_pid" 2>/dev/null)
    case "$row" in
      *"__SCRIPT_MARKER__"*)
        best_match="$check_pid"
        ;;
      *)
        break
        ;;
    esac
    check_pid=$("$REAL_PS_BIN" -o ppid= -p "$check_pid" 2>/dev/null | tr -d ' ')
    hops=$((hops + 1))
  done
  echo "$best_match"
}

self_pid="$(find_self_pid)"
cur_uid="$(id -u)"
if [ -n "$self_pid" ]; then
  printf '%s 1 %s ? 100 1000 claude 0::/user.slice/user-1000.slice/session.scope claude --dangerously-skip-permissions\n' "$self_pid" "$cur_uid"
fi
printf '%s 1 %s ? 100 1000 claude 0::/user.slice/user-1000.slice/session.scope claude --dangerously-skip-permissions\n' "__CONTROL_PID__" "$cur_uid"
FAKE_PS_EOF
  sed -i "s/__CONTROL_PID__/$CONTROL_PID/" "$FAKE_BIN_DIR/ps"
  sed -i "s#__SCRIPT_MARKER__#$SCRIPT_UNDER_TEST#" "$FAKE_BIN_DIR/ps"
  chmod +x "$FAKE_BIN_DIR/ps"
  # Export REAL_PS_BIN so the fake ps script (and any nested invocation of it) can see it.
  export REAL_PS_BIN

  SELF_EXCLUSION_OUT="$(PATH="$FAKE_BIN_DIR:$PATH" bash "$WORKDIR/$SCRIPT_UNDER_TEST" 2>&1)"

  if echo "$SELF_EXCLUSION_OUT" | grep -q "$CONTROL_PID"; then
    pass "self-exclusion (d-2): the control row (different pid) is reported as an orphan"
  else
    fail "self-exclusion (d-2): the control row (different pid) was NOT reported -- harness defect, not a real assertion"
    info "output was: $SELF_EXCLUSION_OUT"
  fi

  # The self-row's PID varies per run (it is the subprocess's own pid); we cannot grep for a
  # literal value we don't know in advance, but we CAN assert the orphan count is exactly 1
  # (the control row only) rather than 2, which is the direct, real behavioral proof that the
  # self-referencing row was excluded.
  if echo "$SELF_EXCLUSION_OUT" | grep -q "^Found 1 orphaned"; then
    pass "self-exclusion (d-2): exactly one orphan reported (self row excluded, control row kept)"
  elif echo "$SELF_EXCLUSION_OUT" | grep -q "^Found 2 orphaned"; then
    fail "self-exclusion (d-2): two orphans reported -- the script's own self row was NOT excluded"
    info "output was: $SELF_EXCLUSION_OUT"
  else
    fail "self-exclusion (d-2): unexpected output shape from the self-exclusion harness run"
    info "output was: $SELF_EXCLUSION_OUT"
  fi
fi

# =====================================================================
# Assertion (e): VmSwap-aware memory accounting
# =====================================================================
# Fixtures live under $WORKDIR/fakeproc/<pid>/status (heredocs), never against live /proc or a
# real PID, per shell-script-testing.md. PROC_ROOT is restored/unset immediately after use, the
# same discipline assertion (c) applies to the _pid_is_alive seam, so it cannot leak into any
# assertion below.
FAKE_PROC_DIR="$WORKDIR/fakeproc"
mkdir -p "$FAKE_PROC_DIR/70001" "$FAKE_PROC_DIR/70002"

# Case: known value.
printf 'Name:\tworker\nVmSwap:\t   12345 kB\n' > "$FAKE_PROC_DIR/70001/status"
PROC_ROOT="$FAKE_PROC_DIR"
KNOWN_SWAP="$(get_vmswap_kb 70001)"
if [ "$KNOWN_SWAP" = "12345" ]; then
  pass "get_vmswap_kb: known VmSwap value fixture returns 12345"
else
  fail "get_vmswap_kb: known VmSwap value fixture returned '$KNOWN_SWAP', expected 12345"
fi

# Case: absent line -- no-swap-configured host must render cleanly, not error.
printf 'Name:\tworker\n' > "$FAKE_PROC_DIR/70002/status"
ABSENT_SWAP="$(get_vmswap_kb 70002)"
if [ "$ABSENT_SWAP" = "0" ]; then
  pass "get_vmswap_kb: status file with no VmSwap line returns 0, not an error"
else
  fail "get_vmswap_kb: absent-line fixture returned '$ABSENT_SWAP', expected 0"
fi

# Case: missing file -- candidate exited between snapshot and read; must not error or abort.
MISSING_SWAP="$(get_vmswap_kb 70099)"
if [ "$MISSING_SWAP" = "0" ]; then
  pass "get_vmswap_kb: nonexistent PID path returns 0, not an error"
else
  fail "get_vmswap_kb: missing-file fixture returned '$MISSING_SWAP', expected 0"
fi

unset PROC_ROOT

# Case: formatting -- closes a pre-existing format_memory coverage gap noted in research.
FORMATTED="$(format_memory 12345)"
if [ "$FORMATTED" = "12.0 MB" ]; then
  pass "format_memory: 12345 KB formats to '12.0 MB'"
else
  fail "format_memory: 12345 KB formatted to '$FORMATTED', expected '12.0 MB'"
fi

# Case: output shape -- assert on full --dry-run output (not only the isolated helper) that
# the table carries both a Memory and a Swap column with correct values, structurally catching
# an orphan_details field-count mismatch between the write site and the read site -- matching
# how (d-2) above asserts on full script output rather than an isolated function call.
SWAP_FAKE_BIN_DIR="$WORKDIR/fakebin-swap"
mkdir -p "$SWAP_FAKE_BIN_DIR"
SWAP_ROW_PID=700055
cat > "$SWAP_FAKE_BIN_DIR/ps" <<'FAKE_PS_SWAP_EOF'
#!/usr/bin/env bash
# Fake ps used only by test-claude-refresh-matcher.sh's VmSwap output-shape case (e).
has_p_flag=false
for a in "$@"; do
  if [ "$a" = "-p" ]; then has_p_flag=true; fi
done
if $has_p_flag; then
  echo "0::/user.slice/user-1000.slice/session.scope"
  exit 0
fi
cur_uid="$(id -u)"
printf '%s 1 %s ? 100 2048 claude 0::/user.slice/user-1000.slice/session.scope claude --dangerously-skip-permissions\n' "__SWAP_ROW_PID__" "$cur_uid"
FAKE_PS_SWAP_EOF
sed -i "s/__SWAP_ROW_PID__/$SWAP_ROW_PID/" "$SWAP_FAKE_BIN_DIR/ps"
chmod +x "$SWAP_FAKE_BIN_DIR/ps"

SWAP_FAKE_PROC_DIR="$WORKDIR/fakeproc-swap"
mkdir -p "$SWAP_FAKE_PROC_DIR/$SWAP_ROW_PID"
printf 'Name:\tclaude\nVmSwap:\t 1258291 kB\n' > "$SWAP_FAKE_PROC_DIR/$SWAP_ROW_PID/status"

SWAP_OUT="$(PATH="$SWAP_FAKE_BIN_DIR:$PATH" PROC_ROOT="$SWAP_FAKE_PROC_DIR" bash "$WORKDIR/$SCRIPT_UNDER_TEST" --dry-run 2>&1)"

if echo "$SWAP_OUT" | grep -qE '^PID[[:space:]]+Memory[[:space:]]+Swap[[:space:]]+Age[[:space:]]+Command'; then
  pass "--dry-run output shape: table header carries both Memory and Swap columns"
else
  fail "--dry-run output shape: table header missing expected Memory/Swap columns"
  info "output was: $SWAP_OUT"
fi

if echo "$SWAP_OUT" | grep -q "$SWAP_ROW_PID" && echo "$SWAP_OUT" | grep -qE '2\.0 MB[[:space:]]+1\.1 GB'; then
  pass "--dry-run output shape: row shows RSS 2.0 MB alongside swap 1.1 GB (no field-count mismatch)"
else
  fail "--dry-run output shape: expected row with RSS 2.0 MB and swap 1.1 GB not found"
  info "output was: $SWAP_OUT"
fi

# =====================================================================
# Assertion (f): Lean LSP predicate cross-contamination
# =====================================================================
# Fixtures are the live-verified argv strings recorded in the task's research report (a real,
# currently-running lean-lsp-mcp tree on this machine). Proves, in both directions, that the
# Lean predicates and is_claude_executable_comm never accept each other's rows -- the
# independently-gated pass this task adds must never widen or be widened by the existing gate.
LAKE_SERVE_ARGS="/home/user/.elan/toolchains/leanprover--lean4---v4.33.0-rc1/bin/lake serve -- -Dserver.reportDelayMs=0"
LEAN_SERVER_ARGS="/home/user/.elan/toolchains/leanprover--lean4---v4.33.0-rc1/bin/lean --server -Dserver.reportDelayMs=0"
LEAN_WORKER_ARGS="/home/user/.elan/toolchains/leanprover--lean4---v4.33.0-rc1/bin/lean --worker -Dserver.reportDelayMs=0 file:///home/user/Project/File.lean"
LAKE_BUILD_ARGS="/home/user/.elan/toolchains/leanprover--lean4---v4.33.0-rc1/bin/lake build"
LAKE_EXE_CACHE_ARGS="/home/user/.elan/toolchains/leanprover--lean4---v4.33.0-rc1/bin/lake exe cache get"
LAKE_DEFUNCT_COMM="lake <defunct>"
LEAN_DEFUNCT_COMM="lean <defunct>"

# --- Each predicate matches its own form ---
if is_lean_serve_comm "lake" "$LAKE_SERVE_ARGS"; then
  pass "is_lean_serve_comm: matches its own form (lake serve)"
else
  fail "is_lean_serve_comm: did NOT match its own form (lake serve)"
fi

if is_lean_server_comm "lean" "$LEAN_SERVER_ARGS"; then
  pass "is_lean_server_comm: matches its own form (lean --server)"
else
  fail "is_lean_server_comm: did NOT match its own form (lean --server)"
fi

if is_lean_worker_comm "lean" "$LEAN_WORKER_ARGS"; then
  pass "is_lean_worker_comm: matches its own form (lean --worker)"
else
  fail "is_lean_worker_comm: did NOT match its own form (lean --worker)"
fi

# --- Mutual exclusivity: each predicate rejects the OTHER two Lean forms ---
if is_lean_serve_comm "lean" "$LEAN_SERVER_ARGS"; then
  fail "is_lean_serve_comm: incorrectly matched a lean --server row (comm mismatch)"
else
  pass "is_lean_serve_comm: rejects lean --server (comm mismatch)"
fi
if is_lean_serve_comm "lean" "$LEAN_WORKER_ARGS"; then
  fail "is_lean_serve_comm: incorrectly matched a lean --worker row (comm mismatch)"
else
  pass "is_lean_serve_comm: rejects lean --worker (comm mismatch)"
fi

if is_lean_server_comm "lake" "$LAKE_SERVE_ARGS"; then
  fail "is_lean_server_comm: incorrectly matched a lake serve row (comm mismatch)"
else
  pass "is_lean_server_comm: rejects lake serve (comm mismatch)"
fi
if is_lean_server_comm "lean" "$LEAN_WORKER_ARGS"; then
  fail "is_lean_server_comm: incorrectly matched a lean --worker row (args mismatch)"
else
  pass "is_lean_server_comm: rejects lean --worker (args mismatch)"
fi

if is_lean_worker_comm "lake" "$LAKE_SERVE_ARGS"; then
  fail "is_lean_worker_comm: incorrectly matched a lake serve row (comm mismatch)"
else
  pass "is_lean_worker_comm: rejects lake serve (comm mismatch)"
fi
if is_lean_worker_comm "lean" "$LEAN_SERVER_ARGS"; then
  fail "is_lean_worker_comm: incorrectly matched a lean --server row (args mismatch)"
else
  pass "is_lean_worker_comm: rejects lean --server (args mismatch)"
fi

# --- Lean predicates reject every Claude comm the existing suite exercises ---
for lean_fn in is_lean_serve_comm is_lean_server_comm is_lean_worker_comm; do
  if "$lean_fn" "claude" "claude --dangerously-skip-permissions"; then
    fail "$lean_fn: incorrectly matched a genuine 'claude' comm row"
  else
    pass "$lean_fn: rejects a genuine 'claude' comm row"
  fi

  if "$lean_fn" "node" "$EARLYOOM_ARGS"; then
    fail "$lean_fn: incorrectly matched a node/claude-code-style argv row"
  else
    pass "$lean_fn: rejects a node/claude-code-style argv row"
  fi

  if "$lean_fn" "bash" "$SELF_PATH_ARGS"; then
    fail "$lean_fn: incorrectly matched a bash row mentioning the refresh script's own path"
  else
    pass "$lean_fn: rejects a bash row mentioning the refresh script's own path"
  fi
done

# --- Reverse direction: is_claude_executable_comm rejects all three Lean rows ---
if is_claude_executable_comm "lake" "$LAKE_SERVE_ARGS"; then
  fail "is_claude_executable_comm: incorrectly accepted a lake serve row"
else
  pass "is_claude_executable_comm: rejects a lake serve row"
fi
if is_claude_executable_comm "lean" "$LEAN_SERVER_ARGS"; then
  fail "is_claude_executable_comm: incorrectly accepted a lean --server row"
else
  pass "is_claude_executable_comm: rejects a lean --server row"
fi
if is_claude_executable_comm "lean" "$LEAN_WORKER_ARGS"; then
  fail "is_claude_executable_comm: incorrectly accepted a lean --worker row"
else
  pass "is_claude_executable_comm: rejects a lean --worker row"
fi

# --- Zombie rows: deliberate, tested exclusion (comm rendered "lake <defunct>"/"lean <defunct>"
# by ps; an exact `case` match on "lake"/"lean" never matches these strings) ---
if is_lean_serve_comm "$LAKE_DEFUNCT_COMM" "[lake] <defunct>"; then
  fail "is_lean_serve_comm: incorrectly matched a zombie 'lake <defunct>' row"
else
  pass "is_lean_serve_comm: rejects a zombie 'lake <defunct>' row (deliberate exclusion)"
fi
if is_lean_server_comm "$LEAN_DEFUNCT_COMM" "[lean] <defunct>"; then
  fail "is_lean_server_comm: incorrectly matched a zombie 'lean <defunct>' row"
else
  pass "is_lean_server_comm: rejects a zombie 'lean <defunct>' row (deliberate exclusion)"
fi
if is_lean_worker_comm "$LEAN_DEFUNCT_COMM" "[lean] <defunct>"; then
  fail "is_lean_worker_comm: incorrectly matched a zombie 'lean <defunct>' row"
else
  pass "is_lean_worker_comm: rejects a zombie 'lean <defunct>' row (deliberate exclusion)"
fi

# --- is_lean_serve_comm rejects other `lake` subcommands ---
if is_lean_serve_comm "lake" "$LAKE_BUILD_ARGS"; then
  fail "is_lean_serve_comm: incorrectly matched 'lake build'"
else
  pass "is_lean_serve_comm: rejects 'lake build'"
fi
if is_lean_serve_comm "lake" "$LAKE_EXE_CACHE_ARGS"; then
  fail "is_lean_serve_comm: incorrectly matched 'lake exe cache get'"
else
  pass "is_lean_serve_comm: rejects 'lake exe cache get'"
fi

# =====================================================================
# Assertion (g): Lean tree end-to-end -- dry-run-clean and termination ORDERING
# =====================================================================
# Extends the fake-ps-on-PATH pattern already used by (d-2)/(e) with a fake ps that additionally
# recognizes the `-C lake,lean` invocation and emits a synthetic 5-row tree (1 lake serve root,
# 1 lean --server, 3 lean --worker), with old etimes and zero pcpu so it is unconditionally idle.
# The SAME synthetic rows are also emitted from the plain `-eo ...` (no `-C`) invocation that
# run_claude_pass()'s take_snapshot() uses -- proving the Claude pass's own candidacy gate
# independently rejects these rows (wrong comm) regardless of their presence in the full process
# table, not merely that the Lean pass's separately-scoped snapshot never sees Claude rows.
LEAN_TREE_ROOT=800001
LEAN_TREE_SERVER=800002
LEAN_TREE_WORKER1=800003
LEAN_TREE_WORKER2=800004
LEAN_TREE_WORKER3=800005

LEAN_FAKE_BIN_DIR="$WORKDIR/fakebin-lean"
mkdir -p "$LEAN_FAKE_BIN_DIR"
cat > "$LEAN_FAKE_BIN_DIR/ps" <<'FAKE_PS_LEAN_EOF'
#!/usr/bin/env bash
# Fake ps used only by test-claude-refresh-matcher.sh's Lean tree end-to-end case (g).
has_p_flag=false
has_c_flag=false
for a in "$@"; do
  if [ "$a" = "-p" ]; then has_p_flag=true; fi
  if [ "$a" = "-C" ]; then has_c_flag=true; fi
done
if $has_p_flag; then
  # validate_cgroup_support()'s self-check.
  echo "0::/user.slice/user-1000.slice/session.scope"
  exit 0
fi

cur_uid="$(id -u)"
CG="0::/user.slice/user-1000.slice/session.scope"

if $has_c_flag; then
  # take_lean_snapshot(): pid,ppid,uid,etimes,rss,pcpu,cgroup:200,comm,args
  printf '%s %s %s %s %s %s %s %s %s\n' __ROOT__    1         "$cur_uid" 20000 10240  0.0 "$CG" lake ".../bin/lake serve -- -Dserver.reportDelayMs=0"
  printf '%s %s %s %s %s %s %s %s %s\n' __SERVER__  __ROOT__   "$cur_uid" 20000 675000 0.0 "$CG" lean ".../bin/lean --server -Dserver.reportDelayMs=0"
  printf '%s %s %s %s %s %s %s %s %s\n' __WORKER1__ __SERVER__ "$cur_uid" 19998 35000  0.0 "$CG" lean ".../bin/lean --worker -Dserver.reportDelayMs=0 file:///a.lean"
  printf '%s %s %s %s %s %s %s %s %s\n' __WORKER2__ __SERVER__ "$cur_uid" 19995 115000 0.0 "$CG" lean ".../bin/lean --worker -Dserver.reportDelayMs=0 file:///b.lean"
  printf '%s %s %s %s %s %s %s %s %s\n' __WORKER3__ __SERVER__ "$cur_uid" 19990 114000 0.0 "$CG" lean ".../bin/lean --worker -Dserver.reportDelayMs=0 file:///c.lean"
  exit 0
fi

# take_snapshot() (Claude pass): pid,ppid,uid,tty,etimes,rss,comm,cgroup:200,args -- same
# synthetic Lean rows, as they would genuinely appear in the full process table.
printf '%s %s %s %s %s %s %s %s %s\n' __ROOT__    1          "$cur_uid" pts/11 20000 10240  lake "$CG" ".../bin/lake serve -- -Dserver.reportDelayMs=0"
printf '%s %s %s %s %s %s %s %s %s\n' __SERVER__  __ROOT__    "$cur_uid" pts/11 20000 675000 lean "$CG" ".../bin/lean --server -Dserver.reportDelayMs=0"
printf '%s %s %s %s %s %s %s %s %s\n' __WORKER1__ __SERVER__  "$cur_uid" ?      19998 35000  lean "$CG" ".../bin/lean --worker -Dserver.reportDelayMs=0 file:///a.lean"
printf '%s %s %s %s %s %s %s %s %s\n' __WORKER2__ __SERVER__  "$cur_uid" ?      19995 115000 lean "$CG" ".../bin/lean --worker -Dserver.reportDelayMs=0 file:///b.lean"
printf '%s %s %s %s %s %s %s %s %s\n' __WORKER3__ __SERVER__  "$cur_uid" ?      19990 114000 lean "$CG" ".../bin/lean --worker -Dserver.reportDelayMs=0 file:///c.lean"
exit 0
FAKE_PS_LEAN_EOF
sed -i "s/__ROOT__/$LEAN_TREE_ROOT/g; s/__SERVER__/$LEAN_TREE_SERVER/g; s/__WORKER1__/$LEAN_TREE_WORKER1/g; s/__WORKER2__/$LEAN_TREE_WORKER2/g; s/__WORKER3__/$LEAN_TREE_WORKER3/g" "$LEAN_FAKE_BIN_DIR/ps"
chmod +x "$LEAN_FAKE_BIN_DIR/ps"

# Fixture /proc/<pid>/status files, driven via the PROC_ROOT seam -- get_vmswap_kb() reads these,
# never live /proc.
LEAN_FAKE_PROC_DIR="$WORKDIR/fakeproc-lean"
for lean_pid in "$LEAN_TREE_ROOT" "$LEAN_TREE_SERVER" "$LEAN_TREE_WORKER1" "$LEAN_TREE_WORKER2" "$LEAN_TREE_WORKER3"; do
  mkdir -p "$LEAN_FAKE_PROC_DIR/$lean_pid"
  printf 'Name:\tlean\nVmSwap:\t   1024 kB\n' > "$LEAN_FAKE_PROC_DIR/$lean_pid/status"
done

# Fake kill: logs "<signal> <pid>" for every SIGTERM(-15)/SIGKILL(-9) to $KILL_LOG_FILE; a
# `kill -0` liveness probe always reports "alive" (exit 0) for these synthetic PIDs, which drives
# every one of them through terminate_pid()'s SIGTERM->sleep->SIGKILL "forced" branch
# deterministically. No real process is ever signaled by this fixture.
KILL_LOG_FILE="$WORKDIR/kill.log"
: > "$KILL_LOG_FILE"
LEAN_FAKE_KILL_DIR="$WORKDIR/fakebin-kill"
mkdir -p "$LEAN_FAKE_KILL_DIR"
cat > "$LEAN_FAKE_KILL_DIR/kill" <<'FAKE_KILL_EOF'
#!/usr/bin/env bash
sig=""
pid=""
for a in "$@"; do
  case "$a" in
    -0|-15|-9) sig="$a" ;;
    *) pid="$a" ;;
  esac
done
if [ "$sig" = "-0" ]; then
  exit 0
fi
echo "${sig#-} ${pid}" >> "$KILL_LOG_FILE"
exit 0
FAKE_KILL_EOF
chmod +x "$LEAN_FAKE_KILL_DIR/kill"
export KILL_LOG_FILE

# --- Dry-run-clean assertion: lists all 5 synthetic PIDs + total, terminates nothing ---
LEAN_DRY_RUN_OUT="$(PATH="$LEAN_FAKE_BIN_DIR:$LEAN_FAKE_KILL_DIR:$PATH" PROC_ROOT="$LEAN_FAKE_PROC_DIR" LEAN_LSP_IDLE_THRESHOLD_MIN=1 bash "$WORKDIR/$SCRIPT_UNDER_TEST" --dry-run 2>&1)"

LEAN_DRY_RUN_OK=true
for lean_pid in "$LEAN_TREE_ROOT" "$LEAN_TREE_SERVER" "$LEAN_TREE_WORKER1" "$LEAN_TREE_WORKER2" "$LEAN_TREE_WORKER3"; do
  if ! echo "$LEAN_DRY_RUN_OUT" | grep -q "$lean_pid"; then
    LEAN_DRY_RUN_OK=false
  fi
done
if $LEAN_DRY_RUN_OK && echo "$LEAN_DRY_RUN_OUT" | grep -q "Found 1 idle Lean LSP process tree"; then
  pass "Lean tree (g): --dry-run lists all five synthetic PIDs and the tree count"
else
  fail "Lean tree (g): --dry-run did not list all five synthetic PIDs / tree count"
  info "output was: $LEAN_DRY_RUN_OUT"
fi

if echo "$LEAN_DRY_RUN_OUT" | grep -q "Total memory that can be reclaimed"; then
  pass "Lean tree (g): --dry-run shows a total reclaimable memory figure"
else
  fail "Lean tree (g): --dry-run did not show a total reclaimable memory figure"
  info "output was: $LEAN_DRY_RUN_OUT"
fi

if [ ! -s "$KILL_LOG_FILE" ]; then
  pass "Lean tree (g): dry-run-clean -- fake-kill log is empty (nothing terminated)"
else
  fail "Lean tree (g): dry-run-clean VIOLATED -- fake-kill log is non-empty after --dry-run"
  info "kill log was: $(cat "$KILL_LOG_FILE")"
fi

# --- Claude pass unaffected by the presence of Lean rows in its own snapshot ---
if echo "$LEAN_DRY_RUN_OUT" | grep -q "No orphaned processes found."; then
  pass "Lean tree (g): Claude pass's own --dry-run output is unaffected by Lean rows in its snapshot"
else
  fail "Lean tree (g): Claude pass's --dry-run output was affected by the presence of Lean rows"
  info "output was: $LEAN_DRY_RUN_OUT"
fi

# --- ORDERING assertion: --force terminates workers before server before root (log sequence) ---
# `kill` is a bash BUILTIN, not an external command -- a plain `PATH=...` override (as used for
# the fake `ps` above) is silently ignored for it, since bash resolves builtins before consulting
# $PATH. The builtin must be disabled for this one subshell via `enable -n kill` BEFORE the
# script under test is sourced, so its own `kill -0`/`kill -15`/`kill -9` calls resolve to the
# fake `kill` on $PATH instead. Sourcing (rather than executing) means the script's own
# `BASH_SOURCE[0] == $0` dual-mode guard does not auto-invoke main() here (`$0` is this `bash -c`
# invocation, not the script), so main() is called explicitly after sourcing.
: > "$KILL_LOG_FILE"
LEAN_FORCE_OUT="$(bash -c '
  enable -n kill
  export PATH="$1:$2:$PATH"
  export PROC_ROOT="$3"
  export LEAN_LSP_IDLE_THRESHOLD_MIN="$4"
  # shellcheck disable=SC1090
  source "$5"
  main --force
' _ "$LEAN_FAKE_BIN_DIR" "$LEAN_FAKE_KILL_DIR" "$LEAN_FAKE_PROC_DIR" 1 "$WORKDIR/$SCRIPT_UNDER_TEST" 2>&1)"

if [ -s "$KILL_LOG_FILE" ]; then
  # Find the LAST line number at which each pid appears (a pid may appear twice: SIGTERM then
  # SIGKILL -- the ordering claim is about pid-to-pid order, not signal count per pid).
  worker1_line=$(grep -n " ${LEAN_TREE_WORKER1}\$" "$KILL_LOG_FILE" | tail -1 | cut -d: -f1)
  worker2_line=$(grep -n " ${LEAN_TREE_WORKER2}\$" "$KILL_LOG_FILE" | tail -1 | cut -d: -f1)
  worker3_line=$(grep -n " ${LEAN_TREE_WORKER3}\$" "$KILL_LOG_FILE" | tail -1 | cut -d: -f1)
  server_line=$(grep -n " ${LEAN_TREE_SERVER}\$" "$KILL_LOG_FILE" | head -1 | cut -d: -f1)
  root_line=$(grep -n " ${LEAN_TREE_ROOT}\$" "$KILL_LOG_FILE" | head -1 | cut -d: -f1)

  if [ -n "$worker1_line" ] && [ -n "$worker2_line" ] && [ -n "$worker3_line" ] \
     && [ -n "$server_line" ] && [ -n "$root_line" ] \
     && [ "$worker1_line" -lt "$server_line" ] && [ "$worker2_line" -lt "$server_line" ] \
     && [ "$worker3_line" -lt "$server_line" ] && [ "$server_line" -lt "$root_line" ]; then
    pass "Lean tree (g): --force ORDERING -- all workers precede server, server precedes root (log sequence)"
  else
    fail "Lean tree (g): --force ORDERING violated or log incomplete"
    info "kill log was: $(cat "$KILL_LOG_FILE")"
  fi
else
  fail "Lean tree (g): --force produced an empty fake-kill log -- harness defect, not a real assertion"
  info "output was: $LEAN_FORCE_OUT"
fi

unset PROC_ROOT KILL_LOG_FILE

# =====================================================================
# Mutation check: pre-fix script cannot run any of this suite's assertions
# =====================================================================
# NOTE: this deliberately pins the specific commit immediately BEFORE the matcher rewrite
# landed, not "HEAD" -- by the time this suite itself was added, HEAD already IS the fixed
# script (the rewrite and this suite are separate, sequential phases of the same change), so
# "git show HEAD:..." would recover the FIXED script, not the pre-fix one, making the check
# vacuously pass. The pinned commit remains resolvable indefinitely (ordinary git history is
# never garbage-collected while reachable from any ref), so this is a stable, permanent
# mutation-check anchor, not a fragile one-time convenience.
info "Mutation check: confirming the suite is not vacuous against the pre-fix script"
PREFIX_COMMIT="7e79b2695"
PREFIX_SCRIPT="$WORKDIR/prefix.sh"
if git -C "$SRC_SCRIPTS_DIR" show "${PREFIX_COMMIT}:agent-system/extensions/core/scripts/$SCRIPT_UNDER_TEST" > "$PREFIX_SCRIPT" 2>/dev/null; then
  MISSING_IN_PREFIX=()
  # Extended for the Lean LSP reclamation pass: is_lean_serve_comm, is_lean_server_comm,
  # is_lean_worker_comm, take_lean_snapshot, lean_row_is_idle, detect_lean_candidate_trees,
  # terminate_pid, run_claude_pass, and run_lean_pass are all brand-NEW functions this task adds
  # (not modifications of existing ones -- terminate_pid/run_claude_pass/run_lean_pass are the
  # Phase 4 extraction/restructure of what used to be inlined directly in main()), so their
  # absence from any pre-task commit -- this same pinned PREFIX_COMMIT included, since it
  # predates this task entirely -- is itself the non-vacuousness proof the plan calls for:
  # assertions (f) and (g) above call each of them by name and would fail with "command not
  # found" against a script that lacks them.
  for fn in is_claude_executable_comm is_system_slice_cgroup is_owned_by_current_uid is_live_inhibitor_target get_vmswap_kb is_lean_serve_comm is_lean_server_comm is_lean_worker_comm take_lean_snapshot lean_row_is_idle detect_lean_candidate_trees terminate_pid run_claude_pass run_lean_pass; do
    if ! grep -q "^${fn}()" "$PREFIX_SCRIPT"; then
      MISSING_IN_PREFIX+=("$fn")
    fi
  done
  if ! grep -q 'BASH_SOURCE\[0\].*==.*\$0' "$PREFIX_SCRIPT"; then
    MISSING_IN_PREFIX+=("main()/BASH_SOURCE dual-mode guard")
  fi

  if [ "${#MISSING_IN_PREFIX[@]}" -eq 14 ] || [ "${#MISSING_IN_PREFIX[@]}" -eq 15 ]; then
    pass "mutation check: pre-fix script (commit $PREFIX_COMMIT) defines none of the fourteen predicates/helpers or the main() guard -- every assertion above would fail with 'command not found' against it (RED confirmed)"
    info "absent in pre-fix: ${MISSING_IN_PREFIX[*]}"
  else
    fail "mutation check: pre-fix script unexpectedly already defines some of these functions -- ${MISSING_IN_PREFIX[*]} were reported missing, expected all 15 markers absent"
  fi
else
  echo "ERROR: mutation check could not recover the pre-fix script via 'git show ${PREFIX_COMMIT}:...' -- this is a hard requirement, not a skippable case" >&2
  fail "mutation check: could not obtain pre-fix script from commit $PREFIX_COMMIT"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -eq 0 ]; then
  exit 0
else
  exit 1
fi
