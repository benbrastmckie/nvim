#!/usr/bin/env bash
# test-lint-state-writer-boundary.sh - Both-polarity fixture test for
# scripts/lint/lint-state-writer-boundary.sh.
#
# The lint's job is to fail when a hand-rolled `jq ... > <staging> && mv <staging> state.json`
# sequence reappears anywhere in the source store, and to stay silent when the same write is
# routed through scripts/state-write.sh. This test asserts both polarities against synthetic
# fixtures written to a scratch directory, so it never depends on the live tree being clean (that
# is a separate, whole-tree assertion) and never mutates the repository.
#
# Structural model: test-lint-postflight-boundary.sh (mktemp -d workdir, deploy-tree-first /
# source-store-fallback candidate resolution, pass()/fail()/info() helpers).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.
# Note this is a test OF a lint: its exit code reports test success, not lint success.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"
LINT_SCRIPT="$(common_test_resolve_candidate "lint-state-writer-boundary.sh" \
  "$REPO_ROOT/.claude/scripts/lint/lint-state-writer-boundary.sh" \
  "$SCRIPT_DIR/../lint/lint-state-writer-boundary.sh")" || exit 2

PASSED=0
FAILED=0
common_test_workdir_init

# =====================================================================
# Case 1 (negative polarity): hand-rolled staged write -> lint must fail (non-zero)
# =====================================================================
common_test_info "=== negative case: hand-rolled staged write ==="

DIRTY_DIR="$WORKDIR/dirty"
mkdir -p "$DIRTY_DIR"
DIRTY_FIXTURE="$DIRTY_DIR/synthetic-dirty-command.md"
cat > "$DIRTY_FIXTURE" << 'EOF'
# Synthetic Dirty Fixture

Update the task record:

```bash
jq '.foo = "bar"' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```
EOF

if bash "$LINT_SCRIPT" "$DIRTY_DIR" >"$WORKDIR/dirty-out.txt" 2>&1; then
  common_test_fail "lint exited 0 for a hand-rolled staged state.json write (expected non-zero)"
else
  common_test_pass "lint exited non-zero for a hand-rolled staged state.json write"
fi

if grep -q "synthetic-dirty-command.md:6" "$WORKDIR/dirty-out.txt"; then
  common_test_pass "lint reports the violation with file:line"
else
  common_test_fail "lint output did not name the violating file:line:
$(cat "$WORKDIR/dirty-out.txt")"
fi

# =====================================================================
# Case 2 (positive polarity): equivalent state-write.sh call -> lint must pass (exit 0)
# =====================================================================
common_test_info "=== positive case: routed through state-write.sh ==="

CLEAN_DIR="$WORKDIR/clean"
mkdir -p "$CLEAN_DIR"
CLEAN_FIXTURE="$CLEAN_DIR/synthetic-clean-command.md"
cat > "$CLEAN_FIXTURE" << 'EOF'
# Synthetic Clean Fixture

Update the task record:

```bash
.claude/scripts/state-write.sh '.foo = "bar"' --session-id "$SESSION_ID"
```
EOF

if bash "$LINT_SCRIPT" "$CLEAN_DIR" >"$WORKDIR/clean-out.txt" 2>&1; then
  common_test_pass "lint exited 0 for a write routed through state-write.sh"
else
  common_test_fail "lint exited non-zero for a state-write.sh call (unexpected):
$(cat "$WORKDIR/clean-out.txt")"
fi

# =====================================================================
# Case 3 (structural control): bare `mv` file relocation, not a staged write -> exit 0
# The vault-restore shape moves a whole state file into place; it is not a jq-staged
# read-modify-write and must not be flagged on shape alone.
# =====================================================================
common_test_info "=== control case: bare mv file relocation ==="

RELOCATE_DIR="$WORKDIR/relocate"
mkdir -p "$RELOCATE_DIR"
cat > "$RELOCATE_DIR/synthetic-relocate.sh" << 'EOF'
#!/usr/bin/env bash
# Synthetic relocation fixture: restores an archived state file into place.
mv "${vault_path}/archive/state.json" "${vault_path}/state.json"
EOF

if bash "$LINT_SCRIPT" "$RELOCATE_DIR" >"$WORKDIR/relocate-out.txt" 2>&1; then
  common_test_pass "lint exited 0 for a bare mv file relocation (correctly not flagged)"
else
  common_test_fail "lint flagged a bare mv file relocation (should be exempt by shape):
$(cat "$WORKDIR/relocate-out.txt")"
fi

# =====================================================================
# Case 4 (structural control): read-only existence check redirecting to /dev/null -> exit 0
# =====================================================================
common_test_info "=== control case: read-only /dev/null check ==="

READONLY_DIR="$WORKDIR/readonly"
mkdir -p "$READONLY_DIR"
cat > "$READONLY_DIR/synthetic-readonly.sh" << 'EOF'
#!/usr/bin/env bash
# Synthetic read-only fixture: existence check, writes nothing.
if ! jq -e '.active_projects[0]' specs/state.json > /dev/null 2>&1; then
  echo "absent"
fi
EOF

if bash "$LINT_SCRIPT" "$READONLY_DIR" >"$WORKDIR/readonly-out.txt" 2>&1; then
  common_test_pass "lint exited 0 for a read-only /dev/null existence check"
else
  common_test_fail "lint flagged a read-only /dev/null existence check (should be exempt by shape):
$(cat "$WORKDIR/readonly-out.txt")"
fi

# =====================================================================
# Case 5: --verbose reports exempt candidate lines, tagged as exempt
# =====================================================================
common_test_info "=== verbose case: exempt lines are reported and tagged ==="

if bash "$LINT_SCRIPT" --verbose "$RELOCATE_DIR" 2>&1 | grep -q "\[EXEMPT\]"; then
  common_test_pass "--verbose tags exempt candidate lines"
else
  common_test_fail "--verbose did not report the exempt candidate line"
fi

# =====================================================================
# Case 6: --quiet suppresses the all-clear summary but still prints violations
# =====================================================================
common_test_info "=== quiet case: silent when clean, loud when dirty ==="

quiet_clean_out="$(bash "$LINT_SCRIPT" --quiet "$CLEAN_DIR" 2>&1)"
if [[ -z "$quiet_clean_out" ]]; then
  common_test_pass "--quiet produces no output on a clean scan"
else
  common_test_fail "--quiet produced output on a clean scan:
$quiet_clean_out"
fi

quiet_dirty_out="$(bash "$LINT_SCRIPT" --quiet "$DIRTY_DIR" 2>&1 || true)"
if grep -q "VIOLATION" <<< "$quiet_dirty_out"; then
  common_test_pass "--quiet still prints violations on a dirty scan"
else
  common_test_fail "--quiet suppressed a violation:
$quiet_dirty_out"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
