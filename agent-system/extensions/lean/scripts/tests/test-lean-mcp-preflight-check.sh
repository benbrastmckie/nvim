#!/usr/bin/env bash
# test-lean-mcp-preflight-check.sh -- regression suite for lean-mcp-preflight-check.sh AND (as of
# the per-project registration model) the underlying verify-lean-mcp.sh checks it wraps.
#
# Proves -- by fixture, not by assertion -- that the wrapper:
#
#   (A) detects the observed drift shape (a lean-lsp `command` path resolving inside a
#       `.claude/` deploy tree that does not exist on disk) and emits an actionable,
#       setup-lean-mcp.sh-naming message, always exiting 0 (WARN, never BLOCK);
#   (B) is byte-silent on a correctly registered project (project-scoped entry, no global);
#   (C) is byte-silent outside a Lean project;
#   (D) distinguishes the exit-2 (project-path mismatch) branch from the exit-1 branch with a
#       genuinely different message than fixture A's -- the anti-vacuous guard proving the
#       wrapper actually reads the verifier's exit code rather than emitting one blanket message
#       for every non-zero outcome;
#   (E) falls back to a generic setup-lean-mcp.sh-naming line when the underlying verifier's
#       output does not match the expected [FAIL]/[WARN]/Run setup-lean-mcp text shape;
#   (F) resolves TWO concurrently-registered Lean projects each to their OWN LEAN_PROJECT_PATH
#       -- the case a single-global-entry model cannot pass;
#   (G) treats a second, unregistered working directory of an already-registered repository as
#       independently unregistered (no accidental inheritance/collision), then confirms BOTH
#       resolve correctly once both are registered;
#   (H) the inverted Check 9: a surviving top-level global entry is drift EVEN when this
#       project's own project-scoped entry is otherwise perfectly correct;
#   (I) a Lean project with NO project-scoped entry at all (the common, day-one-of-a-worktree
#       case) gets the exit-1 "not registered for this project" branch.
#
# Every fixture points HOME at a per-fixture mktemp -d directory holding a synthetic
# .claude.json -- verify-lean-mcp.sh reads "$HOME/.claude.json" with no other override, so this
# needs no change to the verifier and never reads or asserts against the real ~/.claude.json.
# Each fixture repo carries its own .claude/scripts/verify-lean-mcp.sh (fixtures A, B, D, F, G,
# H, I: a copy of the real lean-extension verifier; fixture E: a stub) to reproduce the deployed
# shape the wrapper expects.
#
# Falsifiability / mutation check (recorded, not merely claimed): TWO independent mutations,
# each targeting a DIFFERENT specific check the new per-project fixtures depend on:
#
#   MUTATION 1 (wrapper-level, pre-existing): a mutated copy of lean-mcp-preflight-check.sh that
#   unconditionally exits 0 immediately after invoking the verifier (bypassing all message
#   synthesis) is run against fixtures A, D, E, H, and I, and is asserted to now produce EMPTY
#   output on each -- while B, C, F, and G (which either never reach that code path, or expect
#   empty output already) are unaffected.
#
#   MUTATION 2 (verifier-level, new): a mutated copy of verify-lean-mcp.sh with Check 9 (the
#   inverted surviving-global-entry check) deleted is run, via the UNMUTATED wrapper, against
#   fixture H (correct project entry + surviving global entry). Pre-mutation, fixture H's
#   verifier exits non-zero (drift). Post-mutation it is asserted to exit 0 (Check 9's absence
#   makes the surviving global entry invisible) -- proving fixture H actually exercises Check 9,
#   not some other, coincidentally-overlapping failure path. Fixture F (two correctly-registered
#   projects, neither with a global entry) is asserted UNAFFECTED by this same mutation, since it
#   never reaches Check 9's fail branch either way -- the targeted control.
#
# Fixtures F and G's "should PASS" assertions are inherently non-vacuous by construction rather
# than by an artificial mutation: they assert that DIFFERENT project paths resolve to DIFFERING
# LEAN_PROJECT_PATH values, so a hypothetical shared-state bug (e.g. always answering with the
# first-registered project regardless of which directory is queried) would make the "these two
# values differ" assertion itself fail, with no mutation needed to expose it.
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

