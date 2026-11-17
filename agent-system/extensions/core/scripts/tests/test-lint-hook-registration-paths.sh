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
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"
LINT_SCRIPT="$(common_test_resolve_subject "lint-hook-registration-paths.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lint/lint-hook-registration-paths.sh" \
  "$SCRIPT_DIR/../lint/lint-hook-registration-paths.sh")" || exit 2
common_test_declare_subject "$LINT_SCRIPT"

PASSED=0
FAILED=0
common_test_workdir_init

# =====================================================================
# Case 1 (FAILING, criterion 1): direct CWD-relative `.claude/` registration.
# =====================================================================
common_test_info "=== FAILING: direct .claude/-relative registration ==="

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
  common_test_pass "direct .claude/-relative registration exits non-zero"
else
  common_test_fail "direct .claude/-relative registration exited 0 (expected non-zero):
$case1_out"
fi
if grep -q '\[VIOLATION\].*zz-case1\.sh' <<< "$case1_out"; then
  common_test_pass "direct .claude/-relative violation names the offending registration"
else
  common_test_fail "direct .claude/-relative violation not reported as expected:
$case1_out"
fi

# =====================================================================
# Case 2 (FAILING, criterion 1): CWD-relative path nested inside a `bash -c '...'` wrapper.
# =====================================================================
common_test_info "=== FAILING: CWD-relative path nested inside bash -c wrapper ==="

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
  common_test_pass "bash -c nested CWD-relative invocation is flagged"
else
  common_test_fail "bash -c nested CWD-relative invocation was not flagged:
$case2_out"
fi

# =====================================================================
# Case 3 (FAILING, criterion 11): relative path containing NO `.claude/` at all (the "line-118"
# shape) -- the regression net against re-anchoring the rule on `.claude/` or `hooks/`.
# =====================================================================
common_test_info "=== FAILING: relative path with no .claude/ at all (line-118 shape) ==="

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
  common_test_pass "relative path with no .claude/ at all is flagged (criterion 11)"
else
  common_test_fail "line-118-shaped relative path (no .claude/, no hooks/) was not flagged:
$case3_out"
fi

# =====================================================================
# Case 4 (FAILING, criterion 6): defective registration template inside a fenced JSON block in
# markdown.
# =====================================================================
common_test_info "=== FAILING: defective registration template in fenced markdown JSON ==="

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
  common_test_pass "defective markdown registration template is flagged, naming file and line"
else
  common_test_fail "defective markdown fenced-JSON registration template was not flagged:
$case4_out"
fi

# =====================================================================
# Case 5a (FAILING, criteria 8/9): root-files-only registration, hooks/-shaped, naming both the
# hook script and the fragment file it belongs in. Uses a REAL, existing hook script name
# (guard-destructive-git.sh) so Check D (existence) does not also fire, keeping this assertion
# isolated to the fragment-coverage check.
# =====================================================================
common_test_info "=== FAILING: root-files-only registration (hooks/-shaped) ==="

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
  common_test_pass "hooks/-shaped root-files-only registration names both the hook script and the target fragment file"
else
  common_test_fail "hooks/-shaped root-files-only registration did not report as expected:
$case5a_out"
fi
if ! grep -q "does not exist" <<< "$case5a_out"; then
  common_test_pass "hooks/-shaped root-files-only case does not spuriously trip the existence check (real script)"
else
  common_test_fail "hooks/-shaped root-files-only case unexpectedly tripped the existence check:
$case5a_out"
fi

# =====================================================================
# Case 5b (FAILING, criteria 8/9): root-files-only registration, scripts/-shaped (not hooks/-
# shaped) -- proves the identity notion is not narrowed to hooks/ only. Uses a REAL, existing
# script (verify-deploy.sh) so Check D does not also fire.
# =====================================================================
common_test_info "=== FAILING: root-files-only registration (scripts/-shaped) ==="

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
  common_test_pass "scripts/-shaped root-files-only registration names both the script and the target fragment file"
else
  common_test_fail "scripts/-shaped root-files-only registration did not report as expected:
$case5b_out"
fi

# =====================================================================
# Case 6 (FAILING, criterion 12): registration invoking a source-store script that does not
# exist. Placed in a fragment-only surface so Check C (fragment coverage) does not also fire,
# isolating this assertion to Check D (existence).
# =====================================================================
common_test_info "=== FAILING: registration invoking a nonexistent source-store script ==="

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
  common_test_pass "nonexistent invoked script is flagged, naming file and line"
else
  common_test_fail "nonexistent invoked script was not flagged as expected:
$case6_out"
fi

# =====================================================================
# Case 7 (PASSING, criterion 7 / D3): explicit-cd direct invocation, planted verbatim as a `.sh`
# fixture. The lint must never scan `.sh` files at all (by scan scope, not by a classifier).
# =====================================================================
common_test_info "=== PASSING: explicit-cd direct invocation (.sh file, never scanned) ==="

CASE7_DIR="$WORKDIR/case7"
mkdir -p "$CASE7_DIR"
cat > "$CASE7_DIR/please-grant-shape.sh" << 'EOF'
#!/usr/bin/env bash
( cd "$repo" && jq -n --arg p "/please push origin feature-x" '{prompt:$p}' | bash .claude/hooks/please-grant.sh ) >/dev/null 2>&1
EOF

case7_out="$(bash "$LINT_SCRIPT" "$CASE7_DIR/please-grant-shape.sh" 2>&1)"
case7_rc=$?
if [[ $case7_rc -eq 0 ]]; then
  common_test_pass "explicit-cd direct invocation in a .sh file passes (scan-scope exclusion)"
else
  common_test_fail "explicit-cd direct invocation in a .sh file was unexpectedly flagged:
