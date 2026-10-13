#!/usr/bin/env bash
# check-deploy-freshness.sh — Non-blocking, always-exit-0 check for whether a repo's deployed
# .claude/ tree still matches the source store it was regenerated from.
#
# ALWAYS EXITS 0. This is not a preflight gate: it never changes an admission decision, never
# aborts, retries, or auto-redeploys anything. Its two sanctioned consumers: (1)
# command-gate-in.sh's CHECKPOINT 1, which invokes it as
# `bash .claude/scripts/check-deploy-freshness.sh ... 2>&1 || true` for exactly that reason, and
# (2) scripts/lib/deploy-freshness-lib.sh, the shared comparison library this script sources
# below — its own second exported function (`deploy_freshness_status`) is the blocking companion
# tier described in `context/patterns/regeneration-is-manual-only.md`'s "Detecting When You're
# Stale" section (tier 2: `update-task-status.sh`'s postflight backstop). This script itself
# remains tier 1: silent, advisory, CHECKPOINT-1-only, never a gate.
# MUST be run with `bash`, never sourced — it sets no shell options safe to inherit into a
# caller's shell, and exports nothing a caller could rely on.
#
# Reads <repo_root>/.claude-extensions.json (default repo_root: current directory). For each
# extension entry recording BOTH `source_dir` and `source_git_head`, recomputes the path-scoped
# source-store revision the same way the Lua write side does (state.lua's
# `resolve_source_git_head`: resolve the enclosing repo root via `git rev-parse --show-toplevel`,
# then `git log -1 --format=%H -- <source_dir>`). A mismatch between the recorded and recomputed
# revision prints one WARN line to stderr naming the extension and the regeneration remedy. The
# actual per-extension comparison is delegated to scripts/lib/deploy-freshness-lib.sh
# (`deploy_freshness_stale_names`) — this script owns only the WARN line text/formatting and its
# always-exit-0 contract; it does not re-derive the comparison algorithm inline.
#
# Deliberately SILENT (no output at all, not even a summary line) in every "cannot verify" case
# — "unknown" must not read as either "confirmed fresh" or an alarm:
#   - missing or unparseable .claude-extensions.json
#   - an entry missing `source_dir` or `source_git_head` (every pre-fix deploy)
#   - `source_dir` does not exist on disk
#   - `source_dir` is not inside a git repository
#   - `git` or `jq` is unavailable
#   - the recomputed revision is empty
#
# This is the shallow, preflight-cheap companion to verify-deploy.sh (11 content-diffing gates,
# deliberately NOT preflight-cheap): one path-scoped `git log -1` per extension, safe to run on
# every ordinary command.
#
# --- Consecutive-ignore escalation (TIER 1 remains non-blocking; this is presentation only) ---
# A per-repo WARN nobody acts on is not functioning as a warning. This script tracks a
# consecutive-invocation streak counter at <repo_root>/specs/.freshness-warn-streak.json
# (ephemeral runtime file — see context/standards/orchestrator-runtime-files.md's class table):
# incremented each time this script fires at least one WARN, reset (file deleted) the moment a
# run fires none. At streak >= 5, an additional escalated banner is printed (on top of, never
# instead of, the existing per-extension WARN lines) naming the consecutive count and the
# remedy. Below the threshold, output is byte-identical to before this feature existed. The
# counter is a consecutive COMMAND-INVOCATION count, not wall-clock days, since this check only
# ever fires on an invocation. A CANNOTVERIFY result also resets the counter — this script's
# STALE_NAMES already deliberately collapses FRESH and CANNOTVERIFY into the same silence (see
# the "Deliberately SILENT" block above), and the streak counter inherits that same collapse
# rather than introducing a third distinction. All counter I/O is best-effort and silently
# skipped when <repo_root>/specs/ does not exist, is not writable, or jq is unavailable — this
# script's `set -uo pipefail` / always-`exit 0` contract is never put at risk by it.
#
# Usage: bash check-deploy-freshness.sh [repo_root]
# Exit code: always 0.

set -uo pipefail  # deliberately NOT -e: every step degrades to a silent skip, never an abort

REPO_ROOT="${1:-$(pwd)}"

FRESHNESS_STREAK_THRESHOLD=5
FRESHNESS_STREAK_CAP=999
FRESHNESS_STREAK_FILE="${REPO_ROOT}/specs/.freshness-warn-streak.json"

