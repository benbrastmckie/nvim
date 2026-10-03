#!/usr/bin/env bash
# test-skill-base-lifecycle.sh - Fixture-driven regression suite for scripts/skill-base.sh's
# highest-blast-radius state-mutating lifecycle functions: skill_preflight_update,
# skill_postflight_update, skill_gate_completion_claim, skill_link_artifacts, skill_cleanup.
#
# Of skill-base.sh's 17 top-level functions, only skill_corroborate_phase_counts had dedicated
# coverage prior to this suite (see test-corroborate-phase-counts.sh). This suite closes the
# largest remaining gap by covering the five functions named above; the other 11 remain
# uncovered residuals (see this suite's own header note below and the summary artifact this
# suite's authoring plan produces).
#
# Structural model: test-corroborate-phase-counts.sh (mktemp -d workdir with an EXIT-trap
# cleanup, deploy-tree-first / source-store-fallback candidate resolution, sourced -- not
# subprocessed -- skill-base.sh itself, pass()/fail()/info() helpers with integer counters, exit
# 0 all-pass / 1 any-fail / 2 environment error).
#
# ISOLATION CONTRACT (never touches the real specs/ tree, real state.json, or real task locks):
#   skill_gate_completion_claim and skill_cleanup are pure-logic/pure-filesystem functions tested
#   directly against a mktemp -d WORKDIR.
#   skill_link_artifacts is tested via a SKILL_REPO_ROOT override pointing at an isolated
#   mktemp -d fixture repo (skill_link_artifacts and skill_propagate_completion_summary route
#   every write through "${SKILL_REPO_ROOT}/.claude/scripts/state-write.sh" -- a
#   SKILL_REPO_ROOT-qualified path, not a bare relative one -- exactly the override this suite
#   relies on).
#   skill_preflight_update and skill_postflight_update hardcode the bare relative path
#   `.claude/scripts/update-task-status.sh` (NOT SKILL_REPO_ROOT-qualified, matching every real
#   SKILL.md call site's assumption that cwd == repo root under a live deploy). This suite
#   therefore builds a full isolated fixture repo under WORKDIR (a real .claude/scripts/ tree
#   copied from the deployed tree, plus a private specs/state.json and task directory) and `cd`s
#   into it before exercising those two functions, so the relative path resolves into the
#   fixture -- never into the real repo's .claude/ or specs/.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (a
# required library/script was not found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. A single
# fixed levels-up count cannot be correct for both depths at once, so resolve via the git
# worktree root first (depth-independent) and only fall back to the fixed-depth guess
# (matching the source-store depth) when SCRIPT_DIR is not inside a git work tree.
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

# ─── candidate resolution: deployed tree first, source-store fallback ─────────────────────────
resolve_candidate() {
  local desc="$1"; shift
  local candidate
  for candidate in "$@"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  echo "ERROR: $desc not found at any of:" >&2
  for candidate in "$@"; do
    echo "  $candidate" >&2
  done
  return 1
}

SKILL_BASE="$(resolve_candidate "skill-base.sh" \
  "$REPO_ROOT/.claude/scripts/skill-base.sh" \
  "$SCRIPT_DIR/../skill-base.sh")" || exit 2

DEPLOY_SCRIPTS_SRC="$REPO_ROOT/.claude/scripts"
if [[ ! -d "$DEPLOY_SCRIPTS_SRC" ]]; then
  echo "ERROR: deployed scripts tree not found at $DEPLOY_SCRIPTS_SRC -- this suite needs a" >&2
  echo "       real deployed .claude/scripts/ tree to copy update-task-status.sh's dependency" >&2
  echo "       chain (state-write.sh, task-lock.sh, deploy-root-guard.sh, update-plan-status.sh," >&2
  echo "       update-phase-status.sh, lib/*.sh) from." >&2
  exit 2
fi
for req in update-task-status.sh state-write.sh task-lock.sh generate-todo.sh deploy-root-guard.sh \
           update-plan-status.sh update-phase-status.sh; do
  if [[ ! -f "$DEPLOY_SCRIPTS_SRC/$req" ]]; then
    echo "ERROR: required deployed script missing: $DEPLOY_SCRIPTS_SRC/$req" >&2
    exit 2
  fi
done

# shellcheck disable=SC1090
. "$SKILL_BASE"

# ─── Harness sanity check: the task_dir_override (_task_dir) parameter added to
# skill_postflight_update must be present in the SKILL_BASE actually sourced above, or the
# exit-6 deploy-pending annotation cases in Group 4 below would silently exercise stale code and
# either report a misleading [FAIL] or fail in a confusing "command not found" way. This runs
# first, before any case executes, and exits 2 (environment error) rather than emitting a [FAIL]
# line -- matching this suite's own exit-2 convention for "a required library/script was not
# found." A stale deployed copy names its own path so the failure is actionable, not a bare
# "command not found". ───────────────────────────────────────────────────────────────────────
if ! grep -q '_task_dir' "$SKILL_BASE"; then
  echo "ERROR: sourced skill-base.sh ($SKILL_BASE) does not contain the task_dir_override" >&2
  echo "       change (grep for '_task_dir' found nothing) -- this is a STALE copy that" >&2
  echo "       predates that change. The exit-6 deploy-pending annotation cases in Group 4" >&2
  echo "       below cannot produce meaningful evidence against a stale copy. Re-deploy, or" >&2
  echo "       run the dedicated source-store harness instead (see the implementation plan's" >&2
  echo "       Phase 4 'Verification under a stale deploy' section)." >&2
  exit 2
fi
if ! declare -F skill_postflight_update >/dev/null 2>&1; then
  echo "ERROR: skill_postflight_update is not a defined function after sourcing $SKILL_BASE" >&2
  exit 2
fi

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

ORIG_PWD="$(pwd)"

# Baseline of the real specs/ tree, captured BEFORE any group runs. The contamination guard at
# the end of this suite compares against this baseline (a delta check), not against an assumed
# "must be empty" absolute state -- the real specs/ tree is routinely non-clean during a live
# session (this suite's own dispatch writes real progress/handoff/events.jsonl entries as a side
# effect of ordinary hook-driven event logging on every real tool call), so an absolute
# emptiness check would false-positive on that ambient, pre-existing dirt.
BASELINE_SPECS_STATUS="$(cd "$REPO_ROOT" && git status --short specs/ 2>/dev/null)"

