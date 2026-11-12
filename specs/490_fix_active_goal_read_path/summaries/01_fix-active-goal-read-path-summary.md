# Implementation Summary: Task #490

- **Task**: 490 - Fix active_goal read path
- **Status**: [COMPLETED]
- **Started**: 2026-11-12T06:18:00Z
- **Completed**: 2026-11-12T07:50:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_fix-active-goal-read-path.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`generate-task-order.sh` rendered the `**Goal**:` line in `TODO.md`'s `## Task Order` section but
never read `state.json`'s `active_goal`, making it a dead write with a second, more severe layer:
`--print` mode (the dominant regeneration path, including `/review` Section 6.7.3's own caller)
never rendered any Goal line from any source. The fix replaces the mode-gated resolution with a
single `resolve_goal_text()` chain (`--goal` override > non-empty `active_goal` > existing
`TODO.md` Goal line > omit), applied identically in `--print` and `--update-todo`, backed by
regression cases that were observed red against the unmodified script before the fix landed, with
the precedence and conflict rule documented, and the change carried into the deployed tree.

## What Changed

- `agent-system/extensions/core/scripts/generate-task-order.sh` — added `resolve_goal_text()`
  adjacent to `read_existing_goal()`; replaced the `if GOAL_OVERRIDE / elif MODE==update / else`
  block at the former "Determine goal text" site with one unconditional
  `GOAL_TEXT="$(resolve_goal_text)"` call shared by `--print` and `--update-todo`.
- `agent-system/extensions/core/scripts/tests/test-generate-task-order.sh` — refactored
  `build_state()` into a thin wrapper over a new `build_state_goal()` (emits `active_goal` in all
  three states: absent/`null`, empty `""`, non-empty); added `run_gto_print()`, `goal_line_from()`,
  and `seed_goal_line()` helpers; added five new regression cases (5a-5e) covering the precedence
  chain in both modes.
- `agent-system/extensions/core/context/formats/task-order-format.md` — Goal Statement section now
  documents the full four-tier chain and states the conflict rule and its rationale explicitly;
  Script Usage section notes `--print`/`--update-todo` parity; Generation Algorithm gained a
  "Resolve Goal text" step (inserted as step 6, renumbering the two following steps to 7-9).
- `agent-system/extensions/core/context/schemas/state-schema.json` and
  `agent-system/extensions/core/context/reference/state-management-schema.md` — the `active_goal`
  field description/row no longer claims "no script writes or reads it"; both now name the writer
  (`/review`'s goal-update flow) and the reader (`generate-task-order.sh`'s resolution).
- `agent-system/extensions/core/commands/review.md` — one comment line added above the
  `state-write.sh --regen-todo` call noting the regen now renders `active_goal` through the new
  reader; no functional change (Outcome #5 confirmed below).
- Deployed `.claude/` tree (via `deploy-headless.sh`) and `specs/TODO.md` (via `generate-todo.sh`)
  — carry the fix and the rendered Goal line respectively.

## Decisions

- **Conflict rule** (Outcome #2): a non-empty `active_goal` takes precedence over a hand-edited
  `TODO.md` Goal line; unset, `null`, and `""` all fall through to the preserve-from-TODO
  behavior unchanged. Rationale: `state.json` is the authoritative store and `TODO.md` a generated
  render target, so setting `active_goal` is the deliberate way to change the goal. Accepted
  trade-off: a stale `active_goal` silently overwrites a hand edit, but this self-corrects through
  the goal-update flow (or a direct `state-write.sh` call), whereas the reverse precedence would
  make that flow silently fail with no recovery path.
- Removed the `MODE == "update"` gate on Goal resolution entirely rather than threading the fix
  only into `--update-todo`: the report's caller survey showed every TODO.md-regenerating caller
  (`state-write.sh --regen-todo`, `orchestrator-postflight.sh`, `skill-base.sh`, and
  `commands/review.md` Section 6.7.3) reaches `--print`, never `--update-todo`, so a
  `--update-todo`-only fix would have left the motivating caller's workflow exactly as broken.
- Did not hand-edit `agent-system/extensions/core/index-entries.json`'s stale `line_count` entry
  for `task-order-format.md` in Phase 3: that file already carried ~14 unrelated uncommitted
  `line_count` hunks from concurrent sibling work, and `git-commit-scoped.sh` stages whole files
  (no hunk-level staging), so committing it would have swept in unrelated changes.
  `deploy-headless.sh`'s automatic `generate-context-line-counts.sh --write` call (confirmed in
  its log: "line_count auto-repair: 1 entry/entries corrected from wc -l (extensions: core)")
  fixed it, and everything else stale, before the deploy copy step — no manual edit was needed.

## Plan Deviations

- Phase 4's task "Run `deploy-headless.sh` and confirm `RESULT=landed_verify_clean`" completed
  with a deviation: the one `deploy-headless.sh` invocation run returned `RESULT=landed_verify_red`
  (5 of 41 fast-gate checks failed), not `landed_verify_clean`. The deploy itself landed correctly
  (confirmed: deployed reader present, deployed suite passes, live reproduction closed). The five
  failures were not a content regression: three (gate3/4/10) were transient 60-second-timeout
  kills under this `/orchestrate` batch's concurrent sibling load plus the not-yet-closed
  TODO.md/state.json desync this task itself exists to close, and all three passed cleanly on an
  immediate standalone rerun; the remaining two (eager-load context-budget total,
  `skill-orchestrate/SKILL.md` size ceiling) are pre-existing and sibling-owned (last touched by
  tasks 450 and 609, not in task 490's `file_scope`). Recorded as a `#### Reasoned Exclusions`
  record on Phase 4 rather than absorbed into this task's scope. See the plan's Phase 4 section
  for the full evidence table.
- Phase 4's task "Run the complete gate set: `bash verify-deploy.sh`" was discharged per this
  dispatch's own Batch Gate Deferral directive (`.dispatch/16.md`) against the scoped per-gate
  reruns above rather than a second independent full-gate-set invocation — the complete gate set
  runs once for the whole `/orchestrate` batch at the end and is attributed back to this task via
  its own `modified_files`.

## Verification

- Build: N/A (shell scripts, markdown, JSON schema)
- Tests: `test-generate-task-order.sh` — 18 pre-existing assertions unchanged through the Phase 1
  harness refactor; against the unmodified script (Phase 2 red evidence), `Results: 22 passed, 4
  failed` with failures exactly cases 5a, 5b, 5d's print half, and 5e's print half (the predicted
  set); after the fix, `Results: 26 passed, 0 failed`. Deployed-tree rerun:
  `run-all.sh --only test-generate-task-order.sh` — 1 passed, 0 failed.
- Files verified: Yes — `git diff --numstat` after each phase touched only that phase's declared
  files; the deployed copy carries the new `resolve_goal_text()` read
  (`grep -n active_goal .claude/scripts/generate-task-order.sh`).
- Live reproduction closed end to end: pre-regen, `specs/TODO.md`'s `## Task Order` section had no
  `**Goal**:` line while `specs/state.json`'s `active_goal` was non-empty; post-regen via
  `bash .claude/scripts/generate-todo.sh`, the Goal line renders and its text is byte-identical to
  `jq -r .active_goal specs/state.json`; `specs/state.json` shows no diff (neither `active_goal`
  nor `next_project_number` were written by this task, as required).
- Gate outcome: see Plan Deviations above and the plan's Phase 4 Reasoned Exclusions table for the
  full per-item evidence. The two sibling-owned failures are not attributable to this task; the
  complete gate set's final, authoritative result is produced once at the batch level per the
  dispatch's Batch Gate Deferral directive.

## Impacts

- Any caller that writes `active_goal` and regenerates `TODO.md` (today: `/review` Section 6.7.3
  via `state-write.sh --regen-todo`) now has its intent reach the rendered Goal line, in both
  `--print` and `--update-todo` modes.
- The preserve-from-TODO and `--goal`-override behaviors are unchanged; no existing caller
  regresses.

## Follow-ups

- `task-order-format.md`'s "Optional Status Summary" section still claims the `**Status**:` line
  "is also preserved across regenerations." `read_existing_goal()` reads only the Goal line, not a
  Status line, so that claim is false independently of this task (explicit Non-Goal here;
  recorded as a separate finding for a future task).
- `generate-todo.sh`'s non-default `--state-file`/`--todo-file` mismatch with its internal
  `generate-task-order.sh --print` call (archive-regeneration flows) is pre-existing and flagged
  by the script's own source comment; no archive-path caller writes `active_goal`, so this was an
  explicit Non-Goal and remains unaddressed.

## References

- Research report: specs/490_fix_active_goal_read_path/reports/01_fix-active-goal-read-path.md
- Plan: specs/490_fix_active_goal_read_path/plans/01_fix-active-goal-read-path.md
