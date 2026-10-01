# Implementation Summary: Task #293

- **Task**: 293 - Add a HOLD task status marker that pauses a task and excludes it from dispatch
- **Status**: [COMPLETED]
- **Started**: 2026-10-01T04:08:30Z
- **Completed**: 2026-10-01T06:50:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_hold-task-status-marker.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Added `hold` as the 13th value to the closed task-status enum, giving an operator a way to pause
a task so it is excluded from `/orchestrate` dispatch and single-command gate-in, with all
artifacts preserved and `/todo` never archiving it. Three new fields (`hold_reason`, `held_at`,
`prior_status`) make the hold informative and reversible via `preflight:unhold`. All 8 plan
phases landed; the live consumer repository (`/home/benjamin/Projects/Logos/Verification`) was
re-verified at completion time: `validate-state.sh` went from 12 FAILs to 0, and
`generate-todo.sh` now regenerates `TODO.md` with `[HOLD]` on all 9 held tasks.

## What Changed

- `agent-system/extensions/core/scripts/lib/status-vocabulary.sh` — added `hold` to the enum
  (12 -> 13) and marker map; `hold` deliberately left out of `STATUS_VOCABULARY_LIFECYCLE_RANK`
- `agent-system/extensions/core/context/schemas/state-schema.json` — `hold` added to
  `taskStatus.enum`; `hold_reason`/`held_at`/`prior_status` added to `projectEntry.properties`
- `agent-system/extensions/core/scripts/validate-state.sh` — three fields added to
  `KNOWN_ENTRY_FIELDS`; "12-value" prose updated to "13-value"
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` — dedicated
  `group:"hold"` verdict (not `needs_human`, not `skip`), reason built from `hold_reason`
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — `hold)` bucketing arm
  (mirrors `forced_round_complete)`); comment on `is_terminal_status()` recording the
  deliberate exclusion
- `agent-system/extensions/core/scripts/update-task-status.sh` — `preflight:hold` /
  `preflight:unhold`, `--hold-reason=<string>` flag, the dynamic `unhold` preamble, and a
  **hold-sticky guard** (see Decisions below) that is the actual mechanism preserving
  `status == "hold"` across a forced dispatch
- `agent-system/extensions/core/scripts/generate-todo.sh` — renders the
  `- **Held**: YYYY-MM-DD` line; comment recording Decision 7 (hold counts as active)
- `agent-system/extensions/core/scripts/command-gate-in.sh` — hold ABORT arm ahead of the
  task-lock acquire, no forcing-flag override
- `agent-system/extensions/core/commands/orchestrate.md` — STAGE 0 three-category restructure
  (terminal / hold / ordinary), hold branches on `$FORCE_PHASES_FLAG`
- `agent-system/extensions/core/skills/skill-todo/SKILL.md`,
  `agent-system/extensions/core/commands/todo.md` — verification comments (hold excluded from
  archival by construction), `deferred_expanded_detail[]` reporting addition naming a held
  blocking subtask specifically (Decision 6 mitigation)
- `agent-system/extensions/core/context/standards/status-markers.md` — new `#### [HOLD]`
  section, table rows, Valid Transition Diagram annotation, forcing-flag decision record
- `agent-system/extensions/core/merge-sources/claudemd.md` — third "Paused state" category
- `agent-system/extensions/core/context/reference/state-management-schema.md` — three field
  rows plus a `### Hold Fields` subsection
- Eight files' "12-value"/"closed 12" prose swept to 13
  (`index-entries.json`, `return-meta-status-vocabulary.sh`, `lint-agent-contracts.sh`,
  `update-task-status.sh`, `orchestrate-recover-outcome.sh`, `generate-todo.sh` (x2),
  `validate-return-meta.sh`, `validate-state.sh` (x2))
- Test files: `test-status-vocabulary.sh`, `test-validate-state.sh`,
  `test-orchestrate-triage-classify.sh`, `test-orchestrate-cycle-plan.sh`,
  `test-update-task-status.sh`, `test-force-phases.sh` all gained hold-specific coverage

## Decisions

- **Decision 1-5** (dedicated `hold` triage group; `blocked[]` bucketing arm; `is_terminal_status`
  unwidened; forcing-flag reuses `task_has_forced_phase`; `unhold` as the lift surface) — all
  from research, implemented verbatim as planned.
