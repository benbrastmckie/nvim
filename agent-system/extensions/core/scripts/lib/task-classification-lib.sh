#!/usr/bin/env bash
# task-classification-lib.sh - Terminal-status, forced-phase, and build-heavy-implement
# classification predicates, extracted verbatim from orchestrate-cycle-plan.sh's
# orchestrate_cycle_plan_main() (Phase 5 of the script-corpus decomposition task).
#
# EXTRACTION METHOD: identical to scripts/lib/territory-contention-lib.sh's Phase 4 extraction --
# see that file's own header for the full rationale. Summary: bash scopes `local` DYNAMICALLY (by
# call stack), not lexically (by textual nesting), so a function sourced from a separate file
# still sees a caller's locals when invoked from within that caller's own execution. The four
# blocks below are therefore VERBATIM, byte-for-byte relocations of the original text -- no
# parameter list added, no call site below needed to change. `source` this file from
# orchestrate-cycle-plan.sh alongside the other early lib sources (order relative to
# territory-contention-lib.sh does not matter -- the two libs are independent of each other).
#
# HONEST SIZE, STATED PLAINLY: this is a SMALL extraction -- 34 lines of actual function body
# across four disjoint call sites (67 lines total including their banner comments and the
# build-heavy `task_type` family array's own declaration), not the ~535 lines an earlier
# line-delta-based research estimate suggested (see this task's plan, "Research Integration"
# section, for why that proxy was unreliable). The lib's value is cohesion and testability, not
# line count: four small, independently-testable classification predicates that were previously
# scattered across ~1,400 lines of `orchestrate_cycle_plan_main()`'s body are now one file with
# one job.
#
# UNLIKE territory-contention-lib.sh's extraction (one clean 287-line contiguous region), these
# four blocks were each interleaved with unrelated glue code in their original positions --
# `in_json_array()` sat between three JSON-read assignments that remain in
# orchestrate-cycle-plan.sh, and `task_has_forced_phase()` sat immediately before the "(b)
# All-terminal check" loop that calls it, which also remains there. Each extraction below removed
# ONLY the named function/array (plus its own preceding banner comment, when it had one) and left
# every surrounding line untouched in place.
#
# is_terminal_status() and in_json_array() are fully self-contained (no reference to anything
# outside their own arguments). task_has_forced_phase() references `canonical_force_phases_json`
# (a plain top-level script global, assigned before orchestrate_cycle_plan_main() is even defined
# -- never reassigned inside it) and `mt_get_json` (a plain top-level script function, defined
# before orchestrate_cycle_plan_main() too) -- both already real globals, not function-locals, so
# moving task_has_forced_phase() out needs no scoping accommodation beyond the dynamic-scoping
# property this file's header already explains.

is_terminal_status() {
  # "hold" is deliberately EXCLUDED from this set, not an oversight: a hold is a human-initiated
  # pause, not an archival-eligible terminus. Widening this to include "hold" would let /todo
  # archive a held task's directory, and would let a held dependency wrongly satisfy a
  # dependent task's completion-discharge check in section (c) below (which routes a `blocked`
  # candidate through only when every dependency's status is exactly "completed"). A held task
  # is excluded from dispatch via its own dedicated bucketing arm (the `hold)` case below), not
  # via this predicate.
  case "$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    completed|abandoned|expanded) return 0 ;;
    *) return 1 ;;
  esac
}

in_json_array() {
  # $1 = needle (int), $2 = json array
  jq -e --argjson n "$1" '. as $arr | ($arr | index($n)) != null' >/dev/null 2>&1 <<<"$2"
}

# task_has_forced_phase <t> — Decision (a): the exemption predicate that lets a terminal task
# with a pending forced phase reach eligible_tasks, without reordering section (f)'s seeding and
# consumption. Returns 0 (has a pending forced phase) when EITHER the CLI supplied
# --force-phases this invocation (canonical_force_phases_json, computed well above, before
# is_terminal_status is even defined) OR this task already carries a non-empty
# force_phases_remaining[] queue seeded on a prior cycle. Returns 1 otherwise. Only an
# explicitly forced phase may exempt a terminal task from the two guarded `continue`s below —
# ordinary (unforced) dispatch must never reach a terminal task, which is exactly why this
# predicate, not a broader terminal-status change, is the fix.
task_has_forced_phase() {
  local t="$1"
  if [ "$(echo "$canonical_force_phases_json" | jq 'length')" -gt 0 ]; then
    return 0
  fi
  local remaining
  remaining=$(mt_get_json --arg t "$t" '.force_phases_remaining[$t] // []')
  [ "$(echo "$remaining" | jq 'length')" -gt 0 ]
}

# ── Build-heavy task_type family (single array, single reader) -- this array is the membership
# list for the build-heavy co-scheduling admission rule added inside the bucketing loop below
# (the Mode 2 ruling in the isolation-removal decision record under specs/decisions/: never
# dispatch two build-heavy implement tasks in the same cycle). A future extension that needs this
# behavior adds
# its task_type to this ONE array; nothing else changes.
#
# HOISTING HISTORY (kept for context, now moot by construction): this block used to carry a
# warning that it MUST stay textually above its call site inside orchestrate_cycle_plan_main()'s
# body, because a bash function nested inside another function's body is registered only when
# execution actually reaches its `name() { ... }` statement -- defining it below its call site
# would hit "command not found" (exit 127), silently swallowed by an `if` guard under
# `set -euo pipefail`. Extracting this block into this lib, sourced at the top of
# orchestrate-cycle-plan.sh before orchestrate_cycle_plan_main() is even invoked, makes this the
# ultimate hoist -- the function and array are both defined unconditionally before main() starts,
# so no call site anywhere inside it can ever precede the definition again.
#
# Selected: phase == "implement" AND the task's own task_type is in the lean4/cslib family (the
# two REAL task_type string values that family covers -- "lean4" and "cslib" are each extensions'
# own `task_type` manifest field; "lean4" additionally appears as a cslib `keyword_overrides`
# alias for auto-detecting task_type at /task creation time, which is a DIFFERENT mechanism this
# predicate does not touch or depend on). Every other phase (research/plan) and every other
# task_type is unaffected by this array's one consumer.
BUILD_HEAVY_TASK_TYPES=("lean4" "cslib")
task_is_build_heavy_implement() {
  local phase="$1" ttype="$2" candidate
  [ "$phase" = "implement" ] || return 1
  for candidate in "${BUILD_HEAVY_TASK_TYPES[@]}"; do
    [ "$ttype" = "$candidate" ] && return 0
  done
  return 1
}
