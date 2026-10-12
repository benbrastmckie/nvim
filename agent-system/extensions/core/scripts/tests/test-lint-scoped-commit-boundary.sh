#!/usr/bin/env bash
# test-lint-scoped-commit-boundary.sh - Both-polarity fixture test for
# scripts/lint/lint-scoped-commit-boundary.sh.
#
# The lint's job is to fail when a hand-rolled narrow `git add` + BARE `git commit -m` (no
# trailing pathspec) reappears anywhere in the source store, and to stay silent when the same
# commit is routed through scripts/git-commit-scoped.sh. This test asserts both polarities
# against synthetic fixtures written to a scratch directory, so it never depends on the live tree
# being clean (that is a separate, whole-tree assertion) and never mutates the repository.
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
# (.claude/scripts/tests/), which sit at different depths below the repo root. A single
# fixed levels-up count cannot be correct for both depths at once, so resolve via the git
# worktree root first (depth-independent) and only fall back to the fixed-depth guess
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

LINT_SCRIPT="$(resolve_candidate "lint-scoped-commit-boundary.sh" \
  "$REPO_ROOT/.claude/scripts/lint/lint-scoped-commit-boundary.sh" \
  "$SCRIPT_DIR/../lint/lint-scoped-commit-boundary.sh")" || exit 2

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# =====================================================================
# Case 1 (negative polarity): hand-rolled bare commit -> lint must fail (non-zero)
# =====================================================================
info "=== negative case: hand-rolled bare git commit -m ==="

DIRTY_DIR="$WORKDIR/dirty"
mkdir -p "$DIRTY_DIR"
DIRTY_FIXTURE="$DIRTY_DIR/synthetic-dirty-command.md"
cat > "$DIRTY_FIXTURE" << 'EOF'
# Synthetic Dirty Fixture

Commit the change:

```bash
git add specs/state.json specs/TODO.md
git commit -m "task {N}: create {title}"
```
EOF

if bash "$LINT_SCRIPT" "$DIRTY_DIR" >"$WORKDIR/dirty-out.txt" 2>&1; then
  fail "lint exited 0 for a hand-rolled bare git-commit call site (expected non-zero)"
else
  pass "lint exited non-zero for a hand-rolled bare git-commit call site"
fi

if grep -q "synthetic-dirty-command.md:7" "$WORKDIR/dirty-out.txt"; then
  pass "lint reports the violation with file:line"
else
  fail "lint output did not name the violating file:line:
$(cat "$WORKDIR/dirty-out.txt")"
fi

# =====================================================================
# Case 2 (positive polarity): equivalent git-commit-scoped.sh call -> lint must pass (exit 0)
# =====================================================================
info "=== positive case: routed through git-commit-scoped.sh ==="

CLEAN_DIR="$WORKDIR/clean"
mkdir -p "$CLEAN_DIR"
CLEAN_FIXTURE="$CLEAN_DIR/synthetic-clean-command.md"
cat > "$CLEAN_FIXTURE" << 'EOF'
# Synthetic Clean Fixture

Commit the change:

```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: create {title}" \
  --session "${session_id}" \
  -- specs/state.json specs/TODO.md
```
EOF

if bash "$LINT_SCRIPT" "$CLEAN_DIR" >"$WORKDIR/clean-out.txt" 2>&1; then
  pass "lint exited 0 for a commit routed through git-commit-scoped.sh"
else
  fail "lint exited non-zero for a git-commit-scoped.sh call (unexpected):
$(cat "$WORKDIR/clean-out.txt")"
fi

# =====================================================================
# Case 3 (structural control): a single-line invocation ending in a trailing `-- <pathspec>`
# is exempt by shape alone, even outside the file-level allowlist -- this is the sanctioned
# script's own internal invocation shape.
# =====================================================================
info "=== control case: trailing -- <pathspec> is exempt by shape ==="

SHAPE_DIR="$WORKDIR/shape"
mkdir -p "$SHAPE_DIR"
cat > "$SHAPE_DIR/synthetic-shape.sh" << 'EOF'
#!/usr/bin/env bash
# Synthetic shape fixture: a single-line commit ending in a trailing pathspec.
git commit -m "$full_message" -- "${pathspecs[@]}"
EOF

if bash "$LINT_SCRIPT" "$SHAPE_DIR" >"$WORKDIR/shape-out.txt" 2>&1; then
  pass "lint exited 0 for a commit ending in a trailing -- <pathspec> (exempt by shape)"
else
  fail "lint flagged a commit ending in a trailing -- <pathspec> (should be exempt by shape):
$(cat "$WORKDIR/shape-out.txt")"
fi

# =====================================================================
# Case 4 (file-level allowlist control): a file-level allowlisted path is exempt even though
# its content is the raw anti-pattern shape with no trailing pathspec.
# =====================================================================
info "=== control case: file-level allowlist entry exempt regardless of shape ==="

