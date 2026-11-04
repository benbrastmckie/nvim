#!/usr/bin/env bash
# test-audit-task-proposals.sh - Hermetic fixture suite for scripts/audit-task-proposals.sh.
#
# Reproduces the motivating backlog-reconciliation incident (three proposals compared against a
# synthetic backlog standing in for the real 309/310/311-vs-272/302 episode) and the extended
# closed-record acceptance cases from context/patterns/backlog-reconciliation.md. Every fixture
# state/archive file here is synthetic and written to a `mktemp -d` workdir -- this suite never
# reads or writes the live specs/state.json or specs/archive/state.json.
#
# Structural model: test-lint-state-writer-boundary.sh (common_test_repo_root,
# common_test_resolve_candidate, common_test_workdir_init, common_test_pass/fail/info,
# PASSED/FAILED counters).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT_RESOLVED="$(common_test_repo_root "$SCRIPT_DIR")"
SCRIPT_UNDER_TEST="$(common_test_resolve_candidate "audit-task-proposals.sh" \
  "$REPO_ROOT_RESOLVED/.claude/scripts/audit-task-proposals.sh" \
  "$SCRIPT_DIR/../audit-task-proposals.sh")" || exit 2

# audit-task-proposals.sh sources lib/file-scope-overlap.sh via deploy-root-guard.sh unless
# REPO_ROOT is already set -- export it unconditionally (harmless for the deployed-path case,
# required for the source-store-fallback case) so this suite runs from either tree, matching
# audit-task-proposals.sh's own documented REPO_ROOT override convention.
export REPO_ROOT="$REPO_ROOT_RESOLVED"

PASSED=0
FAILED=0
common_test_workdir_init

# Snapshot specs/** BEFORE any fixture runs, so the "specs/** untouched" assertion near the end
# compares before/after rather than asserting the whole tree is pristine -- a concurrently
# dispatched task's own uncommitted specs/ work (including this very task's own in-flight
# progress files) must never make this suite report a false failure.
SPECS_STATUS_BEFORE="$(cd "$REPO_ROOT_RESOLVED" 2>/dev/null && git status --porcelain specs/ 2>/dev/null || true)"

run_audit() {
  # run_audit <proposals-file> <state-file> <archive-file>
  bash "$SCRIPT_UNDER_TEST" --proposals-file "$1" --state-file "$2" --archive-file "$3"
}

# =====================================================================
# Fixture A: the motivating incident -- subset-of-open (302-analog), duplicate-of-open
# (272-analog, caught ONLY by the semantic pass with exactly one shared path), genuinely-new.
# =====================================================================
common_test_info "=== Fixture A: motivating incident (subset / duplicate-by-semantics / new) ==="

FXA_DIR="$WORKDIR/fixture-a"
mkdir -p "$FXA_DIR/archive"
cat > "$FXA_DIR/state.json" << 'EOF'
{
  "active_projects": [
    {"project_number": 302, "project_name": "widen_gate_cost_ledger_reconciliation",
     "status": "not_started",
     "title": "Reconcile the gate-cost ledger across three disagreeing line numbers",
     "description": "The gate-cost ledger disagrees with the live measurement at three specific line numbers in the cost table; reconcile all three and widen the ledger format to carry a measured-at timestamp.",
     "file_scope": ["scripts/gate-cost-ledger.sh", "docs/reference/gate-cost-table.md", "scripts/tests/test-gate-cost-ledger.sh"]},
    {"project_number": 272, "project_name": "fix_task_lock_heartbeat_never_fires",
     "status": "not_started",
     "title": "Task-lock heartbeat never fires, session registry goes stale",
     "description": "The session-registry heartbeat mechanism documented in task-lock.md and orchestrator-runtime-files.md never actually fires in practice, so session-registry contention checks observe stale data; also covers gaps in test-conflict-predicate.sh and test-session-registry.sh.",
     "file_scope": ["scripts/task-lock.sh", "context/standards/orchestrator-runtime-files.md", "context/patterns/task-lock.md", "scripts/tests/test-session-registry.sh", "scripts/tests/test-conflict-predicate.sh"]}
  ]
}
EOF
echo '{}' > "$FXA_DIR/archive/state.json"

