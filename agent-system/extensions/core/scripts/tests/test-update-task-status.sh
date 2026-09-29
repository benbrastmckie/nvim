#!/usr/bin/env bash
# test-update-task-status.sh - Fixture-driven regression suite for
# scripts/update-task-status.sh, covering preflight/postflight transitions, the
# --phase-check=warn|refuse backstop, and its interaction with
# lib/phase-heading-patterns.sh's non-conforming-heading detection.
#
# NOTE on scope: this plan's own task list named "the refusal path on terminal statuses" as a
# case to cover. Live inspection of update-task-status.sh (all 564 lines) found NO terminal-status
# (completed/abandoned/expanded) refusal logic anywhere in the script -- it has no awareness of
# terminal statuses at all and will happily flip any task's state.json status field regardless of
# its current value. Enforcement of state-management.md's "any non-terminal status -> any command"
# permissive-transition model, if it exists, lives in a calling layer (a skill or command),
# never in this script. This is a stale planning assumption, the same class of finding recorded
# in this task's phase 7 closing commit for a different file -- no fabricated test case was
# written for behavior that does not exist; the suite instead covers the backstop this script
# DOES implement (--phase-check) at the depth the task list asked for.
#
# Structural model: test-corroborate-phase-counts.sh / test-skill-base-lifecycle.sh (mktemp -d
# workdir with an EXIT-trap cleanup, deploy-tree-first / source-store-fallback candidate
# resolution for the target script and its dependency chain, pass()/fail()/info() helpers with
# integer counters, exit 0 all-pass / 1 any-fail / 2 environment error).
#
# ISOLATION CONTRACT: every case runs against a complete, isolated fixture repo built fresh
# under a mktemp -d WORKDIR (a real deployed .claude/scripts/ dependency chain copied in, plus a
# private specs/state.json and task directory with a plan file carrying conforming phase
# headings). update-task-status.sh resolves its own PROJECT_ROOT from its OWN script location
# (BASH_SOURCE-relative, via common_repo_root), not from cwd, so no `cd` is required for the
# state.json path to resolve into the fixture -- only the subprocess invocation path itself
# (`$FIXTURE_ROOT/.claude/scripts/update-task-status.sh ...`) needs to point at the fixture
# copy. The suite never touches the real specs/ tree, real state.json, or real task locks.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

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

DEPLOY_SCRIPTS_SRC="$REPO_ROOT/.claude/scripts"
if [[ ! -d "$DEPLOY_SCRIPTS_SRC" ]]; then
  echo "ERROR: deployed scripts tree not found at $DEPLOY_SCRIPTS_SRC -- this suite needs a" >&2
  echo "       real deployed .claude/scripts/ tree to copy update-task-status.sh's dependency" >&2
  echo "       chain from." >&2
  exit 2
fi
REQUIRED_SCRIPTS=(update-task-status.sh state-write.sh task-lock.sh generate-todo.sh
                   generate-task-order.sh update-plan-status.sh update-phase-status.sh
                   deploy-root-guard.sh)
for req in "${REQUIRED_SCRIPTS[@]}"; do
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

BASELINE_SPECS_STATUS="$(cd "$REPO_ROOT" && git status --short specs/ 2>/dev/null)"

# ─── build_fixture_repo <root>: a full isolated repo shape, real deployed scripts copied in ────
build_fixture_repo() {
  local root="$1"
  mkdir -p "$root/.claude/scripts/lib" "$root/specs"
  for f in "${REQUIRED_SCRIPTS[@]}"; do
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
      "status": "not_started",
      "task_type": "general",
      "next_artifact_number": 1
    }
  ]
}
EOF
}

UTS() { "$FIXTURE_ROOT/.claude/scripts/update-task-status.sh" "$@"; }
task_status() { jq -r '.active_projects[0].status' "$FIXTURE_ROOT/specs/state.json" 2>/dev/null; }

# =====================================================================
# Case 1: preflight transition (not_started -> researching)
# =====================================================================
info "=== Case 1: preflight transition ==="
FIXTURE_ROOT="$WORKDIR/case1"
build_fixture_repo "$FIXTURE_ROOT"

