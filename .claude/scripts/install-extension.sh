#!/usr/bin/env bash
# install-extension.sh - Install a Claude Code extension
#
# Usage: install-extension.sh <extension-directory>
#
# This script reads an extension's manifest.json and performs:
# 1. Merges index-entries.json into main .claude/context/index.json
# 2. Creates symlinks for skills from extension to .claude/skills/
# 3. Creates symlinks for agents from extension to .claude/agents/
# 4. Validates the result
#
# Example:
#   bash .claude/scripts/install-extension.sh .claude/extensions/z3

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

log_info "Installing extension: $EXT_NAME"

# Function to create symlinks for commands
install_commands() {
  local commands_dir="$EXT_DIR/commands"
  local target_dir="$CLAUDE_DIR/commands"

  if [ ! -d "$commands_dir" ]; then
    log_info "No commands directory found, skipping command symlinks"
    return 0
  fi

  for cmd in "$commands_dir"/*.md; do
    if [ -f "$cmd" ]; then
      local cmd_name=$(basename "$cmd")
      local target="$target_dir/$cmd_name"

      if [ -L "$target" ]; then
        # Already a symlink, check if it points to the right place
        local current_target=$(readlink "$target")
        local expected_target="../extensions/$EXT_NAME/commands/$cmd_name"
        if [ "$current_target" = "$expected_target" ]; then
          log_info "Command symlink already exists: $cmd_name"
        else
          log_warn "Command symlink exists but points elsewhere: $cmd_name"
        fi
      elif [ -f "$target" ]; then
        log_warn "Command file exists (not a symlink): $cmd_name"
      else
        # Create symlink
        local rel_path="../extensions/$EXT_NAME/commands/$cmd_name"
        ln -s "$rel_path" "$target"
        log_info "Created command symlink: $cmd_name -> $rel_path"
      fi
    fi
  done
}

# Function to create symlinks for skills
install_skills() {
  local skills_dir="$EXT_DIR/skills"
  local target_dir="$CLAUDE_DIR/skills"

  if [ ! -d "$skills_dir" ]; then
    log_info "No skills directory found, skipping skill symlinks"
    return 0
  fi

  for skill in "$skills_dir"/skill-*; do
    if [ -d "$skill" ]; then
      local skill_name=$(basename "$skill")
      local target="$target_dir/$skill_name"

      if [ -L "$target" ]; then
        # Already a symlink, check if it points to the right place
        local current_target=$(readlink "$target")
        local expected_target="../extensions/$EXT_NAME/skills/$skill_name"
        if [ "$current_target" = "$expected_target" ]; then
          log_info "Skill symlink already exists: $skill_name"
        else
          log_warn "Skill symlink exists but points elsewhere: $skill_name"
        fi
      elif [ -d "$target" ]; then
        log_warn "Skill directory exists (not a symlink): $skill_name"
      else
        # Create symlink
        local rel_path="../extensions/$EXT_NAME/skills/$skill_name"
        ln -s "$rel_path" "$target"
        log_info "Created skill symlink: $skill_name -> $rel_path"
      fi
    fi
  done
}

# Function to create symlinks for agents
install_agents() {
  local agents_dir="$EXT_DIR/agents"
  local target_dir="$CLAUDE_DIR/agents"

  if [ ! -d "$agents_dir" ]; then
    log_info "No agents directory found, skipping agent symlinks"
    return 0
  fi

  for agent in "$agents_dir"/*.md; do
    if [ -f "$agent" ]; then
      local agent_name=$(basename "$agent")
      local target="$target_dir/$agent_name"

      if [ -L "$target" ]; then
        log_info "Agent symlink already exists: $agent_name"
      elif [ -f "$target" ]; then
        log_warn "Agent file exists (not a symlink): $agent_name"
      else
        # Create symlink
        local rel_path="../extensions/$EXT_NAME/agents/$agent_name"
        ln -s "$rel_path" "$target"
        log_info "Created agent symlink: $agent_name -> $rel_path"
      fi
    fi
  done
}

# Function to merge index entries
merge_index_entries() {
  local index_file="$EXT_DIR/index-entries.json"
  local main_index="$CLAUDE_DIR/context/index.json"

  if [ ! -f "$index_file" ]; then
    log_info "No index-entries.json found, skipping context index merge"
    return 0
  fi

  # Backup main index
  cp "$main_index" "$main_index.bak"

  # Detect schema format (flat array vs object with entries)
  local is_flat_array
  if jq -e 'type == "array"' "$index_file" > /dev/null 2>&1; then
    is_flat_array=true
  else
    is_flat_array=false
  fi

  # Get existing paths to check for duplicates
  local existing_paths
  existing_paths=$(jq -r '.entries[].path' "$main_index" | sort)

  # Merge entries
  if [ "$is_flat_array" = true ]; then
    # Flat array format (nix, web)
    jq --slurpfile ext "$index_file" --arg ext_name "$EXT_NAME" '
      .entries += ($ext[0] | map({
        path: .path,
        domain: "project",
        subdomain: $ext_name,
        topics: [],
        keywords: [],
        summary: (.description // ""),
        line_count: (.line_count // 100),
        load_when: .load_when
      })) | .generated = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
    ' "$main_index" > specs/tmp/merged-index.json
  else
    # Object with entries array format (z3, python, formal)
    jq --slurpfile ext "$index_file" --arg ext_name "$EXT_NAME" '
      .entries += ($ext[0].entries | map({
        path: .path,
        domain: "project",
        subdomain: (.category // $ext_name),
        topics: ((.tags // .load_when.topics) // []),
        keywords: (.tags // []),
        summary: ((.description // .summary) // ""),
        line_count: (.line_count // 100),
        load_when: {
          agents: (.load_when.agents // []),
          task_types: (.load_when.task_types // [])
        }
      })) | .generated = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
    ' "$main_index" > specs/tmp/merged-index.json
  fi

  # Validate JSON
  if ! jq empty specs/tmp/merged-index.json 2>/dev/null; then
    log_error "Merged index.json is invalid JSON, restoring backup"
    mv "$main_index.bak" "$main_index"
    return 1
  fi

  # Check for duplicates
  local new_paths
  new_paths=$(jq -r '.entries[].path' specs/tmp/merged-index.json | sort)
  local duplicates
  duplicates=$(echo "$new_paths" | uniq -d)

  if [ -n "$duplicates" ]; then
    log_warn "Duplicate paths detected (entries already exist):"
    echo "$duplicates"
    log_info "Skipping duplicate entries..."

    # Remove duplicates by keeping only unique paths
    jq 'reduce .entries[] as $entry (
      {seen: {}, result: []};
      if .seen[$entry.path] then . else
        .seen[$entry.path] = true | .result += [$entry]
      end
    ) | {version: .version, generated: .generated, entries: .result}' \
      specs/tmp/merged-index.json > specs/tmp/deduped-index.json
    mv specs/tmp/deduped-index.json specs/tmp/merged-index.json
  fi

  # Move merged index into place
  mv specs/tmp/merged-index.json "$main_index"
  rm -f "$main_index.bak"

  local entry_count
  entry_count=$(jq '.entries | length' "$main_index")
  log_info "Merged index entries. Total entries: $entry_count"
}

# Function to validate index after merge
validate_index() {
  local main_index="$CLAUDE_DIR/context/index.json"
  local validation_script="$SCRIPT_DIR/validate-index.sh"

  if [ -x "$validation_script" ]; then
    log_info "Validating merged index..."
    if "$validation_script" "$main_index" > /dev/null 2>&1; then
      log_info "Index validation passed"
    else
      log_warn "Index validation completed with warnings (check output above)"
    fi
  else
    log_info "Validation script not found, skipping validation"
  fi
}

# Main installation
install_commands
install_skills
install_agents
merge_index_entries
validate_index

log_info "Extension '$EXT_NAME' installed successfully"
