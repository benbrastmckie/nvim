#!/usr/bin/env bash
# test-lint-shellcheck-parallel.sh - Repeatable acceptance check for lint-shellcheck.sh's
# one-process-per-file worker-pool dispatch (added to parallelize Gate 22, previously a strictly
# sequential single-invocation scan over the entire corpus).
#
# WHAT THIS PINS DOWN
# --------------------
#   1. DISPATCH-SHAPE ACCEPTANCE GATE, on a small fixture, not the real corpus: a forced worker
#      cap is honoured (peak concurrent `shellcheck` invocations never exceeds the cap, and
#      reaches it when enough files are pending), every invocation carries exactly one target
#      file (one-process-per-file, never a batched multi-file invocation), and findings are
#      emitted whole in discovery order. This replaced an earlier version of this suite that
#      walked the REAL corpus (agent-system/extensions/**/*.sh) twice and asserted a relative
#      wall-clock ratio between SHELLCHECK_JOBS=1 and the parallel default -- sound in principle,
#      but it re-paid ~118s of production-corpus scanning on every run of this suite, which
#      itself runs inside Gate 8, which has been observed nested four `verify-deploy.sh` levels
#      deep (see shell-script-testing.md's Gate 8 root-cause record). A wall-clock ratio taken
#      under Gate 8's own concurrent worker pool was also never a sound measurement in the first
#      place -- ambient contention from sibling suites skews both arms of the ratio unevenly.
#      The fixture-based dispatch-shape assertion below observes the SAME mechanism (worker-pool
#      scheduling via `wait -n`) directly and deterministically, via a PATH-substituted stub
#      `shellcheck` binary that logs its own start/end timestamps and argv instead of actually
#      parsing anything -- this removes both the corpus-walk cost and the ambient-load timing
#      sensitivity a wall-clock ratio carried.
#   2. FINDING-SET EQUIVALENCE: SHELLCHECK_JOBS=1 and a forced worker count > 1 produce
#      byte-identical output on the SAME small fixture used for the dispatch-shape case (now
#      using the REAL shellcheck binary, not the stub), and on a separate seeded-violation
#      fixture (same findings, same order) -- case 3 below, unchanged from the prior version of
#      this suite.
#   3. DISCOVERY-ORDER DETERMINISM: output is byte-identical across worker counts 1, 4, and 8 on
#      a fixed multi-file fixture, regardless of actual completion order under concurrency --
#      case 4 below, unchanged from the prior version of this suite.
#   4. OPT-IN REAL-CORPUS TIMING EXPERIMENT (case 6): the real-corpus wall-clock comparison this
#      suite used to run on every invocation is preserved, not deleted -- it is the standing
#      evidence that one-process-per-file parallel dispatch remains a measured win over the
#      sequential path (see lint-shellcheck.sh's own header for the measured curve). It now runs
#      only when explicitly requested via `RUN_REAL_CORPUS_TIMING=1`, which the default run-all.sh
#      path never sets.
#
# SOURCE-STORE-ONLY SUBJECT RESOLUTION: this suite resolves its one subject (lint-shellcheck.sh)
# purely from its own location (SCRIPT_DIR's sibling ../lint/), never from a deployed
# $REPO_ROOT/.claude path -- precedent: test-run-all-selection.sh's identical rationale. This
# lets the suite run correctly both pre-redeploy (against the source-store copy, from
# agent-system/extensions/core/scripts/tests/) and post-redeploy (against the deployed copy,
# from .claude/scripts/tests/), each time testing whichever copy it actually ships alongside.
#
# LOAD-SENSITIVE: the dispatch-shape case still spins up several concurrent processes (now a
# cheap stub, not real `shellcheck`, and over a 9-file fixture rather than the real corpus) and
# the opt-in case 6, when requested, still walks the real corpus twice. Registered in
# run-all.sh's LOAD_SENSITIVE_BASENAMES so it always runs alone, serially, never nested inside
# another already-parallel suite pool.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED (including a failed acceptance
# gate); 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LINT_SCRIPT="$CORE_DIR/lint/lint-shellcheck.sh"

if [[ ! -f "$LINT_SCRIPT" ]]; then
  echo "ERROR: expected $LINT_SCRIPT" >&2
  exit 2
fi

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [[ -n "${WORKDIR:-}" && -d "$WORKDIR" ]] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

now_ms() { date +%s%3N; }

