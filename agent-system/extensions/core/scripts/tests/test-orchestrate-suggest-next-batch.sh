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

SCRIPT_UNDER_TEST="$(common_test_resolve_subject "orchestrate-suggest-next-batch.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/orchestrate-suggest-next-batch.sh" "$SCRIPT_DIR/../orchestrate-suggest-next-batch.sh")" || exit 2
common_test_declare_subject "$SCRIPT_UNDER_TEST"
ADMIT_SCRIPT="$(common_test_resolve_subject "orchestrate-batch-admit.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/orchestrate-batch-admit.sh" "$SCRIPT_DIR/../orchestrate-batch-admit.sh")" || exit 2
common_test_declare_subject "$ADMIT_SCRIPT"
TRIAGE_SCRIPT="$(common_test_resolve_subject "orchestrate-triage-classify.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/orchestrate-triage-classify.sh" "$SCRIPT_DIR/../orchestrate-triage-classify.sh")" || exit 2
common_test_declare_subject "$TRIAGE_SCRIPT"
UPDATE_STATUS_SCRIPT="$(common_test_resolve_subject "update-task-status.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/update-task-status.sh" "$SCRIPT_DIR/../update-task-status.sh")" || exit 2
common_test_declare_subject "$UPDATE_STATUS_SCRIPT"
TASK_LOCK_SCRIPT="$(common_test_resolve_subject "task-lock.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/task-lock.sh" "$SCRIPT_DIR/../task-lock.sh")" || exit 2
common_test_declare_subject "$TASK_LOCK_SCRIPT"
VALIDATE_STATE_SCRIPT="$(common_test_resolve_subject "validate-state.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/validate-state.sh" "$SCRIPT_DIR/../validate-state.sh")" || exit 2
common_test_declare_subject "$VALIDATE_STATE_SCRIPT"
STATE_WRITE_SCRIPT="$(common_test_resolve_subject "state-write.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/state-write.sh" "$SCRIPT_DIR/../state-write.sh")" || exit 2
common_test_declare_subject "$STATE_WRITE_SCRIPT"
GENERATE_TODO_SCRIPT="$(common_test_resolve_subject "generate-todo.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/generate-todo.sh" "$SCRIPT_DIR/../generate-todo.sh")" || exit 2
common_test_declare_subject "$GENERATE_TODO_SCRIPT"
GUARD_SCRIPT="$(common_test_resolve_subject "deploy-root-guard.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/deploy-root-guard.sh" "$SCRIPT_DIR/../deploy-root-guard.sh")" || exit 2
common_test_declare_subject "$GUARD_SCRIPT"
# LIB_DIR is a directory, not a single-file subject -- the shared resolve-subject helper
# resolves one named file via `[ -f ]`, so it cannot resolve a bare directory. Derived instead from
# GUARD_SCRIPT's own resolved directory: both GUARD_CANDIDATES and the old LIB_DIR_CANDIDATES
# shared the identical deploy-tree-first tree-pair order, so whichever tree GUARD_SCRIPT
# resolved from is the same tree this directory must come from.
LIB_DIR="$(dirname "$GUARD_SCRIPT")/lib"
CRITICAL_PATHS_FILE="$(common_test_resolve_subject "orchestrator-critical-paths.json" "deploy-tree-first" \
  "$REPO_ROOT/.claude/context/reference/orchestrator-critical-paths.json" "$SCRIPT_DIR/../../context/reference/orchestrator-critical-paths.json")" || exit 2
common_test_declare_subject "$CRITICAL_PATHS_FILE"
SCHEMA_DOC="$(common_test_resolve_subject "batch-admit-schema.md" "deploy-tree-first" \
  "$REPO_ROOT/.claude/docs/architecture/batch-admit-schema.md" "$SCRIPT_DIR/../../docs/architecture/batch-admit-schema.md")" || exit 2
common_test_declare_subject "$SCHEMA_DOC"

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

