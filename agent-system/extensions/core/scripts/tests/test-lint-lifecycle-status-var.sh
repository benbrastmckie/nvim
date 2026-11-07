#!/usr/bin/env bash
# test-lint-lifecycle-status-var.sh - Both-polarity fixture test for
# scripts/lint/lint-lifecycle-status-var.sh.
#
# The lint's job is to fail when a line both references $STATE_STATUS and names the
# lifecycle-notify call surface (skill_lifecycle_notify / lifecycle-notify.sh / lifecycle_script),
# and to stay silent on a correct $status call site or on a bare prose mention of $STATE_STATUS
# that does not co-occur with a lifecycle-notify call token. This test asserts both polarities
# against synthetic fixtures written to a scratch directory, so it never depends on the live tree
# being clean and never mutates the repository.
#
# Structural model: test-lint-state-writer-boundary.sh (mktemp -d workdir, deploy-tree-first /
# source-store-fallback candidate resolution, pass()/fail()/info() helpers).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.
# Note this is a test OF a lint: its exit code reports test success, not lint success.

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

LINT_SCRIPT="$(common_test_resolve_subject "lint-lifecycle-status-var.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lint/lint-lifecycle-status-var.sh" \
  "$SCRIPT_DIR/../lint/lint-lifecycle-status-var.sh")" || exit 2
common_test_declare_subject "$LINT_SCRIPT"

PASSED=0
FAILED=0


common_test_workdir_init

# =====================================================================
# Case 1 (negative polarity): skill_lifecycle_notify "$STATE_STATUS" -> lint must fail
# =====================================================================
common_test_info "=== negative case: skill_lifecycle_notify \"\$STATE_STATUS\" ==="

BAD_SHARED_FIXTURE="$WORKDIR/synthetic-bad-shared.md"
cat > "$BAD_SHARED_FIXTURE" << 'EOF'
# Synthetic Bad Fixture (shared-function call shape)

```bash
skill_lifecycle_notify "$STATE_STATUS"
```
EOF

if bash "$LINT_SCRIPT" "$BAD_SHARED_FIXTURE" >"$WORKDIR/bad-shared-out.txt" 2>&1; then
  common_test_fail "lint exited 0 for skill_lifecycle_notify \"\$STATE_STATUS\" (expected non-zero)"
else
  common_test_pass "lint exited non-zero for skill_lifecycle_notify \"\$STATE_STATUS\""
fi

if grep -q "synthetic-bad-shared.md:4" "$WORKDIR/bad-shared-out.txt" && \
   grep -q '\$status' "$WORKDIR/bad-shared-out.txt"; then
  common_test_pass "lint reports the violation with file:line and names the correct \$status variable"
else
  common_test_fail "lint output did not name the violating file:line or the correct \$status variable:
$(cat "$WORKDIR/bad-shared-out.txt")"
fi

# =====================================================================
# Case 2 (negative polarity): direct invocation via a literal path -> lint must fail
# =====================================================================
common_test_info "=== negative case: direct lifecycle-notify.sh invocation, literal path ==="

BAD_DIRECT_FIXTURE="$WORKDIR/synthetic-bad-direct.md"
cat > "$BAD_DIRECT_FIXTURE" << 'EOF'
# Synthetic Bad Fixture (direct invocation, literal path shape)

```bash
bash ".claude/scripts/lifecycle-notify.sh" "$STATE_STATUS" &
```
EOF

if bash "$LINT_SCRIPT" "$BAD_DIRECT_FIXTURE" >"$WORKDIR/bad-direct-out.txt" 2>&1; then
  common_test_fail "lint exited 0 for a literal-path direct lifecycle-notify.sh invocation (expected non-zero)"
else
  common_test_pass "lint exited non-zero for a literal-path direct lifecycle-notify.sh invocation"
fi

# =====================================================================
# Case 3 (negative polarity): direct invocation via a lifecycle_script variable -> lint must fail
# =====================================================================
common_test_info "=== negative case: direct invocation via \$lifecycle_script variable ==="

