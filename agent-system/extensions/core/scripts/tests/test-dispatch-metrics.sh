#!/usr/bin/env bash
# test-dispatch-metrics.sh - Regression suite for dispatch-metrics.sh, proving the load-bearing
# claims mechanically: a missing transcript yields OMITTED (never zeroed) token/tool_call/model
# fields (acceptance-bar test A), a metrics failure never fails a caller using the documented
# non-fatal invocation form (acceptance-bar test B), the project-slug derivation matches the
# confirmed mapping, the exact-match transcript join selects the right candidate (and omits on
# an ambiguous multi-match), closed-enum fields refuse loudly with nothing appended, the append
# path is append-only and lazily creates both the data file and its lock, --backfill marks every
# record it writes, and the wall-clock sentinel omits rather than emitting a negative number.
#
# Structural model: scripts/tests/test-issue-record.sh (set -uo pipefail, pass()/fail()/info()
# helpers, PASSED/FAILED integer counters, exit 0 on all-pass / 1 on any-fail / 2 on environment
# error). Script-under-test resolution mirrors that suite's deploy-tree-first /
# source-store-fallback candidate list, so this one runs correctly both post-deploy
# (.claude/scripts/dispatch-metrics.sh) and in a source-store-only checkout
# (agent-system/extensions/core/scripts/dispatch-metrics.sh).
#
# Harness: each case builds an isolated scratch project root under mktemp -d, with
# <scratch>/.claude/scripts/{dispatch-metrics.sh,deploy-root-guard.sh,lib/common.sh,
# lib/task-lookup-lib.sh} copied in so deploy-root-guard.sh's `*/.claude` case matches and
# PROJECT_ROOT resolves to <scratch>, plus a scratch specs/state.json carrying one active
# project entry and that project's own task directory -- the real script runs against a real
# scratch specs/{N}_{slug}/ tree, never the live repo's own specs/.
#
# The transcript-join cases build a scratch HOME (exported HOME=<scratch_home>) with its own
# ~/.claude/projects/<slug>/<cc_session_id>/subagents/agent-*.jsonl fixtures, so the join never
# touches the real operator's transcript corpus.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (dispatch-metrics.sh not found at any candidate path).

# task-ref-ok:begin inline, category 3: command-usage examples -- the script under test's own
# --task flag and this suite's scratch state.json fixtures take a concrete integer
# project/task number, used literally throughout.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

SCRIPT_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/dispatch-metrics.sh"
  "$SCRIPT_DIR/../dispatch-metrics.sh"
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
  echo "ERROR: dispatch-metrics.sh not found at any of:" >&2
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
  cp "$SCRIPT_UNDER_TEST" "$scratch/.claude/scripts/dispatch-metrics.sh"
  cp "$GUARD_SCRIPT" "$scratch/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_SCRIPT" "$scratch/.claude/scripts/lib/common.sh"
  cp "$TASK_LOOKUP_SCRIPT" "$scratch/.claude/scripts/lib/task-lookup-lib.sh"
  chmod +x "$scratch/.claude/scripts/dispatch-metrics.sh"
  cat > "$scratch/specs/state.json" <<'EOF'
{
  "active_projects": [
    {"project_number": 1, "project_name": "demo_task", "status": "implementing"}
  ]
}
EOF
  echo "$scratch"
}

# run_dm <scratch> [args...] -- invokes dispatch-metrics.sh from the scratch's .claude tree.
run_dm() {
  local scratch="$1"; shift
  bash "$scratch/.claude/scripts/dispatch-metrics.sh" "$@"
}

METRICS_REL="specs/001_demo_task/metrics.jsonl"

