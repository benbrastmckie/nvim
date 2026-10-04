#!/usr/bin/env bash
# test-run-task-observers.sh - Regression suite for run-task-observers.sh and its
# resolution engine, scripts/lib/manifest-routing-lib.sh's routing_resolve_observers().
#
# Proves the matching contract (prefix-aware on topic and task_type, match-if-either, every
# match fires -- never first-match-wins) and the advisory contract (never changes task status,
# never fails a dispatch, bounded timeout, rc recorded as an event and otherwise ignored,
# always exits 0) mechanically, in an isolated scratch sandbox that never touches the live
# repo's own specs/ or .claude/.
#
# Structural model: scripts/tests/test-dispatch-metrics.sh / test-issue-record.sh (set -uo
# pipefail, pass()/fail()/info() helpers, PASSED/FAILED integer counters, exit 0 all-pass / 1
# any-fail / 2 environment error). Script-under-test resolution mirrors the deploy-tree-first /
# source-store-fallback candidate list those suites use, so this one runs correctly both
# post-deploy (.claude/scripts/run-task-observers.sh) and in a source-store-only checkout
# (agent-system/extensions/core/scripts/run-task-observers.sh).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (run-task-observers.sh or a collaborator not found at any candidate path).

# task-ref-ok:begin inline, category 3: command-usage examples -- the script under test's own
# --task flag takes a concrete integer project/task number, used literally throughout this
# suite's invocations and scratch fixtures (specs/001_demo_task/, --task 1, etc.).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

SCRIPT_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/run-task-observers.sh"
  "$SCRIPT_DIR/../run-task-observers.sh"
)
EVENTS_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/events-append.sh"
  "$SCRIPT_DIR/../events-append.sh"
)
GUARD_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/deploy-root-guard.sh"
  "$SCRIPT_DIR/../deploy-root-guard.sh"
)
COMMON_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/lib/common.sh"
  "$SCRIPT_DIR/../lib/common.sh"
)
ROUTING_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/lib/manifest-routing-lib.sh"
  "$SCRIPT_DIR/../lib/manifest-routing-lib.sh"
)

