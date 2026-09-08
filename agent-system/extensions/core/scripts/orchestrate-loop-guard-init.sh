#!/usr/bin/env bash
# orchestrate-loop-guard-init.sh — Shared Stage 2 loop-guard initializer prologue for both
# orchestrate engines (dedup of the orchestrate-skill-body duplication), PLUS (task that ported
# single-task features into the batch engine, Decision 1) the batch engine's shared
# read/seed/flush helper for the same `.orchestrator-loop-guard` file's `cycle_count` field.
#
# Positional form (`<task_dir> <handoff_path_abs>`) covers ONLY the portion of single-task Stage 2
# that sits strictly BEFORE the `budget-continuation-override:begin` sentinel (locked, never
# touched — see specs/055_dedupe_orchestrate_skill_bodies/locked-regions.md) and the small
# blocker-escalation counter pair that sits strictly AFTER the locked region's resume-read block.
# Nothing inside the locked region itself (budget-continuation-override:begin through each
# engine's resume anchor, per test-loop-guard-budget-override.sh) is touched by this script or
# its call sites. This form is deliberately a SMALL extraction — most of Stage 2 is either
# genuinely per-engine (MAX_CYCLES value, the hard-only loop-guard-staleness detector, churn-state
# init, current_plan_version) or inside the locked region. A small measured byte count here is the
# correct outcome, not a shortfall (see the plan's Phase 6 Scope Hypothesis).
#
# `--seed`/`--flush` forms back Decision 1's per-task cumulative cycle budget for the BATCH engine
# (`orchestrate-cycle-plan.sh`), which has no locked region and no single-task Stage 2 call site of
# its own. They touch ONLY the `cycle_count` field and `last_updated`; every other field in the
# guard file's existing schema (`dispatch_seq_counter`, `detected_defects`,
# `burnout_signals_this_session`, `max_cycles`, `infra_failures`, `session_id`, `plan_version`,
# ...) is read/write-preserved untouched, matching the plan's "leave that file's JSON schema
# unchanged" instruction — no new schema is invented, only this one field is touched by these two
# new forms.
#
# Usage:
#   orchestrate-loop-guard-init.sh <task_dir> <handoff_path_abs>
#     Side effect: `mkdir -p <task_dir>` (matching the pre-dedup inline `mkdir -p "$TASK_DIR"`).
#     Output: a single-line compact JSON object on stdout. Fields:
#       loop_guard_file          string  "<task_dir>/.orchestrator-loop-guard"
#       handoff_file              string  echoes handoff_path_abs verbatim
#       max_infra_failures        int     3 (flat, not scaled with MAX_CYCLES — see
#                                           context/patterns/infra-failure-discrimination.md)
#       blocker_escalation_count  int     0 (reset each /orchestrate invocation)
#       max_blocker_escalations   int     2
#
#   orchestrate-loop-guard-init.sh --seed <task_dir_abs>
#     READ-ONLY peek at "<task_dir_abs>/.orchestrator-loop-guard"'s `cycle_count` field — no
#     mutation, no `mkdir -p`, safe to call under --dry-run (mirrors this codebase's existing
#     read-only PROBE convention, e.g. `task-lock.sh check` vs. `acquire`). A missing directory,
#     missing file, or unparseable JSON all degrade to `cycle_count: 0` (first sight of this task
#     — the same "resume at 0" posture the single-task locked region's own resume-read applies to
#     a pre-schema guard file via its `// 0` idiom). Also peeks `pending_dispatch` (see
#     `--record-pending`/`--clear-pending` below), defaulting to `null` for a pre-schema guard
#     file — the same forward-compatibility posture as `cycle_count`'s `// 0`.
#     Output: `{"cycle_count": <int>, "pending_dispatch": <object>|null}`.
#
#   orchestrate-loop-guard-init.sh --flush <task_dir_abs> <cycle_count>
#     Read-modify-write "<task_dir_abs>/.orchestrator-loop-guard": sets `.cycle_count` to the given
#     non-negative integer and `.last_updated` to now, preserving every other field. Creates the
#     file (and the directory, via `mkdir -p`) if absent, starting from `{}` — so a task first
#     routed through the batch path with no prior single-task guard file gets one seeded here,
#     with every other field forward-compatible-defaulted (`// 0`, `// []`) by its later readers
#     (`orchestrate-churn.sh`'s `--burnout-signal`, a future single-task resume) exactly as an
#     old-format guard already is today.
#     Output: `{"cycle_count": <int>}` (echoes the value just written).
#
#   orchestrate-loop-guard-init.sh --record-pending <task_dir_abs> <json>
#     Read-modify-write: sets `.pending_dispatch` to the given JSON object verbatim (must already
#     be a valid, already-serialized JSON object — this form does not construct it), preserving
#     every other field, including `cycle_count`. Creates the file/directory if absent, exactly
#     like `--flush`. The durable cross-invocation ledger half of "do not charge for a read": a
#     dispatch row this cycle actually charges records itself here so a LATER invocation (a fresh
#     `mt_state_file`, unlike `--seed`/`--flush`'s in-session `plan_cache` counterpart) can tell
#     "was this exact charge ever consumed" even after the charging session is long gone.
#     Shape written: `{seq: int, phase: string, forced: bool, dispatch_file: string,
#     recorded_at: string}`. Output: `{"pending_dispatch": <object just written>}`.
#
#   orchestrate-loop-guard-init.sh --clear-pending <task_dir_abs>
#     Read-modify-write: `del(.pending_dispatch)`, preserving every other field. Reaching
#     postflight for a dispatch at all is proof it was consumed — success, failure, defer, and
#     off-schema outcomes all clear it identically. A missing file, or a file with no
#     `pending_dispatch` key, is a safe no-op (idempotent clear). Does NOT `mkdir -p` — clearing a
#     ledger entry that was never recorded (no directory at all) has nothing to do. Output:
#     `{"pending_dispatch": null}`.
#
# Exit codes: 0 on normal completion. 2 — usage error, jq unavailable, a non-integer `--flush`
# cycle_count argument, or invalid JSON given to `--record-pending`.

