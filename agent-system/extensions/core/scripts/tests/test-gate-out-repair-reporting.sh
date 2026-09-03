#!/usr/bin/env bash
# test-gate-out-repair-reporting.sh - Fixture-driven regression suite for the gate-out
# auto-repair reporting instrumentation: skill_validate_task_artifacts's SKILL_VALIDATE_* globals
# (scripts/skill-base.sh) and command-gate-out.sh's console report + events.jsonl leg built on
# top of them.
#
# Prior to this suite, skill_validate_task_artifacts had zero test coverage (confirmed by
# test-skill-base-lifecycle.sh's own uncovered-residuals footer). This suite closes that gap and
# proves BOTH acceptance directions from the same code path: a task whose artifact needed repair
# reports a nonzero repaired-field count, and a task needing none reports zero -- present, not
# omitted.
#
# Structural model: test-skill-base-lifecycle.sh (mktemp -d WORKDIR with an EXIT-trap cleanup,
# deploy-tree-first / source-store-fallback candidate resolution, pass()/fail()/info() helpers
# with integer counters, exit 0 all-pass / 1 any-fail / 2 environment error).
#
# ISOLATION CONTRACT: every case runs against an isolated mktemp -d fixture repo (a private
# .claude/scripts/ tree with the deployed dependency chain copied in, plus the SOURCE-STORE
# (edited) copies of skill-base.sh and command-gate-out.sh overlaid on top -- so this suite
# exercises the code under test, not a stale deployed copy) and a private specs/state.json. No
# case ever touches the real specs/ tree, the real state.json, or the real events.jsonl; a
# pre/post `git status --short specs/` baseline (mirroring test-skill-base-lifecycle.sh's own
# contamination guard) proves it.
#
# Fixture identity: every fixture below is a throwaway project numbered 1 inside its own
# mktemp -d root -- never the real repo's specs/ tree or state.json. Assertions below therefore
# pin that literal fixture number where they check command-gate-out.sh's own emitted text
# verbatim.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (a
# required library/script was not found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

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

SKILL_BASE_SRC="$(resolve_candidate "skill-base.sh (source store)" \
  "$REPO_ROOT/agent-system/extensions/core/scripts/skill-base.sh" \
  "$REPO_ROOT/.claude/scripts/skill-base.sh")" || exit 2
GATE_OUT_SRC="$(resolve_candidate "command-gate-out.sh (source store)" \
  "$REPO_ROOT/agent-system/extensions/core/scripts/command-gate-out.sh" \
  "$REPO_ROOT/.claude/scripts/command-gate-out.sh")" || exit 2
VALIDATE_ARTIFACT_SRC="$(resolve_candidate "validate-artifact.sh (source store)" \
  "$REPO_ROOT/agent-system/extensions/core/scripts/validate-artifact.sh" \
  "$REPO_ROOT/.claude/scripts/validate-artifact.sh")" || exit 2

DEPLOY_SCRIPTS_SRC="$REPO_ROOT/.claude/scripts"
if [[ ! -d "$DEPLOY_SCRIPTS_SRC" ]]; then
  echo "ERROR: deployed scripts tree not found at $DEPLOY_SCRIPTS_SRC -- this suite needs a" >&2
  echo "       real deployed .claude/scripts/ tree to copy update-task-status.sh's dependency" >&2
  echo "       chain from (state-write.sh, task-lock.sh, deploy-root-guard.sh," >&2
  echo "       update-plan-status.sh, update-phase-status.sh, events-append.sh, lib/*.sh)." >&2
  exit 2
fi
for req in update-task-status.sh state-write.sh task-lock.sh generate-todo.sh deploy-root-guard.sh \
           update-plan-status.sh update-phase-status.sh events-append.sh; do
  if [[ ! -f "$DEPLOY_SCRIPTS_SRC/$req" ]]; then
    echo "ERROR: required deployed script missing: $DEPLOY_SCRIPTS_SRC/$req" >&2
    exit 2
  fi
done

# shellcheck disable=SC1090
. "$SKILL_BASE_SRC"
if ! declare -F skill_validate_task_artifacts >/dev/null 2>&1; then
  echo "ERROR: skill_validate_task_artifacts is not a defined function after sourcing $SKILL_BASE_SRC" >&2
  exit 2
