#!/usr/bin/env bash
# test-lint-directory-pathspec-boundary.sh - Both-polarity fixture test for
# scripts/lint/lint-directory-pathspec-boundary.sh.
#
# The lint's job is to fail when a `git-commit-scoped.sh` invocation ends in a bare SHARED
# directory pathspec (e.g. `-- specs/` or `-- .claude/`), and to stay silent when the same
# invocation stages explicit files, or a TASK-SCOPED directory (one carrying a `${...}`
# interpolation, a `{N}`/`{NNN}`-style placeholder, or an already-substituted
# `{NNN}_{SLUG}`-convention directory segment). This test asserts both polarities against
# synthetic fixtures written to a scratch directory, so it never depends on the live tree being
# clean (that is a separate, whole-tree assertion made by Phase 5 of the task that introduced
# this lint) and never mutates the repository.
#
# Structural model: test-lint-scoped-commit-boundary.sh (mktemp -d workdir, deploy-tree-first /
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

LINT_SCRIPT="$(resolve_candidate "lint-directory-pathspec-boundary.sh" \
  "$REPO_ROOT/.claude/scripts/lint/lint-directory-pathspec-boundary.sh" \
  "$SCRIPT_DIR/../lint/lint-directory-pathspec-boundary.sh")" || exit 2

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# =====================================================================
# Case 1 (negative polarity): bare `-- specs/`, multi-line backslash-continued form.
# =====================================================================
info "=== negative case: bare -- specs/ (multi-line) ==="

DIRTY_DIR="$WORKDIR/dirty"
mkdir -p "$DIRTY_DIR"
MULTILINE_FIXTURE="$DIRTY_DIR/synthetic-multiline.md"
cat > "$MULTILINE_FIXTURE" << 'EOF'
# Synthetic Multi-Line Fixture

```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: {action}" \
  --session "${session_id}" \
  -- specs/
```
EOF

if bash "$LINT_SCRIPT" "$DIRTY_DIR/synthetic-multiline.md" >"$WORKDIR/multiline-out.txt" 2>&1; then
  fail "lint exited 0 for a bare multi-line -- specs/ pathspec (expected non-zero)"
else
  pass "lint exited non-zero for a bare multi-line -- specs/ pathspec"
fi

if grep -q "synthetic-multiline.md:7" "$WORKDIR/multiline-out.txt"; then
  pass "lint reports the violation at the closing pathspec line"
else
  fail "lint output did not name the violating file:line:
$(cat "$WORKDIR/multiline-out.txt")"
fi

# =====================================================================
# Case 2 (negative polarity): bare `-- specs/`, single-line form.
# =====================================================================
info "=== negative case: bare -- specs/ (single-line) ==="

SINGLELINE_FIXTURE="$DIRTY_DIR/synthetic-singleline.md"
cat > "$SINGLELINE_FIXTURE" << 'EOF'
# Synthetic Single-Line Fixture

```bash
bash .claude/scripts/git-commit-scoped.sh --message "todo: archive {N} tasks" --session "${session_id}" -- specs/
```
EOF

if bash "$LINT_SCRIPT" "$SINGLELINE_FIXTURE" >"$WORKDIR/singleline-out.txt" 2>&1; then
  fail "lint exited 0 for a bare single-line -- specs/ pathspec (expected non-zero)"
else
  pass "lint exited non-zero for a bare single-line -- specs/ pathspec"
fi

# =====================================================================
# Case 3 (negative polarity): bare `-- .claude/` -- a different shared directory, same hazard.
# =====================================================================
info "=== negative case: bare -- .claude/ ==="

CLAUDEDIR_FIXTURE="$DIRTY_DIR/synthetic-claudedir.sh"
cat > "$CLAUDEDIR_FIXTURE" << 'EOF'
#!/usr/bin/env bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "meta: update rules" \
  --session "${session_id}" \
  -- .claude/
EOF

if bash "$LINT_SCRIPT" "$CLAUDEDIR_FIXTURE" >"$WORKDIR/claudedir-out.txt" 2>&1; then
  fail "lint exited 0 for a bare -- .claude/ pathspec (expected non-zero)"
