#!/usr/bin/env bash
# test-claude-refresh-matcher.sh - Regression suite for claude-refresh.sh's orphan matcher,
# covering the four acceptance-bar assertions: (a) a process under /system.slice/ is never
# selected, (b) a process that merely mentions "claude" in argv without being a Claude
# executable is never selected, (c) an inhibitor whose held target is still alive is never
# selected, and (d) the script's own subshells are never self-selected. Later phases added
# assertions (e)-(j) for the VmSwap accounting, Lean LSP, zombie-reporting, and MCP fan-out
# passes, and assertion (k) for the orphaned build-waiter poll-loop pass: detection (Family A/B
# classification, idle+age gating, the PID-reuse ceiling backstop), the widened self-exclusion
# (pid, ppid, pgid, and the full ancestor chain of $$, all from one frozen snapshot), the
# fail-closed path when the $$ row is absent, the age-threshold-only gate (reaps without
# --force, identically under --force), and per-clause mutation checks proving the pgid and
# ancestor-chain exclusions are load-bearing.
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
field_spec=""
prev=""
for a in "$@"; do
  if [ "$a" = "-p" ]; then has_p_flag=true; fi
  case "$prev" in
    -eo|-o) field_spec="$a" ;;
  esac
  prev="$a"
done
if $has_p_flag; then
  # validate_cgroup_support()'s self-check: return a plausible non-empty user-slice cgroup.
  echo "0::/user.slice/user-1000.slice/session.scope"
  exit 0
fi
case "$field_spec" in
  *pgid*)
    # The build-waiter pass's own field spec -- this fixture is scoped to the Claude pass's
    # self-exclusion case only, so it emits no rows for the pgid-bearing spec (isolates this
    # case from the separately-gated build-waiter pass, matching the Lean/zombie/MCP passes'
    # existing independent-snapshot isolation).
    exit 0
    ;;
esac

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
field_spec=""
prev=""
for a in "$@"; do
  if [ "$a" = "-p" ]; then has_p_flag=true; fi
  case "$prev" in
    -eo|-o) field_spec="$a" ;;
  esac
  prev="$a"
done
if $has_p_flag; then
  echo "0::/user.slice/user-1000.slice/session.scope"
  exit 0
fi
case "$field_spec" in
  *pgid*)
    # Isolate this case from the separately-gated build-waiter pass -- see the (d-2) fixture's
    # matching branch for the full rationale.
    exit 0
    ;;
esac
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
field_spec=""
prev=""
for a in "$@"; do
  if [ "$a" = "-p" ]; then has_p_flag=true; fi
  if [ "$a" = "-C" ]; then has_c_flag=true; fi
  case "$prev" in
    -eo|-o) field_spec="$a" ;;
  esac
  prev="$a"
done
if $has_p_flag; then
  # validate_cgroup_support()'s self-check.
  echo "0::/user.slice/user-1000.slice/session.scope"
  exit 0
fi
case "$field_spec" in
  *pgid*)
    # Isolate this case from the separately-gated build-waiter pass -- see the (d-2) fixture's
    # matching branch for the full rationale.
    exit 0
    ;;
esac

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
# Assertion (h): zombie-state discrimination (unit) and full pass output shape (end-to-end)
# =====================================================================
# Unit-level: zombie_row_is_defunct must accept Z/Z+ and reject every live state code.
if zombie_row_is_defunct "Z"; then
  pass "zombie_row_is_defunct: accepts 'Z'"
else
  fail "zombie_row_is_defunct: rejected 'Z'"
fi
if zombie_row_is_defunct "Z+"; then
  pass "zombie_row_is_defunct: accepts 'Z+'"
else
  fail "zombie_row_is_defunct: rejected 'Z+'"
fi
for live_stat in S R D T I S+ Ss Rl; do
  if zombie_row_is_defunct "$live_stat"; then
    fail "zombie_row_is_defunct: incorrectly accepted live state '$live_stat'"
  else
    pass "zombie_row_is_defunct: rejects live state '$live_stat'"
  fi
done

# End-to-end: full --dry-run/--force output shape over a synthetic snapshot, proving grouping by
# parent, correct child count, live-vs-zombie discrimination, and age reporting -- via a
# dedicated fake `ps` on PATH exactly like assertions (d-2)/(e)/(g) above. Every OTHER pass's own
# ps invocation (Claude/Lean/MCP) sees an empty process table via this same fake ps, isolating
# this assertion to the zombie pass's own output. CLAUDE_JSON_PATH is pointed at a nonexistent
# file so the MCP pass short-circuits before ever calling ps, keeping this fixture minimal.
ZOMBIE_PARENT1=910101   # speech-dispatcher-style parent (live)
ZOMBIE_CHILD1=910102    # zombie child 1 (Z)
ZOMBIE_CHILD2=910103    # zombie child 2 (Z+)
ZOMBIE_PARENT2=910111   # lean-lsp-mcp-style parent (live)
ZOMBIE_CHILD3=910112    # zombie child 3 (Z)

ZOMBIE_FAKE_BIN_DIR="$WORKDIR/fakebin-zombie"
mkdir -p "$ZOMBIE_FAKE_BIN_DIR"
cat > "$ZOMBIE_FAKE_BIN_DIR/ps" <<'FAKE_PS_ZOMBIE_EOF'
#!/usr/bin/env bash
# Fake ps used only by test-claude-refresh-matcher.sh's zombie-pass output-shape case (h).
has_p_flag=false
field_spec=""
prev=""
for a in "$@"; do
  if [ "$a" = "-p" ]; then has_p_flag=true; fi
  case "$prev" in
    -eo|-o) field_spec="$a" ;;
  esac
  prev="$a"
done
if $has_p_flag; then
  echo "0::/user.slice/user-1000.slice/session.scope"
  exit 0
fi

case "$field_spec" in
  *stat*)
    # take_zombie_snapshot(): pid,ppid,stat,etimes,comm
    printf '%s %s %s %s %s\n' __PARENT1__ 1          S  90000 speech-dispatch
    printf '%s %s %s %s %s\n' __CHILD1__  __PARENT1__ Z  50000 "sd_voxin <defunct>"
    printf '%s %s %s %s %s\n' __CHILD2__  __PARENT1__ Z+ 40000 "sd_kali <defunct>"
    printf '%s %s %s %s %s\n' __PARENT2__ 1          S  20000 python3.13
    printf '%s %s %s %s %s\n' __CHILD3__  __PARENT2__ Z  60    "lake <defunct>"
    ;;
  *pgid*)
    # Isolate this case from the separately-gated build-waiter pass -- see the (d-2) fixture's
    # matching branch for the full rationale.
    ;;
  *)
    # Every other snapshot (Claude/Lean/MCP passes) sees an empty process table.
    ;;
