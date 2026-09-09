#!/usr/bin/env bash
# test-lean-mcp-preflight-check.sh -- regression suite for lean-mcp-preflight-check.sh
#
# Proves -- by fixture, not by assertion -- that the wrapper:
#
#   (A) detects the observed drift shape (a lean-lsp `command` path resolving inside a
#       `.claude/` deploy tree that does not exist on disk) and emits an actionable,
#       setup-lean-mcp.sh-naming message, always exiting 0 (WARN, never BLOCK);
#   (B) is byte-silent on a correctly registered project;
#   (C) is byte-silent outside a Lean project;
#   (D) distinguishes the exit-2 (project-path mismatch) branch from the exit-1 branch with a
#       genuinely different message than fixture A's -- the anti-vacuous guard proving the
#       wrapper actually reads the verifier's exit code rather than emitting one blanket message
#       for every non-zero outcome;
#   (E) falls back to a generic setup-lean-mcp.sh-naming line when the underlying verifier's
#       output does not match the expected [FAIL]/[WARN]/Run setup-lean-mcp text shape.
#
# Every fixture points HOME at a per-fixture mktemp -d directory holding a synthetic
# .claude.json -- verify-lean-mcp.sh reads "$HOME/.claude.json" with no other override, so this
# needs no change to the verifier and never reads or asserts against the real ~/.claude.json.
# Each fixture repo carries its own .claude/scripts/verify-lean-mcp.sh (fixtures A-D: a copy of
# the real core verifier; fixture E: a stub) to reproduce the deployed shape the wrapper expects.
#
# Falsifiability / mutation check (recorded, not merely claimed): a mutated copy of the wrapper
# that unconditionally exits 0 immediately after invoking the verifier (bypassing all message
# synthesis) is run against fixtures A, D, and E and is asserted to now produce EMPTY output on
# each -- while B and C, which never reach that code path, are unaffected. This proves fixtures
# A, D, and E actually discriminate the fixed behavior from a silently-broken one, rather than
# passing vacuously regardless of what the wrapper does.
#
# Follows the core shell-test convention (context/standards/shell-script-testing.md; modeled on
# the sibling agent-system/extensions/lean/scripts/tests/test-lean-sorry-census.sh): Class B
# (`set -uo pipefail`, no `-e`) counter-idiom harness with pass()/fail()/info() helpers,
# PASSED/FAILED integer counters, a single mktemp -d workdir with a trap EXIT cleanup, exit 0 on
# all-pass and exit 1 on any-fail.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_SRC="$SCRIPT_DIR/../lean-mcp-preflight-check.sh"
VERIFIER_SRC="$SCRIPT_DIR/../../../core/scripts/verify-lean-mcp.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [ ! -f "$TOOL_SRC" ]; then
  echo "ERROR: expected lean-mcp-preflight-check.sh at $TOOL_SRC" >&2
  exit 1
fi

if [ ! -f "$VERIFIER_SRC" ]; then
  echo "ERROR: expected verify-lean-mcp.sh at $VERIFIER_SRC" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# make_lean_project DIR -- a git-inited Lean project directory (lakefile.lean marker).
make_lean_project() {
  local dir="$1"
  mkdir -p "$dir"
  (cd "$dir" && git init -q >/dev/null 2>&1)
  touch "$dir/lakefile.lean"
}

# deploy_real_verifier REPO -- copies the real core verifier into REPO's deployed path.
deploy_real_verifier() {
  local repo="$1"
  mkdir -p "$repo/.claude/scripts"
  cp "$VERIFIER_SRC" "$repo/.claude/scripts/verify-lean-mcp.sh"
  chmod +x "$repo/.claude/scripts/verify-lean-mcp.sh"
}

# deploy_stub_verifier REPO EXIT_CODE OUTPUT -- a fake verifier that ignores its config entirely
# and just prints OUTPUT (not matching [FAIL]/[WARN]/Run setup-lean-mcp) and exits EXIT_CODE.
deploy_stub_verifier() {
  local repo="$1" code="$2" text="$3"
  mkdir -p "$repo/.claude/scripts"
  cat > "$repo/.claude/scripts/verify-lean-mcp.sh" <<EOF
#!/usr/bin/env bash
echo "$text"
exit $code
EOF
  chmod +x "$repo/.claude/scripts/verify-lean-mcp.sh"
}

# write_claude_json HOME_DIR COMMAND ARGS_JSON PROJECT_PATH -- a synthetic ~/.claude.json with a
# single global lean-lsp mcpServers entry. ARGS_JSON is a raw JSON array literal.
write_claude_json() {
  local home="$1" command="$2" args_json="$3" project_path="$4"
  mkdir -p "$home"
  cat > "$home/.claude.json" <<EOF
{
  "mcpServers": {
    "lean-lsp": {
      "command": "$command",
      "args": $args_json,
      "env": { "LEAN_PROJECT_PATH": "$project_path" }
    }
  }
}
EOF
}