$case7_out"
fi

# =====================================================================
# Case 8 (PASSING, criterion 9): both-surfaces registration (present in root-files AND a
# fragment, same identity) -- the established fresh-install pattern, must pass.
# =====================================================================
common_test_info "=== PASSING: both-surfaces registration ==="

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
  common_test_pass "both-surfaces registration passes"
else
  common_test_fail "both-surfaces registration was unexpectedly flagged:
$case8_out"
fi

# =====================================================================
# Case 9 (PASSING, criterion 9): fragment-only registration (present in a fragment, absent from
# root-files) -- also correct, must pass.
# =====================================================================
common_test_info "=== PASSING: fragment-only registration ==="

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
  common_test_pass "fragment-only registration passes"
else
  common_test_fail "fragment-only registration was unexpectedly flagged:
$case9_out"
fi

# =====================================================================
# Case 10 (PASSING): a plain "$CLAUDE_PROJECT_DIR"-anchored registration, reported [OK] under
# --verbose.
# =====================================================================
common_test_info "=== PASSING: \"\$CLAUDE_PROJECT_DIR\"-anchored registration ==="

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
  common_test_pass "\$CLAUDE_PROJECT_DIR-anchored registration is accepted and reported [OK] under --verbose"
else
  common_test_fail "\$CLAUDE_PROJECT_DIR-anchored registration was not accepted as expected:
$case10_out"
fi

# =====================================================================
# Case 11 (PASSING, D1 + D2): a `~/`-anchored registration passes both the path-shape check and
# the existence check, even though the target script does not exist in the source store.
# =====================================================================
common_test_info "=== PASSING: ~/-anchored registration (D1 anchor, D2 existence exemption) ==="

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
  common_test_pass "tilde-prefixed (~/) anchored registration passes (accepted anchor, existence-check exempt)"
else
  common_test_fail "tilde-prefixed (~/) anchored registration was unexpectedly flagged:
$case11_out"
fi

# =====================================================================
# Case 12 (PASSING): a `bash -c` block that invokes no `*.sh` script at all (e.g. an inline
# permissionDecision echo) is not a registration and must never be flagged.
# =====================================================================
common_test_info "=== PASSING: bash -c block invoking no script at all ==="

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
  common_test_pass "bash -c block with no script invocation passes and is never reported as a candidate"
else
  common_test_fail "bash -c block with no script invocation was unexpectedly reported:
$case12_verbose_out"
fi

# =====================================================================
# Case 13 (PASSING, demonstrated false-positive hazard): a `_comment` field quoting the correct
# form in PROSE must never be treated as a candidate, even under --verbose.
# =====================================================================
common_test_info "=== PASSING: _comment field quoting the correct form in prose ==="

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
  common_test_pass "_comment field quoting the correct form in prose is never treated as a candidate"
else
  common_test_fail "_comment field was unexpectedly treated as a candidate:
$case13_verbose_out"
fi

# =====================================================================
# Case 14 (PASSING, demonstrated false-positive hazard): an mcpServers-scoped "command": "npx"
# is not a hook registration and must never be flagged.
# =====================================================================
common_test_info "=== PASSING: mcpServers-scoped \"command\": \"npx\" ==="

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
  common_test_pass "mcpServers \"command\": \"npx\" is never treated as a candidate"
else
  common_test_fail "mcpServers \"command\": \"npx\" was unexpectedly reported:
$case14_out"
fi

# =====================================================================
# Case 15 (PASSING, D6): a settings.local.json permission matcher carrying a relative path is
# out of scope entirely -- this lint never even opens the file, since its filename does not match
# any recognized settings-surface shape.
# =====================================================================
common_test_info "=== PASSING: settings.local.json permission matcher (D6, out of scope) ==="

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
  common_test_pass "settings.local.json permission matcher is out of scope and passes"
else
  common_test_fail "settings.local.json permission matcher was unexpectedly flagged:
$case15_out"
fi

# =====================================================================
# Case 16 (acceptance criterion 3): agreement on a path OUTSIDE hooks/. Registers a
# scripts/-shaped (not hooks/-shaped) command in root-files only (a real, existing script, so
# Check D's existence check does not also fire), and asserts the lint's own reported identity
# for this registration equals hook_identity.lua's direct output for the SAME command -- the
# single shared definition, exercised from both call sites.
# =====================================================================
common_test_info "=== PASSING (acceptance criterion 3): identity agreement outside hooks/ ==="

CASE16_DIR="$WORKDIR/case16/root-files"
mkdir -p "$CASE16_DIR"
CASE16_CMD='bash .claude/scripts/verify-deploy.sh'
cat > "$CASE16_DIR/settings.json" << EOF
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "case16",
        "hooks": [
          { "type": "command", "command": "$CASE16_CMD" }
        ]
      }
    ]
  }
}
EOF

case16_out="$(bash "$LINT_SCRIPT" "$CASE16_DIR/settings.json" 2>&1)"
case16_lint_identity="$(grep -oE 'identity: [^)]+' <<< "$case16_out" | sed 's/^identity: //')"

HOOK_IDENTITY_CLI_MODULE="$REPO_ROOT/lua/neotex/plugins/ai/shared/extensions/hook_identity_cli.lua"
case16_module_identity="$(printf 'command\t%s\n' "$CASE16_CMD" | nvim --headless --noplugin -u NONE -l "$HOOK_IDENTITY_CLI_MODULE" 2>/dev/null)"

if [[ -n "$case16_lint_identity" ]] \
   && [[ "$case16_lint_identity" == "$case16_module_identity" ]] \
   && [[ "$case16_lint_identity" == "command:scripts/verify-deploy.sh" ]]; then
  common_test_pass "lint-reported identity for a scripts/-shaped (outside hooks/) registration equals hook_identity.lua's own direct output"
