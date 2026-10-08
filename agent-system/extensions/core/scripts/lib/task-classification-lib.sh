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
#
# MEASURED CO-SCHEDULING SIGNAL (later addition to this lib, not part of the original
# extraction above): `task_is_build_heavy_implement()`'s `task_type`-family check was a static
# *verdict* -- any two implement candidates sharing a family (lean4/cslib) were categorically
# refused co-scheduling regardless of actual build weight. The family array
# (`BUILD_HEAVY_CANDIDATE_TASK_TYPES`, renamed from its original unqualified name) is now a *candidacy
# pre-filter* only; the verdict comes from `build_heavy_measure_signal()`, which reads each
# candidate's own recorded implement-dispatch `wall_clock_seconds` history
# (specs/{NNN}_{SLUG}/metrics.jsonl) and aggregates with `max` (never `mean` -- a cache that
# changes between runs makes a single low reading an unreliable proof of lightness, and
# contention risk is one-sided) gated by a minimum sample count. A candidate with no usable
# measurement history conservatively defaults to *heavy*, reproducing today's family-list
# behavior byte-for-byte. Lake job count and `lake-build-guard.sh`'s per-build
# `start_epoch`/`end_epoch` were both evaluated and declined as signals (no capture path for the
# former; single-slot, gitignored, and cross-repo-unreachable for the latter) -- see the banner
# comment directly above `build_heavy_measure_signal()` below for the full declined-alternatives
# table and the omission-not-zeroing constraint on `wall_clock_seconds`.

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

# ── Build-heavy task_type family (single array, single reader) -- DEMOTED from *verdict* to
# *candidacy pre-filter* (see "Measured co-scheduling signal" below and
# batch-orchestration-guardrails.md's "Mode 2: An Admission Rule, Not a Layer"). This array
# answers only "could this task contend over a shared build directory at all?"; the measured
# signal below answers "does it, in fact, heavily?". A future extension that needs this behavior
# adds its task_type to this ONE array; nothing else changes.
#
# WHY THE PRE-FILTER SURVIVES AT ALL: `wall_clock_seconds` (read by build_heavy_measure_signal
# below) measures whole-DISPATCH duration, not build duration -- a slow non-build dispatch (a
# "markdown" or "meta" research dispatch with zero builds) can post a large wall-clock reading
# with nothing to contend over. Consulting wall-clock alone, with no family gate, would therefore
# misclassify such a task as build-heavy, which is strictly worse than today's behavior. The
# family list is retained as the first rung precisely to prevent that.
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
# Candidacy: phase == "implement" AND the task's own task_type is in the lean4/cslib family (the
# two REAL task_type string values that family covers -- "lean4" and "cslib" are each extensions'
# own `task_type` manifest field; "lean4" additionally appears as a cslib `keyword_overrides`
# alias for auto-detecting task_type at /task creation time, which is a DIFFERENT mechanism this
# predicate does not touch or depend on). Every other phase (research/plan) and every other
# task_type is unaffected by this array's one consumer.
BUILD_HEAVY_CANDIDATE_TASK_TYPES=("lean4" "cslib")

# ── Measured co-scheduling signal ───────────────────────────────────────────────────────────
#
# THE SIGNAL: wall-clock dispatch duration (dispatch-metrics.sh's own `wall_clock_seconds`,
# already written for every `phase: "implement"` dispatch to the task's own
# specs/{NNN}_{SLUG}/metrics.jsonl, append-only, never gitignored -- no new instrumentation).
# THE LIMITATION, STATED PLAINLY: this measures a *contention window* -- the probability that two
# candidates' build activity overlaps in time -- not build CPU or job count. It is a proxy for
# build weight, not a measurement of it. Three better-looking alternatives were each declined
# with evidence rather than left unexamined:
#   - Lake job count: no capture path exists anywhere; lake-build-guard.sh already declined
#     parsing it (couples the guard to Lake's output format it deliberately passes through
#     untouched), and Lake 5.0.0 exposes no -j/--jobs flag.
#   - lake-build-guard.sh's build-guard.result start_epoch/end_epoch: a genuine per-build
#     duration, but single-slot (overwritten every build, no history), under the built project's
#     gitignored .lake/, and for lean4 tasks inside a sibling repository unreachable from this
#     repo's admission path.
#   - file_scope -> Mathlib-manifest probe: file_scope is documented as descriptive and not
#     filesystem-validated; no lean4/cslib task directory exists in this repository to verify the
#     resolution against.
#
# THE AGGREGATOR IS max, NOT mean: contention risk is one-sided. A task that has ever built
# heavily can build heavily again (a toolchain bump or dependency change invalidates a populated
# .lake/ at any time); a task that has only ever built lightly may simply not have hit its heavy
# path yet. Averaging lets one light dispatch dilute a heavy one and flip a genuinely heavy task
# to light -- the wrong direction for a fail-safe gate. A *light* verdict additionally requires at
# least BUILD_HEAVY_MIN_SAMPLES usable measurements, because a cache that changes between runs
# (the oelean cache / .lake/ state, directly analogous to the well-known ccache caveat that
# motivates this floor) makes a single low reading an unreliable proof of lightness.
#
# THE NO-HISTORY FALLBACK IS CONSERVATIVE DEFAULT-TO-HEAVY: preserves today's behavior
# byte-for-byte for every unmeasured candidate -- this change is strictly a relaxation applied
# only where evidence exists, never new co-scheduling exposure. Five distinct
# no-usable-measurement conditions all collapse to *heavy*: no task directory resolved; no
# metrics.jsonl; no `phase: "implement"` entries; every implement entry missing
# wall_clock_seconds; fewer than BUILD_HEAVY_MIN_SAMPLES usable entries.
#
# OMISSION-NOT-ZEROING (load-bearing): the metrics format OMITS wall_clock_seconds when
# unavailable rather than writing 0 -- an absent key MUST NOT be read as 0, which would otherwise
# read as maximally light. build_heavy_measure_signal below filters on `has("wall_clock_seconds")`
# before ever touching the value.
#
# Both constants are env-overridable, which doubles as the primary rollback contingency: setting
# BUILD_HEAVY_MIN_SAMPLES very large in the environment falls every candidate back to the
# conservative fallback with no code change.
BUILD_HEAVY_WALL_CLOCK_THRESHOLD_SECONDS="${BUILD_HEAVY_WALL_CLOCK_THRESHOLD_SECONDS:-900}"
BUILD_HEAVY_MIN_SAMPLES="${BUILD_HEAVY_MIN_SAMPLES:-2}"

