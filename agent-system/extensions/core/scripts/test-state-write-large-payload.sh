#!/usr/bin/env bash
# test-state-write-large-payload.sh - Isolated-temp-root suite proving state-write.sh's
# transparent oversized-`--argjson` spill and the additive `--argjson-file NAME PATH` flag work
# above Linux's 131,072-byte MAX_ARG_STRLEN ceiling (the "128KB argv ceiling").
#
# Follows test-state-write-concurrency.sh's precedent exactly: build a throwaway $TMPROOT, copy
# state-write.sh (and its dependencies) byte-for-byte, never touch the real specs/ tree,
# pass()/fail() counters, exit 0/1 on suite result. No testability hooks are added to production
# code -- state-write.sh is copied unmodified and never learns it is under test.
#
# IMPORTANT finding from Phase 1 (recorded here so a future reader does not "fix" this file to
# match the plan's literal Case A wording): Linux's MAX_ARG_STRLEN (131,072 bytes) applies to the
# OS-level execve() that launches state-write.sh's OWN bash-interpreted process, not only to its
# internal jq invocation. A caller therefore CANNOT pass a >131,072-byte raw value via literal
# `--argjson NAME VALUE` on state-write.sh's own command line at all -- the shell fails to exec
# state-write.sh itself (exit 126) before any internal script code (including the Phase 1 spill
# logic) ever runs. This is proven directly in Case A0 below. The mechanism that actually accepts
# a payload above the ceiling in one call is `--argjson-file NAME PATH` (PATH is a short argv
# token regardless of file size) -- this is what Cases A/B/C/D exercise for "above the ceiling".
# The transparent `--argjson` spill path (Phase 1's other deliverable) is still real and
# separately verified in Case E at a value inside the only range it can ever be reached in:
# (100000, ~131072] bytes, where state-write.sh's own invocation still succeeds.
#
# Exit 0 when all cases PASS, exit 1 when any case FAILS.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  PASSED=$((PASSED + 1))
}

fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  FAILED=$((FAILED + 1))
}

info() {
  echo -e "${YELLOW}[INFO]${NC} $1"
}

# --- Locate the real scripts to copy into the fixture ---
for f in state-write.sh task-lock.sh generate-todo.sh deploy-root-guard.sh lib/common.sh lib/task-lookup-lib.sh; do
  if [ ! -f "$SCRIPT_DIR/$f" ]; then
    echo "ERROR: expected $f alongside this script in $SCRIPT_DIR" >&2
    exit 1
  fi
done

# --- Build the isolated temp root ---
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/state-write-large-payload-test.XXXXXX")"

cleanup_root() {
  [ -n "${TMPROOT:-}" ] && [ -d "$TMPROOT" ] && rm -rf "$TMPROOT"
}
trap cleanup_root EXIT

mkdir -p "$TMPROOT/.claude/scripts/lib"
mkdir -p "$TMPROOT/specs"
cp "$SCRIPT_DIR/state-write.sh" "$TMPROOT/.claude/scripts/state-write.sh"
cp "$SCRIPT_DIR/task-lock.sh" "$TMPROOT/.claude/scripts/task-lock.sh"
cp "$SCRIPT_DIR/generate-todo.sh" "$TMPROOT/.claude/scripts/generate-todo.sh"
cp "$SCRIPT_DIR/deploy-root-guard.sh" "$TMPROOT/.claude/scripts/deploy-root-guard.sh"
cp "$SCRIPT_DIR/lib/common.sh" "$TMPROOT/.claude/scripts/lib/common.sh"
cp "$SCRIPT_DIR/lib/task-lookup-lib.sh" "$TMPROOT/.claude/scripts/lib/task-lookup-lib.sh"
chmod +x "$TMPROOT/.claude/scripts/"*.sh

SW="$TMPROOT/.claude/scripts/state-write.sh"
STATE_FILE="$TMPROOT/specs/state.json"

