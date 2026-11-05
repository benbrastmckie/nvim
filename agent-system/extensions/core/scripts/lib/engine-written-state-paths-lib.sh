#!/usr/bin/env bash
# engine-written-state-paths-lib.sh - Single home of the engine-written-state path set that
# every file_scope Containment site must admit regardless of the declared task's own
# file_scope. Modelled structurally on scripts/lib/derived-artifact-probe-lib.sh's header style:
# a contract statement, the fail-open posture, and an explicit enumeration of its consumers.
# Sourced, never executed; sets no shell options a caller inherits; exports nothing a caller
# must guess at.
#
# Contract: the Containment predicate -- one concrete path tested against one task's own
# declared file_scope -- is checked at three independent sites. Each site must additionally
# admit a small, fixed set of paths the AGENT SYSTEM ITSELF writes on behalf of every (or many)
# tasks, never on behalf of one task's declared territory, so those paths are never dropped as
# a false "scope excursion". This file is the ONE place that set is defined; a site widens its
# own scope by sourcing this file and calling engine_written_state_paths, never by hand-copying
# the literal list again.
#
# Admission bar (apply verbatim before adding a fifth member): a candidate must be BOTH (a)
# engine-written on behalf of every/many tasks, not authored by one task's own agent dispatch,
# AND (b) never legitimately declarable in any one task's own file_scope. A path that fails
# either half does not belong here -- widening this list weakens every Containment site's
# excursion guard at once.
#
# Rejected candidates and why each fails the bar:
#   - specs/CHANGE_LOG.md   - written only at archival (skill-todo), not on behalf of every
#                             task's ordinary lifecycle; narrower writer population than the bar
#                             requires.
#   - specs/ROADMAP.md      - user-maintained and read-only for agents; no agent ever writes it,
#                             engine or otherwise, so admitting it here would be a no-op scope
#                             widening with no corresponding writer to protect.
#   - specs/README.md       - static; not written by the engine on behalf of any task.
#   - any task-owned specs/{NNN}_*/ path - this is exactly the territory file_scope already
#                             exists to describe; a task's own directory belongs in that task's
#                             own declared file_scope, not in a universal allowlist that bypasses
#                             the declaration mechanism entirely.
#
# Fail-open posture, mirrored at every consumer (not inside this file): a failed `source` of
# this file, or a call to engine_written_state_paths that yields an empty/unparseable result,
# must never narrow a site's admitted scope below what it admits today. Every consumer falls
# back to the hardcoded two-literal pair ("specs/TODO.md" "specs/state.json") in that case, so a
# library-resolution failure reproduces today's behavior exactly rather than silently emptying
# the splice. This file does not implement the fallback itself -- each consumer site does, right
# at its own call site, because a sourcing failure means code in THIS file cannot run at all.
#
# One exported function:
#
#   engine_written_state_paths - prints the compact JSON array
#     ["specs/TODO.md","specs/state.json","specs/events.jsonl","specs/errors.json"]
#     on stdout, rc 0. Built with `printf` from a literal, NOT via `jq` -- this set is a fixed
#     constant of the core engine (no .claude-extensions.json lookup, unlike the derived-output
#     probes in derived-artifact-probe-lib.sh), so the function must not acquire a `jq`
#     dependency it does not need and must still succeed on a host without `jq` installed.
#
# Consumers (each MUST source this file and call engine_written_state_paths, never
# re-hand-copy the literal list):
#   - scripts/git-commit-scoped.sh (V10's containment_scope_arr splice)
#   - scripts/orchestrate-cycle-postflight.sh (WORK (h)'s effective_file_scope_json splice)
#   - scripts/git-commit-phase.sh (the Phase-Commit Containment Self-Check's file_scope_arr
#     splice)

# engine_written_state_paths
# Prints the compact JSON array of the four engine-written-state paths on stdout. Built from a
# literal via printf, not jq, so this function has no external-tool dependency and always
# succeeds. Always returns 0.
engine_written_state_paths() {
  printf '%s' '["specs/TODO.md","specs/state.json","specs/events.jsonl","specs/errors.json"]'
  return 0
}
