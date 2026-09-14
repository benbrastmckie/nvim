# Implementation Summary: Task #142

- **Task**: 142 - Orchestrator context budget: measure and lock
- **Status**: [COMPLETED]
- **Started**: 2026-09-07
- **Completed**: 2026-09-08
- **Effort**: ~6 hours
- **Dependencies**: 88 (completed)
- **Artifacts**: plans/01_context-budget-gate-lock.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Stage A (task 88 and its neighbors) had already driven the orchestrator's three context surfaces
to or near their targets; this task's job was to **lock the numbers with gates**, not cut
further. It added a source-store ceiling config, a new `verify-deploy.sh` Gate 20 (eager-load
regression check plus two per-file ceilings, severity-toggled by one env-var default), a
fixture-based per-cycle lead-growth probe converting the "~1 KB per task per cycle" claim into a
re-runnable measured number, and a correction to the stale Context Flatness prose across five
files. All six plan phases completed; both new fixture suites and the full gate run are green.

## What Changed

- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` — new ceiling
  config (two per-file ceilings, the recorded eager-load baseline), in the established
  `claudemd-size-budget.json` shape.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — new Gate 20: volatile-file
  unconditional fail (delegated to `measure-eager-context.sh --check`'s exit code), eager-load
  regression check (unconditional `fail()`), two per-file ceilings (`warn()`/`fail()` toggled by
  `ORCHESTRATOR_BUDGET_GATE_MODE`, default `warn`). Every finding text is normalized (value-free)
  to avoid tripping the inter-cycle redeploy checkpoint's findings-diff.
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` — new fixture
  suite: a real-copy (rsync, minus the literature Python venv) fixture tree exercising both
  per-file ceilings, the `ORCHESTRATOR_BUDGET_GATE_MODE=hard` toggle, the eager-load regression
  check, and the load-bearing `deploy_findings_snapshot`/`deploy_baseline_new_findings` pre/post
  diff proving a byte-count drift never registers as a new finding. 15 assertions, all passing.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-context-growth.sh` — new fixture
  suite: a disposable 3-task cycle through the real `orchestrate-cycle-plan.sh` (live mode, not
  dry-run) → `orchestrate-build-dispatch.sh` → `orchestrate-cycle-postflight.sh` call graph,
  measuring the lead's actual per-task-per-cycle byte growth. Prints
  `PER_TASK_PER_CYCLE_BYTES: 871`, deterministic across repeated runs, well under the 2,048 B
  regression ceiling. 6 assertions, all passing.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — `## Context
  Flatness Guarantee` rewritten: names `orchestrate-cycle-postflight.sh`'s compact JSON as what
  the lead actually reads on the normal path (the illustrative `handoff=$(cat ...)` block no
  longer reflected reality and was replaced with the real postflight invocation), cites the
  measured 871 B / ~218 tokens figure and the test that produces it.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — one-line correction of the
  same stale "~450 tokens per cycle per task" claim in the MUST NOT (Context Flatness Constraint)
  section.
- `agent-system/extensions/core/context/patterns/context-protective-lead.md` — three stale
  "skill-orchestrate grows by ~450 tokens per cycle" instances corrected with the measured figure
  and a pointer to the re-runnable test; the Handoff Pattern section's illustrative example
  reframed as generic (not a literal skill-orchestrate reproduction).
- `agent-system/extensions/core/docs/architecture/orchestrate-cycle-postflight.md` — disambiguated
  its own "~450 tokens per cycle" wording as the SCRIPT's own read bound (still accurate,
  unchanged), distinct from the lead's larger total per-cycle growth measured elsewhere.
- `agent-system/extensions/core/manifest.json` — registered both new test scripts under
  `provides.scripts` (required for `check-extension-docs.sh` parity; caught by Gate 3 on the
  first post-implementation deploy).

## Decisions

- Followed research Finding 2's precedent exactly: copied `claudemd-size-budget.json` +
  `SCHEMA_CONFORMANCE_GATE_MODE`'s env-var-toggle shape rather than inventing a new config format.
- Sub-check B (eager-load regression) ships as an unconditional `fail()`, not routed through
  `ORCHESTRATOR_BUDGET_GATE_MODE` — matches this task's own Risk table ("only the eager-load
  regression check ships at fail() tier, and only because the current value is already
  comfortably under baseline") and research Decision 2 (no persisted auto-promotion machinery;
  severity changes are a deliberate follow-up commit, not a runtime toggle).
- Phase 3's fixture suite real-copies (`rsync`, excluding the literature Python venv) the
  `agent-system/extensions/` tree rather than symlinking, because several downstream lints
  (`find ... -type f` without `-L`) do not follow symlinked directories/files — discovered
  empirically after a symlink-only fixture produced spurious "no dispatchable agents found"
  failures unrelated to Gate 20.
- Phase 3's three padding-dependent cases (per-file ceilings x2, eager-load) were merged into one
  combined `verify-deploy.sh` invocation instead of three separate runs, since the suite's runtime
  is dominated by the OTHER 19 gates re-scanning the fixture tree, not Gate 20 itself.
- Phase 4's growth probe measures the lead's RAW captured stdout (contamination included) for the
  `plan_json` byte count, since that is what the lead's Bash tool call actually returns in
  practice — not just the clean trailing JSON line used for the suite's own parsing.

## Plan Deviations

- **Phase 2, sub-check B**: implemented as an unconditional `fail()` rather than mode-toggleable —
  see Decisions above; matches this same phase's own Risk table row, not a deviation from intent.
- **Phase 3, cases 1/2/5**: merged into one combined verify-deploy.sh invocation (deviation for
  runtime reasons; each case's assertions remain independently scoped within that shared run's
  output) — see Decisions above.
- **Phase 3, case 4**: reused the combined run's already-captured findings as the "pre" snapshot
  instead of a fourth full invocation (deviation for runtime reasons; `deploy_findings_snapshot`'s
  contract — a raw `--findings` capture — is unaffected by which run produced the text).
- **Phase 4**: postflight's `--session` argument corrected mid-implementation from the per-task-
  suffixed session id to the bare cycle session id, matching cycle-plan.sh's own multi-state file
  derivation and SKILL.md's own Move 3 code (a bug caught by the fixture failing loudly, not a
  scope change).

## Verification

- Build: N/A (bash/config repo)
- Tests: Passed — `test-verify-deploy-context-budget.sh` 15/15, `test-orchestrate-context-growth.sh`
  6/6, full `tests/run-all.sh` green (all discovered suites, including both new ones)
- Files verified: Yes
- `verify-deploy.sh` (full, not `--skip-slow`): PASS, Gate 20 present with exactly one live
  finding (the pre-existing `commands/orchestrate.md` over-ceiling WARN)
- `check-task-references.sh`: 0 unexempted occurrences in the five prose files touched

## Before/After Table

All four dispatch-named figures, re-measured at completion:

| Figure | Baseline (2026-09-02, task description) | Measured at plan time (2026-09-07) | Measured at completion (2026-09-08) | Command |
|---|---|---|---|---|
| `skills/skill-orchestrate/SKILL.md` | 293,977 B | 15,830 B | 16,025 B | `wc -c` |
| `commands/orchestrate.md` | 46,874 B | 15,812 B | 15,812 B (unchanged; still ~2x over its 8,000 B ceiling) | `wc -c` |
| Eager session load | 63,973 B / ~16k tokens | 62,985 B / 15,746 tokens | 62,985 B / 15,746 tokens (unchanged) | `measure-eager-context.sh --check` |
| Lead-authored prompt text per cycle | 25-60 KB per 5-task cycle (task descriptions interpolated inline) | *(not yet measured — Phase 4 target)* | **871 B measured per task per cycle** (~218 tokens), deterministic | `test-orchestrate-context-growth.sh` |

The SKILL.md 195 B growth between plan time and completion is this task's own Phase 5 prose
correction (added the measured-figure sentences); still comfortably under the 20,000 B ceiling.

## Impacts

- `verify-deploy.sh` now catches, on every deploy, both an eager-load regression above the
  recorded baseline and either orchestrator context-surface file drifting past its ceiling —
  closing the gap the original task 142 description flagged (no lock existed before this task).
- The "~1 KB per task per cycle" Context Flatness claim is now a measured, re-runnable number
  (871 B) rather than an unverified estimate, and every doc/skill file that repeated the older
  "~400/450 tokens" claim now cites it (or, where the older number was a legitimate, unrelated
  file-size ceiling rather than a growth claim, was left untouched).
- `commands/orchestrate.md` remains ~2x over its configured 8,000 B ceiling under a warn-only
  gate — visible on every deploy via Gate 20's WARN, but with no forcing function yet (see
  Follow-ups).

## Follow-ups

- `commands/orchestrate.md` (15,812 B) sits at roughly 2x its 8,000 B ceiling under a warn-only
  Gate 20. This is out of 142's narrowed measure-and-lock scope (Non-Goal: "Further trimming of
  `commands/orchestrate.md`"); a Stage C task should either trim it toward the ceiling or
  deliberately re-derive the ceiling if 8,000 B turns out to be unrealistic for this file's role.
- `orchestrate-cycle-plan.sh`'s live preflight write path leaks `update-task-status.sh`'s
  unredirected `echo "OK: task N status -> X"` onto its own stdout ahead of the final JSON line
  (discovered while building the Phase 4 growth probe). This does not break the lead in practice
  (an LLM reading Bash output tolerates the noise), but it is real, currently-unaccounted bytes in
  every live cycle-plan call, and a literal `jq`-based consumer of `orchestrate-cycle-plan.sh`'s
  stdout would break on it. Worth a small follow-up: redirect that specific `update-task-status.sh`
  preflight call's stdout, or filter it in `skill_preflight_update`.
- The severity-gate config-file pattern (ceiling JSON + env-var mode toggle) now has two
  independent instances (`claudemd-size-budget.json` / `SCHEMA_CONFORMANCE_GATE_MODE` and this
  task's `orchestrator-context-budget.json` / `ORCHESTRATOR_BUDGET_GATE_MODE`). A short
  `context/patterns/` note documenting the pattern (config shape, `warn()`/`fail()`/`info()`
  severity dispatch, normalized-finding-text requirement) would help a third instance land
  correctly on the first try — flagged by the research report's own Context Extension
  Recommendations.

## References

- Plan: `specs/142_reduce_orchestrator_token_consumption/plans/01_context-budget-gate-lock.md`
- Research: `specs/142_reduce_orchestrator_token_consumption/reports/01_context-budget-gate-measurement.md`
- `context/patterns/batch-orchestration-guardrails.md` — the inter-cycle redeploy checkpoint
  contract Phase 3's findings-diff fixture verifies against
- `specs/PATH.md`, "Budgets" table — the sequencing document naming this task as the gate owner
