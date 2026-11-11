# Implementation Summary: Task #499

- **Task**: 499 - Retarget the store-coupled distill sub-modes and retire the memory extension (Parts A, B, C, C2 only; Part D out of scope per the dispatch's SCOPE NARROWING section)
- **Status**: [COMPLETED]
- **Started**: 2026-11-10T00:00:00Z
- **Completed**: 2026-11-10T03:55:00Z
- **Effort**: ~4 hours
- **Dependencies**: 496 (completed), 497 (completed)
- **Artifacts**: plans/01_retarget-distill-submodes-and-cleanup.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Retargeted `/distill`'s two store-coupled sub-modes (`--revise`, `--learn`) onto the hosted
Sapience knowledge store, deleted the six sub-modes the hosted store already performs
server-side (`report`/`--purge`/`--merge`/`--compress`/`--refine`/`--gc`), removed the two
orphaned core scripts (`memory-retrieve.sh`, `memory-harvest.sh`) and their ~27 reference files,
stripped `/todo`'s archive-time memory harvest, and closed the tagged-write half of the sapience
retrieval loop so the already-live retrieval injection has a population to read. The memory
extension itself remains installed and registered, unchanged from before this task -- its
removal (Part D) is explicitly out of scope here, gated on a separate, paused operator decision
about email-Sapience integration. All seven plan phases are closed; Phase 7 closed
`[COMPLETED WITH EXCLUSIONS]` with four reasoned exclusions, none of which required accepting a
gap in this task's own deliverable (see Verification below).

## What Changed

- `agent-system/extensions/memory/context/project/memory/patterns/distill-revise-submode.md` --
  retargeted to the hosted store: inverted evidence-to-store correlation (Event Clustering ->
  Hosted-Store Correlation via `sapience-retrieve.sh`), a mandatory reachability probe, D1's
  SUPERSEDE/SKIP gate (replacing UPDATE/TOMBSTONE/SKIP) via `sapience-remember.sh`, and a run
  record moved from `.memory/revise-log.json` to a `specs/events.jsonl` event.
- `agent-system/extensions/memory/context/project/memory/patterns/distill-learn-submode.md` --
  apply step retargeted to `sapience-remember.sh` writes under a 3-8-note-per-task bound; run
  record likewise moved to `specs/events.jsonl`.
- Four pattern files deleted: `distill-purge-submode.md`, `distill-merge-submode.md`,
  `distill-compress-submode.md`, `distill-refine-submode.md`.
- `agent-system/extensions/memory/skills/skill-distill/SKILL.md` and
  `agent-system/extensions/memory/skills/skill-distill/README.md` -- pruned to the three
  surviving sub-modes (`auto`, `revise`, `learn`); the Scoring Engine, Composite Score, Health
  Score Formula, and Health Status Thresholds retained verbatim (`auto` still consumes them).
- `agent-system/extensions/memory/commands/distill.md` -- rewritten in full for the 3-sub-mode
  dispatch, with a new bare-invocation usage block (no default sub-mode).
- `agent-system/extensions/memory/context/project/memory/distill-usage.md` -- rebuilt with a
  "Why ... Are Not Here" section recording the hosted-store-already-does-this reasoning as a
  current-design fact.
- Two orphaned core scripts deleted (`agent-system/extensions/core/scripts/memory-retrieve.sh`,
  `memory-harvest.sh`), `core/manifest.json` pruned, and ~20 prose/test reference files
  repointed at `sapience-retrieve.sh` or corrected across `core/`, `email/`, `literature/`, and
  `sapience/`.
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` -- removed Stage 7
  (`HarvestMemories`) and Stage 14 (`CreateMemories`) in full, the Stage 8 preview line, and
  Stage 9's memory-harvest sub-step (renumbered consecutively); recorded the rationale as an
  inline comment.
- `agent-system/extensions/sapience/EXTENSION.md` -- postflight wrapup now writes 3-8 notes via
  `sapience-remember.sh` (replacing the untagged `sapience_wrapup` call), with the bound stated
  at the call site; file shrank on its own (2065 B -> 1875 B).
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` -- new
  call-site contract, D3 replace-not-both evidence, and no-lifecycle-hook constraint.
- `.claude/` (deployed tree) -- redeployed via `deploy-headless.sh`; six orphaned deployed files
  and four ghost `context/index.json` rows removed via targeted deletion (the sanctioned
  alternative to `--wipe` for an additive-only, non-destructive deploy).
- `.memory/` -- unchanged by this task, by design (confirmed against the pre-task baseline).

## Decisions

- D1 (plan): a contradicted `--revise` finding collapses UPDATE/TOMBSTONE into a single
  SUPERSEDE write, since the hosted store has neither a delete API nor in-place rewrite.
- D2 (plan): `--revise` inverts correlation direction (cluster evidence, then query per
  surviving cluster) rather than enumerating the hosted store, which offers no enumeration
  endpoint.
- D3 (plan): Part C2's tagged write *replaces* the untagged `sapience_wrapup` call rather than
  keeping both, since an unfiltered read already sees a tagged write, making it strictly more
  reachable than an untagged one.
- This implementation: applied `context/patterns/deploy-orphan-detection.md`'s documented
  "targeted removal of the specific orphan paths" alternative to a full `--wipe` regenerate,
  since the plan's chosen non-destructive deploy default is additive-only and never prunes a
  deleted source's deployed copy.
- This implementation: declined to force a live `/todo --dry-run` invocation or a live
  `total_events: 0` event-store trigger for `--revise`'s degraded path, since both are
  agent-followed instruction documents (not scripts) and forcing either live would require a
  heavyweight workflow dispatch or destructively truncating `specs/events.jsonl`; discharged both
  via static read-through plus the one directly-relevant test suite instead.

## Plan Deviations

- **Phase 2.2** altered: kept `distill-learn-submode.md`'s learn-harvest bookkeeping schema, but
  relocated its destination from `.memory/learn-harvest-log.json` to a `specs/events.jsonl`
  event, since the literal `.memory/` destination the plan named is itself a live write under
  the read-only vault this task's hard sequencing constraint forbids.
- **Phase 3 (extra)** altered: fixed two files outside the phase's declared list
  (`skill-distill/README.md`, `skill-learn/SKILL.md`) whose dangling references this phase's own
  deletions created, required by the phase's own residual-reference verification bullet.
- **Phase 4 (extra)** altered: fixed `sapience-retrieve.sh`'s header comments (not in the
  declared file list), required by the same residual-reference verification; also resynced two
  `index-entries.json` files' stale `line_count` declarations caused by this phase's own edits,
  carefully excluding four unrelated mismatches the same repo-wide regen tool surfaced from
  concurrent sibling tasks' own in-progress work.
