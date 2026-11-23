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
#       entries, tallies classes outside the 18-class seed enum, and lists touched tasks with
#       no contribution. A null or omitted `resolution` on a non-win entry is read identically to
#       `"open"`, so it enters classification rather than being silently dropped; the output's
#       `implicit_open_count` field reports how many candidates arrived that way, informational
#       only. Emits one JSON document on stdout.
#
#       Grouping is CASE- AND SEPARATOR-FOLDED, never a rewrite: `COVERAGE_GAP` and `coverage-gap`
#       fold to the same key and group into one proposal, but the stored `class` value in any
#       issues.jsonl is never modified -- the fold is a read-time transformation inside this one
#       jq filter. Each proposal's `class` is the group's most-frequent raw spelling
#       (lexicographically-smallest-wins tie-break), and `class_variants` lists every distinct raw
#       spelling seen in that group, so a merge is auditable from the output alone. A curated,
#       hand-maintained alias table (shipped empty; see `CLASS_ALIASES_JSON` below) additionally
#       maps one folded spelling to another folded spelling for a semantic merge a human has
#       separately decided is correct -- adding an entry there is a one-line data edit, never a
#       structural change. `unknown_classes` is tallied post-fold, keyed the same way, so spelling
#       noise never inflates it and a canonicalize-to-unrecognized entry is never dropped from
#       either `proposals` or `unknown_classes`.
#   orchestrate-conclusion-aggregate.sh --record-approval --session SID --channel a|b|c|edges --answer yes|no
#       Writes one independent record for that key into this invocation's approval ledger.
#   orchestrate-conclusion-aggregate.sh --check-approval --session SID --channel a|b|c|edges
#       Exits 0 only when that key's own ledger record says "yes". FAIL CLOSED: exits
#       non-zero for "no", an absent record, a malformed ledger, or any internal error -- the one
#       deliberate exception to this codebase's usual fail-open guard posture, because a
#       mis-firing channel gate is strictly worse than a channel that fails to fire when it
#       should have. See context/contracts/conclusion-stage.md's "Relationship to the Approval
#       Ledger" section.
#   orchestrate-conclusion-aggregate.sh --help
#       Show this usage and exit 0.
#
# The closed `--channel` key vocabulary is `a|b|c|edges`. Keys "a", "b", "c" are the three
# conclusion-stage CHANNELS (fix-now, agent-system change, follow-up task). "edges" is NOT a
# fourth channel -- it is an independent, non-channel approval key for the conclusion stage's
# Step 7 next-batch edge write (see context/contracts/conclusion-stage.md). It is gated and read
# through the exact same fail-closed `--record-approval`/`--check-approval` mechanism as a
# channel, under its own key, so no channel's approval ever satisfies "edges" and an "edges"
# approval never satisfies any channel -- see the approval-isolation test for the cross-key proof
# in both directions.
#
# The approval ledger lives at specs/.orchestration/.conclusion-approval-{session_id}.json (the
# existing **/.orchestration/ ephemeral, gitignored runtime-file class -- see
# context/standards/orchestrator-runtime-files.md), one JSON object per invocation with up to
# four keys ("a", "b", "c", "edges"), each "yes" or "no". Read-merge-write under flock, lazily
# created.
#
# FLAG-PARSING AUDIT: a repeated `--tasks N` flag is REJECTED with a non-zero exit and a usage
# error naming the correct single-string form -- it is never silently last-wins. The correct
# call shape is one space-separated string: --tasks "275 274 378". A second, repeated
# mode-selecting flag (--aggregate, --record-approval, --check-approval) is rejected the same
# way, enforcing the "exactly one of ..." promise this header already makes. --session,
# --channel and --answer are genuinely scalar selectors (a session id, a closed-enum channel
# key, a closed-enum yes/no answer); last-occurrence-wins is the ordinary, unsurprising shell
# convention for those three and is left unchanged. No other list-valued flag exists in this
# script.
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
  sed -n '2,69p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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
mode_seen=0
tasks_seen=0

