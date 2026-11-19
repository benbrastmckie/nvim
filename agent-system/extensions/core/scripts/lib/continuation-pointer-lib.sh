#!/usr/bin/env bash
# continuation-pointer-lib.sh — Shared continuation-pointer resolution for /orchestrate.
#
# Purpose: a continuation pointer may arrive on a handoff as either the deprecated nested
# continuation_context.handoff_path (no live writer emits this today) or the flat top-level
# continuation_path (the one canonical form live H9 hard-mode wrap-up writers emit). Before this
# library, this exact jq expression was hand-copied at multiple sites -- SKILL.md's `partial`
# handler (single-task Stage 4/5) and its MT-4 `implement_tasks` loop, plus
# orchestrate-triage-classify.sh's own `continuation_ok` predicate -- with a documented history of
# one copy drifting from the others (see that script's header comment: "do not let this
# hand-applied copy drift from that script again"). This is now the SINGLE canonical
# implementation; do not hand-copy the jq expression a third time.
#
# Class C (sourced only; sets no shell options of its own -- per shell-strict-mode.md, a sourced
# library must never change the calling shell's error-handling behavior; never invoked directly
# as `bash continuation-pointer-lib.sh`).
#
# Usage (after sourcing):
#   result=$(resolve_continuation_pointer "<handoff_path>")
#
# Echoes, on stdout, one compact-JSON line:
#   {"handoff_path": "<path>", "orchestrator_mode": true}   -- a pointer was found, either form,
#                                                                normalized to this one shape
#   null                                                     -- neither form present, or the
#                                                                handoff file is missing/unparseable
#
# The nested-form read is TYPE-GUARDED (`if type == "object"`), not merely null-guarded. Some live
# writers emit `continuation_context` as a free-text STRING describing where to resume rather than
# as the deprecated object; indexing that string with `.handoff_path` is a jq ERROR, and because
# the call site swallows stderr and falls back to `null`, the error used to discard a perfectly
# valid flat `continuation_path` alongside it -- misrouting a `partial` task from `implement` to
# `needs_human`. The guard makes a non-object `continuation_context` fall through to `$flat`.
#
# Callers needing only a boolean (e.g. orchestrate-triage-classify.sh's continuation_ok) test the
# function's own output for the literal string "null":
#   result=$(resolve_continuation_pointer "$handoff_path")
#   if [ "$result" = "null" ]; then continuation_ok="false"; else continuation_ok="true"; fi

resolve_continuation_pointer() {
  local handoff_path="$1"
  if [ -z "$handoff_path" ] || [ ! -f "$handoff_path" ]; then
    echo "null"
    return 0
  fi
  jq -c '
    ((.continuation_context // null) | if type == "object" then (.handoff_path // null) else null end) as $nested |
    (.continuation_path // null) as $flat |
    ($nested // $flat) as $resolved |
    if $resolved != null then {handoff_path: $resolved, orchestrator_mode: true} else null end
  ' "$handoff_path" 2>/dev/null || echo "null"
}
