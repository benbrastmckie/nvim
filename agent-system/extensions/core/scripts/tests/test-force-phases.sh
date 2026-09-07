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
mkdir -p "$WORKDIR/.claude/scripts/lib" "$WORKDIR/specs"
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
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
