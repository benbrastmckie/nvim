# Implementation Summary: Task #196

- **Task**: 196 - Make research the default first phase for an un-researched task unless --fast is given
- **Status**: [COMPLETED]
- **Started**: 2026-09-09T12:17:52Z
- **Completed**: 2026-09-09T14:00:00Z
- **Effort**: ~4.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_research-first-default-unless-fast.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Inverted `/orchestrate`'s classifier default for an un-researched (`not_started`) task from
`plan` back to `research`, made effort-conditional so `--fast` preserves the prior plan-first
behavior as an escape hatch. The routing rule stays in exactly one executable place
(`orchestrate-triage-classify.sh`, now accepting `--effort <fast|hard>`), with the caller
(`orchestrate-cycle-plan.sh`) forwarding its already-parsed `effort_flag` and keeping its
degraded fallback table in lockstep. The `needs_research` verdict and every piece of its
plumbing are retained in full, unchanged, as the safety net that makes `--fast` safe. All five
plan phases completed; the full gate set (four named gates plus two regression suites) is green.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` — added `--effort
  <fast|hard>` flag parsing ahead of the positional `<engine>`; made the live `not_started` row
  and the blocked-discharge `previous_status == "not_started"` arm effort-conditional
  (`research` by default, `plan` under `--effort fast`); updated the header table and its
  four-site lockstep note.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` — updated the
  sandbox probe and existing `not_started`/discharged fixtures for the new default; added a
  `check_fixture_effort` helper and six new fixtures (`--fast`, `--hard`, `researching` never
  skipped, `researched` never re-researched, discharged-under-`--fast`, invalid `--effort`
  value). Assertion count 38 → 48.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — forwards `effort_flag` to
  the classifier as `--effort` at the call site; the degraded inline fallback `case` table now
  encodes the identical effort-conditional `not_started` rule.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — rewrote Group 13
  (degraded-classifier fallback) to assert both effort variants; added new Group 20 exercising
  the LIVE classifier through `--dry-run` for both variants, proving the caller actually forwards
  `--fast` rather than the fallback table merely having it hardcoded. Assertion count 96 → 156.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — Complete State
  Table's `not_started` row split into two effort-conditional rows; "The `needs_research` Fork"
  section retitled and rewritten as "the `--fast` escape hatch"; ASCII diagram redrawn; three
  worked-example flows (new "Default Flow (research-first)", retitled "`--fast` Flow", retitled
  "`--fast` + `needs_research` Escape-Hatch Flow").
- `agent-system/extensions/core/commands/orchestrate.md` — `--fast` row rewritten to state it
  now changes WHICH PHASES RUN, names the `needs_research` escape hatch, and notes
  `--hard`/`--research` composability.
- `agent-system/extensions/core/context/standards/status-markers.md` — "The Two-Phase Default
  with Research on Demand" section retitled "The Effort-Conditional Default with a `--fast`
  Escape Hatch" and rewritten; `[RESEARCHING]`'s "Two producers" note updated.
- `agent-system/extensions/core/agents/planner-agent.md` — Stage 1.5 retitled "the `--fast`
  Escape Hatch"; framing paragraph rewritten to enumerate the three cases a no-`research_path`
  plan dispatch now means (`--fast`, forced plan round, stranded `planning` status); Error
  Handling bullet updated to match. The `research_path`-present skip rule, narrow bar, negative
  examples, and `needs_research`/`user_decision` distinction retained verbatim.
- `agent-system/extensions/core/agents/general-research-agent.md` — `focus_prompt` note rewritten
  so research itself reads as the default entry, not the exceptional case.

## Decisions

- Effort-awareness lives in the classifier (a new `--effort` input), not as a caller
  post-adjustment — preserves the classifier's "one code path" discipline and avoids a fifth
  drift-prone site.
- "Has not already been researched" means exactly `not_started` (and a discharged
  `previous_status` of `not_started`); every other status row is unchanged by effort.
- `needs_research` is retained on both paths in full — the `--fast` escape hatch, and still
  reachable on the default path via forced plan rounds or stranded `planning` statuses.
- `--fast` keeps its name and gains a second, explicitly documented meaning (phase-skipping)
  rather than introducing a new flag.

## Plan Deviations

- Phase 2, task "Add a NEW group (Group 15) exercising the LIVE classifier": numbered Group 20
  instead of Group 15 — Groups 15 and 16 already existed in `test-orchestrate-cycle-plan.sh`
  (stdout/stderr stream discipline; entry-point fd-3 redirect), a line-number drift the plan's
  own Scope Hypothesis anticipated for the doc phase but not for this test file. Also restores
  `orchestrate-batch-admit.sh` alongside the classifier since Group 16 leaves both stubbed with
  no restore of its own.

## Verification

- Build: N/A (shell scripts + Markdown; no compiled build step)
- Tests: `test-orchestrate-triage-classify.sh` 48/48, `test-orchestrate-cycle-plan.sh` 156/156,
  `test-orchestrate-cycle-postflight.sh` 65/65 (regression), `test-orchestrate-build-dispatch.sh`
  66/66 (regression) — all Passed
- Lint: `lint-agent-contracts.sh` 101/101; `check-task-references.sh` 0 unexempted occurrences
  across 4 trees
- shellcheck: clean on all 4 edited shell files (identical pre-existing info/warning counts to
  baseline; 0 new findings)
- Non-deletion audit: all five `needs_research` plumbing sites named in
  `specs/150_research_on_demand/summaries/01_...-summary.md` confirmed present
  (`orchestrate-cycle-postflight.sh` case arm, `update-task-status.sh` `map_status` arm,
  `skill-base.sh` arm, `validate-return-meta.sh`/`validate-handoff.sh` `valid_statuses`,
  `state-schema.json` `research_questions` admission)
- Files verified: Yes

## Impacts

- `/orchestrate` (and any caller of `orchestrate-triage-classify.sh` or
  `orchestrate-cycle-plan.sh`) now researches an un-researched task by default before planning
  it; `--fast` is the explicit opt-out for a specification-shaped task that needs no research.
- No schema changes: the `orchestrate-triage-v1` verdict schema gained no new field; effort is
  surfaced only in the `reason` string.
- Terminal-status handling and forced-phase consumption are explicitly out of scope (companion
  task's territory); this task lands first per the description's own sequencing note.

## Follow-ups

- None.

## References

- Plan: `specs/196_research_first_default_unless_fast/plans/01_research-first-default-unless-fast.md`
- Progress: `specs/196_research_first_default_unless_fast/progress/phase-{1,2,3,4,5}-progress.json`
- Handoffs: `specs/196_research_first_default_unless_fast/handoffs/phase-{1,2,3,4}-handoff-*.md`
- Prior decision this task inverts: `specs/150_research_on_demand/` (report, plan, summary)
