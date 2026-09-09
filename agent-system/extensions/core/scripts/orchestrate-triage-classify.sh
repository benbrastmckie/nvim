#!/usr/bin/env bash
# orchestrate-triage-classify.sh — Shared handoff-triage classifier for /orchestrate.
#
# Purpose: single-task Stage 4 (`skills/skill-orchestrate/SKILL.md`) and multi-task Stage MT-4
# each decide, independently, what a task's current `status` routes to next (research, plan,
# implement, a human-escalation, a skip, or a terminal no-op). Before this script, that rule
# existed as two separately-maintained descriptions — the Stage 4 `partial` handler's prose and
# Stage MT-4's phase-grouping table — which genuinely disagree on one row (see below). This
# script is the "one code path" both the live dispatch and the read-only `--dry-run` mode of
# `orchestrate-cycle-plan.sh` call, so the rule cannot drift into two silently-diverging
# copies again.
#
# Two-engine rationale: `/orchestrate` selects between the single-task engine and the multi-task
# (Stage MT-4) engine purely by `len(TASK_NUMBERS)` — see `commands/orchestrate.md` STAGE 0
# (`== 1` falls through to single-task CHECKPOINT 1; `> 1` goes to the multi-task dispatch block).
# A
# dry-run's entire value is being a *prediction of what the live path will actually do*, so the
# classifier must branch on that SAME `len(task_numbers)` test — never assume one engine's
# semantics for the other's invocation shape. The engine tables below are unified on every row
# except `blocked` (see the justification adjacent to that row): both engines now route `partial`
# with neither a continuation nor blockers to `implement`, and the engine argument still exists
# only because the two engines are selected by that same `len(task_numbers)` test the live path
# uses — not because the two engines' verdicts still diverge on this row.
#
# Usage:
#   orchestrate-triage-classify.sh [--effort <fast|hard>] <engine> <task_number> [<task_number> ...]
#
# where <engine> is exactly "single" or "mt". `--effort` (and `--effort=<value>`) is parsed
# strictly BEFORE the positional <engine> so it can never be confused with a task number.
# Omitted means "no effort flag" — the research-first default applies. `--effort fast` changes
# ONLY the `not_started` routing (the live row below and the blocked-discharge
# `previous_status == "not_started"` arm) to `plan`, preserving the pre-research-first behavior
# as `--fast`'s escape hatch; `--effort hard` does NOT alter routing — only the literal value
# `"fast"` does. Any other `--effort` value exits 2 with a loud stderr line, matching the
# unknown-engine precedent below.
#
# Forbidden calls (this script is read-only; it must never be the mechanism by which a dry-run or
# a classification-only caller mutates anything):
#   - task-lock.sh acquire (or heartbeat/release) — this script does not touch task locks at all
#   - update-task-status.sh
#   - generate-todo.sh
#   - skill-base.sh write functions (skill_preflight_update, skill_postflight_update, etc.)
#   - reconcile-task-status.sh (without --dry-run)
#   - the Agent or Skill tool, or anything that dispatches one
# This script reads ONLY specs/state.json and, for `partial`-status candidates, that candidate's
# own specs/{NNN}_{SLUG}/.orchestrator-handoff.json — never a plan, report, or summary file
# (Context Flatness Constraint).
#
# Precedence for `partial` status (transcribed from the single-task Stage 4 handler's explicit
# reads, which both engines share):
#   1. a continuation pointer is present, in EITHER accepted form -- nested
#      continuation_context.handoff_path non-null, OR flat top-level continuation_path non-null
#      (dual-form acceptance, matching validate-handoff.sh's already-shipped precedent; see the
#      "One Write Form, Deprecated-But-Accepted Read Form" subsection of docs/architecture/handoff-schema.md)              -> `implement`
#   2. else blockers is non-empty                                  -> `needs_human`
#   3. else (neither)                                               -> `implement` (both engines)
#
# Engine tables (verbatim transcription; this table, Stage 4's single-task state handlers,
# Stage MT-4's "Phase grouping" table in skills/skill-orchestrate/SKILL.md, AND the degraded
# fallback classifier table inside orchestrate-cycle-plan.sh (used only when THIS script exits
# non-zero) MUST be changed together, never independently — this script is the executable source
# of truth those sections point back to. Four sites, not three: the degraded fallback is easy to
# forget precisely because it is normally dormant. The `not_started` row is now EFFORT-
# CONDITIONAL (research-first by default, plan-first under `--effort fast`); the degraded
# fallback in orchestrate-cycle-plan.sh must encode the identical effort branch, not just the
# same unconditional group, or the two sites silently diverge exactly on the row this rewrite
# touches.):
#
#   | status                                  | mt group    | single group  |
#   |------------------------------------------|-------------|---------------|
#   | not_started, no --effort or --effort hard | research    | research      |
#   | not_started, --effort fast                | plan        | plan          |
#   | researched                                 | plan        | plan          |
#   | planned, implementing                      | implement   | implement     |
#   | partial + continuation                     | implement   | implement     |
#   | partial + blockers, no continuation         | needs_human | needs_human   |
#   | partial, neither                            | implement   | implement     |
#   | blocked, discharged (all dependencies[] completed, no handoff blockers)   | previous_status-routed | previous_status-routed |
#   | blocked, dependency outstanding or empty dependencies[]                    | skip        | needs_human   |
#   | blocked, dependency abandoned/expanded (non-completed terminal)            | needs_human | needs_human   |
#   | blocked, handoff blockers present (discharge otherwise satisfied)          | needs_human | needs_human   |
#   | blocked, previous_status missing or unrecognized (discharge otherwise satisfied) | needs_human | needs_human |
#   | researching (NEW -- was skip, folded into the old "researching, planning, unknown" row) | research | research |
#   | planning (NEW -- was skip, folded into the old "researching, planning, unknown" row)    | plan     | plan     |
#   | unknown (unrecognized/garbage status)       | skip        | skip          |
#   | terminal (completed/abandoned/expanded)      | terminal    | terminal      |
#
# `researching`/`planning` no longer route to `skip`: eligibility is no longer status-gated (a
# task is admitted/deferred by locks, dependencies[], and file_scope overlap downstream, never by
# an in-flight status string), so a task stranded in `researching`/`planning` by a dead prior
# session's stale lock must actually classify to a real dispatch group, not fall into the same
# bucket as a genuinely unrecognized status string. `unknown` (any status string that is none of
# the above) keeps the old `skip` behavior unchanged — this row split is scoping-only, not a
# widening of what "unknown" means.
#
# `blocked` is NARROWED, not unconditional: a `blocked` candidate is DISCHARGED — its ordering
# constraint has actually resolved — when ALL of the following hold, resolved against the
# already-slurped `$all` array (a second `select(.project_number == ...)` against data already in
# memory, never against the classifier's own `$candidates`/CLI argument list: a dependency that
# has JUST completed is no longer among this cycle's eligible-task candidates, so checking
# candidate-list membership would reproduce the very infinite-skip defect this discrimination
# fixes):
#   1. `dependencies[]` is non-empty (empty is never evidence of resolution — a vacuous `all` over
#      an empty list must not silently discharge).
#   2. every listed dependency's own `status` in state.json is exactly `"completed"` (never the
#      broader terminal set — a dependency stuck at `abandoned`/`expanded` must never silently
#      promote a dependent whose precondition can never be met; that case is its own loud
#      `needs_human` branch instead).
#   3. the candidate's own handoff `blockers[]` (read under the SAME widened per-candidate read
#      this file already performs for `partial`, now extended to `blocked`) is empty or the
#      handoff is absent.
# When discharged, BOTH engines converge: route the candidate's `previous_status` through the
# SAME not_started/researched/planned-or-implementing/researching/planning logic already applied
# to a live `status` above, using `previous_status` as the input instead. A discharged candidate
# with no recorded `previous_status` never guesses — it stays `needs_human` with a reason naming
# the gap.
#
# For the NON-discharged case (dependencies[] empty, a dependency still outstanding, a dependency
# stuck non-completed-terminal, or handoff blockers present), the row STAYS the one that still
# diverges, and this remains intentional: this is a DESIGN, not an undocumented assertion, because
# both engines independently corroborate it in their own handlers rather than only in this shared
# table — Stage 4's `#### State: blocked` handler contains no engine conditional at all (it always
# escalates to a human), and Stage MT-4's table independently folds the non-discharged `blocked`
# case into its generic `skip` group. Two handlers, written separately, already agree with the
# classifier. Semantically: a solo invocation has no sibling task to make progress on, so
# escalation is the only meaningful action for a block that has NOT resolved; a batch invocation
# skips the still-blocked task so its siblings can proceed. Converging `single` to `skip` here
# would introduce a new defect (a solo `/orchestrate` on a genuinely blocked task would do nothing
# at all), not fix one. For the DISCHARGED case, by contrast, both engines converge on the SAME
# `previous_status`-routed group: a solo invocation escalating a factually-resolved block to a
# human is not a deliberate design, it is exactly the "bare assertion by one shared table" failure
# mode named below, so `single` discriminates too rather than keeping its conservative default.
# This narrows, but does not overturn, the archived `orchestrate_eligibility_not_status_gated`
# report's Decision 3 ("blocked and unknown rows: leave unchanged") — `unknown` stays untouched;
# `blocked` stays unconditional only for the non-discharged case. This is unlike the now-removed
# `partial`-with-neither divergence, which was asserted only by this script and one prose
# paragraph citing an untraceable historical decision — nothing else in the system independently
# implemented it. The discriminator for any future audit of a table row: does the OTHER engine's
# own handler implement the divergence in its own code, or does only this shared table assert it?
# Independent implementation by both sides = design (keep it, documented, as here for the
# non-discharged case); bare assertion by one shared table = defect (converge it, as was done for
# `partial`, and as is now done for `blocked`'s discharged case).
#
# Output: NDJSON on stdout, one compact JSON object per candidate, in input order (duplicates
# preserved verbatim if given). Verdict schema (pinned as "orchestrate-triage-v1"; field order is
# stable):
#
#   $schema           string  Literal "orchestrate-triage-v1".
#   task_number        int    The candidate task number, echoed back.
#   engine             string "single" or "mt", echoed back from the invocation argument.
#   status              string|null  The candidate's raw state.json status, or null if unknown.
#   group               string  One of: research, plan, implement, needs_human, skip, terminal, and
#                                 exit_partial (RESERVED — defined but not currently emitted by any
#                                 row as of this schema version; retained for schema stability and
#                                 available to a future row or engine that wants a distinct
#                                 exit-without-dispatch verdict; see orchestrate-cycle-plan.sh's
#                                 defensive exclusion arm, which still treats it as an exclusion if
#                                 it is ever emitted).
#   handoff_state       string  "absent" (partial or blocked status, no readable handoff file),
#                                 "continuation" (a continuation pointer present in either accepted
#                                 form: nested continuation_context.handoff_path or flat
#                                 continuation_path; partial status only — blocked candidates never
#                                 carry a continuation pointer), "blockers" (blockers present, no
#                                 continuation), "empty" (handoff present, neither continuation nor
#                                 blockers), or "not_applicable" (status is neither partial nor
#                                 blocked — no handoff was read).
#   blocker_count       int    Length of the handoff's blockers array (0 when status is neither
#                                 partial nor blocked, or no handoff file exists).
#   handoff_age_min     int|null  Handoff file mtime age in minutes; null when no handoff was read.
#   reason              string  Machine-templated human-readable summary; never the sole carrier
#                                 of a fact already present as a structured field above.
#
# Exit codes:
#   0 - verdicts were emitted on stdout, regardless of group (verdicts are data, not errors —
#       mirrors orchestrate-batch-admit.sh's convention).
#   2 - usage error (unknown engine, zero task numbers, or a non-integer task number), or state
#       unavailable (jq missing, or STATE_FILE missing/unparseable). Nothing is printed on
#       stdout in either case; a single loud line naming the reason goes to stderr.
#
# Output-channel discipline — AUDITED CLEAN, no change needed (audited alongside the fd-3
# structural fix in orchestrate-cycle-plan.sh/orchestrate-cycle-postflight.sh): this script
# already emits exactly once at the end (`printf '%s\n' "$verdicts"`), and every diagnostic
# above that point is already `>&2`. There is no per-call-site stopgap to remove and no
# entry-point redirect needed here. Do not re-open this question without new evidence.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/continuation-pointer-lib.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
STATE_FILE="$PROJECT_ROOT/specs/state.json"

