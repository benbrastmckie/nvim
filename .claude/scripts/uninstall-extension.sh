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
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLAUDE_DIR="$PROJECT_ROOT/.claude"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Validate arguments
if [ $# -ne 1 ]; then
  echo "Usage: $0 <extension-directory>"
  echo "Example: $0 .claude/extensions/z3"
  exit 1
fi

EXT_DIR="$1"

# Convert to absolute path if relative
if [[ ! "$EXT_DIR" = /* ]]; then
  EXT_DIR="$PROJECT_ROOT/$EXT_DIR"
fi

# Validate extension directory exists
if [ ! -d "$EXT_DIR" ]; then
  log_error "Extension directory not found: $EXT_DIR"
  exit 1
fi

# Validate manifest.json exists
MANIFEST="$EXT_DIR/manifest.json"
if [ ! -f "$MANIFEST" ]; then
  log_error "manifest.json not found in $EXT_DIR"
  exit 1
fi

# Read extension name
EXT_NAME=$(jq -r '.name' "$MANIFEST")
if [ -z "$EXT_NAME" ] || [ "$EXT_NAME" = "null" ]; then
  log_error "Extension name not found in manifest.json"
  exit 1
fi

log_info "Uninstalling extension: $EXT_NAME"

# Function to remove command symlinks
remove_commands() {
  local commands_dir="$EXT_DIR/commands"
  local target_dir="$CLAUDE_DIR/commands"

  if [ ! -d "$commands_dir" ]; then
    log_info "No commands directory found, skipping command symlink removal"
    return 0
  fi

  for cmd in "$commands_dir"/*.md; do
    if [ -f "$cmd" ]; then
      local cmd_name=$(basename "$cmd")
      local target="$target_dir/$cmd_name"

      if [ -L "$target" ]; then
        # Check if symlink points to this extension
        local current_target=$(readlink "$target")
        if [[ "$current_target" == *"$EXT_NAME"* ]]; then
          rm "$target"
          log_info "Removed command symlink: $cmd_name"
        else
          log_warn "Command symlink points elsewhere, not removing: $cmd_name"
        fi
      elif [ -f "$target" ]; then
        log_warn "Command is a file (not a symlink), not removing: $cmd_name"
      else
        log_info "Command symlink not found: $cmd_name"
      fi
    fi
  done
}

# Function to remove skill symlinks
remove_skills() {
  local skills_dir="$EXT_DIR/skills"
  local target_dir="$CLAUDE_DIR/skills"

  if [ ! -d "$skills_dir" ]; then
    log_info "No skills directory found, skipping skill symlink removal"
    return 0
  fi

  for skill in "$skills_dir"/skill-*; do
    if [ -d "$skill" ]; then
      local skill_name=$(basename "$skill")
      local target="$target_dir/$skill_name"

      if [ -L "$target" ]; then
        # Check if symlink points to this extension
        local current_target=$(readlink "$target")
        if [[ "$current_target" == *"$EXT_NAME"* ]]; then
          rm "$target"
          log_info "Removed skill symlink: $skill_name"
        else
          log_warn "Skill symlink points elsewhere, not removing: $skill_name"
        fi
      elif [ -d "$target" ]; then
        log_warn "Skill is a directory (not a symlink), not removing: $skill_name"
      else
        log_info "Skill symlink not found: $skill_name"
      fi
    fi
  done
}

# Function to remove agent symlinks
remove_agents() {
  local agents_dir="$EXT_DIR/agents"
  local target_dir="$CLAUDE_DIR/agents"

  if [ ! -d "$agents_dir" ]; then
    log_info "No agents directory found, skipping agent symlink removal"
    return 0
  fi

  for agent in "$agents_dir"/*.md; do
    if [ -f "$agent" ]; then
      local agent_name=$(basename "$agent")
      local target="$target_dir/$agent_name"

      if [ -L "$target" ]; then
        # Check if symlink points to this extension
        local current_target=$(readlink "$target")
        if [[ "$current_target" == *"$EXT_NAME"* ]]; then
          rm "$target"
          log_info "Removed agent symlink: $agent_name"
        else
          log_warn "Agent symlink points elsewhere, not removing: $agent_name"
        fi
      elif [ -f "$target" ]; then
        log_warn "Agent is a file (not a symlink), not removing: $agent_name"
      else
        log_info "Agent symlink not found: $agent_name"
      fi
    fi
  done
}

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
