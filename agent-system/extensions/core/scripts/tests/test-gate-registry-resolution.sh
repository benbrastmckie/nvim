#!/usr/bin/env bash
# test-gate-registry-resolution.sh - Regression suite for scripts/lib/gate-registry-lib.sh, the
# thin interpreter over scripts/gate-registry.data. See that library's own header for the full
# contract (deliberately thin: look up a function name, call it -- no generic guard/output fold).
#
# Coverage:
#   - gate_registry_load parses the REAL gate-registry.data into the documented 7 fields per id.
#   - gate_registry_ids returns the loaded ids, space-separated, ascending.
#   - gate_registry_execute calls the registered function directly (in-process, not a subshell --
#     confirmed by having the called function mutate a caller-scope variable and observing the
#     mutation survive the call).
#   - gate_registry_field returns empty (not an error) for an unknown id or field.
#   - The "-" empty-dependency placeholder normalizes to a truly empty string, not the literal
#     "-" -- this is the regression pin for the TSV-empty-field-collapse defect found and fixed
#     during this task's own Phase 4 (IFS=$'\t' read silently shifts every later column when a
#     field between two tabs is genuinely empty, because bash classifies tab as IFS-whitespace
#     even as IFS's sole member).
#   - A synthetic registry with a genuinely malformed id (non-numeric) is skipped, not aborted.
#   - Phase 7 ("Gate-Level Concurrency Scheduler"): gate_registry_exec_concurrent_batch's wave-
#     barrier dependency honouring, serialized-class isolation, worker-cap enforcement, scalar-
#     sum/array-union delta reconciliation (the mechanism that replaced a naive "source each
#     id's dump in sequence," which silently drops every concurrently-forked id's contribution
#     except the last one sourced), determinism across worker counts, and -- the regression pin
#     for a real bug caught live during this phase's own implementation -- correctness across a
#     SECOND call to the batch function within one process (a bare `MAP=()` reset of an
#     associative scratch array, after `unset` had destroyed its `-A` type, silently recreated
#     it as an indexed array on the second call, corrupting a later string-keyed lookup).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (the
# library was not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB="$CORE_DIR/lib/gate-registry-lib.sh"
REAL_DATA="$CORE_DIR/gate-registry.data"
COMMON_LIB="$CORE_DIR/lib/common.sh"
SHELLCHECK_LINT="$CORE_DIR/lint/lint-shellcheck.sh"

if [ ! -f "$LIB" ]; then
  echo "ERROR: expected $LIB" >&2
  exit 2
fi
if [ ! -f "$REAL_DATA" ]; then
  echo "ERROR: expected $REAL_DATA" >&2
  exit 2
fi
if [ ! -f "$COMMON_LIB" ]; then
  echo "ERROR: expected $COMMON_LIB" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "$LIB"
# shellcheck source=/dev/null
source "$COMMON_LIB"

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); [ -n "${2:-}" ] && echo "$2"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# ─── Case 1-7: load the REAL registry and confirm the documented shape ──────────────────────────
gate_registry_load "$REAL_DATA"

ids="$(gate_registry_ids)"
expected_ids="$(seq 1 23 | tr '\n' ' ' | sed 's/ $//')"
if [ "$ids" = "$expected_ids " ] || [ "$ids" = "$expected_ids" ]; then
  pass "case1: gate_registry_ids returns the real registry's 23 migrated ids, ascending (1-23, Phase 5 completed the migration)"
else
  fail "case1: unexpected ids from the real registry (got: '$ids')"
fi

if [ "$(gate_registry_field 3 invoke)" = "gate3_run" ]; then
  pass "case2: gate_registry_field resolves gate 3's invoke function correctly"
else
  fail "case2: gate 3 invoke mismatch (got: '$(gate_registry_field 3 invoke)')"
fi

if [ "$(gate_registry_field 8 serialized)" = "true" ] && [ "$(gate_registry_field 1 serialized)" = "false" ]; then
  pass "case3: gate_registry_field resolves the serialized flag correctly (gate8=true, gate1=false)"
else
  fail "case3: serialized flag mismatch (gate8='$(gate_registry_field 8 serialized)' gate1='$(gate_registry_field 1 serialized)')"
fi

if [ "$(gate_registry_field 3 requires_source_store)" = "true" ] && [ "$(gate_registry_field 1 requires_source_store)" = "false" ]; then
  pass "case4: gate_registry_field resolves requires_source_store correctly (gate3=true, gate1=false)"
else
  fail "case4: requires_source_store mismatch"
fi

timeout8="$(gate_registry_field 8 timeout_s)"
case "$timeout8" in
  ''|*[!0-9]*) fail "case5: gate 8's timeout_s is not a positive integer (got: '$timeout8')" ;;
  *)
    if [ "$timeout8" -gt 0 ]; then
      pass "case5: gate 8's timeout_s is a positive integer ($timeout8)"
    else
      fail "case5: gate 8's timeout_s is not > 0 (got: $timeout8)"
    fi
    ;;
