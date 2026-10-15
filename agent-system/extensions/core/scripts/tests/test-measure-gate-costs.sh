#!/usr/bin/env bash
# test-measure-gate-costs.sh - Regression suite for scripts/measure-gate-costs.sh, the
# mechanical, idle-guarded, averaged per-gate cost measurement harness this task's Phase 3
# decision gate depends on. See that script's own header for the full contract.
#
# Coverage:
#   - The load guard refuses (exit 2, loud, observed load printed) when the 1-minute load
#     average is above threshold, and proceeds normally when it is not -- both branches
#     exercised deterministically via the MEASURE_GATE_COSTS_LOADAVG_OVERRIDE test-only hook,
#     never by depending on this test host's own ambient load.
#   - Multi-run averaging: a fake verify-deploy.sh stub with a controlled, varying sleep
#     produces the correct arithmetic mean in the output CSV's avg_ms column.
#   - --runs rejects fewer than 2 (a single sample cannot distinguish a real cost from a
#     one-off hiccup).
#   - The unhinted-suite append invariant for --regen-hints: every suite a synthetic run-all.sh
#     fixture discovers appears in the regenerated hints file exactly once, with no suite
#     dropped, duplicated, or silently reordered away, and a SKIPped suite is omitted (a 0ms
#     "cost" for a suite that did not run would misinform scheduling).
#   - Usage errors: unknown flag, missing --target/--runs/--load-threshold argument values.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (the
# SUT was not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SUT="$CORE_DIR/measure-gate-costs.sh"

if [ ! -f "$SUT" ]; then
  echo "ERROR: expected $SUT" >&2
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

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# PART 1 -- load guard, against the REAL script (cheap: the guard fires before any gate runs).
# ═══════════════════════════════════════════════════════════════════════════════════════════════

# Case 1: an overridden load far above any sane threshold refuses, loudly, naming the observed
# load and the threshold, with exit 2 -- and writes NO output file.
out1="$(MEASURE_GATE_COSTS_LOADAVG_OVERRIDE=99.0 bash "$SUT" --gate 1 --runs 2 --out "$WORKDIR/case1.csv" 2>&1)"
rc1=$?
if [ "$rc1" -eq 2 ] && echo "$out1" | grep -q "REFUSING" && echo "$out1" | grep -q "99.0" \
   && [ ! -f "$WORKDIR/case1.csv" ]; then
  pass "case1: load guard refuses (exit 2) at an overridden load far above threshold, writes no output"
else
  fail "case1: load guard did not refuse as expected (rc=$rc1)" "$out1"
fi

# Case 2: an overridden load clearly below the default threshold proceeds and writes output
# (using --gate with a fast, always-present gate so this stays cheap).
out2="$(MEASURE_GATE_COSTS_LOADAVG_OVERRIDE=0.1 bash "$SUT" --gate 15 --runs 2 --out "$WORKDIR/case2.csv" 2>&1)"
rc2=$?
if [ "$rc2" -eq 0 ] && echo "$out2" | grep -q "load guard OK" && [ -f "$WORKDIR/case2.csv" ]; then
  pass "case2: load guard proceeds (exit 0) at an overridden load below threshold, writes output"
else
  fail "case2: expected load guard to proceed and write output (rc=$rc2)" "$out2"
fi

# Case 3: --load-threshold overrides the default -- an overridden load of 5.0 refuses against the
# default 2.0 threshold (case 1 already showed this) but PASSES once --load-threshold 10 is given.
out3="$(MEASURE_GATE_COSTS_LOADAVG_OVERRIDE=5.0 bash "$SUT" --gate 15 --runs 2 --load-threshold 10 --out "$WORKDIR/case3.csv" 2>&1)"
rc3=$?
if [ "$rc3" -eq 0 ] && [ -f "$WORKDIR/case3.csv" ]; then
  pass "case3: --load-threshold raises the ceiling and the same load that refused in case1 now passes"
else
  fail "case3: --load-threshold did not raise the ceiling as expected (rc=$rc3)" "$out3"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# PART 2 -- usage errors.
# ═══════════════════════════════════════════════════════════════════════════════════════════════

# Case 4: --runs below 2 is refused (a single sample cannot distinguish cost from noise).
out4="$(bash "$SUT" --runs 1 --gate 1 2>&1)"; rc4=$?
if [ "$rc4" -eq 2 ] && echo "$out4" | grep -qi "at least 2"; then
  pass "case4: --runs 1 is refused with a clear message"
else
  fail "case4: expected --runs 1 to be refused (rc=$rc4)" "$out4"
fi

# Case 5: an unknown flag is refused.
out5="$(bash "$SUT" --not-a-real-flag 2>&1)"; rc5=$?
if [ "$rc5" -eq 2 ] && echo "$out5" | grep -qi "unknown argument"; then
  pass "case5: an unknown flag is refused with a clear message"
