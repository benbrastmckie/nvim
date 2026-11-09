#!/usr/bin/env bash
# test-validate-artifact.sh - Fixture-driven regression suite for scripts/validate-artifact.sh's
# newest checks: the plan-level Status-line grammar (M1/M2/M3, --fix non-participation), the
# report required-section heading conformance (the general-research-agent.md drift fix,
# including the depth-tolerant any-depth semantics), and the advisory cross-phase ceiling
# consistency check (per-phase Scope Hypothesis estimates summing past a plan-cited numeric
# ceiling while the plan asserts conformance -- cases (f)/(g)/(h) below, driven via
# $VALIDATE_SRC rather than $VALIDATE so they exercise the source-store copy directly ahead of
# that check's own redeploy phase; see $VALIDATE_SRC's own header comment above). Also covers the
# advisory "Files to modify" authoring-shape scan -- FTM-shape cases (g)/(h) below -- surfacing
# the wrapped-continuation, comma-join, and deployed-tree-path (`.claude/**`) shapes that each
# silently drop a path from plan-file-scope-harvest.sh's output; also driven via $VALIDATE_SRC
# for the same redeploy-timing reason. Also carries a
# cross-script conformance guard asserting scripts/lib/plan-status-line.sh's classification
# agrees with update-plan-status.sh's own live accept/reject behavior on the same fixtures -- the
# mechanism that lets this task NOT refactor update-plan-status.sh onto the shared library while
# still guarding against the two ever drifting apart (see plan-status-line.sh's own header
# comment).
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
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

VALIDATE="$(common_test_resolve_subject "validate-artifact.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/validate-artifact.sh" \
  "$SCRIPT_DIR/../validate-artifact.sh")" || exit 2
common_test_declare_subject "$VALIDATE"

# VALIDATE_SRC: mode=source-store for the SAME file, deliberately distinct from $VALIDATE's
# mode=deploy-tree-first resolution above. The cross-phase ceiling consistency cases below
# exercise a check that lives only in the source store until the owning task's own redeploy
# phase lands it under .claude/ -- using $VALIDATE for them would silently test a stale deployed
# copy lacking the check entirely. Every other case in this suite correctly keeps using
# $VALIDATE.
VALIDATE_SRC="$(common_test_resolve_subject "validate-artifact.sh (source store)" "source-store" \
  "$REPO_ROOT/.claude/scripts/validate-artifact.sh" \
  "$SCRIPT_DIR/../validate-artifact.sh")" || exit 2
common_test_declare_subject "$VALIDATE_SRC"

UPDATE_PLAN_STATUS="$(common_test_resolve_subject "update-plan-status.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/update-plan-status.sh" \
  "$SCRIPT_DIR/../update-plan-status.sh")" || exit 2
common_test_declare_subject "$UPDATE_PLAN_STATUS"

PLAN_STATUS_LIB="$(common_test_resolve_subject "plan-status-line.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lib/plan-status-line.sh" \
  "$SCRIPT_DIR/../lib/plan-status-line.sh")" || exit 2
common_test_declare_subject "$PLAN_STATUS_LIB"
# shellcheck disable=SC1090
. "$PLAN_STATUS_LIB"

# SUITE_SELECTION_LIB: deliberately resolved as $VALIDATE_SRC's own sibling (never deploy-tree-
# first), because the Tier Justification fixtures below need to compute their EXPECTED answer
# from the exact same scripts-root `suite_selection_select` will resolve against inside
# $VALIDATE_SRC -- a tree mismatch here would make the fixtures assert against the wrong root's
# suite population (see this task's own summary for the live mismatch this resolution avoids).
SUITE_SELECTION_LIB="$SCRIPT_DIR/../lib/suite-selection-lib.sh"
if [[ ! -f "$SUITE_SELECTION_LIB" ]]; then
  echo "ERROR: suite-selection-lib.sh (source-store sibling) not found at: $SUITE_SELECTION_LIB" >&2
  exit 2
fi
# shellcheck disable=SC1090
. "$SUITE_SELECTION_LIB"

PASSED=0
FAILED=0