else
  common_test_fail "identity agreement outside hooks/ did not hold: lint='$case16_lint_identity' module='$case16_module_identity'
$case16_out"
fi

# =====================================================================
# Case 17 (acceptance criterion 3, ~/-ineligibility on both sides): a ~/-anchored command is
# identity-ineligible (nil/empty) both through the lint's bridge-based resolution (it passes,
# per case 11 above) and through hook_identity.lua's own direct output for the same command.
# =====================================================================
common_test_info "=== PASSING: ~/-anchored command is identity-ineligible on both sides ==="

CASE17_CMD='bash ~/.config/nvim/scripts/claude-ready-signal.sh 2>/dev/null || echo '"'"'{}'"'"''
case17_module_identity="$(printf 'command\t%s\n' "$CASE17_CMD" | nvim --headless --noplugin -u NONE -l "$HOOK_IDENTITY_CLI_MODULE" 2>/dev/null)"

if [[ -z "$case17_module_identity" ]]; then
  # shellcheck disable=SC2088  # Deliberate literal-text mention of "~/" in a human-readable
  # message, not a path meant to be tilde-expanded.
  common_test_pass "~/-anchored command resolves to no identity via hook_identity.lua directly (matches the lint's own existence-exempt, non-flagging treatment in case 11)"
else
  # shellcheck disable=SC2088  # Same deliberate literal-text mention as above.
  common_test_fail "~/-anchored command unexpectedly resolved to an identity: '$case17_module_identity'"
fi

# =====================================================================
# Case 18: a bridge failure (missing/broken bridge file) is FATAL -- a named error and a
# non-zero exit, never a silent fall-back to a second identity notion. Exercised via
# HOOK_IDENTITY_CLI_OVERRIDE so the real bridge file is never touched.
# =====================================================================
common_test_info "=== FAILING (bridge failure): missing hook identity bridge is fatal, loudly ==="

CASE18_DIR="$WORKDIR/case18/root-files"
mkdir -p "$CASE18_DIR"
cat > "$CASE18_DIR/settings.json" << 'EOF'
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/zz-case18.sh" }
        ]
      }
    ]
  }
}
EOF

case18_out="$(HOOK_IDENTITY_CLI_OVERRIDE="$WORKDIR/case18/does-not-exist.lua" bash "$LINT_SCRIPT" "$CASE18_DIR/settings.json" 2>&1)"
case18_rc=$?
if [[ $case18_rc -eq 2 ]] \
   && grep -qi "ERROR.*hook identity bridge" <<< "$case18_out"; then
  common_test_pass "missing hook identity bridge is a loud, fatal (exit 2) error"
else
  common_test_fail "missing hook identity bridge did not fail loudly as expected (rc=$case18_rc):
$case18_out"
fi

# =====================================================================
# Case 19 (FAILING, acceptance criterion 1, shape (a)): a faithful copy of a real drifted
# deploy. ModelBuilder's `~/Projects/ModelBuilder/.claude/settings.json` as measured live on
# 2026-11-17 (specs/527_hook_registration_set_lint_assertion/records/01_live-drift-baseline.md)
# carries three undeclared identities (`wezterm-notify.sh` under `Stop|*`, `tts-notify.sh` under
# `Stop|*`, `wezterm-clear-status.sh` under `UserPromptSubmit|*`) plus a fourth undeclared triple
# (`tts-notify.sh` under the WIDER `Notification|permission_prompt|idle_prompt|elicitation_dialog`
# matcher -- the source declares it only under the narrower `permission_prompt|elicitation_dialog`).
# All four are shape (a): each script is present on this deploy target's own filesystem (planted
# below), so Check E's shape-(a)/(c) split must report them undeclared-but-present, never
# undeclared-and-absent.
# =====================================================================
common_test_info "=== FAILING (acceptance criterion 1, shape (a)): ModelBuilder live-drift exemplar ==="

CASE19_DIR="$WORKDIR/case19/deployed"
mkdir -p "$CASE19_DIR/hooks"
cat > "$CASE19_DIR/settings.json" << 'EOF'
{
  "permissions": {
    "allow": [
      "Bash(git:*)",
      "Bash(lake *)",
      "Bash(pdflatex *)",
      "Bash(latexmk *)",
      "Bash(bibtex *)",
      "Bash(biber *)",
      "Bash(cd *)",
      "Bash(ls *)",
      "Bash(mkdir *)",
      "Bash(cp *)",
      "Bash(mv *)",
      "Bash(chmod +x *)",
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep",
      "WebSearch",
      "WebFetch",
      "Task",
      "TodoWrite",
      "mcp__lean-lsp__*"
    ],
    "deny": [
      "Bash(rm -rf /)",
      "Bash(rm -rf ~)",
      "Bash(sudo *)",
      "Bash(chmod 777 *)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".file_path // empty\" 2>/dev/null); if [[ \"$FILE\" == *\"state.json\"* ]]; then echo \"{\\\"permissionDecision\\\": \\\"allow\\\", \\\"permissionDecisionReason\\\": \\\"State file write\\\"}\"; else echo \"{\\\"permissionDecision\\\": \\\"allow\\\"}\"; fi'"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".file_path // empty\" 2>/dev/null); if [[ \"$FILE\" == *\"specs/state.json\"* ]]; then bash .claude/hooks/validate-state-sync.sh 2>/dev/null || echo \"{}\"; else echo \"{}\"; fi'"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/wezterm-clear-task-number.sh 2>/dev/null || echo '{}'"
          }
        ]
      },
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/log-session.sh 2>/dev/null || echo '{}'"
          },
          {
            "type": "command",
            "command": "bash ~/.config/nvim/scripts/claude-ready-signal.sh 2>/dev/null || echo '{}'"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/post-command.sh 2>/dev/null || echo '{}'"
          },
          {
            "type": "command",
            "command": "bash .claude/hooks/tts-notify.sh 2>/dev/null || echo '{}'"
          },
          {
            "type": "command",
            "command": "bash .claude/hooks/wezterm-notify.sh 2>/dev/null || echo '{}'"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/wezterm-task-number.sh 2>/dev/null || echo '{}'"
          },
          {
            "type": "command",
            "command": "bash .claude/hooks/wezterm-clear-status.sh 2>/dev/null || echo '{}'"
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/subagent-postflight.sh 2>/dev/null || echo '{}'",
            "timeout": 30000
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt|idle_prompt|elicitation_dialog",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/tts-notify.sh 2>/dev/null || echo '{}'"
          }
        ]
      }
    ]
  }
}
EOF
for h in post-command.sh tts-notify.sh wezterm-notify.sh wezterm-clear-task-number.sh \
         log-session.sh wezterm-task-number.sh wezterm-clear-status.sh subagent-postflight.sh; do
  touch "$CASE19_DIR/hooks/$h"