if UTS preflight 1 research sess_test_c1 >"$WORKDIR/c1.out" 2>"$WORKDIR/c1.err"; then
  st="$(task_status)"
  if [[ "$st" == "researching" ]]; then
    pass "preflight research: not_started -> researching"
  else
    fail "preflight research: expected 'researching', got '$st' (see $WORKDIR/c1.err)"
  fi
else
  fail "preflight research exited nonzero (see $WORKDIR/c1.err)"
fi

# =====================================================================
# Case 2: postflight transition (researching -> researched), continuing from Case 1's fixture
# =====================================================================
info "=== Case 2: postflight transition ==="
if UTS postflight 1 research sess_test_c1 >"$WORKDIR/c2.out" 2>"$WORKDIR/c2.err"; then
  st="$(task_status)"
  if [[ "$st" == "researched" ]]; then
    pass "postflight research: researching -> researched"
  else
    fail "postflight research: expected 'researched', got '$st' (see $WORKDIR/c2.err)"
  fi
else
  fail "postflight research exited nonzero (see $WORKDIR/c2.err)"
fi

# =====================================================================
# Case 3: generate-todo.sh regeneration is invoked (TODO.md appears/updates as a side effect)
# =====================================================================
info "=== Case 3: TODO.md regeneration ==="
if [[ -f "$FIXTURE_ROOT/specs/TODO.md" ]]; then
  if grep -q "fixture_task\|RESEARCHED" "$FIXTURE_ROOT/specs/TODO.md" 2>/dev/null; then
    pass "generate-todo.sh regenerated specs/TODO.md with the fixture task's current status"
  else
    fail "specs/TODO.md exists but does not reflect the fixture task (see $FIXTURE_ROOT/specs/TODO.md)"
  fi
else
  fail "generate-todo.sh did not produce specs/TODO.md in the fixture"
fi

# =====================================================================
# Case 4: idempotency (no-op) -- re-running the same postflight call must not error and must
# leave status unchanged, while still regenerating TODO.md (self-healing on retry).
# =====================================================================
info "=== Case 4: idempotency (no-op) ==="
rm -f "$FIXTURE_ROOT/specs/TODO.md"
if UTS postflight 1 research sess_test_c1 >"$WORKDIR/c4.out" 2>"$WORKDIR/c4.err"; then
  st="$(task_status)"
  if [[ "$st" == "researched" ]]; then
    pass "idempotent postflight replay leaves status unchanged (researched)"
  else
    fail "idempotent postflight replay changed status to '$st' unexpectedly"
  fi
  if [[ -f "$FIXTURE_ROOT/specs/TODO.md" ]]; then
    pass "idempotent postflight replay still regenerates TODO.md (self-healing on retry)"
  else
    fail "idempotent postflight replay did not regenerate TODO.md"
  fi
else
  fail "idempotent postflight replay exited nonzero (see $WORKDIR/c4.err)"
fi

# =====================================================================
# Case 5: --phase-check=warn on an INCOMPLETE plan -- logs loudly, proceeds (exit 0, status DOES
# flip to completed).
# =====================================================================
info "=== Case 5: --phase-check=warn (incomplete plan) ==="
FIXTURE_ROOT="$WORKDIR/case5"
build_fixture_repo "$FIXTURE_ROOT"
mkdir -p "$FIXTURE_ROOT/specs/001_fixture_task/plans"
cat > "$FIXTURE_ROOT/specs/001_fixture_task/plans/01_fixture-plan.md" << 'PLANEOF'
# Implementation Plan: Fixture Task

- **Status**: [IMPLEMENTING]

## Implementation Phases

### Phase 1: First phase [COMPLETED]

