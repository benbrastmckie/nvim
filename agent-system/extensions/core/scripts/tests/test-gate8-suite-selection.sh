#!/usr/bin/env bash
# test-gate8-suite-selection.sh - Regression suite for verify-deploy.sh's Gate 8 touched-paths
# narrowing (--gate8-touched / GATE8_TOUCHED): pins the narrowing itself, the full-sweep
# sentinel fallback, the absent-flag byte-identity guarantee, and the forced cache-ineligibility
# invariant (a narrowed run, pass or fail, must never become the basis for a --skip-unchanged
# cache write) -- the hazard D4 in the implementation plan closes.
#
# Structural model: test-gate8-expected-new-distinction.sh's minimal hand-built fixture
# directory (no git worktree, no deploy-headless.sh -- gate8_run() only ever reads
# $TARGET/agent-system/extensions/core/scripts/{tests/run-all.sh,lib/suite-selection-lib.sh},
# specs/.gate-cache/, specs/.gate-lock, and the OPTIONAL $TARGET/.claude/scripts/task-lock.sh,
# which this fixture deliberately omits so Gate 8's own fail-open mutex path never contends for
# the real repository's specs/.gate-lock mutex), combined with test-gate-cache-equivalence.sh's
# STUBBED run-all.sh precedent: the stub swaps the expensive 195-suite payload for a
# near-instant, controllable pass/fail AND records every argument it received (particularly
# whether --only was passed and what it carried), so this suite can assert on gate8_run()'s own
# constructed invocation directly rather than inferring it from run-all.sh's real output.
#
# Root resolution via common_test_repo_root/common_test_ext_root (never a fixed-depth
# `cd ../../..` walk, which gate 29's root-resolution lint rejects).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"
EXT_ROOT="$(common_test_ext_root "$REPO_ROOT")" || EXT_ROOT="$REPO_ROOT/agent-system/extensions"
CORE_DIR="$EXT_ROOT/core/scripts"
VERIFY_DEPLOY="$CORE_DIR/verify-deploy.sh"
SUITE_SELECTION_LIB_SRC="$CORE_DIR/lib/suite-selection-lib.sh"

if [ ! -f "$VERIFY_DEPLOY" ]; then
  echo "ERROR: expected $VERIFY_DEPLOY" >&2
  exit 2
fi
if [ ! -f "$SUITE_SELECTION_LIB_SRC" ]; then
  echo "ERROR: expected $SUITE_SELECTION_LIB_SRC" >&2
  exit 2
fi

PASSED=0
FAILED=0
common_test_workdir_init

