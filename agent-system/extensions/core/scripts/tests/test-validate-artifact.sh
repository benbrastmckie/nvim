#!/usr/bin/env bash
# test-validate-artifact.sh - Fixture-driven regression suite for scripts/validate-artifact.sh's
# two newest checks: the plan-level Status-line grammar (M1/M2/M3, --fix non-participation) and
# the report required-section heading conformance (the general-research-agent.md drift fix,
# including the depth-tolerant any-depth semantics). Also carries a cross-script conformance
# guard asserting scripts/lib/plan-status-line.sh's classification agrees with
# update-plan-status.sh's own live accept/reject behavior on the same fixtures -- the mechanism
# that lets this task NOT refactor update-plan-status.sh onto the shared library while still
# guarding against the two ever drifting apart (see plan-status-line.sh's own header comment).
#
# Structural model: test-update-plan-status.sh (pass()/fail()/info() helpers, PASSED/FAILED
# integer counters, git-root-first REPO_ROOT resolution, mktemp -d workdir with trap EXIT
# cleanup). validate-artifact.sh is driven as a SUBPROCESS (it is an executable script, not a
# sourced library); it resolves its own sibling libraries via ${BASH_SOURCE[0]}, so fixtures for
# it need no scratch REPO_ROOT staging -- only the cross-script conformance guard's
# update-plan-status.sh calls need the specs/{NNN}_{project}/plans/ relative-path fixture shape,
# mirrored from test-update-plan-status.sh's own make_fixture().
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (a
# script under test not found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

VALIDATE_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/validate-artifact.sh"
  "$SCRIPT_DIR/../validate-artifact.sh"
)
VALIDATE=""
for candidate in "${VALIDATE_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    VALIDATE="$candidate"
    break
  fi
done
if [[ -z "$VALIDATE" ]]; then
  echo "ERROR: validate-artifact.sh not found at any of:" >&2
  for candidate in "${VALIDATE_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

UPDATE_PLAN_STATUS_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/update-plan-status.sh"
  "$SCRIPT_DIR/../update-plan-status.sh"
)
UPDATE_PLAN_STATUS=""
for candidate in "${UPDATE_PLAN_STATUS_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    UPDATE_PLAN_STATUS="$candidate"
    break
  fi
done
if [[ -z "$UPDATE_PLAN_STATUS" ]]; then
  echo "ERROR: update-plan-status.sh not found at any of:" >&2
  for candidate in "${UPDATE_PLAN_STATUS_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

PLAN_STATUS_LIB_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/lib/plan-status-line.sh"
  "$SCRIPT_DIR/../lib/plan-status-line.sh"
)
PLAN_STATUS_LIB=""
for candidate in "${PLAN_STATUS_LIB_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    PLAN_STATUS_LIB="$candidate"
    break
  fi
done
if [[ -z "$PLAN_STATUS_LIB" ]]; then
  echo "ERROR: plan-status-line.sh not found at any of:" >&2
  for candidate in "${PLAN_STATUS_LIB_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi
# shellcheck disable=SC1090
. "$PLAN_STATUS_LIB"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

checksum() { md5sum "$1" | cut -d' ' -f1; }

# ── Minimal-plan builder: a full metadata block + all required sections, so only the
# Status-line grammar varies across cases and no unrelated missing-field/missing-section error
# pollutes the assertions below. ──────────────────────────────────────────────────────────────
make_plan_fixture() {
  local status_line="$1"
  local f
  f="$(mktemp --tmpdir="$WORKDIR" plan-XXXXXX.md)"
  cat > "$f" <<EOF
# Plan

- **Task**: 1 - x
${status_line}
- **Effort**: 1h
- **Dependencies**: none
- **Research Inputs**: none
- **Artifacts**: none
- **Standards**: none
- **Type**: meta

## Overview
x

## Goals & Non-Goals
x

## Risks & Mitigations
x

## Implementation Phases

### Phase 1: X [NOT STARTED]

**Verification Tier**: prose

## Testing & Validation
x

## Artifacts & Outputs
x

## Rollback/Contingency
x
EOF
  echo "$f"
}

