#!/usr/bin/env bash
# orchestrate-conclusion-aggregate.sh - Mechanical half of the orchestration conclusion stage
# (Move 5): aggregation, cross-task grouping, win separation, unknown-class tallying, citation
# assembly, and the per-channel approval ledger.
#
# Contract: context/contracts/conclusion-stage.md (the derivation rules this script implements
# against). Classification of an aggregated proposal into one of the three channels -- (a)
# fix-now, (b) agent-system change, (c) follow-up task -- is DELIBERATELY NOT done here: that is
# the orchestrator lead's own judgment call, including the visible-override of a
# `suggested_channel` hint. This script only aggregates, groups, tallies, and gates.
#
# Usage:
#   orchestrate-conclusion-aggregate.sh --aggregate --session SID --tasks "N N N"
#       Reads every listed task's specs/{NNN}_{SLUG}/issues.jsonl (when present), groups
#       open/worked_around entries by class across tasks into proposals, separates kind:"win"
#       entries, tallies classes outside the 15-class seed enum, and lists touched tasks with
#       no contribution. Emits one JSON document on stdout.
#   orchestrate-conclusion-aggregate.sh --record-approval --session SID --channel a|b|c --answer yes|no
#       Writes one independent record for that channel into this invocation's approval ledger.
#   orchestrate-conclusion-aggregate.sh --check-approval --session SID --channel a|b|c
#       Exits 0 only when that channel's own ledger record says "yes". FAIL CLOSED: exits
#       non-zero for "no", an absent record, a malformed ledger, or any internal error -- the one
#       deliberate exception to this codebase's usual fail-open guard posture, because a
#       mis-firing channel gate is strictly worse than a channel that fails to fire when it
#       should have. See context/contracts/conclusion-stage.md's "Relationship to the Approval
#       Ledger" section.
#   orchestrate-conclusion-aggregate.sh --help
#       Show this usage and exit 0.
#
# The approval ledger lives at specs/.orchestration/.conclusion-approval-{session_id}.json (the
# existing **/.orchestration/ ephemeral, gitignored runtime-file class -- see
# context/standards/orchestrator-runtime-files.md), one JSON object per invocation with up to
# three keys ("a", "b", "c"), each "yes" or "no". Read-merge-write under flock, lazily created.
#
# NOT RUNNABLE FROM THE SOURCE STORE: deploy-root-guard.sh (sourced below) fails loudly when
# invoked from agent-system/extensions/core/scripts/. Deploy first (bash
# .claude/scripts/deploy-headless.sh, or the picker's [Reload All]/[Regenerate]), then exercise
# the deployed .claude/scripts/orchestrate-conclusion-aggregate.sh copy.
#
# Exit codes:
#   0 - --aggregate: JSON emitted on stdout. --record-approval: recorded. --check-approval: that
#       channel's own record says "yes". --help: usage shown.
#   1 - Argument/validation error (missing/empty required argument, unresolvable task number, an
#       unrecognized value for a closed-set field). Nothing written for --record-approval.
#   2 - --check-approval only: that channel is NOT approved (absent record, "no", or a malformed
#       ledger). Fail-closed, by design -- see the header note above.

set -euo pipefail

usage() {
  sed -n '2,46p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# --- Paths (sourced BEFORE argument parsing, including --help, so the deploy-root-guard refusal
#     applies universally -- matching roadmap-integration.sh's and every sibling script's
#     convention: this script is not runnable from the source store under ANY flag, not even
#     --help) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
source "${SCRIPT_DIR}/lib/task-lookup-lib.sh"

if [ $# -eq 0 ]; then
  usage
  exit 1
fi

MODE=""
session_arg=""
tasks_arg=""
channel_arg=""
answer_arg=""

while [ $# -gt 0 ]; do
  case "$1" in
    --aggregate) MODE="aggregate"; shift ;;
    --record-approval) MODE="record-approval"; shift ;;
    --check-approval) MODE="check-approval"; shift ;;
    --session) session_arg="${2:-}"; shift 2 ;;
    --tasks) tasks_arg="${2:-}"; shift 2 ;;
    --channel) channel_arg="${2:-}"; shift 2 ;;
    --answer) answer_arg="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "error: exactly one of --aggregate, --record-approval, --check-approval, --help is required" >&2
  usage
  exit 1
