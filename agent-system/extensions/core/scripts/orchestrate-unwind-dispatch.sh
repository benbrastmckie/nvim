#!/usr/bin/env bash
# orchestrate-unwind-dispatch.sh - By-hand recovery for a prepared /orchestrate dispatch that was
# never issued (no Agent call, no postflight).
#
# orchestrate-cycle-plan.sh's LIVE Move 1 changes six things for one task before any agent ever
# runs: the preflight status/last_updated/session_id write, the task lock, the .dispatch/{seq}.md
# file, the durable dispatch_seq_counter, pending_dispatch (both in the task's own
# .orchestrator-loop-guard file), and the run's ephemeral multi-state file. When the operator
# decides that prepared dispatch is unwanted (a crash between Move 1 and Move 2, or a
# deliberately abandoned plan), this script reverses all of it in one shot, or refuses cleanly
# and touches nothing. It is the sanctioned alternative to guard-destructive-git.sh-blocked git
# surgery and to hand-editing state.json -- see docs/architecture/orchestrate-state-machine.md's
# "Unwinding an Unconsumed Dispatch" subsection and context/standards/git-safety.md's
# "Recovering an Unconsumed Dispatch" subsection.
#
# This is a BY-HAND tool only. It is never invoked automatically by the orchestrate loop -- see
# the state-machine doc for the by-hand-only rationale (Decision 7 of the originating plan).
#
# Usage:
#   orchestrate-unwind-dispatch.sh <task_number> --session SID [--dry-run] [--commit]
#                                  [--mt-state FILE]
#
# Arguments:
#   task_number   Required. The task whose prepared-but-unissued dispatch is being unwound.
#   --session SID Required. The session_id of the /orchestrate run that PREPARED the dispatch
#                 being unwound (the bare form, e.g. "sess_1234_abcdef" -- never the
#                 phase-suffixed "SID_<task>" form research/plan preflight writes to state.json).
#                 Used both to find the run's multi-state file (unless --mt-state overrides) and
#                 to cross-check that the task's CURRENT state.json session_id is one this exact
#                 session could have written (see the refusal gate below).
#   --dry-run     Optional. Prints every action this run would take and exits 0. No writes, no
#                 mutation of any kind -- safe to run purely to inspect what would happen.
#   --commit      Optional. After a successful unwind, commits the two tracked paths this script
#                 touches (specs/state.json, specs/TODO.md) via git-commit-scoped.sh. Absent by
#                 default -- the state.json/TODO.md restoration happens either way; this flag only
#                 controls whether it is also committed. Never uses destructive git.
#   --mt-state FILE
#                 Optional. Names the run's multi-state file explicitly. Default:
#                 "specs/.orchestration/.orchestrator-multi-state-${SID}.json" (relative to the
#                 repo root, via the shared runtime_mt_state_path() resolver). If the resolved
#                 file does not exist, or does not carry this task, this step is a logged no-op
#                 (best-effort; never fatal -- see Decision 5 of the originating plan's
#                 "Multi-state file" note).
#
# Refusal gate (Decision 3): ALL of the following must hold, or the script refuses (exit 2) and
# touches NOTHING:
#   1. The task has a `pending_dispatch` record in its durable .orchestrator-loop-guard file.
#   2. That record carries all four `prior_*` fields (prior_status, prior_last_updated,
#      prior_session_id, prior_dispatch_seq_counter). A record written before this task's own
#      Phase 1 change lacks these fields entirely -- a LEGACY record -- and is refused by name
#      (Decision 2): no override flag exists to force it, since guessing a pre-dispatch status
#      from nothing but the CURRENT status is exactly the destructive direction this script
#      exists to avoid. Hand recovery remains available and is documented.
#   3. The record's `dispatch_file` still exists on disk (the same "was this ever consumed"
#      proof orchestrate-cycle-plan.sh's own UNCONSUMED DISPATCH REPLAY check uses).
#   4. Neither the task's `.return-meta.json` nor `.orchestrator-handoff.json` is newer than the
#      dispatch file -- an agent's Stage 0 writes one of these as its very first act, so a newer
#      one is proof an agent already started. A dispatch an agent has started, or that postflight
#      has already consumed, must NEVER be unwound.
#   5. The task's state.json entry's CURRENT session_id is one this exact dispatch could have
#      written: either the bare `SID` (implement's own convention) or `SID_<task_number>`
#      (research/plan's suffixed convention). A different current session_id means a later run
#      already advanced past this dispatch -- unwinding now would silently discard that.
#   6. The task lock is absent, stale, or held by `SID`. A FRESH lock held by a different session
#      means another run is live right now: refuse rather than race it.
#
# Unwind sequence (once every gate above holds), in this exact order:
#   1. Restore state.json's status/last_updated/session_id to the recorded pre-dispatch values,
#      via state-write.sh (the sanctioned writer) with --regen-todo, so TODO.md reflects the
#      restoration in the same step.
#   2. orchestrate-loop-guard-init.sh --flush-seq back to prior_dispatch_seq_counter (falling back
#      to `seq - 1` only for a record that predates that exact field -- never reachable given gate
#      #2 above, which already refuses a record missing it; the fallback exists purely as
#      defense-in-depth).
#   3. orchestrate-loop-guard-init.sh --clear-pending.
#   4. Delete the .dispatch/{seq}.md file.
#   5. Best-effort patch of the run's multi-state file (see --mt-state above).
#   6. Release the task lock -- ALWAYS via the bare `SID`, delegating to task-lock.sh release's
#      own built-in holder-identity check (it already WARNs and leaves a foreign-held lock alone
#      rather than force-removing it; this script adds no second check on top of that).
#   7. With --commit, a single scoped commit of specs/state.json + specs/TODO.md.
#
# Exit codes:
#   0 - success (unwind applied, or --dry-run preview)
#   1 - usage error (bad/missing arguments); nothing touched
#   2 - refused by the gate above, or a required collaborator/library was not found; nothing
#       touched
#
# MUST NOT: use any destructive git operation, or add an exemption to guard-destructive-git.sh
# (see context/standards/git-safety.md).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
STATE_FILE="$PROJECT_ROOT/specs/state.json"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/task-lookup-lib.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/runtime-file-patterns.sh"

