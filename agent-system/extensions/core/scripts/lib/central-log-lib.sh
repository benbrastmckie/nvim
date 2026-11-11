#!/usr/bin/env bash
# central-log-lib.sh - Single home of the cross-repo error-log promotion algorithm shared by
# issue-record.sh and events-append.sh. Modelled structurally on
# scripts/lib/source-store-path-lib.sh and scripts/lib/deploy-freshness-lib.sh: a header stating
# it is the single home of the algorithm, safe to source, sets no shell options a caller
# inherits, and reduces every failure mode to a silent, fail-soft no-op rather than an abort.
#
# WHY THIS EXISTS
# ----------------
# Capture happens per-repository, in a task's own `issues.jsonl` or the repo-wide
# `events.jsonl`. Nothing shows what has been breaking ACROSS every repository that shares this
# agent system. This library pushes a narrow, filtered subset of what each of those two live
# writers already appends into one central, cross-repo log -- `specs/central-errors.jsonl` in
# the repository that OWNS the source store (the repository whose own `.claude-extensions.json`
# resolves an extension's `source_dir` to a directory inside that same repository's own git
# toplevel). This needs no repository enumeration and no usable repo registry: every repository
# that deploys from a source store already knows, from its own `.claude-extensions.json`, which
# repository that store lives in.
#
# EXPORTS EXACTLY ONE FUNCTION
# ----------------------------
#   central_log_promote <origin_store> <json_line>
#     <origin_store> is "issues.jsonl" or "events.jsonl" (anything else is a silent no-op).
#     <json_line> is the exact line just appended to that store (a single JSON object, already
#     built by the caller).
#     ALWAYS returns 0, on every path, including every failure path. Never writes to stdout.
#     Diagnostics, when any are emitted at all, go to stderr and are advisory only -- a caller
#     must never let this function's output or exit status influence its own behavior.
#
# THE OWNING REPOSITORY
# ----------------------
# This script's own deployed location (`<repo_root>/.claude/scripts/lib/central-log-lib.sh`)
# resolves the WRITING repository's root via `common_repo_root` (levels=3, the scripts/lib/
# depth), exactly as issue-record.sh and events-append.sh resolve their own PROJECT_ROOT --
# never a caller-supplied global, so this function's two-argument contract holds regardless of
# what the caller has or has not already resolved into its own shell.
#
# The OWNING repository is then resolved from the WRITING repository's own
# `.claude-extensions.json`: read the first extension entry's own `source_dir` (per-extension
# ONLY -- a top-level `.source_dir` lookup returns `null` and must never be read as the key being
# absent), resolve that directory's enclosing git toplevel via `git -C <source_dir> rev-parse
# --show-toplevel`, and take that toplevel as the owning repository. Every extension in a given
# `.claude-extensions.json` is expected to share one owning repository (one source store, many
# extensions inside it), so the first entry that resolves is sufficient; this function never
# cross-checks the remaining entries.
#
# OWNING-REPO SKIP
# -----------------
# When the resolved owning toplevel equals the writing repository's own canonicalized root, this
# repository owns its own source store: promoting into itself would duplicate every entry into
# the very log it is also captured in. Return 0 having written nothing.
#
# PROMOTION FILTER
# -----------------
# From `issues.jsonl`: promote only a line with `kind == "issue"` (a `kind: "win"` is not
# promoted). From `events.jsonl`: promote only a line with `category == "blocker"`. Any other
# `<origin_store>` value, or a line that fails this filter, is a silent no-op.
#
# ENVELOPE
# --------
# Built with `jq -c -n`, never string concatenation: `central_id` (`cen_{timestamp_ms}_{random6}`),
# `recorded_at` (ISO 8601 UTC), `origin_repo` (the writing repository's absolute root),
# `origin_store` (the `<origin_store>` argument verbatim), and `entry` (the original `<json_line>`
# argument, verbatim and unmodified -- parsed and re-embedded as a JSON value, never re-stringified
# text). See context/formats/issue-log.md's "Central Cross-Repo Log" section for the full field
# contract this implements against.
#
# BOUNDED APPEND
# --------------
# Guarded by `flock -x` on `<owning_root>/specs/.central-errors.lock`. Inside the lock: if
# `<owning_root>/specs/central-errors.jsonl` already holds >= CENTRAL_LOG_ROTATE_AT_LINES (20000)
# lines, rename it to `specs/central-errors.jsonl.1` (replacing any prior generation) and start a
# fresh file; then append the one envelope line.
#
# SILENT NO-OP PATHS (every one returns 0, writes nothing, prints nothing to stdout)
# ------------------------------------------------------------------------------------
#   - A required binary (jq, git, flock, realpath) is missing.
#   - <origin_store> is not "issues.jsonl" or "events.jsonl".
#   - <json_line> is empty, or fails the promotion filter above.
#   - `.claude-extensions.json` is absent or unparseable.
#   - No extension's `source_dir` resolves to a git toplevel.
#   - The resolved owning toplevel equals the writing repository's own root (the owning-repo
#     skip).
#   - `<owning_root>/specs` does not already exist as a directory. NEVER `mkdir -p` it -- an
#     absent `specs/` directory means the target is not a live owning repository, not a
#     bootstrap opportunity.
#   - The lock or the append fails for any reason.
# Never retried, never escalated to a non-zero return, never written to stdout.
#
# This library sets no shell options at file scope (no `set -e`/`-u`/`-o pipefail`) -- it must
# behave identically whether sourced into a caller running under `set -euo pipefail` (both
# issue-record.sh and events-append.sh do) or one that is not.

CENTRAL_LOG_ROTATE_AT_LINES=20000