fi

if [ -z "$session_arg" ]; then
  echo "error: --session is required" >&2
  exit 1
fi

STATE_FILE="$PROJECT_ROOT/specs/state.json"
LEDGER_DIR="$PROJECT_ROOT/specs/.orchestration"
LEDGER_FILE="$LEDGER_DIR/.conclusion-approval-${session_arg}.json"
LOCK_FILE="$LEDGER_DIR/.conclusion-approval-${session_arg}.lock"

# ─── --record-approval ──────────────────────────────────────────────────────────────────────────
if [ "$MODE" = "record-approval" ]; then
  if [ -z "$channel_arg" ] || [ -z "$answer_arg" ]; then
    echo "error: --record-approval requires --channel and --answer" >&2
    exit 1
  fi
  case "$channel_arg" in
    a|b|c) ;;
    *) echo "error: invalid --channel '$channel_arg' (must be one of: a|b|c)" >&2; exit 1 ;;
  esac
  case "$answer_arg" in
    yes|no) ;;
    *) echo "error: invalid --answer '$answer_arg' (must be one of: yes|no)" >&2; exit 1 ;;
  esac

  mkdir -p "$LEDGER_DIR"
  (
    flock -x 200
    existing='{}'
    if [ -s "$LEDGER_FILE" ]; then
      existing="$(cat "$LEDGER_FILE" 2>/dev/null)" || existing='{}'
      echo "$existing" | jq -e . > /dev/null 2>&1 || existing='{}'
    fi
    updated="$(echo "$existing" | jq -c --arg ch "$channel_arg" --arg ans "$answer_arg" '.[$ch] = $ans')"
    printf '%s\n' "$updated" > "$LEDGER_FILE"
  ) 200> "$LOCK_FILE"
  echo "recorded: channel=$channel_arg answer=$answer_arg session=$session_arg"
  exit 0
fi

# ─── --check-approval (FAIL CLOSED) ────────────────────────────────────────────────────────────
if [ "$MODE" = "check-approval" ]; then
  if [ -z "$channel_arg" ]; then
    echo "error: --check-approval requires --channel" >&2
    exit 2
  fi
  case "$channel_arg" in
    a|b|c) ;;
    *) echo "error: invalid --channel '$channel_arg' (must be one of: a|b|c)" >&2; exit 2 ;;
  esac

  if [ ! -s "$LEDGER_FILE" ]; then
    echo "not-approved: channel=$channel_arg session=$session_arg (no ledger record)" >&2
    exit 2
  fi

  answer=""
  if ! answer="$(jq -r --arg ch "$channel_arg" '.[$ch] // "absent"' "$LEDGER_FILE" 2>/dev/null)"; then
    echo "not-approved: channel=$channel_arg session=$session_arg (malformed ledger)" >&2
    exit 2
  fi

  if [ "$answer" = "yes" ]; then
    echo "approved: channel=$channel_arg session=$session_arg"
    exit 0
  fi
  echo "not-approved: channel=$channel_arg session=$session_arg (recorded answer: $answer)" >&2
  exit 2
fi