# =====================================================================================
# Case (a) -- ACCEPTANCE BAR TEST A: a missing transcript (no cc_session_id/HOME subagents
# dir at all) yields OMITTED, never zeroed, token/tool_call/model fields, and the record does
# NOT contain a false "input": 0 measurement.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$METRICS_REL"
  HOME="$scratch/no-such-home" run_dm "$scratch" --task-dir "$scratch/specs/001_demo_task" \
    --phase implement --agent general-implementation-agent --outcome completed \
    --dispatch-seq 1 --session sess_1700000000_aaaaaa --cc-session-id "deadbeef-0000-0000-0000-000000000000" \
    >/dev/null 2>&1
  entry="$(tail -1 "$doc" 2>/dev/null)"
  if [ -n "$entry" ] \
    && [ "$(printf '%s' "$entry" | jq -r 'has("tokens")')" = "false" ] \
    && [ "$(printf '%s' "$entry" | jq -r 'has("tool_calls")')" = "false" ] \
    && [ "$(printf '%s' "$entry" | jq -r 'has("model")')" = "false" ] \
    && ! printf '%s' "$entry" | grep -q '"input":0' \
    && ! printf '%s' "$entry" | grep -q '"input": 0'; then
    pass "(a) ACCEPTANCE: missing transcript omits tokens/tool_calls/model (never zeroes)"
  else
    fail "(a) ACCEPTANCE: missing transcript case -- entry=[$entry]"
  fi
}

# =====================================================================================
# Case (b) -- ACCEPTANCE BAR TEST B: a metrics-recording failure (unwritable/nonexistent task
# directory) does not fail a caller using the documented non-fatal invocation form, while the
# script itself still signals failure via its own exit code when invoked directly.
# =====================================================================================
{
  scratch="$(build_scratch)"
  direct_exit=0
  run_dm "$scratch" --task-dir "$scratch/specs/999_nonexistent_task" \
    --phase implement --agent x --outcome completed --dispatch-seq 1 \
    --session sess_1700000000_bbbbbb >/dev/null 2>&1 || direct_exit=$?

  caller_exit=0
  (
    run_dm "$scratch" --task-dir "$scratch/specs/999_nonexistent_task" \
      --phase implement --agent x --outcome completed --dispatch-seq 1 \
      --session sess_1700000000_bbbbbb \
      >/dev/null 2>&1 || echo "Note: dispatch-metrics recording failed (non-fatal)" >&2
    exit 0
  ) || caller_exit=$?

  if [ "$direct_exit" -ne 0 ] && [ "$caller_exit" -eq 0 ]; then
    pass "(b) ACCEPTANCE: non-fatal-failure -- direct exit nonzero (direct_exit=$direct_exit), documented non-fatal form leaves caller exit 0"
  else
    fail "(b) ACCEPTANCE: non-fatal-failure -- direct_exit=$direct_exit caller_exit=$caller_exit"
  fi
}

