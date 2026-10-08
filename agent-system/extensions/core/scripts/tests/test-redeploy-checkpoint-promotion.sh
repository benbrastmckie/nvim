#!/usr/bin/env bash
# test-redeploy-checkpoint-promotion.sh - Fixture-driven regression suite for the Inter-Cycle
# Redeploy Checkpoint's post-deploy reconcile pass, scripts/lib/redeploy-checkpoint-lib.sh's
# run_post_deploy_reconcile_pass().
#
# WHAT THIS SUITE PROVES: before the widening fix, that function's candidate set is bounded to
# the current /orchestrate invocation's own `post_deploy_reconcile_json` (itself derived from
# `.task_numbers` -- see orchestrate-cycle-plan.sh's per-project `_dp_t` loop), so a project
# refused by the completion-deploy gate (update-task-status.sh's PHASE 0.5, exit 6) in a cycle
# that does not happen to name that project again is structurally invisible to this self-heal
# mechanism forever. After the fix, the SAME function also sweeps specs/state.json system-wide
# for any non-terminal project whose own .return-meta.json carries deploy_pending:true,
# lock-gates each such swept candidate, and replays reconcile-task-status.sh for it -- with no
# new deploy-trigger call site and no change to the gate itself (every promotion attempt still
# passes through that unconditional, check-only gate, which simply re-refuses on a genuinely
# stale tree).
#
# Structural model: test-postflight-deploy-gate.sh (mktemp -d WORKDIR with an EXIT-trap cleanup,
# pass()/fail()/info() counters, set -uo pipefail (Class B), exit 0 all-pass / 1 any-fail /
# 2 environment error, source-store-first resolution for the file(s) under test, deploy-tree-
# first resolution for the unchanged dependency chain, and the build_source_and_extensions
# fabricated-source-repo idiom for freshness control).
#
# RESOLUTION ORDER for the library under test: source-store-first, with an environment-variable
# override (REDEPLOY_CHECKPOINT_LIB) that takes priority over both. The override is what makes
# the fail-before/pass-after demonstration repeatable without ever committing a red suite: point
# it at a pristine (pre-widening) copy of the library and re-run this same suite.
#
# ISOLATION CONTRACT: every case runs against a complete, isolated fixture repo built fresh
# under mktemp -d WORKDIR -- a real dependency chain copied in, a private specs/state.json and
# task directories, and a private .claude-extensions.json/source-repo pair standing in for the
# deploy-freshness comparison. A STUB git-commit-scoped.sh (logs argv, exits 0) replaces the
# real script so this suite never commits anything. The suite never touches the real specs/
# tree, real state.json, or the real .claude-extensions.json.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

DEPLOY_SCRIPTS_SRC="$REPO_ROOT/.claude/scripts"
SOURCE_STORE_SCRIPTS="$REPO_ROOT/agent-system/extensions/core/scripts"

# --- Resolution for the library under test: env override > source-store > deploy tree ---
if [[ -n "${REDEPLOY_CHECKPOINT_LIB:-}" ]]; then
  LIB_UNDER_TEST="$REDEPLOY_CHECKPOINT_LIB"
elif [[ -f "$SOURCE_STORE_SCRIPTS/lib/redeploy-checkpoint-lib.sh" ]]; then
  LIB_UNDER_TEST="$SOURCE_STORE_SCRIPTS/lib/redeploy-checkpoint-lib.sh"
else
  LIB_UNDER_TEST="$DEPLOY_SCRIPTS_SRC/lib/redeploy-checkpoint-lib.sh"
fi
if [[ ! -f "$LIB_UNDER_TEST" ]]; then
  echo "ERROR: redeploy-checkpoint-lib.sh not found at $LIB_UNDER_TEST" >&2
  exit 2
fi

# --- Source-store-first resolution for reconcile-task-status.sh, update-task-status.sh, and
#     lib/deploy-freshness-lib.sh (the files this suite exercises but does not itself modify) ---
RECONCILE_CANDIDATES=(
  "$SOURCE_STORE_SCRIPTS/reconcile-task-status.sh"
  "$DEPLOY_SCRIPTS_SRC/reconcile-task-status.sh"
)
RECONCILE_SRC=""
for c in "${RECONCILE_CANDIDATES[@]}"; do
  [[ -f "$c" ]] && { RECONCILE_SRC="$c"; break; }