usage() {
  cat >&2 <<'EOF'
Usage: orchestrate-unwind-dispatch.sh <task_number> --session SID [--dry-run] [--commit]
                                       [--mt-state FILE]

Unwinds a /orchestrate dispatch that was PREPARED but never ISSUED (no agent call, no
postflight): restores state.json's status/last_updated/session_id, the durable
dispatch_seq_counter, releases the task lock, deletes the .dispatch/{seq}.md file, clears
pending_dispatch, and best-effort patches the run's multi-state file.

Refuses (exit 2, touching nothing) unless a pending_dispatch record with the full prior_*
pre-image exists, its dispatch_file is still on disk, no agent has started (no newer
.return-meta.json/.orchestrator-handoff.json), the current session_id matches this dispatch, and
the task lock is not freshly held by another session.

See this script's own header comment for the full contract.
EOF
}

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: orchestrate-unwind-dispatch.sh: jq is not available." >&2
  exit 2
fi

# --- Argument parsing ---------------------------------------------------------------------------
task_number=""
session_id=""
dry_run=false
do_commit=false
mt_state_override=""

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --session)
      session_id="${2:-}"
      [ $# -ge 2 ] && shift
      shift
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    --commit)
      do_commit=true
      shift
      ;;
    --mt-state)
      mt_state_override="${2:-}"
      [ $# -ge 2 ] && shift
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      echo "ERROR: orchestrate-unwind-dispatch.sh: unrecognized option '$1'." >&2
      usage
      exit 1
      ;;
    *)
      if [ -z "$task_number" ]; then
        task_number="$1"
      else
        echo "ERROR: orchestrate-unwind-dispatch.sh: unexpected extra argument '$1'." >&2
        usage
        exit 1
      fi
      shift
      ;;
  esac
done

case "$task_number" in
  ''|*[!0-9]*)
    echo "ERROR: orchestrate-unwind-dispatch.sh: <task_number> is required and must be a positive integer." >&2
    usage
    exit 1
    ;;
esac
if [ -z "$session_id" ]; then
  echo "ERROR: orchestrate-unwind-dispatch.sh: --session SID is required." >&2
  usage
  exit 1
fi

# --- Resolve the task directory (sourced lookup helpers, never a hand-built path) ----------------
entry=$(task_lookup_entry "$task_number" "$STATE_FILE") || entry=""
if [ -z "$entry" ] || [ "$entry" = "null" ]; then
  echo "ERROR: task $task_number not found in $STATE_FILE (active or archived) -- nothing to unwind." >&2
  exit 2