esac

# Case 6 -- the TSV-empty-field-collapse regression pin: every gate's dependencies field must
# normalize to a truly empty string, never the literal on-disk "-" placeholder leaking through,
# and (indirectly) every LATER field must still resolve to its own correct value rather than a
# neighboring field's value shifted into it by a collapsed empty-field delimiter.
deps_leaked=false
fields_shifted=false
for id in $(gate_registry_ids); do
  d="$(gate_registry_field "$id" dependencies)"
  if [ "$d" = "-" ]; then
    deps_leaked=true
  fi
  class="$(gate_registry_field "$id" cost_class)"
  case "$class" in
    free|moderate|slow) : ;;
    *) fields_shifted=true ;;
  esac
done
if ! $deps_leaked && ! $fields_shifted; then
  pass "case6: the '-' empty-dependency placeholder normalizes to empty, and no field shifted into cost_class's slot (TSV-collapse regression pin)"
else
  fail "case6: TSV-collapse regression -- deps_leaked=$deps_leaked fields_shifted=$fields_shifted"
fi

# Case 7 -- gate_registry_field returns empty (not an error, no abort) for an unknown id/field.
unk_id="$(gate_registry_field 9999 invoke)"
unk_field="$(gate_registry_field 1 not_a_real_field)"
if [ -z "$unk_id" ] && [ -z "$unk_field" ]; then
  pass "case7: an unknown id or field resolves to empty, not an error"
else
  fail "case7: expected empty for unknown id/field (got id='$unk_id' field='$unk_field')"
fi

# ─── Case 8: gate_registry_execute calls the function directly (in-process, not a subshell) ────
TEST_MUTATION_PROBE=""
test_probe_fn() { TEST_MUTATION_PROBE="mutated"; }
SYNTH1="$WORKDIR/synth1.data"
printf '1\tprobe gate\ttest_probe_fn\t-\tfalse\t30\tfree\tfalse\n' > "$SYNTH1"
gate_registry_load "$SYNTH1"
gate_registry_execute 1
if [ "$TEST_MUTATION_PROBE" = "mutated" ]; then
  pass "case8: gate_registry_execute calls the registered function in-process (mutation observed by caller)"
else
  fail "case8: gate_registry_execute did not call the function in-process (TEST_MUTATION_PROBE='$TEST_MUTATION_PROBE')"
fi

# ─── Case 9: an id with no registered function (or a registry that was never loaded for that id)
# is a silent no-op, never an error / abort. ─────────────────────────────────────────────────────
gate_registry_execute 9999
if [ $? -eq 0 ]; then
  pass "case9: gate_registry_execute on an unregistered id is a silent no-op (no abort)"
else
  fail "case9: gate_registry_execute on an unregistered id did not return 0"
fi

# ─── Case 10: a malformed (non-numeric) id row is skipped during load, not aborted, and does not
# poison the ids array. ──────────────────────────────────────────────────────────────────────────
SYNTH2="$WORKDIR/synth2.data"
printf 'abc\tbad row\tsomefn\t-\tfalse\t30\tfree\tfalse\n2\tgood row\ttest_probe_fn\t-\tfalse\t30\tfree\tfalse\n' > "$SYNTH2"
gate_registry_load "$SYNTH2"
ids2="$(gate_registry_ids)"
if [ "$ids2" = "2" ] || [ "$ids2" = "2 " ]; then
  pass "case10: a malformed (non-numeric) id row is skipped during load, leaving only the valid row"
else
  fail "case10: expected only id 2 after skipping the malformed row (got: '$ids2')"
fi

# ─── Case 11-14: gate_registry_exec_bounded (Phase 6, "Uniform Bounded Timeouts Per Gate and
# Per Suite") -- the enforcement mechanism for the timeout_s field cases 5/6 above already
# confirm is well-formed data. See that function's own header for the full contract. ────────────

# Case 11: a fast function under a generous bound finishes normally (rc=0), and its mutations to
# caller-named globals -- including an ARRAY, mirroring verify-deploy.sh's real FINDINGS_LIST --
# are correctly reconciled back across the subshell boundary the bound requires.
TEST_CHECKS=3
TEST_FINDINGS=("FINDING gate1 preexisting")
fast_gate_fn() {
  TEST_CHECKS=$((TEST_CHECKS + 1))
  TEST_FINDINGS+=("FINDING gate2 something broke")
  echo "fast gate stdout"
  echo "fast gate stderr" >&2
}
OUT11="$WORKDIR/out11"; ERR11="$WORKDIR/err11"; STATE11="$WORKDIR/state11"
gate_registry_exec_bounded fast_gate_fn 10 "$OUT11" "$ERR11" "$STATE11" TEST_CHECKS TEST_FINDINGS
rc11=$?
# shellcheck source=/dev/null
[ -s "$STATE11" ] && source "$STATE11"
if [ "$rc11" -eq 0 ] && [ "$TEST_CHECKS" -eq 4 ] && [ "${#TEST_FINDINGS[@]}" -eq 2 ] \
   && [ "$(cat "$OUT11")" = "fast gate stdout" ] && [ "$(cat "$ERR11")" = "fast gate stderr" ]; then
  pass "case11: gate_registry_exec_bounded reconciles scalar + array mutations across the subshell boundary on a clean finish (rc=$rc11, CHECKS=$TEST_CHECKS, findings=${#TEST_FINDINGS[@]})"
