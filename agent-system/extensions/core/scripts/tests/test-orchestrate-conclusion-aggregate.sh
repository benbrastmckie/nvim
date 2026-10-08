#!/usr/bin/env bash
# test-orchestrate-conclusion-aggregate.sh - Regression suite for
# orchestrate-conclusion-aggregate.sh, proving the load-bearing claims mechanically: resolution
# filtering, win separation, cross-task grouping into one proposal per recurring class, citation
# presence, unknown-class tallying, no-contribution tracking, and -- the acceptance-critical
# case -- per-channel approval isolation (no channel fires on another channel's approval).
#
# Structural model: scripts/tests/test-issue-record.sh (set -uo pipefail, pass()/fail()/info()
# helpers, PASSED/FAILED integer counters, exit 0 all-pass / 1 any-fail / 2 environment error,
# deploy-tree-first / source-store-fallback script resolution, mktemp -d scratch project root
# with a scratch specs/state.json and real scratch task directories).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (orchestrate-conclusion-aggregate.sh not found at any candidate path).

# task-ref-ok:begin inline, category 3: command-usage examples -- the script under test's own
# --tasks flag takes concrete integer project/task numbers, used literally throughout this
# suite's invocations and scratch state.json fixtures.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

SCRIPT_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/orchestrate-conclusion-aggregate.sh"
  "$SCRIPT_DIR/../orchestrate-conclusion-aggregate.sh"
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
# Phase 9 cross-cutting fixtures (case i, commit-scope) additionally need git-commit-scoped.sh
# and its own runtime dependency task-lock.sh -- resolved the same deploy-tree-first /
# source-store-fallback way as every other candidate above.
GIT_COMMIT_SCOPED_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/git-commit-scoped.sh"
  "$SCRIPT_DIR/../git-commit-scoped.sh"
)
TASK_LOCK_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/task-lock.sh"
  "$SCRIPT_DIR/../task-lock.sh"
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
GIT_COMMIT_SCOPED_SCRIPT=""
for candidate in "${GIT_COMMIT_SCOPED_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    GIT_COMMIT_SCOPED_SCRIPT="$candidate"
    break
  fi
done
TASK_LOCK_SCRIPT=""
for candidate in "${TASK_LOCK_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    TASK_LOCK_SCRIPT="$candidate"
    break
  fi
done

if [[ -z "$SCRIPT_UNDER_TEST" ]]; then
  echo "ERROR: orchestrate-conclusion-aggregate.sh not found at any of:" >&2
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
#     tree with five active projects (1..5), echoes the scratch root on stdout. ---
build_scratch() {
  local scratch
  scratch="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$scratch/.claude/scripts/lib" \
    "$scratch/specs/001_task_a" "$scratch/specs/002_task_b" "$scratch/specs/003_task_c" \
    "$scratch/specs/004_task_empty" "$scratch/specs/005_task_missing"
  cp "$SCRIPT_UNDER_TEST" "$scratch/.claude/scripts/orchestrate-conclusion-aggregate.sh"
  cp "$GUARD_SCRIPT" "$scratch/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_SCRIPT" "$scratch/.claude/scripts/lib/common.sh"
  cp "$TASK_LOOKUP_SCRIPT" "$scratch/.claude/scripts/lib/task-lookup-lib.sh"
  chmod +x "$scratch/.claude/scripts/orchestrate-conclusion-aggregate.sh"
  cat > "$scratch/specs/state.json" <<'EOF'
{
  "active_projects": [
    {"project_number": 1, "project_name": "task_a", "status": "implementing"},
    {"project_number": 2, "project_name": "task_b", "status": "implementing"},
    {"project_number": 3, "project_name": "task_c", "status": "implementing"},
    {"project_number": 4, "project_name": "task_empty", "status": "implementing"},
    {"project_number": 5, "project_name": "task_missing", "status": "implementing"}
  ]
}
EOF
  # project 4's issues.jsonl exists but is empty; project 5's does not exist at all.
  : > "$scratch/specs/004_task_empty/issues.jsonl"
  echo "$scratch"
}

# run_agg <scratch> [args...] -- invokes orchestrate-conclusion-aggregate.sh from the scratch's
# .claude tree.
run_agg() {
  local scratch="$1"; shift
  bash "$scratch/.claude/scripts/orchestrate-conclusion-aggregate.sh" "$@"
}

