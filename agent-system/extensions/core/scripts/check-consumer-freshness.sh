#!/usr/bin/env bash
# check-consumer-freshness.sh — Source-side TIER 3 fleet freshness report: from THIS repo (the
# source store), reports every KNOWN CONSUMER repo's per-extension deployed revision and flags
# those behind source. This is the opt-in, explicit-invocation companion to the ambient,
# per-repo tiers documented in context/patterns/regeneration-is-manual-only.md's "Detecting When
# You're Stale" section:
#   TIER 1 - check-deploy-freshness.sh: silent-unless-stale, CHECKPOINT-1-only, always exit 0.
#   TIER 2 - update-task-status.sh's postflight backstop: blocking, scoped to THIS repo's own
#            commits.
#   TIER 3 - this script: opt-in, source-repo-initiated, reports the WHOLE known fleet.
#
# Unlike tier 1's deliberate silence, this is an EXPLICITLY INVOKED audit command — its entire
# value is completeness. Every registered consumer gets a row, including MISSING/NOEXTSTATE/
# CANNOTVERIFY rows tier 1 would silently omit. "Unknown" is reported, never hidden.
#
# NEVER WRITES TO A CONSUMER REPO. Every consumer interaction is a read of that repo's own
# .claude-extensions.json. This is the pull-only architecture's read-only fleet view — see
# context/patterns/regeneration-is-manual-only.md, which this script must never invert.
#
# Reuses scripts/lib/deploy-freshness-lib.sh's deploy_freshness_status(repo_root, ext_name)
# UNCHANGED — no new comparison algorithm. That function is already repo-root-parametric: the
# value it compares (source_dir) is an absolute path back into THIS repo, not relative to the
# caller, so it works correctly against any consumer path without modification.
#
# Usage:
#   check-consumer-freshness.sh [--stale-only] [--discover]
#
#   (no flags)     Report every registered consumer x extension: repo, extension, status,
#                  commits-behind.
#   --stale-only   Print only non-FRESH rows (used by deploy-headless.sh's post-deploy hook).
#   --discover     Reconciliation mode (see the --discover block below): scans discover_roots
#                  for on-disk consumers absent from the registry. Never called from
#                  deploy-headless.sh — this is the expensive path the registry exists to avoid
#                  paying on every invocation. Manual/occasional only.
#
# Exit codes:
#   0  no registered consumer is stale (or --discover found no unregistered repo)
#   1  at least one registered consumer is stale (or --discover found an unregistered repo)
#   2  registry missing/unparseable, or a usage error
#
# Callers that must never be affected by this script's outcome are expected to invoke it guarded
# (e.g. `... || true`), the same convention command-gate-in.sh's CHECKPOINT 1 already uses for
# check-deploy-freshness.sh.

set -uo pipefail

# --- Sibling lookups off THIS script's OWN location, never off any consumer path or REPO_ROOT ---
# Mirrors check-deploy-freshness.sh's identical rationale: this resolves correctly whether
# running from the deployed tree (.claude/scripts/) or the source store
# (agent-system/extensions/core/scripts/), with no root-computation needed.
_CCF_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# Degrade-safe guarded source (context/patterns/regeneration-is-manual-only.md's "Redeploy-Remedy
# Emission Sites" subsection, Decision 1(c)): a missing lib falls back to a no-op fragment rather
# than a source-time failure.
_RR_LIB="${_CCF_SCRIPT_DIR}/lib/redeploy-remedy-lib.sh"
# shellcheck source=lib/redeploy-remedy-lib.sh
[ -f "$_RR_LIB" ] && . "$_RR_LIB"
declare -F redeploy_remedy_fragment >/dev/null 2>&1 || redeploy_remedy_fragment() { printf '%s' ""; }

STALE_ONLY=false
DISCOVER=false
for arg in "$@"; do
  case "$arg" in
    --stale-only) STALE_ONLY=true ;;
    --discover) DISCOVER=true ;;
    -h|--help)
      sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $arg" >&2
      echo "Usage: check-consumer-freshness.sh [--stale-only] [--discover]" >&2
      exit 2
      ;;
  esac
done

[ -n "${_CCF_SCRIPT_DIR:-}" ] || { echo "ERROR: could not resolve script directory." >&2; exit 2; }

FRESHNESS_LIB="${_CCF_SCRIPT_DIR}/lib/deploy-freshness-lib.sh"
if [ ! -f "$FRESHNESS_LIB" ]; then
  echo "ERROR: shared freshness library not found: $FRESHNESS_LIB" >&2
  exit 2
fi
# shellcheck disable=SC1090
. "$FRESHNESS_LIB"

