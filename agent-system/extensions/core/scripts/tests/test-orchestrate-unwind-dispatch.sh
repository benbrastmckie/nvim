#!/usr/bin/env bash
# test-orchestrate-unwind-dispatch.sh - Fixture suite for orchestrate-unwind-dispatch.sh, the
# by-hand recovery script that reverses orchestrate-cycle-plan.sh's LIVE Move 1 mutations for a
# task whose prepared dispatch was never issued (no agent call, no postflight).
#
# Structural model: an INTEGRATION suite, not a mock-collaborator unit suite -- each case builds
# a real scratch git repo (test-git-commit-scoped.sh's shape), runs the REAL
# orchestrate-cycle-plan.sh end-to-end to actually PREPARE a live dispatch (proving Phase 1's
# pending_dispatch prior_* pre-image is genuinely populated, not merely hand-constructed), then
# runs the REAL orchestrate-unwind-dispatch.sh against that exact on-disk state. Every
# collaborator (classify/admit/build-dispatch/update-task-status/state-write/generate-todo/
# git-commit-scoped/task-lock) is the genuine, unmodified script.
#
# Follows context/standards/shell-script-testing.md: set -uo pipefail (Class B: PASSED/FAILED
# counters, must keep going past a single case's failure to report the full count), mktemp -d
# workdir with a trap EXIT cleanup, loud-skip discipline on a missing required script.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (a
# required collaborator script was not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

REQUIRED_CORE_SCRIPTS=(
  orchestrate-cycle-plan.sh orchestrate-batch-admit.sh orchestrate-triage-classify.sh
  task-lock.sh orchestrate-loop-guard-init.sh orchestrate-build-aux-dispatch.sh
  deploy-root-guard.sh command-route-agent.sh skill-base.sh orchestrate-build-dispatch.sh
  update-task-status.sh state-write.sh generate-todo.sh generate-task-order.sh
  git-commit-scoped.sh orchestrate-unwind-dispatch.sh
)
REQUIRED_LIB_SCRIPTS=(
  common.sh file-scope-overlap.sh continuation-pointer-lib.sh manifest-routing-lib.sh
  phase-heading-patterns.sh deploy-baseline-lib.sh task-lookup-lib.sh status-vocabulary.sh
  deploy-ledger-lib.sh runtime-file-patterns.sh territory-contention-lib.sh
)

missing=()
for f in "${REQUIRED_CORE_SCRIPTS[@]}"; do
  [ -f "$CORE_DIR/$f" ] || missing+=("$f")
done
for f in "${REQUIRED_LIB_SCRIPTS[@]}"; do
  [ -f "$CORE_DIR/lib/$f" ] || missing+=("lib/$f")
done
[ -f "$CORE_DIR/../context/reference/orchestrator-critical-paths.json" ] || missing+=("../context/reference/orchestrator-critical-paths.json")
if [ "${#missing[@]}" -gt 0 ]; then
  echo "ERROR: test-orchestrate-unwind-dispatch.sh cannot run -- missing required file(s) under $CORE_DIR: ${missing[*]}" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 2
fi
if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is required and is not on PATH" >&2
  exit 2
fi

TOP_WORKDIR="$(mktemp -d)"
# cleanup() is invoked indirectly via `trap cleanup EXIT` below.
# shellcheck disable=SC2329
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

GITIGNORE_BLOCK='**/.lock/
**/.orchestrator-loop-guard
**/.continuation-loop-guard
**/.orchestrator-churn-state.json
**/.postflight-loop-guard
**/.orchestrator-multi-state*.json
**/.drift-inspection.json
**/.return-meta-*.json
**/.events.lock
**/.sessions/
**/.freshness-warn-streak.json
**/.dispatch/
**/.deploy-lock/
**/.scope-lock/
**/.commit-lock/
**/.errors.lock
**/.orchestration/'

