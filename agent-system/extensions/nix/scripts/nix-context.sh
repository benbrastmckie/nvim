#!/usr/bin/env bash
# nix-context.sh — Nix extension context injection hook
#
# Called by skill_context_injection() in skill-base.sh before agent delegation.
# Outputs a brief summary of the Nix environment for agents.
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

echo "[nix-context] Nix configuration context:"

# Report nix version if available
if command -v nix &>/dev/null; then
  nix_version=$(nix --version 2>/dev/null || echo "unknown")
  echo "[nix-context]   Nix: $nix_version"
fi

# Report flake inputs if lock file exists
if [ -f "flake.lock" ]; then
  input_count=$(jq '.nodes | keys | length' flake.lock 2>/dev/null || echo "unknown")
  echo "[nix-context]   Flake inputs (locked): $input_count"
fi

exit 0
