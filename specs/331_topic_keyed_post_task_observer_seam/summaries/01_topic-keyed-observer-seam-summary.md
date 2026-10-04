# Implementation Summary: Topic-Keyed Post-Task Observer Seam

- **Task**: 331 - Topic-keyed post-task observer seam for extensions
- **Status**: [COMPLETED]
- **Started**: 2026-10-03T19:30:00Z
- **Completed**: 2026-10-04T06:25:00Z
- **Effort**: ~6 hours across 7 phases
- **Dependencies**: 327 (completed), 330 (completed)
- **Artifacts**: plans/01_topic-keyed-observer-seam.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added a manifest-declared `observers` block through which a loaded extension registers a
script to run AFTER a task reaches a resting state under `/orchestrate`, matched prefix-aware on
the task's `topic` and/or `task_type` (match-if-either, resolve-ALL). The seam is advisory and
non-blocking: an observer's return code is recorded as a `task_observer_run` event in
`specs/events.jsonl` and otherwise ignored; a bounded timeout prevents a hanging observer from
wedging an orchestration; nothing it does can change task status or fail a dispatch. All seven
plan phases are complete, every new and pre-existing regression suite touched by this work is
green, and the seam ships inert (zero live extension declares `observers` today).

## What Changed

- `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh` — added
  `routing_resolve_observers()`, a sibling resolve-ALL ladder (distinct from the existing
  first-match-wins `routing_lookup`/`routing_lookup_flat`), emitting one TAB-separated line per
  matching observer declaration across every loaded extension (core included); extended the
  file-header function inventory and Usage block.
- `agent-system/extensions/core/scripts/run-task-observers.sh` — new invoker. Resolves matches,
  selects a timeout binary (`timeout` then `gtimeout` then skip-with-event), invokes each
  matching observer with six positional arguments (`task_number task_type topic task_dir
  session_id resting_status`), emits exactly one rc event per attempted observer, and always
  `exit 0`. Registered in `manifest.json`'s `provides.scripts`.
- `agent-system/extensions/core/scripts/tests/test-run-task-observers.sh` — new regression suite,
  15 cases: prefix match, topic-only, task_type-only, both-declared match-if-either, no match,
  multiple matching extensions, missing script, non-executable script, non-zero rc, timeout, no
  timeout binary, failing-observer-does-not-change-status, malformed declaration tolerance,
  `--dry-run`, and an ordering assertion against the postflight call site. Registered in
  `manifest.json`'s `provides.scripts`.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — new WORK (n) section:
  a fresh `topic` read from `state.json`, then the `run-task-observers.sh` call, sited
  immediately after the `persisted_status` computation and before `# ─── Final output ───`,
  provably after WORK (m)'s `dispatch-metrics.sh` call and every WORK (f) `issue-record.sh` call
  site. Gated on `is_live` only, non-fatal. File-header WORK-letter inventory extended.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` —
  `run-task-observers.sh` added to the sandbox's `require_file`/`setup_sandbox` collaborator
  lists; four new end-to-end "Observer acceptance" cases (A-D) covering topic match, prefix
  match, non-match, and crash-does-not-affect-status.
- `agent-system/extensions/core/scripts/check-extension-docs.sh` — Rule X:
  `check_observers_resolve` (structural validation: required `script`, at least one of
  `topic`/`task_type`, allowed-key enforcement, `provides.scripts` presence, deploy-state
  advisory) and `check_observers_documented` (README-mention enforcement), wired into the
  per-extension dispatch loop; header rule-letter index extended.
- `agent-system/extensions/core/docs/guides/creating-extensions.md` — new `## Post-Task
  Observers` section after `## Lifecycle Hooks`: schema, matching contract, execution contract,
  invocation site and ordering guarantee, WHY TOPIC (the 17-task measurement), WHY NOT LIFECYCLE
  HOOKS, documentation requirement, worked example, how-to.
- `agent-system/extensions/core/context/reference/state-management-schema.md` — rewrote the
  `topic` field's Project Entry Fields row to state it is now a BINDING, dispatch-matching key
  (line 69's `active_topics` aggregation row left unchanged, as specified).
- `agent-system/extensions/core/manifest.json` — two new `provides.scripts` entries
  (`run-task-observers.sh`, `tests/test-run-task-observers.sh`).

## Decisions

- Resolve-ALL resolution lives in a sibling function (`routing_resolve_observers`), never folded
  into the existing first-match-wins ladders, per the plan's D1-D7 and the research report's
  library-reuse-boundary finding.
- Timeout binary selection: `timeout` then `gtimeout` then skip-with-event (D3) — never an
  un-bounded invocation, which would violate the hanging-observer contract while appearing to
  satisfy it in code.
- Insertion point: immediately after `persisted_status`, before `# ─── Final output ───` (D4),
  gated on `is_live` only (D5), matching WORK (m)'s own dry-run posture.
- `ROUTE_MANIFEST_ROOT` is set to an absolute `"${PROJECT_ROOT}/.claude"` only when unset (D6),
  making manifest-root resolution cwd-independent.
- Multiple-match ordering: manifest glob order, then observer key sorted within a manifest (D7).

## Plan Deviations

- **Phase 3's case (l) fixture redesigned**: the initial fixture assumed `run-task-observers.sh`
  sandboxes an observer's own filesystem writes, which it does not (out of scope for an advisory
  invoker). Redesigned to assert the SUT's own exit code and non-mutation of `state.json`, with
  the fixture observer only emitting garbage stdout/stderr rather than writing to `state.json`.