done

case19_out="$(bash "$LINT_SCRIPT" --deployed-settings "$CASE19_DIR/settings.json" 2>&1)"
case19_rc=$?
if [[ $case19_rc -ne 0 ]] \
   && grep -q "deployed registration 'wezterm-notify.sh'.*is not declared by any source surface" <<< "$case19_out" \
   && grep -qc "is not declared by any source surface" <<< "$case19_out"; then
  common_test_pass "ModelBuilder live-drift exemplar: shape (a) finding text reported, non-zero exit"
else
  common_test_fail "ModelBuilder live-drift exemplar did not report shape (a) as expected (rc=$case19_rc):
$case19_out"
fi
if ! grep -q "is undeclared AND its script is absent" <<< "$case19_out" \
   && ! grep -q "registered under multiple matchers" <<< "$case19_out"; then
  common_test_pass "ModelBuilder exemplar reports ONLY shape (a) -- no incidental shape (b)/(c) noise"
else
  common_test_fail "ModelBuilder exemplar unexpectedly also reported shape (b) or (c):
$case19_out"
fi

# =====================================================================
# Case 20 (FAILING, acceptance criterion 1, shape (b)): no live shape-(b) instance survives in
# the fleet as of the Phase 1 measurement (specs/527_hook_registration_set_lint_assertion/records/
# 01_live-drift-baseline.md), so this is the plan's one documented reconstruction: a verbatim copy
# of Logos/Theory's real, clean `.claude/settings.json`, with ONE minimal mutation -- a second
# `Notification` matcher block registering `tts-notify.sh` under
# `permission_prompt|idle_prompt|elicitation_dialog` alongside the real
# `permission_prompt|elicitation_dialog` block -- reproducing the exact matcher pair the
# orphan-sweep record archived at
# specs/archive/369_orphan_sweep_for_removed_merge_target_entries/records/01_baseline-measurements.md
# states verbatim (lines 70-71: "Notification|permission_prompt|idle_prompt|elicitation_dialog ->
# tts-notify.sh ... the cross-matcher case -- source now declares tts-notify.sh only under the
# narrower permission_prompt|elicitation_dialog").
# =====================================================================
common_test_info "=== FAILING (acceptance criterion 1, shape (b)): reconstructed duplicate-matcher exemplar ==="