else
  fail "case11: reconciliation after a clean finish was wrong (rc=$rc11 CHECKS=$TEST_CHECKS findings=${#TEST_FINDINGS[@]} out='$(cat "$OUT11" 2>/dev/null)' err='$(cat "$ERR11" 2>/dev/null)')"
fi

# Case 12: an empty (undeclared) timeout_s calls the function DIRECTLY, same process, no
# capture -- byte-identical to every pre-Phase-6 call site, and the correct degrade-safe default.
DIRECT_PROBE=0
direct_gate_fn() { DIRECT_PROBE=9; echo "direct gate stdout"; }
OUT12="$WORKDIR/out12"; ERR12="$WORKDIR/err12"; STATE12="$WORKDIR/state12"
DIRECT_STDOUT_CAPTURE="$WORKDIR/direct-stdout-capture.txt"
# Deliberately NOT `direct_out="$(...)"` -- command substitution itself forks a subshell in
# bash, which would strand DIRECT_PROBE's mutation exactly the way this case exists to prove
# does NOT happen on the empty-timeout direct-call path. Redirect real stdout to a file instead
# so the call stays a genuine plain statement in THIS shell.
gate_registry_exec_bounded direct_gate_fn "" "$OUT12" "$ERR12" "$STATE12" DIRECT_PROBE > "$DIRECT_STDOUT_CAPTURE"
rc12=$?
if [ "$rc12" -eq 0 ] && [ "$DIRECT_PROBE" -eq 9 ] && [ "$(cat "$DIRECT_STDOUT_CAPTURE")" = "direct gate stdout" ] \
   && [ ! -s "$OUT12" ]; then
  pass "case12: an empty timeout_s runs the function directly in-process (no fork, no capture file written)"
else
  fail "case12: empty-timeout direct-call path regressed (rc=$rc12 DIRECT_PROBE=$DIRECT_PROBE stdout='$(cat "$DIRECT_STDOUT_CAPTURE" 2>/dev/null)')"
fi

# Case 13: a stalling function under a short bound times out (rc=124), finishes within the
# bound plus a small margin (never the full 30s sleep), and leaves no orphaned descendant
# process -- proving the process-GROUP kill (not merely the wrapping subshell) actually fires.
# The stalled descendant's OWN pid is written to a dedicated file so this case can check that
# EXACT pid's liveness via `kill -0`, rather than a `pgrep -f "sleep 30"`-style pattern match --
# this suite can run concurrently with sibling suites (including its own repo's other suites,
# under a real parallel `run-all.sh` battery) that legitimately run an unrelated `sleep 30` of
# their own at the same moment, which a broad pattern match would misattribute as a leftover.
STALL_PIDFILE13="$WORKDIR/stall-pid13.txt"
stall_gate_fn() { sleep 30 & echo "$!" > "$STALL_PIDFILE13"; wait; }
OUT13="$WORKDIR/out13"; ERR13="$WORKDIR/err13"; STATE13="$WORKDIR/state13"
t0=$(date +%s%3N)
gate_registry_exec_bounded stall_gate_fn 2 "$OUT13" "$ERR13" "$STATE13"
rc13=$?
t1=$(date +%s%3N)
ms13=$((t1 - t0))
sleep 0.5
stalled_pid13="$(cat "$STALL_PIDFILE13" 2>/dev/null || true)"
leftover13=""
if [ -n "$stalled_pid13" ] && kill -0 "$stalled_pid13" 2>/dev/null; then
  leftover13="pid $stalled_pid13 still alive"
fi
if [ "$rc13" -eq 124 ] && [ "$ms13" -lt 6000 ] && [ -n "$stalled_pid13" ] && [ -z "$leftover13" ]; then
  pass "case13: a stalling function times out (rc=124) within margin (${ms13}ms) with no leftover descendant process (checked exact pid $stalled_pid13)"
else
  fail "case13: stalled-gate timeout did not behave as expected (rc=$rc13, elapsed=${ms13}ms, stalled_pid='$stalled_pid13', leftover='$leftover13')"
fi

# Case 14: the REAL migrated registry's own declared timeout_s values are all enforced-ready
# (positive integers) -- a direct pin that Phase 6 did not leave any migrated gate's bound at
# an empty/zero placeholder that would silently fall back to the unbounded direct-call path.
gate_registry_load "$REAL_DATA"
all_bounded=true
unbounded_ids=""
for id in $(gate_registry_ids); do
  t="$(gate_registry_field "$id" timeout_s)"
  case "$t" in
    ''|0|*[!0-9]*) all_bounded=false; unbounded_ids="$unbounded_ids $id" ;;
  esac
