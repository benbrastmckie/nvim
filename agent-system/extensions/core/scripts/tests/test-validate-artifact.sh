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

**Files to modify**:
- \`path/to/file.ext\`

## Testing & Validation
x

## Artifacts & Outputs
x

## Rollback/Contingency
x
EOF
  echo "$f"
}

# ── Two-phase "Files to modify" fixture builder: Phase 2 always declares a valid Files-to-modify
# block (an anchor), so varying only Phase 1's rendering (via $1) isolates the header-detection
# grammar from the whole-plan/per-phase tier selection -- that selection is exercised separately
# by make_whole_plan_ftm_omit_fixture below. ─────────────────────────────────────────────────────
make_two_phase_ftm_fixture() {
  local phase1_ftm="$1"
  local f
  f="$(mktemp --tmpdir="$WORKDIR" plan-ftm-XXXXXX.md)"
  cat > "$f" <<EOF
# Plan

- **Task**: 1 - x
- **Status**: [IMPLEMENTING]
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
${phase1_ftm}

### Phase 2: Y [NOT STARTED]

**Verification Tier**: prose

**Files to modify**:
- \`path/to/anchor.ext\`

## Testing & Validation
x

## Artifacts & Outputs
x

## Rollback/Contingency
x
EOF
  echo "$f"
}

# ── Whole-plan omission fixture: every phase omits the "Files to modify" field. ────────────────
make_whole_plan_ftm_omit_fixture() {
  local f
  f="$(mktemp --tmpdir="$WORKDIR" plan-ftm-omit-XXXXXX.md)"
  cat > "$f" <<EOF
# Plan

- **Task**: 1 - x
- **Status**: [IMPLEMENTING]
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

### Phase 2: Y [NOT STARTED]

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

# ─── Files to modify (a): phase block with no header at all -- draws the per-phase warning ──
f=$(make_two_phase_ftm_fixture '')
out=$("$VALIDATE" "$f" plan 2>&1)
if echo "$out" | grep -qF "Phase 1 missing **Files to modify** field"; then pass "FTM(a): no-header phase draws the per-phase warning"; else fail "FTM(a) missing expected warning: $out"; fi
if echo "$out" | grep -qF "Every phase omits the **Files to modify** field"; then fail "FTM(a): no-header-on-one-phase incorrectly raised the whole-plan error: $out"; else pass "FTM(a): no whole-plan error raised"; fi
if echo "$out" | grep -qF "[PASS]"; then pass "FTM(a): overall [PASS] in default mode (warning alone)"; else fail "FTM(a) did not PASS overall in default mode: $out"; fi

# ─── Files to modify (b): header present with only a "- none planned" prose sentinel -- NO finding
f=$(make_two_phase_ftm_fixture $'\n\n**Files to modify**:\n- none planned - pure verification phase')
out=$("$VALIDATE" "$f" plan 2>&1)
if echo "$out" | grep -qF "missing **Files to modify** field"; then fail "FTM(b): sentinel-only header incorrectly drew a missing-field finding: $out"; else pass "FTM(b): sentinel-only header draws no finding"; fi
if echo "$out" | grep -qF "Every phase omits"; then fail "FTM(b) incorrectly raised the whole-plan error: $out"; else pass "FTM(b): no whole-plan error"; fi
# The fixture's Phase 2 anchor path is the only real entry; Phase 1's sentinel line must
# contribute zero paths of its own (the harvester's unchanged []-contributes-nothing contract for
# a sentinel-only block), so the harvest is exactly the one-element anchor array, never more.
harvest_before=$(bash "$SCRIPT_DIR/../plan-file-scope-harvest.sh" "$f" 2>&1 | tr -d '[:space:]')
if [[ "$harvest_before" == '["path/to/anchor.ext"]' ]]; then pass "FTM(b): sentinel-only Phase 1 contributes zero paths to the harvest (unchanged contract)"; else fail "FTM(b): harvester output unexpectedly diverged: $harvest_before"; fi

# ─── Files to modify (c): header present with at least one backtick-path entry -- NO finding ──
f=$(make_two_phase_ftm_fixture $'\n\n**Files to modify**:\n- `some/real/path.ext`')
out=$("$VALIDATE" "$f" plan 2>&1)
if echo "$out" | grep -qF "missing **Files to modify** field"; then fail "FTM(c): header-with-path incorrectly drew a missing-field finding: $out"; else pass "FTM(c): header-with-path draws no finding"; fi
if echo "$out" | grep -qF "Every phase omits"; then fail "FTM(c) incorrectly raised the whole-plan error: $out"; else pass "FTM(c): no whole-plan error"; fi

# ─── Files to modify (d): every phase omits the field -- whole-plan log_error ───────────────
f=$(make_whole_plan_ftm_omit_fixture)
out=$("$VALIDATE" "$f" plan 2>&1)
if echo "$out" | grep -qF "Every phase omits the **Files to modify** field"; then pass "FTM(d): whole-plan omission raises the whole-plan error"; else fail "FTM(d) missing expected whole-plan error: $out"; fi
if echo "$out" | grep -qF "[FAIL]"; then pass "FTM(d): overall [FAIL] (error, not just warning)"; else fail "FTM(d) did not FAIL overall: $out"; fi
rc=0; "$VALIDATE" "$f" plan >/dev/null 2>&1 || rc=$?
if [[ $rc -ne 0 ]]; then pass "FTM(d): non-zero exit in default mode"; else fail "FTM(d): exit 0 despite whole-plan error"; fi

# ─── Files to modify (e): mixed plan (one phase omits, another declares) -- warning, NOT error ──
f=$(make_two_phase_ftm_fixture '')
out=$("$VALIDATE" "$f" plan 2>&1)
if echo "$out" | grep -qF "Phase 1 missing **Files to modify** field"; then pass "FTM(e): mixed plan draws the per-phase warning"; else fail "FTM(e) missing expected warning: $out"; fi
if echo "$out" | grep -qF "Every phase omits"; then fail "FTM(e): mixed plan incorrectly raised the whole-plan error: $out"; else pass "FTM(e): mixed plan raises no whole-plan error"; fi
rc=0; "$VALIDATE" "$f" plan >/dev/null 2>&1 || rc=$?
if [[ $rc -eq 0 ]]; then pass "FTM(e): default-mode exit 0 (warning alone does not fail the gate)"; else fail "FTM(e): unexpected non-zero exit in default mode: rc=$rc"; fi
rc=0; "$VALIDATE" "$f" plan --strict >/dev/null 2>&1 || rc=$?
if [[ $rc -ne 0 ]]; then pass "FTM(e): --strict escalates the per-phase warning to a non-zero exit"; else fail "FTM(e): --strict did not escalate: rc=$rc"; fi

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