# add_task_topic <scratch> <number> <status> <file_scope_json> <dependencies_json> <topic_str>
# -- same as add_task(), but with an explicit non-null `topic` field, for Case (i)'s
# topic-cohesion-criterion fixture (every other case's tasks deliberately use add_task()'s
# topic: null, so this helper is scoped to Case (i) alone rather than widening add_task()).
add_task_topic() {
  local scratch="$1" num="$2" status="$3" fs="$4" deps="$5" topic="$6"
  local dir tmp
  dir=$(printf '%03d' "$num")
  mkdir -p "$scratch/specs/${dir}_t${num}"
  tmp="$(mktemp)"
  jq --argjson n "$num" --arg st "$status" --argjson fs "$fs" --argjson deps "$deps" --arg topic "$topic" \
    '.active_projects += [{
      project_number: $n, project_name: ("t" + ($n|tostring)), status: $st,
      file_scope: $fs, dependencies: $deps, topic: $topic
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
# Case (b-not-started): the SAME edge-proposing acceptance shape as case (b), but with BOTH
# colliding fixture tasks at status "not_started" -- the status update-task-status.sh's
# map_status() has no real-transition arm for, which used to force resolve_noop_token() to
# return 1 (no resolving token) and this script to fall back to propose-only. Now that
# update-task-status.sh carries a dedicated no-op-only `preflight:edge_only` pair for exactly
# this status, resolve_noop_token() resolves it and the edge gets written under --write-edges
# exactly as case (b) does for "researched".
# =====================================================================================
{
  scratch="$(build_scratch)"
  add_task "$scratch" 20 not_started '["agent-system/extensions/core/shared-territory-ns"]' '[]'
  add_task "$scratch" 21 not_started '["agent-system/extensions/core/shared-territory-ns"]' '[]'
  out="$(run_suggest "$scratch" --next-batch --session-id "$SID" --write-edges)"
  rc=$?
  if [ "$rc" -eq 0 ] \
    && echo "$out" | grep -q 'edge written' \
    && echo "$out" | grep -q 'task 20: admit' \
    && echo "$out" | grep -q 'task 21: admit'; then
    common_test_pass "(b-not-started.1) --write-edges: both not_started members' edge is written and a real re-probe flips both to admit"
  else
    common_test_fail "(b-not-started.1) --write-edges: rc=$rc -- $out"
  fi
  dep_check=$(jq -c '.active_projects[] | select(.project_number==21) | .dependencies' "$scratch/specs/state.json")
  if [ "$dep_check" = "[20]" ]; then
    common_test_pass "(b-not-started.2) --write-edges: the edge was actually written to scratch state.json (task 21 depends on [20])"
  else
    common_test_fail "(b-not-started.2) --write-edges: expected task 21 dependencies [20], got $dep_check"
  fi
  st20=$(jq -r '.active_projects[] | select(.project_number==20) | .status' "$scratch/specs/state.json")
  st21=$(jq -r '.active_projects[] | select(.project_number==21) | .status' "$scratch/specs/state.json")
  if [ "$st20" = "not_started" ] && [ "$st21" = "not_started" ]; then
    common_test_pass "(b-not-started.3) neither member's status moved off 'not_started' after the edge-only write"
  else
    common_test_fail "(b-not-started.3) expected both statuses 'not_started', got 20='$st20' 21='$st21'"
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

# =====================================================================================
# Case (h): Defect 1 acceptance -- a ready pool whose selected candidates are exactly four
# exact-file_scope-colliding pairs. Asserts four ordered-sequence lines AND at least one
# /orchestrate joint-batch line in the same output (never the measured defect's
# 4-sequences/0-joint-batches shape), with the joint line's members all admit, AND that the
# default (non---write-edges) run leaves specs/state.json byte-identical.
# =====================================================================================
{
  scratch="$(build_scratch)"
  for i in 1 2 3 4; do
    lo=$((i * 10)); hi=$((i * 10 + 1))
    add_task "$scratch" "$lo" not_started "[\"agent-system/extensions/core/h-pair${i}\"]" '[]'
    add_task "$scratch" "$hi" not_started "[\"agent-system/extensions/core/h-pair${i}\"]" '[]'
  done
  before_sha="$(sha256sum "$scratch/specs/state.json" | awk '{print $1}')"
  out="$(run_suggest "$scratch" --next-batch --session-id "$SID")"
  rc=$?
  after_sha="$(sha256sum "$scratch/specs/state.json" | awk '{print $1}')"
  seq_count=$(echo "$out" | grep -cE ', then [0-9]+  \(ordered sequence -- file_scope collision\)')
  joint_count=$(echo "$out" | grep -cE '^/orchestrate [0-9]+(,[0-9]+)+$')
  if [ "$rc" -eq 0 ] && [ "$seq_count" -eq 4 ] && [ "$joint_count" -ge 1 ] \
    && ! echo "$out" | grep -qE 'task [0-9]+: defer'; then
    common_test_pass "(h.1) Defect 1: an all-collision-pairs pool renders all 4 ordered sequences AND at least one joint batch line, every rendered member admit"
  else
    common_test_fail "(h.1) Defect 1: rc=$rc seq_count=$seq_count joint_count=$joint_count -- $out"
  fi
  if [ "$before_sha" = "$after_sha" ]; then
    common_test_pass "(h.2) the default (non---write-edges) run leaves scratch state.json byte-identical"
  else
    common_test_fail "(h.2) scratch state.json changed under the default run: before=$before_sha after=$after_sha"
  fi
}

# =====================================================================================
# Case (i): Defect 2 acceptance -- a ready pool shaped so the territory, topic, and width
# criteria each select a different candidate set. Asserts two or more distinct labelled
# options render, each carrying its own admit evidence, and no two options render the
# identical task list.
# =====================================================================================
{
  scratch="$(build_scratch)"
  add_task "$scratch" 60 not_started '["agent-system/extensions/core/i-territory"]' '[]'
  add_task "$scratch" 61 not_started '["agent-system/extensions/core/i-territory"]' '[]'
  add_task_topic "$scratch" 62 not_started '["agent-system/extensions/core/i-topic-62"]' '[]' 'topic-i'
  add_task_topic "$scratch" 63 not_started '["agent-system/extensions/core/i-topic-63"]' '[]' 'topic-i'
  add_task_topic "$scratch" 64 not_started '["agent-system/extensions/core/i-topic-64"]' '[]' 'topic-i'
  add_task "$scratch" 65 not_started '["agent-system/extensions/core/i-width-65"]' '[]'
  out="$(run_suggest "$scratch" --next-batch --session-id "$SID")"
  rc=$?
  option_count=$(echo "$out" | grep -cE '^Option [0-9]+ -- ')
  admit_count=$(echo "$out" | grep -cE 'task [0-9]+: admit')
  dup_joint=false
  joint_lines="$(echo "$out" | grep -E '^/orchestrate [0-9]+(,[0-9]+)*$' | sort -u | wc -l)"
  joint_lines_raw="$(echo "$out" | grep -cE '^/orchestrate [0-9]+(,[0-9]+)*$')"
  [ "$joint_lines" -lt "$joint_lines_raw" ] && dup_joint=true
  if [ "$rc" -eq 0 ] && [ "$option_count" -ge 2 ] && [ "$admit_count" -ge 1 ] && [ "$dup_joint" = false ]; then
    common_test_pass "(i) Defect 2: two or more distinct labelled options render, each with its own admit evidence, no two carrying an identical joint-line task list"
  else
    common_test_fail "(i) Defect 2: rc=$rc option_count=$option_count admit_count=$admit_count dup_joint=$dup_joint -- $out"
  fi
}

# =====================================================================================
# Case (j): Defect 2's budget constraint -- the shared probe-invocation cap, driven to
# exhaustion mid-multi-option-render, produces the existing explicit cap-reached line AND the
# multi-option loop's own "cut short by the cap" line, retaining whatever already rendered.
# =====================================================================================
{
  scratch="$(build_scratch)"
  add_task "$scratch" 70 not_started '["agent-system/extensions/core/j-territory"]' '[]'
  add_task "$scratch" 71 not_started '["agent-system/extensions/core/j-territory"]' '[]'
  add_task_topic "$scratch" 72 not_started '["agent-system/extensions/core/j-topic-72"]' '[]' 'topic-j'
  add_task_topic "$scratch" 73 not_started '["agent-system/extensions/core/j-topic-73"]' '[]' 'topic-j'
  sed -i 's/MAX_PROBE_INVOCATIONS=20/MAX_PROBE_INVOCATIONS=1/' "$scratch/.claude/scripts/orchestrate-suggest-next-batch.sh"
  out="$(run_suggest "$scratch" --next-batch --session-id "$SID")"
  rc=$?
  if [ "$rc" -eq 0 ] && echo "$out" | grep -q 'probe-invocation cap' \
    && echo "$out" | grep -q 'Batch-option search stopped' \
    && echo "$out" | grep -q '70, then 71'; then
    common_test_pass "(j) Defect 2 budget: the shared probe cap, exhausted mid-multi-option-render, is rendered explicitly and retains the option(s) already rendered"
  else
    common_test_fail "(j) Defect 2 budget: rc=$rc -- $out"
  fi
}

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
# task-ref-ok:end