done
if $all_bounded; then
  pass "case14: every one of the real registry's 23 migrated gates declares a positive timeout_s (enforced, not a silent unbounded fallback)"
else
  fail "case14: gate id(s)$unbounded_ids have no enforceable timeout_s"
fi

# ─── Case 15-21: gate_registry_exec_concurrent_batch (Phase 7, "Gate-Level Concurrency
# Scheduler"). Each case builds its own synthetic registry so the real 23-gate registry (whose
# real functions do real, slow, external work) is never exercised here -- that proof is the
# live, real-corpus before/after byte-diff this task's own implementation summary records
# separately, not this suite's job. ──────────────────────────────────────────────────────────────

# Case 15: a dependent id never starts before its declared prerequisite completes, under a
# worker cap >1 (so the dependency and the pool's own concurrency are both actually exercised,
# not merely declared). gate2 depends on gate1; gate1 sleeps briefly before marking a shared
# trace file, gate2 checks for that mark the instant it starts.
SYNTH15="$WORKDIR/synth15.data"
cat > "$SYNTH15" <<'EOT'
1	dep base	t15_fn1	-	false	30	moderate	false
2	dep on 1	t15_fn2	1	false	30	moderate	false
3	independent	t15_fn3	-	false	30	free	false
EOT
TRACE15="$WORKDIR/trace15.log"
: > "$TRACE15"
t15_fn1() { sleep 0.3; echo "fn1-done" >> "$TRACE15"; }
t15_fn2() {
  if grep -q "fn1-done" "$TRACE15" 2>/dev/null; then
    echo "fn2-ok" >> "$TRACE15"
  else
    echo "fn2-VIOLATION" >> "$TRACE15"
  fi
}
t15_fn3() { sleep 0.1; echo "fn3-done" >> "$TRACE15"; }
gate_registry_load "$SYNTH15"
OUT15="$WORKDIR/out15"; mkdir -p "$OUT15"
gate_registry_exec_concurrent_batch 2 "$OUT15"
if grep -q "fn2-VIOLATION" "$TRACE15"; then
  fail "case15: a dependent id started before its declared prerequisite completed" "$(cat "$TRACE15")"
elif grep -q "fn2-ok" "$TRACE15"; then
  pass "case15: a dependent id (gate2, depends on gate1) never starts before its prerequisite completes, under worker cap 2"
else
  fail "case15: gate2 never ran at all" "$(cat "$TRACE15")"
fi

# Case 16: the registry's serialized class (gate8 in the real data; a synthetic id here) runs
# ALONE -- no temporal overlap with any pool id, confirmed by start/end timestamp ranges.
SYNTH16="$WORKDIR/synth16.data"
cat > "$SYNTH16" <<'EOT'
1	serialized	t16_fn1	-	false	30	moderate	true
2	pool a	t16_fn2	-	false	30	free	false
3	pool b	t16_fn3	-	false	30	free	false
EOT
TIMES16="$WORKDIR/times16.log"
: > "$TIMES16"
t16_fn1() { echo "1 start $(date +%s%3N)" >> "$TIMES16"; sleep 0.3; echo "1 end $(date +%s%3N)" >> "$TIMES16"; }
t16_fn2() { echo "2 start $(date +%s%3N)" >> "$TIMES16"; sleep 0.1; echo "2 end $(date +%s%3N)" >> "$TIMES16"; }
t16_fn3() { echo "3 start $(date +%s%3N)" >> "$TIMES16"; sleep 0.1; echo "3 end $(date +%s%3N)" >> "$TIMES16"; }
gate_registry_load "$SYNTH16"
OUT16="$WORKDIR/out16"; mkdir -p "$OUT16"
gate_registry_exec_concurrent_batch 2 "$OUT16"
serial_end=$(awk '$1==1 && $2=="end" {print $3}' "$TIMES16")
overlap=false
for id in 2 3; do
  pool_start=$(awk -v i="$id" '$1==i && $2=="start" {print $3}' "$TIMES16")
  if [ -n "$pool_start" ] && [ "$pool_start" -lt "$serial_end" ]; then
    overlap=true
  fi
done
if ! $overlap; then
  pass "case16: the serialized-class id (gate1 here) runs alone, strictly before any pool id starts -- no temporal overlap"
else
  fail "case16: a pool id started before the serialized id finished" "$(cat "$TIMES16")"
fi

# Case 17: the worker cap is actually enforced -- with 6 pool ids and cap 2, the number of
# concurrently-active ids never exceeds 2. Verified via `flock`-guarded increment/decrement of a
# shared counter file (NOT a bare read-modify-write, which would race across real concurrent
# processes and could only ever UNDER-count a lost increment -- silently hiding a real
# cap violation rather than risking a false one. flock makes the counter update atomic across
# processes, so a peak reading here is trustworthy in both directions.)
SYNTH17="$WORKDIR/synth17.data"
: > "$SYNTH17"
for i in 1 2 3 4 5 6; do
  printf '%s\tpool\tt17_fn%s\t-\tfalse\t30\tfree\tfalse\n' "$i" "$i" >> "$SYNTH17"
