#!/usr/bin/env bash
# test-orchestrate-record-decision.sh - Regression suite for orchestrate-record-decision.sh,
# proving the two load-bearing claims mechanically: concurrent invocation neither loses nor
# corrupts an entry, and malformed input is rejected with the target file left byte-identical.
#
# Structural model: scripts/tests/test-errors-append.sh (set -uo pipefail, pass()/fail()/info()
# helpers, PASSED/FAILED integer counters, exit 0 on all-pass / 1 on any-fail / 2 on environment
# error). Script-under-test resolution mirrors the deploy-tree-first / source-store-fallback
# candidate list used by that suite, so this one runs correctly both post-deploy
# (.claude/scripts/orchestrate-record-decision.sh) and in a source-store-only checkout
# (agent-system/extensions/core/scripts/orchestrate-record-decision.sh).
#
# Harness: each case builds an isolated scratch project root under mktemp -d, with
# <scratch>/.claude/scripts/{orchestrate-record-decision.sh,deploy-root-guard.sh,
# lib/common.sh,lib/task-lookup-lib.sh} copied in so deploy-root-guard.sh's `*/.claude` case
# matches and PROJECT_ROOT resolves to <scratch>, plus a scratch specs/state.json carrying one
# active project entry and that project's own directory -- the real script runs against a real
# scratch specs/{N}_{slug}/ tree, never the live repo's own specs/.
#
# NOTE: this file's test bodies invoke the script under test with its own --task CLI flag
# followed by a concrete literal integer throughout (the flag takes a number and a placeholder
# would make the invocation unusable, per the Exemption Taxonomy's category 3 "Command-usage
# examples"). The whole body below this header is wrapped in one task-ref-ok:begin/:end block
# for that reason rather than marking dozens of individual lines.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (orchestrate-record-decision.sh not found at any candidate path).

# task-ref-ok:begin inline, category 3: command-usage examples -- the script under test's own
# --task flag takes a concrete integer project/task number, used literally throughout this
# suite's invocations and scratch state.json fixtures.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

SCRIPT_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/orchestrate-record-decision.sh"
  "$SCRIPT_DIR/../orchestrate-record-decision.sh"
)
GUARD_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/deploy-root-guard.sh"
  "$SCRIPT_DIR/../deploy-root-guard.sh"
)
COMMON_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/lib/common.sh"
  "$SCRIPT_DIR/../lib/common.sh"
)
TASK_LOOKUP_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/lib/task-lookup-lib.sh"
  "$SCRIPT_DIR/../lib/task-lookup-lib.sh"
)

SCRIPT_UNDER_TEST=""
for candidate in "${SCRIPT_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    SCRIPT_UNDER_TEST="$candidate"
    break
  fi
done
GUARD_SCRIPT=""
for candidate in "${GUARD_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    GUARD_SCRIPT="$candidate"
    break
  fi
done
COMMON_SCRIPT=""
for candidate in "${COMMON_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    COMMON_SCRIPT="$candidate"
    break
  fi
done
TASK_LOOKUP_SCRIPT=""
for candidate in "${TASK_LOOKUP_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    TASK_LOOKUP_SCRIPT="$candidate"
    break
  fi
done

if [[ -z "$SCRIPT_UNDER_TEST" ]]; then
  echo "ERROR: orchestrate-record-decision.sh not found at any of:" >&2
  for candidate in "${SCRIPT_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi
if [[ -z "$GUARD_SCRIPT" ]]; then
  echo "ERROR: deploy-root-guard.sh not found at any of:" >&2
  for candidate in "${GUARD_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi
if [[ -z "$COMMON_SCRIPT" ]]; then
  echo "ERROR: lib/common.sh not found at any of:" >&2
  for candidate in "${COMMON_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi
if [[ -z "$TASK_LOOKUP_SCRIPT" ]]; then
  echo "ERROR: lib/task-lookup-lib.sh not found at any of:" >&2
  for candidate in "${TASK_LOOKUP_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

TOP_WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

