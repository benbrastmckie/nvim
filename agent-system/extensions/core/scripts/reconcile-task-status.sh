#!/usr/bin/env bash
# reconcile-task-status.sh - Self-healing reconciliation for stuck tasks
#
# Detects tasks stuck in in-flight states (researching, planning, implementing, partial)
# when artifacts already exist on disk, then replays the missed postflight to promote
# their status. Addresses the failure mode where an agent writes artifacts but crashes
# before postflight runs.
#
# Usage:
#   .claude/scripts/reconcile-task-status.sh <task_number> <session_id> [--dry-run]
#
# Arguments:
#   task_number  - Task number (integer)
#   session_id   - Session identifier string
#   --dry-run    - Print what would be done without modifying state
#
# Artifact-to-phase mapping (PROMOTION -- artifact exists, replay the missed postflight):
#   reports/*.md    -> research phase   (researching -> researched)
#   plans/*.md      -> planning phase   (planning -> planned)
#   summaries/*.md  -> implement phase  (implementing -> completed)
#   partial state   -> check handoff for continuation_context
#   plans/*.md      -> planning phase   (not_started -> planned)   [mtime-gated, see below]
#   handoffs/*.md   -> partial state    (not_started -> partial)   [mtime-gated, see below]
#
# Lock-aware DEMOTION (Direction (b) defense-in-depth; see demote_stranded_status() below for the
# full contract): when `researching` or `planning` has NO artifact on disk (the promotion table
# above finds nothing to promote), this script additionally consults `task-lock.sh check` to tell
# a genuinely in-progress task apart from one STRANDED by a dead prior session's stale lock --
# never by re-deriving a second staleness heuristic:
#   researching -> not_started   (demoted only when task-lock.sh check reports free (0) or
#                                  held-stale (2); NEVER on held-fresh (1) or resolution error (3))
#   planning    -> researched    (identical gate)
# This demotes independently of /orchestrate: eligibility is no longer status-gated on
# `researching`/`planning` (see skills/skill-orchestrate/SKILL.md Stage MT-3 step 3), so a
# stranded task already re-dispatches through that mechanism on its own; this demotion is
# operator-visible repair that works even when /orchestrate is never re-invoked on the task.
# Why the not_started mappings are mtime-gated:
#   A not_started task with artifacts on disk is ambiguous. It is either a crashed run whose
#   postflight was lost (promote it) or a task deliberately reset with its old artifacts left in
#   place (leave it alone). The Recover Mode in commands/task.md produces the second shape on
#   purpose: it moves an archived task's entire directory -- plans/, reports/, summaries/,
#   handoffs/ -- back into specs/, forces status="not_started", and stamps last_updated to the
#   recovery time in the same jq call. Artifact PRESENCE cannot tell the two apart; artifact
#   RECENCY can. A crashed run necessarily wrote its artifact after the last successful status
#   write, so artifact_mtime > last_updated. A recovered task's artifacts all predate the
#   recovery stamp, so last_updated > artifact_mtime. Promotion therefore requires a strictly
#   newer artifact (see artifact_newer_than_last_update below).
#
#   Do NOT "simplify" this into a bare artifact-presence check. This reconcile runs live and
#   unattended from the orchestrate entry path (no --dry-run, no human), so dropping the guard
#   would silently fast-forward every recovered task past the research or planning it was
#   recovered to redo.
#
# Off-enum handoff status recovery:
#   handoff_permits_promotion() below treats a handoff `.status` that falls outside both the
#   on-enum terminal set (researched|planned|implemented|partial|failed|blocked) and the
#   recognized non-terminal marker `in_progress` as equivalent to a MISSING handoff -- it
#   permits promotion rather than refusing it, because a value making no interpretable terminal
#   claim carries no less evidence than no claim at all. Every branch reaching this guard has
#   already found the phase's success artifact on disk, so this is never promotion on faith
#   alone. See that function's own docstring for the full three-way contract and the two
#   rejected alternatives (refuse-with-diagnostic-only; a known-bad-synonym table).
#
#   `needs_research` was checked, not assumed, and deliberately left OUT of the on-enum set:
#   this function reads only `.orchestrator-handoff.json`, and `docs/architecture/handoff-schema.md`'s
#   "Handoff Writers" table confirms `planner-agent` -- the sole producer of `needs_research` --
#   is in the "Never writes a handoff, by design" row. This code path is therefore unreachable for
#   a `needs_research` outcome today; a handoff carrying that status would currently fall into the
#   off-vocabulary case-4 branch (permit, with a warning), which is inert because no writer emits
#   it. Revisit this if a future handoff-writing planner variant is ever registered.
#
# Exit codes:
#   0 - Success or no-op (nothing to reconcile, or reconciliation applied)
#   1 - Validation error (bad arguments or state.json missing)
#   2 - state.json read error

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
STATE_FILE="$PROJECT_ROOT/specs/state.json"

