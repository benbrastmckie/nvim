#!/usr/bin/env bash
# test-state-write-spill-names.sh - Isolated-temp-root suite proving state-write.sh assigns a
# DISTINCT private jq --slurpfile binding name to every spilled binding, across both spill
# branches (the transparent oversized --argjson auto-spill, and the caller-driven --argjson-file
# flag), and that a duplicate caller-supplied public NAME hard-fails loudly rather than silently
# last-write-winning.
#
# Follows test-state-write-large-payload.sh's precedent exactly: build a throwaway $TMPROOT, copy
# state-write.sh (and its dependencies) byte-for-byte, never touch the real specs/ tree,
# pass()/fail() counters, exit 0/1 on suite result. No testability hooks are added to production
# code -- state-write.sh is copied unmodified and never learns it is under test.
#
# THE DEFECT THIS SUITE PROVES (pre-fix): both spill branches allocate their private jq binding
# name as `private_name="__spill_${#SPILL_FILES[@]}"`, but only the --arg/--argjson auto-spill
# branch appends to SPILL_FILES afterward. The --argjson-file branch (which never mktemps
# anything -- the caller supplied the file) never appends, so #SPILL_FILES[@] stays 0 forever and
# every --argjson-file binding is named __spill_0. jq's duplicate---slurpfile first-wins semantics
# then silently substitute the FIRST spilled file's value for every later --argjson-file binding.
# Because the two branches share this one counter and only one of them advances it, a MIXED call
# (one --argjson-file plus one oversized --argjson in the same invocation) also corrupts: the
# --argjson-file spill consumes index 0 without advancing it, so the subsequent --argjson
# auto-spill's own __spill_${#SPILL_FILES[@]} computation (now #SPILL_FILES[@]==1, since THAT
# branch did append its own mktemp file) can still land on an index already claimed depending on
# call order -- Case B below constructs the mixed shape and asserts per-binding identity directly
# rather than asserting the mechanism, so it stays valid regardless of the exact fixed shape.
#
# WHY --argjson-file (not --argjson) FOR "over the ceiling": Linux's MAX_ARG_STRLEN (131,072
# bytes) applies to the OS-level execve() that launches state-write.sh's own bash-interpreted
# process, not only to its internal jq invocation -- a caller cannot pass a >131,072-byte raw
# value via literal `--argjson NAME VALUE` on state-write.sh's own command line at all (see
# test-state-write-large-payload.sh's Case A0 for the direct proof). Case A/C below therefore use
# --argjson-file (PATH is a short argv token regardless of file size) to reach the
# --argjson-file branch's defect at all reliably; Case B additionally drives the --argjson
# auto-spill branch with an in-range (SPILL_THRESHOLD, ~131072] byte value, exactly as
# test-state-write-large-payload.sh's own Case E does, since that is the only byte range in which
# state-write.sh's own invocation still succeeds.
#
# Exit 0 when all cases PASS, exit 1 when any case FAILS.

# shellcheck disable=SC2016  # jq filters below are intentionally single-quoted: $NAME is jq's
# own variable syntax and must NOT be shell-expanded.
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

# --- Guard: the real repo specs/state.json must be untouched by this run, start and end. This
# is a belt-and-braces check against the exact incident state-write.sh's implementer hit during
# reproduction (BASH_SOURCE-derived PROJECT_ROOT resolves against the SCRIPT COPY's own location,
# so invoking a copy correctly rooted under $TMPROOT is safe -- but this assertion catches a
# fixture-construction mistake that would not be). Never depends on being run from inside a git
# work tree with a clean state.json already -- it only compares before/after within this run.
REAL_REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
REAL_STATE_FILE="$REAL_REPO_ROOT/specs/state.json"
real_state_before=""
if [ -f "$REAL_STATE_FILE" ]; then
  real_state_before="$(cd "$REAL_REPO_ROOT" && git status --porcelain -- specs/state.json 2>/dev/null || echo "NOGIT")"
fi

# --- Locate the real scripts to copy into the fixture ---
for f in state-write.sh task-lock.sh generate-todo.sh deploy-root-guard.sh lib/common.sh lib/task-lookup-lib.sh; do
  if [ ! -f "$SCRIPT_DIR/$f" ]; then
    echo "ERROR: expected $f alongside this script in $SCRIPT_DIR" >&2
    exit 1
  fi
done

# --- Build the isolated temp root ---
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/state-write-spill-names-test.XXXXXX")"

# shellcheck disable=SC2329  # invoked indirectly via the EXIT trap below, not a dead function
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

# Generate a JSON array payload of at least $1 bytes.
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
# Case A: pure multi-file -- two DISTINCT --argjson-file bindings in ONE call must each resolve
# to their OWN file's value. This is the defect's cleanest reproduction: pre-fix, both bindings
# are named __spill_0 and jq's first-wins semantics make BOTH resolve to the first file's value.
# =====================================================================
python3 -c "
import json
with open('$TMPROOT/payload_first.json', 'w') as f:
    json.dump({'marker': 'FIRST', 'nums': [1, 2, 3]}, f)