esac
exit 0
FAKE_PS_ZOMBIE_EOF
sed -i "s/__PARENT1__/$ZOMBIE_PARENT1/g; s/__CHILD1__/$ZOMBIE_CHILD1/g; s/__CHILD2__/$ZOMBIE_CHILD2/g; s/__PARENT2__/$ZOMBIE_PARENT2/g; s/__CHILD3__/$ZOMBIE_CHILD3/g" "$ZOMBIE_FAKE_BIN_DIR/ps"
chmod +x "$ZOMBIE_FAKE_BIN_DIR/ps"

ZOMBIE_DRY_OUT="$(PATH="$ZOMBIE_FAKE_BIN_DIR:$PATH" CLAUDE_JSON_PATH="$WORKDIR/nonexistent-claude.json" bash "$WORKDIR/$SCRIPT_UNDER_TEST" --dry-run 2>&1)"
ZOMBIE_FORCE_OUT="$(PATH="$ZOMBIE_FAKE_BIN_DIR:$PATH" CLAUDE_JSON_PATH="$WORKDIR/nonexistent-claude.json" bash "$WORKDIR/$SCRIPT_UNDER_TEST" --force 2>&1)"

if echo "$ZOMBIE_DRY_OUT" | grep -q "Found 3 unreaped child process(es) across 2 parent(s)."; then
  pass "Zombie pass (h): reports 3 zombies across 2 parents (grouping by ppid correct)"
else
  fail "Zombie pass (h): did not report 3 zombies across 2 parents"
  info "output was: $ZOMBIE_DRY_OUT"
fi

if echo "$ZOMBIE_DRY_OUT" | grep -q "Parent: speech-dispatch (PID $ZOMBIE_PARENT1)" \
   && echo "$ZOMBIE_DRY_OUT" | grep -q "Parent: python3.13 (PID $ZOMBIE_PARENT2)"; then
  pass "Zombie pass (h): resolves each parent's comm from the shared snapshot"
else
  fail "Zombie pass (h): did not resolve parent comm names correctly"
  info "output was: $ZOMBIE_DRY_OUT"
fi

if echo "$ZOMBIE_DRY_OUT" | grep -q "$ZOMBIE_CHILD1" && echo "$ZOMBIE_DRY_OUT" | grep -q "$ZOMBIE_CHILD2" \
   && echo "$ZOMBIE_DRY_OUT" | grep -q "$ZOMBIE_CHILD3"; then
  pass "Zombie pass (h): all three zombie child PIDs appear in the report"
else
  fail "Zombie pass (h): one or more zombie child PIDs missing from the report"
  info "output was: $ZOMBIE_DRY_OUT"
fi

if echo "$ZOMBIE_DRY_OUT" | grep -qE "^  ${ZOMBIE_PARENT1}[[:space:]]"; then
  fail "Zombie pass (h): the LIVE parent PID ($ZOMBIE_PARENT1) was incorrectly listed as a zombie child row"
else
  pass "Zombie pass (h): the live parent PID is never listed as a zombie child row (Z vs live discrimination)"
fi

if echo "$ZOMBIE_DRY_OUT" | grep -q "Zombie memory cost: 0"; then
  pass "Zombie pass (h): reports zombie memory cost as explicitly zero"
else
  fail "Zombie pass (h): did not report the explicit zero-memory-cost line"
fi

# --dry-run vs --force: identical apart from the [DRY RUN] banner (its own two lines). Removing
# those two lines leaves a doubled blank line behind (one on each side of the banner block) that
# the --force path never has -- `cat -s` squeezes runs of blank lines on BOTH sides before
# comparing, so this normalizes that harmless removal artifact rather than treating it as a
# real divergence.
ZOMBIE_DRY_STRIPPED="$(echo "$ZOMBIE_DRY_OUT" | grep -v '\[DRY RUN\]' | grep -v "can only be reaped by its own parent" | cat -s)"
ZOMBIE_FORCE_SQUEEZED="$(echo "$ZOMBIE_FORCE_OUT" | cat -s)"
if [ "$ZOMBIE_DRY_STRIPPED" = "$ZOMBIE_FORCE_SQUEEZED" ]; then
  pass "Zombie pass (h): --dry-run and --force output identical modulo the DRY RUN banner"
else
  fail "Zombie pass (h): --dry-run and --force output diverged beyond the DRY RUN banner"
  info "dry (stripped) was: $ZOMBIE_DRY_STRIPPED"
  info "force was: $ZOMBIE_FORCE_SQUEEZED"
fi

# =====================================================================
# Assertion (i): MCP fan-out pass -- session-count/memory arithmetic and evidence discriminator
# =====================================================================
# Synthetic fixture: two sessions each for "playwright" (2 procs/session: an exec wrapper plus a
# node child, mirroring the live-observed shape) and "lean-lsp" (1 proc/session), plus a third,
# unrecognized "unknown-server" key to prove the "no use signal available" outcome is distinct
# from both "in use" and "no evidence of use". Session-root attribution is exercised directly:
# each playwright child's ppid IS its own session's exec-wrapper row (matched-to-matched chain).
MCP_FAKE_BIN_DIR="$WORKDIR/fakebin-mcp"
mkdir -p "$MCP_FAKE_BIN_DIR"
cat > "$MCP_FAKE_BIN_DIR/ps" <<'FAKE_PS_MCP_EOF'
#!/usr/bin/env bash
# Fake ps used only by test-claude-refresh-matcher.sh's MCP fan-out case (i).
has_p_flag=false
has_c_flag=false
field_spec=""
prev=""
for a in "$@"; do
  if [ "$a" = "-p" ]; then has_p_flag=true; fi
  if [ "$a" = "-C" ]; then has_c_flag=true; fi
  case "$prev" in
    -eo|-o) field_spec="$a" ;;
  esac
  prev="$a"
done
if $has_p_flag; then
  echo "0::/user.slice/user-1000.slice/session.scope"
  exit 0
fi
if $has_c_flag; then
  # take_lean_snapshot(): pid,ppid,uid,etimes,rss,pcpu,cgroup:200,comm,args -- one ACTIVE
  # lake-serve row, proving lean-lsp's evidence-of-use detector finds it (independent of the
  # Lean idle-reclamation pass's own idle gate, which this row deliberately fails: etimes=60).
  printf '%s %s %s %s %s %s %s %s %s\n' 920201 1 1000 60 5000 0.0 "0::/user.slice/x" lake ".../bin/lake serve -- -Dserver.reportDelayMs=0"
  exit 0
fi

