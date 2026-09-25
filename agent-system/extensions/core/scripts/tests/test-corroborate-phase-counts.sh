#!/usr/bin/env bash
# test-corroborate-phase-counts.sh - Fixture-driven regression suite for
# skill_corroborate_phase_counts() (scripts/skill-base.sh) and its sole consumer
# skill_gate_completion_claim() (also scripts/skill-base.sh), exercising the shared
# handoff-present corroboration path all three orchestration engines call into.
#
# Structural model: scripts/tests/test-phase-heading-patterns.sh (mktemp -d workdir with an
# EXIT-trap cleanup, deploy-tree-first / source-store-fallback candidate resolution, sourced --
# not subprocessed -- libraries, pass()/fail()/info() helpers with integer counters, exit 0
# all-pass / 1 any-fail / 2 environment error).
#
# This suite gives the verification bar's three fixtures (A, B, C below) a real harness that
# exercises production code -- skill_corroborate_phase_counts and skill_gate_completion_claim
# themselves -- rather than a hand-copied reimplementation of markdown-embedded bash.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (a
# required library was not found at any candidate path).

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

SKILL_BASE_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/skill-base.sh"
  "$SCRIPT_DIR/../skill-base.sh"
)
SKILL_BASE=""
for candidate in "${SKILL_BASE_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    SKILL_BASE="$candidate"
    break
  fi
done
if [[ -z "$SKILL_BASE" ]]; then
  echo "ERROR: skill-base.sh not found at any of:" >&2
  for candidate in "${SKILL_BASE_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

LIB_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/lib/phase-heading-patterns.sh"
  "$SCRIPT_DIR/../lib/phase-heading-patterns.sh"
)
LIB=""
for candidate in "${LIB_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    LIB="$candidate"
    break
  fi
done
if [[ -z "$LIB" ]]; then
  echo "ERROR: shared library phase-heading-patterns.sh not found at any of:" >&2
  for candidate in "${LIB_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

# shellcheck disable=SC1090
. "$LIB"
# shellcheck disable=SC1090
. "$SKILL_BASE"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# skill_corroborate_phase_counts invokes `bash .claude/scripts/validate-handoff.sh` (a cwd-relative
# path, matching the exact idiom the SKILL.md call sites use, since a live dispatch always runs
# with cwd == repo root under a real deploy). Run this suite's own invocations from REPO_ROOT so
# that path resolves identically to a production run.
cd "$REPO_ROOT" || { echo "ERROR: cannot cd to REPO_ROOT ($REPO_ROOT)" >&2; exit 2; }

# ─── parse_cpc_output <output_line> ────────────────────────────────────────────────────────────
# Parses skill_corroborate_phase_counts's single stdout line via `read` (never `eval`), setting
# CPC_COMPLETED / CPC_TOTAL / CPC_VERIFIED in the caller's scope.
parse_cpc_output() {
  local line="$1" a b c
  read -r a b c <<< "$line"
  CPC_COMPLETED="${a#phases_completed=}"
  CPC_TOTAL="${b#phases_total=}"
  CPC_VERIFIED="${c#plan_markers_verified=}"
}

# =====================================================================
# Fixture A (verification bar item 1): plan with all phases [COMPLETED], simulated handoff with
# null phase counts. Assert corroboration, the [UNVERIFIED PHASES CORROBORATED] banner, and that
# feeding the corroborated output into skill_gate_completion_claim returns 0 (ALLOW).
# =====================================================================
fixture_a_plan="$WORKDIR/fixture-a-plan.md"
cat > "$fixture_a_plan" << 'EOF'
### Phase 1: Alpha [COMPLETED]
### Phase 2: Beta [COMPLETED]
### Phase 3: Gamma [COMPLETED]
EOF
fixture_a_handoff="$WORKDIR/fixture-a-handoff.json"
cat > "$fixture_a_handoff" << 'EOF'
{
  "status": "implemented",
  "phases_completed": null,
  "phases_total": null,
  "blockers": [],
  "continuation_path": null
}
EOF

cpc_out_a="$(skill_corroborate_phase_counts 968 "$fixture_a_plan" "[test]" "$fixture_a_handoff" 2>"$WORKDIR/fixture-a.stderr")"
cpc_rc_a=$?

if [[ "$cpc_rc_a" -eq 0 ]]; then
  pass "Fixture A: skill_corroborate_phase_counts returns 0 (corroborated) for an all-closed plan"
else
  fail "Fixture A: expected return 0, got $cpc_rc_a"