fi
project_name=$(printf '%s' "$entry" | jq -r '.project_name // ""')
if [ -z "$project_name" ]; then
  echo "ERROR: task $task_number's state.json entry has no project_name -- cannot resolve its directory." >&2
  exit 2
fi
task_dir_rel="$(task_lookup_dir "$task_number" "$project_name" "$PROJECT_ROOT")"
task_dir_abs="${PROJECT_ROOT}/${task_dir_rel}"
guard_file="${task_dir_abs}/.orchestrator-loop-guard"

if [ ! -d "$task_dir_abs" ]; then
  echo "ERROR: task $task_number's directory ($task_dir_rel) does not exist -- nothing to unwind." >&2
  exit 2
fi

# --- Gate #1/#2: pending_dispatch must exist and carry the full prior_* pre-image ----------------
seed_out=$(bash "$SCRIPT_DIR/orchestrate-loop-guard-init.sh" --seed "$task_dir_abs") || {
  echo "ERROR: orchestrate-unwind-dispatch.sh: could not read $guard_file via orchestrate-loop-guard-init.sh --seed." >&2
  exit 2
}
pending=$(printf '%s' "$seed_out" | jq -c '.pending_dispatch // null')
if [ "$pending" = "null" ] || [ -z "$pending" ]; then
  echo "ERROR: task $task_number has no pending_dispatch recorded in $guard_file -- nothing to unwind (it may already have been consumed, or was never a live dispatch)." >&2
  exit 2
fi

missing_fields=""
for f in prior_status prior_last_updated prior_session_id prior_dispatch_seq_counter; do
  if ! printf '%s' "$pending" | jq -e --arg f "$f" 'has($f)' >/dev/null 2>&1; then
    missing_fields="${missing_fields}${missing_fields:+, }${f}"
  fi
done
if [ -n "$missing_fields" ]; then
  echo "ERROR: task $task_number's pending_dispatch record predates the prior_* pre-image (missing: ${missing_fields}) -- this is a LEGACY record this script refuses to guess at. Hand recovery is the only option for this record; see docs/architecture/orchestrate-state-machine.md's 'Unwinding an Unconsumed Dispatch' subsection." >&2
  exit 2
fi

dispatch_file=$(printf '%s' "$pending" | jq -r '.dispatch_file // ""')
phase=$(printf '%s' "$pending" | jq -r '.phase // ""')
seq=$(printf '%s' "$pending" | jq -r '.seq // empty')
forced=$(printf '%s' "$pending" | jq -r '.forced // false')
prior_status=$(printf '%s' "$pending" | jq -r '.prior_status // ""')
prior_last_updated=$(printf '%s' "$pending" | jq -r '.prior_last_updated // ""')
prior_session_id=$(printf '%s' "$pending" | jq -r '.prior_session_id // ""')
prior_dispatch_seq_counter=$(printf '%s' "$pending" | jq -r '.prior_dispatch_seq_counter // empty')

if [ -z "$prior_status" ]; then
  echo "ERROR: task $task_number's pending_dispatch pre-image has an empty prior_status -- this task had no state.json entry before the dispatch it recorded. Restoring 'no entry at all' is out of scope for this script; hand recovery only." >&2
  exit 2
fi

# --- Gate #3: the dispatch_file must still be on disk (proof postflight never consumed it) -------
if [ -z "$dispatch_file" ] || [ ! -f "$dispatch_file" ]; then
  echo "ERROR: task $task_number's recorded dispatch_file ('${dispatch_file:-<empty>}') is already gone -- either postflight already consumed it, or it was deleted by hand. This script refuses to unwind a dispatch it cannot prove is unconsumed. Run this script BEFORE any manual cleanup next time." >&2
  exit 2
fi

# --- Gate #4: no agent has started (Stage 0 writes .return-meta.json/.orchestrator-handoff.json
# as its very first act -- a copy newer than the dispatch file is proof an agent already ran) ----
for f in "$task_dir_abs/.return-meta.json" "$task_dir_abs/.orchestrator-handoff.json"; do
  if [ -f "$f" ] && [ "$f" -nt "$dispatch_file" ]; then
    echo "ERROR: task $task_number's $(basename "$f") is newer than the dispatch file -- an agent appears to have already started (or finished) this dispatch. This script refuses to unwind a dispatch that has begun; it only ever unwinds a dispatch that was prepared and never issued." >&2
    exit 2
  fi
done

