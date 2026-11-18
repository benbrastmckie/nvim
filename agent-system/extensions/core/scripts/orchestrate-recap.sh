#!/usr/bin/env bash
# orchestrate-recap.sh - Two-mode script for the spoken orchestration recap: `--write` persists
# a prose recap composed by the orchestrate lead at Move 5 Step 6 (see
# context/contracts/conclusion-stage.md); the default (no-args) speak mode reads the latest
# recap back, prints it, and speaks it through piper. Mirrors the existing one-script-two-modes
# shape of orchestrate-suggest-next-batch.sh.
#
# BINDING CONSTRAINT: this script is never invoked except by (a) the conclusion stage's
# `--write` call (non-fatal: a failure there warns on stderr and the stage proceeds unchanged),
# and (b) the user-only `/recap` command's default speak-mode call. Nothing on the orchestration
# path ever reaches the speak branch below -- speaking is always the separate, user-invoked `/recap`
# step.
#
# Modes:
#   orchestrate-recap.sh --write --session <session_id>
#     Reads the recap text from STDIN (never a --text argument -- the text is free-form prose
#     and must never travel through argument quoting). Writes
#     {session_id, created_ts, text} JSON to the per-session recap path
#     (lib/runtime-file-patterns.sh's runtime_recap_path). Empty stdin is a loud, non-zero
#     refusal. Creates specs/.orchestration/ if needed.
#
#   orchestrate-recap.sh
#     Default speak mode. Resolution order:
#       1. The newest `.recap-*.json` under specs/.orchestration/ by mtime, when it parses and
#          its `text` field is non-empty.
#       2. Otherwise, the newest `.return-meta-multi-*.json` under specs/.orchestration/ by
#          mtime: when it parses and carries `.status` and `.metadata.tasks_completed`/
#          `.metadata.tasks_failed`, a short mechanical sentence is composed from those fields.
#       3. Otherwise (no file, unparseable, or missing those keys), one fixed generic sentence.
#     Every branch prints the resolved text to stdout and exits 0 -- recompose never fails.
#
#     Playback: the resolved text is always printed first. Audio is then skipped (exit 0, text
#     already printed) when TTS_ENABLED=0, when `piper` is not on PATH, when `paplay` is not on
#     PATH, or when the resolved PIPER_VOICE model file does not exist. Otherwise the text is
#     written to a `mktemp` file and a backgrounded, timeout-bounded
#     `piper ... < tmpfile | paplay` pipeline is launched, the temp file removed once it exits.
#     The recap text is NEVER interpolated into a shell string (no nested `bash -c` holding the
#     message, unlike hooks/tts-notify.sh's speak() helper) -- it only ever reaches piper via
#     file redirection on stdin. No espeak-ng branch, no second TTS engine, anywhere in this file.
#
# Environment:
#   TTS_ENABLED  - "0" disables audio on every path (default: 1). Printed text is unaffected.
#   PIPER_VOICE  - Path to the piper .onnx voice model
#                  (default: $HOME/.local/share/piper/en_US-lessac-medium.onnx)
#
# Exit codes:
#   0 - ran to completion (every speak-mode branch, including every fallback)
#   1 - --write usage error or empty stdin refusal
#   2 - usage error (unrecognized arguments)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy-root-guard.sh
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/runtime-file-patterns.sh"

PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
SPECS_DIR="${PROJECT_ROOT}/specs"

TTS_ENABLED="${TTS_ENABLED:-1}"
PIPER_VOICE="${PIPER_VOICE:-$HOME/.local/share/piper/en_US-lessac-medium.onnx}"

GENERIC_SENTENCE="No recent orchestration recap is available right now."

usage() {
  cat <<'USAGE'
Usage:
  orchestrate-recap.sh --write --session <session_id>   Persist a recap (text on stdin)
  orchestrate-recap.sh                                  Speak the latest recap (default mode)
  orchestrate-recap.sh --help                            Show this help

--write mode:
  Reads the recap text from STDIN and writes it, with the session id and a creation
  timestamp, to the per-session recap file under specs/.orchestration/. Non-fatal caller
  contract: the conclusion stage warns on stderr and proceeds on a non-zero exit here.

Default (speak) mode:
  Prints the latest recap's text, then speaks it through piper unless TTS_ENABLED=0, piper
  or paplay is unavailable, or the configured voice model is missing -- in every one of those
  cases this still prints and exits 0. Recomposes a short recap from durable orchestration
  metadata when no recap file exists, rather than failing. No second TTS engine on any path.

Environment:
  TTS_ENABLED   "0" disables audio on every path (default: 1)
  PIPER_VOICE   Path to the piper .onnx voice model
                (default: $HOME/.local/share/piper/en_US-lessac-medium.onnx)
USAGE
}

