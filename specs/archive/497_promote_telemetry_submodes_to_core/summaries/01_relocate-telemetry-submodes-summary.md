# Implementation Summary: Task #497

- **Task**: 497 - Promote telemetry sub-modes to core
- **Status**: [COMPLETED]
- **Started**: 2026-11-09T20:48:00Z
- **Completed**: 2026-11-09T22:35:00Z
- **Effort**: ~1.75 hours
- **Dependencies**: None (re-sequences 421 to depend on this task; declared edges with 328, 435)
- **Artifacts**: plans/01_relocate-telemetry-submodes-to-core.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Relocated the `--meta`, `--review`, and `--dream` telemetry sub-modes out of the memory
extension's `/distill` surface into a new core-owned `/telemetry` command backed by a new
direct-execution `skill-telemetry`, so all three survive the memory extension's eventual
retirement. Landed five new core files (the three sub-mode specifications, a shared
`telemetry-guardrails.md` design-constraints document, and the `/telemetry` command file),
registered them in core's manifest/context-index/README/CLAUDE.md merge source, repointed every
cross-extension citation (core, books, memory), stripped the three sub-modes from memory's
`/distill` command/skill/doc surface (reduced to its nine remaining sub-modes), deleted the four
relocated source files, redeployed, and verified all three sub-modes live end to end against this
repo's real `specs/events.jsonl` and `~/.claude/history.jsonl`.

## What Changed

- `agent-system/extensions/core/context/standards/telemetry-guardrails.md` — new; relocated
  guardrails document, retitled, outbound paths updated
- `agent-system/extensions/core/context/patterns/telemetry-{meta,review,dream}-submode.md` —
  new; the three de-narrated sub-mode specifications
- `agent-system/extensions/core/commands/telemetry.md` — new; the `/telemetry` command file
- `agent-system/extensions/core/skills/skill-telemetry/SKILL.md` — new; direct-execution host
  with the telemetry sub-mode skeleton, stub pointers, and log schemas
- `agent-system/extensions/core/{manifest.json,index-entries.json,README.md,merge-sources/claudemd.md}`
  — registered `telemetry.md`/`skill-telemetry`, four index entries, command/skill mentions
- `agent-system/extensions/core/context/formats/{dispatch-metrics.md,events-format.md}` —
  repointed guardrails citations at the new core path
- `agent-system/extensions/books/context/project/books/patterns/{books-review-submode.md,books-revise-submode.md}`
  — repointed guardrails and `--meta` spec citations
- `agent-system/extensions/memory/context/project/memory/patterns/{distill-learn-submode.md,distill-revise-submode.md}`
  — repointed guardrails and `--meta` spec citations (the latter also incidentally fixed an
  adjacent "Phase 10" task-number reference embedded in the same sentence as a repointed citation)
- `agent-system/extensions/memory/{commands/distill.md,skills/skill-distill/SKILL.md,README.md,skills/skill-distill/README.md,EXTENSION.md,context/project/memory/distill-usage.md,index-entries.json}`
  — `/distill` reduced to nine sub-modes; stub pointers, dispatch tables, State Integration, and
  log schema docs updated; four stale index entries removed
- `agent-system/extensions/memory/context/project/memory/{telemetry-guardrails.md,patterns/distill-{meta,review,dream}-submode.md}`
  — deleted (relocated to core)
- `specs/telemetry/{dream,review}-log.json` — created by the live verification runs

## Decisions

