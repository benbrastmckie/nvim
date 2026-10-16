#!/usr/bin/env bash
# test-postflight-marker-schema.sh - Fixture test asserting skill_create_postflight_marker
# (scripts/skill-base.sh) produces the exact canonical Shape A key set: session_id, skill,
# task_number, operation, reason, created, stop_hook_active -- no more, no fewer.
#
# This closes the schema-drift gap the shared-skill-stage-skeleton effort settled: prior to
# unification, the corpus had six mutually incompatible marker shapes (two empty `touch`
# variants, skill-base.sh's own then-unused 6-key shape, and four JSON heredoc variants).
# Shape A is the fullest observed shape (adds `task_number`, which 38 of 40 live writers already
# emitted, and retains `stop_hook_active`, which the hard-mode variants had dropped by drift).
#
# Structural model: test-skill-base-lifecycle.sh (mktemp -d workdir, deploy-tree-first /
# source-store-fallback candidate resolution, sourced -- not subprocessed -- skill-base.sh
# itself, pass()/fail()/info() helpers, exit 0 all-pass / 1 any-fail / 2 environment error).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

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


SKILL_BASE="$(common_test_resolve_candidate "skill-base.sh" \
  "$REPO_ROOT/.claude/scripts/skill-base.sh" \
  "$SCRIPT_DIR/../skill-base.sh")" || exit 2

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required for this suite" >&2
  exit 2
fi

# shellcheck disable=SC1090
. "$SKILL_BASE"

PASSED=0
FAILED=0


common_test_workdir_init

ORIG_PWD="$(pwd)"
mkdir -p "$WORKDIR/specs"
cd "$WORKDIR" || exit 2

# =====================================================================
# Case 1: exact Shape A key set (no more, no fewer)
# =====================================================================
common_test_info "=== skill_create_postflight_marker: exact key set ==="

skill_create_postflight_marker "042" "fixture_task" "sess_1700000000_abc123" "skill-reviser" "research"

MARKER_FILE="specs/042_fixture_task/.postflight-pending"

if [[ -f "$MARKER_FILE" ]]; then
  common_test_pass "marker file created at expected path"
else
  common_test_fail "marker file not created at $MARKER_FILE"
fi

if jq empty "$MARKER_FILE" 2>/dev/null; then
  common_test_pass "marker file parses as valid JSON"
else
  common_test_fail "marker file is not valid JSON"
fi

EXPECTED_KEYS="cc_session_id created operation reason session_id skill stop_hook_active task_number"
ACTUAL_KEYS="$(jq -r 'keys | sort | join(" ")' "$MARKER_FILE" 2>/dev/null)"

if [[ "$ACTUAL_KEYS" == "$EXPECTED_KEYS" ]]; then
  common_test_pass "marker key set is exactly the eight Shape A keys: $ACTUAL_KEYS"
else
  common_test_fail "marker key set mismatch -- expected [$EXPECTED_KEYS], got [$ACTUAL_KEYS]"
fi

# =====================================================================
# Case 2: task_number is an unpadded integer derived from padded_num
# =====================================================================
common_test_info "=== task_number derivation ==="

TASK_NUMBER_VALUE="$(jq -r '.task_number' "$MARKER_FILE")"
TASK_NUMBER_TYPE="$(jq -r '.task_number | type' "$MARKER_FILE")"

if [[ "$TASK_NUMBER_TYPE" == "number" ]]; then
  common_test_pass "task_number is a JSON number (not a string)"
else
  common_test_fail "task_number has type '$TASK_NUMBER_TYPE', expected 'number'"
fi

if [[ "$TASK_NUMBER_VALUE" == "42" ]]; then
  common_test_pass "task_number correctly stripped leading zeros from padded_num '042' -> 42"
else
  common_test_fail "task_number expected '42', got '$TASK_NUMBER_VALUE'"
fi

# =====================================================================
# Case 3: field values round-trip correctly
# =====================================================================
common_test_info "=== field value fidelity ==="