### Phase 2: Second phase [NOT STARTED]
PLANEOF
UTS preflight 1 implement sess_test_c5 >/dev/null 2>&1
UTS postflight 1 implement sess_test_c5 --phase-check=warn >"$WORKDIR/c5.out" 2>"$WORKDIR/c5.err"
C5_EXIT=$?
if [[ "$C5_EXIT" -eq 0 ]]; then
  if grep -q "WARNING.*phase-check" "$WORKDIR/c5.err"; then
    pass "--phase-check=warn on an incomplete plan (1/2 phases) logs a WARNING"
  else
    fail "--phase-check=warn did not log the expected WARNING (see $WORKDIR/c5.err)"
  fi
  st="$(task_status)"
  if [[ "$st" == "completed" ]]; then
    pass "--phase-check=warn still proceeds with the status flip (implementing -> completed)"
  else
    fail "--phase-check=warn: expected status 'completed', got '$st'"
  fi
else
  fail "--phase-check=warn unexpectedly exited nonzero ($C5_EXIT) (see $WORKDIR/c5.err)"
fi

# =====================================================================
# Case 6: --phase-check=refuse on the SAME incomplete plan shape -- exits 4, writes NOTHING
# (state.json status stays 'implementing', no plan-file [COMPLETED] stamp).
# =====================================================================
info "=== Case 6: --phase-check=refuse (incomplete plan) ==="
FIXTURE_ROOT="$WORKDIR/case6"
build_fixture_repo "$FIXTURE_ROOT"
mkdir -p "$FIXTURE_ROOT/specs/001_fixture_task/plans"
cat > "$FIXTURE_ROOT/specs/001_fixture_task/plans/01_fixture-plan.md" << 'PLANEOF'
# Implementation Plan: Fixture Task

- **Status**: [IMPLEMENTING]

## Implementation Phases

### Phase 1: First phase [COMPLETED]

### Phase 2: Second phase [NOT STARTED]
PLANEOF
UTS preflight 1 implement sess_test_c6 >/dev/null 2>&1
UTS postflight 1 implement sess_test_c6 --phase-check=refuse >"$WORKDIR/c6.out" 2>"$WORKDIR/c6.err"
C6_EXIT=$?
if [[ "$C6_EXIT" -eq 4 ]]; then
  pass "--phase-check=refuse on an incomplete plan (1/2 phases) exits 4"
else
  fail "--phase-check=refuse: expected exit 4, got $C6_EXIT (see $WORKDIR/c6.err)"
fi
st="$(task_status)"
if [[ "$st" == "implementing" ]]; then
  pass "--phase-check=refuse writes NOTHING to state.json (status stays 'implementing')"
else
  fail "--phase-check=refuse: expected status to stay 'implementing', got '$st' -- state.json was written despite the refusal"
fi
if grep -qE '^\*\*Status\*\*: \[COMPLETED\]' "$FIXTURE_ROOT/specs/001_fixture_task/plans/01_fixture-plan.md" 2>/dev/null; then
  fail "--phase-check=refuse: plan file top-level Status was stamped [COMPLETED] despite the refusal"
else
  pass "--phase-check=refuse: plan file top-level Status was NOT stamped (no plan-file write occurred)"
fi

# =====================================================================
# Case 7: non-conforming phase heading -- INCONCLUSIVE, passes through even under
# --phase-check=refuse (the count is refused as evidence, not trusted as "incomplete").
# =====================================================================
info "=== Case 7: non-conforming heading -> inconclusive, passes through ==="
FIXTURE_ROOT="$WORKDIR/case7"
build_fixture_repo "$FIXTURE_ROOT"
mkdir -p "$FIXTURE_ROOT/specs/001_fixture_task/plans"
cat > "$FIXTURE_ROOT/specs/001_fixture_task/plans/01_fixture-plan.md" << 'PLANEOF'
# Implementation Plan: Fixture Task

- **Status**: [IMPLEMENTING]

## Implementation Phases

### Phase 1: First phase [COMPLETED]

### Phase 2: Second phase [DESCOPED]
PLANEOF
UTS preflight 1 implement sess_test_c7 >/dev/null 2>&1
UTS postflight 1 implement sess_test_c7 --phase-check=refuse >"$WORKDIR/c7.out" 2>"$WORKDIR/c7.err"
C7_EXIT=$?
if [[ "$C7_EXIT" -eq 0 ]]; then
  pass "a non-conforming [DESCOPED] heading makes the count inconclusive; --phase-check=refuse passes through (exit 0)"
