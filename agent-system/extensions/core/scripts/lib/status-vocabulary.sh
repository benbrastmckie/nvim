#!/usr/bin/env bash
# status-vocabulary.sh - Single source of truth for the task-status enum (specs/state.json
# `.active_projects[].status`, i.e. the TASK-LEVEL vocabulary -- a different, wider enum than
# the phase-heading vocabulary phase-heading-patterns.sh anchors).
#
# This is the ONLY place the closed 13-value task-status enum and its state.json-value ->
# TODO.md-marker mapping are defined as executable data. context/schemas/state-schema.json's
# `definitions.taskStatus.enum` is the machine-readable twin of this array -- the two MUST stay
# byte-equal (see scripts/tests/test-status-vocabulary.sh's drift assertion, which extracts the
# schema's enum via jq and diffs it against $STATUS_VOCABULARY_ENUM below). Prose docs
# (context/standards/status-markers.md, context/reference/state-management-schema.md) are
# human-readable glosses over this pair, never independent sources.
#
# `revising`/`revised` are deliberately NOT members of this enum. Three independent pieces of
# evidence converged on treating them as dead vocabulary rather than reconciling them in:
# update-task-status.sh's map_status() has no `revise` case (unreachable through the one
# canonical status writer), state-management-schema.md never mentions them, and
# skill-reviser/SKILL.md explicitly documents skipping the intermediate status ("No intermediate
# 'revising' status is needed for revision... Skip preflight status update"). Do not reintroduce
# them without re-reading that decision.
#
# Modeled on scripts/lib/phase-heading-patterns.sh's "one sourced shared library, many consumers"
# shape. The current consumer list is found live via
# `grep -rl 'status-vocabulary.sh' agent-system/extensions` (the same self-verifying
# consumer-discovery mechanism phase-heading-patterns.sh and task-reference-patterns.sh use).
#
# Usage: `source` this file, then:
#   - Use $STATUS_VOCABULARY_ENUM (bash array) directly for iteration/membership loops.
#   - Call `status_vocabulary_is_valid <value>` to validate a candidate status string.
#   - Use $STATUS_VOCABULARY_TODO_MARKER_MAP (associative array) or call
#     `status_vocabulary_todo_marker <value>` for the state.json-value -> TODO.md-marker mapping
#     (uppercase, space-separated, no brackets -- callers wrap in `[...]` themselves).

# ─── Closed task-status enum (13 values) ───────────────────────────────────────────────────────
# Order matches context/schemas/state-schema.json's definitions.taskStatus.enum exactly -- the
# drift test compares both as sorted sets, but keeping the literal order aligned makes a manual
# diff between the two files trivial.
STATUS_VOCABULARY_ENUM=(
  "not_started"
  "researching"
  "researched"
  "planning"
  "planned"
  "implementing"
  "pr_ready"
  "completed"
  "blocked"
  "abandoned"
  "partial"
  "expanded"
  "hold"
)

# ─── state.json value -> TODO.md marker mapping ────────────────────────────────────────────────
# Bracket-free uppercase marker text; callers that render `[STATUS]` add the brackets themselves
# (matching generate-todo.sh's existing format_status() output contract).
declare -A STATUS_VOCABULARY_TODO_MARKER_MAP=(
  ["not_started"]="NOT STARTED"
  ["researching"]="RESEARCHING"
  ["researched"]="RESEARCHED"
  ["planning"]="PLANNING"
  ["planned"]="PLANNED"
  ["implementing"]="IMPLEMENTING"
  ["pr_ready"]="PR READY"
  ["completed"]="COMPLETED"
  ["blocked"]="BLOCKED"
  ["abandoned"]="ABANDONED"
  ["partial"]="PARTIAL"
  ["expanded"]="EXPANDED"
  ["hold"]="HOLD"
)

# ─── status_vocabulary_is_valid <value> ────────────────────────────────────────────────────────
# Returns 0 (true) iff <value> is exactly one of the thirteen closed enum values, 1 (false)
# otherwise. Never partial-matches (e.g. "not_started_x" is rejected).
status_vocabulary_is_valid() {
  local candidate="$1" v
  for v in "${STATUS_VOCABULARY_ENUM[@]}"; do
    [[ "$candidate" == "$v" ]] && return 0
  done
  return 1
}