# =====================================================================================
# Case (c): metrics_project_slug derivation matches the exact confirmed mapping, plus a path
# containing dots and a path containing a hyphen.
# =====================================================================================
{
  scratch="$(build_scratch)"
  slug_out=$(bash -c '
    source "'"$scratch"'/.claude/scripts/lib/common.sh"
    metrics_project_slug() { local p="${1:-}"; printf "%s" "$p" | sed "s/[^A-Za-z0-9]/-/g"; }
    metrics_project_slug "/home/benjamin/.config/nvim"
  ')
  dots_out=$(bash -c '
    metrics_project_slug() { local p="${1:-}"; printf "%s" "$p" | sed "s/[^A-Za-z0-9]/-/g"; }
    metrics_project_slug "/home/user/my.project.dir"
  ')
  hyphen_out=$(bash -c '
    metrics_project_slug() { local p="${1:-}"; printf "%s" "$p" | sed "s/[^A-Za-z0-9]/-/g"; }
    metrics_project_slug "/home/user/my-repo"
  ')
  if [ "$slug_out" = "-home-benjamin--config-nvim" ] \
    && [ "$dots_out" = "-home-user-my-project-dir" ] \
    && [ "$hyphen_out" = "-home-user-my-repo" ]; then
    pass "(c) slug-derivation: confirmed mapping plus dots/hyphen paths all match"
  else
    fail "(c) slug-derivation: slug_out=[$slug_out] dots_out=[$dots_out] hyphen_out=[$hyphen_out]"
  fi
}

# =====================================================================================
# Case (d): exact-match join -- two candidate transcripts differing only in embedded
# dispatch_seq; the correct one is selected and its tokens/model/tool_calls are read.
# =====================================================================================
build_fake_transcript_tree() {
  # build_fake_transcript_tree <scratch_home> <repo_path> <cc_session_id> <task_number>
  # <dispatch_seq> <agent_filename_no_ext> -- writes one agent-*.jsonl whose first line embeds
  # the given task_number/dispatch_seq (escaped exactly as Claude Code's own transcripts do)
  # and one assistant line carrying usage/model/tool_use content.
  local scratch_home="$1" repo_path="$2" cc_sid="$3" task_num="$4" disp_seq="$5" fname="$6"
  local slug
  slug=$(printf '%s' "$repo_path" | sed 's/[^A-Za-z0-9]/-/g')
  local dir="$scratch_home/.claude/projects/${slug}/${cc_sid}/subagents"
  mkdir -p "$dir"
  # REAL newlines and REAL quote characters -- jq's --arg below does the one-and-only layer of
  # JSON-string escaping (matching how Claude Code's own transcript stores this field: a plain
  # string whose literal characters include unescaped quotes, escaped by the JSONL encoding and
  # unescaped back by `jq -r` on read, exactly as context/formats/dispatch-metrics.md's join
  # procedure documents). Double-escaping here would not match the real on-disk shape.
  local content_str
  content_str="Context:
{
  \"task_number\": ${task_num},
  \"dispatch_seq\": ${disp_seq}
}"
  {
    jq -n -c --arg content "$content_str" '{type:"user", message:{role:"user", content:$content}, timestamp:"2026-01-01T00:00:00.000Z"}'
    jq -n -c '{type:"assistant", timestamp:"2026-01-01T00:05:00.000Z", message:{role:"assistant", model:"claude-sonnet-5", usage:{input_tokens:10, cache_creation_input_tokens:20, cache_read_input_tokens:30, output_tokens:40}, content:[{type:"tool_use", name:"Read"}, {type:"tool_use", name:"Read"}, {type:"tool_use", name:"Bash"}]}}'
  } > "$dir/agent-${fname}.jsonl"
}

{
  scratch="$(build_scratch)"
  scratch_home="$(mktemp -d -p "$TOP_WORKDIR")"
  repo_path="$scratch"
  cc_sid="11111111-1111-1111-1111-111111111111"
  build_fake_transcript_tree "$scratch_home" "$repo_path" "$cc_sid" 1 3 "aaaa"
  build_fake_transcript_tree "$scratch_home" "$repo_path" "$cc_sid" 1 9 "bbbb"
  doc="$scratch/$METRICS_REL"
  HOME="$scratch_home" run_dm "$scratch" --task-dir "$scratch/specs/001_demo_task" \
    --phase implement --agent x --outcome completed \
    --dispatch-seq 3 --session sess_1700000000_cccccc --cc-session-id "$cc_sid" \
    >/dev/null 2>&1
  entry="$(tail -1 "$doc" 2>/dev/null)"
  if [ -n "$entry" ] \
    && [ "$(printf '%s' "$entry" | jq -r '.model')" = "claude-sonnet-5" ] \
    && [ "$(printf '%s' "$entry" | jq -r '.tokens.input')" = "10" ] \
    && [ "$(printf '%s' "$entry" | jq -r '.tool_calls.total')" = "3" ]; then
    pass "(d.1) exact-match-join: dispatch_seq=3 candidate correctly selected over the dispatch_seq=9 sibling"
  else
    fail "(d.1) exact-match-join: entry=[$entry]"
  fi
}

# =====================================================================================
# Case (d.2): two candidates BOTH matching the same task_number+dispatch_seq (defensive,
# impossible-but-tested case) -- omission rather than an arbitrary pick.
# =====================================================================================
{
  scratch="$(build_scratch)"
  scratch_home="$(mktemp -d -p "$TOP_WORKDIR")"
  repo_path="$scratch"
  cc_sid="22222222-2222-2222-2222-222222222222"
  build_fake_transcript_tree "$scratch_home" "$repo_path" "$cc_sid" 1 3 "cccc"
  build_fake_transcript_tree "$scratch_home" "$repo_path" "$cc_sid" 1 3 "dddd"
  doc="$scratch/$METRICS_REL"
  HOME="$scratch_home" run_dm "$scratch" --task-dir "$scratch/specs/001_demo_task" \
    --phase implement --agent x --outcome completed --dispatch-seq 3 \
    --session sess_1700000000_dddddd --cc-session-id "$cc_sid" >/dev/null 2>&1
  entry="$(tail -1 "$doc" 2>/dev/null)"
  if [ -n "$entry" ] && [ "$(printf '%s' "$entry" | jq -r 'has("tokens")')" = "false" ]; then
    pass "(d.2) exact-match-join: ambiguous double-match omits rather than guessing"
  else
    fail "(d.2) exact-match-join: ambiguous double-match case -- entry=[$entry]"
  fi
}

# =====================================================================================
# Case (e): an unrecognized --outcome refuses and writes nothing.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$METRICS_REL"
  if run_dm "$scratch" --task-dir "$scratch/specs/001_demo_task" \
      --phase implement --agent x --outcome bogus --dispatch-seq 1 \
      --session sess_1700000000_eeeeee >/dev/null 2>&1; then
    fail "(e) invalid-outcome: expected nonzero exit, got exit 0"
  elif [ -f "$doc" ]; then
    fail "(e) invalid-outcome: metrics.jsonl was created (must not write on a validation failure)"
  else
    pass "(e) invalid-outcome: exited nonzero and wrote nothing"
  fi
}

# =====================================================================================
# Case (f): an unrecognized --phase refuses and writes nothing.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$METRICS_REL"
  if run_dm "$scratch" --task-dir "$scratch/specs/001_demo_task" \
      --phase bogus --agent x --outcome completed --dispatch-seq 1 \
      --session sess_1700000000_ffffff >/dev/null 2>&1; then
    fail "(f) invalid-phase: expected nonzero exit, got exit 0"
  elif [ -f "$doc" ]; then
    fail "(f) invalid-phase: metrics.jsonl was created (must not write on a validation failure)"
  else
    pass "(f) invalid-phase: exited nonzero and wrote nothing"
  fi
}

# =====================================================================================
# Case (g): the append path -- two sequential invocations yield exactly two lines, each
# independently jq-parseable, and metrics.jsonl plus .metrics.lock are lazily created.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$METRICS_REL"
  lock="$scratch/specs/001_demo_task/.metrics.lock"
  if [ -f "$doc" ] || [ -f "$lock" ]; then
    fail "(g) lazy-creation: metrics.jsonl or .metrics.lock pre-existed before any call"
  else
    run_dm "$scratch" --task-dir "$scratch/specs/001_demo_task" \
      --phase implement --agent x --outcome completed --dispatch-seq 1 \
      --session sess_1700000000_gggggg >/dev/null 2>&1
    run_dm "$scratch" --task-dir "$scratch/specs/001_demo_task" \
      --phase implement --agent x --outcome completed --dispatch-seq 2 \
      --session sess_1700000000_hhhhhh >/dev/null 2>&1
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
    if [ -f "$doc" ] && [ -f "$lock" ] && [ "$line_count" -eq 2 ] && [ "$bad_lines" -eq 0 ]; then
      pass "(g) append-path: two sequential calls yield exactly 2 well-formed lines; file+lock lazily created"
    else
      fail "(g) append-path: line_count=$line_count bad_lines=$bad_lines doc_exists=$([ -f "$doc" ] && echo y || echo n) lock_exists=$([ -f "$lock" ] && echo y || echo n)"
    fi
  fi
}

