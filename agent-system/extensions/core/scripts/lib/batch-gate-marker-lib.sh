#!/usr/bin/env bash
# batch-gate-marker-lib.sh - Single source of truth for the batch-gate-pending marker's path
# convention and staleness window, shared by every producer and consumer so the definition never
# drifts between orchestrate-cycle-plan.sh (writer), orchestrate-batch-gate.sh (discharger), and
# verify-deploy.sh/run-all.sh's own entry guards (readers, Phase 5 of this same body of work).
#
# THE MARKER
# ----------
# Path: specs/.orchestration/batch-gate-pending-<session_id>.json (one per orchestrator session;
# specs/.orchestration/ is already ignored wholesale by specs/.gitignore's own `**/.orchestration/`
# rule, so this marker needs no new ephemeral-file class). Shape:
#   {session_id, pid, written_at (ISO8601 UTC), task_numbers: [...], dispatch_seq: {...}}
#
# Written by orchestrate-cycle-plan.sh whenever the final `.implement_agents` map for THIS
# session is non-empty (never gated on task count -- a batch of one gets a marker too). Removed
# by orchestrate-batch-gate.sh at its own discharge point, once the complete gate set has
# actually run for this session. A consumer never writes or removes this file; it only reads and
# judges staleness.
#
# STALENESS WINDOW
# -----------------
# BATCH_GATE_MARKER_STALE_SEC (default 3600 = 1 hour, overridable via the identically-named env
# var, following this codebase's existing override convention for GATE_MUTEX_STALE_SEC and
# MEASURE_GATE_COSTS_LOAD_THRESHOLD). Rationale for the default: an ordinary orchestrator cycle
# that dispatches an implement phase completes in minutes to tens of minutes, not hours; 1 hour
# gives generous slack for a slow cycle without leaving a genuinely crashed orchestrator's stale
# marker wedging verification for more than a bounded, known window. A marker older than this
# window is IGNORED by every consumer -- not deleted (removal stays the discharger's own job;
# a consumer that also deleted it would race a legitimate concurrent writer) -- with a loud,
# named warning naming the marker's age, so an operator can tell "mechanically ignored, by
# design" apart from "silently vanished."
#
# FAIL-OPEN ON MALFORMED INPUT: an unreadable file, missing `written_at`, or an unparseable
# timestamp is treated as STALE (ignored) rather than fresh (enforced) -- the marker's own job is
# to ADD a refusal, never to accidentally wedge verification forever on a malformed read. This
# mirrors this codebase's existing fail-open posture for optional coordination (specs/.gate-lock,
# the hints file) stated throughout context/standards/shell-script-testing.md.
#
# Sourced (never executed), no shell options changed, every function fail-safe (never calls
# `exit`), mirroring lib/common.sh's own contract.

BATCH_GATE_MARKER_STALE_SEC="${BATCH_GATE_MARKER_STALE_SEC:-3600}"

# batch_gate_marker_path REPO_ROOT SESSION_ID -- stdout: the marker's own full path. Never
# touches the filesystem.
batch_gate_marker_path() {
  local _bgm_root="$1" _bgm_sid="$2"
  echo "${_bgm_root}/specs/.orchestration/batch-gate-pending-${_bgm_sid}.json"
  return 0
}

# batch_gate_marker_glob REPO_ROOT -- stdout: the glob pattern matching ANY session's marker
# under REPO_ROOT, one per line if multiple exist (an entry guard cares whether ANY pending
# marker exists, not specifically this session's own -- a sibling session's own implement
# dispatch this cycle owes a batch-gate discharge too). Never touches the filesystem beyond the
# glob expansion itself; an unmatched glob (no markers at all) prints nothing.
batch_gate_marker_glob() {
  local _bgm_root="$1"
  local _bgm_f
  for _bgm_f in "${_bgm_root}/specs/.orchestration"/batch-gate-pending-*.json; do
    [ -e "$_bgm_f" ] && echo "$_bgm_f"
  done
  return 0
}

# batch_gate_marker_age_sec MARKER_FILE -- stdout: the marker's age in whole seconds (now minus
# its own `written_at`), or empty on any read/parse failure (missing file, unreadable, no
# `written_at` field, or an unparseable timestamp). Never a non-zero exit; emptiness IS the
# failure signal, consistent with this library's fail-safe contract.
batch_gate_marker_age_sec() {
  local _bgm_file="$1"
  local _bgm_written_at _bgm_written_epoch _bgm_now_epoch
  [ -f "$_bgm_file" ] || { echo ""; return 0; }
  _bgm_written_at="$(jq -r '.written_at // empty' "$_bgm_file" 2>/dev/null)"
  [ -z "$_bgm_written_at" ] && { echo ""; return 0; }
  _bgm_written_epoch="$(date -u -d "$_bgm_written_at" +%s 2>/dev/null)"
  [ -z "$_bgm_written_epoch" ] && { echo ""; return 0; }
  _bgm_now_epoch="$(date -u +%s)"
  echo $(( _bgm_now_epoch - _bgm_written_epoch ))
  return 0
}

