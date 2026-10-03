#!/usr/bin/env bash
# test-issue-record.sh - Regression suite for issue-record.sh, proving the load-bearing claims
# mechanically: schema validation refuses and writes nothing, concurrent appends lose nothing,
# an unrecognized --class warns-and-appends rather than refusing, a recording failure is
# non-fatal to a caller using the documented invocation form, win entries are recordable on
# equal footing with issue entries, and --task N resolution works (and fails cleanly when
# unresolvable).
#
# Structural model: scripts/tests/test-orchestrate-record-decision.sh (set -uo pipefail,
# pass()/fail()/info() helpers, PASSED/FAILED integer counters, exit 0 on all-pass / 1 on
# any-fail / 2 on environment error). Script-under-test resolution mirrors the deploy-tree-first
# / source-store-fallback candidate list used by that suite, so this one runs correctly both
# post-deploy (.claude/scripts/issue-record.sh) and in a source-store-only checkout
# (agent-system/extensions/core/scripts/issue-record.sh).
#
# Harness: each case builds an isolated scratch project root under mktemp -d, with
# <scratch>/.claude/scripts/{issue-record.sh,deploy-root-guard.sh,lib/common.sh,
# lib/task-lookup-lib.sh} copied in so deploy-root-guard.sh's `*/.claude` case matches and
# PROJECT_ROOT resolves to <scratch>, plus a scratch specs/state.json carrying one active
# project entry and that project's own directory -- the real script runs against a real scratch
# specs/{N}_{slug}/ tree, never the live repo's own specs/.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (issue-record.sh not found at any candidate path).

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
  "$REPO_ROOT/.claude/scripts/issue-record.sh"
  "$SCRIPT_DIR/../issue-record.sh"
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
  echo "ERROR: issue-record.sh not found at any of:" >&2
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
  cp "$SCRIPT_UNDER_TEST" "$scratch/.claude/scripts/issue-record.sh"
  cp "$GUARD_SCRIPT" "$scratch/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_SCRIPT" "$scratch/.claude/scripts/lib/common.sh"
  cp "$TASK_LOOKUP_SCRIPT" "$scratch/.claude/scripts/lib/task-lookup-lib.sh"
  chmod +x "$scratch/.claude/scripts/issue-record.sh"
  cat > "$scratch/specs/state.json" <<'EOF'
{
  "active_projects": [
    {"project_number": 1, "project_name": "demo_task", "status": "implementing"}
  ]
}
EOF
  echo "$scratch"
}

# run_ir <scratch> [args...] -- invokes issue-record.sh from the scratch's .claude tree.
run_ir() {
  local scratch="$1"; shift
  bash "$scratch/.claude/scripts/issue-record.sh" "$@"
}

ISSUES_REL="specs/001_demo_task/issues.jsonl"

# =====================================================================================
# Case (a): missing --what-happened refuses and writes nothing.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  if run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
      --kind issue --class "tooling bug or gap" --severity minor >/dev/null 2>&1; then
    fail "(a) missing-what-happened: expected nonzero exit, got exit 0"
  elif [ -f "$doc" ]; then
    fail "(a) missing-what-happened: issues.jsonl was created (must not write on a validation failure)"
  else
    pass "(a) missing-what-happened: exited nonzero and wrote nothing"
  fi
}

# =====================================================================================
# Case (b): empty --what-happened refuses and writes nothing.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  if run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
      --kind issue --class "tooling bug or gap" --severity minor --what-happened "" \
      >/dev/null 2>&1; then
    fail "(b) empty-what-happened: expected nonzero exit, got exit 0"
  elif [ -f "$doc" ]; then
    fail "(b) empty-what-happened: issues.jsonl was created (must not write on a validation failure)"
  else
    pass "(b) empty-what-happened: exited nonzero and wrote nothing"
  fi
}

# =====================================================================================
# Case (c): --kind outside issue|win refuses and writes nothing.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  if run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
      --kind bogus --class "tooling bug or gap" --severity minor \
      --what-happened "test" >/dev/null 2>&1; then
    fail "(c) invalid-kind: expected nonzero exit, got exit 0"
  elif [ -f "$doc" ]; then
    fail "(c) invalid-kind: issues.jsonl was created (must not write on a validation failure)"
  else
    pass "(c) invalid-kind: exited nonzero and wrote nothing"
  fi
}

