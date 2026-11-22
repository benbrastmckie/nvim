#!/usr/bin/env bash
# lean-challenge-observe.sh -- the lean extension's post-task observer: gives the Lean Challenge
# snapshot (lean-challenge-snapshot.sh) its producing call site at plan time and its first
# consuming (--check) call site on the implement side, from one registration.
#
# OBSERVER EXECUTION CONTRACT (docs/guides/creating-extensions.md's "Post-Task Observers"
# section): invoked by run-task-observers.sh with exactly six positional arguments, in this
# fixed order:
#
#   $1 task_number   $2 task_type   $3 topic   $4 task_dir   $5 session_id   $6 resting_status
#
# Usage:
#   lean-challenge-observe.sh TASK_NUMBER TASK_TYPE TOPIC TASK_DIR SESSION_ID RESTING_STATUS
#
# ADVISORY AND NON-BLOCKING, NOT NEGOTIABLE. This script can never change task status, never fail
# a dispatch, never block orchestration -- run-task-observers.sh records this script's own exit
# code as one task_observer_run event and otherwise ignores it entirely. Every live-mode
# invocation therefore ALWAYS exits 0, whatever the underlying snapshot invocation did or did not
# manage to do. The ONLY non-zero exit is a true usage error in THIS script's own arguments
# (exit 2), matching books-observe.sh's own usage-error convention.
#
# STATUS DISCRIMINATION ($6 resting_status is the single dispatch key):
#   planned                                   -> produce: invoke the snapshot script with NO
#                                                 --force, so the exit-73 status gate (still
#                                                 admitting `planned`) and the exit-73
#                                                 manifest-exists refusal are both left to decide
#                                                 for themselves whether a snapshot is taken.
#   implementing, partial, pr_ready, completed -> consume: invoke the snapshot script's --check
#                                                 drift verdict.
#   anything else                              -> no-op. In particular researched/planning (still
#                                                 pre-implementation, but not the one producing
#                                                 status) and blocked/abandoned/expanded are all
#                                                 deliberately left alone.
#
# NO PLAN-CONTENT CLASSIFICATION HERE. This script never inspects a plan's
# `## Lean Challenge Statements` section, never decides what counts as a zero-goal plan, and
# never interprets a drift finding. Every one of those judgments belongs to
# lean-challenge-snapshot.sh alone; this observer only dispatches to it on resting_status and
# echoes the resulting exit code to stderr for the captured task_observer_run event.
#
# RESOLUTION. The snapshot script is resolved by BASENAME against the deployed
# `.claude/scripts/` directory -- the identical resolution contract run-task-observers.sh itself
# already applies to resolve THIS observer. This script relies on its OWN inherited working
# directory to BE the repo root that owns that `.claude/scripts/` tree and the `specs/` directory
# the snapshot script in turn resolves relative to its own CWD (see that script's CWD-convention
# comment) -- the single-repo assumption this seam makes explicit rather than hides. A Lean
# project nested below the repo root, or living in a different repository from the `specs/` tree
# that drives it, is not supported.
#
# A missing or non-executable snapshot script is reported with one stderr NOTE and treated
# exactly like every other advisory outcome: exit 0, nothing attempted.
#
# Exit codes:
#   0 - always, in live mode (the advisory role). Read the stderr NOTE/log line, not the exit
#       code, to learn what the underlying snapshot invocation actually did.
#   2 - usage error in THIS script's own arguments (wrong positional count).

set -uo pipefail

usage() {
  echo "Usage: lean-challenge-observe.sh TASK_NUMBER TASK_TYPE TOPIC TASK_DIR SESSION_ID RESTING_STATUS" >&2
  exit 2
}

[ $# -eq 6 ] || usage

TASK_NUMBER="$1"
TASK_TYPE="$2"
TOPIC="$3"
TASK_DIR="$4"
SESSION_ID="$5"
RESTING_STATUS="$6"
# task_type/topic/task_dir/session_id are part of the fixed six-positional contract (see header)
# but are not consumed by this observer's own dispatch logic, which keys on resting_status alone
# (manifest-level matching on task_type already happened before this script was ever invoked).
: "${TASK_TYPE:-}" "${TOPIC:-}" "${TASK_DIR:-}" "${SESSION_ID:-}"

# Resolve the snapshot script by basename against the deployed .claude/scripts/ directory,
# relative to this process's inherited working directory (see the RESOLUTION comment above).
SNAPSHOT_SCRIPT_BASENAME="lean-challenge-snapshot.sh"
SNAPSHOT_SCRIPT=".claude/scripts/${SNAPSHOT_SCRIPT_BASENAME}"

if [ ! -e "$SNAPSHOT_SCRIPT" ]; then
  echo "NOTE: lean-challenge-observe.sh: ${SNAPSHOT_SCRIPT} not found -- skipping (advisory, non-blocking)" >&2
  exit 0
fi
if [ ! -x "$SNAPSHOT_SCRIPT" ]; then
  echo "NOTE: lean-challenge-observe.sh: ${SNAPSHOT_SCRIPT} not executable -- skipping (advisory, non-blocking)" >&2
  exit 0
fi

case "$RESTING_STATUS" in
  planned)
    "$SNAPSHOT_SCRIPT" "$TASK_NUMBER" "."
    snapshot_rc=$?
    echo "lean-challenge-observe.sh: snapshot invocation at resting_status=planned exited rc=${snapshot_rc}" >&2
    ;;
  implementing|partial|pr_ready|completed)
    "$SNAPSHOT_SCRIPT" --check "$TASK_NUMBER" "."
    snapshot_rc=$?
    echo "lean-challenge-observe.sh: --check invocation at resting_status=${RESTING_STATUS} exited rc=${snapshot_rc}" >&2
    ;;
  *)
    : # no-op -- every other resting status (researched, planning, blocked, abandoned,
      # expanded, not_started, or anything unrecognized) is deliberately left alone.
    ;;
esac

# Non-blocking by construction: whatever the dispatch above returned, this observer always
# exits 0 in live mode (see the ADVISORY AND NON-BLOCKING header comment).
exit 0
