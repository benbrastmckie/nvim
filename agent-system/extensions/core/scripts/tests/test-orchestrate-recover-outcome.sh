#!/usr/bin/env bash
# test-orchestrate-recover-outcome.sh - Fixture suite for orchestrate-recover-outcome.sh's D2
# addition: the optional third positional <expected_dispatch_seq> argument and the
# dispatch_seq identity check it gates. Covers: no-arg (2-arg) backward compatibility, absent-field
# degradation (WARN + mtime-only fallback), match, mismatch, and the git-restored-predecessor
# shape (fresh in-window mtime + predecessor dispatch_seq) that mtime alone cannot reject.
#
# orchestrate-recover-outcome.sh is a standalone, read-only script (no `source`d collaborators, no
# calls to sibling scripts) so this suite needs no synthetic `.claude/scripts/` sandbox -- it
# invokes the real script directly against a scratch task directory per case.
#
# Fixture numbers below are synthetic, referred to as "case N" -- never "task N" -- per
# rules/no-task-references-in-deliverables.md.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SUT="$CORE_DIR/orchestrate-recover-outcome.sh"

if [ ! -f "$SUT" ]; then
  echo "ERROR: expected $SUT" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required for this suite" >&2
  exit 2
fi

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

new_task_dir() {
  local d
  d=$(mktemp -d "$WORKDIR/task.XXXXXX")
  echo "$d"
}

write_meta() {
  # $1=task_dir $2=json_body
  echo "$2" > "$1/.return-meta.json"
}

now_ts() { date -u +%s; }

# ── Case 1: no-arg (2-arg) backward compatibility ──────────────────────────────────────────────
# A 2-arg call must behave exactly as before D2: no dispatch_seq comparison at all, even though
# the file itself carries a dispatch_seq field.
task_dir=$(new_task_dir)
write_meta "$task_dir" '{"status":"implemented","dispatch_seq":5,"artifacts":[{"type":"summary","path":"x","summary":"y"}],"metadata":{"phases_completed":3,"phases_total":3}}'
window_start=$(now_ts)
out=$(bash "$SUT" "$task_dir" "$window_start" 2>/tmp/case1.stderr)
rc=$?
recovered=$(echo "$out" | jq -r '.recovered')
if [ "$rc" -eq 0 ] && [ "$recovered" = "true" ]; then
  pass "case 1: 2-arg call recovers successfully, ignoring the file's own dispatch_seq"
else
  fail "case 1: 2-arg call — expected rc=0 recovered=true, got rc=$rc recovered=$recovered"
fi

# ── Case 2: absent-field degradation (3-arg call, file has no dispatch_seq) ────────────────────
task_dir=$(new_task_dir)
write_meta "$task_dir" '{"status":"implemented","artifacts":[{"type":"summary","path":"x","summary":"y"}],"metadata":{"phases_completed":2,"phases_total":2}}'
window_start=$(now_ts)
out=$(bash "$SUT" "$task_dir" "$window_start" 42 2>/tmp/case2.stderr)
rc=$?
recovered=$(echo "$out" | jq -r '.recovered')
warn_seen=$(grep -c "WARN: orchestrate-recover-outcome.sh: .return-meta.json has no dispatch_seq field" /tmp/case2.stderr || true)
if [ "$rc" -eq 0 ] && [ "$recovered" = "true" ] && [ "$warn_seen" -ge 1 ]; then
  pass "case 2: absent dispatch_seq field degrades to mtime-only with a named WARN"
else
  fail "case 2: expected rc=0 recovered=true with WARN, got rc=$rc recovered=$recovered warn_seen=$warn_seen"
fi

# ── Case 3: match ───────────────────────────────────────────────────────────────────────────────
task_dir=$(new_task_dir)
write_meta "$task_dir" '{"status":"planned","dispatch_seq":7,"artifacts":[{"type":"plan","path":"x","summary":"y"}]}'
window_start=$(now_ts)
out=$(bash "$SUT" "$task_dir" "$window_start" 7 2>/tmp/case3.stderr)
rc=$?
recovered=$(echo "$out" | jq -r '.recovered')
if [ "$rc" -eq 0 ] && [ "$recovered" = "true" ]; then
  pass "case 3: matching dispatch_seq recovers"
