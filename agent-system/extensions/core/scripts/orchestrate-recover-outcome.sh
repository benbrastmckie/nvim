#!/usr/bin/env bash
# orchestrate-recover-outcome.sh — Shared .return-meta.json outcome-recovery helper for /orchestrate.
#
# Purpose: `.orchestrator-handoff.json` is written by exactly one active writer today (the
# hard-mode implementation agent's H9 wrap-up). Base-mode research, plan, and implement
# dispatches never write one — by contractual design for research (Stage 3.6 "Scoping
# Decision"), and simply never implemented for base-mode plan/implement. Before this script,
# Stage 5 (single-task base and hard mode) and Stage MT-4 (multi-task) each treated every missing
# handoff identically as a suspected defect, with no way to tell "this dispatch's writer never
# produces a handoff, and it succeeded anyway" from "something actually broke." This script is
# the ONE place that reads a task's `.return-meta.json` — a file every research/plan/implement
# dispatch writes per its own Stage 7 contract — and turns it into the same outcome fields Stage 5
# already reads from a handoff, so the three call sites (base Stage 5, hard Stage 5, multi-task
# Stage MT-4 step 1) cannot drift into three separately-maintained recovery rules.
#
# Precedent: `scripts/command-gate-out.sh` (the non-orchestrator postflight path used by plain
# `/research`, `/plan`, `/implement`) already reads `.return-meta.json`'s `.status` as its sole
# outcome signal. This script extends the same channel to the orchestrator path.
#
# Usage:
#   orchestrate-recover-outcome.sh <task_dir> <window_start_ts> [expected_dispatch_seq]
#
# where <task_dir> is the task's directory (relative or absolute; this script does not care which,
# it only ever appends "/.return-meta.json") and <window_start_ts> is the Unix epoch second the
# current dispatch started (the same `dispatch_start_ts` Stage 5 already captures via `date -u
# +%s` immediately before the Agent tool call, for its handoff staleness gate).
#
# <expected_dispatch_seq> (OPTIONAL, appended so every existing 2-arg call site keeps working
# unchanged) is the orchestrator-minted `dispatch_seq` for THIS dispatch — the same identity value
# the handoff gate's `dispatch-seq-gate:begin`/`:end` region already compares against a handoff's
# own `.dispatch_seq`. When omitted or empty, this script performs mtime-only discrimination
# exactly as before (no dispatch_seq comparison of any kind — this is the pre-D2 behavior, not a
# degraded path). When present, it is compared against the file's own top-level `.dispatch_seq`
# field (`context/formats/return-metadata-file.md`'s `### dispatch_seq (optional)` field):
#   - file field absent/empty  -> WARN (named, to stderr) and degrade to mtime-only — the file
#     predates the dispatch_seq contract, not a bug.
#   - file field present, mismatched -> recovered=false, reason=META_DISPATCH_SEQ_MISMATCH. This
#     is the ONLY check in this script that can reject a git-restored predecessor's
#     `.return-meta.json`: such a file is restored with a fresh, in-window mtime by construction,
#     so the mtime gate above is provably inert against it (see the header's "Item C decision"
#     paragraph's sibling incident, evt_1788246742189_Fodegl).
#   - file field present, matches -> proceed exactly as the pre-D2 path.
#
# Forbidden calls (this script is read-only; it must never be the mechanism by which a Stage 5 or
# Stage MT-4 caller mutates anything):
#   - task-lock.sh (acquire/heartbeat/release)
#   - update-task-status.sh
#   - generate-todo.sh
#   - skill-base.sh write functions (skill_preflight_update, skill_postflight_update,
#     skill_gate_completion_claim, skill_link_artifacts, etc.)
#   - reconcile-task-status.sh (without --dry-run)
#   - the Agent or Skill tool, or anything that dispatches one
# This script reads ONLY `<task_dir>/.return-meta.json` — never a report, plan, summary, or
# handoff file (Context Flatness Constraint). It performs no writes of any kind.
#
# Staleness check: identical idiom and fail-closed default to the handoff staleness gate Stage 5
# already runs: `stat -c %Y ... || stat -f %m ... || echo 0`, compared against
# `${window_start_ts:-9999999999}`. `meta_mtime -ge window_start` is fresh — an unset or
# unparseable window_start_ts defaults to "never fresh," matching the fail-closed posture callers
# already rely on.
#
# Recoverable statuses: `researched`, `planned`, `implemented` — the same success vocabulary
# Stage 5 already branches on when reading a handoff. Every other outcome sets `recovered=false`
# with a reason token below; callers MUST treat that identically to a missing/stale/unparseable
# file — this script never invents a success where the file itself does not report one.
#
# Item C decision (recorded, not re-litigated): this script deliberately does NOT accept a
# top-level `phases_completed`/`phases_total` shape as a fallback alongside the two documented
# read locations below (`.metadata.*` and `.partial_progress.*`). Those two locations are
# exhaustive by design. A permissive fallback would silently bless an off-schema write instead of
# keeping writer drift visible — the `evidence_suspect`/`evidence_reason` fields below are the
# evidence-based alternative: they surface the contradiction for a caller to act on, without
# correcting the underlying value. A future reader tempted to add a fallback should read this
# paragraph first.
#
# Output: a single-line compact JSON object on stdout, with these fields:
#   recovered          bool    true only for a present, fresh, parseable file whose `.status` is
#                                researched/planned/implemented.
#   status             string  the file's `.status` when parseable, else "unknown". Populated
#                                even when recovered=false, so callers can log a
#                                partial/failed/blocked/in_progress outcome without acting on it.
#   reason             string  one of: NONE (recovered=true), META_MISSING, META_STALE,
#                                META_UNPARSEABLE, META_DISPATCH_SEQ_MISMATCH,
#                                STATUS_IN_PROGRESS, STATUS_NOT_SUCCESS, USAGE.
#   artifact_path       string  .artifacts[0].path, or "" when absent/not recovered.
#   artifact_type       string  .artifacts[0].type, or "".
#   artifact_summary    string  .artifacts[0].summary, or "".
#   phases_completed    int     .metadata.phases_completed // .partial_progress.phases_completed // 0
#   phases_total        int     .metadata.phases_total // .partial_progress.phases_total // 0
#   meta_mtime          int     the file's mtime (0 if missing/unstattable).
#   window_start        int     the window_start_ts actually used (post fail-closed default).
#   completion_summary string  .completion_data.completion_summary // "", regardless of branch.
#   roadmap_items      array   .completion_data.roadmap_items // [], regardless of branch.
#   evidence_suspect    bool    true when the recovered=true branch's own resolved values
#                                contradict the file's contents — see "General empty-value
#                                detection signal" below. Always false on every recovered=false
#                                branch (nothing there is evaluated for the signature).
#   evidence_reason     string  NONE (evidence_suspect=false), or one of
#                                PHASES_ZERO_ON_SUCCESS / ARTIFACTS_SHAPE_MISMATCH. If both
#                                signatures fire, PHASES_ZERO_ON_SUCCESS takes precedence.
#
# General empty-value detection signal ("a present, parseable file yielded an empty or zero
# value that its own contents contradict"), evaluated ONLY on the recovered=true path — two
# instances of one signature, not two special cases:
#   PHASES_ZERO_ON_SUCCESS   — status == "implemented" and both resolved phase counts are 0. An
#                                implementation dispatch always has at least one phase, so 0/0 on
#                                a claimed-complete implementation is inherently suspect.
#   ARTIFACTS_SHAPE_MISMATCH — `.artifacts | length` is > 0 but the resolved `artifact_path` is
#                                empty. A non-empty array yielding no path is proof of a shape
#                                mismatch (e.g. a bare-string array), not proof of "no artifacts".
#                                A jq failure while resolving `artifact_path`/`artifact_type`/
#                                `artifact_summary` (non-zero exit) is treated as additional
#                                corroboration of this same signature, never as a separate one.
#
# Exit codes:
#   0 — recovered=true; the JSON object above is on stdout.
#   1 — recovered=false (missing, stale, unparseable, in_progress, or non-success status); the
#       JSON object above is still on stdout so callers can log the reason.
#   2 — usage error (wrong argument count) or jq unavailable. Nothing is printed on stdout;
#       callers MUST treat exit 2 identically to exit 1 (fail closed).

