#!/usr/bin/env bash
# test-routing-resolution.sh - Table-driven parity suite for the consolidated routing ladder.
#
# There is no prior test-*routing*.sh in this directory (test-orchestrate-triage-classify.sh
# covers a different concern -- the partial-status continuation predicate, not routing
# resolution). This suite asserts, mechanically and repeatably:
#
#   (A former Assert 1 exercised the skill-level router's resolution against each manifest's
#     `.routing`/`.routing_hard` block. Both that router script and the two manifest blocks it
#     read are retired by the routing-ladder collapse -- see
#     context/guides/manifest-routing-schema.md -- so Assert 1 is REMOVED outright, not
#     retargeted: there is no surviving skill-level resolution path left to test. Agent-level
#     resolution, Assert 2 below, is unaffected and remains the coverage this suite provides.)
#   Assert 2 (agent existence): command-route-agent.sh resolves every declared pair to an agent
#     name that names a real file under some extension's agents/ directory -- the check that
#     makes the epi-resolves-to-nothing defect class impossible.
#   Assert 3 (intra-file branch coverage -- retargeted by the four-move loop rewrite, see
#     docs/architecture/orchestrate-state-machine.md): the former single-task engine's Stage 1b
#     (three separate command-route-agent.sh call sites, one per phase) and its H1-hard/base
#     dispatch-branch distinction are BOTH deleted -- skill-orchestrate/SKILL.md now has exactly
#     ONE dispatch composition site (Move 2), used unconditionally for every dispatch[] row
#     regardless of whether Move 1's H1 selection forced a phase number. There is no longer a
#     structural way for "one mode's dispatch site" to be silently deleted while the other
#     survives, because there is only one site. Per-phase agent resolution itself now lives
#     entirely in orchestrate-cycle-plan.sh's resolve_agent() function (one command-route-agent.sh
#     call site, invoked once per candidate with a phase-derived default_agent, rather than three
#     separate call sites) -- Assert 3 below checks that site instead of SKILL.md's now-absent
#     Stage 1b, plus that SKILL.md's single Move 2 site still dispatches the row's resolved
#     `agent` field. Separately, hard-mode agent resolution
#     (command-route-agent.sh itself, exercised directly, not via the SKILL.md prose) still falls
#     back to the extension's own standard (non-hard) routing_agents block on a routing_agents_hard
#     miss -- via="hard-miss-standard-fallback" -- rather than discarding the declared domain
#     agent, and only reaches the caller's generic hard default on a genuine total miss of both
#     blocks.
#   Assert 4 (precedence direction): a synthetic fixture where a non-core manifest and a
#     core-named manifest both declare the same (op, task_type) confirms the non-core entry wins
#     -- pinning first-match-wins against a regression to the former standalone hard-mode
#     orchestrate skill's old no-break last-match-wins loop.
#
# Assert 2's matrix is built MECHANICALLY from every manifest.json under
# agent-system/extensions/** rather than hardcoded, so a newly added extension is covered
# automatically -- a hardcoded list would not notice a newly added extension, which is the exact
# failure mode this test exists to prevent.
#
# Source resolution: sources manifest-routing-lib.sh directly (Assert 4's fixture) and shells out
# to command-route-agent.sh (Assert 2, since it is meant to be sourced from a working directory
# at a repo root, exactly like its real callers) with ROUTE_MANIFEST_ROOT=agent-system so all
# three remaining assertions validate the SOURCE STORE, matching lint-routing-wiring.sh's own
# convention -- see manifest-routing-lib.sh's header for the ROUTE_MANIFEST_ROOT contract.
#
# Follows the core shell-test convention in context/standards/shell-script-testing.md:
# pass()/fail()/info() helpers, PASSED/FAILED integer counters, mktemp -d workdir with a trap
# EXIT cleanup (Assert 4's fixture only), exit 0 on all-pass, exit 1 on any-fail.
#
# Exit codes: 0 -- all assertions PASS; 1 -- at least one assertion FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-}"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
fi

EXT_ROOT="$REPO_ROOT/agent-system/extensions"
LIB_SRC="$EXT_ROOT/core/scripts/lib/manifest-routing-lib.sh"
ROUTE_AGENT_SRC="$EXT_ROOT/core/scripts/command-route-agent.sh"
ORCH_SKILL="$EXT_ROOT/core/skills/skill-orchestrate/SKILL.md"
ORCH_CYCLE_PLAN="$EXT_ROOT/core/scripts/orchestrate-cycle-plan.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