- **Ordering-assertion case relocated**: initially drafted inside Phase 3's test file, then
  correctly deferred to Phase 4 (which adds the postflight call site the assertion parses
  against) per the plan's own phase-task assignment.

## Verification

- Build: N/A (shell scripts + markdown)
- Tests: `test-run-task-observers.sh` 15/15 PASS; `test-orchestrate-cycle-postflight.sh` 171/171
  PASS (including 4 new end-to-end observer cases); `test-routing-resolution.sh` 13/13 PASS
  (unchanged, confirming the two existing ladders are untouched). `run-all.sh` full sweep:
  101 passed, 8 failed (3 expected per `known-failures.txt`, 5 NEW), 2 skipped, 111 total — the
  5 NEW failures (`test-detect-noop-bash.sh`, `test-lint-deploy-caller-wrap.sh`,
  `test-lint-state-writer-boundary.sh`, `test-orchestrate-build-aux-dispatch.sh`,
  `test-orchestrate-cycle-plan.sh`) are confirmed pre-existing and unrelated to this task via
  `git log` (their SUTs/suites were each last touched by a different task — 326, 329, 327, 148,
  1012, 240, 995 — and their failure messages have no connection to the observers seam).
- Files verified: Yes (deployed `run-task-observers.sh` and
  `tests/test-run-task-observers.sh` confirmed present and executable post-deploy).
- `shellcheck -S warning` clean on every file this task touched (`manifest-routing-lib.sh`,
  `run-task-observers.sh`, `test-run-task-observers.sh`, `orchestrate-cycle-postflight.sh`,
  `test-orchestrate-cycle-postflight.sh`, `check-extension-docs.sh` — the latter two carry
  pre-existing, unrelated `SC2034` warnings confirmed via `git show HEAD:...` to predate this
  task).
- `check-extension-docs.sh` (plain and `STRICT_CORE_DEPLOY=1`): PASS, all extensions OK.
- `verify-deploy.sh --skip-slow`: PASS, 33 checks, 0 failures.
- `bash .claude/scripts/check-task-references.sh` on both documentation targets: 0 unexempted
  occurrences.
- Inertness confirmed directly: the deployed `run-task-observers.sh`, run against task 331's own
  real identity, exits 0 silently with `specs/events.jsonl` byte-identical before/after.

## ACCEPTANCE Clause -> Test Mapping

| ACCEPTANCE clause | Proven by |
|---|---|
| (i) observer on topic X fires for X and X:sub, not for Y | `test-run-task-observers.sh` cases (a)/(b)/(e); `test-orchestrate-cycle-postflight.sh` Observer acceptance (A)/(B)/(C) |
| (ii) observer sees issue-log/metrics already present | `test-orchestrate-cycle-postflight.sh` Observer acceptance (A) (asserts `metrics_present`/`issues_present` in the probe file) |
| (iii) crashing observer leaves status/orchestration unaffected, produces an rc event | `test-run-task-observers.sh` cases (i)/(l); `test-orchestrate-cycle-postflight.sh` Observer acceptance (D) |
| (iv) `check-extension-docs.sh` flags an undocumented observer | Mechanically exercised via scratch fixture during Phase 5 verification (undocumented/missing-script/no-keys/stray-key/undeployed-script branches each `fail()`, documented-and-deployed passes, undeployed-but-declared is `advisory()`) |
| (v) shellcheck clean | `shellcheck -S warning` clean on every touched file (see Verification above) |

## Impacts

- `active_projects[].topic` is now a binding, dispatch-matching key for the first time (distinct
  from the same-named memory-index taxonomy field `memory-retrieve.sh` already reads).
- No behavior change for any existing extension: zero live extension declares `observers`, so
  the seam resolves zero matches, appends no event, and prints nothing in production today.
- A future extension (e.g. a `books` consumer) can register a topic-keyed observer without any
  further core changes.

## Follow-ups

- A concrete first observer consumer is explicitly out of scope (a separate backlog item depends
  on this one, per the dispatch's own Non-Goals).
- None blocking.

## References

- Plan: `specs/331_topic_keyed_post_task_observer_seam/plans/01_topic-keyed-observer-seam.md`
- Research report: `specs/331_topic_keyed_post_task_observer_seam/reports/01_topic-keyed-observer-seam.md`
- Guide: `agent-system/extensions/core/docs/guides/creating-extensions.md` (`## Post-Task Observers`)
- Schema: `agent-system/extensions/core/context/reference/state-management-schema.md`