else
  fail "--phase-check=refuse: expected exit 0 (inconclusive pass-through) for a non-conforming heading, got $C7_EXIT (see $WORKDIR/c7.err)"
fi
if grep -q "non-conforming\|INCONCLUSIVE" "$WORKDIR/c7.err"; then
  pass "non-conforming heading path logs the INCONCLUSIVE/non-conforming diagnostic"
else
  fail "non-conforming heading path did not log the expected diagnostic (see $WORKDIR/c7.err)"
fi
st="$(cd "$FIXTURE_ROOT" && jq -r '.active_projects[0].status' specs/state.json 2>/dev/null)"
if [[ "$st" == "completed" ]]; then
  pass "non-conforming heading pass-through still completes the status flip (implementing -> completed)"
else
  fail "non-conforming heading pass-through: expected status 'completed', got '$st'"
fi

# =====================================================================
# Case 8 (failing-input case): usage error -- missing required positional arguments -> exit 1
# =====================================================================
info "=== Case 8: usage/validation errors ==="
FIXTURE_ROOT="$WORKDIR/case8"
build_fixture_repo "$FIXTURE_ROOT"
if UTS preflight 1 >"$WORKDIR/c8.out" 2>"$WORKDIR/c8.err"; then
  fail "missing session_id argument: expected exit 1, got exit 0"
else
  c8_exit=$?
  if [[ "$c8_exit" -eq 1 ]]; then
    pass "missing session_id argument exits 1 with a usage message"
  else
    fail "missing session_id argument: expected exit 1, got $c8_exit"
  fi
fi

# Failing-input case: a non-integer task_number must be rejected (exit 1), never silently
# coerced or passed through to the jq lookup.
if UTS preflight not-a-number research sess_test_c8b >"$WORKDIR/c8b.out" 2>"$WORKDIR/c8b.err"; then
  fail "non-integer task_number: expected exit 1, got exit 0"
else
  c8b_exit=$?
  if [[ "$c8b_exit" -eq 1 ]]; then
    pass "non-integer task_number is rejected with exit 1"
  else
    fail "non-integer task_number: expected exit 1, got $c8b_exit"
  fi
fi

# =====================================================================
# Case 9: off-schema status -> generate-todo.sh hard-fails (nonzero exit, named error), writing
# nothing, instead of silently rendering an uppercased marker (the permissive `*)` catch-all this
# task's plan removed). Seeds the off-schema value directly into the fixture's state.json (not
# via update-task-status.sh, which independently validates its own resolved resting state and
# would reject 'foobar' before it ever reached state.json) -- this case is specifically about
# generate-todo.sh's OWN format_status()/status_vocabulary_todo_marker() enforcement, exercised
# the same way a corrupted or hand-edited state.json would trigger it.
#
# task-ref-ok:begin category 6-adjacent: the asserted substring below is generate-todo.sh's own
# literal runtime error text, which embeds the fixture's project_number (1) via its
# "for task ${task_num}" format string -- a functional assertion on produced output, not a
# citation of this repo's own ephemeral task tracker.
# =====================================================================
info "=== Case 9: off-schema status -> generate-todo.sh hard-fails ==="
FIXTURE_ROOT="$WORKDIR/case9"
build_fixture_repo "$FIXTURE_ROOT"
jq '.active_projects[0].status = "foobar"' "$FIXTURE_ROOT/specs/state.json" > "$WORKDIR/c9-state.json.tmp"
mv "$WORKDIR/c9-state.json.tmp" "$FIXTURE_ROOT/specs/state.json"

rm -f "$FIXTURE_ROOT/specs/TODO.md"
if "$FIXTURE_ROOT/.claude/scripts/generate-todo.sh" \
    --state "$FIXTURE_ROOT/specs/state.json" --todo "$FIXTURE_ROOT/specs/TODO.md" --no-log \
    >"$WORKDIR/c9.out" 2>"$WORKDIR/c9.err"; then
  fail "off-schema status 'foobar': expected generate-todo.sh to exit nonzero, got exit 0"