effort=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --effort)
      effort="${2:-}"
      shift 2 || true
      ;;
    --effort=*)
      effort="${1#--effort=}"
      shift || true
      ;;
    *)
      break
      ;;
  esac
done

if [ -n "$effort" ] && [ "$effort" != "fast" ] && [ "$effort" != "hard" ]; then
  echo "ERROR: orchestrate-triage-classify.sh: --effort must be 'fast' or 'hard' (got '$effort')." >&2
  exit 2
fi

engine="${1:-}"
shift || true

if [ "$engine" != "single" ] && [ "$engine" != "mt" ]; then
  echo "ERROR: orchestrate-triage-classify.sh: <engine> must be 'single' or 'mt' (got '${engine:-<empty>}')." >&2
  exit 2
fi

if [ "$#" -eq 0 ]; then
  echo "ERROR: orchestrate-triage-classify.sh requires at least one <task_number> argument." >&2
  exit 2
fi

for arg in "$@"; do
  case "$arg" in
    ''|*[!0-9]*)
      echo "ERROR: orchestrate-triage-classify.sh: '$arg' is not a non-negative integer task_number." >&2
      exit 2
      ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: orchestrate-triage-classify.sh: jq is not available; cannot evaluate triage." >&2
  exit 2
fi

if [ ! -f "$STATE_FILE" ]; then
  echo "ERROR: orchestrate-triage-classify.sh: state file not found at $STATE_FILE." >&2
  exit 2