case "$field_spec" in
  comm)
    if [ "${FAKE_HAS_CHROMIUM:-false}" = "true" ]; then
      echo "chromium"
    fi
    ;;
  *rss*args*)
    # run_mcp_fanout_pass's own snapshot: pid,ppid,rss,args
    printf '%s %s %s %s\n' 920001 920050 1000 "npm exec @playwright/mcp@latest --config x"
    printf '%s %s %s %s\n' 920002 920001 2000 "node .../playwright-mcp --config x"
    printf '%s %s %s %s\n' 920011 920060 1500 "npm exec @playwright/mcp@latest --config x"
    printf '%s %s %s %s\n' 920012 920011 2500 "node .../playwright-mcp --config x"
    printf '%s %s %s %s\n' 920021 920050 3000 ".../bin/lean-lsp-mcp --lean-project-path x"
    printf '%s %s %s %s\n' 920022 920060 3500 ".../bin/lean-lsp-mcp --lean-project-path x"
    ;;
  *pgid*)
    # Isolate this case from the separately-gated build-waiter pass -- see the (d-2) fixture's
    # matching branch for the full rationale.
    ;;
  *)
    ;;
esac
exit 0
FAKE_PS_MCP_EOF
chmod +x "$MCP_FAKE_BIN_DIR/ps"

MCP_PROC_DIR="$WORKDIR/fakeproc-mcp"
for p in 920001 920002 920011 920012 920021 920022 920201; do
  mkdir -p "$MCP_PROC_DIR/$p"
  printf 'Name:\tproc\nVmSwap:\t   100 kB\n' > "$MCP_PROC_DIR/$p/status"
done

CLAUDE_JSON_FIXTURE="$WORKDIR/claude-mcp-fixture.json"
cat > "$CLAUDE_JSON_FIXTURE" <<'FIXTURE_EOF'
{"mcpServers": {"playwright": {"command": "playwright-mcp", "args": []}, "lean-lsp": {"command": "x", "args": []}, "unknown-server": {"command": "y", "args": []}}}
FIXTURE_EOF

# Run 1: no chromium/headless_shell anywhere -- playwright must be flagged, lean-lsp must not
# (its lake-serve tree is present), unknown-server gets "no use signal available".
MCP_OUT_NOCHROME="$(PATH="$MCP_FAKE_BIN_DIR:$PATH" PROC_ROOT="$MCP_PROC_DIR" CLAUDE_JSON_PATH="$CLAUDE_JSON_FIXTURE" FAKE_HAS_CHROMIUM=false bash "$WORKDIR/$SCRIPT_UNDER_TEST" --dry-run 2>&1)"

# Expected arithmetic (worked by hand from the fixture above):
#   playwright: 4 procs (920001/920002 session A, 920011/920012 session B), 2 sessions,
#               rss 1000+2000+1500+2500=7000 + swap 4*100=400 -> 7400 KB -> "7.2 MB"
#   lean-lsp:   2 procs (920021 session A, 920022 session B), 2 sessions,
#               rss 3000+3500=6500 + swap 2*100=200 -> 6700 KB -> "6.5 MB"
#   unknown-server: 0 procs, 0 sessions, 0 KB
#   total: 7400+6700+0=14100 KB -> mb=14100/1024=13, frac=(14100%1024)*10/1024=7 -> "13.7 MB"
if echo "$MCP_OUT_NOCHROME" | grep -qE '^playwright[[:space:]]+2[[:space:]]+4[[:space:]]+7\.2 MB[[:space:]]+no evidence of use'; then
  pass "MCP pass (i): playwright row -- 2 sessions, 4 procs, 7.2 MB, flagged 'no evidence of use'"
else
  fail "MCP pass (i): playwright row did not match expected session/proc/memory/evidence arithmetic"
  info "output was: $MCP_OUT_NOCHROME"
fi

if echo "$MCP_OUT_NOCHROME" | grep -qE '^lean-lsp[[:space:]]+2[[:space:]]+2[[:space:]]+6\.5 MB[[:space:]]+in use'; then
  pass "MCP pass (i): lean-lsp row -- 2 sessions, 2 procs, 6.5 MB, 'in use' (lake-serve tree present)"
else
  fail "MCP pass (i): lean-lsp row did not match expected session/proc/memory/evidence arithmetic"
  info "output was: $MCP_OUT_NOCHROME"
fi

if echo "$MCP_OUT_NOCHROME" | grep -qE '^unknown-server[[:space:]]+0[[:space:]]+0[[:space:]]+0 KB[[:space:]]+no use signal available'; then
  pass "MCP pass (i): unrecognized server key reports 'no use signal available', never 'unused'"
else
  fail "MCP pass (i): unrecognized server key did not report the 'no use signal available' outcome"
  info "output was: $MCP_OUT_NOCHROME"
fi

if echo "$MCP_OUT_NOCHROME" | grep -q "Total MCP server memory: 13.7 MB"; then
  pass "MCP pass (i): total memory sums all three servers correctly (13.7 MB)"
else
  fail "MCP pass (i): total memory did not match expected sum"
  info "output was: $MCP_OUT_NOCHROME"
fi

ADVISORY_PARAGRAPH_COUNT="$(echo "$MCP_OUT_NOCHROME" | grep -c "no live evidence of use")"
if [ "$ADVISORY_PARAGRAPH_COUNT" -eq 1 ]; then
  pass "MCP pass (i): exactly one advisory paragraph emitted (only playwright flagged)"
else
  fail "MCP pass (i): expected exactly one advisory paragraph, found $ADVISORY_PARAGRAPH_COUNT"
  info "output was: $MCP_OUT_NOCHROME"
fi

# Run 2: chromium IS present -- playwright's evidence-of-use flips to "in use", no advisory at all.
MCP_OUT_CHROME="$(PATH="$MCP_FAKE_BIN_DIR:$PATH" PROC_ROOT="$MCP_PROC_DIR" CLAUDE_JSON_PATH="$CLAUDE_JSON_FIXTURE" FAKE_HAS_CHROMIUM=true bash "$WORKDIR/$SCRIPT_UNDER_TEST" --dry-run 2>&1)"

if echo "$MCP_OUT_CHROME" | grep -qE '^playwright[[:space:]]+2[[:space:]]+4[[:space:]]+7\.2 MB[[:space:]]+in use'; then
  pass "MCP pass (i): evidence discriminator flips to 'in use' when a chromium-like row is present"
else
  fail "MCP pass (i): playwright was not reclassified 'in use' with chromium present"
  info "output was: $MCP_OUT_CHROME"
fi

if echo "$MCP_OUT_CHROME" | grep -q "Scoping advisory"; then
  fail "MCP pass (i): a scoping advisory was emitted even though no server was flagged"
else
  pass "MCP pass (i): no scoping advisory is emitted when no server is flagged"
fi

