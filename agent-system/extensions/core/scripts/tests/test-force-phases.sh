#!/usr/bin/env bash
# test-force-phases.sh - Regression suite for A2 (phase-forcing flags on /orchestrate):
# parse-command-args.sh's FORCE_PHASES_FLAG accumulation, status-vocabulary.sh's rank helpers,
# skill_postflight_update's monotonic-max clamp (positional 7), and
# orchestrate-stage5-postflight.sh's artifact-round advance (force_invoked, positional 20).
#
# Structural model: reuses test-skill-base-lifecycle.sh's STRUCTURAL conventions verbatim
# (mktemp -d WORKDIR with an EXIT-trap cleanup, sourced -- not subprocessed -- library files,
# pass()/fail()/info() helpers with integer counters, an isolated fixture repo under WORKDIR,
# exit 0 all-pass / 1 any-fail / 2 environment error). This is a NEW, separate test file
# (test-skill-base-lifecycle.sh is owned by a sibling task landing concurrently) -- not an
# extension of that suite.
#
# CANDIDATE-RESOLUTION INVERSION (deliberate, and the reason this suite cannot just copy the
# sibling's resolve_candidate() calls verbatim): this repository's .claude/ tree is a gitignored,
# disposable deploy artifact regenerated from agent-system/extensions/**. Every relevant loader in
# this codebase (including the sibling suite above) resolves DEPLOY-TREE-FIRST, source-store
# fallback -- correct for a suite validating what actually runs in production. This suite instead
# tests a PRE-DEPLOY SOURCE-STORE EDIT, a different question: did A2 land correctly in the four
# files this task edits? Copying the deploy-first order verbatim here would make this suite
# silently vacuous -- it would validate the OLD, undeployed-against copy and report a false green
# on a source-store regression. So for exactly the four files this task edits --
# scripts/skill-base.sh, scripts/lib/status-vocabulary.sh,
# scripts/orchestrate-stage5-postflight.sh, and scripts/parse-command-args.sh -- resolution below
# is inverted: agent-system/extensions/core/ FIRST, falling back to .claude/ only if the
# source-store copy is absent. Every OTHER fixture dependency (update-task-status.sh,
# state-write.sh, task-lock.sh, generate-todo.sh, deploy-root-guard.sh, update-plan-status.sh,
# update-phase-status.sh, and the rest of lib/*.sh) keeps the existing deploy-tree provenance --
# those are not under test here, and inverting their resolution too would just substitute one
# untested assumption for another.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (a
# required library/script was not found at any candidate path, OR the harness-sanity case
# detected a wrong-copy load -- see that case below for why it is exit 2, not exit 1).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Same depth-independent REPO_ROOT resolution the sibling suite uses (git worktree root first,
# fixed-depth fallback second) -- this suite lives at the identical depth under both the
# source-store and deployed trees, so the same fallback arithmetic applies unchanged.
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

SOURCE_STORE_SCRIPTS="$REPO_ROOT/agent-system/extensions/core/scripts"
DEPLOY_SCRIPTS_SRC="$REPO_ROOT/.claude/scripts"

# ─── resolve_inverted: source-store first, deploy fallback (the deliberate inversion) ──────────
resolve_inverted() {
  local desc="$1" relpath="$2"
  if [[ -f "$SOURCE_STORE_SCRIPTS/$relpath" ]]; then
    printf '%s\n' "$SOURCE_STORE_SCRIPTS/$relpath"
    return 0
  fi
  if [[ -f "$DEPLOY_SCRIPTS_SRC/$relpath" ]]; then
    printf '%s\n' "$DEPLOY_SCRIPTS_SRC/$relpath"
    return 0
  fi
  echo "ERROR: $desc not found at either candidate:" >&2
  echo "  $SOURCE_STORE_SCRIPTS/$relpath" >&2
  echo "  $DEPLOY_SCRIPTS_SRC/$relpath" >&2
  return 1
}

SKILL_BASE="$(resolve_inverted "skill-base.sh" "skill-base.sh")" || exit 2
STATUS_VOCAB="$(resolve_inverted "lib/status-vocabulary.sh" "lib/status-vocabulary.sh")" || exit 2
STAGE5_POSTFLIGHT="$(resolve_inverted "orchestrate-stage5-postflight.sh" "orchestrate-stage5-postflight.sh")" || exit 2
PARSE_ARGS="$(resolve_inverted "parse-command-args.sh" "parse-command-args.sh")" || exit 2

if [[ ! -d "$DEPLOY_SCRIPTS_SRC" ]]; then
  echo "ERROR: deployed scripts tree not found at $DEPLOY_SCRIPTS_SRC -- this suite needs a" >&2
  echo "       real deployed .claude/scripts/ tree to copy the non-task-edited dependency" >&2
  echo "       chain (state-write.sh, task-lock.sh, update-task-status.sh, lib/*.sh) from." >&2
  exit 2
