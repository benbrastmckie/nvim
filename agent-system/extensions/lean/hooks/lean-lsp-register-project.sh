#!/usr/bin/env bash
# lean-lsp-register-project.sh -- SessionStart hook: automatic per-project lean-lsp registration
#
# Fires on every session start (matcher "startup"). Detects whether the session's CWD is a Lean
# project (lakefile.lean/lakefile.toml at CWD or git root -- copied verbatim from
# setup-lean-mcp.sh/verify-lean-mcp.sh's own detection; keep the three in lockstep) and, if so,
# invokes the writer (setup-lean-mcp.sh --scope project --quiet) to register or repair this
# project's OWN .projects[<path>].mcpServers."lean-lsp" entry in ~/.claude.json.
#
# Zero manual steps: this is what makes a freshly created worktree (e.g. a PR review checkout
# with no .claude/ deploy at all) correct on first use, per the task this hook was built for.
#
# Stable-path invariant (D5 / mcp-server-ownership.md's ".claude/-path boundary" invariant):
# this hook, once installed, is invoked from ~/.claude/hooks/lean-lsp-register-project.sh -- a
# stable, user-level, non-repository path -- and it in turn resolves the WRITER
# (setup-lean-mcp.sh) from an equally stable user-level path, ~/.claude/scripts/setup-lean-mcp.sh
# (installed alongside this hook by install-lean-lsp-session-hook.sh), NEVER from the calling
# repository's own (possibly nonexistent) .claude/ tree. This is required, not merely tidy: the
# acceptance case is a repository with NO .claude/ deploy at all, so a repo-relative resolution
# would silently do nothing there.
#
# Session-start snapshot trap (measured empirically -- see the per-project lean-lsp registration
# task's Phase 1 progress record): a SessionStart hook's own write is NOT reliably visible within
# the SAME session that performed it -- the MCP tool registry snapshot is taken independently of
# hook execution. So whenever this hook actually WRITES (registers or repairs an entry), it emits
# an `additionalContext` notice naming the project and asking for a restart if the tool is not yet
# available; when the entry already matched (the common, steady-state case), it stays completely
# silent, matching the WARN-never-BLOCK, silent-on-success contract every other lean hook/wrapper
# in this extension follows (see lean-mcp-preflight-check.sh).
#
# Contract: always exits 0; always emits exactly one line of valid JSON ({} or
# {"additionalContext": "..."}) on stdout; never fails the session even if $HOME/.claude.json is
# unwritable, jq is missing, or the writer errors -- every failure path below degrades to a
# silent {}, never to non-JSON noise that could break the harness hook contract.

set -uo pipefail

# Lean-project detection, verbatim-identical to setup-lean-mcp.sh / verify-lean-mcp.sh /
# lean-mcp-preflight-check.sh's own copies. If this ever changes, change all four together.
GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -f "lakefile.lean" ] || [ -f "lakefile.toml" ]; then
    PROJECT_PATH="$(pwd)"
elif [ -n "$GIT_ROOT" ] && { [ -f "$GIT_ROOT/lakefile.lean" ] || [ -f "$GIT_ROOT/lakefile.toml" ]; }; then
    PROJECT_PATH="$GIT_ROOT"
else
    # Not a Lean project: silent, exit 0.
    echo '{}'
    exit 0
fi

WRITER="$HOME/.claude/scripts/setup-lean-mcp.sh"

if [ ! -f "$WRITER" ]; then
    # Not installed yet (installer has not run, or was --remove'd): silent, exit 0. Never noisy
    # about the hook's own installation state -- that is the installer's job to report, not this
    # per-session hook's.
    echo '{}'
    exit 0
fi

WRITE_OUTPUT="$(bash "$WRITER" --project "$PROJECT_PATH" --scope project --quiet 2>&1)"
WRITER_RC=$?

if [ "$WRITER_RC" -ne 0 ] || [ -z "$WRITE_OUTPUT" ]; then
    # Either the writer failed (degrade silently -- a SessionStart hook must never surface a
    # scary error on every session start for a transient jq/disk issue) or it was a no-op
    # (entry already correct, the steady-state case): silent, exit 0.
    echo '{}'
    exit 0
fi

# The writer wrote something (registered or repaired the entry). Per the session-start snapshot
# trap above, tell the session so a failed lean-lsp call in THIS session is understood rather
# than mistaken for a deeper bug.
NOTICE="lean-lsp: registered/repaired the per-project entry for $PROJECT_PATH. If a lean-lsp tool call in this session reports the file as not found in any Lean project, restart the session -- MCP server registration is snapshotted at session start, and a just-written entry is not guaranteed to be visible in the session that wrote it."

if command -v jq > /dev/null 2>&1; then
    printf '%s' "$NOTICE" | jq -Rs '{additionalContext: .}' 2>/dev/null || echo '{}'
else
    # No jq available (should not happen in this repo's environment, but degrade to silent
    # rather than risk emitting malformed JSON via hand escaping).
    echo '{}'
fi

exit 0