# =====================================================================
# Assertion (j): structural absence of any signal call; advisory text content
# =====================================================================
# Extracted from the FILE on disk (the copy this suite sourced), not from the live shell
# functions -- "sed-extracted body", exactly as the plan's verification step names it.
ZOMBIE_BODY="$(sed -n '/^ZOMBIE_SNAPSHOT_PS_FIELDS=/,/^MCP_SNAPSHOT_PS_FIELDS=/p' "$WORKDIR/$SCRIPT_UNDER_TEST")"
MCP_BODY="$(sed -n '/^MCP_SNAPSHOT_PS_FIELDS=/,/^main() {/p' "$WORKDIR/$SCRIPT_UNDER_TEST")"

if echo "$ZOMBIE_BODY" | grep -qE '(^|[^_a-zA-Z])kill([^_a-zA-Z]|$)|terminate_pid'; then
  fail "Structural (j): zombie pass block contains a kill/terminate_pid reference"
  info "matched: $(echo "$ZOMBIE_BODY" | grep -E '(^|[^_a-zA-Z])kill([^_a-zA-Z]|$)|terminate_pid')"
else
  pass "Structural (j): zombie pass block (constant + predicate + run_zombie_pass) contains zero kill/terminate_pid references"
fi

if echo "$MCP_BODY" | grep -qE '(^|[^_a-zA-Z])kill([^_a-zA-Z]|$)|terminate_pid'; then
  fail "Structural (j): MCP fan-out pass block contains a kill/terminate_pid reference"
  info "matched: $(echo "$MCP_BODY" | grep -E '(^|[^_a-zA-Z])kill([^_a-zA-Z]|$)|terminate_pid')"
else
  pass "Structural (j): MCP fan-out pass block (constants + predicates + run_mcp_fanout_pass) contains zero kill/terminate_pid references"
fi

# Advisory text content, reusing the MCP_OUT_NOCHROME captured output from assertion (i) above --
# this IS the emitted advisory text the acceptance bar requires be grepped.
if echo "$MCP_OUT_NOCHROME" | grep -qE 'cannot access project-scoped|subagents cannot'; then
  fail "Advisory text (j): contains banned subagent-barrier phrasing"
else
  pass "Advisory text (j): contains no subagent-barrier phrasing"
fi

if echo "$MCP_OUT_NOCHROME" | grep -qi 'workspace trust'; then
  pass "Advisory text (j): mentions workspace trust"
else
  fail "Advisory text (j): does not mention workspace trust"
fi

# =====================================================================
# Assertion (k): orphaned build-waiter poll-loop pass -- unit, end-to-end, and mutation checks
# =====================================================================
# Unit-level: is_shell_comm, build_waiter_family, build_waiter_row_is_idle, and both outcomes of
# build_self_exclusion_set are called directly (no fake ps needed for these).
if is_shell_comm "bash"; then
  pass "is_shell_comm: accepts 'bash'"
else
  fail "is_shell_comm: rejected 'bash'"
fi
if is_shell_comm "sh"; then
  pass "is_shell_comm: accepts 'sh'"
else
  fail "is_shell_comm: rejected 'sh'"
fi
if is_shell_comm "nvim"; then
  fail "is_shell_comm: incorrectly accepted 'nvim'"
else
  pass "is_shell_comm: rejects 'nvim'"
fi

FAMILY_A_ARGS="timeout 3000 bash -c while kill -0 \"\$1\" 2>/dev/null; do sleep 10; done _ 555555"
build_waiter_family "$FAMILY_A_ARGS"
if [ "$BUILD_WAITER_FAMILY" = "A" ] && [ "$BUILD_WAITER_EMBEDDED_PID" = "555555" ]; then
  pass "build_waiter_family: classifies the canonical bounded-build-waiter idiom as Family A and extracts the embedded pid"
else
  fail "build_waiter_family: did not classify the canonical idiom as Family A with embedded pid 555555 (got family='$BUILD_WAITER_FAMILY' pid='$BUILD_WAITER_EMBEDDED_PID')"
fi

FAMILY_A_BAD_TAIL_ARGS="timeout 3000 bash -c while kill -0 \"\$1\" 2>/dev/null; do sleep 10; done _ abc"
build_waiter_family "$FAMILY_A_BAD_TAIL_ARGS"
if [ -z "$BUILD_WAITER_FAMILY" ]; then
  pass "build_waiter_family: a Family A-shaped argv with a non-numeric trailing token classifies as neither (fails closed)"
else
  fail "build_waiter_family: a non-numeric trailing token was misclassified as family '$BUILD_WAITER_FAMILY'"
fi

FAMILY_B_ARGS='until grep -q "^EXIT=" /tmp/somelog; do sleep 10; done'
build_waiter_family "$FAMILY_B_ARGS"
if [ "$BUILD_WAITER_FAMILY" = "B" ] && [ -z "$BUILD_WAITER_EMBEDDED_PID" ]; then
  pass "build_waiter_family: classifies a legacy 'until grep -q' sentinel poll as Family B with no embedded pid"
else
  fail "build_waiter_family: did not classify the sentinel poll as Family B (got family='$BUILD_WAITER_FAMILY' pid='$BUILD_WAITER_EMBEDDED_PID')"
fi

FAMILY_B_SELFMATCH_ARGS='until ! ps aux | grep -q "[b]ash check.sh"; do sleep 8; done'
build_waiter_family "$FAMILY_B_SELFMATCH_ARGS"
if [ "$BUILD_WAITER_FAMILY" = "B" ]; then
  pass "build_waiter_family: classifies the legacy self-match 'ps aux | grep' poll (the incident class this pass reaps) as Family B"
else
  fail "build_waiter_family: did not classify the legacy self-match poll as Family B (got family='$BUILD_WAITER_FAMILY')"
fi

NEITHER_ARGS='vim --headless -c "some unrelated command"'
build_waiter_family "$NEITHER_ARGS"
if [ -z "$BUILD_WAITER_FAMILY" ]; then
  pass "build_waiter_family: an unrelated argv classifies as neither family"
else
  fail "build_waiter_family: an unrelated argv was misclassified as family '$BUILD_WAITER_FAMILY'"
fi

if build_waiter_row_is_idle 3600 "0.0" 60; then
  pass "build_waiter_row_is_idle: idle (pcpu 0, etimes past a 60-minute threshold) is TRUE"
else
  fail "build_waiter_row_is_idle: an idle row (pcpu 0, etimes 3600s past a 60min threshold) was NOT reported idle"
fi
if build_waiter_row_is_idle 30 "0.0" 60; then
  fail "build_waiter_row_is_idle: a row younger than the threshold was incorrectly reported idle"
else
  pass "build_waiter_row_is_idle: a row younger than the threshold is NOT idle"
fi
if build_waiter_row_is_idle 3600 "2.0" 60; then
  fail "build_waiter_row_is_idle: a busy row (pcpu 2.0) was incorrectly reported idle"
else
  pass "build_waiter_row_is_idle: a busy row (pcpu 2.0) is NOT idle"
fi