done
ACTIVE17="$WORKDIR/active17.count"
MAXSEEN17="$WORKDIR/maxseen17.count"
LOCK17="$WORKDIR/lock17"
echo 0 > "$ACTIVE17"
echo 0 > "$MAXSEEN17"
t17_body() {
  (
    flock -x 200
    local cur max
    cur=$(($(cat "$ACTIVE17") + 1))
    echo "$cur" > "$ACTIVE17"
    max=$(cat "$MAXSEEN17")
    [ "$cur" -gt "$max" ] && echo "$cur" > "$MAXSEEN17"
  ) 200>"$LOCK17"
  sleep 0.2
  (
    flock -x 200
    echo "$(($(cat "$ACTIVE17") - 1))" > "$ACTIVE17"
  ) 200>"$LOCK17"
}
for i in 1 2 3 4 5 6; do
  eval "t17_fn$i() { t17_body; }"
done
gate_registry_load "$SYNTH17"
OUT17="$WORKDIR/out17"; mkdir -p "$OUT17"
gate_registry_exec_concurrent_batch 2 "$OUT17"
maxseen="$(cat "$MAXSEEN17")"
if [ "$maxseen" -eq 2 ]; then
  pass "case17: worker cap 2 is both enforced and genuinely exercised -- peak concurrently-active count observed was exactly $maxseen"
elif [ "$maxseen" -lt 2 ]; then
  fail "case17: concurrency was never exercised (peak observed was $maxseen, want exactly 2) -- cap enforcement is unproven, not merely unviolated"
else
  fail "case17: worker cap 2 was exceeded -- peak concurrently-active count was $maxseen"
fi

# Case 18: delta reconciliation sums scalars and unions array contributions correctly across
# MULTIPLE concurrently-run ids sharing one wave -- the exact defect class a naive
# "source each id's dump in sequence" has (every id's dump is "shared baseline + own delta," not
# a running total; sourcing them in sequence REPLACES rather than ACCUMULATES, silently dropping
# every id's contribution except the last one sourced). 6 ids, cap 3, each increments CHECKS by
# 1 and appends one unique finding.
SYNTH18="$WORKDIR/synth18.data"
: > "$SYNTH18"
for i in 1 2 3 4 5 6; do
  printf '%s\tpool\tt18_fn%s\t-\tfalse\t30\tfree\tfalse\n' "$i" "$i" >> "$SYNTH18"
done
for i in 1 2 3 4 5 6; do
  eval "t18_fn$i() { CHECKS18=\$((CHECKS18+1)); FINDINGS18+=(\"f$i\"); }"
done
gate_registry_load "$SYNTH18"
CHECKS18=0
FINDINGS18=()
OUT18="$WORKDIR/out18"; mkdir -p "$OUT18"
gate_registry_exec_concurrent_batch 3 "$OUT18" CHECKS18 FINDINGS18
if [ "$CHECKS18" -eq 6 ] && [ "${#FINDINGS18[@]}" -eq 6 ]; then
  pass "case18: 6 concurrently-run ids (cap 3) correctly sum CHECKS to 6 and union all 6 findings (CHECKS18=$CHECKS18, findings=${#FINDINGS18[@]})"
else
  fail "case18: delta reconciliation lost contributions -- CHECKS18=$CHECKS18 (want 6), findings=${#FINDINGS18[@]} (want 6): ${FINDINGS18[*]:-<empty>}"
fi

# Case 19: determinism -- the SAME synthetic registry and vars, run at worker counts 1, 2, and 4,
# produce an IDENTICAL final CHECKS sum and an identical (order-independent) findings SET.
det_run() {
  local jobs="$1"
  CHECKS19=0
  FINDINGS19=()
  local outdir="$WORKDIR/out19-$jobs"
  mkdir -p "$outdir"
  gate_registry_load "$SYNTH18"
  for i in 1 2 3 4 5 6; do
    eval "t18_fn$i() { CHECKS19=\$((CHECKS19+1)); FINDINGS19+=(\"f$i\"); }"
  done
  gate_registry_exec_concurrent_batch "$jobs" "$outdir" CHECKS19 FINDINGS19
  printf '%s|%s\n' "$CHECKS19" "$(printf '%s\n' "${FINDINGS19[@]}" | sort | tr '\n' ',')"
}
d1="$(det_run 1)"
d2="$(det_run 2)"
d4="$(det_run 4)"
if [ "$d1" = "$d2" ] && [ "$d2" = "$d4" ]; then
  pass "case19: identical CHECKS sum and findings set at worker counts 1, 2, and 4 ($d1)"