# batch_gate_marker_is_pending REPO_ROOT -- exit 0 (pending, non-stale marker exists) or exit 1
# (no marker, or every existing marker is stale/malformed). Prints nothing on its own; a caller
# wanting the warning text should call batch_gate_marker_pending_warning separately (kept
# distinct so a caller can decide whether/how loudly to surface it).
batch_gate_marker_is_pending() {
  local _bgm_root="$1"
  local _bgm_f _bgm_age
  while IFS= read -r _bgm_f; do
    [ -z "$_bgm_f" ] && continue
    _bgm_age="$(batch_gate_marker_age_sec "$_bgm_f")"
    [ -z "$_bgm_age" ] && continue
    if [ "$_bgm_age" -lt "$BATCH_GATE_MARKER_STALE_SEC" ] 2>/dev/null; then
      return 0
    fi
  done < <(batch_gate_marker_glob "$_bgm_root")
  return 1
}

# batch_gate_marker_roster REPO_ROOT -- stdout: one JSON object per line, one per marker found
# under REPO_ROOT (any session, every marker -- never filtered to "this session's own"), split by
# the SAME staleness window every other function in this library already uses:
#   {session_id, path, age_sec, stale, task_numbers}
# `session_id` is read from the marker's own JSON (never re-derived from the filename, so a
# malformed filename never desyncs from the marker's own declared identity). `age_sec` is empty
# (not 0) on an unreadable/malformed marker, mirroring batch_gate_marker_age_sec's own emptiness-
# is-the-failure-signal contract; `stale` is then forced `true` for that row (fail-open: an
# unreadable marker is treated as abandoned, never as a live, non-stale obligation -- the same
# ruling batch_gate_marker_is_pending already applies). `task_numbers` defaults to `[]` on a
# missing/malformed field rather than failing the whole row. Never touches the filesystem beyond
# the read. This is the roster a caller renders or iterates; it is NOT itself a pending/stale
# decision for any one marker in isolation -- batch_gate_marker_is_pending stays the single
# source of truth for that boolean, and this function's own `stale` field is computed with the
# exact same comparison so the two can never disagree.
batch_gate_marker_roster() {
  local _bgm_root="$1"
  local _bgm_f _bgm_age _bgm_stale _bgm_sid _bgm_tn
  while IFS= read -r _bgm_f; do
    [ -z "$_bgm_f" ] && continue
    _bgm_age="$(batch_gate_marker_age_sec "$_bgm_f")"
    _bgm_sid="$(jq -r '.session_id // ""' "$_bgm_f" 2>/dev/null)"
    _bgm_tn="$(jq -c '.task_numbers // []' "$_bgm_f" 2>/dev/null)" || _bgm_tn='[]'
    if [ -z "$_bgm_age" ]; then
      _bgm_stale="true"
    elif [ "$_bgm_age" -ge "$BATCH_GATE_MARKER_STALE_SEC" ] 2>/dev/null; then
      _bgm_stale="true"
    else
      _bgm_stale="false"
    fi
    jq -n -c \
      --arg sid "$_bgm_sid" \
      --arg path "$_bgm_f" \
      --arg age "$_bgm_age" \
      --argjson stale "$_bgm_stale" \
      --argjson tn "$_bgm_tn" \
      '{session_id: $sid, path: $path, age_sec: ($age | if . == "" then null else tonumber end), stale: $stale, task_numbers: $tn}' \
      2>/dev/null
  done < <(batch_gate_marker_glob "$_bgm_root")
  return 0
}

# batch_gate_marker_pending_warning REPO_ROOT -- stdout: one loud, named warning line per stale
# marker found (age, path, and the staleness window), so an operator can see what was ignored
# and why. Prints nothing when no markers exist at all. Never touches the filesystem beyond the
# read.
batch_gate_marker_pending_warning() {
  local _bgm_root="$1"
  local _bgm_f _bgm_age
  while IFS= read -r _bgm_f; do
    [ -z "$_bgm_f" ] && continue
    _bgm_age="$(batch_gate_marker_age_sec "$_bgm_f")"
    if [ -z "$_bgm_age" ]; then
      echo "WARNING: batch-gate-pending marker at '$_bgm_f' is unreadable or malformed (missing/unparseable written_at) -- ignored (treated as stale, fail-open)."
    elif [ "$_bgm_age" -ge "$BATCH_GATE_MARKER_STALE_SEC" ] 2>/dev/null; then
      echo "WARNING: batch-gate-pending marker at '$_bgm_f' is ${_bgm_age}s old (>= ${BATCH_GATE_MARKER_STALE_SEC}s staleness window) -- ignored (a crashed orchestrator session likely never discharged it; this verification is NOT deferred)."
    fi
  done < <(batch_gate_marker_glob "$_bgm_root")
  return 0
}
