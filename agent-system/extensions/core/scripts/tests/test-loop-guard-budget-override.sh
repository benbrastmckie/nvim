#!/usr/bin/env bash
# test-loop-guard-budget-override.sh - Regression suite for Defect B: the explicit,
# operator-typed `--continue-budget` override that lets an operator continue a task's work past
# an exhausted MAX_CYCLES work-cycle budget.
#
# FORMER TWO-TARGET STRUCTURE, NOW SINGLE-TARGET (the four-move loop rewrite deleted the
# single-task engine -- see docs/architecture/orchestrate-state-machine.md): this suite used to
# cover the override mechanism in two engines. Former TARGET 1 -- the merged single-task
# `skill-orchestrate/SKILL.md` engine, exercised via a `budget-continuation-override:begin`
# sentinel-region extraction -- is REMOVED, not retargeted: that sentinel lived inside the
# deleted single-task Stage 2 (Loop Guard Initialization), which no longer exists anywhere in
# SKILL.md, and the mechanism it exercised is already the SAME code TARGET 2 below tests directly
# (Decision 1 of the task that ported single-task's loop guard into the batch engine moved this
# exact mechanism -- archive-aside, reset `cycle_count` to 0 in place, preserve
# `dispatch_seq_counter`/`detected_defects` -- into `orchestrate-cycle-plan.sh`'s own top-of-cycle
# eligibility loop, well before this rewrite). Retargeting Target 1's extraction harness onto
# orchestrate-cycle-plan.sh would duplicate coverage TARGET 2 (below) and
# `test-orchestrate-cycle-plan.sh`'s own much larger, authoritative Group 8 already provide
# (cross-session cumulative resume, mode-aware `max_cycles`, mixed-batch exclusion); per this
# task's own guidance, the duplicate is deleted rather than retargeted.
#
# TARGET 2 (below): `orchestrate-cycle-plan.sh` itself, called directly. Its two cases re-prove
# the same headline properties former Target 1's Cases 1/2 used to prove, against the batch
# engine; `test-orchestrate-cycle-plan.sh`'s own Group 8 remains the authoritative, much larger
# suite for that engine -- this section is a second, narrower angle from this suite's own name,
# not a replacement for Group 8.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT


# =====================================================================
# MAX_CYCLES message assertion (retargeted -- the former single-task Stage 7 that used to own
# this message is deleted; orchestrate-cycle-plan.sh's own top-of-cycle budget guard is the
# sole site that emits it now, for every batch size including a batch of one).
# =====================================================================
CYCLE_PLAN_FILE="$REPO_ROOT/agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh"
if [[ -f "$CYCLE_PLAN_FILE" ]] && \
   grep -q 'MAX_CYCLES reached' "$CYCLE_PLAN_FILE" && \
   grep -q -- '--continue-budget' "$CYCLE_PLAN_FILE"; then
  pass "orchestrate-cycle-plan.sh's MAX_CYCLES message names --continue-budget"
else
  fail "orchestrate-cycle-plan.sh's MAX_CYCLES message does not name --continue-budget (or the file was not found)"
fi

# =====================================================================
# test-session-runtime-files.sh Case 3 byte-stability: git diff HEAD must be empty for the base
# engine file, or a recorded justification must exist. This suite runs the check itself rather
# than trusting a hand-authored claim.
# =====================================================================
SESSION_TEST_CANDIDATES=(
  "$SCRIPT_DIR/../test-session-runtime-files.sh"
  "$REPO_ROOT/.claude/scripts/test-session-runtime-files.sh"
)
SESSION_TEST=""
for candidate in "${SESSION_TEST_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    SESSION_TEST="$candidate"
    break
  fi
done
if [[ -n "$SESSION_TEST" ]]; then
  if bash "$SESSION_TEST" >"$WORKDIR/session-runtime.out" 2>&1; then
    pass "test-session-runtime-files.sh passes (Case 3 included)"
  else
    fail "test-session-runtime-files.sh FAILED -- see $WORKDIR/session-runtime.out"
    cat "$WORKDIR/session-runtime.out"
  fi
