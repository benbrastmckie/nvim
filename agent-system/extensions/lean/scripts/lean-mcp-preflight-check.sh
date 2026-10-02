#!/usr/bin/env bash
# lean-mcp-preflight-check.sh -- WARN-only per-project lean-lsp MCP readiness check: MCP
# registration drift (original scope) PLUS language-server reachability and a dispatch-file
# injection block (--dispatch-block mode).
#
# Invoked two ways:
#
#   1. No-flag mode (original, unchanged byte-for-byte): called directly from Stage 2 (Preflight
#      Status Update) of the lean skills that dispatch to lean-lsp-using agents. Wraps the lean-
#      extension verifier (verify-lean-mcp.sh) into something safe to call on every such dispatch:
#        - Silent and exit 0 when the current directory is not a Lean project.
#        - Silent and exit 0 when this project's OWN .projects[<path>].mcpServers."lean-lsp"
#          entry is correctly registered (the per-project model -- see verify-lean-mcp.sh's
#          header).
#        - One actionable, setup-lean-mcp.sh-naming message on drift -- still exit 0.
#
#   2. `--dispatch-block` mode (new): called unconditionally from
#      orchestrate-build-dispatch.sh for every `/orchestrate` dispatch, gated only by this
#      script's own lakefile detection (never by task_type -- a manifest hooks.preflight
#      registration cannot reach a non-lean4-typed Lean project; see
#      mcp-server-ownership.md). Prints nothing and exits 0 outside a Lean project (byte-
#      identical to a build before this mode existed). Inside a Lean project, prints a complete
#      `<lean-readiness-context>` ... `</lean-readiness-context>` block on stdout naming:
#        - the resolved project root;
#        - the registration result, reusing the SAME single verifier invocation this mode makes
#          (registered / project_path_mismatch / not_registered -- never a second verifier call);
#        - the reachability tier (`reachable` / `not_reachable` / `unknown`), from
#          probe_reachability() below, run ONLY when registration is `registered` (skipped
#          otherwise, to avoid spending the ps/proc cost on a project that cannot be reachable
#          through the registered path anyway -- the not-yet-registered exit stays in the cheap
#          band);
#        - the `index: unavailable` / `warming` / `consulted` three-state interpretation rule
#          for `lean_local_search`, so the reader learns how to read a future tool result rather
#          than only receiving a tier label;
#        - the explicit statement that a live process is NECESSARY but not SUFFICIENT for
#          reachability (a live-but-hung server still reports `reachable` here -- this probe
#          checks process presence and project identity, never responsiveness);
#        - the explicit statement that Lean work without lean-lsp is an accepted degraded mode
#          (compiled probes remain available) the agent should proceed in, announcing its
#          evidence tier, never abort over.
#
# Contract (both modes): WARN, never BLOCK. lean4 work without lean-lsp is an accepted degraded
# mode, so this script must never cause a caller to treat its finding as a dispatch failure. It
# always exits 0.
#
# Reachability detection (probe_reachability, --dispatch-block mode only): one atomic
# `ps -eo pid,ppid,comm,args --no-headers` snapshot; select rows whose `args` contains the
# literal substring `lean-lsp-mcp` (`comm` is useless for this match -- `uvx` does not
# exec-replace, so both the launcher and an unrelated concurrent `mcp-nixos` server show
# `comm=uv`); drop the row whose pid equals `$$` or whose ppid equals `$$` (the self-match guard,
# modeled on lake-build-guard.sh's `is_self_row` idiom -- this script's own `ps` invocation never
# matches the pattern itself, but the guard is cheap insurance against a future self-reference).
# For each surviving candidate, read `/proc/<pid>/environ` (NUL-delimited) for
# `LEAN_PROJECT_PATH` and require an EXACT match against the resolved project root before
# reporting `reachable`. A bare argv match is never sufficient on its own -- see the Risks table
# in this task's plan for the wrong-project-server false positive this guards against.
#
# Three-value result contract: `reachable` (an exact LEAN_PROJECT_PATH match found);
# `not_reachable` (the ps snapshot succeeded, candidates were checked, none matched -- including
# the case where a candidate's args matched but its environ's LEAN_PROJECT_PATH named a
# DIFFERENT project); `unknown` (no /proc on this platform, `ps` itself failed, every candidate's
# environ was unreadable, or registration was not confirmed present so the probe did not run at
# all). `unknown` and an argv-only match are never promoted to `reachable`.
#
# Linux-only caveat: `/proc` is a Linux-specific mechanism. A macOS deploy gets `unknown`
# unconditionally for the reachability tier -- this is the decided, honest degrade path, not a
# defect; `unknown` is always the safe default and is never silently promoted.
#
# Detection-lockstep requirement: the Lean-project pre-check below (lakefile.lean/lakefile.toml
# at CWD or git root) is copied verbatim from verify-lean-mcp.sh's own detection. If that
# detection ever changes, this copy must change with it or the two scripts will silently
# disagree about which directories are Lean projects.
#
# Follow-up (not undertaken here): once the four lean skills that call this script migrate onto
# context/patterns/skill-preflight-flow.md's shared Stage 2+3 block, this script belongs behind a
# manifest hooks.preflight declaration (collapsing four inline call sites into one), the same
# mechanism the nix extension already uses. (This follow-up is independent of --dispatch-block,
# which is called from orchestrate-build-dispatch.sh, not from a manifest hook, precisely because
# hooks.preflight cannot reach a non-lean4 task_type -- see mcp-server-ownership.md.)
#
# Positional args (5, all accepted and ignored -- matches the lifecycle-hook signature other
# preflight scripts take, e.g. nix-preflight.sh, so this script can move to a manifest
# hooks.preflight declaration later without a signature change) PLUS an optional
# `--dispatch-block` flag, which composes with the five positionals in any position:
#   $1 = task_number   $2 = task_type   $3 = task_dir   $4 = session_id   $5 = operation
#
# Measured added wall-clock cost (5-run means, `date +%s%N` deltas around `bash script.sh`,
# this machine, synthetic fixtures under a per-run mktemp HOME):
#   no-flag mode (unchanged): non-Lean early exit ~6ms; correctly-registered Lean project (full
#   9-check verifier run through Check 9, output discarded) ~25ms; drifted Lean project (Check 3
#   fails fast, output captured and filtered) ~20ms.
#   --dispatch-block mode (new): non-Lean early exit ~6ms (identical code path, no new cost);
#   registered Lean project with the reachability probe run (one `ps -eo pid,ppid,comm,args`
#   snapshot plus at most a handful of `/proc/<pid>/environ` reads) ~35ms; not-registered Lean
#   project (probe skipped) ~20ms, unchanged from the no-flag drifted-project band.
# All bands are within the same order of magnitude as the ~30ms verify-lean-mcp.sh --quiet
# baseline and well under the ~100ms budget. No repository walk, no network call, no MCP server
# spawn on any path -- confirmed by inspection: every command reachable from this script and from
# verify-lean-mcp.sh is `test`, `jq`, `ps`, a `/proc` read, `git rev-parse --show-toplevel`, or
# output formatting.

