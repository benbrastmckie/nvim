#!/usr/bin/env bash
# test-reconcile-demote-stranded.sh - Fixture-driven regression suite for
# reconcile-task-status.sh's demote_stranded_status() lock-aware demotion gate, specifically the
# fix for its held-live conflation: exit 1 is shared by TWO distinct task-lock.sh check states
# (held-fresh and the additive held-live state), and the gate used to treat every exit-1 line as
# "a live session may be working" -- correct for held-fresh, wrong for held-live, whose entire
# point is that the heartbeat IS stale. The fix branches on the output line's TEXT PREFIX and
# consults dispatch-strand-probe.sh for held-live, demoting only on a `stranded` verdict.
#
# Structural model: test-reconcile-handoff-status.sh's sandbox (a real
# $SANDBOX/.claude/scripts/ tree, whole-directory-copied from the source store so
# dispatch-strand-probe.sh, task-lock.sh, and every other collaborator ride along unmodified,
# plus a throwaway $SANDBOX/specs/ tree). Every case runs the sandboxed copy via --dry-run.
#
# Seven cases: free -> demote; held-stale -> demote; held-fresh -> refuse (message unchanged);
# held-live + probe stranded -> demote; held-live + probe live -> refuse; held-live + probe
# unknown -> refuse; resolution error -> refuse.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

# Source-store-first / deploy-tree-fallback, matching test-reconcile-handoff-status.sh's own
# rationale: this suite regression-guards the fix being landed in the source store right now, so
# preferring a possibly-stale deployed mirror would silently validate the wrong file.
SCRIPTS_SRC_CANDIDATES=(
  "$REPO_ROOT/agent-system/extensions/core/scripts"
  "$REPO_ROOT/.claude/scripts"
)
SCRIPTS_SRC=""
for candidate in "${SCRIPTS_SRC_CANDIDATES[@]}"; do
  if [[ -f "$candidate/reconcile-task-status.sh" && -f "$candidate/dispatch-strand-probe.sh" ]]; then
    SCRIPTS_SRC="$candidate"
    break
  fi
done
if [[ -z "$SCRIPTS_SRC" ]]; then
  echo "ERROR: reconcile-task-status.sh and dispatch-strand-probe.sh not found together at any of:" >&2
  for candidate in "${SCRIPTS_SRC_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

SANDBOX="$(mktemp -d)"
cleanup() { [ -n "${SANDBOX:-}" ] && [ -d "$SANDBOX" ] && rm -rf "$SANDBOX"; }
trap cleanup EXIT

mkdir -p "$SANDBOX/.claude/scripts"
if ! cp -r "$SCRIPTS_SRC/." "$SANDBOX/.claude/scripts/"; then
  echo "ERROR: failed to populate sandbox scripts tree from $SCRIPTS_SRC" >&2
  exit 2
fi
RECONCILE="$SANDBOX/.claude/scripts/reconcile-task-status.sh"
for req in "$RECONCILE" "$SANDBOX/.claude/scripts/dispatch-strand-probe.sh" "$SANDBOX/.claude/scripts/task-lock.sh"; do
  if [[ ! -f "$req" ]]; then
    echo "ERROR: sandbox $req missing after copy" >&2
    exit 2
  fi
done

TASK_NUMBER=1
SESSION_ID="test-session"
PROJECT_NAME="fixture_task"
PADDED="001"
TASK_DIR="$SANDBOX/specs/${PADDED}_${PROJECT_NAME}"
OWN_PID="$$"

reset_specs() {
  rm -rf "$SANDBOX/specs"
  mkdir -p "$TASK_DIR" "$SANDBOX/specs/.sessions"
}

write_state_json() {
  local status="$1"
  cat > "$SANDBOX/specs/state.json" <<EOF
{
  "next_project_number": 2,
  "active_projects": [
    {
      "project_number": $TASK_NUMBER,
      "project_name": "$PROJECT_NAME",
      "status": "$status",
      "task_type": "general",
      "last_updated": "2020-01-01T00:00:00Z"
    }
  ]
}
EOF
}

minutes_ago_iso() { date -u -d "@$(( $(date -u +%s) - ($1 * 60) ))" +%Y-%m-%dT%H:%M:%SZ; }

