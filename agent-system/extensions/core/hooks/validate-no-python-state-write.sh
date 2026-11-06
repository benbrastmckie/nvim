#!/usr/bin/env bash
# validate-no-python-state-write.sh
# PreToolUse Bash hook: BLOCKS a live Python/interpreter re-serialization write to a state.json
# target via exit code 2. This is the companion write-time guard to
# scripts/lint/lint-state-writer-boundary.sh's Python-channel detection (gate 12): the lint can
# only see the bad shape if it lands as text in a scanned .md/.sh file. A live Bash-tool
# `python3 -c "..."` invocation that is run once and never written to any tracked file -- the
# originating incident's own shape -- is invisible to a content lint by construction. This hook
# sees it instead, because the Bash tool invocation itself IS its own trigger surface.
#
# Modeled on guard-destructive-git.sh: reads the `tool_input.command` field from stdin, scans it
# line-by-line against the shared `state-writer-boundary-patterns-lib.sh` predicate -- the SAME
# predicate `lint-state-writer-boundary.sh`'s own `classify_line` delegates to, so both
# consumers agree byte-for-byte on what counts as a violation -- and blocks via exit code 2 plus
# a stderr message naming `state-write.sh`. NOT `permissionDecision: deny`, which is
# documented-buggy for allow-listed Bash calls (see guard-destructive-git.sh's own header for
# the GH issue numbers and the full rationale).
#
# Fails OPEN (exit 0) when its own shared library cannot be sourced -- a broken write-time guard
# must never block every Bash call in the session. This is the OPPOSITE polarity from gate 12
# (a deploy gate that fails LOUD, exit 2, on a missing library, since a silent skip there would
# ship an unenforced lint): a write-time hook instead degrades to "not enforced this call"
# rather than "block everything", exactly as validate-no-task-references.sh already does for
# its own shared library.
#
# KNOWN LIMITATION: inherits the shared library's own structural model verbatim -- a
# variable-indirected path, or a write assembled across more lines than this hook's own
# line-by-line scan reads independently, is invisible here exactly as it is to the lint. See
# scripts/lib/state-writer-boundary-patterns-lib.sh's header for the full account.
#
# Exit codes:
#   0 - Allowed (no violation found, non-Bash tool, empty command, or library unavailable --
#       fail-open)
#   2 - Blocked (a write-capable Python open() call on a state.json target was found)

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$HOOK_DIR/../scripts/lib/state-writer-boundary-patterns-lib.sh"

if [ ! -f "$LIB" ]; then
  echo "WARNING: validate-no-python-state-write.sh: shared library not found at $LIB -- failing open (not blocking)" >&2
  exit 0
fi
# shellcheck disable=SC1090
# Explicit fail-open on a sourcing failure (e.g. a syntax error in the library), not just a
# missing file -- honors this hook's own documented "fails OPEN if its own shared pattern
# library cannot be sourced" contract (see header) even under a pipefail shell, where an
# unguarded `.` failure could otherwise propagate unexpectedly.
if ! . "$LIB"; then
  echo "WARNING: validate-no-python-state-write.sh: shared library at $LIB failed to source -- failing open (not blocking)" >&2
  exit 0
fi

INPUT=$(cat) || true
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || true

# Allow through if command is empty (non-Bash tool or parse failure).
if [ -z "$COMMAND" ]; then
  exit 0
fi

# Scan line-by-line: the broad candidate limb first (cheap), then the write-mode classifier only
# on a matching line -- mirrors the lint's own grep-then-classify two-step exactly, so a command
# that is allowed here is allowed there and vice versa.
while IFS= read -r line; do
  if [[ "$line" =~ $STATE_WRITER_PY_CANDIDATE_LIMB ]]; then
    verdict="$(state_writer_py_classify_line "$line")"
    if [ "$verdict" = "VIOLATION" ]; then
      echo "BLOCKED: this command writes to a state.json target through a Python open() call:" >&2
      echo "  $line" >&2
      echo "Per context/patterns/task-lock.md's State-Write Convention, the only sanctioned writer" >&2
      echo "for specs/state.json, specs/archive/state.json, or a vault-root state.json is" >&2
      echo "scripts/state-write.sh -- pass your jq filter plus any --arg/--argjson bindings to it" >&2
      echo "rather than a Python json.load/json.dump in-place write (with or without" >&2
      echo "ensure_ascii=False -- both bypass its acquire -> stage -> transform -> validate -> mv ->" >&2
      echo "release sequence)." >&2
      exit 2
    fi
  fi
done <<< "$COMMAND"

exit 0