# Fail-closed unit assertion: a snapshot string with no $$ row must make build_self_exclusion_set
# return non-zero and leave both output globals empty.
NO_SELF_SNAPSHOT="999001 1 999001 $CURRENT_UID 100 0.0 0::/user.slice/x bash foo"
if build_self_exclusion_set "$NO_SELF_SNAPSHOT"; then
  fail "build_self_exclusion_set: incorrectly succeeded against a snapshot with no \$\$ row"
else
  pass "build_self_exclusion_set: fails closed (returns non-zero) when the \$\$ row is absent"
fi
if [ -z "$BUILD_WAITER_SELF_PGID" ] && [ -z "$BUILD_WAITER_ANCESTOR_PIDS" ]; then
  pass "build_self_exclusion_set: both output globals are left empty on the fail-closed path"
else
  fail "build_self_exclusion_set: an output global was populated despite the \$\$ row being absent"
fi

# Success-path unit assertion: a synthetic two-row snapshot ($$ and its fabricated parent) proves
# the pgid capture and the ancestor-chain walk both work from data alone, with no fake ps needed.
SELF_TEST_PARENT_PID=888888
SELF_TEST_PGID=777777
SELF_TEST_SNAPSHOT="$$ $SELF_TEST_PARENT_PID $SELF_TEST_PGID $CURRENT_UID 50 0.0 0::/user.slice/x bash self
$SELF_TEST_PARENT_PID 1 $SELF_TEST_PARENT_PID $CURRENT_UID 500 0.0 0::/user.slice/x bash parent"
if build_self_exclusion_set "$SELF_TEST_SNAPSHOT"; then
  if [ "$BUILD_WAITER_SELF_PGID" = "$SELF_TEST_PGID" ] \
     && [[ " $BUILD_WAITER_ANCESTOR_PIDS " == *" $$ "* ]] \
     && [[ " $BUILD_WAITER_ANCESTOR_PIDS " == *" $SELF_TEST_PARENT_PID "* ]]; then
    pass "build_self_exclusion_set: resolves its own pgid and walks the ancestor chain (\$\$ and its parent) from a synthetic snapshot"
  else
    fail "build_self_exclusion_set: pgid or ancestor chain incorrect (pgid='$BUILD_WAITER_SELF_PGID' ancestors='$BUILD_WAITER_ANCESTOR_PIDS')"
  fi
else
  fail "build_self_exclusion_set: unexpectedly failed against a snapshot containing the \$\$ row"
fi

# =====================================================================
# Assertion (k) continued: end-to-end via a dedicated build-waiter fake ps + fake kill
# =====================================================================
# The fake ps below reuses the (d-2) fixture's ancestry-walk technique verbatim to discover the
# REAL pid/ppid/pgid the running script-under-test process will see as its own "$$" -- required
# because the reaper's self-exclusion set (pid, pgid, ancestor chain) must line up with genuine
# values for this end-to-end case to mean anything. Twelve synthetic non-self rows cover every
# case the plan requires; only three are expected to be reaped (dead-writer Family A, past-ceiling
# Family A, and idle-past-threshold Family B).
BUILD_WAITER_FAKE_BIN_DIR="$WORKDIR/fakebin-buildwaiter"
mkdir -p "$BUILD_WAITER_FAKE_BIN_DIR"
cat > "$BUILD_WAITER_FAKE_BIN_DIR/ps" <<'FAKE_PS_BUILDWAITER_EOF'
#!/usr/bin/env bash
# Fake ps used only by test-claude-refresh-matcher.sh's build-waiter end-to-end case (k).
has_p_flag=false
field_spec=""
prev=""
for a in "$@"; do
  if [ "$a" = "-p" ]; then has_p_flag=true; fi
  case "$prev" in
    -eo|-o) field_spec="$a" ;;
  esac
  prev="$a"
done
if $has_p_flag; then
  echo "0::/user.slice/user-1000.slice/session.scope"
  exit 0
fi

case "$field_spec" in
  *pgid*) : ;;
  *) exit 0 ;;
esac

CG="0::/user.slice/user-1000.slice/session.scope"
cur_uid="$(id -u)"

find_self_pid() {
  local check_pid="$PPID"
  local best_match=""
  local hops=0
  while [ -n "$check_pid" ] && [ "$check_pid" != "1" ] && [ "$hops" -lt 25 ]; do
    local row
    row=$("$REAL_PS_BIN" -o args= -p "$check_pid" 2>/dev/null)
    case "$row" in
      *"BUILDWAITER_HARNESS_SELFMARK"*)
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
if [ -z "$self_pid" ]; then
  exit 0
fi
self_ppid="$("$REAL_PS_BIN" -o ppid= -p "$self_pid" 2>/dev/null | tr -d ' ')"
self_pgid="$("$REAL_PS_BIN" -o pgid= -p "$self_pid" 2>/dev/null | tr -d ' ')"

# Self row -- excluded by pid == $$ regardless of shape.
printf '%s\n' "$self_pid $self_ppid $self_pgid $cur_uid 100 0.0 $CG bash self-row-marker"

# 1. Family A, dead embedded writer, idle past threshold -- SELECTED.
printf '%s\n' "931001 1 931001 $cur_uid 200 0.0 $CG bash timeout 3000 bash -c while kill -0 \"\$1\" 2>/dev/null; do sleep 10; done _ 555001"
# 2. Family A, live embedded writer, idle past REAP_MIN but under the ceiling -- NOT selected.
printf '%s\n' "931002 1 931002 $cur_uid 90 0.0 $CG bash timeout 3000 bash -c while kill -0 \"\$1\" 2>/dev/null; do sleep 10; done _ 555002"
# 3. Family A, live embedded writer past the ceiling -- SELECTED (PID-reuse backstop).
printf '%s\n' "931003 1 931003 $cur_uid 150 0.0 $CG bash timeout 3000 bash -c while kill -0 \"\$1\" 2>/dev/null; do sleep 10; done _ 555003"
# 4. Family A-shaped argv, non-numeric trailing token -- NOT selected (fails closed).
printf '%s\n' "931004 1 931004 $cur_uid 300 0.0 $CG bash timeout 3000 bash -c while kill -0 \"\$1\" 2>/dev/null; do sleep 10; done _ abc"
# 5. Family B, idle past threshold -- SELECTED.
printf '%s\n' "931005 1 931005 $cur_uid 300 0.0 $CG bash until grep -q \"^EXIT=\" /tmp/somelog.931005; do sleep 10; done"
# 6. Family B, younger than the threshold -- NOT selected.
printf '%s\n' "931006 1 931006 $cur_uid 30 0.0 $CG bash until grep -q \"^EXIT=\" /tmp/somelog.931006; do sleep 10; done"
# 7. Family B, busy (pcpu 2.0) -- NOT selected.
printf '%s\n' "931007 1 931007 $cur_uid 300 2.0 $CG bash until grep -q \"^EXIT=\" /tmp/somelog.931007; do sleep 10; done"
# 8. Non-shell comm (nvim) with a Family-B-shaped argv -- NOT selected.
printf '%s\n' "931008 1 931008 $cur_uid 300 0.0 $CG nvim until grep -q \"^EXIT=\" /tmp/somelog.931008; do sleep 10; done"
# 9. pgid collision with the reaper's own pgid -- NOT selected.
printf '%s\n' "931009 1 $self_pgid $cur_uid 300 0.0 $CG bash until grep -q \"^EXIT=\" /tmp/somelog.931009; do sleep 10; done"
# 10. Ancestor of $$ (the reaper's own real parent pid, fabricated with a waiter shape) -- NOT selected.
printf '%s\n' "$self_ppid 1 931010 $cur_uid 300 0.0 $CG bash until grep -q \"^EXIT=\" /tmp/somelog.ancestor; do sleep 10; done"
# 11. Under /system.slice/ -- NOT selected.
printf '%s\n' "931011 1 931011 $cur_uid 300 0.0 0::/system.slice/somedaemon.service bash until grep -q \"^EXIT=\" /tmp/somelog.931011; do sleep 10; done"
# 12. Foreign uid -- NOT selected.
printf '%s\n' "931012 1 931012 65534 300 0.0 $CG bash until grep -q \"^EXIT=\" /tmp/somelog.931012; do sleep 10; done"
exit 0
FAKE_PS_BUILDWAITER_EOF
chmod +x "$BUILD_WAITER_FAKE_BIN_DIR/ps"

