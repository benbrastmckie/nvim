# Implementation Summary: Task #330

- **Task**: 330 - Per-dispatch cost and timing record
- **Status**: [COMPLETED]
- **Started**: 2026-10-04T01:15:00Z
- **Completed**: 2026-10-04T05:10:00Z
- **Effort**: ~4 hours
- **Dependencies**: Task 329 (per-task issue log) — already [COMPLETED]
- **Artifacts**: plans/01_dispatch-metrics-record.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Built `dispatch-metrics.sh` as the single sanctioned writer of a new per-task
`specs/{NNN}_{SLUG}/metrics.jsonl` append-only cost-and-timing capture log — one JSON line per
orchestration dispatch, covering completion, partial, and blocked outcomes alike. The script has
two modes: a live postflight mode that reads `dispatch_start_ts`-anchored wall-clock, git
commits/churn, and — via an exact `task_number`+`dispatch_seq` match against the dispatch's own
Claude Code transcript — model, per-class token totals, and a per-tool-call breakdown; and a
`--backfill N` mode that derives per-phase wall-clock from phase-commit timestamps and git churn
for an already-completed task, marking every figure it recovers as `backfilled`/`derived` and
omitting what the transcript retention window has already erased. All seven plan phases closed
(six `[COMPLETED]`, one `[COMPLETED WITH EXCLUSIONS]`).

## What Changed

- `agent-system/extensions/core/context/formats/dispatch-metrics.md` — new file: full record
  schema, the exact transcript-join procedure, the three measured traps (hook-runtime vs. phase
  duration, dispatch_seq-is-not-a-count, phase-commit-timestamp wall-clock), the omission-not-
  zeroing rule, the 30-day transcript retention window, and the `--backfill` marking contract.
- `agent-system/extensions/core/scripts/dispatch-metrics.sh` — new file: live-mode arg parsing
  and closed enums, `entry_id`/timestamp construction, `wall_clock_seconds` with sentinel
  omission, git commits/churn derivation, the exact-match transcript join
  (`metrics_project_slug`, `metrics_transcript_join`), and `--backfill N` mode (phase-commit
  wall-clock deltas, `events.jsonl`-derived dispatch counts, full-range churn via
  `metrics_churn_for_hashes`, `figure_provenance` marking). `flock`-guarded append to
  `metrics.jsonl`, lazily created.
- `agent-system/extensions/core/scripts/tests/test-dispatch-metrics.sh` — new file: 11-case
  regression suite including both acceptance-bar-required tests (missing transcript → omitted
  not zeroed; metrics failure → non-fatal to caller) plus slug derivation, exact-match join
  (including the double-match defensive case), closed-enum refusal, append-path atomicity,
  `--backfill` marking, and the wall-clock sentinel.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — one new `WORK (m)`
  section, sited after WORK (k) and before WORK (i)'s per-task commit: a single non-fatal
  `dispatch-metrics.sh` call per dispatch, gated only on `is_live` (never on `have_outcome`,
  `research_gate_failed`, or `dispatch_status`), with a `dispatch_status`→`--outcome` mapping and
  a `phase`/`inferred_phase`→`--phase` mapping.
- `agent-system/extensions/core/manifest.json` — two `provides.scripts` entries added
  (`dispatch-metrics.sh`, `tests/test-dispatch-metrics.sh`).
- `agent-system/extensions/core/index-entries.json` — one new context-index entry for the format
  doc.
- `specs/330_per_dispatch_cost_and_timing_record/metrics.jsonl` — produced at runtime via
  `--backfill 330` against this task's own real commit history (filtered to this implementation
  round): 8 lines, one per phase-commit, demonstrating the full mechanism end-to-end on real data.

## Decisions

- **D1 — one script, two modes.** `--backfill` lives inside `dispatch-metrics.sh` rather than a
  separate file, mirroring `issue-record.sh`'s single-script shape.
- **D2 — one postflight call site, not three.** `WORK (m)` sits after the `dispatch_status` case
  statement and before the per-task commit, covering every outcome (including the no-outcome
  case) by construction rather than by three duplicated arm-local calls.