else
  fail "case 3: expected rc=0 recovered=true, got rc=$rc recovered=$recovered"
fi

# ── Case 4: mismatch ────────────────────────────────────────────────────────────────────────────
task_dir=$(new_task_dir)
write_meta "$task_dir" '{"status":"planned","dispatch_seq":4,"artifacts":[{"type":"plan","path":"x","summary":"y"}]}'
window_start=$(now_ts)
out=$(bash "$SUT" "$task_dir" "$window_start" 1 2>/tmp/case4.stderr)
rc=$?
recovered=$(echo "$out" | jq -r '.recovered')
reason=$(echo "$out" | jq -r '.reason')
if [ "$rc" -eq 1 ] && [ "$recovered" = "false" ] && [ "$reason" = "META_DISPATCH_SEQ_MISMATCH" ]; then
  pass "case 4: mismatched dispatch_seq is rejected with reason=META_DISPATCH_SEQ_MISMATCH"
else
  fail "case 4: expected rc=1 recovered=false reason=META_DISPATCH_SEQ_MISMATCH, got rc=$rc recovered=$recovered reason=$reason"
fi

# ── Case 5: git-restored predecessor shape ─────────────────────────────────────────────────────
# Fresh, IN-WINDOW mtime (the git-restore lands "now", inside this dispatch's own window) but a
# PREDECESSOR dispatch_seq baked into the restored file's content. mtime alone would pass this --
# only the dispatch_seq check can reject it. window_start is set in the past relative to "now" so
# the freshly-written file's mtime is unambiguously >= window_start.
task_dir=$(new_task_dir)
window_start=$(( $(now_ts) - 100 ))
write_meta "$task_dir" '{"status":"implemented","dispatch_seq":4,"artifacts":[{"type":"summary","path":"x","summary":"y"}],"metadata":{"phases_completed":0,"phases_total":0}}'
out=$(bash "$SUT" "$task_dir" "$window_start" 1 2>/tmp/case5.stderr)
rc=$?
recovered=$(echo "$out" | jq -r '.recovered')
reason=$(echo "$out" | jq -r '.reason')
meta_mtime=$(echo "$out" | jq -r '.meta_mtime')
if [ "$rc" -eq 1 ] && [ "$recovered" = "false" ] && [ "$reason" = "META_DISPATCH_SEQ_MISMATCH" ] && [ "$meta_mtime" -ge "$window_start" ]; then
  pass "case 5: git-restored predecessor (fresh in-window mtime, stale dispatch_seq) is rejected by recovery"
else
  fail "case 5: expected rc=1 recovered=false reason=META_DISPATCH_SEQ_MISMATCH with meta_mtime>=window_start, got rc=$rc recovered=$recovered reason=$reason meta_mtime=$meta_mtime window_start=$window_start"
fi

# ── Invariant: usage error still exits 2 on argument-count violations ──────────────────────────
if bash "$SUT" "$WORKDIR" >/dev/null 2>/dev/null; then
  fail "invariant: missing window_start_ts should exit non-zero"
else
  rc=$?
  if [ "$rc" -eq 2 ]; then
    pass "invariant: usage error (missing window_start_ts) exits 2"
  else
    fail "invariant: expected exit 2 for usage error, got $rc"
  fi
fi

if bash "$SUT" "$WORKDIR" 1 2 3 >/dev/null 2>/dev/null; then
  fail "invariant: four positional args should be rejected"
else
  rc=$?
  if [ "$rc" -eq 2 ]; then
    pass "invariant: usage error (too many args) exits 2"
  else
    fail "invariant: expected exit 2 for too many args, got $rc"
  fi
fi

echo ""
echo "==================================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "==================================================================="

[ "$FAILED" -eq 0 ]