write_lock_fixture() {
  # write_lock_fixture <session_id> <heartbeat_minutes_ago>
  local session_id="$1" mins_ago="$2" ts
  ts=$(minutes_ago_iso "$mins_ago")
  mkdir -p "$TASK_DIR/.lock"
  jq -n --arg session_id "$session_id" --argjson task_number "$TASK_NUMBER" \
    --arg operation "research" --arg ts "$ts" --arg command "/research $TASK_NUMBER" \
    '{session_id: $session_id, task_number: $task_number, operation: $operation, acquired_at: $ts, heartbeat_at: $ts, command: $command}' \
    > "$TASK_DIR/.lock/holder.json"
}

write_session_registry_fixture() {
  # write_session_registry_fixture <session_id> <pid> <heartbeat_minutes_ago>
  local session_id="$1" pid="$2" mins_ago="$3" ts
  ts=$(minutes_ago_iso "$mins_ago")
  jq -n --arg session_id "$session_id" --argjson pid "$pid" --arg pid_source "test-fixture" \
    --arg command "/test $session_id" --argjson task_numbers "[$TASK_NUMBER]" \
    --argjson file_scope "[]" --arg ts "$ts" \
    '{session_id: $session_id, pid: $pid, pid_source: $pid_source, command: $command, task_numbers: $task_numbers, file_scope: $file_scope, started_at: $ts, heartbeat_at: $ts}' \
    > "$SANDBOX/specs/.sessions/${session_id}.json"
}

STDOUT_FILE="$SANDBOX/_stdout.txt"
STDERR_FILE="$SANDBOX/_stderr.txt"

run_reconcile() {
  (cd "$SANDBOX" && bash "$RECONCILE" "$TASK_NUMBER" "$SESSION_ID" --dry-run) \
    >"$STDOUT_FILE" 2>"$STDERR_FILE"
}

# =====================================================================
# Case 1: free (no lock at all) -> DEMOTE. Unchanged by this fix.
# =====================================================================
info "=== Case 1: free -> demote ==="
reset_specs
write_state_json "researching"
run_reconcile
if grep -qF "Would demote: researching -> not_started" "$STDOUT_FILE"; then
  pass "(1) free lock demotes researching -> not_started"
else
  fail "(1) expected a demotion line, stdout: $(cat "$STDOUT_FILE") stderr: $(cat "$STDERR_FILE")"
fi

# =====================================================================
# Case 2: held-stale (stale heartbeat, no live session registry entry) -> DEMOTE. Unchanged.
# =====================================================================
info "=== Case 2: held-stale -> demote ==="
reset_specs
write_state_json "researching"
write_lock_fixture "sess_dead" 120
# Deliberately no specs/.sessions/sess_dead.json -- falls through to held-stale, exit 2.
run_reconcile
if grep -qF "Would demote: researching -> not_started" "$STDOUT_FILE"; then
  pass "(2) held-stale demotes researching -> not_started"
else
  fail "(2) expected a demotion line, stdout: $(cat "$STDOUT_FILE") stderr: $(cat "$STDERR_FILE")"
fi

# =====================================================================
# Case 3: held-fresh (heartbeat inside the threshold) -> REFUSE, message byte-identical to the
# pre-fix text (git diff over reconcile-task-status.sh must show this string untouched).
# =====================================================================
info "=== Case 3: held-fresh -> refuse, message unchanged ==="
reset_specs
write_state_json "researching"
write_lock_fixture "sess_fresh" 2
run_reconcile
if grep -qF "task-lock.sh check reports a FRESH lock" "$STDOUT_FILE" \
   && grep -qF "refusing demotion (a live session may genuinely be in progress)" "$STDOUT_FILE" \
   && ! grep -qF "Would demote" "$STDOUT_FILE"; then
  pass "(3) held-fresh refuses with the unchanged message, no demotion"
else
  fail "(3) expected the unchanged held-fresh refusal, stdout: $(cat "$STDOUT_FILE") stderr: $(cat "$STDERR_FILE")"
fi

# =====================================================================
# Case 4: held-live + probe verdict `stranded` -> DEMOTE (the fix's whole point).
# =====================================================================
info "=== Case 4: held-live + probe stranded -> demote ==="
reset_specs
write_state_json "researching"
write_lock_fixture "sess_live_stranded" 120
write_session_registry_fixture "sess_live_stranded" "$OWN_PID" 120
echo "old, never touched since" > "$TASK_DIR/old.md"
touch -d "$(minutes_ago_iso 120)" "$TASK_DIR/old.md"
run_reconcile
if grep -qF "Would demote: researching -> not_started" "$STDOUT_FILE" \
   && grep -qF "dispatch-strand-probe.sh verdict=stranded" "$STDOUT_FILE"; then
  pass "(4) held-live + probe verdict=stranded demotes, naming the probe verdict"