# run_wrapper TOOL REPO HOME -- runs TOOL from REPO with HOME set, writing combined
# stdout+stderr to stdout. Deliberately NOT invoked via command substitution's own subshell for
# the exit-code capture: `$()` discards a subshell's variable assignments, so the wrapper's own
# exit code is captured directly into the caller-visible $RUN_RC by running this in the current
# shell and reading $? immediately after, with output separately captured to a temp file.
run_wrapper() {
  local tool="$1" repo="$2" home="$3" outfile="$4"
  (cd "$repo" && HOME="$home" bash "$tool") > "$outfile" 2>&1
  RUN_RC=$?
}

# =====================================================================
# Fixture A -- the observed shape: command resolves inside a .claude/ deploy tree that does not
# exist on disk (Check 3 of the real verifier fires unconditionally on path shape).
# =====================================================================
REPO_A="$WORKDIR/fixture_a/repo"
HOME_A="$WORKDIR/fixture_a/home"
make_lean_project "$REPO_A"
deploy_real_verifier "$REPO_A"
write_claude_json "$HOME_A" "$REPO_A/.claude/scripts/lean-lsp-mcp-wrapper.sh" '[]' "$REPO_A"

OUTFILE_A="$WORKDIR/out_a.txt"
run_wrapper "$TOOL_SRC" "$REPO_A" "$HOME_A" "$OUTFILE_A"
RC_A="$RUN_RC"
OUT_A="$(cat "$OUTFILE_A")"

if [ "$RC_A" -eq 0 ] && [ -n "$OUT_A" ] && echo "$OUT_A" | grep -q "setup-lean-mcp.sh"; then
  pass "Fixture A (drifted command inside .claude/ tree): wrapper exit 0, non-empty output naming setup-lean-mcp.sh"
else
  fail "Fixture A: expected exit 0 and output naming setup-lean-mcp.sh; got rc=$RC_A output:
$OUT_A"
fi

# =====================================================================
# Fixture B -- correct registration: byte-empty output.
# =====================================================================
REPO_B="$WORKDIR/fixture_b/repo"
HOME_B="$WORKDIR/fixture_b/home"
make_lean_project "$REPO_B"
deploy_real_verifier "$REPO_B"
write_claude_json "$HOME_B" "uvx" '["lean-lsp-mcp"]' "$REPO_B"

OUTFILE_B="$WORKDIR/out_b.txt"
run_wrapper "$TOOL_SRC" "$REPO_B" "$HOME_B" "$OUTFILE_B"
RC_B="$RUN_RC"
OUT_B="$(cat "$OUTFILE_B")"

if [ "$RC_B" -eq 0 ] && [ -z "$OUT_B" ]; then
  pass "Fixture B (correct registration): wrapper exit 0, byte-empty output"
else
  fail "Fixture B: expected exit 0 and empty output; got rc=$RC_B output:
$OUT_B"
fi

# =====================================================================
# Fixture C -- not a Lean project: no lakefile at CWD or git root. Byte-empty output.
# =====================================================================
REPO_C="$WORKDIR/fixture_c/repo"
HOME_C="$WORKDIR/fixture_c/home"
mkdir -p "$REPO_C"
(cd "$REPO_C" && git init -q >/dev/null 2>&1)
mkdir -p "$HOME_C"

OUTFILE_C="$WORKDIR/out_c.txt"
run_wrapper "$TOOL_SRC" "$REPO_C" "$HOME_C" "$OUTFILE_C"
RC_C="$RUN_RC"
OUT_C="$(cat "$OUTFILE_C")"

if [ "$RC_C" -eq 0 ] && [ -z "$OUT_C" ]; then
  pass "Fixture C (non-Lean repository): wrapper exit 0, byte-empty output"
else
  fail "Fixture C: expected exit 0 and empty output; got rc=$RC_C output:
$OUT_C"
fi

# =====================================================================
# Fixture D -- project-path mismatch (the real verifier's sole exit-2 path): otherwise-correct
# entry whose LEAN_PROJECT_PATH points at a different, existing Lean fixture directory.
# =====================================================================
REPO_D="$WORKDIR/fixture_d/repo"
OTHER_D="$WORKDIR/fixture_d/other"
HOME_D="$WORKDIR/fixture_d/home"
make_lean_project "$REPO_D"
make_lean_project "$OTHER_D"
deploy_real_verifier "$REPO_D"
write_claude_json "$HOME_D" "uvx" '["lean-lsp-mcp"]' "$OTHER_D"

OUTFILE_D="$WORKDIR/out_d.txt"
run_wrapper "$TOOL_SRC" "$REPO_D" "$HOME_D" "$OUTFILE_D"
RC_D="$RUN_RC"
OUT_D="$(cat "$OUTFILE_D")"

if [ "$RC_D" -eq 0 ] && [ -n "$OUT_D" ] && echo "$OUT_D" | grep -q "setup-lean-mcp.sh"; then
  pass "Fixture D (project-path mismatch): wrapper exit 0, non-empty output naming setup-lean-mcp.sh"