# verify-lean-mcp.sh now lives in the lean extension itself (agent-system/extensions/lean/scripts/,
# relocated from core/scripts/ so registration lives alongside the other lean-specific per-project
# mechanism), so it is a sibling one level up from this suite in BOTH layouts: the source store
# (scripts/tests/../) and a deployed consumer repo (every extension's scripts/ flattens into a
# single .claude/scripts/, so it is still scripts/tests/../). A single candidate now suffices
# where a source-store-vs-deployed dual-candidate probe was previously required -- see
# utility-scripts-inventory.md's lean-mcp-preflight-check.sh entry.
VERIFIER_SRC=""
for candidate in \
  "$SCRIPT_DIR/../verify-lean-mcp.sh"; do
  if [ -f "$candidate" ]; then
    VERIFIER_SRC="$candidate"
    break
  fi
done

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [ ! -f "$TOOL_SRC" ]; then
  echo "ERROR: expected lean-mcp-preflight-check.sh at $TOOL_SRC" >&2
  exit 1
fi

if [ -z "$VERIFIER_SRC" ]; then
  echo "ERROR: expected verify-lean-mcp.sh at $SCRIPT_DIR/../verify-lean-mcp.sh" >&2
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

# deploy_real_verifier REPO -- copies the real lean-extension verifier into REPO's deployed path.
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

# write_project_claude_json HOME_DIR REPO_KEY_PATH COMMAND ARGS_JSON LEAN_PROJECT_PATH -- a
# synthetic ~/.claude.json with a single PROJECT-SCOPED lean-lsp entry under
# .projects[REPO_KEY_PATH].mcpServers."lean-lsp". ARGS_JSON is a raw JSON array literal.
# REPO_KEY_PATH and LEAN_PROJECT_PATH are deliberately separate parameters: fixture D needs them
# to differ (the entry is filed under the querying repo's path but its own env value names a
# different project) while every other fixture passes the same value for both.
write_project_claude_json() {
  local home="$1" repo_key="$2" command="$3" args_json="$4" lean_project_path="$5"
  mkdir -p "$home"
  jq -n \
    --arg repo_key "$repo_key" \
    --arg command "$command" \
    --argjson args "$args_json" \
    --arg lean_project_path "$lean_project_path" \
    '{"projects": {($repo_key): {"mcpServers": {"lean-lsp": {"command": $command, "args": $args, "env": {"LEAN_PROJECT_PATH": $lean_project_path}}}}}}' \
    > "$home/.claude.json"
}