else
  pass "lint exited non-zero for a bare -- .claude/ pathspec"
fi

# =====================================================================
# Case 4 (positive polarity): explicit file list -- lint must pass (exit 0).
# =====================================================================
info "=== positive case: explicit file list ==="

CLEAN_DIR="$WORKDIR/clean"
mkdir -p "$CLEAN_DIR"
EXPLICIT_FIXTURE="$CLEAN_DIR/synthetic-explicit.md"
cat > "$EXPLICIT_FIXTURE" << 'EOF'
# Synthetic Explicit-File-List Fixture

```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: {action}" \
  --session "${session_id}" \
  -- specs/TODO.md specs/state.json
```
EOF

if bash "$LINT_SCRIPT" "$EXPLICIT_FIXTURE" >"$WORKDIR/explicit-out.txt" 2>&1; then
  pass "lint exited 0 for an explicit file-list pathspec"
else
  fail "lint exited non-zero for an explicit file-list pathspec (unexpected):
$(cat "$WORKDIR/explicit-out.txt")"
fi

# =====================================================================
# Case 5 (positive polarity): task-scoped directory with a `${...}` interpolation.
# =====================================================================
info "=== positive case: task-scoped directory (interpolated) ==="

TASKSCOPED_FIXTURE="$CLEAN_DIR/synthetic-taskscoped.md"
cat > "$TASKSCOPED_FIXTURE" << 'EOF'
# Synthetic Task-Scoped Fixture

```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: {action}" \
  --session "${session_id}" \
  -- "specs/${padded}_${slug}/" specs/TODO.md
```
EOF

if bash "$LINT_SCRIPT" "$TASKSCOPED_FIXTURE" >"$WORKDIR/taskscoped-out.txt" 2>&1; then
  pass "lint exited 0 for a \${...}-interpolated task-scoped directory pathspec"
else
  fail "lint exited non-zero for a task-scoped directory pathspec (unexpected):
$(cat "$WORKDIR/taskscoped-out.txt")"
fi

# =====================================================================
# Case 6 (positive polarity): task-scoped directory via `${task_dir}/`.
# =====================================================================
info "=== positive case: task-scoped directory (\${task_dir}/) ==="

TASKDIR_FIXTURE="$CLEAN_DIR/synthetic-taskdir.md"
cat > "$TASKDIR_FIXTURE" << 'EOF'
# Synthetic Task-Dir Fixture

```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: {action}" \
  --session "${session_id}" \
  -- "${task_dir}/" specs/state.json
```
EOF

if bash "$LINT_SCRIPT" "$TASKDIR_FIXTURE" >"$WORKDIR/taskdir-out.txt" 2>&1; then
  pass "lint exited 0 for a \${task_dir}/ task-scoped directory pathspec"
else
  fail "lint exited non-zero for \${task_dir}/ (unexpected):
$(cat "$WORKDIR/taskdir-out.txt")"
fi

# =====================================================================
# Case 7 (positive polarity): a `git-commit-scoped.sh` mention in prose with no invocation
# (no trailing pathspec at all) must never be flagged.
# =====================================================================
info "=== positive case: prose mention, no invocation ==="

PROSE_FIXTURE="$CLEAN_DIR/synthetic-prose.md"
cat > "$PROSE_FIXTURE" << 'EOF'
# Synthetic Prose Fixture

Commits are routed through `.claude/scripts/git-commit-scoped.sh`, the single sanctioned
implementation of path-scoped, mutex-serialized committing. See its header for the full
contract.
EOF

if bash "$LINT_SCRIPT" "$PROSE_FIXTURE" >"$WORKDIR/prose-out.txt" 2>&1; then
  pass "lint exited 0 for a prose mention with no invocation"
else
  fail "lint exited non-zero for a prose-only mention (unexpected):
$(cat "$WORKDIR/prose-out.txt")"
fi

# =====================================================================
# Case 8 (positive polarity): a `:(exclude)` token is never a positive pathspec and must not
# itself be classified (even though it ends in no `/` it should simply be skipped, not exempted
# as a file -- verified here via --verbose output tagging it SKIP rather than EXEMPT).
# =====================================================================
info "=== positive case: :(exclude) magic pathspec is skipped, not classified ==="

