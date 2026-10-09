#!/usr/bin/env bash
# test-lint-hook-registration-paths.sh - Both-polarity fixture test for
# scripts/lint/lint-hook-registration-paths.sh.
#
# The lint's job is to fail on a CWD-relative invoked-script path in a hook registration (in
# settings JSON surfaces or source-store markdown), on a hook registration present only in
# install-once root-files/settings.json and absent from every fragment surface, and on a
# registration invoking a source-store script that does not exist -- while staying silent on
# every correct shape (an accepted anchor, a both-surfaces or fragment-only registration, an
# explicit-cd direct invocation in a .sh file, a non-hook mcpServers command, a settings.local.json
# permission matcher, and an unrelated prose mention). This suite plants synthetic fixtures in a
# scratch directory and asserts both polarities; it never depends on the live tree being clean
# (that is a separate, whole-corpus assertion made by Phases 1-3's own verification and by the
# full verify-deploy.sh battery) and never mutates the repository.
#
# Structural model: test-lint-directory-pathspec-boundary.sh (mktemp -d WORKDIR, deploy-tree-first
# / source-store-fallback candidate resolution, pass()/fail()/info() helpers).
#
# No on-disk fixture files are committed -- every fixture below is built and torn down inside the
# mktemp -d WORKDIR.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.
# Note this is a test OF a lint: its exit code reports test success, not lint success.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

LINT_SCRIPT="$(resolve_candidate "lint-hook-registration-paths.sh" \
  "$REPO_ROOT/.claude/scripts/lint/lint-hook-registration-paths.sh" \
  "$SCRIPT_DIR/../lint/lint-hook-registration-paths.sh")" || exit 2

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# =====================================================================
# Case 1 (FAILING, criterion 1): direct CWD-relative `.claude/` registration.
# =====================================================================
info "=== FAILING: direct .claude/-relative registration ==="

CASE1_DIR="$WORKDIR/case1/root-files"
mkdir -p "$CASE1_DIR"
cat > "$CASE1_DIR/settings.json" << 'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash .claude/hooks/zz-case1.sh" }
        ]
      }
    ]
  }
}
EOF

case1_out="$(bash "$LINT_SCRIPT" "$CASE1_DIR/settings.json" 2>&1)"
case1_rc=$?
if [[ $case1_rc -ne 0 ]]; then
  pass "direct .claude/-relative registration exits non-zero"
else
  fail "direct .claude/-relative registration exited 0 (expected non-zero):
$case1_out"
fi
if grep -q '\[VIOLATION\].*zz-case1\.sh' <<< "$case1_out"; then
  pass "direct .claude/-relative violation names the offending registration"
else
  fail "direct .claude/-relative violation not reported as expected:
$case1_out"
fi

# =====================================================================
# Case 2 (FAILING, criterion 1): CWD-relative path nested inside a `bash -c '...'` wrapper.
# =====================================================================
info "=== FAILING: CWD-relative path nested inside bash -c wrapper ==="

CASE2_DIR="$WORKDIR/case2/merge-sources"
mkdir -p "$CASE2_DIR"
cat > "$CASE2_DIR/settings-hooks.json" << 'EOF'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          { "type": "command", "command": "bash -c 'FILE=$(echo \"$X\"); if [[ -n \"$FILE\" ]]; then bash .claude/hooks/zz-case2.sh 2>/dev/null; fi'" }
        ]
      }
    ]
  }
}
EOF

case2_out="$(bash "$LINT_SCRIPT" "$CASE2_DIR/settings-hooks.json" 2>&1)"
case2_rc=$?
if [[ $case2_rc -ne 0 ]] && grep -q 'VIOLATION' <<< "$case2_out"; then
  pass "bash -c nested CWD-relative invocation is flagged"
else
  fail "bash -c nested CWD-relative invocation was not flagged:
$case2_out"
fi

