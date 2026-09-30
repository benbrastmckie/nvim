#!/usr/bin/env bash
# reap-session-runtime-files.sh — mtime-based reap for abandoned session-scoped orchestration
# runtime files.
#
# Purpose: session-scoping specs/.orchestration/.orchestrator-multi-state-{session_id}.json and
# specs/.orchestration/.return-meta-multi-{session_id}.json (see
# context/standards/orchestrator-runtime-files.md's Class Table) trades batch-collision risk for
# unbounded litter — a batch orchestration that never reaches its own cleanup path (crash,
# killed session, interrupted terminal) leaves its session-suffixed file behind forever. This
# script sweeps both specs/.orchestration/ (the current location) and the legacy specs/ root
# (permanent coverage, never dropped — see "Filename shapes swept" below), deleting matches
# whose mtime exceeds ORCHESTRATOR_SESSION_REAP_MIN minutes.
#
# Filename shapes swept (four naming generations per family, eight globs total): the current
# hyphen-suffixed shape (`.orchestrator-multi-state-*.json`) plus three superseded generations
# that gitignore's shell-glob patterns already tolerate but this script's own literal candidate
# array used to miss entirely — un-suffixed (`.orchestrator-multi-state.json`), dot-separator
# (`.orchestrator-multi-state.sess_{sid}.json`), and `.prev-` (`.orchestrator-multi-state.prev-sess_{sid}.json`).
# Widening this array (rather than a one-shot legacy-name migration script) was chosen because
# the gitignore side already tolerates all four shapes at any depth — widening protects every
# consumer repo permanently, not just this one repo once. The dot-separator glob
# (`.orchestrator-multi-state.*.json`) also matches every `.prev-` file, since `.prev-sess_{sid}`
# is itself a valid match for the wildcard after the separating dot; both patterns are kept
# explicit in the candidate array (matching the four-shapes-named contract) and the resulting
# duplicate path is de-duplicated before reaping, never reaped or reported twice.
#
# Modeled on task-lock.sh's `reap` subcommand: same --dry-run contract, same
# report-then-delete-or-report shape, so `skill-refresh/SKILL.md` can echo this script's output
# verbatim the same way it already does for task-lock.sh reap.
#
# Scope: ONLY the two repo-level singleton families (all four naming generations of each)
# directly under specs/. Deliberately does NOT recurse into specs/{NNN}_{SLUG}/ — per-task
# runtime files (.orchestrator-loop-guard, .orchestrator-churn-state.json, .drift-inspection.json,
# .lock/) are already correctly isolated by task directory and are out of scope for this sweep.
#
# Staleness criterion: file mtime, matching task-lock.sh cmd_reap's own fallback path. This does
# NOT conflict with the "no freshness check on read" principle documented in
# orchestrator-runtime-files.md: that principle governs whether an in-flight READ trusts an old
# file's content unconditionally (it does, by design). Reap is a distinct, explicitly-invoked
# DELETION sweep, never run implicitly from a read path, and mtime is already used elsewhere in
# this codebase (task-lock.sh) for the identical reap purpose. The multi-state file's mtime
# advances on every dispatch cycle (cycle_count, current_statuses, dispatch_start_ts all rewrite
# it — see skill-orchestrate/SKILL.md's Stage MT loop), so mtime is a live signal that only stops
# advancing once the writing invocation truly terminates.
#
# Threshold: ORCHESTRATOR_SESSION_REAP_MIN, default 240 minutes. Deliberately NOT
# TASK_LOCK_REAP_MIN (task-lock.sh's own threshold) — a multi-task batch can run up to
# MAX_CYCLES_MT = min(task_count * 5, 25) cycles, each potentially a full research + plan +
# implement dispatch per task, so the safe threshold must be materially longer than a single
# task's lock threshold, and there is no PID/heartbeat liveness signal for the batch orchestrator
# the way task-lock.sh has for a single task's lock.
#
# Usage:
#   reap-session-runtime-files.sh [--dry-run]
#
# Exit codes:
#   0 - always (whether or not anything qualified for reaping; reap reports, it never fails
#       the caller for "nothing to do")
#   2 - usage error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"

ORCHESTRATOR_SESSION_REAP_MIN="${ORCHESTRATOR_SESSION_REAP_MIN:-240}"

dry_run=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      dry_run=true
      shift
      ;;
    *)
      echo "Usage: $0 [--dry-run]" >&2
      exit 2
      ;;
  esac
done

now_epoch() {
  date -u +%s
}

# --- extract_session_id: best-effort session_id extraction from filename or file content ---
# Filename shapes (four naming generations per family — see the header comment's "Filename
# shapes swept" note): hyphen-suffixed (`.orchestrator-multi-state-{session_id}.json`,
# `.return-meta-multi-{session_id}.json`), dot-separator
# (`.orchestrator-multi-state.{session_id}.json`, `.return-meta-multi.{session_id}.json`),
# `.prev-` (`.orchestrator-multi-state.prev-{session_id}.json`,
# `.return-meta-multi.prev-{session_id}.json`), and un-suffixed
# (`.orchestrator-multi-state.json`, `.return-meta-multi.json` — no embedded session id at all).
# Falls back to the file's own "session_id" JSON field (return-meta-multi always carries one;
# multi-state always carries one per skill-orchestrate/SKILL.md Stage MT-1) whenever the
# filename shape does not parse cleanly, including for the un-suffixed shape by construction.
extract_session_id() {
  local f="$1" base sid
  base=$(basename "$f")
  case "$base" in
    .orchestrator-multi-state.json|.return-meta-multi.json)
      # Un-suffixed shape carries no filename-embedded session id at all — go straight to the
      # file-content fallback rather than falling through to the generic strips below, which
      # would otherwise mis-parse ".json" as a leftover "session id".
      sid=$(jq -r '.session_id // "unknown"' "$f" 2>/dev/null) || true
      [ -n "$sid" ] || sid="unknown"
      echo "$sid"
      return
      ;;
  esac
  sid="${base#.orchestrator-multi-state-}"
  sid="${sid#.return-meta-multi-}"
  sid="${sid#.orchestrator-multi-state.prev-}"
  sid="${sid#.return-meta-multi.prev-}"
  sid="${sid#.orchestrator-multi-state.}"
  sid="${sid#.return-meta-multi.}"
  sid="${sid%.json}"
  if [ "$sid" = "$base" ] || [ -z "$sid" ]; then
    sid=$(jq -r '.session_id // "unknown"' "$f" 2>/dev/null) || true
    [ -n "$sid" ] || sid="unknown"
  fi
  echo "$sid"
}