# build_fixture <fixture_dir> -- a minimal Gate-8-reachable fixture: .claude/ exists (gate0's
# only requirement) but deliberately has no scripts/task-lock.sh (fail-open mutex path, same as
# test-gate8-expected-new-distinction.sh's own fixtures); agent-system/extensions/core/ exists
# with manifest.json, a COPY of the REAL verify-deploy.sh under test, the REAL
# suite-selection-lib.sh, and a STUBBED run-all.sh in scripts/tests/. The verify-deploy.sh copy
# is never itself executed (this fixture is always driven by $VERIFY_DEPLOY, the one real
# source-store binary) -- it exists purely so gate-cache-lib.sh's implementation-digest
# machinery (gate_cache_resolve_verify_deploy/gate_cache_extract_invoke_body) can find a copy of
# gate8_run()'s own function body UNDER THE FIXTURE to hash, which Case E's cache-write
# assertions require. The fixture is also a throwaway git repo (gate-cache-lib.sh's `@extensions`
# corpus resolution shells out to `git ls-files`), committed with explicit paths -- never a bare
# `-A`/`.` pathspec, matching this repo's own git-staging convention even for a scratch fixture.
build_fixture() {
  local fx="$1"
  mkdir -p "$fx/.claude/scripts"
  mkdir -p "$fx/agent-system/extensions/core/scripts/tests"
  mkdir -p "$fx/agent-system/extensions/core/scripts/lib"
  echo '{}' > "$fx/agent-system/extensions/core/manifest.json"
  cp "$SUITE_SELECTION_LIB_SRC" "$fx/agent-system/extensions/core/scripts/lib/suite-selection-lib.sh"
  cp "$VERIFY_DEPLOY" "$fx/agent-system/extensions/core/scripts/verify-deploy.sh"
  cat > "$fx/agent-system/extensions/core/scripts/tests/run-all.sh" << 'STUBEOF'
#!/usr/bin/env bash
# STUB for test-gate8-suite-selection.sh -- NOT the real run-all.sh (see that file's own real
# copy for the genuine battery). Records every argument this invocation received to a marker
# file beside this script, so the test can inspect exactly what gate8_run() constructed
# (in particular whether --only was passed and what it carried), then reports a deterministic,
# near-instant pass/fail controlled by a force-fail marker -- swapping the expensive payload for
# a controllable one, mirroring test-gate-cache-equivalence.sh's stub precedent.
set -uo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
printf '%s\n' "$@" > "$SELF_DIR/.stub-received-args"
if [ -f "$SELF_DIR/.stub-force-fail" ]; then
  echo "[run-all] Failing suites (1):"
  echo "    stub-seeded-suite"
  echo "[run-all] 0 passed, 1 failed (0 expected, 1 NEW), 0 skipped, 1 total"
  exit 1
fi
echo "stub: all discovered suites passed (not real -- see test-gate8-suite-selection.sh)"
exit 0
STUBEOF
  chmod +x "$fx/agent-system/extensions/core/scripts/tests/run-all.sh"

  git -C "$fx" init -q
  git -C "$fx" add \
    .claude \
    agent-system/extensions/core/manifest.json \
    agent-system/extensions/core/scripts/lib/suite-selection-lib.sh \
    agent-system/extensions/core/scripts/verify-deploy.sh \
    agent-system/extensions/core/scripts/tests/run-all.sh
  git -C "$fx" -c user.email="test@test.local" -c user.name="gate8-suite-selection-test" \
    commit -q -m "fixture init"
}

# fixture_commit <fixture_dir> -- commits every currently-tracked-or-untracked file under the
# fixture's own agent-system/ and .claude/ trees, explicit paths only (never -A/.), so a later
# mutation (e.g. a placeholder suite file added after build_fixture) is reflected in the
# `@extensions` corpus's `git ls-files` resolution that Case E's cache-write assertions depend
# on.
fixture_commit() {
  local fx="$1"
  git -C "$fx" add agent-system .claude
  git -C "$fx" -c user.email="test@test.local" -c user.name="gate8-suite-selection-test" \
    commit -q -m "fixture update" --allow-empty
}

# fixture_tests_dir <fixture_dir> -- the fixture's own scripts/tests/ directory, where the
# stub, its .stub-received-args marker, and real-basename suite placeholder files all live.
fixture_tests_dir() {
  echo "$1/agent-system/extensions/core/scripts/tests"
}

# stub_args <fixture_dir> -- echoes the stub's recorded argv from its last invocation, one
# argument per line (empty if the stub was never invoked).
stub_args() {
  local td
  td="$(fixture_tests_dir "$1")"
  [ -f "$td/.stub-received-args" ] && cat "$td/.stub-received-args"
}

# stub_only_value <fixture_dir> -- echoes the value immediately following a "--only" line in
# the stub's recorded argv, or nothing if --only was not passed.
stub_only_value() {
  stub_args "$1" | awk '/^--only$/ { getline; print; exit }'
}

run_gate8() {
  # Usage: run_gate8 <fixture_dir> [extra verify-deploy.sh args...]
  # Deliberately never passes --skip-slow -- that would defer gate 8 entirely. --only-gate 8
  # alone keeps every other gate from running.
  local fx="$1"; shift
  bash "$VERIFY_DEPLOY" --only-gate 8 "$@" "$fx" 2>&1
}

