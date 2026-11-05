#!/usr/bin/env bash
# extension-install-lib.sh - Shared helpers for install-extension.sh / uninstall-extension.sh.
#
# Those two scripts are a mutual duplicate-block pair: 35 duplicate 10-line sliding-window hits
# each against the other (script-inventory.sh). The shared surface is the argument/EXT_DIR/
# manifest validation preamble and the colored log-line trio -- every byte of each script up to
# (but not including) its own first install/uninstall-specific function. This library extracts
# exactly that preamble so it has one definition, sourced from both call sites, rather than two.
#
# Sourced only, never executed directly. Requires the caller to have already sourced
# lib/common.sh and set PROJECT_ROOT (for extlib_resolve_ext_dir) -- this library does not
# duplicate that bootstrap, matching common.sh's own "SCRIPT_DIR bootstrap stays inline at each
# consumer" convention.
#
# Usage (both call sites, identical):
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/lib/common.sh"
#   source "${SCRIPT_DIR}/lib/extension-install-lib.sh"
#   PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
#   . "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
#   CLAUDE_DIR="$PROJECT_ROOT/.claude"
#
#   if [ $# -ne 1 ]; then extlib_usage_and_exit "$0"; fi
#   EXT_DIR="$(extlib_resolve_ext_dir "$PROJECT_ROOT" "$1")"
#   EXT_NAME="$(extlib_validate_extension "$EXT_DIR")" || exit 1

# Colors for output -- unchanged from the pair's own pre-extraction literals.
EXTLIB_RED='\033[0;31m'
EXTLIB_GREEN='\033[0;32m'
EXTLIB_YELLOW='\033[0;33m'
EXTLIB_NC='\033[0m'

extlib_log_info() {
  echo -e "${EXTLIB_GREEN}[INFO]${EXTLIB_NC} $1"
}

extlib_log_warn() {
  echo -e "${EXTLIB_YELLOW}[WARN]${EXTLIB_NC} $1"
}

extlib_log_error() {
  echo -e "${EXTLIB_RED}[ERROR]${EXTLIB_NC} $1" >&2
}

# extlib_usage_and_exit <script-path> -- prints the pair's shared usage/example lines and
# exits 1. Callers use "$0" so the printed usage names the actual invoked script.
extlib_usage_and_exit() {
  local script_name="$1"
  echo "Usage: $script_name <extension-directory>"
  echo "Example: $script_name .claude/extensions/z3"
  exit 1
}