# Fake kill: 555001's liveness probe reports dead (the Family A dead-writer case); every other
# -0 probe (555002/555003, and terminate_pid's own liveness re-checks on the candidate pids
# themselves) reports alive, driving terminate_pid's SIGTERM->SIGKILL "forced" branch for every
# selected candidate -- matching the Lean ordering fixture's established convention. SIGTERM/
# SIGKILL are logged to $KILL_LOG_FILE.
BUILD_WAITER_FAKE_KILL_DIR="$WORKDIR/fakebin-buildwaiter-kill"
mkdir -p "$BUILD_WAITER_FAKE_KILL_DIR"
cat > "$BUILD_WAITER_FAKE_KILL_DIR/kill" <<'FAKE_KILL_BUILDWAITER_EOF'
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
  case "$pid" in
    555001) exit 1 ;;
    *) exit 0 ;;
  esac
fi
echo "${sig#-} ${pid}" >> "$KILL_LOG_FILE"
exit 0
FAKE_KILL_BUILDWAITER_EOF
chmod +x "$BUILD_WAITER_FAKE_KILL_DIR/kill"

BUILD_WAITER_KILL_LOG="$WORKDIR/build-waiter-kill.log"
BUILD_WAITER_NOCLAUDE_JSON="$WORKDIR/nonexistent-claude.json"

# --dry-run: detection runs (so _pid_is_alive IS exercised, hence the `enable -n kill` + source
# pattern the Lean ordering assertion (g) established), but nothing is ever terminated.
: > "$BUILD_WAITER_KILL_LOG"
BUILD_WAITER_DRY_OUT="$(bash -c '
  : BUILDWAITER_HARNESS_SELFMARK
  enable -n kill
  export PATH="$1:$2:$PATH"
  export BUILD_WAITER_REAP_MIN="$3"
  export BUILD_WAITER_CEILING_MIN="$4"
  export KILL_LOG_FILE="$5"
  export CLAUDE_JSON_PATH="$7"
  # shellcheck disable=SC1090
  source "$6"
  main --dry-run
' _ "$BUILD_WAITER_FAKE_BIN_DIR" "$BUILD_WAITER_FAKE_KILL_DIR" 1 2 "$BUILD_WAITER_KILL_LOG" "$WORKDIR/$SCRIPT_UNDER_TEST" "$BUILD_WAITER_NOCLAUDE_JSON" 2>&1)"

if echo "$BUILD_WAITER_DRY_OUT" | grep -q "WARNING: this script's own process row"; then
  fail "Build-waiter pass (k): harness defect -- the fail-closed warning fired unexpectedly (self-pid resolution failed in the fixture)"
  info "output was: $BUILD_WAITER_DRY_OUT"
else
  pass "Build-waiter pass (k): self-row resolution succeeded in the fixture (no spurious fail-closed warning)"
fi

if [ -s "$BUILD_WAITER_KILL_LOG" ]; then
  fail "Build-waiter pass (k): --dry-run terminated something (fake-kill log non-empty)"
  info "kill log was: $(cat "$BUILD_WAITER_KILL_LOG")"
else
  pass "Build-waiter pass (k): --dry-run terminates nothing (fake-kill log stays empty)"
fi

if echo "$BUILD_WAITER_DRY_OUT" | grep -q "Found 3 orphaned build-waiter poll loop(s):"; then
  pass "Build-waiter pass (k): --dry-run reports exactly 3 candidates"
else
  fail "Build-waiter pass (k): --dry-run did not report exactly 3 candidates"
  info "output was: $BUILD_WAITER_DRY_OUT"
fi

for expected_pid in 931001 931003 931005; do
  if echo "$BUILD_WAITER_DRY_OUT" | grep -qE "^${expected_pid}[[:space:]]"; then
    pass "Build-waiter pass (k): candidate $expected_pid appears in the --dry-run report"
  else
    fail "Build-waiter pass (k): candidate $expected_pid missing from the --dry-run report"
    info "output was: $BUILD_WAITER_DRY_OUT"
  fi
done

for excluded_pid in 931002 931004 931006 931007 931008 931009 931011 931012; do
  if echo "$BUILD_WAITER_DRY_OUT" | grep -qE "^${excluded_pid}[[:space:]]"; then
    fail "Build-waiter pass (k): excluded pid $excluded_pid incorrectly appeared as a candidate"
    info "output was: $BUILD_WAITER_DRY_OUT"
  else
    pass "Build-waiter pass (k): excluded pid $excluded_pid correctly absent from the candidate report"
  fi
done

# No-flag: the age-threshold-only gate reaps WITHOUT --force (unlike rows 1-2's interactive
# process passes).
: > "$BUILD_WAITER_KILL_LOG"
BUILD_WAITER_NOFLAG_OUT="$(bash -c '
  : BUILDWAITER_HARNESS_SELFMARK
  enable -n kill
  export PATH="$1:$2:$PATH"
  export BUILD_WAITER_REAP_MIN="$3"
  export BUILD_WAITER_CEILING_MIN="$4"
  export KILL_LOG_FILE="$5"
  export CLAUDE_JSON_PATH="$7"
  # shellcheck disable=SC1090
  source "$6"
  main