EXCLUDE_FIXTURE="$CLEAN_DIR/synthetic-exclude.md"
cat > "$EXCLUDE_FIXTURE" << 'EOF'
# Synthetic Exclude-Magic Fixture

```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: {action}" \
  --session "${session_id}" \
  -- specs/TODO.md ":(exclude)specs/TODO.md.bak"
```
EOF

exclude_out="$(bash "$LINT_SCRIPT" --verbose "$EXCLUDE_FIXTURE" 2>&1)"
exclude_rc=$?
if [[ $exclude_rc -eq 0 ]]; then
  pass "lint exited 0 for a pathspec list containing a :(exclude) token"
else
  fail "lint exited non-zero for a :(exclude)-bearing pathspec (unexpected):
$exclude_out"
fi

if grep -q '\[SKIP\]' <<< "$exclude_out"; then
  pass "--verbose tags the :(exclude) token as SKIP, not EXEMPT or VIOLATION"
else
  fail "--verbose did not tag the :(exclude) token as SKIP:
$exclude_out"
fi

# =====================================================================
# Case 9 (file-level allowlist control): a file-level allowlisted path is exempt even though
# its content is the raw violation shape.
# =====================================================================
info "=== control case: file-level allowlist entry exempt regardless of shape ==="

ALLOWLIST_DIR="$WORKDIR/allowlisted/agent-system/extensions/core/scripts/lint"
mkdir -p "$ALLOWLIST_DIR"
cat > "$ALLOWLIST_DIR/lint-directory-pathspec-boundary.sh" << 'EOF'
#!/usr/bin/env bash
# Synthetic stand-in for the lint's own path, to exercise the allowlist independent of the
# real script's own content.
bash .claude/scripts/git-commit-scoped.sh \
  --message "placeholder" \
  --session "${session_id}" \
  -- specs/
EOF

if bash "$LINT_SCRIPT" "$WORKDIR/allowlisted" >"$WORKDIR/allowlist-out.txt" 2>&1; then
  pass "lint exited 0 for a file-level allowlisted path regardless of shape"
else
  fail "lint flagged a file-level allowlisted path (should be exempt regardless of shape):
$(cat "$WORKDIR/allowlist-out.txt")"
fi

# =====================================================================
# Case 10: --verbose reports exempt and skipped candidate tokens, tagged
# =====================================================================
info "=== verbose case: exempt tokens are reported and tagged ==="

explicit_verbose_out="$(bash "$LINT_SCRIPT" --verbose "$EXPLICIT_FIXTURE" 2>&1)"
# Captured first, then grepped -- piping directly to `grep -q` races: grep exits after its
# first match and closes the pipe, which can SIGPIPE the still-writing lint process (running
# under its own `set -e`) before its second [EXEMPT] line flushes; with this script's own
# `pipefail`, that SIGPIPE'd writer's non-zero exit then wins the pipeline status even though
# grep itself matched. Capturing to a variable first removes the race entirely.
if grep -q "\[EXEMPT\]" <<< "$explicit_verbose_out"; then
  pass "--verbose tags exempt candidate tokens"
else
  fail "--verbose did not report the exempt candidate token:
$explicit_verbose_out"
fi

# =====================================================================
# Case 11: --quiet suppresses the all-clear summary but still prints violations
# =====================================================================
info "=== quiet case: silent when clean, loud when dirty ==="

quiet_clean_out="$(bash "$LINT_SCRIPT" --quiet "$EXPLICIT_FIXTURE" 2>&1)"
if [[ -z "$quiet_clean_out" ]]; then
  pass "--quiet produces no output on a clean scan"
else
  fail "--quiet produced output on a clean scan:
$quiet_clean_out"
fi

quiet_dirty_out="$(bash "$LINT_SCRIPT" --quiet "$MULTILINE_FIXTURE" 2>&1 || true)"
if grep -q "VIOLATION" <<< "$quiet_dirty_out"; then
  pass "--quiet still prints violations on a dirty scan"
else
  fail "--quiet suppressed a violation:
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
