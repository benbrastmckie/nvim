#!/usr/bin/env bash
# test-gate-contention-tagging.sh - Regression suite for generalized contention tagging
# (gate-ceiling-fit Phase 6): a load-correlated timeout kill is tagged `[CONTENTION]` as a
# non-blocking WARN-FINDING, for ANY gate, never only gate 8, and never changes the gate's own
# pass/fail verdict.
#
# Fixture: `gate_store_fixture_build` (already proven by test-gate-registry-resolution.sh's
# case35-39) builds a path-mirrored, throwaway copy of verify-deploy.sh + lib/ + lint/ +
# gate-registry.data with one extra synthetic gate appended -- this suite post-edits that one
# appended row/function (timeout_s 30 -> 1, body replaced with a deliberate stall) rather than
# rebuilding the scaffold from scratch. Load is injected deterministically via
# GREG_LOADAVG_OVERRIDE (lib/gate-registry-lib.sh's own test-only hook), never this host's real
# ambient load -- the whole point is a result independent of host contention.
#
# Four cases: a killed gate tags [CONTENTION] under seeded high load; a killed gate does NOT tag
# under seeded low load; the tag never changes the gate's own FAIL verdict or exit status; and
# gate 8's own pre-existing, independent annotation path is untouched by this generalization
# (confirmed by code-presence, not re-run -- test-gate-lock.sh already owns gate 8's own
# live-contention behavior).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GSF_LIB="$CORE_DIR/lib/gate-store-fixture-lib.sh"

if [ ! -f "$GSF_LIB" ]; then
  echo "ERROR: expected $GSF_LIB" >&2
  exit 2
fi
# shellcheck source=../lib/gate-store-fixture-lib.sh
source "$GSF_LIB"

PASSED=0
FAILED=0

common_test_workdir_init
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

build_stalling_fixture() {
  # Usage: build_stalling_fixture <dest_root_suffix> -> prints the copied verify-deploy.sh path
  local dest_root="$WORKDIR/$1"
  local extra_id=901
  local vd_copy data_copy lib_copy
  vd_copy="$(gate_store_fixture_build "$dest_root" "$extra_id" "Stalling contention probe")" || return 1
  data_copy="$(dirname "$vd_copy")/gate-registry.data"
  lib_copy="$(dirname "$vd_copy")/lib/gate-registry-lib.sh"

  # Shorten the appended row's timeout_s from 30 to 1 (TAB-separated field 6) -- this suite's
  # whole point is a cheap, fast kill, not a real 30s wait.
  awk -F'\t' -v OFS='\t' -v id="$extra_id" '{ if ($1 == id) { $6 = "1" }; print }' "$data_copy" > "$data_copy.tmp"
  mv "$data_copy.tmp" "$data_copy"

  # Replace the generated always-passing body (`pass "... (fixture)"`) with a deliberate stall,
  # in BOTH copies (gate-store-fixture-lib.sh's own header explains why the function is
  # duplicated into verify-deploy.sh's own text: lint-gate-registry.sh's Check A greps
  # verify-deploy.sh's text only).
  sed -i 's/^pass "Stalling contention probe (fixture)"$/sleep 30/' "$lib_copy" "$vd_copy"

  echo "$vd_copy"
}

run_fixture() {
  # Usage: run_fixture <verify_deploy_path> <loadavg_override>
  # TARGET is the REAL repo root (a real .claude/ deploy tree + agent-system/extensions),
  # mirroring test-gate-registry-resolution.sh's own case36/37 convention: the fixture's job is
  # only to supply an ALTERNATE verify-deploy.sh + gate-registry.data (with the one extra gate
  # appended), not an alternate TARGET.
  local vd="$1" load="$2"
  GREG_LOADAVG_OVERRIDE="$load" bash "$vd" --findings --jobs 1 --only-gate 901 --quiet "$REPO_ROOT" 2>&1
}

# --- Case 1: a killed gate tags [CONTENTION] under seeded high load (>= the 2.0 default) -----
VD1="$(build_stalling_fixture fixture1)"
out1="$(run_fixture "$VD1" "5.0")"; rc1=$?
if echo "$out1" | grep -q "\[CONTENTION\] gate901:"; then
  common_test_pass "case1: a killed gate tags [CONTENTION] under seeded high load (5.0 >= 2.0)"
