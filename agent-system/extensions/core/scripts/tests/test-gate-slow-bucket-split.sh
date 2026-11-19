#!/usr/bin/env bash
# test-gate-slow-bucket-split.sh - Regression suite for the slow-cost-class gate split: gate 8
# narrowed to free/moderate/unknown, the new gate 31 covering exactly the slow bucket, with zero
# change to which suites run by default.
#
# Four cases, each deliberately cheap (no real suite execution beyond a fast --skip-slow path):
#   (a) Set equality at the GATE level: a direct replica of gate8_run/gate31_run's own
#       hints-file-driven slow/non-slow split (NOT suite_selection_by_cost_class's own
#       core-scoped "unknown" bucket, which is a real, pre-existing, and out-of-scope mismatch
#       against run-all.sh's cross-extension discovery -- see the case's own comment) covers
#       every REALLY-discovered suite (209 at implementation time) exactly once, read-only
#       against the real tree, no fixture needed.
#   (b) Hints-file-absent degradation: an isolated fixture with no suite-cost-hints.txt at all
#       -- free+moderate+unknown must cover every discovered suite (today's pre-split behavior,
#       preserved) and slow must cover none (a documented no-op, never a silent full run).
#   (c) --skip-slow defers both gate 8 and gate 31 -- cheap: the SKIP branch fires before any
#       run-all.sh invocation, so this case costs milliseconds, not minutes. Both gates skipping
#       trips verify-deploy.sh's own pre-existing zero-check-under-filter guard (exit 2,
#       "cannot attest"); this is the correct, by-design outcome, not a regression.
#   (d) --only-gate selects each gate independently: --only-gate 8 (skip-slow) shows gate 8's
#       own header only, and --only-gate 31 (skip-slow) shows gate 31's own header only -- no
#       cross-contamination between the two serialized gates' selection (same zero-check exit 2
#       as case (c), for the same reason).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
SRC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"
CORE_DIR="$SRC_DIR"
VERIFY_DEPLOY="$CORE_DIR/verify-deploy.sh"

for req in lib/suite-selection-lib.sh lib/common.sh verify-deploy.sh gate-registry.data; do
  if [ ! -f "$SRC_DIR/$req" ]; then
    echo "ERROR: expected $req alongside this suite's sibling scripts dir ($SRC_DIR)" >&2
    exit 2
  fi
done

PASSED=0
FAILED=0