resolve_candidate() {
  local name="$1"; shift
  local candidate
  for candidate in "$@"; do
    if [[ -f "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  echo "ERROR: $name not found at any of:" >&2
  for candidate in "$@"; do
    echo "  $candidate" >&2
  done
  return 1
}

SCRIPT_UNDER_TEST="$(resolve_candidate "run-task-observers.sh" "${SCRIPT_CANDIDATES[@]}")" || exit 2
EVENTS_SCRIPT="$(resolve_candidate "events-append.sh" "${EVENTS_CANDIDATES[@]}")" || exit 2
GUARD_SCRIPT="$(resolve_candidate "deploy-root-guard.sh" "${GUARD_CANDIDATES[@]}")" || exit 2
COMMON_SCRIPT="$(resolve_candidate "lib/common.sh" "${COMMON_CANDIDATES[@]}")" || exit 2
ROUTING_SCRIPT="$(resolve_candidate "lib/manifest-routing-lib.sh" "${ROUTING_CANDIDATES[@]}")" || exit 2

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

TOP_WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

# --- build_scratch -- isolated <scratch>/.claude/scripts/{...} + <scratch>/specs/ tree,
#     echoes the scratch root on stdout. Never touches the live repo's own specs/ or .claude/. ---
build_scratch() {
  local scratch
  scratch="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$scratch/.claude/scripts/lib" "$scratch/.claude/extensions" "$scratch/specs/001_demo_task"
  cp "$SCRIPT_UNDER_TEST" "$scratch/.claude/scripts/run-task-observers.sh"
  cp "$EVENTS_SCRIPT" "$scratch/.claude/scripts/events-append.sh"
  cp "$GUARD_SCRIPT" "$scratch/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_SCRIPT" "$scratch/.claude/scripts/lib/common.sh"
  cp "$ROUTING_SCRIPT" "$scratch/.claude/scripts/lib/manifest-routing-lib.sh"
  chmod +x "$scratch/.claude/scripts/run-task-observers.sh" "$scratch/.claude/scripts/events-append.sh"
  : > "$scratch/specs/001_demo_task/issues.jsonl"
  : > "$scratch/specs/001_demo_task/metrics.jsonl"
  echo "$scratch"
}

# declare_observer <scratch> <ext_name> <observer_key> <script_basename> [topic] [task_type] [timeout_seconds]
declare_observer() {
  local scratch="$1" ext="$2" key="$3" script="$4" topic="${5:-}" tt="${6:-}" to="${7:-}"
  local ext_dir="$scratch/.claude/extensions/$ext"
  mkdir -p "$ext_dir"
  local manifest="$ext_dir/manifest.json"
  if [[ ! -f "$manifest" ]]; then
    echo '{"name": "'"$ext"'", "observers": {}}' > "$manifest"
  fi
  jq --arg k "$key" --arg s "$script" --arg t "$topic" --arg tt "$tt" --arg to "$to" \
    '.observers[$k] = ({script: $s} +
       (if $t == "" then {} else {topic: $t} end) +
       (if $tt == "" then {} else {task_type: $tt} end) +
       (if $to == "" then {} else {timeout_seconds: ($to | tonumber)} end))' \
    "$manifest" > "$manifest.tmp" && mv "$manifest.tmp" "$manifest"
}

# declare_raw_observer <scratch> <ext_name> <observer_json> -- for malformed-declaration cases
declare_raw_observer() {
  local scratch="$1" ext="$2" key="$3" json="$4"
  local ext_dir="$scratch/.claude/extensions/$ext"
  mkdir -p "$ext_dir"
  local manifest="$ext_dir/manifest.json"
  if [[ ! -f "$manifest" ]]; then
    echo '{"name": "'"$ext"'", "observers": {}}' > "$manifest"
  fi
  jq --arg k "$key" --argjson v "$json" '.observers[$k] = $v' "$manifest" > "$manifest.tmp" && mv "$manifest.tmp" "$manifest"
}

# observer_script <scratch> <basename> <body> -- writes an executable observer script.
observer_script() {
  local scratch="$1" basename="$2" body="$3"
  printf '#!/usr/bin/env bash\n%s\n' "$body" > "$scratch/.claude/scripts/$basename"
  chmod +x "$scratch/.claude/scripts/$basename"
}

# run_rto <scratch> [args...] -- invokes run-task-observers.sh from the scratch's .claude tree.
run_rto() {
  local scratch="$1"; shift
  (cd "$scratch/.claude/scripts" && bash run-task-observers.sh "$@")
}

EVENTS_REL="specs/events.jsonl"

# =====================================================================================
# Case (a): prefix match -- a topic: books declaration fires for topic books:certify.
# =====================================================================================
{
  scratch="$(build_scratch)"
  declare_observer "$scratch" ext1 obs1 obs1.sh books
  observer_script "$scratch" obs1.sh "echo ran > \"\$4/obs1.ran\"; exit 0"
  run_rto "$scratch" --task 1 --task-type "" --topic "books:certify" \
    --task-dir "$scratch/specs/001_demo_task" --session sess_1000000000_aaaaaa --status COMPLETED >/dev/null 2>&1
  if [ -f "$scratch/specs/001_demo_task/obs1.ran" ]; then
    pass "(a) prefix match: books declaration fires for topic books:certify"
  else
    fail "(a) prefix match: observer did not fire"
  fi
}

# =====================================================================================
# Case (b): topic-only match -- fires on topic, does not fire when topic differs even if
# task_type coincidentally equals the topic string.
# =====================================================================================
{
  scratch="$(build_scratch)"
  declare_observer "$scratch" ext1 obs1 obs1.sh books
  observer_script "$scratch" obs1.sh "echo ran > \"\$4/obs1.ran\"; exit 0"
  run_rto "$scratch" --task 1 --task-type "books" --topic "other" \
    --task-dir "$scratch/specs/001_demo_task" --session sess_1000000000_aaaaaa --status COMPLETED >/dev/null 2>&1
  if [ ! -f "$scratch/specs/001_demo_task/obs1.ran" ]; then
    pass "(b) topic-only: topic-only declaration does not fire on a coincidental task_type match"
  else
    fail "(b) topic-only: observer fired when only task_type (not topic) matched"
  fi
}

# =====================================================================================
# Case (c): task_type-only match -- prefix-aware (present matches present:grant).
# =====================================================================================
{
  scratch="$(build_scratch)"
  declare_observer "$scratch" ext1 obs1 obs1.sh "" present
  observer_script "$scratch" obs1.sh "echo ran > \"\$4/obs1.ran\"; exit 0"
  run_rto "$scratch" --task 1 --task-type "present:grant" --topic "" \
    --task-dir "$scratch/specs/001_demo_task" --session sess_1000000000_aaaaaa --status COMPLETED >/dev/null 2>&1
  if [ -f "$scratch/specs/001_demo_task/obs1.ran" ]; then
    pass "(c) task_type-only: present declaration fires for task_type present:grant"
  else
    fail "(c) task_type-only: observer did not fire"
  fi
}

# =====================================================================================
# Case (d): both-declared match-if-either -- fires on topic only, fires on task_type only,
# and reports matched_on=both when both match.
# =====================================================================================
{
  scratch="$(build_scratch)"
  declare_observer "$scratch" ext1 obs1 obs1.sh books lean4
  observer_script "$scratch" obs1.sh "echo ran >> \"\$4/obs1.ran\"; exit 0"

  rm -f "$scratch/specs/001_demo_task/obs1.ran"
  run_rto "$scratch" --task 1 --task-type "other" --topic "books" \
    --task-dir "$scratch/specs/001_demo_task" --session sess_1000000000_aaaaaa --status COMPLETED >/dev/null 2>&1
  fired_topic_only=0; [ -f "$scratch/specs/001_demo_task/obs1.ran" ] && fired_topic_only=1

  rm -f "$scratch/specs/001_demo_task/obs1.ran"
  run_rto "$scratch" --task 1 --task-type "lean4" --topic "other" \
    --task-dir "$scratch/specs/001_demo_task" --session sess_1000000000_aaaaaa --status COMPLETED >/dev/null 2>&1
  fired_tt_only=0; [ -f "$scratch/specs/001_demo_task/obs1.ran" ] && fired_tt_only=1

  rm -f "$scratch/$EVENTS_REL"
  rm -f "$scratch/specs/001_demo_task/obs1.ran"
  run_rto "$scratch" --task 1 --task-type "lean4" --topic "books" \
    --task-dir "$scratch/specs/001_demo_task" --session sess_1000000000_aaaaaa --status COMPLETED >/dev/null 2>&1
  matched_both=0
  if [ -f "$scratch/$EVENTS_REL" ] && jq -e '.detail.matched_on == "both"' "$scratch/$EVENTS_REL" >/dev/null 2>&1; then
    matched_both=1
  fi

  if [ "$fired_topic_only" -eq 1 ] && [ "$fired_tt_only" -eq 1 ] && [ "$matched_both" -eq 1 ]; then
    pass "(d) both-declared match-if-either: topic-only, task_type-only, and both-match (matched_on=both) all correct"
  else
    fail "(d) both-declared match-if-either: topic_only=$fired_topic_only tt_only=$fired_tt_only both=$matched_both"
  fi
}

# =====================================================================================
# Case (e): no match -- a declaration on Y does not fire for topic X; no event appended; exit 0.
# =====================================================================================
{
  scratch="$(build_scratch)"
  declare_observer "$scratch" ext1 obs1 obs1.sh Y
  observer_script "$scratch" obs1.sh "echo ran > \"\$4/obs1.ran\"; exit 0"
  run_rto "$scratch" --task 1 --task-type "" --topic "X" \
    --task-dir "$scratch/specs/001_demo_task" --session sess_1000000000_aaaaaa --status COMPLETED
  rc=$?
  if [ -f "$scratch/specs/001_demo_task/obs1.ran" ]; then
    fail "(e) no match: observer fired despite non-matching topic"
  elif [ -f "$scratch/$EVENTS_REL" ]; then
    fail "(e) no match: an event was appended despite zero matches"
  elif [ "$rc" -ne 0 ]; then
    fail "(e) no match: exit code was $rc, expected 0"
  else
    pass "(e) no match: silent, no event, exit 0"
  fi
}

# =====================================================================================
# Case (f): multiple matching extensions -- two fixture extensions both matching one task
# BOTH fire, in deterministic glob/key order (D7).
# =====================================================================================
{
  scratch="$(build_scratch)"
  declare_observer "$scratch" ext1 obs1 obs1.sh X
  observer_script "$scratch" obs1.sh "echo ran > \"\$4/obs1.ran\"; exit 0"
  declare_observer "$scratch" ext2 obs2 obs2.sh X
  observer_script "$scratch" obs2.sh "echo ran > \"\$4/obs2.ran\"; exit 0"
  run_rto "$scratch" --task 1 --task-type "" --topic "X" \
    --task-dir "$scratch/specs/001_demo_task" --session sess_1000000000_aaaaaa --status COMPLETED >/dev/null 2>&1
  if [ -f "$scratch/specs/001_demo_task/obs1.ran" ] && [ -f "$scratch/specs/001_demo_task/obs2.ran" ]; then
    pass "(f) multiple matching extensions: both fired (no first-match-wins regression)"
  else
    fail "(f) multiple matching extensions: at least one did not fire"
  fi
}

# =====================================================================================
# Case (g): missing script -- declaration whose script resolves to no deployed file yields
# exactly one deviation event and exit 0.
# =====================================================================================
{
  scratch="$(build_scratch)"
  declare_observer "$scratch" ext1 obs1 ghost.sh X
  rm -f "$scratch/$EVENTS_REL"
  run_rto "$scratch" --task 1 --task-type "" --topic "X" \
    --task-dir "$scratch/specs/001_demo_task" --session sess_1000000000_aaaaaa --status COMPLETED
  rc=$?
  n_events=$(wc -l < "$scratch/$EVENTS_REL" 2>/dev/null || echo 0)
  if [ "$rc" -eq 0 ] && [ "$n_events" -eq 1 ] && jq -e '.category == "deviation" and .detail.skipped == "missing_script"' "$scratch/$EVENTS_REL" >/dev/null 2>&1; then
    pass "(g) missing script: exactly one deviation event, skipped=missing_script, exit 0"
  else
    fail "(g) missing script: rc=$rc events=$n_events"
  fi
}

# =====================================================================================
# Case (h): non-executable script -- same shape, distinguished in the detail payload.
# =====================================================================================
{
  scratch="$(build_scratch)"
  declare_observer "$scratch" ext1 obs1 notexec.sh X
  echo '#!/usr/bin/env bash' > "$scratch/.claude/scripts/notexec.sh"
  chmod -x "$scratch/.claude/scripts/notexec.sh"
  rm -f "$scratch/$EVENTS_REL"
  run_rto "$scratch" --task 1 --task-type "" --topic "X" \
    --task-dir "$scratch/specs/001_demo_task" --session sess_1000000000_aaaaaa --status COMPLETED
  rc=$?
  if [ "$rc" -eq 0 ] && jq -e '.category == "deviation" and .detail.skipped == "not_executable"' "$scratch/$EVENTS_REL" >/dev/null 2>&1; then
    pass "(h) non-executable script: deviation event with skipped=not_executable, exit 0"
  else
    fail "(h) non-executable script: rc=$rc"
  fi
}

# =====================================================================================
# Case (i): non-zero rc -- an observer exiting 3 yields one deviation event carrying rc: 3,
# and the SUT still exits 0.
# =====================================================================================
{
  scratch="$(build_scratch)"
  declare_observer "$scratch" ext1 obs1 obs1.sh X
  observer_script "$scratch" obs1.sh "exit 3"
  rm -f "$scratch/$EVENTS_REL"
  run_rto "$scratch" --task 1 --task-type "" --topic "X" \
    --task-dir "$scratch/specs/001_demo_task" --session sess_1000000000_aaaaaa --status COMPLETED
  rc=$?
  if [ "$rc" -eq 0 ] && jq -e '.category == "deviation" and .detail.rc == 3' "$scratch/$EVENTS_REL" >/dev/null 2>&1; then
    pass "(i) non-zero rc: deviation event with rc=3, SUT exits 0"
  else
    fail "(i) non-zero rc: rc=$rc"
  fi
}

# =====================================================================================
# Case (j): timeout -- an observer sleeping past a 1-second timeout_seconds is killed, the
# event carries timed_out: true, the SUT exits 0, and total wall-clock stays bounded.
# =====================================================================================
{
  scratch="$(build_scratch)"
  declare_observer "$scratch" ext1 obs1 obs1.sh X "" 1
  observer_script "$scratch" obs1.sh "sleep 30; exit 0"
  rm -f "$scratch/$EVENTS_REL"
  start_ts=$(date +%s)
  run_rto "$scratch" --task 1 --task-type "" --topic "X" \
    --task-dir "$scratch/specs/001_demo_task" --session sess_1000000000_aaaaaa --status COMPLETED
  rc=$?
  end_ts=$(date +%s)
  elapsed=$((end_ts - start_ts))
  if [ "$rc" -eq 0 ] && [ "$elapsed" -lt 15 ] && jq -e '.detail.timed_out == true' "$scratch/$EVENTS_REL" >/dev/null 2>&1; then
    pass "(j) timeout: killed within bound (elapsed=${elapsed}s), timed_out=true, SUT exits 0"
  else
    fail "(j) timeout: rc=$rc elapsed=${elapsed}s"
  fi
}

# =====================================================================================
# Case (k): no timeout binary -- with timeout/gtimeout removed from PATH, the observer is
# SKIPPED (never invoked un-bounded) and one deviation event carrying the skip reason is appended.
# =====================================================================================
{
  scratch="$(build_scratch)"
  declare_observer "$scratch" ext1 obs1 obs1.sh X
  observer_script "$scratch" obs1.sh "echo ran > \"\$4/obs1.ran\"; exit 0"
  rm -f "$scratch/$EVENTS_REL"
  NO_TIMEOUT_DIR="$(mktemp -d -p "$TOP_WORKDIR")"
  for bin in bash jq cp mkdir chmod rm cat basename dirname date mktemp sort tr head grep cut printf flock pwd dd od; do
    real="$(command -v "$bin" 2>/dev/null || true)"
    [ -n "$real" ] && ln -sf "$real" "$NO_TIMEOUT_DIR/$bin"
  done
  (
    PATH="$NO_TIMEOUT_DIR"
    export PATH
    cd "$scratch/.claude/scripts" && bash run-task-observers.sh --task 1 --task-type "" --topic "X" \
      --task-dir "$scratch/specs/001_demo_task" --session sess_1000000000_aaaaaa --status COMPLETED
  )
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -f "$scratch/specs/001_demo_task/obs1.ran" ] \
    && jq -e '.category == "deviation" and .detail.skipped == "no_timeout_binary"' "$scratch/$EVENTS_REL" >/dev/null 2>&1; then
    pass "(k) no timeout binary: observer skipped (never invoked un-bounded), deviation event, exit 0"
  else
    fail "(k) no timeout binary: rc=$rc observer_ran=$([ -f "$scratch/specs/001_demo_task/obs1.ran" ] && echo yes || echo no)"
  fi
  rm -rf "$NO_TIMEOUT_DIR"
}

