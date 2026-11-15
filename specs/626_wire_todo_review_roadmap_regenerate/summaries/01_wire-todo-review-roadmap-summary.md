# Implementation Summary: Task #626

- **Task**: 626 - Wire /todo and /review to roadmap regeneration behind the shared preflight gate
- **Status**: [COMPLETED]
- **Started**: 2026-11-14T00:00:00Z
- **Completed**: 2026-11-14T01:45:00Z
- **Effort**: ~2 hours
- **Dependencies**: 625 (completed), 436 (completed), 458 (completed)
- **Artifacts**: plans/01_wire-todo-review-roadmap.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Wired `/todo` and `/review` to `roadmap-integration.sh --regenerate` behind the shared preflight
classify/scaffold gate, recorded the postflight-legality ruling for the `/todo` call site, and
rewrote `context/patterns/roadmap-update.md`'s caller contract to name all four live callers with
their interactive-vs-autonomous arms. All edits landed in the core source store
(`agent-system/extensions/core/`) per the hard edit-target constraint, with `.claude/**`
regenerated from that store and the deployed tree confirmed consistent.

## What Changed

- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` — added one
  scope-clarifying sentence to `## Overview` recording that the Allowed/Prohibited tables and
  their lint are scoped to agent-delegating skills, so a direct-execution command body (like
  `/todo`'s and `/review`'s) needs no Move-5-shaped additive exception.
- `agent-system/extensions/core/commands/todo.md` — new `### 6.6. Regenerate Roadmap` stage
  (classify -> interactive `AskUserQuestion` approval on `absent`/`unknown` -> scaffold on
  approval -> `--regenerate` -> commit `specs/ROADMAP.md` alone if changed), sited after Stage
  6's archival commit and Stage 6.5's metrics sync; one new `roadmap_regenerated` output field.
- `agent-system/extensions/core/commands/review.md` — new `### 6.8. Regenerate Roadmap` section
  with the identical step shape, sited after Section 6.7's Task Order management and before
  Section 7's Git Commit, with an explicit note that `--brief` mode early-exits before reaching
  it; one new output line.
- `agent-system/extensions/core/context/patterns/roadmap-update.md` — rewrote `## Live Callers`
  as a four-entry list (`/orchestrate` conclusion stage, `roadmap-agent` via `/roadmap`, `/todo`,
  `/review`) each naming its arm; corrected the `## Responsibility Split` bullet and removed the
  stale "neither /todo nor /review" claim and the old open-gap Ruling paragraph; extended the
  `## Preflight Obligation` interactive-arm parenthetical to name all three interactive callers;
  recorded the postflight-legality ruling inline.
- `agent-system/extensions/core/index-entries.json` — mechanical line-count sync for the three
  edited context/pattern/standard files, applied automatically by `deploy-headless.sh`.

## Decisions

- Both new callers use the interactive `AskUserQuestion` arm (not the non-interactive degrade):
  both are user-invoked slash commands running in a live session with `AskUserQuestion` already
  in their `allowed-tools` frontmatter, so an approver is always present.
- The `/todo` call site is postflight-legal as-is: `context/standards/postflight-tool-restrictions.md`'s
  base tables and their lint (`lint-postflight-boundary.sh`) are scoped to skills that delegate
  to a subagent via the Agent tool; `commands/todo.md` never delegates, so there is no
  agent-work/postflight boundary for that standard to protect, and no additive exception is
  needed.
- Commit the roadmap render only when it actually changed, in its own `specs/ROADMAP.md`-only
  commit, separate from each command's other commits — never folded into an existing multi-path
  `stage_paths` array.

## Plan Deviations

- **Phase 4**: reworded two pre-existing "no longer" occurrences outside the plan's named edit
  points (the `--prune`-equivalence sentence under Live Callers, and the advisory
  batch-proposal-lint disposition paragraph) to satisfy that phase's own whole-file
  forbidden-phrasing verification grep. Neither touched the protected `--prune` Per-Mode-Contract
  section or the Preflight Obligation's Hard Constraint paragraph, both left byte-identical per
  the plan's Decisions.
- **Phase 5, verification-tier discharge**: per this dispatch's Batch Gate Deferral directive,
  discharged the "run the complete unnarrowed gate set" task item against
  `verify-deploy.sh --skip-slow --only-gate 3,4,9` instead — the complete gate set runs once at
  the batch level, not independently per task.
- **Phase 5, idempotence check**: the `--regenerate --dry-run` sanity check reported a content
  diff against the committed `specs/ROADMAP.md`. Root-caused to concurrent sibling
  `/orchestrate` batch tasks advancing `specs/state.json` mid-dispatch (new tasks 629-633 landed
  live during this dispatch), not to a regression: this task never modified
  `roadmap-integration.sh`/`roadmap-preflight-lib.sh` and never actually ran `/todo` or `/review`
  (only authored their command markdown), so it never wrote `specs/ROADMAP.md` itself.

## Verification

- Build: N/A (markdown/prose task, no build step).
- Tests: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
  test-assess-repo-health.sh,test-todo-archived-projects-scan.sh,test-todo-move-pair-staging.sh`
  — 3/3 passed (Phase 2).
- Scoped gates: `verify-deploy.sh --skip-slow --only-gate 3,4,9` (doc-lint, task-reference lint,
  postflight-boundary lint) — doc-lint and postflight-boundary lint PASS; task-reference lint
  shows one pre-existing, out-of-scope finding in a file this task never touched
  (`orchestrator-context-budget.json`).
- `bash .claude/scripts/validate-state.sh specs/state.json` exits 0 (warnings only, all
  pre-existing and unrelated).
- `deploy-headless.sh` landed the deploy from the edited source store; subsequent scoped-gate
  re-run (after the automatic line-count sync) is clean for every file this task touched.
- Consumer-discovery and caller-count greps confirm exactly four code-level `--regenerate` call
  sites (`commands/review.md`, `skills/skill-roadmap/SKILL.md`, `commands/todo.md`,
  `agents/roadmap-agent.md`) and no surviving "two callers" claim anywhere in the deployed tree.
- Files verified: Yes — every edited file read back and grep-confirmed against its phase's own
  verification criteria.

## Impacts

- `specs/ROADMAP.md` can no longer go stale behind a silent `/todo` or `/review` refusal: both
  commands now classify and regenerate it on every invocation, gated by the same approval arm
  `/roadmap` already uses.
- `context/patterns/roadmap-update.md` now matches the code: a future reader sees all four live
  callers and their arms in one place, with no contradicting "acknowledged gap" language to
  reconcile.

## Follow-ups

- None required by this task. The full, unnarrowed gate set still runs once at the batch level
  per the Batch Gate Deferral directive and will attribute its result back to this task via
  `modified_files`.

## References

- Plan: `specs/626_wire_todo_review_roadmap_regenerate/plans/01_wire-todo-review-roadmap.md`
- Research report: `specs/626_wire_todo_review_roadmap_regenerate/reports/01_wire-todo-review-roadmap.md`
- Handoffs: `specs/626_wire_todo_review_roadmap_regenerate/handoffs/phase-{1..5}-handoff-*.md`