for f in "$LIB_SRC" "$ROUTE_AGENT_SRC" "$ORCH_SKILL"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: expected file not found: $f" >&2
    exit 2
  fi
done
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required" >&2
  exit 2
fi

# =====================================================================
# Assert 2: agent existence -- command-route-agent.sh resolves every declared routing_agents /
# routing_agents_hard pair to a file that exists on disk.
# =====================================================================
echo ""
echo "--- Assert 2: agent existence ---"

assert2_failures=0
assert2_checked=0
while IFS= read -r manifest; do
  [ -z "$manifest" ] && continue
  for block in routing_agents routing_agents_hard; do
    while IFS=$'\t' read -r op tt agent; do
      [ -z "$op" ] && continue
      assert2_checked=$((assert2_checked + 1))
      found=false
      while IFS= read -r agent_file; do
        [ -n "$agent_file" ] && found=true && break
      done < <(find "$EXT_ROOT" -maxdepth 3 -path "*/agents/${agent}.md" -type f 2>/dev/null)
      if [ "$found" != true ]; then
        fail "Assert 2: $block.$op.$tt = $agent (manifest: ${manifest#"$EXT_ROOT"/}) names no existing agent file"
        assert2_failures=$((assert2_failures + 1))
      fi
    done < <(jq -r --arg b "$block" \
      '(.[$b] // {}) | to_entries[] | .key as $op | (.value | to_entries[]) | "\($op)\t\(.key)\t\(.value)"' \
      "$manifest" 2>/dev/null)
  done
done < <(find "$EXT_ROOT" -maxdepth 2 -name "manifest.json" -type f | sort)

if [ "$assert2_failures" -eq 0 ]; then
  pass "Assert 2: all $assert2_checked routing_agents/routing_agents_hard declarations name an existing agent file"
fi

# =====================================================================
# Assert 3: intra-file branch coverage (structural, resolution-site count + branch-aware dispatch
# presence) plus semantic (hard-mode never silently falls back to the standard block on a miss).
# =====================================================================
echo ""
echo "--- Assert 3: intra-file branch coverage ---"

cycle_plan_calls=$(grep -c 'command-route-agent\.sh' "$ORCH_CYCLE_PLAN" 2>/dev/null || echo 0)
if [ "$cycle_plan_calls" -ge 1 ]; then
  pass "Assert 3 (structural): orchestrate-cycle-plan.sh ($cycle_plan_calls) invokes command-route-agent.sh (resolve_agent(), shared across research/plan/implement)"
else
  fail "Assert 3 (structural): expected >=1 command-route-agent.sh invocation in orchestrate-cycle-plan.sh, got $cycle_plan_calls"
fi

if grep -qE 'case "\$TASK_TYPE"|sed .s/\^skill-' "$ORCH_CYCLE_PLAN" 2>/dev/null; then
  fail "Assert 3 (structural): a case-table or sed-derivation pattern still exists in orchestrate-cycle-plan.sh"
else
  pass "Assert 3 (structural): no case-table or sed-derivation pattern remains in orchestrate-cycle-plan.sh"
fi

if grep -qE 'case "\$TASK_TYPE"|sed .s/\^skill-' "$ORCH_SKILL" 2>/dev/null; then
  fail "Assert 3 (structural): a case-table or sed-derivation pattern still exists in skill-orchestrate/SKILL.md"
else
  pass "Assert 3 (structural): no case-table or sed-derivation pattern remains in skill-orchestrate/SKILL.md"
fi

# Branch-aware check (RETARGETED -- the four-move loop rewrite deleted both the single-task
# engine and its H1-hard/base dispatch-branch distinction; skill-orchestrate/SKILL.md now has
# exactly one dispatch composition site, used unconditionally for every dispatch[] row). Assert
# that resolve_agent()'s three phase-specific caller defaults are each wired in
# orchestrate-cycle-plan.sh, and that SKILL.md's single Move 2 site actually dispatches each
# row's resolved `.agent` field -- the structural invariant the old two-branch check protected,
# now expressed against a single site rather than two.
for default_agent in "general-research-agent" "planner-agent" "general-implementation-agent"; do
  if grep -qF "$default_agent" "$ORCH_CYCLE_PLAN"; then
    pass "Assert 3 (branch-aware): orchestrate-cycle-plan.sh resolve_agent() wires caller default $default_agent"
  else
    fail "Assert 3 (branch-aware): orchestrate-cycle-plan.sh resolve_agent() missing caller default $default_agent"
  fi
