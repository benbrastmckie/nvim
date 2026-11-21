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
# RESOLVE-ONCE PASS-THROUGH (linked repo): before the per-note loop, this script resolves this
# repo's Sapience project key AT MOST ONCE for the whole batch (mirroring sapience-remember.sh's
# own PROJECT-KEY RESOLUTION block -- see that script's header -- but duplicated rather than
# shared, for the same declared-file_scope reason that block gives for its own duplication) and
# forwards the result to every `sapience-remember.sh` call as `--project-key`, which short-
# circuits that script's own per-call GET /v1/people/projects. Net effect: a linked repo (one
# carrying `.sapience/project.json`) issues exactly one GET for a whole completed task instead of
# one per note. An unlinked repo (no binding file) takes a pure filesystem-stat path: zero GETs,
# no `--project-key` forwarded, byte-identical to pre-Phase-4 behavior. A resolution that fails
# (binding present but the GET fails or matches nothing) degrades the WHOLE batch to untagged
# writes -- never a refusal, never a dropped note -- and is mirrored by exactly one
# `infrastructure/transport unavailable` issue row recorded once up front, not per note.
#
# Exit codes: 0 on every path except a usage error (missing --task-dir or --task), which exits 1
# so a caller's `|| note` guard can distinguish misuse from a degraded write. Every
# `issue-record.sh` call this script makes is itself `|| true`-guarded: a recording failure must
# never fail this script, and this script's own failure must never fail its caller (every call
# site invokes it as `... || echo "Note: ... failed (non-fatal)" >&2`).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"
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

# --- PROJECT_ROOT: resolved from this script's own location (never from cwd), matching
#     sapience-remember.sh's identical convention -- the call sites that invoke this script
#     (orchestrate-cycle-postflight.sh, reconcile-task-status.sh) do not guarantee cwd is the
#     repo root. ---
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"

# --- resolve_checkout_toplevel <dir> -- resolves <dir> to its git toplevel, following a linked
#     worktree to its PARENT CHECKOUT rather than the worktree itself. Echoes the toplevel path
#     and returns 0, or returns 1 with no output when <dir> is not inside a git repository.
#     Logic mirrors sapience-remember.sh's own marker-delimited
#     `sapience-worktree-checkout-resolution` block, but is deliberately NOT added to that
#     block's tracked nine-file lockstep set (test-sapience-mcp-registration.sh Case 30) -- this
#     phase's own declared file_scope is limited to this script and its test suite, so the two
#     copies are intentionally independent rather than retrofitted into that list. ---
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

# --- project_binding_present -- cheap, network-free existence check for this repo's
#     `.sapience/project.json` binding file. Used only to decide whether a resolution attempt (and
#     a possible degrade issue row) is warranted at all -- the unlinked path (no binding) must
#     issue NO GET and NO issue row, staying a pure filesystem stat. ---
project_binding_present() {
  local repo_toplevel
  repo_toplevel="$(resolve_checkout_toplevel "$PROJECT_ROOT" 2>/dev/null)" || return 1
  [ -n "$repo_toplevel" ] || return 1
  [ -f "${repo_toplevel}/.sapience/project.json" ]
}

# --- resolve_project_key_once -- issues AT MOST ONE GET /v1/people/projects for the whole task
#     (never per note). Echoes the resolved key on success (one line); echoes nothing on any
#     failure (unresolvable toplevel, unreadable/malformed binding, no empty cid, no token, a
#     curl failure, a non-JSON response, or no matching entry) -- every failure path is a silent
#     "write untagged" signal to the caller, never an error. Resolution shape (host/token
#     precedence, binding-cid match) is copied from sapience-remember.sh's PROJECT-KEY
#     RESOLUTION block; see that script's header for the source of truth. ---
resolve_project_key_once() {
  local repo_toplevel link_file binding_cid config_file sapience_host sapience_token
  local encoded_token projects_url projects_response key

  repo_toplevel="$(resolve_checkout_toplevel "$PROJECT_ROOT" 2>/dev/null)" || return 0
  [ -n "$repo_toplevel" ] || return 0

  link_file="${repo_toplevel}/.sapience/project.json"
  [ -f "$link_file" ] || return 0
  jq -e . "$link_file" >/dev/null 2>&1 || return 0
  binding_cid="$(jq -r '.project // empty' "$link_file" 2>/dev/null)" || binding_cid=""
  [ -n "$binding_cid" ] || return 0

  config_file="${HOME}/.sapience/config.json"
  sapience_host="${SAPIENCE_HOST:-}"
  if [ -z "$sapience_host" ] && [ -f "$config_file" ]; then
    sapience_host="$(jq -r '.host // empty' "$config_file" 2>/dev/null)" || sapience_host=""
  fi
  [ -z "$sapience_host" ] && sapience_host="https://app.spnc.ai"
  sapience_host="${sapience_host%/}"

  sapience_token="${SAPIENCE_TOKEN:-}"
  if [ -z "$sapience_token" ] && [ -f "$config_file" ]; then
    sapience_token="$(jq -r '.token // empty' "$config_file" 2>/dev/null)" || sapience_token=""
  fi
  [ -n "$sapience_token" ] || return 0

  encoded_token="$(jq -rn --arg v "$sapience_token" '$v|@uri')"
  projects_url="${sapience_host}/v1/people/projects?token=${encoded_token}"
  projects_response="$(curl -sS --connect-timeout 3 --max-time 8 \
    -H 'X-Sapience-Client: postflight-sapience-notes.sh' \
    "$projects_url" 2>/dev/null)" || projects_response=""
  [ -n "$projects_response" ] || return 0
  printf '%s' "$projects_response" | jq -e . >/dev/null 2>&1 || return 0

  key="$(printf '%s' "$projects_response" | jq -r --arg cid "$binding_cid" '
    (if has("projects") then .projects elif (type == "array") then . else [] end) // [] |
    map(select((.cid // .id // "") == $cid)) | .[0].key // empty
  ' 2>/dev/null)" || key=""
  [ -n "$key" ] && printf '%s\n' "$key"
  return 0
}

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

# --- Resolve-once pass-through: at most ONE GET /v1/people/projects for this whole batch,
#     computed before the per-note loop starts. An unlinked repo (no binding) never calls
#     project_binding_present's network path at all, so it costs nothing and issues no GET and
#     no issue row -- see header "RESOLVE-ONCE PASS-THROUGH" for the full contract. ---
PROJECT_KEY=""
if project_binding_present; then
  PROJECT_KEY="$(resolve_project_key_once)"
  if [ -z "$PROJECT_KEY" ]; then
    issue_record --kind issue --class "infrastructure/transport unavailable" --severity minor \
      --resolution worked_around \
      --what-happened "Task ${TASK_NUMBER}: linked-repo project-key resolution (GET /v1/people/projects) failed or matched no entry for this batch of ${honored_count} note(s); writing untagged for the whole batch (degrade, no note dropped, no further GET issued by this script)."
  fi
fi

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
  [ -n "$PROJECT_KEY" ] && remember_args+=(--project-key "$PROJECT_KEY")
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
