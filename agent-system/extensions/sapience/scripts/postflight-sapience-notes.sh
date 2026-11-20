#!/usr/bin/env bash
# postflight-sapience-notes.sh - The single mechanically-anchored site where a completing task's
# agent-authored sapience_notes array actually reaches the Sapience vault.
#
# Usage: postflight-sapience-notes.sh --task-dir PATH --task N [--session-id S] [--phase P]
#                                      [--dispatch-seq N] [--dry-run]
#
# Reads <task-dir>/.return-meta.json's top-level `sapience_notes` array (producer: the completing
# implementation agent; see context/formats/return-metadata-file.md's `### sapience_notes
# (optional)` section) and issues one `sapience-remember.sh` call per honored note, non-fatally.
# This script performs the read itself, rather than depending on a value threaded through
# propagation machinery, so both the live `/orchestrate` completion path
# (`orchestrate-cycle-postflight.sh`) and the deferred reconcile path (`reconcile-task-status.sh`,
# which bypasses `skill_postflight_update` and every propagation helper entirely) reach the same
# one write site.
#
# Presence guard: if this script's own sibling `sapience-remember.sh` is absent (the sapience
# extension is not loaded in this repository), this script exits 0 silently with no issue row.
# An unloaded extension is not a knowledge-capture gap.
#
# The 8-note ceiling is a pre-write `jq length` check performed ONCE before any write is issued,
# never a counter incremented inside the per-note loop -- an array of length > 8 is sliced to the
# first 8 before the loop ever starts. A length of exactly 0 skips the loop entirely and records
# exactly one `knowledge-capture gap` issue row (see context/formats/issue-log.md) rather than
# writing nothing silently.
#
# Per-note degrade: a non-zero `sapience-remember.sh` exit for one note is mirrored by one
# `infrastructure/transport unavailable` issue row carrying that call's stderr, and the loop
# CONTINUES to the remaining notes -- never aborts on first failure, never retries.
#
# Exit codes: 0 on every path except a usage error (missing --task-dir or --task), which exits 1
# so a caller's `|| note` guard can distinguish misuse from a degraded write. Every
# `issue-record.sh` call this script makes is itself `|| true`-guarded: a recording failure must
# never fail this script, and this script's own failure must never fail its caller (every call
# site invokes it as `... || echo "Note: ... failed (non-fatal)" >&2`).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1

usage() {
  cat >&2 <<'USAGE'
Usage: postflight-sapience-notes.sh --task-dir PATH --task N [--session-id S] [--phase P]
                                     [--dispatch-seq N] [--dry-run]

Required:
  --task-dir PATH   The task directory holding .return-meta.json (used verbatim).
  --task N          Task number (unpadded), used in issue-record.sh --what-happened text.

Optional:
  --session-id S    Forwarded to issue-record.sh --session.
  --phase P         Forwarded to issue-record.sh --phase.
  --dispatch-seq N  Forwarded to issue-record.sh --dispatch-seq.
  --dry-run         Forwarded to every sapience-remember.sh call; prints the redacted request
                     body for each honored note instead of issuing a network call.

Exit codes:
  0 - every path except a usage error (every degrade is recorded non-fatally, never raised)
  1 - usage error (missing --task-dir or --task)
USAGE
}

TASK_DIR=""
TASK_NUMBER=""
SESSION_ID=""
PHASE=""
DISPATCH_SEQ=""
DRY_RUN="false"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --task-dir)
      [ "$#" -ge 2 ] || { echo "postflight-sapience-notes.sh: --task-dir requires a value" >&2; exit 1; }
      TASK_DIR="$2"; shift 2 ;;
    --task)
      [ "$#" -ge 2 ] || { echo "postflight-sapience-notes.sh: --task requires a value" >&2; exit 1; }
      TASK_NUMBER="$2"; shift 2 ;;
    --session-id)
      [ "$#" -ge 2 ] || { echo "postflight-sapience-notes.sh: --session-id requires a value" >&2; exit 1; }
      SESSION_ID="$2"; shift 2 ;;
    --phase)
      [ "$#" -ge 2 ] || { echo "postflight-sapience-notes.sh: --phase requires a value" >&2; exit 1; }
      PHASE="$2"; shift 2 ;;
    --dispatch-seq)
      [ "$#" -ge 2 ] || { echo "postflight-sapience-notes.sh: --dispatch-seq requires a value" >&2; exit 1; }
      DISPATCH_SEQ="$2"; shift 2 ;;
    --dry-run)
      DRY_RUN="true"; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "postflight-sapience-notes.sh: unknown flag: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [ -z "$TASK_DIR" ] || [ -z "$TASK_NUMBER" ]; then
  echo "postflight-sapience-notes.sh: --task-dir and --task are both required" >&2
  usage
  exit 1
fi

# --- Presence guard: an unloaded sapience extension is not a knowledge-capture gap. ---
if [ ! -f "${SCRIPT_DIR}/sapience-remember.sh" ]; then
  exit 0
fi

