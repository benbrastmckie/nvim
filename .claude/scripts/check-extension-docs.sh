#!/usr/bin/env bash
# check-extension-docs.sh
#
# Doc-lint script that iterates .claude/extensions/*/ and flags:
#   - missing README.md
#   - missing EXTENSION.md
#   - missing manifest.json
#   - manifest entries referencing nonexistent files (agents, skills, commands, rules, scripts)
#   - README.md older than manifest.json (potential drift)
#   - commands listed in manifest but not mentioned in README.md
#
# Exit codes:
#   0 - all extensions pass
#   1 - one or more extensions have failures
#
# Usage:
#   bash .claude/scripts/check-extension-docs.sh
#   bash .claude/scripts/check-extension-docs.sh --quiet   (suppress info output)

set -uo pipefail

QUIET=0
if [[ "${1:-}" == "--quiet" ]]; then
  QUIET=1
fi

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
EXT_DIR="${EXT_DIR:-$REPO_ROOT/.claude/extensions}"

if [[ ! -d "$EXT_DIR" ]]; then
  echo "ERROR: $EXT_DIR does not exist" >&2
  exit 1
fi

FAILURES=0
declare -A EXTENSION_STATUS

info() { [[ $QUIET -eq 0 ]] && echo "  $*"; }
fail() {
  echo "  FAIL: $*"
  FAILURES=$((FAILURES + 1))
  EXTENSION_STATUS["$CURRENT_EXT"]="FAIL"
}

check_file() {
  local f="$1"
  local label="$2"
  if [[ ! -f "$f" ]]; then
    fail "$label missing ($f)"
    return 1
  fi
  if [[ ! -s "$f" ]]; then
    fail "$label is empty ($f)"
    return 1
  fi
  return 0
}

check_manifest_entries() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  # agents (file references)
  local agents
  agents=$(jq -r '.provides.agents[]? // empty' "$manifest" 2>/dev/null)
  for a in $agents; do
    if [[ ! -f "$ext_path/agents/$a" ]]; then
      fail "manifest agent entry missing on disk: agents/$a"
    fi
  done

  # skills (directory references with SKILL.md)
  local skills
  skills=$(jq -r '.provides.skills[]? // empty' "$manifest" 2>/dev/null)
  for s in $skills; do
    if [[ ! -f "$ext_path/skills/$s/SKILL.md" ]]; then
      fail "manifest skill entry missing on disk: skills/$s/SKILL.md"
    fi
  done

  # commands (file references)
  local cmds
  cmds=$(jq -r '.provides.commands[]? // empty' "$manifest" 2>/dev/null)
  for c in $cmds; do
    if [[ ! -f "$ext_path/commands/$c" ]]; then
      fail "manifest command entry missing on disk: commands/$c"
    fi
  done

  # rules
  local rules
  rules=$(jq -r '.provides.rules[]? // empty' "$manifest" 2>/dev/null)
  for r in $rules; do
    if [[ ! -f "$ext_path/rules/$r" ]]; then
      fail "manifest rule entry missing on disk: rules/$r"
    fi
  done

  # scripts
  local scripts
  scripts=$(jq -r '.provides.scripts[]? // empty' "$manifest" 2>/dev/null)
  for s in $scripts; do
    if [[ ! -f "$ext_path/scripts/$s" ]]; then
      fail "manifest script entry missing on disk: scripts/$s"
    fi
  done
}

check_routing_block() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  # Skip routing check if extension declares routing_exempt: true
  local routing_exempt
  routing_exempt=$(jq -r '.routing_exempt // false' "$manifest" 2>/dev/null)
  if [[ "$routing_exempt" == "true" ]]; then
    return 0
  fi

  # If manifest declares non-empty provides.skills, verify routing block exists
  local skill_count
  skill_count=$(jq -r '.provides.skills | length' "$manifest" 2>/dev/null)
  if [[ "$skill_count" -gt 0 ]]; then
    local has_routing
    has_routing=$(jq -r 'has("routing")' "$manifest" 2>/dev/null)
    if [[ "$has_routing" == "false" ]]; then
      fail "manifest declares $skill_count skill(s) but has no routing block"
    fi
  fi
}

# Rule A: Undeclared skill dirs in extension source not in provides.skills
check_undeclared_skills() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  [[ -d "$ext_path/skills" ]] || return 0

  for skill_dir in "$ext_path/skills/"/skill-*/; do
    [[ -d "$skill_dir" ]] || continue
    local skill_name
    skill_name=$(basename "$skill_dir")
    if ! jq -e --arg s "$skill_name" '.provides.skills[]? | select(. == $s)' \
        "$manifest" > /dev/null 2>&1; then
      fail "skill dir on disk NOT in provides.skills: $skill_name"
    fi
  done
}