- **D3 — `commits` excludes the postflight bookkeeping commit** by construction (the metrics call
  runs before WORK (i)'s commit).
- **D4 — exact-match join only** (`task_number` AND `dispatch_seq`, never nearest-timestamp or
  `.meta.json` description matching).
- **D5 — `cc_session_id` from the live environment variable**, passed explicitly from the call
  site.
- **D6 — omission, never zeroing**, acceptance-tested for `tokens`, `tool_calls`, `model`, and
  `wall_clock_seconds`-with-a-sentinel-start.
- **D7 — no currency figure.**

## Plan Deviations

- **Phase 7** closed `[COMPLETED WITH EXCLUSIONS]`: `bash .claude/scripts/verify-deploy.sh`
  reports 32/34 checks passing. The 2 residual failures — a transient, gitignored
  `tmp/noop-bash-count-<session>` runtime marker (self-created by this very dispatch's own
  interactive Bash use, via the pre-existing `detect-noop-bash.sh` hook) and 3 pre-existing
  `run-all.sh` suite failures last touched by unrelated tasks 326/250
  (`test-gate-out-repair-reporting.sh`, `test-lint-json-channel-discipline.sh`,
  `test-orchestrate-cycle-plan.sh`) — are both evidenced (via `git check-ignore`/`git log`) as
  outside this task's file footprint and pre-existing the dispatch. Full reasoning and evidence
  recorded in the plan's Phase 7 `#### Reasoned Exclusions` table.
- A discovered-during-implementation limitation (not a plan deviation, but worth flagging): the
  `--backfill` mode's commit-subject-grep selection has no defense against task-number reuse
  after a vault operation — recorded as an open issue in `issues.jsonl` rather than fixed
  in-script, since closing it is a materially larger, separately-scoped change.

## Verification

- Build: N/A (shell scripts; `bash -n` parses on all three touched/new scripts)
- Tests: `test-dispatch-metrics.sh` 11/11 passed; `test-issue-record.sh` (sibling regression)
  15/15 passed; `test-orchestrate-cycle-postflight.sh` (dependent suite) 166/166 passed with zero
  regression from the new `WORK (m)` section.
- Shellcheck: clean on all three scripts (info-level findings only, matching each file's sibling
  baseline exactly; zero new findings on `orchestrate-cycle-postflight.sh` versus its pre-edit
  committed version).
- Files verified: Yes — all three deployed copies confirmed present after `deploy-headless.sh`;
  `validate-context-index.sh` passed (288 entries, 0 errors); `check-task-references.sh` clean
  (0 occurrences) on every touched file.
- Acceptance 1–4 all demonstrated with recorded `jq` evidence (real `--backfill 330` run, direct
  `--outcome blocked`/`partial` calls, scratch multi-commit fixture) — see Phase 7's task list in
  the plan for the full quoted evidence.

## Impacts

- Every future orchestration dispatch (research, plan, implement, aux, conclusion) now produces
  exactly one `metrics.jsonl` line at postflight time, capturing cost/timing figures that were
  previously unrecoverable once Claude Code's 30-day transcript retention window elapsed.
- `--backfill N` lets an operator retroactively recover what is still derivable for any
  already-completed task, with every recovered figure explicitly marked.
- No existing behavior changed: the new postflight call is strictly additive and non-fatal; a
  `dispatch-metrics.sh` failure can never change a task's status, verdict, or exit code.

## Follow-ups

- `--backfill`'s commit-subject-grep selection should eventually gain a defense against
  task-number reuse across vault operations (see the open issue recorded in `issues.jsonl`);
  out of this task's scope.
- `context/patterns/deploy-orphan-detection.md`'s "Runtime artifact" exclusion class could be
  extended to cover `detect-noop-bash.sh`'s `tmp/noop-bash-count-*` pattern, closing the
  `verify-deploy.sh` false-positive observed during this task's own Phase 7 (unrelated to this
  task's own scope; recorded as an open issue).
- Any reporting/aggregation/dashboard over `metrics.jsonl` is a deliberate non-goal of this task
  (capture-only, mirroring `issue-log.md`'s own boundary) and remains a separate future task.

## References

- Plan: `specs/330_per_dispatch_cost_and_timing_record/plans/01_dispatch-metrics-record.md`
- Research report: `specs/330_per_dispatch_cost_and_timing_record/reports/01_dispatch-metrics-script-design.md`
- Format doc: `agent-system/extensions/core/context/formats/dispatch-metrics.md`
- Sibling precedent: `agent-system/extensions/core/context/formats/issue-log.md`,
  `agent-system/extensions/core/scripts/issue-record.sh`