- **Phase 4 (deferred)**: left `email-to-memory-preferences.md`'s section 5.1 citation of the
  now-deleted Purge Sub-Mode unresolved -- re-deriving the G4 guardrail design against a vault
  with no local purge/merge/compress/gc sub-modes is a substantive email-extension design
  change, outside this task's Non-Goals.
- **Phase 7** altered: manually removed six orphaned deployed files and four ghost index rows,
  via the deploy-orphan-detection pattern's own sanctioned alternative to `--wipe` (see Decisions
  above).

## Verification

- Build: N/A (no compiled artifact)
- Tests: `verify-deploy.sh` (complete gate set, no flags) ran twice to completion. 40 of 43
  checks PASS after the redeploy and targeted orphan removal. The 3 remaining non-PASS gates
  (gate 8 shell-suite battery, gate 10 state-schema timeout, gate 24 dead-command lint) and the
  one unconfirmed Part C2 write sub-item are each individually investigated and accounted for in
  the plan's Phase 7 `#### Reasoned Exclusions` table -- none traced to a file this task touched.
  `test-todo-move-pair-staging.sh` (directly exercises this task's `skill-todo/SKILL.md` edit):
  41/41 pass. `test-orchestrate-build-aux-dispatch.sh`, `test-manifest-scripts-sync.sh`,
  `test-script-inventory.sh` (exercise this task's core-script edits): all pass cleanly.
- Files verified: Yes -- `grep -rn 'memory-retrieve\.sh|memory-harvest\.sh' agent-system/`
  returns zero; both scripts and the four deleted pattern files are absent from both the source
  store and the deployed tree; `.memory/` unchanged from the task's starting baseline.

## Impacts

- Every research/plan/implement dispatch across all 25 migrated extension skills now reaches
  memory context through `sapience-retrieve.sh` (the hosted store) rather than the local vault.
- `/distill` now has 3 sub-modes instead of 9; a bare invocation prints usage rather than
  defaulting to a health report.
- `/todo` archival no longer performs a bulk memory-candidate harvest at archive time; that
  retroactive sweep is now exclusively `/distill --learn`'s, bounded and interactive.
- The sapience postflight wrapup now writes a tagged, retrievable note set per completed task
  instead of an untagged one invisible to repo-scoped reads -- closing the loop the retrieval
  side of this system has relied on since it shipped.

## Follow-ups

- **External service observation, recommend operator investigation**: `POST /ingest-kos`
  against the live Sapience host hangs indefinitely (confirmed up to 270 seconds) for real,
  coherent note content, while trivial/nonsense content gets fast responses. This was reproduced
  consistently and is unrelated to anything this task changed, but it means the tagged-write
  call site this task just wired may not actually land a write in practice until the underlying
  service issue is resolved. The call site's own degrade behavior (fail fast, log, never block
  postflight) was independently confirmed correct regardless.
- A subsequent dispatch should confirm `sapience-retrieve.sh` can see a note this task's own
  completed-task wrapup wrote (Phase 7's third Part C2 item, explicitly deferred to observation
  on a later dispatch by the plan's own design) -- contingent on the service issue above.
- Six shell-test-suite failures newly observed in gate 8 (`test-double-loading-check.sh` and
  five others) are plausibly caused by concurrent sibling tasks' in-progress edits to shared
  core infrastructure this same cycle; worth a quick recheck once those siblings land.
- Part D (removing the memory extension itself) remains gated on the paused email-preference
  harvest port / operator decision about Sapience email integration, as before this task.

## References

- Plan: `specs/499_retire_memory_extension/plans/01_retarget-distill-submodes-and-cleanup.md`
- Research: `specs/499_retire_memory_extension/reports/01_retarget-distill-submodes-and-cleanup.md`
- Progress files: `specs/499_retire_memory_extension/progress/phase-{1..7}-progress.json`
- Handoffs: `specs/499_retire_memory_extension/handoffs/phase-{1..7}-handoff-*.md`
- Issues: `specs/499_retire_memory_extension/issues.jsonl`