else
  fail "case5: expected an unknown flag to be refused (rc=$rc5)" "$out5"
fi

# Case 6: --gate with a non-numeric id is refused.
out6="$(bash "$SUT" --gate "not-a-number" --load-threshold 99 2>&1)"; rc6=$?
if [ "$rc6" -eq 2 ] && echo "$out6" | grep -qi "invalid gate id"; then
  pass "case6: a non-numeric --gate value is refused"
else
  fail "case6: expected a non-numeric --gate value to be refused (rc=$rc6)" "$out6"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# PART 3 -- multi-run averaging, against a SYNTHETIC verify-deploy.sh stub swapped in at runtime
# via a fixture directory shaped exactly like the real scripts/ layout (measure-gate-costs.sh
# resolves VERIFY_DEPLOY relative to its OWN location, so the fixture copies the SUT alongside a
# controllable fake verify-deploy.sh rather than trying to stub the real one in place).
# ═══════════════════════════════════════════════════════════════════════════════════════════════

FIXTURE="$WORKDIR/fixture/scripts"
mkdir -p "$FIXTURE/lib" "$FIXTURE/tests"
cp "$SUT" "$FIXTURE/measure-gate-costs.sh"
cp "$CORE_DIR/lib/common.sh" "$FIXTURE/lib/common.sh"
chmod +x "$FIXTURE/measure-gate-costs.sh"

# A deterministic fake verify-deploy.sh: sleeps a controlled amount keyed to a counter file, so
# two successive runs produce two DIFFERENT, known wall times whose mean is independently
# computable by this test (avoiding a flaky "roughly equal" assertion against real sleep jitter
# by using sleep amounts far enough apart that scheduling noise cannot bridge them).
cat > "$FIXTURE/verify-deploy.sh" << 'EOF'
#!/usr/bin/env bash
marker="${TMPDIR:-/tmp}/mgc-fake-verify-counter"
count=0
[ -f "$marker" ] && count=$(cat "$marker")
count=$((count + 1))
echo "$count" > "$marker"
if [ "$count" -eq 1 ]; then
  sleep 0.2
else
  sleep 0.5
fi
exit 0
EOF
chmod +x "$FIXTURE/verify-deploy.sh"
rm -f "${TMPDIR:-/tmp}/mgc-fake-verify-counter"

avg_out="$WORKDIR/avg-case.csv"
bash "$FIXTURE/measure-gate-costs.sh" --gate 1 --runs 2 --load-threshold 999 --out "$avg_out" >/dev/null 2>&1
if [ -f "$avg_out" ]; then
  data_row="$(grep '^gate1,' "$avg_out")"
  # New column shape (this task's Phase 1 hardening): gate_id,run1_ms,run1_load,run2_ms,
  # run2_load,avg_ms,cost_class,valid -- run_ms and run_load now interleave, so avg_ms moved
  # from field 4 to field 6.
  run1="$(echo "$data_row" | cut -d',' -f2)"
  run2="$(echo "$data_row" | cut -d',' -f4)"
  avg="$(echo "$data_row" | cut -d',' -f6)"
  expected_avg=$(( (run1 + run2) / 2 ))
  # Sanity bounds: run1 should be roughly 200ms, run2 roughly 500ms (sleep-dominated, with
  # generous slack for scheduling jitter on a shared CI-like host).
  if [ "$run1" -ge 150 ] && [ "$run1" -le 1000 ] && [ "$run2" -ge 400 ] && [ "$run2" -le 1500 ] \
     && [ "$avg" -eq "$expected_avg" ]; then
    pass "case7: multi-run averaging computes the correct arithmetic mean (run1=${run1}ms run2=${run2}ms avg=${avg}ms)"
  else
    fail "case7: averaging produced unexpected values (run1=$run1 run2=$run2 avg=$avg expected_avg=$expected_avg)" "$data_row"
  fi
else
  fail "case7: expected output file $avg_out was not written"
fi
rm -f "${TMPDIR:-/tmp}/mgc-fake-verify-counter"

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# PART 4 -- the unhinted-suite append invariant for --regen-hints, against a SYNTHETIC
# tests/run-all.sh fixture (the real run-all.sh copied into the fixture tree, with a handful of
# tiny fixture suites -- mirrors test-run-all-selection.sh's own fixture convention).
# ═══════════════════════════════════════════════════════════════════════════════════════════════

RUN_ALL_SRC="$CORE_DIR/tests/run-all.sh"
if [ -f "$RUN_ALL_SRC" ]; then
  cp "$RUN_ALL_SRC" "$FIXTURE/tests/run-all.sh"
  chmod +x "$FIXTURE/tests/run-all.sh"

  cat > "$FIXTURE/tests/test-fx-fast1.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat > "$FIXTURE/tests/test-fx-fast2.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat > "$FIXTURE/tests/test-fx-fail.sh" << 'EOF'