# ─── --aggregate ────────────────────────────────────────────────────────────────────────────────
if [ "$MODE" = "aggregate" ]; then
  if [ -z "$tasks_arg" ]; then
    echo "error: --aggregate requires --tasks \"N N N\"" >&2
    exit 1
  fi

  # Seed enum (15 classes; context/formats/issue-log.md is authoritative -- kept in sync by hand,
  # same convention as issue-record.sh's own comment-only copy).
  SEED_CLASSES_JSON='[
    "design-record defect or ambiguity",
    "gate collision",
    "missing cheap verification tier",
    "vacuous or silent pass",
    "tooling bug or gap",
    "resource/OOM including misdiagnosis",
    "plan scope-hypothesis wrong",
    "planned feature absent",
    "language or module-system gotcha",
    "environment",
    "cross-task ownership/territory",
    "stale deploy or source-store boundary",
    "orchestration defect",
    "stale workaround",
    "cost-forced exclusion or substituted verification"
  ]'

  entries_tmp="$(mktemp)"
  no_contrib_tmp="$(mktemp)"
  trap 'rm -f "$entries_tmp" "$no_contrib_tmp"' EXIT

  : > "$entries_tmp"
  : > "$no_contrib_tmp"

  for task_num in $tasks_arg; do
    if ! [[ "$task_num" =~ ^[0-9]+$ ]]; then
      echo "error: --tasks entry '$task_num' is not a bare non-negative integer" >&2
      exit 1
    fi

    task_entry="$(task_lookup_entry "$task_num" "$STATE_FILE")"
    if [ -z "$task_entry" ]; then
      echo "warning: task $task_num does not resolve to any entry in $STATE_FILE; treating as no-contribution" >&2
      echo "$task_num" >> "$no_contrib_tmp"
      continue
    fi
    project_name="$(echo "$task_entry" | jq -r '.project_name // empty')"
    if [ -z "$project_name" ]; then
      echo "warning: task $task_num has no project_name; treating as no-contribution" >&2
      echo "$task_num" >> "$no_contrib_tmp"
      continue
    fi
    task_dir_rel="$(task_lookup_dir "$task_num" "$project_name" "$PROJECT_ROOT")"
    issues_file="$PROJECT_ROOT/$task_dir_rel/issues.jsonl"

    if [ ! -s "$issues_file" ]; then
      echo "$task_num" >> "$no_contrib_tmp"
      continue
    fi

    had_valid_line=0
    while IFS= read -r line || [ -n "$line" ]; do
      [ -z "$line" ] && continue
      if echo "$line" | jq -e . > /dev/null 2>&1; then
        echo "$line" | jq -c --argjson task "$task_num" '. + {task: $task}' >> "$entries_tmp"
        had_valid_line=1
      else
        echo "warning: skipping malformed issues.jsonl line in $issues_file" >&2
      fi
    done < "$issues_file"

    if [ "$had_valid_line" -eq 0 ]; then
      echo "$task_num" >> "$no_contrib_tmp"
    fi
  done

  no_contrib_json="$(jq -c -R -s 'split("\n") | map(select(length > 0) | tonumber)' "$no_contrib_tmp" 2>/dev/null)" || no_contrib_json='[]'

  jq -s \
    --argjson no_contribution_tasks "$no_contrib_json" \
    --argjson seed_classes "$SEED_CLASSES_JSON" \
    '
    def sev_rank: if . == "blocking" then 3 elif . == "costly" then 2 elif . == "minor" then 1 else 0 end;
    def sev_label: if . == 3 then "blocking" elif . == 2 then "costly" elif . == 1 then "minor" else "none" end;

    . as $entries
    | ($entries | map(select(.kind == "win"))) as $wins
    | ($entries
        | map(select(.kind != "win" and ((.resolution // "") as $r | $r == "open" or $r == "worked_around")))
      ) as $candidates
    | (
        $candidates
        | group_by(.class)
        | map({
            class: .[0].class,
            citations: map({task: .task, entry_id: .entry_id}),
            severity_max: (map(.severity | sev_rank) | max | sev_label),
            suggested_channel_hints: (map(.suggested_channel) | map(select(. != null)) | unique)
          })
      ) as $proposals
    | (
        $entries
        | map(select(([.class] - $seed_classes) | length > 0))
        | group_by(.class)
        | map({class: .[0].class, count: length})
      ) as $unknown_classes
    | {
        proposals: $proposals,
        wins: ($wins | map({task: .task, entry_id: .entry_id, class: .class, what_happened: .what_happened, estimated_cost: .estimated_cost, resolution: .resolution})),
        unknown_classes: $unknown_classes,
        no_contribution_tasks: $no_contribution_tasks
      }
    ' "$entries_tmp"

  exit 0
fi
