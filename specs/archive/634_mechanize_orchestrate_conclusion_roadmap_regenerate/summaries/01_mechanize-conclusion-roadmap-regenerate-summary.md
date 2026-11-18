# Implementation Summary: Task #634

- **Task**: 634 - Mechanize /orchestrate conclusion-stage roadmap regenerate
- **Status**: [COMPLETED]
- **Started**: 2026-11-16T03:23:00Z
- **Completed**: 2026-11-16T09:15:00Z
- **Effort**: ~6 hours
- **Dependencies**: None
- **Artifacts**: plans/01_mechanize-conclusion-roadmap-regenerate.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Extracted `/orchestrate`'s conclusion-stage roadmap-update step (Step 5) from prose-only
execution into one script, `orchestrate-conclusion-roadmap.sh`, invoked unconditionally from
Move 4's finalize sequence — so the regenerate can no longer be skipped by a lead ending its
turn before Move 5 ever runs. Deferred the consolidated output's emission to Move 5's own Step 6
and added a `Stop`-hook backstop (`orchestrate-conclusion-backstop.sh`) as defense-in-depth.
Added two new test suites, and updated six prose surfaces to state the resulting design.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-conclusion-roadmap.sh` — new; the single
  executable copy of Step 5 (classify, regenerate-or-degrade, commit, advisory lint, pending
  marker write)
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` — added
  `runtime_conclusion_pending_marker_path`, the shared marker-path resolver
- `agent-system/extensions/core/manifest.json` — `provides.scripts`/`provides.hooks`
  declarations for the new script, hook, and two test suites
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Move 4 gained the
  unconditional invocation plus the render-and-stage/emit split; Move 5's pointer rewritten
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` — `SKILL.md`
  ceiling moved 25500 B -> 26000 B (reviewed, dated ceiling move)
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — numbered item
  5 corrected to render-and-stage; new "Roadmap-Update Stage" subsection; Move 5 placement
  paragraph corrected
- `agent-system/extensions/core/hooks/orchestrate-conclusion-backstop.sh` — new; the `Stop`-hook
  backstop, modeled on `subagent-postflight.sh`'s proven marker/loop-guard shape
- `agent-system/extensions/core/root-files/settings.json` and `merge-sources/settings-hooks.json`
  — `Stop` array registration (both surfaces required by gate 21's fragment-coverage check)
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` — Step 5 rewritten as
  description-plus-pointer (zero executable code remaining in that section); the Executable
  Stage Body preamble records the GOAL (2) ruling; Step 6 gained the marker-deletion action
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-roadmap.sh` — new;
  Cases A-E plus a live-tree isolation guard (19 assertions)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-backstop.sh` — new;
  the hook's five guard cases (10 assertions)
- `agent-system/extensions/core/scripts/tests/suite-classification.data` — one `unit`/`-` row
  per new suite
- `agent-system/extensions/core/context/patterns/roadmap-update.md` — Live Callers entry 1
  rewritten to name the script and Move 4
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` — Conclusion
  Stage `Bash` row and preamble corrected
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` —
  opening-line attribution and the `### Conclusion` section note corrected
- `agent-system/extensions/core/index-entries.json` — line-count reconciliation (gate 3 Rule R)

## Decisions

- GOAL (1): extract to a script; the contract keeps the authoritative prose as a
  description-plus-pointer, never a second executable copy.
- GOAL (2): adopt both the reorder (defer emission to Move 5 Step 6) AND the `Stop`-hook
  backstop, as defense-in-depth together, not as alternatives.
- The pending marker's `continuation_count` lives inside the marker itself (not a sibling
  loop-guard file), matching the Phase 1 script's own chosen schema.
- `stop_hook_active` is read from hook STDIN (Claude Code's own live, harness-maintained flag),
  not from the marker's own field as `subagent-postflight.sh` does — that precedent's field is
  permanently `false` by its sole writer's own design comment, so copying it verbatim would have
  produced a dead escape.
- Phase 6 (the plan's final `full`-tiered phase) discharged its own verification against this
  dispatch's Batch Gate Deferral directive's scoped narrowing
  (`verify-deploy.sh --only-gate 2,3,4,5,8,9,11,14,17,18,20,21,22,27,29`) rather than
  independently re-running the complete gate set.

## Plan Deviations

- **Phase 1**: Phase 1's own verification line names the literal source-store path for the
  `--dry-run` self-test; exercised the deployed copy instead, since this script family
  (modeled on `orchestrate-batch-gate.sh`) is not runnable from the source store by design.
- **Phase 3**: `stop_hook_active` read from hook stdin rather than the marker's own field — see
  Decisions above.
- **Phase 5**: found and fixed a genuine, self-introduced defect from Phase 4 while re-reading
  per this phase's own instruction — a missing `task-ref-ok:end` marker in
  `test-orchestrate-conclusion-roadmap.sh`.
- **Phase 6**: the plan's literal `bash agent-system/deploy-headless.sh` path does not exist;
  used the correct entry point, `agent-system/extensions/core/scripts/deploy-headless.sh`,
  throughout. The complete gate set was discharged against the Batch Gate Deferral directive's
  scoped narrowing rather than independently re-run.

## Verification

- Build: N/A
- Tests: Passed (both new suites, 29 assertions total, pass cleanly against the deployed tree;
  the two scoped-gate-discharge failures — gate 8 and gate 29 — and `run-all.sh`'s own 7 failing
  suites are all independently confirmed pre-existing or environmental, fully recorded in
  Phase 2's and Phase 6's own Reasoned Exclusions tables)
- Files verified: Yes

## Impacts

- The roadmap regenerate now runs unconditionally from every `/orchestrate` invocation's Move 4,
  single-task and batch alike, on every exit status — closing the lead-discretion-dependent skip
  this task's own measured evidence (the `/orchestrate 436, 626` run) demonstrated.
- The consolidated output is now a single combined report (Move 4's render-and-stage plus Move
  5's own channels), rather than two partial emissions.
- A session cannot end its turn while the conclusion stage's roadmap step has run but the rest
  of Move 5 has not, closing the same class of silent-skip risk for the remaining Move 5 content
  (issue classification, channel recording, Step 7's next-batch suggestion).

## Follow-ups

- Five pre-existing, independently-owned defects were observed and recorded as evidence (not
  fixed, out of this task's scope): the `typescript` extension's own gate-29 `REPO_ROOT` depth
  violation (and its downstream `test-gate-registry-resolution.sh` case); a load-induced gate-10
  timeout; `test-update-task-status.sh`'s own contamination-guard false-positive under
  concurrent-sibling load; and `run-all.sh`'s five already-`known-failures.txt`-tracked
  suites.

## References

- `specs/634_mechanize_orchestrate_conclusion_roadmap_regenerate/plans/01_mechanize-conclusion-roadmap-regenerate.md`
- `specs/634_mechanize_orchestrate_conclusion_roadmap_regenerate/reports/01_mechanize-conclusion-roadmap-regenerate.md`
- `specs/634_mechanize_orchestrate_conclusion_roadmap_regenerate/progress/phase-{1..6}-progress.json`
- `specs/634_mechanize_orchestrate_conclusion_roadmap_regenerate/handoffs/phase-{1..6}-handoff-*.md`