cat > "$FXA_DIR/proposals.json" << 'EOF'
[
  {"id": "309-analog", "title": "Reconcile the gate-cost ledger at three line numbers",
   "description": "Three specific line numbers in the gate-cost table disagree with the live measurement; reconcile them.",
   "file_scope": ["docs/reference/gate-cost-table.md"]},
  {"id": "310-analog", "title": "Session heartbeat never fires for task-lock sessions",
   "description": "The heartbeat mechanism for session registry contention never fires in practice, causing stale session data for task-lock.sh contention checks.",
   "file_scope": ["scripts/task-lock.sh", "scripts/session-monitor.sh", "context/standards/session-registry-notes.md", "scripts/tests/test-heartbeat-liveness.sh"]},
  {"id": "311-analog", "title": "Introduce a BUILD_HEAVY weight classification for dispatch scheduling",
   "description": "No open record anywhere mentions BUILD_HEAVY or build-weight classification; this is new scheduling metadata.",
   "file_scope": ["scripts/lib/dispatch-weight.sh"]}
]
EOF

FXA_OUT="$WORKDIR/fixture-a-out.ndjson"
if run_audit "$FXA_DIR/proposals.json" "$FXA_DIR/state.json" "$FXA_DIR/archive/state.json" > "$FXA_OUT" 2>"$WORKDIR/fixture-a-err.txt"; then
  common_test_pass "Fixture A: audit ran to completion (exit 0)"
else
  common_test_fail "Fixture A: audit exited non-zero: $(cat "$WORKDIR/fixture-a-err.txt")"
fi

fxa_verdict() {
  jq -r --arg id "$1" --arg verdict "$2" --argjson pnum "$3" \
    'select(.proposal.id == $id) | .verdicts[] | select(.verdict == $verdict and .project_number == $pnum) | .verdict' \
    "$FXA_OUT"
}

if [[ "$(fxa_verdict "309-analog" "subset-of-open" 302)" == "subset-of-open" ]]; then
  common_test_pass "Fixture A: 309-analog yields subset-of-open naming 302"
else
  common_test_fail "Fixture A: 309-analog did not yield subset-of-open naming 302:
$(jq -c 'select(.proposal.id=="309-analog")' "$FXA_OUT")"
fi

if [[ "$(fxa_verdict "310-analog" "duplicate-of-open" 272)" == "duplicate-of-open" ]]; then
  common_test_pass "Fixture A: 310-analog yields duplicate-of-open naming 272"
else
  common_test_fail "Fixture A: 310-analog did not yield duplicate-of-open naming 272:
$(jq -c 'select(.proposal.id=="310-analog")' "$FXA_OUT")"
fi

# Prove the mechanical pass ALONE is insufficient for the 310-analog case: its mechanical_class
# must be "overlap" (weak, partial), never "exact"/"subset"/"superset" (which would mean the
# mechanical pass alone already conclusively caught it) -- and the shared path count must be 1.
fxa_310_mech="$(jq -r 'select(.proposal.id=="310-analog") | .verdicts[] | select(.project_number==272) | .mechanical_class' "$FXA_OUT")"
fxa_310_shared_count="$(jq -r '[select(.proposal.id=="310-analog") | .verdicts[] | select(.project_number==272) | .shared_paths[]?] | length' "$FXA_OUT" 2>/dev/null || echo "err")"
if [[ "$fxa_310_mech" == "overlap" ]]; then
  common_test_pass "Fixture A: 310-analog's mechanical pass alone found only a weak 'overlap' (not exact/subset/superset) -- the semantic pass did the real work"
else
  common_test_fail "Fixture A: 310-analog's mechanical_class was '$fxa_310_mech', expected 'overlap' (proves mechanical pass alone is insufficient)"
fi