# --- Parse arguments ---
DRY_RUN=false
POSITIONAL_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) POSITIONAL_ARGS+=("$arg") ;;
  esac
done

task_number="${POSITIONAL_ARGS[0]:-}"
session_id="${POSITIONAL_ARGS[1]:-}"

# --- Validation ---
if [[ -z "$task_number" || -z "$session_id" ]]; then
  echo "Usage: $0 <task_number> <session_id> [--dry-run]" >&2
  exit 1
fi

if ! [[ "$task_number" =~ ^[0-9]+$ ]]; then
  echo "Error: task_number must be a positive integer, got '$task_number'" >&2
  exit 1
fi

if [[ ! -f "$STATE_FILE" ]]; then
  echo "Error: state.json not found at $STATE_FILE" >&2
  exit 1
fi

# --- Read current task status from state.json ---
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  "$STATE_FILE" 2>/dev/null) || {
  echo "Error: failed to read state.json for task $task_number" >&2
  exit 2
}

if [[ -z "$task_data" ]]; then
  # Task not found — no-op (not an error, task may have been archived)
  exit 0
fi

current_status=$(echo "$task_data" | jq -r '.status // "not_started"')
project_name=$(echo "$task_data" | jq -r '.project_name')

# --- Resolve task directory ---
PADDED_NUM=$(printf "%03d" "$task_number")
TASK_DIR="$PROJECT_ROOT/specs/${PADDED_NUM}_${project_name}"

# --- Helper: find latest artifact in a subdirectory ---
find_latest_artifact() {
  local subdir="$1"
  local artifact_dir="${TASK_DIR}/${subdir}"
  if [[ -d "$artifact_dir" ]]; then
    # `|| true`: under `set -e -o pipefail`, an existing-but-empty directory makes the
    # unexpanded `*.md` glob a literal nonexistent filename, so `ls` exits non-zero and
    # pipefail would abort the whole script even though `sort`/`tail` succeed on empty input.
    # An empty artifact directory is a legitimate no-artifact-yet state, not an error.
    ls -1 "${artifact_dir}/"*.md 2>/dev/null | sort -V | tail -1 || true
  fi
}

# --- Helper: check if artifact is already linked in state.json ---
artifact_already_linked() {
  local artifact_path="$1"
  local artifact_type="$2"
  # Normalize to relative path (specs/...)
  local rel_path="${artifact_path#$PROJECT_ROOT/}"
  jq -r --argjson num "$task_number" \
    '[.active_projects[] | select(.project_number == $num) | .artifacts // [] | .[] | .path] | .[]' \
    "$STATE_FILE" 2>/dev/null | grep -qF "$rel_path" && return 0 || return 1
}

