# Implementation Summary: Task #314

- **Task**: 314 - Make the unconsumed-dispatch replay decide its dispatch_seq BEFORE the seq is minted and before the dispatch file is composed
- **Status**: [COMPLETED]
- **Started**: 2026-10-02T13:37:18Z
- **Completed**: 2026-10-02T14:34:00Z
- **Effort**: ~5 hours (as estimated)
- **Dependencies**: None
- **Artifacts**: plans/01_replay-seq-hoist-mechanics.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Fixed the unconsumed-dispatch replay branch in `orchestrate-cycle-plan.sh`, which previously
rewrote `mt_json.dispatch_seq[$t]` roughly 140 lines after `orchestrate-build-dispatch.sh` had
already composed the dispatch file with a freshly minted seq -- causing the composed file and
state to permanently disagree and silently losing the status transition on every genuine
crash-recovery replay. The replay decision is now made before the mint and before the dispatch
file is composed, so exactly one seq is ever in play per row. A post-compose Identity-vs-state
consistency assertion was added as a loud backstop, and Group 19 of
`test-orchestrate-cycle-plan.sh` was extended with a four-leg seq-agreement check that reads the
composed dispatch file directly -- something no assertion in the suite did before this task,
which is exactly why the original defect shipped green.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` -- hoisted the replay
  decision (`_pd_replay`, `_pd_seq`, and the three inputs it depends on) above the dispatch_seq
  mint and above the `orchestrate-build-dispatch.sh` call; made the mint a two-way branch
  (replay reuses the recorded seq with no new global mint; non-replay mints exactly as before);
  added a gate requiring `mt_json.last_dispatch_hash[$t]` to be empty for a replay to be honored
  (a durable replay now applies only when this session has not already dispatched this task
  this run); added a post-compose assertion that parses the composed file's own
  `- dispatch_seq:` Identity line and defers the row loudly on any disagreement or
  missing/unparseable line.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` -- extended Group
  19 case 1 with a real-Identity-block `orchestrate-build-dispatch.sh` stub and four-leg
  seq-agreement assertions (composed file Identity, `mt_json.dispatch_seq[$t]`, a real
  `orchestrate-recover-outcome.sh` invocation, and the handoff seq predicate), plus an
  ephemeral-counter assertion; revised the pre-existing durable-counter assertion's comment to
  record why it alone gave false assurance; upgraded all 8 remaining `orchestrate-build-dispatch.sh`
  stubs across the suite to write real, byte-compatible Identity-bearing files (discovered
  necessity, see Deviations); fixed two further narrowly-scoped test collisions this exposed
  (Group 18's own two genuinely-separate charges colliding with Fix 2's identical-dispatch halt;
  the budget group's seq-no-repeat case exercising a legitimate replay it mis-read as a
  regression).
- `specs/314_replay_seq_decided_before_dispatch_compose/reports/01_replay-seq-hoist-mechanics.md`
  -- appended an "Argued correction, as implemented" note recording the final D1/D2 wording and
  a correction to the report's own Finding 3 about the "move verbatim" instruction turning out
  insufficient.
- Regenerated `.claude/scripts/orchestrate-cycle-plan.sh` and
  `.claude/scripts/tests/test-orchestrate-cycle-plan.sh` via `deploy-headless.sh` (gitignored
  deploy artifacts; no tracked churn).

## Decisions

- DELIVERABLE 1 option (a) (hoist the decision) implemented as settled at plan time; the
  reuse-the-recorded-file-verbatim alternative remained rejected on the per-cycle-varying-input
  grounds (territory/focus/phase-number/model) the plan already argued.
- D1/D2 scope rulings from the plan (option (b)-minimal four-leg demonstration; Legs 3/4 stand in
  for the `state.json` transition) implemented exactly as settled.
- Added one condition to the replay predicate beyond the plan's literal "move verbatim" text: a
  durable replay is honored only when `mt_json.last_dispatch_hash[$t]` is empty (this session has
  not already dispatched this task this run). Discovered via the plan's own RED-first/full-suite
  methodology applied rigorously at every phase (not just Phase 1) -- hoisting the decision ahead
  of Fix 2's identical-dispatch halt check removed an accidental ordering shield that previously
  kept the two mechanisms from ever colliding. Argued in full in the plan's Phase 2 section and
  the report's Finding 3 correction.

## Plan Deviations

