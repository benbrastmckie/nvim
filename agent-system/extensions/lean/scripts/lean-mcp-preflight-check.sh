#!/usr/bin/env bash
# lean-mcp-preflight-check.sh -- WARN-only lean-lsp MCP registration drift check
#
# Invoked directly from Stage 2 (Preflight Status Update) of the lean skills that dispatch to
# lean-lsp-using agents. It wraps the existing core verifier (verify-lean-mcp.sh) into something
# safe to call on every such dispatch:
#
#   - Silent and exit 0 when the current directory is not a Lean project.
#   - Silent and exit 0 when lean-lsp registration is correct.
#   - One actionable, setup-lean-mcp.sh-naming message on drift -- still exit 0.
#
# Contract: WARN, never BLOCK. lean4 work without lean-lsp is an accepted degraded mode
# (compiled probes remain available), so this script must never cause a caller to treat its
# non-zero-verifier-exit finding as a dispatch failure. It always exits 0 itself.
#
# Detection-lockstep requirement: the Lean-project pre-check below (lakefile.lean/lakefile.toml
# at CWD or git root) is copied verbatim from verify-lean-mcp.sh's own detection. If that
# detection ever changes, this copy must change with it or the two scripts will silently
# disagree about which directories are Lean projects.
#
# Follow-up (not undertaken here): once the four lean skills that call this script migrate onto
# context/patterns/skill-preflight-flow.md's shared Stage 2+3 block, this script belongs behind a
# manifest hooks.preflight declaration (collapsing four inline call sites into one), the same
# mechanism the nix extension already uses.
#
# Positional args (5, all accepted and ignored -- matches the lifecycle-hook signature other
# preflight scripts take, e.g. nix-preflight.sh, so this script can move to a manifest
# hooks.preflight declaration later without a signature change):
#   $1 = task_number   $2 = task_type   $3 = task_dir   $4 = session_id   $5 = operation
#
# Measured added wall-clock cost (5-run means, this machine): non-Lean early exit ~3ms;
# correctly-registered Lean project (full verifier run, output discarded) ~31ms; drifted Lean
# project (full verifier run plus message synthesis) ~32ms. No repository walk, no network call,
# no MCP server spawn on any path.

set -euo pipefail

# Lean-project pre-check first: if neither lakefile.lean nor lakefile.toml exists at CWD or at
# the git root, this is not a Lean project -- exit 0 immediately with no output. Copied verbatim
# from verify-lean-mcp.sh's own detection; see the lockstep note above.
if [ ! -f "lakefile.lean" ] && [ ! -f "lakefile.toml" ]; then
    GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -z "$GIT_ROOT" ] || { [ ! -f "$GIT_ROOT/lakefile.lean" ] && [ ! -f "$GIT_ROOT/lakefile.toml" ]; }; then
        exit 0
    fi
fi

VERIFIER=".claude/scripts/verify-lean-mcp.sh"

# A deploy that predates the verifier must not produce noise.
if [ ! -x "$VERIFIER" ]; then
    exit 0
fi

# Invoke once, non-quiet, capturing stdout+stderr and the exit status without tripping -e.
rc=0
output="$("$VERIFIER" 2>&1)" || rc=$?

if [ "$rc" -eq 0 ]; then
    exit 0
fi

if [ "$rc" -eq 2 ]; then
    echo "[lean-mcp-preflight] lean-lsp currently indexes a different Lean project"
else
    echo "[lean-mcp-preflight] lean-lsp MCP registration does not match the sanctioned form"
fi

filtered="$(printf '%s\n' "$output" | grep -E '^\[FAIL\]|^\[WARN\]|^Run setup-lean-mcp' || true)"

if [ -n "$filtered" ]; then
    printf '%s\n' "$filtered"
else
    echo "[lean-mcp-preflight] Run setup-lean-mcp.sh to fix lean-lsp MCP registration"
fi

# Contract: WARN, never BLOCK.
exit 0