#!/usr/bin/env bash
echo "deliberate fixture failure"
exit 1
EOF
  # Deliberately non-executable, to confirm the SKIP path is correctly excluded from the
  # regenerated hints file rather than contributing a misleading 0ms row.
  cat > "$FIXTURE/tests/test-fx-skip.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$FIXTURE/tests/test-fx-fast1.sh" "$FIXTURE/tests/test-fx-fast2.sh" "$FIXTURE/tests/test-fx-fail.sh"
  chmod -x "$FIXTURE/tests/test-fx-skip.sh"

  hints_out="$WORKDIR/hints-case.txt"
  (cd "$WORKDIR" && bash "$FIXTURE/measure-gate-costs.sh" --skip-gate-measure --regen-hints "$hints_out" \
    --load-threshold 999 --target "$WORKDIR/fixture" >/dev/null 2>&1)

  if [ -f "$hints_out" ]; then
    n_fast1=$(grep -c '^test-fx-fast1\.sh,' "$hints_out")
    n_fast2=$(grep -c '^test-fx-fast2\.sh,' "$hints_out")
    n_fail=$(grep -c '^test-fx-fail\.sh,' "$hints_out")
    n_skip=$(grep -c '^test-fx-skip\.sh,' "$hints_out")
    if [ "$n_fast1" -eq 1 ] && [ "$n_fast2" -eq 1 ] && [ "$n_fail" -eq 1 ] && [ "$n_skip" -eq 0 ]; then
      pass "case8: every discovered non-skipped suite appears exactly once in the regenerated hints file, SKIPped suite omitted"
    else
      fail "case8: unhinted-suite append invariant violated (fast1=$n_fast1 fast2=$n_fast2 fail=$n_fail skip=$n_skip, expected 1/1/1/0)" "$(cat "$hints_out")"
    fi
  else
    fail "case8: expected hints output file $hints_out was not written"
  fi
else
  info "case8 skipped: real tests/run-all.sh not found at $RUN_ALL_SRC (unexpected in this repo, but non-fatal for this suite's own PASS/FAIL tally)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# PART 5 -- mid-run contamination marking and overwrite protection (this task's Phase 1
# hardening). Uses the MEASURE_GATE_COSTS_LOADAVG_SEQUENCE/_SEQFILE test-only seam, which the
# static OVERRIDE hook from Part 1 cannot exercise: that hook returns one value for the whole
# run, so it cannot simulate load that is clean at the START of a gate's measurement and rises
# DURING it -- exactly the gap that caused a real contaminated sample (load 1.46 at the start,
# an unrelated sibling build driving it to ~27 mid-flight) to be written and trusted as if clean.
# ═══════════════════════════════════════════════════════════════════════════════════════════════

seqfile9="$WORKDIR/seq9-idx"
out9="$WORKDIR/case9.csv"
rm -f "$seqfile9"
# Sequence: pre-guard clean (0.1), run1-end clean (0.1), run2-end CONTAMINATED (5.0), then the
# repeated tail value (5.0) covers the final post-measurement guard call.
MEASURE_GATE_COSTS_LOADAVG_SEQFILE="$seqfile9" MEASURE_GATE_COSTS_LOADAVG_SEQUENCE="0.1,0.1,5.0,5.0" \
  bash "$SUT" --gate 15 --runs 2 --out "$out9" >/dev/null 2>&1
rc9=$?
if [ -f "$out9" ] && grep -qE '^# ALL_VALID=false$' "$out9" \
   && grep '^gate15,' "$out9" | grep -qE ',0$' && [ "$rc9" -eq 0 ]; then
  pass "case9: a load rise captured mid-run (not only at start/end) marks the row 'valid' column 0 and the file's ALL_VALID header false, with no prior clean artifact to protect (exit 0)"
else
  fail "case9: expected ALL_VALID=false and a 0 valid column after a simulated mid-run rise (rc=$rc9)" "$(cat "$out9" 2>&1)"
fi
rm -f "$seqfile9"

# Case 10: a fully clean run (every captured load below threshold) marks the row AND the file
# valid -- the negative of case 9, proving the marking isn't trivially always-false.
out10="$WORKDIR/case10.csv"
MEASURE_GATE_COSTS_LOADAVG_OVERRIDE=0.1 bash "$SUT" --gate 15 --runs 2 --out "$out10" >/dev/null 2>&1
if [ -f "$out10" ] && grep -qE '^# ALL_VALID=true$' "$out10" && grep '^gate15,' "$out10" | grep -qE ',1$'; then
  pass "case10: a clean run (every per-run load below threshold) marks ALL_VALID=true and the row's valid column 1"