# --- Helper: link artifact in state.json and TODO.md ---
link_artifact() {
  local artifact_path="$1"
  local artifact_type="$2"    # report | plan | summary
  local artifact_summary="$3"

  # Normalize to relative path for state.json and TODO.md
  local rel_path="${artifact_path#$PROJECT_ROOT/}"

  if artifact_already_linked "$artifact_path" "$artifact_type"; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[reconcile] Artifact already linked in state.json: $rel_path — skipping"
    fi
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[reconcile] Would link artifact in state.json: type=$artifact_type path=$rel_path"
  else
    # Both steps routed through state-write.sh, the single mutex-guarded specs/state.json
    # writer. Each call is its own critical section (state-write.sh has no multi-call batching
    # interface); this is the same two-separate-writes shape the prior tmp-and-mv code used.
    # Step 1: Remove existing artifacts of same type (Issue #1132-safe pattern)
    "$SCRIPT_DIR/state-write.sh" \
      '(.active_projects[] | select(.project_number == $num)).artifacts =
        [(.active_projects[] | select(.project_number == $num)).artifacts // [] | .[] | select(.type == $atype | not)]' \
      --session-id "$session_id" \
      --arg atype "$artifact_type" \
      --argjson num "$task_number" \
      || { echo "[reconcile] ERROR: state-write.sh failed removing same-type artifacts for $rel_path" >&2; return 1; }
    # Step 2: Add new artifact entry
    "$SCRIPT_DIR/state-write.sh" \
      '(.active_projects[] | select(.project_number == $num)).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
      --session-id "$session_id" \
      --arg path "$rel_path" \
      --arg type "$artifact_type" \
      --arg summary "$artifact_summary" \
      --argjson num "$task_number" \
      || { echo "[reconcile] ERROR: state-write.sh failed adding artifact entry for $rel_path" >&2; return 1; }
    echo "[reconcile] Linked $artifact_type artifact in state.json: $rel_path"
  fi

  # Step 3: Regenerate TODO.md from state.json
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[reconcile] Would regenerate TODO.md via generate-todo.sh"
  else
    "$SCRIPT_DIR/generate-todo.sh" || {
      echo "[reconcile] WARNING: generate-todo.sh failed for $rel_path (non-fatal)" >&2
    }
  fi
}

# --- Helper: harvest a plan's "Files to modify" union as a --file-scope-add argv fragment ---
#
# Shared by both `postflight ... plan ...` replay sites below (the `planning` and `not_started`
# no-summary-yet branches). Never re-implements path extraction -- always calls
# plan-file-scope-harvest.sh as a subprocess, per this task's reuse constraint. Degrades to no
# flag at all (byte-for-byte no-op, matching update-task-status.sh's own FILE_SCOPE_ADD_LEN
# no-op contract) on any harvester failure, empty result, or unparseable output -- a harvest
# problem must never block reconciliation's own status-promotion replay.
#
# Usage: harvested_flag="$(harvest_file_scope_args "$plan_file")"; prints either the single
# "--file-scope-add=<json>" token (no trailing newline issues -- $() strips it) or nothing.
harvest_file_scope_args() {
  local plan_file="$1"
  local harvested
  harvested=$(bash "$SCRIPT_DIR/plan-file-scope-harvest.sh" "$plan_file" 2>/dev/null) \
    || { echo "[reconcile] WARNING: plan-file-scope-harvest.sh failed for $plan_file, skipping file_scope harvest (non-blocking)" >&2; return 0; }
  if [[ -n "$harvested" && "$harvested" != "[]" && "$harvested" != "null" ]]; then
    echo "--file-scope-add=$harvested"
  fi
}

# --- Helper: lock-aware demotion for a stranded in-flight task with no artifact ---
#
# Direction (b) defense-in-depth (research report Decision 1): a task sitting in `researching` or
# `planning` with NO artifact on disk is genuinely ambiguous from an artifact-presence read alone
# -- it is either honestly in-progress (a live session is working on it right now) or STRANDED (a
# prior session died mid-phase and its lock is stale, or was never held at all). This helper
# resolves that ambiguity the same way `/orchestrate`'s admission gate already does: by consulting
# `task-lock.sh check`, never by re-deriving a second staleness heuristic of its own.
#
# This is reached ONLY after the caller's existing no-artifact no-op branch has already run and
# decided there is nothing to promote -- demotion is additional, defense-in-depth behavior layered
# on top of that branch, never a replacement for it. A task WITH an artifact never reaches this
# helper at all; that case is the existing promotion path above, unchanged.
#
# Exit-code gate on `task-lock.sh check` (see that command's own contract for the full semantics):
#   0 (free)        -> DEMOTE. No lock at all; nothing is protecting this status, so a task
#                      genuinely in-progress under a live session would still hold a fresh lock.
#   2 (held-stale)   -> DEMOTE. The lock exists but its holder's heartbeat is stale past
#                      TASK_LOCK_STALE_MIN -- the classic stranded-task signature this defense
#                      exists for (a dead prior session's lock left behind).
#   1 (held-fresh)   -> NEVER demote. A genuinely fresh lock means a live session may actually be
#                      working on this task right now; demoting out from under it would race a
#                      real in-progress operation. Refuse loudly instead.
#   3 (resolution error) -> NEVER demote. Fail CLOSED on ambiguity -- an error resolving the task's
#                      own directory or lock state is not evidence of staleness, and this script's
#                      own header already establishes it runs live and unattended (no human to
#                      arbitrate a wrong guess).
#
# New class of write for this script: every other mutation reconcile-task-status.sh makes is a
# PROMOTION (advancing status forward once an artifact proves the phase completed). This is the
# first DEMOTION -- moving status backward with no artifact evidence at all, based solely on lock
# staleness. Scoped as narrowly as possible: gated on the no-artifact branch already having run,
# gated on the lock-check exit code exactly as above, and logged loudly on every demotion AND
# every refusal so this new write class is never silent.
demote_stranded_status() {
  local from_status="$1" to_status="$2"

  local lock_check_output lock_check_exit
  # `if VAR=$(cmd); then ... ; else lock_check_exit=$?; fi` rather than a bare
  # `lock_check_output=$(cmd); lock_check_exit=$?` -- under this script's `set -euo pipefail`, a
  # bare assignment whose command substitution exits non-zero (1 held-fresh, 2 held-stale, 3
  # resolution error -- ALL of them routine, expected outcomes of `task-lock.sh check`, per its
  # own documented contract) would abort the whole script on this line, before
  # `lock_check_exit=$?` could ever capture the status. Wrapping the assignment in the `if` test
  # is `-e`-exempt and preserves the captured exit code exactly, mirroring the same fix already
  # applied to orchestrate-batch-admit.sh, state-write.sh, task-lock.sh, and
  # git-commit-scoped.sh for identical reasons.
  if lock_check_output=$(bash "$SCRIPT_DIR/task-lock.sh" check "$task_number" 2>&1); then
    lock_check_exit=0
  else
    lock_check_exit=$?
  fi

  case "$lock_check_exit" in
    0|2)
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[reconcile] Would demote: $from_status -> $to_status (task-lock.sh check: $lock_check_output)"
      else
        if ! "$SCRIPT_DIR/state-write.sh" \
          '(.active_projects[] | select(.project_number == ($num | tonumber))) |= . + {
            status: $status,
            last_updated: $ts
          }' \
          --session-id "$session_id" \
          --arg num "$task_number" \
          --arg status "$to_status" \
          --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          --regen-todo; then
          echo "[reconcile] ERROR: state-write.sh failed demoting task $task_number ($from_status -> $to_status)" >&2
          return 1
        fi
        echo "[reconcile] DEMOTED: Task $task_number: $from_status -> $to_status (task-lock.sh check: $lock_check_output; no artifact found -- stranded by a dead prior session)"
      fi
      ;;
    1)
      echo "[reconcile] Task $task_number: status=$from_status, no artifact, task-lock.sh check reports a FRESH lock ($lock_check_output) — refusing demotion (a live session may genuinely be in progress)"
      ;;
    *)
      echo "[reconcile] Task $task_number: status=$from_status, no artifact, task-lock.sh check FAILED to resolve (exit $lock_check_exit: $lock_check_output) — refusing demotion, failing CLOSED on ambiguity"
      ;;
  esac
}

