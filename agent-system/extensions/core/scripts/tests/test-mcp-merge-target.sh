#!/usr/bin/env bash
# test-mcp-merge-target.sh - Durable scratch-tree regression harness for the merge_targets.mcp
# deploy-engine mechanism (init.lua's `mcp` branches in process_merge_targets()/
# reverse_merge_targets(), driving merge.lua's merge_settings/unmerge_settings against a
# project-root .mcp.json). Proves, end to end against a throwaway fixture extension and a
# throwaway fixture project, that all four stated requirements hold:
#   (a) a generated server entry carries its explicit "type" field verbatim
#   (b) unloading an extension removes its servers from .mcp.json
#   (c) deploying twice yields a byte-identical .mcp.json
#   (d) hand-written entries a user added to .mcp.json survive regeneration
# plus two empirical risk checks the design left open rather than assumed:
#   (E) whether a load -> reload (simulated regenerate) -> unload sequence still retracts
#   (claude mcp get): whether the fixture server is visible via the CLI, recording whatever the
#     workspace-trust gate (Claude Code v2.1.196+) actually does rather than assuming a result
#
# Structural model: test-deploy-orphans.sh (pass()/fail()/info() helpers via common.sh's
# common_test_pass/common_test_fail/common_test_info, PASSED/FAILED integer counters, a
# trap-based mktemp -d WORKDIR, exit 0/1/2 convention). Unlike that harness, this one does NOT
# use deploy-headless.sh (which resolves the real source store) -- it builds its OWN scratch
# source store under WORKDIR and drives the engine directly via one `nvim --headless -c "lua
# ..." -c "qa!"` subprocess per step, exactly as the implementation plan's Phase 3 directs. The
# Lua module under test always resolves from the real ~/.config/nvim runtimepath (this repo);
# only the extension SOURCE STORE and the fixture PROJECT are scratch, discarded on exit. No
# step in this harness deploys into this repository: $REPO_ROOT is only used as nvim's cwd so
# `require(...)` resolves the real modules, and .mcp.json is only ever written under WORKDIR.
#
# Exit codes: 0 -- all assertions PASS; 1 -- at least one assertion FAILED; 2 -- environment
# error (nvim/jq not found, or a step could not run at all).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

if [[ -z "$REPO_ROOT" ]]; then
  echo "ERROR: could not resolve repo root from $SCRIPT_DIR" >&2
  exit 2
fi

if ! command -v nvim >/dev/null 2>&1; then
  echo "ERROR: nvim not found on PATH; cannot drive the extension engine headlessly." >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not found on PATH; cannot validate generated JSON." >&2
  exit 2
fi

PASSED=0
FAILED=0