CASE20_DIR="$WORKDIR/case20/deployed"
mkdir -p "$CASE20_DIR/hooks"
cat > "$CASE20_DIR/settings.json" << 'EOF'
{
  "permissions": {
    "deny": [
      "Bash(rm -rf /)",
      "Bash(rm -rf ~)",
      "Bash(sudo *)",
      "Bash(chmod 777 *)"
    ],
    "allow": [
      "Bash(git:*)",
      "Bash(lake *)",
      "Bash(pdflatex *)",
      "Bash(latexmk *)",
      "Bash(bibtex *)",
      "Bash(biber *)",
      "Bash(cd *)",
      "Bash(ls *)",
      "Bash(mkdir *)",
      "Bash(cp *)",
      "Bash(mv *)",
      "Bash(chmod +x *)",
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep",
      "WebSearch",
      "WebFetch",
      "Task",
      "TodoWrite",
      "mcp__lean-lsp__*"
    ]
  },
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/post-command.sh 2>/dev/null || echo '{}'"
          },
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/claude-stop-notify.sh 2>/dev/null || echo '{}'"
          },
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/memory-nudge.sh 2>/dev/null || echo '{}'"
          },
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/events-log-lifecycle.sh 2>/dev/null || echo '{}'"
          }
        ],
        "matcher": "*"
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/tts-notify.sh 2>/dev/null || echo '{}'"
          }
        ],
        "matcher": "permission_prompt|elicitation_dialog"
      },
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/tts-notify.sh 2>/dev/null || echo '{}'"
          }
        ],
        "matcher": "permission_prompt|idle_prompt|elicitation_dialog"
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "command": "bash ~/.config/nvim/scripts/claude-ready-signal.sh 2>/dev/null || echo '{}'",
            "type": "command"
          },
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/log-session.sh 2>/dev/null || echo '{}'"
          }
        ],
        "matcher": "startup"
      },
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/wezterm-clear-task-number.sh 2>/dev/null || echo '{}'"
          }
        ],
        "matcher": "*"
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "timeout": 30000,
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/subagent-postflight.sh 2>/dev/null || echo '{}'"
          },
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/events-log-lifecycle.sh 2>/dev/null || echo '{}'"
          }
        ],
        "matcher": "*"
      }
    ],
    "PreToolUse": [
      {
        "hooks": [
          {
            "command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".file_path // empty\" 2>/dev/null); if [[ \"$FILE\" == *\"state.json\"* ]]; then echo \"{\\\"permissionDecision\\\": \\\"allow\\\", \\\"permissionDecisionReason\\\": \\\"State file write\\\"}\"; else echo \"{\\\"permissionDecision\\\": \\\"allow\\\"}\"; fi'",
            "type": "command"
          }
        ],
        "matcher": "Write"
      },
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-no-task-references.sh"
          },
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-no-record-versioning.sh"
          }
        ],
        "matcher": "Write|Edit"
      },
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/guard-destructive-git.sh"
          },
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-bounded-waiter.sh"
          },
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-task-creation-audit.sh"
          },
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-no-python-state-write.sh"
          }
        ],
        "matcher": "Bash"
      },
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/guard-git-push.sh"
          }
        ],
        "matcher": "Bash|Write|Edit"
      }
    ],
    "PostToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".file_path // empty\" 2>/dev/null); if [[ \"$FILE\" == *\"specs/state.json\"* ]]; then bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-state-sync.sh 2>/dev/null || echo \"{}\"; else echo \"{}\"; fi'"
          }
        ],
        "matcher": "Write"
      },
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-handoff-location.sh"
          },
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-meta-write.sh 2>/dev/null || echo '{}'"
          },
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-plan-write.sh 2>/dev/null || echo '{}'"
          },
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/events-log-artifact.sh 2>/dev/null || echo '{}'"
          }
        ],
        "matcher": "Write|Edit"
      },
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/detect-noop-bash.sh 2>/dev/null || echo '{}'"
          },
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/record-stash-provenance.sh 2>/dev/null || echo '{}'"
          }
        ],
        "matcher": "Bash"
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/wezterm-task-number.sh 2>/dev/null || echo '{}'"
          },
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/wezterm-preflight-status.sh 2>/dev/null || echo '{}'"
          },
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/please-grant.sh"
          }
        ],
        "matcher": "*"
      }
    ]
  }
}
EOF
touch "$CASE20_DIR/hooks/tts-notify.sh"

case20_out="$(bash "$LINT_SCRIPT" --deployed-settings "$CASE20_DIR/settings.json" 2>&1)"
case20_rc=$?
if [[ $case20_rc -ne 0 ]] \
   && grep -q "is registered under multiple matchers for event 'Notification'" <<< "$case20_out"; then
  common_test_pass "reconstructed duplicate-matcher exemplar: shape (b) finding text reported, non-zero exit"
else
  common_test_fail "reconstructed duplicate-matcher exemplar did not report shape (b) as expected (rc=$case20_rc):
$case20_out"
fi
if grep -q "permission_prompt|elicitation_dialog, permission_prompt|idle_prompt|elicitation_dialog" <<< "$case20_out"; then
  common_test_pass "shape (b) finding names both distinct matcher strings"
else
  common_test_fail "shape (b) finding did not name both distinct matchers:
$case20_out"
fi

# =====================================================================
# Case 21 (FAILING, acceptance criterion 1, shape (c)): a faithful copy of a real drifted deploy.
# SPSDemo's `~/Projects/SPSDemo/.claude/settings.json` as measured live on 2026-11-17 carries the
# orphan-sweep-record-cited `scripts/claude-ready-signal.sh` orphan under `SessionStart|startup`,
# undeclared by any source surface AND absent from this deploy target's own filesystem (the
# companion `hooks/` directory below plants SPSDemo's other real hook scripts present, with the
# cited one deliberately never created at `scripts/claude-ready-signal.sh`).
# =====================================================================
common_test_info "=== FAILING (acceptance criterion 1, shape (c)): SPSDemo live-drift exemplar ==="