# =====================================================================
# Case 3 (FAILING, criterion 11): relative path containing NO `.claude/` at all (the "line-118"
# shape) -- the regression net against re-anchoring the rule on `.claude/` or `hooks/`.
# =====================================================================
info "=== FAILING: relative path with no .claude/ at all (line-118 shape) ==="

CASE3_DIR="$WORKDIR/case3/merge-sources"
mkdir -p "$CASE3_DIR"
cat > "$CASE3_DIR/settings-hooks.json" << 'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "bash scripts/claude-ready-signal-case3.sh 2>/dev/null || echo '{}'" }
        ]
      }
    ]
  }
}
EOF

case3_out="$(bash "$LINT_SCRIPT" "$CASE3_DIR/settings-hooks.json" 2>&1)"
case3_rc=$?
if [[ $case3_rc -ne 0 ]] && grep -q '\[VIOLATION\].*claude-ready-signal-case3\.sh' <<< "$case3_out"; then
  pass "relative path with no .claude/ at all is flagged (criterion 11)"
else
  fail "line-118-shaped relative path (no .claude/, no hooks/) was not flagged:
$case3_out"
fi

# =====================================================================
# Case 4 (FAILING, criterion 6): defective registration template inside a fenced JSON block in
# markdown.
# =====================================================================
info "=== FAILING: defective registration template in fenced markdown JSON ==="

CASE4_DIR="$WORKDIR/case4"
mkdir -p "$CASE4_DIR"
cat > "$CASE4_DIR/doc.md" << 'EOF'
# Example doc

