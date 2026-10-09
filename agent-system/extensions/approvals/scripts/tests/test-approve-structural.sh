#!/usr/bin/env bash
# test-approve-structural.sh - Structural regression fixture for the no-self-approval and
# no-delegation properties: the skill declares AskUserQuestion and never Agent, carries no
# agent: frontmatter field, no line anywhere pairs --record with --agent, the skill states its
# own no-agent-fallback explicitly, the orchestrator_mode stop is present, and every authored
# file under this extension appears in manifest.json's provides.*.
#
# IMPORTANT -- WHAT THIS FIXTURE DOES AND DOES NOT PROVE: this is a shell script. It cannot
# itself invoke AskUserQuestion or the Agent tool, so it CANNOT re-verify the underlying harness
# fact that AskUserQuestion is withheld from a dispatched subagent -- that measurement lives in
# the settled investigation this task's dispatch cites (askuserquestion_unreachable_in_subagents)
# and can only be re-confirmed by a live dispatch probe. This fixture only protects the
# STRUCTURE built against that settled fact: no agent file instructs itself to call the
# withheld tool, the prompting lives where the tool works, and the documentation's own claims
# agree with the measurement. A green run here is NOT a harness re-verification; do not read it
# as one. Modeled directly on test-askuserquestion-rehome.sh's own honesty header.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
fi

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

EXT_SOURCE_STORE="$REPO_ROOT/agent-system/extensions/approvals"
EXT_DEPLOYED_ROOT="$REPO_ROOT/.claude"

if [[ -d "$EXT_SOURCE_STORE" ]]; then
  EXT_ROOT="$EXT_SOURCE_STORE"
  SCAN_MODE="source-store"
  MANIFEST="$EXT_ROOT/manifest.json"
  SKILL_FILE="$EXT_ROOT/skills/skill-approve/SKILL.md"
  COMMAND_FILE="$EXT_ROOT/commands/approve.md"
else
  EXT_ROOT="$EXT_DEPLOYED_ROOT"
  SCAN_MODE="deployed (flat)"
  MANIFEST=""
  SKILL_FILE="$EXT_ROOT/skills/skill-approve/SKILL.md"
  COMMAND_FILE="$EXT_ROOT/commands/approve.md"
fi

info "scan mode: $SCAN_MODE"

if [[ ! -f "$SKILL_FILE" ]]; then
  echo "ERROR: SKILL.md not found at $SKILL_FILE" >&2
  exit 2
fi
if [[ ! -f "$COMMAND_FILE" ]]; then
  echo "ERROR: approve.md not found at $COMMAND_FILE" >&2
  exit 2
fi

# --- Case 1: allowed-tools carries AskUserQuestion, never Agent -------------------------
allowed_tools_line="$(grep -m1 '^allowed-tools:' "$SKILL_FILE")"
if grep -q "AskUserQuestion" <<< "$allowed_tools_line"; then
  pass "skill-approve declares AskUserQuestion in allowed-tools"
else
  fail "skill-approve does not declare AskUserQuestion in allowed-tools: $allowed_tools_line"
fi
if grep -Eq '(^| )Agent(,|$)' <<< "$allowed_tools_line"; then
  fail "skill-approve declares Agent in allowed-tools -- this must never be present: $allowed_tools_line"
else
  pass "skill-approve does not declare Agent in allowed-tools"
fi

# --- Case 2: no agent: frontmatter field -------------------------------------------------
if grep -q '^agent:' "$SKILL_FILE"; then
  fail "skill-approve carries an 'agent:' frontmatter field -- this must never be present"
else
  pass "skill-approve carries no 'agent:' frontmatter field"
fi

# --- Case 3: no line anywhere pairs --record with --agent -------------------------------
pairing_found=0
for f in "$SKILL_FILE" "$COMMAND_FILE"; do
  if grep -n -- '--record' "$f" | grep -q -- '--agent'; then
    pairing_found=1
    fail "a line in $f pairs --record with --agent"
  fi
done
if [[ "$pairing_found" -eq 0 ]]; then
  pass "no line in skill-approve or approve.md pairs --record with --agent"
fi

# --- Case 4: explicit no-agent-fallback statement ----------------------------------------
if grep -qi "no fallback" "$SKILL_FILE" && grep -qi "records the agent as approver" "$SKILL_FILE"; then
  pass "skill-approve states explicitly that there is no fallback that records the agent as approver"
else
  fail "skill-approve does not carry the explicit no-agent-fallback statement"
fi

# --- Case 5: orchestrator_mode stop is present -------------------------------------------
if grep -q "orchestrator_mode" "$SKILL_FILE"; then
  pass "skill-approve checks orchestrator_mode and stops for an autonomous dispatch"
else
  fail "skill-approve does not mention orchestrator_mode anywhere"
fi

# --- Case 6: every authored file under the extension appears in manifest.json's provides.* -
if [[ -n "$MANIFEST" && -f "$MANIFEST" ]]; then
  manifest_ok=1

  check_declared() {
    local kind="$1" path="$2" rel
    rel="$(basename "$path")"
    if ! jq -e --arg v "$rel" --arg kind "$kind" '.provides[$kind] // [] | index($v) != null' "$MANIFEST" >/dev/null 2>&1; then
      fail "manifest.json provides.$kind does not declare $rel"
      manifest_ok=0
    fi
  }
  check_declared "commands" "$COMMAND_FILE"

  skill_dir_name="$(basename "$(dirname "$SKILL_FILE")")"
  if ! jq -e --arg v "$skill_dir_name" '.provides.skills // [] | index($v) != null' "$MANIFEST" >/dev/null 2>&1; then
    fail "manifest.json provides.skills does not declare $skill_dir_name"
    manifest_ok=0
  fi

  while IFS= read -r script_file; do
    [[ -z "$script_file" ]] && continue
    rel="$(basename "$script_file")"
    if ! jq -e --arg v "$rel" '.provides.scripts // [] | index($v) != null' "$MANIFEST" >/dev/null 2>&1; then
      fail "manifest.json provides.scripts does not declare $rel"
      manifest_ok=0
    fi
  done < <(find "$EXT_ROOT/scripts" -maxdepth 1 -name '*.sh' -type f 2>/dev/null)

  if [[ "$manifest_ok" -eq 1 ]]; then
    pass "every authored command/skill/top-level script appears in manifest.json's provides.*"
  fi
else
  info "[SKIP] manifest.json cross-check: not available in deployed-flat scan mode"
fi

echo
echo "=== test-approve-structural.sh: $PASSED passed, $FAILED failed ==="
[[ "$FAILED" -eq 0 ]]