fi
if ! grep -q 'SKILL_VALIDATE_FIXES' "$SKILL_BASE_SRC"; then
  echo "ERROR: sourced skill-base.sh ($SKILL_BASE_SRC) does not define SKILL_VALIDATE_FIXES --" >&2
  echo "       this is a STALE copy that predates the gate-out repair-reporting instrumentation." >&2
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

# ─── build_fixture_repo <root>: isolated repo shape with the deployed dependency chain copied
# in, then the SOURCE-STORE (edited) skill-base.sh/command-gate-out.sh/validate-artifact.sh
# overlaid on top -- so command-gate-out.sh (invoked as a subprocess, which sources
# .claude/scripts/skill-base.sh internally) exercises the code under test. ────────────────────
build_fixture_repo() {
  local root="$1"
  mkdir -p "$root/.claude/scripts/lib" "$root/specs"
  for f in update-task-status.sh state-write.sh task-lock.sh generate-todo.sh deploy-root-guard.sh \
           update-plan-status.sh update-phase-status.sh events-append.sh; do
    cp "$DEPLOY_SCRIPTS_SRC/$f" "$root/.claude/scripts/$f"
    chmod +x "$root/.claude/scripts/$f"
  done
  cp "$DEPLOY_SCRIPTS_SRC"/lib/*.sh "$root/.claude/scripts/lib/" 2>/dev/null || true
  cp "$SKILL_BASE_SRC" "$root/.claude/scripts/skill-base.sh"
  cp "$GATE_OUT_SRC" "$root/.claude/scripts/command-gate-out.sh"
  cp "$VALIDATE_ARTIFACT_SRC" "$root/.claude/scripts/validate-artifact.sh"
  chmod +x "$root/.claude/scripts/skill-base.sh" "$root/.claude/scripts/command-gate-out.sh" \
    "$root/.claude/scripts/validate-artifact.sh"
  cat > "$root/specs/state.json" << 'EOF'
{
  "next_project_number": 2,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "fixture_task",
      "status": "implementing",
      "task_type": "general",
      "next_artifact_number": 2
    }
  ]
}
EOF
  mkdir -p "$root/specs/001_fixture_task/plans" "$root/specs/001_fixture_task/reports" \
    "$root/specs/001_fixture_task/summaries"
  cat > "$root/specs/001_fixture_task/.return-meta.json" << 'EOF'
{"status": "implemented"}
EOF
}

# ─── write_valid_plan <path>: a fully-conforming plan artifact -- the clean-direction fixture. ─
write_valid_plan() {
  local path="$1"
  cat > "$path" << 'EOF'
# Fixture Plan

- **Task**: 1 - fixture
- **Status**: [NOT STARTED]
- **Effort**: 1h
- **Dependencies**: None
- **Research Inputs**: none
- **Artifacts**: plans/01_test.md
- **Standards**: none
- **Type**: meta

## Overview
x

## Goals & Non-Goals
x

## Risks & Mitigations
x

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases |
|------|--------|
| 1 | 1 |

### Phase 1: Fixture [NOT STARTED]
- **Verification Tier**: local

## Testing & Validation
x

## Artifacts & Outputs
x

## Rollback/Contingency
x
EOF
}

# ─── write_repairable_plan <path>: missing **Status** metadata field -- --fix inserts a
# placeholder and reports fixes=1, errors=0. ────────────────────────────────────────────────────
write_repairable_plan() {
  local path="$1"
  cat > "$path" << 'EOF'
# Fixture Plan

- **Task**: 1 - fixture
- **Effort**: 1h
- **Dependencies**: None
- **Research Inputs**: none
- **Artifacts**: plans/01_test.md
- **Standards**: none
- **Type**: meta

## Overview
x

## Goals & Non-Goals
x

## Risks & Mitigations
x

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases |
|------|--------|
| 1 | 1 |

### Phase 1: Fixture [NOT STARTED]
- **Verification Tier**: local

## Testing & Validation
x

## Artifacts & Outputs
x

## Rollback/Contingency
x
EOF
}

# ─── write_repair_plus_errors_plan <path>: missing **Status** (fixable) AND every required
# section past Overview (not fixable) -- pins the exit-2 conflation named in the plan's D-A
# residual-risk bullet: fixes>0 AND errors>0 in the same summary line. ─────────────────────────
write_repair_plus_errors_plan() {
  local path="$1"
  cat > "$path" << 'EOF'
# Fixture Plan

- **Task**: 1 - fixture
- **Effort**: 1h
- **Dependencies**: None
- **Research Inputs**: none
- **Artifacts**: plans/01_test.md
- **Standards**: none
- **Type**: meta

## Overview
x
EOF
}

# =====================================================================
# Case 1: repaired direction -- gate-out end to end
# =====================================================================
info "=== Case 1: repaired direction (command-gate-out.sh end to end) ==="
CASE1_ROOT="$WORKDIR/case1"
build_fixture_repo "$CASE1_ROOT"
write_repairable_plan "$CASE1_ROOT/specs/001_fixture_task/plans/01_test.md"
CASE1_OUT="$(cd "$CASE1_ROOT" && bash .claude/scripts/command-gate-out.sh 1 implement sess_case1 2>&1)"
CASE1_RC=$?
if [[ "$CASE1_RC" -eq 0 ]]; then
  pass "Case 1: command-gate-out.sh exits 0 on a repaired artifact"
else
  fail "Case 1: command-gate-out.sh exited $CASE1_RC (expected 0) on a repaired artifact"
fi
if printf '%s\n' "$CASE1_OUT" | grep -qE '^\[gate-out\] Artifact validation for task 1: [1-9][0-9]* field\(s\) auto-repaired, 0 error\(s\), 0 warning\(s\) remaining\.$'; then  # task-ref-ok inline, category 6 analog: pins the literal numbered text command-gate-out.sh emits
  pass "Case 1: report line names a nonzero repaired-field count"
else
  fail "Case 1: report line did not name a nonzero repaired-field count. Output:
$CASE1_OUT"
fi
if printf '%s\n' "$CASE1_OUT" | grep -qF '[gate-out] Auto-repaired artifact(s): '; then
  pass "Case 1: repaired-files line is present"
else
  fail "Case 1: repaired-files line is missing"
fi

# =====================================================================
# Case 2: clean direction -- gate-out end to end. Assert the line is PRESENT, not merely that no
# error occurred; a report that only appears on repair fails the acceptance criterion.
# =====================================================================
info "=== Case 2: clean direction (command-gate-out.sh end to end) ==="
CASE2_ROOT="$WORKDIR/case2"
build_fixture_repo "$CASE2_ROOT"
write_valid_plan "$CASE2_ROOT/specs/001_fixture_task/plans/01_test.md"
CASE2_OUT="$(cd "$CASE2_ROOT" && bash .claude/scripts/command-gate-out.sh 1 implement sess_case2 2>&1)"
CASE2_RC=$?
if [[ "$CASE2_RC" -eq 0 ]]; then
  pass "Case 2: command-gate-out.sh exits 0 on a clean artifact"
else
  fail "Case 2: command-gate-out.sh exited $CASE2_RC (expected 0) on a clean artifact"
fi
if printf '%s\n' "$CASE2_OUT" | grep -qF '[gate-out] Artifact validation for task 1: 0 field(s) auto-repaired, 0 error(s), 0 warning(s) remaining.'; then  # task-ref-ok inline, category 6 analog: pins the literal numbered text command-gate-out.sh emits
  pass "Case 2: report line is present and names zero (not omitted)"
else
  fail "Case 2: report line naming zero was not found. Output:
$CASE2_OUT"
fi
if printf '%s\n' "$CASE2_OUT" | grep -qF '[gate-out] Auto-repaired artifact(s):'; then
  fail "Case 2: repaired-files line appeared despite zero fixes"
else
  pass "Case 2: repaired-files line correctly absent when nothing was repaired"
fi

# =====================================================================
# Case 3: multi-file aggregation -- two repairable artifacts across two subdirectories sum
# correctly and both paths appear in SKILL_VALIDATE_FIXED_FILES. Exercised directly against the
# sourced function (not the gate-out subprocess) so the globals are inspectable in this shell.
# =====================================================================
info "=== Case 3: multi-file aggregation (direct function call) ==="
CASE3_DIR="$WORKDIR/case3_fixture"
mkdir -p "$CASE3_DIR/plans" "$CASE3_DIR/reports" "$CASE3_DIR/summaries"
write_repairable_plan "$CASE3_DIR/plans/01_a.md"
write_repairable_plan "$CASE3_DIR/plans/02_b.md"
skill_validate_task_artifacts "$CASE3_DIR" > "$WORKDIR/case3.out" 2>&1
if [[ "${SKILL_VALIDATE_FIXES:-0}" -eq 2 ]]; then
  pass "Case 3: two repairable artifacts across the sweep sum to SKILL_VALIDATE_FIXES=2"
else
  fail "Case 3: expected SKILL_VALIDATE_FIXES=2, got ${SKILL_VALIDATE_FIXES:-<unset>}"
fi
if [[ "$SKILL_VALIDATE_FIXED_FILES" == *"01_a.md"* ]] && [[ "$SKILL_VALIDATE_FIXED_FILES" == *"02_b.md"* ]]; then
  pass "Case 3: SKILL_VALIDATE_FIXED_FILES names both repaired paths"
else
  fail "Case 3: SKILL_VALIDATE_FIXED_FILES did not name both repaired paths: $SKILL_VALIDATE_FIXED_FILES"
fi

# =====================================================================
# Case 4: errors-remaining alongside fixes -- pins the exit-2 conflation in D-A's residual-risk
# bullet: an artifact that gets a metadata field fixed while a required section is still missing
# reports nonzero fixes AND nonzero errors in the same sweep.
# =====================================================================
info "=== Case 4: errors-remaining alongside fixes (direct function call) ==="
CASE4_DIR="$WORKDIR/case4_fixture"
mkdir -p "$CASE4_DIR/plans" "$CASE4_DIR/reports" "$CASE4_DIR/summaries"
write_repair_plus_errors_plan "$CASE4_DIR/plans/01_test.md"
skill_validate_task_artifacts "$CASE4_DIR" > "$WORKDIR/case4.out" 2>&1
if [[ "${SKILL_VALIDATE_FIXES:-0}" -gt 0 ]] && [[ "${SKILL_VALIDATE_ERRORS:-0}" -gt 0 ]]; then
  pass "Case 4: fixes=${SKILL_VALIDATE_FIXES} AND errors=${SKILL_VALIDATE_ERRORS} both nonzero in the same sweep"
else
  fail "Case 4: expected both fixes>0 and errors>0, got fixes=${SKILL_VALIDATE_FIXES:-0} errors=${SKILL_VALIDATE_ERRORS:-0}"
fi

# =====================================================================
# Case 5: validation could not run -- exit 5 (shared phase-heading library missing) must yield a
# nonzero error count, never a silent zero. Constructed by pointing a fixture's own
# .claude/scripts/validate-artifact.sh at a directory with no lib/ sibling, which
# validate-artifact.sh's plan-type path requires.
# =====================================================================
info "=== Case 5: validation could not run (exit 5, no silent zero) ==="
CASE5_ROOT="$WORKDIR/case5"
mkdir -p "$CASE5_ROOT/.claude/scripts" "$CASE5_ROOT/fixture_dir/plans" "$CASE5_ROOT/fixture_dir/reports" \
  "$CASE5_ROOT/fixture_dir/summaries"
cp "$VALIDATE_ARTIFACT_SRC" "$CASE5_ROOT/.claude/scripts/validate-artifact.sh"
chmod +x "$CASE5_ROOT/.claude/scripts/validate-artifact.sh"
# Deliberately no .claude/scripts/lib/ -- validate-artifact.sh's plan-type path resolves the
# shared phase-heading library as its own sibling, so this reliably drives exit 5.
write_valid_plan "$CASE5_ROOT/fixture_dir/plans/01_test.md"
DIRECT_RC=0
( cd "$CASE5_ROOT" && bash .claude/scripts/validate-artifact.sh fixture_dir/plans/01_test.md plan >/dev/null 2>&1 ) || DIRECT_RC=$?
if [[ "$DIRECT_RC" -eq 5 ]]; then
  info "Case 5 setup confirmed: direct validate-artifact.sh call exits 5 as expected"
else
  info "Case 5 setup produced exit $DIRECT_RC instead of 5 -- environment may differ; case result below still checked"
fi
(
  cd "$CASE5_ROOT" || exit 2
  skill_validate_task_artifacts "fixture_dir" > "$WORKDIR/case5.out" 2>&1
  echo "${SKILL_VALIDATE_ERRORS:-0}" > "$WORKDIR/case5.errors"
)
CASE5_ERRORS="$(cat "$WORKDIR/case5.errors" 2>/dev/null || echo 0)"
if [[ "$CASE5_ERRORS" -gt 0 ]]; then
  pass "Case 5: validation-could-not-run (exit 5) reports a nonzero error count, never silent zero"
else
  fail "Case 5: expected a nonzero error count for an exit-5 validation-could-not-run result, got $CASE5_ERRORS"
fi

# =====================================================================
# Case 6: no stale globals -- a call over a repairable fixture followed by a call over a clean
# fixture reports zero on the second call.
# =====================================================================
info "=== Case 6: no stale globals across calls (direct function call) ==="
CASE6_DIR="$WORKDIR/case6_fixture"
mkdir -p "$CASE6_DIR/plans" "$CASE6_DIR/reports" "$CASE6_DIR/summaries"
write_repairable_plan "$CASE6_DIR/plans/01_test.md"
skill_validate_task_artifacts "$CASE6_DIR" > "$WORKDIR/case6a.out" 2>&1
FIRST_CALL_FIXES="${SKILL_VALIDATE_FIXES:-0}"
CASE6_CLEAN_DIR="$WORKDIR/case6_clean_fixture"
mkdir -p "$CASE6_CLEAN_DIR/plans" "$CASE6_CLEAN_DIR/reports" "$CASE6_CLEAN_DIR/summaries"
write_valid_plan "$CASE6_CLEAN_DIR/plans/01_test.md"
skill_validate_task_artifacts "$CASE6_CLEAN_DIR" > "$WORKDIR/case6b.out" 2>&1
if [[ "$FIRST_CALL_FIXES" -gt 0 ]] && [[ "${SKILL_VALIDATE_FIXES:-0}" -eq 0 ]] && \
   [[ "${SKILL_VALIDATE_ERRORS:-0}" -eq 0 ]] && [[ "${SKILL_VALIDATE_WARNINGS:-0}" -eq 0 ]] && \
   [[ -z "$SKILL_VALIDATE_FIXED_FILES" ]]; then
  pass "Case 6: a clean call after a repairing call reports all-zero globals (no stale carryover)"
else
  fail "Case 6: stale globals detected. first_call_fixes=$FIRST_CALL_FIXES second_call: fixes=${SKILL_VALIDATE_FIXES:-0} errors=${SKILL_VALIDATE_ERRORS:-0} warnings=${SKILL_VALIDATE_WARNINGS:-0} fixed_files=[$SKILL_VALIDATE_FIXED_FILES]"
fi

# =====================================================================
# Case 7: summary-line format pinning (D-B's mitigation) -- assert validate-artifact.sh's three
# terminal shapes match their expected patterns, so a future wording change fails here loudly
# rather than silently degrading the counts to zero.
# =====================================================================
info "=== Case 7: summary-line format pinning ==="
CASE7_DIR="$WORKDIR/case7_fixture"
mkdir -p "$CASE7_DIR/plans"

write_repairable_plan "$CASE7_DIR/plans/01_fixed.md"
FIXED_LINE="$(bash "$VALIDATE_ARTIFACT_SRC" "$CASE7_DIR/plans/01_fixed.md" plan --fix 2>/dev/null | tail -1)"
if [[ "$FIXED_LINE" =~ ^\[FIXED\]\ [0-9]+\ field\(s\)\ auto-repaired ]]; then
  pass "Case 7: [FIXED] summary-line shape matches the pinned pattern"
else
  fail "Case 7: [FIXED] summary-line shape drifted. Got: $FIXED_LINE"
fi

write_valid_plan "$CASE7_DIR/plans/02_pass.md"
PASS_LINE="$(bash "$VALIDATE_ARTIFACT_SRC" "$CASE7_DIR/plans/02_pass.md" plan --fix 2>/dev/null | tail -1)"
if [[ "$PASS_LINE" =~ ^\[PASS\]\  ]]; then
  pass "Case 7: [PASS] summary-line shape matches the pinned pattern"
else
  fail "Case 7: [PASS] summary-line shape drifted. Got: $PASS_LINE"
fi

cat > "$CASE7_DIR/plans/03_fail.md" << 'EOF'
# Fixture Plan

- **Task**: 1 - fixture
- **Status**: [NOT STARTED]
- **Effort**: 1h
- **Dependencies**: None
- **Research Inputs**: none
- **Artifacts**: plans/03_fail.md
- **Standards**: none
- **Type**: meta

## Overview
x
EOF
FAIL_LINE="$(bash "$VALIDATE_ARTIFACT_SRC" "$CASE7_DIR/plans/03_fail.md" plan 2>/dev/null | tail -1)"
if [[ "$FAIL_LINE" =~ ^\[FAIL\]\ [0-9]+\ error\(s\) ]]; then
  pass "Case 7: [FAIL] summary-line shape matches the pinned pattern"
else
  fail "Case 7: [FAIL] summary-line shape drifted. Got: $FAIL_LINE"
fi

# =====================================================================
# Case 8: events row -- the repaired direction appends exactly one artifact_auto_repair row with
# the matching counts in its detail object, and the clean direction's row is category=milestone.
# =====================================================================
info "=== Case 8: events.jsonl row (command-gate-out.sh end to end) ==="
CASE8_ROOT="$WORKDIR/case8"
build_fixture_repo "$CASE8_ROOT"
write_repairable_plan "$CASE8_ROOT/specs/001_fixture_task/plans/01_test.md"
( cd "$CASE8_ROOT" && bash .claude/scripts/command-gate-out.sh 1 implement sess_case8 >/dev/null 2>&1 )
CASE8_EVENTS="$CASE8_ROOT/specs/events.jsonl"
if [[ -f "$CASE8_EVENTS" ]]; then
  CASE8_ROW_COUNT=$(jq -c 'select(.event_type == "artifact_auto_repair")' "$CASE8_EVENTS" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$CASE8_ROW_COUNT" -eq 1 ]]; then
    pass "Case 8: exactly one artifact_auto_repair events.jsonl row was appended"
  else
    fail "Case 8: expected exactly one artifact_auto_repair row, found $CASE8_ROW_COUNT"
  fi
  CASE8_ROW="$(jq -c 'select(.event_type == "artifact_auto_repair")' "$CASE8_EVENTS" 2>/dev/null | tail -1)"
  CASE8_CATEGORY="$(printf '%s' "$CASE8_ROW" | jq -r '.category' 2>/dev/null)"
  CASE8_FIXES="$(printf '%s' "$CASE8_ROW" | jq -r '.detail.fixes' 2>/dev/null)"
  if [[ "$CASE8_CATEGORY" == "deviation" ]]; then
    pass "Case 8: repaired direction's events row has category=deviation"
  else
    fail "Case 8: expected category=deviation, got '$CASE8_CATEGORY'"
  fi
  if [[ "$CASE8_FIXES" -gt 0 ]] 2>/dev/null; then
    pass "Case 8: events row's detail.fixes matches the nonzero repaired-field count"
  else
    fail "Case 8: events row's detail.fixes was not a positive number: '$CASE8_FIXES'"
  fi
else
  fail "Case 8: specs/events.jsonl was not created"
fi

CASE8B_ROOT="$WORKDIR/case8b"
build_fixture_repo "$CASE8B_ROOT"
write_valid_plan "$CASE8B_ROOT/specs/001_fixture_task/plans/01_test.md"
( cd "$CASE8B_ROOT" && bash .claude/scripts/command-gate-out.sh 1 implement sess_case8b >/dev/null 2>&1 )
CASE8B_EVENTS="$CASE8B_ROOT/specs/events.jsonl"
if [[ -f "$CASE8B_EVENTS" ]]; then
  CASE8B_CATEGORY="$(jq -r 'select(.event_type == "artifact_auto_repair") | .category' "$CASE8B_EVENTS" 2>/dev/null | tail -1)"
  if [[ "$CASE8B_CATEGORY" == "milestone" ]]; then
    pass "Case 8: clean direction's events row has category=milestone"
  else
    fail "Case 8: expected clean-direction category=milestone, got '$CASE8B_CATEGORY'"
  fi
else
  fail "Case 8: clean-direction specs/events.jsonl was not created"
fi

# =====================================================================
# Contamination guard: this suite must never leave a NEW mark on the actual repo's specs/ tree.
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
