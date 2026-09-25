#!/usr/bin/env bash
# test-return-meta-status-vocabulary.sh - Fixture-driven regression suite for
# scripts/lib/return-meta-status-vocabulary.sh, the single sourced anchor for the closed 8-value
# .return-meta.json status enum.
#
# Assertion families:
#   (a) Membership: all 8 values present, in order; "completed" is explicitly NOT a member.
#   (b) Drift assertion (TEMPORARY -- Phase 1 only): the library's array matches the literal
#       `valid_statuses=(...)` array still present in validate-return-meta.sh at authoring time,
#       so the two cannot silently diverge before Phase 2 lands. Phase 2 deletes the validator's
#       private literal array and replaces this assertion with a sourcing check (the validator
#       sources this library rather than carrying its own copy) -- see that phase's task list.
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
  "$REPO_ROOT/.claude/scripts/validate-return-meta.sh"
  "$SCRIPT_DIR/../validate-return-meta.sh"
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
# (b) Drift assertion (TEMPORARY -- see header comment; Phase 2 replaces this block).
# Extracts the literal `valid_statuses=(...)` array straight out of validate-return-meta.sh's
# source text (not by sourcing it -- the script is not designed to be sourced) and compares it,
# as a sorted set, against the library's own array. Skipped with an [INFO] line (not a [FAIL])
# once Phase 2 deletes the literal array, since at that point there is nothing left to extract
# and the sourcing assertion below takes over as the anti-drift mechanism.
# =====================================================================
if [[ -n "$VALIDATOR" ]] && grep -q '^valid_statuses=(' "$VALIDATOR"; then
  validator_line="$(grep '^valid_statuses=(' "$VALIDATOR")"
  # Extract every double-quoted token on the valid_statuses=( ... ) line.
  mapfile -t validator_values < <(grep -oE '"[a-z_]+"' <<<"$validator_line" | tr -d '"')
  validator_sorted="$(printf '%s\n' "${validator_values[@]}" | sort)"
  lib_sorted="$(printf '%s\n' "${RETURN_META_STATUS_VALUES[@]}" | sort)"
  if [[ "$validator_sorted" == "$lib_sorted" ]]; then
    pass "RETURN_META_STATUS_VALUES is byte-equal (as a sorted set) to validate-return-meta.sh's literal valid_statuses array"
  else
    fail "library/validator literal-array DRIFT detected"
    info "validator array (sorted): $validator_sorted"
    info "library array (sorted): $lib_sorted"
  fi
else
  info "validate-return-meta.sh's literal valid_statuses array not found (already extracted to the library) -- drift assertion retired, relying on the sourcing assertion below"
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
