#!/usr/bin/env bash
# test-engine-written-state-paths-lib.sh - Regression suite for
# lib/engine-written-state-paths-lib.sh, the single canonical definition of the
# engine-written-state path set every file_scope Containment site admits regardless of a task's
# own declared file_scope.
#
# Structural model: test-derived-artifact-probe-lib.sh's library-direct testing style (source
# the real library in a scratch subshell, exercise its one exported function). This library has
# no .claude-extensions.json lookup and no fixture directories to fabricate -- it is a fixed
# constant -- so this suite is simpler: it asserts shape, exact membership, the
# membership-creep tripwire, and source-time idempotence/silence.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (library or jq not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
# REPO_ROOT resolution: same dual-depth support as sibling suites (source-store vs. deployed
# invocation sites sit at different depths below the repo root) -- resolve via the git worktree
# root first and only fall back to the fixed-depth guess when not inside a work tree.
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

LIB="$(common_test_resolve_subject "engine-written-state-paths-lib.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lib/engine-written-state-paths-lib.sh" \
  "$SCRIPT_DIR/../lib/engine-written-state-paths-lib.sh")" || exit 2
common_test_declare_subject "$LIB"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not found on PATH" >&2
  exit 2
fi

PASSED=0
FAILED=0

common_test_info "Using library: $LIB"

# =====================================================================
# Case (a): the function prints valid JSON that is an array of strings
# =====================================================================
RESULT_JSON="$(
  # shellcheck disable=SC1090
  . "$LIB"
  engine_written_state_paths
)"
if echo "$RESULT_JSON" | jq -e 'type == "array" and (all(.[]; type == "string"))' >/dev/null 2>&1; then
  common_test_pass "engine_written_state_paths prints a JSON array of strings"
else
  common_test_fail "engine_written_state_paths: expected a JSON array of strings, got <<<${RESULT_JSON}>>>"
fi

# =====================================================================
# Case (b): exactly the four expected members, no more
# =====================================================================
COUNT="$(echo "$RESULT_JSON" | jq 'length' 2>/dev/null)"
if [ "$COUNT" = "4" ]; then
  common_test_pass "engine_written_state_paths: exactly four members"
else
  common_test_fail "engine_written_state_paths: expected length 4, got <<<${COUNT}>>> (full value: ${RESULT_JSON})"
fi

# =====================================================================
# Case (c): specs/events.jsonl and specs/errors.json are present
# =====================================================================
if echo "$RESULT_JSON" | jq -e 'index("specs/events.jsonl") != null' >/dev/null 2>&1; then
  common_test_pass "specs/events.jsonl is present in the member set"
else
  common_test_fail "specs/events.jsonl is MISSING from the member set: ${RESULT_JSON}"
fi
if echo "$RESULT_JSON" | jq -e 'index("specs/errors.json") != null' >/dev/null 2>&1; then
  common_test_pass "specs/errors.json is present in the member set"
else
  common_test_fail "specs/errors.json is MISSING from the member set: ${RESULT_JSON}"
fi

# Also confirm the two pre-existing members survived the migration to this shared source.
if echo "$RESULT_JSON" | jq -e 'index("specs/TODO.md") != null' >/dev/null 2>&1; then
  common_test_pass "specs/TODO.md is present in the member set"
else
  common_test_fail "specs/TODO.md is MISSING from the member set: ${RESULT_JSON}"
fi
if echo "$RESULT_JSON" | jq -e 'index("specs/state.json") != null' >/dev/null 2>&1; then
  common_test_pass "specs/state.json is present in the member set"
else
  common_test_fail "specs/state.json is MISSING from the member set: ${RESULT_JSON}"
fi

# =====================================================================
# Case (d): specs/CHANGE_LOG.md and specs/ROADMAP.md are ABSENT -- a membership-creep
# tripwire, not a tautology. If a future edit widens the list past the justified four, this
# case fails loudly rather than silently passing.
# =====================================================================
if echo "$RESULT_JSON" | jq -e 'index("specs/CHANGE_LOG.md") == null' >/dev/null 2>&1; then
  common_test_pass "specs/CHANGE_LOG.md is absent (membership-creep tripwire)"
else
  common_test_fail "specs/CHANGE_LOG.md unexpectedly present -- membership has crept wider than the justified four: ${RESULT_JSON}"
fi
if echo "$RESULT_JSON" | jq -e 'index("specs/ROADMAP.md") == null' >/dev/null 2>&1; then
  common_test_pass "specs/ROADMAP.md is absent (membership-creep tripwire)"
else
  common_test_fail "specs/ROADMAP.md unexpectedly present -- membership has crept wider than the justified four: ${RESULT_JSON}"
fi

# =====================================================================
# Case (e): sourcing the file twice is idempotent and emits nothing on stdout or stderr at
# source time (the library must only define the function, never run it as a side effect of
# being sourced).
# =====================================================================
SOURCE_TWICE_OUT="$(
  # shellcheck disable=SC1090
  . "$LIB"
  # shellcheck disable=SC1090
  . "$LIB"
  engine_written_state_paths
  echo "RC=$?"
)"
SOURCE_TWICE_FIRST_LINE="$(
  # shellcheck disable=SC1090
  { . "$LIB"; } 2>&1
  echo "SOURCE_SILENT_MARKER"
)"
if echo "$SOURCE_TWICE_OUT" | grep -q 'RC=0$'; then
  common_test_pass "sourcing twice is idempotent: function still callable and returns rc 0"
else
  common_test_fail "sourcing twice: expected trailing RC=0, got <<<${SOURCE_TWICE_OUT}>>>"
fi
if [ "$(echo "$SOURCE_TWICE_FIRST_LINE" | head -1)" = "SOURCE_SILENT_MARKER" ]; then
  common_test_pass "sourcing emits nothing on stdout or stderr at source time"
else
  common_test_fail "sourcing produced unexpected output before the marker: <<<${SOURCE_TWICE_FIRST_LINE}>>>"
fi

echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
