#!/usr/bin/env bash
# nvim-context.sh — Neovim extension context injection hook
#
# Called by skill_context_injection() in skill-base.sh before agent delegation.
# Outputs a brief summary of the Neovim configuration environment for agents.
#
# Positional args (5 required):
#   $1 = task_number   $2 = task_type   $3 = task_dir   $4 = session_id   $5 = operation

set -euo pipefail

# shellcheck disable=SC2034  # These 5 positional args are part of skill_run_extension_hook's
# documented, stable calling contract (skill-base.sh) shared by every extension's context
# hook -- this particular hook reports static environment info and does not need any of them,
# but the parameter slots are kept for interface parity with sibling hooks that do.
TASK_NUMBER="${1:-}"
# shellcheck disable=SC2034
TASK_TYPE="${2:-}"
# shellcheck disable=SC2034
TASK_DIR="${3:-}"
# shellcheck disable=SC2034
SESSION_ID="${4:-}"
# shellcheck disable=SC2034
OPERATION="${5:-}"

# Output context summary to stdout (captured by skill-base.sh)
echo "[nvim-context] Neovim configuration context:"

# Report lazy.nvim plugin count if available
if [ -f "lazy-lock.json" ]; then
  plugin_count=$(jq 'keys | length' lazy-lock.json 2>/dev/null || echo "unknown")
  echo "[nvim-context]   Plugins locked: $plugin_count"
fi

# Report neovim version if available
if command -v nvim &>/dev/null; then
  nvim_version=$(nvim --version 2>/dev/null | head -1 || echo "unknown")
  echo "[nvim-context]   Neovim: $nvim_version"
fi

exit 0