# =====================================================================================
# Case (d): a malformed --tags-json refuses and writes nothing.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  if run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
      --kind issue --class "tooling bug or gap" --severity minor \
      --what-happened "test" --tags-json '{not valid json' >/dev/null 2>&1; then
    fail "(d) malformed-tags-json: expected nonzero exit, got exit 0"
  elif [ -f "$doc" ]; then
    fail "(d) malformed-tags-json: issues.jsonl was created (must not write on a validation failure)"
  else
    pass "(d) malformed-tags-json: exited nonzero and wrote nothing"
  fi
}

# =====================================================================================
# Case (e): an invalid --severity refuses and writes nothing (true closed-set field).
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  if run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
      --kind issue --class "tooling bug or gap" --severity catastrophic \
      --what-happened "test" >/dev/null 2>&1; then
    fail "(e) invalid-severity: expected nonzero exit, got exit 0"
  elif [ -f "$doc" ]; then
    fail "(e) invalid-severity: issues.jsonl was created (must not write on a validation failure)"
  else
    pass "(e) invalid-severity: exited nonzero and wrote nothing"
  fi
}

# =====================================================================================
# Case (f): refusals above leave issues.jsonl byte-for-byte unchanged, not merely
# line-count-equal, when a prior valid entry already exists.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
    --kind issue --class "tooling bug or gap" --severity minor \
    --what-happened "seed entry" >/dev/null 2>&1
  before="$(md5sum "$doc")"
  run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
    --kind issue --class "tooling bug or gap" --severity minor --what-happened "" >/dev/null 2>&1
  after="$(md5sum "$doc")"
  if [ "$before" = "$after" ]; then
    pass "(f) byte-identical-on-refusal: a refused call after a valid entry leaves the file byte-for-byte unchanged"
  else
    fail "(f) byte-identical-on-refusal: file changed on a refused call (before=$before after=$after)"
  fi
}

# =====================================================================================
# Case (g): append-atomicity -- N concurrent background invocations yield exactly N
# well-formed lines, every one parsing with jq -e, with no interleaved or truncated line.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  N=15
  pids=()
  for i in $(seq 1 "$N"); do
    run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
      --kind issue --class "tooling bug or gap" --severity minor \
      --what-happened "concurrent entry $i" >/dev/null 2>&1 &
    pids+=($!)
  done
  ok=true
  for pid in "${pids[@]}"; do
    wait "$pid" || ok=false
  done
  line_count=0
  bad_lines=0
  if [ -f "$doc" ]; then
    line_count="$(wc -l < "$doc" | tr -d ' ')"
    while IFS= read -r line; do
      if ! printf '%s' "$line" | jq -e . >/dev/null 2>&1; then
        bad_lines=$((bad_lines + 1))
      fi
    done < "$doc"
  fi
  if [ "$ok" = "true" ] && [ "$line_count" -eq "$N" ] && [ "$bad_lines" -eq 0 ]; then
    pass "(g) concurrency: $N parallel appends yield exactly $N well-formed lines"
  else
    fail "(g) concurrency: expected $N well-formed lines, got line_count=$line_count bad_lines=$bad_lines ok=$ok"
  fi
}

# =====================================================================================
# Case (h): an unrecognized --class exits 0, appends one line carrying that class
# verbatim, and emits a warning on stderr.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  stderr_file="$TOP_WORKDIR/ir_stderr_h.txt"
  exit_code=0
  run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
    --kind issue --class "a brand new never-before-seen class" --severity minor \
    --what-happened "unknown class test" >/dev/null 2>"$stderr_file" || exit_code=$?
  stderr_out="$(cat "$stderr_file" 2>/dev/null)"
  if [ "$exit_code" -eq 0 ] \
    && jq -e '.class == "a brand new never-before-seen class"' <<<"$(tail -1 "$doc")" >/dev/null 2>&1 \
    && printf '%s' "$stderr_out" | grep -qi "warning.*class"; then
    pass "(h) unknown-class: exits 0, appends the class verbatim, warns on stderr"
  else
    fail "(h) unknown-class: exit_code=$exit_code stderr=[$stderr_out]"
  fi
}

# =====================================================================================
# Case (i): non-fatal failure -- a call against a nonexistent target leaves the caller's
# exit status unaffected when invoked in the documented non-fatal form, while the script
# itself still signals failure via its own exit code when invoked directly.
# =====================================================================================
{
  scratch="$(build_scratch)"
  direct_exit=0
  run_ir "$scratch" --task-dir "$scratch/specs/999_nonexistent_task" \
    --kind issue --class "environment" --severity minor --what-happened "test" \
    >/dev/null 2>&1 || direct_exit=$?

  caller_exit=0
  (
    run_ir "$scratch" --task-dir "$scratch/specs/999_nonexistent_task" \
      --kind issue --class "environment" --severity minor --what-happened "test" \
      >/dev/null 2>&1 || echo "Note: issue recording failed (non-fatal)" >&2
    exit 0
  ) || caller_exit=$?

  if [ "$direct_exit" -ne 0 ] && [ "$caller_exit" -eq 0 ]; then
    pass "(i) non-fatal-failure: direct exit nonzero (direct_exit=$direct_exit), documented non-fatal form leaves caller exit 0"
  else
    fail "(i) non-fatal-failure: direct_exit=$direct_exit caller_exit=$caller_exit"
  fi
}