set -euo pipefail

# --- Flag parsing: --dispatch-block composes with the five ignored positional args in any
# position; no getopts needed since this is the only recognized flag. ------------------------
DISPATCH_BLOCK=false
for _arg in "$@"; do
    case "$_arg" in
        --dispatch-block) DISPATCH_BLOCK=true ;;
    esac
done

# Lean-project pre-check: resolve PROJECT_ROOT (empty if this is not a Lean project). Copied
# verbatim in spirit from verify-lean-mcp.sh's own detection -- see the lockstep note above. If
# neither lakefile.lean nor lakefile.toml exists at CWD or at the git root, this is not a Lean
# project -- exit 0 immediately with no output, in either mode.
PROJECT_ROOT=""
if [ -f "lakefile.lean" ] || [ -f "lakefile.toml" ]; then
    PROJECT_ROOT="$(pwd)"
else
    GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$GIT_ROOT" ] && { [ -f "$GIT_ROOT/lakefile.lean" ] || [ -f "$GIT_ROOT/lakefile.toml" ]; }; then
        PROJECT_ROOT="$GIT_ROOT"
    fi
fi

if [ -z "$PROJECT_ROOT" ]; then
    exit 0
fi

VERIFIER=".claude/scripts/verify-lean-mcp.sh"

# A deploy that predates the verifier must not produce noise, in either mode.
if [ ! -x "$VERIFIER" ]; then
    exit 0