# build_heavy_measure_signal <task_dir_abs> -- reads this task's own metrics.jsonl and emits
# exactly one line on stdout: "heavy|<basis prose>" or "light|<basis prose>". ALWAYS exits 0 --
# every failure path (missing file, no implement entries, all entries missing the key, below the
# sample floor) is itself a *heavy* verdict with its own basis prose, never a non-zero exit.
# Count and max are computed in ONE jq call, malformed-line-tolerant (`fromjson? // empty` skips
# any line that fails to parse as JSON rather than aborting) and float-safe (the comparison below
# uses awk, never a bash integer test, because wall_clock_seconds may be a float like 4123.7).
build_heavy_measure_signal() {
  local task_dir_abs="$1" metrics_file counts count max_val
  metrics_file="${task_dir_abs}/metrics.jsonl"
  if [ -z "$task_dir_abs" ] || [ ! -f "$metrics_file" ]; then
    BUILD_HEAVY_SIGNAL_BASIS="no metrics history (no task directory or metrics.jsonl); conservative default-to-heavy"
    echo "heavy|$BUILD_HEAVY_SIGNAL_BASIS"
    return 0
  fi
  counts=$(jq -R -r -s '
    split("\n")
    | map(fromjson? // empty)
    | map(select(.phase == "implement") | select(has("wall_clock_seconds")) | .wall_clock_seconds)
    | "\(length) \(max // 0)"
  ' <"$metrics_file" 2>/dev/null) || counts=""
  count=$(awk '{print $1}' <<<"$counts")
  max_val=$(awk '{print $2}' <<<"$counts")
  if [ -z "$count" ] || [ "$count" = "0" ]; then
    BUILD_HEAVY_SIGNAL_BASIS="no usable implement-phase wall_clock_seconds entries; conservative default-to-heavy"
    echo "heavy|$BUILD_HEAVY_SIGNAL_BASIS"
    return 0
  fi
  if awk -v c="$count" -v floor="$BUILD_HEAVY_MIN_SAMPLES" 'BEGIN { exit !(c < floor) }'; then
    BUILD_HEAVY_SIGNAL_BASIS="only ${count} usable implement-phase measurement(s), below the ${BUILD_HEAVY_MIN_SAMPLES}-sample floor; conservative default-to-heavy"
    echo "heavy|$BUILD_HEAVY_SIGNAL_BASIS"
    return 0
  fi
  if awk -v m="$max_val" -v t="$BUILD_HEAVY_WALL_CLOCK_THRESHOLD_SECONDS" 'BEGIN { exit !(m >= t) }'; then
    BUILD_HEAVY_SIGNAL_BASIS="measured max ${max_val}s over ${count} implement dispatches >= ${BUILD_HEAVY_WALL_CLOCK_THRESHOLD_SECONDS}s threshold"
    echo "heavy|$BUILD_HEAVY_SIGNAL_BASIS"
    return 0
  fi
  BUILD_HEAVY_SIGNAL_BASIS="measured max ${max_val}s over ${count} implement dispatches < ${BUILD_HEAVY_WALL_CLOCK_THRESHOLD_SECONDS}s threshold"
  echo "light|$BUILD_HEAVY_SIGNAL_BASIS"
  return 0
}

# task_is_build_heavy_implement <phase> <ttype> [task_dir_abs] -- three-rung ladder: (1) phase
# must be "implement"; (2) ttype must be in the candidacy pre-filter array; (3) delegate to the
# measured signal. An empty or omitted third argument (the original two-argument call shape)
# skips rung 3 entirely and returns 0 (heavy) -- the backward-compatible, conservative path:
# every pre-existing call site that cannot supply a task directory keeps today's exact verdict.
# BUILD_HEAVY_SIGNAL_BASIS is set as a global on every rung-3 evaluation (following
# lake-build-guard.sh's _RECORD_FINALIZED precedent of a global over a return channel), so the
# caller can name the decision's basis in its own deferred[] reason without restructuring this
# predicate's return-code interface.
task_is_build_heavy_implement() {
  local phase="$1" ttype="$2" task_dir_abs="${3:-}" candidate is_candidate=1 signal
  [ "$phase" = "implement" ] || return 1
  for candidate in "${BUILD_HEAVY_CANDIDATE_TASK_TYPES[@]}"; do
    [ "$ttype" = "$candidate" ] && is_candidate=0 && break
  done
  [ "$is_candidate" -eq 0 ] || return 1
  if [ -z "$task_dir_abs" ]; then
    BUILD_HEAVY_SIGNAL_BASIS="no task directory supplied to the predicate; conservative default-to-heavy"
    return 0
  fi
  signal=$(build_heavy_measure_signal "$task_dir_abs")
  BUILD_HEAVY_SIGNAL_BASIS="${signal#*|}"
  [ "${signal%%|*}" = "heavy" ] && return 0
  return 1
}
