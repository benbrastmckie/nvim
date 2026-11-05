#!/usr/bin/env bash
# test-orchestrate-suggest-next-batch.sh - Regression suite for
# orchestrate-suggest-next-batch.sh, proving the acceptance criteria mechanically: a clean
# ready set admits wholesale (a); a file_scope-colliding pair never appears as an unordered
# joint suggestion, DOES appear as an ordered sequence with the --depends-on-add command, and
# flips to admit under --write-edges after a real re-probe (b); Mode B's alternatives search
# excludes tasks covered by a live queue entry and surfaces a disjoint set instead (c); the
# shipped absent-file_scope blocking-in-batch / advisory-cross-batch split is reflected rather
# than second-guessed (d); the batch-size truncation never splits a territory-mandatory group
# off the end (e); no copy of the admission predicate exists anywhere in the new script's
# source, and the real schema document's own Complete JSON Schema section stays untouched (f);
# and the alternatives search's probe-invocation cap is honored and rendered explicitly, never
# silently truncated (g).
#
# Structural model: scripts/tests/test-orchestrate-conclusion-aggregate.sh (set -uo pipefail,
# pass()/fail()/info() helpers, PASSED/FAILED integer counters, exit 0 all-pass / 1 any-fail /
# 2 environment error, deploy-tree-first / source-store-fallback script resolution, mktemp -d
# scratch project root with a scratch specs/state.json and real scratch task directories).
# This suite's scratch tree additionally needs the real orchestrate-batch-admit.sh,
# orchestrate-triage-classify.sh, update-task-status.sh, task-lock.sh, validate-state.sh,
# deploy-root-guard.sh, the WHOLE scripts/lib/ directory (rather than cherry-picking individual
# libraries -- the admission/status/lock/validate chain's transitive dependencies are not all
# independently enumerated by this suite's own research, and a wholesale copy is the
# conservative, correct choice per the plan's own "copy list is a starting hypothesis, not a
# verified inventory" instruction), and context/reference/orchestrator-critical-paths.json --
# because the script under test shells out to every one of those, never re-deriving their
# logic itself (the whole point this suite exists to prove).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (a required script/library not found at any candidate path).

# task-ref-ok:begin inline, category 3: command-usage examples -- the script under test's own
# --session-id/--max-tasks flags and this suite's scratch task numbers are concrete integers
# used literally throughout, not references to this repository's own task-management metadata.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

SCRIPT_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/orchestrate-suggest-next-batch.sh"
  "$SCRIPT_DIR/../orchestrate-suggest-next-batch.sh"
)
ADMIT_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/orchestrate-batch-admit.sh"
  "$SCRIPT_DIR/../orchestrate-batch-admit.sh"
)
TRIAGE_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/orchestrate-triage-classify.sh"
  "$SCRIPT_DIR/../orchestrate-triage-classify.sh"
)
UPDATE_STATUS_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/update-task-status.sh"
  "$SCRIPT_DIR/../update-task-status.sh"
)
TASK_LOCK_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/task-lock.sh"
  "$SCRIPT_DIR/../task-lock.sh"
)
VALIDATE_STATE_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/validate-state.sh"
  "$SCRIPT_DIR/../validate-state.sh"
)
STATE_WRITE_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/state-write.sh"
  "$SCRIPT_DIR/../state-write.sh"
)
GENERATE_TODO_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/generate-todo.sh"
  "$SCRIPT_DIR/../generate-todo.sh"
)
GUARD_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/deploy-root-guard.sh"
  "$SCRIPT_DIR/../deploy-root-guard.sh"
)
LIB_DIR_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/lib"
  "$SCRIPT_DIR/../lib"
)
CRITICAL_PATHS_CANDIDATES=(
  "$REPO_ROOT/.claude/context/reference/orchestrator-critical-paths.json"
  "$SCRIPT_DIR/../../context/reference/orchestrator-critical-paths.json"
)
SCHEMA_DOC_CANDIDATES=(
  "$REPO_ROOT/.claude/docs/architecture/batch-admit-schema.md"
  "$SCRIPT_DIR/../../docs/architecture/batch-admit-schema.md"
)

