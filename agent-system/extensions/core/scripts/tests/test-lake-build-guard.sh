#!/usr/bin/env bash
# test-lake-build-guard.sh - Toolchain-free regression suite for lake-build-guard.sh.
#
# Covers 21 acceptance-mapped cases below (the original 13 plus 8 added for the truthful-success
# fixes: subcommand validation, scope-keyed sharing, the REPLAY marker, and the --help wait
# idiom), plus a non-vacuousness (mutation) section. The script under test is invoked as a REAL
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
# No case in this suite asserts that pressure IS detected. Any future case that wants to test the
# positive direction must override these two variables locally with a pressured fixture rather
# than relying on the host to happen to be under load.
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

# =====================================================================================
# Case 1: silent and transparent when clean
# =====================================================================================
CASE1_ROOT="$WORKDIR/case1"
build_fixture "$CASE1_ROOT"

DIRECT_RC=0
PATH="$CASE1_ROOT/bin:$PATH" "$CASE1_ROOT/bin/lake" build > "$WORKDIR/c1_direct.out" 2> "$WORKDIR/c1_direct.err" || DIRECT_RC=$?

GUARD_RC=0
run_guard "$CASE1_ROOT" build build > "$WORKDIR/c1_guard.out" 2> "$WORKDIR/c1_guard.err" || GUARD_RC=$?

if diff -q "$WORKDIR/c1_direct.out" "$WORKDIR/c1_guard.out" >/dev/null \
   && diff -q "$WORKDIR/c1_direct.err" "$WORKDIR/c1_guard.err" >/dev/null \
   && [ "$DIRECT_RC" = "$GUARD_RC" ] && [ "$GUARD_RC" = "0" ]; then
  pass "case 1: silent and transparent when clean (stdout/stderr/exit byte-identical to direct fake lake, zero guard-emitted bytes)"
else
  fail "case 1: clean-path transparency mismatch (direct_rc=$DIRECT_RC guard_rc=$GUARD_RC)"
  info "diff stdout: $(diff "$WORKDIR/c1_direct.out" "$WORKDIR/c1_guard.out" 2>&1)"
  info "diff stderr: $(diff "$WORKDIR/c1_direct.err" "$WORKDIR/c1_guard.err" 2>&1)"
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
GUARD_COMBINED="$(run_guard "$CASE3_ROOT" build build 2>&1)"
GUARD_RC=$?

if [ "$DIRECT_COMBINED" = "$GUARD_COMBINED" ] && [ "$GUARD_RC" = "0" ]; then
  pass "case 3: command substitution (\$(guard build 2>&1) equals \$(fake_lake 2>&1), matching \$?)"
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