# Rules B + C: Routing target consistency and deployment
#
# Policy rationale (documented per plan Phase 2):
#   Both routing and routing_hard share the same deployment-dimension severity rule:
#     - FAIL if the extension is installed but the target is not deployed
#     - WARN (info) if the extension is not installed (expected undeployed state)
#   routing_hard adds TWO stricter requirements beyond the deployment dimension:
#     1. Source-grounding: the target must exist in some extension's SOURCE provides.skills
#     2. Unconditional-dispatch FAIL: command-route-skill.sh steps 4a-4d scan routing_hard
#        across ALL manifests without an install guard. A routing_hard target that exists
#        in source but is undeployed because its extension is uninstalled is a correctness
#        bug regardless of installation. This is the lean case -- FAIL for routing_hard
#        targets that exist in source but are undeployed.
#   Rule B (resolvability): any routing or routing_hard target that does not exist in any
#   extension's provides.skills AND is not deployed is a FAIL (manifest typo/stale entry).
check_routing_consistency() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  # Determine if this extension is "installed":
  # installed = at least one of its source skills appears in .claude/skills/ OR
  #             at least one of its source agents appears in .claude/agents/
  local installed=0
  if [[ -d "$ext_path/skills" ]]; then
    local sdir
    for sdir in "$ext_path/skills/"/*/; do
      [[ -d "$sdir" ]] || continue
      local sn
      sn=$(basename "$sdir")
      if [[ -d "$REPO_ROOT/.claude/skills/$sn" || -L "$REPO_ROOT/.claude/skills/$sn" ]]; then
        installed=1
        break
      fi
    done
  fi
  if [[ $installed -eq 0 && -d "$ext_path/agents" ]]; then
    local af
    for af in "$ext_path/agents/"*.md; do
      [[ -f "$af" ]] || continue
      local an
      an=$(basename "$af")
      if [[ -f "$REPO_ROOT/.claude/agents/$an" ]]; then
        installed=1
        break
      fi
    done
  fi

  # Helper: check if a skill target is resolvable (in any extension's provides.skills
  # OR deployed under .claude/skills/)
  target_resolvable() {
    local target="$1"
    # Check deployed first (fast path for cross-extension core skills)
    if [[ -d "$REPO_ROOT/.claude/skills/$target" || -L "$REPO_ROOT/.claude/skills/$target" ]]; then
      return 0
    fi
    # Check all extension manifests for provides.skills
    local m
    for m in "$EXT_DIR"/*/manifest.json; do
      [[ -f "$m" ]] || continue
      if jq -e --arg s "$target" '.provides.skills[]? | select(. == $s)' \
          "$m" > /dev/null 2>&1; then
        return 0
      fi
    done
    return 1
  }

  # --- routing targets ---
  local routing_targets
  routing_targets=$(jq -r '.routing // {} | to_entries[] | .value | to_entries[] | .value' \
    "$manifest" 2>/dev/null)
  local t base_t
  for t in $routing_targets; do
    # Routing values may use colon notation (e.g., skill-grant:assemble) where the part
    # before the colon is the actual skill name and the colon suffix is a sub-operation mode.
    # Strip the suffix for skill-resolution purposes.
    base_t="${t%%:*}"
    if [[ ! -d "$REPO_ROOT/.claude/skills/$base_t" && ! -L "$REPO_ROOT/.claude/skills/$base_t" ]]; then
      # Rule B: target not resolvable to any provides.skills and not deployed
      if ! target_resolvable "$base_t"; then
        fail "routing target not resolvable (not in any provides.skills, not deployed): $t"
      elif [[ $installed -eq 1 ]]; then
        # Rule C (routing, installed): deployed dimension violation
        fail "routing target not deployed (extension is installed): $t"
      else
        # Rule C (routing, uninstalled): warn only
        info "WARN: routing target not deployed (extension not installed): $t"
      fi
    fi
  done

  # --- routing_hard targets ---
  local hard_targets
  hard_targets=$(jq -r '.routing_hard // {} | to_entries[] | .value | to_entries[] | .value' \
    "$manifest" 2>/dev/null)
  for t in $hard_targets; do
    # Strip colon sub-operation suffix for skill-resolution (same as routing above)
    base_t="${t%%:*}"
    if [[ ! -d "$REPO_ROOT/.claude/skills/$base_t" && ! -L "$REPO_ROOT/.claude/skills/$base_t" ]]; then
      # Rule B: target not resolvable to any provides.skills and not deployed
      if ! target_resolvable "$base_t"; then
        fail "routing_hard target not resolvable (not in any provides.skills, not deployed): $t"
      elif [[ $installed -eq 1 ]]; then
        # Rule C (routing_hard, installed): deployment violation
        fail "routing_hard target not deployed (extension is installed): $t"
      else
        # Rule C extra for routing_hard (unconditional-dispatch FAIL clause):
        # routing_hard is scanned by command-route-skill.sh with no install guard --
        # a source-grounded but undeployed routing_hard target is a live correctness bug.
        fail "routing_hard target declared but not deployed (and extension not installed): $t"
      fi
    fi
  done
}

