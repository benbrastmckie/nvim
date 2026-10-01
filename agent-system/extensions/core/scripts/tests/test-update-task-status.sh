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

# ─── SOURCE-STORE-FIRST OVERRIDE for the files THIS suite's hold coverage actually tests ────────
# Same deliberate inversion test-force-phases.sh documents at its own header (this repository's
# .claude/ tree is a gitignored, disposable deploy artifact regenerated from
# agent-system/extensions/** -- every OTHER loader in this codebase resolves deploy-tree-first,
# correct for validating what actually runs in production, but WRONG for a suite that must prove
# a pre-deploy source-store edit landed correctly). Scoped to EXACTLY the three files this task's
# hold-related work touches -- update-task-status.sh (preflight:hold/unhold, the hold-sticky
# guard), generate-todo.sh (the "- **Held**:" line), and lib/status-vocabulary.sh (the "hold"
# enum member/marker-map entry both of those depend on) -- never the rest of the dependency
# chain, which stays deploy-sourced exactly as every other case in this suite already relies on.
SOURCE_STORE_SCRIPTS="$REPO_ROOT/agent-system/extensions/core/scripts"
HOLD_OVERRIDE_FILES=(update-task-status.sh generate-todo.sh)
for hf in "${HOLD_OVERRIDE_FILES[@]}"; do
  if [[ ! -f "$SOURCE_STORE_SCRIPTS/$hf" ]]; then
    echo "ERROR: source-store override file missing: $SOURCE_STORE_SCRIPTS/$hf" >&2
    exit 2
  fi
done
if [[ ! -f "$SOURCE_STORE_SCRIPTS/lib/status-vocabulary.sh" ]]; then
  echo "ERROR: source-store override file missing: $SOURCE_STORE_SCRIPTS/lib/status-vocabulary.sh" >&2
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
  # Source-store-first override (see the header comment above this suite's HOLD_OVERRIDE_FILES
  # declaration): re-copy exactly the three hold-related files from agent-system/extensions/core/
  # ON TOP of the deploy-sourced copies above, so this suite exercises the pre-deploy edit.
  for hf in "${HOLD_OVERRIDE_FILES[@]}"; do
    cp "$SOURCE_STORE_SCRIPTS/$hf" "$root/.claude/scripts/$hf"
    chmod +x "$root/.claude/scripts/$hf"
  done
  cp "$SOURCE_STORE_SCRIPTS/lib/status-vocabulary.sh" "$root/.claude/scripts/lib/status-vocabulary.sh"
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

task_field() { jq -r --arg f "$1" '.active_projects[0][$f] // ""' "$FIXTURE_ROOT/specs/state.json" 2>/dev/null; }
task_has_field() { jq -e --arg f "$1" '.active_projects[0] | has($f)' "$FIXTURE_ROOT/specs/state.json" >/dev/null 2>&1; }

# =====================================================================
# Case 12: preflight:hold sets all three new fields and the [HOLD] marker, capturing
# prior_status from the real current status (planned, not a hardcoded literal).
# =====================================================================
info "=== Case 12: preflight:hold sets hold_reason/held_at/prior_status ==="
FIXTURE_ROOT="$WORKDIR/case12"
build_fixture_repo "$FIXTURE_ROOT"
UTS preflight 1 plan sess_test_c12 >/dev/null 2>&1
UTS postflight 1 plan sess_test_c12 >/dev/null 2>&1   # -> planned, the pre-hold status to capture