- **Phase 2** altered: the replay predicate gained one additional guard condition (empty
  `last_dispatch_hash[$t]`) beyond the plan's literal "move verbatim; do not restructure the
  predicate" instruction, to avoid a genuine regression in Group 28 (identical-dispatch halt)
  that the plan's own research did not anticipate. Root-caused with a standalone repro harness;
  reasoning recorded in the plan and the orchestrate-cycle-plan.sh comment at the decision block.
- **Phase 3** altered/extended: in addition to the single-file production change the plan's
  Files-to-modify list named, 8 of the 9 `orchestrate-build-dispatch.sh` test stubs across
  `test-orchestrate-cycle-plan.sh` had to be upgraded to write real, Identity-bearing files
  (mirroring Group 19's own Phase 1 stub) because DELIVERABLE 2's new production check reads the
  composed file's content, and most pre-existing stubs returned a notional, never-written
  `/fake/...` path -- harmless before this task, fatal to the new "missing Identity line is a
  loud disagreement, never a pass" contract. This in turn required 5 assertion updates (Groups
  15/16/18's literal path checks) and two further narrow fixes (a per-call nonce in Group 18's
  stub to avoid a false identical-dispatch collision with Fix 2; consuming run 1's dispatch file
  in the G8 budget group's seq-no-repeat case, which was itself exercising a legitimate replay).
  All reasoning recorded in the plan's Phase 3 deviation note and in code comments.

## Verification

- Build: N/A (bash scripts; `bash -n` parses clean on every edit)
- Tests: Passed -- `test-orchestrate-cycle-plan.sh` exits 0, 335 passed, 0 failed (exact match
  against Phase 1's RED-run total of 330+5=335; nothing disappeared). Six sibling orchestrate
  suites that exercise `orchestrate-cycle-plan.sh` as their SUT (`test-handoff-reader-parity.sh`,
  `test-orchestrate-unwind-dispatch.sh`, `test-force-phases.sh`,
  `test-orchestrate-context-growth.sh`, `test-routing-resolution.sh`,
  `test-mint-dispatch-seq.sh`) all pass with zero failures.
- Files verified: Yes -- deployed `.claude/scripts/orchestrate-cycle-plan.sh` and
  `.claude/scripts/tests/test-orchestrate-cycle-plan.sh` confirmed to contain the new code and
  independently pass the full suite (335/0) against their own `CORE_DIR` anchor.
- shellcheck: clean (`-S warning`) on both touched files -- zero new findings; the 4 warnings
  present (2 per file) are confirmed pre-existing against the pre-task commit.
- Manual verification: deliberately perturbed the Group 19 stub's Identity seq, confirmed the
  production code defers the row with an explicit, readable reason and no dispatch row, then
  reverted the perturbation (diff confirmed byte-identical afterward).

## Impacts

- A crash-recovery replay of an unconsumed dispatch (phase/forced match, recorded dispatch_file
  still on disk) now produces exactly one seq across the dispatch file's Identity block,
  `mt_json.dispatch_seq[$t]`, the handoff seq check, and `.return-meta.json`'s seq check --
  closing the data-loss path observed in the originating incident (a correct, completed plan
  left `state.json` stuck at `planning` with `plan_path` null, and the next cycle queued a
  redundant re-plan).
- A future seq-decided-after-compose-style regression in this file is now caught loudly (a
  DEFERRED row with an explicit, greppable reason) rather than silently shipping, independent of
  whether the replay hoist itself stays correct through future edits.
- The durable `dispatch_seq_counter` and the ephemeral `mt_json.dispatch_seq_counter` now agree
  by construction after a replay (no double-mint, no divergence, no later run able to re-mint a
  value already used as a dispatch filename).

## Follow-ups

- None required by this task. Two items are explicitly out of scope and filed separately per the
  dispatch's own Territory/Non-Goals: the postflight-side defect-attribution and
  report-vs-persist-divergence follow-ups (separate task, no shared files), and task 250's
  decomposition of `orchestrate-cycle-plan.sh` into `lib/` (ordering constraint recorded in the
  plan's Risks table: whichever of the two lands second must carry the other's change along).

## References

- `specs/314_replay_seq_decided_before_dispatch_compose/reports/01_replay-seq-hoist-mechanics.md`
  (research report, with the "Argued correction, as implemented" note appended at Phase 5)
- `specs/314_replay_seq_decided_before_dispatch_compose/plans/01_replay-seq-hoist-mechanics.md`
  (implementation plan, all 6 phases `[COMPLETED]`, deviations argued inline)
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (the fixed source)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` (extended Group 19,
  upgraded stubs, revised/new comments)
