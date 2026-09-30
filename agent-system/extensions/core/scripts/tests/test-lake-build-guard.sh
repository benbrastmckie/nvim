#!/usr/bin/env bash
# test-lake-build-guard.sh - Toolchain-free regression suite for lake-build-guard.sh.
#
# Covers 34 acceptance-mapped cases below (the original 13, 8 added for the truthful-success
# fixes: subcommand validation, scope-keyed sharing, the REPLAY marker, and the --help wait
# idiom, 1 for positive-direction memory-pressure detection, 2 for the killed-holder terminal-
# record guarantee, 5 for the `result` subcommand's verdict/orphan reporting, 3 for the
# --expect-pid/--expect-scope ownership assertions, and 2 for the STATUS line and its
# documentation), plus a non-vacuousness (mutation) section spanning mutations A-K. Running the
# suite reports 47 [PASS] lines: the 34 numbered cases (case 12 splits into 12a/12b and case 27
# into 27a/27b, so 36 case-level passes) plus the 11 mutation checks. The script under test is
# invoked as a REAL
# SUBPROCESS throughout (never sourced): its behavior depends on genuine flock() semantics,
# process substitution, and PATH-resolved external commands (`lake`, `flock`, optionally
# `systemd-run`), none of which are meaningfully testable by calling functions directly in-process
# the way test-claude-refresh-matcher.sh does for its pure predicates.
#
# Fixture model: every case builds its OWN fresh package root under the suite's mktemp -d
# workdir via build_fixture() (heredoc-authored fake `lake`, per the core convention -- no
# committed fixture tree, no fixture-generator script). A fresh root per case is required, not
# merely tidy: lake-build-guard.sh's result-sharing cache means a SECOND build against an
# unchanged, already-built fixture legitimately replays the first build's result rather than
# re-invoking `lake` -- reusing a fixture across cases would make later cases silently test the
# cache instead of what they intend to. A second fixture variant, build_fixture_unknown_cmd(),
# installs a fake `lake` that prints "error: unknown command '<arg>'" to stderr and exits 0 for
# ANY first argument -- this deterministically reproduces the documented Defect A shape (an
# unknown lake subcommand exiting 0) without depending on the REAL `lake` binary, whose actual
# exit code for an unknown command differs across machines/versions (see the plan's Risks table).
#
# Design note this suite locks in (see the script's own header comment for the full statement):
# sharing is checked on BOTH the immediate-acquire (uncontended) and waiter (contended) lock
# paths, not the waiter path alone. This lets cases 5 and 6 below exercise the staleness/
# abandoned-lock rejections with plain sequential invocations -- no artificial concurrency
# choreography needed -- while case 4 still exercises genuine concurrent convoy-avoidance.
#
# Structural model: pass()/fail()/info() helpers, PASSED/FAILED integer counters, SCRIPT_DIR
# resolved via BASH_SOURCE, mktemp -d workdir with trap EXIT cleanup, loud-skip discipline (see
# context/standards/shell-script-testing.md). Uses set -uo pipefail (deliberately not -e) so the
# suite reports a complete summary rather than aborting at the first failing case.
#
# Exit codes: 0 all cases PASS; 1 at least one case FAILED (or a required script is missing).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_SCRIPTS_DIR="$SCRIPT_DIR/.."
SCRIPT_UNDER_TEST="lake-build-guard.sh"
GUARD="$SRC_SCRIPTS_DIR/$SCRIPT_UNDER_TEST"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

# --- Loud-skip discipline: verify the required script exists and is executable before running
# anything. A missing/non-executable script under test is a loud exit 1, never a silent skip. ---
if [ ! -f "$GUARD" ]; then
  echo "ERROR: test-lake-build-guard.sh cannot run -- missing required script: $GUARD" >&2
  exit 1