# =====================================================================
# Shared fixture for cases 1 and 2: 8 clean files + 1 file carrying a deliberate SC2155
# (masked-exit-code) violation. Large enough (9 files) to make a forced low worker cap
# observably reach its ceiling across multiple waves without approaching the real corpus.
# =====================================================================
FIXTURE_DIR="$WORKDIR/dispatch-fixture"
mkdir -p "$FIXTURE_DIR"
FIXTURE_N=9
for n in $(seq 1 $((FIXTURE_N - 1))); do
  cat > "$FIXTURE_DIR/clean$n.sh" << EOF
#!/usr/bin/env bash
set -euo pipefail
clean_fn_$n() {
  echo "clean $n"
}
clean_fn_$n
EOF
done
cat > "$FIXTURE_DIR/dirty.sh" << 'EOF'
#!/usr/bin/env bash
dirty_fn() {
  local x=$(false)
  echo "$x"
}
EOF

# =====================================================================
# Case 1: dispatch-shape acceptance gate on the fixture (stub shellcheck)
# =====================================================================
info "=== dispatch-shape case: worker cap honoured, one-process-per-file, via a stub shellcheck ==="

STUB_BIN_DIR="$WORKDIR/stubbin"
mkdir -p "$STUB_BIN_DIR"
export STUB_LOG="$WORKDIR/stub.log"
: > "$STUB_LOG"
# The stub never parses its target file -- it logs its own start/end wall-clock (ms) and full
# argv, sleeps a fixed, generous window (0.4s) so overlapping invocations are observable with a
# wide safety margin, then exits 0 (a clean pass) so the real lint script's control flow and
# finding-count bookkeeping are unaffected. $STUB_LOG is inherited via the environment (not
# substituted into the heredoc), so the single-quoted heredoc below is copied verbatim.
cat > "$STUB_BIN_DIR/shellcheck" << 'STUBEOF'
#!/usr/bin/env bash
start_ms="$(date +%s%3N)"
printf 'START %s %s %s\n' "$start_ms" "$$" "$*" >> "$STUB_LOG"
sleep 0.4
end_ms="$(date +%s%3N)"
printf 'END %s %s %s\n' "$end_ms" "$$" "$*" >> "$STUB_LOG"
exit 0
STUBEOF
chmod +x "$STUB_BIN_DIR/shellcheck"

DISPATCH_CAP=3
dispatch_out="$(PATH="$STUB_BIN_DIR:$PATH" SHELLCHECK_JOBS="$DISPATCH_CAP" bash "$LINT_SCRIPT" "$FIXTURE_DIR" 2>&1)"
dispatch_rc=$?

if [[ "$dispatch_rc" -eq 0 ]]; then
  pass "stub-backed dispatch run exits 0 (stub reports no findings on every file)"
else
  fail "stub-backed dispatch run expected exit 0, got $dispatch_rc:
$dispatch_out"
fi

start_count="$(grep -c '^START' "$STUB_LOG" || true)"
if [[ "$start_count" -eq "$FIXTURE_N" ]]; then
  pass "exactly $FIXTURE_N shellcheck invocations observed (one per fixture file)"
else
  fail "expected $FIXTURE_N shellcheck invocations, observed $start_count"
fi

# One-process-per-file: every invocation's argv must name exactly one fixture file -- a future
# batched shape (multiple file arguments per invocation) would be caught here even though it
# would still produce correct findings, because it was already measured to regress wall time on
# this corpus (see lint-shellcheck.sh's own header) and must never be silently reintroduced.
batched_count=0
while IFS= read -r line; do
  file_hits="$(grep -o "${FIXTURE_DIR}/[A-Za-z0-9_.]*\\.sh" <<< "$line" | wc -l)"
  [[ "$file_hits" -ne 1 ]] && batched_count=$((batched_count + 1))
done < <(grep '^START' "$STUB_LOG")
if [[ "$batched_count" -eq 0 ]]; then
  pass "every invocation named exactly one fixture file (no batched multi-file dispatch)"
else
  fail "$batched_count of $FIXTURE_N invocations did not name exactly one fixture file"
fi