set -euo pipefail

task_dir="${1:-}"
window_start_ts="${2:-}"
expected_dispatch_seq="${3:-}"

if [ -z "$task_dir" ] || [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "ERROR: orchestrate-recover-outcome.sh: usage: orchestrate-recover-outcome.sh <task_dir> <window_start_ts> [expected_dispatch_seq]" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: orchestrate-recover-outcome.sh: jq is not available; cannot evaluate recovery." >&2
  exit 2
fi

# Fail-closed default: an empty/non-numeric window_start_ts becomes "never fresh."
case "$window_start_ts" in
  ''|*[!0-9]*) window_start="9999999999" ;;
  *) window_start="$window_start_ts" ;;
esac

meta_file="${task_dir}/.return-meta.json"

emit() {
  # $1=recovered $2=status $3=reason $4=artifact_path $5=artifact_type $6=artifact_summary
  # $7=phases_completed $8=phases_total $9=meta_mtime ${10}=completion_summary ${11}=roadmap_items
  # ${12}=evidence_suspect ${13}=evidence_reason
  # Braces are mandatory on ${10}/${11}/${12}/${13} — bare $10 parses as $1 followed by a
  # literal "0".
  jq -n -c \
    --argjson recovered "$1" \
    --arg status "$2" \
    --arg reason "$3" \
    --arg artifact_path "$4" \
    --arg artifact_type "$5" \
    --arg artifact_summary "$6" \
    --argjson phases_completed "$7" \
    --argjson phases_total "$8" \
    --argjson meta_mtime "$9" \
    --argjson window_start "$window_start" \
    --arg completion_summary "${10}" \
    --argjson roadmap_items "${11}" \
    --argjson evidence_suspect "${12}" \
    --arg evidence_reason "${13}" \
    '{recovered: $recovered, status: $status, reason: $reason,
      artifact_path: $artifact_path, artifact_type: $artifact_type,
      artifact_summary: $artifact_summary, phases_completed: $phases_completed,
      phases_total: $phases_total, meta_mtime: $meta_mtime, window_start: $window_start,
      completion_summary: $completion_summary, roadmap_items: $roadmap_items,
      evidence_suspect: $evidence_suspect, evidence_reason: $evidence_reason}'
}