ALLOWLIST_DIR="$WORKDIR/allowlisted/agent-system/extensions/core/scripts"
mkdir -p "$ALLOWLIST_DIR"
cat > "$ALLOWLIST_DIR/git-commit-scoped.sh" << 'EOF'
#!/usr/bin/env bash
# Synthetic stand-in for the sanctioned script's own path, to exercise the allowlist
# independent of the real script's own content-based exemption.
git commit -m "placeholder"
EOF

if bash "$LINT_SCRIPT" "$WORKDIR/allowlisted" >"$WORKDIR/allowlist-out.txt" 2>&1; then
  pass "lint exited 0 for a file-level allowlisted path (git-commit-scoped.sh) regardless of shape"
else
  fail "lint flagged a file-level allowlisted path (should be exempt regardless of shape):
$(cat "$WORKDIR/allowlist-out.txt")"
fi

# =====================================================================
# Case 5: --verbose reports exempt candidate lines, tagged as exempt
# =====================================================================
info "=== verbose case: exempt lines are reported and tagged ==="

# Captured into a variable before grepping, rather than piped directly into `grep -q`: under
# `set -o pipefail` (in effect for this whole suite), `grep -q` closing its read end as soon as
# it finds a match can SIGPIPE the still-writing upstream process, and pipefail then reports the
# pipeline's exit status as that SIGPIPE kill (141) rather than grep's own successful 0 -- a false
# failure completely independent of whether the match was actually found. Capturing first avoids
# the race entirely.
verbose_shape_out="$(bash "$LINT_SCRIPT" --verbose "$SHAPE_DIR" 2>&1)"
if grep -q "\[EXEMPT\]" <<< "$verbose_shape_out"; then
  pass "--verbose tags exempt candidate lines"
else
  fail "--verbose did not report the exempt candidate line"
fi

# =====================================================================
# Case 6: --quiet suppresses the all-clear summary but still prints violations
# =====================================================================
info "=== quiet case: silent when clean, loud when dirty ==="

quiet_clean_out="$(bash "$LINT_SCRIPT" --quiet "$CLEAN_DIR" 2>&1)"
if [[ -z "$quiet_clean_out" ]]; then
  pass "--quiet produces no output on a clean scan"
else
  fail "--quiet produced output on a clean scan:
$quiet_clean_out"
fi

quiet_dirty_out="$(bash "$LINT_SCRIPT" --quiet "$DIRTY_DIR" 2>&1 || true)"
if grep -q "VIOLATION" <<< "$quiet_dirty_out"; then
  pass "--quiet still prints violations on a dirty scan"
else
  fail "--quiet suppressed a violation:
$quiet_dirty_out"
fi

# =====================================================================
# Case 7 (negative polarity, Rule 2): a piped phase-commit invocation with no set -o pipefail
# in effect -> lint must fail (non-zero), naming it as a PIPE-VIOLATION.
# =====================================================================
info "=== Rule 2 negative case: piped invocation, no pipefail ==="

PIPE_DIR="$WORKDIR/pipe-dirty"
mkdir -p "$PIPE_DIR"
PIPE_DIRTY_FIXTURE="$PIPE_DIR/synthetic-piped-command.md"
cat > "$PIPE_DIRTY_FIXTURE" << 'EOF'
# Synthetic Piped Fixture

Commit the change:

```bash
bash .claude/scripts/git-commit-scoped.sh --message "task {N}: create {title}" --session "${session_id}" -- specs/state.json | tail -25
```
EOF

if bash "$LINT_SCRIPT" "$PIPE_DIR" >"$WORKDIR/pipe-dirty-out.txt" 2>&1; then
  fail "lint exited 0 for a piped phase-commit invocation with no pipefail (expected non-zero)"
else
  pass "lint exited non-zero for a piped phase-commit invocation with no pipefail"
fi

if grep -q "PIPE-VIOLATION" "$WORKDIR/pipe-dirty-out.txt"; then
  pass "lint tags the finding as a PIPE-VIOLATION"
else
  fail "lint output did not tag the piped-invocation finding:
$(cat "$WORKDIR/pipe-dirty-out.txt")"
fi

# =====================================================================
# Case 8 (positive polarity, Rule 2): the identical piped invocation, but the file also sets
# `set -o pipefail` -> lint must pass (exit 0) for this rule (the real exit code now propagates).
# =====================================================================
info "=== Rule 2 positive case: piped invocation under set -o pipefail ==="

PIPEFAIL_DIR="$WORKDIR/pipe-clean-pipefail"
mkdir -p "$PIPEFAIL_DIR"
cat > "$PIPEFAIL_DIR/synthetic-piped-pipefail.sh" << 'EOF'
#!/usr/bin/env bash
set -o pipefail
bash .claude/scripts/git-commit-scoped.sh --message "msg" --session "$sid" -- specs/state.json | tail -25
EOF

if bash "$LINT_SCRIPT" "$PIPEFAIL_DIR" >"$WORKDIR/pipefail-out.txt" 2>&1; then
  pass "lint exited 0 for a piped invocation when set -o pipefail is in effect in the file"
else
  fail "lint flagged a piped invocation despite set -o pipefail being in effect:
$(cat "$WORKDIR/pipefail-out.txt")"
fi