# write_entry <issues_file> <kind> <class> <severity> <resolution_or_null> <suggested_channel_or_null>
# <what_happened> -- appends one well-formed issues.jsonl line directly (bypassing issue-record.sh,
# which this suite does not depend on).
write_entry() {
  local file="$1" kind="$2" class="$3" severity="$4" resolution="$5" suggested="$6" what="$7"
  jq -c -n \
    --arg entry_id "iss_$(date -u +%s%N)_$RANDOM" \
    --arg kind "$kind" --arg class "$class" --arg severity "$severity" \
    --arg resolution "$resolution" --arg suggested "$suggested" --arg what "$what" \
    '{
      entry_id: $entry_id, timestamp: "2026-01-01T00:00:00Z", kind: $kind, class: $class,
      severity: $severity, phase: null, dispatch_seq: null, what_happened: $what,
      evidence_path: null, estimated_cost: null,
      resolution: (if $resolution == "null" then null else $resolution end),
      suggested_channel: (if $suggested == "null" then null else $suggested end),
      tags: {}, task_dir: "unused", session_id: null
    }' >> "$file"
}

SID="sess_test_$$_aggregate"

# =====================================================================================
# Case (a): resolution filtering -- an open entry and a worked_around entry appear in
# proposals[]; a fixed_inline non-win entry does not.
# =====================================================================================
{
  scratch="$(build_scratch)"
  f1="$scratch/specs/001_task_a/issues.jsonl"
  write_entry "$f1" issue "tooling bug or gap" minor open null fix_now "open entry"
  write_entry "$f1" issue "tooling bug or gap" minor worked_around null fix_now "worked-around entry"
  write_entry "$f1" issue "tooling bug or gap" minor fixed_inline null fix_now "fixed entry"
  out="$(run_agg "$scratch" --aggregate --session "$SID" --tasks "1")"
  cites=$(echo "$out" | jq '[.proposals[] | select(.class=="tooling bug or gap") | .citations[]] | length')
  if [ "$cites" = "2" ]; then
    pass "(a) resolution-filtering: open+worked_around entries counted, fixed_inline excluded (citations=2)"
  else
    fail "(a) resolution-filtering: expected 2 citations, got $cites -- $out"
  fi
}

# =====================================================================================
# Case (b): win separation -- a kind:"win" entry appears in wins[] and in no proposal.
# =====================================================================================
{
  scratch="$(build_scratch)"
  f1="$scratch/specs/001_task_a/issues.jsonl"
  write_entry "$f1" win "orchestration defect" none null null null "a win"
  out="$(run_agg "$scratch" --aggregate --session "$SID" --tasks "1")"
  win_count=$(echo "$out" | jq '.wins | length')
  prop_count=$(echo "$out" | jq '[.proposals[] | select(.class=="orchestration defect")] | length')
  if [ "$win_count" = "1" ] && [ "$prop_count" = "0" ]; then
    pass "(b) win-separation: win entry in wins[], no proposal generated"
  else
    fail "(b) win-separation: win_count=$win_count prop_count=$prop_count -- $out"
  fi
}

# =====================================================================================
# Case (c): cross-task grouping -- three scratch tasks each recording the same class
# produce exactly ONE proposal carrying THREE citations, not three proposals.
# =====================================================================================
{
  scratch="$(build_scratch)"
  write_entry "$scratch/specs/001_task_a/issues.jsonl" issue "gate collision" minor open null fix_now "task 1 gate collision"
  write_entry "$scratch/specs/002_task_b/issues.jsonl" issue "gate collision" costly worked_around null agent_system "task 2 gate collision"
  write_entry "$scratch/specs/003_task_c/issues.jsonl" issue "gate collision" minor open null fix_now "task 3 gate collision"
  out="$(run_agg "$scratch" --aggregate --session "$SID" --tasks "1 2 3")"
  prop_count=$(echo "$out" | jq '[.proposals[] | select(.class=="gate collision")] | length')
  cite_count=$(echo "$out" | jq '[.proposals[] | select(.class=="gate collision") | .citations[]] | length')
  sev_max=$(echo "$out" | jq -r '.proposals[] | select(.class=="gate collision") | .severity_max')
  if [ "$prop_count" = "1" ] && [ "$cite_count" = "3" ] && [ "$sev_max" = "costly" ]; then
    pass "(c) cross-task-grouping: one proposal, three citations, severity_max=costly"
  else
    fail "(c) cross-task-grouping: prop_count=$prop_count cite_count=$cite_count sev_max=$sev_max -- $out"
  fi
}