else
  fail "case10: expected ALL_VALID=true and a 1 valid column for a clean run" "$(cat "$out10" 2>&1)"
fi

# Case 11: overwrite protection -- a contaminated run must NEVER replace a previously
# ALL_VALID=true artifact. Start from case10's clean file (ALL_VALID=true), then run a
# contaminated measurement against the SAME --out path and assert: (a) exit 2, (b) the original
# file's bytes are completely unchanged, (c) a sibling ".contaminated-<timestamp>" file exists
# and itself carries ALL_VALID=false, (d) the original file still reads back ALL_VALID=true.
out11="$out10"
sum_before="$(md5sum "$out11" | awk '{print $1}')"
seqfile11="$WORKDIR/seq11-idx"
rm -f "$seqfile11"
err11="$(MEASURE_GATE_COSTS_LOADAVG_SEQFILE="$seqfile11" MEASURE_GATE_COSTS_LOADAVG_SEQUENCE="0.1,0.1,5.0,5.0" \
  bash "$SUT" --gate 15 --runs 2 --out "$out11" 2>&1)"
rc11=$?
sum_after="$(md5sum "$out11" | awk '{print $1}')"
side_count=$(find "$WORKDIR" -maxdepth 1 -name "$(basename "$out11").contaminated-*" | wc -l)
side_file="$(find "$WORKDIR" -maxdepth 1 -name "$(basename "$out11").contaminated-*" | head -1)"
if [ "$rc11" -eq 2 ] && [ "$sum_before" = "$sum_after" ] && [ "$side_count" -ge 1 ] \
   && echo "$err11" | grep -q "REFUSING to overwrite previously-clean" \
   && [ -n "$side_file" ] && grep -qE '^# ALL_VALID=false$' "$side_file" \
   && grep -qE '^# ALL_VALID=true$' "$out11"; then
  pass "case11: a contaminated run is refused from overwriting a previously-clean artifact (exit 2, byte-identical original, contaminated data diverted to a sibling file)"
else
  fail "case11: overwrite protection did not behave as expected (rc=$rc11, same_bytes=$([ "$sum_before" = "$sum_after" ] && echo yes || echo no), side_count=$side_count)" "$err11"
fi
rm -f "$seqfile11"

# Case 12: --regen-hints carries the identical treatment -- a per-invocation load capture (one
# per --runs iteration, not only once before/after the whole regen pass) feeds an ALL_VALID
# header on suite-cost-hints.txt, and the same overwrite protection applies. Reuses the Part 4
# fixture tree (tiny, fast fixture suites) so this stays cheap.
if [ -f "$RUN_ALL_SRC" ]; then
  hints12_clean="$WORKDIR/hints12.txt"
  MEASURE_GATE_COSTS_LOADAVG_OVERRIDE=0.1 bash "$FIXTURE/measure-gate-costs.sh" --skip-gate-measure \
    --regen-hints "$hints12_clean" --load-threshold 999 --target "$WORKDIR/fixture" >/dev/null 2>&1
  seqfile12="$WORKDIR/seq12-idx"
  rm -f "$seqfile12"
  sum12_before="$(md5sum "$hints12_clean" 2>/dev/null | awk '{print $1}')"
  err12="$(MEASURE_GATE_COSTS_LOADAVG_SEQFILE="$seqfile12" MEASURE_GATE_COSTS_LOADAVG_SEQUENCE="0.1,5.0" \
    bash "$FIXTURE/measure-gate-costs.sh" --skip-gate-measure --regen-hints "$hints12_clean" \
    --load-threshold 2.0 --target "$WORKDIR/fixture" 2>&1)"
  rc12=$?
  sum12_after="$(md5sum "$hints12_clean" 2>/dev/null | awk '{print $1}')"
  side12_count=$(find "$WORKDIR" -maxdepth 1 -name "$(basename "$hints12_clean").contaminated-*" | wc -l)
  if [ -f "$hints12_clean" ] && grep -qE '^# ALL_VALID=true$' <<< "$(head -30 "$hints12_clean")" \
     && [ "$rc12" -eq 2 ] && [ "$sum12_before" = "$sum12_after" ] && [ "$side12_count" -ge 1 ]; then
    pass "case12: --regen-hints applies the identical per-invocation ALL_VALID marking and overwrite protection as the gate-cost CSV"
  else
    fail "case12: --regen-hints validity/overwrite-protection treatment did not behave as expected (rc=$rc12, side_count=$side12_count)" "$err12"
  fi
  rm -f "$seqfile12"
else
  info "case12 skipped: real tests/run-all.sh not found at $RUN_ALL_SRC"
fi

echo ""
echo "Results: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