cache_file() {
  echo "$1/specs/.gate-cache/gate8.json"
}

# =====================================================================
# Case A (absent flag): no --gate8-touched at all. Gate 8 must reach the stub with no --only
# argument and emit today's exact unnarrowed pass string, byte-identical to a pre-narrowing run.
# =====================================================================
FX_A="$WORKDIR/case-a"
build_fixture "$FX_A"

case_a_out="$(run_gate8 "$FX_A")"
case_a_rc=$?
if [ "$case_a_rc" -eq 0 ]; then
  common_test_pass "case A (absent flag): exit 0"
else
  common_test_fail "case A (absent flag): expected exit 0, got $case_a_rc" "$case_a_out"
fi
if printf '%s\n' "$case_a_out" | grep -qF '[PASS] run-all.sh: all discovered suites passed'; then
  common_test_pass "case A (absent flag): emits today's exact unnarrowed pass string"
else
  common_test_fail "case A (absent flag): expected the exact unnarrowed pass string" "$case_a_out"
fi
if printf '%s\n' "$(stub_args "$FX_A")" | grep -qF -- '--only'; then
  common_test_fail "case A (absent flag): stub unexpectedly received --only" "$(stub_args "$FX_A")"
else
  common_test_pass "case A (absent flag): stub received no --only argument (byte-identical invocation)"
fi

# =====================================================================
# Case B (mappable single path): a touched path whose basename pairs with a real suite file in
# the fixture. Gate 8 must narrow to exactly that suite and say so in its pass message.
# =====================================================================
FX_B="$WORKDIR/case-b"
build_fixture "$FX_B"
touch "$(fixture_tests_dir "$FX_B")/test-foo.sh"

case_b_out="$(run_gate8 "$FX_B" --gate8-touched foo.sh)"
case_b_rc=$?
if [ "$case_b_rc" -eq 0 ]; then
  common_test_pass "case B (mappable single path): exit 0"
else
  common_test_fail "case B (mappable single path): expected exit 0, got $case_b_rc" "$case_b_out"
fi
if printf '%s\n' "$case_b_out" | grep -qF '[PASS] run-all.sh: 1 selected suite(s) passed (narrowed by --gate8-touched -- NOT a full-battery pass)'; then
  common_test_pass "case B (mappable single path): narrowed pass message names the count and the narrowing"
else
  common_test_fail "case B (mappable single path): expected the narrowed pass message" "$case_b_out"
fi
if [ "$(stub_only_value "$FX_B")" = "test-foo.sh" ]; then
  common_test_pass "case B (mappable single path): --only carries exactly the selector's own output (test-foo.sh)"
else
  common_test_fail "case B (mappable single path): expected --only test-foo.sh" "stub argv: $(stub_args "$FX_B")"
fi

# =====================================================================
# Case C (multi-path union): two touched paths whose basenames each pair with their own real
# suite file. The union must resolve and be accepted end-to-end by the stub (standing in for
# run-all.sh's own --only basename validation) -- the smoke test guarding against a
# discovery-rule divergence between suite-selection-lib.sh and run-all.sh.
# =====================================================================
FX_C="$WORKDIR/case-c"
build_fixture "$FX_C"
touch "$(fixture_tests_dir "$FX_C")/test-foo.sh" "$(fixture_tests_dir "$FX_C")/test-bar.sh"

case_c_out="$(run_gate8 "$FX_C" --gate8-touched foo.sh,bar.sh)"
case_c_rc=$?
if [ "$case_c_rc" -eq 0 ]; then
  common_test_pass "case C (multi-path union): exit 0"
else
  common_test_fail "case C (multi-path union): expected exit 0, got $case_c_rc" "$case_c_out"
fi
if printf '%s\n' "$case_c_out" | grep -qF '[PASS] run-all.sh: 2 selected suite(s) passed (narrowed by --gate8-touched -- NOT a full-battery pass)'; then
  common_test_pass "case C (multi-path union): narrowed pass message names the union count (2)"