else
  c9_exit=$?
  if [[ "$c9_exit" -eq 1 ]]; then
    pass "off-schema status 'foobar': generate-todo.sh exits 1"
  else
    fail "off-schema status 'foobar': expected exit 1, got $c9_exit"
  fi
fi
if grep -q "off-schema status 'foobar' for task 1" "$WORKDIR/c9.err"; then
  pass "off-schema status error names both the bad value and the fixture's project_number"
else
  fail "off-schema status error did not name the value and project_number as expected (see $WORKDIR/c9.err)"
fi
# task-ref-ok:end
if [[ -f "$FIXTURE_ROOT/specs/TODO.md" ]]; then
  fail "off-schema status: TODO.md was written despite the hard-fail (nothing should be written)"
else
  pass "off-schema status: nothing was written to TODO.md"
fi

# =====================================================================
# Case 10: implement preflight regression guard -- a preflight that dispatches nothing for a
# phase must never advance that phase's marker, because a false [IN PROGRESS] marker feeds
# fabricated territory-conflict signals into hard-mode dispatch reasoning (the defect this
# suite's authoring plan deletes update_plan_file()'s auto-advance convenience to fix). Asserts
# a non-dispatching implement preflight leaves plan phase headings byte-identical, with a
# required positive control proving the fixture plan file was actually found and processed.
# =====================================================================
info "=== Case 10: implement preflight leaves phase headings byte-identical ==="
FIXTURE_ROOT="$WORKDIR/case10"
build_fixture_repo "$FIXTURE_ROOT"
# 'planned' is a legitimate resting status from which an implement preflight is valid.
jq '.active_projects[0].status = "planned"' "$FIXTURE_ROOT/specs/state.json" > "$WORKDIR/c10-state.json.tmp"
mv "$WORKDIR/c10-state.json.tmp" "$FIXTURE_ROOT/specs/state.json"
mkdir -p "$FIXTURE_ROOT/specs/001_fixture_task/plans"
cat > "$FIXTURE_ROOT/specs/001_fixture_task/plans/01_fixture-plan.md" << 'PLANEOF'
# Implementation Plan: Fixture Task

- **Status**: [NOT STARTED]

## Implementation Phases

### Phase 1: First phase [NOT STARTED]

### Phase 2: Second phase [NOT STARTED]
PLANEOF

C10_PLAN="$FIXTURE_ROOT/specs/001_fixture_task/plans/01_fixture-plan.md"
BEFORE_HEADINGS="$(grep -E '^### Phase ' "$C10_PLAN")"

if UTS preflight 1 implement sess_test_c10 >"$WORKDIR/c10.out" 2>"$WORKDIR/c10.err"; then
  C10_EXIT=0
else
  C10_EXIT=$?
fi

AFTER_HEADINGS="$(grep -E '^### Phase ' "$C10_PLAN")"

if [[ "$BEFORE_HEADINGS" == "$AFTER_HEADINGS" ]]; then
  pass "implement preflight leaves plan phase headings byte-identical (no dispatch, no advance)"
else
  fail "implement preflight changed phase headings unexpectedly -- before:
$BEFORE_HEADINGS
-- after:
$AFTER_HEADINGS"
fi

if grep -q '\[IN PROGRESS\]' "$C10_PLAN"; then
  fail "implement preflight left a phase heading marked [IN PROGRESS] -- the deleted auto-advance regressed"
else
  pass "no phase heading contains [IN PROGRESS] after a non-dispatching implement preflight"
fi

# Positive control (required): the call must have exited 0 AND the plan-level Status line must
# have flipped to [IMPLEMENTING], proving update_plan_file() was entered and the fixture plan
# file was found -- without this, the case above would pass even if the fixture were never
# located, making it worthless as a regression guard.
if [[ "$C10_EXIT" -eq 0 ]]; then
  pass "Case 10 positive control: implement preflight call exited 0 (see $WORKDIR/c10.err on failure)"
else
  fail "Case 10 positive control: implement preflight call exited $C10_EXIT (see $WORKDIR/c10.err)"
fi
if grep -qE '^- \*\*Status\*\*: \[IMPLEMENTING\]' "$C10_PLAN"; then
  pass "Case 10 positive control: plan-level Status line flipped to [IMPLEMENTING] (function was entered, plan file was found)"