else
  fail "case19: non-deterministic across worker counts -- jobs=1:[$d1] jobs=2:[$d2] jobs=4:[$d4]"
fi

# Case 20: regression pin for the real bug caught live during this phase's own implementation --
# a SECOND call to gate_registry_exec_concurrent_batch within the same process must reconcile
# correctly, not corrupt on a bare associative-array reset whose type was previously destroyed
# by `unset`. (The crash this pins: "line N: finding: unbound variable", from a string-keyed
# lookup silently landing on an indexed array after the first call's cleanup.)
gate_registry_load "$SYNTH18"
for i in 1 2 3 4 5 6; do
  eval "t18_fn$i() { CHECKS20=\$((CHECKS20+1)); FINDINGS20+=(\"f$i\"); }"
done
CHECKS20=0; FINDINGS20=()
OUT20A="$WORKDIR/out20a"; mkdir -p "$OUT20A"
gate_registry_exec_concurrent_batch 2 "$OUT20A" CHECKS20 FINDINGS20
round1_ok=$([ "$CHECKS20" -eq 6 ] && echo true || echo false)
CHECKS20=0; FINDINGS20=()
OUT20B="$WORKDIR/out20b"; mkdir -p "$OUT20B"
gate_registry_exec_concurrent_batch 2 "$OUT20B" CHECKS20 FINDINGS20
round2_ok=$([ "$CHECKS20" -eq 6 ] && [ "${#FINDINGS20[@]}" -eq 6 ] && echo true || echo false)
if [ "$round1_ok" = "true" ] && [ "$round2_ok" = "true" ]; then
  pass "case20: a second call to gate_registry_exec_concurrent_batch within the same process reconciles correctly (round1 CHECKS20=6 ok, round2 CHECKS20=$CHECKS20 findings=${#FINDINGS20[@]} ok)"
else
  fail "case20: second-call corruption regressed -- round1_ok=$round1_ok round2_ok=$round2_ok CHECKS20=$CHECKS20 findings=${#FINDINGS20[@]}"
fi

# Case 21: a timed-out id (rc=124) under concurrency is reported via its rc.$id file and is NOT
# reconciled into CHECKS/FINDINGS (mirrors the sequential path's own "only source on a clean
# finish" rule) -- a killed job's partial/absent state dump must never be double-applied or
# silently counted as a pass.
SYNTH21="$WORKDIR/synth21.data"
cat > "$SYNTH21" <<'EOT'
1	stalls	t21_fn1	-	false	1	moderate	false
2	fast	t21_fn2	-	false	30	free	false
EOT
t21_fn1() { sleep 5; CHECKS21=$((CHECKS21+1)); }
t21_fn2() { CHECKS21=$((CHECKS21+1)); }
gate_registry_load "$SYNTH21"
CHECKS21=0
OUT21="$WORKDIR/out21"; mkdir -p "$OUT21"
gate_registry_exec_concurrent_batch 2 "$OUT21" CHECKS21
rc21_1="$(cat "$OUT21/rc.1" 2>/dev/null)"
if [ "$rc21_1" = "124" ] && [ "$CHECKS21" -eq 1 ]; then
  pass "case21: a stalled id under concurrency reports rc=124 via its rc file and its own (never-dumped) state is correctly excluded from reconciliation (CHECKS21=$CHECKS21, only the fast id's own contribution)"
else
  fail "case21: timeout/reconciliation interaction regressed -- rc.1=$rc21_1 CHECKS21=$CHECKS21 (want rc=124, CHECKS21=1)"
fi

# ─── Case 22-25: Phase 9 ("Shared Corpus Enumeration") plumbing ────────────────────────────────
# gate_registry_shared_corpus_build (producer, lib/gate-registry-lib.sh) and
# common_shared_corpus_available/common_shared_corpus_files (consumer, lib/common.sh) are tested
# together here because they are a producer/consumer PAIR with no third caller of either half in
# isolation -- verify-deploy.sh calls the producer once per invocation and exports its result;
# every affected lint calls the consumer. A synthetic git repo (not the real source store) is
# built fresh so a seeded violation can be planted and torn down without touching real files.

SYNTH22_ROOT="$WORKDIR/synth22-repo"
mkdir -p "$SYNTH22_ROOT/agent-system/extensions/fakeext/scripts"
(
  cd "$SYNTH22_ROOT" || exit 1
  git init -q .
  git config user.email "test@example.com"
  git config user.name "test"
  cat > agent-system/extensions/fakeext/scripts/clean.sh <<'EOT'
#!/usr/bin/env bash
set -euo pipefail
echo "clean"
EOT
  # Seeded violation: SC2155 (declare-and-assign-in-one-line masks the assignment's own exit
  # status), the exact class this lint exists to catch (see lint-shellcheck.sh's own header).
  cat > agent-system/extensions/fakeext/scripts/dirty.sh <<'EOT'
#!/usr/bin/env bash
export FOO="$(false)"
EOT
  # A file OUTSIDE agent-system/extensions/ must never appear in the corpus -- git ls-files is
  # pathspec-scoped to that subtree only.
  mkdir -p docs
  echo "# not in scope" > docs/outside.md
  git add -- agent-system/extensions/fakeext/scripts/clean.sh \
             agent-system/extensions/fakeext/scripts/dirty.sh \
             docs/outside.md
  git commit -q -m "seed"
)