# Worker cap honoured: peak concurrent invocations must never exceed the forced cap, and -- with
# $FIXTURE_N > DISPATCH_CAP -- must actually reach it, proving genuine parallel dispatch rather
# than silent serialization.
peak_concurrency="$(
  {
    grep '^START' "$STUB_LOG" | awk '{print $2, 1}'
    grep '^END' "$STUB_LOG" | awk '{print $2, -1}'
  } | sort -n -k1,1 | awk '{active += $2; if (active > peak) peak = active} END {print peak}'
)"
if [[ "$peak_concurrency" -le "$DISPATCH_CAP" ]]; then
  pass "peak concurrent invocations ($peak_concurrency) never exceeded the forced cap ($DISPATCH_CAP)"
else
  fail "peak concurrent invocations ($peak_concurrency) EXCEEDED the forced cap ($DISPATCH_CAP) -- the worker cap is not honoured"
fi
if [[ "$peak_concurrency" -eq "$DISPATCH_CAP" ]]; then
  pass "peak concurrent invocations reached the forced cap ($DISPATCH_CAP), confirming genuine parallel dispatch"
else
  fail "peak concurrent invocations ($peak_concurrency) never reached the forced cap ($DISPATCH_CAP) with $FIXTURE_N files pending -- dispatch may be serialized"
fi

# =====================================================================
# Case 2: finding-set equivalence on the SAME fixture, real shellcheck, SHELLCHECK_JOBS=1 vs a
# forced worker count > 1
# =====================================================================
info "=== fixture finding-set equivalence case: SHELLCHECK_JOBS=1 vs a forced worker count ==="

fixture_seq_out="$(SHELLCHECK_JOBS=1 bash "$LINT_SCRIPT" "$FIXTURE_DIR" 2>&1)"
fixture_seq_rc=$?
fixture_par_out="$(SHELLCHECK_JOBS=4 bash "$LINT_SCRIPT" "$FIXTURE_DIR" 2>&1)"
fixture_par_rc=$?

if [[ "$fixture_seq_rc" -ne 0 && "$fixture_par_rc" -ne 0 ]]; then
  pass "both worker counts exit non-zero on the fixture's seeded violation"
else
  fail "expected both worker counts to exit non-zero on the fixture (seq_rc=$fixture_seq_rc par_rc=$fixture_par_rc)"
fi

if [[ "$fixture_seq_out" == "$fixture_par_out" ]]; then
  pass "fixture finding set byte-identical between SHELLCHECK_JOBS=1 and SHELLCHECK_JOBS=4"
else
  fail "fixture finding set differs between worker counts:
seq: $fixture_seq_out
par: $fixture_par_out"
fi

# =====================================================================
# Case 3: seeded-violation equivalence between SHELLCHECK_JOBS=1 and default (unchanged)
# =====================================================================
info "=== seeded-violation case: identical findings, both worker counts ==="

SEED_DIR="$WORKDIR/seed"
mkdir -p "$SEED_DIR"
cat > "$SEED_DIR/a-clean.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
clean_fn() {
  local x
  x="$(false || true)"
  echo "$x"
}
clean_fn
EOF
cat > "$SEED_DIR/b-dirty.sh" << 'EOF'
#!/usr/bin/env bash
dirty_fn() {
  local x=$(false)
  echo "$x"
}
EOF
cat > "$SEED_DIR/c-clean.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "clean"
EOF

seed_seq_out="$(SHELLCHECK_JOBS=1 bash "$LINT_SCRIPT" "$SEED_DIR" 2>&1)"
seed_seq_rc=$?
seed_par_out="$(bash "$LINT_SCRIPT" "$SEED_DIR" 2>&1)"
seed_par_rc=$?

if [[ "$seed_seq_rc" -ne 0 && "$seed_par_rc" -ne 0 ]]; then
  pass "both worker counts exit non-zero on the seeded-violation fixture"
else
  fail "expected both worker counts to exit non-zero on the seeded-violation fixture (seq_rc=$seed_seq_rc par_rc=$seed_par_rc)"
fi

if grep -q 'SC2155' <<< "$seed_seq_out" && grep -q 'SC2155' <<< "$seed_par_out"; then
  pass "both worker counts name SC2155 for the seeded violation"
else
  fail "SC2155 missing from one or both outputs:
seq: $seed_seq_out
par: $seed_par_out"
fi

if [[ "$seed_seq_out" == "$seed_par_out" ]]; then
  pass "seeded-violation output byte-identical between SHELLCHECK_JOBS=1 and default"
else
  fail "seeded-violation output differs between worker counts:
seq: $seed_seq_out
par: $seed_par_out"
fi

# =====================================================================
# Case 4: discovery-order determinism across worker counts 1, 4, 8 (unchanged)
# =====================================================================
info "=== determinism case: identical output across SHELLCHECK_JOBS=1,4,8 ==="

