#!/usr/bin/env bash
# test-lint-shellcheck-parallel.sh - Repeatable acceptance check for lint-shellcheck.sh's
# one-process-per-file worker-pool dispatch (added to parallelize Gate 22, previously a strictly
# sequential single-invocation scan over the entire corpus).
#
# WHAT THIS PINS DOWN
# --------------------
#   1. ACCEPTANCE GATE: the default parallel path (SHELLCHECK_JOBS unset, i.e. 8) must be
#      materially faster than the one-process-per-file path forced to a single worker
#      (SHELLCHECK_JOBS=1) on the REAL corpus (agent-system/extensions/**/*.sh). This suite
#      FAILS if the parallel path is not faster -- it is a repeatable regression gate against
#      the lint silently regressing back toward sequential cost, not a one-off measurement.
#      Comparison uses a RELATIVE ratio (parallel <= 80% of the forced-single-worker wall time),
#      not an absolute-ms threshold -- precedent: test-run-all-parallel.sh's own case3/case4,
#      redesigned the same way after flaking under genuine ambient host load with an absolute
#      threshold. An 80% ceiling leaves ample margin under the ~52% ratio measured at
#      implementation time (76.8s at jobs=1 vs 39.5s at jobs=8, idle-to-light-load host) while
#      still catching a real regression back to no-parallelism.
#   2. FINDING-SET EQUIVALENCE: SHELLCHECK_JOBS=1 and the default parallel path produce
#      byte-identical output on the real corpus (same clean-pass case) and on a seeded-violation
#      fixture (same findings, same order).
#   3. DISCOVERY-ORDER DETERMINISM: output is byte-identical across worker counts 1, 4, and 8 on
#      a fixed multi-file fixture, regardless of actual completion order under concurrency.
#
# SOURCE-STORE-ONLY SUBJECT RESOLUTION: this suite resolves its one subject (lint-shellcheck.sh)
# purely from its own location (SCRIPT_DIR's sibling ../lint/), never from a deployed
# $REPO_ROOT/.claude path -- precedent: test-run-all-selection.sh's identical rationale. This
# lets the suite run correctly both pre-redeploy (against the source-store copy, from
# agent-system/extensions/core/scripts/tests/) and post-redeploy (against the deployed copy,
# from .claude/scripts/tests/), each time testing whichever copy it actually ships alongside.
#
# LOAD-SENSITIVE: this suite spins up to 8 concurrent real `shellcheck` processes and makes a
# real wall-clock comparison against a forced-single-worker run over the ~387-file real corpus
# (two full corpus scans, ~2 minutes total at implementation time) -- an ambient-load precaution
# in the same spirit as run-all.sh's own LOAD_SENSITIVE_BASENAMES list. It is registered there
# (run-all.sh) so it always runs alone, serially, never nested inside another already-parallel
# suite pool.
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
# Case 1: acceptance gate + finding-set equivalence on the REAL corpus
# =====================================================================
info "=== real-corpus case: SHELLCHECK_JOBS=1 vs default (parallel), timed ==="

start_seq="$(now_ms)"
seq_out="$(SHELLCHECK_JOBS=1 bash "$LINT_SCRIPT" --quiet 2>&1)"
seq_rc=$?
end_seq="$(now_ms)"
seq_ms=$((end_seq - start_seq))

start_par="$(now_ms)"
par_out="$(bash "$LINT_SCRIPT" --quiet 2>&1)"
par_rc=$?
end_par="$(now_ms)"
par_ms=$((end_par - start_par))

info "SHELLCHECK_JOBS=1 wall=${seq_ms}ms rc=${seq_rc} out=${seq_out}"
info "default (parallel) wall=${par_ms}ms rc=${par_rc} out=${par_out}"

if [[ "$seq_rc" -eq "$par_rc" && "$seq_out" == "$par_out" ]]; then
  pass "real-corpus finding set identical between SHELLCHECK_JOBS=1 and the default parallel path"
else
  fail "real-corpus finding set differs between SHELLCHECK_JOBS=1 and default:
seq(rc=$seq_rc): $seq_out
par(rc=$par_rc): $par_out"
fi

# Relative-ratio acceptance gate (see header): parallel must be <= 80% of the forced-single-
# worker wall time. Guard against a pathologically fast host where seq_ms is already ~0.
if [[ "$seq_ms" -gt 0 ]]; then
  ceiling_ms=$(( seq_ms * 80 / 100 ))
  if [[ "$par_ms" -le "$ceiling_ms" ]]; then
    pass "parallel path (${par_ms}ms) is at or below 80% of the forced-single-worker time (${seq_ms}ms, ceiling ${ceiling_ms}ms)"
  else
    fail "parallel path (${par_ms}ms) did NOT beat 80% of the forced-single-worker time (${seq_ms}ms, ceiling ${ceiling_ms}ms) -- the parallel dispatch may have regressed"
  fi
else
  info "forced-single-worker wall time measured as 0ms -- skipping the ratio assertion as unmeasurable on this host"
fi

# =====================================================================
# Case 2: seeded-violation equivalence between SHELLCHECK_JOBS=1 and default
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
# Case 3: discovery-order determinism across worker counts 1, 4, 8
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
# Case 4: SHELLCHECK_JOBS validation (non-integer, zero, negative all refused)
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
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