with open('$TMPROOT/payload_second.json', 'w') as f:
    json.dump({'marker': 'SECOND', 'nums': [4, 5, 6, 7]}, f)
"

reset_state_json
(
  cd "$TMPROOT" || exit 1
  "$SW" '. + {"first": $a, "second": $b}' --session-id "sess_caseA" \
    --argjson-file a "$TMPROOT/payload_first.json" \
    --argjson-file b "$TMPROOT/payload_second.json" \
    > "$TMPROOT/caseA.out" 2>&1
  echo $? > "$TMPROOT/caseA.exit"
)
caseA_exit=$(cat "$TMPROOT/caseA.exit" 2>/dev/null || echo "?")

caseA_ok=true
if [ "$caseA_exit" != "0" ]; then
  caseA_ok=false
  info "caseA: exited $caseA_exit (expected 0): $(cat "$TMPROOT/caseA.out" 2>/dev/null | head -c 300)"
else
  first_marker=$(jq -r '.first.marker // "MISSING"' "$STATE_FILE" 2>/dev/null)
  second_marker=$(jq -r '.second.marker // "MISSING"' "$STATE_FILE" 2>/dev/null)
  info "caseA: .first.marker=$first_marker .second.marker=$second_marker"
  if [ "$first_marker" != "FIRST" ] || [ "$second_marker" != "SECOND" ]; then
    caseA_ok=false
    info "caseA: expected .first.marker=FIRST and .second.marker=SECOND -- got .first.marker=$first_marker .second.marker=$second_marker (each --argjson-file binding must resolve to ITS OWN file's value)"
  fi
fi

if [ "$caseA_ok" = true ]; then
  pass "A: two distinct --argjson-file bindings in one call each resolve to their own file's value"
else
  fail "A: two --argjson-file bindings in one call collided -- one file's value overwrote the other (the defect: both named __spill_0)"
fi

# =====================================================================
# Case B: mixed call -- one --argjson-file binding combined with an oversized (>SPILL_THRESHOLD,
# but under the ~131072-byte exec ceiling) --argjson auto-spill binding, PLUS a plain small --arg
# binding to confirm the non-spilling path is unaffected. Asserts each of the three resolves to
# its own value. This is the "subtler half" the dispatch calls out: the two branches sharing one
# counter that only one of them advances corrupts even a single --argjson-file binding once mixed
# with an auto-spill.
# =====================================================================
python3 -c "
import json
with open('$TMPROOT/payload_mixed_file.json', 'w') as f:
    json.dump({'marker': 'FILEVAL', 'tag': 'from-argjson-file'}, f)
"
INRANGE_VAL="$(gen_payload 125000)"
info "caseB in-range auto-spill value length: ${#INRANGE_VAL} bytes"

reset_state_json
(
  cd "$TMPROOT" || exit 1
  "$SW" '. + {"filed": $f, "spilled": $s, "plain": $p}' --session-id "sess_caseB" \
    --argjson-file f "$TMPROOT/payload_mixed_file.json" \
    --argjson s "$INRANGE_VAL" \
    --arg p "plain-value" \
    > "$TMPROOT/caseB.out" 2>&1
  echo $? > "$TMPROOT/caseB.exit"
)
caseB_exit=$(cat "$TMPROOT/caseB.exit" 2>/dev/null || echo "?")

caseB_ok=true
if [ "$caseB_exit" != "0" ]; then
  caseB_ok=false
  info "caseB: exited $caseB_exit (expected 0): $(cat "$TMPROOT/caseB.out" 2>/dev/null | head -c 300)"
else
  filed_marker=$(jq -r '.filed.marker // "MISSING"' "$STATE_FILE" 2>/dev/null)
  spilled_len=$(jq -r 'if (.spilled | type) == "array" then (.spilled | length) else "NOTARRAY" end' "$STATE_FILE" 2>/dev/null)
  plain_val=$(jq -r '.plain // "MISSING"' "$STATE_FILE" 2>/dev/null)
  info "caseB: .filed.marker=$filed_marker .spilled(len)=$spilled_len .plain=$plain_val"
  if [ "$filed_marker" != "FILEVAL" ]; then
    caseB_ok=false
    info "caseB: expected .filed.marker=FILEVAL, got $filed_marker (the --argjson-file binding was clobbered by the mixed auto-spill binding)"
  fi
  if ! echo "$INRANGE_VAL" | jq -e --argjson want "$spilled_len" '(. | length) == $want' > /dev/null 2>&1; then
    caseB_ok=false
    info "caseB: .spilled array length ($spilled_len) does not match the source auto-spilled payload's own length"
  fi
  if [ "$plain_val" != "plain-value" ]; then
    caseB_ok=false
    info "caseB: expected .plain=plain-value (non-spilling path must be unaffected), got $plain_val"
  fi