CORPUS22="$(gate_registry_shared_corpus_build "$SYNTH22_ROOT")"
corpus22_lines="$(tr '\0' '\n' < "$CORPUS22" | sort)"
expected22_lines="$(printf 'agent-system/extensions/fakeext/scripts/clean.sh\nagent-system/extensions/fakeext/scripts/dirty.sh')"
if [ "$corpus22_lines" = "$expected22_lines" ]; then
  pass "case22: gate_registry_shared_corpus_build enumerates exactly the tracked agent-system/extensions subtree (2 files), excluding the out-of-subtree docs/ file"
else
  fail "case22: shared-corpus producer scope regressed" "got: [$corpus22_lines] want: [$expected22_lines]"
fi

GATE_SHARED_CORPUS_FILE="$CORPUS22" GATE_SHARED_CORPUS_ROOT="$SYNTH22_ROOT"
export GATE_SHARED_CORPUS_FILE GATE_SHARED_CORPUS_ROOT
if common_shared_corpus_available; then
  pass "case23: common_shared_corpus_available reports true once GATE_SHARED_CORPUS_FILE/_ROOT are exported and the corpus file is readable"
else
  fail "case23: common_shared_corpus_available reported unavailable with both variables exported and the file readable"
fi

filtered23="$(common_shared_corpus_files '*.sh' | tr '\0' '\n' | sort)"
expected23="$(printf '%s\n%s' "$SYNTH22_ROOT/agent-system/extensions/fakeext/scripts/clean.sh" "$SYNTH22_ROOT/agent-system/extensions/fakeext/scripts/dirty.sh")"
if [ "$filtered23" = "$expected23" ]; then
  pass "case23b: common_shared_corpus_files '*.sh' returns both entries as absolute paths prefixed with GATE_SHARED_CORPUS_ROOT"
else
  fail "case23b: common_shared_corpus_files filtering regressed" "got: [$filtered23] want: [$expected23]"
fi

# Case 24: the seeded violation (dirty.sh) is actually detected end-to-end when lint-shellcheck.sh
# is invoked with NO scan-path argument and the shared-corpus env vars exported -- this is the
# real consumer path every gate12/17/18/21/22/23_run() function exercises, not just the plumbing
# functions in isolation. Requires shellcheck on PATH; degrades to a skip (not a failure) when it
# is not, matching this suite's own portability posture elsewhere.
if command -v shellcheck >/dev/null 2>&1; then
  sc_out="$(bash "$SHELLCHECK_LINT" 2>&1)"
  sc_rc=$?
  if [ "$sc_rc" -eq 1 ] && printf '%s' "$sc_out" | grep -q 'dirty\.sh'; then
    pass "case24: lint-shellcheck.sh, invoked with no scan-path argument and the shared-corpus env vars exported, detects the seeded dirty.sh violation via the shared-corpus fast path (rc=1)"
  else
    fail "case24: shared-corpus consumer path did not detect the seeded violation" "rc=$sc_rc out=$sc_out"
  fi
else
  echo "[INFO] case24: skipped -- shellcheck not on PATH"
fi

unset GATE_SHARED_CORPUS_FILE GATE_SHARED_CORPUS_ROOT

# Case 25: with the shared-corpus env vars unset (ordinary standalone invocation), the exact
# same lint-shellcheck.sh binary against the exact same seeded fixture, via an EXPLICIT scan-path
# argument (the "dual file-set contract" `find`-based branch -- SCRIPT_DIR/PROJECT_ROOT
# resolution walks up from the LINT SCRIPT's own real on-disk location, not the caller's cwd, so
# a no-args invocation here cannot be redirected at the synthetic repo; an explicit path is the
# correct way to target it, and is exactly what every existing fixture test in this codebase
# already does for this lint -- see test-lint-shellcheck.sh), must still detect the seeded
# violation -- proving the shared-corpus fast path (case24) and the find-based fallback agree on
# this fixture, not only on the real corpus (cases above).
if command -v shellcheck >/dev/null 2>&1; then
  sc_out25="$(bash "$SHELLCHECK_LINT" "$SYNTH22_ROOT/agent-system/extensions" 2>&1)"
  sc_rc25=$?
  if [ "$sc_rc25" -eq 1 ] && printf '%s' "$sc_out25" | grep -q 'dirty\.sh'; then
    pass "case25: the same seeded violation is detected via the pre-existing find-based explicit-path fallback (shared-corpus env vars unset, rc=1)"
  else
    fail "case25: explicit-path fallback regressed on the same fixture" "rc=$sc_rc25 out=$sc_out25"
  fi