common_test_workdir_init

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

# ── Cross-phase ceiling consistency fixture builder: two phases each carrying a
# **Scope Hypothesis** line estimate in "lines", plus a caller-supplied Rollback/Contingency
# sentence that either cites a ceiling and asserts conformance, cites the same ceiling with a
# lower-summing estimate, or cites no ceiling at all -- the three shapes the three cases below
# each need. ────────────────────────────────────────────────────────────────────────────────
make_ceiling_fixture() {
  local phase1_estimate="$1" phase2_estimate="$2" rollback_sentence="$3"
  local f
  f="$(mktemp --tmpdir="$WORKDIR" plan-ceiling-XXXXXX.md)"
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

**Scope Hypothesis**: estimated at roughly ${phase1_estimate} added lines in file.go.

**Files to modify**:
- \`file.go\`

### Phase 2: Y [NOT STARTED]

**Verification Tier**: prose

**Scope Hypothesis**: estimated at roughly ${phase2_estimate} added lines in file.go.

**Files to modify**:
- \`file.go\`

## Testing & Validation
x

## Artifacts & Outputs
x

## Rollback/Contingency
${rollback_sentence}
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
if echo "$out" | grep -qF "[PASS]"; then common_test_pass "conforming Status line: [PASS]"; else common_test_fail "conforming Status line did not PASS: $out"; fi
if echo "$out" | grep -q "plan-level Status line"; then common_test_fail "conforming Status line raised a grammar error: $out"; else common_test_pass "conforming Status line raises no grammar error"; fi

# ─── Status-grammar: conforming + trailing annotation ───────────────────────────────────────
f=$(make_plan_fixture '- **Status**: [IMPLEMENTING] (resumed; Phases 1R-10R closed)')
out=$("$VALIDATE" "$f" plan 2>&1)
if echo "$out" | grep -qF "[PASS]"; then common_test_pass "trailing-annotation Status line: [PASS]"; else common_test_fail "trailing-annotation Status line did not PASS: $out"; fi

# ─── Status-grammar: M1 (no Status line at all) ─────────────────────────────────────────────
f=$(mktemp --tmpdir="$WORKDIR" plan-m1-XXXXXX.md)
cat > "$f" <<'EOF'
# Plan
no status line here
EOF
out=$("$VALIDATE" "$f" plan 2>&1)
if echo "$out" | grep -qF "plan-level Status line not found"; then common_test_pass "M1: plan-level Status line not found error"; else common_test_fail "M1 missing expected error: $out"; fi

# ─── Status-grammar: M2 (no bracket pair) ───────────────────────────────────────────────────
f=$(make_plan_fixture '- **Status**: COMPLETED')
out=$("$VALIDATE" "$f" plan 2>&1)
if echo "$out" | grep -qF "plan-level Status line has no [STATUS] bracket pair"; then common_test_pass "M2: no bracket pair error"; else common_test_fail "M2 missing expected error: $out"; fi
if echo "$out" | grep -qF "[FAIL]"; then common_test_pass "M2: overall [FAIL]"; else common_test_fail "M2 did not FAIL overall: $out"; fi

# ─── Status-grammar: M3 (text between prefix and bracket) ──────────────────────────────────
f=$(make_plan_fixture '- **Status**: see [NOTE]')
out=$("$VALIDATE" "$f" plan 2>&1)
if echo "$out" | grep -qF "plan-level Status line has unexpected text between the prefix and the bracket"; then common_test_pass "M3: unexpected-text error"; else common_test_fail "M3 missing expected error: $out"; fi

# ─── --fix non-participation: M2 fixture untouched, error still reported ───────────────────
f=$(make_plan_fixture '- **Status**: COMPLETED')
before=$(checksum "$f")
out=$("$VALIDATE" "$f" plan --fix 2>&1)
after=$(checksum "$f")
if [[ "$before" == "$after" ]]; then common_test_pass "--fix leaves M2 Status line byte-identical"; else common_test_fail "--fix mutated the M2 fixture"; fi
if echo "$out" | grep -qF "plan-level Status line has no [STATUS] bracket pair"; then common_test_pass "--fix still reports the M2 grammar error"; else common_test_fail "--fix suppressed the M2 grammar error: $out"; fi

# ─── Files to modify (a): phase block with no header at all -- draws the per-phase warning ──
f=$(make_two_phase_ftm_fixture '')
out=$("$VALIDATE" "$f" plan 2>&1)
if echo "$out" | grep -qF "Phase 1 missing **Files to modify** field"; then common_test_pass "FTM(a): no-header phase draws the per-phase warning"; else common_test_fail "FTM(a) missing expected warning: $out"; fi
if echo "$out" | grep -qF "Every phase omits the **Files to modify** field"; then common_test_fail "FTM(a): no-header-on-one-phase incorrectly raised the whole-plan error: $out"; else common_test_pass "FTM(a): no whole-plan error raised"; fi
if echo "$out" | grep -qF "[PASS]"; then common_test_pass "FTM(a): overall [PASS] in default mode (warning alone)"; else common_test_fail "FTM(a) did not PASS overall in default mode: $out"; fi

# ─── Files to modify (b): header present with only a "- none planned" prose sentinel -- NO finding
f=$(make_two_phase_ftm_fixture $'\n\n**Files to modify**:\n- none planned - pure verification phase')
out=$("$VALIDATE" "$f" plan 2>&1)
if echo "$out" | grep -qF "missing **Files to modify** field"; then common_test_fail "FTM(b): sentinel-only header incorrectly drew a missing-field finding: $out"; else common_test_pass "FTM(b): sentinel-only header draws no finding"; fi
if echo "$out" | grep -qF "Every phase omits"; then common_test_fail "FTM(b) incorrectly raised the whole-plan error: $out"; else common_test_pass "FTM(b): no whole-plan error"; fi
# The fixture's Phase 2 anchor path is the only real entry; Phase 1's sentinel line must
# contribute zero paths of its own (the harvester's unchanged []-contributes-nothing contract for
# a sentinel-only block), so the harvest is exactly the one-element anchor array, never more.
harvest_before=$(bash "$SCRIPT_DIR/../plan-file-scope-harvest.sh" "$f" 2>&1 | tr -d '[:space:]')
if [[ "$harvest_before" == '["path/to/anchor.ext"]' ]]; then common_test_pass "FTM(b): sentinel-only Phase 1 contributes zero paths to the harvest (unchanged contract)"; else common_test_fail "FTM(b): harvester output unexpectedly diverged: $harvest_before"; fi

# ─── Files to modify (c): header present with at least one backtick-path entry -- NO finding ──
f=$(make_two_phase_ftm_fixture $'\n\n**Files to modify**:\n- `some/real/path.ext`')
out=$("$VALIDATE" "$f" plan 2>&1)
if echo "$out" | grep -qF "missing **Files to modify** field"; then common_test_fail "FTM(c): header-with-path incorrectly drew a missing-field finding: $out"; else common_test_pass "FTM(c): header-with-path draws no finding"; fi
if echo "$out" | grep -qF "Every phase omits"; then common_test_fail "FTM(c) incorrectly raised the whole-plan error: $out"; else common_test_pass "FTM(c): no whole-plan error"; fi

# ─── Files to modify (d): every phase omits the field -- whole-plan log_error ───────────────
f=$(make_whole_plan_ftm_omit_fixture)
out=$("$VALIDATE" "$f" plan 2>&1)
if echo "$out" | grep -qF "Every phase omits the **Files to modify** field"; then common_test_pass "FTM(d): whole-plan omission raises the whole-plan error"; else common_test_fail "FTM(d) missing expected whole-plan error: $out"; fi
if echo "$out" | grep -qF "[FAIL]"; then common_test_pass "FTM(d): overall [FAIL] (error, not just warning)"; else common_test_fail "FTM(d) did not FAIL overall: $out"; fi
rc=0; "$VALIDATE" "$f" plan >/dev/null 2>&1 || rc=$?
if [[ $rc -ne 0 ]]; then common_test_pass "FTM(d): non-zero exit in default mode"; else common_test_fail "FTM(d): exit 0 despite whole-plan error"; fi

# ─── Files to modify (e): mixed plan (one phase omits, another declares) -- warning, NOT error ──
f=$(make_two_phase_ftm_fixture '')
out=$("$VALIDATE" "$f" plan 2>&1)
if echo "$out" | grep -qF "Phase 1 missing **Files to modify** field"; then common_test_pass "FTM(e): mixed plan draws the per-phase warning"; else common_test_fail "FTM(e) missing expected warning: $out"; fi
if echo "$out" | grep -qF "Every phase omits"; then common_test_fail "FTM(e): mixed plan incorrectly raised the whole-plan error: $out"; else common_test_pass "FTM(e): mixed plan raises no whole-plan error"; fi
rc=0; "$VALIDATE" "$f" plan >/dev/null 2>&1 || rc=$?
if [[ $rc -eq 0 ]]; then common_test_pass "FTM(e): default-mode exit 0 (warning alone does not fail the gate)"; else common_test_fail "FTM(e): unexpected non-zero exit in default mode: rc=$rc"; fi
rc=0; "$VALIDATE" "$f" plan --strict >/dev/null 2>&1 || rc=$?
if [[ $rc -ne 0 ]]; then common_test_pass "FTM(e): --strict escalates the per-phase warning to a non-zero exit"; else common_test_fail "FTM(e): --strict did not escalate: rc=$rc"; fi

# ─── Files to modify authoring-shape (g): all three shapes in one phase block -- each warns,
# default-mode exit stays 0, and --strict escalates. Uses VALIDATE_SRC (not the deploy-tree-first
# VALIDATE) because the deployed core tree can be stale relative to a freshly landed source-store
# edit -- the same VALIDATE_SRC precedent the TJ(negative) and ceiling(f) cases above already
# establish for exactly this reason. ────────────────────────────────────────────────────────────
f=$(make_two_phase_ftm_fixture '
**Files to modify**:
- `scripts/real-source-file.sh` - a legitimate path
- `scripts/wrapped.sh` - relocate the
  `## Some Heading` reference subsections behind the existing
- `scripts/commajoin-a.sh`, `scripts/commajoin-b.sh` - as ranked
- `.claude/scripts/stray.sh` - should be the sentinel instead')
out=$("$VALIDATE_SRC" "$f" plan 2>&1)
if echo "$out" | grep -qF "wrapped-continuation line begins with a backtick"; then common_test_pass "FTM-shape(g): wrapped-continuation shape warns"; else common_test_fail "FTM-shape(g) missing wrapped-continuation warning: $out"; fi
if echo "$out" | grep -qF "joins a second backtick-delimited path with a comma"; then common_test_pass "FTM-shape(g): comma-join shape warns"; else common_test_fail "FTM-shape(g) missing comma-join warning: $out"; fi
if echo "$out" | grep -qF "a deployed-tree (.claude/**) path is named directly"; then common_test_pass "FTM-shape(g): deployed-tree-path shape warns"; else common_test_fail "FTM-shape(g) missing deployed-tree-path warning: $out"; fi
if echo "$out" | grep -qF "[FAIL]"; then common_test_fail "FTM-shape(g): overall [FAIL] in default mode (should be warnings only): $out"; else common_test_pass "FTM-shape(g): overall default-mode outcome is not a hard [FAIL]"; fi
rc=0; "$VALIDATE_SRC" "$f" plan >/dev/null 2>&1 || rc=$?
if [[ $rc -eq 0 ]]; then common_test_pass "FTM-shape(g): default-mode exit 0 (warnings alone do not fail the gate)"; else common_test_fail "FTM-shape(g): unexpected non-zero exit in default mode: rc=$rc"; fi
rc=0; "$VALIDATE_SRC" "$f" plan --strict >/dev/null 2>&1 || rc=$?
if [[ $rc -ne 0 ]]; then common_test_pass "FTM-shape(g): --strict escalates to a non-zero exit"; else common_test_fail "FTM-shape(g): --strict did not escalate: rc=$rc"; fi

# ─── Files to modify authoring-shape (h): a correctly-authored block (one path per line, the
# sentinel used instead of a deployed-tree path) emits NONE of the three new warnings -- the
# no-noise negative case. ────────────────────────────────────────────────────────────────────
f=$(make_two_phase_ftm_fixture '
**Files to modify**:
- `scripts/real-source-file.sh` - a legitimate path
- `scripts/another-real-file.sh` - another legitimate path
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration')
out=$("$VALIDATE_SRC" "$f" plan 2>&1)
if echo "$out" | grep -qF "wrapped-continuation line begins with a backtick"; then common_test_fail "FTM-shape(h): false-positive wrapped-continuation warning: $out"; else common_test_pass "FTM-shape(h): no wrapped-continuation warning"; fi
if echo "$out" | grep -qF "joins a second backtick-delimited path with a comma"; then common_test_fail "FTM-shape(h): false-positive comma-join warning: $out"; else common_test_pass "FTM-shape(h): no comma-join warning"; fi
if echo "$out" | grep -qF "a deployed-tree (.claude/**) path is named directly"; then common_test_fail "FTM-shape(h): false-positive deployed-tree-path warning: $out"; else common_test_pass "FTM-shape(h): no deployed-tree-path warning"; fi

# ─── Cross-phase ceiling consistency (f): contradiction -- estimates sum past the cited
# ceiling while the plan asserts conformance -- WARNS, default-mode exit stays 0 ─────────────
f=$(make_ceiling_fixture "60" "50" "This change stays well under the 100-line limit.")
out=$("$VALIDATE_SRC" "$f" plan 2>&1)
if echo "$out" | grep -qF "sum to 110"; then common_test_pass "ceiling(f): contradiction fixture warns with the correct summed total"; else common_test_fail "ceiling(f) missing expected warning: $out"; fi
if echo "$out" | grep -qF "cited 100-line ceiling"; then common_test_pass "ceiling(f): warning names the cited ceiling"; else common_test_fail "ceiling(f) did not name the ceiling: $out"; fi
rc=0; "$VALIDATE_SRC" "$f" plan >/dev/null 2>&1 || rc=$?
if [[ $rc -eq 0 ]]; then common_test_pass "ceiling(f): default-mode exit stays 0 (advisory, not blocking)"; else common_test_fail "ceiling(f): unexpected non-zero exit in default mode: rc=$rc"; fi
rc=0; "$VALIDATE_SRC" "$f" plan --strict >/dev/null 2>&1 || rc=$?
if [[ $rc -ne 0 ]]; then common_test_pass "ceiling(f): --strict escalates the warning to a non-zero exit (via the pre-existing total_issues branch)"; else common_test_fail "ceiling(f): --strict did not escalate: rc=$rc"; fi

# ─── Cross-phase ceiling consistency (g): no-contradiction -- same cited ceiling, estimates
# sum BELOW it -- no warning from the new check ──────────────────────────────────────────────
f=$(make_ceiling_fixture "10" "10" "This change stays well under the 100-line limit.")
out=$("$VALIDATE_SRC" "$f" plan 2>&1)
if echo "$out" | grep -qF "cited 100-line ceiling"; then common_test_fail "ceiling(g): no-contradiction fixture incorrectly warned: $out"; else common_test_pass "ceiling(g): no-contradiction fixture draws no ceiling warning"; fi

# ─── Cross-phase ceiling consistency (h): no-ceiling -- per-phase estimates present but no
# ceiling cited anywhere -- the check must not fire on estimates alone ──────────────────────
f=$(make_ceiling_fixture "60" "50" "This change has no stated ceiling.")
out=$("$VALIDATE_SRC" "$f" plan 2>&1)
if echo "$out" | grep -qF "cited"; then common_test_fail "ceiling(h): no-ceiling fixture incorrectly warned: $out"; else common_test_pass "ceiling(h): no-ceiling fixture draws no ceiling warning"; fi

# ─── Report-heading: near-miss-only FAILs ───────────────────────────────────────────────────
f=$(make_report_fixture '
## Recommended Next Steps (for the plan phase)
x

## Context Extension Recommendations
x')
out=$("$VALIDATE" "$f" report 2>&1)
if echo "$out" | grep -qF "Missing required section: ## Recommendations"; then common_test_pass "near-miss headings alone: Missing required section error"; else common_test_fail "near-miss case did not report missing Recommendations: $out"; fi

# ─── Report-heading: conforming (## Recommendations added) PASSes ──────────────────────────
f=$(make_report_fixture '
## Recommended Next Steps (for the plan phase)
x

## Context Extension Recommendations
x

## Recommendations
x')
out=$("$VALIDATE" "$f" report 2>&1)
if echo "$out" | grep -qF "[PASS]"; then common_test_pass "conforming report (## Recommendations added): [PASS]"; else common_test_fail "conforming report did not PASS: $out"; fi

# ─── Report-heading: ## Context Extension Recommendations ALONE still FAILs ─────────────────
f=$(make_report_fixture '
## Context Extension Recommendations
x')
out=$("$VALIDATE" "$f" report 2>&1)
if echo "$out" | grep -qF "Missing required section: ## Recommendations"; then common_test_pass "Context Extension Recommendations alone still FAILs (no false pass)"; else common_test_fail "Context Extension Recommendations alone incorrectly satisfied Recommendations: $out"; fi

# ─── Depth tolerance: only conforming heading is ### Recommendations (nested) -- PASSes ────
f=$(make_report_fixture '
### Recommendations
x')
out=$("$VALIDATE" "$f" report 2>&1)
if echo "$out" | grep -qF "[PASS]"; then common_test_pass "depth-tolerant ### Recommendations satisfies the any-depth check"; else common_test_fail "depth-tolerant nested heading did not PASS: $out"; fi

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
      common_test_pass "conformance guard ($label): both accept (library=OK, update-plan-status.sh rc=0)"
    else
      common_test_fail "conformance guard ($label): library says OK but update-plan-status.sh rejected (rc=$rc): $(cat "$WORKDIR/conf-err.log")"
    fi
  else
    if [[ $rc -ne 0 ]]; then
      common_test_pass "conformance guard ($label): both reject (library=$shape, update-plan-status.sh rc=$rc)"
    else
      common_test_fail "conformance guard ($label): library says $shape but update-plan-status.sh accepted (rc=0)"
    fi
  fi
  rm -f "$WORKDIR/conf-err.log"
}

check_conformance "OK"      $'# Plan\n- **Status**: [IMPLEMENTING]'
check_conformance "trailing" $'# Plan\n- **Status**: [IMPLEMENTING] (resumed; Phases 1R-10R closed)'
check_conformance "M1"      $'# Plan\nno status line here'
check_conformance "M2"      $'# Plan\n- **Status**: COMPLETED'
check_conformance "M3"      $'# Plan\n- **Status**: see [NOTE]'

# ── Tier Justification measurement fixture builder: a two-phase plan whose Phase 1 (non-final)
# carries a caller-supplied **Files to modify** block and a caller-supplied
# **Tier Justification** line; Phase 2 (final) always carries a valid, unrelated anchor so the
# Files-to-modify presence check stays quiet and only the Tier Justification measurement check's
# own findings vary across cases.
#
# TJ_REAL_SUITE_PATH is deliberately NOT itself a `test-*.sh` file: `plan-file-scope-harvest.sh`
# is referenced by several real suites (measured, not assumed), and using a *non-test-shaped*
# basename avoids a genuine ambiguity discovered live while authoring this fixture -- the claim
# extraction below scans for `test-*.sh` TOKENS anywhere in the justification text, so a real
# suite PATH that itself looks like `test-*.sh` would be misread as part of the claim rather
# than as the measured subject, silently flipping a sentinel claim into a (coincidentally
# matching) suite-list claim. TJ_UNMAPPED_PATH is PID-suffixed so its exact runtime string never
# appears as a literal substring in this test file's OWN source -- a fixed literal placeholder
# would make `suite_selection_select`'s grep-based reference stratum discover THIS test file as
# a spurious "reference" to its own fixture string once this edit lands in the source store
# (confirmed live: a static placeholder resolved to `test-validate-artifact.sh` via that exact
# self-match, not to the sentinel). ─────────────────────────────────────────────────────────────
TJ_REAL_SUITE_PATH="agent-system/extensions/core/scripts/plan-file-scope-harvest.sh"
TJ_UNMAPPED_PATH="docs/nonexistent-fixture-subject-$$.md"
# Computed, never hardcoded, so this fixture tracks the corpus's actual current mapping rather
# than a snapshot that can silently drift stale as suites are added/removed/renamed.
mapfile -t TJ_REAL_SUITE_NAMES < <(suite_selection_select "$TJ_REAL_SUITE_PATH")
TJ_REAL_SUITE_NAMES_CSV="$(IFS=,; echo "${TJ_REAL_SUITE_NAMES[*]}")"

make_tj_fixture() {
  local files_block="$1" tier_justification="$2"
  local f
  f="$(mktemp --tmpdir="$WORKDIR" plan-tj-XXXXXX.md)"
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

**Verification Tier**: local

**Tier Justification**: ${tier_justification}

${files_block}

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

# ─── Tier Justification (positive): claim names exactly the measured suite(s) -- no mismatch ──
f=$(make_tj_fixture "**Files to modify**:
- \`${TJ_REAL_SUITE_PATH}\`" "\`suite_selection_select ${TJ_REAL_SUITE_PATH}\` returns \`${TJ_REAL_SUITE_NAMES[*]}\`, so the covering check is \`bash .claude/scripts/tests/run-all.sh --only ${TJ_REAL_SUITE_NAMES_CSV}\`.")
out=$("$VALIDATE_SRC" "$f" plan 2>&1)
if echo "$out" | grep -qF "Tier Justification"; then common_test_fail "TJ(positive): measured claim incorrectly drew a Tier Justification finding: $out"; else common_test_pass "TJ(positive): measured claim draws no Tier Justification finding"; fi
if echo "$out" | grep -qF "[PASS]"; then common_test_pass "TJ(positive): overall [PASS]"; else common_test_fail "TJ(positive) did not PASS overall: $out"; fi

# ─── Tier Justification (negative/fabrication): claim includes the real suite(s) PLUS a
# fabricated one that suite_selection_select never returns -- exactly one mismatch warning
# (fabrication only; the real suites' presence in the claim means no under-verification
# direction fires) ───────────────────────────────────────────────────────────────────────────
f=$(make_tj_fixture "**Files to modify**:
- \`${TJ_REAL_SUITE_PATH}\`" "\`suite_selection_select ${TJ_REAL_SUITE_PATH}\` returns \`${TJ_REAL_SUITE_NAMES[*]}\`, so the covering check is \`bash .claude/scripts/tests/run-all.sh --only ${TJ_REAL_SUITE_NAMES_CSV},test-totally-fabricated-suite.sh\`.")
out=$("$VALIDATE_SRC" "$f" plan 2>&1)
tj_warn_count=$(echo "$out" | grep -cF "Tier Justification")
if [[ "$tj_warn_count" -eq 1 ]]; then common_test_pass "TJ(negative): exactly one Tier Justification warning"; else common_test_fail "TJ(negative): expected exactly one Tier Justification warning, got $tj_warn_count: $out"; fi
if echo "$out" | grep -qF "fabricates coverage"; then common_test_pass "TJ(negative): warning identifies fabricated coverage"; else common_test_fail "TJ(negative) did not identify fabrication: $out"; fi
if echo "$out" | grep -qF "test-totally-fabricated-suite.sh"; then common_test_pass "TJ(negative): warning names the fabricated suite"; else common_test_fail "TJ(negative) did not name the fabricated suite: $out"; fi
rc=0; "$VALIDATE_SRC" "$f" plan --strict >/dev/null 2>&1 || rc=$?
if [[ $rc -ne 0 ]]; then common_test_pass "TJ(negative): --strict escalates to a non-zero exit"; else common_test_fail "TJ(negative): --strict did not escalate: rc=$rc"; fi
rc=0; "$VALIDATE_SRC" "$f" plan >/dev/null 2>&1 || rc=$?
if [[ $rc -eq 0 ]]; then common_test_pass "TJ(negative): default-mode exit stays 0 (advisory)"; else common_test_fail "TJ(negative): unexpected non-zero exit in default mode: rc=$rc"; fi

# ─── Tier Justification sentinel (i): claims __FULL_SWEEP__ for a path that actually maps to a
# real suite -- defect 2's own shape -- must WARN ───────────────────────────────────────────
f=$(make_tj_fixture "**Files to modify**:
- \`${TJ_REAL_SUITE_PATH}\`" "\`suite_selection_select ${TJ_REAL_SUITE_PATH}\` returns the \`__FULL_SWEEP__\` sentinel, so the covering check is \`bash <repo_root>/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <repo_root>\`.")
out=$("$VALIDATE_SRC" "$f" plan 2>&1)
if echo "$out" | grep -qF "unmeasured/false sentinel claim"; then common_test_pass "TJ-sentinel(i): fabricated sentinel claim WARNS"; else common_test_fail "TJ-sentinel(i) missing expected warning: $out"; fi

# ─── Tier Justification sentinel (ii): claims __FULL_SWEEP__ for a path genuinely unmapped to
# any suite -- the honest case -- must draw no finding ─────────────────────────────────────
f=$(make_tj_fixture "**Files to modify**:
- \`${TJ_UNMAPPED_PATH}\`" "\`suite_selection_select ${TJ_UNMAPPED_PATH}\` returns the \`__FULL_SWEEP__\` sentinel, so the covering check is \`bash <repo_root>/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <repo_root>\`.")
out=$("$VALIDATE_SRC" "$f" plan 2>&1)
if echo "$out" | grep -qF "Tier Justification"; then common_test_fail "TJ-sentinel(ii): measured sentinel claim incorrectly drew a finding: $out"; else common_test_pass "TJ-sentinel(ii): measured sentinel claim draws no finding"; fi

# ─── Tier Justification skip-case: Files to modify holds only the reserved __WHOLE_TREE__
# sentinel -- the remaining touched-path set is empty after filtering, so the check must skip
# silently even though the Tier Justification claim itself would otherwise mismatch ─────────
f=$(make_tj_fixture "**Files to modify**:
- \`__WHOLE_TREE__\` - deploy-headless.sh regenerates the entire deployed tree." "\`suite_selection_select\` is not applicable; this justification intentionally names a suite that does not exist, to prove the skip-case fires before any comparison is attempted: \`test-should-never-be-compared.sh\`.")
out=$("$VALIDATE_SRC" "$f" plan 2>&1)
if echo "$out" | grep -qF "Tier Justification"; then common_test_fail "TJ(skip-case): __WHOLE_TREE__-only phase incorrectly drew a Tier Justification finding: $out"; else common_test_pass "TJ(skip-case): __WHOLE_TREE__-only phase draws no Tier Justification finding"; fi

# ─── Tier Justification skip-case (prose sentinel): Files to modify holds only a
# "- none planned ..." prose sentinel (no backtick-path entry at all) -- the harvester already
# contributes zero paths for this shape (see FTM(b) above), so the remaining touched-path set is
# empty and the check must skip silently here too ──────────────────────────────────────────
f=$(make_tj_fixture "**Files to modify**:
- none planned - pure verification phase" "\`suite_selection_select\` is not applicable; this justification intentionally names a suite that does not exist, to prove the skip-case fires before any comparison is attempted: \`test-should-never-be-compared.sh\`.")
out=$("$VALIDATE_SRC" "$f" plan 2>&1)
if echo "$out" | grep -qF "Tier Justification"; then common_test_fail "TJ(skip-case, prose sentinel): incorrectly drew a Tier Justification finding: $out"; else common_test_pass "TJ(skip-case, prose sentinel): draws no Tier Justification finding"; fi

echo ""
common_test_info "Target scripts: $VALIDATE ; $VALIDATE_SRC ; $UPDATE_PLAN_STATUS ; $PLAN_STATUS_LIB"
echo "PASSED: $PASSED"
echo "FAILED: $FAILED"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
exit 0