reset_state_json() {
  cat > "$STATE_FILE" << 'EOF'
{
  "next_project_number": 3,
  "active_projects": [
    {"project_number": 1, "project_name": "case_a", "status": "implementing"},
    {"project_number": 2, "project_name": "case_b", "status": "implementing"}
  ]
}
EOF
}

reset_state_json
info "Fixture built at $TMPROOT"

# Generate a JSON array payload of at least $1 bytes (measures the actual serialized length
# rather than guessing element counts -- MAX_ARG_STRLEN is a byte, not element, ceiling).
gen_payload() {
  local min_bytes="$1"
  python3 -c "
import json, sys
target = $min_bytes
arr = []
i = 0
while len(json.dumps(arr)) < target:
    arr.append({'i': i, 'text': 'x' * 40})
    i += 1
print(json.dumps(arr))
"
}

# =====================================================================
# Case A0: the OS-level ceiling itself -- a >131,072-byte value passed as a literal --argjson
# argument on state-write.sh's OWN command line fails to even exec (proves the Phase 1 finding
# and justifies why Cases A-D below use --argjson-file for "above the ceiling").
# =====================================================================
OVERSIZED_PAYLOAD="$(gen_payload 200000)"
info "OVERSIZED_PAYLOAD length: ${#OVERSIZED_PAYLOAD} bytes"

(
  cd "$TMPROOT"
  "$SW" '.' --session-id "sess_caseA0" --argjson stuff "$OVERSIZED_PAYLOAD" --dry-run \
    > "$TMPROOT/caseA0.out" 2>&1
  echo $? > "$TMPROOT/caseA0.exit"
)
caseA0_exit=$(cat "$TMPROOT/caseA0.exit" 2>/dev/null || echo "?")

if [ "$caseA0_exit" = "126" ]; then
  pass "A0: a >131,072-byte value via literal --argjson fails to exec state-write.sh itself (exit 126) -- confirmed OS-level MAX_ARG_STRLEN ceiling, not fixable inside the script"
else
  fail "A0: expected exit 126 (OS exec failure) for an oversized literal --argjson invocation, got $caseA0_exit: $(cat "$TMPROOT/caseA0.out" 2>/dev/null | head -c 300)"
fi

# =====================================================================
# Case A: --argjson-file with a >131,072-byte file in ONE call exits 0 -- this is the exact shape
# that fails today (as any oversized single call must, per A0) with plain --argjson.
# =====================================================================
PAYLOAD_FILE="$TMPROOT/big_payload.json"
gen_payload 200000 > "$PAYLOAD_FILE"
PAYLOAD_BYTES=$(wc -c < "$PAYLOAD_FILE")
info "PAYLOAD_FILE size: ${PAYLOAD_BYTES} bytes"

reset_state_json
(
  cd "$TMPROOT"
  "$SW" '. + {"big": $bigval}' --session-id "sess_caseA" --argjson-file bigval "$PAYLOAD_FILE" \
    > "$TMPROOT/caseA.out" 2>&1
  echo $? > "$TMPROOT/caseA.exit"
)
caseA_exit=$(cat "$TMPROOT/caseA.exit" 2>/dev/null || echo "?")

caseA_ok=true
[ "$caseA_exit" = "0" ] || { caseA_ok=false; info "caseA exited $caseA_exit (expected 0): $(cat "$TMPROOT/caseA.out" 2>/dev/null | head -c 300)"; }
if [ "$caseA_ok" = true ]; then
  diff <(jq -S '.big' "$STATE_FILE") <(jq -S '.' "$PAYLOAD_FILE") > /dev/null 2>&1 || { caseA_ok=false; info "caseA: written .big does not match source payload"; }
fi

if [ "$caseA_ok" = true ]; then
  pass "A: --argjson-file with a ${PAYLOAD_BYTES}-byte file (above the 131,072-byte ceiling) in one call exits 0 and writes correct state"