make_report_fixture() {
  local extra_headings="$1"
  local f
  f="$(mktemp --tmpdir="$WORKDIR" report-XXXXXX.md)"
  cat > "$f" <<EOF
# Report

- **Task**: 1 - x
- **Started**: 2026-01-01
- **Completed**: 2026-01-01
- **Effort**: 1h
- **Dependencies**: none
- **Sources/Inputs**: none
- **Artifacts**: none
- **Standards**: none

## Executive Summary
x

## Context & Scope
x

## Findings
x

## Decisions
x
${extra_headings}
EOF
  echo "$f"
}

# ─── Status-grammar: conforming ──────────────────────────────────────────────────────────────
f=$(make_plan_fixture '- **Status**: [IMPLEMENTING]')
out=$("$VALIDATE" "$f" plan 2>&1)
if echo "$out" | grep -qF "[PASS]"; then pass "conforming Status line: [PASS]"; else fail "conforming Status line did not PASS: $out"; fi
if echo "$out" | grep -q "plan-level Status line"; then fail "conforming Status line raised a grammar error: $out"; else pass "conforming Status line raises no grammar error"; fi

# ─── Status-grammar: conforming + trailing annotation ───────────────────────────────────────
f=$(make_plan_fixture '- **Status**: [IMPLEMENTING] (resumed; Phases 1R-10R closed)')
out=$("$VALIDATE" "$f" plan 2>&1)
if echo "$out" | grep -qF "[PASS]"; then pass "trailing-annotation Status line: [PASS]"; else fail "trailing-annotation Status line did not PASS: $out"; fi

# ─── Status-grammar: M1 (no Status line at all) ─────────────────────────────────────────────
f=$(mktemp --tmpdir="$WORKDIR" plan-m1-XXXXXX.md)
cat > "$f" <<'EOF'
# Plan
no status line here
EOF
out=$("$VALIDATE" "$f" plan 2>&1)
if echo "$out" | grep -qF "plan-level Status line not found"; then pass "M1: plan-level Status line not found error"; else fail "M1 missing expected error: $out"; fi

# ─── Status-grammar: M2 (no bracket pair) ───────────────────────────────────────────────────
f=$(make_plan_fixture '- **Status**: COMPLETED')
out=$("$VALIDATE" "$f" plan 2>&1)
if echo "$out" | grep -qF "plan-level Status line has no [STATUS] bracket pair"; then pass "M2: no bracket pair error"; else fail "M2 missing expected error: $out"; fi
if echo "$out" | grep -qF "[FAIL]"; then pass "M2: overall [FAIL]"; else fail "M2 did not FAIL overall: $out"; fi

# ─── Status-grammar: M3 (text between prefix and bracket) ──────────────────────────────────
f=$(make_plan_fixture '- **Status**: see [NOTE]')
out=$("$VALIDATE" "$f" plan 2>&1)
if echo "$out" | grep -qF "plan-level Status line has unexpected text between the prefix and the bracket"; then pass "M3: unexpected-text error"; else fail "M3 missing expected error: $out"; fi

# ─── --fix non-participation: M2 fixture untouched, error still reported ───────────────────
f=$(make_plan_fixture '- **Status**: COMPLETED')
before=$(checksum "$f")
out=$("$VALIDATE" "$f" plan --fix 2>&1)
after=$(checksum "$f")
if [[ "$before" == "$after" ]]; then pass "--fix leaves M2 Status line byte-identical"; else fail "--fix mutated the M2 fixture"; fi
if echo "$out" | grep -qF "plan-level Status line has no [STATUS] bracket pair"; then pass "--fix still reports the M2 grammar error"; else fail "--fix suppressed the M2 grammar error: $out"; fi