resolve_one() {
  local name="$1"; shift
  local candidate
  for candidate in "$@"; do
    if [[ -e "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  echo "ERROR: $name not found at any of:" >&2
  for candidate in "$@"; do
    echo "  $candidate" >&2
  done
  return 1
}

SCRIPT_UNDER_TEST="$(resolve_one "orchestrate-suggest-next-batch.sh" "${SCRIPT_CANDIDATES[@]}")" || exit 2
ADMIT_SCRIPT="$(resolve_one "orchestrate-batch-admit.sh" "${ADMIT_CANDIDATES[@]}")" || exit 2
TRIAGE_SCRIPT="$(resolve_one "orchestrate-triage-classify.sh" "${TRIAGE_CANDIDATES[@]}")" || exit 2
UPDATE_STATUS_SCRIPT="$(resolve_one "update-task-status.sh" "${UPDATE_STATUS_CANDIDATES[@]}")" || exit 2
TASK_LOCK_SCRIPT="$(resolve_one "task-lock.sh" "${TASK_LOCK_CANDIDATES[@]}")" || exit 2
VALIDATE_STATE_SCRIPT="$(resolve_one "validate-state.sh" "${VALIDATE_STATE_CANDIDATES[@]}")" || exit 2
STATE_WRITE_SCRIPT="$(resolve_one "state-write.sh" "${STATE_WRITE_CANDIDATES[@]}")" || exit 2
GENERATE_TODO_SCRIPT="$(resolve_one "generate-todo.sh" "${GENERATE_TODO_CANDIDATES[@]}")" || exit 2
GUARD_SCRIPT="$(resolve_one "deploy-root-guard.sh" "${GUARD_CANDIDATES[@]}")" || exit 2
LIB_DIR="$(resolve_one "scripts/lib" "${LIB_DIR_CANDIDATES[@]}")" || exit 2
CRITICAL_PATHS_FILE="$(resolve_one "orchestrator-critical-paths.json" "${CRITICAL_PATHS_CANDIDATES[@]}")" || exit 2
SCHEMA_DOC="$(resolve_one "batch-admit-schema.md" "${SCHEMA_DOC_CANDIDATES[@]}")" || exit 2

PASSED=0
FAILED=0


TOP_WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

# --- build_scratch -- builds an isolated <scratch>/.claude/scripts/{...} +
#     <scratch>/.claude/context/reference/ + <scratch>/specs/ tree with every script/library
#     orchestrate-suggest-next-batch.sh shells out to, plus an empty active_projects state.json.
#     Echoes the scratch root on stdout. ---
build_scratch() {
  local scratch
  scratch="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$scratch/.claude/scripts/lib" "$scratch/.claude/context/reference" \
    "$scratch/specs/.orchestration/queue"
  cp "$SCRIPT_UNDER_TEST" "$scratch/.claude/scripts/orchestrate-suggest-next-batch.sh"
  cp "$ADMIT_SCRIPT" "$scratch/.claude/scripts/orchestrate-batch-admit.sh"
  cp "$TRIAGE_SCRIPT" "$scratch/.claude/scripts/orchestrate-triage-classify.sh"
  cp "$UPDATE_STATUS_SCRIPT" "$scratch/.claude/scripts/update-task-status.sh"
  cp "$TASK_LOCK_SCRIPT" "$scratch/.claude/scripts/task-lock.sh"
  cp "$VALIDATE_STATE_SCRIPT" "$scratch/.claude/scripts/validate-state.sh"
  cp "$STATE_WRITE_SCRIPT" "$scratch/.claude/scripts/state-write.sh"
  cp "$GENERATE_TODO_SCRIPT" "$scratch/.claude/scripts/generate-todo.sh"
  cp "$GUARD_SCRIPT" "$scratch/.claude/scripts/deploy-root-guard.sh"
  cp "$LIB_DIR"/*.sh "$scratch/.claude/scripts/lib/"
  cp "$CRITICAL_PATHS_FILE" "$scratch/.claude/context/reference/orchestrator-critical-paths.json"
  chmod +x "$scratch/.claude/scripts/"*.sh
  echo '{"active_projects": []}' > "$scratch/specs/state.json"
  echo "$scratch"
}

# add_task <scratch> <number> <status> <file_scope_json> <dependencies_json> -- appends one
# active_projects entry (and creates its empty task directory, matching real layout) to the
# scratch state.json. file_scope_json is a JSON value (an array, or the literal null for an
# absent-scope fixture); dependencies_json is a JSON array (possibly empty).
add_task() {
  local scratch="$1" num="$2" status="$3" fs="$4" deps="$5"
  local dir tmp
  dir=$(printf '%03d' "$num")
  mkdir -p "$scratch/specs/${dir}_t${num}"
  tmp="$(mktemp)"
  jq --argjson n "$num" --arg st "$status" --argjson fs "$fs" --argjson deps "$deps" \
    '.active_projects += [{
      project_number: $n, project_name: ("t" + ($n|tostring)), status: $st,
      file_scope: $fs, dependencies: $deps, topic: null
    }]' "$scratch/specs/state.json" > "$tmp"
  mv "$tmp" "$scratch/specs/state.json"
}

# add_queue_entry <scratch> <orchestration_id> <task_numbers_json> <file_scope_json> -- writes
# one LIVE (pid=$$, fresh heartbeat) orchestration-queue entry, matching task-lock.sh's own
# queue-register schema closely enough for queue-list to parse and compute live=true.
add_queue_entry() {
  local scratch="$1" id="$2" nums="$3" fs="$4"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jq -n --arg id "$id" --argjson pid "$$" --argjson nums "$nums" --argjson fs "$fs" --arg now "$now" \
    '{
      orchestration_id: $id, session_id: ("sess_" + $id), pid: $pid, pid_source: "test",
      command: "/orchestrate test", task_numbers: $nums, file_scope: $fs, state: "running",
      started_at: $now, heartbeat_at: $now, finished_at: null, archived_at: null,
      disposition_reason: null
    }' > "$scratch/specs/.orchestration/queue/${id}.json"
}

# run_suggest <scratch> [args...] -- invokes orchestrate-suggest-next-batch.sh from the
# scratch's own .claude tree.
run_suggest() {
  local scratch="$1"; shift
  bash "$scratch/.claude/scripts/orchestrate-suggest-next-batch.sh" "$@"
}

SID="sess_test_$$_suggest"

# =====================================================================================
# Case (a): happy path -- a clean, disjoint ready set the real admission script admits
# wholesale. Every member appears in the Mode A suggestion with an admit verdict.
# =====================================================================================
{
  scratch="$(build_scratch)"
  add_task "$scratch" 1 not_started '["agent-system/extensions/core/a1"]' '[]'
  add_task "$scratch" 2 not_started '["agent-system/extensions/core/a2"]' '[]'
  add_task "$scratch" 3 not_started '["agent-system/extensions/core/a3"]' '[]'
  out="$(run_suggest "$scratch" --next-batch --session-id "$SID")"
  rc=$?
  if [ "$rc" -eq 0 ] \
    && echo "$out" | grep -q '^/orchestrate' \
    && echo "$out" | grep -q 'task 1: admit' \
    && echo "$out" | grep -q 'task 2: admit' \
    && echo "$out" | grep -q 'task 3: admit'; then
    common_test_pass "(a) happy path: a clean disjoint ready set admits wholesale, every member shown as admit"
  else
    common_test_fail "(a) happy path: rc=$rc -- $out"
  fi
}

# =====================================================================================
# Case (b): the edge-proposing acceptance case -- two ready, EXACT-file_scope-colliding
# candidates with no existing edge. Pre-edge: no unordered joint suggestion. Post
# --write-edges: both verdicts flip to admit on a real re-probe.
# =====================================================================================
{
  scratch="$(build_scratch)"
  add_task "$scratch" 10 researched '["agent-system/extensions/core/shared-territory"]' '[]'
  add_task "$scratch" 11 researched '["agent-system/extensions/core/shared-territory"]' '[]'
  out="$(run_suggest "$scratch" --next-batch --session-id "$SID")"
  rc=$?
  no_joint_pair=true
  echo "$out" | grep -E '^/orchestrate 1?0?,\s*1?1?$' >/dev/null 2>&1 && no_joint_pair=false
  if [ "$rc" -eq 0 ] && [ "$no_joint_pair" = true ] \
    && echo "$out" | grep -q '10, then 11' \
    && echo "$out" | grep -q -- '--depends-on-add=\[10\]'; then
    common_test_pass "(b.1) pre-edge: colliding pair renders as an ordered sequence with the --depends-on-add command, never an unordered joint line"
  else
    common_test_fail "(b.1) pre-edge: rc=$rc no_joint_pair=$no_joint_pair -- $out"
  fi
}
{
  scratch="$(build_scratch)"
  add_task "$scratch" 10 researched '["agent-system/extensions/core/shared-territory"]' '[]'
  add_task "$scratch" 11 researched '["agent-system/extensions/core/shared-territory"]' '[]'
  out="$(run_suggest "$scratch" --next-batch --session-id "$SID" --write-edges)"
  rc=$?
  if [ "$rc" -eq 0 ] \
    && echo "$out" | grep -q 'edge written' \
    && echo "$out" | grep -q 'task 10: admit' \
    && echo "$out" | grep -q 'task 11: admit'; then
    common_test_pass "(b.2) --write-edges: edge written and a real re-probe flips both members to admit"
  else
    common_test_fail "(b.2) --write-edges: rc=$rc -- $out"
  fi
  dep_check=$(jq -c '.active_projects[] | select(.project_number==11) | .dependencies' "$scratch/specs/state.json")
  if [ "$dep_check" = "[10]" ]; then
    common_test_pass "(b.3) --write-edges: the edge was actually written to scratch state.json (task 11 depends on [10])"
  else
    common_test_fail "(b.3) --write-edges: expected task 11 dependencies [10], got $dep_check"
  fi
}

# =====================================================================================
# Case (c): Mode B -- a live queue entry covering the obvious next batch forces the
# alternatives search to surface a different, disjoint set.
# =====================================================================================
{
  scratch="$(build_scratch)"
  add_task "$scratch" 30 not_started '["agent-system/extensions/core/c30"]' '[]'
  add_task "$scratch" 31 not_started '["agent-system/extensions/core/c31"]' '[]'
  add_task "$scratch" 32 not_started '["agent-system/extensions/core/c32"]' '[]'
  add_task "$scratch" 33 not_started '["agent-system/extensions/core/c33"]' '[]'
  add_queue_entry "$scratch" "orch_c" '[30,31]' '["agent-system/extensions/core/c30","agent-system/extensions/core/c31"]'

  out_a="$(run_suggest "$scratch" --next-batch --session-id "$SID")"
  out_b="$(run_suggest "$scratch" --alternatives --session-id "$SID")"
  if echo "$out_a" | grep -q 'task 30: admit' && echo "$out_a" | grep -q 'task 31: admit'; then
    common_test_pass "(c.1) Mode A (queue-unaware) proposes the obvious batch, which includes the queue-covered tasks"
  else
    common_test_fail "(c.1) Mode A did not propose tasks 30/31 as expected -- $out_a"
  fi
  if ! echo "$out_b" | grep -q 'task 30' && ! echo "$out_b" | grep -q 'task 31' \
    && echo "$out_b" | grep -q 'task 32: admit' && echo "$out_b" | grep -q 'task 33: admit'; then
    common_test_pass "(c.2) Mode B excludes the live-queue-covered tasks (30,31) and surfaces a disjoint set (32,33) instead"
  else
    common_test_fail "(c.2) Mode B did not surface the expected disjoint alternative -- $out_b"
  fi
}

# =====================================================================================
# Case (d): absent-file_scope candidates -- the shipped blocking-in-batch posture is
# reflected (the lower-numbered, designated candidate admits; the other defers and is
# dropped this round) rather than second-guessed or forced through as a joint pair.
# Status "planned" (-> phase group "implement", per orchestrate-triage-classify.sh's
# routing table) is used deliberately rather than "not_started": a research/plan-routed
# absent-scope candidate is UNCONDITIONALLY exempt from this blocking branch (the same
# D-phase rationale the self-modification branch uses), so "not_started" would admit both
# candidates regardless of the collision and never exercise the branch under test.
# =====================================================================================
{
  scratch="$(build_scratch)"
  add_task "$scratch" 20 planned 'null' '[]'
  add_task "$scratch" 21 planned 'null' '[]'
  out="$(run_suggest "$scratch" --next-batch --session-id "$SID")"
  rc=$?
  if [ "$rc" -eq 0 ] && echo "$out" | grep -q 'task 20: admit' && ! echo "$out" | grep -q 'task 21: admit'; then
    common_test_pass "(d) absent-file_scope: the designated (lowest-numbered) absent-scope candidate admits; the other defers and is dropped this round, not forced through"
  else
    common_test_fail "(d) absent-file_scope: rc=$rc -- $out"
  fi
}

# =====================================================================================
# Case (e): truncation precedence -- a territory-mandatory pair (exact file_scope match)
# is never split off the end by --max-tasks; an unrelated singleton that would have been
# trimmed never appears in the output at all.
# =====================================================================================
{
  scratch="$(build_scratch)"
  add_task "$scratch" 40 researched '["agent-system/extensions/core/e-territory"]' '[]'
  add_task "$scratch" 41 researched '["agent-system/extensions/core/e-territory"]' '[]'
  add_task "$scratch" 42 researched '["agent-system/extensions/core/e-other"]' '[]'
  out="$(run_suggest "$scratch" --next-batch --session-id "$SID" --max-tasks 2)"
  rc=$?
  if [ "$rc" -eq 0 ] && echo "$out" | grep -q '40, then 41' && ! echo "$out" | grep -q 'task 42'; then
    common_test_pass "(e) truncation precedence: the territory-mandatory pair (40,41) is fully represented; the trimmed singleton (42) never appears"
  else
    common_test_fail "(e) truncation precedence: rc=$rc -- $out"
  fi
}

# =====================================================================================
# Case (f): the no-forked-predicate regression -- the script's own source contains no
# overlap-library reference, no hand-rolled jq overlap defs, and no hand-rolled
# path-prefix comparison; and the real schema document's Complete JSON Schema section
# carries no reference to this task's new script (only the "Read by" consumer list may,
# and only once Phase 5 wires it -- this section itself must never grow).
# =====================================================================================
{
  forked_refs=$(grep -c 'file-scope-overlap\|scopes_overlap\|self_mod_match\|norm(' "$SCRIPT_UNDER_TEST" || true)
  forked_refs=${forked_refs:-0}
  path_prefix_hits=$(grep -cE 'dirname.*basename|startswith\(.*\)\s*and' "$SCRIPT_UNDER_TEST" || true)
  path_prefix_hits=${path_prefix_hits:-0}
  if [ "$forked_refs" = "0" ] && [ "$path_prefix_hits" = "0" ]; then
    common_test_pass "(f.1) no-forked-predicate: zero overlap-library/jq-def/path-prefix references in the new script's own source"
  else
    common_test_fail "(f.1) no-forked-predicate: forked_refs=$forked_refs path_prefix_hits=$path_prefix_hits"
  fi

  schema_section=$(awk '/^## Complete JSON Schema/{flag=1; next} /^## /{flag=0} flag' "$SCHEMA_DOC")
  if ! echo "$schema_section" | grep -q 'orchestrate-suggest-next-batch'; then
    common_test_pass "(f.2) no-forked-predicate: the real schema document's own Complete JSON Schema section carries no reference to the new script (consumer-list-only, never schema-widening)"
  else
    common_test_fail "(f.2) no-forked-predicate: Complete JSON Schema section unexpectedly references orchestrate-suggest-next-batch.sh"
  fi
}

# =====================================================================================
# Case (g): the probe-invocation cap -- never exceeded, and the cap-reached condition is
# rendered explicitly rather than silently truncating the search.
# =====================================================================================
{
  scratch="$(build_scratch)"
  add_task "$scratch" 50 not_started '["agent-system/extensions/core/g50"]' '[]'
  add_task "$scratch" 51 not_started '["agent-system/extensions/core/g51"]' '[]'
  sed -i 's/MAX_PROBE_INVOCATIONS=20/MAX_PROBE_INVOCATIONS=0/' "$scratch/.claude/scripts/orchestrate-suggest-next-batch.sh"
  out="$(run_suggest "$scratch" --next-batch --session-id "$SID")"
  rc=$?
  if [ "$rc" -eq 0 ] && echo "$out" | grep -q 'probe-invocation cap'; then
    common_test_pass "(g) probe-invocation cap: reaching the cap is rendered explicitly and exits 0, never a silent truncation"
  else
    common_test_fail "(g) probe-invocation cap: rc=$rc -- $out"
  fi
}

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
# task-ref-ok:end