# =====================================================================================
# Case (l): a failing observer does not change status -- run-task-observers.sh itself never
# touches specs/state.json, and a crashing (garbage-stdout-emitting) observer leaves the SUT's
# own exit code at 0. (The observer process is not sandboxed by the SUT -- that is out of
# scope for an advisory invoker -- so this asserts what the SUT itself does, not what an
# observer could theoretically do to its own filesystem.)
# =====================================================================================
{
  scratch="$(build_scratch)"
  cat > "$scratch/specs/state.json" <<'EOF'
{"active_projects": [{"project_number": 1, "status": "implementing"}]}
EOF
  before_sum="$(sha256sum "$scratch/specs/state.json" | awk '{print $1}')"
  declare_observer "$scratch" ext1 obs1 obs1.sh X
  observer_script "$scratch" obs1.sh "echo 'garbage stdout/stderr noise' >&2; exit 1"
  run_rto "$scratch" --task 1 --task-type "" --topic "X" \
    --task-dir "$scratch/specs/001_demo_task" --session sess_1000000000_aaaaaa --status COMPLETED
  rc=$?
  after_sum="$(sha256sum "$scratch/specs/state.json" | awk '{print $1}')"
  if [ "$rc" -eq 0 ] && [ "$before_sum" = "$after_sum" ]; then
    pass "(l) failing observer does not change status: specs/state.json byte-identical, SUT exits 0"
  else
    fail "(l) failing observer does not change status: rc=$rc before=$before_sum after=$after_sum"
  fi
}