# Registry resolution: ONE relative path, correct in BOTH the source store
# (agent-system/extensions/core/scripts/../context/reference/known-consumer-repos.json) and the
# deployed tree (.claude/scripts/../context/reference/known-consumer-repos.json) -- an
# ENV_VAR_OVERRIDE hook is provided for the fixture test suite (Phase 6) to point at a scratch
# registry without needing a scratch $SCRIPT_DIR layout.
REGISTRY="${CONSUMER_FRESHNESS_REGISTRY_PATH:-${_CCF_SCRIPT_DIR}/../context/reference/known-consumer-repos.json}"

if [ ! -f "$REGISTRY" ]; then
  echo "ERROR: consumer registry not found: $REGISTRY" >&2
  exit 2
fi
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required." >&2; exit 2; }

REGISTRY_JSON="$(cat "$REGISTRY" 2>/dev/null)"
if [ -z "$REGISTRY_JSON" ] || ! echo "$REGISTRY_JSON" | jq -e . >/dev/null 2>&1; then
  echo "ERROR: consumer registry is empty or not valid JSON: $REGISTRY" >&2
  exit 2
fi

SOURCE_REPO="$(echo "$REGISTRY_JSON" | jq -r '.source_repo // empty')"

# --- commits-behind helper -----------------------------------------------------------------
# Locates the recorded head's position in the path-scoped history via
# `git rev-list --count <recorded>..<recomputed> -- <source_dir>`. Prints "?" rather than
# asserting a number when the recorded head is not reachable (rebase/GC of source history) --
# never aborts, never claims 0 when unknown.
_ccf_commits_behind() {
  local source_dir="$1" recorded="$2"
  [ -n "$source_dir" ] && [ -n "$recorded" ] && [ -d "$source_dir" ] || { echo "?"; return 0; }
  local toplevel
  toplevel="$(git -C "$source_dir" rev-parse --show-toplevel 2>/dev/null)" || { echo "?"; return 0; }
  [ -n "$toplevel" ] || { echo "?"; return 0; }
  local count
  count="$(git -C "$toplevel" rev-list --count "${recorded}..HEAD" -- "$source_dir" 2>/dev/null)" || { echo "?"; return 0; }
  [ -n "$count" ] && [[ "$count" =~ ^[0-9]+$ ]] || { echo "?"; return 0; }
  echo "$count"
  return 0
}

ANY_STALE=false

# --- Header ------------------------------------------------------------------------------------
if ! $STALE_ONLY; then
  printf '%-40s %-14s %-14s %-8s\n' "REPO" "EXTENSION" "STATUS" "BEHIND"
  printf '%-40s %-14s %-14s %-8s\n' "----" "---------" "------" "------"
  # Source repo row: marked distinctly (fresh by construction), not omitted.
  printf '%-40s %-14s %-14s %-8s\n' "${SOURCE_REPO:-<this repo>}" "(source)" "FRESH*" "0"
fi

# --- Main report: every registered consumer x every extension THAT REPO records ---------------
CONSUMER_COUNT="$(echo "$REGISTRY_JSON" | jq '.consumers // [] | length')"
i=0
while [ "$i" -lt "$CONSUMER_COUNT" ]; do
  path="$(echo "$REGISTRY_JSON" | jq -r --argjson i "$i" '.consumers[$i].path // empty')"
  i=$((i + 1))
  [ -n "$path" ] || continue

  if [ ! -d "$path" ]; then
    ANY_STALE=true
    $STALE_ONLY && printf '%-40s %-14s %-14s %-8s\n' "$path" "-" "MISSING" "-"
    if ! $STALE_ONLY; then
      printf '%-40s %-14s %-14s %-8s\n' "$path" "-" "MISSING" "-"
    fi
    continue
  fi

  ext_state="$path/.claude-extensions.json"
  if [ ! -f "$ext_state" ]; then
    ANY_STALE=true
    printf '%-40s %-14s %-14s %-8s\n' "$path" "-" "NOEXTSTATE" "-"
    continue
  fi

  ext_names="$(jq -r '.extensions // {} | keys[]?' "$ext_state" 2>/dev/null)"
  if [ -z "$ext_names" ]; then
    ANY_STALE=true
    printf '%-40s %-14s %-14s %-8s\n' "$path" "-" "NOEXTSTATE" "-"
    continue
  fi

  while IFS= read -r ext_name; do
    [ -n "$ext_name" ] || continue
    status="$(deploy_freshness_status "$path" "$ext_name")"
    behind="0"
    if [ "$status" = "STALE" ]; then
      ANY_STALE=true
      recorded="$(jq -r --arg n "$ext_name" '.extensions[$n].source_git_head // empty' "$ext_state" 2>/dev/null)"
      source_dir="$(jq -r --arg n "$ext_name" '.extensions[$n].source_dir // empty' "$ext_state" 2>/dev/null)"
      behind="$(_ccf_commits_behind "$source_dir" "$recorded")"
    elif [ "$status" = "CANNOTVERIFY" ]; then
      ANY_STALE=true
      behind="-"
    fi
    if $STALE_ONLY; then
      [ "$status" = "STALE" ] || [ "$status" = "CANNOTVERIFY" ] || continue
    fi
    printf '%-40s %-14s %-14s %-8s\n' "$path" "$ext_name" "$status" "$behind"
  done <<< "$ext_names"