fi

parse_cpc_output "$cpc_out_a"
if [[ "$CPC_VERIFIED" == "true" && "$CPC_COMPLETED" == "3" && "$CPC_TOTAL" == "3" ]]; then
  pass "Fixture A: output is phases_completed=3 phases_total=3 plan_markers_verified=true"
else
  fail "Fixture A: unexpected output ($cpc_out_a)"
fi

if grep -q "\[UNVERIFIED PHASES CORROBORATED\]" "$WORKDIR/fixture-a.stderr"; then
  pass "Fixture A: [UNVERIFIED PHASES CORROBORATED] banner emitted"
else
  fail "Fixture A: banner not found in stderr"
fi

if skill_gate_completion_claim 968 "$CPC_COMPLETED" "$CPC_TOTAL" "$CPC_VERIFIED" "[test]" 2>>"$WORKDIR/fixture-a.stderr"; then
  pass "Fixture A: skill_gate_completion_claim ALLOWS completion on the corroborated output"
else
  fail "Fixture A: gate refused despite corroborated evidence"
fi
# Verification arm (1): a linear, all-[COMPLETED] plan with a matching complete handoff --
# ALLOWED, emitting the case 2/3 label exactly as today (the widened trigger does not change this
# shape's outcome or label).
if grep -q "COMPLETION-CLAIM GATE case 2/3" "$WORKDIR/fixture-a.stderr"; then
  pass "Fixture A (arm 1): the case 2/3 label is emitted for a linear, fully-complete plan"
else
  fail "Fixture A (arm 1): expected the case 2/3 label on stderr, got: $(cat "$WORKDIR/fixture-a.stderr")"
fi

# =====================================================================
# Fixture B (verification bar item 2): plan with a partial close. Assert non-corroborated,
# plan_markers_verified stays absent, and the gate returns 1 (REFUSE).
# =====================================================================
fixture_b_plan="$WORKDIR/fixture-b-plan.md"
cat > "$fixture_b_plan" << 'EOF'
### Phase 1: Alpha [COMPLETED]
### Phase 2: Beta [NOT STARTED]
### Phase 3: Gamma [NOT STARTED]
EOF

cpc_out_b="$(skill_corroborate_phase_counts 968 "$fixture_b_plan" "[test]" 2>"$WORKDIR/fixture-b.stderr")"
cpc_rc_b=$?

if [[ "$cpc_rc_b" -eq 1 ]]; then
  pass "Fixture B: skill_corroborate_phase_counts returns 1 (not corroborated) for a partial plan"
else
  fail "Fixture B: expected return 1, got $cpc_rc_b"
fi

parse_cpc_output "$cpc_out_b"
if [[ "$CPC_VERIFIED" == "absent" ]]; then
  pass "Fixture B: plan_markers_verified stays absent"
else
  fail "Fixture B: expected plan_markers_verified=absent, got $CPC_VERIFIED"
fi

if skill_gate_completion_claim 968 0 0 "$CPC_VERIFIED" "[test]" 2>>"$WORKDIR/fixture-b.stderr"; then
  fail "Fixture B: gate ALLOWED completion for a partial plan (should REFUSE)"
else
  pass "Fixture B: gate REFUSES completion for a partial plan (accounting absent, no corroboration)"
fi

# =====================================================================
# Fixture C (verification bar item 3): plan has zero CONFORMING phase headings -- every heading
# line present fails the canonical grammar or the closed marker enum. Assert non-corroborated,
# the non-conforming warning is emitted, and the gate refuses.
# =====================================================================
fixture_c_plan="$WORKDIR/fixture-c-plan.md"
cat > "$fixture_c_plan" << 'EOF'
### Phase 1a: Alpha [COMPLETED]
### Phase 2.1.3: Beta [DESCOPED]
EOF

cpc_out_c="$(skill_corroborate_phase_counts 968 "$fixture_c_plan" "[test]" 2>"$WORKDIR/fixture-c.stderr")"
cpc_rc_c=$?

if [[ "$cpc_rc_c" -eq 1 ]]; then
  pass "Fixture C: skill_corroborate_phase_counts returns 1 (not corroborated) for a heading-less-conforming plan"
else
  fail "Fixture C: expected return 1, got $cpc_rc_c"
fi

parse_cpc_output "$cpc_out_c"
if [[ "$CPC_VERIFIED" == "absent" ]]; then
  pass "Fixture C: plan_markers_verified stays absent"