# --- Case (a): set equality at the GATE level, against the REAL tree, read-only --------------
# NOTE: this deliberately does NOT test suite_selection_by_cost_class's own free/moderate/slow/
# unknown classification for cross-extension set equality against the real tree -- that
# library's own `unknown` bucket is documented (and confirmed live) to be core-extension-scoped
# only, a real and PRE-EXISTING mismatch against run-all.sh's own cross-extension discovery (209
# real suites vs. 178 core-only vs. 156 hints-file rows, measured at implementation time) that
# this task does not own (territory edge 650 owns suite-selection-lib.sh's discovery scope).
# gate8_run/gate31_run do NOT call suite_selection_by_cost_class for their own slow/non-slow
# split for exactly this reason -- see verify-deploy.sh's own "WHY --only <everything minus
# slow> HERE" comment in gate8_run. This case instead proves the GATE-LEVEL mechanism those two
# functions actually use: a direct hints-file parse (>= the moderate threshold -> slow) plus a
# direct replica of run-all.sh's own two-location discovery walk, exactly as gate8_run/gate31_run
# perform it -- read-only, no fixture needed.
_SSL_MODERATE_MS="$(grep -oE '^SUITE_SELECTION_COST_MODERATE_MS=[0-9]+' "$SRC_DIR/lib/suite-selection-lib.sh" | head -n1 | cut -d= -f2)"
[ -z "$_SSL_MODERATE_MS" ] && _SSL_MODERATE_MS=30000
_HINTS_FILE="$SRC_DIR/tests/suite-cost-hints.txt"
mapfile -t _real_slow < <(
  if [ -f "$_HINTS_FILE" ]; then
    while IFS=, read -r _h_base _h_ms; do
      [ -n "$_h_base" ] || continue
      case "$_h_base" in \#*) continue ;; esac
      [ -n "$_h_ms" ] && [ "$_h_ms" -ge "$_SSL_MODERATE_MS" ] 2>/dev/null && echo "$_h_base"
    done < "$_HINTS_FILE"
  fi | sort -u
)
_EXT_ROOT="$(cd "$SRC_DIR/../.." && pwd)"
mapfile -t _real_all < <(
  for _e_dir in "$_EXT_ROOT"/*/; do
    _e_scripts="${_e_dir}scripts"
    [ -d "$_e_scripts" ] || continue
    if [ -d "$_e_scripts/tests" ]; then
      for _e_f in "$_e_scripts/tests"/test-*.sh; do [ -e "$_e_f" ] && basename "$_e_f"; done
    fi
    for _e_f in "$_e_scripts"/test-*.sh; do [ -e "$_e_f" ] && basename "$_e_f"; done
  done | sort -u
)
mapfile -t _real_nonslow < <(comm -23 <(printf '%s\n' "${_real_all[@]}") <(printf '%s\n' "${_real_slow[@]}"))
_real_union_n="$(printf '%s\n' "${_real_slow[@]}" "${_real_nonslow[@]}" | sort -u | wc -l)"
if [ "${#_real_all[@]}" -gt 0 ] && [ "$_real_union_n" -eq "${#_real_all[@]}" ]; then
  common_test_pass "case(a): slow ∪ non-slow (as gate8_run/gate31_run compute them) covers exactly the ${#_real_all[@]} really-discovered suites"
else
  common_test_fail "case(a): slow+nonslow union (${_real_union_n}) != real discovered total (${#_real_all[@]})"
fi
_sum_n=$(( ${#_real_slow[@]} + ${#_real_nonslow[@]} ))
if [ "$_sum_n" -eq "${#_real_all[@]}" ]; then
  common_test_pass "case(a): slow and non-slow are mutually exclusive (no suite double-counted, sum=${_sum_n})"
else
  common_test_fail "case(a): slow/non-slow overlap (sum=${_sum_n}, union=${#_real_all[@]})"
fi

# --- Case (b): hints-file-absent degradation, isolated fixture -------------------------------
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/gate-slow-bucket-split-test.XXXXXX")"
cleanup() { [ -n "${TMPROOT:-}" ] && [ -d "$TMPROOT" ] && rm -rf "$TMPROOT"; }
trap cleanup EXIT

mkdir -p "$TMPROOT/scripts/lib" "$TMPROOT/scripts/tests"
cp "$SRC_DIR/lib/suite-selection-lib.sh" "$TMPROOT/scripts/lib/suite-selection-lib.sh"
# A handful of empty stub suites -- basenames only matter for this discovery-and-bucket check;
# no suite content is ever executed. Deliberately NO suite-cost-hints.txt in this fixture.
for stub in test-alpha.sh test-beta.sh test-gamma.sh; do
  : > "$TMPROOT/scripts/tests/$stub"
done

(
  # shellcheck source=/dev/null
  source "$TMPROOT/scripts/lib/suite-selection-lib.sh"
  mapfile -t _fx_all < <(_ssl_discovered_basenames | sort -u)
  mapfile -t _fx_fmu < <(suite_selection_by_cost_class "free,moderate,unknown" | sort -u)
  mapfile -t _fx_slow < <(suite_selection_by_cost_class "slow" | sort -u)
  if [ "${#_fx_all[@]}" -eq 3 ] && [ "$(printf '%s\n' "${_fx_all[@]}")" = "$(printf '%s\n' "${_fx_fmu[@]}")" ]; then
    echo "PASS:case(b)-fmu"
  else
    echo "FAIL:case(b)-fmu:${#_fx_all[@]}:${#_fx_fmu[@]}"
  fi
  if [ "${#_fx_slow[@]}" -eq 0 ]; then
    echo "PASS:case(b)-slow-empty"
  else
    echo "FAIL:case(b)-slow-empty:${#_fx_slow[@]}"
  fi
) > "$TMPROOT/fixture-result.txt" 2>&1

if grep -q '^PASS:case(b)-fmu' "$TMPROOT/fixture-result.txt"; then
  common_test_pass "case(b): with no hints file, free+moderate+unknown covers every discovered suite (today's pre-split behavior, preserved)"
else
  common_test_fail "case(b): hints-absent fmu degradation failed" "$(cat "$TMPROOT/fixture-result.txt")"
fi
if grep -q '^PASS:case(b)-slow-empty' "$TMPROOT/fixture-result.txt"; then
  common_test_pass "case(b): with no hints file, slow covers zero suites (documented no-op, never a silent full run)"
else
  common_test_fail "case(b): hints-absent slow degradation failed" "$(cat "$TMPROOT/fixture-result.txt")"
fi

# --- Case (c): --skip-slow defers both gate 8 and gate 31 (cheap: SKIP branch, no real run) ---
# Deliberately WITHOUT --quiet: --skip-slow on an --only-gate selection whose every selected
# gate SKIPs trips verify-deploy.sh's own PRE-EXISTING "cannot attest: ... 0 check(s) ran"
# zero-check-under-filter guard (exit 2) -- a correct, by-design refusal to certify a run that
# verified nothing, not a defect this task introduces (the same guard fires identically for
# --skip-slow --only-gate 8 alone, before this task's own gate 31 existed). The header/SKIP
# lines this case actually checks for are printed before that guard's own final exit, so they
# are still observable in the captured output; --quiet would additionally suppress them.
skip_out="$(bash "$VERIFY_DEPLOY" --skip-slow --only-gate 8,31 "$REPO_ROOT" 2>&1)"
skip_rc=$?
if echo "$skip_out" | grep -q "8\. Shell test suite runner" && echo "$skip_out" | grep -q "31\. Slow cost-class shell suites"; then
  common_test_pass "case(c): --only-gate 8,31 shows both gate headers"
else
  common_test_fail "case(c): expected both gate 8 and gate 31 headers" "$skip_out"
fi
_skip_count="$(printf '%s\n' "$skip_out" | grep -c '\[SKIP\] --skip-slow')"
if [ "$_skip_count" -eq 2 ]; then
  common_test_pass "case(c): --skip-slow defers both gate 8 and gate 31 (2 SKIP lines)"
else
  common_test_fail "case(c): expected 2 --skip-slow SKIP lines, got $_skip_count" "$skip_out"
fi
if [ "$skip_rc" -eq 2 ] && echo "$skip_out" | grep -q "cannot attest"; then
  common_test_pass "case(c): both-skipped selection correctly refuses to attest (exit 2, pre-existing zero-check-under-filter guard, not a regression)"
else
  common_test_fail "case(c): expected exit 2 with a 'cannot attest' line, got rc=$skip_rc" "$skip_out"
fi

# --- Case (d): --only-gate selects each gate independently (cheap: --skip-slow, header-only) -
# Same "cannot attest" exit-2 expectation as case (c) above, for the same pre-existing reason --
# a single skipped gate under --only-gate is still a zero-check selection.
only8_out="$(bash "$VERIFY_DEPLOY" --skip-slow --only-gate 8 "$REPO_ROOT" 2>&1)"
only8_rc=$?
if echo "$only8_out" | grep -q "8\. Shell test suite runner" && ! echo "$only8_out" | grep -q "31\. Slow cost-class shell suites" && [ "$only8_rc" -eq 2 ]; then
  common_test_pass "case(d): --only-gate 8 shows gate 8's header only, not gate 31's (exit 2, zero-check guard)"
else
  common_test_fail "case(d): --only-gate 8 cross-contaminated with gate 31, or unexpected exit ($only8_rc)" "$only8_out"
fi
only31_out="$(bash "$VERIFY_DEPLOY" --skip-slow --only-gate 31 "$REPO_ROOT" 2>&1)"
only31_rc=$?
if echo "$only31_out" | grep -q "31\. Slow cost-class shell suites" && ! echo "$only31_out" | grep -q "8\. Shell test suite runner" && [ "$only31_rc" -eq 2 ]; then
  common_test_pass "case(d): --only-gate 31 shows gate 31's header only, not gate 8's (exit 2, zero-check guard)"
else
  common_test_fail "case(d): --only-gate 31 cross-contaminated with gate 8, or unexpected exit ($only31_rc)" "$only31_out"
fi

echo ""
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