fi

if [ "$caseB_ok" = true ]; then
  pass "B: mixed --argjson-file + oversized --argjson + plain --arg call resolves all three bindings to their own values"
else
  fail "B: mixed --argjson-file + --argjson call corrupted at least one binding (the subtler shared-counter defect)"
fi

# =====================================================================
# Case C: duplicate public NAME across spilled bindings must be a LOUD, non-zero-exit error
# naming the NAME, never a silent last-write-wins. Pre-fix, state-write.sh has no such guard at
# all and exits 0 with the second binding silently overwriting the first in EFFECTIVE_FILTER's
# `as $NAME` prefix chain.
# =====================================================================
python3 -c "
import json
with open('$TMPROOT/payload_dup1.json', 'w') as f:
    json.dump({'which': 'one'}, f)
with open('$TMPROOT/payload_dup2.json', 'w') as f:
    json.dump({'which': 'two'}, f)
"

reset_state_json
(
  cd "$TMPROOT" || exit 1
  "$SW" '. + {"dup": $dupname}' --session-id "sess_caseC" \
    --argjson-file dupname "$TMPROOT/payload_dup1.json" \
    --argjson-file dupname "$TMPROOT/payload_dup2.json" \
    > "$TMPROOT/caseC.out" 2>&1
  echo $? > "$TMPROOT/caseC.exit"
)
caseC_exit=$(cat "$TMPROOT/caseC.exit" 2>/dev/null || echo "?")
caseC_stderr="$(cat "$TMPROOT/caseC.out" 2>/dev/null)"

caseC_ok=true
if [ "$caseC_exit" = "0" ]; then
  caseC_ok=false
  info "caseC: exited 0 for a duplicate spilled NAME ('dupname' passed twice) -- expected a non-zero hard error. Output: $(echo "$caseC_stderr" | head -c 300)"
else
  info "caseC: exited $caseC_exit for duplicate NAME 'dupname'"
  if ! echo "$caseC_stderr" | grep -qi "dupname"; then
    caseC_ok=false
    info "caseC: error output does not name the conflicting NAME ('dupname'): $(echo "$caseC_stderr" | head -c 300)"
  fi
fi

if [ "$caseC_ok" = true ]; then
  pass "C: a duplicate spilled public NAME hard-fails with a non-zero exit naming the NAME"
else
  fail "C: duplicate spilled public NAME did not hard-fail loudly (silent last-write-wins, or exit 0, or no NAME in diagnostic)"
fi

# =====================================================================
# Case D: ownership invariant -- a caller-supplied --argjson-file PATH must still exist on disk
# after a successful run. This guards against the tempting wrong "fix" of appending the caller's
# PATH to SPILL_FILES to advance the shared counter, which would make cleanup()'s
# `rm -f "${SPILL_FILES[@]}"` delete a caller-owned file. This is an invariant, not a defect
# probe -- it must PASS both before and after the fix.
# =====================================================================
python3 -c "
import json
with open('$TMPROOT/payload_owned.json', 'w') as f:
    json.dump({'owned': True}, f)
"

reset_state_json
(
  cd "$TMPROOT" || exit 1
  "$SW" '. + {"owned": $o}' --session-id "sess_caseD" \
    --argjson-file o "$TMPROOT/payload_owned.json" \
    > "$TMPROOT/caseD.out" 2>&1
  echo $? > "$TMPROOT/caseD.exit"
)
caseD_exit=$(cat "$TMPROOT/caseD.exit" 2>/dev/null || echo "?")

caseD_ok=true
[ "$caseD_exit" = "0" ] || { caseD_ok=false; info "caseD: exited $caseD_exit (expected 0): $(cat "$TMPROOT/caseD.out" 2>/dev/null | head -c 300)"; }
[ -f "$TMPROOT/payload_owned.json" ] || { caseD_ok=false; info "caseD: caller-supplied --argjson-file PATH was deleted by the run -- SPILL_FILES cleanup must never own a caller's file"; }

if [ "$caseD_ok" = true ]; then
  pass "D: a caller-supplied --argjson-file PATH survives the run (SPILL_FILES stays cleanup-ownership-only)"
else
  fail "D: caller-owned --argjson-file PATH did not survive the run"
fi

# =====================================================================
# Real-tree guard: confirm the real repo specs/state.json is untouched, start and end.
# =====================================================================
real_state_after=""
if [ -f "$REAL_STATE_FILE" ]; then
  real_state_after="$(cd "$REAL_REPO_ROOT" && git status --porcelain -- specs/state.json 2>/dev/null || echo "NOGIT")"
fi

if [ "$real_state_before" = "$real_state_after" ]; then
  pass "guard: real repo specs/state.json git status is unchanged before/after this suite ('${real_state_before:-clean}')"
else
  fail "guard: real repo specs/state.json git status CHANGED during this suite -- before='${real_state_before}' after='${real_state_after}'"
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