Add this to your settings:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "bash .claude/hooks/zz-case4.sh" }
        ]
      }
    ]
  }
}
```

Done.
EOF

case4_out="$(bash "$LINT_SCRIPT" "$CASE4_DIR/doc.md" 2>&1)"
case4_rc=$?
if [[ $case4_rc -ne 0 ]] && grep -q '\[VIOLATION\].*doc\.md:.*zz-case4\.sh' <<< "$case4_out"; then
  pass "defective markdown registration template is flagged, naming file and line"
else
  fail "defective markdown fenced-JSON registration template was not flagged:
$case4_out"
fi

# =====================================================================
# Case 5a (FAILING, criteria 8/9): root-files-only registration, hooks/-shaped, naming both the
# hook script and the fragment file it belongs in. Uses a REAL, existing hook script name
# (guard-destructive-git.sh) so Check D (existence) does not also fire, keeping this assertion
# isolated to the fragment-coverage check.
# =====================================================================
info "=== FAILING: root-files-only registration (hooks/-shaped) ==="

CASE5A_DIR="$WORKDIR/case5a/root-files"
mkdir -p "$CASE5A_DIR"
cat > "$CASE5A_DIR/settings.json" << 'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/guard-destructive-git.sh" }
        ]
      }
    ]
  }
}
EOF

case5a_out="$(bash "$LINT_SCRIPT" "$CASE5A_DIR/settings.json" 2>&1)"
case5a_rc=$?
if [[ $case5a_rc -ne 0 ]] \
   && grep -q "guard-destructive-git.sh" <<< "$case5a_out" \
   && grep -q "absent from every fragment surface" <<< "$case5a_out" \
   && grep -q "agent-system/extensions/core/merge-sources/settings-hooks.json" <<< "$case5a_out"; then
  pass "hooks/-shaped root-files-only registration names both the hook script and the target fragment file"
else
  fail "hooks/-shaped root-files-only registration did not report as expected:
$case5a_out"
fi
if ! grep -q "does not exist" <<< "$case5a_out"; then
  pass "hooks/-shaped root-files-only case does not spuriously trip the existence check (real script)"
else
  fail "hooks/-shaped root-files-only case unexpectedly tripped the existence check:
$case5a_out"
fi

# =====================================================================
# Case 5b (FAILING, criteria 8/9): root-files-only registration, scripts/-shaped (not hooks/-
# shaped) -- proves the identity notion is not narrowed to hooks/ only. Uses a REAL, existing
# script (verify-deploy.sh) so Check D does not also fire.
# =====================================================================
info "=== FAILING: root-files-only registration (scripts/-shaped) ==="

CASE5B_DIR="$WORKDIR/case5b/root-files"
mkdir -p "$CASE5B_DIR"
cat > "$CASE5B_DIR/settings.json" << 'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/scripts/verify-deploy.sh" }
        ]
      }
    ]
  }
}
EOF

case5b_out="$(bash "$LINT_SCRIPT" "$CASE5B_DIR/settings.json" 2>&1)"
case5b_rc=$?
if [[ $case5b_rc -ne 0 ]] \
   && grep -q "verify-deploy.sh" <<< "$case5b_out" \
   && grep -q "absent from every fragment surface" <<< "$case5b_out" \
   && grep -q "agent-system/extensions/core/merge-sources/settings-hooks.json" <<< "$case5b_out"; then
  pass "scripts/-shaped root-files-only registration names both the script and the target fragment file"
else
  fail "scripts/-shaped root-files-only registration did not report as expected:
$case5b_out"
fi

# =====================================================================
# Case 6 (FAILING, criterion 12): registration invoking a source-store script that does not
# exist. Placed in a fragment-only surface so Check C (fragment coverage) does not also fire,
# isolating this assertion to Check D (existence).
# =====================================================================
info "=== FAILING: registration invoking a nonexistent source-store script ==="

CASE6_DIR="$WORKDIR/case6/merge-sources"
mkdir -p "$CASE6_DIR"
cat > "$CASE6_DIR/settings-hooks.json" << 'EOF'
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/zz-does-not-exist-case6.sh" }
        ]
      }
    ]
  }
}
EOF

case6_out="$(bash "$LINT_SCRIPT" "$CASE6_DIR/settings-hooks.json" 2>&1)"
case6_rc=$?
if [[ $case6_rc -ne 0 ]] \
   && grep -q "does not exist" <<< "$case6_out" \
   && grep -q "zz-does-not-exist-case6.sh" <<< "$case6_out"; then
  pass "nonexistent invoked script is flagged, naming file and line"
else
  fail "nonexistent invoked script was not flagged as expected:
$case6_out"
fi

# =====================================================================
# Case 7 (PASSING, criterion 7 / D3): explicit-cd direct invocation, planted verbatim as a `.sh`
# fixture. The lint must never scan `.sh` files at all (by scan scope, not by a classifier).
# =====================================================================
info "=== PASSING: explicit-cd direct invocation (.sh file, never scanned) ==="

CASE7_DIR="$WORKDIR/case7"
mkdir -p "$CASE7_DIR"
cat > "$CASE7_DIR/please-grant-shape.sh" << 'EOF'
#!/usr/bin/env bash
( cd "$repo" && jq -n --arg p "/please push origin feature-x" '{prompt:$p}' | bash .claude/hooks/please-grant.sh ) >/dev/null 2>&1
EOF

case7_out="$(bash "$LINT_SCRIPT" "$CASE7_DIR/please-grant-shape.sh" 2>&1)"
case7_rc=$?
if [[ $case7_rc -eq 0 ]]; then
  pass "explicit-cd direct invocation in a .sh file passes (scan-scope exclusion)"
else
  fail "explicit-cd direct invocation in a .sh file was unexpectedly flagged:
$case7_out"
fi

# =====================================================================
# Case 8 (PASSING, criterion 9): both-surfaces registration (present in root-files AND a
# fragment, same identity) -- the established fresh-install pattern, must pass.
# =====================================================================
info "=== PASSING: both-surfaces registration ==="

CASE8_DIR="$WORKDIR/case8"
mkdir -p "$CASE8_DIR/root-files" "$CASE8_DIR/merge-sources"
cat > "$CASE8_DIR/root-files/settings.json" << 'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/guard-destructive-git.sh" }
        ]
      }
    ]
  }
}
EOF
cat > "$CASE8_DIR/merge-sources/settings-hooks.json" << 'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/guard-destructive-git.sh" }
        ]
      }
    ]
  }
}
EOF

case8_out="$(bash "$LINT_SCRIPT" "$CASE8_DIR" 2>&1)"
case8_rc=$?
if [[ $case8_rc -eq 0 ]]; then
  pass "both-surfaces registration passes"
else
  fail "both-surfaces registration was unexpectedly flagged:
$case8_out"
fi

# =====================================================================
# Case 9 (PASSING, criterion 9): fragment-only registration (present in a fragment, absent from
# root-files) -- also correct, must pass.
# =====================================================================
info "=== PASSING: fragment-only registration ==="

CASE9_DIR="$WORKDIR/case9/merge-sources"
mkdir -p "$CASE9_DIR"
cat > "$CASE9_DIR/settings-hooks.json" << 'EOF'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/mail-guard.sh 2>/dev/null || echo '{}'" }
        ]
      }
    ]
  }
}
EOF

case9_out="$(bash "$LINT_SCRIPT" "$WORKDIR/case9" 2>&1)"
case9_rc=$?
if [[ $case9_rc -eq 0 ]]; then
  pass "fragment-only registration passes"
else
  fail "fragment-only registration was unexpectedly flagged:
$case9_out"
fi

# =====================================================================
# Case 10 (PASSING): a plain "$CLAUDE_PROJECT_DIR"-anchored registration, reported [OK] under
# --verbose.
# =====================================================================
info "=== PASSING: \"\$CLAUDE_PROJECT_DIR\"-anchored registration ==="

CASE10_DIR="$WORKDIR/case10/merge-sources"
mkdir -p "$CASE10_DIR"
cat > "$CASE10_DIR/settings-hooks.json" << 'EOF'
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/post-command.sh 2>/dev/null || echo '{}'" }
        ]
      }
    ]
  }
}
EOF

case10_out="$(bash "$LINT_SCRIPT" --verbose "$CASE10_DIR/settings-hooks.json" 2>&1)"
case10_rc=$?
if [[ $case10_rc -eq 0 ]] && grep -q '\[OK\].*post-command\.sh' <<< "$case10_out"; then
  pass "\$CLAUDE_PROJECT_DIR-anchored registration is accepted and reported [OK] under --verbose"
else
  fail "\$CLAUDE_PROJECT_DIR-anchored registration was not accepted as expected:
$case10_out"
fi

# =====================================================================
# Case 11 (PASSING, D1 + D2): a `~/`-anchored registration passes both the path-shape check and
# the existence check, even though the target script does not exist in the source store.
# =====================================================================
info "=== PASSING: ~/-anchored registration (D1 anchor, D2 existence exemption) ==="

CASE11_DIR="$WORKDIR/case11/merge-sources"
mkdir -p "$CASE11_DIR"
cat > "$CASE11_DIR/settings-hooks.json" << 'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "bash ~/.config/nvim/scripts/does-not-exist-anywhere.sh 2>/dev/null || echo '{}'" }
        ]
      }
    ]
  }
}
EOF

case11_out="$(bash "$LINT_SCRIPT" "$CASE11_DIR/settings-hooks.json" 2>&1)"
case11_rc=$?
if [[ $case11_rc -eq 0 ]]; then
  pass "tilde-prefixed (~/) anchored registration passes (accepted anchor, existence-check exempt)"
else
  fail "tilde-prefixed (~/) anchored registration was unexpectedly flagged:
$case11_out"
fi

# =====================================================================
# Case 12 (PASSING): a `bash -c` block that invokes no `*.sh` script at all (e.g. an inline
# permissionDecision echo) is not a registration and must never be flagged.
# =====================================================================
info "=== PASSING: bash -c block invoking no script at all ==="

CASE12_DIR="$WORKDIR/case12/merge-sources"
mkdir -p "$CASE12_DIR"
cat > "$CASE12_DIR/settings-hooks.json" << 'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          { "type": "command", "command": "bash -c 'echo \"{\\\"permissionDecision\\\": \\\"allow\\\"}\"'" }
        ]
      }
    ]
  }
}
EOF

case12_verbose_out="$(bash "$LINT_SCRIPT" --verbose "$CASE12_DIR/settings-hooks.json" 2>&1)"
case12_rc=$?
if [[ $case12_rc -eq 0 ]] && ! grep -qE '\[VIOLATION\]|\[OK\]|\[EXEMPT\]' <<< "$case12_verbose_out"; then
  pass "bash -c block with no script invocation passes and is never reported as a candidate"
else
  fail "bash -c block with no script invocation was unexpectedly reported:
$case12_verbose_out"
fi

# =====================================================================
# Case 13 (PASSING, demonstrated false-positive hazard): a `_comment` field quoting the correct
# form in PROSE must never be treated as a candidate, even under --verbose.
# =====================================================================
info "=== PASSING: _comment field quoting the correct form in prose ==="

CASE13_DIR="$WORKDIR/case13/root-files"
mkdir -p "$CASE13_DIR"
cat > "$CASE13_DIR/settings.json" << 'EOF'
{
  "_comment": "Hook commands must use bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/x.sh, never a CWD-relative .claude/ path.",
  "hooks": {}
}
EOF

case13_verbose_out="$(bash "$LINT_SCRIPT" --verbose "$CASE13_DIR/settings.json" 2>&1)"
case13_rc=$?
if [[ $case13_rc -eq 0 ]] && ! grep -qE '\[VIOLATION\]|\[OK\]|\[EXEMPT\]' <<< "$case13_verbose_out"; then
  pass "_comment field quoting the correct form in prose is never treated as a candidate"
else
  fail "_comment field was unexpectedly treated as a candidate:
$case13_verbose_out"
fi

# =====================================================================
# Case 14 (PASSING, demonstrated false-positive hazard): an mcpServers-scoped "command": "npx"
# is not a hook registration and must never be flagged.
# =====================================================================
info "=== PASSING: mcpServers-scoped \"command\": \"npx\" ==="

CASE14_DIR="$WORKDIR/case14"
mkdir -p "$CASE14_DIR"
cat > "$CASE14_DIR/settings-fragment.json" << 'EOF'
{
  "mcpServers": {
    "obsidian-memory": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/obsidian-claude-code-mcp@latest"]
    }
  }
}
EOF

case14_out="$(bash "$LINT_SCRIPT" --verbose "$CASE14_DIR/settings-fragment.json" 2>&1)"
case14_rc=$?
if [[ $case14_rc -eq 0 ]] && ! grep -q 'npx' <<< "$case14_out"; then
  pass "mcpServers \"command\": \"npx\" is never treated as a candidate"
else
  fail "mcpServers \"command\": \"npx\" was unexpectedly reported:
$case14_out"
fi

# =====================================================================
# Case 15 (PASSING, D6): a settings.local.json permission matcher carrying a relative path is
# out of scope entirely -- this lint never even opens the file, since its filename does not match
# any recognized settings-surface shape.
# =====================================================================
info "=== PASSING: settings.local.json permission matcher (D6, out of scope) ==="

CASE15_DIR="$WORKDIR/case15/root-files"
mkdir -p "$CASE15_DIR"
cat > "$CASE15_DIR/settings.local.json" << 'EOF'
{
  "permissions": {
    "allow": [
      "Bash(bash .claude/scripts/some-relative-thing.sh)"
    ]
  }
}
EOF

case15_out="$(bash "$LINT_SCRIPT" "$CASE15_DIR/settings.local.json" 2>&1)"
case15_rc=$?
if [[ $case15_rc -eq 0 ]]; then
  pass "settings.local.json permission matcher is out of scope and passes"
else
  fail "settings.local.json permission matcher was unexpectedly flagged:
$case15_out"
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
