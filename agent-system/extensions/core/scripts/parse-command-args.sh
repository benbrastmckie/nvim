#!/usr/bin/env bash
# parse-command-args.sh — Superset argument parser for Claude Code commands
#
# Usage: source .claude/scripts/parse-command-args.sh "$ARGUMENTS"
#
# IMPORTANT: This script MUST be sourced (not called as a subprocess) because
# it exports variables into the calling shell. Source it within a single Bash
# tool invocation so the exported variables are visible to subsequent commands
# in that same invocation.
#
# Exported Variables:
#   TASK_NUMBERS   — space-separated list of task numbers (ranges expanded)
#   REMAINING_ARGS — remaining args string after task numbers removed
#   EFFORT_FLAG    — "fast", "hard", or ""
#   MODEL_FLAG     — "haiku", "sonnet", "opus", "fable", or ""
#   CLEAN_FLAG     — "true" or "false"
#   FORCE_FLAG     — "true" or "false"
#   DRY_RUN_FLAG   — "true" or "false" (--dry-run mode: report-only, no dispatch)
#   LOCAL_FLAG     — "true" or "false" (--local mode opt-out for /meta global-default targeting)
#   EXPLOIT_FLAG   — "true" or "false" (--exploit mode hint for team research)
#   EXPLORE_FLAG   — "true" or "false" (--explore mode hint for team research)
#   LIT_FLAG       — "true" or "false" (--lit mode hint for literature-based tasks)
#   COMPARE_FLAG   — "true" or "false" (--compare mode hint for advisory Comparator-gated
#                    lean implementation dispatches; composes with --hard rather than competing
#                    with it, same as LIT_FLAG and CLEAN_FLAG)
#   ALLOW_SELF_MODIFYING_FLAG — "true" or "false" (default off; opt-in bypass of the
#                    self-modification admission gate, per-invocation only)
#   ALLOW_SCOPE_COLLISION_FLAG — "true" or "false" (default off; opt-in consumer-side bypass of
#                    the CROSS-BATCH `file_scope_collision` admission gate, for this invocation
#                    only. Never bypasses an `in_batch` collision — see D1 in the originating
#                    plan; the unqualified flag name deliberately does not cover `in_batch`)
#   CONTINUE_BUDGET_FLAG — "true" or "false" (default off; /orchestrate --continue-budget:
#                    Defect B's explicit, operator-typed override authorizing a fresh
#                    work-cycle budget after MAX_CYCLES exhaustion, per-invocation only --
#                    never inferred automatically)
#   FORCE_PHASES_FLAG — comma-separated subset of "research,plan,implement", or "" (default;
#                    /orchestrate-only). Composable: any combination of --research/--plan/
#                    --implement may be passed together. Canonicalized to lifecycle order
#                    (research, plan, implement) regardless of the order the flags were typed
#                    on the command line -- "--plan --research" and "--research --plan" both
#                    yield "research,plan".
#   FOCUS_PROMPT   — remaining text after all recognized flags stripped
#
# Downstream dependencies:
#   skill-base.sh will source this script.
#   The multi-task dispatch extraction relies on TASK_NUMBERS and REMAINING_ARGS.