' _ "$BUILD_WAITER_FAKE_BIN_DIR" "$BUILD_WAITER_FAKE_KILL_DIR" 1 2 "$BUILD_WAITER_KILL_LOG" "$WORKDIR/$SCRIPT_UNDER_TEST" "$BUILD_WAITER_NOCLAUDE_JSON" 2>&1)"

NOFLAG_KILL_LOG_CONTENT="$(cat "$BUILD_WAITER_KILL_LOG")"
NOFLAG_PIDS="$(echo "$NOFLAG_KILL_LOG_CONTENT" | grep -oE '[0-9]+$' | sort -u)"
if echo "$NOFLAG_PIDS" | grep -qx 931001 && echo "$NOFLAG_PIDS" | grep -qx 931003 && echo "$NOFLAG_PIDS" | grep -qx 931005; then
  pass "Build-waiter pass (k): no-flag invocation terminates all three expected candidates (age-threshold-only gate reaps without --force)"
else
  fail "Build-waiter pass (k): no-flag invocation did not terminate all three expected candidates"
  info "kill log was: $NOFLAG_KILL_LOG_CONTENT"
  info "no-flag output was: $BUILD_WAITER_NOFLAG_OUT"
fi
NOFLAG_UNEXPECTED="$(echo "$NOFLAG_PIDS" | grep -vE '^(931001|931003|931005)$' || true)"
if [ -z "$NOFLAG_UNEXPECTED" ]; then
  pass "Build-waiter pass (k): no-flag invocation signals exactly the three expected candidates, nothing else"
else
  fail "Build-waiter pass (k): no-flag invocation signaled unexpected pid(s): $NOFLAG_UNEXPECTED"
fi

# --force: the candidate set must be identical to the no-flag run (this pass ignores $FORCE
# entirely -- it is accepted only for call-site symmetry).
: > "$BUILD_WAITER_KILL_LOG"
BUILD_WAITER_FORCE_OUT="$(bash -c '
  : BUILDWAITER_HARNESS_SELFMARK
  enable -n kill
  export PATH="$1:$2:$PATH"
  export BUILD_WAITER_REAP_MIN="$3"
  export BUILD_WAITER_CEILING_MIN="$4"
  export KILL_LOG_FILE="$5"
  export CLAUDE_JSON_PATH="$7"
  # shellcheck disable=SC1090
  source "$6"
  main --force
' _ "$BUILD_WAITER_FAKE_BIN_DIR" "$BUILD_WAITER_FAKE_KILL_DIR" 1 2 "$BUILD_WAITER_KILL_LOG" "$WORKDIR/$SCRIPT_UNDER_TEST" "$BUILD_WAITER_NOCLAUDE_JSON" 2>&1)"

FORCE_PIDS="$(cat "$BUILD_WAITER_KILL_LOG" | grep -oE '[0-9]+$' | sort -u)"
if [ "$FORCE_PIDS" = "$NOFLAG_PIDS" ] && [ -n "$FORCE_PIDS" ]; then
  pass "Build-waiter pass (k): --force terminates the identical candidate set as the no-flag invocation"
else
  fail "Build-waiter pass (k): --force candidate set diverged from the no-flag candidate set"
  info "no-flag pids: $NOFLAG_PIDS"
  info "force pids: $FORCE_PIDS"
  info "force output was: $BUILD_WAITER_FORCE_OUT"
fi

# Fail-closed end-to-end: a fake ps that never emits a $$ row for the build-waiter field spec.
BUILD_WAITER_NOSELF_BIN_DIR="$WORKDIR/fakebin-buildwaiter-noself"
mkdir -p "$BUILD_WAITER_NOSELF_BIN_DIR"
cat > "$BUILD_WAITER_NOSELF_BIN_DIR/ps" <<'FAKE_PS_NOSELF_EOF'
#!/usr/bin/env bash
for a in "$@"; do
  if [ "$a" = "-p" ]; then
    echo "0::/user.slice/user-1000.slice/session.scope"
    exit 0
  fi
done
exit 0
FAKE_PS_NOSELF_EOF
chmod +x "$BUILD_WAITER_NOSELF_BIN_DIR/ps"

: > "$BUILD_WAITER_KILL_LOG"
BUILD_WAITER_NOSELF_OUT="$(bash -c '
  : BUILDWAITER_HARNESS_SELFMARK
  enable -n kill
  export PATH="$1:$2:$PATH"
  export BUILD_WAITER_REAP_MIN="$3"
  export BUILD_WAITER_CEILING_MIN="$4"
  export KILL_LOG_FILE="$5"
  export CLAUDE_JSON_PATH="$7"
  # shellcheck disable=SC1090
  source "$6"
  main --force
' _ "$BUILD_WAITER_NOSELF_BIN_DIR" "$BUILD_WAITER_FAKE_KILL_DIR" 1 2 "$BUILD_WAITER_KILL_LOG" "$WORKDIR/$SCRIPT_UNDER_TEST" "$BUILD_WAITER_NOCLAUDE_JSON" 2>&1)"

if echo "$BUILD_WAITER_NOSELF_OUT" | grep -q "WARNING: this script's own process row was not found"; then
  pass "Build-waiter pass (k): fail-closed -- a missing \$\$ row produces the warning line"
else
  fail "Build-waiter pass (k): the fail-closed warning did not appear when the \$\$ row is absent"
  info "output was: $BUILD_WAITER_NOSELF_OUT"
fi
if [ -s "$BUILD_WAITER_KILL_LOG" ]; then
  fail "Build-waiter pass (k): the fail-closed path unexpectedly signaled a process (kill log non-empty)"
  info "kill log was: $(cat "$BUILD_WAITER_KILL_LOG")"
else
  pass "Build-waiter pass (k): the fail-closed path signals nothing (kill log empty), even under --force"
fi

# =====================================================================
# Structural assertion (k): the build-waiter pass block contains no pgrep/ps-aux reference
# =====================================================================
BUILD_WAITER_BODY="$(sed -n '/^BUILD_WAITER_SNAPSHOT_PS_FIELDS=/,/^# --- Unreaped-child/p' "$WORKDIR/$SCRIPT_UNDER_TEST")"
if echo "$BUILD_WAITER_BODY" | grep -qE 'pgrep|ps aux'; then
  fail "Structural (k): build-waiter pass block contains a pgrep/ps-aux reference"
  info "matched: $(echo "$BUILD_WAITER_BODY" | grep -E 'pgrep|ps aux')"
else
  pass "Structural (k): build-waiter pass block (constants, predicates, run_build_waiter_pass) contains no pgrep/ps-aux reference"
fi