DET_DIR="$WORKDIR/det"
mkdir -p "$DET_DIR"
for n in 1 2 3 4 5; do
cat > "$DET_DIR/f$n.sh" << EOF
#!/usr/bin/env bash
dirty_fn_$n() {
  local x=\$(false)
  echo "\$x \$n"
}
EOF
done

det_out_1="$(SHELLCHECK_JOBS=1 bash "$LINT_SCRIPT" "$DET_DIR" 2>&1)"
det_out_4="$(SHELLCHECK_JOBS=4 bash "$LINT_SCRIPT" "$DET_DIR" 2>&1)"
det_out_8="$(SHELLCHECK_JOBS=8 bash "$LINT_SCRIPT" "$DET_DIR" 2>&1)"

if [[ "$det_out_1" == "$det_out_4" && "$det_out_4" == "$det_out_8" ]]; then
  pass "output byte-identical across SHELLCHECK_JOBS=1,4,8 on a 5-file mixed fixture"
else
  fail "output differs across worker counts:
jobs=1: $det_out_1
jobs=4: $det_out_4
jobs=8: $det_out_8"
fi

# =====================================================================
# Case 5: SHELLCHECK_JOBS validation (non-integer, zero, negative all refused) (unchanged)
# =====================================================================
info "=== SHELLCHECK_JOBS validation case ==="

for bad in 0 -1 abc; do
  bad_out="$(SHELLCHECK_JOBS="$bad" bash "$LINT_SCRIPT" "$SEED_DIR" 2>&1)"
  bad_rc=$?
  if [[ "$bad_rc" -eq 2 ]]; then
    pass "SHELLCHECK_JOBS='$bad' is refused with exit 2"
  else
    fail "SHELLCHECK_JOBS='$bad' expected exit 2, got $bad_rc:
$bad_out"
  fi
done

# =====================================================================
# Case 6: opt-in real-corpus timing experiment (RUN_REAL_CORPUS_TIMING=1 only)
# =====================================================================
if [[ "${RUN_REAL_CORPUS_TIMING:-0}" == "1" ]]; then
  info "=== opt-in real-corpus case: SHELLCHECK_JOBS=1 vs default (parallel), timed ==="

  start_seq="$(now_ms)"
  real_seq_out="$(SHELLCHECK_JOBS=1 bash "$LINT_SCRIPT" --quiet 2>&1)"
  real_seq_rc=$?
  end_seq="$(now_ms)"
  real_seq_ms=$((end_seq - start_seq))

  start_par="$(now_ms)"
  real_par_out="$(bash "$LINT_SCRIPT" --quiet 2>&1)"
  real_par_rc=$?
  end_par="$(now_ms)"
  real_par_ms=$((end_par - start_par))

  info "SHELLCHECK_JOBS=1 wall=${real_seq_ms}ms rc=${real_seq_rc} out=${real_seq_out}"
  info "default (parallel) wall=${real_par_ms}ms rc=${real_par_rc} out=${real_par_out}"

  if [[ "$real_seq_rc" -eq "$real_par_rc" && "$real_seq_out" == "$real_par_out" ]]; then
    pass "real-corpus finding set identical between SHELLCHECK_JOBS=1 and the default parallel path"
  else
    fail "real-corpus finding set differs between SHELLCHECK_JOBS=1 and default:
seq(rc=$real_seq_rc): $real_seq_out
par(rc=$real_par_rc): $real_par_out"
  fi

  if [[ "$real_seq_ms" -gt 0 ]]; then
    ceiling_ms=$(( real_seq_ms * 80 / 100 ))
    if [[ "$real_par_ms" -le "$ceiling_ms" ]]; then
      pass "parallel path (${real_par_ms}ms) is at or below 80% of the forced-single-worker time (${real_seq_ms}ms, ceiling ${ceiling_ms}ms)"
    else
      fail "parallel path (${real_par_ms}ms) did NOT beat 80% of the forced-single-worker time (${real_seq_ms}ms, ceiling ${ceiling_ms}ms) -- the parallel dispatch may have regressed"
    fi
  else
    info "forced-single-worker wall time measured as 0ms -- skipping the ratio assertion as unmeasurable on this host"
  fi
else
  info "=== opt-in real-corpus timing experiment skipped (set RUN_REAL_CORPUS_TIMING=1 to run it) ==="
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