# Rule D: Deployed skills must reference agents that exist
check_deployed_skill_agents() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  local skills
  skills=$(jq -r '.provides.skills[]? // empty' "$manifest" 2>/dev/null)
  local s
  for s in $skills; do
    local deployed_skill="$REPO_ROOT/.claude/skills/$s/SKILL.md"
    [[ -f "$deployed_skill" ]] || continue  # not deployed, skip

    # Extract subagent_type from SKILL.md body
    local agent_name
    agent_name=$(grep -o 'subagent_type: "[^"]*"' "$deployed_skill" 2>/dev/null \
      | head -1 | cut -d'"' -f2)
    [[ -z "$agent_name" ]] && continue      # direct-execution skill, no agent
    [[ "$agent_name" == "fork" ]] && continue  # fork pattern, not a named agent file

    if [[ ! -f "$REPO_ROOT/.claude/agents/${agent_name}.md" ]]; then
      fail "deployed skill $s references agent $agent_name NOT in .claude/agents/"
    fi
  done
}

check_readme_vs_manifest() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"
  local readme="$ext_path/README.md"

  # Compare mtimes: warn if README older than manifest (possible drift)
  if [[ -f "$readme" && -f "$manifest" ]]; then
    local readme_mtime manifest_mtime
    readme_mtime=$(stat -c %Y "$readme" 2>/dev/null || stat -f %m "$readme")
    manifest_mtime=$(stat -c %Y "$manifest" 2>/dev/null || stat -f %m "$manifest")
    if [[ "$readme_mtime" -lt "$manifest_mtime" ]]; then
      info "WARN: README.md older than manifest.json (possible drift)"
    fi
  fi

  # Commands listed in manifest must be mentioned in README.md
  if [[ -f "$readme" ]]; then
    local cmds
    cmds=$(jq -r '.provides.commands[]? // empty' "$manifest" 2>/dev/null)
    for c in $cmds; do
      local cmd_name="${c%.md}"
      if ! grep -q "/$cmd_name" "$readme"; then
        fail "command /$cmd_name listed in manifest but not mentioned in README.md"
      fi
    done
  fi
}

echo "Checking .claude/extensions/ documentation..."
echo

for ext_path in "$EXT_DIR"/*/; do
  ext_name=$(basename "$ext_path")
  CURRENT_EXT="$ext_name"
  EXTENSION_STATUS["$ext_name"]="PASS"

  echo "[$ext_name]"

  # Required files
  check_file "$ext_path/manifest.json" "manifest.json"
  check_file "$ext_path/EXTENSION.md" "EXTENSION.md"
  check_file "$ext_path/README.md" "README.md"

  # Manifest entry validation (only if manifest exists and is valid)
  if [[ -f "$ext_path/manifest.json" ]]; then
    if jq empty "$ext_path/manifest.json" 2>/dev/null; then
      check_manifest_entries "$ext_path"
      check_routing_block "$ext_path"
      check_undeclared_skills "$ext_path"
      check_routing_consistency "$ext_path"
      check_deployed_skill_agents "$ext_path"
      check_readme_vs_manifest "$ext_path"
    else
      fail "manifest.json is not valid JSON"
    fi
  fi

  if [[ "${EXTENSION_STATUS[$ext_name]}" == "PASS" ]]; then
    info "OK"
  fi
  echo
done

# Summary table
echo "====================================="
echo "Summary"
echo "====================================="
printf "%-15s %s\n" "Extension" "Status"
printf "%-15s %s\n" "---------" "------"
for ext in "${!EXTENSION_STATUS[@]}"; do
  printf "%-15s %s\n" "$ext" "${EXTENSION_STATUS[$ext]}"
done | sort
echo

if [[ "$FAILURES" -gt 0 ]]; then
  echo "FAIL: $FAILURES issue(s) found"
  exit 1
else
  echo "PASS: all extensions OK"
  exit 0
fi