if jq -e 'select(.proposal.id=="310-analog") | .verdicts[] | select(.project_number==272) | (.shared_paths // []) | length == 1' "$FXA_OUT" >/dev/null 2>&1; then
  common_test_pass "Fixture A: 310-analog shares exactly ONE path with 272"
else
  common_test_fail "Fixture A: 310-analog's shared_paths count was not exactly 1 (got: $fxa_310_shared_count)"
fi

if jq -e 'select(.proposal.id=="311-analog") | .verdicts == [{"verdict":"genuinely-new"}]' "$FXA_OUT" >/dev/null 2>&1; then
  common_test_pass "Fixture A: 311-analog yields exactly genuinely-new (no corpus record declares a scope, so every corpus record also surfaces as scope-blind -- assert genuinely-new is still present among them)"
elif jq -e 'select(.proposal.id=="311-analog") | .verdicts[] | select(.verdict=="genuinely-new")' "$FXA_OUT" >/dev/null 2>&1; then
  common_test_pass "Fixture A: 311-analog's verdict list includes genuinely-new"
else
  common_test_fail "Fixture A: 311-analog did not yield genuinely-new:
$(jq -c 'select(.proposal.id=="311-analog")' "$FXA_OUT")"
fi

# =====================================================================
# Fixture B: closed record in the ARCHIVE -- covered-by-closed naming project_name + artifact.
# =====================================================================
common_test_info "=== Fixture B: closed record in the archive ==="

FXB_DIR="$WORKDIR/fixture-b"
mkdir -p "$FXB_DIR/archive"
echo '{"active_projects": []}' > "$FXB_DIR/state.json"
cat > "$FXB_DIR/archive/state.json" << 'EOF'
{
  "completed_projects": [
    {"project_number": 9001, "project_name": "archived_widget_doohickey_fix", "status": "completed",
     "title": "Fix the widget doohickey race condition",
     "description": "Resolved a race condition in the widget doohickey teardown path.",
     "file_scope": ["src/widget/doohickey.sh"],
     "artifacts": [{"type": "summary", "path": "specs/archive/old/01_doohickey-summary.md"}]}
  ],
  "archived_projects": [],
  "abandoned_projects": []
}
EOF
echo '[{"id": "fxb-1", "title": "Widget doohickey race condition", "description": "A race condition exists in widget doohickey teardown.", "file_scope": ["src/widget/doohickey.sh"]}]' > "$FXB_DIR/proposals.json"

FXB_OUT="$WORKDIR/fixture-b-out.ndjson"
run_audit "$FXB_DIR/proposals.json" "$FXB_DIR/state.json" "$FXB_DIR/archive/state.json" > "$FXB_OUT" 2>"$WORKDIR/fixture-b-err.txt"

if jq -e '.verdicts[] | select(.verdict == "covered-by-closed" and .project_number == 9001 and .project_name == "archived_widget_doohickey_fix" and (.discharging_artifact.path == "specs/archive/old/01_doohickey-summary.md"))' "$FXB_OUT" >/dev/null 2>&1; then
  common_test_pass "Fixture B: archived record yields covered-by-closed with project_name + discharging_artifact"
else
  common_test_fail "Fixture B: did not find the expected covered-by-closed verdict:
$(cat "$FXB_OUT")"
fi

# =====================================================================
# Fixture C: closed record still RESIDENT in the live state file (status: completed).
# =====================================================================
common_test_info "=== Fixture C: closed record still resident in the live state file ==="

FXC_DIR="$WORKDIR/fixture-c"
mkdir -p "$FXC_DIR/archive"
cat > "$FXC_DIR/state.json" << 'EOF'
{
  "active_projects": [
    {"project_number": 777, "project_name": "fix_widget_teardown_race_live", "status": "completed",
     "title": "Fix widget teardown race (live, not yet archived)",
     "description": "Resolved a race in widget teardown; still awaiting archival.",
     "file_scope": ["src/widget/teardown.sh"],
     "artifacts": [{"type": "summary", "path": "specs/777_fix_widget_teardown_race_live/summaries/01-summary.md"}]}
  ]
}
EOF
echo '{}' > "$FXC_DIR/archive/state.json"
echo '[{"id": "fxc-1", "title": "Widget teardown race", "description": "A race exists in widget teardown.", "file_scope": ["src/widget/teardown.sh"]}]' > "$FXC_DIR/proposals.json"