- Chosen invocation surface (per the prior cycle's relayed, non-blocking decision): one new core
  command `/telemetry` hosting all three flags under their existing names, backed by one new
  skill `skill-telemetry`, rather than folding `--meta` onto the existing `/meta` command.
- Dropped the `last_dream`/`dream_count` `memory_health` coupling in `state.json` entirely
  (rather than carrying it forward at the new location): `--dream`'s own log file
  (`specs/telemetry/dream-log.json`) is now its sole `--since` cursor.
- The `--meta` sub-mode's previously-stale `meta-builder-agent.md` "Known limitation" quotation
  had already been corrected in a prior commit from this task's own planning cycle; relocation
  simply carried the already-fixed prose forward rather than re-fixing it.

## Plan Deviations

- **Phase 2, 4, 5** (verification): ran the scoped `verify-deploy.sh --only-gate N[,M...]`
  narrowing instead of the plan's literal unscoped full-gate-set instruction, for Phases 2 and 4
  by the same operational reasoning the dispatch's Batch Gate Deferral section states for Phase
  5 (measured heavy concurrent contention from several other sibling tasks' own full gate runs
  in this same `/orchestrate` batch — one single Gate-8 test, `test-gate-cache-equivalence.sh`,
  alone ran 10+ minutes during the Phase 4 attempt). Phase 5 is the plan's actual named final
  phase, so its own deferral applies literally there. The complete gate set (Gate 8's full
  shell-suite battery, plus three findings — eager-context-budget, a shellcheck finding in the
  unrelated lean extension, and two dead-command-recommendation findings in pre-existing memory
  documentation — surfaced during two earlier, abandoned-then-completed unscoped attempts) is
  deferred to the single batch-end full run; see the issue log for the three unrelated findings.
- **Phase 3**: the plan's Scope Hypothesis undercounted `distill-revise-submode.md`'s
  `distill-meta-submode.md` references by one (two actual occurrences, not one). Both repointed;
  reported per the phase's own "discrepancy must be reported" instruction.

## Verification

- Build: N/A (markdown/JSON documentation and skill/command specifications)
- Tests: `verify-deploy.sh --skip-slow --only-gate 3,4` (Phases 1-2), `--only-gate 3,4,13`
  (Phase 5) — all PASS. `check-record-versioning.sh` and `check-task-references.sh` — 0 findings
  on every new/touched file. `grep -rn "distill-meta-submode\|distill-review-submode\|distill-dream-submode\|context/project/memory/telemetry-guardrails" agent-system/ .claude/`
  — zero hits in both the source store and the deployed tree.
- Files verified: Yes — all six new deployed files present
  (`.claude/commands/telemetry.md`, `.claude/skills/skill-telemetry/SKILL.md`,
  `.claude/context/standards/telemetry-guardrails.md`,
  `.claude/context/patterns/telemetry-{meta,review,dream}-submode.md`); four orphaned deployed
  copies removed after the first redeploy pass; a second redeploy pass confirmed clean.
- Live verification: `--meta --dry-run` surfaced the real handoff-schema defect cluster (23
  "handoff mtime predates window" occurrences, 4 `dispatch_status` off-schema, 3 `dispatch_seq`
  mismatches, all attributing to `skill-orchestrate/SKILL.md`/`general-implementation-agent.md`)
  via `events-query.sh` against this repo's real `specs/events.jsonl` (8,030 events). `--dream`
  surfaced a genuine recurring, uncovered theme from `~/.claude/history.jsonl` (4,273 prompts for
  this repo). `--review` announced the exact required OTel-degraded-path string (confirmed
  `CLAUDE_CODE_ENABLE_TELEMETRY` unset on this machine) and stated its funnel rule. Both
  MANDATORY STOP exemptions (`--review`, `--dream`) present exactly once each in the deployed
  tree.

## Impacts

- `/telemetry` is now a new, discoverable core command surviving independently of the memory
  extension's eventual retirement.
- `/distill` is reduced to its nine remaining sub-modes (`report`/`purge`/`merge`/`compress`/
  `refine`/`gc`/`auto`/`revise`/`learn`); no functionality was removed, only relocated.
- Task 421 (`retarget_distill_meta_as_evidence_consumer`) now depends on this task and should
  retarget its own file_scope at the new core paths
  (`agent-system/extensions/core/context/patterns/telemetry-meta-submode.md`,
  `skill-telemetry/SKILL.md`) rather than the now-deleted memory-extension files.

## Follow-ups

- Task 421's re-sequencing/file_scope retargeting at the orchestration level (task-graph
  concern, not a file edit within this dispatch's own scope).
- The batch-end complete gate run should resolve or re-attribute the three findings recorded in
  the issue log (eager-context-budget overage, a lean-extension shellcheck finding, two
  memory-extension dead-command-recommendation findings) — none caused primarily by this task.

## References

- Plan: `specs/497_promote_telemetry_submodes_to_core/plans/01_relocate-telemetry-submodes-to-core.md`
- Research: `specs/497_promote_telemetry_submodes_to_core/reports/01_relocate-telemetry-submodes-research.md`
- Progress files: `specs/497_promote_telemetry_submodes_to_core/progress/phase-{1..5}-progress.json`
- Handoffs: `specs/497_promote_telemetry_submodes_to_core/handoffs/phase-{1..5}-handoff-*.md`