# =====================================================================================
# Case (j): kind: "win" is accepted and appended on equal footing with an issue.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  if run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
      --kind win --class "orchestration defect" --severity none \
      --what-happened "a win entry" >/dev/null 2>&1; then
    if jq -e '.kind == "win"' <<<"$(tail -1 "$doc")" >/dev/null 2>&1; then
      pass "(j) win-entry: a kind=win entry is accepted and appended"
    else
      fail "(j) win-entry: appended but kind != win: $(tail -1 "$doc")"
    fi
  else
    fail "(j) win-entry: expected exit 0, got nonzero"
  fi
}

# =====================================================================================
# Case (k): --task N resolution -- a bare task number resolves to the right task
# directory via task-lookup-lib.sh.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  if run_ir "$scratch" --task 1 \
      --kind issue --class "environment" --severity minor \
      --what-happened "task-number resolution test" >/dev/null 2>&1; then
    if [ -f "$doc" ] && jq -e '.task_dir == "specs/001_demo_task"' <<<"$(tail -1 "$doc")" >/dev/null 2>&1; then
      pass "(k) task-number-resolution: --task 1 resolves to specs/001_demo_task"
    else
      fail "(k) task-number-resolution: resolved but task_dir field wrong or file missing"
    fi
  else
    fail "(k) task-number-resolution: expected exit 0, got nonzero"
  fi
}

# =====================================================================================
# Case (l): an unresolvable --task number refuses cleanly.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  if run_ir "$scratch" --task 999 \
      --kind issue --class "environment" --severity minor \
      --what-happened "should refuse" >/dev/null 2>&1; then
    fail "(l) unresolvable-task: expected nonzero exit, got exit 0"
  elif [ -f "$doc" ]; then
    fail "(l) unresolvable-task: issues.jsonl was created for an unresolvable task"
  else
    pass "(l) unresolvable-task: exited nonzero and wrote nothing"
  fi
}

# =====================================================================================
# Case (m): --task-dir and --task together refuses (mutually exclusive).
# =====================================================================================
{
  scratch="$(build_scratch)"
  if run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" --task 1 \
      --kind issue --class "environment" --severity minor \
      --what-happened "should refuse" >/dev/null 2>&1; then
    fail "(m) mutually-exclusive-task-args: expected nonzero exit, got exit 0"
  else
    pass "(m) mutually-exclusive-task-args: exited nonzero when both --task-dir and --task given"
  fi
}

# =====================================================================================
# Case (n): --cost-value without --cost-unit refuses.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  if run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
      --kind issue --class "environment" --severity minor --what-happened "test" \
      --cost-value 5 >/dev/null 2>&1; then
    fail "(n) cost-value-without-unit: expected nonzero exit, got exit 0"
  elif [ -f "$doc" ]; then
    fail "(n) cost-value-without-unit: issues.jsonl was created"
  else
    pass "(n) cost-value-without-unit: exited nonzero and wrote nothing"
  fi
}

# =====================================================================================
# Case (o): a well-formed call with every optional field populates all fields correctly
# and the appended line parses with jq -e.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
    --kind issue --class "gate collision" --severity costly --phase implement \
    --dispatch-seq 7 --what-happened "full-field test" \
    --evidence-path "scripts/issue-record.sh:1" --cost-value 12 --cost-unit minutes \
    --resolution fixed_inline --suggested-channel fix_now --tags-json '{"a":1}' \
    --session sess_1000000000_aaaaaa >/dev/null 2>&1
  entry="$(tail -1 "$doc")"
  if printf '%s' "$entry" | jq -e . >/dev/null 2>&1 \
    && jq -e '.phase == "implement" and .dispatch_seq == 7 and .estimated_cost.value == 12
      and .estimated_cost.unit == "minutes" and .resolution == "fixed_inline"
      and .suggested_channel == "fix_now" and .tags.a == 1
      and .session_id == "sess_1000000000_aaaaaa"' <<<"$entry" >/dev/null 2>&1; then
    pass "(o) full-field: all optional fields populate correctly and the line parses"
  else
    fail "(o) full-field: $entry"
  fi
}

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
# task-ref-ok:end