# find_newest <dir> <glob-name-pattern> - echoes the newest matching path by mtime, or nothing.
# Uses find (not a bare glob) so a zero-match directory never trips `set -e`.
find_newest() {
  local dir="$1" pattern="$2"
  find "$dir" -maxdepth 1 -name "$pattern" -printf '%T@ %p\n' 2>/dev/null \
    | sort -rn \
    | head -n1 \
    | cut -d' ' -f2-
}

cmd_write() {
  local session_id=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --session)
        session_id="${2:-}"
        shift 2
        ;;
      *)
        echo "orchestrate-recap.sh --write: unrecognized argument '$1'" >&2
        exit 2
        ;;
    esac
  done

  if [ -z "$session_id" ]; then
    echo "orchestrate-recap.sh --write: --session <session_id> is required" >&2
    exit 1
  fi

  local text
  text="$(cat)"
  if [ -z "$text" ]; then
    echo "orchestrate-recap.sh --write: refused -- stdin was empty; the recap text must be piped in on stdin" >&2
    exit 1
  fi

  local recap_path
  recap_path="$(runtime_recap_path "$SPECS_DIR" "$session_id")"
  mkdir -p "$(dirname "$recap_path")"

  local created_ts tmp_path
  created_ts="$(date +%s)"
  tmp_path="${recap_path}.tmp.$$"
  jq -n --arg sid "$session_id" --argjson ts "$created_ts" --arg text "$text" \
    '{session_id: $sid, created_ts: $ts, text: $text}' > "$tmp_path"
  mv "$tmp_path" "$recap_path"
  echo "orchestrate-recap.sh --write: recap persisted to ${recap_path}"
}

# recap_text_from_recap_file <file> - echoes usable text, or nothing if unusable.
recap_text_from_recap_file() {
  local file="$1"
  [ -n "$file" ] && [ -f "$file" ] || return 0
  if jq -e '(.text != null) and ((.text | type) == "string") and ((.text | length) > 0)' "$file" >/dev/null 2>&1; then
    jq -r '.text' "$file"
  fi
}

# recap_text_from_multi_meta <file> - echoes a mechanically composed sentence, or nothing if the
# file is absent, unparseable, or missing the expected keys.
recap_text_from_multi_meta() {
  local file="$1"
  [ -n "$file" ] && [ -f "$file" ] || return 0
  if ! jq -e '(.status != null) and (.metadata.tasks_completed != null) and (.metadata.tasks_failed != null)' "$file" >/dev/null 2>&1; then
    return 0
  fi
  local status completed_n failed_n
  status="$(jq -r '.status' "$file")"
  completed_n="$(jq -r '.metadata.tasks_completed | length' "$file")"
  failed_n="$(jq -r '.metadata.tasks_failed | length' "$file")"
  if [ "$failed_n" = "0" ]; then
    echo "The last orchestration run finished with status ${status}. ${completed_n} task or tasks completed, with no failures. Check the written report for the next recommended step."
  else
    echo "The last orchestration run finished with status ${status}. ${completed_n} task or tasks completed and ${failed_n} task or tasks failed. Check the written report for what went wrong and the next recommended step."
  fi
}

cmd_speak() {
  local recap_dir="${SPECS_DIR}/.orchestration"
  local text=""

  local latest_recap
  latest_recap="$(find_newest "$recap_dir" ".recap-*.json")"
  text="$(recap_text_from_recap_file "$latest_recap")"

  if [ -z "$text" ]; then
    local latest_meta
    latest_meta="$(find_newest "$recap_dir" ".return-meta-multi-*.json")"
    text="$(recap_text_from_multi_meta "$latest_meta")"
  fi

  if [ -z "$text" ]; then
    text="$GENERIC_SENTENCE"
  fi

  echo "$text"

  if [ "$TTS_ENABLED" != "1" ]; then
    exit 0
  fi
  if ! command -v piper >/dev/null 2>&1; then
    exit 0
  fi
  if ! command -v paplay >/dev/null 2>&1; then
    exit 0
  fi
  if [ ! -f "$PIPER_VOICE" ]; then
    exit 0
  fi

  local tmp_text
  tmp_text="$(mktemp)"
  printf '%s' "$text" > "$tmp_text"
  (
    timeout 30 piper --model "$PIPER_VOICE" --output_file - --quiet < "$tmp_text" 2>/dev/null \
      | paplay >/dev/null 2>&1
    rm -f "$tmp_text"
  ) &
  disown 2>/dev/null || true
  exit 0
}

case "${1:-}" in
  --help|-h)
    usage
    exit 0
    ;;
  --write)
    shift
    cmd_write "$@"
    ;;
  "")
    cmd_speak
    ;;
  *)
    echo "orchestrate-recap.sh: unrecognized argument '$1'" >&2
    usage >&2
    exit 2
    ;;
esac