# --- Helper: does a handoff permit promotion to this phase's success status? ---
# Three-way classification of the handoff's `.status` against this phase's expected success
# value, generalizing the contract the `partial` branch below already implements for the
# missing-handoff case:
#   1. Handoff file absent -> permit (0). Unchanged from prior behavior.
#   2. Handoff present, `.status` exact-matches expected_status -> permit (0). Unchanged.
#   3. Handoff present, `.status` is an on-enum terminal value from a DIFFERENT phase's success
#      (or blocked/partial/failed) -> refuse (1), unchanged. This is genuine negative evidence:
#      the phase legitimately claims a different terminal outcome than the one being checked for.
#   4. Handoff present, `.status` is `in_progress`, off-vocabulary, empty, or the file is
#      unparseable JSON -> permit (0). None of these make a terminal claim at all, so they are
#      treated exactly like a missing handoff -- the same code path as case 1, not merely an
#      equivalent outcome. This mirrors artifact_newer_than_last_update's "signal absent ->
#      permit" philosophy (see that helper's docstring below): the absence of an interpretable
#      terminal claim is not evidence of failure. Refusing here wedges the task forever, because
#      record_refused_promotion (below) writes no recoverable state for an off-enum value and
#      every subsequent reconcile pass hits the identical refusal.
#
# `in_progress` gets DISTINCT diagnostic wording from the off-vocabulary case, never the
# off-schema/malformed framing: it is a recognized non-terminal marker in
# context/formats/return-metadata-file.md's normative vocabulary, not a schema violation. See
# context/patterns/system-defect-discrimination.md's OFF_SCHEMA_STATUS row, which states verbatim
# that `in_progress` "is a valid non-terminal marker, not a violation" -- labeling it malformed
# here would invent a second, competing notion of "malformed status" and contradict that sibling
# contract.
#
# Do NOT re-tighten case 4 back to a bare refusal, and do NOT add a known-bad-synonym
# normalization table. Both were considered and rejected:
#   - refuse-with-diagnostic-only: preserves the original wedge exactly (record_refused_promotion
#     writes no state for an off-enum value, so every re-run hits the identical refusal) -- only
#     adds visibility, never fixes the underlying bug.
#   - a synonym table mapping known-bad values (e.g. "success", "research_complete") to their
#     intended enum equivalents: unmaintainable (an open-ended, ever-growing list that must be
#     updated for every new writer bug), launders malformed writes into looking legitimate, and
#     risks false-positive promotion for a synonym that was never actually vetted against the
#     writer that produced it.
#
# Both diagnostics go to stderr, unconditionally (not gated on --dry-run), using the
# `[reconcile] WARNING:` prefix already used elsewhere in this file. Returns 0 (permit) or 1
# (refuse) via exit status.
handoff_permits_promotion() {
  local expected_status="$1"
  local handoff_file="${TASK_DIR}/.orchestrator-handoff.json"
  if [[ ! -f "$handoff_file" ]]; then
    return 0
  fi
  local handoff_status
  handoff_status=$(jq -r '.status // ""' "$handoff_file" 2>/dev/null)

  if [[ "$handoff_status" == "$expected_status" ]]; then
    return 0
  fi

  case "$handoff_status" in
    researched|planned|implemented|partial|failed|blocked)
      # On-enum terminal value that does not match this phase's expected success status --
      # genuine negative evidence. Refuse, unchanged from prior behavior.
      return 1
      ;;
    in_progress)
      # Recognized non-terminal marker: makes no terminal claim, so it is treated as if the
      # handoff were absent. Diagnostic wording is deliberately distinct from the off-vocabulary
      # case below -- never "off-schema" or "malformed" for this recognized value.
      echo "[reconcile] WARNING: task $task_number: handoff status='in_progress' is a recognized non-terminal marker carrying no terminal claim -- treating the handoff as if absent and permitting promotion to '$expected_status'." >&2
      return 0
      ;;
    *)
      # Off-vocabulary, including empty (.status absent or unparseable JSON): makes no
      # interpretable terminal claim, so it is treated exactly like a missing handoff. See the
      # do-not-re-tighten note above for why this is the deliberate, chosen behavior.
      local displayed_status="$handoff_status"
      if [[ -z "$displayed_status" ]]; then
        displayed_status="(empty -- handoff present but .status is missing or the file is unparseable)"
      fi
      echo "[reconcile] WARNING: task $task_number: handoff status='$displayed_status' is off-schema (not one of the six legal values researched|planned|implemented|partial|failed|blocked, and not in_progress) -- treating the handoff as if absent and permitting promotion to '$expected_status'." >&2
      return 0
      ;;
  esac
}

