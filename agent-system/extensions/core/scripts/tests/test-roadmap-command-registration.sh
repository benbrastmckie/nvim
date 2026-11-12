#!/usr/bin/env bash
# test-roadmap-command-registration.sh - Structural registration suite for the /roadmap
# command/skill/agent trio: existence, manifest.json registration, agent frontmatter validity,
# the new entry-template index entry, and the two claudemd.md table rows.
#
# Structural model: test-validate-state.sh (pass()/fail() counters via common_test_pass/fail,
# source-store-first resolution via common_test_resolve_subject/common_test_repo_root).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 2
fi

PASSED=0
FAILED=0

# This suite is always source-store-scoped: the trio's own files live under the source store
# (agent-system/extensions/core/**), and registration is checked against the source store's own
# manifest.json/index-entries.json/merge-sources/claudemd.md -- never the deployed .claude/
# mirror, which may not yet reflect this round's edits.
CORE_EXT_ROOT="$REPO_ROOT/agent-system/extensions/core"
if [[ ! -d "$CORE_EXT_ROOT" ]]; then
  echo "ERROR: source-store core extension root not found at $CORE_EXT_ROOT" >&2
  exit 2
fi

COMMAND_FILE="$CORE_EXT_ROOT/commands/roadmap.md"
AGENT_FILE="$CORE_EXT_ROOT/agents/roadmap-agent.md"
SKILL_FILE="$CORE_EXT_ROOT/skills/skill-roadmap/SKILL.md"
MANIFEST_FILE="$CORE_EXT_ROOT/manifest.json"
INDEX_FILE="$CORE_EXT_ROOT/index-entries.json"
CLAUDEMD_FILE="$CORE_EXT_ROOT/merge-sources/claudemd.md"

# --- 1. The three files exist ---
for pair in "command_file:$COMMAND_FILE" "agent_file:$AGENT_FILE" "skill_file:$SKILL_FILE"; do
  label="${pair%%:*}"
  path="${pair#*:}"
  if [[ -f "$path" ]]; then
    common_test_pass "$label exists: ${path#"$REPO_ROOT"/}"
  else
    common_test_fail "$label MISSING: ${path#"$REPO_ROOT"/}"
  fi
done

# --- 2. Each listed in manifest.json's matching provides array ---
if [[ -f "$MANIFEST_FILE" ]]; then
  if jq -e '.provides.commands | index("roadmap.md")' "$MANIFEST_FILE" >/dev/null 2>&1; then
    common_test_pass "manifest.json provides.commands lists roadmap.md"
  else
    common_test_fail "manifest.json provides.commands does NOT list roadmap.md"
  fi
  if jq -e '.provides.agents | index("roadmap-agent.md")' "$MANIFEST_FILE" >/dev/null 2>&1; then
    common_test_pass "manifest.json provides.agents lists roadmap-agent.md"
  else
    common_test_fail "manifest.json provides.agents does NOT list roadmap-agent.md"
  fi
  if jq -e '.provides.skills | index("skill-roadmap")' "$MANIFEST_FILE" >/dev/null 2>&1; then
    common_test_pass "manifest.json provides.skills lists skill-roadmap"
  else
    common_test_fail "manifest.json provides.skills does NOT list skill-roadmap"
  fi
  if jq -e '.provides.scripts | index("tests/test-roadmap-command-registration.sh")' "$MANIFEST_FILE" >/dev/null 2>&1; then
    common_test_pass "manifest.json provides.scripts lists this suite itself"
  else
    common_test_fail "manifest.json provides.scripts does NOT list tests/test-roadmap-command-registration.sh"
  fi
else
  common_test_fail "manifest.json not found at ${MANIFEST_FILE#"$REPO_ROOT"/}"
fi

# --- 3. Agent frontmatter carries a valid model: and no forbidden key ---
if [[ -f "$AGENT_FILE" ]]; then
  fm="$(awk 'NR==1{next} /^---$/{exit} {print}' "$AGENT_FILE")"
  model_value="$(grep -E '^model:' <<<"$fm" | head -n1 | sed -E 's/^model:[[:space:]]*//')"
  case "$model_value" in
    opus|sonnet|haiku)
      common_test_pass "roadmap-agent.md frontmatter model: is valid ($model_value)"
      ;;
    *)
      common_test_fail "roadmap-agent.md frontmatter model: '$model_value' is not one of opus|sonnet|haiku"
      ;;
  esac
  if grep -qE '^(allowed-tools|mcp-servers):' <<<"$fm"; then
    common_test_fail "roadmap-agent.md frontmatter carries a forbidden key (allowed-tools:/mcp-servers:)"
  else
    common_test_pass "roadmap-agent.md frontmatter carries no forbidden key"
  fi
  if grep -qE '^name:[[:space:]]*roadmap-agent$' <<<"$fm"; then
    common_test_pass "roadmap-agent.md frontmatter name: matches roadmap-agent"
  else
    common_test_fail "roadmap-agent.md frontmatter name: does not match roadmap-agent"
  fi
else
  common_test_fail "cannot check agent frontmatter: $AGENT_FILE not found"
fi

# --- 4. The index entry for the new template resolves ---
if [[ -f "$INDEX_FILE" ]]; then
  if jq -e '.entries[] | select(.path == "formats/roadmap-entry-template.md")' "$INDEX_FILE" >/dev/null 2>&1; then
    common_test_pass "index-entries.json carries an entry for formats/roadmap-entry-template.md"
    declared_lc="$(jq -r '.entries[] | select(.path == "formats/roadmap-entry-template.md") | .line_count' "$INDEX_FILE")"
    actual_lc="$(wc -l < "$CORE_EXT_ROOT/context/formats/roadmap-entry-template.md" | tr -d ' ')"
    if [[ "$declared_lc" == "$actual_lc" ]]; then
      common_test_pass "roadmap-entry-template.md's declared line_count ($declared_lc) matches wc -l"
    else
      common_test_fail "roadmap-entry-template.md's declared line_count ($declared_lc) does not match wc -l ($actual_lc)"
    fi
  else
    common_test_fail "index-entries.json has NO entry for formats/roadmap-entry-template.md"
  fi
else
  common_test_fail "index-entries.json not found at ${INDEX_FILE#"$REPO_ROOT"/}"
fi

# --- 5. Both claudemd.md tables carry a /roadmap row ---
if [[ -f "$CLAUDEMD_FILE" ]]; then
  if grep -qE '^\| `/roadmap` \|' "$CLAUDEMD_FILE"; then
    common_test_pass "claudemd.md Command Reference table carries a /roadmap row"
  else
    common_test_fail "claudemd.md Command Reference table is MISSING a /roadmap row"
  fi
  if grep -qE '^\| skill-roadmap \| roadmap-agent \|' "$CLAUDEMD_FILE"; then
    common_test_pass "claudemd.md Skill-to-Agent Mapping table carries the skill-roadmap | roadmap-agent row"
  else
    common_test_fail "claudemd.md Skill-to-Agent Mapping table is MISSING the skill-roadmap | roadmap-agent row"
  fi
else
  common_test_fail "merge-sources/claudemd.md not found at ${CLAUDEMD_FILE#"$REPO_ROOT"/}"
fi

echo
echo "Results: $PASSED passed, $FAILED failed"
if [[ "$FAILED" -eq 0 ]]; then
  exit 0
else
  exit 1
fi