# ─── build_fixture_repo: a full isolated repo shape under $1, real deployed scripts copied in ──
build_fixture_repo() {
  local root="$1"
  mkdir -p "$root/.claude/scripts/lib" "$root/specs"
  # update-plan-status.sh and update-phase-status.sh are required for Group 4's implement-target
  # case below to reach update_plan_file()'s plan-file logic at all -- without them,
  # update-task-status.sh's plan_script executability check early-returns with "not found or not
  # executable" and the case would pass vacuously even if a per-phase marker defect were present.
  # plan-file-scope-harvest.sh is required for the Group 4a plan-postflight file_scope harvest
  # cases below -- skill_postflight_update's plan branch calls it via the same hardcoded bare
  # relative path (`.claude/scripts/plan-file-scope-harvest.sh`) noted in this function's own
  # header comment, so without a copy here that branch would silently no-op (harvester not found)
  # rather than genuinely exercising the harvest.
  for f in update-task-status.sh state-write.sh task-lock.sh generate-todo.sh deploy-root-guard.sh \
           update-plan-status.sh update-phase-status.sh plan-file-scope-harvest.sh; do
    cp "$DEPLOY_SCRIPTS_SRC/$f" "$root/.claude/scripts/$f"
    chmod +x "$root/.claude/scripts/$f"
  done
  cp "$DEPLOY_SCRIPTS_SRC"/lib/*.sh "$root/.claude/scripts/lib/" 2>/dev/null || true
  cat > "$root/specs/state.json" << 'EOF'
{
  "next_project_number": 2,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "fixture_task",
      "status": "researched",
      "task_type": "general",
      "next_artifact_number": 1
    }
  ]
}
EOF
}

# ─── build_deploy_gate_source_repo <root>: fabricated .claude-extensions.json plus a throwaway
# source-store stand-in repo with a committed "core" extension subdirectory, advanced past its
# recorded head so update-task-status.sh's deploy-freshness comparison reports STALE for the
# "core" extension. Adapted from test-postflight-deploy-gate.sh's build_source_and_extensions
# helper (pattern source only -- that file is neither modified nor sourced here; the technique
# is reimplemented locally, scoped to Group 4's exit-6 cases below). ───────────────────────────
build_deploy_gate_source_repo() {
  local root="$1"
  local src_repo="$root/source-repo"
  mkdir -p "$src_repo/agent-system/extensions/core/scripts"
  git init -q "$src_repo"
  git -C "$src_repo" config user.email "test@example.com"
  git -C "$src_repo" config user.name "Test"
  echo "v1" > "$src_repo/agent-system/extensions/core/scripts/foo.sh"
  git -C "$src_repo" add agent-system/extensions/core/scripts/foo.sh
  git -C "$src_repo" commit -q -m "initial"
  local head_v1
  head_v1="$(git -C "$src_repo" log -1 --format=%H -- agent-system/extensions)"
  cat > "$root/.claude-extensions.json" << EOF
{"version":"1.0.0","extensions":{"core":{"version":"1.0.0","source_dir":"${src_repo}/agent-system/extensions/core","source_git_head":"${head_v1}"}}}
EOF
  # Advance the source repo without updating the recorded head -> STALE.
  echo "v2" > "$src_repo/agent-system/extensions/core/scripts/foo.sh"
  git -C "$src_repo" add agent-system/extensions/core/scripts/foo.sh
  git -C "$src_repo" commit -q -m "v2"
}

# ─── write_deploy_gate_return_meta <root>: a .return-meta.json whose modified_files overlaps
# agent-system/extensions/**, so the completion-deploy gate's overlap+STALE predicate fires. ───
write_deploy_gate_return_meta() {
  local root="$1"
  # build_fixture_repo above creates only specs/state.json, not a task directory (unlike
  # build_source_and_extensions's caller, test-postflight-deploy-gate.sh's build_fixture_repo,
  # which pre-creates specs/001_fixture_task/plans/). Create it here before writing into it.
  mkdir -p "$root/specs/001_fixture_task"
  cat > "$root/specs/001_fixture_task/.return-meta.json" << 'EOF'
{"status": "implemented", "modified_files": ["agent-system/extensions/core/scripts/foo.sh"]}
EOF
}

# =====================================================================
# Group 1: skill_gate_completion_claim -- pure logic, no I/O. All three cases plus the
# non-integer-input sanitization guard.
# =====================================================================
info "=== skill_gate_completion_claim ==="

if skill_gate_completion_claim 900 3 3 "absent" "[test]" 2>/tmp/sgcc-out.$$; then
  pass "Case 2: phases_completed >= phases_total (3/3) -> ALLOW (return 0)"
else
  fail "Case 2: phases_completed >= phases_total (3/3) -> expected ALLOW, got REFUSE"
fi
rm -f /tmp/sgcc-out.$$

if skill_gate_completion_claim 901 2 3 "absent" "[test]" 2>/dev/null; then
  fail "Case 1: phases_completed < phases_total (2/3) -> expected REFUSE, got ALLOW"
else
  pass "Case 1: phases_completed < phases_total (2/3) -> REFUSE (return 1)"
fi

if skill_gate_completion_claim 902 0 0 "true" "[test]" 2>/dev/null; then
  pass "Case 3 corroborated: phases_total=0, plan_markers_verified=true -> ALLOW (return 0)"
else
  fail "Case 3 corroborated: phases_total=0, plan_markers_verified=true -> expected ALLOW, got REFUSE"
fi

if skill_gate_completion_claim 903 0 0 "false" "[test]" 2>/dev/null; then
  fail "Case 3 uncorroborated: phases_total=0, plan_markers_verified=false -> expected REFUSE, got ALLOW"
else
  pass "Case 3 uncorroborated: phases_total=0, plan_markers_verified=false -> REFUSE (return 1)"
fi

# Failing-input case: non-integer phases_completed/phases_total must sanitize to 0 (fail closed
# to Case 3), never crash the -ge/-gt arithmetic under set -e.
if skill_gate_completion_claim 904 "not-a-number" "also-not-a-number" "false" "[test]" 2>/dev/null; then
  fail "Non-integer inputs sanitize to 0/0, plan_markers_verified=false -> expected REFUSE, got ALLOW"
else
  pass "Non-integer inputs sanitize to 0/0 (fail closed to Case 3) without an arithmetic crash"
fi

# =====================================================================
# Group 2: skill_cleanup -- removes .postflight-pending and .postflight-loop-guard only; must not
# error when they are already absent (the || true guard's own contract). Per skill_cleanup()'s
# own header comment in skill-base.sh (the contract narrowed by commit 75ec7bfa6):
#   "Removes .postflight-pending and .postflight-loop-guard only. .return-meta.json is NOT
#   removed here: ... Ownership of .return-meta.json's deletion belongs to the calling command's
#   own last step that consumes it."
# A positive control below asserts .return-meta.json survives, so a future re-narrowing or
# re-widening of this contract surfaces here immediately instead of silently drifting.
# =====================================================================
info "=== skill_cleanup ==="

CLEANUP_TASK_DIR="$WORKDIR/specs/002_cleanup_fixture"
mkdir -p "$CLEANUP_TASK_DIR"
touch "$CLEANUP_TASK_DIR/.postflight-pending" \
      "$CLEANUP_TASK_DIR/.postflight-loop-guard" \
      "$CLEANUP_TASK_DIR/.return-meta.json"
( cd "$WORKDIR" && skill_cleanup "002" "cleanup_fixture" )
if [[ ! -f "$CLEANUP_TASK_DIR/.postflight-pending" ]] && \
   [[ ! -f "$CLEANUP_TASK_DIR/.postflight-loop-guard" ]]; then
  pass "skill_cleanup removes both lifecycle temp files (.postflight-pending, .postflight-loop-guard)"
else
  fail "skill_cleanup left at least one lifecycle temp file behind"
fi

# Positive control: .return-meta.json is NOT deleted by skill_cleanup -- ownership of its
# deletion belongs to the calling command's own last step (see the quoted contract above).
if [[ -f "$CLEANUP_TASK_DIR/.return-meta.json" ]]; then
  pass "Positive control: skill_cleanup does not delete .return-meta.json (ownership stays with the caller)"
else
  fail "Positive control: .return-meta.json was deleted by skill_cleanup -- contract regression"
fi

# Failing/degenerate-input case: calling again on an already-clean directory must not error
# (rm -f ... || true is exactly this contract).
if ( cd "$WORKDIR" && skill_cleanup "002" "cleanup_fixture" ); then
  pass "skill_cleanup on an already-clean directory is a silent no-op (no error)"
else
  fail "skill_cleanup on an already-clean directory unexpectedly returned nonzero"
fi

# =====================================================================
# Group 2a: skill_lifecycle_notify -- regression coverage for the empty-status loud-failure guard
# (a real defect: 12 call sites once passed an undefined $STATE_STATUS, which bash silently
# expands to "", and skill_lifecycle_notify forwarded that empty string to lifecycle-notify.sh's
# own silent no-op branch -- six-plus weeks of every lifecycle TTS/tab-color announcement
# vanishing with zero observable trace). The guard below must be loud (stderr warning) and MUST
# NOT change skill_lifecycle_notify's never-blocking, always-returns-0 contract. Hardcodes the
# bare relative path ".claude/scripts/lifecycle-notify.sh", matching skill_preflight_update's own
# real-cwd assumption above -- isolated via a `cd` into a fixture dir, never touching the real
# repo's .claude/.
# =====================================================================
info "=== skill_lifecycle_notify ==="

LIFECYCLE_FIXTURE_DIR="$WORKDIR/lifecycle_fixture"
mkdir -p "$LIFECYCLE_FIXTURE_DIR/.claude/scripts"

# Empty-status case: must warn on stderr, must NOT invoke the notify script, and must still
# return 0 (never-blocking contract preserved).
LIFECYCLE_EMPTY_MARKER="$LIFECYCLE_FIXTURE_DIR/empty-invoked.marker"
cat > "$LIFECYCLE_FIXTURE_DIR/.claude/scripts/lifecycle-notify.sh" << EOF
#!/usr/bin/env bash
touch "$LIFECYCLE_EMPTY_MARKER"
EOF
chmod +x "$LIFECYCLE_FIXTURE_DIR/.claude/scripts/lifecycle-notify.sh"

LIFECYCLE_EMPTY_STDERR="$WORKDIR/lifecycle-empty-stderr.$$"
if ( cd "$LIFECYCLE_FIXTURE_DIR" && skill_lifecycle_notify "" ) 2>"$LIFECYCLE_EMPTY_STDERR"; then
  if grep -qi "skill_lifecycle_notify" "$LIFECYCLE_EMPTY_STDERR"; then
    pass "skill_lifecycle_notify \"\" warns on stderr naming the function, and returns success"
  else
    fail "skill_lifecycle_notify \"\" returned success but the stderr warning did not name the function"
  fi
else
  fail "skill_lifecycle_notify \"\" unexpectedly returned nonzero (breaks the never-blocking contract)"
fi
if [[ -f "$LIFECYCLE_EMPTY_MARKER" ]]; then
  fail "skill_lifecycle_notify \"\" invoked lifecycle-notify.sh despite the empty-argument guard"
else
  pass "skill_lifecycle_notify \"\" does not invoke lifecycle-notify.sh (guard short-circuits before the call)"
fi
rm -f "$LIFECYCLE_EMPTY_STDERR"

# Non-empty-status case: the guard must not regress the existing, working backgrounded-invocation
# path. skill_lifecycle_notify backgrounds the call (`&`), so poll briefly for the marker rather
# than assuming synchronous completion.
LIFECYCLE_REAL_MARKER="$LIFECYCLE_FIXTURE_DIR/real-invoked.marker"
rm -f "$LIFECYCLE_REAL_MARKER"
cat > "$LIFECYCLE_FIXTURE_DIR/.claude/scripts/lifecycle-notify.sh" << EOF
#!/usr/bin/env bash
echo "\$1" > "$LIFECYCLE_REAL_MARKER"
EOF
chmod +x "$LIFECYCLE_FIXTURE_DIR/.claude/scripts/lifecycle-notify.sh"
( cd "$LIFECYCLE_FIXTURE_DIR" && skill_lifecycle_notify "researched" )
lifecycle_wait_iter=0
while [[ ! -f "$LIFECYCLE_REAL_MARKER" ]] && [[ "$lifecycle_wait_iter" -lt 20 ]]; do
  sleep 0.1
  lifecycle_wait_iter=$((lifecycle_wait_iter + 1))
done
if [[ -f "$LIFECYCLE_REAL_MARKER" ]] && [[ "$(cat "$LIFECYCLE_REAL_MARKER")" == "researched" ]]; then
  pass "skill_lifecycle_notify \"researched\" still invokes lifecycle-notify.sh with the status argument (non-empty path unregressed)"
else
  fail "skill_lifecycle_notify \"researched\" did not invoke lifecycle-notify.sh as expected"
fi

# =====================================================================
# Group 3: skill_link_artifacts -- routed through SKILL_REPO_ROOT-qualified state-write.sh calls
# plus a generate-todo.sh regen. Isolated via SKILL_REPO_ROOT override; never touches the real
# specs/ tree.
# =====================================================================
info "=== skill_link_artifacts ==="

LINK_ROOT="$WORKDIR/link-fixture"
build_fixture_repo "$LINK_ROOT"
mkdir -p "$LINK_ROOT/specs/001_fixture_task/summaries"
cat > "$LINK_ROOT/specs/001_fixture_task/summaries/01_fixture-summary.md" << 'EOF'
# Implementation Summary: Fixture Task

- **Status**: [COMPLETED]
EOF

SKILL_REPO_ROOT="$LINK_ROOT" skill_link_artifacts 1 \
  "specs/001_fixture_task/summaries/01_fixture-summary.md" "summary" "Fixture summary" \
  "'**Summary**'" "'**Description**'" "sess_test_link" 2>"$WORKDIR/link-stderr.log"
LINK_EXIT=$?

if [[ "$LINK_EXIT" -eq 0 ]]; then
  registered=$(jq -r '.active_projects[0].artifacts // [] | length' "$LINK_ROOT/specs/state.json" 2>/dev/null)
  if [[ "$registered" == "1" ]]; then
    pass "skill_link_artifacts registers exactly one artifact entry in state.json"
  else
    fail "skill_link_artifacts: expected 1 artifact entry, found '$registered' (see $WORKDIR/link-stderr.log)"
  fi
  path_written=$(jq -r '.active_projects[0].artifacts[0].path // ""' "$LINK_ROOT/specs/state.json" 2>/dev/null)
  if [[ "$path_written" == "specs/001_fixture_task/summaries/01_fixture-summary.md" ]]; then
    pass "skill_link_artifacts writes the exact artifact path"
  else
    fail "skill_link_artifacts: path mismatch, got '$path_written'"
  fi
else
  fail "skill_link_artifacts exited $LINK_EXIT (see $WORKDIR/link-stderr.log)"
fi

# Failing-input case: empty artifact_path is a documented no-op guard (the `[ -n "$artifact_path" ]`
# gate) -- must not attempt a write or error.
BEFORE_COUNT=$(jq -r '.active_projects[0].artifacts // [] | length' "$LINK_ROOT/specs/state.json" 2>/dev/null)
SKILL_REPO_ROOT="$LINK_ROOT" skill_link_artifacts 1 "" "summary" "" "'**Summary**'" "'**Description**'" "sess_test_link" 2>/dev/null
AFTER_COUNT=$(jq -r '.active_projects[0].artifacts // [] | length' "$LINK_ROOT/specs/state.json" 2>/dev/null)
if [[ "$BEFORE_COUNT" == "$AFTER_COUNT" ]]; then
  pass "skill_link_artifacts with an empty artifact_path is a no-op (artifact count unchanged: $BEFORE_COUNT)"
else
  fail "skill_link_artifacts with an empty artifact_path unexpectedly changed artifact count ($BEFORE_COUNT -> $AFTER_COUNT)"
fi

# =====================================================================
# Group 4: skill_preflight_update / skill_postflight_update -- hardcode the bare relative path
# .claude/scripts/update-task-status.sh, so this group cd's into a full fixture repo.
# =====================================================================
info "=== skill_preflight_update / skill_postflight_update ==="

LIFECYCLE_ROOT="$WORKDIR/lifecycle-fixture"
build_fixture_repo "$LIFECYCLE_ROOT"

cd "$LIFECYCLE_ROOT" || { fail "could not cd into lifecycle fixture repo"; }

skill_preflight_update 1 "plan" "sess_test_preflight" 2>"$WORKDIR/preflight-stderr.log"
PREFLIGHT_EXIT=$?
if [[ "$PREFLIGHT_EXIT" -eq 0 ]]; then
  new_status=$(jq -r '.active_projects[0].status' "$LIFECYCLE_ROOT/specs/state.json" 2>/dev/null)
  if [[ "$new_status" == "planning" ]]; then
    pass "skill_preflight_update transitions researched -> planning for a plan preflight"
  else
    fail "skill_preflight_update: expected status 'planning', got '$new_status' (see $WORKDIR/preflight-stderr.log)"
  fi
else
  fail "skill_preflight_update exited $PREFLIGHT_EXIT (see $WORKDIR/preflight-stderr.log)"
fi

skill_postflight_update 1 "plan" "sess_test_preflight" "planned" 2>"$WORKDIR/postflight-stderr.log"
POSTFLIGHT_EXIT=$?
if [[ "$POSTFLIGHT_EXIT" -eq 0 ]]; then
  new_status=$(jq -r '.active_projects[0].status' "$LIFECYCLE_ROOT/specs/state.json" 2>/dev/null)
  if [[ "$new_status" == "planned" ]]; then
    pass "skill_postflight_update transitions planning -> planned on a successful plan postflight"
  else
    fail "skill_postflight_update: expected status 'planned', got '$new_status' (see $WORKDIR/postflight-stderr.log)"
  fi
else
  fail "skill_postflight_update exited $POSTFLIGHT_EXIT (see $WORKDIR/postflight-stderr.log)"
fi

# Failing/degenerate-input case: a non-success status must SKIP the update-task-status.sh call
# entirely (the case "$status" in researched|planned|implemented) guard) and never touch
# state.json -- status stays exactly as it was left by the prior postflight above.
BEFORE_STATUS=$(jq -r '.active_projects[0].status' "$LIFECYCLE_ROOT/specs/state.json" 2>/dev/null)
skill_postflight_update 1 "plan" "sess_test_preflight" "blocked" 2>/dev/null
AFTER_STATUS=$(jq -r '.active_projects[0].status' "$LIFECYCLE_ROOT/specs/state.json" 2>/dev/null)
if [[ "$BEFORE_STATUS" == "$AFTER_STATUS" ]]; then
  pass "skill_postflight_update with a non-success status ('blocked') skips the status write (unchanged: $AFTER_STATUS)"
else
  fail "skill_postflight_update with a non-success status unexpectedly changed state.json ($BEFORE_STATUS -> $AFTER_STATUS)"
fi

cd "$ORIG_PWD" || true

# =====================================================================
# Group 4a: skill_postflight_update's plan-branch file_scope harvest. skill_postflight_update is
# the ACTUALLY-LIVE plan-postflight path (called from orchestrate-cycle-postflight.sh and
# orchestrate-stage5-postflight.sh -- orchestrator-postflight.sh's own "research and plan only"
# Stage 7 branch has no live callers, see that script's own header note), so this is the site
# that matters for real /orchestrate plan-postflight runs, distinct from and in addition to
# orchestrator-postflight.sh's own branch.
# =====================================================================
info "=== skill_postflight_update (plan-branch file_scope harvest) ==="

HARVEST_ROOT="$WORKDIR/harvest-fixture"
build_fixture_repo "$HARVEST_ROOT"
mkdir -p "$HARVEST_ROOT/specs/001_fixture_task/plans"
cat > "$HARVEST_ROOT/specs/001_fixture_task/plans/01_fixture-plan.md" << 'PLANEOF'
### Phase 1: Example [NOT STARTED]

**Files to modify**:
- `scripts/harvested-one.sh` - added by the harvest test fixture
- `scripts/harvested-two.sh`

**Verification**:
- ok
PLANEOF

cd "$HARVEST_ROOT" || { fail "could not cd into harvest fixture repo"; }
skill_postflight_update 1 "plan" "sess_test_harvest" "planned" "" "specs/001_fixture_task" \
  2>"$WORKDIR/harvest-postflight-stderr.log"
HARVEST_POSTFLIGHT_EXIT=$?
HARVEST_FILE_SCOPE="$(jq -c '.active_projects[0].file_scope' "$HARVEST_ROOT/specs/state.json" 2>/dev/null)"
if [[ "$HARVEST_POSTFLIGHT_EXIT" -eq 0 ]]; then
  pass "skill_postflight_update (plan, with a real plan file): exits 0"
else
  fail "skill_postflight_update (plan, with a real plan file) exited $HARVEST_POSTFLIGHT_EXIT (see $WORKDIR/harvest-postflight-stderr.log)"
fi
if [[ "$(echo "$HARVEST_FILE_SCOPE" | jq -c 'sort')" == '["scripts/harvested-one.sh","scripts/harvested-two.sh"]' ]]; then
  pass "skill_postflight_update (plan): file_scope harvested from the plan's Files to modify field ($HARVEST_FILE_SCOPE)"
else
  fail "skill_postflight_update (plan): expected file_scope [\"scripts/harvested-one.sh\",\"scripts/harvested-two.sh\"], got '$HARVEST_FILE_SCOPE' (see $WORKDIR/harvest-postflight-stderr.log)"
fi
cd "$ORIG_PWD" || true

# --- Degenerate case: no plans/ directory at all -- file_scope stays absent/null, never [] ----
NOPLAN_ROOT="$WORKDIR/harvest-noplan-fixture"
build_fixture_repo "$NOPLAN_ROOT"
cd "$NOPLAN_ROOT" || { fail "could not cd into no-plan harvest fixture repo"; }
skill_postflight_update 1 "plan" "sess_test_harvest_noplan" "planned" "" "specs/001_fixture_task" \
  2>"$WORKDIR/harvest-noplan-postflight-stderr.log"
NOPLAN_FILE_SCOPE="$(jq -c '.active_projects[0].file_scope' "$NOPLAN_ROOT/specs/state.json" 2>/dev/null)"
if [[ "$NOPLAN_FILE_SCOPE" == "null" ]]; then
  pass "skill_postflight_update (plan, no plans/ dir): file_scope stays absent (null), no bogus [] written"
else
  fail "skill_postflight_update (plan, no plans/ dir): expected file_scope null, got '$NOPLAN_FILE_SCOPE' (see $WORKDIR/harvest-noplan-postflight-stderr.log)"
fi
cd "$ORIG_PWD" || true

# =====================================================================
# Group 4b: per-dispatch deploy-freshness surface inside skill_preflight_update (see
# skill-base.sh's own deploy-freshness-lib.sh sourcing block and skill_deploy_freshness_stale_names
# helper). Three cases: WARN-and-parity (stale extension present, everything else on the same
# call still runs), silence (no .claude-extensions.json at all -- the CANNOTVERIFY shape must
# never read as an alarm), and no-abort-on-missing-library (a fresh bash -c subprocess, since the
# library is already defined process-wide in THIS suite's own shell from the top-of-file source
# and removing a fixture's on-disk copy cannot undefine an already-defined shell function).
# =====================================================================
info "=== skill_preflight_update (deploy-freshness surface) ==="

# --- Case: WARN present, naming the stale extension, AND the rest of the call still runs
# (status write + reaches the same trailing lifecycle-event code as the clean path) ------------
FRESHNESS_WARN_ROOT="$WORKDIR/freshness-warn-fixture"
build_fixture_repo "$FRESHNESS_WARN_ROOT"
build_deploy_gate_source_repo "$FRESHNESS_WARN_ROOT"

# NOTE: SKILL_REPO_ROOT is exported ONCE, process-wide, when skill-base.sh was sourced at the
# top of this file (its own BASH_SOURCE-derived default) and is NOT updated by a bare `cd` --
# only the hardcoded-relative-path calls inside skill_preflight_update (documented at this
# suite's own top) resolve via cwd. skill_deploy_freshness_stale_names deliberately reads
# $SKILL_REPO_ROOT (never a relative path, by skill-base.sh's own design), so it must be
# overridden per-call here exactly like Group 3's skill_link_artifacts calls above -- omitting
# this override would silently check the REAL repo's own .claude-extensions.json instead of the
# fixture's fabricated one.
cd "$FRESHNESS_WARN_ROOT" || fail "could not cd into freshness-warn fixture repo"
SKILL_REPO_ROOT="$FRESHNESS_WARN_ROOT" skill_preflight_update 1 "plan" "sess_test_freshness_warn" 2>"$WORKDIR/freshness-warn-stderr.log"
FRESHNESS_WARN_EXIT=$?
FRESHNESS_WARN_STDERR="$(cat "$WORKDIR/freshness-warn-stderr.log")"
cd "$ORIG_PWD" || true

if [[ "$FRESHNESS_WARN_EXIT" -eq 0 ]]; then
  pass "skill_preflight_update (stale 'core' extension): still returns 0"
else
  fail "skill_preflight_update (stale 'core' extension): unexpectedly exited $FRESHNESS_WARN_EXIT"
fi
if printf '%s' "$FRESHNESS_WARN_STDERR" | grep -qi "deployed .claude/ tree is STALE.*extension(s): core"; then
  pass "skill_preflight_update (stale 'core' extension): emits the named WARN block on stderr"
else
  fail "skill_preflight_update (stale 'core' extension): expected a WARN naming 'core', got: $FRESHNESS_WARN_STDERR"
fi
FRESHNESS_WARN_STATUS="$(jq -r '.active_projects[0].status' "$FRESHNESS_WARN_ROOT/specs/state.json" 2>/dev/null)"
if [[ "$FRESHNESS_WARN_STATUS" == "planning" ]]; then
  pass "skill_preflight_update (stale 'core' extension): status write still ran (researched -> planning) alongside the WARN"
else
  fail "skill_preflight_update (stale 'core' extension): expected status write to still reach 'planning', got '$FRESHNESS_WARN_STATUS'"
fi
# _events_append_observable's own stderr WARNING is one-time-per-process (a module-level
# _EVENTS_APPEND_OBSERVABLE_WARNED guard -- see skill-base.sh's own comment on that function), so
# it will already have fired silently-once during the EARLIER Group 4 preflight/postflight cases
# in this same suite process; asserting on stderr text here would false-negative. Its
# unconditional sentinel-log append (gated only on "kind" being non-empty, never on the
# one-time-warned flag) is the reliable proxy that execution actually reached this trailing call.
if [[ -f "$FRESHNESS_WARN_ROOT/.claude/tmp/events-append-observable.log" ]]; then
  pass "skill_preflight_update (stale 'core' extension): execution still reaches the trailing lifecycle-event call (same as the clean path)"
else
  fail "skill_preflight_update (stale 'core' extension): did not reach the trailing lifecycle-event call -- the WARN may have short-circuited the rest of the function"
fi

# --- Case: silence when there is no .claude-extensions.json at all (CANNOTVERIFY must never
# read as an alarm) -------------------------------------------------------------------------
FRESHNESS_NOEXT_ROOT="$WORKDIR/freshness-noext-fixture"
build_fixture_repo "$FRESHNESS_NOEXT_ROOT"
# build_fixture_repo deliberately never writes a .claude-extensions.json; confirm that hypothesis
# rather than assuming it, since a silent future change to that helper would invalidate this case.
if [[ -f "$FRESHNESS_NOEXT_ROOT/.claude-extensions.json" ]]; then
  fail "freshness silence case: fixture setup assumption broken -- build_fixture_repo now writes .claude-extensions.json"
fi

cd "$FRESHNESS_NOEXT_ROOT" || fail "could not cd into freshness-noext fixture repo"
SKILL_REPO_ROOT="$FRESHNESS_NOEXT_ROOT" skill_preflight_update 1 "plan" "sess_test_freshness_noext" 2>"$WORKDIR/freshness-noext-stderr.log"
FRESHNESS_NOEXT_EXIT=$?
FRESHNESS_NOEXT_STDERR="$(cat "$WORKDIR/freshness-noext-stderr.log")"
cd "$ORIG_PWD" || true

if [[ "$FRESHNESS_NOEXT_EXIT" -eq 0 ]] && ! printf '%s' "$FRESHNESS_NOEXT_STDERR" | grep -qi "deployed .claude/ tree is STALE"; then
  pass "skill_preflight_update (no .claude-extensions.json): silent on the freshness surface, still returns 0 (CANNOTVERIFY never reads as an alarm)"
else
  fail "skill_preflight_update (no .claude-extensions.json): expected silence and exit 0, got rc=$FRESHNESS_NOEXT_EXIT stderr=$FRESHNESS_NOEXT_STDERR"
fi

# --- Case: no-abort when the library is not resolvable at either candidate path. Must run in a
# FRESH bash -c subprocess: this suite's own top-of-file `. "$SKILL_BASE"` already defined
# deploy_freshness_stale_names process-wide, so removing a fixture's on-disk copy cannot
# undefine it within the SAME shell. -----------------------------------------------------------
FRESHNESS_NOLIB_ROOT="$WORKDIR/freshness-nolib-fixture"
mkdir -p "$FRESHNESS_NOLIB_ROOT/.claude/scripts" "$FRESHNESS_NOLIB_ROOT/specs"
cp "$SKILL_BASE" "$FRESHNESS_NOLIB_ROOT/.claude/scripts/skill-base.sh"
echo '{"active_projects": []}' > "$FRESHNESS_NOLIB_ROOT/specs/state.json"
# Deliberately no .claude/scripts/lib/ directory at all -- both of skill-base.sh's own candidate
# paths (SKILL_REPO_ROOT-qualified and BASH_SOURCE-relative) resolve underneath this same fixture
# root, so omitting lib/ entirely fails both, reproducing "library not resolvable at either
# candidate path."

NOLIB_STDOUT_FILE="$WORKDIR/freshness-nolib-stdout.log"
if SKILL_REPO_ROOT="$FRESHNESS_NOLIB_ROOT" bash -c '
  set -euo pipefail
  cd "$SKILL_REPO_ROOT"
  # shellcheck disable=SC1091
  source "$SKILL_REPO_ROOT/.claude/scripts/skill-base.sh"
  skill_preflight_update 9999 research sess_test_nolib
  echo "SUBPROCESS_REACHED_END"
' >"$NOLIB_STDOUT_FILE" 2>"$WORKDIR/freshness-nolib-stderr.log"; then
  NOLIB_RC=0
else
  NOLIB_RC=$?
fi
if [[ "$NOLIB_RC" -eq 0 ]] && grep -q "SUBPROCESS_REACHED_END" "$NOLIB_STDOUT_FILE"; then
  pass "skill_preflight_update under set -e with the freshness library unresolvable at either candidate path: does not abort the caller"
else
  fail "skill_preflight_update under set -e with the freshness library unresolvable: caller aborted (rc=$NOLIB_RC); see $WORKDIR/freshness-nolib-stderr.log"
fi

# --- Assert no code path added for this surface writes specs/.freshness-warn-streak.json (that
# counter is a consecutive-COMMAND-invocation count owned exclusively by check-deploy-freshness.sh;
# skill_preflight_update must never touch it). Checked across every fixture root used in this
# group, including the WARN case (which is the one most likely to accidentally touch it). ------
STREAK_TOUCHED=false
for _fr in "$FRESHNESS_WARN_ROOT" "$FRESHNESS_NOEXT_ROOT" "$FRESHNESS_NOLIB_ROOT"; do
  if [[ -f "$_fr/specs/.freshness-warn-streak.json" ]]; then
    STREAK_TOUCHED=true
  fi
done
if [[ "$STREAK_TOUCHED" == "false" ]]; then
  pass "skill_preflight_update's deploy-freshness surface never writes specs/.freshness-warn-streak.json"
else
  fail "skill_preflight_update's deploy-freshness surface unexpectedly wrote specs/.freshness-warn-streak.json in at least one fixture"
fi

# =====================================================================
# Group 4 (exit-6 deploy-pending annotation): skill_postflight_update's task_dir_override
# parameter (this task's own fix) must reach the exit-6 deploy-pending annotation block without
# relying on the ambient TASK_DIR variable, which /orchestrate's own postflight call sites never
# set. Each case builds its own isolated fixture root (overlap+STALE deploy-gate technique
# adapted from test-postflight-deploy-gate.sh's Case 1 -- that file is not modified), cd's into
# it (skill_postflight_update hardcodes the bare relative path, same discipline as the plain
# Group 4 cases above), and restores $ORIG_PWD afterward. No SKILL_REPO_ROOT override is used.
# =====================================================================
info "=== skill_postflight_update (exit-6 deploy-pending annotation) ==="

# --- Primary case: 6th positional supplied, TASK_DIR unset (the /orchestrate condition) ---
DEPLOY_GATE_ROOT="$WORKDIR/deploy-gate-fixture"
build_fixture_repo "$DEPLOY_GATE_ROOT"
build_deploy_gate_source_repo "$DEPLOY_GATE_ROOT"
write_deploy_gate_return_meta "$DEPLOY_GATE_ROOT"

cd "$DEPLOY_GATE_ROOT" || { fail "could not cd into deploy-gate fixture repo (primary case)"; }
unset TASK_DIR
skill_postflight_update 1 "implement" "sess_test_deploygate_primary" "implemented" "" \
  "specs/001_fixture_task" 2>"$WORKDIR/deploygate-primary-stderr.log"
DG_PRIMARY_EXIT=$?
cd "$ORIG_PWD" || true

if [[ "$DG_PRIMARY_EXIT" -eq 6 ]]; then
  pass "Primary case: exit-6 deploy-pending refusal reached (6th arg supplied, TASK_DIR unset)"
else
  fail "Primary case: expected exit 6, got $DG_PRIMARY_EXIT (see $WORKDIR/deploygate-primary-stderr.log)"
fi
DG_PRIMARY_PENDING="$(jq -r '.deploy_pending // "MISSING"' "$DEPLOY_GATE_ROOT/specs/001_fixture_task/.return-meta.json" 2>/dev/null)"
if [[ "$DG_PRIMARY_PENDING" == "true" ]]; then
  pass "Primary case: .return-meta.json gains deploy_pending == true"
else
  fail "Primary case: expected deploy_pending == true, got '$DG_PRIMARY_PENDING'"
fi
DG_PRIMARY_REASON="$(jq -r '.deploy_pending_reason // "MISSING"' "$DEPLOY_GATE_ROOT/specs/001_fixture_task/.return-meta.json" 2>/dev/null)"
if [[ -n "$DG_PRIMARY_REASON" && "$DG_PRIMARY_REASON" != "MISSING" && "$DG_PRIMARY_REASON" != "null" ]]; then
  pass "Primary case: deploy_pending_reason is a non-null, non-empty string"
else
  fail "Primary case: deploy_pending_reason missing/null/empty (got '$DG_PRIMARY_REASON')"
fi

# --- Regression-guard case: 6th arg omitted, TASK_DIR exported (the legacy skill-context path) ---
DEPLOY_GATE_ROOT2="$WORKDIR/deploy-gate-fixture-legacy"
build_fixture_repo "$DEPLOY_GATE_ROOT2"
build_deploy_gate_source_repo "$DEPLOY_GATE_ROOT2"
write_deploy_gate_return_meta "$DEPLOY_GATE_ROOT2"

cd "$DEPLOY_GATE_ROOT2" || { fail "could not cd into deploy-gate fixture repo (legacy case)"; }
export TASK_DIR="specs/001_fixture_task"
skill_postflight_update 1 "implement" "sess_test_deploygate_legacy" "implemented" \
  2>"$WORKDIR/deploygate-legacy-stderr.log"
DG_LEGACY_EXIT=$?
unset TASK_DIR
cd "$ORIG_PWD" || true

if [[ "$DG_LEGACY_EXIT" -eq 6 ]]; then
  pass "Regression-guard case: exit-6 reached with 6th arg omitted, TASK_DIR exported (legacy path)"
else
  fail "Regression-guard case: expected exit 6, got $DG_LEGACY_EXIT (see $WORKDIR/deploygate-legacy-stderr.log)"
fi
DG_LEGACY_PENDING="$(jq -r '.deploy_pending // "MISSING"' "$DEPLOY_GATE_ROOT2/specs/001_fixture_task/.return-meta.json" 2>/dev/null)"
if [[ "$DG_LEGACY_PENDING" == "true" ]]; then
  pass "Regression-guard case: the default \${6:-\${TASK_DIR:-}} default still reaches the annotation block"
else
  fail "Regression-guard case: expected deploy_pending == true, got '$DG_LEGACY_PENDING'"
fi

# --- Non-blocking case: neither the 6th argument nor TASK_DIR is set -- still returns 6, never
# errors or crashes (the annotation block stays best-effort). ---
DEPLOY_GATE_ROOT3="$WORKDIR/deploy-gate-fixture-noannotation"
build_fixture_repo "$DEPLOY_GATE_ROOT3"
build_deploy_gate_source_repo "$DEPLOY_GATE_ROOT3"
write_deploy_gate_return_meta "$DEPLOY_GATE_ROOT3"

cd "$DEPLOY_GATE_ROOT3" || { fail "could not cd into deploy-gate fixture repo (non-blocking case)"; }
unset TASK_DIR
skill_postflight_update 1 "implement" "sess_test_deploygate_noannotation" "implemented" \
  2>"$WORKDIR/deploygate-noannotation-stderr.log"
DG_NOANNOTATION_EXIT=$?
cd "$ORIG_PWD" || true

if [[ "$DG_NOANNOTATION_EXIT" -eq 6 ]]; then
  pass "Non-blocking case: still returns 6 with neither the 6th argument nor TASK_DIR set (no crash)"
else
  fail "Non-blocking case: expected exit 6, got $DG_NOANNOTATION_EXIT (see $WORKDIR/deploygate-noannotation-stderr.log)"
fi

# =====================================================================
# Group 4 (implement-target case): skill_preflight_update against target_status="implement" with
# a fixture that actually contains a plan file -- the coverage gap this suite's authoring plan
# names explicitly. Every prior Group 4 case above passes only "plan", which never reaches
# update_plan_file()'s plan-file logic at all (that function early-returns unless
# target_status == "implement"), so this is the first case in this suite that can regress the
# preflight phase auto-advance convenience that plan deletes. Uses its own fixture root, isolated
# from the "plan"-target cases above.
# =====================================================================
info "=== skill_preflight_update (target_status=implement, with a real plan file) ==="

IMPLEMENT_ROOT="$WORKDIR/lifecycle-implement-fixture"
build_fixture_repo "$IMPLEMENT_ROOT"
# Routed through the fixture's own copy of state-write.sh (the sanctioned state.json writer)
# rather than a hand-rolled `jq ... > tmp && mv` sequence -- see
# scripts/lint/lint-state-writer-boundary.sh's boundary contract, which this suite is not
# exempt from (unlike test-update-task-status.sh's deliberate corrupt-state fixture).
"$IMPLEMENT_ROOT/.claude/scripts/state-write.sh" '.active_projects[0].status = "planned"' \
  --session-id "sess_test_implement_setup"
mkdir -p "$IMPLEMENT_ROOT/specs/001_fixture_task/plans"
cat > "$IMPLEMENT_ROOT/specs/001_fixture_task/plans/01_fixture-plan.md" << 'PLANEOF'
# Implementation Plan: Fixture Task

- **Status**: [NOT STARTED]

## Implementation Phases

### Phase 1: First phase [NOT STARTED]

### Phase 2: Second phase [NOT STARTED]
PLANEOF
IMPLEMENT_PLAN="$IMPLEMENT_ROOT/specs/001_fixture_task/plans/01_fixture-plan.md"
BEFORE_IMPLEMENT_HEADINGS="$(grep -E '^### Phase ' "$IMPLEMENT_PLAN")"

cd "$IMPLEMENT_ROOT" || { fail "could not cd into implement-target fixture repo"; }
skill_preflight_update 1 "implement" "sess_test_implement" 2>"$WORKDIR/implement-preflight-stderr.log"
IMPLEMENT_PREFLIGHT_EXIT=$?
cd "$ORIG_PWD" || true

AFTER_IMPLEMENT_HEADINGS="$(grep -E '^### Phase ' "$IMPLEMENT_PLAN")"

if [[ "$BEFORE_IMPLEMENT_HEADINGS" == "$AFTER_IMPLEMENT_HEADINGS" ]]; then
  pass "skill_preflight_update (implement) leaves plan phase headings byte-identical (no dispatch, no advance)"
else
  fail "skill_preflight_update (implement) changed phase headings unexpectedly -- before:
$BEFORE_IMPLEMENT_HEADINGS
-- after:
$AFTER_IMPLEMENT_HEADINGS"
fi

if grep -q '\[IN PROGRESS\]' "$IMPLEMENT_PLAN"; then
  fail "skill_preflight_update (implement) left a phase heading marked [IN PROGRESS] -- the deleted auto-advance regressed"
else
  pass "no phase heading contains [IN PROGRESS] after skill_preflight_update (implement)"
fi

# Positive control (required): proves the wrapper actually reached update_plan_file()'s
# plan-file logic -- without this, the assertions above would pass even if
# update-plan-status.sh/update-phase-status.sh were still missing from build_fixture_repo's copy
# loop and the plan-file write never happened at all.
if [[ "$IMPLEMENT_PREFLIGHT_EXIT" -eq 0 ]]; then
  new_implement_status=$(jq -r '.active_projects[0].status' "$IMPLEMENT_ROOT/specs/state.json" 2>/dev/null)
  if [[ "$new_implement_status" == "implementing" ]]; then
    pass "Positive control: skill_preflight_update (implement) moved state.json status to 'implementing'"
  else
    fail "Positive control: expected state.json status 'implementing', got '$new_implement_status' (see $WORKDIR/implement-preflight-stderr.log)"
  fi
else
  fail "skill_preflight_update (implement) exited $IMPLEMENT_PREFLIGHT_EXIT (see $WORKDIR/implement-preflight-stderr.log)"
fi
if grep -qE '^- \*\*Status\*\*: \[IMPLEMENTING\]' "$IMPLEMENT_PLAN"; then
  pass "Positive control: plan-level Status line flipped to [IMPLEMENTING] (update_plan_file() was entered, plan file was found)"
else
  fail "Positive control: plan-level Status line did not flip to [IMPLEMENTING] -- the byte-identity assertions above would be vacuous"
fi

# =====================================================================
# Group 5: skill_get_extension_dir / skill_run_extension_hook -- the extension lifecycle hook
# mechanism's resolver and invocation functions.
#
# SOURCE-STORE-FIRST resolution, deliberately the REVERSE of this suite's own default
# (deployed-tree-first, source-store-fallback) candidate order used for SKILL_BASE above. The
# functions under test here are being changed IN THE SOURCE STORE by the authoring task; the
# deployed copy at .claude/scripts/skill-base.sh is regenerated only by a separate, later
# operator action (<leader>al "Reload All", or deploy-headless.sh) that this task deliberately
# does not perform. A deploy-first resolution would therefore silently exercise the OLD,
# unchanged deployed code and report a misleading PASS here -- exactly the hazard this suite's
# own stale-deploy harness guard above (the "_task_dir" grep, which exits 2 rather than letting a
# stale copy report a false PASS) already exists to prevent, just applied in the opposite
# direction. Each case below sources its chosen copy inside its OWN subshell (never at suite
# level), so the suite-level SKILL_BASE-sourced functions used by every other group above remain
# completely untouched.
# =====================================================================
info "=== skill_get_extension_dir / skill_run_extension_hook (source-store-first) ==="

HOOK_SKILL_BASE="$(resolve_candidate "skill-base.sh (source-store-first, for the hook mechanism group)" \
  "$SCRIPT_DIR/../skill-base.sh" \
  "$REPO_ROOT/.claude/scripts/skill-base.sh")" || exit 2
info "Group 5 exercises: $HOOK_SKILL_BASE"

# ─── fixture: a real object-schema .claude-extensions.json joined with per-extension manifests ──
HOOK_ROOT="$WORKDIR/hook-fixture"
mkdir -p "$HOOK_ROOT/.claude/extensions/fixtureext" "$HOOK_ROOT/.claude/extensions/inactiveext" \
  "$HOOK_ROOT/.claude/scripts"
cat > "$HOOK_ROOT/.claude-extensions.json" << 'EOF'
{"version":"1.0.0","extensions":{"fixtureext":{"status":"active"},"inactiveext":{"status":"inactive"}}}
EOF
cat > "$HOOK_ROOT/.claude/extensions/fixtureext/manifest.json" << 'EOF'
{
  "task_type": "hookfixturetype",
  "hooks": {
    "preflight": "hook-sentinel.sh",
    "postflight": "scripts/hook-sentinel.sh",
    "context_injection": "scripts/hook-badrc.sh",
    "verification": "scripts/does-not-exist.sh"
  }
}
EOF
cat > "$HOOK_ROOT/.claude/extensions/inactiveext/manifest.json" << 'EOF'
{"task_type": "inactivetype", "hooks": {}}
EOF
cat > "$HOOK_ROOT/.claude/scripts/hook-sentinel.sh" << EOF
#!/usr/bin/env bash
echo "sentinel" > "$WORKDIR/hook-sentinel-fired"
exit 0
EOF
cat > "$HOOK_ROOT/.claude/scripts/hook-badrc.sh" << 'EOF'
#!/usr/bin/env bash
exit 7
EOF
chmod +x "$HOOK_ROOT/.claude/scripts/hook-sentinel.sh" "$HOOK_ROOT/.claude/scripts/hook-badrc.sh"

HOOK_NOEXT_ROOT="$WORKDIR/hook-noext-fixture"
mkdir -p "$HOOK_NOEXT_ROOT"

# ─── subshell helpers: source HOOK_SKILL_BASE fresh inside the subshell each time, never at suite
# level, so these cases can never leak their resolution order into any later group. ────────────
run_resolver_case() {
  local fixture_root="$1" task_type="$2"
  (
    cd "$fixture_root" || exit 2
    # shellcheck disable=SC1090
    . "$HOOK_SKILL_BASE"
    skill_get_extension_dir "$task_type"
  )
}

run_hook_case() {
  local fixture_root="$1"; shift
  (
    cd "$fixture_root" || exit 2
    # shellcheck disable=SC1090
    . "$HOOK_SKILL_BASE"
    skill_run_extension_hook "$@" >"$WORKDIR/hook-case-stdout.log" 2>"$WORKDIR/hook-case-stderr.log"
    func_rc=$?
    printf 'RC=%s;STATUS=%s;NAME=%s;PATH=%s;FUNC_RC=%s\n' \
      "${SKILL_HOOK_LAST_RC}" "${SKILL_HOOK_LAST_STATUS}" "${SKILL_HOOK_LAST_NAME}" \
      "${SKILL_HOOK_LAST_PATH}" "$func_rc"
  )
}

# --- resolver hit ---------------------------------------------------------------------------
RESOLVER_HIT=$(run_resolver_case "$HOOK_ROOT" "hookfixturetype")
if [[ "$RESOLVER_HIT" == ".claude/extensions/fixtureext" ]]; then
  pass "skill_get_extension_dir resolves a matching active task_type to its extension dir"
else
  fail "skill_get_extension_dir (hit): expected '.claude/extensions/fixtureext', got '$RESOLVER_HIT'"
fi

# --- resolver miss: unknown task_type -------------------------------------------------------
RESOLVER_MISS=$(run_resolver_case "$HOOK_ROOT" "no-such-type")
if [[ -z "$RESOLVER_MISS" ]]; then
  pass "skill_get_extension_dir returns empty for an unknown task_type"
else
  fail "skill_get_extension_dir (miss): expected empty, got '$RESOLVER_MISS'"
fi

# --- resolver miss: extension present but status != active ---------------------------------
RESOLVER_INACTIVE=$(run_resolver_case "$HOOK_ROOT" "inactivetype")
if [[ -z "$RESOLVER_INACTIVE" ]]; then
  pass "skill_get_extension_dir does not match an extension whose status is not active"
else
  fail "skill_get_extension_dir (inactive): expected empty, got '$RESOLVER_INACTIVE'"
fi

# --- resolver safety: no .claude-extensions.json at all -------------------------------------
RESOLVER_NOEXT=$(run_resolver_case "$HOOK_NOEXT_ROOT" "hookfixturetype")
RESOLVER_NOEXT_RC=$?
if [[ -z "$RESOLVER_NOEXT" && "$RESOLVER_NOEXT_RC" -eq 0 ]]; then
  pass "skill_get_extension_dir with no .claude-extensions.json at all returns empty and exits 0"
else
  fail "skill_get_extension_dir (no extensions.json): expected empty/exit 0, got '$RESOLVER_NOEXT' / rc=$RESOLVER_NOEXT_RC"
fi

# --- hook fires: bare filename form ---------------------------------------------------------
rm -f "$WORKDIR/hook-sentinel-fired"
HOOK_FIRE=$(run_hook_case "$HOOK_ROOT" "preflight" 1 hookfixturetype specs/001_x sess_test implement)
if [[ -f "$WORKDIR/hook-sentinel-fired" ]] && [[ "$HOOK_FIRE" == "RC=0;STATUS=ran;NAME=preflight;PATH=.claude/scripts/hook-sentinel.sh;FUNC_RC=0" ]]; then
  pass "skill_run_extension_hook fires a declared hook (bare filename form), RC=0, STATUS=ran"
else
  fail "skill_run_extension_hook (hook fires, bare form): sentinel-written=$( [[ -f "$WORKDIR/hook-sentinel-fired" ]] && echo yes || echo no), got '$HOOK_FIRE'"
fi

# --- prefixed-path tolerance: scripts/<name>.sh form resolves identically -------------------
rm -f "$WORKDIR/hook-sentinel-fired"
HOOK_FIRE_PREFIXED=$(run_hook_case "$HOOK_ROOT" "postflight" 1 hookfixturetype specs/001_x sess_test implement)
if [[ -f "$WORKDIR/hook-sentinel-fired" ]] && [[ "$HOOK_FIRE_PREFIXED" == "RC=0;STATUS=ran;NAME=postflight;PATH=.claude/scripts/hook-sentinel.sh;FUNC_RC=0" ]]; then
  pass "skill_run_extension_hook resolves the scripts/-prefixed manifest form identically (nix/nvim's actual form)"
else
  fail "skill_run_extension_hook (prefixed-path tolerance): sentinel-written=$( [[ -f "$WORKDIR/hook-sentinel-fired" ]] && echo yes || echo no), got '$HOOK_FIRE_PREFIXED'"
fi

# --- rc observable: non-zero hook exit, function still returns 0 ---------------------------
HOOK_BADRC=$(run_hook_case "$HOOK_ROOT" "context_injection" 1 hookfixturetype specs/001_x sess_test implement)
if [[ "$HOOK_BADRC" == "RC=7;STATUS=ran;NAME=context_injection;PATH=.claude/scripts/hook-badrc.sh;FUNC_RC=0" ]]; then
  pass "skill_run_extension_hook makes a non-zero hook exit observable (RC=7) while the function itself still returns 0"
else
  fail "skill_run_extension_hook (rc observable): got '$HOOK_BADRC'"
fi
if grep -q "WARNING.*exited non-zero" "$WORKDIR/hook-case-stdout.log" 2>/dev/null; then
  pass "skill_run_extension_hook prints the existing non-blocking WARNING on a non-zero exit"
else
  fail "skill_run_extension_hook (rc observable): expected non-blocking WARNING on stdout, got: $(cat "$WORKDIR/hook-case-stdout.log" 2>/dev/null)"
fi

# --- loud skip + reset discipline: a declared hook resolving to a missing/non-executable script
# emits the NOTE on stderr and still returns 0 -- run immediately after the non-zero case above
# so this ALSO proves a subsequent skipped invocation does not leak the prior run's RC=7. -----
HOOK_LOUDSKIP=$(run_hook_case "$HOOK_ROOT" "verification" 1 hookfixturetype specs/001_x sess_test implement)
if [[ "$HOOK_LOUDSKIP" == "RC=;STATUS=skipped_not_executable;NAME=verification;PATH=.claude/scripts/does-not-exist.sh;FUNC_RC=0" ]]; then
  pass "skill_run_extension_hook resets RC/STATUS on a subsequent skipped invocation (no leak of the prior RC=7); STATUS=skipped_not_executable"
else
  fail "skill_run_extension_hook (loud skip / reset discipline): got '$HOOK_LOUDSKIP'"
fi
if grep -q "^NOTE:.*hook skipped" "$WORKDIR/hook-case-stderr.log" 2>/dev/null; then
  pass "skill_run_extension_hook emits a loud one-line NOTE on stderr for a missing/non-executable resolved hook"
else
  fail "skill_run_extension_hook (loud skip): expected a NOTE on stderr, got: $(cat "$WORKDIR/hook-case-stderr.log" 2>/dev/null)"
fi

# =====================================================================
# Real-tree contamination guard: this suite must never leave a NEW mark on the actual repo's
# specs/ tree relative to the pre-suite baseline, no matter which group ran. Delta check, not an
# absolute-emptiness check -- see the BASELINE_SPECS_STATUS comment above for why.
# =====================================================================
info "=== contamination guard ==="
FINAL_SPECS_STATUS="$(cd "$REPO_ROOT" && git status --short specs/ 2>/dev/null)"
if [[ "$FINAL_SPECS_STATUS" == "$BASELINE_SPECS_STATUS" ]]; then
  pass "real specs/ tree status is unchanged relative to this suite's pre-run baseline"
else
  fail "real specs/ tree status changed during this suite (baseline vs. final differ) -- baseline:
$BASELINE_SPECS_STATUS
-- final:
$FINAL_SPECS_STATUS"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"
echo ""
echo "Residual (uncovered by this suite, out of scope per this suite's own authoring plan):"
echo "  _events_append_observable,"
echo "  skill_validate_input, skill_create_postflight_marker, skill_context_injection,"
echo "  skill_read_artifact_number, skill_read_metadata, skill_validate_artifact,"
echo "  skill_propagate_completion_summary,"
echo "  skill_corroborate_phase_counts (already covered by test-corroborate-phase-counts.sh)."
echo "  skill_validate_task_artifacts is now covered by test-gate-out-repair-reporting.sh"
echo "  (its SKILL_VALIDATE_* aggregation globals and command-gate-out.sh's report/events leg)."
echo "  skill_get_extension_dir and skill_run_extension_hook are now covered by Group 5 above"
echo "  (source-store-first resolver/hook-mechanism coverage against the real object schema)."

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
