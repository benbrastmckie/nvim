#!/usr/bin/env bash
# Check vault threshold - outputs status for both vault-needed and vault-not-needed cases
# Returns: exit 0 for normal, exit 1 for vault threshold exceeded
#
# CRITICAL: This script produces UNCONDITIONAL output to force model attention.
# Both "vault needed" and "vault not needed" cases output a status message.

set -euo pipefail

# Determine PROJECT_ROOT
if [[ -n "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT="$PROJECT_ROOT"
elif [[ -f "specs/state.json" ]]; then
    PROJECT_ROOT="."
elif [[ -f "../specs/state.json" ]]; then
    PROJECT_ROOT=".."
else
    echo "ERROR: Cannot find specs/state.json - unable to check vault threshold"
    exit 2
fi

STATE_FILE="${PROJECT_ROOT}/specs/state.json"
VAULT_THRESHOLD=1000

# Read next_project_number from state.json
if [[ ! -f "$STATE_FILE" ]]; then
    echo "ERROR: State file not found: $STATE_FILE"
    exit 2
fi

next_num=$(jq -r '.next_project_number // 0' "$STATE_FILE")

if [[ -z "$next_num" || "$next_num" == "null" ]]; then
    echo "ERROR: next_project_number not found in $STATE_FILE"
    exit 2
fi

# UNCONDITIONAL OUTPUT - always prints status message
if [[ "$next_num" -gt "$VAULT_THRESHOLD" ]]; then
    echo ""
    echo "=============================================="
    echo "  VAULT THRESHOLD EXCEEDED"
    echo "=============================================="
    echo "  next_project_number: $next_num"
    echo "  threshold: $VAULT_THRESHOLD"
    echo "  status: VAULT OPERATION REQUIRED"
    echo "=============================================="
    echo ""
    echo "Proceeding to vault confirmation (sub-step 9.1)..."
    exit 1
else
    echo ""
    echo "Vault check: next_project_number=$next_num (threshold: $VAULT_THRESHOLD) - OK"
    echo ""
    exit 0
fi