# _central_log_repo_root -- resolves the WRITING repository's root from this script's own
# deployed location, via common_repo_root (levels=3: scripts/lib/ -> scripts/ -> .claude/ ->
# repo root). Sources lib/common.sh from the same directory if not already loaded. Prints the
# resolved root, or empty string on any failure. Never aborts.
_central_log_repo_root() {
  local _clrr_script_dir
  _clrr_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || return 0
  [ -z "$_clrr_script_dir" ] && return 0
  if ! command -v common_repo_root >/dev/null 2>&1; then
    # shellcheck source=/dev/null
    source "${_clrr_script_dir}/common.sh" 2>/dev/null || return 0
  fi
  common_repo_root "$_clrr_script_dir" 3
  return 0
}

# _central_log_owning_root <writing_repo_root> -- resolves the OWNING repository's canonicalized
# root from <writing_repo_root>'s own .claude-extensions.json, per the header's algorithm. Prints
# the resolved root, or nothing on any failure (missing file, unparseable JSON, no extension with
# a source_dir resolving to a git toplevel, missing jq/git/realpath). Never aborts.
_central_log_owning_root() {
  local writing_root="${1:-}"
  [ -z "$writing_root" ] && return 0
  command -v jq >/dev/null 2>&1 || return 0
  command -v git >/dev/null 2>&1 || return 0
  command -v realpath >/dev/null 2>&1 || return 0

  local ext_file="${writing_root}/.claude-extensions.json"
  [ -f "$ext_file" ] || return 0
  local ext_json
  ext_json="$(cat "$ext_file" 2>/dev/null)" || return 0
  echo "$ext_json" | jq -e . >/dev/null 2>&1 || return 0

  local source_dirs
  source_dirs="$(echo "$ext_json" | jq -r '.extensions // {} | to_entries[]? | .value.source_dir // empty' 2>/dev/null)"
  [ -z "$source_dirs" ] && return 0

  local src toplevel
  while IFS= read -r src; do
    [ -z "$src" ] && continue
    [ -d "$src" ] || continue
    toplevel="$(git -C "$src" rev-parse --show-toplevel 2>/dev/null)" || continue
    [ -z "$toplevel" ] && continue
    toplevel="$(realpath -m -- "$toplevel" 2>/dev/null)" || continue
    [ -n "$toplevel" ] && echo "$toplevel" && return 0
  done <<< "$source_dirs"
  return 0
}

# central_log_promote <origin_store> <json_line> -- see header for the full contract. ALWAYS
# returns 0.
central_log_promote() {
  local origin_store="${1:-}" json_line="${2:-}"

  [ -z "$origin_store" ] && return 0
  [ -z "$json_line" ] && return 0
  command -v jq >/dev/null 2>&1 || return 0
  command -v git >/dev/null 2>&1 || return 0
  command -v flock >/dev/null 2>&1 || return 0
  command -v realpath >/dev/null 2>&1 || return 0

  # --- Promotion filter ---
  case "$origin_store" in
    issues.jsonl)
      local kind
      kind="$(printf '%s' "$json_line" | jq -r '.kind // empty' 2>/dev/null)" || return 0
      [ "$kind" = "issue" ] || return 0
      ;;
    events.jsonl)
      local category
      category="$(printf '%s' "$json_line" | jq -r '.category // empty' 2>/dev/null)" || return 0
      [ "$category" = "blocker" ] || return 0
      ;;
    *)
      return 0
      ;;
  esac

  # --- Resolve writing and owning repositories; apply the owning-repo skip ---
  local writing_root writing_root_canon owning_root
  writing_root="$(_central_log_repo_root)"
  [ -z "$writing_root" ] && return 0
  writing_root_canon="$(realpath -m -- "$writing_root" 2>/dev/null)" || return 0
  [ -z "$writing_root_canon" ] && return 0

  owning_root="$(_central_log_owning_root "$writing_root_canon")"
  [ -z "$owning_root" ] && return 0

  [ "$owning_root" = "$writing_root_canon" ] && return 0

  # --- The target specs/ directory must already exist; never bootstrap it ---
  local owning_specs="${owning_root}/specs"
  [ -d "$owning_specs" ] || return 0

  # --- Build the envelope ---
  local central_id envelope
  central_id="cen_$(date -u +%s%3N 2>/dev/null || date -u +%s)_$(od -An -N3 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')"
  envelope="$(jq -c -n \
    --arg central_id "$central_id" \
    --arg recorded_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg origin_repo "$writing_root_canon" \
    --arg origin_store "$origin_store" \
    --argjson entry "$json_line" \
    '{central_id: $central_id, recorded_at: $recorded_at, origin_repo: $origin_repo, origin_store: $origin_store, entry: $entry}' \
    2>/dev/null)" || return 0
  [ -z "$envelope" ] && return 0

  # --- Bounded, flock-guarded append with single-generation rotation ---
  local central_file="${owning_specs}/central-errors.jsonl"
  local lock_file="${owning_specs}/.central-errors.lock"
  (
    flock -x 201 2>/dev/null || exit 0
    local line_count=0
    if [ -f "$central_file" ]; then
      line_count="$(wc -l < "$central_file" 2>/dev/null || echo 0)"
    fi
    if [ "${line_count:-0}" -ge "$CENTRAL_LOG_ROTATE_AT_LINES" ] 2>/dev/null; then
      mv -f -- "$central_file" "${central_file}.1" 2>/dev/null || true
    fi
    printf '%s\n' "$envelope" >> "$central_file" 2>/dev/null || true
  ) 2>/dev/null 201> "$lock_file" || true

  return 0
}