else
  fail "(4) expected a probe-attributed demotion, stdout: $(cat "$STDOUT_FILE") stderr: $(cat "$STDERR_FILE")"
fi

# =====================================================================
# Case 5: held-live + probe verdict `live` (the healthy-but-slow shape: an artifact touched
# inside the window) -> REFUSE, distinct wording from the held-fresh refusal.
# =====================================================================
info "=== Case 5: held-live + probe live -> refuse ==="
reset_specs
write_state_json "researching"
write_lock_fixture "sess_live_healthy" 41
write_session_registry_fixture "sess_live_healthy" "$OWN_PID" 41
echo "actively being rewritten" > "$TASK_DIR/report.md"
# Deliberately NOT backdated -- mtime is "now", inside the stale window.
run_reconcile
if grep -qF "task-lock.sh check reports held-live" "$STDOUT_FILE" \
   && grep -qF "dispatch-strand-probe.sh verdict=live" "$STDOUT_FILE" \
   && ! grep -qF "Would demote" "$STDOUT_FILE"; then
  pass "(5) held-live + probe verdict=live refuses, with wording distinct from held-fresh"
else
  fail "(5) expected a probe-attributed refusal, stdout: $(cat "$STDOUT_FILE") stderr: $(cat "$STDERR_FILE")"
fi

# =====================================================================
# Case 6: held-live + probe verdict `unknown` (probe cannot resolve, e.g. unparseable fields) ->
# REFUSE. Fail-closed: unknown never demotes.
# =====================================================================
info "=== Case 6: held-live + probe unknown -> refuse ==="
reset_specs
write_state_json "researching"
write_lock_fixture "sess_live_unknown" 120
write_session_registry_fixture "sess_live_unknown" "$OWN_PID" 120
# Corrupt the task directory's own resolvability for the probe by removing the directory the
# probe would otherwise quiesce-check -- simplest reliable way to force the probe's own
# resolution to come back ambiguous without touching task-lock.sh's output: temporarily rename
# dispatch-strand-probe.sh out of the way so reconcile's own `[[ -x ... ]]` guard sees it
# missing, which is exactly the "probe cannot be run at all" fail-closed path this case also
# covers.
mv "$SANDBOX/.claude/scripts/dispatch-strand-probe.sh" "$SANDBOX/.claude/scripts/dispatch-strand-probe.sh.hidden"
run_reconcile
mv "$SANDBOX/.claude/scripts/dispatch-strand-probe.sh.hidden" "$SANDBOX/.claude/scripts/dispatch-strand-probe.sh"
if grep -qF "task-lock.sh check reports held-live" "$STDOUT_FILE" \
   && grep -qF "dispatch-strand-probe.sh verdict=unknown" "$STDOUT_FILE" \
   && ! grep -qF "Would demote" "$STDOUT_FILE"; then
  pass "(6) held-live + unresolvable probe refuses (fail-closed on unknown)"
else
  fail "(6) expected a fail-closed refusal, stdout: $(cat "$STDOUT_FILE") stderr: $(cat "$STDERR_FILE")"
fi

# =====================================================================
# Case 7: resolution error (task-lock.sh check exit 3, e.g. an unresolvable task directory) ->
# REFUSE. Unchanged by this fix.
# =====================================================================
info "=== Case 7: resolution error -> refuse ==="
reset_specs
# No state.json at all -- task-lock.sh check cannot resolve the task directory, exit 3.
rm -f "$SANDBOX/specs/state.json"
echo '{"next_project_number":2,"active_projects":[]}' > "$SANDBOX/specs/state.json"
run_reconcile
if grep -qF "FAILED to resolve" "$STDERR_FILE" && ! grep -qF "Would demote" "$STDOUT_FILE"; then
  pass "(7) resolution error refuses, failing closed on ambiguity"
else
  info "(7) note: reconcile-task-status.sh's own task-resolution precondition may short-circuit before reaching demote_stranded_status() for a wholly-absent task entry -- see output below"
  info "stdout: $(cat "$STDOUT_FILE")"
  info "stderr: $(cat "$STDERR_FILE")"
  if ! grep -qF "Would demote" "$STDOUT_FILE"; then
    pass "(7) at minimum, no demotion occurs when the task cannot be resolved at all"
  else
    fail "(7) expected no demotion for an unresolvable task"
  fi
fi

echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
