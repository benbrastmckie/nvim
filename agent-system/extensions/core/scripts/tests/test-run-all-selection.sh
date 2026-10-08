#!/usr/bin/env bash
# test-run-all-selection.sh - Regression suite for suite-level selection within Gate 8: both
# halves of the mechanism -- scripts/lib/suite-selection-lib.sh's touched-file -> suite mapping
# (fail-safe escalation, mapping correctness, resolution-order classification) AND run-all.sh's
# --only SUITE[,SUITE,...] flag (validate-all-tokens-first refusal, no-flag behavior preservation,
# and parity of every existing mechanism -- --jobs, the nested guard, LOAD_SENSITIVE_BASENAMES,
# TOTAL_ACCOUNTED, known-failures.txt, --timings -- with and without selection).
#
# Structural model: test-run-all-parallel.sh (pass()/fail()/info() helpers, PASSED/FAILED
# counters, mktemp WORKDIR with trap EXIT cleanup, a SYNTHETIC source-store-shaped fixture with
# the real run-all.sh COPIED in so its own SCRIPT_DIR resolution walks the fixture tree, never
# the real repo's ~120-suite battery -- this suite must itself stay fast and deterministic). The
# library-level cases (fail-safe escalation, mapping correctness) run directly against the REAL
# corpus instead: sourcing a library and calling a pure function is cheap (milliseconds, no suite
# execution), so there is no affordability reason to synthesize a fixture for those cases, and a
# real zero-reference script is more honest evidence than a synthetic stand-in would be.
#
# SOURCE-STORE-ONLY SUBJECT RESOLUTION: this suite resolves its two subjects
# ($RUN_ALL_SRC, $SUITE_SELECTION_LIB) purely from its own location (SCRIPT_DIR's siblings),
# never from a deployed $REPO_ROOT/.claude path -- so this suite itself can never join the
# deployed-preferring population it is partly concerned with classifying in other suites.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_ALL_SRC="$CORE_DIR/tests/run-all.sh"
SUITE_SELECTION_LIB="$CORE_DIR/lib/suite-selection-lib.sh"

if [ ! -f "$RUN_ALL_SRC" ]; then
  echo "ERROR: expected $RUN_ALL_SRC" >&2
  exit 2
fi
if [ ! -f "$SUITE_SELECTION_LIB" ]; then
  echo "ERROR: expected $SUITE_SELECTION_LIB" >&2
  exit 2
fi

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); [ -n "${2:-}" ] && echo "$2"; }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# See test-run-all-parallel.sh's identical header note: an outer run-all.sh unconditionally
# exports RUN_ALL_NESTED=1 into every suite it launches (including this one, when discovered
# as part of a real battery run), and that export is inherited by every child process this
# script spawns. Clearing it once here restores a clean unnested environment for every
# "unguarded" fixture invocation below; the deliberate exception (the nested-guard case) sets it
# explicitly only for that single command.
unset RUN_ALL_NESTED

# =====================================================================================
# PART 1 -- suite-selection-lib.sh, against the REAL corpus (cheap: pure function calls, no
# suite execution).
# =====================================================================================

# shellcheck source=/dev/null
source "$SUITE_SELECTION_LIB"

