#!/usr/bin/env bash
# uninstall-extension.sh - Uninstall a Claude Code extension
#
# Usage: uninstall-extension.sh <extension-directory>
#
# This script reads an extension's manifest.json and reverses installation:
# 1. Removes skill symlinks from .claude/skills/
# 2. Removes agent symlinks from .claude/agents/
# 3. Removes index entries from .claude/context/index.json
#
# Example:
#   bash .claude/scripts/uninstall-extension.sh .claude/extensions/z3

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/extension-install-lib.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
CLAUDE_DIR="$PROJECT_ROOT/.claude"

log_info() { extlib_log_info "$1"; }
log_warn() { extlib_log_warn "$1"; }
log_error() { extlib_log_error "$1"; }

# Validate arguments
if [ $# -ne 1 ]; then
  extlib_usage_and_exit "$0"
fi

EXT_DIR="$(extlib_resolve_ext_dir "$PROJECT_ROOT" "$1")"
EXT_NAME="$(extlib_validate_extension "$EXT_DIR")" || exit 1

log_info "Uninstalling extension: $EXT_NAME"

# Symlink removal for commands/skills/agents: see extlib_remove_symlinks's own header for the
# parameter meaning. Unlike the install side, all three pre-extraction functions here already
# agreed on behavior (always an ownership check before removing), so no quirk-preserving flag
# is needed.
remove_commands() { extlib_remove_symlinks "$EXT_NAME" "$EXT_DIR" "$CLAUDE_DIR/commands" '*.md' 0 command; }
remove_skills() { extlib_remove_symlinks "$EXT_NAME" "$EXT_DIR" "$CLAUDE_DIR/skills" 'skill-*' 1 skill; }
remove_agents() { extlib_remove_symlinks "$EXT_NAME" "$EXT_DIR" "$CLAUDE_DIR/agents" '*.md' 0 agent; }

# Function to remove index entries
remove_index_entries() {
  local index_file="$EXT_DIR/index-entries.json"
  local main_index="$CLAUDE_DIR/context/index.json"

  if [ ! -f "$index_file" ]; then
    log_info "No index-entries.json found, skipping context index cleanup"
    return 0
  fi

  # Get paths from extension's index-entries.json
  local ext_paths
  if jq -e 'type == "array"' "$index_file" > /dev/null 2>&1; then
    # Flat array format
    ext_paths=$(jq -r '.[].path' "$index_file")
  else
    # Object with entries array format
    ext_paths=$(jq -r '.entries[].path' "$index_file")
  fi

  if [ -z "$ext_paths" ]; then
    log_info "No paths found in index-entries.json"
    return 0
  fi

  # Backup main index
  cp "$main_index" "$main_index.bak"

  # Remove entries with matching paths
  # Build a jq filter to exclude these paths
  local path_filter
  path_filter=$(echo "$ext_paths" | jq -R -s 'split("\n") | map(select(length > 0))')

  jq --argjson paths "$path_filter" '
    .entries = [.entries[] | select(.path as $p | $paths | index($p) | not)] |
    .generated = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
  ' "$main_index" > specs/tmp/cleaned-index.json

  # Validate JSON
  if ! jq empty specs/tmp/cleaned-index.json 2>/dev/null; then
    log_error "Cleaned index.json is invalid JSON, restoring backup"
    mv "$main_index.bak" "$main_index"
    return 1
  fi

  # Move cleaned index into place
  mv specs/tmp/cleaned-index.json "$main_index"
  rm -f "$main_index.bak"

  local entry_count
  entry_count=$(jq '.entries | length' "$main_index")
  local removed_count
  removed_count=$(echo "$ext_paths" | wc -l)
  log_info "Removed $removed_count index entries. Remaining entries: $entry_count"
}

# Main uninstallation
remove_commands
remove_skills
remove_agents
remove_index_entries

log_info "Extension '$EXT_NAME' uninstalled successfully"