- **Decision 6 (held-subtask blocking resolution)**: reading (a) is correct — **a held subtask
  continues to block its parent `[EXPANDED]` task's archival**, unchanged. A hold is a pause, not
  a completion-equivalent; a parent with genuinely paused work is not done. The mitigation
  implemented is a **reporting improvement, not a logic change**: both `skill-todo/SKILL.md` and
  `commands/todo.md` gained a `deferred_expanded_detail[]` array, built in a separate pass *after*
  the existing blocking-decision `case` statement (which is byte-for-byte unchanged in both
  files), naming a held blocking subtask specifically with its `hold_reason` rather than folding
  it into a generic "still active" count. The two implementations were diffed after editing and
  are logic-identical (only comment line-wrapping differs).
- **Decision 7 (generate-todo.sh active/terminal split)**: left unmodified — `hold` falls to the
  `*)` catch-all and counts as `active_count`, which is correct (a held task is non-terminal). A
  one-line comment now records this as intentional.
- **A real gap surfaced during implementation, beyond the plan's granular task list**: the
  rank-based `monotonic-max` clamp (`skill-base.sh`/`orchestrate-cycle-plan.sh`) does **not**
  protect `status == "hold"` across a forced live dispatch, because `hold` is deliberately
  unranked (Decision/Phase 1) — `status_vocabulary_would_regress(hold, implementing)` returns
  false ("no regression"), so the clamp alone would let an ordinary forced preflight write
  overwrite `hold` -> `implementing`. The actual fix (landed in `update-task-status.sh`) is a
  dedicated **hold-sticky guard**: whenever the task's current status is already `"hold"`, every
  operation except `preflight:hold` (reason update) and `preflight:unhold` (the lift) is
  downgraded to a no-op on the status field alone, while every other side effect (TODO.md regen,
  hooks, events) still runs normally. This is the mechanism that actually satisfies "an explicit
  `--implement` against a held task IS admitted and leaves `status == 'hold'` afterward" — proven
  end-to-end via a direct `skill_preflight_update(task, "implement", session, "monotonic-max")`
  call against a scratch fixture (the exact call `orchestrate-cycle-plan.sh`'s live path makes).
- **Out-of-scope observation (not fixed, per the dispatch's explicit instruction)**: research
  flagged that `commands/orchestrate.md` STAGE 0's pre-existing terminal-status arm
  (`completed|abandoned|expanded)`) never checks `$FORCE_PHASES_FLAG`, so that file's own
  documented claim that a forcing flag admits a terminal task appears honored only in the
  `--dry-run` path. This implementation's new `hold)` arm deliberately does NOT copy that
  unconditional-skip shape (it branches on `$FORCE_PHASES_FLAG` directly, so the hold override
  genuinely works in the live path), and deliberately does NOT fix the adjacent terminal-side
  gap, which remains exactly as research found it and is recorded here so it is not lost.

## Plan Deviations

- **Phase 3** *(altered)*: scope grew beyond the plan's literal file list to include
  `scripts/generate-todo.sh` (rendering the `- **Held**:` line) and the hold-sticky guard inside
  `update-task-status.sh` — both necessary to make the plan's own Phase 2 claim ("the hold's
  persistence is a property of Phase 3's map_status() work") actually true; see the Decisions
  section above and the plan's own Phase 3 deviation note.
- **Phase 7** *(altered)*: the plan hypothesized an 11-file/14-occurrence prose sweep; the actual
  fresh grep at implementation time found 8 files/10 occurrences (2 files were already fixed in
  Phase 1). The smaller, actual set governs per the plan's own stated rule.
- No other deviations; every other phase followed its plan tasks as written.

## Verification

- **Build**: N/A (no compiled artifacts)
- **Tests**: `bash scripts/tests/test-status-vocabulary.sh`, `test-validate-state.sh`,
  `test-orchestrate-triage-classify.sh` (60/60), `test-orchestrate-cycle-plan.sh` (330/330),
  `test-update-task-status.sh` (47/47), `test-force-phases.sh` (36/36) — all pass when run
  against the source-store copies directly (see Follow-ups for the one caveat).
- **Full shell harness** (`scripts/tests/run-all.sh --jobs auto`, both engines, all extensions):
  97 passed, 7 failed, 104 total. Of the 7: 4 are pre-existing, documented in
  `known-failures.txt`, unrelated to this task
  (`test-gate-out-repair-reporting.sh`, `test-lint-json-channel-discipline.sh`,
  `test-run-all-parallel.sh`, `test-verify-deploy-context-budget.sh`). The remaining 3 are
  explained, not real regressions:
  - `test-status-vocabulary.sh`, `test-validate-state.sh`: these two suites' own candidate
    resolution prefers this repo's deployed `.claude/` copy over the source store; this repo's
    own `.claude/` has not been redeployed mid-cycle (a sibling task's own deploy phase was still
    pending at verification time, and the dispatch's concurrency note explicitly prohibits a
    whole-tree redeploy mid-cycle). The underlying logic is independently proven correct: Phase 1
    verified it by directly sourcing the edited `status-vocabulary.sh`, and byte-equality between
    the enum and its schema twin was reconfirmed at Phase 8 (13 values both sides).
  - `test-typst-element-lint.sh`: fails on a pre-existing, uncommitted, unrelated modification to
    `agent-system/extensions/typst/scripts/typst-element-lint.sh` that was already present in the
    working tree before this dispatch began (outside this task's `file_scope`) — exactly the
    scenario `known-failures.txt`'s own header documents excluding for the identical reason.
- **Shellcheck**: clean (`--severity=warning`) across every script this task touched; every
  warning observed is independently confirmed pre-existing (verified against the pre-edit copy
  for each).
- **Task-reference lint**: `check-task-references.sh agent-system/extensions/core` — 0
  unexempted occurrences.

### Live Consumer-Repo Acceptance (`/home/benjamin/Projects/Logos/Verification`)

- Re-ran the live discovery immediately before claiming completion: the held-task set is
  **unchanged** from research time — 9 tasks (125, 126, 127, 128, 141, 142, 143, 162, 165), all
  carrying `hold_reason`/`held_at`/`prior_status` already.
- Deployed the source store (`bash .claude/scripts/deploy-headless.sh`, default non-destructive
  resync) — landed clean, 14 checks / 0 failures.
- `validate-state.sh --deep`: **0 FAILs** (down from 12) — 18 passed, 3 warnings (all pre-existing
  glob-shaped `file_scope` advisories on an unrelated task, #119).
- `generate-todo.sh`: regenerated successfully; all 9 held tasks render `[HOLD]` with a
  `- **Held**: 2026-09-30` line; `validate-state.sh` then reports TODO.md back in sync.
- `/orchestrate --dry-run` against a held candidate (#125, whose own dependencies are all
  `completed`) shows it in `blocked[]` with its `hold_reason` text and 0 dispatch. (A different
  held candidate, #165, depends on #125 itself and correctly shows `no_eligible_stuck` instead —
  this is the pre-existing "a non-terminal predecessor silently defers its dependent to next
  cycle" mechanism working exactly as it does for any other non-terminal status, not a
  hold-specific behavior.)
- The only writes made to the consumer repo were the two the dispatch explicitly sanctions: the
  deploy itself, and `generate-todo.sh`'s regeneration of `specs/TODO.md` (left as an uncommitted
  working-tree change there, for that repo's own owner/session to commit).
- A live, non-mutating end-to-end proof (rather than a live dispatch against the shared consumer
  repo, which has another session's work in flight) confirmed the forced-admit-and-preserve-hold
  claim: `test-orchestrate-cycle-plan.sh`'s Group 33b proves a forced `implement` against a held
  candidate dispatches; a direct `skill_preflight_update(task, "implement", session,
  "monotonic-max")` call against a scratch fixture (the exact call the live path makes) confirmed
  `status` stays `"hold"` afterward.
- A set-then-lift round trip (`test-update-task-status.sh` Case 14, plus a manual scratch-fixture
  repeat) restores the exact `prior_status` and leaves no residual `hold_reason`/`held_at`/
  `prior_status` keys.

## Impacts

- Any task hand-set to `status: "hold"` (in this repo or any consumer repo sharing this source
  store) now validates, renders, and is excluded from dispatch — no migration needed for
  pre-existing hand-written values.
- `/orchestrate`, `/research`, `/plan`, `/implement` all now respect a hold; `/revise` remains
  exempt by design.
- An operator can pause and resume a task via `update-task-status.sh preflight <N> hold
  --hold-reason=<string>` / `update-task-status.sh preflight <N> unhold`.

## Follow-ups

- This repo's own `.claude/` deploy tree should be redeployed once the sibling batch's own deploy
  coordination completes, which will clear the two stale-copy test failures noted above (no code
  change required — purely a deploy-timing artifact).
- The pre-existing, out-of-scope `commands/orchestrate.md` STAGE 0 terminal-arm
  `$FORCE_PHASES_FLAG` gap (flagged by research, deliberately not fixed here) remains open for a
  future task.
- The consumer repo's regenerated `specs/TODO.md` is left as an uncommitted working-tree change
  for that repo's own session/owner to commit.

## References

- `specs/293_add_hold_task_status_marker/reports/01_hold-task-status-marker.md`
- `specs/293_add_hold_task_status_marker/plans/01_hold-task-status-marker.md`
- `agent-system/extensions/core/context/standards/status-markers.md` (`#### [HOLD]` section)
- `agent-system/extensions/core/context/reference/state-management-schema.md` (`### Hold Fields`)