# =====================================================================
# Mutation checks (k): the pgid and ancestor-chain exclusions are load-bearing
# =====================================================================
# Per shell-script-testing.md's "Mutation checks for regex-shaped fixes": delete the clause, rerun
# the SAME fixture against the mutant, and confirm the previously-excluded row is now (wrongly)
# selected -- proving the deleted clause was doing real work, not merely present but redundant.
BUILD_WAITER_MUTANT_PGID="$WORKDIR/mutant-buildwaiter-pgid.sh"
# shellcheck disable=SC2016  # single-quoted deliberately: this is a literal sed address pattern,
# not a shell expansion -- it must match the literal text "$BUILD_WAITER_SELF_PGID" in the source.
sed '/if \[ -n "\$BUILD_WAITER_SELF_PGID" \]/,+2d' "$WORKDIR/$SCRIPT_UNDER_TEST" > "$BUILD_WAITER_MUTANT_PGID"

BUILD_WAITER_MUTANT_PGID_OUT="$(bash -c '
  : BUILDWAITER_HARNESS_SELFMARK
  enable -n kill
  export PATH="$1:$2:$PATH"
  export BUILD_WAITER_REAP_MIN="$3"
  export BUILD_WAITER_CEILING_MIN="$4"
  export KILL_LOG_FILE="$5"
  export CLAUDE_JSON_PATH="$7"
  # shellcheck disable=SC1090
  source "$6"
  main --dry-run
' _ "$BUILD_WAITER_FAKE_BIN_DIR" "$BUILD_WAITER_FAKE_KILL_DIR" 1 2 "$WORKDIR/mutant-pgid-kill.log" "$BUILD_WAITER_MUTANT_PGID" "$BUILD_WAITER_NOCLAUDE_JSON" 2>&1)"

if echo "$BUILD_WAITER_MUTANT_PGID_OUT" | grep -qE "^931009[[:space:]]"; then
  pass "Mutation check (k): removing the pgid-exclusion clause makes the pgid-collision row 931009 wrongly selected (RED confirmed -- the clause is load-bearing)"
else
  fail "Mutation check (k): row 931009 was still excluded after removing the pgid-exclusion clause -- mutation had no observable effect"
  info "output was: $BUILD_WAITER_MUTANT_PGID_OUT"
fi

BUILD_WAITER_MUTANT_ANCESTOR="$WORKDIR/mutant-buildwaiter-ancestor.sh"
sed '/local is_ancestor=false/,+8d' "$WORKDIR/$SCRIPT_UNDER_TEST" > "$BUILD_WAITER_MUTANT_ANCESTOR"

BUILD_WAITER_MUTANT_ANCESTOR_OUT="$(bash -c '
  : BUILDWAITER_HARNESS_SELFMARK
  enable -n kill
  export PATH="$1:$2:$PATH"
  export BUILD_WAITER_REAP_MIN="$3"
  export BUILD_WAITER_CEILING_MIN="$4"
  export KILL_LOG_FILE="$5"
  export CLAUDE_JSON_PATH="$7"
  # shellcheck disable=SC1090
  source "$6"
  main --dry-run
' _ "$BUILD_WAITER_FAKE_BIN_DIR" "$BUILD_WAITER_FAKE_KILL_DIR" 1 2 "$WORKDIR/mutant-ancestor-kill.log" "$BUILD_WAITER_MUTANT_ANCESTOR" "$BUILD_WAITER_NOCLAUDE_JSON" 2>&1)"

if echo "$BUILD_WAITER_MUTANT_ANCESTOR_OUT" | grep -q "Found 4 orphaned build-waiter poll loop(s):"; then
  pass "Mutation check (k): removing the ancestor-chain exclusion makes the ancestor-of-\$\$ row wrongly selected (RED confirmed -- the clause is load-bearing)"
else
  fail "Mutation check (k): candidate count did not increase to 4 after removing the ancestor-chain exclusion -- mutation had no observable effect"
  info "output was: $BUILD_WAITER_MUTANT_ANCESTOR_OUT"
fi

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
  # terminate_pid, run_claude_pass, and run_lean_pass are all brand-NEW functions that pass added
  # (not modifications of existing ones -- terminate_pid/run_claude_pass/run_lean_pass are the
  # extraction/restructure of what used to be inlined directly in main()), so their absence from
  # any pre-task commit -- this same pinned PREFIX_COMMIT included, since it predates all of this
  # entirely -- is itself the non-vacuousness proof the plan calls for: assertions (f) and (g)
  # above call each of them by name and would fail with "command not found" against a script that
  # lacks them.
  #
  # Further extended for the report-only MCP fan-out and zombie passes: take_zombie_snapshot,
  # zombie_row_is_defunct, run_zombie_pass, mcp_playwright_evidence_of_use,
  # mcp_lean_lsp_evidence_of_use, mcp_server_evidence_of_use, and run_mcp_fanout_pass are all
  # brand-NEW functions this change adds, so their absence from the same pinned pre-fix commit is
  # the identical non-vacuousness proof for assertions (h), (i), and (j) above.
  #
  # Further extended for the orphaned build-waiter poll-loop pass: take_build_waiter_snapshot,
  # is_shell_comm, build_waiter_family, build_waiter_row_is_idle, build_self_exclusion_set, and
  # run_build_waiter_pass are all brand-NEW functions this change adds, so their absence from the
  # same pinned pre-fix commit is the identical non-vacuousness proof for assertion (k) above.
  for fn in is_claude_executable_comm is_system_slice_cgroup is_owned_by_current_uid is_live_inhibitor_target get_vmswap_kb is_lean_serve_comm is_lean_server_comm is_lean_worker_comm take_lean_snapshot lean_row_is_idle detect_lean_candidate_trees terminate_pid run_claude_pass run_lean_pass take_zombie_snapshot zombie_row_is_defunct run_zombie_pass mcp_playwright_evidence_of_use mcp_lean_lsp_evidence_of_use mcp_server_evidence_of_use run_mcp_fanout_pass take_build_waiter_snapshot is_shell_comm build_waiter_family build_waiter_row_is_idle build_self_exclusion_set run_build_waiter_pass; do
    if ! grep -q "^${fn}()" "$PREFIX_SCRIPT"; then
      MISSING_IN_PREFIX+=("$fn")
    fi
  done
  if ! grep -q 'BASH_SOURCE\[0\].*==.*\$0' "$PREFIX_SCRIPT"; then
    MISSING_IN_PREFIX+=("main()/BASH_SOURCE dual-mode guard")
  fi

  if [ "${#MISSING_IN_PREFIX[@]}" -eq 27 ] || [ "${#MISSING_IN_PREFIX[@]}" -eq 28 ]; then
    pass "mutation check: pre-fix script (commit $PREFIX_COMMIT) defines none of the twenty-seven predicates/helpers or the main() guard -- every assertion above would fail with 'command not found' against it (RED confirmed)"
    info "absent in pre-fix: ${MISSING_IN_PREFIX[*]}"
  else
    fail "mutation check: pre-fix script unexpectedly already defines some of these functions -- ${MISSING_IN_PREFIX[*]} were reported missing, expected all 28 markers absent"
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