CASE21_DIR="$WORKDIR/case21/deployed"
mkdir -p "$CASE21_DIR/hooks"
cat > "$CASE21_DIR/settings.json" << 'EOF'
{
  "env": {
    "SLASH_COMMAND_TOOL_CHAR_BUDGET": "50000"
  },
  "permissions": {
    "deny": [
      "Bash(rm -rf /)",
      "Bash(rm -rf ~)",
      "Bash(sudo *)",
      "Bash(chmod 777 *)"
    ],
    "allow": [
      "Bash(git:*)",
      "Bash(lake *)",
      "Bash(pdflatex *)",
      "Bash(latexmk *)",
      "Bash(bibtex *)",
      "Bash(biber *)",
      "Bash(cd *)",
      "Bash(ls *)",
      "Bash(mkdir *)",
      "Bash(cp *)",
      "Bash(mv *)",
      "Bash(chmod +x *)",
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep",
      "WebSearch",
      "WebFetch",
      "Task",
      "TaskCreate",
      "TaskUpdate",
      "Skill"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          {
            "command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".file_path // empty\" 2>/dev/null); if [[ \"$FILE\" == *\"state.json\"* ]]; then echo \"{\\\"permissionDecision\\\": \\\"allow\\\", \\\"permissionDecisionReason\\\": \\\"State file write\\\"}\"; else echo \"{\\\"permissionDecision\\\": \\\"allow\\\"}\"; fi'",
            "type": "command"
          }
        ],
        "matcher": "Write"
      },
      {
        "hooks": [
          {
            "command": "bash .claude/hooks/guard-destructive-git.sh",
            "type": "command"
          }
        ],
        "matcher": "Bash"
      },
      {
        "hooks": [
          {
            "command": "bash .claude/hooks/validate-no-task-references.sh",
            "type": "command"
          }
        ],
        "matcher": "Write|Edit"
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "command": "bash .claude/hooks/wezterm-clear-task-number.sh 2>/dev/null || echo '{}'",
            "type": "command"
          }
        ],
        "matcher": "*"
      },
      {
        "hooks": [
          {
            "command": "bash .claude/hooks/log-session.sh 2>/dev/null || echo '{}'",
            "type": "command"
          },
          {
            "command": "bash scripts/claude-ready-signal.sh 2>/dev/null || echo '{}'",
            "type": "command"
          }
        ],
        "matcher": "startup"
      }
    ],
    "PostToolUse": [
      {
        "hooks": [
          {
            "command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".file_path // empty\" 2>/dev/null); if [[ \"$FILE\" == *\"specs/state.json\"* ]]; then bash .claude/hooks/validate-state-sync.sh 2>/dev/null || echo \"{}\"; else echo \"{}\"; fi'",
            "type": "command"
          }
        ],
        "matcher": "Write"
      },
      {
        "hooks": [
          {
            "command": "bash .claude/hooks/validate-plan-write.sh 2>/dev/null || echo '{}'",
            "type": "command"
          },
          {
            "command": "bash .claude/hooks/events-log-artifact.sh 2>/dev/null || echo '{}'",
            "type": "command"
          },
          {
            "command": "bash .claude/hooks/validate-handoff-location.sh",
            "type": "command"
          },
          {
            "command": "bash .claude/hooks/validate-meta-write.sh 2>/dev/null || echo '{}'",
            "type": "command"
          }
        ],
        "matcher": "Write|Edit"
      },
      {
        "hooks": [
          {
            "command": "bash .claude/hooks/detect-noop-bash.sh 2>/dev/null || echo '{}'",
            "type": "command"
          }
        ],
        "matcher": "Bash"
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "command": "bash .claude/hooks/wezterm-task-number.sh 2>/dev/null || echo '{}'",
            "type": "command"
          },
          {
            "command": "bash .claude/hooks/wezterm-preflight-status.sh 2>/dev/null || echo '{}'",
            "type": "command"
          }
        ],
        "matcher": "*"
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "command": "bash .claude/hooks/subagent-postflight.sh 2>/dev/null || echo '{}'",
            "timeout": 30000,
            "type": "command"
          },
          {
            "command": "bash .claude/hooks/events-log-lifecycle.sh 2>/dev/null || echo '{}'",
            "type": "command"
          }
        ],
        "matcher": "*"
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "command": "bash .claude/hooks/tts-notify.sh 2>/dev/null || echo '{}'",
            "type": "command"
          }
        ],
        "matcher": "permission_prompt|elicitation_dialog"
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "command": "bash .claude/hooks/post-command.sh 2>/dev/null || echo '{}'",
            "type": "command"
          },
          {
            "command": "bash .claude/hooks/claude-stop-notify.sh 2>/dev/null || echo '{}'",
            "type": "command"
          },
          {
            "command": "bash .claude/hooks/memory-nudge.sh 2>/dev/null || echo '{}'",
            "type": "command"
          },
          {
            "command": "bash .claude/hooks/events-log-lifecycle.sh 2>/dev/null || echo '{}'",
            "type": "command"
          }
        ],
        "matcher": "*"
      }
    ]
  }
}
EOF
for h in claude-stop-notify.sh detect-noop-bash.sh events-log-artifact.sh events-log-lifecycle.sh \
         guard-destructive-git.sh lean-lsp-register-project.sh log-session.sh memory-nudge.sh \
         post-command.sh subagent-postflight.sh tts-notify.sh validate-handoff-location.sh \
         validate-meta-write.sh validate-no-task-references.sh validate-plan-write.sh \
         validate-state-sync.sh wezterm-clear-task-number.sh wezterm-notify.sh \
         wezterm-preflight-status.sh wezterm-task-number.sh; do
  touch "$CASE21_DIR/hooks/$h"
done
# Deliberately NEVER create scripts/claude-ready-signal.sh -- that absence is the point of this
# exemplar.

case21_out="$(bash "$LINT_SCRIPT" --deployed-settings "$CASE21_DIR/settings.json" 2>&1)"
case21_rc=$?
if [[ $case21_rc -ne 0 ]] \
   && grep -q "undeclared AND its script is absent from this deploy target" <<< "$case21_out" \
   && grep -q "claude-ready-signal.sh" <<< "$case21_out"; then
  common_test_pass "SPSDemo live-drift exemplar: shape (c) finding text reported, non-zero exit"
else
  common_test_fail "SPSDemo live-drift exemplar did not report shape (c) as expected (rc=$case21_rc):
$case21_out"
fi
if ! grep -q "is not declared by any source surface" <<< "$case21_out" \
   && ! grep -q "registered under multiple matchers" <<< "$case21_out"; then
  common_test_pass "SPSDemo exemplar reports ONLY shape (c) -- no incidental shape (a)/(b) noise"
else
  common_test_fail "SPSDemo exemplar unexpectedly also reported shape (a) or (b):
$case21_out"
fi

# =====================================================================
# Case 22 (PASSING, acceptance criterion 2): a hand-written custom hook command -- not
# recognizable as a source-store hook invocation at all (no `*.sh` registration, nil identity) --
# survives Check E with ZERO findings. A lint that reports a user's own hook registration as
# drift is worse than no lint.
# =====================================================================
common_test_info "=== PASSING (acceptance criterion 2): hand-written custom hook survives Check E ==="