else
  fail "A: --argjson-file oversized-payload case failed (see INFO lines above)"
fi

# =====================================================================
# Case B: byte-identity -- the same total payload applied via one --argjson-file call vs. split
# into 4 smaller plain --argjson calls (the documented manual workaround) produces diff-identical
# state.json.
# =====================================================================
python3 -c "
import json
arr = [{'i': i, 'text': 'y' * 30} for i in range(2000)]
with open('$TMPROOT/split_payload.json', 'w') as f:
    json.dump(arr, f)
"
SPLIT_PAYLOAD_BYTES=$(wc -c < "$TMPROOT/split_payload.json")
info "split payload size: ${SPLIT_PAYLOAD_BYTES} bytes (chunked into 4 calls of 500 elements each)"

# One-call path via --argjson-file
reset_state_json
(
  cd "$TMPROOT"
  "$SW" '. + {"items": $v}' --session-id "sess_caseB_one" --argjson-file v "$TMPROOT/split_payload.json" \
    > "$TMPROOT/caseB_one.out" 2>&1
  echo $? > "$TMPROOT/caseB_one.exit"
)
caseB_one_exit=$(cat "$TMPROOT/caseB_one.exit" 2>/dev/null || echo "?")
ONE_CALL_RESULT="$TMPROOT/caseB_one_state.json"
cp "$STATE_FILE" "$ONE_CALL_RESULT"

