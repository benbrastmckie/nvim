#!/usr/bin/env bash
# test-status-vocabulary.sh - Fixture-driven regression suite for scripts/lib/status-vocabulary.sh,
# the single sourced anchor for the closed 13-value task-status enum (specs/state.json
# `.active_projects[].status`).
#
# Two assertion families:
#   (a) Anti-drift: the library's STATUS_VOCABULARY_ENUM is byte-equal (as a sorted set) to
#       context/schemas/state-schema.json's `definitions.taskStatus.enum` -- the schema and the
#       library are a single source with two representations, and this is the test that keeps
#       them from silently diverging.
#   (b) Predicate correctness: status_vocabulary_is_valid accepts every enum value and rejects
#       revising, revised (deliberately deleted dead vocabulary), research_complete, ready
#       (command-structure.md's fabricated-vocabulary defect sites), and in_progress (the
#       .return-meta.json vocabulary's cross-vocabulary confusion source).
#
# Structural model: scripts/tests/test-phase-heading-patterns.sh (pass()/fail()/info() helpers,
# PASSED/FAILED integer counters, deploy-tree-first/source-store-fallback library resolution,
# exit 0 on all-pass / exit 1 on any-fail).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (library
# or schema not found at any candidate path, or jq unavailable).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. A single
# fixed levels-up count cannot be correct for both depths at once, so resolve via the git
# worktree root first (depth-independent) and only fall back to the fixed-depth guess
# (matching the source-store depth) when SCRIPT_DIR is not inside a git work tree.
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

LIB="$(common_test_resolve_subject "status-vocabulary.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lib/status-vocabulary.sh" \
  "$SCRIPT_DIR/../lib/status-vocabulary.sh")" || exit 2
common_test_declare_subject "$LIB"
# shellcheck disable=SC1090
. "$LIB"

SCHEMA="$(common_test_resolve_subject "state-schema.json" "deploy-tree-first" \
  "$REPO_ROOT/.claude/context/schemas/state-schema.json" \
  "$SCRIPT_DIR/../../context/schemas/state-schema.json")" || exit 2
common_test_declare_subject "$SCHEMA"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not available; cannot compare schema enum" >&2
  exit 2
fi

PASSED=0
FAILED=0


# =====================================================================
# (a) Anti-drift: library enum vs. schema enum, compared as sorted sets.
# =====================================================================
schema_enum_sorted="$(jq -r '.definitions.taskStatus.enum[]' "$SCHEMA" | sort)"
lib_enum_sorted="$(printf '%s\n' "${STATUS_VOCABULARY_ENUM[@]}" | sort)"

if [[ "$schema_enum_sorted" == "$lib_enum_sorted" ]]; then
  common_test_pass "library STATUS_VOCABULARY_ENUM is byte-equal (as a sorted set) to schema definitions.taskStatus.enum"
else
  common_test_fail "library/schema enum DRIFT detected"
  common_test_info "schema enum (sorted):"
  common_test_info "$schema_enum_sorted"
  common_test_info "library enum (sorted):"
  common_test_info "$lib_enum_sorted"
fi

schema_count=$(jq -r '.definitions.taskStatus.enum | length' "$SCHEMA")
lib_count="${#STATUS_VOCABULARY_ENUM[@]}"
if [[ "$schema_count" -eq 13 && "$lib_count" -eq 13 ]]; then
  common_test_pass "both schema (n=$schema_count) and library (n=$lib_count) enums have exactly 13 values"
else
  common_test_fail "expected exactly 13 enum values; schema has $schema_count, library has $lib_count"
fi

# =====================================================================
# (b) Predicate correctness: every enum value accepted.
# =====================================================================
for v in "${STATUS_VOCABULARY_ENUM[@]}"; do
  if status_vocabulary_is_valid "$v"; then
    common_test_pass "status_vocabulary_is_valid accepts enum value '$v'"
  else
    common_test_fail "status_vocabulary_is_valid REJECTED enum value '$v' (should accept)"
  fi
done

# =====================================================================
# (b) Predicate correctness: dead/fabricated/foreign values rejected.
# =====================================================================
REJECT_FIXTURES=(
  "revising"
  "revised"
  "research_complete"
  "ready"
  "in_progress"
)
for v in "${REJECT_FIXTURES[@]}"; do
  if status_vocabulary_is_valid "$v"; then
    common_test_fail "status_vocabulary_is_valid ACCEPTED '$v' (should reject -- dead/fabricated/foreign vocabulary)"
  else
    common_test_pass "status_vocabulary_is_valid correctly rejects '$v'"
  fi
done

# =====================================================================
# status_vocabulary_todo_marker: spot-check a few mappings, including the pr_ready case whose
# marker contains a space (the reason this whole mapping exists as data rather than a mechanical
# uppercase+underscore-strip transform).
# =====================================================================
marker=$(status_vocabulary_todo_marker "pr_ready") || marker="__CALL_FAILED__"
if [[ "$marker" == "PR READY" ]]; then
  common_test_pass "status_vocabulary_todo_marker('pr_ready') == 'PR READY'"
else
  common_test_fail "status_vocabulary_todo_marker('pr_ready') returned '$marker', expected 'PR READY'"
fi

marker=$(status_vocabulary_todo_marker "not_started") || marker="__CALL_FAILED__"
if [[ "$marker" == "NOT STARTED" ]]; then
  common_test_pass "status_vocabulary_todo_marker('not_started') == 'NOT STARTED'"
else
  common_test_fail "status_vocabulary_todo_marker('not_started') returned '$marker', expected 'NOT STARTED'"
fi

marker=$(status_vocabulary_todo_marker "hold") || marker="__CALL_FAILED__"
if [[ "$marker" == "HOLD" ]]; then
  common_test_pass "status_vocabulary_todo_marker('hold') == 'HOLD'"
else
  common_test_fail "status_vocabulary_todo_marker('hold') returned '$marker', expected 'HOLD'"
fi

if status_vocabulary_todo_marker "revising" >/dev/null 2>&1; then
  common_test_fail "status_vocabulary_todo_marker('revising') succeeded (should fail -- dead vocabulary)"
else
  common_test_pass "status_vocabulary_todo_marker('revising') correctly fails"
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