set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: orchestrate-loop-guard-init.sh: jq is not available." >&2
  exit 2
fi

case "${1:-}" in
  --seed)
    seed_task_dir="${2:-}"
    if [ -z "$seed_task_dir" ] || [ "$#" -ne 2 ]; then
      echo "ERROR: orchestrate-loop-guard-init.sh: usage: orchestrate-loop-guard-init.sh --seed <task_dir_abs>" >&2
      exit 2
    fi
    seed_guard_file="${seed_task_dir}/.orchestrator-loop-guard"
    seed_cycle_count=0
    seed_pending_json="null"
    if [ -f "$seed_guard_file" ] && jq empty "$seed_guard_file" 2>/dev/null; then
      seed_cycle_count=$(jq -r '.cycle_count // 0' "$seed_guard_file" 2>/dev/null) || seed_cycle_count=0
      case "$seed_cycle_count" in ''|*[!0-9]*) seed_cycle_count=0 ;; esac
      seed_pending_json=$(jq -c '.pending_dispatch // null' "$seed_guard_file" 2>/dev/null) || seed_pending_json="null"
    fi
    jq -n -c --argjson c "$seed_cycle_count" --argjson p "$seed_pending_json" \
      '{cycle_count: $c, pending_dispatch: $p}'
    exit 0
    ;;
  --flush)
    flush_task_dir="${2:-}"
    flush_cycle_count="${3:-}"
    if [ -z "$flush_task_dir" ] || [ "$#" -ne 3 ]; then
      echo "ERROR: orchestrate-loop-guard-init.sh: usage: orchestrate-loop-guard-init.sh --flush <task_dir_abs> <cycle_count>" >&2
      exit 2
    fi
    case "$flush_cycle_count" in
      ''|*[!0-9]*)
        echo "ERROR: orchestrate-loop-guard-init.sh: --flush cycle_count '${flush_cycle_count}' is not a non-negative integer." >&2
        exit 2
        ;;
    esac
    mkdir -p "$flush_task_dir"
    flush_guard_file="${flush_task_dir}/.orchestrator-loop-guard"
    flush_base="{}"
    if [ -f "$flush_guard_file" ] && jq empty "$flush_guard_file" 2>/dev/null; then
      flush_base=$(cat "$flush_guard_file")
    fi
    printf '%s\n' "$flush_base" | jq -c \
      --argjson c "$flush_cycle_count" \
      --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '.cycle_count = $c | .last_updated = $updated' \
      > "${flush_guard_file}.tmp" && mv "${flush_guard_file}.tmp" "$flush_guard_file"
    jq -n -c --argjson c "$flush_cycle_count" '{cycle_count: $c}'
    exit 0
    ;;
  --record-pending)
    rp_task_dir="${2:-}"
    rp_json="${3:-}"
    if [ -z "$rp_task_dir" ] || [ "$#" -ne 3 ]; then
      echo "ERROR: orchestrate-loop-guard-init.sh: usage: orchestrate-loop-guard-init.sh --record-pending <task_dir_abs> <json>" >&2
      exit 2
    fi
    if ! printf '%s' "$rp_json" | jq empty >/dev/null 2>&1; then
      echo "ERROR: orchestrate-loop-guard-init.sh: --record-pending <json> is not valid JSON." >&2
      exit 2
    fi
    mkdir -p "$rp_task_dir"
    rp_guard_file="${rp_task_dir}/.orchestrator-loop-guard"
    rp_base="{}"
    if [ -f "$rp_guard_file" ] && jq empty "$rp_guard_file" 2>/dev/null; then
      rp_base=$(cat "$rp_guard_file")
    fi
    printf '%s\n' "$rp_base" | jq -c \
      --argjson p "$rp_json" \
      --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '.pending_dispatch = $p | .last_updated = $updated' \
      > "${rp_guard_file}.tmp" && mv "${rp_guard_file}.tmp" "$rp_guard_file"
    jq -n -c --argjson p "$rp_json" '{pending_dispatch: $p}'
    exit 0
    ;;
  --clear-pending)
    cp_task_dir="${2:-}"
    if [ -z "$cp_task_dir" ] || [ "$#" -ne 2 ]; then
      echo "ERROR: orchestrate-loop-guard-init.sh: usage: orchestrate-loop-guard-init.sh --clear-pending <task_dir_abs>" >&2
      exit 2
    fi
    cp_guard_file="${cp_task_dir}/.orchestrator-loop-guard"
    if [ -f "$cp_guard_file" ] && jq empty "$cp_guard_file" 2>/dev/null; then
      jq -c --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        'del(.pending_dispatch) | .last_updated = $updated' \
        "$cp_guard_file" > "${cp_guard_file}.tmp" && mv "${cp_guard_file}.tmp" "$cp_guard_file"
    fi
    # A missing/unparseable guard file: nothing to clear, still a success (idempotent).
    jq -n -c '{pending_dispatch: null}'
    exit 0
    ;;
esac

task_dir="${1:-}"
handoff_path_abs="${2:-}"

if [ -z "$task_dir" ] || [ "$#" -ne 2 ]; then
  echo "ERROR: orchestrate-loop-guard-init.sh: usage: orchestrate-loop-guard-init.sh <task_dir> <handoff_path_abs>" >&2
  exit 2
fi

mkdir -p "$task_dir"

loop_guard_file="${task_dir}/.orchestrator-loop-guard"

jq -n -c \
  --arg loop_guard_file "$loop_guard_file" \
  --arg handoff_file "$handoff_path_abs" \
  --argjson max_infra_failures 3 \
  --argjson blocker_escalation_count 0 \
  --argjson max_blocker_escalations 2 \
  '{loop_guard_file: $loop_guard_file, handoff_file: $handoff_file,
    max_infra_failures: $max_infra_failures,
    blocker_escalation_count: $blocker_escalation_count,
    max_blocker_escalations: $max_blocker_escalations}'

exit 0