CASE22_DIR="$WORKDIR/case22"
mkdir -p "$CASE22_DIR/empty-scan" "$CASE22_DIR/deployed"
cat > "$CASE22_DIR/deployed/settings.json" << 'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'my own custom notification' >> /tmp/my-own-log.txt"
          }
        ]
      }
    ]
  }
}
EOF

case22_out="$(bash "$LINT_SCRIPT" --deployed-settings "$CASE22_DIR/deployed/settings.json" "$CASE22_DIR/empty-scan" 2>&1)"
case22_rc=$?
if [[ $case22_rc -eq 0 ]] && grep -q "Total violations: 0" <<< "$case22_out"; then
  common_test_pass "hand-written custom hook command produces zero Check E findings"
else
  common_test_fail "hand-written custom hook command unexpectedly produced a finding (rc=$case22_rc):
$case22_out"
fi

# =====================================================================
# Case 23 (PASSING, acceptance criterion 3): copies of deployed settings.json files from repos
# the Phase 1 record (specs/527_hook_registration_set_lint_assertion/records/
# 01_live-drift-baseline.md) measured clean on 2026-11-17 -- `~/Projects/protocol` (23a) and
# `~/Projects/theorem_proving_in_lean4` (23b) -- each produce zero findings against the real
# source declared set.
# =====================================================================
common_test_info "=== PASSING (acceptance criterion 3): measured-clean-repo exemplars produce zero findings ==="

CASE23A_DIR="$WORKDIR/case23a/deployed"
mkdir -p "$CASE23A_DIR"
cat > "$CASE23A_DIR/settings.json" << 'EOF'
{
  "permissions": {
    "allow": [
      "Bash(git:*)",
      "Bash(lake *)",
      "Bash(pdflatex *)",
      "Bash(latexmk *)",
      "Bash(bibtex *)",
      "Bash(biber *)",
      "Bash(cd *)",
      "Bash(ls *)",
      "Bash(mkdir *)",
      "Bash(cp *)",
      "Bash(mv *)",
      "Bash(chmod +x *)",
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep",
      "WebSearch",
      "WebFetch",
      "Task",
      "TodoWrite",
      "mcp__lean-lsp__*"
    ],
    "deny": [
      "Bash(rm -rf /)",
      "Bash(rm -rf ~)",
      "Bash(sudo *)",
      "Bash(chmod 777 *)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".file_path // empty\" 2>/dev/null); if [[ \"$FILE\" == *\"state.json\"* ]]; then echo \"{\\\"permissionDecision\\\": \\\"allow\\\", \\\"permissionDecisionReason\\\": \\\"State file write\\\"}\"; else echo \"{\\\"permissionDecision\\\": \\\"allow\\\"}\"; fi'"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".file_path // empty\" 2>/dev/null); if [[ \"$FILE\" == *\"specs/state.json\"* ]]; then bash .claude/hooks/validate-state-sync.sh 2>/dev/null || echo \"{}\"; else echo \"{}\"; fi'"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/log-session.sh 2>/dev/null || echo '{}'"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/post-command.sh 2>/dev/null || echo '{}'"
          }
        ]
      }
    ]
  },
  "model": "claude-opus-4-5-20251101"
}
EOF

case23a_out="$(bash "$LINT_SCRIPT" --deployed-settings "$CASE23A_DIR/settings.json" 2>&1)"
case23a_rc=$?
if [[ $case23a_rc -eq 0 ]] && grep -q "Total violations: 0" <<< "$case23a_out"; then
  common_test_pass "protocol measured-clean exemplar produces zero findings"
else
  common_test_fail "protocol measured-clean exemplar unexpectedly produced a finding (rc=$case23a_rc):
$case23a_out"
fi

CASE23B_DIR="$WORKDIR/case23b/deployed"
mkdir -p "$CASE23B_DIR"
cat > "$CASE23B_DIR/settings.json" << 'EOF'
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/wezterm-task-number.sh 2>/dev/null || echo '{}'",
            "type": "command"
          },
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/wezterm-preflight-status.sh 2>/dev/null || echo '{}'",
            "type": "command"
          },
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/please-grant.sh",
            "type": "command"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt|elicitation_dialog",
        "hooks": [
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/tts-notify.sh 2>/dev/null || echo '{}'",
            "type": "command"
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/subagent-postflight.sh 2>/dev/null || echo '{}'",
            "type": "command",
            "timeout": 30000
          },
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/events-log-lifecycle.sh 2>/dev/null || echo '{}'",
            "type": "command"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/post-command.sh 2>/dev/null || echo '{}'",
            "type": "command"
          },
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/claude-stop-notify.sh 2>/dev/null || echo '{}'",
            "type": "command"
          },
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/memory-nudge.sh 2>/dev/null || echo '{}'",
            "type": "command"
          },
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/events-log-lifecycle.sh 2>/dev/null || echo '{}'",
            "type": "command"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".file_path // empty\" 2>/dev/null); if [[ \"$FILE\" == *\"specs/state.json\"* ]]; then bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-state-sync.sh 2>/dev/null || echo \"{}\"; else echo \"{}\"; fi'",
            "type": "command"
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-handoff-location.sh",
            "type": "command"
          },
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-meta-write.sh 2>/dev/null || echo '{}'",
            "type": "command"
          },
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-plan-write.sh 2>/dev/null || echo '{}'",
            "type": "command"
          },
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/events-log-artifact.sh 2>/dev/null || echo '{}'",
            "type": "command"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/detect-noop-bash.sh 2>/dev/null || echo '{}'",
            "type": "command"
          },
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/record-stash-provenance.sh 2>/dev/null || echo '{}'",
            "type": "command"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".file_path // empty\" 2>/dev/null); if [[ \"$FILE\" == *\"state.json\"* ]]; then echo \"{\\\"permissionDecision\\\": \\\"allow\\\", \\\"permissionDecisionReason\\\": \\\"State file write\\\"}\"; else echo \"{\\\"permissionDecision\\\": \\\"allow\\\"}\"; fi'",
            "type": "command"
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-no-task-references.sh",
            "type": "command"
          },
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-no-record-versioning.sh",
            "type": "command"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/guard-destructive-git.sh",
            "type": "command"
          },
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-bounded-waiter.sh",
            "type": "command"
          },
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-task-creation-audit.sh",
            "type": "command"
          },
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-no-python-state-write.sh",
            "type": "command"
          }
        ]
      },
      {
        "matcher": "Bash|Write|Edit",
        "hooks": [
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/guard-git-push.sh",
            "type": "command"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/wezterm-clear-task-number.sh 2>/dev/null || echo '{}'",
            "type": "command"
          }
        ]
      },
      {
        "matcher": "startup",
        "hooks": [
          {
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/log-session.sh 2>/dev/null || echo '{}'",
            "type": "command"
          }
        ]
      }
    ]
  },
  "env": {
    "SLASH_COMMAND_TOOL_CHAR_BUDGET": "50000"
  },
  "permissions": {
    "allow": [
      "Bash(git:*)",
      "Bash(lake *)",
      "Bash(pdflatex *)",
      "Bash(latexmk *)",
      "Bash(bibtex *)",
      "Bash(biber *)",
      "Bash(cd *)",
      "Bash(ls *)",
      "Bash(mkdir *)",
      "Bash(cp *)",
      "Bash(mv *)",
      "Bash(chmod +x *)",
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep",
      "WebSearch",
      "WebFetch",
      "Task",
      "TaskCreate",
      "TaskUpdate",
      "Skill",
      "mcp__lean-lsp__*"
    ],
    "deny": [
      "Bash(rm -rf /)",
      "Bash(rm -rf ~)",
      "Bash(sudo *)",
      "Bash(chmod 777 *)"
    ]
  }
}
EOF