# =====================================================================
# Case 9 (structural control, Rule 2): an UNpiped phase-commit invocation -> never a candidate.
# =====================================================================
info "=== Rule 2 control case: unpiped invocation is not flagged ==="

PIPE_CLEAN_DIR="$WORKDIR/pipe-clean"
mkdir -p "$PIPE_CLEAN_DIR"
cat > "$PIPE_CLEAN_DIR/synthetic-unpiped.md" << 'EOF'
# Synthetic Unpiped Fixture

```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: create {title}" \
  --session "${session_id}" \
  -- specs/state.json
```
EOF

if bash "$LINT_SCRIPT" "$PIPE_CLEAN_DIR" >"$WORKDIR/pipe-clean-out.txt" 2>&1; then
  pass "lint exited 0 for an unpiped phase-commit invocation"
else
  fail "lint flagged an unpiped phase-commit invocation (should never be a Rule 2 candidate):
$(cat "$WORKDIR/pipe-clean-out.txt")"
fi

# =====================================================================
# Case 10 (structural control, Rule 2): a pipe inside a TEST ASSERTION on captured output
# (the shape that already exists legitimately throughout test-git-commit-scoped.sh) is never a
# candidate -- the invocation line itself never carries a pipe, only a later assertion line does.
# =====================================================================
info "=== Rule 2 control case: a pipe inside a test assertion is not flagged ==="

ASSERTION_DIR="$WORKDIR/pipe-assertion"
mkdir -p "$ASSERTION_DIR"
cat > "$ASSERTION_DIR/synthetic-assertion.sh" << 'EOF'
#!/usr/bin/env bash
out="$(bash .claude/scripts/git-commit-scoped.sh --message "msg" --session "$sid" -- specs/state.json)"
rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q "some expected substring"; then
  echo "pass"
fi
EOF

if bash "$LINT_SCRIPT" "$ASSERTION_DIR" >"$WORKDIR/assertion-out.txt" 2>&1; then
  pass "lint exited 0 when the only pipe is inside a test assertion on captured output, not on the invocation line itself"
else
  fail "lint wrongly flagged a test-assertion pipe as a piped invocation:
$(cat "$WORKDIR/assertion-out.txt")"
fi

# =====================================================================
# Case 11 (negative polarity, Rule 3): a bare `|| echo ...` sink with no $?/rc=/case anywhere in
# the invocation block -> lint must fail (non-zero), naming it as a SINK-VIOLATION. Rule 3 scans
# .sh files only, so this fixture is a .sh file (an .md fixture would never be a candidate).
# =====================================================================
info "=== Rule 3 negative case: bare || echo sink, no \$? capture ==="

SINK_DIRTY_DIR="$WORKDIR/sink-dirty"
mkdir -p "$SINK_DIRTY_DIR"
cat > "$SINK_DIRTY_DIR/synthetic-sink.sh" << 'EOF'
#!/usr/bin/env bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "msg" --session "$sid" \
  -- specs/state.json \
  || echo "WARNING: commit failed (non-blocking)" >&2
EOF

if bash "$LINT_SCRIPT" "$SINK_DIRTY_DIR" >"$WORKDIR/sink-dirty-out.txt" 2>&1; then
  fail "lint exited 0 for a bare || echo exit-code sink (expected non-zero)"
else
  pass "lint exited non-zero for a bare || echo exit-code sink"
fi

if grep -q "SINK-VIOLATION" "$WORKDIR/sink-dirty-out.txt"; then
  pass "lint tags the finding as a SINK-VIOLATION"
else
  fail "lint output did not tag the exit-code-sink finding:
$(cat "$WORKDIR/sink-dirty-out.txt")"
fi

# =====================================================================
# Case 12 (positive polarity, Rule 3): the identical invocation shape, but the caller captures
# $? explicitly into an rc variable and branches via a case statement -> lint must pass (exit 0)
# for this rule. Proves the rule is not vacuous: the only difference from Case 11 is the capture.
# =====================================================================
info "=== Rule 3 positive case: rc=\$? capture plus a case branch ==="

SINK_CLEAN_DIR="$WORKDIR/sink-clean"
mkdir -p "$SINK_CLEAN_DIR"
cat > "$SINK_CLEAN_DIR/synthetic-sink-clean.sh" << 'EOF'
#!/usr/bin/env bash
commit_rc=0
bash .claude/scripts/git-commit-scoped.sh \
  --message "msg" --session "$sid" \
  -- specs/state.json || commit_rc=$?
case "$commit_rc" in
  0) : ;;
  1) echo "NOTE: nothing to commit (non-blocking)" >&2 ;;
  *) echo "ERROR: commit failed with exit $commit_rc" >&2 ;;
esac
EOF

if bash "$LINT_SCRIPT" "$SINK_CLEAN_DIR" >"$WORKDIR/sink-clean-out.txt" 2>&1; then
  pass "lint exited 0 when the caller captures \$? explicitly and branches via case"
else
  fail "lint flagged an exit-code-capturing, case-branching invocation as a sink:
$(cat "$WORKDIR/sink-clean-out.txt")"
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