fi

now_epoch() { date -u +%s; }

# Build the candidates JSON array (preserves input order, including duplicates if given).
candidates_json="[$(printf '%s\n' "$@" | paste -sd, -)]"

# Single read of STATE_FILE to resolve each candidate's status/project_name — needed up front so
# we know, per candidate, whether (and where) to read a handoff file below.
if lookup_json=$(jq -n -c --argjson candidates "$candidates_json" --slurpfile state_arr "$STATE_FILE" '
  ($state_arr[0].active_projects // []) as $all |
  [ $candidates[] as $c |
    ([$all[] | select(.project_number == $c)] | first) as $entry |
    { task_number: $c, status: ($entry.status // null), project_name: ($entry.project_name // null) }
  ]
' 2>&1); then
  lookup_exit=0
else
  lookup_exit=$?
fi
if [ "$lookup_exit" -ne 0 ]; then
  echo "ERROR: orchestrate-triage-classify.sh: failed to evaluate state lookup against $STATE_FILE (jq exit $lookup_exit): $lookup_json" >&2
  exit 2
fi

# Per-partial-or-blocked-candidate handoff read (Context Flatness Constraint: only for
# status == "partial" or status == "blocked", and only .orchestrator-handoff.json — never a plan,
# report, or summary). Widened from "partial"-only so the discriminating `blocked` arm below can
# read the SAME `blocker_count`/`continuation_ok`/`age_min` extraction for a `blocked` candidate's
# discharge-blockers check (discriminator 3), reusing this loop verbatim rather than duplicating
# it.
handoff_info_json="{}"
lookup_count=$(echo "$lookup_json" | jq 'length')
idx=0
while [ "$idx" -lt "$lookup_count" ]; do
  row=$(echo "$lookup_json" | jq -c ".[$idx]")
  idx=$((idx + 1))

  row_status=$(echo "$row" | jq -r '.status // ""')
  [ "$row_status" = "partial" ] || [ "$row_status" = "blocked" ] || continue

  row_task=$(echo "$row" | jq -r '.task_number')
  row_project=$(echo "$row" | jq -r '.project_name // ""')

  if [ -z "$row_project" ]; then
    handoff_info_json=$(echo "$handoff_info_json" | jq --argjson t "$row_task" \
      '. + {($t|tostring): {state: "absent", blocker_count: 0, continuation: false, age_min: null}}')
    continue
  fi

  padded=$(printf "%03d" "$row_task")
  handoff_path="$PROJECT_ROOT/specs/${padded}_${row_project}/.orchestrator-handoff.json"

  if [ ! -f "$handoff_path" ]; then
    handoff_info_json=$(echo "$handoff_info_json" | jq --argjson t "$row_task" \
      '. + {($t|tostring): {state: "absent", blocker_count: 0, continuation: false, age_min: null}}')
    continue
  fi

  blocker_count=$(jq -r '(.blockers // []) | length' "$handoff_path" 2>/dev/null) || true
  case "$blocker_count" in ''|*[!0-9]*) blocker_count=0 ;; esac

  # Dual-form acceptance (Option B): a continuation pointer is present when EITHER the nested
  # `continuation_context.handoff_path` is non-null OR the flat top-level `continuation_path` is
  # non-null. This codifies the precedent validate-handoff.sh already ships (it accepts
  # continuation_path OR continuation_context as two equally valid forms) rather than inventing a
  # new contract. The nested form now has NO writer -- it is retained on the read side only for
  # backward compatibility with handoffs written before the nested-form writer was deleted; the
  # flat continuation_path form is the one canonical, writable form every live writer emits. Do
  # not re-narrow this to one form without updating every reader in lockstep (see
  # docs/architecture/handoff-schema.md's "One Write Form, Deprecated-But-Accepted Read Form" subsection).
  # Shared helper (scripts/lib/continuation-pointer-lib.sh) -- the SAME resolution
  # orchestrate-build-dispatch.sh's implement-phase gatherer also calls, collapsing what were
  # two independently hand-copied implementations into one. This predicate only needs the
  # boolean: non-"null" means a pointer was found in either accepted form.
  continuation_resolved=$(resolve_continuation_pointer "$handoff_path")
  if [ "$continuation_resolved" = "null" ]; then
    continuation_ok="false"
  else
    continuation_ok="true"
  fi

  mtime=$(stat -c %Y "$handoff_path" 2>/dev/null || stat -f %m "$handoff_path" 2>/dev/null || echo "")
  if [ -n "$mtime" ]; then
    age_min=$(( ($(now_epoch) - mtime) / 60 ))
  else
    age_min="null"
  fi

  handoff_info_json=$(echo "$handoff_info_json" | jq \
    --argjson t "$row_task" --argjson bc "$blocker_count" --argjson cont "$continuation_ok" --argjson age "$age_min" \
    '. + {($t|tostring): {state: "present", blocker_count: $bc, continuation: $cont, age_min: $age}}')
done

if verdicts=$(jq -n -c \
  --arg engine "$engine" \
  --arg effort "$effort" \
  --argjson candidates "$candidates_json" \
  --argjson handoff_info "$handoff_info_json" \
  --slurpfile state_arr "$STATE_FILE" \
  '
  def is_terminal: ascii_downcase as $s | ($s == "completed" or $s == "abandoned" or $s == "expanded");

  ($state_arr[0].active_projects // []) as $all |
  $candidates[] as $c |
  ([$all[] | select(.project_number == $c)] | first) as $entry |
  ($handoff_info[($c|tostring)] // null) as $hinfo |

  if ($entry == null) then
    {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:null, group:"skip",
     handoff_state:"not_applicable", blocker_count:0, handoff_age_min:null,
     reason:("task #" + ($c|tostring) + " not found in state.json; treated as skip")}
  else
  ($entry.status // "") as $status |
  if ($status|is_terminal) then
    {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"terminal",
     handoff_state:"not_applicable", blocker_count:0, handoff_age_min:null,
     reason:("task #" + ($c|tostring) + " is terminal (" + $status + ")")}
  elif $status == "not_started" then
    (if $effort == "fast" then "plan" else "research" end) as $grp |
    {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:$grp,
     handoff_state:"not_applicable", blocker_count:0, handoff_age_min:null,
     reason:(if $effort == "fast" then
       ("task #" + ($c|tostring) + " is not_started; --effort fast routes to plan (research-first default skipped -- the planner can still request research via needs_research if the description does not suffice)")
     else
       ("task #" + ($c|tostring) + " is not_started; routes to research (research-first default -- pass --fast to route straight to plan instead)")
     end)}
  elif $status == "researched" then
    {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"plan",
     handoff_state:"not_applicable", blocker_count:0, handoff_age_min:null,
     reason:("task #" + ($c|tostring) + " is researched; routes to plan")}
  elif ($status == "planned" or $status == "implementing") then
    {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"implement",
     handoff_state:"not_applicable", blocker_count:0, handoff_age_min:null,
     reason:("task #" + ($c|tostring) + " is " + $status + "; routes to implement")}
  elif $status == "researching" then
    {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"research",
     handoff_state:"not_applicable", blocker_count:0, handoff_age_min:null,
     reason:("task #" + ($c|tostring) + " is researching (in-flight, possibly stranded by a dead prior session); routes to research")}
  elif $status == "planning" then
    {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"plan",
     handoff_state:"not_applicable", blocker_count:0, handoff_age_min:null,
     reason:("task #" + ($c|tostring) + " is planning (in-flight, possibly stranded by a dead prior session); routes to plan")}
  elif $status == "partial" then
    (($hinfo.state // "absent")) as $hstate |
    (($hinfo.blocker_count // 0)) as $bc |
    (($hinfo.continuation // false)) as $cont |
    (($hinfo.age_min // null)) as $age |
    if $cont then
      {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"implement",
       handoff_state:"continuation", blocker_count:$bc, handoff_age_min:$age,
       reason:("task #" + ($c|tostring) + " is partial with a valid continuation pointer; routes to implement")}
    elif ($bc > 0) then
      {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"needs_human",
       handoff_state:"blockers", blocker_count:$bc, handoff_age_min:$age,
       reason:("task #" + ($c|tostring) + " is partial with " + ($bc|tostring) + " unresolved blocker(s) and no continuation; needs human")}
    else
      {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"implement",
       handoff_state:(if $hstate == "absent" then "absent" else "empty" end), blocker_count:$bc, handoff_age_min:$age,
       reason:("task #" + ($c|tostring) + " is partial with neither continuation nor blockers; routes to implement")}
    end
  elif $status == "blocked" then
    ($entry.dependencies // []) as $deps |
    ($entry.previous_status // null) as $prev |
    (($hinfo.state // "absent")) as $hstate |
    (($hinfo.blocker_count // 0)) as $bc |
    (($hinfo.age_min // null)) as $age |
    (if $hstate == "absent" then "absent" elif $bc > 0 then "blockers" else "empty" end) as $hstate_out |
    # Mechanism constraint (do not substitute candidate-list membership for this lookup): each
    # dependency status is resolved from the already-slurped $all array, NOT from $candidates --
    # a dependency that has JUST completed is no longer among this cycle eligible-task candidates
    # in the live path, so checking membership here would reproduce the very infinite-skip defect
    # this discrimination fixes.
    ($deps | map(. as $d | {dep: $d, dep_status: (([$all[] | select(.project_number == $d)] | first).status // null)})) as $dep_rows |
    ($dep_rows | map(select(.dep_status == "abandoned" or .dep_status == "expanded"))) as $dep_terminal_bad |
    ($dep_rows | map(select(.dep_status != "completed"))) as $dep_outstanding |
    if ($deps | length) == 0 then
      ((if $engine == "mt" then "skip" else "needs_human" end)) as $grp |
      {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:$grp,
       handoff_state:$hstate_out, blocker_count:$bc, handoff_age_min:$age,
       reason:("task #" + ($c|tostring) + " is blocked with no tracked dependencies; likely externally or manually blocked (" + (if $engine == "mt" then "mt skips" else "single needs human" end) + ")")}
    elif ($dep_terminal_bad | length) > 0 then
      ($dep_terminal_bad | map((.dep|tostring) + " (" + .dep_status + ")") | join(", ")) as $bad_list |
      {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"needs_human",
       handoff_state:$hstate_out, blocker_count:$bc, handoff_age_min:$age,
       reason:("task #" + ($c|tostring) + " is blocked on dependency(ies) " + $bad_list + " which reached a non-completed terminal status; this precondition can never be met, needs human")}
    elif ($dep_outstanding | length) > 0 then
      ($dep_outstanding | map((.dep|tostring) + " (" + (.dep_status // "unknown") + ")") | join(", ")) as $outstanding_list |
      ((if $engine == "mt" then "skip" else "needs_human" end)) as $grp |
      {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:$grp,
       handoff_state:$hstate_out, blocker_count:$bc, handoff_age_min:$age,
       reason:("task #" + ($c|tostring) + " is blocked on outstanding dependency(ies) " + $outstanding_list + " (" + (if $engine == "mt" then "mt skips" else "single needs human" end) + ")")}
    elif ($bc > 0) then
      {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"needs_human",
       handoff_state:$hstate_out, blocker_count:$bc, handoff_age_min:$age,
       reason:("task #" + ($c|tostring) + " has all dependencies completed but its handoff carries " + ($bc|tostring) + " unresolved blocker(s); needs human")}
    elif ($prev == null) then
      {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"needs_human",
       handoff_state:$hstate_out, blocker_count:$bc, handoff_age_min:$age,
       reason:("task #" + ($c|tostring) + " is blocked with satisfied dependencies but no previous_status; cannot determine discharge phase, needs human")}
    else
      ($prev) as $p |
      (if $p == "not_started" then (if $effort == "fast" then "plan" else "research" end)
       elif $p == "researched" then "plan"
       elif ($p == "planned" or $p == "implementing") then "implement"
       elif $p == "researching" then "research"
       elif $p == "planning" then "plan"
       else null end) as $routed_group |
      if $routed_group == null then
        {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"needs_human",
         handoff_state:$hstate_out, blocker_count:$bc, handoff_age_min:$age,
         reason:("task #" + ($c|tostring) + " is discharged (dependencies completed, no handoff blockers) but previous_status \"" + $p + "\" is unrecognized; needs human")}
      else
        {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:$routed_group,
         handoff_state:$hstate_out, blocker_count:$bc, handoff_age_min:$age,
         reason:("task #" + ($c|tostring) + " is blocked but discharged (all dependencies completed, no handoff blockers); routes via previous_status \"" + $p + "\" to " + $routed_group)}
      end
    end
  else
    {"$schema":"orchestrate-triage-v1", task_number:$c, engine:$engine, status:$status, group:"skip",
     handoff_state:"not_applicable", blocker_count:0, handoff_age_min:null,
     reason:("task #" + ($c|tostring) + " status \"" + $status + "\" is transitional/unknown; skip")}
  end
  end
  ' 2>&1); then
  verdicts_exit=0
else
  verdicts_exit=$?
fi

if [ "$verdicts_exit" -ne 0 ]; then
  echo "ERROR: orchestrate-triage-classify.sh: failed to evaluate triage against $STATE_FILE (jq exit $verdicts_exit): $verdicts" >&2
  exit 2
fi

printf '%s\n' "$verdicts"
exit 0