# --- Helper: read the handoff's status field (empty string if no handoff file) ---
handoff_status_value() {
  local handoff_file="${TASK_DIR}/.orchestrator-handoff.json"
  if [[ -f "$handoff_file" ]]; then
    jq -r '.status // ""' "$handoff_file" 2>/dev/null
  fi
}

# --- Helper: is this artifact newer than the task's last recorded status write? ---
# The false-positive guard for the not_started branches (see the header's "Why the not_started
# mappings are mtime-gated" note). Returns 0 (permit) when the artifact's mtime is strictly
# greater than state.json's last_updated for this task, 1 (refuse) otherwise.
#
# Ties refuse, deliberately: a directory move can land an artifact's mtime on the same whole
# second as the recovery stamp, and the two outcomes are not symmetric. Refusing a tie costs one
# re-run of /plan; permitting one silently skips planning on a task that was reopened to redo it.
#
# Fails OPEN (0) when last_updated is missing or unparseable -- the same "signal absent ->
# permit" philosophy handoff_permits_promotion above already uses, so a task predating the
# last_updated field behaves as it did before. Fails CLOSED (1) when the artifact cannot be
# stat'd, which should not happen: callers only reach here after find_latest_artifact (or an
# equivalent listing) already located the file, so an unreadable path means something is wrong
# and refusing is correct.
#
# stat and date both use the GNU-then-BSD fallback idiom already established elsewhere in this
# codebase (scripts/claude-cleanup.sh for stat, scripts/task-lock.sh for date) rather than
# assuming GNU. A guard that silently degrades to a no-op on a non-Linux host would be worse
# than no guard, because it would look present in review while permitting every promotion.
artifact_newer_than_last_update() {
  local artifact_path="$1"
  local artifact_mtime last_updated_raw last_updated_epoch

  artifact_mtime=$(stat -c %Y "$artifact_path" 2>/dev/null \
    || stat -f %m "$artifact_path" 2>/dev/null) || return 1
  [[ -n "$artifact_mtime" ]] || return 1

  last_updated_raw=$(echo "$task_data" | jq -r '.last_updated // empty' 2>/dev/null)
  [[ -n "$last_updated_raw" ]] || return 0

  last_updated_epoch=$(date -u -d "$last_updated_raw" +%s 2>/dev/null \
    || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_updated_raw" +%s 2>/dev/null) || return 0
  [[ -n "$last_updated_epoch" ]] || return 0

  [[ "$artifact_mtime" -gt "$last_updated_epoch" ]]
}

# --- Helper: record a refused promotion using the sanctioned partial/blocked postflight
# termini — but only when the handoff status maps unambiguously onto one of them. Any other
# handoff status (e.g. "failed", or an empty/missing status field) is already surfaced by the
# caller's refusal line; this is a plain no-op for those cases — never invent a status.
record_refused_promotion() {
  local handoff_status="$1"
  case "$handoff_status" in
    blocked|partial)
      local dry_run_flag=()
      if [[ "$DRY_RUN" == "true" ]]; then
        dry_run_flag=(--dry-run)
      fi
      "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "$handoff_status" "$session_id" "${dry_run_flag[@]}"
      ;;
    *)
      : # ambiguous mapping — no recording, the refusal line above is the whole report
      ;;
  esac
}