# ─── Report-heading: near-miss-only FAILs ───────────────────────────────────────────────────
f=$(make_report_fixture '
## Recommended Next Steps (for the plan phase)
x

## Context Extension Recommendations
x')
out=$("$VALIDATE" "$f" report 2>&1)
if echo "$out" | grep -qF "Missing required section: ## Recommendations"; then pass "near-miss headings alone: Missing required section error"; else fail "near-miss case did not report missing Recommendations: $out"; fi

# ─── Report-heading: conforming (## Recommendations added) PASSes ──────────────────────────
f=$(make_report_fixture '
## Recommended Next Steps (for the plan phase)
x

## Context Extension Recommendations
x

## Recommendations
x')
out=$("$VALIDATE" "$f" report 2>&1)
if echo "$out" | grep -qF "[PASS]"; then pass "conforming report (## Recommendations added): [PASS]"; else fail "conforming report did not PASS: $out"; fi

# ─── Report-heading: ## Context Extension Recommendations ALONE still FAILs ─────────────────
f=$(make_report_fixture '
## Context Extension Recommendations
x')
out=$("$VALIDATE" "$f" report 2>&1)
if echo "$out" | grep -qF "Missing required section: ## Recommendations"; then pass "Context Extension Recommendations alone still FAILs (no false pass)"; else fail "Context Extension Recommendations alone incorrectly satisfied Recommendations: $out"; fi

# ─── Depth tolerance: only conforming heading is ### Recommendations (nested) -- PASSes ────
f=$(make_report_fixture '
### Recommendations
x')
out=$("$VALIDATE" "$f" report 2>&1)
if echo "$out" | grep -qF "[PASS]"; then pass "depth-tolerant ### Recommendations satisfies the any-depth check"; else fail "depth-tolerant nested heading did not PASS: $out"; fi

# ─── Cross-script conformance guard: plan-status-line.sh vs update-plan-status.sh ──────────
# For each of the five Status-grammar shapes, build a throwaway specs/{NNN}_{slug}/plans/
# layout, invoke the real update-plan-status.sh against it, and assert its accept/reject
# outcome agrees with plan_status_classify's verdict for the same content. Read-only with
# respect to update-plan-status.sh -- it is never edited by this suite or this task.
make_conformance_fixture() {
  local content="$1"
  local dir
  dir="$(mktemp -d --tmpdir="$WORKDIR")"
  mkdir -p "$dir/specs/001_demo/plans"
  printf '%s\n' "$content" > "$dir/specs/001_demo/plans/01_x.md"
  echo "$dir"
}

check_conformance() {
  local label="$1" content="$2"
  local dir pf classification shape
  dir=$(make_conformance_fixture "$content")
  pf="$dir/specs/001_demo/plans/01_x.md"
  classification="$(plan_status_classify "$pf")"
  shape="${classification%% *}"
  (cd "$dir" && "$UPDATE_PLAN_STATUS" 1 demo COMPLETED >/dev/null 2>"$WORKDIR/conf-err.log")
  local rc=$?
  if [[ "$shape" == "OK" ]]; then
    if [[ $rc -eq 0 ]]; then
      pass "conformance guard ($label): both accept (library=OK, update-plan-status.sh rc=0)"
    else
      fail "conformance guard ($label): library says OK but update-plan-status.sh rejected (rc=$rc): $(cat "$WORKDIR/conf-err.log")"
    fi
  else
    if [[ $rc -ne 0 ]]; then
      pass "conformance guard ($label): both reject (library=$shape, update-plan-status.sh rc=$rc)"
    else
      fail "conformance guard ($label): library says $shape but update-plan-status.sh accepted (rc=0)"
    fi
  fi
  rm -f "$WORKDIR/conf-err.log"
}

check_conformance "OK"      $'# Plan\n- **Status**: [IMPLEMENTING]'
check_conformance "trailing" $'# Plan\n- **Status**: [IMPLEMENTING] (resumed; Phases 1R-10R closed)'
check_conformance "M1"      $'# Plan\nno status line here'
check_conformance "M2"      $'# Plan\n- **Status**: COMPLETED'
check_conformance "M3"      $'# Plan\n- **Status**: see [NOTE]'

echo ""
info "Target scripts: $VALIDATE ; $UPDATE_PLAN_STATUS ; $PLAN_STATUS_LIB"
echo "PASSED: $PASSED"
echo "FAILED: $FAILED"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
exit 0
