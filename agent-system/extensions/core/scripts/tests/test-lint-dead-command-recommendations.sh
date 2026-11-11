#!/usr/bin/env bash
# test-lint-dead-command-recommendations.sh - Fixture-driven regression test for
# scripts/lint/lint-dead-command-recommendations.sh.
#
# Proves the lint fires on a planted offender, that a recommendation naming a REAL command is
# never flagged, and that the valid-command SET is derived by filesystem enumeration rather than
# hardcoded -- a fixture commands/ directory introduces a brand-new valid command with no edit to
# the lint itself. All fixtures are synthetic, written to a scratch directory; this suite never
# depends on the live tree being clean (that is a separate, whole-tree assertion covered by
# Phase 7's gate 24) and never mutates the repository.
#
# Structural model: test-lint-task-lookup-adoption.sh (mktemp -d workdir, deploy-tree-first /
# source-store-fallback candidate resolution, common_test_pass/_fail/_info helpers).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.
# Note this is a test OF a lint: its exit code reports test success, not lint success (the suite
# is green even while the real corpus is still red -- it asserts lint behavior on synthetic
# fixtures, not corpus cleanliness).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"
LINT_SCRIPT="$(common_test_resolve_subject "lint-dead-command-recommendations.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lint/lint-dead-command-recommendations.sh" \
  "$SCRIPT_DIR/../lint/lint-dead-command-recommendations.sh")" || exit 2
common_test_declare_subject "$LINT_SCRIPT"

PASSED=0
FAILED=0
common_test_workdir_init

# =====================================================================
# Case 1 (acceptance criterion): a synthetic file naming a command with no definition file ->
# lint fails, names the exact file:line.
# =====================================================================
common_test_info "=== acceptance criterion: deliberately-violating fixture ==="

CASE1_FIXTURE="$WORKDIR/case1-offender.md"
cat > "$CASE1_FIXTURE" << 'EOF'
# Synthetic fixture

Some prose above.
Next: /totally-fake-cmd-434 {N}
More prose below.
EOF

if bash "$LINT_SCRIPT" "$CASE1_FIXTURE" >"$WORKDIR/case1-out.txt" 2>&1; then
  common_test_fail "lint exited 0 for a recommendation naming an undefined command (expected non-zero)"
else
  common_test_pass "lint exited non-zero for a recommendation naming an undefined command"
fi

if grep -q "case1-offender.md:4" "$WORKDIR/case1-out.txt" && grep -q "totally-fake-cmd-434" "$WORKDIR/case1-out.txt"; then
  common_test_pass "lint names the exact violating file:line and command"
else
  common_test_fail "lint output did not name the violating file:line/command:
$(cat "$WORKDIR/case1-out.txt")"
fi

# =====================================================================
# Case 2 (negative control): the same recommendation shape naming a REAL command (/orchestrate)
# is not flagged -- proves enumeration, not just the regex, drives the verdict.
# =====================================================================
common_test_info "=== control case: a real command is never flagged ==="

CASE2_FIXTURE="$WORKDIR/case2-real-command.md"
cat > "$CASE2_FIXTURE" << 'EOF'
# Synthetic fixture

Next: /orchestrate {N}
EOF

if bash "$LINT_SCRIPT" "$CASE2_FIXTURE" >"$WORKDIR/case2-out.txt" 2>&1; then
  common_test_pass "lint exits 0 for a recommendation naming a real, defined command"
else
  common_test_fail "lint rejected a recommendation naming a real command (/orchestrate):
$(cat "$WORKDIR/case2-out.txt")"
fi

if grep -q "VIOLATION" "$WORKDIR/case2-out.txt"; then
  common_test_fail "lint flagged a real command as a violation:
$(cat "$WORKDIR/case2-out.txt")"
else
  common_test_pass "lint reports no violation for a real command"
fi

# =====================================================================
# Case 3 (self-updating behavior): a fixture commands/ directory introduces a brand-new valid
# command; a recommendation naming it is then NOT flagged, proving the valid-command set is
# derived by enumeration rather than hardcoded in the lint.
# =====================================================================
common_test_info "=== self-updating behavior: a fixture command makes its own name valid ==="

SELFUPDATE_DIR="$WORKDIR/selfupdate"
mkdir -p "$SELFUPDATE_DIR/commands"
cat > "$SELFUPDATE_DIR/commands/newcmd-434.md" << 'EOF'
# /newcmd-434

A synthetic command definition used only to prove enumeration-driven validity.
EOF
cat > "$SELFUPDATE_DIR/usage.md" << 'EOF'
# Usage

Next: Run /newcmd-434 {N} to proceed.
EOF

if bash "$LINT_SCRIPT" "$SELFUPDATE_DIR" >"$WORKDIR/selfupdate-out.txt" 2>&1; then
  common_test_pass "lint exits 0 once the fixture command directory makes the name valid"
else
  common_test_fail "lint still flagged a command defined by a fixture commands/ directory:
$(cat "$WORKDIR/selfupdate-out.txt")"
fi

if grep -q "VIOLATION" "$WORKDIR/selfupdate-out.txt"; then
  common_test_fail "lint flagged /newcmd-434 despite its fixture definition file:
$(cat "$WORKDIR/selfupdate-out.txt")"
else
  common_test_pass "lint reports no violation once the fixture command is enumerated"
fi

# =====================================================================
# Case 4 (shape coverage): both the JSON-value form and the bare-prose form are caught.
# =====================================================================
common_test_info "=== shape coverage: JSON-value form and bare-prose form ==="

CASE4_JSON="$WORKDIR/case4-shape.json"
cat > "$CASE4_JSON" << 'EOF'
{
  "next_steps": "Run /another-fake-cmd-434 to proceed"
}
EOF
CASE4_PROSE="$WORKDIR/case4-shape-prose.md"
cat > "$CASE4_PROSE" << 'EOF'
Run /another-fake-cmd-434 first.
EOF