fi
for req in update-task-status.sh state-write.sh task-lock.sh generate-todo.sh deploy-root-guard.sh \
           update-plan-status.sh update-phase-status.sh; do
  if [[ ! -f "$DEPLOY_SCRIPTS_SRC/$req" ]]; then
    echo "ERROR: required deployed script missing: $DEPLOY_SCRIPTS_SRC/$req" >&2
    exit 2
  fi
done

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# ─── build the isolated fixture repo: deployed dependency chain, THEN overlay the four ────────
# task-edited files with whichever candidate resolve_inverted picked above (source-store,
# normally -- deploy only as the documented absent-fallback).
mkdir -p "$WORKDIR/.claude/scripts/lib" "$WORKDIR/specs" "$WORKDIR/specs/.orchestration"
for f in update-task-status.sh state-write.sh task-lock.sh generate-todo.sh deploy-root-guard.sh \
         update-plan-status.sh update-phase-status.sh; do
  cp "$DEPLOY_SCRIPTS_SRC/$f" "$WORKDIR/.claude/scripts/$f"
  chmod +x "$WORKDIR/.claude/scripts/$f"
done
cp "$DEPLOY_SCRIPTS_SRC"/lib/*.sh "$WORKDIR/.claude/scripts/lib/" 2>/dev/null || true
cp "$SKILL_BASE" "$WORKDIR/.claude/scripts/skill-base.sh"
cp "$STATUS_VOCAB" "$WORKDIR/.claude/scripts/lib/status-vocabulary.sh"
cp "$STAGE5_POSTFLIGHT" "$WORKDIR/.claude/scripts/orchestrate-stage5-postflight.sh"
chmod +x "$WORKDIR/.claude/scripts/orchestrate-stage5-postflight.sh"
cp "$PARSE_ARGS" "$WORKDIR/.claude/scripts/parse-command-args.sh"

cat > "$WORKDIR/specs/state.json" << 'EOF'
{
  "next_project_number": 2,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "fixture_task",
      "status": "planned",
      "task_type": "general",
      "next_artifact_number": 2
    }
  ]
}
EOF

ORIG_PWD="$(pwd)"

# =====================================================================
# Harness sanity -- MUST run first; gates every case below. A failure here means this suite
# would otherwise silently report on the WRONG code (the stale-deploy hazard this task's plan
# documents at length), which is a different and more dangerous condition than a genuine
# assertion failure -- hence exit 2 (environment error), never exit 1 (test failure), on any
# miss in this section.
# =====================================================================
info "=== harness sanity (resolved-copy provenance) ==="

for pair in "skill-base.sh:$SKILL_BASE" "lib/status-vocabulary.sh:$STATUS_VOCAB" \
            "orchestrate-stage5-postflight.sh:$STAGE5_POSTFLIGHT" \
            "parse-command-args.sh:$PARSE_ARGS"; do
  desc="${pair%%:*}"
  resolved="${pair#*:}"
  echo "[INFO] resolved $desc -> $resolved"
  case "$resolved" in
    "$SOURCE_STORE_SCRIPTS"/*)
      pass "$desc resolved under agent-system/extensions/core/ (source-store copy)"
      ;;
    *)
      echo "ERROR: $desc resolved to a non-source-store path ($resolved) -- this suite would silently test the wrong copy. Refusing to continue." >&2
      exit 2
      ;;
  esac
done

# shellcheck disable=SC1090
. "$SKILL_BASE"
if declare -F status_vocabulary_would_regress >/dev/null 2>&1; then
  fail "status_vocabulary_would_regress is defined at top-level scope before any clamp call -- unexpected (it should only become defined once skill_postflight_update's monotonic-max branch sources it); harmless if so, but worth recording since it changes what the next case actually proves"
else
  info "status_vocabulary_would_regress not yet defined (expected -- skill_postflight_update sources it lazily, only under status_clamp_mode=monotonic-max)"
fi
# shellcheck disable=SC1090
. "$STATUS_VOCAB"
if declare -F status_vocabulary_would_regress >/dev/null 2>&1; then
  pass "status_vocabulary_would_regress is a defined function once lib/status-vocabulary.sh is sourced directly"
else
  echo "ERROR: status_vocabulary_would_regress is not defined after sourcing $STATUS_VOCAB -- this is the signature of the partial-fix stale-deploy failure mode, not a logic bug. Refusing to continue." >&2
  exit 2
fi

# =====================================================================
# Parser: FORCE_PHASES_FLAG accumulation and canonicalization
# =====================================================================
info "=== parser: FORCE_PHASES_FLAG ==="

# shellcheck disable=SC1090
. "$PARSE_ARGS" "42 --research --plan" >/dev/null 2>&1
if [[ "$FORCE_PHASES_FLAG" == "research,plan" ]]; then
  pass "--research --plan yields FORCE_PHASES_FLAG=research,plan"
else
  fail "--research --plan yielded FORCE_PHASES_FLAG='$FORCE_PHASES_FLAG' (expected research,plan)"
fi

# shellcheck disable=SC1090
. "$PARSE_ARGS" "42 --plan --research" >/dev/null 2>&1
if [[ "$FORCE_PHASES_FLAG" == "research,plan" ]]; then
  pass "--plan --research yields the identical FORCE_PHASES_FLAG=research,plan (canonical-order, not token-order)"
else
  fail "--plan --research yielded FORCE_PHASES_FLAG='$FORCE_PHASES_FLAG' (expected research,plan)"
fi

# shellcheck disable=SC1090
. "$PARSE_ARGS" "42 focus on the LSP config" >/dev/null 2>&1
if [[ "$FORCE_PHASES_FLAG" == "" && "$FOCUS_PROMPT" == "focus on the LSP config" ]]; then
  pass "no forcing flags yields FORCE_PHASES_FLAG='' and an intact FOCUS_PROMPT"
else
  fail "no forcing flags: FORCE_PHASES_FLAG='$FORCE_PHASES_FLAG' FOCUS_PROMPT='$FOCUS_PROMPT' (expected '' / 'focus on the LSP config')"
fi

# =====================================================================
# Rank: status_vocabulary_would_regress (the four Phase 2 cases)
# =====================================================================
info "=== rank: status_vocabulary_would_regress ==="

if status_vocabulary_would_regress planned researched; then
  pass "planned -> researched: regresses (returns 0)"
else
  fail "planned -> researched: expected regression (0), got non-regression"
fi

if status_vocabulary_would_regress researched planned; then
  fail "researched -> planned: expected non-regression (1), got regression"
else
  pass "researched -> planned: does not regress (returns 1)"
fi

if status_vocabulary_would_regress planned planned; then
  pass "planned -> planned: equal rank counts as a regression for monotonic-max purposes (returns 0)"
else
  fail "planned -> planned: expected regression (0), got non-regression"
fi

if status_vocabulary_would_regress blocked researched; then
  fail "blocked -> researched: expected non-regression (1, unranked side), got regression"
else
  pass "blocked -> researched: unranked side means the clamp does not apply (returns 1)"
fi

if status_vocabulary_would_regress hold researched; then
  fail "hold -> researched: expected non-regression (1, unranked side -- hold is deliberately omitted from STATUS_VOCABULARY_LIFECYCLE_RANK alongside blocked/partial/abandoned/expanded), got regression"
else
  pass "hold -> researched: unranked side means the clamp does not apply (returns 1)"
fi

# =====================================================================
# Clamp: skill_postflight_update's monotonic-max mode (positional 7)
# =====================================================================
info "=== clamp: skill_postflight_update monotonic-max ==="

cd "$WORKDIR"
export SKILL_REPO_ROOT="$WORKDIR"

CLAMP_OUT="$(skill_postflight_update 1 research sess_test_clamp researched "" "" monotonic-max 2>&1)"
CLAMP_RC=$?
CLAMP_STATUS="$(jq -r '.active_projects[0].status' specs/state.json)"
if [[ "$CLAMP_RC" -eq 0 && "$CLAMP_STATUS" == "planned" ]] && echo "$CLAMP_OUT" | grep -q '\[monotonic-max\]'; then
  pass "monotonic-max clamp: forced research->researched against current=planned leaves status at planned, rc=0, and prints the [monotonic-max] notice"
else
  fail "monotonic-max clamp: rc=$CLAMP_RC status=$CLAMP_STATUS output=$CLAMP_OUT (expected rc=0, status=planned, [monotonic-max] notice present)"
fi

# =====================================================================
# Clamp opt-out: the identical call WITHOUT the 7th argument transitions normally
# =====================================================================
info "=== clamp opt-out (default unchanged) ==="

skill_postflight_update 1 research sess_test_optout researched >/dev/null 2>&1
OPTOUT_STATUS="$(jq -r '.active_projects[0].status' specs/state.json)"
if [[ "$OPTOUT_STATUS" == "researched" ]]; then
  pass "clamp opt-out: the same call WITHOUT status_clamp_mode transitions the status (researched) -- default is unchanged"
else
  fail "clamp opt-out: expected status=researched, got '$OPTOUT_STATUS'"
fi

# Reset fixture status back to planned for the arity-preservation cases below.
# Routed through the fixture's own copy of state-write.sh (the sanctioned state.json
# writer) rather than a hand-rolled `jq ... > tmp && mv` sequence -- see
# scripts/lint/lint-state-writer-boundary.sh's boundary contract, which this suite is not
# exempt from (unlike test-update-task-status.sh's deliberate corrupt-state fixture).
"$WORKDIR/.claude/scripts/state-write.sh" '.active_projects[0].status = "planned"' \
  --session-id "sess_test_arity_setup"

# =====================================================================
# Arity preservation: a 4-argument and a 5-argument call still behave exactly as before
# =====================================================================
info "=== arity preservation ==="

skill_postflight_update 1 plan sess_test_4arg planned >/dev/null 2>&1
ARITY4_STATUS="$(jq -r '.active_projects[0].status' specs/state.json)"
if [[ "$ARITY4_STATUS" == "planned" ]]; then
  pass "4-argument call (no phase_check_mode, no clamp) still transitions to the target status normally"
else
  fail "4-argument call: expected status=planned, got '$ARITY4_STATUS'"
fi

# Deliberately "research" here, not "implement": update-task-status.sh's update_plan_file()
# only touches a plan file when target_status == "implement" (and this fixture has none), so
# "research" isolates the arity/phase_check_mode question from that unrelated plan-file path.
skill_postflight_update 1 research sess_test_5arg researched warn >/dev/null 2>&1
ARITY5_RC=$?
ARITY5_STATUS="$(jq -r '.active_projects[0].status' specs/state.json)"
if [[ "$ARITY5_RC" -eq 0 && "$ARITY5_STATUS" == "researched" ]]; then
  pass "5-argument call (phase_check_mode=warn, no clamp) transitions normally under the unchanged code path (rc=0, status=researched)"
else
  fail "5-argument call: rc=$ARITY5_RC status=$ARITY5_STATUS (expected rc=0, status=researched)"
fi

cd "$ORIG_PWD"
unset SKILL_REPO_ROOT

# =====================================================================
# Artifact advance: orchestrate-stage5-postflight.sh's force_invoked-gated round advance
# =====================================================================
info "=== artifact advance: orchestrate-stage5-postflight.sh ==="

run_stage5() {
  local dispatch_status="$1" force_invoked="$2" session_id="$3"
  ( cd "$WORKDIR" && bash .claude/scripts/orchestrate-stage5-postflight.sh \
      1 "$session_id" general "specs/001_fixture_task" "$dispatch_status" \
      1 1 true "" "" "" \
      "[test]" "test:site" "test/attributed-path" "" \
      9999999999 "specs/001_fixture_task/.orchestrator-loop-guard.json" \
      "specs/001_fixture_task/.orchestrator-loop-guard.json" 0 "$force_invoked" )
}
mkdir -p "$WORKDIR/specs/001_fixture_task"

"$WORKDIR/.claude/scripts/state-write.sh" '.active_projects[0].next_artifact_number = 2' \
  --session-id "sess_test_advance_setup"
BEFORE_RESEARCHED=$(jq -r '.active_projects[0].next_artifact_number' "$WORKDIR/specs/state.json")
run_stage5 researched false sess_test_advance_r >/dev/null 2>&1
AFTER_RESEARCHED=$(jq -r '.active_projects[0].next_artifact_number' "$WORKDIR/specs/state.json")
if [[ "$AFTER_RESEARCHED" -eq $((BEFORE_RESEARCHED + 1)) ]]; then
  pass "researched dispatch (unforced) unconditionally advances next_artifact_number ($BEFORE_RESEARCHED -> $AFTER_RESEARCHED)"
else
  fail "researched dispatch: next_artifact_number $BEFORE_RESEARCHED -> $AFTER_RESEARCHED (expected +1)"
fi

"$WORKDIR/.claude/scripts/state-write.sh" '.active_projects[0].status = "planned"' \
  --session-id "sess_test_advance_pu_setup"
BEFORE_UNFORCED=$(jq -r '.active_projects[0].next_artifact_number' "$WORKDIR/specs/state.json")
run_stage5 planned false sess_test_advance_pu >/dev/null 2>&1
AFTER_UNFORCED=$(jq -r '.active_projects[0].next_artifact_number' "$WORKDIR/specs/state.json")
if [[ "$AFTER_UNFORCED" -eq "$BEFORE_UNFORCED" ]]; then
  pass "planned dispatch with force_invoked=false does NOT advance next_artifact_number (stays $BEFORE_UNFORCED)"
else
  fail "planned dispatch, force_invoked=false: next_artifact_number $BEFORE_UNFORCED -> $AFTER_UNFORCED (expected no change)"
fi

"$WORKDIR/.claude/scripts/state-write.sh" '.active_projects[0].status = "planned"' \
  --session-id "sess_test_advance_pf_setup"
BEFORE_FORCED=$(jq -r '.active_projects[0].next_artifact_number' "$WORKDIR/specs/state.json")
run_stage5 planned true sess_test_advance_pf >/dev/null 2>&1
AFTER_FORCED=$(jq -r '.active_projects[0].next_artifact_number' "$WORKDIR/specs/state.json")
if [[ "$AFTER_FORCED" -eq $((BEFORE_FORCED + 1)) ]]; then
  pass "planned dispatch with force_invoked=true DOES advance next_artifact_number ($BEFORE_FORCED -> $AFTER_FORCED)"
else
  fail "planned dispatch, force_invoked=true: next_artifact_number $BEFORE_FORCED -> $AFTER_FORCED (expected +1)"
fi

# =====================================================================
# Stop-after-the-last-forced-phase (observed live incident regression): a task whose forced-phase
# queue was seeded and exhausted THIS RUN must be excluded from dispatch for the rest of the run
# -- never routed by status -- whether or not a later call in the same run repeats the flag.
# Exercises orchestrate-cycle-plan.sh, the BATCH multi-task engine -- a FIFTH file this task's own
# plan edits alongside the four resolved above, so it is resolved with the SAME source-store-first
# inversion (never silently testing the stale deploy copy); every genuinely non-task-edited
# batch-engine collaborator below keeps this suite's existing deploy-tree provenance.
# =====================================================================
info "=== stop-after-last-forced-phase (orchestrate-cycle-plan.sh, observed live incident) ==="

CYCLE_PLAN="$(resolve_inverted "orchestrate-cycle-plan.sh" "orchestrate-cycle-plan.sh")" || exit 2
echo "[INFO] resolved orchestrate-cycle-plan.sh -> $CYCLE_PLAN"
case "$CYCLE_PLAN" in
  "$SOURCE_STORE_SCRIPTS"/*)
    pass "orchestrate-cycle-plan.sh resolved under agent-system/extensions/core/ (source-store copy)"
    ;;
  *)
    echo "ERROR: orchestrate-cycle-plan.sh resolved to a non-source-store path ($CYCLE_PLAN) -- this suite would silently test the wrong copy. Refusing to continue." >&2
    exit 2
    ;;
esac

cp "$CYCLE_PLAN" "$WORKDIR/.claude/scripts/orchestrate-cycle-plan.sh"
chmod +x "$WORKDIR/.claude/scripts/orchestrate-cycle-plan.sh"
# territory-contention-lib.sh, task-classification-lib.sh, and redeploy-checkpoint-lib.sh:
# orchestrate-cycle-plan.sh now `source`s all three libs (the script-corpus decomposition task's
# Phase 4, 5, and 6 extractions). They need the SAME source-store-first inversion as CYCLE_PLAN
# itself -- the line-106 deploy-tree lib/*.sh copy above predates all three files' existence and
# would otherwise silently leave the fixture without them, breaking every case below that reaches
# orchestrate-cycle-plan.sh's sourced functions.
TERRITORY_LIB="$(resolve_inverted "lib/territory-contention-lib.sh" "lib/territory-contention-lib.sh")" || exit 2
cp "$TERRITORY_LIB" "$WORKDIR/.claude/scripts/lib/territory-contention-lib.sh"
TASK_CLASSIFICATION_LIB="$(resolve_inverted "lib/task-classification-lib.sh" "lib/task-classification-lib.sh")" || exit 2
cp "$TASK_CLASSIFICATION_LIB" "$WORKDIR/.claude/scripts/lib/task-classification-lib.sh"
REDEPLOY_CHECKPOINT_LIB="$(resolve_inverted "lib/redeploy-checkpoint-lib.sh" "lib/redeploy-checkpoint-lib.sh")" || exit 2
cp "$REDEPLOY_CHECKPOINT_LIB" "$WORKDIR/.claude/scripts/lib/redeploy-checkpoint-lib.sh"
# Non-task-edited batch-engine collaborators: existing deploy-tree provenance, unchanged.
for f in orchestrate-batch-admit.sh orchestrate-triage-classify.sh orchestrate-build-dispatch.sh \
         orchestrate-loop-guard-init.sh orchestrate-build-aux-dispatch.sh command-route-agent.sh; do
  cp "$DEPLOY_SCRIPTS_SRC/$f" "$WORKDIR/.claude/scripts/$f"
  chmod +x "$WORKDIR/.claude/scripts/$f"
done
mkdir -p "$WORKDIR/.claude/context/reference"
cp "$REPO_ROOT/.claude/context/reference/orchestrator-critical-paths.json" \
   "$WORKDIR/.claude/context/reference/orchestrator-critical-paths.json"

CYCLE_PLAN_SUT="$WORKDIR/.claude/scripts/orchestrate-cycle-plan.sh"
run_cycle_plan() {
  bash "$CYCLE_PLAN_SUT" "$@" --state-file "$WORKDIR/specs/state.json"
}

# A fresh candidate (#2), independent of #1's mutations above, starting at "planned" so that an
# ORDINARY (unforced) classification would route it to "implement" -- distinguishing the
# exclusion below from an ordinary status-derived dispatch.
"$WORKDIR/.claude/scripts/state-write.sh" \
  '.active_projects += [{"project_number": 2, "project_name": "fixture_task_fphase", "status": "planned", "task_type": "general", "dependencies": [], "file_scope": [], "next_artifact_number": 1}] | .next_project_number = 3' \
  --session-id "sess_test_fphase_setup"
mkdir -p "$WORKDIR/specs/002_fixture_task_fphase/reports"

FPHASE_SESSION="sess_test_fphase"
FPHASE_MT_STATE="$WORKDIR/specs/.orchestration/.orchestrator-multi-state-${FPHASE_SESSION}.json"
rm -f "$FPHASE_MT_STATE"
find "$WORKDIR/specs" -maxdepth 2 -type d -name '.lock' -exec rm -rf {} + 2>/dev/null || true

# Cycle 1: forced research dispatches (LIVE). "research dispatched and postflighted" is
# simulated by directly writing the post-postflight status (researched) once the dispatch itself
# is confirmed below -- this suite's domain is the batch engine's OWN persistence
# (force_phases_remaining/forced_round_seeded/dispatch bookkeeping), not
# orchestrate-cycle-postflight.sh's separate artifact/status-write mechanics, out of scope here.
fphase_cycle1_out=$(run_cycle_plan --session "$FPHASE_SESSION" --no-plan-cache --force-phases research 2)
fphase_cycle1_exit=$?
if [ "$fphase_cycle1_exit" -eq 0 ] && \
   [ "$(echo "$fphase_cycle1_out" | jq -r '.dispatch | map(select(.task == 2 and .phase == "research")) | length')" = "1" ]; then
  pass "cycle 1: forced research round dispatches candidate #2 (exit 0)"
else
  fail "cycle 1: expected a forced research dispatch for candidate #2 (exit $fphase_cycle1_exit): $fphase_cycle1_out"
fi
fphase_dispatch_files_before=$(find "$WORKDIR/specs/002_fixture_task_fphase/.dispatch" -type f 2>/dev/null | wc -l | tr -d ' ')

"$WORKDIR/.claude/scripts/state-write.sh" \
  '(.active_projects[] | select(.project_number == 2) | .status) = "researched"' \
  --session-id "sess_test_fphase_postflight"

fphase_cycle_before=$(jq -r --arg t "2" '.cycle_counts[$t] // 0' "$FPHASE_MT_STATE" 2>/dev/null)

# Case (1): a SECOND live call, SAME session, WITH the flag repeated.
fphase_cycle2_out=$(run_cycle_plan --session "$FPHASE_SESSION" --no-plan-cache --force-phases research 2)
fphase_cycle2_exit=$?
fphase_status_after_2=$(jq -r '.active_projects[] | select(.project_number == 2) | .status' "$WORKDIR/specs/state.json")
fphase_cycle_after_2=$(jq -r --arg t "2" '.cycle_counts[$t] // 0' "$FPHASE_MT_STATE" 2>/dev/null)
fphase_dispatch_files_after_2=$(find "$WORKDIR/specs/002_fixture_task_fphase/.dispatch" -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "$fphase_cycle2_exit" -eq 0 ] && \
   [ "$(echo "$fphase_cycle2_out" | jq -r '.dispatch | map(select(.task == 2)) | length')" = "0" ]; then
  pass "case 1 (repeated flag): zero dispatch rows for candidate #2"
else
  fail "case 1 (repeated flag): expected zero dispatch rows (exit $fphase_cycle2_exit): $fphase_cycle2_out"
fi
if [ "$fphase_status_after_2" = "researched" ]; then
  pass "case 1: status stays 'researched' (no regression)"
else
  fail "case 1: status changed to '$fphase_status_after_2'"
fi
if [ "$fphase_dispatch_files_after_2" = "$fphase_dispatch_files_before" ]; then
  pass "case 1: no new dispatch file written"
else
  fail "case 1: dispatch file count changed ($fphase_dispatch_files_before -> $fphase_dispatch_files_after_2)"
fi
if [ "$fphase_cycle_after_2" = "$fphase_cycle_before" ]; then
  pass "case 1: cycle_counts unchanged ($fphase_cycle_after_2)"
else
  fail "case 1: cycle_counts changed ($fphase_cycle_before -> $fphase_cycle_after_2)"
fi

# Case (2): a live call WITHOUT the flag -- must ALSO be excluded (proves the exclusion is
# driven by the persisted forced_round_seeded marker for THIS run, not by the flag's own
# presence/absence on any individual call).
fphase_cycle3_out=$(run_cycle_plan --session "$FPHASE_SESSION" --no-plan-cache 2)
fphase_cycle3_exit=$?
fphase_status_after_3=$(jq -r '.active_projects[] | select(.project_number == 2) | .status' "$WORKDIR/specs/state.json")
fphase_cycle_after_3=$(jq -r --arg t "2" '.cycle_counts[$t] // 0' "$FPHASE_MT_STATE" 2>/dev/null)
fphase_dispatch_files_after_3=$(find "$WORKDIR/specs/002_fixture_task_fphase/.dispatch" -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "$fphase_cycle3_exit" -eq 0 ] && \
   [ "$(echo "$fphase_cycle3_out" | jq -r '.dispatch | map(select(.task == 2)) | length')" = "0" ]; then
  pass "case 2 (flag omitted): zero dispatch rows for candidate #2"
else
  fail "case 2 (flag omitted): expected zero dispatch rows (exit $fphase_cycle3_exit): $fphase_cycle3_out"
fi
if [ "$fphase_status_after_3" = "researched" ]; then
  pass "case 2: status stays 'researched' (no regression)"
else
  fail "case 2: status changed to '$fphase_status_after_3'"
fi
if [ "$fphase_dispatch_files_after_3" = "$fphase_dispatch_files_before" ]; then
  pass "case 2: no new dispatch file written"
else
  fail "case 2: dispatch file count changed ($fphase_dispatch_files_before -> $fphase_dispatch_files_after_3)"
fi
if [ "$fphase_cycle_after_3" = "$fphase_cycle_before" ]; then
  pass "case 2: cycle_counts unchanged ($fphase_cycle_after_3)"
else
  fail "case 2: cycle_counts changed ($fphase_cycle_before -> $fphase_cycle_after_3)"
fi
if [ "$(echo "$fphase_cycle3_out" | jq -r '.blocked | map(select(.task == 2 and (.reason | contains("forced round complete")))) | length')" = "1" ]; then
  pass "case 2: a forced_round_complete blocked[] row is present"
else
  fail "case 2: expected a forced_round_complete blocked[] row, got: $fphase_cycle3_out"
fi

# Counter-case: an UNFORCED multi-phase session still advances research -> plan -> implement
# (this fix must never touch ordinary, unforced routing).
"$WORKDIR/.claude/scripts/state-write.sh" \
  '.active_projects += [{"project_number": 3, "project_name": "fixture_task_unforced", "status": "not_started", "task_type": "general", "dependencies": [], "file_scope": [], "next_artifact_number": 1}] | .next_project_number = 4' \
  --session-id "sess_test_unforced_setup"
mkdir -p "$WORKDIR/specs/003_fixture_task_unforced/reports"
UNFORCED_SESSION="sess_test_unforced"
rm -f "$WORKDIR/specs/.orchestration/.orchestrator-multi-state-${UNFORCED_SESSION}.json"

unforced_cycle1_out=$(run_cycle_plan --session "$UNFORCED_SESSION" --no-plan-cache 3)
unforced_phase_1=$(echo "$unforced_cycle1_out" | jq -r '.dispatch | map(select(.task == 3)) | .[0].phase // ""')
if [ "$unforced_phase_1" = "research" ]; then
  pass "unforced counter-case: cycle 1 (not_started) advances to research"
else
  fail "unforced counter-case: cycle 1 expected phase=research, got '$unforced_phase_1': $unforced_cycle1_out"
fi

"$WORKDIR/.claude/scripts/state-write.sh" \
  '(.active_projects[] | select(.project_number == 3) | .status) = "researched"' \
  --session-id "sess_test_unforced_postflight_1"
unforced_cycle2_out=$(run_cycle_plan --session "$UNFORCED_SESSION" --no-plan-cache 3)
unforced_phase_2=$(echo "$unforced_cycle2_out" | jq -r '.dispatch | map(select(.task == 3)) | .[0].phase // ""')
if [ "$unforced_phase_2" = "plan" ]; then
  pass "unforced counter-case: cycle 2 (researched) advances to plan"
else
  fail "unforced counter-case: cycle 2 expected phase=plan, got '$unforced_phase_2': $unforced_cycle2_out"
fi

"$WORKDIR/.claude/scripts/state-write.sh" \
  '(.active_projects[] | select(.project_number == 3) | .status) = "planned"' \
  --session-id "sess_test_unforced_postflight_2"
unforced_cycle3_out=$(run_cycle_plan --session "$UNFORCED_SESSION" --no-plan-cache 3)
unforced_phase_3=$(echo "$unforced_cycle3_out" | jq -r '.dispatch | map(select(.task == 3)) | .[0].phase // ""')
if [ "$unforced_phase_3" = "implement" ]; then
  pass "unforced counter-case: cycle 3 (planned) advances to implement"
else
  fail "unforced counter-case: cycle 3 expected phase=implement, got '$unforced_phase_3': $unforced_cycle3_out"
fi

# =====================================================================
# STAGE 0 hold admission: an explicit forcing flag admits a held candidate through
# commands/orchestrate.md's STAGE 0 validated_tasks loop; without one, the candidate is skipped
# with a hold-specific reason distinct from the terminal-status skip. Extracted directly from the
# source-store markdown command file (never the deployed copy, matching this suite's own
# source-store-first inversion rationale at its header) and run in isolation against a synthetic
# specs/state.json -- the command file is markdown with embedded bash, not a sourced script, so
# this is the only way to exercise its STAGE 0 logic without invoking the full /orchestrate flow.
# NOTE on fixture numbering (matching test-orchestrate-cycle-plan.sh's own convention): the
# project_number below is synthetic fixture data for this suite only -- messages say "candidate
# #N", never "task N".
# =====================================================================
info "=== STAGE 0 hold admission (commands/orchestrate.md) ==="
ORCH_MD="$SOURCE_STORE_SCRIPTS/../commands/orchestrate.md"
if [[ ! -f "$ORCH_MD" ]]; then
  echo "ERROR: expected commands/orchestrate.md at $ORCH_MD" >&2
  exit 2
fi
STAGE0_SNIPPET=$(awk '/^validated_tasks=\(\); skipped_tasks=\(\)$/{flag=1} flag{print} flag && /^done$/{exit}' "$ORCH_MD")
if [[ -z "$STAGE0_SNIPPET" ]]; then
  echo "ERROR: could not extract the STAGE 0 validated_tasks loop from $ORCH_MD (anchor text drifted?)" >&2
  exit 2
fi
if ! echo "$STAGE0_SNIPPET" | grep -q "hold)"; then
  echo "ERROR: extracted STAGE 0 snippet has no hold) arm -- extraction anchor or source file is wrong" >&2
  exit 2
fi

STAGE0_WORKDIR="$(mktemp -d)"
mkdir -p "$STAGE0_WORKDIR/specs"
cat > "$STAGE0_WORKDIR/specs/state.json" << 'EOF'
{
  "active_projects": [
    {"project_number": 42, "project_name": "held_fixture", "status": "hold", "hold_reason": "waiting on vendor decision"}
  ]
}
EOF

run_stage0() {
  # $1 = FORCE_PHASES_FLAG value ("" or "implement")
  (
    cd "$STAGE0_WORKDIR" || exit 2
    # shellcheck disable=SC2034  # consumed by `eval "$STAGE0_SNIPPET"` below, invisible to static analysis
    TASK_NUMBERS=(42)
    FORCE_PHASES_FLAG="$1"
    eval "$STAGE0_SNIPPET"
    printf 'validated_tasks=%s\n' "${validated_tasks[*]:-}"
    printf 'skipped_tasks=%s\n' "${skipped_tasks[*]:-}"
  )
}

stage0_unforced_out="$(run_stage0 "")"
stage0_unforced_validated=$(echo "$stage0_unforced_out" | grep '^validated_tasks=' | cut -d= -f2-)
stage0_unforced_skipped=$(echo "$stage0_unforced_out" | grep '^skipped_tasks=' | cut -d= -f2-)
if [[ -z "$stage0_unforced_validated" ]] && echo "$stage0_unforced_skipped" | grep -q "held \[waiting on vendor decision\]"; then
  pass "STAGE 0, no forcing flag: held candidate #42 is skipped with a hold-specific reason, not validated"
else
  fail "STAGE 0, no forcing flag: expected empty validated_tasks and a hold-specific skip reason, got validated='$stage0_unforced_validated' skipped='$stage0_unforced_skipped'"
fi

stage0_forced_out="$(run_stage0 "implement")"
stage0_forced_validated=$(echo "$stage0_forced_out" | grep '^validated_tasks=' | cut -d= -f2-)
if [[ "$stage0_forced_validated" == "42" ]]; then
  pass "STAGE 0, --force-phases set: held candidate #42 IS admitted into validated_tasks"
else
  fail "STAGE 0, --force-phases set: expected validated_tasks='42', got '$stage0_forced_validated'"
fi

rm -rf "$STAGE0_WORKDIR"

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