# --- build_scratch -- builds an isolated <scratch>/.claude/scripts/{...} + <scratch>/specs/
#     tree with one active project (number 1, dir specs/001_demo_task/), echoes the scratch
#     root on stdout. Never touches the live repo's own specs/. ---
build_scratch() {
  local scratch
  scratch="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$scratch/.claude/scripts/lib" "$scratch/specs/001_demo_task"
  cp "$SCRIPT_UNDER_TEST" "$scratch/.claude/scripts/orchestrate-record-decision.sh"
  cp "$GUARD_SCRIPT" "$scratch/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_SCRIPT" "$scratch/.claude/scripts/lib/common.sh"
  cp "$TASK_LOOKUP_SCRIPT" "$scratch/.claude/scripts/lib/task-lookup-lib.sh"
  chmod +x "$scratch/.claude/scripts/orchestrate-record-decision.sh"
  cat > "$scratch/specs/state.json" <<'EOF'
{
  "active_projects": [
    {"project_number": 1, "project_name": "demo_task", "status": "implementing"}
  ]
}
EOF
  echo "$scratch"
}

# run_ord <scratch> [args...] -- invokes orchestrate-record-decision.sh from the scratch's
# .claude tree.
run_ord() {
  local scratch="$1"; shift
  bash "$scratch/.claude/scripts/orchestrate-record-decision.sh" "$@"
}

DECISIONS_REL="specs/001_demo_task/.decisions.json"

# =====================================================================================
# Case (a): first append lazily creates the file as a bare top-level array.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$DECISIONS_REL"
  if [ -f "$doc" ]; then
    fail "(a) lazy-creation: .decisions.json unexpectedly pre-exists in fresh scratch"
  elif run_ord "$scratch" --task 1 --session sess_1000000000_aaaaaa --cycle 1 \
      --question "Q1" --answer "A1" >/dev/null 2>&1; then
    if [ -f "$doc" ] && jq -e 'type == "array" and length == 1' "$doc" >/dev/null 2>&1; then
      pass "(a) lazy-creation: first append creates a bare top-level array with 1 entry"
    else
      fail "(a) lazy-creation: .decisions.json missing or not a bare array after first append"
    fi
  else
    fail "(a) lazy-creation: append exited non-zero on a fresh scratch root"
  fi
}

# =====================================================================================
# Case (b): a second append is additive and leaves entry 1 byte-identical.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$DECISIONS_REL"
  run_ord "$scratch" --task 1 --session sess_1000000000_aaaaaa --cycle 1 \
    --question "Q1" --answer "A1" >/dev/null 2>&1
  entry1_before="$(jq -c '.[0]' "$doc")"
  run_ord "$scratch" --task 1 --session sess_1000000000_aaaaaa --cycle 2 \
    --question "Q2" --answer "A2" >/dev/null 2>&1
  entry1_after="$(jq -c '.[0]' "$doc")"
  count="$(jq 'length' "$doc")"
  if [ "$count" -eq 2 ] && [ "$entry1_before" = "$entry1_after" ]; then
    pass "(b) additive-append: second append yields 2 entries; entry 1 byte-identical"
  else
    fail "(b) additive-append: count=$count entry1_before=$entry1_before entry1_after=$entry1_after"
  fi
}

# =====================================================================================
# Case (c): all four fields present; cycle a JSON number; timestamp ISO 8601 UTC.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$DECISIONS_REL"
  run_ord "$scratch" --task 1 --session sess_1000000000_aaaaaa --cycle 3 \
    --question "Q" --answer "A" >/dev/null 2>&1
  if jq -e '.[0] | (has("question") and has("answer") and has("cycle") and has("timestamp"))' "$doc" >/dev/null 2>&1 \
    && jq -e '.[0].cycle | type == "number"' "$doc" >/dev/null 2>&1 \
    && jq -e '.[0].timestamp | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")' "$doc" >/dev/null 2>&1; then
    pass "(c) shape-conformance: all 4 fields present, cycle is a JSON number, timestamp is ISO 8601 UTC"
  else
    fail "(c) shape-conformance: $(cat "$doc")"
  fi
}

# =====================================================================================
# Case (d): concurrent appends (background invocations, then wait) lose nothing.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$DECISIONS_REL"
  N=15
  pids=()
  for i in $(seq 1 "$N"); do
    run_ord "$scratch" --task 1 --session sess_1000000000_aaaaaa --cycle "$i" \
      --question "Q$i" --answer "A$i" >/dev/null 2>&1 &
    pids+=($!)
  done
  ok=true
  for pid in "${pids[@]}"; do
    wait "$pid" || ok=false
  done
  if [ "$ok" = "true" ] && jq -e 'type == "array"' "$doc" >/dev/null 2>&1; then
    count="$(jq 'length' "$doc")"
    unique_count="$(jq '[.[].question] | unique | length' "$doc")"
    if [ "$count" -eq "$N" ] && [ "$unique_count" -eq "$N" ]; then
      pass "(d) concurrency: $N parallel appends yield exactly $N unique entries"
    else
      fail "(d) concurrency: expected $N entries with $N unique questions, got count=$count unique=$unique_count"
    fi
  else
    fail "(d) concurrency: one or more invocations failed, or the document no longer parses"
  fi
}