# --- Shared freshness comparison library ---
# Sibling lookup off this script's OWN location (not off REPO_ROOT, which names the repo being
# CHECKED — a different, unrelated directory from the one this script itself is deployed or
# source-stored in). This resolves correctly whether this script is running from the deployed
# tree (.claude/scripts/check-deploy-freshness.sh, lib sibling at
# .claude/scripts/lib/deploy-freshness-lib.sh) or the source store
# (agent-system/extensions/core/scripts/check-deploy-freshness.sh, lib sibling at
# agent-system/extensions/core/scripts/lib/deploy-freshness-lib.sh) with no root-computation
# needed at all — unlike update-task-status.sh's PROJECT_ROOT-anchored candidate list, this
# script does not use deploy-root-guard.sh and has no independent notion of "project root" to
# anchor against. A missing library degrades to this script's own existing silent-no-op
# contract (never a loud environment error) — "always exit 0, never alarm" already covers this
# case, so there is no new failure mode to introduce.
_CDF_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
FRESHNESS_LIB="${_CDF_SCRIPT_DIR:-}/lib/deploy-freshness-lib.sh"

[ -n "${_CDF_SCRIPT_DIR:-}" ] || exit 0
[ -f "$FRESHNESS_LIB" ] || exit 0
# shellcheck disable=SC1090
. "$FRESHNESS_LIB"

# Degrade-safe guarded source (context/patterns/regeneration-is-manual-only.md's "Redeploy-Remedy
# Emission Sites" subsection, Decision 1(c)): a missing lib falls back to a no-op fragment rather
# than a source-time failure. This script's own always-exit-0 contract already means a missing
# RR_LIB cannot newly introduce a failure mode here either way.
_RR_LIB="${_CDF_SCRIPT_DIR:-}/lib/redeploy-remedy-lib.sh"
# shellcheck disable=SC1090
[ -f "$_RR_LIB" ] && . "$_RR_LIB"
declare -F redeploy_remedy_fragment >/dev/null 2>&1 || redeploy_remedy_fragment() { printf '%s' ""; }

STALE_NAMES="$(deploy_freshness_stale_names "$REPO_ROOT")"

ANY_WARNED=false
while IFS= read -r name; do
  [ -n "$name" ] || continue
  ANY_WARNED=true
  echo "WARN: deployed extension '${name}' is stale — its .claude/ tree no longer matches the source store." >&2
  echo "  Remedy: bash .claude/scripts/deploy-headless.sh (or the picker's [Reload All] / 'Regenerate'). $(redeploy_remedy_fragment)" >&2
  echo "  For per-file detail: bash .claude/scripts/verify-deploy.sh --findings" >&2
done <<< "$STALE_NAMES"

# --- Streak counter update + escalated banner (see the header block above for the full contract) ---
# Every step below degrades to a silent skip on any failure — never allowed to abort or alarm.
if command -v jq >/dev/null 2>&1; then
  if [ "$ANY_WARNED" = "true" ]; then
    _prev_streak=0
    if [ -f "$FRESHNESS_STREAK_FILE" ]; then
      _prev_streak="$(jq -r '.streak // 0' "$FRESHNESS_STREAK_FILE" 2>/dev/null)"
      [[ "$_prev_streak" =~ ^[0-9]+$ ]] || _prev_streak=0
    fi
    _new_streak=$(( _prev_streak + 1 ))
    [ "$_new_streak" -gt "$FRESHNESS_STREAK_CAP" ] && _new_streak="$FRESHNESS_STREAK_CAP"

    if [ -d "${REPO_ROOT}/specs" ] && [ -w "${REPO_ROOT}/specs" ]; then
      _ext_json="$(printf '%s\n' "$STALE_NAMES" | jq -R -s -c 'split("\n") | map(select(length > 0))' 2>/dev/null)"
      [ -n "$_ext_json" ] || _ext_json="[]"
      _updated_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"
      jq -n --argjson streak "$_new_streak" --argjson extensions "$_ext_json" --arg updated "$_updated_ts" \
        '{streak: $streak, extensions: $extensions, updated: $updated}' \
        > "${FRESHNESS_STREAK_FILE}.tmp.$$" 2>/dev/null \
        && mv -f "${FRESHNESS_STREAK_FILE}.tmp.$$" "$FRESHNESS_STREAK_FILE" 2>/dev/null || true
      rm -f "${FRESHNESS_STREAK_FILE}.tmp.$$" 2>/dev/null || true
    fi

    if [ "$_new_streak" -ge "$FRESHNESS_STREAK_THRESHOLD" ]; then
      echo "" >&2
      echo "WARN: this deploy-freshness warning has now appeared on ${_new_streak} consecutive command invocations." >&2
      echo "  It has not been acted on. This escalated notice is VISIBILITY ONLY -- it never blocks anything." >&2
      echo "  Remedy: bash .claude/scripts/deploy-headless.sh (or the picker's [Reload All] / 'Regenerate'). $(redeploy_remedy_fragment)" >&2
    fi
  else
    # No WARN fired this run (fresh or cannot-verify, deliberately collapsed) -- reset the streak.
    rm -f "$FRESHNESS_STREAK_FILE" 2>/dev/null || true
  fi
fi

exit 0
