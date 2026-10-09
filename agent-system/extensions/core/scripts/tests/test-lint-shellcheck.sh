#!/usr/bin/env bash
# test-lint-shellcheck.sh - Both-polarity fixture test for scripts/lint/lint-shellcheck.sh.
#
# The lint's job is to fail when a tracked *.sh file carries a shellcheck finding at -S warning,
# and to stay silent on a clean file. This test asserts every documented polarity against
# synthetic fixtures written to a scratch directory, so it never depends on the live tree being
# clean (that is Gate 22's own whole-tree assertion, exercised separately) and never mutates the
# repository.
#
# Structural model: test-lint-state-writer-boundary.sh (mktemp -d workdir, deploy-tree-first /
# source-store-fallback candidate resolution, pass()/fail()/info() helpers).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.
# Note this is a test OF a lint: its exit code reports test success, not lint success.

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

resolve_candidate() {
  local desc="$1"; shift
  local candidate
  for candidate in "$@"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  echo "ERROR: $desc not found at any of:" >&2
  for candidate in "$@"; do
    echo "  $candidate" >&2
  done
  return 1
}

LINT_SCRIPT="$(resolve_candidate "lint-shellcheck.sh" \
  "$REPO_ROOT/.claude/scripts/lint/lint-shellcheck.sh" \
  "$SCRIPT_DIR/../lint/lint-shellcheck.sh")" || exit 2

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# =====================================================================
# Case 1 (negative polarity): a seeded SC2155 fixture -> lint must fail (non-zero) and name SC2155
# =====================================================================
info "=== negative case: seeded SC2155 (masked exit code) ==="

DIRTY_DIR="$WORKDIR/dirty"
mkdir -p "$DIRTY_DIR"
cat > "$DIRTY_DIR/synthetic-dirty.sh" << 'EOF'
#!/usr/bin/env bash
dirty_fn() {
  local x=$(false)
  echo "$x"
}
EOF

dirty_out="$(bash "$LINT_SCRIPT" "$DIRTY_DIR" 2>&1)"
dirty_status=$?
if [[ "$dirty_status" -ne 0 ]]; then
  pass "lint exited non-zero for a seeded SC2155 fixture"
else
  fail "lint exited 0 for a seeded SC2155 fixture (expected non-zero):
$dirty_out"
fi

if grep -q 'SC2155' <<< "$dirty_out"; then
  pass "lint output names SC2155"
else
  fail "lint output did not name SC2155:
$dirty_out"
fi

# =====================================================================
# Case 2 (positive polarity): a clean fixture at -S warning -> lint must pass (exit 0)
# =====================================================================
info "=== positive case: clean fixture ==="

CLEAN_DIR="$WORKDIR/clean"
mkdir -p "$CLEAN_DIR"
cat > "$CLEAN_DIR/synthetic-clean.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
clean_fn() {
  local x
  x="$(false || true)"
  echo "$x"
}
clean_fn
EOF

if bash "$LINT_SCRIPT" "$CLEAN_DIR" >"$WORKDIR/clean-out.txt" 2>&1; then
  pass "lint exited 0 for a clean fixture"
else
  fail "lint exited non-zero for a clean fixture (unexpected):
$(cat "$WORKDIR/clean-out.txt")"
fi

# =====================================================================
# Case 3: unresolvable shellcheck binary -> exit exactly 70, message names the tool
# =====================================================================
info "=== unresolvable-binary case: PATH cannot resolve shellcheck ==="

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck_dir="$(dirname "$(command -v shellcheck)")"
  scrubbed_path="$(printf '%s' "$PATH" | tr ':' '\n' | grep -vF "$shellcheck_dir" | paste -sd: -)"
else
  # The tool is already unresolvable in this environment; the ambient PATH itself exercises
  # the case.
  scrubbed_path="$PATH"
fi

unresolvable_out="$(PATH="$scrubbed_path" bash "$LINT_SCRIPT" "$CLEAN_DIR" 2>&1)"
unresolvable_status=$?
if [[ "$unresolvable_status" -eq 70 ]]; then
  pass "lint exits exactly 70 when shellcheck is unresolvable on PATH"
else
  fail "lint exited $unresolvable_status (expected 70) when shellcheck is unresolvable:
$unresolvable_out"
fi

if grep -qi 'shellcheck' <<< "$unresolvable_out"; then
  pass "unresolvable-binary message names the tool"
else
  fail "unresolvable-binary message did not name the tool:
$unresolvable_out"
fi

# =====================================================================
# Case 4: an empty scan path (no *.sh files) -> exit 2, never a silent exit 0
# =====================================================================
info "=== empty-scan-path case ==="

EMPTY_DIR="$WORKDIR/empty"
mkdir -p "$EMPTY_DIR"

empty_out="$(bash "$LINT_SCRIPT" "$EMPTY_DIR" 2>&1)"
empty_status=$?
if [[ "$empty_status" -eq 2 ]]; then
  pass "lint exits 2 on an empty scan path (never a silent exit 0)"
else
  fail "lint exited $empty_status (expected 2) on an empty scan path:
$empty_out"
fi

# =====================================================================
# Case 5: --quiet suppresses per-finding lines while preserving the exit code
# =====================================================================
info "=== quiet case: counts only, exit code preserved ==="

quiet_dirty_out="$(bash "$LINT_SCRIPT" --quiet "$DIRTY_DIR" 2>&1)"
quiet_dirty_status=$?
if [[ "$quiet_dirty_status" -ne 0 ]]; then
  pass "--quiet preserves the non-zero exit code on a dirty scan"
else
  fail "--quiet changed the exit code to 0 on a dirty scan"
fi

if grep -q '\[VIOLATION\]' <<< "$quiet_dirty_out"; then
  fail "--quiet did not suppress per-finding [VIOLATION] lines:
$quiet_dirty_out"
else
  pass "--quiet suppresses per-finding [VIOLATION] lines"
fi

if bash "$LINT_SCRIPT" --quiet "$CLEAN_DIR" >"$WORKDIR/quiet-clean-out.txt" 2>&1; then
  pass "--quiet preserves the zero exit code on a clean scan"
else
  fail "--quiet changed the exit code on a clean scan (expected 0):
$(cat "$WORKDIR/quiet-clean-out.txt")"
fi

# =====================================================================
# Case 6: --verbose emits the resolved shellcheck version
# =====================================================================
info "=== verbose case: resolved shellcheck version is reported ==="

verbose_out="$(bash "$LINT_SCRIPT" --verbose "$CLEAN_DIR" 2>&1)"
if grep -qi 'version' <<< "$verbose_out"; then
  pass "--verbose reports the resolved shellcheck version"
else
  fail "--verbose did not report the resolved shellcheck version:
$verbose_out"
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