while [ $# -gt 0 ]; do
  case "$1" in
    --aggregate|--record-approval|--check-approval)
      mode_seen=$((mode_seen + 1))
      if [ "$mode_seen" -gt 1 ]; then
        echo "error: exactly one of --aggregate, --record-approval, --check-approval is required, but more than one was given (saw '$1' after MODE was already set to '$MODE')" >&2
        usage
        exit 1
      fi
      case "$1" in
        --aggregate) MODE="aggregate" ;;
        --record-approval) MODE="record-approval" ;;
        --check-approval) MODE="check-approval" ;;
      esac
      shift
      ;;
    --session) session_arg="${2:-}"; shift 2 ;;
    --tasks)
      tasks_seen=$((tasks_seen + 1))
      if [ "$tasks_seen" -gt 1 ]; then
        echo "error: --tasks was given more than once; pass every task number in ONE space-separated string instead, e.g. --tasks \"N N N\" (repeated --tasks flags are rejected, never silently last-wins)" >&2
        usage
        exit 1
      fi
      tasks_arg="${2:-}"
      shift 2
      ;;
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
    a|b|c|edges) ;;
    *) echo "error: invalid --channel '$channel_arg' (must be one of: a|b|c|edges)" >&2; exit 1 ;;
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
    a|b|c|edges) ;;
    *) echo "error: invalid --channel '$channel_arg' (must be one of: a|b|c|edges)" >&2; exit 2 ;;
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

  # Seed enum (18 classes; context/formats/issue-log.md is authoritative -- kept in sync by hand,
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
    "cost-forced exclusion or substituted verification",
    "infrastructure/transport unavailable",
    "knowledge-capture gap",
    "scope excursion"
  ]'

  # Semantic alias table (shipped empty; context/formats/issue-log.md's "Promoting a Class"
  # subsection documents the promotion path). Shape: {"<folded-variant>": "<folded-canonical>"},
  # consulted by canon_class() below, AFTER the mechanical case/separator fold and BEFORE
  # grouping. Adding an entry here is the one-line data edit a future, better-evidenced semantic
  # merge requires -- see the plan's Decision D1 for why no automatic semantic merge (e.g.
  # collapsing the five "scope" variants, or "design-gap" into "design-ambiguity") is applied
  # here today. Zero entries, deliberately.
  CLASS_ALIASES_JSON='{}'

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
    --argjson class_aliases "$CLASS_ALIASES_JSON" \
    '
    # fold_class/canon_class are the grouping-time-only normalization twin of the bash
    # issue_fold_class() helper inside issue-record.sh. SHARED FRAGILITY: a change to either
    # requires a matching change to the other. HARD CONSTRAINT: this is a read-time
    # transformation inside this one jq filter -- no issues.jsonl line is ever rewritten by it;
    # the stored class value in any fixture or real issues.jsonl is byte-identical before and
    # after this script runs.
    def fold_class: ascii_downcase | gsub("[-_\\s]+"; " ") | gsub("^ +| +$"; "");
    def canon_class($aliases): fold_class as $f | ($aliases[$f] // $f);
    # Deterministic representative selection for a folded group: the most frequent raw spelling,
    # tie-broken by the lexicographically smallest spelling (stable double sort_by).
    def most_frequent_raw($raws): $raws | group_by(.) | map({v: .[0], c: length}) | sort_by(.v) | sort_by(-.c) | .[0].v;

    def sev_rank: if . == "blocking" then 3 elif . == "costly" then 2 elif . == "minor" then 1 else 0 end;
    def sev_label: if . == 3 then "blocking" elif . == 2 then "costly" elif . == 1 then "minor" else "none" end;

    . as $entries
    | ($entries | map(select(.kind == "win"))) as $wins
    | ($entries
        | map(select(.kind != "win" and ((.resolution // "open") as $r | $r == "open" or $r == "worked_around")))
      ) as $candidates
    | ($candidates | map(select(.resolution == null)) | length) as $implicit_open_count
    | ($seed_classes | map(canon_class($class_aliases))) as $canon_seeds
    | (
        $candidates
        | group_by(.class | canon_class($class_aliases))
        | map(
            . as $group
            | ($group | map({task: .task, entry_id: .entry_id})) as $all_citations
            | ($group | map(.class)) as $raw_classes
            | {
                class: most_frequent_raw($raw_classes),
                class_variants: ($raw_classes | unique),
                citations: ($all_citations[0:10]),
                citations_remainder: (if ($all_citations | length) > 10 then (($all_citations | length) - 10) else 0 end),
                severity_max: ($group | map(.severity | sev_rank) | max | sev_label),
                suggested_channel_hints: ($group | map(.suggested_channel) | map(select(. != null)) | unique)
              }
          )
      ) as $proposals
    | (
        $entries
        | map(select( ((.class | canon_class($class_aliases)) as $c | ($canon_seeds | index($c))) == null ))
        | group_by(.class | canon_class($class_aliases))
        | map(
            . as $group
            | ($group | map(.class)) as $raw_classes
            | {class: most_frequent_raw($raw_classes), count: ($group | length), variants: ($raw_classes | unique)}
          )
      ) as $unknown_classes
    | {
        proposals: $proposals,
        wins: ($wins | map({task: .task, entry_id: .entry_id, class: .class, what_happened: .what_happened, estimated_cost: .estimated_cost, resolution: .resolution})),
        unknown_classes: $unknown_classes,
        implicit_open_count: $implicit_open_count,
        no_contribution_tasks: $no_contribution_tasks
      }
    ' "$entries_tmp"

  exit 0
fi