done

move2_heading='### Move 2: Dispatch'
move2_start=$(grep -nF "$move2_heading" "$ORCH_SKILL" | head -1 | cut -d: -f1)
move3_start=$(grep -nF '### Move 3:' "$ORCH_SKILL" | head -1 | cut -d: -f1)
if [ -n "${move2_start:-}" ] && [ -n "${move3_start:-}" ] && [ "$move2_start" -lt "$move3_start" ]; then
  move2_body="$(sed -n "${move2_start},$((move3_start - 1))p" "$ORCH_SKILL")"
  if grep -q '\.agent' <<< "$move2_body"; then
    pass "Assert 3 (branch-aware): SKILL.md's single Move 2 dispatch site dispatches each row's resolved .agent field"
  else
    fail "Assert 3 (branch-aware): SKILL.md's Move 2 dispatch site does NOT reference the row's resolved .agent field"
  fi
else
  fail "Assert 3 (branch-aware): could not locate Move 2/Move 3 region boundaries in skill-orchestrate/SKILL.md (move2_start=${move2_start:-MISSING} move3_start=${move3_start:-MISSING})"
fi

# Semantic: for task types with NO routing_agents_hard entry anywhere, hard-mode resolution must
# fall back to the extension's own declared standard routing_agents agent (via
# "hard-miss-standard-fallback") rather than discarding it in favor of the caller's generic hard
# default -- this is the corrected contract this task's fix implements. `neovim` -> expects
# neovim-research-agent; `nix` -> expects nix-research-agent.
#
# Fixture-coupling note: `nix` is currently one of the 14 extensions that declare routing_agents
# without routing_agents_hard (see the research report), so today it exercises the
# standard-fallback rung. If a future task declares a routing_agents_hard block for `nix`, this
# fixture's expected value must move from `nix-research-agent` (standard-fallback rung, via
# "hard-miss-standard-fallback") to that new hard-block value (hard-hit rung, via from
# routing_lookup). The fixture is pinned to nix's CURRENT absence of a hard block, not to nix as
# a permanent no-hard-block example.
declare -A _assert3_semantic_expected=( [neovim]="neovim-research-agent" [nix]="nix-research-agent" )
for tt in neovim nix; do
  expected="${_assert3_semantic_expected[$tt]}"
  hard_actual=$(
    cd "$REPO_ROOT" && ROUTE_MANIFEST_ROOT=agent-system \
      bash -c "source '$ROUTE_AGENT_SRC' 'research' '$tt' 'general-research-agent' 'hard' 2>/dev/null; echo \"\$AGENT_NAME\""
  )
  hard_trace=$(
    cd "$REPO_ROOT" && ROUTE_MANIFEST_ROOT=agent-system \
      bash -c "source '$ROUTE_AGENT_SRC' 'research' '$tt' 'general-research-agent' 'hard' 2>&1 1>/dev/null"
  )
  hard_via=$(echo "$hard_trace" | grep -o 'via=[a-zA-Z-]*' | tail -n 1 | cut -d= -f2)
  if [ "$hard_actual" = "$expected" ] && [ "$hard_via" = "hard-miss-standard-fallback" ]; then
    pass "Assert 3 (semantic): $tt has no routing_agents_hard entry, hard-mode falls back to the standard block's own agent ($expected, via=hard-miss-standard-fallback), not the caller's generic hard default"
  else
    fail "Assert 3 (semantic): $tt hard-mode resolved '$hard_actual' (via=$hard_via), expected standard-fallback to '$expected' (via=hard-miss-standard-fallback)"
  fi
done