FXC_OUT="$WORKDIR/fixture-c-out.ndjson"
run_audit "$FXC_DIR/proposals.json" "$FXC_DIR/state.json" "$FXC_DIR/archive/state.json" > "$FXC_OUT" 2>"$WORKDIR/fixture-c-err.txt"

if jq -e '.verdicts[] | select(.verdict == "covered-by-closed" and .project_number == 777 and .project_name == "fix_widget_teardown_race_live" and (.discharging_artifact.path | test("777_fix_widget_teardown_race_live")))' "$FXC_OUT" >/dev/null 2>&1; then
  common_test_pass "Fixture C: live completed record yields covered-by-closed (proves the union is real, not archive-only)"
else
  common_test_fail "Fixture C: did not find the expected covered-by-closed verdict:
$(cat "$FXC_OUT")"
fi

# =====================================================================
# Fixture D: a corpus record with NO file_scope -- scope-blind, never silent non-overlap.
# =====================================================================
common_test_info "=== Fixture D: corpus record with no file_scope ==="

FXD_DIR="$WORKDIR/fixture-d"
mkdir -p "$FXD_DIR/archive"
cat > "$FXD_DIR/state.json" << 'EOF'
{
  "active_projects": [
    {"project_number": 555, "project_name": "no_scope_declared_task", "status": "not_started",
     "title": "A task that declares no file_scope at all",
     "description": "This record has no file_scope field."}
  ]
}
EOF
echo '{}' > "$FXD_DIR/archive/state.json"
echo '[{"id": "fxd-1", "title": "Unrelated proposal", "description": "Nothing to do with the above.", "file_scope": ["some/other/path.sh"]}]' > "$FXD_DIR/proposals.json"

FXD_OUT="$WORKDIR/fixture-d-out.ndjson"
run_audit "$FXD_DIR/proposals.json" "$FXD_DIR/state.json" "$FXD_DIR/archive/state.json" > "$FXD_OUT" 2>"$WORKDIR/fixture-d-err.txt"

if jq -e '.verdicts[] | select(.verdict == "scope-blind" and .project_number == 555)' "$FXD_OUT" >/dev/null 2>&1; then
  common_test_pass "Fixture D: record with no file_scope yields scope-blind, not silent non-overlap"
else
  common_test_fail "Fixture D: did not find the expected scope-blind verdict:
$(cat "$FXD_OUT")"
fi

if jq -e '.degradations | any(. | test("scope-blind.*555"))' "$FXD_OUT" >/dev/null 2>&1; then
  common_test_pass "Fixture D: degradations array names the scope-blind record"
else
  common_test_fail "Fixture D: degradations array did not name the scope-blind record:
$(jq -c '.degradations' "$FXD_OUT")"
fi

# =====================================================================
# Fixture E: no-suppression -- a covered-by-closed match still carries the proposal, and no
# exit code or flag drops it.
# =====================================================================
common_test_info "=== Fixture E: no-suppression ==="

if jq -e '.proposal.id == "fxb-1"' "$FXB_OUT" >/dev/null 2>&1; then
  common_test_pass "Fixture E: a covered-by-closed match's output line still carries the proposal identity"
else
  common_test_fail "Fixture E: proposal identity missing from covered-by-closed output"
fi

# Re-run Fixture B with no special flag and confirm the exit code is still 0 (never a
# suppression-via-nonzero-exit path) and the verdict is present -- there is no flag this suite
# can pass to make the match disappear, because audit-task-proposals.sh defines none.
if bash "$SCRIPT_UNDER_TEST" --proposals-file "$FXB_DIR/proposals.json" --state-file "$FXB_DIR/state.json" --archive-file "$FXB_DIR/archive/state.json" > "$WORKDIR/fxe-rerun.ndjson" 2>"$WORKDIR/fxe-rerun-err.txt"; then
  if jq -e '.verdicts[] | select(.verdict=="covered-by-closed")' "$WORKDIR/fxe-rerun.ndjson" >/dev/null 2>&1; then
    common_test_pass "Fixture E: re-run with no special flags still surfaces the covered-by-closed verdict (no suppression path exists)"
  else
    common_test_fail "Fixture E: re-run lost the covered-by-closed verdict"
  fi