if UTS preflight 1 hold sess_test_c12 --hold-reason="Awaiting upstream API decision" \
    >"$WORKDIR/c12.out" 2>"$WORKDIR/c12.err"; then
  st="$(task_status)"
  if [[ "$st" == "hold" ]]; then
    pass "12a: preflight:hold sets status to 'hold'"
  else
    fail "12a: expected status 'hold', got '$st' (see $WORKDIR/c12.err)"
  fi
  hr="$(task_field hold_reason)"
  if [[ "$hr" == "Awaiting upstream API decision" ]]; then
    pass "12b: hold_reason captured from --hold-reason"
  else
    fail "12b: expected hold_reason 'Awaiting upstream API decision', got '$hr'"
  fi
  ha="$(task_field held_at)"
  if [[ "$ha" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    pass "12c: held_at is a YYYY-MM-DD date ('$ha')"
  else
    fail "12c: held_at is not a YYYY-MM-DD date, got '$ha'"
  fi
  ps="$(task_field prior_status)"
  if [[ "$ps" == "planned" ]]; then
    pass "12d: prior_status captured from the REAL current status ('planned'), not a literal"
  else
    fail "12d: expected prior_status 'planned', got '$ps'"
  fi
  if grep -q '\[HOLD\]' "$FIXTURE_ROOT/specs/TODO.md" 2>/dev/null; then
    pass "12e: TODO.md regenerated with the [HOLD] marker"
  else
    fail "12e: TODO.md missing the [HOLD] marker (see $FIXTURE_ROOT/specs/TODO.md)"
  fi
  if grep -q -- '- \*\*Held\*\*:' "$FIXTURE_ROOT/specs/TODO.md" 2>/dev/null; then
    pass "12f: TODO.md renders the '- **Held**:' line"
  else
    fail "12f: TODO.md missing the '- **Held**:' line"
  fi
else
  fail "12: preflight:hold exited nonzero unexpectedly (see $WORKDIR/c12.err)"
fi

# =====================================================================
# Case 13: preflight:hold WITHOUT --hold-reason fails loudly (hard validation error), writing
# nothing to state.json.
# =====================================================================
info "=== Case 13: preflight:hold without --hold-reason fails loudly ==="
FIXTURE_ROOT="$WORKDIR/case13"
build_fixture_repo "$FIXTURE_ROOT"
BEFORE_13="$(jq -c '.active_projects[0]' "$FIXTURE_ROOT/specs/state.json")"
if UTS preflight 1 hold sess_test_c13 >"$WORKDIR/c13.out" 2>"$WORKDIR/c13.err"; then
  fail "13: preflight:hold with no --hold-reason unexpectedly exited 0"
else
  AFTER_13="$(jq -c '.active_projects[0]' "$FIXTURE_ROOT/specs/state.json")"
  if [[ "$BEFORE_13" == "$AFTER_13" ]]; then
    pass "13a: missing --hold-reason is rejected, state.json unchanged"
  else
    fail "13a: missing --hold-reason rejection exited nonzero but state.json changed anyway"
  fi
  if grep -qi "hold-reason" "$WORKDIR/c13.err"; then
    pass "13b: rejection error names --hold-reason"
  else
    fail "13b: rejection error does not mention --hold-reason (see $WORKDIR/c13.err)"
  fi
fi

# =====================================================================
# Case 14: a set-then-lift round trip (preflight:unhold) restores prior_status EXACTLY and
# removes all three hold fields (field omission via del(), not nulling).
# =====================================================================
info "=== Case 14: preflight:unhold restores prior_status and clears hold fields ==="
FIXTURE_ROOT="$WORKDIR/case14"
build_fixture_repo "$FIXTURE_ROOT"
UTS preflight 1 plan sess_test_c14 >/dev/null 2>&1
UTS postflight 1 plan sess_test_c14 >/dev/null 2>&1
UTS preflight 1 hold sess_test_c14 --hold-reason="pausing for case 14" >/dev/null 2>&1

if UTS preflight 1 unhold sess_test_c14 >"$WORKDIR/c14.out" 2>"$WORKDIR/c14.err"; then
  st="$(task_status)"
  if [[ "$st" == "planned" ]]; then
    pass "14a: preflight:unhold restores status to the exact recorded prior_status ('planned')"
  else
    fail "14a: expected status 'planned' after unhold, got '$st' (see $WORKDIR/c14.err)"
  fi
  if task_has_field hold_reason || task_has_field held_at || task_has_field prior_status; then
    fail "14b: one or more of hold_reason/held_at/prior_status still present after unhold"
  else
    pass "14b: hold_reason/held_at/prior_status all removed (field omission, not nulling)"
  fi
else
  fail "14: preflight:unhold exited nonzero unexpectedly (see $WORKDIR/c14.err)"
fi

# =====================================================================
# Case 15: preflight:unhold with a MISSING prior_status fails loudly and writes nothing -- never
# falls back to 'not_started' or any other default.
# =====================================================================
info "=== Case 15: preflight:unhold with missing prior_status fails loudly ==="
FIXTURE_ROOT="$WORKDIR/case15"
build_fixture_repo "$FIXTURE_ROOT"
# Hand-craft a "hold" entry with NO prior_status field at all (simulating a corrupted/pre-feature
# entry), bypassing UTS's own preflight:hold (which always sets prior_status) on purpose.
jq '.active_projects[0].status = "hold" | .active_projects[0].hold_reason = "manually corrupted fixture"' \
  "$FIXTURE_ROOT/specs/state.json" > "$WORKDIR/c15-state.json.tmp" && mv "$WORKDIR/c15-state.json.tmp" "$FIXTURE_ROOT/specs/state.json"
BEFORE_15="$(jq -c '.active_projects[0]' "$FIXTURE_ROOT/specs/state.json")"
if UTS preflight 1 unhold sess_test_c15 >"$WORKDIR/c15.out" 2>"$WORKDIR/c15.err"; then
  fail "15: preflight:unhold with no prior_status unexpectedly exited 0"
else
  AFTER_15="$(jq -c '.active_projects[0]' "$FIXTURE_ROOT/specs/state.json")"
  if [[ "$BEFORE_15" == "$AFTER_15" ]]; then
    pass "15a: missing prior_status is rejected, state.json unchanged"
  else
    fail "15a: missing-prior_status rejection exited nonzero but state.json changed anyway"
  fi
  if grep -qi "prior_status" "$WORKDIR/c15.err"; then
    pass "15b: rejection error names prior_status"
  else
    fail "15b: rejection error does not mention prior_status (see $WORKDIR/c15.err)"
  fi
fi

# =====================================================================
# Case 16: a forced ordinary operation (preflight:implement) against an ALREADY-held task does
# NOT clear the hold -- the sticky guard keeps status=="hold" and every hold field intact. This
# is the actual mechanism (not the rank-based monotonic-max clamp) that preserves a hold across
# an /orchestrate forcing-flag override.
# =====================================================================
info "=== Case 16: an ordinary preflight write on an already-held task does not clear the hold ==="
FIXTURE_ROOT="$WORKDIR/case16"
build_fixture_repo "$FIXTURE_ROOT"
UTS preflight 1 plan sess_test_c16 >/dev/null 2>&1
UTS postflight 1 plan sess_test_c16 >/dev/null 2>&1
UTS preflight 1 hold sess_test_c16 --hold-reason="pausing for case 16" >/dev/null 2>&1

if UTS preflight 1 implement sess_test_c16 >"$WORKDIR/c16.out" 2>"$WORKDIR/c16.err"; then
  st="$(task_status)"
  if [[ "$st" == "hold" ]]; then
    pass "16a: preflight:implement on a held task leaves status == 'hold' (sticky guard fired)"
  else
    fail "16a: expected status to stay 'hold', got '$st' (see $WORKDIR/c16.err)"
  fi
  ps="$(task_field prior_status)"
  if [[ "$ps" == "planned" ]]; then
    pass "16b: prior_status is still intact ('planned'), untouched by the forced implement"
  else
    fail "16b: expected prior_status to remain 'planned', got '$ps'"
  fi
  if grep -qi "does not clear the hold" "$WORKDIR/c16.err"; then
    pass "16c: a NOTICE names the skipped status write"
  else
    fail "16c: expected a NOTICE naming the skipped status write (see $WORKDIR/c16.err)"
  fi
else
  fail "16: preflight:implement on a held task exited nonzero unexpectedly (see $WORKDIR/c16.err)"
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