# --- Helper: map a state.json task-level status to its plan-level marker equivalent. ---
# Plan-level Status uses a narrower 6-marker vocabulary than the full task-level vocabulary (see
# status-markers.md's "Plan-level vs. phase-level markers" section): a plan document is
# not_started, implementing, partial, blocked, abandoned, or completed -- it does not track
# research/planning sub-phases of its own, so statuses like "researching" or "planning" have no
# plan-level equivalent. Echoes the equivalent marker and returns 0 when one exists; returns 1
# (nothing echoed) otherwise.
plan_level_equivalent() {
  local state_status="$1"
  case "$state_status" in
    not_started) echo "NOT STARTED" ;;
    implementing) echo "IMPLEMENTING" ;;
    partial) echo "PARTIAL" ;;
    blocked) echo "BLOCKED" ;;
    abandoned) echo "ABANDONED" ;;
    completed) echo "COMPLETED" ;;
    *) return 1 ;;
  esac
}

# --- Report-only plan-vs-state.json divergence check (optional/stretch scope). Never repairs
# either direction -- unlike "artifact exists, therefore promote", a plan-vs-state mismatch has
# no unambiguous correct side. Compares only the plan-level `- **Status**:` field, never
# phase-heading markers, which are a distinct, narrower grain. No-ops silently (exit status
# unaffected) when the current status has no plan-level equivalent or no plan file exists yet.
check_plan_state_divergence() {
  local expected_plan_status
  expected_plan_status=$(plan_level_equivalent "$current_status") || return 0

  local plan_file
  plan_file=$(find_latest_artifact "plans")
  if [[ -z "$plan_file" ]]; then
    return 0
  fi

  local plan_status
  plan_status=$(grep -m1 '^- \*\*Status\*\*:' "$plan_file" 2>/dev/null | \
    sed -E 's/^- \*\*Status\*\*:\s*\[?([A-Z ]+)\]?.*/\1/')
  if [[ -z "$plan_status" ]]; then
    return 0
  fi

  if [[ "$plan_status" != "$expected_plan_status" ]]; then
    echo "[reconcile] WARNING: task $task_number plan status=$plan_status, state.json status=$current_status"
  fi
}