done
[[ -z "$RECONCILE_SRC" ]] && { echo "ERROR: reconcile-task-status.sh not found at any of: ${RECONCILE_CANDIDATES[*]}" >&2; exit 2; }

UTS_CANDIDATES=(
  "$SOURCE_STORE_SCRIPTS/update-task-status.sh"
  "$DEPLOY_SCRIPTS_SRC/update-task-status.sh"
)
UTS_SRC=""
for c in "${UTS_CANDIDATES[@]}"; do
  [[ -f "$c" ]] && { UTS_SRC="$c"; break; }
done
[[ -z "$UTS_SRC" ]] && { echo "ERROR: update-task-status.sh not found at any of: ${UTS_CANDIDATES[*]}" >&2; exit 2; }

FRESHNESS_LIB_CANDIDATES=(
  "$SOURCE_STORE_SCRIPTS/lib/deploy-freshness-lib.sh"
  "$DEPLOY_SCRIPTS_SRC/lib/deploy-freshness-lib.sh"
)
FRESHNESS_LIB_SRC=""
for c in "${FRESHNESS_LIB_CANDIDATES[@]}"; do
  [[ -f "$c" ]] && { FRESHNESS_LIB_SRC="$c"; break; }
done
[[ -z "$FRESHNESS_LIB_SRC" ]] && { echo "ERROR: deploy-freshness-lib.sh not found at any of: ${FRESHNESS_LIB_CANDIDATES[*]}" >&2; exit 2; }

# --- Deploy-tree-first resolution (unchanged dependencies) ---
if [[ ! -d "$DEPLOY_SCRIPTS_SRC" ]]; then
  echo "ERROR: deployed scripts tree not found at $DEPLOY_SCRIPTS_SRC -- this suite needs a" >&2
  echo "       real deployed .claude/scripts/ tree to copy the unchanged dependency chain from." >&2
  exit 2
fi
REQUIRED_SCRIPTS=(state-write.sh task-lock.sh generate-todo.sh generate-task-order.sh
                   update-plan-status.sh update-phase-status.sh deploy-root-guard.sh)
for req in "${REQUIRED_SCRIPTS[@]}"; do
  if [[ ! -f "$DEPLOY_SCRIPTS_SRC/$req" ]]; then
    echo "ERROR: required deployed script missing: $DEPLOY_SCRIPTS_SRC/$req" >&2
    exit 2
  fi
done
REQUIRED_LIBS=(common.sh phase-heading-patterns.sh status-vocabulary.sh file-scope-overlap.sh task-lookup-lib.sh)
for req in "${REQUIRED_LIBS[@]}"; do
  if [[ ! -f "$DEPLOY_SCRIPTS_SRC/lib/$req" ]]; then
    echo "ERROR: required deployed library missing: $DEPLOY_SCRIPTS_SRC/lib/$req" >&2
    exit 2
  fi