else
  fail "Fixture C: expected plan_markers_verified=absent, got $CPC_VERIFIED"
fi

if grep -q "NON-CONFORMING PHASE HEADING" "$WORKDIR/fixture-c.stderr"; then
  pass "Fixture C: non-conforming warning emitted"
else
  fail "Fixture C: expected a NON-CONFORMING PHASE HEADING warning in stderr"
fi

if skill_gate_completion_claim 968 0 0 "$CPC_VERIFIED" "[test]" 2>>"$WORKDIR/fixture-c.stderr"; then
  fail "Fixture C: gate ALLOWED completion for a non-conforming-headings plan (should REFUSE)"
else
  pass "Fixture C: gate REFUSES completion for a non-conforming-headings plan"
fi

# =====================================================================
# Fixture D: mixed [COMPLETED] and [COMPLETED WITH EXCLUSIONS], all closed. Assert corroborated --
# COMPLETED WITH EXCLUSIONS counts as closed per the shared library's DONE alternation.
# =====================================================================
fixture_d_plan="$WORKDIR/fixture-d-plan.md"
cat > "$fixture_d_plan" << 'EOF'
### Phase 1: Alpha [COMPLETED]
### Phase 2: Beta [COMPLETED WITH EXCLUSIONS]
EOF

cpc_out_d="$(skill_corroborate_phase_counts 968 "$fixture_d_plan" "[test]" 2>"$WORKDIR/fixture-d.stderr")"
cpc_rc_d=$?

if [[ "$cpc_rc_d" -eq 0 ]]; then
  pass "Fixture D: COMPLETED WITH EXCLUSIONS counts as closed -- corroborated"
else
  fail "Fixture D: expected return 0, got $cpc_rc_d"
fi
parse_cpc_output "$cpc_out_d"
if [[ "$CPC_VERIFIED" == "true" && "$CPC_COMPLETED" == "2" && "$CPC_TOTAL" == "2" ]]; then
  pass "Fixture D: output is phases_completed=2 phases_total=2 plan_markers_verified=true"
else
  fail "Fixture D: unexpected output ($cpc_out_d)"
fi

# =====================================================================
# Fixture E: a non-conforming heading (letter-suffixed phase number) mixed with otherwise-closed
# phases. Assert the unreliable/absent branch, never a corroboration -- one bad heading is
# sufficient to block the whole plan's corroboration.
# =====================================================================
fixture_e_plan="$WORKDIR/fixture-e-plan.md"
cat > "$fixture_e_plan" << 'EOF'
### Phase 1: Alpha [COMPLETED]
### Phase 2: Beta [COMPLETED]
### Phase 3a: Gamma [COMPLETED]
EOF

cpc_out_e="$(skill_corroborate_phase_counts 968 "$fixture_e_plan" "[test]" 2>"$WORKDIR/fixture-e.stderr")"
cpc_rc_e=$?

if [[ "$cpc_rc_e" -eq 1 ]]; then
  pass "Fixture E: a single non-conforming heading blocks corroboration for the whole plan"
else
  fail "Fixture E: expected return 1, got $cpc_rc_e"
fi
parse_cpc_output "$cpc_out_e"
if [[ "$CPC_VERIFIED" == "absent" ]]; then
  pass "Fixture E: plan_markers_verified stays absent"
else
  fail "Fixture E: expected plan_markers_verified=absent, got $CPC_VERIFIED"
fi

# =====================================================================
# Fixture F (D4 guard): phases_total > 0 and incomplete. Assert the gate refuses regardless of
# any corroboration output -- proving Case 1 (phase accounting present, incomplete -> always
# refuse) is untouched and cannot be overridden by a plan_markers_verified=true value.
# =====================================================================
if skill_gate_completion_claim 968 3 5 "true" "[test]" 2>"$WORKDIR/fixture-f.stderr"; then
  fail "Fixture F: gate ALLOWED completion with phases_total=5 phases_completed=3 (Case 1 must always refuse)"
else
  pass "Fixture F: gate REFUSES completion when phase accounting is present and incomplete, even with plan_markers_verified=true"
fi

# =====================================================================
# Fixture G: empty/missing plan path. Assert the absent verdict, not a crash.
# =====================================================================
cpc_out_g="$(skill_corroborate_phase_counts 968 "" "[test]" 2>"$WORKDIR/fixture-g.stderr")"
cpc_rc_g=$?
if [[ "$cpc_rc_g" -eq 1 ]]; then
  pass "Fixture G: empty plan_path returns 1 (not corroborated), no crash"