BAD_VAR_FIXTURE="$WORKDIR/synthetic-bad-var.md"
cat > "$BAD_VAR_FIXTURE" << 'EOF'
# Synthetic Bad Fixture (direct invocation, variable-held path shape)

```bash
lifecycle_script=".claude/scripts/lifecycle-notify.sh"
if [ -f "$lifecycle_script" ]; then bash "$lifecycle_script" "$STATE_STATUS" & fi
```
EOF

if bash "$LINT_SCRIPT" "$BAD_VAR_FIXTURE" >"$WORKDIR/bad-var-out.txt" 2>&1; then
  common_test_fail "lint exited 0 for a \$lifecycle_script-held direct invocation (expected non-zero)"
else
  common_test_pass "lint exited non-zero for a \$lifecycle_script-held direct invocation"
fi

# =====================================================================
# Case 4 (positive polarity): correct $status call site -> lint must pass (exit 0)
# =====================================================================
common_test_info "=== positive case: skill_lifecycle_notify \"\$status\" (the fix) ==="

GOOD_FIXTURE="$WORKDIR/synthetic-good.md"
cat > "$GOOD_FIXTURE" << 'EOF'
# Synthetic Good Fixture

```bash
skill_lifecycle_notify "$status"
```
EOF

if bash "$LINT_SCRIPT" "$GOOD_FIXTURE" >"$WORKDIR/good-out.txt" 2>&1; then
  common_test_pass "lint exited 0 for the correct skill_lifecycle_notify \"\$status\" call"
else
  common_test_fail "lint exited non-zero for a correct \$status call site (unexpected):
$(cat "$WORKDIR/good-out.txt")"
fi

# =====================================================================
# Case 5 (structural control / false-positive guard): a bare $STATE_STATUS prose mention with no
# co-occurring lifecycle-notify call token on the same line must NOT be flagged. This mirrors the
# real legitimate uses this lint must never false-positive on: update-task-status.sh's own
# internal map_status() assignment and status-markers.md's prose describing that mapping.
# =====================================================================
common_test_info "=== control case: bare \$STATE_STATUS prose mention, no lifecycle-notify token ==="

CONTROL_FIXTURE="$WORKDIR/synthetic-control-prose.md"
cat > "$CONTROL_FIXTURE" << 'EOF'
# Synthetic Control Fixture (legitimate prose, no lifecycle-notify call token)

`update-task-status.sh postflight ... implement` maps to state.json status `"completed"`
internally (see that script's own `postflight:implement -> STATE_STATUS="completed"` mapping).
EOF

if bash "$LINT_SCRIPT" "$CONTROL_FIXTURE" >"$WORKDIR/control-out.txt" 2>&1; then
  common_test_pass "lint exited 0 for a bare \$STATE_STATUS prose mention (correctly not flagged)"
else
  common_test_fail "lint flagged a bare \$STATE_STATUS prose mention (should be exempt -- no lifecycle-notify token co-occurs):
$(cat "$WORKDIR/control-out.txt")"
fi

# =====================================================================
# Case 6 (real-tree regression guard): the actual update-task-status.sh and status-markers.md
# legitimate uses must not be flagged when scanned directly.
# =====================================================================
common_test_info "=== real-tree false-positive guard: confirmed-legitimate files ==="

REAL_UTS="$SCRIPT_DIR/../update-task-status.sh"
REAL_STATUS_MARKERS="$SCRIPT_DIR/../../context/standards/status-markers.md"

for real_fixture in "$REAL_UTS" "$REAL_STATUS_MARKERS"; do
  if [[ ! -f "$real_fixture" ]]; then
    common_test_info "SKIP: $real_fixture not found at this invocation depth (non-fatal, structural)"
    continue
  fi
  if bash "$LINT_SCRIPT" "$real_fixture" >"$WORKDIR/real-out.txt" 2>&1; then
    common_test_pass "lint exited 0 for confirmed-legitimate file: $real_fixture"
  else
    common_test_fail "lint flagged a confirmed-legitimate file: $real_fixture
$(cat "$WORKDIR/real-out.txt")"
  fi
done

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