else
  echo "[INFO] case25: skipped -- shellcheck not on PATH"
fi

# ─── Case 26-30: the ninth `input_corpus` field (this task's Phase 2) ───────────────────────────
# Covers the loader/accessor round-trip and the lint's rejection of a legacy 8-field row, an
# empty (non-"-") corpus field, and an unparseable entry -- the three malformations Phase 2's own
# task list names explicitly. LINT_SCRIPT is read fresh here rather than assumed from an earlier
# section.
LINT_SCRIPT="$CORE_DIR/lint/lint-gate-registry.sh"

gate_registry_load "$REAL_DATA"

# Case 26: a real nine-field row's input_corpus round-trips through the loader and accessor.
if [ "$(gate_registry_field 2 input_corpus)" = ".claude/settings.json" ]; then
  pass "case26: gate_registry_field resolves gate 2's input_corpus correctly (nine-field round-trip)"
else
  fail "case26: gate 2 input_corpus mismatch (got: '$(gate_registry_field 2 input_corpus)')"
fi

# Case 27: the "-" placeholder (gate 14, declared '-' deliberately -- see this task's Phase 2
# planning note) normalizes to a truly empty string, mirroring the dependencies field's own
# normalization and for the identical IFS=$'\t' empty-field-collapse reason.
if [ "$(gate_registry_field 14 input_corpus)" = "" ]; then
  pass "case27: the '-' input_corpus placeholder (gate 14) normalizes to empty, not the literal '-'"
else
  fail "case27: expected empty input_corpus for gate 14 (got: '$(gate_registry_field 14 input_corpus)')"
fi

# Case 28: a synthetic registry built by DROPPING the 9th field from an otherwise-valid row (7
# tabs instead of 8) is rejected LOUDLY by the lint, never silently mis-parsed (which would shift
# 'serialized' into 'input_corpus' and leave the real input_corpus unset).
SYNTH26="$WORKDIR/synth26-eightfield.data"
awk -F'\t' 'BEGIN{OFS="\t"} /^1\t/{NF=8} {print}' "$REAL_DATA" > "$SYNTH26"
out28="$(bash "$LINT_SCRIPT" "$SYNTH26" 2>&1)"; rc28=$?
if [ "$rc28" -eq 1 ] && echo "$out28" | grep -q "row has 7 tab(s), expected exactly 8"; then
  pass "case28: lint-gate-registry.sh loudly rejects a legacy 8-field (7-tab) row rather than silently mis-parsing it"
else
  fail "case28: expected a loud field-count rejection (rc=$rc28)" "$out28"
fi

# Case 29: a synthetic registry whose input_corpus field is blank (not '-') is rejected -- blank
# is never a silent synonym for "not declared."
SYNTH27="$WORKDIR/synth27-blankcorpus.data"
awk -F'\t' 'BEGIN{OFS="\t"} /^2\t/{$9=""} {print}' "$REAL_DATA" > "$SYNTH27"
out29="$(bash "$LINT_SCRIPT" "$SYNTH27" 2>&1)"; rc29=$?
if [ "$rc29" -eq 1 ] && echo "$out29" | grep -q "input_corpus is empty"; then
  pass "case29: lint-gate-registry.sh rejects a blank (non-'-') input_corpus field"
else
  fail "case29: expected a blank-corpus rejection (rc=$rc29)" "$out29"
fi

# Case 30: a synthetic registry with an unparseable input_corpus entry (disallowed characters) is
# rejected by the lint's grammar check.
SYNTH28="$WORKDIR/synth28-badentry.data"
awk -F'\t' 'BEGIN{OFS="\t"} /^2\t/{$9="some|bad;entry"} {print}' "$REAL_DATA" > "$SYNTH28"
out30="$(bash "$LINT_SCRIPT" "$SYNTH28" 2>&1)"; rc30=$?
if [ "$rc30" -eq 1 ] && echo "$out30" | grep -q "does not match any grammar shape"; then
  pass "case30: lint-gate-registry.sh rejects an input_corpus entry that does not parse against the grammar"
else
  fail "case30: expected an unparseable-entry rejection (rc=$rc30)" "$out30"
fi

# Case 31: the real, populated gate-registry.data itself passes the lint cleanly end to end
# (all 23 rows, nine fields, grammar-conformant corpora) -- the positive control for cases 28-30.
out31="$(bash "$LINT_SCRIPT" "$REAL_DATA" 2>&1)"; rc31=$?
if [ "$rc31" -eq 0 ]; then
  pass "case31: lint-gate-registry.sh passes cleanly on the real, populated gate-registry.data"
else
  fail "case31: expected the real registry to pass the lint (rc=$rc31)" "$out31"
fi

# Restore the real registry for any downstream consumer of this same shell (defensive; this
# suite's own process exits right after, but mirrors good hygiene).
gate_registry_load "$REAL_DATA"

echo ""
echo "Results: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