# =====================================================================================
# Case (m): malformed declaration tolerance -- an entry missing script, and an entry with
# neither topic nor task_type, are skipped without failing the run.
# =====================================================================================
{
  scratch="$(build_scratch)"
  declare_raw_observer "$scratch" ext1 noscript '{"topic": "X"}'
  declare_raw_observer "$scratch" ext1 nokeys '{"script": "obs1.sh"}'
  rm -f "$scratch/$EVENTS_REL"
  run_rto "$scratch" --task 1 --task-type "" --topic "X" \
    --task-dir "$scratch/specs/001_demo_task" --session sess_1000000000_aaaaaa --status COMPLETED
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -f "$scratch/$EVENTS_REL" ]; then
    pass "(m) malformed declaration tolerance: both malformed entries skipped silently, exit 0"
  else
    fail "(m) malformed declaration tolerance: rc=$rc events_exist=$([ -f "$scratch/$EVENTS_REL" ] && echo yes || echo no)"
  fi
}

# =====================================================================================
# Case (n): --dry-run -- matches reported on stderr, no event appended, observer's side-effect
# file absent.
# =====================================================================================
{
  scratch="$(build_scratch)"
  declare_observer "$scratch" ext1 obs1 obs1.sh X
  observer_script "$scratch" obs1.sh "echo ran > \"\$4/obs1.ran\"; exit 0"
  stderr_out=$(run_rto "$scratch" --task 1 --task-type "" --topic "X" \
    --task-dir "$scratch/specs/001_demo_task" --session sess_1000000000_aaaaaa --status COMPLETED --dry-run 2>&1 1>/dev/null)
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -f "$scratch/specs/001_demo_task/obs1.ran" ] && [ ! -f "$scratch/$EVENTS_REL" ] \
    && printf '%s' "$stderr_out" | grep -q "would invoke observer obs1"; then
    pass "(n) --dry-run: reported on stderr, no event, no invocation, exit 0"
  else
    fail "(n) --dry-run: rc=$rc stderr=[$stderr_out]"
  fi
}


echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
# task-ref-ok:end