if [[ "$(jq -r '.session_id' "$MARKER_FILE")" == "sess_1700000000_abc123" ]]; then
  common_test_pass "session_id round-trips correctly"
else
  common_test_fail "session_id did not round-trip correctly"
fi

if [[ "$(jq -r '.skill' "$MARKER_FILE")" == "skill-reviser" ]]; then
  common_test_pass "skill round-trips correctly"
else
  common_test_fail "skill did not round-trip correctly"
fi

if [[ "$(jq -r '.operation' "$MARKER_FILE")" == "research" ]]; then
  common_test_pass "operation round-trips correctly"
else
  common_test_fail "operation did not round-trip correctly"
fi

if [[ "$(jq -r '.stop_hook_active' "$MARKER_FILE")" == "false" ]]; then
  common_test_pass "stop_hook_active defaults to false"
else
  common_test_fail "stop_hook_active expected 'false', got '$(jq -r '.stop_hook_active' "$MARKER_FILE")'"
fi

# =====================================================================
# Case 3b: cc_session_id round-trips CLAUDE_CODE_SESSION_ID when set, and is present-but-empty
# when unset (key presence, not key absence, is the fail-safe contract both hooks rely on).
# =====================================================================
common_test_info "=== cc_session_id set/unset round-trip ==="

CLAUDE_CODE_SESSION_ID="cc-fixture-session-uuid" skill_create_postflight_marker \
  "043" "fixture_task_cc_set" "sess_1700000002_ghi789" "skill-reviser" "research"
MARKER_FILE_CC_SET="specs/043_fixture_task_cc_set/.postflight-pending"
if [[ "$(jq -r '.cc_session_id' "$MARKER_FILE_CC_SET" 2>/dev/null)" == "cc-fixture-session-uuid" ]]; then
  common_test_pass "cc_session_id round-trips CLAUDE_CODE_SESSION_ID when set"
else
  common_test_fail "cc_session_id did not round-trip CLAUDE_CODE_SESSION_ID -- got '$(jq -r '.cc_session_id' "$MARKER_FILE_CC_SET" 2>/dev/null)'"
fi

env -u CLAUDE_CODE_SESSION_ID bash -c "
  . '$SKILL_BASE'
  skill_create_postflight_marker '044' 'fixture_task_cc_unset' 'sess_1700000003_jkl012' 'skill-reviser' 'research'
"
MARKER_FILE_CC_UNSET="specs/044_fixture_task_cc_unset/.postflight-pending"
if [[ -f "$MARKER_FILE_CC_UNSET" ]] && jq -e 'has("cc_session_id")' "$MARKER_FILE_CC_UNSET" >/dev/null 2>&1 \
  && [[ "$(jq -r '.cc_session_id' "$MARKER_FILE_CC_UNSET")" == "" ]]; then
  common_test_pass "cc_session_id key is present and empty when CLAUDE_CODE_SESSION_ID is unset"
else
  common_test_fail "cc_session_id key presence/emptiness contract violated when CLAUDE_CODE_SESSION_ID is unset"
fi

# =====================================================================
# Case 4: task_number derivation with a zero-leading, multi-digit padded_num that has no
# leading zero to strip (regression guard against an off-by-one in the 10# arithmetic base).
# =====================================================================
common_test_info "=== task_number derivation (no leading zeros) ==="

skill_create_postflight_marker "123" "fixture_task_2" "sess_1700000001_def456" "skill-spawn" "plan"
MARKER_FILE_2="specs/123_fixture_task_2/.postflight-pending"
if [[ "$(jq -r '.task_number' "$MARKER_FILE_2" 2>/dev/null)" == "123" ]]; then
  common_test_pass "task_number derivation handles a padded_num with no leading zeros (123 -> 123)"
else
  common_test_fail "task_number derivation failed for padded_num '123'"
fi

cd "$ORIG_PWD" || true

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