else
  fail "Case 10 positive control: plan-level Status line did not flip to [IMPLEMENTING] -- the byte-identity assertion above would be vacuous"
fi

# =====================================================================
# Case 11: --file-scope-add -- additive-only union-merge onto file_scope, restricted to
# operation=postflight/target_status in {research, plan}. Eight sub-cases (a)-(h) share one
# fixture, run in sequence, mirroring Case 1/2's continuation pattern. (g)/(h) cover the
# target_status=plan widening this phase adds: (g) asserts plan is now accepted, (h) asserts
# implement is still rejected under postflight (the target_status axis, distinct from (f)'s
# operation axis).
# =====================================================================
info "=== Case 11: --file-scope-add ==="
FIXTURE_ROOT="$WORKDIR/case11"
build_fixture_repo "$FIXTURE_ROOT"
file_scope() { jq -c '.active_projects[0].file_scope' "$FIXTURE_ROOT/specs/state.json" 2>/dev/null; }

UTS preflight 1 research sess_test_c11 >"$WORKDIR/c11pre.out" 2>"$WORKDIR/c11pre.err" || true

# --- 11a: an already-null file_scope becomes the added array (real, non-noop write path) ---
if UTS postflight 1 research sess_test_c11 --file-scope-add='["a.sh","b.sh"]' \
    >"$WORKDIR/c11a.out" 2>"$WORKDIR/c11a.err"; then
  fs="$(file_scope)"
  if [[ "$fs" == '["a.sh","b.sh"]' ]]; then
    pass "11a: null file_scope becomes the added array"
  else
    fail "11a: expected [\"a.sh\",\"b.sh\"], got '$fs' (see $WORKDIR/c11a.err)"
  fi
else
  fail "11a: postflight with --file-scope-add exited nonzero (see $WORKDIR/c11a.err)"
fi

# --- 11b: re-running with the same array is idempotent (status is now a no-op path) ---
if UTS postflight 1 research sess_test_c11 --file-scope-add='["a.sh","b.sh"]' \
    >"$WORKDIR/c11b.out" 2>"$WORKDIR/c11b.err"; then
  fs="$(file_scope)"
  if [[ "$fs" == '["a.sh","b.sh"]' ]]; then
    pass "11b: re-running with the same array is idempotent"
  else
    fail "11b: expected unchanged [\"a.sh\",\"b.sh\"], got '$fs' (see $WORKDIR/c11b.err)"
  fi
else
  fail "11b: idempotent re-run exited nonzero (see $WORKDIR/c11b.err)"
fi

# --- 11c: union adds only new paths (status no-op path; only 'c.sh' is genuinely new) ---
if UTS postflight 1 research sess_test_c11 --file-scope-add='["b.sh","c.sh"]' \
    >"$WORKDIR/c11c.out" 2>"$WORKDIR/c11c.err"; then
  fs="$(file_scope)"
  if [[ "$fs" == '["a.sh","b.sh","c.sh"]' ]]; then
    pass "11c: union adds only the new path ('c.sh'), 'b.sh' not duplicated"
  else
    fail "11c: expected [\"a.sh\",\"b.sh\",\"c.sh\"], got '$fs' (see $WORKDIR/c11c.err)"
  fi
else
  fail "11c: union-add call exited nonzero (see $WORKDIR/c11c.err)"
fi

# --- 11d: no flag leaves file_scope untouched ---
if UTS postflight 1 research sess_test_c11 >"$WORKDIR/c11d.out" 2>"$WORKDIR/c11d.err"; then
  fs="$(file_scope)"
  if [[ "$fs" == '["a.sh","b.sh","c.sh"]' ]]; then
    pass "11d: no --file-scope-add flag leaves file_scope untouched"
  else
    fail "11d: expected unchanged [\"a.sh\",\"b.sh\",\"c.sh\"], got '$fs' (see $WORKDIR/c11d.err)"
  fi
else
  fail "11d: postflight without the flag exited nonzero (see $WORKDIR/c11d.err)"
fi