else
  fail "Fixture G: expected return 1, got $cpc_rc_g"
fi
parse_cpc_output "$cpc_out_g"
if [[ "$CPC_VERIFIED" == "absent" ]]; then
  pass "Fixture G: plan_markers_verified stays absent for an empty plan path"
else
  fail "Fixture G: expected plan_markers_verified=absent, got $CPC_VERIFIED"
fi

cpc_out_g2="$(skill_corroborate_phase_counts 968 "$WORKDIR/does-not-exist.md" "[test]" 2>"$WORKDIR/fixture-g2.stderr")"
cpc_rc_g2=$?
if [[ "$cpc_rc_g2" -eq 1 ]]; then
  pass "Fixture G: missing (non-empty but nonexistent) plan_path returns 1, no crash"
else
  fail "Fixture G: expected return 1 for a nonexistent plan path, got $cpc_rc_g2"
fi

# =====================================================================
# Fixture H: validate-handoff.sh invoked against a handoff with null counts. Assert the function
# still returns its own verdict and does not abort -- the diagnostic is non-gating.
# =====================================================================
fixture_h_plan="$WORKDIR/fixture-h-plan.md"
cat > "$fixture_h_plan" << 'EOF'
### Phase 1: Alpha [COMPLETED]
EOF
fixture_h_handoff="$WORKDIR/fixture-h-handoff.json"
cat > "$fixture_h_handoff" << 'EOF'
{
  "status": "implemented",
  "phases_completed": null,
  "phases_total": null,
  "blockers": []
}
EOF

# Sanity precondition: validate-handoff.sh itself must exit non-zero (FAIL) against this fixture,
# otherwise this fixture would not actually exercise the non-gating guarantee.
if bash .claude/scripts/validate-handoff.sh "$fixture_h_handoff" >/dev/null 2>&1; then
  info "Fixture H precondition: validate-handoff.sh unexpectedly exited 0 against a null-count handoff -- diagnostic non-gating guarantee is untested by this run, but the function-level assertions below still hold"
else
  info "Fixture H precondition confirmed: validate-handoff.sh exits non-zero against a null-count handoff"
fi

cpc_out_h="$(skill_corroborate_phase_counts 968 "$fixture_h_plan" "[test]" "$fixture_h_handoff" 2>"$WORKDIR/fixture-h.stderr")"
cpc_rc_h=$?
if [[ "$cpc_rc_h" -eq 0 ]]; then
  pass "Fixture H: function returns its own verdict (0, corroborated) despite validate-handoff.sh failing on the null-count handoff"
else
  fail "Fixture H: expected return 0, got $cpc_rc_h"
fi
parse_cpc_output "$cpc_out_h"
if [[ "$CPC_VERIFIED" == "true" && "$CPC_COMPLETED" == "1" && "$CPC_TOTAL" == "1" ]]; then
  pass "Fixture H: output unaffected by the non-gating validate-handoff.sh diagnostic"
else
  fail "Fixture H: unexpected output ($cpc_out_h)"
fi

# =====================================================================
# corroborate_and_gate <plan_path> <handoff_completed> <handoff_total> <log_prefix>
# <stderr_capture_file> -- replicates orchestrate-cycle-postflight.sh's OWN widened corroboration
# block verbatim in shape: call skill_corroborate_phase_counts unconditionally for an
# "implemented" dispatch, then gate the phases_completed/phases_total overwrite on
# plan_markers_verified=="true", leaving both untouched on any non-corroborating result. Then
# feeds the resulting (possibly-corrected) counts into skill_gate_completion_claim, exactly as
# the real caller does. Sets COG_COMPLETED/COG_TOTAL/COG_VERIFIED/COG_GATE_RC in the caller's
# scope. This is the arms (1)-(4) harness: the real production functions, called in the real
# widened sequence, without needing test-orchestrate-cycle-postflight.sh's full git/filesystem
# harness (which carries a large, pre-existing, unrelated flakiness surface -- confirmed via
# `git stash` bisection to already fail 34/110 cases before this change's first edit).
# =====================================================================
corroborate_and_gate() {
  local plan_path="$1" handoff_completed="$2" handoff_total="$3" log_prefix="$4" stderr_file="$5"
  local cpc_line cpc_a cpc_b cpc_c cog_cpc_completed cog_cpc_total cog_cpc_verified
  COG_COMPLETED="$handoff_completed"
  COG_TOTAL="$handoff_total"
  COG_VERIFIED="absent"
  cpc_line=$(skill_corroborate_phase_counts 968 "$plan_path" "$log_prefix" 2>>"$stderr_file")
  read -r cpc_a cpc_b cpc_c <<< "$cpc_line"
  cog_cpc_completed="${cpc_a#phases_completed=}"
  cog_cpc_total="${cpc_b#phases_total=}"
  cog_cpc_verified="${cpc_c#plan_markers_verified=}"
  if [[ "$cog_cpc_verified" == "true" ]]; then
    COG_COMPLETED="$cog_cpc_completed"
    COG_TOTAL="$cog_cpc_total"
  fi
  COG_VERIFIED="$cog_cpc_verified"
  if skill_gate_completion_claim 968 "$COG_COMPLETED" "$COG_TOTAL" "$COG_VERIFIED" "$log_prefix" 2>>"$stderr_file"; then
    COG_GATE_RC=0
  else
    COG_GATE_RC=1
  fi
}

