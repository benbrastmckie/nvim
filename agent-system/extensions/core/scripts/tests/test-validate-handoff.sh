#!/usr/bin/env bash
# test-validate-handoff.sh - Bidirectional fixture suite for validate-handoff.sh, asserting it
# enforces exactly the schema at context/schemas/orchestrator-handoff-schema.json: the full
# six-value status vocabulary, the conditional artifacts-non-empty rule, and the required
# summary field.
#
# Structural model: scripts/tests/test-phase-heading-patterns.sh /
# test-corroborate-phase-counts.sh (mktemp -d workdir with an EXIT-trap cleanup, deploy-tree-first
# / source-store-fallback candidate resolution, pass()/fail()/info() helpers with integer
# counters, exit 0 all-pass / 1 any-fail / 2 environment error).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (the
# validator script was not found at any candidate path).

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

# Source-store-first (not deploy-first, unlike test-corroborate-phase-counts.sh's SKILL_BASE
# resolution): this suite validates the validator's own logic under active development, which
# lives in the source store before a Phase 7 redeploy copies it to the deploy tree. After
# redeploy the two are identical, so either order then yields the same result.
VALIDATOR_CANDIDATES=(
  "$SCRIPT_DIR/../validate-handoff.sh"
  "$REPO_ROOT/.claude/scripts/validate-handoff.sh"
)
VALIDATOR=""
for candidate in "${VALIDATOR_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    VALIDATOR="$candidate"
    break
  fi
done
if [[ -z "$VALIDATOR" ]]; then
  echo "ERROR: validate-handoff.sh not found at any of:" >&2
  for candidate in "${VALIDATOR_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
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

# ─── assert_accept <name> <json-content> ───────────────────────────────────────────────────────
# Writes the fixture, runs the validator, asserts exit 0.
assert_accept() {
  local name="$1" content="$2"
  local f="$WORKDIR/${name}.json"
  printf '%s' "$content" > "$f"
  if bash "$VALIDATOR" "$f" >"$WORKDIR/${name}.out" 2>&1; then
    pass "$name: validator exits 0 (accept)"
  else
    fail "$name: validator exited non-zero (expected accept) -- see $WORKDIR/${name}.out"
  fi
}

# ─── assert_reject <name> <json-content> ───────────────────────────────────────────────────────
# Writes the fixture, runs the validator, asserts non-zero exit.
assert_reject() {
  local name="$1" content="$2"
  local f="$WORKDIR/${name}.json"
  printf '%s' "$content" > "$f"
  if bash "$VALIDATOR" "$f" >"$WORKDIR/${name}.out" 2>&1; then
    fail "$name: validator exited 0 (expected reject) -- see $WORKDIR/${name}.out"
  else
    pass "$name: validator exits non-zero (reject)"
  fi
}

# ─── assert_accept_no_warn <name> <grep-pattern> <json-content> ──────────────────────────────
# Writes the fixture, runs the validator, asserts exit 0 AND that <grep-pattern> does not appear
# anywhere in the captured output -- pins that a given WARN class stays silent on this fixture.
assert_accept_no_warn() {
  local name="$1" pattern="$2" content="$3"
  local f="$WORKDIR/${name}.json"
  printf '%s' "$content" > "$f"
  if ! bash "$VALIDATOR" "$f" >"$WORKDIR/${name}.out" 2>&1; then
    fail "$name: validator exited non-zero (expected accept) -- see $WORKDIR/${name}.out"
    return
  fi
  if grep -q -- "$pattern" "$WORKDIR/${name}.out"; then
    fail "$name: validator accepted but pattern '$pattern' unexpectedly present -- see $WORKDIR/${name}.out"
  else
    pass "$name: validator exits 0 (accept) and pattern '$pattern' absent"
  fi
}

# =====================================================================
# ACCEPT fixtures
# =====================================================================

# Accept 1: conformant hard-mode implemented handoff, summary + non-empty artifacts.
assert_accept "accept-implemented" '{
  "status": "implemented",
  "summary": "Implemented all phases and verified the deploy tree.",
  "artifacts": [
    {"type": "summary", "path": "specs/000_x/summaries/01_x-summary.md", "summary": "Implementation summary"}
  ],
  "phases_completed": 3,
  "phases_total": 3,
  "blockers": [],
  "continuation_path": null
}'

# Accept 2: partial handoff with artifacts: [] and a non-null continuation_path.
assert_accept "accept-partial" '{
  "status": "partial",
  "summary": "Stopped after phase 2 due to context pressure.",
  "artifacts": [],
  "phases_completed": 2,
  "phases_total": 5,
  "blockers": [],
  "continuation_path": "specs/000_x/handoffs/phase-2-handoff-20260101T000000Z.md"
}'

# Accept 3: researched-status handoff with a report artifact. This is the regression the fix
# exists to close -- the pre-change validator's 3-value status enum would have REJECTED it.
assert_accept "accept-researched" '{
  "status": "researched",
  "summary": "Completed research for the task.",
  "artifacts": [
    {"type": "report", "path": "specs/000_x/reports/01_x.md"}
  ],
  "phases_completed": 0,
  "phases_total": 0,
  "blockers": []
}'

# =====================================================================
# REJECT fixtures
# =====================================================================

# Reject 1: handoff missing artifacts entirely.
assert_reject "reject-no-artifacts" '{
  "status": "implemented",
  "summary": "Missing the artifacts field.",
  "phases_completed": 1,
  "phases_total": 1,
  "blockers": []
}'