# --- Main reconciliation dispatch ---
case "$current_status" in

  researching)
    check_plan_state_divergence
    # Check for completed research artifact
    report_file=$(find_latest_artifact "reports")
    if [[ -z "$report_file" ]]; then
      # No artifact — reached only after this no-op condition: check whether the task is
      # actually stranded (lock-aware demotion, Direction (b) defense-in-depth) rather than
      # genuinely in-progress.
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[reconcile] Task $task_number: status=researching, no report artifact found — no-op (checking for stranding)"
      fi
      demote_stranded_status "researching" "not_started"
      exit 0
    fi

    # Handoff-aware promotion guard (see handoff_permits_promotion above).
    if ! handoff_permits_promotion "researched"; then
      handoff_status=$(handoff_status_value)
      echo "[reconcile] Task $task_number: status=researching, artifact exists but handoff status=$handoff_status — refusing promotion"
      record_refused_promotion "$handoff_status"
      exit 0
    fi

    report_basename=$(basename "$report_file")
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[reconcile] Task $task_number: status=researching, found report $report_basename"
      echo "[reconcile] Would promote: researching -> researched via postflight research"
      link_artifact "$report_file" "report" "Research report: $report_basename"
    else
      echo "[reconcile] Task $task_number: status=researching but report exists ($report_basename) — replaying postflight"
      link_artifact "$report_file" "report" "Research report: $report_basename"
      "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "research" "$session_id"
      echo "[reconcile] Task $task_number: promoted researching -> researched"
    fi
    ;;

  planning)
    check_plan_state_divergence
    # Check for completed plan artifact
    plan_file=$(find_latest_artifact "plans")
    if [[ -z "$plan_file" ]]; then
      # No artifact — reached only after this no-op condition: check whether the task is
      # actually stranded (lock-aware demotion, Direction (b) defense-in-depth) rather than
      # genuinely in-progress.
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[reconcile] Task $task_number: status=planning, no plan artifact found — no-op (checking for stranding)"
      fi
      demote_stranded_status "planning" "researched"
      exit 0
    fi

    # Handoff-aware promotion guard (see handoff_permits_promotion above).
    if ! handoff_permits_promotion "planned"; then
      handoff_status=$(handoff_status_value)
      echo "[reconcile] Task $task_number: status=planning, artifact exists but handoff status=$handoff_status — refusing promotion"
      record_refused_promotion "$handoff_status"
      exit 0
    fi

    plan_basename=$(basename "$plan_file")
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[reconcile] Task $task_number: status=planning, found plan $plan_basename"
      echo "[reconcile] Would promote: planning -> planned via postflight plan"
      link_artifact "$plan_file" "plan" "Implementation plan: $plan_basename"
    else
      echo "[reconcile] Task $task_number: status=planning but plan exists ($plan_basename) — replaying postflight"
      link_artifact "$plan_file" "plan" "Implementation plan: $plan_basename"
      fsa_args=()
      harvested_flag="$(harvest_file_scope_args "$plan_file")"
      [[ -n "$harvested_flag" ]] && fsa_args=("$harvested_flag")
      "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "plan" "$session_id" "${fsa_args[@]}"
      echo "[reconcile] Task $task_number: promoted planning -> planned"
    fi
    ;;

  implementing)
    check_plan_state_divergence
    # Check for completed summary artifact
    summary_file=$(find_latest_artifact "summaries")
    if [[ -z "$summary_file" ]]; then
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[reconcile] Task $task_number: status=implementing, no summary artifact found — no-op"
      fi
      exit 0
    fi

    # Handoff-aware promotion guard (see handoff_permits_promotion above).
    if ! handoff_permits_promotion "implemented"; then
      handoff_status=$(handoff_status_value)
      echo "[reconcile] Task $task_number: status=implementing, artifact exists but handoff status=$handoff_status — refusing promotion"
      record_refused_promotion "$handoff_status"
      exit 0
    fi

    summary_basename=$(basename "$summary_file")
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[reconcile] Task $task_number: status=implementing, found summary $summary_basename"
      echo "[reconcile] Would promote: implementing -> completed via postflight implement"
      link_artifact "$summary_file" "summary" "Implementation summary: $summary_basename"
    else
      echo "[reconcile] Task $task_number: status=implementing but summary exists ($summary_basename) — replaying postflight"
      link_artifact "$summary_file" "summary" "Implementation summary: $summary_basename"
      reconcile_rc=0
      "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "implement" "$session_id" --phase-check=refuse || reconcile_rc=$?
      if [[ "$reconcile_rc" -eq 4 ]]; then
        # A repair attempt can itself be refused. That is the intended, accepted failure mode: a
        # stuck-but-honestly-labeled task is strictly safer than a silently-wrong [COMPLETED]
        # one, and this branch already logs loudly on every path so the refusal is never silent.
        echo "[reconcile] Task $task_number: phase-accounting backstop refused the implementing -> completed promotion (plan file shows incomplete phases) — leaving status=implementing"
        exit 0
      elif [[ "$reconcile_rc" -ne 0 ]]; then
        echo "[reconcile] Task $task_number: update-task-status.sh failed (exit $reconcile_rc)" >&2
        exit "$reconcile_rc"
      fi
      echo "[reconcile] Task $task_number: promoted implementing -> completed"
    fi
    ;;

  partial)
    check_plan_state_divergence
    # For partial state, check if there's a summary (stuck after final phase)
    summary_file=$(find_latest_artifact "summaries")
    if [[ -z "$summary_file" ]]; then
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[reconcile] Task $task_number: status=partial, no summary artifact found — no-op"
      fi
      exit 0
    fi

    # Handoff-aware promotion guard (see handoff_permits_promotion above), consolidated onto the
    # shared helper so this reader gets the same three-way classification as the other five
    # call sites instead of a bare `!= "implemented"` fallthrough. Behavior change, deliberate:
    # an on-enum non-"implemented" status (e.g. "blocked") previously fell through this inline
    # check silently (a no-op logged only under --dry-run); it now logs unconditionally and
    # calls record_refused_promotion, matching the `implementing` branch's refusal shape exactly.
    # record_refused_promotion writing "partial" on an already-`partial` task is an idempotent
    # no-op transition, so this is safe to call unconditionally.
    if ! handoff_permits_promotion "implemented"; then
      handoff_status=$(handoff_status_value)
      echo "[reconcile] Task $task_number: status=partial, artifact exists but handoff status=$handoff_status — refusing promotion"
      record_refused_promotion "$handoff_status"
      exit 0
    fi

    summary_basename=$(basename "$summary_file")
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[reconcile] Task $task_number: status=partial, found summary $summary_basename, handoff permits promotion"
      echo "[reconcile] Would promote: partial -> completed via postflight implement"
      link_artifact "$summary_file" "summary" "Implementation summary: $summary_basename"
    else
      echo "[reconcile] Task $task_number: status=partial but summary exists ($summary_basename), handoff permits promotion — replaying postflight"
      link_artifact "$summary_file" "summary" "Implementation summary: $summary_basename"
      reconcile_rc=0
      "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "implement" "$session_id" --phase-check=refuse || reconcile_rc=$?
      if [[ "$reconcile_rc" -eq 4 ]]; then
        echo "[reconcile] Task $task_number: phase-accounting backstop refused the partial -> completed promotion (plan file shows incomplete phases) — leaving status=partial"
        exit 0
      elif [[ "$reconcile_rc" -ne 0 ]]; then
        echo "[reconcile] Task $task_number: update-task-status.sh failed (exit $reconcile_rc)" >&2
        exit "$reconcile_rc"
      fi
      echo "[reconcile] Task $task_number: promoted partial -> completed"
    fi
    ;;

  not_started)
    check_plan_state_divergence
    # Case (a): a plan exists and postdates the last recorded status write. The planning
    # postflight was lost mid-run -- replay it and promote not_started -> planned.
    plan_file=$(find_latest_artifact "plans")
    if [[ -n "$plan_file" ]] && artifact_newer_than_last_update "$plan_file"; then
      # Handoff-aware promotion guard (see handoff_permits_promotion above). Note this guard is
      # near-pass-through in standard mode -- .orchestrator-handoff.json is written only by
      # hard-mode dispatch paths -- so it is NOT what disambiguates a recovered task from a
      # stranded one. That is artifact_newer_than_last_update's job, above.
      if ! handoff_permits_promotion "planned"; then
        handoff_status=$(handoff_status_value)
        echo "[reconcile] Task $task_number: status=not_started, plan exists but handoff status=$handoff_status — refusing promotion"
        record_refused_promotion "$handoff_status"
        exit 0
      fi

      plan_basename=$(basename "$plan_file")
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[reconcile] Task $task_number: status=not_started, found plan $plan_basename"
        echo "[reconcile] Would promote: not_started -> planned via postflight plan"
        link_artifact "$plan_file" "plan" "Implementation plan: $plan_basename"
      else
        echo "[reconcile] Task $task_number: status=not_started but plan exists ($plan_basename) — replaying postflight"
        link_artifact "$plan_file" "plan" "Implementation plan: $plan_basename"
        fsa_args=()
        harvested_flag="$(harvest_file_scope_args "$plan_file")"
        [[ -n "$harvested_flag" ]] && fsa_args=("$harvested_flag")
        "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "plan" "$session_id" "${fsa_args[@]}"
        echo "[reconcile] Task $task_number: promoted not_started -> planned"
      fi
      exit 0
    fi

    # Case (b), defense in depth: no fresh plan, but handoffs/ holds a phase handoff that
    # postdates the last status write, so an implementation run started and died. Promote to
    # `partial`, never `implementing`: `implementing` asserts work is underway right now, while a
    # cold reconcile pass finding a stalled run is exactly status-markers.md's "implementation
    # partially completed (can resume)". `partial` is also what record_refused_promotion and the
    # `partial` branch above already treat as the resting state for this situation, and the
    # permissive-transition rule lets /implement pick it up unchanged on the next dispatch.
    handoff_dir="${TASK_DIR}/handoffs"
    if [[ -d "$handoff_dir" ]]; then
      # `|| true` for the same pipefail reason documented on find_latest_artifact above: an
      # existing-but-empty directory leaves the glob unexpanded and makes `ls` exit non-zero.
      # `ls -1t` rather than the `sort -V` used there, because the question here is strictly
      # "is any handoff newer than last_updated" -- an mtime question, not a filename-order one.
      latest_handoff=$(ls -1t "${handoff_dir}/"*.md 2>/dev/null | head -1 || true)
      if [[ -n "$latest_handoff" ]] && artifact_newer_than_last_update "$latest_handoff"; then
        if ! handoff_permits_promotion "partial"; then
          handoff_status=$(handoff_status_value)
          echo "[reconcile] Task $task_number: status=not_started, handoffs/ non-empty but handoff status=$handoff_status — refusing promotion"
          record_refused_promotion "$handoff_status"
          exit 0
        fi

        handoff_basename=$(basename "$latest_handoff")
        if [[ "$DRY_RUN" == "true" ]]; then
          echo "[reconcile] Task $task_number: status=not_started, found phase handoff $handoff_basename"
          echo "[reconcile] Would promote: not_started -> partial via postflight partial"
        else
          echo "[reconcile] Task $task_number: status=not_started but phase handoff exists ($handoff_basename) — replaying postflight"
          "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "partial" "$session_id"
          echo "[reconcile] Task $task_number: promoted not_started -> partial"
        fi
        exit 0
      fi
    fi

    # Nothing newer than last_updated: either a genuinely new task, or one deliberately reset
    # (Recover Mode in commands/task.md) with its old artifacts intact. not_started is the
    # correct resting state in both cases -- no-op.
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[reconcile] Task $task_number: status=not_started, no artifact newer than last_updated — no-op"
    fi
    ;;

  *)
    # All other statuses (researched, planned, completed, blocked, abandoned, expanded) are
    # either terminal or already at a stable state — no-op
    exit 0
    ;;
esac

exit 0