# --- Gate #5: the CURRENT state.json session_id must be one THIS dispatch could have written ----
current_session_id=$(printf '%s' "$entry" | jq -r '.session_id // ""')
suffixed_session_id="${session_id}_${task_number}"
if [ -n "$current_session_id" ] && [ "$current_session_id" != "$session_id" ] && [ "$current_session_id" != "$suffixed_session_id" ]; then
  echo "ERROR: task $task_number's CURRENT state.json session_id ('$current_session_id') does not match the given --session ('$session_id', bare or suffixed) -- a different run may already have advanced past this dispatch. Refusing rather than risk discarding that later work." >&2
  exit 2
fi

# --- Gate #6: the task lock is absent, stale, or held by SID -- a FRESH foreign lock refuses -----
lock_check_out=""
lock_check_exit=0
if lock_check_out=$(bash "$SCRIPT_DIR/task-lock.sh" check "$task_number" 2>&1); then
  lock_check_exit=0
else
  lock_check_exit=$?
fi
if [ "$lock_check_exit" -eq 1 ]; then
  held_session=$(printf '%s' "$lock_check_out" | sed -n 's/.*session=\([^ ]*\).*/\1/p')
  if [ "$held_session" != "$session_id" ]; then
    echo "ERROR: task $task_number's lock is FRESH and held by a different session ('$held_session') -- another run appears to be live right now. Refusing rather than race it." >&2
    exit 2
  fi
elif [ "$lock_check_exit" -gt 2 ]; then
  echo "ERROR: orchestrate-unwind-dispatch.sh: task-lock.sh check errored unexpectedly (exit $lock_check_exit): $lock_check_out" >&2
  exit 2
fi
# exit 0 (free) or exit 2 (stale) both proceed -- a stale lock is not a live-run signal.