else
  common_test_fail "Fixture E: re-run exited non-zero unexpectedly"
fi

# =====================================================================
# Closed-record durable-anchor assertion: no verdict anywhere identifies a closed record by a
# bare number alone -- every covered-by-closed / closed-side scope-blind verdict carries
# project_name (and covered-by-closed also carries discharging_artifact).
# =====================================================================
common_test_info "=== Durable-anchor assertion: no bare-number closed citation ==="

bare_number_violation=false
for out in "$FXA_OUT" "$FXB_OUT" "$FXC_OUT" "$FXD_OUT"; do
  if jq -e '.verdicts[] | select(.verdict == "covered-by-closed") | select((.project_name // "") == "" or (.discharging_artifact // null) == null)' "$out" >/dev/null 2>&1; then
    bare_number_violation=true
  fi
done
if [[ "$bare_number_violation" == false ]]; then
  common_test_pass "No covered-by-closed verdict identifies a closed record by bare number alone"
else
  common_test_fail "Found a covered-by-closed verdict missing project_name or discharging_artifact"
fi

# =====================================================================
# D4 call-shape assertion: --proposals-file / stdin mode works standalone, no project_number,
# no task directory, enforcement hook nowhere in this call path (this script never invokes one).
# =====================================================================
common_test_info "=== D4: standalone proposal-time set-mode call shape ==="

if jq -e '.proposal.project_number == null' "$FXA_OUT" >/dev/null 2>&1; then
  common_test_pass "Set-mode proposals carry no project_number in their output identity"
else
  common_test_fail "Set-mode output unexpectedly carried a project_number"
fi

# The script's header is permitted to DOCUMENT that the enforcement hook is not in this call
# path (D4) -- what must never exist is an actual INVOCATION of (or dependency on) the hook.
if ! grep -Eq '(^|[^#[:alnum:]_.-])(bash|source|\.)[[:space:]]+.*validate-task-creation-audit' "$SCRIPT_UNDER_TEST"; then
  common_test_pass "audit-task-proposals.sh never INVOKES the enforcement hook -- fully standalone (D4)"
else
  common_test_fail "audit-task-proposals.sh appears to invoke the enforcement hook; it must be callable with no hook in the path"
fi

# Corroborate standalone-callability directly: the hook does not exist on disk at all yet
# (Phase 7 creates it), and every fixture above already ran this script to completion without
# it -- the strongest possible proof that the hook is nowhere in this call path.
if [[ ! -e "$REPO_ROOT_RESOLVED/agent-system/extensions/core/hooks/validate-task-creation-audit.sh" ]]; then
  common_test_pass "Corroboration: the enforcement hook does not exist on disk, and every fixture above still ran to completion"
else
  common_test_info "Enforcement hook already exists on disk (Phase 7 landed) -- the grep-based check above remains the live assertion"
fi

# =====================================================================
# No specs/** touched by this suite.
# =====================================================================
common_test_info "=== specs/** untouched ==="
SPECS_STATUS_AFTER="$(cd "$REPO_ROOT_RESOLVED" 2>/dev/null && git status --porcelain specs/ 2>/dev/null || true)"
if [[ "$SPECS_STATUS_AFTER" == "$SPECS_STATUS_BEFORE" ]]; then
  common_test_pass "specs/** is unchanged (before/after this suite's fixtures) -- no live specs/ write"
else
  common_test_fail "specs/** status changed across this suite's run (before vs after differ):
BEFORE:
$SPECS_STATUS_BEFORE
AFTER:
$SPECS_STATUS_AFTER"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