parse_command_args() {
  local args="$1"

  # Step 1: Extract task spec (leading digits, commas, ranges, spaces — stop at letters or --)
  # Uses bash regex to capture leading task spec before any text/flags
  local task_spec=""
  if [[ "$args" =~ ^([0-9][0-9,\ \-]*)(\ +.*)?$ ]]; then
    task_spec="${BASH_REMATCH[1]}"
  fi
  # Trim trailing whitespace and commas
  task_spec=$(echo "$task_spec" | sed 's/[, ]*$//')

  # Step 2: Expand ranges "22-24" -> "22 23 24"
  TASK_NUMBERS=""
  for token in $(echo "$task_spec" | tr ',' ' '); do
    token=$(echo "$token" | xargs)  # trim whitespace
    if [ -z "$token" ]; then
      continue
    fi
    if echo "$token" | grep -qE '^[0-9]+-[0-9]+$'; then
      start=$(echo "$token" | cut -d'-' -f1)
      end=$(echo "$token" | cut -d'-' -f2)
      for n in $(seq "$start" "$end"); do
        TASK_NUMBERS="$TASK_NUMBERS $n"
      done
    else
      TASK_NUMBERS="$TASK_NUMBERS $token"
    fi
  done
  TASK_NUMBERS=$(echo "$TASK_NUMBERS" | xargs)  # trim whitespace

  # Step 3: Strip task spec to get remaining args
  local remaining
  remaining="${args#$task_spec}"
  remaining=$(echo "$remaining" | sed 's/^[[:space:]]*//')
  REMAINING_ARGS="$remaining"

  # Step 4: Scan for flags (superset — all commands, all flags)
  EFFORT_FLAG=""
  MODEL_FLAG=""
  CLEAN_FLAG="false"
  FORCE_FLAG="false"
  DRY_RUN_FLAG="false"
  LOCAL_FLAG="false"
  EXPLOIT_FLAG="false"
  EXPLORE_FLAG="false"
  LIT_FLAG="false"
  COMPARE_FLAG="false"
  ALLOW_SELF_MODIFYING_FLAG="false"
  ALLOW_SCOPE_COLLISION_FLAG="false"
  CONTINUE_BUDGET_FLAG="false"
  FORCE_PHASES_FLAG=""

  if [[ "$remaining" =~ --fast ]]; then
    EFFORT_FLAG="fast"
  fi
  if [[ "$remaining" =~ --hard ]]; then
    EFFORT_FLAG="hard"
  fi
  if [[ "$remaining" =~ --haiku ]]; then
    MODEL_FLAG="haiku"
  fi
  if [[ "$remaining" =~ --sonnet ]]; then
    MODEL_FLAG="sonnet"
  fi
  if [[ "$remaining" =~ --opus ]]; then
    MODEL_FLAG="opus"
  fi
  if [[ "$remaining" =~ --fable ]]; then
    MODEL_FLAG="fable"
  fi
  if [[ "$remaining" =~ --clean ]]; then
    CLEAN_FLAG="true"
  fi
  if [[ "$remaining" =~ --force ]]; then
    FORCE_FLAG="true"
  fi
  if [[ "$remaining" =~ --dry-run ]]; then
    DRY_RUN_FLAG="true"
  fi
  if [[ "$remaining" =~ --local ]]; then
    LOCAL_FLAG="true"
  fi
  if [[ "$remaining" =~ --exploit ]]; then
    EXPLOIT_FLAG="true"
  fi
  if [[ "$remaining" =~ --explore ]]; then
    EXPLORE_FLAG="true"
  fi
  if [[ "$remaining" =~ --lit ]]; then
    LIT_FLAG="true"
  fi
  if [[ "$remaining" =~ --compare ]]; then
    COMPARE_FLAG="true"
  fi
  if [[ "$remaining" =~ --allow-self-modifying ]]; then
    ALLOW_SELF_MODIFYING_FLAG="true"
  fi
  if [[ "$remaining" =~ --allow-scope-collision ]]; then
    ALLOW_SCOPE_COLLISION_FLAG="true"
  fi
  if [[ "$remaining" =~ --continue-budget ]]; then
    CONTINUE_BUDGET_FLAG="true"
  fi
  if [[ "$remaining" =~ --research ]]; then
    FORCE_PHASES_FLAG="${FORCE_PHASES_FLAG:+$FORCE_PHASES_FLAG,}research"
  fi
  if [[ "$remaining" =~ --plan ]]; then
    FORCE_PHASES_FLAG="${FORCE_PHASES_FLAG:+$FORCE_PHASES_FLAG,}plan"
  fi
  if [[ "$remaining" =~ --implement ]]; then
    FORCE_PHASES_FLAG="${FORCE_PHASES_FLAG:+$FORCE_PHASES_FLAG,}implement"
  fi

  # Step 5: Strip all recognized flags to produce FOCUS_PROMPT
  FOCUS_PROMPT=$(echo "$remaining" \
    | sed 's/--fast//g' \
    | sed 's/--hard//g' \
    | sed 's/--haiku//g' \
    | sed 's/--sonnet//g' \
    | sed 's/--opus//g' \
    | sed 's/--fable//g' \
    | sed 's/--clean//g' \
    | sed 's/--force//g' \
    | sed 's/--dry-run//g' \
    | sed 's/--local//g' \
    | sed 's/--exploit//g' \
    | sed 's/--explore//g' \
    | sed 's/--lit//g' \
    | sed 's/--compare//g' \
    | sed 's/--allow-self-modifying//g' \
    | sed 's/--allow-scope-collision//g' \
    | sed 's/--continue-budget//g' \
    | sed 's/--research//g' \
    | sed 's/--plan//g' \
    | sed 's/--implement//g' \
    | xargs)

  # Step 6: Validate — at least one task number is required
  if [ -z "$TASK_NUMBERS" ]; then
    echo "ERROR: No task numbers found in arguments: $args" >&2
    return 1
  fi

  export TASK_NUMBERS REMAINING_ARGS EFFORT_FLAG MODEL_FLAG CLEAN_FLAG FORCE_FLAG DRY_RUN_FLAG LOCAL_FLAG EXPLOIT_FLAG EXPLORE_FLAG LIT_FLAG COMPARE_FLAG ALLOW_SELF_MODIFYING_FLAG ALLOW_SCOPE_COLLISION_FLAG CONTINUE_BUDGET_FLAG FORCE_PHASES_FLAG FOCUS_PROMPT
}

parse_command_args "$1"