# Case 1: fail-safe escalation. Dynamically derive a currently-true zero-reference candidate
# (never hardcode a specific basename here: a name hardcoded in THIS suite's own source text
# becomes, the moment this suite exists in the corpus, a textual "reference" to itself via
# suite-selection-lib.sh's own grep-based stratum (b) -- poisoning the very fixture this case is
# meant to prove). Scan the corpus's lib/+lint/+flat-non-test population and pick the first
# candidate whose basename is not grep-referenced by any discovered suite, including this one.
ZERO_REF_CANDIDATE=""
for _cand in "$CORE_DIR"/lib/*.sh "$CORE_DIR"/lint/*.sh "$CORE_DIR"/*.sh; do
  [ -e "$_cand" ] || continue
  _cand_base="$(basename "$_cand")"
  case "$_cand_base" in test-*.sh|run-all.sh) continue ;; esac
  if ! grep -l -F -- "$_cand_base" "$CORE_DIR"/tests/test-*.sh "$CORE_DIR"/test-*.sh 2>/dev/null | grep -q .; then
    ZERO_REF_CANDIDATE="$_cand_base"
    break
  fi
done
unset _cand _cand_base

if [ -z "$ZERO_REF_CANDIDATE" ]; then
  fail "case1: setup error -- no zero-reference candidate could be derived from the current corpus"
  fail "case1b: skipped -- case1's candidate derivation failed"
else
  escalation_out="$(suite_selection_select "$CORE_DIR/$ZERO_REF_CANDIDATE")"
  if [ "$escalation_out" = "$SUITE_SELECTION_FULL_SWEEP_SENTINEL" ]; then
    pass "case1: a real zero-reference script ($ZERO_REF_CANDIDATE) escalates to the full-sweep sentinel"
  else
    fail "case1: expected the full-sweep sentinel for $ZERO_REF_CANDIDATE, got:" "$escalation_out"
  fi

  # Case 1b: the unmapped-reporter names the same path as unmappable.
  unmapped_out="$(suite_selection_unmapped "$CORE_DIR/$ZERO_REF_CANDIDATE")"
  if [ "$unmapped_out" = "$CORE_DIR/$ZERO_REF_CANDIDATE" ]; then
    pass "case1b: suite_selection_unmapped names the zero-reference path verbatim"
  else
    fail "case1b: suite_selection_unmapped did not name the unmappable path as expected" "$unmapped_out"
  fi
fi

# Case 2: mapping correctness -- a lint/ file maps to its paired suite (strict basename pairing).
LINT_FIXTURE="lint-agent-contracts.sh"
lint_out="$(suite_selection_select "$CORE_DIR/lint/$LINT_FIXTURE")"
if printf '%s\n' "$lint_out" | grep -qx "test-${LINT_FIXTURE}"; then
  pass "case2: lint/$LINT_FIXTURE maps to its paired suite test-$LINT_FIXTURE"
else
  fail "case2: lint/$LINT_FIXTURE did not map to test-$LINT_FIXTURE" "$lint_out"
fi

# Case 2b: a shared lib/ file maps to its full many-to-one suite set (reference count >= 10,
# well above any single-pairing result, proving stratum (b) fired).
LIB_FIXTURE="task-lookup-lib.sh"
lib_out="$(suite_selection_select "$CORE_DIR/lib/$LIB_FIXTURE")"
lib_count="$(printf '%s\n' "$lib_out" | grep -c .)"
if [ "$lib_count" -ge 10 ]; then
  pass "case2b: lib/$LIB_FIXTURE maps to its full many-to-one suite set ($lib_count suites)"
else
  fail "case2b: lib/$LIB_FIXTURE mapped to only $lib_count suite(s), expected >= 10" "$lib_out"
fi

# Case 2c: every returned suite carries a resolution-order classification (one of the three
# documented values) via suite_selection_select_annotated.
annotated_out="$(suite_selection_select_annotated "$CORE_DIR/lint/$LINT_FIXTURE")"
bad_class_count=0
while IFS='|' read -r _suite _class; do
  [ -n "$_suite" ] || continue
  case "$_class" in
    source-only|source-first|deployed-first) ;;
    *) bad_class_count=$((bad_class_count + 1)) ;;
  esac
done <<< "$annotated_out"
if [ "$bad_class_count" -eq 0 ] && [ -n "$annotated_out" ]; then
  pass "case2c: every selected suite carries a valid resolution-order classification"
else
  fail "case2c: $bad_class_count selected suite(s) carried an invalid/missing classification" "$annotated_out"
fi

# Case 3: multi-path union, except a single unmappable path escalates the whole call.
if [ -z "$ZERO_REF_CANDIDATE" ]; then
  fail "case3: skipped -- case1's candidate derivation failed"
else
  union_out="$(suite_selection_select "$CORE_DIR/lint/$LINT_FIXTURE" "$CORE_DIR/$ZERO_REF_CANDIDATE")"
  if [ "$union_out" = "$SUITE_SELECTION_FULL_SWEEP_SENTINEL" ]; then
    pass "case3: one unmappable path among several escalates the whole multi-path call"
  else
    fail "case3: multi-path call with one unmappable path did not escalate" "$union_out"
  fi
fi

# =====================================================================================
# PART 2 -- run-all.sh's --only flag, against the REAL script directly (cheap: validation
# happens before any suite executes).
# =====================================================================================

# Case 4: invalid --only token exits 2, names the token, and runs nothing (no [RUN] line at all).
bad_token_out="$(bash "$RUN_ALL_SRC" --only "definitely-not-a-real-suite.sh" 2>&1)"
bad_token_rc=$?
if [ "$bad_token_rc" -eq 2 ] \
   && printf '%s\n' "$bad_token_out" | grep -q "definitely-not-a-real-suite.sh" \
   && ! printf '%s\n' "$bad_token_out" | grep -q '\[RUN\]'; then
  pass "case4: invalid --only token exits 2, names the token, runs no suite"
else
  fail "case4: invalid --only token did not refuse cleanly (rc=$bad_token_rc)" "$bad_token_out"
fi

# Case 4b: a mixed valid+invalid token list refuses the WHOLE run (no partial subset silently
# runs) -- picks one real, cheap, known-fast suite as the "valid" half.
mixed_out="$(bash "$RUN_ALL_SRC" --only "test-common-lib.sh,definitely-not-a-real-suite.sh" 2>&1)"
mixed_rc=$?
if [ "$mixed_rc" -eq 2 ] && ! printf '%s\n' "$mixed_out" | grep -q '\[RUN\]'; then
  pass "case4b: a mixed valid+invalid --only list refuses the whole run, not a partial subset"
else
  fail "case4b: mixed valid+invalid --only list did not refuse cleanly (rc=$mixed_rc)" "$mixed_out"
fi

# Case 4c: --only with an empty argument exits 2 with a named error.
empty_out="$(bash "$RUN_ALL_SRC" --only "" 2>&1)"
empty_rc=$?
if [ "$empty_rc" -eq 2 ] && printf '%s\n' "$empty_out" | grep -q "ERROR: --only"; then
  pass "case4c: --only with an empty argument exits 2 with a named error"
else
  fail "case4c: --only '' did not exit 2 with a named error (rc=$empty_rc)" "$empty_out"
fi

# =====================================================================================
# PART 3 -- run-all.sh's --only flag, against a SYNTHETIC fixture (mechanism parity: --jobs,
# the nested guard, LOAD_SENSITIVE_BASENAMES, TOTAL_ACCOUNTED, known-failures.txt, --timings).
# =====================================================================================

EXT_ROOT="$WORKDIR/exts"
TESTS_DIR="$EXT_ROOT/core/scripts/tests"
FLAT_DIR="$EXT_ROOT/core/scripts"
mkdir -p "$TESTS_DIR"
echo '{}' > "$EXT_ROOT/core/manifest.json"
cp "$RUN_ALL_SRC" "$TESTS_DIR/run-all.sh"
chmod +x "$TESTS_DIR/run-all.sh"
FIXTURE_RUNNER="$TESTS_DIR/run-all.sh"

cat > "$TESTS_DIR/test-fx-pass1.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$TESTS_DIR/test-fx-pass2.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$TESTS_DIR/test-fx-fail1.sh" << 'EOF'
#!/usr/bin/env bash
echo "deliberate fixture failure (registered in known-failures.txt)"
exit 1
EOF
cat > "$TESTS_DIR/test-fx-fail2.sh" << 'EOF'
#!/usr/bin/env bash
echo "deliberate fixture failure (NOT registered -- must classify NEW)"
exit 1
EOF
# Named EXACTLY one of run-all.sh's fixed LOAD_SENSITIVE_BASENAMES entries so is_load_sensitive()
# recognizes it inside this isolated fixture -- harmless here since the fixture never touches the
# real corpus's own test-run-all-parallel.sh.
cat > "$TESTS_DIR/test-run-all-parallel.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TESTS_DIR"/test-fx-pass1.sh "$TESTS_DIR"/test-fx-pass2.sh \
  "$TESTS_DIR"/test-fx-fail1.sh "$TESTS_DIR"/test-fx-fail2.sh "$TESTS_DIR"/test-run-all-parallel.sh

mkdir -p "$FLAT_DIR"
cat > "$FLAT_DIR/test-fx-flat1.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$FLAT_DIR/test-fx-flat1.sh"

cat > "$TESTS_DIR/known-failures.txt" << 'EOF'
# synthetic fixture known-failures manifest
test-fx-fail1.sh|real-defect|synthetic known failure for test-run-all-selection.sh|test-fixture
EOF

# 2 quick pass + 2 quick fail + 1 load-sensitive pass + 1 flat pass = 6 fixture suites total.
FIXTURE_TOTAL=6

# Case 5: no-flag behavior is unaffected by the new --only machinery -- the fixture's full-sweep
# tally line matches the exact expected counts/classification (2 EXPECTED+NEW split, 6 total).
noflag_out="$(bash "$FIXTURE_RUNNER" --quiet 2>&1)"
noflag_rc=$?
if [ "$noflag_rc" -eq 1 ] \
   && printf '%s\n' "$noflag_out" | grep -qF "4 passed, 2 failed (1 expected, 1 NEW), 0 skipped, 6 total"; then
  pass "case5: no-flag run's tally line matches expected pre-selection semantics exactly"
else
  fail "case5: no-flag run's tally line did not match expected semantics (rc=$noflag_rc)" "$noflag_out"
fi

# Case 6: --only selects exactly the given subset, preserving EXPECTED/NEW classification
# identically to the full run (test-fx-fail1.sh EXPECTED, test-fx-fail2.sh NEW).
TIMINGS_FILE="$WORKDIR/timings-case6.csv"
only_out="$(bash "$FIXTURE_RUNNER" --quiet --timings "$TIMINGS_FILE" --only "test-fx-pass1.sh,test-fx-fail1.sh,test-fx-fail2.sh" 2>&1)"
only_rc=$?
if [ "$only_rc" -eq 1 ] \
   && printf '%s\n' "$only_out" | grep -qF "1 passed, 2 failed (1 expected, 1 NEW), 0 skipped, 3 total"; then
  pass "case6: --only selects exactly the given 3-suite subset with identical EXPECTED/NEW classification"
else
  fail "case6: --only subset tally did not match expected (rc=$only_rc)" "$only_out"
fi

# Case 6b: --timings emits exactly one row per SELECTED suite plus the aggregate TOTAL row --
# never the full 6-suite discovered population.
if [ -f "$TIMINGS_FILE" ]; then
  timings_lines="$(wc -l < "$TIMINGS_FILE")"
  timings_suite_rows="$(grep -vc '^TOTAL,' "$TIMINGS_FILE")"
  if [ "$timings_lines" -eq 4 ] && [ "$timings_suite_rows" -eq 3 ]; then
    pass "case6b: --timings under selection emits exactly 3 suite rows + 1 TOTAL row (not all $FIXTURE_TOTAL discovered)"
  else
    fail "case6b: --timings row count under selection was wrong (expected 3 suite + 1 TOTAL, got $timings_suite_rows suite + $((timings_lines - timings_suite_rows)) other)" "$(cat "$TIMINGS_FILE")"
  fi
else
  fail "case6b: expected timings file $TIMINGS_FILE was not created"
fi

# Case 7: --only + --jobs 2 exercises the parallel path and TOTAL_ACCOUNTED cleanly (no
# "internal scheduling error" message, which is run-all.sh's own self-check for this).
jobs2_out="$(bash "$FIXTURE_RUNNER" --quiet --jobs 2 --only "test-fx-pass1.sh,test-fx-pass2.sh,test-run-all-parallel.sh" 2>&1)"
jobs2_rc=$?
# known-failures.txt exists in this fixture, so MANIFEST_PRESENT=true for every run against it --
# even an all-pass tally line carries the "(E expected, N NEW)" clause.
if [ "$jobs2_rc" -eq 0 ] \
   && printf '%s\n' "$jobs2_out" | grep -qF "3 passed, 0 failed (0 expected, 0 NEW), 0 skipped, 3 total" \
   && ! printf '%s\n' "$jobs2_out" | grep -q "internal scheduling error"; then
  pass "case7: --only + --jobs 2 runs cleanly with no TOTAL_ACCOUNTED scheduling error"
else
  fail "case7: --only + --jobs 2 did not run cleanly (rc=$jobs2_rc)" "$jobs2_out"
fi

# Case 8: a LOAD_SENSITIVE_BASENAMES member included in --only still runs alone, serially,
# before the parallel pool starts -- confirmed via the exact [RUN] annotation run-all.sh prints
# for a load-sensitive suite, even under selection.
loadsens_out="$(bash "$FIXTURE_RUNNER" --jobs 2 --only "test-fx-pass1.sh,test-run-all-parallel.sh" 2>&1)"
if printf '%s\n' "$loadsens_out" | grep -qF "[RUN]  $TESTS_DIR/test-run-all-parallel.sh (load-sensitive: serialized, not in the parallel pool)"; then
  pass "case8: a LOAD_SENSITIVE_BASENAMES member selected via --only still serializes ahead of the parallel pool"
else
  fail "case8: load-sensitive serialization annotation missing under --only + --jobs 2" "$loadsens_out"
fi

# Case 9: RUN_ALL_NESTED=1 still forces sequential under --only + --jobs N (same RELATIVE-ratio
# timing technique as test-run-all-parallel.sh's cases 3/4, applied under selection, using two
# deliberately slow fixture suites selected via --only).
for n in a b; do
  cat > "$TESTS_DIR/test-fx-slow-$n.sh" << 'EOF'
#!/usr/bin/env bash
sleep 0.4
exit 0
EOF
  chmod +x "$TESTS_DIR/test-fx-slow-$n.sh"
done

t0=$(date +%s%3N)
bash "$FIXTURE_RUNNER" --quiet --jobs 2 --only "test-fx-slow-a.sh,test-fx-slow-b.sh" >/dev/null 2>&1
t1=$(date +%s%3N)
only_parallel_ms=$((t1 - t0))

t0=$(date +%s%3N)
RUN_ALL_NESTED=1 bash "$FIXTURE_RUNNER" --quiet --jobs 2 --only "test-fx-slow-a.sh,test-fx-slow-b.sh" >/dev/null 2>&1
t1=$(date +%s%3N)
only_nested_ms=$((t1 - t0))

info "case9 timing: --only+parallel=${only_parallel_ms}ms --only+nested(forced-sequential)=${only_nested_ms}ms"

if [ "$only_nested_ms" -ge "$only_parallel_ms" ]; then
  pass "case9: RUN_ALL_NESTED=1 forces sequential (${only_nested_ms}ms) under --only, not faster than unguarded parallel (${only_parallel_ms}ms)"
else
  fail "case9: RUN_ALL_NESTED=1 (${only_nested_ms}ms) was FASTER than unguarded --only + --jobs 2 (${only_parallel_ms}ms) -- the nested guard may not compose with selection"
fi

echo ""
echo "==================================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "==================================================================="

[ "$FAILED" -eq 0 ] && exit 0 || exit 1