else
  info "test-session-runtime-files.sh not found at any candidate path -- skipping (not this suite's environment error)"
fi

# =====================================================================
# TARGET 2: orchestrate-cycle-plan.sh's OWN budget guard / --continue-budget path, direct (not
# SKILL.md-extracted). Decision 1 of the task that ported single-task's loop-guard budget into
# the batch engine moved this exact mechanism (archive-aside, reset cycle_count to 0 in place,
# preserve dispatch_seq_counter/detected_defects) into that script's own top-of-cycle eligibility
# loop. This section re-proves the SAME two headline properties Cases 1/2 above prove for the
# SKILL.md-extracted region -- refusal without the flag, archive+reset+preserve+dispatch with it
# -- against the batch engine directly, one case each, rather than duplicating
# test-orchestrate-cycle-plan.sh's own much larger Group 8 (which already covers this in full,
# including cross-session cumulative resume and mode-aware max_cycles; this section is a second,
# narrower angle on the same underlying mechanism, not a replacement for that suite).
# =====================================================================
info "TARGET 2: orchestrate-cycle-plan.sh direct (not SKILL.md-extracted)"

CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CP_SUT_SRC="$CORE_DIR/orchestrate-cycle-plan.sh"

if [[ ! -f "$CP_SUT_SRC" ]]; then
  fail "TARGET 2: orchestrate-cycle-plan.sh not found at $CP_SUT_SRC -- skipping this target's cases"