if [ ! -f "$meta_file" ]; then
  emit false "unknown" "META_MISSING" "" "" "" 0 0 0 "" "[]" false "NONE"
  exit 1
fi

meta_mtime=$(stat -c %Y "$meta_file" 2>/dev/null || stat -f %m "$meta_file" 2>/dev/null || echo 0)

if [ "$meta_mtime" -lt "$window_start" ]; then
  emit false "unknown" "META_STALE" "" "" "" 0 0 "$meta_mtime" "" "[]" false "NONE"
  exit 1
fi

if ! meta_json=$(jq -c '.' "$meta_file" 2>/dev/null); then
  emit false "unknown" "META_UNPARSEABLE" "" "" "" 0 0 "$meta_mtime" "" "[]" false "NONE"
  exit 1
fi

# ── dispatch_seq identity check (D2) ─────────────────────────────────────────────────────────
# Only performed when the caller supplied a third argument. Omitting it (the pre-D2, 2-arg call
# shape) skips this block entirely -- not a degraded path, the ordinary one for a caller that
# has not adopted dispatch_seq threading yet.
if [ -n "$expected_dispatch_seq" ]; then
  meta_dispatch_seq=$(echo "$meta_json" | jq -r '.dispatch_seq // empty' 2>/dev/null)
  if [ -z "$meta_dispatch_seq" ]; then
    echo "WARN: orchestrate-recover-outcome.sh: .return-meta.json has no dispatch_seq field — writer predates the dispatch_seq contract; degrading to mtime-only discrimination." >&2
  elif [ "$meta_dispatch_seq" != "$expected_dispatch_seq" ]; then
    status=$(echo "$meta_json" | jq -r '.status // "unknown"')
    echo "ERROR: orchestrate-recover-outcome.sh: DISPATCH_SEQ MISMATCH — .return-meta.json carries dispatch_seq=$meta_dispatch_seq, this cycle expected dispatch_seq=$expected_dispatch_seq. Not this dispatch's own report (a still-live/resurrected predecessor, or a git-restored file) — treating as unrecovered." >&2
    emit false "$status" "META_DISPATCH_SEQ_MISMATCH" "" "" "" 0 0 "$meta_mtime" "" "[]" false "NONE"
    exit 1
  fi
fi

status=$(echo "$meta_json" | jq -r '.status // "unknown"')
phases_completed=$(echo "$meta_json" | jq -r '.metadata.phases_completed // .partial_progress.phases_completed // 0')
phases_total=$(echo "$meta_json" | jq -r '.metadata.phases_total // .partial_progress.phases_total // 0')