# =====================================================================================
# Case (d): citation presence -- every emitted proposal carries a non-empty citations[]
# with both a task number and an entry_id.
# =====================================================================================
{
  scratch="$(build_scratch)"
  write_entry "$scratch/specs/001_task_a/issues.jsonl" issue "environment" minor open null null "env issue"
  out="$(run_agg "$scratch" --aggregate --session "$SID" --tasks "1")"
  ok=$(echo "$out" | jq '[.proposals[] | (.citations | length > 0) and (.citations[0] | has("task") and has("entry_id"))] | all')
  if [ "$ok" = "true" ]; then
    pass "(d) citation-presence: every proposal carries non-empty citations with task+entry_id"
  else
    fail "(d) citation-presence: $out"
  fi
}

# =====================================================================================
# Case (e): unknown-class tally -- an entry with a class outside the seed enum is
# counted in unknown_classes[].
# =====================================================================================
{
  scratch="$(build_scratch)"
  write_entry "$scratch/specs/001_task_a/issues.jsonl" issue "a brand new unseeded class" minor open null null "novel class"
  out="$(run_agg "$scratch" --aggregate --session "$SID" --tasks "1")"
  count=$(echo "$out" | jq '[.unknown_classes[] | select(.class=="a brand new unseeded class")] | length')
  if [ "$count" = "1" ]; then
    pass "(e) unknown-class-tally: novel class counted in unknown_classes[]"
  else
    fail "(e) unknown-class-tally: $out"
  fi
}

# =====================================================================================
# Case (f): no_contribution_tasks[] -- a touched task with no issues.jsonl (project 5)
# and one with an empty file (project 4) both appear; a task with content does not.
# =====================================================================================
{
  scratch="$(build_scratch)"
  write_entry "$scratch/specs/001_task_a/issues.jsonl" issue "environment" minor open null null "has content"
  out="$(run_agg "$scratch" --aggregate --session "$SID" --tasks "1 4 5")"
  nc="$(echo "$out" | jq -c '.no_contribution_tasks | sort')"
  if [ "$nc" = "[4,5]" ]; then
    pass "(f) no-contribution-tasks: empty-file task and missing-file task both listed, content task excluded"
  else
    fail "(f) no-contribution-tasks: expected [4,5], got $nc -- $out"
  fi
}