fi
if [ ! -x "$GUARD" ]; then
  echo "ERROR: test-lake-build-guard.sh cannot run -- $GUARD exists but is not executable" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() {
  [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"
}
trap cleanup EXIT

# --- Ambient-host isolation: deterministic memory-pressure inputs --------------------------------
# lake-build-guard.sh consults a PSI file and a meminfo file to decide whether the machine is
# under memory pressure, and emits a stderr notice (or, in preflight mode, exits 11) when it is.
# Read from the REAL /proc, that verdict is a property of whatever else happens to be running on
# the developer's machine at the time -- so cases asserting the guard's clean/quiet path (1, 3)
# and the preflight-proceeds path (11) would pass on an idle host and fail on a busy one. This was
# observed live: a host swapping at 57% of SwapTotal (over the guard's own 50% threshold) made
# exactly those three cases fail while every other case passed.
#
# Both inputs are redirected, suite-wide, at the script's OWN documented seams
# (LAKE_BUILD_GUARD_PSI_PATH / LAKE_BUILD_GUARD_MEMINFO_PATH) to fixture files describing an
# unpressured machine. This isolates the tests from ambient host state WITHOUT weakening any
# threshold or altering the guard's behavior -- the pressure logic under test is unchanged and
# still fully exercised; it is merely fed a known input instead of an arbitrary one.
#
# Case 22 below covers the positive direction: it overrides LAKE_BUILD_GUARD_MEMINFO_PATH locally
# with a pressured fixture to assert that preflight DOES detect pressure, closing the gap where a
# regression disabling check_memory_pressure() entirely would otherwise leave every case green.
# Any further case that wants to test the positive direction should follow the same local-override
# idiom rather than relying on the host to happen to be under load.
PSI_FIXTURE_CLEAN="$WORKDIR/fixture-psi-clean"
MEMINFO_FIXTURE_CLEAN="$WORKDIR/fixture-meminfo-clean"

cat > "$PSI_FIXTURE_CLEAN" <<'PSI_EOF'
some avg10=0.00 avg60=0.00 avg300=0.00 total=0
full avg10=0.00 avg60=0.00 avg300=0.00 total=0
PSI_EOF

# MemAvailable = 50% of MemTotal (threshold is "below 10% is pressure"); SwapFree = SwapTotal, so
# swap-in-use is 0% (threshold is "above 50% is pressure"). Comfortably clean on both signals.
cat > "$MEMINFO_FIXTURE_CLEAN" <<'MEMINFO_EOF'
MemTotal:       32000000 kB
MemFree:        16000000 kB
MemAvailable:   16000000 kB
SwapTotal:      32000000 kB
SwapFree:       32000000 kB
MEMINFO_EOF

export LAKE_BUILD_GUARD_PSI_PATH="$PSI_FIXTURE_CLEAN"
export LAKE_BUILD_GUARD_MEMINFO_PATH="$MEMINFO_FIXTURE_CLEAN"

# --- Fixture builder ------------------------------------------------------------------------------
# Builds a synthetic Lean package at $1: lakefile.toml, lean-toolchain, a couple of .lean
# sources, and a fake `lake` in $1/bin controlled entirely via environment variables at
# invocation time (FAKE_LAKE_OUT, FAKE_LAKE_ERR, FAKE_LAKE_EXIT, FAKE_LAKE_SLEEP,
# FAKE_LAKE_COUNTER), so no committed fixture data is needed and every case can drive the same
# fake binary differently.
build_fixture() {
  local root="$1"
  mkdir -p "$root/bin" "$root/src"
  cat > "$root/lakefile.toml" <<'EOF'
name = "fixture"
EOF
  echo "leanprover/lean4:stable" > "$root/lean-toolchain"
  echo "def foo := 1" > "$root/src/Foo.lean"
  echo "def bar := 2" > "$root/src/Bar.lean"
  cat > "$root/bin/lake" <<'FAKE_LAKE_EOF'
#!/usr/bin/env bash
if [ -n "${FAKE_LAKE_COUNTER:-}" ]; then
  echo "invocation" >> "$FAKE_LAKE_COUNTER"
fi
echo "${FAKE_LAKE_OUT:-STDOUT_MARKER}"
echo "${FAKE_LAKE_ERR:-STDERR_MARKER}" >&2
if [ -n "${FAKE_LAKE_SLEEP:-}" ]; then
  sleep "$FAKE_LAKE_SLEEP"
fi
exit "${FAKE_LAKE_EXIT:-0}"
FAKE_LAKE_EOF
  chmod +x "$root/bin/lake"
}

# Variant fake `lake` for Defect A regression cases: given ANY first argument, prints
# "error: unknown command '<arg>'" to stderr and exits 0 -- deterministically reproducing the
# documented "unknown command, exit 0" defect shape. The REAL `lake` binary MUST NOT be used for
# these cases (see the plan's Risks & Mitigations: on this machine `lake TARGET` actually exits 1,
# not 0, which would make a real-binary-based regression test vacuous or version-flaky).
build_fixture_unknown_cmd() {
  local root="$1"
  mkdir -p "$root/bin" "$root/src"
  cat > "$root/lakefile.toml" <<'EOF'
name = "fixture"
EOF
  echo "leanprover/lean4:stable" > "$root/lean-toolchain"
  echo "def foo := 1" > "$root/src/Foo.lean"
  cat > "$root/bin/lake" <<'FAKE_LAKE_EOF'
#!/usr/bin/env bash
if [ -n "${FAKE_LAKE_COUNTER:-}" ]; then
  echo "invocation" >> "$FAKE_LAKE_COUNTER"
fi
echo "error: unknown command '${1:-}'" >&2
exit 0
FAKE_LAKE_EOF
  chmod +x "$root/bin/lake"
}

# Invoke the guard against a fixture root: run_guard <root> <mode> [extra args...]
run_guard() {
  local root="$1" mode="$2"
  shift 2
  PATH="$root/bin:$PATH" "$GUARD" "$mode" --dir "$root" "$@"
}

# Read one key=value field out of a build-guard.result-shaped file. Reimplemented here (never
# sourced from the script under test, per this suite's real-subprocess convention) purely as a
# test-side reader; it has no bearing on the guard's own get_record_field().
read_result_field() {
  local field="$1" file="$2"
  [ -f "$file" ] || return 1
  grep "^${field}=" "$file" 2>/dev/null | tail -n 1 | cut -d= -f2-
}

# Bounded wait: poll a condition (a command string, eval'd each iteration) every 0.1s up to
# max_iters times. Per context/patterns/bounded-build-waiter.md, every wait in this suite is
# either a `kill -0`-keyed liveness check or a hard-bounded poll -- never an unbounded loop.
wait_until() {
  local max_iters="$1" cond="$2"
  local i=0
  while [ "$i" -lt "$max_iters" ]; do
    if eval "$cond"; then
      return 0
    fi
    sleep 0.1
    i=$((i + 1))
  done
  return 1
}

# =====================================================================================
# Case 1: silent and transparent when clean
# =====================================================================================
CASE1_ROOT="$WORKDIR/case1"
build_fixture "$CASE1_ROOT"

DIRECT_RC=0
PATH="$CASE1_ROOT/bin:$PATH" "$CASE1_ROOT/bin/lake" build > "$WORKDIR/c1_direct.out" 2> "$WORKDIR/c1_direct.err" || DIRECT_RC=$?

GUARD_RC=0
run_guard "$CASE1_ROOT" build build > "$WORKDIR/c1_guard.out" 2> "$WORKDIR/c1_guard.err" || GUARD_RC=$?

# The one documented, deliberate exception to "zero guard-emitted bytes": the belt-and-braces
# `lake-build-guard: STATUS: exit_status=N` line (see case 33) is stripped before comparing, since
# it is guard-emitted BY DESIGN on every real build, on the guard's own raw stderr -- never inside
# STDOUT_CAPTURE_PATH/STDERR_CAPTURE_PATH, and never on the REPLAY path (case 33 asserts the
# capture-file and no-status-on-replay halves of that contract). Everything else on this path
# stays byte-for-byte identical to the direct fake-lake invocation.
grep -v '^lake-build-guard: STATUS:' "$WORKDIR/c1_guard.err" > "$WORKDIR/c1_guard_stripped.err"

if diff -q "$WORKDIR/c1_direct.out" "$WORKDIR/c1_guard.out" >/dev/null \
   && diff -q "$WORKDIR/c1_direct.err" "$WORKDIR/c1_guard_stripped.err" >/dev/null \
   && [ "$DIRECT_RC" = "$GUARD_RC" ] && [ "$GUARD_RC" = "0" ]; then
  pass "case 1: silent and transparent when clean (stdout/stderr/exit byte-identical to direct fake lake, modulo the one documented STATUS line)"
else
  fail "case 1: clean-path transparency mismatch (direct_rc=$DIRECT_RC guard_rc=$GUARD_RC)"
  info "diff stdout: $(diff "$WORKDIR/c1_direct.out" "$WORKDIR/c1_guard.out" 2>&1)"
  info "diff stderr: $(diff "$WORKDIR/c1_direct.err" "$WORKDIR/c1_guard_stripped.err" 2>&1)"
fi

# =====================================================================================
# Case 2: exit-code passthrough
# =====================================================================================
CASE2_ROOT="$WORKDIR/case2"
build_fixture "$CASE2_ROOT"

RC=0
FAKE_LAKE_EXIT=7 run_guard "$CASE2_ROOT" build build > /dev/null 2>&1 || RC=$?
if [ "$RC" = "7" ]; then
  pass "case 2: exit-code passthrough (fake lake exit 7 -> guard exit 7)"
else
  fail "case 2: expected guard exit 7, got $RC"
fi

# =====================================================================================
# Case 3: command substitution
# =====================================================================================
CASE3_ROOT="$WORKDIR/case3"
build_fixture "$CASE3_ROOT"

DIRECT_COMBINED="$(PATH="$CASE3_ROOT/bin:$PATH" "$CASE3_ROOT/bin/lake" build 2>&1)"
GUARD_COMBINED_RAW="$(run_guard "$CASE3_ROOT" build build 2>&1)"
GUARD_RC=$?
# Same documented STATUS-line carve-out as case 1 (see its comment): stripped before comparing.
GUARD_COMBINED="$(printf '%s\n' "$GUARD_COMBINED_RAW" | grep -v '^lake-build-guard: STATUS:')"

if [ "$DIRECT_COMBINED" = "$GUARD_COMBINED" ] && [ "$GUARD_RC" = "0" ]; then
  pass "case 3: command substitution (\$(guard build 2>&1) equals \$(fake_lake 2>&1) modulo the one documented STATUS line, matching \$?)"
else
  fail "case 3: command-substitution mismatch (guard_rc=$GUARD_RC)"
  info "direct=[$DIRECT_COMBINED] guard=[$GUARD_COMBINED]"
fi

# =====================================================================================
# Case 4: no duplicate build (convoy avoidance under genuine concurrency)
# =====================================================================================
CASE4_ROOT="$WORKDIR/case4"
build_fixture "$CASE4_ROOT"
COUNTER4="$WORKDIR/case4_counter"
: > "$COUNTER4"

FAKE_LAKE_COUNTER="$COUNTER4" FAKE_LAKE_SLEEP=1 run_guard "$CASE4_ROOT" build build \
  > "$WORKDIR/c4_a.out" 2> "$WORKDIR/c4_a.err" &
A_PID=$!
sleep 0.3
B_RC=0
FAKE_LAKE_COUNTER="$COUNTER4" run_guard "$CASE4_ROOT" build build \
  > "$WORKDIR/c4_b.out" 2> "$WORKDIR/c4_b.err" || B_RC=$?
wait "$A_PID"
A_RC=$?

INVOCATIONS4="$(wc -l < "$COUNTER4" | tr -d ' ')"
if [ "$INVOCATIONS4" = "1" ] && [ "$A_RC" = "0" ] && [ "$B_RC" = "0" ] \
   && diff -q "$WORKDIR/c4_a.out" "$WORKDIR/c4_b.out" >/dev/null; then
  pass "case 4: no duplicate build (exactly 1 fake-lake invocation for 2 overlapping guard invocations; B replayed A's output)"
else
  fail "case 4: expected exactly 1 invocation with matching A/B output; invocations=$INVOCATIONS4 a_rc=$A_RC b_rc=$B_RC"
  info "a.out=$(cat "$WORKDIR/c4_a.out" 2>/dev/null) b.out=$(cat "$WORKDIR/c4_b.out" 2>/dev/null)"
fi

# =====================================================================================
# Case 5: staleness -- a real content change (never a touch) defeats sharing
# =====================================================================================
CASE5_ROOT="$WORKDIR/case5"
build_fixture "$CASE5_ROOT"
COUNTER5="$WORKDIR/case5_counter"
: > "$COUNTER5"

FAKE_LAKE_COUNTER="$COUNTER5" run_guard "$CASE5_ROOT" build build > /dev/null 2>&1
AFTER_A5="$(wc -l < "$COUNTER5" | tr -d ' ')"

# Real CONTENT edit (size-changing, so it is unambiguous even within the same wall-clock
# second) -- a bare `touch` would be vacuous here since Lake's own staleness is content-hash
# based and this suite must not encode a test Lake itself would consider a no-op.
echo "def foo := 999999999" > "$CASE5_ROOT/src/Foo.lean"

FAKE_LAKE_COUNTER="$COUNTER5" run_guard "$CASE5_ROOT" build build > /dev/null 2>&1
AFTER_B5="$(wc -l < "$COUNTER5" | tr -d ' ')"

if [ "$AFTER_A5" = "1" ] && [ "$AFTER_B5" = "2" ]; then
  pass "case 5: a real content edit between runs defeats sharing (second run built rather than shared)"
else
  fail "case 5: expected invocation count 1 then 2; got $AFTER_A5 then $AFTER_B5"
fi

# =====================================================================================
# Case 6: abandoned lock -- an in_flight record naming a dead PID is never shared
# =====================================================================================
CASE6_ROOT="$WORKDIR/case6"
build_fixture "$CASE6_ROOT"
mkdir -p "$CASE6_ROOT/.lake"
COUNTER6="$WORKDIR/case6_counter"
: > "$COUNTER6"

cat > "$CASE6_ROOT/.lake/build-guard.result" <<EOF
state=in_flight
holder_pid=999999
start_epoch=1
end_epoch=
pre_fingerprint=deadbeef
post_fingerprint=
lake_bin=/nonexistent-lake
exit_status=
log_path=$CASE6_ROOT/.lake/build-guard.log
EOF

FAKE_LAKE_COUNTER="$COUNTER6" run_guard "$CASE6_ROOT" build build > /dev/null 2>&1
RC6=$?
INVOCATIONS6="$(wc -l < "$COUNTER6" | tr -d ' ')"

if [ "$INVOCATIONS6" = "1" ] && [ "$RC6" = "0" ]; then
  pass "case 6: a hand-written in_flight record naming a dead PID is never shared (a real build ran)"
else
  fail "case 6: expected exactly 1 real build and exit 0; invocations=$INVOCATIONS6 rc=$RC6"
fi

# =====================================================================================
# Case 7: lock derivation -- resolves to the NEAREST lakefile, not a parent's, not a git root's
# =====================================================================================
CASE7_PARENT="$WORKDIR/case7_parent"
mkdir -p "$CASE7_PARENT/.git"
cat > "$CASE7_PARENT/lakefile.toml" <<'EOF'
name = "parent-package"
EOF
mkdir -p "$CASE7_PARENT/pkg/sub/deep"
cat > "$CASE7_PARENT/pkg/lakefile.toml" <<'EOF'
name = "nested-package"
EOF

CASE7_OUT="$("$GUARD" status --dir "$CASE7_PARENT/pkg/sub/deep" --verbose 2>&1)"
if echo "$CASE7_OUT" | grep -q "lock path: $CASE7_PARENT/pkg/\.lake/build-guard\.lock"; then
  pass "case 7: lock derivation resolves to the nearest package's .lake/, not the parent's or the git root's"
else
  fail "case 7: expected lock path under $CASE7_PARENT/pkg/.lake/"
  info "output was: $CASE7_OUT"
fi

# =====================================================================================
# Case 8: no self-match -- a wrapper whose own argv contains "lake build" does not confuse status
# =====================================================================================
CASE8_ROOT="$WORKDIR/case8"
build_fixture "$CASE8_ROOT"

CASE8_OUT="$(bash -c "exec -a 'wrapper-that-mentions-lake-build-in-its-own-argv' bash -c '\"$GUARD\" status --dir \"$CASE8_ROOT\"'" 2>&1)"
CASE8_RC=$?
if [ "$CASE8_RC" = "0" ] && [ -z "$CASE8_OUT" ]; then
  pass "case 8: no self-match (wrapper argv containing the literal string 'lake build' still yields exit 0, no output)"
else
  fail "case 8: expected exit 0 and no output; got rc=$CASE8_RC output=[$CASE8_OUT]"
fi

# =====================================================================================
# Case 9: LSP contamination -- a long-lived process whose comm is `lean` does not fool status
# =====================================================================================
CASE9_ROOT="$WORKDIR/case9"
build_fixture "$CASE9_ROOT"
cat > "$CASE9_ROOT/bin/lean" <<'EOF'
#!/usr/bin/env bash
sleep 20
EOF
chmod +x "$CASE9_ROOT/bin/lean"

"$CASE9_ROOT/bin/lean" --worker &
LEAN_PID=$!
sleep 0.2

CASE9_RC=0
CASE9_OUT="$("$GUARD" status --dir "$CASE9_ROOT" 2>&1)" || CASE9_RC=$?
kill "$LEAN_PID" 2>/dev/null || true
wait "$LEAN_PID" 2>/dev/null || true

if [ "$CASE9_RC" = "0" ] && [ -z "$CASE9_OUT" ]; then
  pass "case 9: an ambient long-lived lean --worker process does not cause status to report a false in-flight build"
else
  fail "case 9: expected exit 0 and no output; got rc=$CASE9_RC output=[$CASE9_OUT]"
fi

# =====================================================================================
# Case 10: cgroup degradation -- systemd-run absent from PATH degrades audibly, build still works
# =====================================================================================
CASE10_ROOT="$WORKDIR/case10"
build_fixture "$CASE10_ROOT"

ISOBIN="$WORKDIR/case10_isobin"
mkdir -p "$ISOBIN"
for tool in bash env cat echo tee sha256sum stat awk grep find sort mkdir ps date dirname sleep cut tail wc chmod flock; do
  toolpath="$(command -v "$tool" 2>/dev/null || true)"
  if [ -n "$toolpath" ]; then
    ln -sf "$toolpath" "$ISOBIN/$tool"
  fi
done
if [ -e "$ISOBIN/systemd-run" ]; then
  rm -f "$ISOBIN/systemd-run"
fi

CASE10_RC=0
CASE10_OUT="$(PATH="$CASE10_ROOT/bin:$ISOBIN" "$GUARD" build --dir "$CASE10_ROOT" --memory-bound build 2>"$WORKDIR/c10.err")" || CASE10_RC=$?
CASE10_ERR="$(cat "$WORKDIR/c10.err")"

if [ "$CASE10_RC" = "0" ] && [ "$CASE10_OUT" = "STDOUT_MARKER" ] && [ -n "$CASE10_ERR" ]; then
  pass "case 10: cgroup degradation (systemd-run absent -> visible stderr notice AND a successful unbounded build with intact output)"
else
  fail "case 10: expected exit 0, intact stdout, and a non-empty stderr notice; rc=$CASE10_RC out=[$CASE10_OUT] err=[$CASE10_ERR]"
fi

# =====================================================================================
# Case 11: PSI degradation -- LAKE_BUILD_GUARD_PSI_PATH pointed at a nonexistent file
# =====================================================================================
CASE11_ROOT="$WORKDIR/case11"
build_fixture "$CASE11_ROOT"

CASE11_RC=0
LAKE_BUILD_GUARD_PSI_PATH="$WORKDIR/does-not-exist-psi" \
  run_guard "$CASE11_ROOT" preflight > /dev/null 2>&1 || CASE11_RC=$?

if [ "$CASE11_RC" = "0" ]; then
  pass "case 11: PSI path pointed at a nonexistent file does not crash; falls back to the meminfo-only signal and the build proceeds"
else
  fail "case 11: expected preflight exit 0 with PSI path unavailable, got rc=$CASE11_RC"
fi

# =====================================================================================
# Case 12: no hardcoded project path or memory byte constant
# =====================================================================================
if grep -nE '/home/|/Projects/|/run/current-system' "$GUARD" > "$WORKDIR/c12_paths.txt"; then
  fail "case 12: found an absolute home/project/system path literal in the script"
  info "matches: $(cat "$WORKDIR/c12_paths.txt")"
else
  pass "case 12a: no absolute home/project/system path literal found in the script"
fi

if grep -nE '[0-9]+(GB|MB|G|M)\b' "$GUARD" > "$WORKDIR/c12_bytes.txt"; then
  fail "case 12: found an absolute memory byte constant in the script"
  info "matches: $(cat "$WORKDIR/c12_bytes.txt")"
else
  pass "case 12b: no absolute memory byte constant found in the script (MemoryHigh/MemoryMax are systemd percentage strings)"
fi

# =====================================================================================
# Case 13: falsified lever stays dropped -- LEAN_NUM_THREADS appears only in comments,
# never assigned or exported (regression guard against re-introducing this folklore)
# =====================================================================================
LEAN_NUM_THREADS_ASSIGNMENTS="$(grep -nE '(^|[^#[:alnum:]_])LEAN_NUM_THREADS[[:space:]]*=' "$GUARD" | grep -vE '^\s*[0-9]+:\s*#' || true)"
LEAN_NUM_THREADS_EXPORTS="$(grep -nE 'export[[:space:]]+LEAN_NUM_THREADS' "$GUARD" || true)"
LEAN_NUM_THREADS_TOTAL_LINES="$(grep -c 'LEAN_NUM_THREADS' "$GUARD" || true)"
LEAN_NUM_THREADS_COMMENT_LINES="$(grep -E 'LEAN_NUM_THREADS' "$GUARD" | grep -cE '^\s*#' || true)"

if [ -z "$LEAN_NUM_THREADS_ASSIGNMENTS" ] && [ -z "$LEAN_NUM_THREADS_EXPORTS" ] \
   && [ "$LEAN_NUM_THREADS_TOTAL_LINES" -gt 0 ] \
   && [ "$LEAN_NUM_THREADS_TOTAL_LINES" = "$LEAN_NUM_THREADS_COMMENT_LINES" ]; then
  pass "case 13: LEAN_NUM_THREADS appears only in comment lines ($LEAN_NUM_THREADS_TOTAL_LINES occurrence(s)) documenting it as a falsified non-lever, never assigned or exported"
else
  fail "case 13: LEAN_NUM_THREADS regression -- total_lines=$LEAN_NUM_THREADS_TOTAL_LINES comment_lines=$LEAN_NUM_THREADS_COMMENT_LINES assignments=[$LEAN_NUM_THREADS_ASSIGNMENTS] exports=[$LEAN_NUM_THREADS_EXPORTS]"
fi

# =====================================================================================
# Case 14: Defect A -- unknown subcommand via the `--` path exits 77 before any build runs
# =====================================================================================
CASE14_ROOT="$WORKDIR/case14"
build_fixture_unknown_cmd "$CASE14_ROOT"
COUNTER14="$WORKDIR/case14_counter"
: > "$COUNTER14"

RC14=0
FAKE_LAKE_COUNTER="$COUNTER14" run_guard "$CASE14_ROOT" build -- garbagecmd TARGET > /dev/null 2>&1 || RC14=$?
INVOCATIONS14="$(wc -l < "$COUNTER14" | tr -d ' ')"

if [ "$RC14" = "77" ] && [ "$INVOCATIONS14" = "0" ]; then
  pass "case 14: unrecognized subcommand via the -- path exits 77 with zero fake-lake invocations (Defect A)"
else
  fail "case 14: expected exit 77 and 0 invocations; got rc=$RC14 invocations=$INVOCATIONS14"
fi

# =====================================================================================
# Case 15: Defect A -- unknown subcommand via the bare catch-all path exits 77 (the case a
# `--`-only fix would miss, since this suite's own invocations use this shape throughout)
# =====================================================================================
CASE15_ROOT="$WORKDIR/case15"
build_fixture_unknown_cmd "$CASE15_ROOT"
COUNTER15="$WORKDIR/case15_counter"
: > "$COUNTER15"

RC15=0
FAKE_LAKE_COUNTER="$COUNTER15" run_guard "$CASE15_ROOT" build garbagecmd TARGET > /dev/null 2>&1 || RC15=$?
INVOCATIONS15="$(wc -l < "$COUNTER15" | tr -d ' ')"

if [ "$RC15" = "77" ] && [ "$INVOCATIONS15" = "0" ]; then
  pass "case 15: unrecognized subcommand via the bare catch-all path exits 77 with zero fake-lake invocations (the case a --)-only fix would miss)"
else
  fail "case 15: expected exit 77 and 0 invocations; got rc=$RC15 invocations=$INVOCATIONS15"
fi

# =====================================================================================
# Case 16: Decision 2 -- `build` with no lake arguments exits 77 (zero-length lake_args is the
# same false-pass class as an unknown subcommand: no build runs, no result is recorded)
# =====================================================================================
CASE16_ROOT="$WORKDIR/case16"
build_fixture_unknown_cmd "$CASE16_ROOT"
COUNTER16="$WORKDIR/case16_counter"
: > "$COUNTER16"

RC16=0
FAKE_LAKE_COUNTER="$COUNTER16" run_guard "$CASE16_ROOT" build > /dev/null 2>&1 || RC16=$?
INVOCATIONS16="$(wc -l < "$COUNTER16" | tr -d ' ')"

if [ "$RC16" = "77" ] && [ "$INVOCATIONS16" = "0" ]; then
  pass "case 16: build with no lake arguments exits 77 with zero fake-lake invocations (Decision 2)"
else
  fail "case 16: expected exit 77 and 0 invocations; got rc=$RC16 invocations=$INVOCATIONS16"
fi

# =====================================================================================
# Case 17: exit-code passthrough survives subcommand validation (case 2's template, run through
# the `--` path with a RECOGNIZED subcommand)
# =====================================================================================
CASE17_ROOT="$WORKDIR/case17"
build_fixture "$CASE17_ROOT"

RC17=0
FAKE_LAKE_EXIT=7 run_guard "$CASE17_ROOT" build -- build TARGET > /dev/null 2>&1 || RC17=$?
if [ "$RC17" = "7" ]; then
  pass "case 17: exit-code passthrough survives subcommand validation (-- build TARGET, FAKE_LAKE_EXIT=7 -> guard exit 7)"
else
  fail "case 17: expected guard exit 7, got $RC17"
fi

# =====================================================================================
# Case 18: Defect B -- a scoped build followed by an unchanged-tree full build produces 2 real
# invocations (sharing is keyed on scope, not staleness alone). `Foo.Bar` follows `build`, so
# lake_args[0] is the valid `build` subcommand and Phase 1's validation does not interfere.
# =====================================================================================
CASE18_ROOT="$WORKDIR/case18"
build_fixture "$CASE18_ROOT"
COUNTER18="$WORKDIR/case18_counter"
: > "$COUNTER18"

FAKE_LAKE_COUNTER="$COUNTER18" run_guard "$CASE18_ROOT" build build Foo.Bar > /dev/null 2>&1
FAKE_LAKE_COUNTER="$COUNTER18" run_guard "$CASE18_ROOT" build build > /dev/null 2>&1
INVOCATIONS18="$(wc -l < "$COUNTER18" | tr -d ' ')"

if [ "$INVOCATIONS18" = "2" ]; then
  pass "case 18: a scoped build followed by an unchanged-tree full build produces 2 real fake-lake invocations (Defect B: sharing keyed on scope, not staleness alone)"
else
  fail "case 18: expected 2 invocations, got $INVOCATIONS18"
fi

# =====================================================================================
# Case 19: the sharing optimization survives scope-keying -- a full build followed by an
# IDENTICAL full build over an unchanged tree still shares (1 invocation, not disabled)
# =====================================================================================
CASE19_ROOT="$WORKDIR/case19"
build_fixture "$CASE19_ROOT"
COUNTER19="$WORKDIR/case19_counter"
: > "$COUNTER19"

FAKE_LAKE_COUNTER="$COUNTER19" run_guard "$CASE19_ROOT" build build > /dev/null 2>&1
FAKE_LAKE_COUNTER="$COUNTER19" run_guard "$CASE19_ROOT" build build > /dev/null 2>&1
INVOCATIONS19="$(wc -l < "$COUNTER19" | tr -d ' ')"

if [ "$INVOCATIONS19" = "1" ]; then
  pass "case 19: an identical full build over an unchanged tree still shares (1 invocation) -- the sharing optimization survives scope-keying, it is not disabled"
else
  fail "case 19: expected 1 invocation, got $INVOCATIONS19"
fi

# =====================================================================================
# Case 20: a replayed run announces itself with the lake-build-guard: REPLAY: marker on stderr
# without --no-share; a fresh run does not emit it
# =====================================================================================
CASE20_ROOT="$WORKDIR/case20"
build_fixture "$CASE20_ROOT"

FRESH_ERR20="$(run_guard "$CASE20_ROOT" build build 2>&1 1>/dev/null)"
REPLAY_ERR20="$(run_guard "$CASE20_ROOT" build build 2>&1 1>/dev/null)"

if ! printf '%s' "$FRESH_ERR20" | grep -q 'lake-build-guard: REPLAY:' \
   && printf '%s' "$REPLAY_ERR20" | grep -q 'lake-build-guard: REPLAY:'; then
  pass "case 20: a replayed run emits the lake-build-guard: REPLAY: marker on stderr without --no-share, and a fresh run does not"
else
  fail "case 20: expected marker absent on the fresh run and present on the replay; fresh=[$FRESH_ERR20] replay=[$REPLAY_ERR20]"
fi

# =====================================================================================
# Case 21: Defect C -- --help output documents the `kill -0` wait idiom and the `pgrep -f`
# self-match pitfall (grep-based inspection case, following cases 12/13's template)
# =====================================================================================
HELP_OUT21="$("$GUARD" --help 2>&1)"
if printf '%s' "$HELP_OUT21" | grep -q 'kill -0' && printf '%s' "$HELP_OUT21" | grep -q 'pgrep'; then
  pass "case 21: --help output documents the kill -0 wait idiom and the pgrep -f self-match pitfall"
else
  fail "case 21: expected --help output to contain both 'kill -0' and 'pgrep'; got=[$HELP_OUT21]"
fi

# =====================================================================================
# Case 22: positive direction -- a pressured meminfo fixture makes preflight DETECT pressure
# =====================================================================================
# Counterpart to the suite-wide clean-fixture default set up above. With no case driving the
# pressured direction, a regression that disabled check_memory_pressure() entirely would leave
# every other case green -- this case closes that gap. Follows case 11's per-invocation
# local-override idiom (LAKE_BUILD_GUARD_MEMINFO_PATH is overridden on this ONE invocation only;
# the suite-wide exports at lines 104-105 are never reassigned) and case 10's stderr-capture
# idiom. LAKE_BUILD_GUARD_PSI_PATH is deliberately left at the suite-wide clean fixture, so only
# the two meminfo-derived reasons fire, not a PSI reason.
#
# Threshold constants are grep'd out of $GUARD at run time (never hardcoded) so this case stays
# correct if MEM_AVAILABLE_RATIO_THRESHOLD / SWAP_USED_RATIO_THRESHOLD are ever retuned. MemTotal
# and SwapTotal are exact multiples of 100 and the target ratios (THRESH/2 for availability,
# (THRESH+100)/2 for swap-in-use) are chosen so the integer-truncating ratio arithmetic in
# check_memory_pressure() lands comfortably past each threshold, never on the boundary.
CASE22_MEM_AVAIL_THRESH="$(grep -oE '^MEM_AVAILABLE_RATIO_THRESHOLD=[0-9]+' "$GUARD" | cut -d= -f2)"
CASE22_SWAP_USED_THRESH="$(grep -oE '^SWAP_USED_RATIO_THRESHOLD=[0-9]+' "$GUARD" | cut -d= -f2)"

if [ -z "$CASE22_MEM_AVAIL_THRESH" ] || [ -z "$CASE22_SWAP_USED_THRESH" ]; then
  fail "case 22: could not read MEM_AVAILABLE_RATIO_THRESHOLD / SWAP_USED_RATIO_THRESHOLD out of $GUARD"
else
  CASE22_ROOT="$WORKDIR/case22"
  build_fixture "$CASE22_ROOT"

  CASE22_AVAIL_RATIO_TARGET=$(( CASE22_MEM_AVAIL_THRESH / 2 ))
  CASE22_SWAP_RATIO_TARGET=$(( (CASE22_SWAP_USED_THRESH + 100) / 2 ))

  CASE22_MEM_TOTAL=32000000
  CASE22_SWAP_TOTAL=32000000
  CASE22_MEM_AVAIL=$(( CASE22_MEM_TOTAL * CASE22_AVAIL_RATIO_TARGET / 100 ))
  CASE22_SWAP_USED=$(( CASE22_SWAP_TOTAL * CASE22_SWAP_RATIO_TARGET / 100 ))
  CASE22_SWAP_FREE=$(( CASE22_SWAP_TOTAL - CASE22_SWAP_USED ))

  MEMINFO_FIXTURE_PRESSURED="$WORKDIR/fixture-meminfo-pressured"
  cat > "$MEMINFO_FIXTURE_PRESSURED" <<EOF
MemTotal:       $CASE22_MEM_TOTAL kB
MemFree:        $CASE22_MEM_AVAIL kB
MemAvailable:   $CASE22_MEM_AVAIL kB
SwapTotal:      $CASE22_SWAP_TOTAL kB
SwapFree:       $CASE22_SWAP_FREE kB
EOF

  CASE22_RC=0
  LAKE_BUILD_GUARD_MEMINFO_PATH="$MEMINFO_FIXTURE_PRESSURED" \
    run_guard "$CASE22_ROOT" preflight > /dev/null 2> "$WORKDIR/c22.err" || CASE22_RC=$?
  CASE22_ERR="$(cat "$WORKDIR/c22.err")"

  if [ "$CASE22_RC" = "11" ] \
     && printf '%s' "$CASE22_ERR" | grep -qF "MemAvailable/MemTotal = ${CASE22_AVAIL_RATIO_TARGET}% is below threshold ${CASE22_MEM_AVAIL_THRESH}%" \
     && printf '%s' "$CASE22_ERR" | grep -qF "swap-in-use = ${CASE22_SWAP_RATIO_TARGET}% of SwapTotal exceeds threshold ${CASE22_SWAP_USED_THRESH}%"; then
    pass "case 22: positive direction -- a pressured meminfo fixture, overriding LAKE_BUILD_GUARD_MEMINFO_PATH on this single invocation only, makes preflight exit 11 and report both the MemAvailable and swap-in-use reasons"
  else
    fail "case 22: expected preflight exit 11 with both the MemAvailable and swap-in-use reasons; got rc=$CASE22_RC err=[$CASE22_ERR]"
  fi
fi

# =====================================================================================
# Case 23: a holder killed (SIGTERM to its own process group) leaves a TERMINAL aborted record,
# never a permanently-stuck in_flight one (the killed-holder defect this task fixes)
# =====================================================================================
# Launched under `setsid` so the guard process becomes its own session/process-group leader --
# required so a single `kill -TERM -- -$pgid` reaches both the guard shell (to fire its trap) and
# the fake-lake child it launched in the foreground (to actually end bash's wait() on it; see the
# script's own TERMINAL RECORD GUARANTEE header note on trap-delivery deferral). The PGID used is
# read back from the record's own holder_pid field -- NOT bash's "$!" -- because setsid may or may
# not fork depending on whether its caller is already a process group leader, so "$!" is not a
# reliable handle on the real running guard PID; holder_pid is (it is `$$` from inside the guard
# itself, always accurate regardless of any exec chain). This follows
# context/patterns/bounded-build-waiter.md throughout: bounded polls only, liveness via `kill -0`
# on a captured PID, never `pgrep -f`.
CASE23_ROOT="$WORKDIR/case23"
build_fixture "$CASE23_ROOT"
CASE23_RESULT="$CASE23_ROOT/.lake/build-guard.result"

setsid env FAKE_LAKE_SLEEP=30 PATH="$CASE23_ROOT/bin:$PATH" \
  "$GUARD" build --dir "$CASE23_ROOT" build \
  > "$WORKDIR/c23.out" 2> "$WORKDIR/c23.err" &
disown 2>/dev/null || true

CASE23_HOLDER_PID=""
if wait_until 50 '[ -f "$CASE23_RESULT" ] && grep -q "^state=in_flight" "$CASE23_RESULT" 2>/dev/null'; then
  CASE23_HOLDER_PID="$(read_result_field holder_pid "$CASE23_RESULT")"
fi

CASE23_OK=false
if [ -n "$CASE23_HOLDER_PID" ] && kill -0 "$CASE23_HOLDER_PID" 2>/dev/null; then
  # Negative PID targets the whole process group (holder_pid doubles as its own pgid, see above).
  kill -TERM -- "-$CASE23_HOLDER_PID" 2>/dev/null || true
  if wait_until 100 '! kill -0 "$CASE23_HOLDER_PID" 2>/dev/null'; then
    CASE23_OK=true
  fi
fi

CASE23_STATE="$(read_result_field state "$CASE23_RESULT" 2>/dev/null || true)"
CASE23_EXIT_STATUS="$(read_result_field exit_status "$CASE23_RESULT" 2>/dev/null || true)"
CASE23_ABORT_REASON="$(read_result_field abort_reason "$CASE23_RESULT" 2>/dev/null || true)"

if [ "$CASE23_OK" = "true" ] && [ "$CASE23_STATE" = "aborted" ] && [ -n "$CASE23_EXIT_STATUS" ] \
   && [ "$CASE23_ABORT_REASON" = "TERM" ]; then
  pass "case 23: a holder killed with SIGTERM (to its own process group) leaves a terminal aborted record (state=aborted, exit_status=$CASE23_EXIT_STATUS, abort_reason=TERM) rather than a permanently-stuck in_flight one"
else
  fail "case 23: expected a terminal aborted record after SIGTERM; ok=$CASE23_OK state=$CASE23_STATE exit_status=[$CASE23_EXIT_STATUS] abort_reason=[$CASE23_ABORT_REASON] holder_pid=[$CASE23_HOLDER_PID]"
fi

# =====================================================================================
# Case 24: after case 23's kill, a second build on the SAME root does not block behind the dead
# holder and runs a REAL build (never shares the aborted record) -- proves the lock is free and
# the aborted state is correctly excluded from decide_sharing()'s state==complete condition
# =====================================================================================
CASE24_COUNTER="$WORKDIR/case24_counter"
: > "$CASE24_COUNTER"

CASE24_RC=0
CASE24_ERR="$(FAKE_LAKE_COUNTER="$CASE24_COUNTER" run_guard "$CASE23_ROOT" build build --timeout 20 2>&1 1>/dev/null)" || CASE24_RC=$?
CASE24_INVOCATIONS="$(wc -l < "$CASE24_COUNTER" | tr -d ' ')"

if [ "$CASE24_RC" = "0" ] && [ "$CASE24_INVOCATIONS" = "1" ] \
   && ! printf '%s' "$CASE24_ERR" | grep -q 'lake-build-guard: REPLAY:'; then
  pass "case 24: a build against the same root after case 23's kill does not block and runs a real build (1 fake-lake invocation, no REPLAY marker) -- an aborted record is never shared"
else
  fail "case 24: expected exit 0, exactly 1 real invocation, and no REPLAY marker; rc=$CASE24_RC invocations=$CASE24_INVOCATIONS err=[$CASE24_ERR]"
fi

# =====================================================================================
# Case 25: `result` against a project with no record present exits 23
# =====================================================================================
CASE25_ROOT="$WORKDIR/case25"
build_fixture "$CASE25_ROOT"

CASE25_RC=0
run_guard "$CASE25_ROOT" result > /dev/null 2>&1 || CASE25_RC=$?

if [ "$CASE25_RC" = "23" ]; then
  pass "case 25: result against a project with no record present exits 23 (no record)"
else
  fail "case 25: expected exit 23, got $CASE25_RC"
fi

# =====================================================================================
# Case 26: `result` against an in_flight record whose lock is HELD (a build genuinely still
# running) exits 21 and reports state=in_flight -- never scans the process table, only probes
# the lock via the same non-blocking flock -n idiom cmd_status() already uses
# =====================================================================================
CASE26_ROOT="$WORKDIR/case26"
build_fixture "$CASE26_ROOT"
mkdir -p "$CASE26_ROOT/.lake"
CASE26_LOCK="$CASE26_ROOT/.lake/build-guard.lock"
cat > "$CASE26_ROOT/.lake/build-guard.result" <<EOF
state=in_flight
holder_pid=999999
start_epoch=1
end_epoch=
pre_fingerprint=deadbeef
post_fingerprint=
scope_key=
lake_bin=/nonexistent-lake
exit_status=
log_path=$CASE26_ROOT/.lake/build-guard.log
EOF

flock "$CASE26_LOCK" -c 'sleep 5' &
CASE26_LOCKHOLDER_PID=$!
wait_until 30 '! flock -n "$CASE26_LOCK" -c true 2>/dev/null'

CASE26_RC=0
CASE26_OUT="$(run_guard "$CASE26_ROOT" result 2>&1)" || CASE26_RC=$?
kill "$CASE26_LOCKHOLDER_PID" 2>/dev/null || true
wait "$CASE26_LOCKHOLDER_PID" 2>/dev/null || true

if [ "$CASE26_RC" = "21" ] && printf '%s' "$CASE26_OUT" | grep -q '^state=in_flight'; then
  pass "case 26: result against an in_flight record whose lock is currently held (a build genuinely still running) exits 21 and reports state=in_flight"
else
  fail "case 26: expected exit 21 with state=in_flight; got rc=$CASE26_RC out=[$CASE26_OUT]"
fi

# =====================================================================================
# Case 27: orphan and aborted terminal reporting, both exit 22
# =====================================================================================
# 27a: an in_flight record whose lock is FREE means the holder died WITHOUT any trap firing
# (e.g. SIGKILL) -- result must not trust the record's stale in_flight claim; it reports
# state=orphaned instead (see cmd_result()'s orphan-detection comment).
CASE27A_ROOT="$WORKDIR/case27a"
build_fixture "$CASE27A_ROOT"
mkdir -p "$CASE27A_ROOT/.lake"
cat > "$CASE27A_ROOT/.lake/build-guard.result" <<EOF
state=in_flight
holder_pid=999999
start_epoch=1
end_epoch=
pre_fingerprint=deadbeef
post_fingerprint=
scope_key=
lake_bin=/nonexistent-lake
exit_status=
log_path=$CASE27A_ROOT/.lake/build-guard.log
EOF

CASE27A_RC=0
CASE27A_OUT="$(run_guard "$CASE27A_ROOT" result 2>&1)" || CASE27A_RC=$?

if [ "$CASE27A_RC" = "22" ] && printf '%s' "$CASE27A_OUT" | grep -q '^state=orphaned'; then
  pass "case 27a: an in_flight record whose lock is free (holder died untrappably) is reported as state=orphaned and exits 22, never trusted as a live build"
else
  fail "case 27a: expected exit 22 with state=orphaned; got rc=$CASE27A_RC out=[$CASE27A_OUT]"
fi

# 27b: a hand-written state=aborted record (already terminal, from a trapped kill) exits 22 and
# reports state=aborted verbatim -- no orphan probe applies since the state is not in_flight.
CASE27B_ROOT="$WORKDIR/case27b"
build_fixture "$CASE27B_ROOT"
mkdir -p "$CASE27B_ROOT/.lake"
cat > "$CASE27B_ROOT/.lake/build-guard.result" <<EOF
state=aborted
holder_pid=999999
start_epoch=1
end_epoch=2
pre_fingerprint=deadbeef
post_fingerprint=deadbeef
scope_key=
lake_bin=/nonexistent-lake
exit_status=143
log_path=$CASE27B_ROOT/.lake/build-guard.log
abort_reason=TERM
EOF

CASE27B_RC=0
CASE27B_OUT="$(run_guard "$CASE27B_ROOT" result 2>&1)" || CASE27B_RC=$?

if [ "$CASE27B_RC" = "22" ] && printf '%s' "$CASE27B_OUT" | grep -q '^state=aborted' \
   && printf '%s' "$CASE27B_OUT" | grep -q '^abort_reason=TERM'; then
  pass "case 27b: a hand-written state=aborted record is reported verbatim (state=aborted, abort_reason=TERM) and exits 22"
else
  fail "case 27b: expected exit 22 with state=aborted and abort_reason=TERM; got rc=$CASE27B_RC out=[$CASE27B_OUT]"
fi

# =====================================================================================
# Case 28: a real PASSING build's verdict is reachable from result's exit code alone (0), no
# pipeline, no text parsing
# =====================================================================================
CASE28_ROOT="$WORKDIR/case28"
build_fixture "$CASE28_ROOT"
run_guard "$CASE28_ROOT" build build > /dev/null 2>&1

CASE28_RC=0
CASE28_OUT="$(run_guard "$CASE28_ROOT" result 2>&1)" || CASE28_RC=$?

if [ "$CASE28_RC" = "0" ] && printf '%s' "$CASE28_OUT" | grep -q '^state=complete' \
   && printf '%s' "$CASE28_OUT" | grep -q '^exit_status=0'; then
  pass "case 28: a real passing build's verdict (state=complete, exit_status=0) is reachable via result's own exit code (0), with no pipeline and no text parsing"
else
  fail "case 28: expected exit 0 with state=complete and exit_status=0; got rc=$CASE28_RC out=[$CASE28_OUT]"
fi

# =====================================================================================
# Case 29: a real FAILING build's verdict is reachable from result's exit code (20), with the
# real recorded exit_status visible on stdout -- this is the acceptance-critical case: the
# original defect this task's absorbed work exists to fix (a broken build looking "exit 0"
# because a caller could only read a pipeline's last stage). Also confirms the run_lake_foreground
# set -e fix: before it, a failing build never reached finalize_record() at all and state stayed
# in_flight forever, which this case would have caught as a state!=complete mismatch.
# =====================================================================================
CASE29_ROOT="$WORKDIR/case29"
build_fixture "$CASE29_ROOT"
FAKE_LAKE_EXIT=5 run_guard "$CASE29_ROOT" build build > /dev/null 2>&1

CASE29_RC=0
CASE29_OUT="$(run_guard "$CASE29_ROOT" result 2>&1)" || CASE29_RC=$?

if [ "$CASE29_RC" = "20" ] && printf '%s' "$CASE29_OUT" | grep -q '^state=complete' \
   && printf '%s' "$CASE29_OUT" | grep -q '^exit_status=5'; then
  pass "case 29: a real failing build's verdict (state=complete, exit_status=5) is reachable via result's own exit code (20), with the real exit code visible on stdout -- no pipeline, no text parsing"
else
  fail "case 29: expected exit 20 with state=complete and exit_status=5; got rc=$CASE29_RC out=[$CASE29_OUT]"
fi

# =====================================================================================
# Case 30: --expect-pid mismatch refuses with exit 24 and prints no verdict lines on stdout
# =====================================================================================
CASE30_ROOT="$WORKDIR/case30"
build_fixture "$CASE30_ROOT"
run_guard "$CASE30_ROOT" build build > /dev/null 2>&1

CASE30_RC=0
CASE30_OUT="$(run_guard "$CASE30_ROOT" result --expect-pid 1 2>/dev/null)" || CASE30_RC=$?
CASE30_ERR="$(run_guard "$CASE30_ROOT" result --expect-pid 1 2>&1 1>/dev/null)"

if [ "$CASE30_RC" = "24" ] && [ -z "$CASE30_OUT" ] && printf '%s' "$CASE30_ERR" | grep -q 'not the expected pid 1'; then
  pass "case 30: --expect-pid mismatch (an obviously-wrong pid) refuses with exit 24, a stderr explanation, and no verdict lines on stdout"
else
  fail "case 30: expected exit 24, empty stdout, and a mismatch message; rc=$CASE30_RC out=[$CASE30_OUT] err=[$CASE30_ERR]"
fi

# =====================================================================================
# Case 31: --expect-scope mismatch (a differently-scoped lake argument vector) refuses with 24
# =====================================================================================
CASE31_ROOT="$WORKDIR/case31"
build_fixture "$CASE31_ROOT"
run_guard "$CASE31_ROOT" build build > /dev/null 2>&1

CASE31_RC=0
run_guard "$CASE31_ROOT" result --expect-scope -- build Foo.Bar > /dev/null 2>&1 || CASE31_RC=$?

if [ "$CASE31_RC" = "24" ]; then
  pass "case 31: --expect-scope -- build Foo.Bar against a record built with a plain 'build' refuses with exit 24 (differently-scoped, never reports a sibling's verdict)"
else
  fail "case 31: expected exit 24, got $CASE31_RC"
fi

# =====================================================================================
# Case 32: a MATCHING --expect-scope (the same lake argument vector the record was built with)
# reports the real verdict (0) rather than refusing -- confirms the assertion is not just an
# always-refuse stub
# =====================================================================================
CASE32_ROOT="$WORKDIR/case32"
build_fixture "$CASE32_ROOT"
run_guard "$CASE32_ROOT" build build > /dev/null 2>&1

CASE32_RC=0
run_guard "$CASE32_ROOT" result --expect-scope -- build > /dev/null 2>&1 || CASE32_RC=$?

if [ "$CASE32_RC" = "0" ]; then
  pass "case 32: a matching --expect-scope -- build against a record built with 'build' reports the real verdict (exit 0), not a refusal"
else
  fail "case 32: expected exit 0, got $CASE32_RC"
fi

# =====================================================================================
# Case 33: the STATUS line appears exactly once on a fresh build's stderr, never inside the
# capture files, and a subsequent replay's captured output stays byte-identical with no STATUS
# line of its own (cases 1/3's byte-equality guarantee, now exercised across a replay too)
# =====================================================================================
CASE33_ROOT="$WORKDIR/case33"
build_fixture "$CASE33_ROOT"

FRESH_ERR33="$(run_guard "$CASE33_ROOT" build build 2>&1 1>/dev/null)"
FRESH_OUT33_COUNT="$(printf '%s' "$FRESH_ERR33" | grep -c '^lake-build-guard: STATUS: exit_status=0$' || true)"

CASE33_STDOUT_CAPTURE="$CASE33_ROOT/.lake/build-guard.stdout"
CASE33_STDERR_CAPTURE="$CASE33_ROOT/.lake/build-guard.stderr"
CASE33_CAPTURE_STATUS_COUNT=0
if [ -f "$CASE33_STDOUT_CAPTURE" ]; then
  CASE33_CAPTURE_STATUS_COUNT=$((CASE33_CAPTURE_STATUS_COUNT + $(grep -c 'STATUS:' "$CASE33_STDOUT_CAPTURE" || true)))
fi
if [ -f "$CASE33_STDERR_CAPTURE" ]; then
  CASE33_CAPTURE_STATUS_COUNT=$((CASE33_CAPTURE_STATUS_COUNT + $(grep -c 'STATUS:' "$CASE33_STDERR_CAPTURE" || true)))
fi

# Snapshot the fresh capture bytes, then replay and confirm byte-equality plus no STATUS line.
cp "$CASE33_STDOUT_CAPTURE" "$WORKDIR/c33_fresh.stdout" 2>/dev/null || true
cp "$CASE33_STDERR_CAPTURE" "$WORKDIR/c33_fresh.stderr" 2>/dev/null || true

run_guard "$CASE33_ROOT" build build > /dev/null 2>"$WORKDIR/c33_replay.err"
REPLAY_ERR33="$(cat "$WORKDIR/c33_replay.err")"
REPLAY_STATUS_COUNT33="$(printf '%s' "$REPLAY_ERR33" | grep -c 'STATUS:' || true)"

if [ "$FRESH_OUT33_COUNT" = "1" ] && [ "$CASE33_CAPTURE_STATUS_COUNT" = "0" ] \
   && diff -q "$WORKDIR/c33_fresh.stdout" "$CASE33_STDOUT_CAPTURE" >/dev/null 2>&1 \
   && diff -q "$WORKDIR/c33_fresh.stderr" "$CASE33_STDERR_CAPTURE" >/dev/null 2>&1 \
   && [ "$REPLAY_STATUS_COUNT33" = "0" ]; then
  pass "case 33: fresh build stderr contains exactly one lake-build-guard: STATUS: exit_status=0 line; capture files contain no STATUS:; a subsequent replay's captured output stays byte-identical and its own stderr has no STATUS: line"
else
  fail "case 33: expected exactly 1 fresh STATUS line, 0 in capture files, 0 on replay, and byte-identical replayed captures; fresh_count=$FRESH_OUT33_COUNT capture_count=$CASE33_CAPTURE_STATUS_COUNT replay_count=$REPLAY_STATUS_COUNT33"
fi

# =====================================================================================
# Case 34: --help documents all four capture paths, the result mode, --expect-pid/--expect-scope,
# and the never-a-pipeline rule (case-21-style grep-based inspection)
# =====================================================================================
HELP_OUT34="$("$GUARD" --help 2>&1)"
if printf '%s' "$HELP_OUT34" | grep -q 'build-guard.result' \
   && printf '%s' "$HELP_OUT34" | grep -q 'build-guard.stdout' \
   && printf '%s' "$HELP_OUT34" | grep -q 'build-guard.stderr' \
   && printf '%s' "$HELP_OUT34" | grep -q 'build-guard.log' \
   && printf '%s' "$HELP_OUT34" | grep -q 'lake-build-guard.sh result' \
   && printf '%s' "$HELP_OUT34" | grep -q -- '--expect-pid' \
   && printf '%s' "$HELP_OUT34" | grep -q -- '--expect-scope' \
   && printf '%s' "$HELP_OUT34" | grep -qi 'pipeline'; then
  pass "case 34: --help documents all four capture paths, the result mode, --expect-pid/--expect-scope, and the never-a-pipeline rule"
else
  fail "case 34: expected --help output to name build-guard.result/.stdout/.stderr/.log, the result mode, --expect-pid, --expect-scope, and 'pipeline'; got=[$HELP_OUT34]"
fi

# =====================================================================================
# Test C: cross-tree replay refusal over a raw, full cp -al hardlink clone of the project root
# -- pins the INCIDENTAL protection that keeps decide_sharing() safe across trees even when
# every OTHER sharing
# condition (state=complete, scope match, freshness) is satisfiable. The protection is not
# designed: compute_fingerprint()'s hashed pre-image embeds each file's own path string (`stat
# -c '%n %s %y'` in the default `stat` mode; even `hash` mode's `sha256sum` output is a
# "<hash>  <filename>" line, which also embeds the filename), so two DIFFERENT root paths can
# never hash to an equal fingerprint, and decide_sharing()'s post_fingerprint comparison always
# fails closed across trees. A future change to a pure content hash (dropping path-embedding)
# would silently reopen a cross-tree replay at the decide_sharing() level. This case is
# deliberately NOT routed through dispatch-worktree.sh's `provision` -- it uses a raw `cp -al`
# directly -- so it pins the guard's OWN logic independent of that script's clone-side fix and
# stays load-bearing (not vacuous) whether or not that fix is present.
# =====================================================================================
TESTC_ROOT1="$WORKDIR/testc_root1"
TESTC_ROOT2="$WORKDIR/testc_root2"
build_fixture "$TESTC_ROOT1"

COUNTERC="$WORKDIR/testc_counter"
: > "$COUNTERC"

# Real build in root1 at a given scope.
FAKE_LAKE_COUNTER="$COUNTERC" run_guard "$TESTC_ROOT1" build build > /dev/null 2>&1

# Raw, FULL cp -al clone of the whole root (mirrors dispatch-worktree.sh's own hardlink-clone
# mechanism, but invoked directly rather than through that script) -- deliberately NOT a
# selective per-file copy. A full hardlink clone gives root2 files with the SAME content AND
# the SAME mtime as root1's (they are the same inode), so path is the ONLY thing that differs
# between the two trees' fingerprint pre-images. A selective `cp -r` of the non-.lake/ files
# would reset their mtime to copy time, which would ALSO defeat sharing in stat mode -- for a
# reason having nothing to do with path-embedding -- and silently make this case pass for the
# wrong reason (confirmed by hand: a `cp -r`-based version of this fixture still passed against
# a path-stripped mutant of compute_fingerprint(), because the mtime difference alone already
# blocked the replay it was supposed to prove).
cp -al "$TESTC_ROOT1" "$TESTC_ROOT2"

# Real build in root2, the SAME scope -- if decide_sharing() replayed root1's cross-tree-shared
# record, no second fake-lake invocation would occur and no STATUS marker (real-build-only)
# would appear, while a REPLAY marker would.
TESTC_ERR="$WORKDIR/testc_err"
FAKE_LAKE_COUNTER="$COUNTERC" run_guard "$TESTC_ROOT2" build build > /dev/null 2>"$TESTC_ERR"
INVOCATIONSC="$(wc -l < "$COUNTERC" | tr -d ' ')"

if [ "$INVOCATIONSC" = "2" ] \
   && grep -q 'lake-build-guard: STATUS:' "$TESTC_ERR" \
   && ! grep -q 'lake-build-guard: REPLAY:' "$TESTC_ERR"; then
  pass "Test C: a real build occurs in root2 despite a raw full cp -al hardlink clone of root1 at the same scope (2 invocations, STATUS marker present, REPLAY marker absent) -- cross-tree replay is refused, pinning the incidental fingerprint path-embedding protection"
else
  fail "Test C: expected a real build in root2 (2 invocations, STATUS present, REPLAY absent); got invocations=$INVOCATIONSC stderr=[$(cat "$TESTC_ERR")]"
fi

# =====================================================================================
# Non-vacuousness (mutation) checks
# =====================================================================================
# Per context/standards/shell-script-testing.md's "Mutation checks for regex-shaped fixes", and
# the two examples this task's own plan calls out explicitly (removing the `flock -n`
# short-circuit must break case 4; removing `--quiet` must break case 1): this section applies
# a deliberate, targeted mutation to a COPY of the script under test for exactly those two named
# examples and confirms the corresponding case actually goes RED against the mutant -- proving
# those two cases are not vacuously green. The remaining 11 cases are new behavior with no prior
# "pre-fix" script to diff against (this is a brand-new script, not a regression fix to an
# existing one, so there is no historical commit to pin the way test-claude-refresh-matcher.sh
# does); non-vacuousness for those is established by direct inspection instead, recorded below.
info "Non-vacuousness: applying a targeted mutation to a scratch copy for the two cases the plan calls out by name"

MUTANT_DIR="$WORKDIR/mutants"
mkdir -p "$MUTANT_DIR"

# --- Mutation A: remove the --quiet flag from the systemd-run invocation -> case 1-style
# transparency must break when --memory-bound is combined with a real systemd-run (status
# chatter on stderr corrupts the previously-silent clean path). Case 1 itself does not pass
# --memory-bound, so this mutation is exercised via a dedicated mini-case here rather than by
# re-running case 1 verbatim.
MUTANT_QUIET="$MUTANT_DIR/no-quiet.sh"
sed 's/systemd-run --user --scope --quiet --collect/systemd-run --user --scope --collect/' "$GUARD" > "$MUTANT_QUIET"
chmod +x "$MUTANT_QUIET"

if command -v systemd-run >/dev/null 2>&1 && systemd-run --user --scope --quiet --collect -- true >/dev/null 2>&1; then
  MUTANT_ROOT="$WORKDIR/mutant_quiet_fixture"
  build_fixture "$MUTANT_ROOT"
  MUTANT_ERR="$(PATH="$MUTANT_ROOT/bin:$PATH" "$MUTANT_QUIET" build --dir "$MUTANT_ROOT" --memory-bound build 2>&1 1>/dev/null)"
  if [ -n "$MUTANT_ERR" ]; then
    pass "mutation A: removing --quiet from the systemd-run wrapper introduces systemd status chatter on stderr (confirms case 1/10's --quiet requirement is load-bearing, not vacuous)"
  else
    fail "mutation A: removing --quiet did not introduce any stderr chatter on this machine -- inconclusive, but recorded rather than silently skipped"
  fi
else
  info "mutation A skipped: systemd-run --user --scope is unavailable on this machine (no user cgroup delegation) -- case 10 already covers this environment via the degradation path"
fi

# --- Mutation B: remove the flock -n short-circuit (force every acquisition through -w) ->
# case 4's "exactly 1 invocation" assertion must survive being exercised against a version that
# can no longer distinguish "uncontended" from "contended" cheaply; more directly, disabling
# flock entirely proves the counter-based assertion actually depends on serialization at all.
MUTANT_NOFLOCK="$MUTANT_DIR/no-flock.sh"
sed 's/^have_flock() {/have_flock() { return 1; } ; _disabled_have_flock() {/' "$GUARD" > "$MUTANT_NOFLOCK"
chmod +x "$MUTANT_NOFLOCK"

MUTANT4_ROOT="$WORKDIR/mutant_noflock_fixture"
build_fixture "$MUTANT4_ROOT"
MUTANT4_COUNTER="$WORKDIR/mutant4_counter"
: > "$MUTANT4_COUNTER"
FAKE_LAKE_COUNTER="$MUTANT4_COUNTER" FAKE_LAKE_SLEEP=1 \
  PATH="$MUTANT4_ROOT/bin:$PATH" "$MUTANT_NOFLOCK" build --dir "$MUTANT4_ROOT" build \
  > /dev/null 2>&1 &
MUTANT4_A=$!
sleep 0.3
FAKE_LAKE_COUNTER="$MUTANT4_COUNTER" \
  PATH="$MUTANT4_ROOT/bin:$PATH" "$MUTANT_NOFLOCK" build --dir "$MUTANT4_ROOT" build \
  > /dev/null 2>&1
wait "$MUTANT4_A"
MUTANT4_INVOCATIONS="$(wc -l < "$MUTANT4_COUNTER" | tr -d ' ')"

if [ "$MUTANT4_INVOCATIONS" != "1" ]; then
  pass "mutation B: disabling flock serialization breaks case 4's single-invocation guarantee ($MUTANT4_INVOCATIONS invocations instead of 1) -- confirms case 4 is not vacuously green"
else
  fail "mutation B: disabling flock still produced exactly 1 invocation -- inconclusive (unexpected timing), recorded rather than silently skipped"
fi

# --- Mutation C (Defect A): disable validate_build_subcommand() entirely (same
# always-return-0-and-shadow-the-original trick as mutation B's have_flock() mutant) -> both the
# `--`-path and bare-catch-all unrecognized-subcommand cases (14 and 15) must go RED, since the
# unknown subcommand now reaches the fake `lake`, which exits 0, and the guard reports a pass.
MUTANT_NOVALIDATE="$MUTANT_DIR/no-validate.sh"
sed 's/^validate_build_subcommand() {/validate_build_subcommand() { return 0; } ; _disabled_validate_build_subcommand() {/' "$GUARD" > "$MUTANT_NOVALIDATE"
chmod +x "$MUTANT_NOVALIDATE"

MUTANTC_ROOT="$WORKDIR/mutant_novalidate_fixture"
build_fixture_unknown_cmd "$MUTANTC_ROOT"
MUTANTC_COUNTER="$WORKDIR/mutantc_counter"
: > "$MUTANTC_COUNTER"
MUTANTC_RC=0
FAKE_LAKE_COUNTER="$MUTANTC_COUNTER" \
  PATH="$MUTANTC_ROOT/bin:$PATH" "$MUTANT_NOVALIDATE" build --dir "$MUTANTC_ROOT" -- garbagecmd TARGET \
  > /dev/null 2>&1 || MUTANTC_RC=$?
MUTANTC_INVOCATIONS="$(wc -l < "$MUTANTC_COUNTER" | tr -d ' ')"

if [ "$MUTANTC_RC" = "0" ] && [ "$MUTANTC_INVOCATIONS" = "1" ]; then
  pass "mutation C: disabling subcommand validation reintroduces Defect A -- an unrecognized subcommand now reaches the fake lake (which exits 0) and the guard reports a false pass, breaking cases 14/15 -- confirms they are not vacuously green"
else
  fail "mutation C: disabling subcommand validation did not produce the expected false pass -- inconclusive (rc=$MUTANTC_RC invocations=$MUTANTC_INVOCATIONS), recorded rather than silently skipped"
fi

# --- Mutation D (Defect B): remove the scope_key comparison from decide_sharing() (force it
# always-true) -> case 18's "scoped build then full build produces 2 invocations" assertion must
# go RED (invocation count stays at 1, since the differently-scoped result is wrongly shared),
# while case 19's "identical full build still shares" stays green (proving the fix is
# load-bearing AND that it did not simply disable sharing outright).
MUTANT_NOSCOPE="$MUTANT_DIR/no-scope.sh"
sed 's/\[ -n "\$record_scope_key" \] && \[ "\$record_scope_key" = "\$waiter_scope_key" \] || return 1/true/' "$GUARD" > "$MUTANT_NOSCOPE"
chmod +x "$MUTANT_NOSCOPE"

MUTANTD_ROOT="$WORKDIR/mutant_noscope_fixture"
build_fixture "$MUTANTD_ROOT"
MUTANTD_COUNTER="$WORKDIR/mutantd_counter"
: > "$MUTANTD_COUNTER"
FAKE_LAKE_COUNTER="$MUTANTD_COUNTER" \
  PATH="$MUTANTD_ROOT/bin:$PATH" "$MUTANT_NOSCOPE" build --dir "$MUTANTD_ROOT" build Foo.Bar \
  > /dev/null 2>&1
FAKE_LAKE_COUNTER="$MUTANTD_COUNTER" \
  PATH="$MUTANTD_ROOT/bin:$PATH" "$MUTANT_NOSCOPE" build --dir "$MUTANTD_ROOT" build \
  > /dev/null 2>&1
MUTANTD_INVOCATIONS="$(wc -l < "$MUTANTD_COUNTER" | tr -d ' ')"

MUTANTD2_ROOT="$WORKDIR/mutant_noscope_fixture2"
build_fixture "$MUTANTD2_ROOT"
MUTANTD2_COUNTER="$WORKDIR/mutantd2_counter"
: > "$MUTANTD2_COUNTER"
FAKE_LAKE_COUNTER="$MUTANTD2_COUNTER" \
  PATH="$MUTANTD2_ROOT/bin:$PATH" "$MUTANT_NOSCOPE" build --dir "$MUTANTD2_ROOT" build \
  > /dev/null 2>&1
FAKE_LAKE_COUNTER="$MUTANTD2_COUNTER" \
  PATH="$MUTANTD2_ROOT/bin:$PATH" "$MUTANT_NOSCOPE" build --dir "$MUTANTD2_ROOT" build \
  > /dev/null 2>&1
MUTANTD2_INVOCATIONS="$(wc -l < "$MUTANTD2_COUNTER" | tr -d ' ')"

if [ "$MUTANTD_INVOCATIONS" = "1" ] && [ "$MUTANTD2_INVOCATIONS" = "1" ]; then
  pass "mutation D: disabling the scope_key comparison reintroduces Defect B -- a scoped-then-full sequence now wrongly shares (1 invocation instead of 2, breaking case 18), while the identical-full-build sequence still shares (1 invocation, case 19 unaffected) -- confirms case 18 is load-bearing and did not simply disable sharing"
else
  fail "mutation D: unexpected invocation counts -- scoped-then-full=$MUTANTD_INVOCATIONS (want 1, i.e. wrongly shared) full-then-full=$MUTANTD2_INVOCATIONS (want 1) -- inconclusive, recorded rather than silently skipped"
fi

# --- Mutation E (replay notice): remove the REPLAY: stderr line from cmd_build()'s replay branch
# -> case 20's "replay emits the marker" assertion must go RED (the marker never appears, even on
# a genuine replay).
MUTANT_NOREPLAY="$MUTANT_DIR/no-replay.sh"
sed '/^    echo "lake-build-guard: REPLAY: sharing result from holder pid/d' "$GUARD" > "$MUTANT_NOREPLAY"
chmod +x "$MUTANT_NOREPLAY"

MUTANTE_ROOT="$WORKDIR/mutant_noreplay_fixture"
build_fixture "$MUTANTE_ROOT"
PATH="$MUTANTE_ROOT/bin:$PATH" "$MUTANT_NOREPLAY" build --dir "$MUTANTE_ROOT" build > /dev/null 2>&1
MUTANTE_REPLAY_ERR="$(PATH="$MUTANTE_ROOT/bin:$PATH" "$MUTANT_NOREPLAY" build --dir "$MUTANTE_ROOT" build 2>&1 1>/dev/null)"

if ! printf '%s' "$MUTANTE_REPLAY_ERR" | grep -q 'lake-build-guard: REPLAY:'; then
  pass "mutation E: removing the REPLAY: stderr line silences a genuine replay -- confirms case 20's marker assertion is load-bearing, not vacuous"
else
  fail "mutation E: the REPLAY: marker still appeared after removing its emission line -- inconclusive (sed pattern did not match), recorded rather than silently skipped"
fi

# --- Mutation F (positive-direction non-vacuousness): neuter check_memory_pressure() so it
# unconditionally clears PRESSURE_REASONS and reports "no pressure" (same function-shadowing
# trick as mutations B/C above) -> case 22's pressured invocation must now go RED (preflight
# exits 0 with no reasons against the SAME pressured fixture that made case 22 pass), confirming
# case 22 is not vacuously green.
MUTANT_NOPRESSURE="$MUTANT_DIR/no-pressure.sh"
sed 's/^check_memory_pressure() {/check_memory_pressure() { PRESSURE_REASONS=(); return 1; } ; _disabled_check_memory_pressure() {/' "$GUARD" > "$MUTANT_NOPRESSURE"
chmod +x "$MUTANT_NOPRESSURE"

if [ -z "${CASE22_MEM_AVAIL_THRESH:-}" ] || [ -z "${CASE22_SWAP_USED_THRESH:-}" ] || [ -z "${MEMINFO_FIXTURE_PRESSURED:-}" ]; then
  fail "mutation F: case 22's pressured fixture is unavailable -- inconclusive, recorded rather than silently skipped"
else
  MUTANTF_ROOT="$WORKDIR/mutant_nopressure_fixture"
  build_fixture "$MUTANTF_ROOT"
  MUTANTF_RC=0
  LAKE_BUILD_GUARD_MEMINFO_PATH="$MEMINFO_FIXTURE_PRESSURED" \
    PATH="$MUTANTF_ROOT/bin:$PATH" "$MUTANT_NOPRESSURE" preflight --dir "$MUTANTF_ROOT" \
    > /dev/null 2>"$WORKDIR/mutantf.err" || MUTANTF_RC=$?
  MUTANTF_ERR="$(cat "$WORKDIR/mutantf.err")"

  if [ "$MUTANTF_RC" = "0" ] && [ -z "$MUTANTF_ERR" ]; then
    pass "mutation F: neutering check_memory_pressure() to always report no pressure makes the SAME pressured fixture that made case 22 fire now pass silently (exit 0, no reasons) -- confirms case 22 is not vacuously green"
  else
    fail "mutation F: expected preflight exit 0 with no output against the neutered guard; got rc=$MUTANTF_RC err=[$MUTANTF_ERR] -- inconclusive (sed pattern did not match), recorded rather than silently skipped"
  fi
fi

# --- Mutation G (terminal record guarantee): remove the three trap-install lines from
# run_as_holder() (same line-deletion trick as removing a whole guard clause) -> case 23's
# assertion must go RED: with no trap installed, a SIGTERM to the process group kills the guard
# outright with no chance to finalize, and the record stays permanently at state=in_flight.
MUTANT_NOTRAP="$MUTANT_DIR/no-trap.sh"
sed '/^  trap .*_abort_record_trap/d' "$GUARD" > "$MUTANT_NOTRAP"
chmod +x "$MUTANT_NOTRAP"

MUTANTG_ROOT="$WORKDIR/mutant_notrap_fixture"
build_fixture "$MUTANTG_ROOT"
MUTANTG_RESULT="$MUTANTG_ROOT/.lake/build-guard.result"

setsid env FAKE_LAKE_SLEEP=30 PATH="$MUTANTG_ROOT/bin:$PATH" \
  "$MUTANT_NOTRAP" build --dir "$MUTANTG_ROOT" build \
  > /dev/null 2> /dev/null &
disown 2>/dev/null || true

MUTANTG_HOLDER_PID=""
if wait_until 50 '[ -f "$MUTANTG_RESULT" ] && grep -q "^state=in_flight" "$MUTANTG_RESULT" 2>/dev/null'; then
  MUTANTG_HOLDER_PID="$(read_result_field holder_pid "$MUTANTG_RESULT")"
fi

if [ -n "$MUTANTG_HOLDER_PID" ] && kill -0 "$MUTANTG_HOLDER_PID" 2>/dev/null; then
  kill -TERM -- "-$MUTANTG_HOLDER_PID" 2>/dev/null || true
  wait_until 100 '! kill -0 "$MUTANTG_HOLDER_PID" 2>/dev/null' || true
fi
MUTANTG_STATE="$(read_result_field state "$MUTANTG_RESULT" 2>/dev/null || true)"

if [ "$MUTANTG_STATE" = "in_flight" ]; then
  pass "mutation G: removing the trap-install lines from run_as_holder() leaves a killed holder's record permanently at state=in_flight -- confirms case 23's terminal-record assertion is load-bearing, not vacuous"
else
  fail "mutation G: expected the record to stay in_flight after removing the trap install; got state=[$MUTANTG_STATE] -- inconclusive (sed pattern did not match, or holder pid was never captured), recorded rather than silently skipped"
fi

# --- Mutation H (idempotency guard): neutralize the _RECORD_FINALIZED=true / trap-clear pair that
# run_as_holder() runs immediately after a NORMAL finalize_record() call -> an ordinary
# exit-code-passthrough build must now end with state=aborted, because the still-armed EXIT trap
# fires on the process's own final `exit "$rc"` and _abort_record_trap() no longer sees the flag
# set, so it re-finalizes (overwriting the good complete record) instead of returning as a no-op.
MUTANT_NOIDEMPOTENT="$MUTANT_DIR/no-idempotent.sh"
sed '/^  _RECORD_FINALIZED=true$/,+1d' "$GUARD" > "$MUTANT_NOIDEMPOTENT"
chmod +x "$MUTANT_NOIDEMPOTENT"

MUTANTH_ROOT="$WORKDIR/mutant_noidempotent_fixture"
build_fixture "$MUTANTH_ROOT"
MUTANTH_RESULT="$MUTANTH_ROOT/.lake/build-guard.result"
MUTANTH_RC=0
PATH="$MUTANTH_ROOT/bin:$PATH" "$MUTANT_NOIDEMPOTENT" build --dir "$MUTANTH_ROOT" build \
  > /dev/null 2>&1 || MUTANTH_RC=$?
MUTANTH_STATE="$(read_result_field state "$MUTANTH_RESULT" 2>/dev/null || true)"

# With the idempotency guard gone, the still-armed EXIT trap re-fires on the process's own final
# `exit 0` and _abort_record_trap()'s bare-EXIT branch forces a zero pending "$?" to 1 (per
# Decision 1: exit_status is never left empty/zero on a terminal record it writes) -- so the
# mutation corrupts BOTH the record (state=aborted instead of complete) AND the guard's own exit
# code (1 instead of the original build's 0), a strictly stronger signal that the guard is broken.
if [ "$MUTANTH_RC" = "1" ] && [ "$MUTANTH_STATE" = "aborted" ]; then
  pass "mutation H: neutralizing the _RECORD_FINALIZED idempotency guard turns an ordinary successful (exit 0) build into state=aborted with a corrupted exit code (rc=1) -- the still-armed EXIT trap re-finalizes on the process's own normal exit -- confirms the idempotency guard is load-bearing, not vacuous"
else
  fail "mutation H: expected rc=1 with state=aborted after neutralizing the idempotency guard; got rc=$MUTANTH_RC state=[$MUTANTH_STATE] -- inconclusive (sed pattern did not match), recorded rather than silently skipped"
fi

# --- Mutation I (result verdict): force cmd_result() to always exit 0 (same function-shadowing
# trick as mutations B/C/F) -> case 29's terminal-nonzero assertion must go RED (a failed build
# would be reported as exit 0 -- the exact false-pass shape this subcommand exists to prevent).
MUTANT_NORESULT="$MUTANT_DIR/no-result-verdict.sh"
sed 's/^cmd_result() {/cmd_result() { echo "state=complete"; echo "exit_status=0"; exit 0; } ; _disabled_cmd_result() {/' "$GUARD" > "$MUTANT_NORESULT"
chmod +x "$MUTANT_NORESULT"

MUTANTI_ROOT="$WORKDIR/mutant_noresult_fixture"
build_fixture "$MUTANTI_ROOT"
FAKE_LAKE_EXIT=5 PATH="$MUTANTI_ROOT/bin:$PATH" "$MUTANT_NORESULT" build --dir "$MUTANTI_ROOT" build \
  > /dev/null 2>&1

MUTANTI_RC=0
PATH="$MUTANTI_ROOT/bin:$PATH" "$MUTANT_NORESULT" result --dir "$MUTANTI_ROOT" > /dev/null 2>&1 || MUTANTI_RC=$?

if [ "$MUTANTI_RC" = "0" ]; then
  pass "mutation I: forcing cmd_result() to always report exit 0 turns case 29's real failing build (exit_status=5) into a false pass -- confirms case 29's terminal-nonzero assertion is load-bearing, not vacuous"
else
  fail "mutation I: expected the neutered cmd_result() to report exit 0 unconditionally; got rc=$MUTANTI_RC -- inconclusive (sed pattern did not match), recorded rather than silently skipped"
fi

# --- Mutation J (ownership assertion): neutralize cmd_result()'s --expect-scope comparison
# (force the mismatch condition to always be false, same technique as mutation D's decide_sharing
# neutralization) -> case 31's mismatch-refusal assertion must go RED (a differently-scoped
# record is wrongly reported as a match instead of refused).
MUTANT_NOEXPECTSCOPE="$MUTANT_DIR/no-expect-scope.sh"
sed 's/\[ -z "\$scope_key" \] || \[ "\$scope_key" != "\$expected_scope_key" \]/false/' "$GUARD" > "$MUTANT_NOEXPECTSCOPE"
chmod +x "$MUTANT_NOEXPECTSCOPE"

MUTANTJ_ROOT="$WORKDIR/mutant_noexpectscope_fixture"
build_fixture "$MUTANTJ_ROOT"
PATH="$MUTANTJ_ROOT/bin:$PATH" "$MUTANT_NOEXPECTSCOPE" build --dir "$MUTANTJ_ROOT" build > /dev/null 2>&1

MUTANTJ_RC=0
PATH="$MUTANTJ_ROOT/bin:$PATH" "$MUTANT_NOEXPECTSCOPE" result --dir "$MUTANTJ_ROOT" --expect-scope -- build Foo.Bar \
  > /dev/null 2>&1 || MUTANTJ_RC=$?

if [ "$MUTANTJ_RC" = "0" ]; then
  pass "mutation J: neutralizing cmd_result()'s --expect-scope comparison makes a differently-scoped vector (build Foo.Bar against a record built with 'build') wrongly report a match (exit 0) instead of refusing -- confirms case 31's mismatch-refusal assertion is load-bearing, not vacuous"
else
  fail "mutation J: expected the neutered comparison to always report a match (exit 0); got rc=$MUTANTJ_RC -- inconclusive (sed pattern did not match), recorded rather than silently skipped"
fi

# --- Mutation K (STATUS line): remove the STATUS emission line from run_as_holder() -> case 33's
# "exactly one STATUS line" assertion must go RED (a fresh build's stderr has zero).
MUTANT_NOSTATUS="$MUTANT_DIR/no-status.sh"
sed '/^  echo "lake-build-guard: STATUS: exit_status=\$rc" >&2$/d' "$GUARD" > "$MUTANT_NOSTATUS"
chmod +x "$MUTANT_NOSTATUS"

MUTANTK_ROOT="$WORKDIR/mutant_nostatus_fixture"
build_fixture "$MUTANTK_ROOT"
MUTANTK_ERR="$(PATH="$MUTANTK_ROOT/bin:$PATH" "$MUTANT_NOSTATUS" build --dir "$MUTANTK_ROOT" build 2>&1 1>/dev/null)"

if ! printf '%s' "$MUTANTK_ERR" | grep -q 'lake-build-guard: STATUS:'; then
  pass "mutation K: removing the STATUS emission line silences a fresh build's status token entirely -- confirms case 33's assertion is load-bearing, not vacuous"
else
  fail "mutation K: the STATUS line still appeared after removing its emission lines -- inconclusive (sed pattern did not match both call sites), recorded rather than silently skipped"
fi

# --- Remaining cases' non-vacuousness, established by direct inspection (documented, not
# separately scripted, per the plan's "state briefly how it fails" instruction): ---
info "mutation reasoning (cases 2,3,5,6,7,8,9,11,12,13,16,21 -- by inspection, not separately scripted):"
info "  case 2: removing 'return \"\$rc\"' from run_lake_foreground (hardcoding 'return 0' instead) breaks the exit-7 assertion directly."
info "  case 3: any code path that echoes guard-emitted text to stdout/stderr on the clean path breaks the byte-equality assertion."
info "  case 5: removing the post_fp/current_fp comparison in decide_sharing() (always returning 0) breaks case 5 by sharing a stale result -- invocation count would stay at 1."
info "  case 6: removing the 'state == complete' check in decide_sharing() breaks case 6 the same way -- an abandoned in_flight record would be shared, invocation count would stay at 1."
info "  case 7: replacing resolve_project_root()'s upward walk with 'git rev-parse --show-toplevel' breaks case 7 -- it would resolve to the git root, not the nested package."
info "  case 8/9: reintroducing any pgrep-lean or pgrep -f 'lake build' style scan in cmd_status breaks cases 8 and 9 by matching the wrapper argv / the fake lean worker."
info "  case 11: removing the '[ -r ... ]' guard before reading LAKE_BUILD_GUARD_PSI_PATH breaks case 11 with a crash/nonzero exit instead of a graceful fallback."
info "  case 12: hardcoding a byte figure (e.g. MemoryHigh=6G) or an absolute path breaks the grep-based assertions directly."
info "  case 13: assigning or exporting LEAN_NUM_THREADS anywhere breaks case 13's comment-only invariant directly."
info "  case 16: removing the empty-lake_args check from validate_build_subcommand() (returning 0 unconditionally for a zero-length vector) breaks case 16 -- a zero-arg 'build' would reach lake instead of exiting 77."
info "  case 21: deleting the 'kill -0'/'pgrep' WAITING subsection from print_help()'s heredoc breaks case 21's grep-based assertion directly."

# =====================================================================================
# Summary
# =====================================================================================
echo ""
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -eq 0 ]; then
  exit 0
else
  exit 1
fi