else
  common_test_fail "case1: expected a [CONTENTION] gate901 line under high load" "$out1"
fi
if echo "$out1" | grep -q "^FINDING gate901 TIMEOUT:"; then
  common_test_pass "case1: the real TIMEOUT FINDING is still present alongside the annotation"
else
  common_test_fail "case1: expected the real TIMEOUT FINDING to still be present" "$out1"
fi

# --- Case 2: a killed gate does NOT tag under seeded low load (well under 2.0) ---------------
VD2="$(build_stalling_fixture fixture2)"
out2="$(run_fixture "$VD2" "0.1")"; rc2=$?
if ! echo "$out2" | grep -q "\[CONTENTION\]"; then
  common_test_pass "case2: a killed gate does NOT tag [CONTENTION] under seeded low load (0.1 < 2.0)"
else
  common_test_fail "case2: unexpected [CONTENTION] tag under low load" "$out2"
fi
if echo "$out2" | grep -q "^FINDING gate901 TIMEOUT:"; then
  common_test_pass "case2: the real TIMEOUT FINDING is still present without the annotation"
else
  common_test_fail "case2: expected the real TIMEOUT FINDING to still be present" "$out2"
fi

# --- Case 3: the tag never changes the gate's own verdict/exit status ------------------------
if [ "$rc1" -eq "$rc2" ] && [ "$rc1" -eq 1 ]; then
  common_test_pass "case3: identical exit status (1, a real FAIL) with and without the [CONTENTION] annotation"
else
  common_test_fail "case3: exit status diverged between the tagged and untagged runs (rc1=$rc1, rc2=$rc2) or was not the expected FAIL (1)"
fi
checks1="$(echo "$out1" | grep -oE 'FAIL -- [0-9]+ of [0-9]+ check' | head -n1)"
checks2="$(echo "$out2" | grep -oE 'FAIL -- [0-9]+ of [0-9]+ check' | head -n1)"
if [ -n "$checks1" ] && [ "$checks1" = "$checks2" ]; then
  common_test_pass "case3: identical check tally ('$checks1') with and without the annotation -- CHECKS/FAILURES untouched by the tag"
else
  common_test_fail "case3: check tally diverged ('$checks1' vs '$checks2')"
fi

# --- Case 4b: the SAME tagging works under the concurrent pool path (--jobs > 1), exercising
# _greg_pool_job's own entryload.$id/killload.$id file writes -- Cases 1-3 above only exercised
# the sequential path's direct _greg_load_1min calls, a structurally different code path. -----
VD4b="$(build_stalling_fixture fixture4b)"
out4b="$(GREG_LOADAVG_OVERRIDE=5.0 bash "$VD4b" --findings --jobs 2 --only-gate 901 --quiet "$REPO_ROOT" 2>&1)"
if echo "$out4b" | grep -q "\[CONTENTION\] gate901:" && echo "$out4b" | grep -q "^FINDING gate901 TIMEOUT:"; then
  common_test_pass "case4b: the concurrent-pool path (--jobs 2) tags [CONTENTION] identically to the sequential path"
else
  common_test_fail "case4b: expected a [CONTENTION] gate901 line and the TIMEOUT FINDING under --jobs 2" "$out4b"
fi

# --- Case 4: gate 8's own pre-existing, independent annotation path is untouched -------------
# Code-presence check only (live re-exercise is test-gate-lock.sh's own job, already covering
# gate 8's real contention behavior) -- confirms this generalization did not remove or rename
# gate 8's own bespoke GATE8_CONTENTION_DETECTED/_gate8_load_1min mechanism while adding the
# generic one.
if grep -q "GATE8_CONTENTION_DETECTED" "$CORE_DIR/verify-deploy.sh" && grep -q "_gate8_load_1min" "$CORE_DIR/verify-deploy.sh"; then
  common_test_pass "case4: gate 8's own pre-existing contention-detection code is still present, unremoved by this generalization"
else
  common_test_fail "case4: gate 8's own pre-existing contention-detection code appears to have been removed"
fi

echo ""
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