else
  common_test_fail "case C (multi-path union): expected a 2-suite narrowed pass message" "$case_c_out"
fi
case_c_only="$(stub_only_value "$FX_C")"
if [ "$case_c_only" = "test-bar.sh,test-foo.sh" ] || [ "$case_c_only" = "test-foo.sh,test-bar.sh" ]; then
  common_test_pass "case C (multi-path union): --only carries both resolved suites"
else
  common_test_fail "case C (multi-path union): expected --only to carry both test-foo.sh and test-bar.sh" "stub argv: $(stub_args "$FX_C")"
fi

# =====================================================================
# Case D (unmappable path): a touched path with no covering suite. Gate 8 must fall back to the
# full-sweep sentinel -- the stub receives no --only argument at all, never a zero-suite --only.
# =====================================================================
FX_D="$WORKDIR/case-d"
build_fixture "$FX_D"

case_d_out="$(run_gate8 "$FX_D" --gate8-touched this-path-has-no-covering-suite-xyz.sh)"
case_d_rc=$?
if [ "$case_d_rc" -eq 0 ]; then
  common_test_pass "case D (unmappable path): exit 0"
else
  common_test_fail "case D (unmappable path): expected exit 0, got $case_d_rc" "$case_d_out"
fi
if printf '%s\n' "$case_d_out" | grep -q 'Note:.*full-sweep sentinel'; then
  common_test_pass "case D (unmappable path): emits the sentinel-fallback Note: line"
else
  common_test_fail "case D (unmappable path): expected a sentinel-fallback Note: line" "$case_d_out"
fi
if printf '%s\n' "$case_d_out" | grep -qF '[PASS] run-all.sh: all discovered suites passed'; then
  common_test_pass "case D (unmappable path): falls back to the full, unnarrowed pass string"
else
  common_test_fail "case D (unmappable path): expected the unnarrowed pass string on sentinel fallback" "$case_d_out"
fi
if printf '%s\n' "$(stub_args "$FX_D")" | grep -qF -- '--only'; then
  common_test_fail "case D (unmappable path): stub unexpectedly received --only (never a zero-suite --only)" "$(stub_args "$FX_D")"
else
  common_test_pass "case D (unmappable path): stub received no --only argument on sentinel fallback"
fi

# =====================================================================
# Case E (forced cache-ineligibility): under --skip-unchanged, a clean NARROWED run must leave
# no gate8 cache entry (invalidated, never written), while a clean UNNARROWED run on the exact
# same fixture still writes one -- the D4 invariant this phase exists to close.
# =====================================================================
FX_E="$WORKDIR/case-e"
build_fixture "$FX_E"
touch "$(fixture_tests_dir "$FX_E")/test-foo.sh"
fixture_commit "$FX_E"
CACHE_E="$(cache_file "$FX_E")"

if [ -f "$CACHE_E" ]; then
  common_test_fail "case E (forced cache-ineligibility): precondition violated -- cache entry already present before any run" "$CACHE_E"
else
  common_test_pass "case E (forced cache-ineligibility): precondition -- no pre-existing cache entry"
fi

case_e_narrowed_out="$(bash "$VERIFY_DEPLOY" --skip-unchanged --only-gate 8 --gate8-touched foo.sh "$FX_E" 2>&1)"
case_e_narrowed_rc=$?
if [ "$case_e_narrowed_rc" -eq 0 ] && printf '%s\n' "$case_e_narrowed_out" | grep -qF '[PASS] run-all.sh: 1 selected suite(s) passed'; then
  common_test_pass "case E (forced cache-ineligibility): narrowed run is a clean, narrowed pass"
else
  common_test_fail "case E (forced cache-ineligibility): expected a clean narrowed pass" "$case_e_narrowed_out"