# ─── status_vocabulary_todo_marker <value> ─────────────────────────────────────────────────────
# Prints the bracket-free uppercase TODO.md marker text for <value> on stdout and returns 0 when
# <value> is a member of the closed enum. Prints nothing and returns 1 when it is not -- callers
# needing a loud failure on an off-schema value (e.g. generate-todo.sh's format_status()) should
# check the return code rather than trusting empty output alone.
status_vocabulary_todo_marker() {
  local candidate="$1"
  if ! status_vocabulary_is_valid "$candidate"; then
    return 1
  fi
  printf '%s\n' "${STATUS_VOCABULARY_TODO_MARKER_MAP[$candidate]}"
  return 0
}

# ─── STATUS_VOCABULARY_LIFECYCLE_RANK ──────────────────────────────────────────────────────────
# Linear-progress subset of the closed enum above, ranked in the order the valid-transition
# diagram in context/standards/status-markers.md documents. `blocked`, `partial`, `abandoned`,
# and `expanded` are deliberately OMITTED: per rules/state-management.md's permissive model these
# are non-terminal exception states or terminal states that live outside the linear axis, and the
# monotonic-max clamp below concerns only ordinary lifecycle-progress regression. `hold` is
# deliberately omitted too -- it is a human-initiated pause, not a point on the linear-progress
# axis, and belongs in the same omitted set as blocked/partial/abandoned/expanded rather than
# being assigned a rank. `pr_ready` is
# included at rank 6 -- it sits on the linear axis between `implementing` and `completed` -- even
# though the status-markers.md transition diagram's research-cited ordering text stopped at
# `completed`.
declare -A STATUS_VOCABULARY_LIFECYCLE_RANK=(
  ["not_started"]=0
  ["researching"]=1
  ["researched"]=2
  ["planning"]=3
  ["planned"]=4
  ["implementing"]=5
  ["pr_ready"]=6
  ["completed"]=7
)

# ─── status_vocabulary_rank <status> ───────────────────────────────────────────────────────────
# Prints the lifecycle rank for <status> on stdout when it is a member of the ranked subset
# above; prints nothing (empty string) when <status> is unranked (including when it is not a
# member of the closed enum at all). Always returns 0 -- callers test the printed value, not the
# return code, matching status_vocabulary_todo_marker's convention would invert this, but an
# empty-vs-nonempty check is simpler for the boolean predicate below to build on.
status_vocabulary_rank() {
  local candidate="$1"
  if [[ -n "${STATUS_VOCABULARY_LIFECYCLE_RANK[$candidate]+set}" ]]; then
    printf '%s\n' "${STATUS_VOCABULARY_LIFECYCLE_RANK[$candidate]}"
  fi
  return 0
}

# ─── status_vocabulary_would_regress <current> <target> ───────────────────────────────────────
# Returns 0 (yes, this transition would regress the task's lifecycle position) only when BOTH
# <current> and <target> are ranked AND rank(target) <= rank(current) -- equal rank counts as a
# regression for monotonic-max purposes (re-writing the same resting state is not forward
# progress). Returns 1 (no, does not regress / clamp does not apply) in every other case,
# including when either side is unranked (blocked/partial/abandoned/expanded, or any value
# outside the closed enum). This "unranked means the clamp does not apply" rule is the
# deliberate, minimal choice: a forced phase on a `partial` or `blocked` task writes its status
# exactly as it does today.
status_vocabulary_would_regress() {
  local current="$1" target="$2"
  local current_rank target_rank
  current_rank=$(status_vocabulary_rank "$current")
  target_rank=$(status_vocabulary_rank "$target")
  if [[ -z "$current_rank" || -z "$target_rank" ]]; then
    return 1
  fi
  if [[ "$target_rank" -le "$current_rank" ]]; then
    return 0
  fi
  return 1
}