# --- Resolve the multi-state file (best-effort; see --mt-state) ---------------------------------
if [ -n "$mt_state_override" ]; then
  case "$mt_state_override" in
    /*) mt_state_file="$mt_state_override" ;;
    *) mt_state_file="$PROJECT_ROOT/$mt_state_override" ;;
  esac
else
  mt_state_file="$(runtime_mt_state_path "$PROJECT_ROOT/specs" "$session_id")"
fi

restore_dsc="$prior_dispatch_seq_counter"
if [ -z "$restore_dsc" ]; then
  # Defense-in-depth only -- unreachable given the Gate #2 refusal above, which already requires
  # this field to be present.
  restore_dsc=$(( seq > 0 ? seq - 1 : 0 ))
fi

# --- --dry-run: print every action, touch nothing, exit 0 ---------------------------------------
if [ "$dry_run" = "true" ]; then
  echo "[orchestrate-unwind-dispatch] DRY-RUN -- task $task_number ($task_dir_rel), phase=$phase, forced=$forced, seq=$seq"
  echo "[orchestrate-unwind-dispatch] would restore state.json: status='$prior_status' last_updated='$prior_last_updated' session_id='$prior_session_id'"
  echo "[orchestrate-unwind-dispatch] would regenerate TODO.md"
  echo "[orchestrate-unwind-dispatch] would flush dispatch_seq_counter in $guard_file back to $restore_dsc"
  echo "[orchestrate-unwind-dispatch] would clear pending_dispatch in $guard_file"
  echo "[orchestrate-unwind-dispatch] would delete dispatch file: $dispatch_file"
  if [ -f "$mt_state_file" ]; then
    echo "[orchestrate-unwind-dispatch] would best-effort patch multi-state file: $mt_state_file"
  else
    echo "[orchestrate-unwind-dispatch] multi-state file not found ($mt_state_file) -- would be a no-op"
  fi
  echo "[orchestrate-unwind-dispatch] would release the task lock (only if held by '$session_id')"
  if [ "$do_commit" = "true" ]; then
    echo "[orchestrate-unwind-dispatch] would commit specs/state.json specs/TODO.md via git-commit-scoped.sh"
  fi
  exit 0
fi

# =================================================================================================
# LIVE UNWIND (every gate above held)
# =================================================================================================

# (1) Restore state.json's status/last_updated/session_id, regenerating TODO.md in the same step.
# `del(...)` when the pre-image field was absent (rather than assigning an empty string), so a
# task that never had a session_id/last_updated before this dispatch is restored to that exact
# absent shape, not a spurious empty-string field.
# shellcheck disable=SC2016 # single-quoted deliberately: these are jq's own $-bindings, passed
# via --arg/--argjson below, never meant to be shell-expanded.
restore_filter='(.active_projects[] | select(.project_number == $num)) |= (
  .status = $status
  | (if $lu == "" then del(.last_updated) else .last_updated = $lu end)
  | (if $sid == "" then del(.session_id) else .session_id = $sid end)
)'
bash "$SCRIPT_DIR/state-write.sh" "$restore_filter" \
  --session-id "$session_id" \
  --argjson num "$task_number" \
  --arg status "$prior_status" \
  --arg lu "$prior_last_updated" \
  --arg sid "$prior_session_id" \
  --regen-todo

# (2) Flush the durable dispatch_seq_counter back to its pre-charge value.
bash "$SCRIPT_DIR/orchestrate-loop-guard-init.sh" --flush-seq "$task_dir_abs" "$restore_dsc" >/dev/null

# (3) Clear pending_dispatch.
bash "$SCRIPT_DIR/orchestrate-loop-guard-init.sh" --clear-pending "$task_dir_abs" >/dev/null

# (4) Delete the dispatch file.
rm -f "$dispatch_file"

# (5) Best-effort multi-state file patch (never fatal -- field-shape drift here must not abort an
# otherwise-successful unwind of the durable state, which is the part that actually matters).
if [ -f "$mt_state_file" ] && jq empty "$mt_state_file" >/dev/null 2>&1; then
  if jq -e --arg t "$task_number" 'has("dispatch_seq") and (.dispatch_seq | has($t)) or has("cycle_counts") and (.cycle_counts | has($t))' "$mt_state_file" >/dev/null 2>&1; then
    mt_tmp="${mt_state_file}.tmp.$$"
    if jq --arg t "$task_number" --argjson seq "${seq:-0}" --argjson prior_dsc "$restore_dsc" '
        del(.dispatch_seq[$t]?)
        | .cycle_counts[$t] = (((.cycle_counts[$t] // 0) - 1) as $c | if $c < 0 then 0 else $c end)
        | if (.dispatch_seq_counter // null) == $seq then .dispatch_seq_counter = $prior_dsc else . end
      ' "$mt_state_file" > "$mt_tmp" && jq empty "$mt_tmp" >/dev/null 2>&1; then
      mv "$mt_tmp" "$mt_state_file"
      echo "[orchestrate-unwind-dispatch] patched multi-state file: $mt_state_file"
    else
      rm -f "$mt_tmp"
      echo "WARN: orchestrate-unwind-dispatch.sh: could not patch multi-state file $mt_state_file (jq transform failed) -- left untouched (best-effort, non-fatal)." >&2
    fi
  else
    echo "[orchestrate-unwind-dispatch] multi-state file $mt_state_file does not carry task $task_number -- no-op."
  fi
else
  echo "[orchestrate-unwind-dispatch] multi-state file not found ($mt_state_file) -- no-op."
fi

# (6) Release the task lock -- delegates entirely to task-lock.sh release's own holder-identity
# check (WARNs and leaves a foreign-held lock alone rather than force-removing it).
bash "$SCRIPT_DIR/task-lock.sh" release "$task_number" "$session_id" || true

# (7) Optional scoped commit.
if [ "$do_commit" = "true" ]; then
  bash "$SCRIPT_DIR/git-commit-scoped.sh" \
    --message "task ${task_number}: unwind unconsumed ${phase} dispatch (seq ${seq})" \
    --session "$session_id" \
    -- specs/state.json specs/TODO.md \
    || echo "WARN: orchestrate-unwind-dispatch.sh: git-commit-scoped.sh reported nothing to commit or a commit failure (non-fatal; the unwind itself already applied)." >&2
fi

echo "[orchestrate-unwind-dispatch] task $task_number unwound: status/last_updated/session_id restored, dispatch_seq_counter reset to $restore_dsc, pending_dispatch cleared, dispatch file removed, lock released."
echo "[orchestrate-unwind-dispatch] If the underlying work was already complete (a summaries/*.md exists for this round), the likely next step is: bash $SCRIPT_DIR/reconcile-task-status.sh $task_number $session_id -- not a direct re-run of orchestrate-cycle-postflight.sh or /orchestrate, which would open a fresh dispatch window this task's existing handoff predates. See docs/architecture/orchestrate-state-machine.md's \"Unwinding an Unconsumed Dispatch\" subsection."
exit 0