# =====================================================================================
# Case (e): a pre-existing object-wrapped {"decisions": [...]} file is REFUSED with the file
# left byte-identical -- the exact observed failure shape.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$DECISIONS_REL"
  printf '%s' '{"decisions": []}' > "$doc"
  before="$(md5sum "$doc")"
  if run_ord "$scratch" --task 1 --session sess_1000000000_aaaaaa --cycle 1 \
      --question "Q" --answer "A" >/dev/null 2>&1; then
    fail "(e) object-wrapper-refusal: expected nonzero exit, got exit 0"
  else
    after="$(md5sum "$doc")"
    if [ "$before" = "$after" ]; then
      pass "(e) object-wrapper-refusal: a {\"decisions\": [...]} file is refused and left byte-identical"
    else
      fail "(e) object-wrapper-refusal: refused but the target file changed"
    fi
  fi
}

# =====================================================================================
# Case (f): a missing required argument exits nonzero and writes nothing.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$DECISIONS_REL"
  if run_ord "$scratch" --task 1 --session sess_1000000000_aaaaaa --cycle 1 \
      --question "Q" >/dev/null 2>&1; then
    fail "(f) missing-argument: expected nonzero exit, got exit 0"
  elif [ -f "$doc" ]; then
    fail "(f) missing-argument: .decisions.json was created (must not write on a validation failure)"
  else
    pass "(f) missing-argument: exited nonzero and wrote nothing"
  fi
}

# =====================================================================================
# Case (g): a non-integer --cycle is refused.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$DECISIONS_REL"
  if run_ord "$scratch" --task 1 --session sess_1000000000_aaaaaa --cycle not-a-number \
      --question "Q" --answer "A" >/dev/null 2>&1; then
    fail "(g) non-integer-cycle: expected nonzero exit, got exit 0"
  elif [ -f "$doc" ]; then
    fail "(g) non-integer-cycle: .decisions.json was created (must not write on a validation failure)"
  else
    pass "(g) non-integer-cycle: exited nonzero and wrote nothing"
  fi
}

# =====================================================================================
# Case (h): the file the writer produces is rendered correctly by the reader's own jq
# expression from orchestrate-build-dispatch.sh.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$DECISIONS_REL"
  run_ord "$scratch" --task 1 --session sess_1000000000_aaaaaa --cycle 5 \
    --question "Which backend?" --answer "Use the existing one" >/dev/null 2>&1
  decisions_content="$(cat "$doc")"
  decisions_count="$(echo "$decisions_content" | jq 'length' 2>/dev/null)" || decisions_count=0
  rendered=""
  if [ "$decisions_count" -gt 0 ]; then
    rendered="$(echo "$decisions_content" | jq -r \
      '.[] | "- Question: \(.question)\n  Answer: \(.answer)\n  Answered in cycle \(.cycle) at \(.timestamp)"')"
  fi
  if [ "$decisions_count" -eq 1 ] && printf '%s' "$rendered" | grep -q "Question: Which backend?" \
    && printf '%s' "$rendered" | grep -q "Answer: Use the existing one" \
    && printf '%s' "$rendered" | grep -q "Answered in cycle 5"; then
    pass "(h) reader-compat: orchestrate-build-dispatch.sh's own jq expression renders the written file"
  else
    fail "(h) reader-compat: count=$decisions_count rendered=[$rendered]"
  fi
}

# =====================================================================================
# Case: unresolvable task number exits nonzero and writes nothing.
# =====================================================================================
{
  scratch="$(build_scratch)"
  if run_ord "$scratch" --task 999 --session sess_1000000000_aaaaaa --cycle 1 \
      --question "Q" --answer "A" >/dev/null 2>&1; then
    fail "unresolvable-task: expected nonzero exit, got exit 0"
  else
    pass "unresolvable-task: exited nonzero when the task number resolves to no entry"
  fi
}

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
# task-ref-ok:end