# =====================================================================================
# Case (g) [ACCEPTANCE-CRITICAL]: per-channel approval isolation. Recording "yes" for
# channel (a) only must leave (b) and (c) not-approved; repeated for (b) and (c) alone.
# An unrecorded channel, a "no" answer, and a malformed ledger all read as not-approved.
# =====================================================================================
{
  scratch="$(build_scratch)"
  gsid="${SID}_g"

  # Channel (a) only.
  run_agg "$scratch" --record-approval --session "$gsid" --channel a --answer yes >/dev/null 2>&1
  a_ok=1; b_ok=1; c_ok=1
  run_agg "$scratch" --check-approval --session "$gsid" --channel a >/dev/null 2>&1; a_ok=$?
  run_agg "$scratch" --check-approval --session "$gsid" --channel b >/dev/null 2>&1; b_ok=$?
  run_agg "$scratch" --check-approval --session "$gsid" --channel c >/dev/null 2>&1; c_ok=$?
  case_g1=false
  if [ "$a_ok" -eq 0 ] && [ "$b_ok" -ne 0 ] && [ "$c_ok" -ne 0 ]; then case_g1=true; fi

  # Channel (b) only, fresh session.
  gsid2="${SID}_g2"
  run_agg "$scratch" --record-approval --session "$gsid2" --channel b --answer yes >/dev/null 2>&1
  run_agg "$scratch" --check-approval --session "$gsid2" --channel a >/dev/null 2>&1; a2_ok=$?
  run_agg "$scratch" --check-approval --session "$gsid2" --channel b >/dev/null 2>&1; b2_ok=$?
  run_agg "$scratch" --check-approval --session "$gsid2" --channel c >/dev/null 2>&1; c2_ok=$?
  case_g2=false
  if [ "$a2_ok" -ne 0 ] && [ "$b2_ok" -eq 0 ] && [ "$c2_ok" -ne 0 ]; then case_g2=true; fi

  # Channel (c) only, fresh session.
  gsid3="${SID}_g3"
  run_agg "$scratch" --record-approval --session "$gsid3" --channel c --answer yes >/dev/null 2>&1
  run_agg "$scratch" --check-approval --session "$gsid3" --channel a >/dev/null 2>&1; a3_ok=$?
  run_agg "$scratch" --check-approval --session "$gsid3" --channel b >/dev/null 2>&1; b3_ok=$?
  run_agg "$scratch" --check-approval --session "$gsid3" --channel c >/dev/null 2>&1; c3_ok=$?
  case_g3=false
  if [ "$a3_ok" -ne 0 ] && [ "$b3_ok" -ne 0 ] && [ "$c3_ok" -eq 0 ]; then case_g3=true; fi

  # Unrecorded channel on a brand-new session reads not-approved.
  gsid4="${SID}_g4"
  run_agg "$scratch" --check-approval --session "$gsid4" --channel a >/dev/null 2>&1; unrec_ok=$?
  case_g4=false
  [ "$unrec_ok" -ne 0 ] && case_g4=true

  # A "no" answer reads not-approved.
  gsid5="${SID}_g5"
  run_agg "$scratch" --record-approval --session "$gsid5" --channel a --answer no >/dev/null 2>&1
  run_agg "$scratch" --check-approval --session "$gsid5" --channel a >/dev/null 2>&1; no_ok=$?
  case_g5=false
  [ "$no_ok" -ne 0 ] && case_g5=true

  # A malformed ledger reads not-approved.
  gsid6="${SID}_g6"
  mkdir -p "$scratch/specs/.orchestration"
  echo "{ not valid json" > "$scratch/specs/.orchestration/.conclusion-approval-${gsid6}.json"
  run_agg "$scratch" --check-approval --session "$gsid6" --channel a >/dev/null 2>&1; malformed_ok=$?
  case_g6=false
  [ "$malformed_ok" -ne 0 ] && case_g6=true

  if [ "$case_g1" = "true" ] && [ "$case_g2" = "true" ] && [ "$case_g3" = "true" ] \
    && [ "$case_g4" = "true" ] && [ "$case_g5" = "true" ] && [ "$case_g6" = "true" ]; then
    pass "(g) [ACCEPTANCE-CRITICAL] per-channel approval isolation: a-only/b-only/c-only/unrecorded/no/malformed all behave correctly"
  else
    fail "(g) per-channel approval isolation: g1=$case_g1 g2=$case_g2 g3=$case_g3 g4=$case_g4 g5=$case_g5 g6=$case_g6"
  fi
}

# =====================================================================================
# Case (h): --help exits 0 from the deployed copy but refuses from the source store
# (deploy-root-guard applies to every flag, including --help).
# =====================================================================================
{
  scratch="$(build_scratch)"
  deployed_exit=0
  run_agg "$scratch" --help >/dev/null 2>&1 || deployed_exit=$?
  src_exit=0
  # Deliberately NOT $SCRIPT_UNDER_TEST (deploy-tree-first resolution -- once this script is
  # registered and deployed, that candidate would already point at the deployed copy, defeating
  # this case). The real source-store path is hardcoded here so this case always exercises a
  # genuine source-store invocation regardless of this repo's current deploy state.
  SRC_STORE_SCRIPT="$REPO_ROOT/agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh"
  if [[ -f "$SRC_STORE_SCRIPT" ]]; then
    bash "$SRC_STORE_SCRIPT" --help >/dev/null 2>&1 || src_exit=$?
  else
    info "(h) source-store copy not found at $SRC_STORE_SCRIPT -- skipping the source-store half of this case"
    src_exit=1
  fi
  if [ "$deployed_exit" -eq 0 ] && [ "$src_exit" -ne 0 ]; then
    pass "(h) deploy-root-guard: --help succeeds deployed, refuses from the source store"
  else
    fail "(h) deploy-root-guard: deployed_exit=$deployed_exit src_exit=$src_exit"
  fi
}