# extlib_resolve_ext_dir <project-root> <raw-arg> -- echoes the absolute extension directory:
# the raw argument unchanged if already absolute, else joined onto project-root.
extlib_resolve_ext_dir() {
  local project_root="$1"
  local ext_dir="$2"
  if [[ ! "$ext_dir" = /* ]]; then
    ext_dir="$project_root/$ext_dir"
  fi
  echo "$ext_dir"
}

# extlib_validate_extension <ext-dir> -- validates the extension directory and its
# manifest.json exist and carry a non-null .name, then echoes that name. Exits 1 (via
# extlib_log_error) on any validation failure, matching the pair's pre-extraction behavior
# exactly (same messages, same exit code, same stderr/stdout split).
extlib_validate_extension() {
  local ext_dir="$1"

  if [ ! -d "$ext_dir" ]; then
    extlib_log_error "Extension directory not found: $ext_dir"
    exit 1
  fi

  local manifest="$ext_dir/manifest.json"
  if [ ! -f "$manifest" ]; then
    extlib_log_error "manifest.json not found in $ext_dir"
    exit 1
  fi

  local ext_name
  ext_name=$(jq -r '.name' "$manifest")
  if [ -z "$ext_name" ] || [ "$ext_name" = "null" ]; then
    extlib_log_error "Extension name not found in manifest.json"
    exit 1
  fi

  echo "$ext_name"
}

# extlib_install_symlinks <ext-name> <ext-dir> <target-dir> <glob-pattern> <is-dir:0|1>
#   <label> <check-target:0|1>
#
# The install-side loop body install_commands/install_skills/install_agents each hand-rolled
# (3 near-identical copies inside install-extension.sh, each also duplicated against its
# uninstall-extension.sh counterpart). Parameterized across the three callers:
#   - <glob-pattern> is the item glob under "<ext-dir>/<label>s" ('*.md' or 'skill-*').
#   - <is-dir> selects a directory-vs-regular-file existence test (skills are directories).
#   - <check-target> preserves a genuine pre-extraction behavioral difference: install_commands
#     and install_skills verify an existing symlink still points at the expected target (and
#     warn if it points elsewhere); install_agents never did this check. Passing 0 for the
#     agents call site reproduces that exact (lenient) behavior rather than silently tightening
#     it -- this extraction changes no caller's observable output.
#
# Message shapes match the three pre-extraction functions byte-for-byte: "No <label>s directory
# found, skipping <label> symlinks", "<Label> symlink already exists: NAME", "<Label> symlink
# exists but points elsewhere: NAME" (check-target callers only), "<Label> file|directory exists
# (not a symlink): NAME", "Created <label> symlink: NAME -> REL_PATH".
extlib_install_symlinks() {
  local ext_name="$1" ext_dir="$2" target_dir="$3" glob_pattern="$4" is_dir="$5" label="$6" check_target="$7"
  local source_subdir="${label}s"
  local src_dir="$ext_dir/$source_subdir"
  local label_cap="${label^}"
  local kind_noun="file"
  [ "$is_dir" = "1" ] && kind_noun="directory"

  if [ ! -d "$src_dir" ]; then
    extlib_log_info "No $source_subdir directory found, skipping $label symlinks"
    return 0
  fi

  local item
  # shellcheck disable=SC2231 # deliberate unquoted glob suffix, matching the pre-extraction loops
  for item in "$src_dir"/$glob_pattern; do
    if { [ "$is_dir" = "1" ] && [ -d "$item" ]; } || { [ "$is_dir" != "1" ] && [ -f "$item" ]; }; then
      local item_name target rel_path
      item_name=$(basename "$item")
      target="$target_dir/$item_name"
      rel_path="../../agent-system/extensions/$ext_name/$source_subdir/$item_name"

      if [ -L "$target" ]; then
        if [ "$check_target" = "1" ]; then
          local current_target
          current_target=$(readlink "$target")
          if [ "$current_target" = "$rel_path" ]; then
            extlib_log_info "$label_cap symlink already exists: $item_name"
          else
            extlib_log_warn "$label_cap symlink exists but points elsewhere: $item_name"
          fi
        else
          extlib_log_info "$label_cap symlink already exists: $item_name"
        fi
      elif [ -e "$target" ]; then
        extlib_log_warn "$label_cap $kind_noun exists (not a symlink): $item_name"
      else
        ln -s "$rel_path" "$target"
        extlib_log_info "Created $label symlink: $item_name -> $rel_path"
      fi
    fi
  done
}

# extlib_remove_symlinks <ext-name> <ext-dir> <target-dir> <glob-pattern> <is-dir:0|1> <label>
#
# The uninstall-side analogue of extlib_install_symlinks -- remove_commands/remove_skills/
# remove_agents were already consistent with each other (unlike their install-side
# counterparts), so no check-target parameter is needed here: all three always verify
# ownership (the existing symlink's target string contains <ext-name>) before removing.
#
# Message shapes match the three pre-extraction functions byte-for-byte: "No <label>s directory
# found, skipping <label> symlink removal", "Removed <label> symlink: NAME", "<Label> symlink
# points elsewhere, not removing: NAME", "<Label> is a file|directory (not a symlink), not
# removing: NAME", "<Label> symlink not found: NAME".
extlib_remove_symlinks() {
  local ext_name="$1" ext_dir="$2" target_dir="$3" glob_pattern="$4" is_dir="$5" label="$6"
  local source_subdir="${label}s"
  local src_dir="$ext_dir/$source_subdir"
  local label_cap="${label^}"
  local kind_noun="file"
  [ "$is_dir" = "1" ] && kind_noun="directory"

  if [ ! -d "$src_dir" ]; then
    extlib_log_info "No $source_subdir directory found, skipping $label symlink removal"
    return 0
  fi

  local item
  # shellcheck disable=SC2231 # deliberate unquoted glob suffix, matching the pre-extraction loops
  for item in "$src_dir"/$glob_pattern; do
    if { [ "$is_dir" = "1" ] && [ -d "$item" ]; } || { [ "$is_dir" != "1" ] && [ -f "$item" ]; }; then
      local item_name target
      item_name=$(basename "$item")
      target="$target_dir/$item_name"

      if [ -L "$target" ]; then
        local current_target
        current_target=$(readlink "$target")
        if [[ "$current_target" == *"$ext_name"* ]]; then
          rm "$target"
          extlib_log_info "Removed $label symlink: $item_name"
        else
          extlib_log_warn "$label_cap symlink points elsewhere, not removing: $item_name"
        fi
      elif [ -e "$target" ]; then
        extlib_log_warn "$label_cap is a $kind_noun (not a symlink), not removing: $item_name"
      else
        extlib_log_info "$label_cap symlink not found: $item_name"
      fi
    fi
  done
}