fi
if [ -f "$CACHE_E" ]; then
  common_test_fail "case E (forced cache-ineligibility): a clean NARROWED pass wrote a cache entry (must never happen)" "$(cat "$CACHE_E" 2>/dev/null)"
else
  common_test_pass "case E (forced cache-ineligibility): a clean narrowed pass leaves NO cache entry"
fi

case_e_unnarrowed_out="$(bash "$VERIFY_DEPLOY" --skip-unchanged --only-gate 8 "$FX_E" 2>&1)"
case_e_unnarrowed_rc=$?
if [ "$case_e_unnarrowed_rc" -eq 0 ] && printf '%s\n' "$case_e_unnarrowed_out" | grep -qF '[PASS] run-all.sh: all discovered suites passed'; then
  common_test_pass "case E (forced cache-ineligibility): unnarrowed run on the same fixture is a clean, unnarrowed pass"
else
  common_test_fail "case E (forced cache-ineligibility): expected a clean unnarrowed pass" "$case_e_unnarrowed_out"
fi
if [ -f "$CACHE_E" ]; then
  common_test_pass "case E (forced cache-ineligibility): the unnarrowed pass DOES write a cache entry (generic --skip-unchanged behavior, untouched by this phase)"
else
  common_test_fail "case E (forced cache-ineligibility): expected the unnarrowed pass to write a cache entry" "(no entry present)"
fi

# =====================================================================
# Case F (argument validation): a missing/empty --gate8-touched value must exit 2 with the named
# error, and emit a FINDING gate0 line under --findings -- mirroring --only-gate's own
# invalid-argument posture.
# =====================================================================
FX_F="$WORKDIR/case-f"
build_fixture "$FX_F"

# Deliberately --gate8-touched as the LAST argument (no value at all, no TARGET) -- this must
# exit 2 at argument-parsing time, before TARGET is even consulted, exercising the "truly
# missing" branch ([ $# -lt 2 ]) rather than the "present but empty" branch ([ -z "$2" ]).
case_f_out="$(bash "$VERIFY_DEPLOY" --gate8-touched 2>&1)"
case_f_rc=$?
if [ "$case_f_rc" -eq 2 ]; then
  common_test_pass "case F (argument validation): missing value exits 2"
else
  common_test_fail "case F (argument validation): expected exit 2, got $case_f_rc" "$case_f_out"
fi
if printf '%s\n' "$case_f_out" | grep -qF 'ERROR: --gate8-touched requires PATH'; then
  common_test_pass "case F (argument validation): emits the named --gate8-touched error"
else
  common_test_fail "case F (argument validation): expected the named --gate8-touched error" "$case_f_out"
fi

case_f_findings="$(bash "$VERIFY_DEPLOY" --findings --gate8-touched 2>&1)"
if printf '%s\n' "$case_f_findings" | grep -qF 'FINDING gate0 verify-deploy could not run: --gate8-touched requires PATH'; then
  common_test_pass "case F (argument validation): emits a FINDING gate0 line under --findings"
else
  common_test_fail "case F (argument validation): expected a FINDING gate0 line under --findings" "$case_f_findings"
fi

# Non-vacuousness: an explicitly EMPTY value (present but "") must also trip the error, via the
# sibling branch ([ -z "$2" ]) rather than the "truly missing" one above.
case_f_empty_out="$(bash "$VERIFY_DEPLOY" --gate8-touched "" "$FX_F" 2>&1)"
case_f_empty_rc=$?
if [ "$case_f_empty_rc" -eq 2 ] && printf '%s\n' "$case_f_empty_out" | grep -qF 'ERROR: --gate8-touched requires PATH'; then
  common_test_pass "case F (argument validation): an explicitly empty value also exits 2 with the named error"
else
  common_test_fail "case F (argument validation): expected exit 2 with the named error for an explicitly empty value" "$case_f_empty_out"
fi

echo ""
echo "==================================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "==================================================================="

[ "$FAILED" -eq 0 ] && exit 0 || exit 1
