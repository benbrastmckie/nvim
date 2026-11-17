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
# Reap pass (runs first, ungated): the bidirectional register/remove logic above is gated on
# resolving THIS session's own .claude-extensions.json, a precondition an orphaned (deleted or
# renamed) project directory can never again satisfy -- its removal branch can only ever fire
# for a path that still exists AND still carries a manifest showing sapience inactive. The only
# session that can ever clean up after a vanished repo is therefore some OTHER, still-living
# session, which is why this hook invokes `setup-sapience-mcp.sh --reap` unconditionally, before
# and independent of the manifest-reachability branch below, on every session start in every
# repository. The `jq`-present and writer-exists guards are hoisted above that branch for the
# same reason: the reap pass depends on both and must still run when no manifest is reachable at
# all.
#
# Contract: always exits 0; always emits exactly one line of valid JSON ({} or
# {"additionalContext": "..."}) on stdout; never fails the session even if $HOME/.claude.json is
# unwritable, jq is missing, or the writer errors -- every failure path below degrades to a
# silent {}, never to non-JSON noise that could break the harness hook contract. This holds
# whether zero, one, or both of the reap pass and the per-repo half have something to report:
# notices are assembled into an array and joined into exactly one JSON line.

set -uo pipefail

# === BEGIN sapience-worktree-checkout-resolution (byte-identical in every copy: this hook,
# verify-sapience-mcp.sh, sapience-retrieve.sh, sapience-remember.sh, and
# verify-sapience-context-scoping.sh -- test-sapience-mcp-registration.sh's lockstep case
# extracts this marker-delimited block from each copy and asserts they are all byte-identical).
# Resolves a directory (default: cwd) to its git toplevel, following a linked worktree to its
# PARENT CHECKOUT rather than the worktree itself. Echoes the toplevel path and returns 0, or
# returns 1 with no output when the directory is not inside a git repository at all.
#
# Detection: compare `git rev-parse --git-dir` against `--git-common-dir`. Equal (including
# both failing, on a non-git path) means "not a linked worktree -- behave exactly like a bare
# `git rev-parse --show-toplevel`". Unequal means "linked worktree -- the common dir's PARENT
# directory is the checkout". `--git-common-dir` returns a relative path at a checkout root but
# an absolute path from inside a worktree, so it is absolutized before its parent is taken.
resolve_checkout_toplevel() {
    local dir="${1:-.}" git_dir common_dir
    git_dir="$(git -C "$dir" rev-parse --git-dir 2>/dev/null)" || return 1
    common_dir="$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null)" || return 1
    if [ "$git_dir" = "$common_dir" ]; then
        git -C "$dir" rev-parse --show-toplevel 2>/dev/null
        return $?
    fi
    case "$common_dir" in
        /*) : ;;
        *) common_dir="$(cd "$dir" 2>/dev/null && pwd)/$common_dir" ;;
    esac
    (cd "$common_dir/.." 2>/dev/null && pwd)
}
# === END sapience-worktree-checkout-resolution ===

# Preconditions common to BOTH halves below (the reap pass and the per-repo register/remove
# half): a working jq, and an installed writer. Hoisted above the manifest-reachability branch
# -- unlike the pre-reap version of this hook, which gated both guards on a reachable
# .claude-extensions.json -- because the reap pass depends on both and must still run when no
# manifest is reachable at all; that is exactly the previously-unreachable path this phase
# closes.
if ! command -v jq > /dev/null 2>&1; then
    # No jq available: cannot reap, cannot read activation status, cannot emit any JSON beyond a
    # literal {}. Silent, exit 0.
    echo '{}'
    exit 0
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
NOTICES=()

# --- Reap pass: ungated, cross-project, runs on every session start regardless of THIS
# session's own repo's manifest reachability or activation state (see the header comment above
# for the full rationale). A nonzero exit or empty output -- nothing to reap, or a transient
# failure -- degrades silently, exactly like every writer invocation in the per-repo half below.
REAP_OUTPUT="$(bash "$WRITER" --reap --quiet 2>&1)"
REAP_RC=$?
if [ "$REAP_RC" -eq 0 ] && [ -n "$REAP_OUTPUT" ]; then
    NOTICES+=("sapience: reaped one or more orphaned per-project entries whose project directory no longer exists on disk.")
fi

# Project-root / activation detection for the per-repo half. The git root resolved below is the
# PARENT CHECKOUT for a linked worktree (never the worktree itself); registration is keyed on
# the checkout exclusively. Keep in lockstep with verify-sapience-mcp.sh's own copy (see the
# marker block above).
GIT_ROOT="$(resolve_checkout_toplevel 2>/dev/null || true)"

HAVE_PROJECT=false
PROJECT_PATH=""
EXTENSIONS_FILE=""
if [ -f ".claude-extensions.json" ]; then
    PROJECT_PATH="$(pwd)"
    EXTENSIONS_FILE="$(pwd)/.claude-extensions.json"
    HAVE_PROJECT=true
elif [ -n "$GIT_ROOT" ] && [ -f "$GIT_ROOT/.claude-extensions.json" ]; then
    PROJECT_PATH="$GIT_ROOT"
    EXTENSIONS_FILE="$GIT_ROOT/.claude-extensions.json"
    HAVE_PROJECT=true
fi
# No .claude-extensions.json reachable at all: HAVE_PROJECT stays false and the per-repo half
# below contributes no notice -- this is no longer an early exit (the reap pass above may
# already have something to report, and either way exactly one JSON line is still emitted at
# the end of this script).

if $HAVE_PROJECT; then
    SAPIENCE_STATUS="$(jq -r '.extensions.sapience.status // empty' "$EXTENSIONS_FILE" 2>/dev/null || echo "")"
    IS_ACTIVE=false
    if [ "$SAPIENCE_STATUS" = "active" ]; then
        IS_ACTIVE=true
    fi

    HAS_EXISTING_ENTRY=false
    if [ -f "$CLAUDE_CONFIG" ]; then
        EXISTING="$(jq -c --arg path "$PROJECT_PATH" '.projects[$path].mcpServers.sapience // empty' "$CLAUDE_CONFIG" 2>/dev/null || echo "")"
        if [ -n "$EXISTING" ] && [ "$EXISTING" != "null" ]; then
            HAS_EXISTING_ENTRY=true
        fi
    fi

    WRITE_OUTPUT=""
    WRITER_RC=0
    ACTION=""
    if $IS_ACTIVE; then
        WRITE_OUTPUT="$(bash "$WRITER" --project "$PROJECT_PATH" --scope project --quiet 2>&1)"
        WRITER_RC=$?
        ACTION="registered/repaired"
    elif $HAS_EXISTING_ENTRY; then
        # Inactive, but an entry exists: remove it. This is the only mechanism that can
        # un-register the per-project entry once the extension is unloaded.
        WRITE_OUTPUT="$(bash "$WRITER" --project "$PROJECT_PATH" --scope project --remove --quiet 2>&1)"
        WRITER_RC=$?
        ACTION="removed"
    fi
    # Inactive with no existing entry: WRITE_OUTPUT/ACTION stay empty -- the common steady-state
    # case for a repo that has never loaded sapience at all. This no longer exits early; it
    # simply contributes no notice below, exactly like a no-op write does.

    if [ "$WRITER_RC" -eq 0 ] && [ -n "$WRITE_OUTPUT" ]; then
        # The writer wrote something (registered, repaired, or removed the entry). Per the
        # session-start snapshot trap, tell the session so a sapience MCP call in THIS session
        # is understood rather than mistaken for a deeper bug.
        NOTICES+=("sapience: ${ACTION} the per-project entry for $PROJECT_PATH. If a sapience MCP tool call in this session reports the server as unavailable, restart the session -- MCP server registration is snapshotted at session start, and a just-written entry is not guaranteed to be visible in the session that wrote it.")
    fi
    # A nonzero WRITER_RC (writer failed) or empty WRITE_OUTPUT (no-op: entry already
    # correct/already absent) degrades silently -- a SessionStart hook must never surface a
    # scary error on every session start for a transient jq/disk issue.
fi

# Notice assembly: emit {} when neither half had anything to report, or exactly one
# {"additionalContext": "..."} line joining whichever of the reap notice and the per-repo notice
# fired (either, both, or neither) -- so the always-exit-0 / exactly-one-JSON-line contract holds
# regardless of which half(s) had something to say.
if [ "${#NOTICES[@]}" -eq 0 ]; then
    echo '{}'
    exit 0
fi

printf '%s\n' "${NOTICES[@]}" | jq -cRs '{additionalContext: .}' 2>/dev/null || echo '{}'

exit 0