# Fourth semantic case: a never-declared task_type must still resolve to the caller-supplied
# default under hard mode -- the genuine total-miss rung, which no existing fixture exercises.
_total_miss_actual=$(
  cd "$REPO_ROOT" && ROUTE_MANIFEST_ROOT=agent-system \
    bash -c "source '$ROUTE_AGENT_SRC' 'research' 'zzz-unrouted-test-type' 'general-research-agent' 'hard' 2>/dev/null; echo \"\$AGENT_NAME\""
)
if [ "$_total_miss_actual" = "general-research-agent" ]; then
  pass "Assert 3 (semantic): a never-declared task_type under hard mode still resolves the caller's default (general-research-agent) -- the true total-miss rung"
else
  fail "Assert 3 (semantic): never-declared task_type under hard mode resolved '$_total_miss_actual', expected caller default 'general-research-agent'"
fi

# lean4 DOES have a routing_agents_hard entry, and it must differ from the standard entry
# (proving hard mode reads a different block, not the same one twice under different names).
lean_std=$(
  cd "$REPO_ROOT" && ROUTE_MANIFEST_ROOT=agent-system \
    bash -c "source '$ROUTE_AGENT_SRC' 'research' 'lean4' 'general-research-agent' '' 2>/dev/null; echo \"\$AGENT_NAME\""
)
lean_hard=$(
  cd "$REPO_ROOT" && ROUTE_MANIFEST_ROOT=agent-system \
    bash -c "source '$ROUTE_AGENT_SRC' 'research' 'lean4' 'general-research-agent' 'hard' 2>/dev/null; echo \"\$AGENT_NAME\""
)
if [ "$lean_std" = "lean-research-agent" ] && [ "$lean_hard" = "lean-research-hard-agent" ] && [ "$lean_std" != "$lean_hard" ]; then
  pass "Assert 3 (semantic): lean4 standard ($lean_std) and hard ($lean_hard) resolve to distinct, correctly-declared agents"
else
  fail "Assert 3 (semantic): lean4 standard='$lean_std' hard='$lean_hard' did not match expected lean-research-agent / lean-research-hard-agent"
fi

# =====================================================================
# Assert 4: precedence direction -- a synthetic fixture where a non-core manifest and the core
# manifest both declare the same (op, task_type) confirms the non-core entry wins.
# =====================================================================
echo ""
echo "--- Assert 4: precedence direction (synthetic fixture) ---"

FIXTURE_DIR="$(mktemp -d)"
cleanup_fixture() { [ -n "${FIXTURE_DIR:-}" ] && [ -d "$FIXTURE_DIR" ] && rm -rf "$FIXTURE_DIR"; }
trap cleanup_fixture EXIT

mkdir -p "$FIXTURE_DIR/extensions/core" "$FIXTURE_DIR/extensions/zzz-noncore"
cat > "$FIXTURE_DIR/extensions/core/manifest.json" <<'EOF'
{
  "name": "core",
  "routing_agents": {
    "research": { "zzztest": "core-zzztest-agent" }
  }
}
EOF
cat > "$FIXTURE_DIR/extensions/zzz-noncore/manifest.json" <<'EOF'
{
  "name": "zzz-noncore",
  "routing_agents": {
    "research": { "zzztest": "noncore-zzztest-agent" }
  }
}
EOF

fixture_result=$(
  cd "$REPO_ROOT" && ROUTE_MANIFEST_ROOT="$FIXTURE_DIR" bash -c "
    source '$LIB_SRC'
    routing_lookup 'routing_agents' 'research' 'zzztest'
    echo \"\$_ROUTE_LAST_VALUE|\$_ROUTE_LAST_VIA\"
  "
)
fixture_value="${fixture_result%%|*}"
fixture_via="${fixture_result##*|}"

if [ "$fixture_value" = "noncore-zzztest-agent" ] && [ "$fixture_via" = "noncore-exact" ]; then
  pass "Assert 4: non-core manifest wins over core manifest for an identical (op, task_type) key (via=$fixture_via)"
else
  fail "Assert 4: expected non-core entry 'noncore-zzztest-agent' (via=noncore-exact) to win, got '$fixture_value' (via=$fixture_via)"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "========================================"
echo "Summary"
echo "========================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
  echo "ROUTING RESOLUTION TEST FAILED ($FAILED failures)"
  exit 1
fi
echo "ROUTING RESOLUTION TEST PASSED"
exit 0