# add_global_claude_json_entry HOME_DIR COMMAND ARGS_JSON LEAN_PROJECT_PATH -- merges a top-level
# GLOBAL lean-lsp entry into an EXISTING $home/.claude.json (used to construct the Check-9
# surviving-global-entry fixture on top of an already-correct project-scoped one).
add_global_claude_json_entry() {
  local home="$1" command="$2" args_json="$3" lean_project_path="$4"
  local tmp
  tmp=$(mktemp "${home}/.claude.json.tmp.XXXXXXXXXX")
  jq \
    --arg command "$command" \
    --argjson args "$args_json" \
    --arg lean_project_path "$lean_project_path" \
    '.mcpServers."lean-lsp" = {"command": $command, "args": $args, "env": {"LEAN_PROJECT_PATH": $lean_project_path}}' \
    "$home/.claude.json" > "$tmp"
  mv "$tmp" "$home/.claude.json"
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

# run_verifier_direct VERIFIER REPO HOME -- runs VERIFIER (the real or a mutated verifier)
# directly (not through the wrapper) from REPO with HOME set. Used by fixtures that need the
# verifier's own exit code (0/1/2), not the wrapper's always-0 exit code.
run_verifier_direct() {
  local verifier="$1" repo="$2" home="$3" outfile="$4"
  (cd "$repo" && HOME="$home" bash "$verifier") > "$outfile" 2>&1
  RUN_RC=$?
}

CANON_ARGS='["lean-lsp-mcp"]'

# =====================================================================
# Fixture A -- the observed shape: command resolves inside a .claude/ deploy tree that does not
# exist on disk (Check 3 of the real verifier fires unconditionally on path shape). Rewritten to
# the per-project model: the bad entry is now PROJECT-SCOPED (a global-only entry is no longer
# "configured" at all under the new model -- see fixture I).
# =====================================================================
REPO_A="$WORKDIR/fixture_a/repo"
HOME_A="$WORKDIR/fixture_a/home"
make_lean_project "$REPO_A"
deploy_real_verifier "$REPO_A"
write_project_claude_json "$HOME_A" "$REPO_A" "$REPO_A/.claude/scripts/lean-lsp-mcp-wrapper.sh" '[]' "$REPO_A"

OUTFILE_A="$WORKDIR/out_a.txt"
run_wrapper "$TOOL_SRC" "$REPO_A" "$HOME_A" "$OUTFILE_A"
RC_A="$RUN_RC"
OUT_A="$(cat "$OUTFILE_A")"

if [ "$RC_A" -eq 0 ] && [ -n "$OUT_A" ] && echo "$OUT_A" | grep -q "setup-lean-mcp.sh"; then
  pass "Fixture A (drifted command inside .claude/ tree, project-scoped): wrapper exit 0, non-empty output naming setup-lean-mcp.sh"
else
  fail "Fixture A: expected exit 0 and output naming setup-lean-mcp.sh; got rc=$RC_A output:
$OUT_A"
fi

# =====================================================================
# Fixture B -- correct registration: a correct PROJECT-scoped entry, NO global entry. Byte-empty
# output. This is also the PASS direction of the inverted Check 9 (see fixture H for the FAIL
# direction).
# =====================================================================
REPO_B="$WORKDIR/fixture_b/repo"
HOME_B="$WORKDIR/fixture_b/home"
make_lean_project "$REPO_B"
deploy_real_verifier "$REPO_B"
write_project_claude_json "$HOME_B" "$REPO_B" "uvx" "$CANON_ARGS" "$REPO_B"

OUTFILE_B="$WORKDIR/out_b.txt"
run_wrapper "$TOOL_SRC" "$REPO_B" "$HOME_B" "$OUTFILE_B"
RC_B="$RUN_RC"
OUT_B="$(cat "$OUTFILE_B")"

if [ "$RC_B" -eq 0 ] && [ -z "$OUT_B" ]; then
  pass "Fixture B (correct project-scoped registration, no global entry -- Check 9 PASS direction): wrapper exit 0, byte-empty output"
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
# Fixture D -- project-path mismatch (the real verifier's sole exit-2 path): a project-scoped
# entry, filed under REPO_D's own key, whose inner LEAN_PROJECT_PATH points at a different,
# existing Lean fixture directory.
# =====================================================================
REPO_D="$WORKDIR/fixture_d/repo"
OTHER_D="$WORKDIR/fixture_d/other"
HOME_D="$WORKDIR/fixture_d/home"
make_lean_project "$REPO_D"
make_lean_project "$OTHER_D"
deploy_real_verifier "$REPO_D"
write_project_claude_json "$HOME_D" "$REPO_D" "uvx" "$CANON_ARGS" "$OTHER_D"

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
# Fixture F -- concurrent multi-project: TWO Lean projects registered in the SAME ~/.claude.json
# at once, each queried from its own directory, each expected to resolve to its OWN
# LEAN_PROJECT_PATH. This is the case a single-global-entry model cannot pass (only one project
# could ever hold the global slot at a time).
# =====================================================================
REPO_F1="$WORKDIR/fixture_f/repo1"
REPO_F2="$WORKDIR/fixture_f/repo2"
HOME_F="$WORKDIR/fixture_f/home"
make_lean_project "$REPO_F1"
make_lean_project "$REPO_F2"
deploy_real_verifier "$REPO_F1"
deploy_real_verifier "$REPO_F2"
write_project_claude_json "$HOME_F" "$REPO_F1" "uvx" "$CANON_ARGS" "$REPO_F1"
# Merge REPO_F2's entry into the SAME home/.claude.json alongside REPO_F1's (write_project_claude_json
# would overwrite the whole file, so merge by hand here).
TMP_F=$(mktemp "${HOME_F}/.claude.json.tmp.XXXXXXXXXX")
jq --arg key "$REPO_F2" --arg path "$REPO_F2" \
  '.projects[$key] = {"mcpServers": {"lean-lsp": {"command": "uvx", "args": ["lean-lsp-mcp"], "env": {"LEAN_PROJECT_PATH": $path}}}}' \
  "$HOME_F/.claude.json" > "$TMP_F"
mv "$TMP_F" "$HOME_F/.claude.json"

OUTFILE_F1="$WORKDIR/out_f1.txt"
OUTFILE_F2="$WORKDIR/out_f2.txt"
run_wrapper "$TOOL_SRC" "$REPO_F1" "$HOME_F" "$OUTFILE_F1"
RC_F1="$RUN_RC"
run_wrapper "$TOOL_SRC" "$REPO_F2" "$HOME_F" "$OUTFILE_F2"
RC_F2="$RUN_RC"

if [ "$RC_F1" -eq 0 ] && [ -z "$(cat "$OUTFILE_F1")" ] && [ "$RC_F2" -eq 0 ] && [ -z "$(cat "$OUTFILE_F2")" ]; then
  pass "Fixture F (concurrent multi-project): both REPO_F1 and REPO_F2 independently silent/exit-0 from the SAME shared ~/.claude.json"
else
  fail "Fixture F: expected both silent+exit0; got RC_F1=$RC_F1 out='$(cat "$OUTFILE_F1")' RC_F2=$RC_F2 out='$(cat "$OUTFILE_F2")'"
fi

CONFIGURED_F1=$(jq -r --arg k "$REPO_F1" '.projects[$k].mcpServers."lean-lsp".env.LEAN_PROJECT_PATH' "$HOME_F/.claude.json")
CONFIGURED_F2=$(jq -r --arg k "$REPO_F2" '.projects[$k].mcpServers."lean-lsp".env.LEAN_PROJECT_PATH' "$HOME_F/.claude.json")
if [ "$CONFIGURED_F1" = "$REPO_F1" ] && [ "$CONFIGURED_F2" = "$REPO_F2" ] && [ "$CONFIGURED_F1" != "$CONFIGURED_F2" ]; then
  pass "Fixture F: REPO_F1 and REPO_F2 hold DIFFERING, own-project LEAN_PROJECT_PATH values (non-vacuous by construction -- a shared-state bug would make these equal)"
else
  fail "Fixture F: expected differing own-project paths; got F1=$CONFIGURED_F1 F2=$CONFIGURED_F2"
fi

# =====================================================================
# Fixture G -- fresh-worktree independence: a second working directory of an "already
# registered" repository (simulated here as a second, distinct Lean project directory sharing
# no registration with the first) must be independently UNREGISTERED until it gets its own
# entry -- no accidental inheritance or collision with the parent's entry -- and once registered,
# BOTH resolve correctly, with the original's entry undisturbed.
# =====================================================================
REPO_G_MAIN="$WORKDIR/fixture_g/main"
REPO_G_WORKTREE="$WORKDIR/fixture_g/worktree"
HOME_G="$WORKDIR/fixture_g/home"
make_lean_project "$REPO_G_MAIN"
make_lean_project "$REPO_G_WORKTREE"
deploy_real_verifier "$REPO_G_MAIN"
deploy_real_verifier "$REPO_G_WORKTREE"
write_project_claude_json "$HOME_G" "$REPO_G_MAIN" "uvx" "$CANON_ARGS" "$REPO_G_MAIN"

# Step 1: worktree is NOT registered yet -- must be the unregistered (exit-1) case, not silently
# inheriting the main repo's entry.
OUTFILE_G1="$WORKDIR/out_g1.txt"
run_wrapper "$TOOL_SRC" "$REPO_G_WORKTREE" "$HOME_G" "$OUTFILE_G1"
RC_G1="$RUN_RC"
OUT_G1="$(cat "$OUTFILE_G1")"

if [ "$RC_G1" -eq 0 ] && [ -n "$OUT_G1" ] && echo "$OUT_G1" | grep -q "not registered for this project"; then
  pass "Fixture G step 1 (unregistered worktree): reported as unregistered, not silently inheriting the main repo's entry"
else
  fail "Fixture G step 1: expected the unregistered-project message; got rc=$RC_G1 output:
$OUT_G1"
fi

# Step 2: register the worktree too (via the real writer, exercising it end-to-end), then
# confirm BOTH main and worktree are now silent/correct, and the main repo's own entry is
# unchanged.
BEFORE_MAIN_ENTRY=$(jq -c --arg k "$REPO_G_MAIN" '.projects[$k].mcpServers."lean-lsp"' "$HOME_G/.claude.json")
HOME="$HOME_G" bash "$SCRIPT_DIR/../setup-lean-mcp.sh" --project "$REPO_G_WORKTREE" --scope project --quiet > /dev/null 2>&1
AFTER_MAIN_ENTRY=$(jq -c --arg k "$REPO_G_MAIN" '.projects[$k].mcpServers."lean-lsp"' "$HOME_G/.claude.json")

OUTFILE_G2_MAIN="$WORKDIR/out_g2_main.txt"
OUTFILE_G2_WORKTREE="$WORKDIR/out_g2_worktree.txt"
run_wrapper "$TOOL_SRC" "$REPO_G_MAIN" "$HOME_G" "$OUTFILE_G2_MAIN"
RC_G2_MAIN="$RUN_RC"
run_wrapper "$TOOL_SRC" "$REPO_G_WORKTREE" "$HOME_G" "$OUTFILE_G2_WORKTREE"
RC_G2_WORKTREE="$RUN_RC"

if [ "$RC_G2_MAIN" -eq 0 ] && [ -z "$(cat "$OUTFILE_G2_MAIN")" ] && [ "$RC_G2_WORKTREE" -eq 0 ] && [ -z "$(cat "$OUTFILE_G2_WORKTREE")" ]; then
  pass "Fixture G step 2 (worktree registered independently): both main and worktree now silent/exit-0"
else
  fail "Fixture G step 2: expected both silent+exit0; got RC_MAIN=$RC_G2_MAIN out='$(cat "$OUTFILE_G2_MAIN")' RC_WORKTREE=$RC_G2_WORKTREE out='$(cat "$OUTFILE_G2_WORKTREE")'"
fi

if [ "$BEFORE_MAIN_ENTRY" = "$AFTER_MAIN_ENTRY" ]; then
  pass "Fixture G step 2: registering the worktree left the main repo's own entry byte-identical (no cross-project mutation)"
else
  fail "Fixture G step 2: main repo's entry changed after registering an unrelated worktree; before='$BEFORE_MAIN_ENTRY' after='$AFTER_MAIN_ENTRY'"
fi

# =====================================================================
# Fixture H -- inverted Check 9, FAIL direction: a correct project-scoped entry PLUS a
# surviving top-level global entry. The global entry is drift on its own, even though this
# project's own entry is otherwise perfectly correct (see fixture B for the PASS direction).
# =====================================================================
REPO_H="$WORKDIR/fixture_h/repo"
HOME_H="$WORKDIR/fixture_h/home"
make_lean_project "$REPO_H"
deploy_real_verifier "$REPO_H"
write_project_claude_json "$HOME_H" "$REPO_H" "uvx" "$CANON_ARGS" "$REPO_H"
add_global_claude_json_entry "$HOME_H" "uvx" "$CANON_ARGS" "$REPO_H"

OUTFILE_H="$WORKDIR/out_h.txt"
run_wrapper "$TOOL_SRC" "$REPO_H" "$HOME_H" "$OUTFILE_H"
RC_H="$RUN_RC"
OUT_H="$(cat "$OUTFILE_H")"

if [ "$RC_H" -eq 0 ] && [ -n "$OUT_H" ] && echo "$OUT_H" | grep -q "retire-global"; then
  pass "Fixture H (Check 9 FAIL direction: correct project entry + surviving global): wrapper exit 0, output naming --retire-global"
else
  fail "Fixture H: expected exit 0 and output naming --retire-global; got rc=$RC_H output:
$OUT_H"
fi

# =====================================================================
# Fixture I -- unregistered project: no project-scoped entry at all (the common day-one-of-a-
# worktree case), no global entry either. Must hit the exit-1 "not registered for this project"
# branch, naming setup-lean-mcp.sh as the remedy.
# =====================================================================
REPO_I="$WORKDIR/fixture_i/repo"
HOME_I="$WORKDIR/fixture_i/home"
make_lean_project "$REPO_I"
deploy_real_verifier "$REPO_I"
mkdir -p "$HOME_I"
echo '{}' > "$HOME_I/.claude.json"

OUTFILE_I="$WORKDIR/out_i.txt"
run_wrapper "$TOOL_SRC" "$REPO_I" "$HOME_I" "$OUTFILE_I"
RC_I="$RUN_RC"
OUT_I="$(cat "$OUTFILE_I")"

if [ "$RC_I" -eq 0 ] && [ -n "$OUT_I" ] && echo "$OUT_I" | grep -q "not registered for this project" && echo "$OUT_I" | grep -q "setup-lean-mcp.sh"; then
  pass "Fixture I (unregistered project, no entries at all): wrapper exit 0, output naming both the unregistered state and setup-lean-mcp.sh"
else
  fail "Fixture I: expected exit 0 and output naming the unregistered state + setup-lean-mcp.sh; got rc=$RC_I output:
$OUT_I"
fi

# =====================================================================
# Mutation check 1 (wrapper-level, pre-existing, extended to the new fixtures): a mutated copy
# of the wrapper that unconditionally exits 0 immediately after invoking the verifier --
# bypassing all message synthesis -- must produce EMPTY output on fixtures A, D, E, H, and I
# (which all require non-empty output pre-mutation), while B and C (already silent) remain
# unaffected. Fixtures F and G are not part of this mutation check: their assertions are already
# non-vacuous by construction (see the file header).
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
  fail "Mutation 1 setup: sed insertion did not find the expected anchor line in $TOOL_SRC -- mutation check did not run"
else
  run_wrapper "$MUTATED_TOOL" "$REPO_A" "$HOME_A" "$WORKDIR/mut_out_a.txt"
  MUT_OUT_A="$(cat "$WORKDIR/mut_out_a.txt")"
  run_wrapper "$MUTATED_TOOL" "$REPO_D" "$HOME_D" "$WORKDIR/mut_out_d.txt"
  MUT_OUT_D="$(cat "$WORKDIR/mut_out_d.txt")"
  run_wrapper "$MUTATED_TOOL" "$REPO_E" "$HOME_E" "$WORKDIR/mut_out_e.txt"
  MUT_OUT_E="$(cat "$WORKDIR/mut_out_e.txt")"
  run_wrapper "$MUTATED_TOOL" "$REPO_H" "$HOME_H" "$WORKDIR/mut_out_h.txt"
  MUT_OUT_H="$(cat "$WORKDIR/mut_out_h.txt")"
  run_wrapper "$MUTATED_TOOL" "$REPO_I" "$HOME_I" "$WORKDIR/mut_out_i.txt"
  MUT_OUT_I="$(cat "$WORKDIR/mut_out_i.txt")"
  run_wrapper "$MUTATED_TOOL" "$REPO_B" "$HOME_B" "$WORKDIR/mut_out_b.txt"
  MUT_OUT_B="$(cat "$WORKDIR/mut_out_b.txt")"
  run_wrapper "$MUTATED_TOOL" "$REPO_C" "$HOME_C" "$WORKDIR/mut_out_c.txt"
  MUT_OUT_C="$(cat "$WORKDIR/mut_out_c.txt")"

  if [ -z "$MUT_OUT_A" ] && [ -z "$MUT_OUT_D" ] && [ -z "$MUT_OUT_E" ] && [ -z "$MUT_OUT_H" ] && [ -z "$MUT_OUT_I" ]; then
    pass "Mutation 1: neutralized wrapper produces EMPTY output on fixtures A, D, E, H, I (were non-empty pre-mutation) -- fixtures are discriminative, not vacuous"
  else
    fail "Mutation 1: expected fixtures A, D, E, H, I to go silent under the neutralized wrapper; got A='$MUT_OUT_A' D='$MUT_OUT_D' E='$MUT_OUT_E' H='$MUT_OUT_H' I='$MUT_OUT_I'"
  fi

  if [ -z "$MUT_OUT_B" ] && [ -z "$MUT_OUT_C" ]; then
    pass "Mutation 1: fixtures B and C remain empty under the neutralized wrapper (unaffected, as expected -- they exit before the mutated line)"
  else
    fail "Mutation 1: expected fixtures B, C to remain empty; got B='$MUT_OUT_B' C='$MUT_OUT_C'"
  fi
fi

# =====================================================================
# Mutation check 2 (verifier-level, new): a mutated copy of verify-lean-mcp.sh with Check 9 (the
# inverted surviving-global-entry check) deleted. Run DIRECTLY (not through the wrapper, so the
# verifier's own exit code is visible) against fixture H's config: pre-mutation the verifier
# exits non-zero; post-mutation, with Check 9 gone, it must exit 0 -- proving fixture H actually
# depends on Check 9, not some other check that happens to also fail on this config. Fixture F
# (no global entry at either project) is the control: Check 9 never fires there either way, so
# the mutation must NOT change its (already exit-0) outcome.
# =====================================================================
MUTATED_VERIFIER="$WORKDIR/mutated-verify-lean-mcp.sh"
# Deletes the Check 9 block: from its comment-block opening line through its closing `fi`,
# identified by the unique anchor text "Check 9 (inverted)" at the start of the block and the
# GLOBAL_ENTRY variable it introduces. Uses awk for a range delete rather than sed, since the
# block spans a variable, multi-line, uniquely-bounded region.
awk '
  /^# Check 9 \(inverted\)/ { skipping = 1 }
  skipping && /^fi$/ { skipping = 0; next }
  skipping { next }
  { print }
' "$VERIFIER_SRC" > "$MUTATED_VERIFIER"
chmod +x "$MUTATED_VERIFIER"

if grep -q "Check 9 (inverted)" "$MUTATED_VERIFIER"; then
  fail "Mutation 2 setup: awk delete did not find/remove the expected Check 9 block in $VERIFIER_SRC -- mutation check did not run"
else
  # Overwrite fixture H's OWN deployed verifier in place with the mutated content and run
  # DIRECTLY (not through the wrapper). Safe to mutate REPO_H's deployed copy at this point:
  # mutation 1 above already finished every wrapper-level call that depended on REPO_H's
  # ORIGINAL deployed verifier. Reusing the exact same repo/home pair (rather than a fresh
  # scratch copy) is deliberate -- it is what keeps the .claude.json project KEY
  # (.projects[$REPO_H]) matching the directory the verifier resolves $(pwd) against; a
  # separate scratch directory would have a different absolute path and would fail Check 2
  # (absent entry) instead of exercising Check 9 as intended.
  cp "$MUTATED_VERIFIER" "$REPO_H/.claude/scripts/verify-lean-mcp.sh"
  chmod +x "$REPO_H/.claude/scripts/verify-lean-mcp.sh"

  OUTFILE_H_MUT="$WORKDIR/out_h_mut.txt"
  run_verifier_direct "$REPO_H/.claude/scripts/verify-lean-mcp.sh" "$REPO_H" "$HOME_H" "$OUTFILE_H_MUT"
  RC_H_MUT="$RUN_RC"

  if [ "$RC_H_MUT" -eq 0 ]; then
    pass "Mutation 2: with Check 9 deleted, the verifier now exits 0 on fixture H's config (was non-zero pre-mutation) -- fixture H is discriminative for Check 9 specifically"
  else
    fail "Mutation 2: expected exit 0 with Check 9 deleted; got rc=$RC_H_MUT output:
$(cat "$OUTFILE_H_MUT")"
  fi

  # Control: fixture F1's config (no global entry) must be unaffected -- Check 9 was never the
  # reason F passes. Same in-place-overwrite approach, on REPO_F1's own deployed verifier
  # (mutation 1 never touches F, so this is the first and only mutation applied to it).
  cp "$MUTATED_VERIFIER" "$REPO_F1/.claude/scripts/verify-lean-mcp.sh"
  chmod +x "$REPO_F1/.claude/scripts/verify-lean-mcp.sh"

  OUTFILE_F1_MUT="$WORKDIR/out_f1_mut.txt"
  run_verifier_direct "$REPO_F1/.claude/scripts/verify-lean-mcp.sh" "$REPO_F1" "$HOME_F" "$OUTFILE_F1_MUT"
  RC_F1_MUT="$RUN_RC"

  if [ "$RC_F1_MUT" -eq 0 ]; then
    pass "Mutation 2 control: fixture-F-shaped config (no global entry) still exits 0 with Check 9 deleted -- confirms the mutation is targeted, not overly broad"
  else
    fail "Mutation 2 control: expected exit 0 (unaffected); got rc=$RC_F1_MUT output:
$(cat "$OUTFILE_F1_MUT")"
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