# Reject 2: handoff missing summary.
assert_reject "reject-no-summary" '{
  "status": "implemented",
  "artifacts": [
    {"type": "summary", "path": "specs/000_x/summaries/01_x-summary.md"}
  ],
  "phases_completed": 1,
  "phases_total": 1,
  "blockers": []
}'

# Reject 3: implemented handoff with artifacts: [] (non-empty required for implemented).
assert_reject "reject-implemented-empty-artifacts" '{
  "status": "implemented",
  "summary": "Claims implemented but has no artifacts.",
  "artifacts": [],
  "phases_completed": 1,
  "phases_total": 1,
  "blockers": []
}'

# Reject 4: off-vocabulary status.
assert_reject "reject-off-vocab-status" '{
  "status": "done",
  "summary": "Off-vocabulary status value.",
  "artifacts": [
    {"type": "summary", "path": "specs/000_x/summaries/01_x-summary.md"}
  ],
  "phases_completed": 1,
  "phases_total": 1,
  "blockers": []
}'

# Reject 6: handoff missing blockers entirely -- an otherwise-conforming implemented handoff with
# no blockers key at all, the exact shape measured live in production incidents that motivated
# this check.
assert_reject "reject-no-blockers" '{
  "status": "implemented",
  "summary": "Missing the blockers field.",
  "artifacts": [
    {"type": "summary", "path": "specs/000_x/summaries/01_x-summary.md"}
  ],
  "phases_completed": 1,
  "phases_total": 1
}'

# =====================================================================
# WARN-scoping fixtures (Phase 4): sorry_inventory and continuation_path/continuation_context
# must not WARN on an ordinary clean implemented handoff; Check 5's status-conditioned
# continuation WARN must still fire when status is partial/blocked with no pointer set.
# =====================================================================

# A clean implemented handoff emits neither the sorry_inventory WARN nor the unconditioned
# continuation WARN (both were removed/relocated in Phase 4).
assert_accept_no_warn "accept-clean-no-sorry-warn" "Optional field absent: sorry_inventory" '{
  "status": "implemented",
  "summary": "Clean implemented handoff with no sorry_inventory field.",
  "artifacts": [
    {"type": "summary", "path": "specs/000_x/summaries/01_x-summary.md"}
  ],
  "phases_completed": 1,
  "phases_total": 1,
  "blockers": []
}'

assert_accept_no_warn "accept-clean-no-continuation-warn" "continuation_path (or continuation_context)" '{
  "status": "implemented",
  "summary": "Clean implemented handoff with no continuation pointer at all.",
  "artifacts": [
    {"type": "summary", "path": "specs/000_x/summaries/01_x-summary.md"}
  ],
  "phases_completed": 1,
  "phases_total": 1,
  "blockers": []
}'

# Tripwire: Check 5's status-conditioned continuation WARN must still fire for a partial-status
# handoff with no continuation pointer set -- proving the WARN relaxation above did not silence
# the one case where this signal is actually informative.
assert_accept "accept-partial-no-continuation-still-warns" '{
  "status": "partial",
  "summary": "Partial handoff with no continuation pointer set.",
  "artifacts": [],
  "phases_completed": 1,
  "phases_total": 3,
  "blockers": []
}'
if grep -q "continuation_path and continuation_context are both null or absent" \
    "$WORKDIR/accept-partial-no-continuation-still-warns.out" 2>/dev/null; then
  pass "accept-partial-no-continuation-still-warns: Check 5 continuation WARN still fires"
else
  fail "accept-partial-no-continuation-still-warns: Check 5 continuation WARN did not fire -- see $WORKDIR/accept-partial-no-continuation-still-warns.out"
fi

# =====================================================================
# dispatch_seq fixtures (three outcomes: valid integer, absent, non-integer)
# =====================================================================

# Accept 5: dispatch_seq present and a valid integer -- PASS, exit 0.
assert_accept "accept-dispatch-seq-integer" '{
  "status": "implemented",
  "summary": "Implemented with a valid dispatch_seq echoed back.",
  "artifacts": [
    {"type": "summary", "path": "specs/000_x/summaries/01_x-summary.md"}
  ],
  "phases_completed": 1,
  "phases_total": 1,
  "blockers": [],
  "dispatch_seq": 7
}'

# Accept 6: dispatch_seq absent entirely -- WARN, not a rejection (exit 0). Covers a writer that
# predates this contract or omits it by omission; the strict reject-on-absent form is
# deliberately not adopted.
assert_accept "accept-dispatch-seq-absent" '{
  "status": "implemented",
  "summary": "Implemented with no dispatch_seq field at all.",
  "artifacts": [
    {"type": "summary", "path": "specs/000_x/summaries/01_x-summary.md"}
  ],
  "phases_completed": 1,
  "phases_total": 1,
  "blockers": []
}'

# Reject 5: dispatch_seq present but not an integer -- FAIL, exit non-zero.
assert_reject "reject-dispatch-seq-non-integer" '{
  "status": "implemented",
  "summary": "Implemented with a malformed dispatch_seq.",
  "artifacts": [
    {"type": "summary", "path": "specs/000_x/summaries/01_x-summary.md"}
  ],
  "phases_completed": 1,
  "phases_total": 1,
  "blockers": [],
  "dispatch_seq": "not-an-integer"
}'

# =====================================================================
# Summary
# =====================================================================
info "Validator resolved to: $VALIDATOR"
echo ""
echo "========================================"
echo "test-validate-handoff.sh Summary"
echo "========================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