# =====================================================================================
# Case (i) [Phase 9, commit-scope fixture]: in an isolated scratch git repo, two distinct
# per-channel pathspec classes are staged and committed through git-commit-scoped.sh in two
# SEPARATE invocations; asserts from `git log`/`git show --stat` that the two commits are
# separate and each contains only its own channel's paths -- per-channel staging scope
# distinguishable in the result, as the acceptance criterion requires. Does not edit
# git-commit-scoped.sh itself (another task's territory); only exercises it.
# =====================================================================================
{
  if [[ -z "$GIT_COMMIT_SCOPED_SCRIPT" ]] || [[ -z "$TASK_LOCK_SCRIPT" ]]; then
    info "(i) commit-scope fixture: git-commit-scoped.sh or task-lock.sh not found -- skipping (environment limitation, not a case failure)"
  else
    cs_repo="$(mktemp -d -p "$TOP_WORKDIR")"
    git -C "$cs_repo" init -q
    git -C "$cs_repo" config user.email "test@example.com"
    git -C "$cs_repo" config user.name "Test Suite"
    mkdir -p "$cs_repo/.claude/scripts/lib"
    cp "$GIT_COMMIT_SCOPED_SCRIPT" "$cs_repo/.claude/scripts/git-commit-scoped.sh"
    cp "$TASK_LOCK_SCRIPT" "$cs_repo/.claude/scripts/task-lock.sh"
    cp "$GUARD_SCRIPT" "$cs_repo/.claude/scripts/deploy-root-guard.sh"
    cp "$COMMON_SCRIPT" "$cs_repo/.claude/scripts/lib/common.sh"
    cp "$TASK_LOOKUP_SCRIPT" "$cs_repo/.claude/scripts/lib/task-lookup-lib.sh"
    chmod +x "$cs_repo/.claude/scripts/git-commit-scoped.sh" "$cs_repo/.claude/scripts/task-lock.sh" "$cs_repo/.claude/scripts/deploy-root-guard.sh"

    # Two disjoint per-channel pathspec classes: channel (a)-shaped fix paths, and the
    # channel (c)-shaped follow-up-task paths (specs/state.json + specs/TODO.md).
    mkdir -p "$cs_repo/agent-system/extensions/core/scripts"
    echo "line1" > "$cs_repo/agent-system/extensions/core/scripts/channel-a-fix.sh"
    echo '{"active_projects":[]}' > "$cs_repo/specs_state_seed.json"
    git -C "$cs_repo" add agent-system/extensions/core/scripts/channel-a-fix.sh specs_state_seed.json
    git -C "$cs_repo" commit -q -m "seed"

    echo "line2" >> "$cs_repo/agent-system/extensions/core/scripts/channel-a-fix.sh"
    mkdir -p "$cs_repo/specs"
    echo '{"active_projects":[]}' > "$cs_repo/specs/state.json"
    echo "# TODO" > "$cs_repo/specs/TODO.md"

    (cd "$cs_repo" && bash "$cs_repo/.claude/scripts/git-commit-scoped.sh" \
      --message "channel (a) fix commit" --session "sess_commitscope_a" \
      -- agent-system/extensions/core/scripts/channel-a-fix.sh >/dev/null 2>&1)
    (cd "$cs_repo" && bash "$cs_repo/.claude/scripts/git-commit-scoped.sh" \
      --message "channel (c) follow-up commit" --session "sess_commitscope_c" \
      -- specs/state.json specs/TODO.md >/dev/null 2>&1)

    commit_count=$(git -C "$cs_repo" log --oneline | wc -l | tr -d ' ')
    a_commit_files=$(git -C "$cs_repo" show --name-only --format= HEAD~1 2>/dev/null)
    c_commit_files=$(git -C "$cs_repo" show --name-only --format= HEAD 2>/dev/null)

    if [ "$commit_count" = "3" ] \
      && echo "$a_commit_files" | grep -q "channel-a-fix.sh" \
      && ! echo "$a_commit_files" | grep -q "specs/state.json" \
      && echo "$c_commit_files" | grep -q "specs/state.json" \
      && echo "$c_commit_files" | grep -q "specs/TODO.md" \
      && ! echo "$c_commit_files" | grep -q "channel-a-fix.sh"; then
      pass "(i) commit-scope: two separate commits, each containing only its own channel's paths"
    else
      fail "(i) commit-scope: commit_count=$commit_count a_files=[$a_commit_files] c_files=[$c_commit_files]"
    fi
  fi
}

