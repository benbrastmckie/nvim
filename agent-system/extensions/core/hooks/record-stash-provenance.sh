#!/usr/bin/env bash
# record-stash-provenance.sh
# PostToolUse hook (matcher "Bash"): the write half of the stash-ownership ledger
# guard-destructive-git.sh's Phase 3 predicate reads. See scripts/lib/stash-provenance-lib.sh
# for the full mechanism (diff-across-a-whole-Bash-call, never command-text matching) and why
# that is the only approach that correctly attributes git-snapshot.sh's subprocess-invisible
# internal stash creation to the session that ran it.
#
# Contract (mirrors detect-noop-bash.sh's own documented contract, with ONE deliberate
# divergence named below):
#   - ADVISORY TO THE HARNESS: this hook never blocks a Bash call. It always exits 0 and always
#     emits `{}` on stdout.
#   - FAIL-CLOSED ON OWNERSHIP, divergent from detect-noop-bash.sh's fail-OPEN posture: this
#     hook's own exit code is still always 0 (it cannot block anything — it is a PostToolUse
#     hook with nothing left to block), but a missing/invalid session_id, a non-Bash tool_name,
#     or any internal failure means NOTHING is recorded, which is exactly the fail-closed
#     direction sp_is_owned's caller needs: an unrecorded stash sha reads as foreign later,
#     never as owned. This is the one place this hook's behavior differs in SPIRIT (not in exit
#     code — both are always 0) from detect-noop-bash.sh, whose missing-session-id case is
#     genuinely inert (there is nothing to fail toward); here it actively matters, so it is
#     called out rather than left implicit.
set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="${HOOK_DIR}/../scripts/lib/stash-provenance-lib.sh"

emit_ok() {
  echo '{}'
  exit 0
}

[ -r "$LIB" ] || emit_ok
# shellcheck source=../scripts/lib/stash-provenance-lib.sh
source "$LIB" || emit_ok

INPUT="$(cat 2>/dev/null)" || INPUT=""

if ! command -v jq >/dev/null 2>&1; then
  emit_ok
fi

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || TOOL_NAME=""
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null) || SESSION_ID=""

if [ "$TOOL_NAME" != "Bash" ] || [ -z "$SESSION_ID" ]; then
  emit_ok
fi

if ! sp_session_valid "$SESSION_ID"; then
  emit_ok
fi

sp_record_new_owned "$SESSION_ID" || true

emit_ok