case23b_out="$(bash "$LINT_SCRIPT" --deployed-settings "$CASE23B_DIR/settings.json" 2>&1)"
case23b_rc=$?
if [[ $case23b_rc -eq 0 ]] && grep -q "Total violations: 0" <<< "$case23b_out"; then
  common_test_pass "theorem_proving_in_lean4 measured-clean exemplar produces zero findings"
else
  common_test_fail "theorem_proving_in_lean4 measured-clean exemplar unexpectedly produced a finding (rc=$case23b_rc):
$case23b_out"
fi

# =====================================================================
# Case 24 (acceptance criterion 4): Check E's own identity resolution for a registration whose
# path lies OUTSIDE hooks/ agrees with hook_identity.lua's direct output for the same command --
# asserting Check E specifically (the existing Case 16 asserts this agreement for Checks C/D
# only). Reuses the `scripts/claude-ready-signal.sh` CWD-relative command, undeclared and (in
# this minimal fixture, with no companion scripts/ directory) absent -- shape (c) -- whose
# finding text quotes the resolved identity directly.
# =====================================================================
common_test_info "=== PASSING (acceptance criterion 4): Check E identity agreement outside hooks/ ==="

CASE24_DIR="$WORKDIR/case24"
mkdir -p "$CASE24_DIR/empty-scan" "$CASE24_DIR/deployed"
CASE24_CMD='bash scripts/claude-ready-signal.sh 2>/dev/null || echo '"'"'{}'"'"''
cat > "$CASE24_DIR/deployed/settings.json" << EOF
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          { "type": "command", "command": "$CASE24_CMD" }
        ]
      }
    ]
  }
}
EOF

case24_out="$(bash "$LINT_SCRIPT" --deployed-settings "$CASE24_DIR/deployed/settings.json" "$CASE24_DIR/empty-scan" 2>&1)"
case24_lint_identity="$(grep -oE 'identity: [^)]+' <<< "$case24_out" | sed 's/^identity: //')"
case24_module_identity="$(printf 'command\t%s\n' "$CASE24_CMD" | nvim --headless --noplugin -u NONE -l "$HOOK_IDENTITY_CLI_MODULE" 2>/dev/null)"

if [[ -n "$case24_lint_identity" ]] \
   && [[ "$case24_lint_identity" == "$case24_module_identity" ]] \
   && [[ "$case24_lint_identity" == "command:scripts/claude-ready-signal.sh" ]]; then
  common_test_pass "Check E's reported identity for a scripts/-shaped (outside hooks/) deployed registration equals hook_identity.lua's own direct output"
else
  common_test_fail "Check E identity agreement outside hooks/ did not hold: lint='$case24_lint_identity' module='$case24_module_identity'
$case24_out"
fi

# =====================================================================
# Case 25 (PASSING): a `--deployed-settings PATH` naming a file that does not exist degrades to
# zero Check E findings and exit 0, never exit 2 -- mirroring every other check's missing-surface
# degrade in this script.
# =====================================================================
common_test_info "=== PASSING: missing --deployed-settings file degrades to zero findings ==="

CASE25_DIR="$WORKDIR/case25"
mkdir -p "$CASE25_DIR/empty-scan"

case25_out="$(bash "$LINT_SCRIPT" --deployed-settings "$CASE25_DIR/does-not-exist.json" "$CASE25_DIR/empty-scan" 2>&1)"
case25_rc=$?
if [[ $case25_rc -eq 0 ]] && grep -q "Total violations: 0" <<< "$case25_out"; then
  common_test_pass "missing --deployed-settings file degrades to zero findings and exit 0"
else
  common_test_fail "missing --deployed-settings file did not degrade as expected (rc=$case25_rc):
$case25_out"
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