else
  CP_WORKDIR="$WORKDIR/cycle-plan-target"
  mkdir -p "$CP_WORKDIR/.claude/scripts/lib" "$CP_WORKDIR/specs"
  cp_ok=true
  for f in orchestrate-cycle-plan.sh orchestrate-batch-admit.sh orchestrate-triage-classify.sh \
           task-lock.sh orchestrate-loop-guard-init.sh \
           deploy-root-guard.sh command-route-agent.sh skill-base.sh; do
    if [[ -f "$CORE_DIR/$f" ]]; then
      cp "$CORE_DIR/$f" "$CP_WORKDIR/.claude/scripts/$f"
    else
      fail "TARGET 2: missing collaborator $f -- environment error for this target"
      cp_ok=false
    fi
  done
  for f in common.sh file-scope-overlap.sh continuation-pointer-lib.sh manifest-routing-lib.sh \
           phase-heading-patterns.sh deploy-baseline-lib.sh; do
    if [[ -f "$CORE_DIR/lib/$f" ]]; then
      cp "$CORE_DIR/lib/$f" "$CP_WORKDIR/.claude/scripts/lib/$f"
    else
      fail "TARGET 2: missing collaborator lib/$f -- environment error for this target"
      cp_ok=false
    fi
  done
  mkdir -p "$CP_WORKDIR/.claude/context/reference"
  if [[ -f "$CORE_DIR/../context/reference/orchestrator-critical-paths.json" ]]; then
    cp "$CORE_DIR/../context/reference/orchestrator-critical-paths.json" \
       "$CP_WORKDIR/.claude/context/reference/orchestrator-critical-paths.json"
  else
    cp_ok=false
  fi
  chmod +x "$CP_WORKDIR"/.claude/scripts/*.sh 2>/dev/null || true

  if [[ "$cp_ok" == "true" ]]; then
    CP_SUT="$CP_WORKDIR/.claude/scripts/orchestrate-cycle-plan.sh"
    CP_STATE_FILE="$CP_WORKDIR/specs/state.json"
    cat > "$CP_STATE_FILE" <<'EOF'
{
  "active_projects": [
    {"project_number": 950, "project_name": "loop_guard_target2", "task_type": "general", "status": "implementing", "description": "budget-override direct-target candidate", "dependencies": [], "file_scope": []}
  ]
}
EOF
    mkdir -p "$CP_WORKDIR/specs/950_loop_guard_target2"
    jq -n --argjson dsc 7 --argjson dd '["marker"]' \
      '{cycle_count: 13, dispatch_seq_counter: $dsc, detected_defects: $dd}' \
      > "$CP_WORKDIR/specs/950_loop_guard_target2/.orchestrator-loop-guard"

    # Stubs for the LIVE-only dispatch path Case T2-2 reaches (Case T2-1 refuses before either is
    # called) -- neither script's own real behavior is under test here, only that a re-authorized
    # candidate reaches an actual dispatch this cycle. Mirrors test-orchestrate-cycle-plan.sh's own
    # Group 4/5 stub convention.
    cat > "$CP_WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh" <<'EOF'
#!/usr/bin/env bash
proj_num="$1"; phase="$2"
jq -n -c --arg f "/fake/${proj_num}-${phase}.md" '{dispatch_file: $f, model: ""}'
EOF
    chmod +x "$CP_WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh"
    cat > "$CP_WORKDIR/.claude/scripts/update-task-status.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$CP_WORKDIR/.claude/scripts/update-task-status.sh"

    # Case T2-1: exhausted (cycle_count=13=hard-mode MAX_CYCLES), flag ABSENT -- blocked with the
    # MAX_CYCLES reason, guard file left fully in place.
    cp_out=$(bash "$CP_SUT" --session t2_sess_a --state-file "$CP_STATE_FILE" --hard 950 2>"$WORKDIR/t2-case1.err")
    if echo "$cp_out" | jq -e '.blocked | map(select(.task == 950)) | length == 1' >/dev/null 2>&1 && \
       [[ "$(echo "$cp_out" | jq -r '.blocked[0].reason')" == *MAX_CYCLES* ]]; then
      pass "TARGET 2 case T2-1: exhausted budget blocks (flag absent), reason names MAX_CYCLES"
    else
      fail "TARGET 2 case T2-1: expected a blocked row naming MAX_CYCLES (stdout: $cp_out)"
    fi
    if [[ "$(jq -r '.cycle_count' "$CP_WORKDIR/specs/950_loop_guard_target2/.orchestrator-loop-guard")" == "13" ]]; then
      pass "TARGET 2 case T2-1: durable guard file left unchanged (cycle_count still 13)"
    else
      fail "TARGET 2 case T2-1: durable guard file was unexpectedly modified"
    fi

    # Case T2-2: same exhausted guard, flag PRESENT -- archived aside, reset to cycle_count=0 in
    # place (then charged to 1 by this same cycle's own live dispatch), dispatch_seq_counter and
    # detected_defects preserved, and a dispatch actually occurs this cycle.
    cp_out2=$(bash "$CP_SUT" --session t2_sess_b --state-file "$CP_STATE_FILE" --hard --continue-budget 950 2>"$WORKDIR/t2-case2.err")
    if echo "$cp_out2" | jq -e '.dispatch | map(select(.task == 950)) | length == 1' >/dev/null 2>&1; then
      pass "TARGET 2 case T2-2: --continue-budget authorizes a dispatch this cycle"
    else
      fail "TARGET 2 case T2-2: expected a dispatch row for the re-authorized candidate (stdout: $cp_out2)"
    fi
    post_guard="$CP_WORKDIR/specs/950_loop_guard_target2/.orchestrator-loop-guard"
    if [[ -f "$post_guard" ]] && [[ "$(jq -r '.dispatch_seq_counter' "$post_guard")" == "7" ]] && \
       [[ "$(jq -r '.detected_defects | length' "$post_guard")" == "1" ]]; then
      pass "TARGET 2 case T2-2: --continue-budget's reset preserves dispatch_seq_counter and detected_defects"
    else
      fail "TARGET 2 case T2-2: dispatch_seq_counter/detected_defects not preserved (got: $(cat "$post_guard" 2>/dev/null))"
    fi
    archived_count=$(find "$CP_WORKDIR/specs/950_loop_guard_target2" -maxdepth 1 -name '.exhausted-loop-guard-*.json' 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$archived_count" -ge 1 ]]; then
      pass "TARGET 2 case T2-2: the exhausted guard is archived aside for auditability"
    else
      fail "TARGET 2 case T2-2: no archived exhausted-guard file found"
    fi
  fi
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