WORKDIR="$(mktemp -d)"
cleanup() { [[ -n "${WORKDIR:-}" && -d "$WORKDIR" ]] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

SRC_ROOT="$WORKDIR/src"
PROJECT_DIR="$WORKDIR/project"
FIXTURE_DIR="$SRC_ROOT/agent-system/extensions/mcpfixture"
MCP_JSON="$PROJECT_DIR/.mcp.json"
SERVER_NAME="mcpfixture-server"

mkdir -p "$FIXTURE_DIR"
mkdir -p "$PROJECT_DIR"
git -C "$PROJECT_DIR" init -q
git -C "$PROJECT_DIR" -c user.email="test@test.local" -c user.name="mcp-merge-target-test" \
  commit -q --allow-empty -m "scratch init"

# Minimal fixture extension: no provides, no dependencies (so loading it never forces a core
# bootstrap -- confirmed empirically by the first load step below), one declared mcp server.
cat > "$FIXTURE_DIR/manifest.json" <<EOF
{
  "name": "mcpfixture",
  "version": "1.0.0",
  "description": "Scratch fixture extension for the merge_targets.mcp regression harness.",
  "dependencies": [],
  "merge_targets": {
    "mcp": {
      "source": "mcp-fragment.json",
      "target": ".mcp.json"
    }
  }
}
EOF

cat > "$FIXTURE_DIR/mcp-fragment.json" <<EOF
{
  "mcpServers": {
    "$SERVER_NAME": {
      "type": "stdio",
      "command": "true",
      "args": []
    }
  }
}
EOF

if ! jq empty "$FIXTURE_DIR/manifest.json" 2>/dev/null || ! jq empty "$FIXTURE_DIR/mcp-fragment.json" 2>/dev/null; then
  echo "ERROR: fixture manifest/fragment failed to parse as JSON" >&2
  exit 2
fi

# run_lua <lua-code> -- one headless nvim subprocess, cwd at REPO_ROOT so `require(...)`
# resolves the real shared extension modules. Prints whatever the lua code prints; qa! always
# follows so the process exits even on a lua error (pcall'd at the call site below).
run_lua() {
  (cd "$REPO_ROOT" && nvim --headless -c "lua $1" -c "qa!" 2>&1)
}

MANAGER_BOOTSTRAP="local ext_config = require('neotex.plugins.ai.shared.extensions.config'); local ext_init = require('neotex.plugins.ai.shared.extensions.init'); local manager = ext_init.create(ext_config.claude('$SRC_ROOT'));"

do_load() {
  run_lua "$MANAGER_BOOTSTRAP local ok, err = manager.load('mcpfixture', { project_dir = '$PROJECT_DIR', confirm = false }); print('LOAD_RESULT ok=' .. tostring(ok) .. ' err=' .. tostring(err))"
}

do_unload() {
  run_lua "$MANAGER_BOOTSTRAP local ok, err = manager.unload('mcpfixture', { project_dir = '$PROJECT_DIR', confirm = false }); print('UNLOAD_RESULT ok=' .. tostring(ok) .. ' err=' .. tostring(err))"
}

# reset_project -- discards the fixture project entirely and recreates a fresh git repo at
# $PROJECT_DIR. Each assertion GROUP below starts from this clean slate so one group's reload
# (which thins merge-tracking data -- see Assertion Group E) never leaks into another group's
# result. This is a scratch harness operating on its own throwaway WORKDIR; it never touches
# this repository.
reset_project() {
  rm -rf "$PROJECT_DIR"
  mkdir -p "$PROJECT_DIR"
  git -C "$PROJECT_DIR" init -q
  git -C "$PROJECT_DIR" -c user.email="test@test.local" -c user.name="mcp-merge-target-test" \
    commit -q --allow-empty -m "scratch init"
}

do_force_reload() {
  run_lua "$MANAGER_BOOTSTRAP local ok, err = manager.load('mcpfixture', { project_dir = '$PROJECT_DIR', confirm = false, force = true }); print('LOAD_RESULT ok=' .. tostring(ok) .. ' err=' .. tostring(err))"
}

# =====================================================================
# Group A: requirement (a) generation, and requirement (b) retraction on a PLAIN load -> unload
# round trip (no intervening reload, so merge-tracking data is at its fullest and a clean
# retraction -- including decision 6's empty-file cleanup -- is expected to succeed).
# =====================================================================
reset_project
common_test_info "Group A: first load, driving manager.load('mcpfixture', ...) against the scratch project"
load_a_output="$(do_load)"
if ! echo "$load_a_output" | grep -q 'LOAD_RESULT ok=true'; then
  echo "ERROR: Group A load did not succeed. Output:" >&2
  echo "$load_a_output" | sed 's/^/    /' >&2
  exit 2
fi
common_test_pass "Scope hypothesis confirmed: mcpfixture (dependencies = {}) loads without forcing a core bootstrap"

if [[ -f "$MCP_JSON" ]] && jq empty "$MCP_JSON" 2>/dev/null; then
  common_test_pass "Assertion A: .mcp.json exists and is valid JSON after load"
else
  common_test_fail "Assertion A: .mcp.json missing or invalid JSON after load"
fi

generated_type="$(jq -r --arg s "$SERVER_NAME" '.mcpServers[$s].type // "MISSING"' "$MCP_JSON" 2>/dev/null)"
if [[ "$generated_type" == "stdio" ]]; then
  common_test_pass "Assertion A (requirement a): generated entry's explicit \"type\" field is \"stdio\""
else
  common_test_fail "Assertion A (requirement a): generated entry's \"type\" field is '$generated_type', expected 'stdio'"
fi

common_test_info "Group A: unloading mcpfixture immediately (no intervening reload)"
unload_a_output="$(do_unload)"
if ! echo "$unload_a_output" | grep -q 'UNLOAD_RESULT ok=true'; then
  common_test_fail "Assertion D: plain unload did not report ok=true: $(echo "$unload_a_output" | grep UNLOAD_RESULT)"
elif [[ ! -f "$MCP_JSON" ]]; then
  common_test_pass "Assertion D (requirement b) + decision 6: a plain load -> unload round trip fully retracts the fixture's server AND removes the now-empty .mcp.json file"
else
  common_test_fail "Assertion D: .mcp.json still exists after a plain unload with no hand-written entries: $(cat "$MCP_JSON")"
fi

# =====================================================================
# Group B: requirement (c), idempotency. A second deploy on an ALREADY-loaded extension is
# refused by manager.load's own already-loaded guard, so "deploy twice" here means re-running
# process_merge_targets' effect via a FORCED reload -- the real "deploy twice" shape.
# =====================================================================
reset_project
common_test_info "Group B: load, then force a second deploy (reload) to check byte-identity"
load_b_output="$(do_load)"
if ! echo "$load_b_output" | grep -q 'LOAD_RESULT ok=true'; then
  echo "ERROR: Group B load did not succeed. Output:" >&2
  echo "$load_b_output" | sed 's/^/    /' >&2
  exit 2
fi
cp "$MCP_JSON" "$WORKDIR/mcp-after-first-load.json"

reload_output="$(do_force_reload)"
if ! echo "$reload_output" | grep -q 'LOAD_RESULT ok=true'; then
  common_test_fail "Assertion B: forced reload did not succeed: $(echo "$reload_output" | grep LOAD_RESULT)"
elif cmp -s "$WORKDIR/mcp-after-first-load.json" "$MCP_JSON"; then
  common_test_pass "Assertion B (requirement c): second deploy is byte-identical (cmp)"
else
  common_test_fail "Assertion B (requirement c): second deploy is NOT byte-identical to the first"
  common_test_info "RISK CONFIRMED: write_json's jq . is order-preserving, not sorting -- see plan Risks table contingency (M.write_json sort_keys)"
fi

# =====================================================================
# Group C: requirement (d), hand-written survival across a regeneration, PLUS Assertion E (the
# regenerate-then-unload risk): planting a hand-written entry and force-reloading thins the
# persisted merge-tracking data for THIS extension (deep_merge only tracks keys/items not
# already present, and manager.load overwrites -- never merges -- the persisted tracked data on
# every load call), so the unload that follows is the exact "load -> regenerate -> unload"
# shape the Risks table flags as a latent, pre-existing limitation of the shared merge_settings
# tracking path. This assertion RECORDS whichever outcome actually occurs rather than requiring
# retraction to succeed -- per the plan's explicit instruction not to expand scope if it
# reproduces -- while still requiring the hand-written entry to be untouched either way.
# =====================================================================
reset_project
common_test_info "Group C: load, plant a hand-written entry, force-reload (regenerate)"
load_c_output="$(do_load)"
if ! echo "$load_c_output" | grep -q 'LOAD_RESULT ok=true'; then
  echo "ERROR: Group C load did not succeed. Output:" >&2
  echo "$load_c_output" | sed 's/^/    /' >&2
  exit 2
fi

HAND_WRITTEN_NAME="hand-written-server"
tmp_planted="$(mktemp)"
jq --arg name "$HAND_WRITTEN_NAME" \
  '.mcpServers[$name] = {"type": "stdio", "command": "my-own-server"}' \
  "$MCP_JSON" > "$tmp_planted" && mv "$tmp_planted" "$MCP_JSON"

do_force_reload >/dev/null

hand_written_present="$(jq -r --arg name "$HAND_WRITTEN_NAME" '.mcpServers[$name].command // "MISSING"' "$MCP_JSON" 2>/dev/null)"
fixture_still_present="$(jq -r --arg s "$SERVER_NAME" '.mcpServers[$s].type // "MISSING"' "$MCP_JSON" 2>/dev/null)"
if [[ "$hand_written_present" == "my-own-server" ]] && [[ "$fixture_still_present" == "stdio" ]]; then
  common_test_pass "Assertion C (requirement d): hand-written entry survives regeneration alongside the extension's own entry"
else
  common_test_fail "Assertion C (requirement d): hand-written='$hand_written_present' fixture='$fixture_still_present' (expected my-own-server / stdio)"
fi

common_test_info "Assertion E: unloading after the regenerate above (load -> regenerate -> unload)"
do_unload >/dev/null
fixture_after_regen_unload="$(jq -r --arg s "$SERVER_NAME" '.mcpServers[$s] // "ABSENT"' "$MCP_JSON" 2>/dev/null)"
hand_written_after_regen_unload="$(jq -r --arg name "$HAND_WRITTEN_NAME" '.mcpServers[$name].command // "MISSING"' "$MCP_JSON" 2>/dev/null)"
if [[ "$hand_written_after_regen_unload" != "my-own-server" ]]; then
  common_test_fail "Assertion E: the hand-written entry was disturbed by unload after a regenerate (it must survive regardless of retraction outcome): '$hand_written_after_regen_unload'"
elif [[ "$fixture_after_regen_unload" == "ABSENT" ]]; then
  common_test_pass "Assertion E: retraction still happened after a load -> regenerate -> unload sequence (tracking was not thinned in this run), and the hand-written entry survived"
else
  common_test_pass "Assertion E: retraction did NOT happen after regenerate-then-unload -- documented as a pre-existing, latent limitation of the shared merge_settings tracking path (not introduced by mcp; see plan Risks table), and the hand-written entry survived regardless"
fi

# =====================================================================
# claude mcp get check: attempted, non-fatal. A workspace-trust refusal is an acceptable,
# expected outcome under Claude Code v2.1.196+ (project-scoped MCP servers require workspace
# trust approval before `claude mcp list`/`claude mcp get` will read them). This assertion
# never fails the harness; it only records what actually happened.
# =====================================================================
reset_project
common_test_info "claude mcp get check (non-fatal, informational only)"
do_load >/dev/null
if command -v claude >/dev/null 2>&1; then
  mcp_get_output="$(cd "$PROJECT_DIR" && claude mcp get "$SERVER_NAME" 2>&1)"
  mcp_get_status=$?
  common_test_info "claude mcp get '$SERVER_NAME' exited $mcp_get_status; output:"
  echo "$mcp_get_output" | sed 's/^/    /'
else
  common_test_info "claude CLI not found on PATH; claude mcp get could not be attempted (recorded, not a failure)"
fi
do_unload >/dev/null

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