# =====================================================================
# Fixture I (verification arm 2, plan-fixture half): a branched plan modeled on the observed
# incident -- seven phases, three of them [COMPLETED WITH EXCLUSIONS] with a full
# `#### Reasoned Exclusions` record, against a handoff reporting phases_completed=4
# phases_total=7 (the understated Case 1 shape). Assert ALLOWED, the case 2/3 label, and that the
# count reaches 7/7 through skill_corroborate_phase_counts -- not through any new field.
# =====================================================================
fixture_i_plan="$WORKDIR/fixture-i-plan.md"
cat > "$fixture_i_plan" << 'EOF'
### Phase 1: Rerunnable Harness and Pre-Change Baseline [COMPLETED]
### Phase 2: Twenty-Plus-Seed Sweep of the Renamed Construction [COMPLETED]
### Phase 3: Land the Alpha-Rename in core.py [COMPLETED WITH EXCLUSIONS]

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Land the alpha-rename | Phase 2's gate failed (5/25 undecided vs. 2/25 baseline); contingency branch taken instead | Sweep measurement in Phase 2's own report |

### Phase 4: Full Example-Set Regression Diff [COMPLETED WITH EXCLUSIONS]

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Regression diff | Bypassed by the same gate failure as Phase 3 | Sweep measurement in Phase 2's own report |

### Phase 5: Full Bimodal Suite and Gating Oracle Suite [COMPLETED WITH EXCLUSIONS]

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Full suite run | Bypassed by the same gate failure as Phase 3 | Sweep measurement in Phase 2's own report |

### Phase 6: Correct the Stale Claims and Record the History [COMPLETED]
### Phase 7: CONDITIONAL -- Revert and Author an UNSTABLE entry [COMPLETED]
EOF

: > "$WORKDIR/fixture-i.stderr"
corroborate_and_gate "$fixture_i_plan" 4 7 "[test]" "$WORKDIR/fixture-i.stderr"

if [[ "$COG_VERIFIED" == "true" && "$COG_COMPLETED" == "7" && "$COG_TOTAL" == "7" ]]; then
  pass "Fixture I: the branched-plan incident shape corroborates to 7/7 through skill_corroborate_phase_counts (no new field)"
else
  fail "Fixture I: expected 7/7 verified=true, got completed=$COG_COMPLETED total=$COG_TOTAL verified=$COG_VERIFIED"
fi
if [[ "$COG_GATE_RC" -eq 0 ]]; then
  pass "Fixture I: skill_gate_completion_claim ALLOWS completion on the corrected 7/7 count"
else
  fail "Fixture I: gate refused despite the corroborated 7/7 count"
fi
if grep -q "COMPLETION-CLAIM GATE case 2/3" "$WORKDIR/fixture-i.stderr"; then
  pass "Fixture I: the case 2/3 label is emitted (arm 2's caller-level label assertion)"
else
  fail "Fixture I: expected the case 2/3 label on stderr, got: $(cat "$WORKDIR/fixture-i.stderr")"
fi
if grep -q "\[UNVERIFIED PHASES CORROBORATED\].*7/7 phases closed" "$WORKDIR/fixture-i.stderr"; then
  pass "Fixture I: the corroboration banner names 7/7 phases closed"
else
  fail "Fixture I: expected the 7/7 corroboration banner, got: $(cat "$WORKDIR/fixture-i.stderr")"
fi