# =====================================================================================
# Case (j) [Phase 9, anti-bypass fixture]: meta-builder-agent.md's FORBIDDEN list still names
# its task-creation-only and no-AskUserQuestion constraints, AND the channel (b) step in
# conclusion-stage.md restates the task-creation-only constraint and passes
# collected_answers.confirmed.
# =====================================================================================
{
  mb_agent="$REPO_ROOT/agent-system/extensions/core/agents/meta-builder-agent.md"
  concl="$REPO_ROOT/agent-system/extensions/core/context/contracts/conclusion-stage.md"
  if [[ ! -f "$mb_agent" ]] || [[ ! -f "$concl" ]]; then
    fail "(j) anti-bypass: required source file(s) not found ($mb_agent / $concl)"
  else
    mb_ok=false
    concl_ok=false
    if grep -qE 'Write any files outside' "$mb_agent" \
      && grep -qE 'Call.*AskUserQuestion' "$mb_agent"; then
      mb_ok=true
    fi
    if grep -qi 'creates TASKS' "$concl" \
      && grep -q 'collected_answers.confirmed' "$concl"; then
      concl_ok=true
    fi
    if [ "$mb_ok" = "true" ] && [ "$concl_ok" = "true" ]; then
      pass "(j) anti-bypass: meta-builder-agent.md's FORBIDDEN clauses and conclusion-stage.md's channel (b) restatement both still hold"
    else
      fail "(j) anti-bypass: mb_ok=$mb_ok concl_ok=$concl_ok"
    fi
  fi
}

# =====================================================================================
# Case (k) [Phase 9, gate-intactness fixture]: the three channels' execution steps in
# conclusion-stage.md each reference --check-approval with their OWN channel letter and no
# other's -- the prose half of the invariant case (g) above proves mechanically.
# =====================================================================================
{
  concl="$REPO_ROOT/agent-system/extensions/core/context/contracts/conclusion-stage.md"
  if [[ ! -f "$concl" ]]; then
    fail "(k) gate-intactness: $concl not found"
  else
    # Each step's gate block spans multiple lines (the `--check-approval \` continuation line
    # and the `--channel X` line are separate) -- check membership across the captured block,
    # never a single-line literal match.
    step_4a=$(awk '/^### Step 4a/{flag=1} /^### Step 4b/{flag=0} flag' "$concl")
    step_4b=$(awk '/^### Step 4b/{flag=1} /^### Step 4c/{flag=0} flag' "$concl")
    step_4c=$(awk '/^### Step 4c/{flag=1} /^### Step 5/{flag=0} flag' "$concl")

    a_ok=false; b_ok=false; c_ok=false
    if echo "$step_4a" | grep -q -- "--check-approval" \
      && echo "$step_4a" | grep -qE -- '--channel a\b' \
      && ! echo "$step_4a" | grep -qE -- '--channel (b|c)\b'; then
      a_ok=true
    fi
    if echo "$step_4b" | grep -q -- "--check-approval" \
      && echo "$step_4b" | grep -qE -- '--channel b\b' \
      && ! echo "$step_4b" | grep -qE -- '--channel (a|c)\b'; then
      b_ok=true
    fi
    if echo "$step_4c" | grep -q -- "--check-approval" \
      && echo "$step_4c" | grep -qE -- '--channel c\b' \
      && ! echo "$step_4c" | grep -qE -- '--channel (a|b)\b'; then
      c_ok=true
    fi

    if [ "$a_ok" = "true" ] && [ "$b_ok" = "true" ] && [ "$c_ok" = "true" ]; then
      pass "(k) gate-intactness: each channel's execution step references --check-approval with its own channel letter only"
    else
      fail "(k) gate-intactness: a_ok=$a_ok b_ok=$b_ok c_ok=$c_ok"
    fi
  fi
}

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
# task-ref-ok:end