total_count=0
reaped_count=0

# nullglob so a no-match glob expands to zero words rather than the literal pattern string.
# Restored via a trap-independent explicit unset at the end since this script always exits
# through the same tail regardless of branch taken.
#
# Four shapes per family, eight globs per location, sixteen globs total. The dot-separator glob
# (`.orchestrator-multi-state.*.json`) also matches every `.prev-` file, so the same path can
# appear twice in the expanded array; de-duplicated below before any counting or reaping.
#
# Two locations are swept, PERMANENTLY, not transitionally: the current `specs/.orchestration/`
# location (see context/standards/orchestrator-runtime-files.md's Class Table) AND the legacy
# `specs/` root, which every writer used before this task's relocation. Keeping the legacy root
# globs is deliberate and permanent — every already-stranded file at the `specs/` root, in this
# repo and in every other consumer repo that has not yet redeployed this change, stays reapable
# forever. Dropping the legacy globs once every writer relocates would create exactly the fourth
# orphaned generation this task's own risk table warns against.
shopt -s nullglob
candidates=(
  "$PROJECT_ROOT"/specs/.orchestration/.orchestrator-multi-state.json
  "$PROJECT_ROOT"/specs/.orchestration/.orchestrator-multi-state-*.json
  "$PROJECT_ROOT"/specs/.orchestration/.orchestrator-multi-state.*.json
  "$PROJECT_ROOT"/specs/.orchestration/.orchestrator-multi-state.prev-*.json
  "$PROJECT_ROOT"/specs/.orchestration/.return-meta-multi.json
  "$PROJECT_ROOT"/specs/.orchestration/.return-meta-multi-*.json
  "$PROJECT_ROOT"/specs/.orchestration/.return-meta-multi.*.json
  "$PROJECT_ROOT"/specs/.orchestration/.return-meta-multi.prev-*.json
  "$PROJECT_ROOT"/specs/.orchestrator-multi-state.json
  "$PROJECT_ROOT"/specs/.orchestrator-multi-state-*.json
  "$PROJECT_ROOT"/specs/.orchestrator-multi-state.*.json
  "$PROJECT_ROOT"/specs/.orchestrator-multi-state.prev-*.json
  "$PROJECT_ROOT"/specs/.return-meta-multi.json
  "$PROJECT_ROOT"/specs/.return-meta-multi-*.json
  "$PROJECT_ROOT"/specs/.return-meta-multi.*.json
  "$PROJECT_ROOT"/specs/.return-meta-multi.prev-*.json
)
shopt -u nullglob

declare -A _seen_candidate
deduped_candidates=()
for f in "${candidates[@]}"; do
  [ -n "${_seen_candidate[$f]+x}" ] && continue
  _seen_candidate["$f"]=1
  deduped_candidates+=("$f")
done
candidates=( "${deduped_candidates[@]}" )

for f in "${candidates[@]}"; do
  [ -f "$f" ] || continue
  total_count=$(( total_count + 1 ))

  session_id=$(extract_session_id "$f")
  file_mtime=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null) || true
  if [ -z "$file_mtime" ]; then
    echo "SKIP: $f (could not stat mtime)" >&2
    continue
  fi
  age_min=$(( ( $(now_epoch) - file_mtime ) / 60 ))
  # Two-location-aware: strip PROJECT_ROOT/ rather than hardcoding "specs/<basename>", which was
  # only ever correct for the (formerly sole) specs/ root location and would silently mis-report
  # a specs/.orchestration/ file as if it still sat at the specs/ root.
  rel_path="${f#"$PROJECT_ROOT"/}"

  if [ "$age_min" -gt "$ORCHESTRATOR_SESSION_REAP_MIN" ]; then
    reaped_count=$(( reaped_count + 1 ))
    if [ "$dry_run" = true ]; then
      echo "would reap: $rel_path session=$session_id age_min=$age_min"
    else
      rm -f "$f" 2>/dev/null || true
      echo "reaped: $rel_path session=$session_id age_min=$age_min"
    fi
  fi
done

if [ "$reaped_count" -eq 0 ]; then
  echo "no stale session-scoped orchestration files found (${total_count} file(s) scanned, threshold ${ORCHESTRATOR_SESSION_REAP_MIN}min)"
elif [ "$dry_run" = true ]; then
  echo "would reap ${reaped_count} of ${total_count} session-scoped orchestration file(s) (threshold ${ORCHESTRATOR_SESSION_REAP_MIN}min)"
else
  echo "reaped ${reaped_count} of ${total_count} session-scoped orchestration file(s) (threshold ${ORCHESTRATOR_SESSION_REAP_MIN}min)"
fi

exit 0