else
  fail "Fixture D: expected exit 0 and output naming setup-lean-mcp.sh; got rc=$RC_D output:
$OUT_D"
fi

if [ "$OUT_D" != "$OUT_A" ]; then
  pass "Fixture D message differs from Fixture A's (exit-2 vs exit-1 branches are genuinely distinct)"
else
  fail "Fixture D: output is identical to Fixture A's -- wrapper is not distinguishing rc=2 from rc=1"
fi

# =====================================================================
# Fixture E -- fallback path: a stub verifier exits 1 with output matching none of
# [FAIL]/[WARN]/Run setup-lean-mcp. The generic fallback line must still fire.
# =====================================================================
REPO_E="$WORKDIR/fixture_e/repo"
HOME_E="$WORKDIR/fixture_e/home"
make_lean_project "$REPO_E"
deploy_stub_verifier "$REPO_E" 1 "something broke unrelated to the expected text shape"
mkdir -p "$HOME_E"

OUTFILE_E="$WORKDIR/out_e.txt"
run_wrapper "$TOOL_SRC" "$REPO_E" "$HOME_E" "$OUTFILE_E"
RC_E="$RUN_RC"
OUT_E="$(cat "$OUTFILE_E")"

if [ "$RC_E" -eq 0 ] && [ -n "$OUT_E" ] && echo "$OUT_E" | grep -q "setup-lean-mcp.sh"; then
  pass "Fixture E (fallback path): wrapper exit 0, generic fallback line names setup-lean-mcp.sh"
else
  fail "Fixture E: expected exit 0 and fallback output naming setup-lean-mcp.sh; got rc=$RC_E output:
$OUT_E"
fi

# =====================================================================
# Mutation check (falsifiability gate): a mutated copy of the wrapper that unconditionally exits
# 0 immediately after invoking the verifier -- bypassing all message synthesis -- must produce
# EMPTY output on fixtures A, D, and E (which previously required non-empty output), while B and
# C (which exit before reaching that code path) remain unaffected.
# =====================================================================
MUTATED_TOOL="$WORKDIR/mutated-lean-mcp-preflight-check.sh"
# Single quotes are deliberate: this is a literal sed pattern that must match
# $VERIFIER/rc/$? verbatim in lean-mcp-preflight-check.sh's own source text, not a shell
# expansion in this test script.
# shellcheck disable=SC2016
sed '/output="\$("\$VERIFIER" 2>&1)" || rc=\$?/a\    exit 0  # MUTATION: neutralized failure branch (test-only)' \
  "$TOOL_SRC" > "$MUTATED_TOOL"
chmod +x "$MUTATED_TOOL"

if ! grep -q "MUTATION: neutralized failure branch" "$MUTATED_TOOL"; then
  fail "Mutation setup: sed insertion did not find the expected anchor line in $TOOL_SRC -- mutation check did not run"
else
  run_wrapper "$MUTATED_TOOL" "$REPO_A" "$HOME_A" "$WORKDIR/mut_out_a.txt"
  MUT_OUT_A="$(cat "$WORKDIR/mut_out_a.txt")"
  run_wrapper "$MUTATED_TOOL" "$REPO_D" "$HOME_D" "$WORKDIR/mut_out_d.txt"
  MUT_OUT_D="$(cat "$WORKDIR/mut_out_d.txt")"
  run_wrapper "$MUTATED_TOOL" "$REPO_E" "$HOME_E" "$WORKDIR/mut_out_e.txt"
  MUT_OUT_E="$(cat "$WORKDIR/mut_out_e.txt")"
  run_wrapper "$MUTATED_TOOL" "$REPO_B" "$HOME_B" "$WORKDIR/mut_out_b.txt"
  MUT_OUT_B="$(cat "$WORKDIR/mut_out_b.txt")"
  run_wrapper "$MUTATED_TOOL" "$REPO_C" "$HOME_C" "$WORKDIR/mut_out_c.txt"
  MUT_OUT_C="$(cat "$WORKDIR/mut_out_c.txt")"

  if [ -z "$MUT_OUT_A" ] && [ -z "$MUT_OUT_D" ] && [ -z "$MUT_OUT_E" ]; then
    pass "Mutation check: neutralized wrapper produces EMPTY output on fixtures A, D, E (were non-empty pre-mutation) -- fixtures are discriminative, not vacuous"
  else
    fail "Mutation check: expected fixtures A, D, E to go silent under the neutralized wrapper; got A='$MUT_OUT_A' D='$MUT_OUT_D' E='$MUT_OUT_E'"
  fi

  if [ -z "$MUT_OUT_B" ] && [ -z "$MUT_OUT_C" ]; then
    pass "Mutation check: fixtures B and C remain empty under the neutralized wrapper (unaffected, as expected -- they exit before the mutated line)"
  else
    fail "Mutation check: expected fixtures B, C to remain empty; got B='$MUT_OUT_B' C='$MUT_OUT_C'"
  fi
fi

# =====================================================================
# Summary
# =====================================================================

info "Passed: $PASSED, Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