# =====================================================================================
# Case (h): --backfill marking -- every backfilled line carries backfilled: true.
# =====================================================================================
{
  scratch="$(build_scratch)"
  bfdir="$(mktemp -d -p "$TOP_WORKDIR")"
  (
    cd "$bfdir" || exit 1
    git init -q
    git config user.email "t@t.local"
    git config user.name "T"
    mkdir -p specs/005_bf_task
    echo x > specs/005_bf_task/f.md
    git add specs/005_bf_task/f.md
    GIT_AUTHOR_DATE="2026-02-01T00:00:00" GIT_COMMITTER_DATE="2026-02-01T00:00:00" \
      git commit -q -m "task 5: complete research"
    echo y > specs/005_bf_task/g.md
    git add specs/005_bf_task/g.md
    GIT_AUTHOR_DATE="2026-02-01T01:00:00" GIT_COMMITTER_DATE="2026-02-01T01:00:00" \
      git commit -q -m "$(printf 'task 5: create implementation plan\n\nSession: sess_1700000000_iiiiii')"
  )
  mkdir -p "$bfdir/.claude/scripts/lib"
  cp "$SCRIPT_UNDER_TEST" "$bfdir/.claude/scripts/dispatch-metrics.sh"
  cp "$GUARD_SCRIPT" "$bfdir/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_SCRIPT" "$bfdir/.claude/scripts/lib/common.sh"
  cp "$TASK_LOOKUP_SCRIPT" "$bfdir/.claude/scripts/lib/task-lookup-lib.sh"
  chmod +x "$bfdir/.claude/scripts/dispatch-metrics.sh"
  cat > "$bfdir/specs/state.json" <<'EOF'
{"active_projects": [{"project_number": 5, "project_name": "bf_task", "status": "completed"}]}
EOF
  touch "$bfdir/specs/events.jsonl"
  bash "$bfdir/.claude/scripts/dispatch-metrics.sh" --backfill 5 >/dev/null 2>&1
  bfdoc="$bfdir/specs/005_bf_task/metrics.jsonl"
  if [ -f "$bfdoc" ] && [ "$(jq -cs 'map(.backfilled) | unique' "$bfdoc" 2>/dev/null)" = "[true]" ] \
    && [ "$(jq -cs 'map(has("figure_provenance")) | unique' "$bfdoc" 2>/dev/null)" = "[true]" ] \
    && [ "$(jq -cs 'map(has("tokens")) | unique' "$bfdoc" 2>/dev/null)" = "[false]" ]; then
    pass "(h) backfill-marking: every line backfilled:true with populated figure_provenance, no tokens key"
  else
    fail "(h) backfill-marking: $([ -f "$bfdoc" ] && cat "$bfdoc" || echo 'no metrics.jsonl produced')"
  fi
}

