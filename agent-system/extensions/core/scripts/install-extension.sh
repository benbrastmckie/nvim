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

log_info "Installing extension: $EXT_NAME"

# Symlink creation for commands/skills/agents: see extlib_install_symlinks's own header for the
# parameter meaning, in particular why the agents call passes check-target=0 (install_agents
# never verified an existing symlink's target before this extraction, and that lenient behavior
# is preserved rather than silently tightened).
install_commands() { extlib_install_symlinks "$EXT_NAME" "$EXT_DIR" "$CLAUDE_DIR/commands" '*.md' 0 command 1; }
install_skills() { extlib_install_symlinks "$EXT_NAME" "$EXT_DIR" "$CLAUDE_DIR/skills" 'skill-*' 1 skill 1; }
install_agents() { extlib_install_symlinks "$EXT_NAME" "$EXT_DIR" "$CLAUDE_DIR/agents" '*.md' 0 agent 0; }

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