# ─── Deliberately RAW, never normalized (do not "fix" this) ────────────────────────────────
# This block reads .artifacts[0].{path,type,summary} directly off the raw on-disk JSON, with NO
# bare-string-to-object normalization applied. That is intentional, not an oversight: this
# script's own ARTIFACTS_SHAPE_MISMATCH signature below depends on observing a non-empty
# `artifacts` array that resolves to an EMPTY artifact_path -- exactly what a bare-string element
# produces before normalization. The chokepoint that DOES normalize (in-memory only, never
# rewriting the on-disk file) is `skill_read_metadata` in scripts/skill-base.sh; this script is a
# separate, independent reader that does not source skill-base.sh, precisely so its detector
# keeps seeing the unrepaired shape. Normalizing here would blind ARTIFACTS_SHAPE_MISMATCH
# exactly when it is needed. See context/formats/return-metadata-file.md's `artifacts (required)`
# section for the full four-layer posture this asymmetry implements.
if artifact_path=$(echo "$meta_json" | jq -r '.artifacts[0].path // ""'); then
  artifact_path_rc=0
else
  artifact_path_rc=$?
fi
if artifact_type=$(echo "$meta_json" | jq -r '.artifacts[0].type // ""'); then
  artifact_type_rc=0
else
  artifact_type_rc=$?
fi
if artifact_summary=$(echo "$meta_json" | jq -r '.artifacts[0].summary // ""'); then
  artifact_summary_rc=0
else
  artifact_summary_rc=$?
fi
completion_summary=$(echo "$meta_json" | jq -r '.completion_data.completion_summary // ""')
roadmap_items=$(echo "$meta_json" | jq -c '.completion_data.roadmap_items // []')

case "$status" in
  researched|planned|implemented)
    # General empty-value detection signal (evaluated only on this recovered=true path — see
    # the script header's "General empty-value detection signal" section for the full rationale
    # and the Item C decision this is the alternative to).
    artifacts_length=$(echo "$meta_json" | jq -r '(.artifacts // []) | length' 2>/dev/null) || artifacts_length=0
    jq_artifact_failure=false
    if [ "$artifact_path_rc" -ne 0 ] || [ "$artifact_type_rc" -ne 0 ] || [ "$artifact_summary_rc" -ne 0 ]; then
      jq_artifact_failure=true
    fi
    evidence_suspect=false
    evidence_reason="NONE"
    if [ "$status" = "implemented" ] && [ "$phases_completed" -eq 0 ] && [ "$phases_total" -eq 0 ]; then
      # PHASES_ZERO_ON_SUCCESS takes precedence when both signatures fire — recorded in the
      # header's field-doc table, not just here.
      evidence_suspect=true
      evidence_reason="PHASES_ZERO_ON_SUCCESS"
    elif { [ "$artifacts_length" -gt 0 ] && [ -z "$artifact_path" ]; } || [ "$jq_artifact_failure" = true ]; then
      evidence_suspect=true
      evidence_reason="ARTIFACTS_SHAPE_MISMATCH"
    fi
    emit true "$status" "NONE" "$artifact_path" "$artifact_type" "$artifact_summary" \
      "$phases_completed" "$phases_total" "$meta_mtime" "$completion_summary" "$roadmap_items" \
      "$evidence_suspect" "$evidence_reason"
    exit 0
    ;;
  needs_research)
    # needs_research is a planner-only outcome carrying an empty artifacts array by design (no
    # plan is written on this path). It deliberately does NOT share the
    # researched|planned|implemented arm's artifacts-evidence-mismatch logic above: an empty
    # artifacts array is the correct and expected shape here, not evidence of a writer bug, so
    # this arm short-circuits directly to recovered=true, evidence_suspect=false without
    # evaluating ARTIFACTS_SHAPE_MISMATCH or PHASES_ZERO_ON_SUCCESS.
    emit true "$status" "NONE" "$artifact_path" "$artifact_type" "$artifact_summary" \
      "$phases_completed" "$phases_total" "$meta_mtime" "$completion_summary" "$roadmap_items" \
      false "NONE"
    exit 0
    ;;
  in_progress)
    emit false "$status" "STATUS_IN_PROGRESS" "" "" "" 0 0 "$meta_mtime" "" "[]" false "NONE"
    exit 1
    ;;
  *)
    emit false "$status" "STATUS_NOT_SUCCESS" "" "" "" 0 0 "$meta_mtime" "" "[]" false "NONE"
    exit 1
    ;;
esac
