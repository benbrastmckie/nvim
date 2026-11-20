#!/usr/bin/env bash
# test-orchestrate-conclusion-roadmap.sh - Regression suite for orchestrate-conclusion-roadmap.sh,
# the single executable copy of /orchestrate's conclusion-stage roadmap-update step
# (context/contracts/conclusion-stage.md's Step 5), invoked unconditionally from Move 4's
# finalize sequence.
#
# Structural model: test-orchestrate-batch-gate.sh (set -uo pipefail, common_test_repo_root,
# common_test_resolve_subject/common_test_declare_subject source-store-first resolution,
# mktemp -d scratch root with a scratch specs/state.json and scratch git repo, pass/fail
# counters, exit 0/1/2) and test-roadmap-generation.sh (the classic-layout ROADMAP.md fixture
# shape, isolation discipline).
#
# ISOLATION CONTRACT: every case builds a fresh scratch project root under mktemp -d with its
# own <scratch>/.claude/scripts/{orchestrate-conclusion-roadmap.sh,roadmap-integration.sh,
# generate-task-order.sh,deploy-root-guard.sh,events-append.sh,issue-record.sh,
# git-commit-scoped.sh,lint/lint-roadmap-batch-proposals.sh,lib/{common.sh,task-lookup-lib.sh,
# runtime-file-patterns.sh,roadmap-preflight-lib.sh,status-vocabulary.sh,roadmap-entries-lib.sh,
# file-scope-overlap.sh}} and a real
# <scratch>/.git repo. The suite never reads or writes the real specs/ROADMAP.md,
# specs/events.jsonl, or specs/state.json -- a checksum guard at the end confirms all three are
# byte-identical to how this suite found them.
#
# task-ref-ok:begin inline, category 3: command-usage examples -- fixture project numbers
# (901-910) are synthetic specs/state.json rows, unrelated to this repository's own
# task-management numbering.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (the
# SUT or a hard dependency was not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

DEPLOY_SCRIPTS_SRC="$REPO_ROOT/.claude/scripts"
SOURCE_STORE_SCRIPTS="$REPO_ROOT/agent-system/extensions/core/scripts"

resolve() {
  # resolve <desc> <relative-path-under-scripts/>
  common_test_resolve_subject "$1" "deploy-tree-first" "$DEPLOY_SCRIPTS_SRC/$2" "$SOURCE_STORE_SCRIPTS/$2"
}

SUT="$(resolve "orchestrate-conclusion-roadmap.sh" "orchestrate-conclusion-roadmap.sh")" || exit 2
common_test_declare_subject "$SUT"
GUARD_SRC="$(resolve "deploy-root-guard.sh" "deploy-root-guard.sh")" || exit 2
common_test_declare_subject "$GUARD_SRC"
COMMON_SRC="$(resolve "lib/common.sh" "lib/common.sh")" || exit 2
common_test_declare_subject "$COMMON_SRC"
TASK_LOOKUP_SRC="$(resolve "lib/task-lookup-lib.sh" "lib/task-lookup-lib.sh")" || exit 2
common_test_declare_subject "$TASK_LOOKUP_SRC"
RUNTIME_PATTERNS_SRC="$(resolve "lib/runtime-file-patterns.sh" "lib/runtime-file-patterns.sh")" || exit 2
common_test_declare_subject "$RUNTIME_PATTERNS_SRC"
PREFLIGHT_SRC="$(resolve "lib/roadmap-preflight-lib.sh" "lib/roadmap-preflight-lib.sh")" || exit 2
common_test_declare_subject "$PREFLIGHT_SRC"
STATUSVOC_SRC="$(resolve "lib/status-vocabulary.sh" "lib/status-vocabulary.sh")" || exit 2
common_test_declare_subject "$STATUSVOC_SRC"
ENTRIES_SRC="$(resolve "lib/roadmap-entries-lib.sh" "lib/roadmap-entries-lib.sh")" || exit 2
common_test_declare_subject "$ENTRIES_SRC"
SCOPE_OVERLAP_SRC="$(resolve "lib/file-scope-overlap.sh" "lib/file-scope-overlap.sh")" || exit 2
common_test_declare_subject "$SCOPE_OVERLAP_SRC"
ROADMAP_INTEGRATION_SRC="$(resolve "roadmap-integration.sh" "roadmap-integration.sh")" || exit 2
common_test_declare_subject "$ROADMAP_INTEGRATION_SRC"
GTO_SRC="$(resolve "generate-task-order.sh" "generate-task-order.sh")" || exit 2
common_test_declare_subject "$GTO_SRC"
LINT_SRC="$(resolve "lint/lint-roadmap-batch-proposals.sh" "lint/lint-roadmap-batch-proposals.sh")" || exit 2
common_test_declare_subject "$LINT_SRC"
EVENTS_SRC="$(resolve "events-append.sh" "events-append.sh")" || exit 2
common_test_declare_subject "$EVENTS_SRC"
ISSUE_SRC="$(resolve "issue-record.sh" "issue-record.sh")" || exit 2
common_test_declare_subject "$ISSUE_SRC"
COMMIT_SRC="$(resolve "git-commit-scoped.sh" "git-commit-scoped.sh")" || exit 2
common_test_declare_subject "$COMMIT_SRC"
HANDOFF_SRC="$(resolve "milestone-review-handoff.sh" "milestone-review-handoff.sh")" || exit 2
common_test_declare_subject "$HANDOFF_SRC"
STATEWRITE_SRC="$(resolve "state-write.sh" "state-write.sh")" || exit 2
common_test_declare_subject "$STATEWRITE_SRC"
PNUMINUSE_SRC="$(resolve "lib/project-number-inuse.sh" "lib/project-number-inuse.sh")" || exit 2
common_test_declare_subject "$PNUMINUSE_SRC"
TASKLOCK_SRC="$(resolve "task-lock.sh" "task-lock.sh")" || exit 2
common_test_declare_subject "$TASKLOCK_SRC"

