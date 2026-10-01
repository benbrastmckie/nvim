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

LIB_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/lib/status-vocabulary.sh"
  "$SCRIPT_DIR/../lib/status-vocabulary.sh"
)
LIB=""
for candidate in "${LIB_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    LIB="$candidate"
    break
  fi
done
if [[ -z "$LIB" ]]; then
  echo "ERROR: shared library status-vocabulary.sh not found at any of:" >&2
  for candidate in "${LIB_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi
# shellcheck disable=SC1090
. "$LIB"

SCHEMA_CANDIDATES=(
  "$REPO_ROOT/.claude/context/schemas/state-schema.json"
  "$SCRIPT_DIR/../../context/schemas/state-schema.json"
)
SCHEMA=""
for candidate in "${SCHEMA_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    SCHEMA="$candidate"
    break
  fi
done
if [[ -z "$SCHEMA" ]]; then
  echo "ERROR: state-schema.json not found at any of:" >&2
  for candidate in "${SCHEMA_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not available; cannot compare schema enum" >&2
  exit 2
fi

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

# =====================================================================
# (a) Anti-drift: library enum vs. schema enum, compared as sorted sets.
# =====================================================================
schema_enum_sorted="$(jq -r '.definitions.taskStatus.enum[]' "$SCHEMA" | sort)"
lib_enum_sorted="$(printf '%s\n' "${STATUS_VOCABULARY_ENUM[@]}" | sort)"

if [[ "$schema_enum_sorted" == "$lib_enum_sorted" ]]; then
  pass "library STATUS_VOCABULARY_ENUM is byte-equal (as a sorted set) to schema definitions.taskStatus.enum"
else
  fail "library/schema enum DRIFT detected"
  info "schema enum (sorted):"
  info "$schema_enum_sorted"
  info "library enum (sorted):"
  info "$lib_enum_sorted"
fi

schema_count=$(jq -r '.definitions.taskStatus.enum | length' "$SCHEMA")
lib_count="${#STATUS_VOCABULARY_ENUM[@]}"
if [[ "$schema_count" -eq 13 && "$lib_count" -eq 13 ]]; then
  pass "both schema (n=$schema_count) and library (n=$lib_count) enums have exactly 13 values"
else
  fail "expected exactly 13 enum values; schema has $schema_count, library has $lib_count"
fi

# =====================================================================
# (b) Predicate correctness: every enum value accepted.
# =====================================================================
for v in "${STATUS_VOCABULARY_ENUM[@]}"; do
  if status_vocabulary_is_valid "$v"; then
    pass "status_vocabulary_is_valid accepts enum value '$v'"
  else
    fail "status_vocabulary_is_valid REJECTED enum value '$v' (should accept)"
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
    fail "status_vocabulary_is_valid ACCEPTED '$v' (should reject -- dead/fabricated/foreign vocabulary)"
  else
    pass "status_vocabulary_is_valid correctly rejects '$v'"
  fi
done

# =====================================================================
# status_vocabulary_todo_marker: spot-check a few mappings, including the pr_ready case whose
# marker contains a space (the reason this whole mapping exists as data rather than a mechanical
# uppercase+underscore-strip transform).
# =====================================================================
marker=$(status_vocabulary_todo_marker "pr_ready") || marker="__CALL_FAILED__"
if [[ "$marker" == "PR READY" ]]; then
  pass "status_vocabulary_todo_marker('pr_ready') == 'PR READY'"
else
  fail "status_vocabulary_todo_marker('pr_ready') returned '$marker', expected 'PR READY'"
fi

marker=$(status_vocabulary_todo_marker "not_started") || marker="__CALL_FAILED__"
if [[ "$marker" == "NOT STARTED" ]]; then
  pass "status_vocabulary_todo_marker('not_started') == 'NOT STARTED'"
else
  fail "status_vocabulary_todo_marker('not_started') returned '$marker', expected 'NOT STARTED'"
fi

marker=$(status_vocabulary_todo_marker "hold") || marker="__CALL_FAILED__"
if [[ "$marker" == "HOLD" ]]; then
  pass "status_vocabulary_todo_marker('hold') == 'HOLD'"
else
  fail "status_vocabulary_todo_marker('hold') returned '$marker', expected 'HOLD'"
fi

if status_vocabulary_todo_marker "revising" >/dev/null 2>&1; then
  fail "status_vocabulary_todo_marker('revising') succeeded (should fail -- dead vocabulary)"
else
  pass "status_vocabulary_todo_marker('revising') correctly fails"
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