# --- issue_record -- non-fatal wrapper around issue-record.sh, forwarding the optional
#     --session/--phase/--dispatch-seq context this script itself received. A recording failure
#     never fails this script. ---
issue_record() {
  local _rc=0
  local -a _issue_args=(--task-dir "$TASK_DIR")
  [ -n "$SESSION_ID" ] && _issue_args+=(--session "$SESSION_ID")
  [ -n "$PHASE" ] && _issue_args+=(--phase "$PHASE")
  [ -n "$DISPATCH_SEQ" ] && _issue_args+=(--dispatch-seq "$DISPATCH_SEQ")
  _issue_args+=("$@")
  "${SCRIPT_DIR}/issue-record.sh" "${_issue_args[@]}" >/dev/null 2>&1 || _rc=$?
  [ "$_rc" -eq 0 ] || echo "postflight-sapience-notes.sh: issue-record.sh call failed (non-fatal, rc=$_rc)" >&2
  return 0
}

# --- Read sapience_notes from .return-meta.json, failing closed to [] on a missing, unreadable,
#     or malformed file -- this script performs this read itself rather than depending on a
#     value threaded through propagation machinery neither completion path reliably exercises. ---
RETURN_META="${TASK_DIR}/.return-meta.json"
notes_json="$(jq -c '.sapience_notes // []' "$RETURN_META" 2>/dev/null)" || notes_json="[]"
if ! printf '%s' "$notes_json" | jq -e 'type == "array"' >/dev/null 2>&1; then
  notes_json="[]"
fi

count="$(printf '%s' "$notes_json" | jq 'length')"

if [ "$count" -eq 0 ]; then
  issue_record --kind issue --class "knowledge-capture gap" --severity minor --resolution open \
    --what-happened "Task ${TASK_NUMBER} completed with no sapience_notes emitted in .return-meta.json; no durable knowledge-capture note was written at this completion boundary."
  exit 0
fi

honored_json="$notes_json"
if [ "$count" -gt 8 ]; then
  honored_json="$(printf '%s' "$notes_json" | jq -c '.[0:8]')"
  echo "postflight-sapience-notes.sh: ${count} sapience_notes emitted, honoring only the first 8 (ceiling)" >&2
  issue_record --kind issue --class "tooling bug or gap" --severity minor \
    --what-happened "Task ${TASK_NUMBER} emitted ${count} sapience_notes, exceeding the 8-note ceiling; only the first 8 were honored and written via sapience-remember.sh, the remaining $((count - 8)) discarded."
fi

honored_count="$(printf '%s' "$honored_json" | jq 'length')"

i=0
while [ "$i" -lt "$honored_count" ]; do
  entry="$(printf '%s' "$honored_json" | jq -c ".[$i]")"
  subject="$(printf '%s' "$entry" | jq -r '.subject // empty')"
  value="$(printf '%s' "$entry" | jq -r '.value // empty')"

  # Producer schema violation (missing/empty required subject and/or value) is NOT a
  # transport failure -- classify and skip before ever invoking sapience-remember.sh (which
  # would itself refuse the call with "--subject and --value are both required"). Reuses the
  # "knowledge-capture gap" class already used for the zero-notes case above: a malformed
  # entry is the same class of fault as no entry at all -- no durable note reaches the vault.
  # Fail-soft posture preserved: never abort the postflight, skip this one entry and continue.
  if [ -z "$subject" ] || [ -z "$value" ]; then
    offending_keys="$(printf '%s' "$entry" | jq -r 'keys | join(", ")' 2>/dev/null)" || offending_keys=""
    [ -n "$offending_keys" ] || offending_keys="(unparseable entry)"
    issue_record --kind issue --class "knowledge-capture gap" --severity minor --resolution open \
      --what-happened "sapience_notes entry $((i + 1))/${honored_count} of task ${TASK_NUMBER} is missing required subject and/or value (producer schema violation, not a transport failure) -- entry's top-level keys: [${offending_keys}]. Skipped; not written to the vault."
    i=$((i + 1))
    continue
  fi

  predicate="$(printf '%s' "$entry" | jq -r '.predicate // empty')"
  ko_type="$(printf '%s' "$entry" | jq -r '.ko_type // empty')"
  confidence="$(printf '%s' "$entry" | jq -r 'if (.confidence == null) then "" else (.confidence | tostring) end')"
  source_loc="$(printf '%s' "$entry" | jq -r '.source_loc // empty')"

  remember_args=(--subject "$subject" --value "$value")
  [ -n "$predicate" ] && remember_args+=(--predicate "$predicate")
  [ -n "$ko_type" ] && remember_args+=(--ko-type "$ko_type")
  [ -n "$confidence" ] && remember_args+=(--confidence "$confidence")
  [ -n "$source_loc" ] && remember_args+=(--source-loc "$source_loc")
  [ "$DRY_RUN" = "true" ] && remember_args+=(--dry-run)

  remember_out=""
  remember_rc=0
  remember_out="$("${SCRIPT_DIR}/sapience-remember.sh" "${remember_args[@]}" 2>&1)" || remember_rc=$?

  if [ "$remember_rc" -ne 0 ]; then
    issue_record --kind issue --class "infrastructure/transport unavailable" --severity minor \
      --resolution worked_around \
      --what-happened "sapience-remember.sh failed for note $((i + 1))/${honored_count} of task ${TASK_NUMBER} (subject: ${subject}): ${remember_out}"
  elif [ "$DRY_RUN" = "true" ]; then
    printf '%s\n' "$remember_out"
  fi

  i=$((i + 1))
done

exit 0