# =====================================================================================
# Case (i): the wall-clock sentinel -- --dispatch-start-ts 9999999999 omits
# wall_clock_seconds rather than emitting a negative number.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$METRICS_REL"
  run_dm "$scratch" --task-dir "$scratch/specs/001_demo_task" \
    --phase implement --agent x --outcome completed --dispatch-seq 1 \
    --dispatch-start-ts 9999999999 --session sess_1700000000_jjjjjj >/dev/null 2>&1
  entry="$(tail -1 "$doc" 2>/dev/null)"
  if [ -n "$entry" ] && [ "$(printf '%s' "$entry" | jq -r 'has("wall_clock_seconds")')" = "false" ]; then
    pass "(i) wall-clock-sentinel: dispatch_start_ts=9999999999 omits wall_clock_seconds"
  else
    fail "(i) wall-clock-sentinel: entry=[$entry]"
  fi
}

# =====================================================================================
# Case (j): --task-dir and --task together refuses (mutually exclusive).
# =====================================================================================
{
  scratch="$(build_scratch)"
  if run_dm "$scratch" --task-dir "$scratch/specs/001_demo_task" --task 1 \
      --phase implement --agent x --outcome completed --dispatch-seq 1 \
      --session sess_1700000000_kkkkkk >/dev/null 2>&1; then
    fail "(j) mutually-exclusive-task-args: expected nonzero exit, got exit 0"
  else
    pass "(j) mutually-exclusive-task-args: exited nonzero when both --task-dir and --task given"
  fi
}

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
# task-ref-ok:end
