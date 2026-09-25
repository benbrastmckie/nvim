#!/usr/bin/env bash
# test-return-meta-status-vocabulary.sh - Fixture-driven regression suite for
# scripts/lib/return-meta-status-vocabulary.sh, the single sourced anchor for the closed 8-value
# .return-meta.json status enum.
#
# Assertion families:
#   (a) Membership: all 8 values present, in order; "completed" is explicitly NOT a member.
#   (b) Sourcing assertion: validate-return-meta.sh carries no private literal copy of the
#       vocabulary and instead sources this library, so the two cannot silently diverge.
#   (c) Predicate correctness: is_return_meta_status accepts every enum value and rejects
#       "completed" and other foreign/fabricated values.
#   (d) Success-subset correctness: is_return_meta_success_status accepts exactly the 3 subset
#       values (researched, planned, implemented) and rejects in_progress, completed, and the
#       other 5 non-subset enum members (needs_research, partial, failed, blocked).
#
# Structural model: scripts/tests/test-status-vocabulary.sh (pass()/fail()/info() helpers, PASSED/
# FAILED integer counters, deploy-tree-first/source-store-fallback library resolution, exit 0 on
# all-pass / exit 1 on any-fail).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (library
# not found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. Resolve via the
# git worktree root first (depth-independent) and only fall back to the fixed-depth guess
# (matching the source-store depth) when SCRIPT_DIR is not inside a git work tree.
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

LIB_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/lib/return-meta-status-vocabulary.sh"
  "$SCRIPT_DIR/../lib/return-meta-status-vocabulary.sh"
)
LIB=""
for candidate in "${LIB_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    LIB="$candidate"
    break
  fi
done
if [[ -z "$LIB" ]]; then
  echo "ERROR: shared library return-meta-status-vocabulary.sh not found at any of:" >&2
  for candidate in "${LIB_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi
# shellcheck disable=SC1090
. "$LIB"

VALIDATOR_CANDIDATES=(
  "$SCRIPT_DIR/../validate-return-meta.sh"
  "$REPO_ROOT/.claude/scripts/validate-return-meta.sh"
)
VALIDATOR=""
for candidate in "${VALIDATOR_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    VALIDATOR="$candidate"
    break
  fi
done

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

# =====================================================================
# (a) Membership: exactly 8 values, in order; "completed" is NOT a member.
# =====================================================================
EXPECTED_ORDER=(in_progress researched planned implemented needs_research partial failed blocked)
if [[ "${#RETURN_META_STATUS_VALUES[@]}" -eq 8 ]]; then
  pass "RETURN_META_STATUS_VALUES has exactly 8 values"
else
  fail "expected exactly 8 enum values, got ${#RETURN_META_STATUS_VALUES[@]}"
fi

order_match=true
for i in "${!EXPECTED_ORDER[@]}"; do
  if [[ "${RETURN_META_STATUS_VALUES[$i]:-}" != "${EXPECTED_ORDER[$i]}" ]]; then
    order_match=false
  fi
done
if [[ "$order_match" == "true" ]]; then
  pass "RETURN_META_STATUS_VALUES order matches validate-return-meta.sh's original array"
else
  fail "RETURN_META_STATUS_VALUES order does not match expected: ${EXPECTED_ORDER[*]}"
  info "actual: ${RETURN_META_STATUS_VALUES[*]}"
fi

# =====================================================================
# (b) Sourcing assertion (Phase 2): validate-return-meta.sh no longer carries a private literal
# copy of the vocabulary -- it sources this library instead, so the two cannot drift. Replaces
# Phase 1's temporary drift assertion, which extracted a literal `valid_statuses=(...)` array
# that Phase 2 deleted from the validator.
# =====================================================================
if [[ -n "$VALIDATOR" ]]; then
  if grep -q '^valid_statuses=(' "$VALIDATOR"; then
    fail "validate-return-meta.sh still carries a private literal valid_statuses array -- Phase 2 should have deleted it"
  else
    pass "validate-return-meta.sh's private literal valid_statuses array is gone"
  fi
  if grep -q "return-meta-status-vocabulary.sh" "$VALIDATOR"; then
    pass "validate-return-meta.sh sources return-meta-status-vocabulary.sh"
  else
    fail "validate-return-meta.sh does not source return-meta-status-vocabulary.sh"
  fi
else
  info "validate-return-meta.sh not found at any candidate path; skipping sourcing assertion"
fi

if is_return_meta_status "completed"; then
  fail "is_return_meta_status ACCEPTED 'completed' (must reject -- forbidden value)"
else
  pass "is_return_meta_status correctly rejects 'completed'"
fi

# =====================================================================
# (c) Predicate correctness: every enum value accepted.
# =====================================================================
for v in "${RETURN_META_STATUS_VALUES[@]}"; do
  if is_return_meta_status "$v"; then
    pass "is_return_meta_status accepts enum value '$v'"
  else
    fail "is_return_meta_status REJECTED enum value '$v' (should accept)"
  fi
done

# Foreign/fabricated values rejected, including the task-level vocabulary's own members that are
# NOT members of this narrower enum (e.g. "not_started", "researching" -- task-level-only).
REJECT_FIXTURES=(
  "completed"
  "not_started"
  "researching"
  "ready"
)
for v in "${REJECT_FIXTURES[@]}"; do
  if is_return_meta_status "$v"; then
    fail "is_return_meta_status ACCEPTED '$v' (should reject -- not a member of the 8-value enum)"
  else
    pass "is_return_meta_status correctly rejects '$v'"
  fi
done

# =====================================================================
# (d) Success-subset correctness.
# =====================================================================
if [[ "${#RETURN_META_SUCCESS_STATUSES[@]}" -eq 3 ]]; then
  pass "RETURN_META_SUCCESS_STATUSES has exactly 3 values"
else
  fail "expected exactly 3 success-subset values, got ${#RETURN_META_SUCCESS_STATUSES[@]}"
fi

for v in "${RETURN_META_SUCCESS_STATUSES[@]}"; do
  if is_return_meta_success_status "$v"; then
    pass "is_return_meta_success_status accepts subset value '$v'"
  else
    fail "is_return_meta_success_status REJECTED subset value '$v' (should accept)"
  fi
done

NON_SUCCESS_ENUM_MEMBERS=(in_progress needs_research partial failed blocked)
for v in "${NON_SUCCESS_ENUM_MEMBERS[@]}"; do
  if is_return_meta_success_status "$v"; then
    fail "is_return_meta_success_status ACCEPTED '$v' (should reject -- valid enum member outside the success subset)"
  else
    pass "is_return_meta_success_status correctly rejects non-subset enum member '$v'"
  fi
done

if is_return_meta_success_status "completed"; then
  fail "is_return_meta_success_status ACCEPTED 'completed' (should reject)"
else
  pass "is_return_meta_success_status correctly rejects 'completed'"
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