# --- build_repo -- a scratch git repo with every real collaborator deployed. Echoes its path. ---
build_repo() {
  local repo
  repo="$(mktemp -d -p "$TOP_WORKDIR")"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Test Suite"
  mkdir -p "$repo/.claude/scripts/lib" "$repo/.claude/context/reference" "$repo/specs" "$repo/specs/.orchestration"
  local f
  for f in "${REQUIRED_CORE_SCRIPTS[@]}"; do
    cp "$CORE_DIR/$f" "$repo/.claude/scripts/$f"
  done
  for f in "${REQUIRED_LIB_SCRIPTS[@]}"; do
    cp "$CORE_DIR/lib/$f" "$repo/.claude/scripts/lib/$f"
  done
  cp "$CORE_DIR/../context/reference/orchestrator-critical-paths.json" \
     "$repo/.claude/context/reference/orchestrator-critical-paths.json"
  chmod +x "$repo"/.claude/scripts/*.sh
  printf '%s\n' "$GITIGNORE_BLOCK" > "$repo/specs/.gitignore"
  git -C "$repo" add specs/.gitignore
  git -C "$repo" commit -q -m "initial (empty repo)"
  echo "$repo"
}

# --- prepare_dispatch <repo> <project_number> <slug> <session> -- writes a RESEARCHED task,
# commits it as the pre-dispatch snapshot, then runs the REAL orchestrate-cycle-plan.sh to
# prepare a live plan dispatch. Echoes nothing; sets globals PD_TASK_DIR, PD_GUARD_FILE,
# PD_DISPATCH_FILE, PD_SNAPSHOT (sorted-keys JSON of the pre-dispatch state.json entry). ---
prepare_dispatch() {
  local repo="$1" num="$2" slug="$3" session="$4"
  local padded task_dir
  padded=$(printf "%03d" "$num")
  task_dir="specs/${padded}_${slug}"

  cat > "$repo/specs/state.json" <<EOF
{
  "active_projects": [
    {"project_number": $num, "project_name": "$slug", "task_type": "general", "status": "researched", "description": "unwind fixture task", "dependencies": [], "file_scope": [], "last_updated": "2020-01-01T00:00:00Z", "session_id": "sess_before_${num}"}
  ]
}
EOF
  mkdir -p "$repo/${task_dir}/reports"
  echo "# fixture report" > "$repo/${task_dir}/reports/01_report.md"
  git -C "$repo" add specs/state.json "${task_dir}"
  git -C "$repo" commit -q -m "task ${num}: complete research (pre-dispatch snapshot)"

  PD_SNAPSHOT="$(jq -S -c --argjson n "$num" '.active_projects[] | select(.project_number == $n)' "$repo/specs/state.json")"

  ( cd "$repo" && bash .claude/scripts/orchestrate-cycle-plan.sh --session "$session" --state-file specs/state.json "$num" ) \
    >"$TOP_WORKDIR/.cp_out" 2>"$TOP_WORKDIR/.cp_err"
  PD_CP_EXIT=$?
  PD_CP_STDOUT="$(cat "$TOP_WORKDIR/.cp_out")"
  PD_CP_STDERR="$(cat "$TOP_WORKDIR/.cp_err")"

  PD_TASK_DIR="$repo/${task_dir}"
  PD_GUARD_FILE="${PD_TASK_DIR}/.orchestrator-loop-guard"
  PD_DISPATCH_FILE="$(jq -r '.pending_dispatch.dispatch_file // ""' "$PD_GUARD_FILE" 2>/dev/null)"
}

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case 1: happy path -- live plan dispatch, then --commit unwind, exact restoration + clean tree
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Case 1: happy path (live dispatch -> unwind --commit -> exact restoration, clean tree)"

repo1="$(build_repo)"
prepare_dispatch "$repo1" 501 "unwind_case1" "case1_sess"

if [ "$PD_CP_EXIT" -eq 0 ] && [ -n "$PD_DISPATCH_FILE" ] && [ -f "$PD_DISPATCH_FILE" ]; then
  pass "Case 1: orchestrate-cycle-plan.sh prepared a live plan dispatch (dispatch_file on disk)"
else
  fail "Case 1: orchestrate-cycle-plan.sh did not prepare a live dispatch as expected (exit=$PD_CP_EXIT stdout=$PD_CP_STDOUT stderr=$PD_CP_STDERR)"
fi

c1_pending_prior="$(jq -c '.pending_dispatch | {prior_status, prior_last_updated, prior_session_id, prior_dispatch_seq_counter}' "$PD_GUARD_FILE" 2>/dev/null)"
c1_expected_prior='{"prior_status":"researched","prior_last_updated":"2020-01-01T00:00:00Z","prior_session_id":"sess_before_501","prior_dispatch_seq_counter":0}'
if [ "$c1_pending_prior" = "$c1_expected_prior" ]; then
  pass "Case 1: the REAL live dispatch populated the prior_* pre-image correctly end-to-end"
else
  fail "Case 1: prior_* pre-image mismatch -- expected $c1_expected_prior, got $c1_pending_prior"
fi

( cd "$repo1" && bash .claude/scripts/orchestrate-unwind-dispatch.sh 501 --session case1_sess --commit ) \
  >"$TOP_WORKDIR/.uw1_out" 2>"$TOP_WORKDIR/.uw1_err"
uw1_exit=$?
uw1_out="$(cat "$TOP_WORKDIR/.uw1_out")"
uw1_err="$(cat "$TOP_WORKDIR/.uw1_err")"

if [ "$uw1_exit" -eq 0 ]; then
  pass "Case 1: unwind exits 0"
else
  fail "Case 1: unwind exited $uw1_exit (stdout=$uw1_out stderr=$uw1_err)"
fi

c1_post="$(jq -S -c --argjson n 501 '.active_projects[] | select(.project_number == $n)' "$repo1/specs/state.json")"
if [ "$c1_post" = "$PD_SNAPSHOT" ]; then
  pass "Case 1: state.json entry matches the pre-dispatch snapshot EXACTLY (status/last_updated/session_id restored)"
else
  fail "Case 1: state.json entry mismatch -- expected $PD_SNAPSHOT, got $c1_post"
fi

if [ -f "$repo1/specs/TODO.md" ] && grep -q "501" "$repo1/specs/TODO.md" && grep -qi "researched" <(grep "501" "$repo1/specs/TODO.md"); then
  pass "Case 1: TODO.md was regenerated and reflects the restored 'researched' status for #501"
else
  fail "Case 1: TODO.md missing or does not reflect the restored status: $(cat "$repo1/specs/TODO.md" 2>/dev/null | grep 501)"
fi

if [ ! -d "$PD_TASK_DIR/.lock" ]; then
  pass "Case 1: the task lock was released"
else
  fail "Case 1: the task lock directory still exists: $(cat "$PD_TASK_DIR/.lock/holder.json" 2>/dev/null)"
fi

if [ ! -f "$PD_DISPATCH_FILE" ]; then
  pass "Case 1: the dispatch file was deleted"
else
  fail "Case 1: the dispatch file still exists: $PD_DISPATCH_FILE"
fi

if jq -e '.pending_dispatch == null' "$PD_GUARD_FILE" >/dev/null 2>&1; then
  pass "Case 1: pending_dispatch was cleared from the guard file"
else
  fail "Case 1: pending_dispatch is still present: $(cat "$PD_GUARD_FILE" 2>/dev/null)"
fi

if [ "$(jq -r '.dispatch_seq_counter' "$PD_GUARD_FILE" 2>/dev/null)" = "0" ]; then
  pass "Case 1: dispatch_seq_counter was flushed back to its pre-dispatch value (0)"
else
  fail "Case 1: expected dispatch_seq_counter=0 after unwind; got $(cat "$PD_GUARD_FILE" 2>/dev/null)"
fi

c1_porcelain="$(cd "$repo1" && git status --porcelain -- specs/)"
if [ -z "$c1_porcelain" ]; then
  pass "Case 1: 'git status --porcelain -- specs/' is empty after the scoped commit (no leftovers)"
else
  fail "Case 1: leftover changes under specs/ after the scoped commit: $c1_porcelain"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case 2: refuses once postflight has consumed the dispatch (--clear-pending already ran)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Case 2: refuses once the dispatch has been consumed (pending_dispatch already cleared)"

repo2="$(build_repo)"
prepare_dispatch "$repo2" 502 "unwind_case2" "case2_sess"
# What postflight does first, on every outcome: clear pending_dispatch.
bash "$repo2/.claude/scripts/orchestrate-loop-guard-init.sh" --clear-pending "$PD_TASK_DIR" >/dev/null

c2_state_before="$(cat "$repo2/specs/state.json")"
c2_guard_before="$(cat "$PD_GUARD_FILE" 2>/dev/null)"

( cd "$repo2" && bash .claude/scripts/orchestrate-unwind-dispatch.sh 502 --session case2_sess ) \
  >"$TOP_WORKDIR/.uw2_out" 2>"$TOP_WORKDIR/.uw2_err"
uw2_exit=$?

if [ "$uw2_exit" -eq 2 ]; then
  pass "Case 2: unwind refuses (exit 2) once pending_dispatch has already been consumed"
else
  fail "Case 2: expected exit 2; got $uw2_exit (stdout=$(cat "$TOP_WORKDIR/.uw2_out") stderr=$(cat "$TOP_WORKDIR/.uw2_err"))"
fi

c2_state_after="$(cat "$repo2/specs/state.json")"
c2_guard_after="$(cat "$PD_GUARD_FILE" 2>/dev/null)"
if [ "$c2_state_before" = "$c2_state_after" ] && [ "$c2_guard_before" = "$c2_guard_after" ]; then
  pass "Case 2: refusal touched NOTHING (state.json and the guard file are byte-identical)"
else
  fail "Case 2: refusal unexpectedly mutated state -- state changed: $([ "$c2_state_before" != "$c2_state_after" ] && echo yes || echo no), guard changed: $([ "$c2_guard_before" != "$c2_guard_after" ] && echo yes || echo no)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case 3: refuses once an agent has started (a newer .return-meta.json exists)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Case 3: refuses once an agent has started (.return-meta.json newer than the dispatch file)"

repo3="$(build_repo)"
prepare_dispatch "$repo3" 503 "unwind_case3" "case3_sess"
sleep 1
echo '{"status":"planned"}' > "$PD_TASK_DIR/.return-meta.json"

c3_state_before="$(cat "$repo3/specs/state.json")"
c3_guard_before="$(cat "$PD_GUARD_FILE" 2>/dev/null)"

( cd "$repo3" && bash .claude/scripts/orchestrate-unwind-dispatch.sh 503 --session case3_sess ) \
  >"$TOP_WORKDIR/.uw3_out" 2>"$TOP_WORKDIR/.uw3_err"
uw3_exit=$?

if [ "$uw3_exit" -eq 2 ]; then
  pass "Case 3: unwind refuses (exit 2) once an agent appears to have started"
else
  fail "Case 3: expected exit 2; got $uw3_exit (stderr=$(cat "$TOP_WORKDIR/.uw3_err"))"
fi
if grep -qi "agent appears to have already started" "$TOP_WORKDIR/.uw3_err"; then
  pass "Case 3: the refusal names the agent-started reason"
else
  fail "Case 3: refusal message did not name the agent-started reason: $(cat "$TOP_WORKDIR/.uw3_err")"
fi

c3_state_after="$(cat "$repo3/specs/state.json")"
c3_guard_after="$(cat "$PD_GUARD_FILE" 2>/dev/null)"
if [ "$c3_state_before" = "$c3_state_after" ] && [ "$c3_guard_before" = "$c3_guard_after" ]; then
  pass "Case 3: refusal touched NOTHING"
else
  fail "Case 3: refusal unexpectedly mutated state"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case 4: --dry-run writes nothing
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Case 4: --dry-run performs no writes"

repo4="$(build_repo)"
prepare_dispatch "$repo4" 504 "unwind_case4" "case4_sess"

c4_state_sum_before="$(sha256sum "$repo4/specs/state.json" | awk '{print $1}')"
c4_guard_sum_before="$(sha256sum "$PD_GUARD_FILE" | awk '{print $1}')"
c4_dispatch_sum_before="$(sha256sum "$PD_DISPATCH_FILE" | awk '{print $1}')"
c4_lock_present_before="$([ -d "$PD_TASK_DIR/.lock" ] && echo yes || echo no)"

( cd "$repo4" && bash .claude/scripts/orchestrate-unwind-dispatch.sh 504 --session case4_sess --dry-run ) \
  >"$TOP_WORKDIR/.uw4_out" 2>"$TOP_WORKDIR/.uw4_err"
uw4_exit=$?

if [ "$uw4_exit" -eq 0 ]; then
  pass "Case 4: --dry-run exits 0"
else
  fail "Case 4: --dry-run exited $uw4_exit (stderr=$(cat "$TOP_WORKDIR/.uw4_err"))"
fi

c4_state_sum_after="$(sha256sum "$repo4/specs/state.json" | awk '{print $1}')"
c4_guard_sum_after="$(sha256sum "$PD_GUARD_FILE" | awk '{print $1}')"
c4_dispatch_sum_after="$(sha256sum "$PD_DISPATCH_FILE" 2>/dev/null | awk '{print $1}')"
c4_lock_present_after="$([ -d "$PD_TASK_DIR/.lock" ] && echo yes || echo no)"

if [ "$c4_state_sum_before" = "$c4_state_sum_after" ] && [ "$c4_guard_sum_before" = "$c4_guard_sum_after" ] \
   && [ "$c4_dispatch_sum_before" = "$c4_dispatch_sum_after" ] && [ "$c4_lock_present_before" = "$c4_lock_present_after" ]; then
  pass "Case 4: --dry-run left state.json, the guard file, the dispatch file, and the lock byte/state-identical"
else
  fail "Case 4: --dry-run mutated something -- state: $([ "$c4_state_sum_before" = "$c4_state_sum_after" ] && echo ok || echo CHANGED), guard: $([ "$c4_guard_sum_before" = "$c4_guard_sum_after" ] && echo ok || echo CHANGED), dispatch: $([ "$c4_dispatch_sum_before" = "$c4_dispatch_sum_after" ] && echo ok || echo CHANGED), lock: $c4_lock_present_before -> $c4_lock_present_after"
fi

if grep -q "DRY-RUN" "$TOP_WORKDIR/.uw4_out"; then
  pass "Case 4: --dry-run prints its planned actions"
else
  fail "Case 4: --dry-run produced no DRY-RUN preview output: $(cat "$TOP_WORKDIR/.uw4_out")"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case 5: refuses under a FRESH lock held by a different session
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Case 5: refuses when the task lock is FRESH and held by a different session"

repo5="$(build_repo)"
prepare_dispatch "$repo5" 505 "unwind_case5" "case5_sess"
# Overwrite the lock's holder to a different, still-fresh session (heartbeat just now).
jq --arg sid "some_other_session" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '.session_id = $sid | .heartbeat_at = $now | .acquired_at = $now' \
  "$PD_TASK_DIR/.lock/holder.json" > "$PD_TASK_DIR/.lock/holder.json.tmp" && \
  mv "$PD_TASK_DIR/.lock/holder.json.tmp" "$PD_TASK_DIR/.lock/holder.json"

c5_lock_before="$(cat "$PD_TASK_DIR/.lock/holder.json")"

( cd "$repo5" && bash .claude/scripts/orchestrate-unwind-dispatch.sh 505 --session case5_sess ) \
  >"$TOP_WORKDIR/.uw5_out" 2>"$TOP_WORKDIR/.uw5_err"
uw5_exit=$?

if [ "$uw5_exit" -eq 2 ]; then
  pass "Case 5: unwind refuses (exit 2) under a fresh foreign lock"
else
  fail "Case 5: expected exit 2; got $uw5_exit (stderr=$(cat "$TOP_WORKDIR/.uw5_err"))"
fi
if grep -qi "another run appears to be live" "$TOP_WORKDIR/.uw5_err"; then
  pass "Case 5: the refusal names the live-lock reason"
else
  fail "Case 5: refusal message did not name the live-lock reason: $(cat "$TOP_WORKDIR/.uw5_err")"
fi

c5_lock_after="$(cat "$PD_TASK_DIR/.lock/holder.json" 2>/dev/null)"
if [ "$c5_lock_before" = "$c5_lock_after" ]; then
  pass "Case 5: the foreign lock was left completely untouched"
else
  fail "Case 5: the foreign lock was unexpectedly modified -- before=$c5_lock_before after=$c5_lock_after"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [ "$FAILED" -eq 0 ]; then
  exit 0
else
  exit 1
fi