# --- 11e: a malformed value exits non-zero without writing state ---
BEFORE_11E="$(jq -c '.active_projects[0]' "$FIXTURE_ROOT/specs/state.json")"
if UTS postflight 1 research sess_test_c11 --file-scope-add='{"bad":1}' \
    >"$WORKDIR/c11e.out" 2>"$WORKDIR/c11e.err"; then
  fail "11e: malformed --file-scope-add value unexpectedly exited 0"
else
  AFTER_11E="$(jq -c '.active_projects[0]' "$FIXTURE_ROOT/specs/state.json")"
  if [[ "$BEFORE_11E" == "$AFTER_11E" ]]; then
    pass "11e: malformed --file-scope-add value exits non-zero without writing state"
  else
    fail "11e: malformed --file-scope-add value exited non-zero but state.json changed anyway"
  fi
fi

# --- 11f: the flag on a non-research or non-postflight call is rejected ---
BEFORE_11F="$(jq -c '.active_projects[0]' "$FIXTURE_ROOT/specs/state.json")"
if UTS preflight 1 implement sess_test_c11 --file-scope-add='["x.sh"]' \
    >"$WORKDIR/c11f.out" 2>"$WORKDIR/c11f.err"; then
  fail "11f: --file-scope-add on preflight/implement unexpectedly exited 0"
else
  AFTER_11F="$(jq -c '.active_projects[0]' "$FIXTURE_ROOT/specs/state.json")"
  if [[ "$BEFORE_11F" == "$AFTER_11F" ]]; then
    pass "11f: --file-scope-add rejected on a non-research/non-postflight call, state unchanged"
  else
    fail "11f: --file-scope-add rejection exited non-zero but state.json changed anyway"
  fi
fi

# --- 11g: postflight ... plan ... --file-scope-add is now ACCEPTED and merges additively ---
# (the widened restriction this phase adds: target_status=plan alongside target_status=research)
if UTS postflight 1 plan sess_test_c11 --file-scope-add='["d.sh"]' \
    >"$WORKDIR/c11g.out" 2>"$WORKDIR/c11g.err"; then
  fs="$(file_scope)"
  if [[ "$fs" == '["a.sh","b.sh","c.sh","d.sh"]' ]]; then
    pass "11g: postflight/plan --file-scope-add is accepted and merges additively"
  else
    fail "11g: expected [\"a.sh\",\"b.sh\",\"c.sh\",\"d.sh\"], got '$fs' (see $WORKDIR/c11g.err)"
  fi
else
  fail "11g: postflight/plan --file-scope-add unexpectedly exited nonzero (see $WORKDIR/c11g.err)"
fi

# --- 11h: postflight ... implement ... --file-scope-add is STILL rejected (only research/plan
# are permitted target statuses under postflight; this exercises the target_status axis of the
# guard, distinct from 11f's operation axis) ---
BEFORE_11H="$(jq -c '.active_projects[0]' "$FIXTURE_ROOT/specs/state.json")"
if UTS postflight 1 implement sess_test_c11 --file-scope-add='["y.sh"]' \
    >"$WORKDIR/c11h.out" 2>"$WORKDIR/c11h.err"; then
  fail "11h: --file-scope-add on postflight/implement unexpectedly exited 0"
else
  AFTER_11H="$(jq -c '.active_projects[0]' "$FIXTURE_ROOT/specs/state.json")"
  if [[ "$BEFORE_11H" == "$AFTER_11H" ]]; then
    pass "11h: --file-scope-add rejected on postflight/implement, state unchanged"
  else
    fail "11h: --file-scope-add rejection exited non-zero but state.json changed anyway"
  fi
  if grep -q "target_status in {research, plan}" "$WORKDIR/c11h.err"; then
    pass "11h: rejection error names both permitted target statuses"
  else
    fail "11h: rejection error does not name both permitted target statuses (see $WORKDIR/c11h.err)"
  fi
fi

# =====================================================================
# Real-tree contamination guard (delta check against the pre-suite baseline; see
# test-skill-base-lifecycle.sh's identical guard for why this is a delta, not an absolute
# emptiness check).
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

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