# Batched-workaround path: 4 plain --argjson calls, each appending a quarter of the array
reset_state_json
(
  cd "$TMPROOT"
  "$SW" '. + {"items": []}' --session-id "sess_caseB_init" > "$TMPROOT/caseB_batch.out" 2>&1
  batch_ok=$?
  for chunk in 0 1 2 3; do
    chunk_json=$(python3 -c "
import json
arr = json.load(open('$TMPROOT/split_payload.json'))
lo = $chunk * 500
hi = lo + 500
print(json.dumps(arr[lo:hi]))
")
    "$SW" '.items += $chunk' --session-id "sess_caseB_batch_$chunk" --argjson chunk "$chunk_json" \
      >> "$TMPROOT/caseB_batch.out" 2>&1
    [ "$?" = "0" ] || batch_ok=1
  done
  echo "$batch_ok" > "$TMPROOT/caseB_batch.exit"
)
caseB_batch_exit=$(cat "$TMPROOT/caseB_batch.exit" 2>/dev/null || echo "?")
BATCH_RESULT="$TMPROOT/caseB_batch_state.json"
cp "$STATE_FILE" "$BATCH_RESULT"

caseB_ok=true
[ "$caseB_one_exit" = "0" ] || { caseB_ok=false; info "caseB one-call exited $caseB_one_exit: $(cat "$TMPROOT/caseB_one.out" 2>/dev/null | head -c 300)"; }
[ "$caseB_batch_exit" = "0" ] || { caseB_ok=false; info "caseB batched calls exited $caseB_batch_exit: $(cat "$TMPROOT/caseB_batch.out" 2>/dev/null | head -c 300)"; }
if [ "$caseB_ok" = true ]; then
  diff <(jq -S '.items' "$ONE_CALL_RESULT") <(jq -S '.items' "$BATCH_RESULT") > /dev/null 2>&1 || { caseB_ok=false; info "caseB: one-call .items differs from batched .items"; }
fi

if [ "$caseB_ok" = true ]; then
  pass "B: one-call --argjson-file payload produces state.json byte-identical (on .items) to the 4-batch --argjson workaround"
else
  fail "B: byte-identity case failed (see INFO lines above)"
fi

# =====================================================================
# Case C: filter-semantics -- a spilled binding used (i) as a plain scalar/array binding, (ii)
# inside a select() predicate, (iii) inside array construction, each producing the expected
# result. Covers the EFFECTIVE_FILTER prefix-injection risk (`($priv[0]) as $NAME | <orig>`).
# =====================================================================
python3 -c "
import json
payload = {'nums': [10, 20, 30], 'pad': 'z' * 150000}
with open('$TMPROOT/filter_payload.json', 'w') as f:
    json.dump(payload, f)
"
info "filter_payload.json size: $(wc -c < "$TMPROOT/filter_payload.json") bytes"

caseC_ok=true

# (i) scalar/array binding
reset_state_json
(
  cd "$TMPROOT"
  "$SW" '. + {"scalar_check": ($v.nums | length)}' --session-id "sess_caseC_scalar" \
    --argjson-file v "$TMPROOT/filter_payload.json" > "$TMPROOT/caseC_scalar.out" 2>&1
  echo $? > "$TMPROOT/caseC_scalar.exit"
)
[ "$(cat "$TMPROOT/caseC_scalar.exit" 2>/dev/null)" = "0" ] || { caseC_ok=false; info "caseC scalar binding exit != 0: $(cat "$TMPROOT/caseC_scalar.out" 2>/dev/null)"; }
[ "$(jq '.scalar_check' "$STATE_FILE" 2>/dev/null)" = "3" ] || { caseC_ok=false; info "caseC scalar binding: expected scalar_check == 3"; }

# (ii) select() predicate
reset_state_json
(
  cd "$TMPROOT"
  "$SW" '.active_projects |= map(select(.project_number == ($v.nums[0] - 9)))' --session-id "sess_caseC_select" \
    --argjson-file v "$TMPROOT/filter_payload.json" > "$TMPROOT/caseC_select.out" 2>&1
  echo $? > "$TMPROOT/caseC_select.exit"
)
[ "$(cat "$TMPROOT/caseC_select.exit" 2>/dev/null)" = "0" ] || { caseC_ok=false; info "caseC select() exit != 0: $(cat "$TMPROOT/caseC_select.out" 2>/dev/null)"; }
[ "$(jq '.active_projects | length' "$STATE_FILE" 2>/dev/null)" = "1" ] || { caseC_ok=false; info "caseC select(): expected exactly one surviving project (project_number == 1)"; }

# (iii) array construction
reset_state_json
(
  cd "$TMPROOT"
  "$SW" '. + {"arr_check": [$v.nums[], "extra"]}' --session-id "sess_caseC_arr" \
    --argjson-file v "$TMPROOT/filter_payload.json" > "$TMPROOT/caseC_arr.out" 2>&1
  echo $? > "$TMPROOT/caseC_arr.exit"
)
[ "$(cat "$TMPROOT/caseC_arr.exit" 2>/dev/null)" = "0" ] || { caseC_ok=false; info "caseC array construction exit != 0: $(cat "$TMPROOT/caseC_arr.out" 2>/dev/null)"; }
[ "$(jq -c '.arr_check' "$STATE_FILE" 2>/dev/null)" = "[10,20,30,\"extra\"]" ] || { caseC_ok=false; info "caseC array construction: unexpected arr_check value: $(jq -c '.arr_check' "$STATE_FILE" 2>/dev/null)"; }

if [ "$caseC_ok" = true ]; then
  pass "C: spilled binding resolves correctly as a scalar binding, inside select(), and inside array construction"
else
  fail "C: filter-semantics case failed (see INFO lines above)"
fi

# =====================================================================
# Case D: --argjson-file NAME PATH with a >128KB file produces the same result as Case A (a
# second, independently-constructed payload to guard against Case A's fixture being coincidental).
# =====================================================================
python3 -c "
import json
arr = [{'k': i, 'v': 'w' * 60} for i in range(2500)]
with open('$TMPROOT/payload_d.json', 'w') as f:
    json.dump(arr, f)
"
PAYLOAD_D_BYTES=$(wc -c < "$TMPROOT/payload_d.json")
info "payload_d.json size: ${PAYLOAD_D_BYTES} bytes"

reset_state_json
(
  cd "$TMPROOT"
  "$SW" '. + {"d": $v}' --session-id "sess_caseD" --argjson-file v "$TMPROOT/payload_d.json" \
    --dry-run > "$TMPROOT/caseD_dry.out" 2>&1
  echo $? > "$TMPROOT/caseD_dry.exit"
)
caseD_dry_exit=$(cat "$TMPROOT/caseD_dry.exit" 2>/dev/null || echo "?")

reset_state_json
(
  cd "$TMPROOT"
  "$SW" '. + {"d": $v}' --session-id "sess_caseD" --argjson-file v "$TMPROOT/payload_d.json" \
    > "$TMPROOT/caseD.out" 2>&1
  echo $? > "$TMPROOT/caseD.exit"
)
caseD_exit=$(cat "$TMPROOT/caseD.exit" 2>/dev/null || echo "?")

caseD_ok=true
[ "$PAYLOAD_D_BYTES" -gt 131072 ] || { caseD_ok=false; info "caseD: fixture payload_d.json (${PAYLOAD_D_BYTES} bytes) did not actually exceed the 131,072-byte ceiling -- test proves nothing"; }
[ "$caseD_dry_exit" = "0" ] || { caseD_ok=false; info "caseD --dry-run exited $caseD_dry_exit (expected 0): $(cat "$TMPROOT/caseD_dry.out" 2>/dev/null | head -c 300)"; }
[ "$caseD_exit" = "0" ] || { caseD_ok=false; info "caseD real write exited $caseD_exit (expected 0): $(cat "$TMPROOT/caseD.out" 2>/dev/null | head -c 300)"; }
if [ "$caseD_ok" = true ]; then
  diff <(jq -S '.d' "$STATE_FILE") <(jq -S '.' "$TMPROOT/payload_d.json") > /dev/null 2>&1 || { caseD_ok=false; info "caseD: written .d does not match source payload"; }
fi

if [ "$caseD_ok" = true ]; then
  pass "D: --argjson-file NAME PATH with a second independent >128KB file (${PAYLOAD_D_BYTES} bytes) exits 0 in both --dry-run and real-write modes with correct output"
else
  fail "D: independent --argjson-file case failed (see INFO lines above)"
fi

# =====================================================================
# Case E: under-threshold --argjson still takes the plain argv path (unchanged behavior), AND
# the transparent spill path is genuinely exercised in the only range it can ever be reached in:
# (100000, ~131072] bytes, where state-write.sh's own invocation still succeeds (see the header
# note on the A0 finding).
# =====================================================================
SMALL_VAL='{"a": 1, "b": [1,2,3]}'
reset_state_json
(
  cd "$TMPROOT"
  "$SW" '. + {"small": $v}' --session-id "sess_caseE_small" --argjson v "$SMALL_VAL" \
    > "$TMPROOT/caseE_small.out" 2>&1
  echo $? > "$TMPROOT/caseE_small.exit"
)
caseE_small_ok=true
[ "$(cat "$TMPROOT/caseE_small.exit" 2>/dev/null)" = "0" ] || { caseE_small_ok=false; info "caseE small --argjson exit != 0: $(cat "$TMPROOT/caseE_small.out" 2>/dev/null)"; }
[ "$(jq -c '.small' "$STATE_FILE" 2>/dev/null)" = '{"a":1,"b":[1,2,3]}' ] || { caseE_small_ok=false; info "caseE small --argjson: unexpected .small value"; }
[ -z "$(find "$TMPROOT/specs" -maxdepth 1 -name 'state-write-spill.*' 2>/dev/null)" ] || { caseE_small_ok=false; info "caseE: a spill file was created for an under-threshold value"; }

# In-range spill path: a value just under the OS's own exec ceiling but over SPILL_THRESHOLD
INRANGE_VAL="$(gen_payload 125000)"
info "in-range spilled value length: ${#INRANGE_VAL} bytes"
reset_state_json
(
  cd "$TMPROOT"
  "$SW" '. + {"mid": $v}' --session-id "sess_caseE_mid" --argjson v "$INRANGE_VAL" \
    > "$TMPROOT/caseE_mid.out" 2>&1
  echo $? > "$TMPROOT/caseE_mid.exit"
)
caseE_mid_ok=true
[ "${#INRANGE_VAL}" -gt 100000 ] || { caseE_mid_ok=false; info "caseE: in-range fixture did not actually exceed SPILL_THRESHOLD (100000 bytes)"; }
[ "$(cat "$TMPROOT/caseE_mid.exit" 2>/dev/null)" = "0" ] || { caseE_mid_ok=false; info "caseE in-range spilled --argjson exit != 0: $(cat "$TMPROOT/caseE_mid.out" 2>/dev/null | head -c 300)"; }
if [ "$caseE_mid_ok" = true ]; then
  diff <(jq -S '.mid' "$STATE_FILE") <(echo "$INRANGE_VAL" | jq -S '.') > /dev/null 2>&1 || { caseE_mid_ok=false; info "caseE: written .mid does not match the in-range spilled value"; }
fi

if [ "$caseE_small_ok" = true ] && [ "$caseE_mid_ok" = true ]; then
  pass "E: under-threshold --argjson takes the unchanged plain path (no spill file), and the spill path is verified for the reachable (100000, ~131072] byte range"
else
  fail "E: under-threshold/in-range --argjson case failed (see INFO lines above)"
fi

# =====================================================================
# Case F: --dry-run with an oversized payload (via --argjson-file) exits 0 and leaves no temp
# files behind, including no leaked spill file from argument parsing.
# =====================================================================
reset_state_json
before_files=$(find "$TMPROOT/specs" -type f | sort)
(
  cd "$TMPROOT"
  "$SW" '. + {"big": $v}' --session-id "sess_caseF" --argjson-file v "$PAYLOAD_FILE" --dry-run \
    > "$TMPROOT/caseF.out" 2>&1
  echo $? > "$TMPROOT/caseF.exit"
)
caseF_exit=$(cat "$TMPROOT/caseF.exit" 2>/dev/null || echo "?")
after_files=$(find "$TMPROOT/specs" -type f | sort)

# Also exercise the plain --argjson spill path under --dry-run (in-range value, per A0's finding)
(
  cd "$TMPROOT"
  "$SW" '. + {"mid": $v}' --session-id "sess_caseF_spill" --argjson v "$INRANGE_VAL" --dry-run \
    > "$TMPROOT/caseF_spill.out" 2>&1
  echo $? > "$TMPROOT/caseF_spill.exit"
)
caseF_spill_exit=$(cat "$TMPROOT/caseF_spill.exit" 2>/dev/null || echo "?")
after_files_spill=$(find "$TMPROOT/specs" -type f | sort)

caseF_ok=true
[ "$caseF_exit" = "0" ] || { caseF_ok=false; info "caseF --argjson-file --dry-run exited $caseF_exit (expected 0)"; }
[ "$caseF_spill_exit" = "0" ] || { caseF_ok=false; info "caseF spilled --argjson --dry-run exited $caseF_spill_exit (expected 0)"; }
[ "$before_files" = "$after_files" ] || { caseF_ok=false; info "caseF: files under specs/ changed after --argjson-file --dry-run"; }
[ "$after_files" = "$after_files_spill" ] || { caseF_ok=false; info "caseF: files under specs/ changed after spilled --argjson --dry-run (spill file leaked)"; }

if [ "$caseF_ok" = true ]; then
  pass "F: --dry-run with an oversized payload (both --argjson-file and the in-range spilled --argjson path) exits 0 and leaks no temp files"
else
  fail "F: --dry-run no-leak case failed (see INFO lines above)"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