PASSED=0
FAILED=0

TOP_WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

REAL_ROADMAP="$REPO_ROOT/specs/ROADMAP.md"
REAL_EVENTS="$REPO_ROOT/specs/events.jsonl"
REAL_STATE="$REPO_ROOT/specs/state.json"
REAL_ROADMAP_SUM_BEFORE=""
REAL_EVENTS_SUM_BEFORE=""
REAL_STATE_SUM_BEFORE=""
[ -f "$REAL_ROADMAP" ] && REAL_ROADMAP_SUM_BEFORE="$(sha256sum "$REAL_ROADMAP" | awk '{print $1}')"
[ -f "$REAL_EVENTS" ] && REAL_EVENTS_SUM_BEFORE="$(sha256sum "$REAL_EVENTS" | awk '{print $1}')"
[ -f "$REAL_STATE" ] && REAL_STATE_SUM_BEFORE="$(sha256sum "$REAL_STATE" | awk '{print $1}')"

# ─── Harness helpers ────────────────────────────────────────────────────────────────────────

# build_sandbox -- builds an isolated <scratch>/.claude/scripts/{...} deploy-shaped tree plus a
# real git repo at <scratch>/.git. Echoes the scratch root.
build_sandbox() {
  local scratch
  scratch="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$scratch/.claude/scripts/lib" "$scratch/.claude/scripts/lint" "$scratch/specs"
  cp "$SUT" "$scratch/.claude/scripts/orchestrate-conclusion-roadmap.sh"
  cp "$GUARD_SRC" "$scratch/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_SRC" "$scratch/.claude/scripts/lib/common.sh"
  cp "$TASK_LOOKUP_SRC" "$scratch/.claude/scripts/lib/task-lookup-lib.sh"
  cp "$RUNTIME_PATTERNS_SRC" "$scratch/.claude/scripts/lib/runtime-file-patterns.sh"
  cp "$PREFLIGHT_SRC" "$scratch/.claude/scripts/lib/roadmap-preflight-lib.sh"
  cp "$STATUSVOC_SRC" "$scratch/.claude/scripts/lib/status-vocabulary.sh"
  cp "$ENTRIES_SRC" "$scratch/.claude/scripts/lib/roadmap-entries-lib.sh"
  cp "$SCOPE_OVERLAP_SRC" "$scratch/.claude/scripts/lib/file-scope-overlap.sh"
  cp "$ROADMAP_INTEGRATION_SRC" "$scratch/.claude/scripts/roadmap-integration.sh"
  cp "$GTO_SRC" "$scratch/.claude/scripts/generate-task-order.sh"
  cp "$LINT_SRC" "$scratch/.claude/scripts/lint/lint-roadmap-batch-proposals.sh"
  cp "$EVENTS_SRC" "$scratch/.claude/scripts/events-append.sh"
  cp "$ISSUE_SRC" "$scratch/.claude/scripts/issue-record.sh"
  cp "$COMMIT_SRC" "$scratch/.claude/scripts/git-commit-scoped.sh"
  cp "$HANDOFF_SRC" "$scratch/.claude/scripts/milestone-review-handoff.sh"
  cp "$STATEWRITE_SRC" "$scratch/.claude/scripts/state-write.sh"
  cp "$PNUMINUSE_SRC" "$scratch/.claude/scripts/lib/project-number-inuse.sh"
  cp "$TASKLOCK_SRC" "$scratch/.claude/scripts/task-lock.sh"
  chmod +x "$scratch"/.claude/scripts/*.sh "$scratch"/.claude/scripts/lint/*.sh
  git -C "$scratch" init -q
  git -C "$scratch" config user.email "test@example.com"
  git -C "$scratch" config user.name "Test Suite"
  echo "$scratch"
}

# write_state <scratch> <project_number> -- a single-project, no-dependency, "not_started"
# (ready) state.json fixture.
write_state() {
  local scratch="$1" pnum="$2"
  cat > "$scratch/specs/state.json" <<EOF
{
  "active_topics": ["alpha"],
  "active_projects": [
    {"project_number": ${pnum}, "status": "not_started", "title": "Fixture item ${pnum} description", "topic": "alpha", "dependencies": [], "project_name": "item_${pnum}"}
  ]
}
EOF
}

# write_generated_roadmap_stale <scratch> -- a generated ROADMAP.md holding only the sentinel
# line, so --regenerate always changes content (adds the fixture item) -- used to force an
# "OUTCOME: ... rewrote" result.
write_generated_roadmap_stale() {
  local scratch="$1"
  printf '%s\n' '<!-- generated by roadmap-integration.sh from specs/state.json; do not edit -->' \
    > "$scratch/specs/ROADMAP.md"
}

# write_classic_roadmap <scratch> -- a hand-authored classic 8-header ROADMAP.md, which the
# conclusion step must leave untouched.
write_classic_roadmap() {
  local scratch="$1"
  cat > "$scratch/specs/ROADMAP.md" <<'EOF'
# Roadmap

*Fixture preamble for test-orchestrate-conclusion-roadmap.sh.*

## Goal

Fixture goal text, authored.

## Gate state

Fixture gate-state text, authored.

## Next

(rendered by --regenerate)

## Open work

(rendered by --regenerate)

## Checks before and after every call

Fixture checks text, authored.

## Settled decisions (do not re-litigate)

Fixture decisions text, authored.

## Standing rules

Fixture rules text, authored.

## Unfiled observations (none worth a task yet)

(none worth a task yet)
EOF
}

# mt_state_write <path> <task_numbers_json_array> [<failed_tasks_json_array>] -- the multi-task
# batch state file orchestrate-conclusion-roadmap.sh reads via --state-file.
mt_state_write() {
  local path="$1" task_numbers="$2" failed="${3:-[]}"
  jq -n --argjson tn "$task_numbers" --argjson ft "$failed" \
    '{session_id: "sess_test", task_numbers: $tn, failed_tasks: $ft}' > "$path"
}

# run_sut <scratch> [args...] -- invokes the SUT with CWD set to the scratch root (git-commit-
# scoped.sh's own git operations resolve relative to CWD, matching the house convention already
# established by test-orchestrate-conclusion-aggregate.sh's commit-scope case).
run_sut() {
  local scratch="$1"; shift
  local stdout_file stderr_file
  stdout_file="$(mktemp)"; stderr_file="$(mktemp)"
  (cd "$scratch" && bash "$scratch/.claude/scripts/orchestrate-conclusion-roadmap.sh" "$@") >"$stdout_file" 2>"$stderr_file"
  LAST_EXIT=$?
  LAST_STDOUT="$(cat "$stdout_file")"
  LAST_STDERR="$(cat "$stderr_file")"
  rm -f "$stdout_file" "$stderr_file"
}

MT_STATE="$TOP_WORKDIR/mt-state.json"

# =====================================================================================
# Case A: all_terminal, generated roadmap -- the regenerate fires, the scoped commit lands on
# specs/ROADMAP.md alone, and stderr carries OUTCOME: --regenerate rewrote.
# =====================================================================================
common_test_info "Case A: all_terminal, generated roadmap"
SCRATCH_A="$(build_sandbox)"
write_state "$SCRATCH_A" 901
write_generated_roadmap_stale "$SCRATCH_A"
git -C "$SCRATCH_A" add specs/ROADMAP.md
git -C "$SCRATCH_A" commit -q -m "seed"
mt_state_write "$MT_STATE" '[901]'
run_sut "$SCRATCH_A" --session sess_caseA --state-file "$MT_STATE"

if [ "$LAST_EXIT" -eq 0 ]; then
  common_test_pass "Case A: exits 0"
else
  common_test_fail "Case A: expected exit 0, got exit=$LAST_EXIT stderr=$LAST_STDERR"
fi
if echo "$LAST_STDOUT" | grep -q "^OUTCOME: --regenerate rewrote"; then
  common_test_pass "Case A: stdout carries OUTCOME: --regenerate rewrote"
else
  common_test_fail "Case A: expected an OUTCOME: --regenerate rewrote line, got stdout=$LAST_STDOUT"
fi
caseA_commit_files="$(git -C "$SCRATCH_A" show --name-only --format= HEAD 2>/dev/null)"
if [ "$caseA_commit_files" = "specs/ROADMAP.md" ]; then
  common_test_pass "Case A: the scoped commit lands on specs/ROADMAP.md alone"
else
  common_test_fail "Case A: expected the HEAD commit to touch only specs/ROADMAP.md, got: $caseA_commit_files"
fi
if echo "$LAST_STDOUT" | grep -q "^Scan complete\. shape=.* findings="; then
  common_test_pass "Case A: the advisory lint ran to completion and its scan line is in the outcome block"
else
  common_test_fail "Case A: expected the lint's 'Scan complete.' line in the outcome block, got stdout=$LAST_STDOUT"
fi
if grep -q "item_901\|Fixture item 901" "$SCRATCH_A/specs/ROADMAP.md"; then
  common_test_pass "Case A: the regenerated file actually contains the fixture item"
else
  common_test_fail "Case A: expected the fixture item in the regenerated ROADMAP.md"
fi

# =====================================================================================
# Case B: a partial-exit-shaped state file (non-empty failed_tasks) produces an identical
# outcome, proving the script carries no exit_status branch at all -- it never reads
# failed_tasks. Paired with a grep-level structural assertion over the deployed SKILL.md.
# =====================================================================================
common_test_info "Case B: partial-exit-shaped state file produces an identical outcome"
SCRATCH_B="$(build_sandbox)"
write_state "$SCRATCH_B" 902
write_generated_roadmap_stale "$SCRATCH_B"
git -C "$SCRATCH_B" add specs/ROADMAP.md
git -C "$SCRATCH_B" commit -q -m "seed"
mt_state_write "$MT_STATE" '[902]' '[902]'
run_sut "$SCRATCH_B" --session sess_caseB --state-file "$MT_STATE"

if [ "$LAST_EXIT" -eq 0 ] && echo "$LAST_STDOUT" | grep -q "^OUTCOME: --regenerate rewrote"; then
  common_test_pass "Case B: a non-empty failed_tasks state file still fires the regenerate (no exit_status branch)"
else
  common_test_fail "Case B: expected an identical rewrote outcome regardless of failed_tasks, got exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

DEPLOYED_SKILL_MD="$DEPLOY_SCRIPTS_SRC/../skills/skill-orchestrate/SKILL.md"
if [ -f "$DEPLOYED_SKILL_MD" ]; then
  move4_body="$(awk '/^### Move 4: Branch/,/^### Move 5: Conclusion/' "$DEPLOYED_SKILL_MD")"
  if echo "$move4_body" | grep -q "orchestrate-conclusion-roadmap.sh --session" \
    && ! echo "$move4_body" | grep -B3 "orchestrate-conclusion-roadmap.sh --session" | grep -qE '^\s*if '; then
    common_test_pass "Case B: the deployed SKILL.md's Move 4 invocation sits unconditionally (no guarding 'if' immediately above it)"
  else
    common_test_fail "Case B: expected an unconditional invocation line inside Move 4 of the deployed SKILL.md"
  fi
else
  common_test_info "Case B: deployed SKILL.md not found -- skipping the structural grep assertion (environment limitation, not a case failure)"
fi

# =====================================================================================
# Case C: absent/unknown -- --regenerate is never invoked (no OUTCOME: line at all),
# specs/ROADMAP.md stays absent, and all three degrade surfaces fire: the named warning, the
# roadmap_regenerate_blocked row in events.jsonl plus its own scoped commit, and at least one
# issues.jsonl row per scratch task dir.
# =====================================================================================
common_test_info "Case C: absent ROADMAP.md triggers the loud three-part degrade"
SCRATCH_C="$(build_sandbox)"
write_state "$SCRATCH_C" 903
mkdir -p "$SCRATCH_C/specs/903_item_903"
git -C "$SCRATCH_C" add specs/state.json 2>/dev/null || true
git -C "$SCRATCH_C" commit -q -m "seed" --allow-empty
mt_state_write "$MT_STATE" '[903]'
run_sut "$SCRATCH_C" --session sess_caseC --state-file "$MT_STATE"

if [ "$LAST_EXIT" -eq 0 ]; then
  common_test_pass "Case C: exits 0"
else
  common_test_fail "Case C: expected exit 0, got exit=$LAST_EXIT stderr=$LAST_STDERR"
fi
if echo "$LAST_STDOUT" | grep -q "^OUTCOME:"; then
  common_test_fail "Case C: expected NO OUTCOME: line at all (regenerate never invoked), got stdout=$LAST_STDOUT"
else
  common_test_pass "Case C: no OUTCOME: line is printed (regenerate was never invoked)"
fi
if echo "$LAST_STDOUT" | grep -q "^Scan complete\. shape=.* findings="; then
  common_test_pass "Case C: the advisory lint runs on the degrade arm too (it reads state, never the file)"
else
  common_test_fail "Case C: expected the lint's 'Scan complete.' line on the degrade arm, got stdout=$LAST_STDOUT"
fi
if [ ! -f "$SCRATCH_C/specs/ROADMAP.md" ]; then
  common_test_pass "Case C: specs/ROADMAP.md stays absent (never scaffolded)"
else
  common_test_fail "Case C: specs/ROADMAP.md was unexpectedly created"
fi
if echo "$LAST_STDERR" | grep -qi "roadmap regenerate blocked" || echo "$LAST_STDOUT" | grep -qi "roadmap regenerate blocked"; then
  common_test_pass "Case C: a named structured warning is surfaced"
else
  common_test_fail "Case C: expected a named 'roadmap regenerate blocked' warning, got stderr=$LAST_STDERR stdout=$LAST_STDOUT"
fi
if [ -f "$SCRATCH_C/specs/events.jsonl" ] && grep -q "roadmap_regenerate_blocked" "$SCRATCH_C/specs/events.jsonl"; then
  common_test_pass "Case C: a roadmap_regenerate_blocked row lands in the scratch events.jsonl"
else
  common_test_fail "Case C: expected a roadmap_regenerate_blocked row in events.jsonl"
fi
caseC_events_commit="$(git -C "$SCRATCH_C" log --oneline -- specs/events.jsonl 2>/dev/null | wc -l | tr -d ' ')"
if [ "$caseC_events_commit" -ge 1 ]; then
  common_test_pass "Case C: the degrade's events.jsonl write is itself scoped-committed"
else
  common_test_fail "Case C: expected at least one commit touching specs/events.jsonl"
fi
if [ -f "$SCRATCH_C/specs/903_item_903/issues.jsonl" ] && [ -s "$SCRATCH_C/specs/903_item_903/issues.jsonl" ]; then
  common_test_pass "Case C: at least one issues.jsonl row lands in the scratch task directory"
else
  common_test_fail "Case C: expected a non-empty issues.jsonl in the scratch task directory"
fi

# =====================================================================================
# Case D: idempotence -- two back-to-back runs with no intervening state change; the second
# emits OUTCOME: --regenerate left ... unchanged and creates no second commit.
# =====================================================================================
common_test_info "Case D: a second run with no intervening change is a no-op"
SCRATCH_D="$(build_sandbox)"
write_state "$SCRATCH_D" 904
write_generated_roadmap_stale "$SCRATCH_D"
git -C "$SCRATCH_D" add specs/ROADMAP.md
git -C "$SCRATCH_D" commit -q -m "seed"
mt_state_write "$MT_STATE" '[904]'
run_sut "$SCRATCH_D" --session sess_caseD_1 --state-file "$MT_STATE"
first_run_commit_count="$(git -C "$SCRATCH_D" log --oneline | wc -l | tr -d ' ')"

run_sut "$SCRATCH_D" --session sess_caseD_2 --state-file "$MT_STATE"
second_run_commit_count="$(git -C "$SCRATCH_D" log --oneline | wc -l | tr -d ' ')"

if echo "$LAST_STDOUT" | grep -q "^OUTCOME: --regenerate left .* unchanged"; then
  common_test_pass "Case D: the second run emits OUTCOME: --regenerate left ... unchanged"
else
  common_test_fail "Case D: expected an 'unchanged' OUTCOME on the second run, got stdout=$LAST_STDOUT"
fi
if [ "$second_run_commit_count" = "$first_run_commit_count" ]; then
  common_test_pass "Case D: the second run creates no second commit ($first_run_commit_count -> $second_run_commit_count)"
else
  common_test_fail "Case D: expected no new commit on the second run, got $first_run_commit_count -> $second_run_commit_count"
fi

# =====================================================================================
# Case E: the pending marker -- written on a real run, carrying cc_session_id and
# continuation_count: 0; never written under --dry-run.
# =====================================================================================
common_test_info "Case E: the pending marker is written on a real run, never under --dry-run"
SCRATCH_E="$(build_sandbox)"
write_state "$SCRATCH_E" 905
write_generated_roadmap_stale "$SCRATCH_E"
git -C "$SCRATCH_E" add specs/ROADMAP.md
git -C "$SCRATCH_E" commit -q -m "seed"
mt_state_write "$MT_STATE" '[905]'
CLAUDE_CODE_SESSION_ID="cc-test-xyz" run_sut "$SCRATCH_E" --session sess_caseE --state-file "$MT_STATE"
MARKER_E="$SCRATCH_E/specs/.orchestration/.conclusion-pending-sess_caseE.json"

if [ -f "$MARKER_E" ]; then
  common_test_pass "Case E: the pending marker is written on a real run"
else
  common_test_fail "Case E: expected the pending marker at $MARKER_E"
fi
if [ -f "$MARKER_E" ] && [ "$(jq -r '.cc_session_id' "$MARKER_E" 2>/dev/null)" = "cc-test-xyz" ] \
  && [ "$(jq -r '.continuation_count' "$MARKER_E" 2>/dev/null)" = "0" ]; then
  common_test_pass "Case E: the marker carries cc_session_id and continuation_count: 0"
else
  common_test_fail "Case E: expected cc_session_id=cc-test-xyz and continuation_count=0, got: $(cat "$MARKER_E" 2>/dev/null)"
fi

SCRATCH_E2="$(build_sandbox)"
write_state "$SCRATCH_E2" 906
write_generated_roadmap_stale "$SCRATCH_E2"
git -C "$SCRATCH_E2" add specs/ROADMAP.md
git -C "$SCRATCH_E2" commit -q -m "seed"
mt_state_write "$MT_STATE" '[906]'
run_sut "$SCRATCH_E2" --session sess_caseE2 --state-file "$MT_STATE" --dry-run
MARKER_E2="$SCRATCH_E2/specs/.orchestration/.conclusion-pending-sess_caseE2.json"
if [ ! -f "$MARKER_E2" ]; then
  common_test_pass "Case E: --dry-run never writes the pending marker"
else
  common_test_fail "Case E: --dry-run unexpectedly wrote the pending marker at $MARKER_E2"
fi

# =====================================================================================
# Case F: a hand-authored classic file is refused -- --regenerate is never invoked, the file is
# byte-identical afterwards, and the degrade summary names the migration.
# =====================================================================================
common_test_info "Case F: a hand-authored classic ROADMAP.md degrades and names the migration"
SCRATCH_F="$(build_sandbox)"
write_state "$SCRATCH_F" 907
write_classic_roadmap "$SCRATCH_F"
cp "$SCRATCH_F/specs/ROADMAP.md" "$SCRATCH_F/roadmap-before.md"
git -C "$SCRATCH_F" add specs/ROADMAP.md
git -C "$SCRATCH_F" commit -q -m "seed"
mt_state_write "$MT_STATE" '[907]'
run_sut "$SCRATCH_F" --session sess_caseF --state-file "$MT_STATE"

if [ "$LAST_EXIT" -eq 0 ] && echo "$LAST_STDOUT" | grep -q "^verdict: classic$" \
  && ! echo "$LAST_STDOUT" | grep -q "^OUTCOME:"; then
  common_test_pass "Case F: exits 0 with verdict classic and no OUTCOME: line (regenerate never invoked)"
else
  common_test_fail "Case F: expected exit 0, verdict classic and no OUTCOME: line, got exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi
if cmp -s "$SCRATCH_F/roadmap-before.md" "$SCRATCH_F/specs/ROADMAP.md"; then
  common_test_pass "Case F: the hand-authored file is byte-identical afterwards"
else
  common_test_fail "Case F: the hand-authored ROADMAP.md was modified"
fi
if echo "$LAST_STDOUT" | grep -q "^regenerate: skipped .*migrate-roadmap-to-milestones.sh"; then
  common_test_pass "Case F: the degrade summary names migrate-roadmap-to-milestones.sh"
else
  common_test_fail "Case F: expected the degrade summary to name the migration, got stdout=$LAST_STDOUT"
fi
if [ -f "$SCRATCH_F/specs/events.jsonl" ] && grep -q "roadmap_regenerate_blocked" "$SCRATCH_F/specs/events.jsonl"; then
  common_test_pass "Case F: a roadmap_regenerate_blocked row lands in the scratch events.jsonl"
else
  common_test_fail "Case F: expected a roadmap_regenerate_blocked row in events.jsonl"
fi

# =====================================================================================
# Case G: the store's own output path is the one regenerated and committed.
# =====================================================================================
common_test_info "Case G: roadmap_context.output_path is classified, regenerated and committed"
SCRATCH_G="$(build_sandbox)"
write_state "$SCRATCH_G" 908
jq '.roadmap_context = {output_path: "docs/ROADMAP.md"}' "$SCRATCH_G/specs/state.json" > "$SCRATCH_G/specs/state.json.new" \
  && mv "$SCRATCH_G/specs/state.json.new" "$SCRATCH_G/specs/state.json"
mkdir -p "$SCRATCH_G/docs"
printf '%s\n' '<!-- generated by roadmap-integration.sh from specs/state.json; do not edit -->' > "$SCRATCH_G/docs/ROADMAP.md"
git -C "$SCRATCH_G" add docs/ROADMAP.md
git -C "$SCRATCH_G" commit -q -m "seed"
mt_state_write "$MT_STATE" '[908]'
run_sut "$SCRATCH_G" --session sess_caseG --state-file "$MT_STATE"
caseG_commit_files="$(git -C "$SCRATCH_G" show --name-only --format= HEAD 2>/dev/null)"
if [ "$LAST_EXIT" -eq 0 ] && echo "$LAST_STDOUT" | grep -q "^OUTCOME: --regenerate rewrote" \
  && [ "$caseG_commit_files" = "docs/ROADMAP.md" ] && [ ! -e "$SCRATCH_G/specs/ROADMAP.md" ]; then
  common_test_pass "Case G: the resolved output path is regenerated and is the only path committed"
else
  common_test_fail "Case G: expected docs/ROADMAP.md regenerated and committed alone, got exit=$LAST_EXIT files=$caseG_commit_files stdout=$LAST_STDOUT"
fi

# =====================================================================================
# Case H: milestone handoff wiring -- a fully-done milestone with a matching milestone ref
# produces review.state="prepared", a specs/milestones/<id>-review-handoff.md file, and the
# literal /please + /merge commands on stderr -- fired from THIS SUT's own non-fatal call site,
# not a direct call to milestone-review-handoff.sh.
# =====================================================================================
common_test_info "Case H: milestone handoff fires from orchestrate-conclusion-roadmap.sh after a successful regenerate"
SCRATCH_H="$(build_sandbox)"
write_state "$SCRATCH_H" 909
jq '.active_projects[0].status = "completed" | .roadmap_milestones = [{"id": "M1", "title": "Fixture milestone", "progress": {"status": "active"}, "review": {"state": "none"}, "batches": [{"task_ids": [909], "description": "fixture batch"}]}]' \
  "$SCRATCH_H/specs/state.json" > "$SCRATCH_H/specs/state.json.new" \
  && mv "$SCRATCH_H/specs/state.json.new" "$SCRATCH_H/specs/state.json"
write_generated_roadmap_stale "$SCRATCH_H"
git -C "$SCRATCH_H" add specs/ROADMAP.md specs/state.json
git -C "$SCRATCH_H" commit -q -m "seed"
caseH_seed_tree="$(git -C "$SCRATCH_H" rev-parse HEAD^'{tree}')"
caseH_seed_sha="$(git -C "$SCRATCH_H" rev-parse HEAD)"
caseH_land_sha="$(git -C "$SCRATCH_H" commit-tree "$caseH_seed_tree" -p "$caseH_seed_sha" -m "task 909: fixture task")"
git -C "$SCRATCH_H" update-ref refs/heads/milestone/M1 "$caseH_land_sha" ""
mt_state_write "$MT_STATE" '[909]'
run_sut "$SCRATCH_H" --session sess_caseH --state-file "$MT_STATE"

if [ "$LAST_EXIT" -eq 0 ]; then
  common_test_pass "Case H: SUT still exits 0 with the handoff wired in"
else
  common_test_fail "Case H: expected exit 0, got exit=$LAST_EXIT stderr=$LAST_STDERR"
fi
if grep -q "MILESTONE REVIEW READY: milestone M1" <<< "$LAST_STDERR"; then
  common_test_pass "Case H: a named MILESTONE REVIEW READY notice names milestone M1"
else
  common_test_fail "Case H: expected a MILESTONE REVIEW READY notice. stderr=$LAST_STDERR"
fi
if grep -q "/please push refs/heads/milestone/M1" <<< "$LAST_STDERR" && grep -q "^  /merge" <<< "$LAST_STDERR"; then
  common_test_pass "Case H: the literal /please + /merge commands are printed"
else
  common_test_fail "Case H: expected literal /please and /merge lines. stderr=$LAST_STDERR"
fi
if [ -f "$SCRATCH_H/specs/milestones/M1-review-handoff.md" ] && grep -q "task 909: fixture task" "$SCRATCH_H/specs/milestones/M1-review-handoff.md"; then
  common_test_pass "Case H: specs/milestones/M1-review-handoff.md is written and names the landed commit's subject"
else
  common_test_fail "Case H: expected specs/milestones/M1-review-handoff.md naming the landed commit"
fi
if jq -e '.roadmap_milestones[0].review.state == "prepared" and .roadmap_milestones[0].review.ref == "refs/heads/milestone/M1"' "$SCRATCH_H/specs/state.json" >/dev/null 2>&1; then
  common_test_pass "Case H: state.json's review.state is 'prepared' with review.ref set"
else
  common_test_fail "Case H: expected review.state=prepared and review.ref set in state.json: $(cat "$SCRATCH_H/specs/state.json")"
fi
if grep -nE 'git[[:space:]]+push|git-push-granted\.sh|\bgh[[:space:]]+pr\b|\bglab[[:space:]]+mr\b' "$HANDOFF_SRC" | grep -v '^[0-9]*:#' | grep -v "NEVER CALLS" >/dev/null 2>&1; then
  common_test_fail "Case H: milestone-review-handoff.sh contains a forbidden push/PR invocation"
else
  common_test_pass "Case H: milestone-review-handoff.sh contains no git push/git-push-granted.sh/gh pr/glab mr invocation"
fi

# =====================================================================================
# Case I: a handoff failure is non-fatal -- the roadmap regenerate and its commit still
# succeed, and the SUT still exits 0, even when milestone-review-handoff.sh itself crashes.
# =====================================================================================
common_test_info "Case I: milestone-review-handoff.sh failure does not fail the roadmap conclusion stage"
SCRATCH_I="$(build_sandbox)"
write_state "$SCRATCH_I" 910
write_generated_roadmap_stale "$SCRATCH_I"
git -C "$SCRATCH_I" add specs/ROADMAP.md
git -C "$SCRATCH_I" commit -q -m "seed"
# Simulate a crashing handoff script -- any failure mode must leave the roadmap stage unaffected.
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$SCRATCH_I/.claude/scripts/milestone-review-handoff.sh"
chmod +x "$SCRATCH_I/.claude/scripts/milestone-review-handoff.sh"
mt_state_write "$MT_STATE" '[910]'
run_sut "$SCRATCH_I" --session sess_caseI --state-file "$MT_STATE"

if [ "$LAST_EXIT" -eq 0 ]; then
  common_test_pass "Case I: SUT still exits 0 when the handoff script crashes"
else
  common_test_fail "Case I: expected exit 0 despite the crashing handoff, got exit=$LAST_EXIT stderr=$LAST_STDERR"
fi
if echo "$LAST_STDOUT" | grep -q "^OUTCOME: --regenerate rewrote"; then
  common_test_pass "Case I: the roadmap regenerate still ran and rewrote the file"
else
  common_test_fail "Case I: expected the regenerate to still succeed, got stdout=$LAST_STDOUT"
fi
caseI_commit_files="$(git -C "$SCRATCH_I" show --name-only --format= HEAD 2>/dev/null)"
if [ "$caseI_commit_files" = "specs/ROADMAP.md" ]; then
  common_test_pass "Case I: the roadmap regenerate commit still landed, unaffected by the handoff crash"
else
  common_test_fail "Case I: expected the roadmap commit to still land, got: $caseI_commit_files"
fi

# ─── Live-tree isolation guard ───────────────────────────────────────────────────────────────
REAL_ROADMAP_SUM_AFTER=""
REAL_EVENTS_SUM_AFTER=""
REAL_STATE_SUM_AFTER=""
[ -f "$REAL_ROADMAP" ] && REAL_ROADMAP_SUM_AFTER="$(sha256sum "$REAL_ROADMAP" | awk '{print $1}')"
[ -f "$REAL_EVENTS" ] && REAL_EVENTS_SUM_AFTER="$(sha256sum "$REAL_EVENTS" | awk '{print $1}')"
[ -f "$REAL_STATE" ] && REAL_STATE_SUM_AFTER="$(sha256sum "$REAL_STATE" | awk '{print $1}')"
if [ "$REAL_ROADMAP_SUM_BEFORE" = "$REAL_ROADMAP_SUM_AFTER" ] \
  && [ "$REAL_EVENTS_SUM_BEFORE" = "$REAL_EVENTS_SUM_AFTER" ] \
  && [ "$REAL_STATE_SUM_BEFORE" = "$REAL_STATE_SUM_AFTER" ]; then
  common_test_pass "Isolation: the real specs/ROADMAP.md, specs/events.jsonl, and specs/state.json are untouched"
else
  common_test_fail "Isolation: a real specs/ file changed during this suite's run"
fi

echo ""
echo "========================================"
echo "test-orchestrate-conclusion-roadmap.sh Summary"
echo "========================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
# task-ref-ok:end