done

if ! $STALE_ONLY; then
  echo ""
  if $ANY_STALE; then
    echo "Summary: one or more registered consumers are STALE, CANNOTVERIFY, MISSING, or NOEXTSTATE."
    echo "Remedy for a STALE consumer: run 'bash .claude/scripts/deploy-headless.sh' IN THAT REPO"
    echo "(this repo never pushes into a consumer -- see context/patterns/regeneration-is-manual-only.md)."
    echo "$(redeploy_remedy_fragment)"
  else
    echo "Summary: all registered consumers are FRESH."
  fi
fi

# --- --discover reconciliation mode -------------------------------------------------------------
# Expensive path the registry exists to avoid paying routinely. Never called from
# deploy-headless.sh. Manual/occasional only. Never edits the registry automatically -- prints
# the exact JSON object to add instead.
if $DISCOVER; then
  echo ""
  echo "--- --discover: scanning discover_roots for on-disk consumers not in the registry ---"
  DISCOVER_ROOTS_COUNT="$(echo "$REGISTRY_JSON" | jq '.discover_roots // [] | length')"
  REGISTERED_PATHS="$(echo "$REGISTRY_JSON" | jq -r '.consumers // [] | .[].path')"

  FOUND_TMPFILE="$(mktemp 2>/dev/null)" || FOUND_TMPFILE=""
  j=0
  while [ "$j" -lt "$DISCOVER_ROOTS_COUNT" ]; do
    root="$(echo "$REGISTRY_JSON" | jq -r --argjson j "$j" '.discover_roots[$j] // empty')"
    j=$((j + 1))
    [ -n "$root" ] || continue
    if [ ! -d "$root" ]; then
      echo "  NOTE: discover_root not readable, skipping: $root"
      continue
    fi
    while IFS= read -r found; do
      [ -n "$found" ] || continue
      found_dir="$(dirname "$found")"
      src="$(jq -r --arg root "$SOURCE_REPO" '.extensions // {} | to_entries[] | select(.value.source_dir != null and (.value.source_dir | startswith($root + "/agent-system/extensions/"))) | .value.source_dir' "$found" 2>/dev/null | head -1)"
      [ -n "$src" ] || continue
      # The source repo itself may carry its own .claude-extensions.json (it self-hosts a
      # deploy for development) with source_dir pointing at itself -- that is not a fleet
      # consumer and is already shown distinctly as the "(source)" row above, so it is excluded
      # from both the found-set (informational REGISTERED-BUT-ABSENT pass below) and the
      # UNREGISTERED report.
      [ "$found_dir" = "$SOURCE_REPO" ] && continue
      # discover_roots may overlap (e.g. a broad root and a narrower root both covering the same
      # consumer within --maxdepth 3) -- dedupe against FOUND_TMPFILE so an overlapping root
      # never produces a duplicate UNREGISTERED line for the same directory.
      if [ -n "$FOUND_TMPFILE" ] && grep -qxF "$found_dir" "$FOUND_TMPFILE" 2>/dev/null; then
        continue
      fi
      [ -n "$FOUND_TMPFILE" ] && echo "$found_dir" >> "$FOUND_TMPFILE"
      if ! echo "$REGISTERED_PATHS" | grep -qxF "$found_dir"; then
        echo "  UNREGISTERED: $found_dir (found on disk, not in registry)"
        echo "    Add to consumers[]: {\"path\": \"$found_dir\", \"note\": \"discovered $(date -u +%Y-%m-%d)\"}"
        ANY_STALE=true
      fi
    done < <(find "$root" -maxdepth 3 -name '.claude-extensions.json' -not -path '*/.git/*' 2>/dev/null)
  done

  if [ -n "$FOUND_TMPFILE" ]; then
    while IFS= read -r reg_path; do
      [ -n "$reg_path" ] || continue
      if ! grep -qxF "$reg_path" "$FOUND_TMPFILE" 2>/dev/null; then
        echo "  REGISTERED-BUT-ABSENT: $reg_path (in registry, not found by this scan -- informational, not auto-removed)"
      fi
    done <<< "$REGISTERED_PATHS"
    rm -f "$FOUND_TMPFILE"
  fi
fi

if $ANY_STALE; then
  exit 1
fi
exit 0