fi

# probe_reachability PROJECT_ROOT -- prints "reachable" | "not_reachable" | "unknown" on stdout.
# See the header comment block above for the full contract. Never promotes unknown or an
# argv-only match to reachable.
probe_reachability() {
    local project_root="$1"
    local snapshot

    if [ ! -d /proc ]; then
        echo "unknown"
        return
    fi

    if ! snapshot="$(ps -eo pid,ppid,comm,args --no-headers 2>/dev/null)"; then
        echo "unknown"
        return
    fi

    local found_unreadable=false
    local pid ppid comm args env_path

    while read -r pid ppid comm args; do
        [ -z "$pid" ] && continue
        case "$args" in
            *lean-lsp-mcp*) ;;
            *) continue ;;
        esac
        # Self-match guard, modeled on lake-build-guard.sh's is_self_row idiom.
        if [ "$pid" = "$$" ] || [ "$ppid" = "$$" ]; then
            continue
        fi
        if [ ! -r "/proc/$pid/environ" ]; then
            found_unreadable=true
            continue
        fi
        env_path=""
        env_path="$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | sed -n 's/^LEAN_PROJECT_PATH=//p' | head -n1)" || env_path=""
        if [ -n "$env_path" ] && [ "$env_path" = "$project_root" ]; then
            echo "reachable"
            return
        fi
    done <<< "$snapshot"

    if [ "$found_unreadable" = true ]; then
        echo "unknown"
    else
        echo "not_reachable"
    fi
}

# emit_dispatch_block -- prints the complete <lean-readiness-context> block using the already-
# resolved PROJECT_ROOT, REG_STATUS and TIER.
emit_dispatch_block() {
    cat <<BLOCK_EOF
<lean-readiness-context>
Lean project root: $PROJECT_ROOT
lean-lsp MCP registration: $REG_STATUS
lean-lsp server reachability: $TIER

A live lean-lsp-mcp process is a NECESSARY but not SUFFICIENT condition for reachability: a
live-but-hung server still reports "reachable" here, since this probe checks process presence
and project identity, not responsiveness.

Interpretation rule for lean_local_search's \`index\` field:
  - \`unavailable\` -- no language server is running. An empty result under this state is NOT
    proof of absence; evidence of record degrades to a grep sweep instead of LSP-backed lookup.
  - \`warming\` -- the index is still loading. An empty result under this state is also NOT
    proof of absence.
  - \`consulted\` -- the ONLY state in which an empty result is proof of absence.

Lean work without lean-lsp is an accepted degraded mode (compiled probes remain available).
Proceed, but announce this evidence tier rather than treating a degraded or unavailable index
result as a negative finding.
</lean-readiness-context>
BLOCK_EOF
}

if [ "$DISPATCH_BLOCK" = true ]; then
    rc=0
    "$VERIFIER" --quiet >/dev/null 2>&1 || rc=$?

    case "$rc" in
        0) REG_STATUS="registered" ;;
        2) REG_STATUS="project_path_mismatch" ;;
        *) REG_STATUS="not_registered" ;;
    esac

    if [ "$REG_STATUS" = "registered" ]; then
        TIER="$(probe_reachability "$PROJECT_ROOT")"
    else
        TIER="unknown"
    fi

    emit_dispatch_block
    exit 0
fi

# --- No-flag mode: unchanged byte-for-byte from the original registration-drift wrapper. -------

# Invoke once, non-quiet, capturing stdout+stderr and the exit status without tripping -e.
rc=0
output="$("$VERIFIER" 2>&1)" || rc=$?

if [ "$rc" -eq 0 ]; then
    exit 0
fi

if [ "$rc" -eq 2 ]; then
    echo "[lean-mcp-preflight] lean-lsp currently indexes a different Lean project"
else
    echo "[lean-mcp-preflight] lean-lsp is not registered for this project"
fi

filtered="$(printf '%s\n' "$output" | grep -E '^\[FAIL\]|^\[WARN\]|^Run setup-lean-mcp' || true)"

if [ -n "$filtered" ]; then
    printf '%s\n' "$filtered"
else
    echo "[lean-mcp-preflight] Run setup-lean-mcp.sh to fix lean-lsp MCP registration"
fi

# Contract: WARN, never BLOCK.
exit 0
