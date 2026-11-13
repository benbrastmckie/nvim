#!/usr/bin/env bash
# sapience-mcp-register-project.sh -- SessionStart hook: automatic per-project sapience
# registration/removal, bidirectional.
#
# Fires on every session start. Detects whether the session's repo has the sapience extension
# ACTIVE (`.claude-extensions.json` at CWD or at the git root shows
# `.extensions.sapience.status == "active"` -- the Sapience analogue of lean's lakefile test;
# keep this detection in lockstep with verify-sapience-mcp.sh's own copy) and, if so, invokes the
# writer (setup-sapience-mcp.sh --scope project --quiet) to register or repair this project's OWN
# .projects[<path>].mcpServers.sapience entry in ~/.claude.json. If the extension is NOT active
# and a project-scoped entry already exists, the writer is invoked with --remove instead --
# this bidirectionality is the only mechanism that can un-register the per-project entry once
# the extension is unloaded, since the merge engine governs only in-tree merge targets, never
# ~/.claude.json.
#
# Zero manual steps: this is what makes a freshly created worktree (e.g. a PR review checkout
# with no .claude/ deploy at all) correct on first use.
#
# Stable-path invariant (mcp-server-ownership.md's ".claude/"-path boundary): this hook, once
# installed, is invoked from ~/.claude/hooks/sapience-mcp-register-project.sh -- a stable,
# user-level, non-repository path -- and it in turn resolves the WRITER (setup-sapience-mcp.sh)
# from an equally stable user-level path, ~/.claude/scripts/setup-sapience-mcp.sh (installed
# alongside this hook by install-sapience-mcp-session-hook.sh), NEVER from the calling
# repository's own (possibly nonexistent) .claude/ tree. This is required, not merely tidy: the
# acceptance case is a repository with NO .claude/ deploy at all, so a repo-relative resolution
# would silently do nothing there.
#
# Session-start snapshot trap (mirrors lean's lean-lsp-register-project.sh): a SessionStart
# hook's own write is NOT reliably visible within the SAME session that performed it -- the MCP
# tool registry snapshot is taken independently of hook execution. So whenever this hook
# actually WRITES or REMOVES an entry, it emits an `additionalContext` notice naming the project
# and the action taken; when nothing changed (the common, steady-state case), it stays
# completely silent, matching lean's WARN-never-BLOCK, silent-on-success contract.
#
# One-session-start removal lag (Risk 6 in this extension's domain docs): unloading the
# extension does not retroactively remove the per-project ~/.claude.json entry until the next
# session start in that repo. install-sapience-mcp-session-hook.sh --remove covers the
# immediate case.
#
# Contract: always exits 0; always emits exactly one line of valid JSON ({} or
# {"additionalContext": "..."}) on stdout; never fails the session even if $HOME/.claude.json is
# unwritable, jq is missing, or the writer errors -- every failure path below degrades to a
# silent {}, never to non-JSON noise that could break the harness hook contract.

set -uo pipefail

# Project-root / activation detection. Keep in lockstep with verify-sapience-mcp.sh's own copy.
GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"

if [ -f ".claude-extensions.json" ]; then
    PROJECT_PATH="$(pwd)"
    EXTENSIONS_FILE="$(pwd)/.claude-extensions.json"
elif [ -n "$GIT_ROOT" ] && [ -f "$GIT_ROOT/.claude-extensions.json" ]; then
    PROJECT_PATH="$GIT_ROOT"
    EXTENSIONS_FILE="$GIT_ROOT/.claude-extensions.json"
else
    # No .claude-extensions.json reachable at all: cannot determine activation. Silent, exit 0.
    echo '{}'
    exit 0
fi

if ! command -v jq > /dev/null 2>&1; then
    # No jq available: cannot read activation status or emit safe JSON. Silent, exit 0.
    echo '{}'
    exit 0
fi

SAPIENCE_STATUS="$(jq -r '.extensions.sapience.status // empty' "$EXTENSIONS_FILE" 2>/dev/null || echo "")"
IS_ACTIVE=false
if [ "$SAPIENCE_STATUS" = "active" ]; then
    IS_ACTIVE=true
fi

WRITER="$HOME/.claude/scripts/setup-sapience-mcp.sh"

if [ ! -f "$WRITER" ]; then
    # Not installed yet (installer has not run, or was --remove'd): silent, exit 0. Never noisy
    # about the hook's own installation state -- that is the installer's job to report, not this
    # per-session hook's.
    echo '{}'
    exit 0
fi

CLAUDE_CONFIG="$HOME/.claude.json"
HAS_EXISTING_ENTRY=false
if [ -f "$CLAUDE_CONFIG" ]; then
    EXISTING="$(jq -c --arg path "$PROJECT_PATH" '.projects[$path].mcpServers.sapience // empty' "$CLAUDE_CONFIG" 2>/dev/null || echo "")"
    if [ -n "$EXISTING" ] && [ "$EXISTING" != "null" ]; then
        HAS_EXISTING_ENTRY=true
    fi
fi

if $IS_ACTIVE; then
    WRITE_OUTPUT="$(bash "$WRITER" --project "$PROJECT_PATH" --scope project --quiet 2>&1)"
    WRITER_RC=$?
    ACTION="registered/repaired"
else
    if ! $HAS_EXISTING_ENTRY; then
        # Inactive, and nothing to remove: silent, exit 0. The common steady-state case for a
        # repo that has never loaded sapience at all.
        echo '{}'
        exit 0
    fi
    WRITE_OUTPUT="$(bash "$WRITER" --project "$PROJECT_PATH" --scope project --remove --quiet 2>&1)"
    WRITER_RC=$?
    ACTION="removed"
fi

if [ "$WRITER_RC" -ne 0 ] || [ -z "$WRITE_OUTPUT" ]; then
    # Either the writer failed (degrade silently -- a SessionStart hook must never surface a
    # scary error on every session start for a transient jq/disk issue) or it was a no-op
    # (entry already correct/already absent, the steady-state case): silent, exit 0.
    echo '{}'
    exit 0
fi

# The writer wrote something (registered, repaired, or removed the entry). Per the session-start
# snapshot trap, tell the session so a sapience MCP call in THIS session is understood rather
# than mistaken for a deeper bug.
NOTICE="sapience: ${ACTION} the per-project entry for $PROJECT_PATH. If a sapience MCP tool call in this session reports the server as unavailable, restart the session -- MCP server registration is snapshotted at session start, and a just-written entry is not guaranteed to be visible in the session that wrote it."

printf '%s' "$NOTICE" | jq -cRs '{additionalContext: .}' 2>/dev/null || echo '{}'

exit 0
