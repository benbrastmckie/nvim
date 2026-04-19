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

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXT_DIR="$REPO_ROOT/.claude/extensions"

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

# Core purity check: detect nvim/neovim/VimTeX references in non-nvim extension sources
check_core_purity() {
  echo "[core-purity]"
  local purity_failures=0

  # Whitelist: files that legitimately contain the search terms
  local whitelist=(
    "lint-postflight-boundary.sh"
    "postflight-tool-restrictions.md"
    "extensions/core/README.md"
    "extensions/latex/README.md"
    "check-extension-docs.sh"
    "settings.local.json"
  )

  # Build grep exclusion args
  local grep_exclude=""
  for w in "${whitelist[@]}"; do
    grep_exclude="$grep_exclude --exclude=*${w##*/}"
  done

  # Search non-nvim extension directories
  local matches
  matches=$(grep -riE 'nvim|neovim|neotex|vimtex' \
    "$EXT_DIR/core/" \
    "$EXT_DIR/latex/" \
    "$EXT_DIR/memory/" \
    "$EXT_DIR/typst/" \
    --include='*.md' --include='*.sh' --include='*.json' \
    2>/dev/null | \
    grep -v 'extensions/core/README.md' | \
    grep -v 'extensions/latex/README.md' | \
    grep -v 'lint-postflight-boundary.sh' | \
    grep -v 'postflight-tool-restrictions.md' | \
    grep -v 'extensions/nvim/' | \
    grep -v 'context/project/neovim/' | \
    grep -v 'check-extension-docs.sh' | \
    grep -v 'settings.local.json' || true)

  if [[ -n "$matches" ]]; then
    while IFS= read -r line; do
      CURRENT_EXT="core-purity"
      fail "stale nvim reference: $line"
      purity_failures=$((purity_failures + 1))
    done <<< "$matches"
  else
    info "OK - no stale nvim/neovim/VimTeX references in non-nvim extensions"
  fi
  echo
}

check_core_purity

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