if bash "$LINT_SCRIPT" "$CASE4_JSON" >"$WORKDIR/case4-json-out.txt" 2>&1; then
  common_test_fail "lint exited 0 for the JSON-value recommendation shape (expected non-zero)"
else
  common_test_pass "lint fires on the JSON-value recommendation shape"
fi
if grep -q "another-fake-cmd-434" "$WORKDIR/case4-json-out.txt"; then
  common_test_pass "lint names the command inside the JSON-value shape"
else
  common_test_fail "lint did not name the command inside the JSON-value shape:
$(cat "$WORKDIR/case4-json-out.txt")"
fi

if bash "$LINT_SCRIPT" "$CASE4_PROSE" >"$WORKDIR/case4-prose-out.txt" 2>&1; then
  common_test_fail "lint exited 0 for the bare-prose recommendation shape (expected non-zero)"
else
  common_test_pass "lint fires on the bare-prose recommendation shape"
fi
if grep -q "another-fake-cmd-434" "$WORKDIR/case4-prose-out.txt"; then
  common_test_pass "lint names the command inside the bare-prose shape"
else
  common_test_fail "lint did not name the command inside the bare-prose shape:
$(cat "$WORKDIR/case4-prose-out.txt")"
fi

# =====================================================================
# Case 5 (README exclusion): a recommendation naming /README IS flagged, proving
# commands/README.md is excluded from the valid-command set even when freshly created.
# =====================================================================
common_test_info "=== README exclusion: commands/README.md never becomes a valid command ==="

README_DIR="$WORKDIR/readmecase"
mkdir -p "$README_DIR/commands"
cat > "$README_DIR/commands/README.md" << 'EOF'
# Commands directory index (not a command)
EOF
cat > "$README_DIR/usage.md" << 'EOF'
Run /README {N} to see the format.
EOF

if bash "$LINT_SCRIPT" "$README_DIR" >"$WORKDIR/readme-out.txt" 2>&1; then
  common_test_fail "lint exited 0 for a recommendation naming /README (expected non-zero: README.md is excluded)"
else
  common_test_pass "lint flags a recommendation naming /README"
fi
if grep -q "/README has no definition file" "$WORKDIR/readme-out.txt"; then
  common_test_pass "lint confirms commands/README.md is excluded from the valid-command set"
else
  common_test_fail "lint did not confirm README exclusion:
$(cat "$WORKDIR/readme-out.txt")"
fi

# =====================================================================
# External-source-store fixture: a synthetic root holding a .claude-extensions.json whose
# core.source_dir resolves to THIS repository's own source store, and no local
# agent-system/extensions directory anywhere in the fixture tree. The lint script (plus its two
# sibling libraries) is COPIED into the fixture at the same relative depth
# (<root>/fakestore/scripts/lint/, libs at .../scripts/lib/) it occupies in the real tree, so
# common_repo_root's own fixed-depth candidate and the upward-walk fallback both land on <root>
# (which has no agent-system/extensions of its own) rather than on a path this fixture does not
# control. Exercises the DEFAULT_SCAN / valid-command-enumeration resolution path directly --
# every other case above passes an explicit path argument and never reaches it. The SOURCE-STORE
# copy is used deliberately here, regardless of what LINT_SCRIPT above resolved (it prefers
# deploy-tree-first): this fixture must exercise the logic as it is developed in the source
# store, never a possibly-stale deployed copy.
# =====================================================================
LINT_SCRIPT_STORE="$SCRIPT_DIR/../lint/lint-dead-command-recommendations.sh"
EXTSTORE_FIXTURE="$WORKDIR/extstore-lint"
mkdir -p "$EXTSTORE_FIXTURE/fakestore/scripts/lint" "$EXTSTORE_FIXTURE/fakestore/scripts/lib"
cp "$LINT_SCRIPT_STORE" "$EXTSTORE_FIXTURE/fakestore/scripts/lint/lint-dead-command-recommendations.sh"
cp "$SCRIPT_DIR/../lib/common.sh" "$SCRIPT_DIR/../lib/lint-corpus-scan-lib.sh" \
  "$EXTSTORE_FIXTURE/fakestore/scripts/lib/"
cat > "$EXTSTORE_FIXTURE/.claude-extensions.json" <<EOF
{"extensions":{"core":{"source_dir":"$REPO_ROOT/agent-system/extensions/core"}}}
EOF

EXTSTORE_OUTPUT="$(bash "$EXTSTORE_FIXTURE/fakestore/scripts/lint/lint-dead-command-recommendations.sh" 2>&1)"
EXTSTORE_EXIT=$?
if [[ "$EXTSTORE_EXIT" -ne 2 ]]; then
  common_test_pass "lint does not exit 2 (environment error) against the external-source-store fixture"
else
  common_test_fail "lint exited 2 (environment error) against the external-source-store fixture (output: $EXTSTORE_OUTPUT)"
fi
if grep -qE "^Files checked: [1-9]" <<< "$EXTSTORE_OUTPUT"; then
  common_test_pass "lint reports a non-empty file enumeration against the external-source-store fixture"
else
  common_test_fail "lint did not report a non-empty file enumeration against the external-source-store fixture (output: $EXTSTORE_OUTPUT)"
fi
if ! grep -q "valid-command enumeration yielded an empty set" <<< "$EXTSTORE_OUTPUT"; then
  common_test_pass "lint's valid-command enumeration is non-empty against the external-source-store fixture"
else
  common_test_fail "lint reported an empty valid-command enumeration against the external-source-store fixture (output: $EXTSTORE_OUTPUT)"
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