done

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
# shellcheck disable=SC2329  # invoked indirectly via the EXIT trap below, not a dead function
cleanup() { [[ -n "${WORKDIR:-}" && -d "$WORKDIR" ]] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

info "Library under test: $LIB_UNDER_TEST"
info "reconcile-task-status.sh (source-store-first, unmodified by this suite): $RECONCILE_SRC"
info "update-task-status.sh (source-store-first, unmodified by this suite): $UTS_SRC"

# ─── build_fixture_repo <root>: isolated repo shape ─────────────────────────────────────────
# .claude/scripts/ with: the real reconcile-task-status.sh + update-task-status.sh +
# deploy-freshness-lib.sh (source-store-first), the real unchanged dependency chain
# (deploy-tree-first), and a STUB git-commit-scoped.sh that logs argv and exits 0.
build_fixture_repo() {
  local root="$1"
  mkdir -p "$root/.claude/scripts/lib" "$root/specs"
  cp "$RECONCILE_SRC" "$root/.claude/scripts/reconcile-task-status.sh"
  chmod +x "$root/.claude/scripts/reconcile-task-status.sh"
  cp "$UTS_SRC" "$root/.claude/scripts/update-task-status.sh"
  chmod +x "$root/.claude/scripts/update-task-status.sh"
  cp "$FRESHNESS_LIB_SRC" "$root/.claude/scripts/lib/deploy-freshness-lib.sh"
  for f in "${REQUIRED_SCRIPTS[@]}"; do
    cp "$DEPLOY_SCRIPTS_SRC/$f" "$root/.claude/scripts/$f"
    chmod +x "$root/.claude/scripts/$f"
  done
  for f in "${REQUIRED_LIBS[@]}"; do
    cp "$DEPLOY_SCRIPTS_SRC/lib/$f" "$root/.claude/scripts/lib/$f"
  done
  # Stub: the suite must never commit. Logs argv (space-joined) to GIT_COMMIT_SCOPED_STUB_LOG
  # when set, one line per invocation; always exits 0.
  cat > "$root/.claude/scripts/git-commit-scoped.sh" << 'STUBEOF'
#!/usr/bin/env bash
if [ -n "${GIT_COMMIT_SCOPED_STUB_LOG:-}" ]; then
  printf '%s\n' "$*" >> "$GIT_COMMIT_SCOPED_STUB_LOG"
fi
exit 0
STUBEOF
  chmod +x "$root/.claude/scripts/git-commit-scoped.sh"
}

# ─── build_source_and_extensions <root>: fabricated .claude-extensions.json plus a throwaway
# source-store stand-in repo with a committed "core" extension subdirectory. Returns (via
# globals) the source repo and its HEAD after the initial commit. Identical idiom to
# test-postflight-deploy-gate.sh's own helper of the same name. ────────────────────────────
SRC_REPO=""
SRC_HEAD_V1=""
build_source_and_extensions() {
  local root="$1"
  SRC_REPO="$root/source-repo"
  mkdir -p "$SRC_REPO/agent-system/extensions/core/scripts"
  git init -q "$SRC_REPO"
  git -C "$SRC_REPO" config user.email "test@example.com"
  git -C "$SRC_REPO" config user.name "Test"
  echo "v1" > "$SRC_REPO/agent-system/extensions/core/scripts/foo.sh"
  git -C "$SRC_REPO" add agent-system/extensions/core/scripts/foo.sh
  git -C "$SRC_REPO" commit -q -m "initial"
  SRC_HEAD_V1="$(git -C "$SRC_REPO" log -1 --format=%H -- "$SRC_REPO/agent-system/extensions")"
  cat > "$root/.claude-extensions.json" << EOF
{"version":"1.0.0","extensions":{"core":{"version":"1.0.0","source_dir":"${SRC_REPO}/agent-system/extensions/core","source_git_head":"${SRC_HEAD_V1}"}}}
EOF
}

# ─── add_task_entry <tasks_json_var_name> <num> <name> <status>: appends one active_projects
# entry (JSON) to the named shell variable holding a JSON array. ────────────────────────────
add_task_entry() {
  local -n _ate_arr="$1"
  local num="$2" name="$3" status="$4"
  _ate_arr="$(jq -n -c --argjson prev "$_ate_arr" --argjson n "$num" --arg name "$name" --arg s "$status" \
    '$prev + [{project_number:$n, project_name:$name, status:$s, task_type:"meta", next_artifact_number:2}]')"
}

# ─── write_state_json <root> <tasks_json> ────────────────────────────────────────────────────
write_state_json() {
  local root="$1" tasks_json="$2"
  jq -n -c --argjson tasks "$tasks_json" '{next_project_number: 99, active_projects: $tasks}' \
    > "$root/specs/state.json"
}

# ─── build_task_dir <root> <num> <name> [deploy_pending] [modified_files_json]: builds a
# complete "implementing, ready to promote" project directory -- plans/01_*.md with its single
# phase COMPLETED, summaries/01_*-summary.md, .orchestrator-handoff.json status=implemented,
# and .return-meta.json. deploy_pending defaults to "true"; modified_files_json defaults to an
# array overlapping agent-system/extensions/core/**. ─────────────────────────────────────────
build_task_dir() {
  local root="$1" num="$2" name="$3" deploy_pending="${4:-true}" modified_files_json="${5:-[\"agent-system/extensions/core/scripts/foo.sh\"]}"
  local padded task_dir
  padded=$(printf "%03d" "$num")
  task_dir="$root/specs/${padded}_${name}"
  mkdir -p "$task_dir/plans" "$task_dir/summaries"
  cat > "$task_dir/plans/01_fixture-plan.md" << 'PLANEOF'
# Implementation Plan: Fixture Project

- **Status**: [IMPLEMENTING]

## Implementation Phases

### Phase 1: Only phase [COMPLETED]
PLANEOF
  cat > "$task_dir/summaries/01_fixture-summary.md" << 'SUMEOF'
# Implementation Summary: Fixture Project

- **Status**: [COMPLETED]
SUMEOF
  cat > "$task_dir/.orchestrator-handoff.json" << 'HANDOFFEOF'
{"status": "implemented", "phases_completed": 1, "phases_total": 1, "summary": "fixture", "blockers": []}
HANDOFFEOF
  cat > "$task_dir/.return-meta.json" << EOF
{"status": "implemented", "deploy_pending": ${deploy_pending}, "modified_files": ${modified_files_json}}
EOF
}

# ─── drive_pass <fixture_root> <project_numbers_json> <post_deploy_json> <cycle> <out_prefix>:
# runs run_post_deploy_reconcile_pass() in an isolated subshell against the fixture, supplying
# exactly the globals it closes over (dry_run, cycle_count, session_id, SCRIPT_DIR, STATE_FILE,
# PROJECT_ROOT, post_deploy_reconcile_json, the mt_* family over an in-memory mt_json, and
# task_lookup_dir sourced from the fixture's own lib/task-lookup-lib.sh). Writes stdout to
# <out_prefix>.out, stderr to <out_prefix>.err, and the final mt_json to <out_prefix>.mt.json. ──
drive_pass() {
  local fixture_root="$1" task_numbers_json="$2" post_deploy_json="$3" cyc="$4" out_prefix="$5"
  (
    SCRIPT_DIR="$fixture_root/.claude/scripts"
    # shellcheck disable=SC2034  # read by run_post_deploy_reconcile_pass after it is sourced
    # below -- a closed-over global invisible to single-file static analysis, not dead code.
    STATE_FILE="$fixture_root/specs/state.json"
    # shellcheck disable=SC2034  # closed-over global, see STATE_FILE above
    PROJECT_ROOT="$fixture_root"
    dry_run=false
    # shellcheck disable=SC2034  # closed-over global, see STATE_FILE above
    cycle_count="$cyc"
    # shellcheck disable=SC2034  # closed-over global, see STATE_FILE above
    session_id="sess_test_redeploy_checkpoint"
    # shellcheck disable=SC2034  # closed-over global, see STATE_FILE above
    post_deploy_reconcile_json="$post_deploy_json"
    mt_state_file="$fixture_root/.mt-state.json"
    mt_json="$(jq -n -c --argjson tn "$task_numbers_json" \
      '{task_numbers: $tn, completed_tasks: [], post_deploy_reconcile_notices: [], cycle_modified_files: ["placeholder"], failed_tasks: []}')"

    # shellcheck disable=SC2329  # invoked indirectly by run_post_deploy_reconcile_pass once
    # sourced below, not a dead function -- mirrors orchestrate-cycle-plan.sh's own mt_* family.
    mt_save() { [ "$dry_run" = "true" ] && return 0; printf '%s\n' "$mt_json" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"; }
    # shellcheck disable=SC2329  # see mt_save above
    mt_get() { local argc="$#"; local filter="${!argc}"; echo "$mt_json" | jq -r "${@:1:$((argc-1))}" "$filter"; }
    # shellcheck disable=SC2329  # see mt_save above
    mt_get_json() { local argc="$#"; local filter="${!argc}"; echo "$mt_json" | jq -c "${@:1:$((argc-1))}" "$filter"; }
    # shellcheck disable=SC2329  # see mt_save above
    mt_set() { local argc="$#"; local filter="${!argc}"; mt_json=$(echo "$mt_json" | jq -c "${@:1:$((argc-1))}" "$filter"); }

    # shellcheck disable=SC1090,SC1091
    . "$fixture_root/.claude/scripts/lib/task-lookup-lib.sh"
    # shellcheck disable=SC1090
    . "$LIB_UNDER_TEST"

    run_post_deploy_reconcile_pass

    printf '%s\n' "$mt_json" > "${out_prefix}.mt.json"
  ) >"${out_prefix}.out" 2>"${out_prefix}.err"
}

task_status_in() { # <root> <num>
  jq -r --argjson n "$2" '.active_projects[] | select(.project_number == $n) | .status' "$1/specs/state.json" 2>/dev/null
}
deploy_pending_in() { # <root> <num> <name>
  local padded
  padded=$(printf "%03d" "$2")
  jq -r '.deploy_pending // false' "$1/specs/${padded}_$3/.return-meta.json" 2>/dev/null
}

# =====================================================================
# Case A (characterization -- must stay green both before and after the widening fix):
# in-batch candidate (post_deploy_reconcile_json=[1]), FRESH tree -> project 1 promoted to
# completed, a notice recorded, .completed_tasks contains 1.
# =====================================================================
info "=== Case A: in-batch candidate, FRESH tree -> promoted ==="
CASE_A_ROOT="$WORKDIR/caseA"
build_fixture_repo "$CASE_A_ROOT"
build_source_and_extensions "$CASE_A_ROOT"
build_task_dir "$CASE_A_ROOT" 1 "fixture_one"
TASKS_A='[]'
add_task_entry TASKS_A 1 "fixture_one" "implementing"
write_state_json "$CASE_A_ROOT" "$TASKS_A"

drive_pass "$CASE_A_ROOT" '[1]' '[1]' 1 "$WORKDIR/caseA_out"

a_status="$(task_status_in "$CASE_A_ROOT" 1)"
if [[ "$a_status" == "completed" ]]; then
  pass "Case A: in-batch candidate promoted to completed"
else
  fail "Case A: expected status 'completed' for project 1, got '$a_status' (see $WORKDIR/caseA_out.err)"
fi
if [[ -f "$WORKDIR/caseA_out.mt.json" ]] && jq -e '.completed_tasks == [1]' "$WORKDIR/caseA_out.mt.json" >/dev/null 2>&1; then
  pass "Case A: .completed_tasks contains the promoted project number"
else
  fail "Case A: .completed_tasks did not contain exactly [1] (see $WORKDIR/caseA_out.mt.json)"
fi
if [[ -f "$WORKDIR/caseA_out.mt.json" ]] && jq -e '.post_deploy_reconcile_notices | length >= 1' "$WORKDIR/caseA_out.mt.json" >/dev/null 2>&1; then
  pass "Case A: a post_deploy_reconcile_notices entry was recorded"
else
  fail "Case A: no post_deploy_reconcile_notices entry recorded (see $WORKDIR/caseA_out.mt.json)"
fi

# =====================================================================
# Pre-fix probe (NOT asserted -- this is the "fails before" evidence for the fail-before/
# pass-after demonstration, captured via info() so it is visible in the dispatch log
# regardless of which library (pristine or widened) this run happens to be exercising):
# out-of-batch candidate (post_deploy_reconcile_json=[], .task_numbers=[1], project 2
# deploy-pending, FRESH tree) -> against the UNMODIFIED library, project 2's status and
# deploy_pending marker are both expected to remain unchanged (structurally invisible to the
# invocation-scoped loop). A later addition to this suite turns this into assertions.
# =====================================================================
info "=== Pre-fix probe: out-of-batch candidate, FRESH tree (not asserted here) ==="
PROBE_ROOT="$WORKDIR/probe"
build_fixture_repo "$PROBE_ROOT"
build_source_and_extensions "$PROBE_ROOT"
build_task_dir "$PROBE_ROOT" 2 "fixture_two"
TASKS_PROBE='[]'
add_task_entry TASKS_PROBE 1 "fixture_one" "implementing"
add_task_entry TASKS_PROBE 2 "fixture_two" "implementing"
write_state_json "$PROBE_ROOT" "$TASKS_PROBE"

drive_pass "$PROBE_ROOT" '[1]' '[]' 1 "$WORKDIR/probe_out"

probe_status="$(task_status_in "$PROBE_ROOT" 2)"
probe_dp="$(deploy_pending_in "$PROBE_ROOT" 2 "fixture_two")"
info "Pre-fix probe result: project 2 status='${probe_status}' deploy_pending='${probe_dp}' (candidate set was post_deploy_reconcile_json=[] -- project 2 was never a member, so the unmodified library has no code path that can reach it)"
info "Pre-fix probe verbatim stderr:"
while IFS= read -r line; do info "    $line"; done < "$WORKDIR/probe_out.err" 2>/dev/null

echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