# =====================================================================
# Fixture J (verification arm 3): a bare shortfall -- the handoff reports phases_completed=4
# phases_total=7, and the PLAN ALSO shows only 4 of 7 phases closed (no exclusions anywhere).
# Assert REFUSED, the case 1/3 label, phases_total NOT zeroed, and -- replicating
# orchestrate-cycle-postflight.sh's own downstream defect-recording predicate verbatim -- that the
# condition guarding META_MISSING_AFTER_NARRATION (`phases_total == 0 && plan_markers_verified !=
# "true"`) evaluates FALSE, proving no false-positive defect record would be written. Fail-closed
# is preserved: a genuine shortfall is not silently reclassified as Case 3.
# =====================================================================
fixture_j_plan="$WORKDIR/fixture-j-plan.md"
cat > "$fixture_j_plan" << 'EOF'
### Phase 1: Alpha [COMPLETED]
### Phase 2: Beta [COMPLETED]
### Phase 3: Gamma [COMPLETED]
### Phase 4: Delta [COMPLETED]
### Phase 5: Epsilon [NOT STARTED]
### Phase 6: Zeta [NOT STARTED]
### Phase 7: Eta [NOT STARTED]
EOF

: > "$WORKDIR/fixture-j.stderr"
corroborate_and_gate "$fixture_j_plan" 4 7 "[test]" "$WORKDIR/fixture-j.stderr"

if [[ "$COG_COMPLETED" == "4" && "$COG_TOTAL" == "7" ]]; then
  pass "Fixture J: a bare shortfall leaves the handoff's own counts (4/7) untouched -- phases_total NOT zeroed"
else
  fail "Fixture J: expected the handoff's own 4/7 to survive untouched, got completed=$COG_COMPLETED total=$COG_TOTAL"
fi
if [[ "$COG_GATE_RC" -ne 0 ]]; then
  pass "Fixture J: skill_gate_completion_claim REFUSES on the genuine shortfall"
else
  fail "Fixture J: gate unexpectedly ALLOWED a genuine 4/7 shortfall"
fi
if grep -q "COMPLETION-CLAIM GATE case 1/3" "$WORKDIR/fixture-j.stderr"; then
  pass "Fixture J: the case 1/3 label is emitted -- refused as an ordinary Case 1, not reclassified"
else
  fail "Fixture J: expected the case 1/3 label on stderr, got: $(cat "$WORKDIR/fixture-j.stderr")"
fi
if [[ "$COG_TOTAL" -eq 0 && "$COG_VERIFIED" != "true" ]]; then
  fail "Fixture J: the caller's own defect-recording predicate (phases_total==0 && plan_markers_verified!=true) would WRONGLY fire -- false-positive META_MISSING_AFTER_NARRATION risk"
else
  pass "Fixture J: the caller's own defect-recording predicate does not fire (phases_total=$COG_TOTAL, plan_markers_verified=$COG_VERIFIED) -- no false-positive defect record"
fi

# =====================================================================
# Fixture K (verification arm 4): an agent under-reporting phases_total (handoff reports
# phases_completed=0 phases_total=0) against the SAME incomplete plan as Fixture J. Assert
# REFUSED, the case 3/3 label, and that the pre-existing defect-recording predicate DOES fire --
# regression guard proving an agent cannot escape the gate by under-reporting phases_total.
# =====================================================================
: > "$WORKDIR/fixture-k.stderr"
corroborate_and_gate "$fixture_j_plan" 0 0 "[test]" "$WORKDIR/fixture-k.stderr"

if [[ "$COG_GATE_RC" -ne 0 ]]; then
  pass "Fixture K: skill_gate_completion_claim REFUSES an under-reported 0/0 against an incomplete plan"
else
  fail "Fixture K: gate unexpectedly ALLOWED an under-reported 0/0"
fi
if grep -q "COMPLETION-CLAIM GATE case 3/3" "$WORKDIR/fixture-k.stderr"; then
  pass "Fixture K: the case 3/3 label is emitted"
else
  fail "Fixture K: expected the case 3/3 label on stderr, got: $(cat "$WORKDIR/fixture-k.stderr")"
fi
if [[ "$COG_TOTAL" -eq 0 && "$COG_VERIFIED" != "true" ]]; then
  pass "Fixture K: the caller's own defect-recording predicate DOES fire (phases_total=0, plan_markers_verified=$COG_VERIFIED) -- unchanged pre-existing behavior"
else
  fail "Fixture K: expected the defect-recording predicate to fire for an under-reported 0/0, got phases_total=$COG_TOTAL plan_markers_verified=$COG_VERIFIED"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "========================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "========================================"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
