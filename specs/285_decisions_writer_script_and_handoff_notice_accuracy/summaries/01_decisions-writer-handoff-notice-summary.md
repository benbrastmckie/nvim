# Implementation Summary: Task #285

- **Task**: 285 - Decisions writer script and handoff notice accuracy
- **Status**: [COMPLETED]
- **Started**: 2026-10-03T22:08:00Z
- **Completed**: 2026-10-03T23:15:00Z
- **Effort**: ~4.5 hours
- **Dependencies**: None (task 334 was a concurrent sibling with no file overlap)
- **Artifacts**: plans/01_decisions-writer-handoff-notice.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, shell-strict-mode.md

## Overview

Two lead-facing contract-surface defects in the `/orchestrate` loop were closed independently.
Defect 1 (Phases 1-4) replaced hand-authored `.decisions.json` JSON with a single, flock-guarded
writer script (`orchestrate-record-decision.sh`) and repointed `skill-orchestrate/SKILL.md`'s
Move 4 at it, so the lead never hand-authors the file again. Defect 2 (Phases 5-6) established
the true per-phase `.orchestrator-handoff.json` writer predicate by mechanical sweep (research
never writes one, in any mode; plan and implement write one whenever `orchestrator_mode: true`,
independent of hard/base mode) and corrected both the live postflight notice and every
documentation/schema site that had stated the false "hard-mode-implement-only" framing as fact.
All work is confined to `agent-system/extensions/core/**` (the source store); `.claude/` was
never deployed, matching the plan's explicit Non-Goal.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-record-decision.sh` (new) — the sanctioned
  `.decisions.json` writer: `--task N --session SID --cycle C --question TEXT --answer TEXT`,
  flock-guarded read→merge→validate→atomic-mv, refuses a malformed/object-wrapped existing
  document and leaves it byte-identical on any failure.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-record-decision.sh` (new) — 9-case
  regression suite (lazy creation, additive append, shape conformance, 15-way concurrency,
  object-wrapper refusal, missing-argument/non-integer-cycle rejection, reader-compat, unresolvable
  task).
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` — added `decisions-lock` as
  the 20th runtime ephemeral-pattern class member, across all six parallel arrays.
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` — fenced block
  and per-file table updated to match.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-unwind-dispatch.sh` — fixture
  gitignore block updated; `test-runtime-file-tracking.sh` — hardcoded 19→20 member-count
  assertion updated (a 4th verbatim-count carrier found beyond the plan's named three).
- `agent-system/extensions/core/manifest.json` — registered both new scripts in
  `provides.scripts`.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Move 4 now instructs calling
  the script instead of hand-authoring the schema (179 B → 166 B; file now measures 19,921 B,
  under its 20,000 B ceiling).
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — Writer paragraph (Move 4
  reference) plus 5 factual-predicate sites corrected (top summary, Handoff Writers
  paragraph+table, Outcome Channels with an explicit divergence note, When to Write).
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — new bullet for the
  writer script.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — the no-handoff notice
  at the `recovered=true` branch now splits by `$phase`: research gets an informational `NOTE:`
  tag (no `RECOVERY:` token); plan/implement keep `RECOVERY:` and name their own phase.
- `agent-system/extensions/core/scripts/orchestrate-stage5-gates.sh` — orphaned duplicate notice
  de-falsified (false parenthetical removed, kept phase-agnostic, no interface change).
- `agent-system/extensions/core/context/patterns/infra-failure-discrimination.md` — corrected the
  same claim in place.
- `agent-system/extensions/core/context/schemas/orchestrator-handoff-schema.json` — `description`
  prose corrected (structural keys unchanged, confirmed by `git diff`).
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` and
  `agent-system/extensions/core/scripts/skill-base.sh` — two additionally-discovered comment
  sites asserting the same false claim, corrected.
- `agent-system/extensions/core/index-entries.json` — two `line_count` repairs
  (`orchestrator-runtime-files.md` 539→541, `infra-failure-discrimination.md` 134→136), mechanical
  consequences of this task's own edits to those files.

## Decisions

- `orchestrate-record-decision.sh` uses exit code 1 for argument/validation errors and exit code
  2 for existing-or-merged-document shape failures — a refinement beyond `errors-append.sh`'s
  single exit-1 convention, documented in the script's own header.
- Introduced a new `NOTE:` tag in `orchestrate-cycle-postflight.sh`'s vocabulary for the expected
  research no-handoff case, since none of the existing tags (ADVISORY/ERROR/EVIDENCE/WARN/WARNING)
  fit without semantic collision (ADVISORY is already claimed for the unrelated
  file_scope-excursion finding).
- Corrected `handoff-schema.md`'s "one channel per mode" framing with an explicit divergence note
  rather than silently rewriting the decision record, per the plan's Non-Goal — the broader
  design-reconciliation question (whether the architecture itself should change) is left as an
  observation, not resolved.
- Left `agents/general-research-agent.md:241`'s own "hard-mode-implement-only" phrasing untouched
  — an explicit Non-Goal, confirmed present in all ~23 research agents (a shared-template
  artifact, not a 5-file-only occurrence as the Non-Goal's prose suggested).

## Plan Deviations

- **Phase 1**: found and fixed a 4th verbatim-count carrier beyond the plan's named three —
  `test-runtime-file-tracking.sh` Case 5's hardcoded "19 class members" assertion.
- **Phase 3**: added a 9th test case beyond the plan's named eight (unresolvable task number).
- **Phase 4**: discovered and fixed a stale `index-entries.json` line_count for
  `orchestrator-runtime-files.md`, a mechanical consequence of Phase 1's own edit.
- **Phase 6**: the re-grep footprint was materially larger than the plan's 3-file hypothesis — 2
  additional sites (`orchestrate-recover-outcome.sh`, `skill-base.sh`) asserted the identical
  falsehood and were fixed so the acceptance criterion holds; a 5th false-claim site inside
  `handoff-schema.md` itself (the top-of-document "Written by" summary) was also corrected beyond
  the plan's named four; a second `index-entries.json` line_count repair followed the same pattern
  as Phase 4's.
- **Phase 7**: a self-caught-and-corrected mistake in the `.claude/` temp-sync-for-testing
  procedure (restored from current `HEAD` instead of the pre-task commit partway through;
  corrected before any gate ran against the mistaken state — see that phase's progress file).

Full per-phase detail in `progress/phase-{1..7}-progress.json`'s `deviations` arrays.

## Verification

- Build: N/A (meta task, no build system)
- Tests: Passed — 9/9 (`test-orchestrate-record-decision.sh`), 166/166
  (`test-orchestrate-cycle-postflight.sh`), 9/9 (`test-runtime-file-tracking.sh`), 23/23
  (`test-init-specs.sh`), 21/21 (`test-orchestrate-unwind-dispatch.sh`), plus 7/7
  (`test-orchestrate-recover-outcome.sh`) and 48/48 (`test-skill-base-lifecycle.sh`) as collateral
  confirmation for the two additionally-discovered Phase 6 sites.
- Files verified: Yes — all 17 touched/created source-store files confirmed on disk;
  `.claude/` confirmed byte-identical to the pre-task commit (`ed7d50e05`) throughout, never
  deployed.

### Acceptance Walk-Through

| Acceptance item | Demonstrated by |
|---|---|
| Lead records a decision with one documented script call, no JSON-shape knowledge | `skill-orchestrate/SKILL.md` Move 4's rewritten sentence; `orchestrate-record-decision.sh --task N --session SID --cycle C --question TEXT --answer TEXT` functional smoke test |
| Malformed `.decisions.json` unreachable through the sanctioned path | `test-orchestrate-record-decision.sh` case (e): object-wrapped file refused, byte-identical |
| New script registered in utility-scripts inventory | `docs/reference/utility-scripts-inventory.md` bullet added |
| SKILL.md Move 4 cites the script instead of the prose schema | `grep -n 'decisions.json' skills/skill-orchestrate/SKILL.md` — only the dispatch-rendering reference at line 64 survives |
| Handoff notice's phase claim verified against the writers and matches | Mechanical sweep: 22/22 research agents, 19/20 implement/planner agents (1 documented exception) — recorded in Phase 5's commit message |
| Expected/unexpected cases distinguishable at a glance | Manual scratch-sandbox exercise: research → `NOTE:` only; plan/implement → `RECOVERY:` naming their own phase |
| shellcheck clean per shell-strict-mode.md | All 9 touched/created shell files: every finding info-level or confirmed pre-existing via diff against HEAD |

## Impacts

- A lead running `/orchestrate` and relaying a batched `AskUserQuestion` answer now calls one
  script instead of hand-authoring JSON — removing the exact failure mode observed live
  (2026-09-30, session `sess_1790791567_96a2e0`: an object-wrapped `.decisions.json` aborted the
  dispatch-build reader and silently deferred the task for two cycles).
- The postflight no-handoff notice no longer tells a lead "RECOVERY" and "expected" in the same
  breath for research, and no longer falsely claims plan/implement never write a handoff — a lead
  reading cycle output can now distinguish a normal research-phase fallback from a genuine
  plan/implement writer defect.
- `docs/architecture/handoff-schema.md`'s "Outcome Channels" section now states a divergence
  explicitly rather than leaving a silently-false "one channel per mode" claim; a future reader
  of that document will see the correction and its own Non-Goal note about the architecture
  question it leaves open.

## Follow-ups

- `.claude/` regeneration (manual-only, per `context/patterns/regeneration-is-manual-only.md`) —
  the next deploy will pick up all 17 source-store files, including the two new scripts (both
  currently show as "never deployed" advisories in `check-extension-docs.sh`).
- The consequent `specs/.gitignore` managed-block refresh via `init-specs.sh`, which only takes
  effect after that same future redeploy.
- The reader-side `jq 'length'` type-safety gate at `orchestrate-build-dispatch.sh:389-392` is
  owned elsewhere (recorded as a jq type-safety instance on a separate task) — explicitly not
  touched here.
- The "hard-mode-implement-only" phrasing inside research agents' own "never write one"
  subsections (confirmed present in ~23 files, not 5) remains an open, explicitly-scoped-out
  secondary inaccuracy.
- Whether `handoff-schema.md`'s broader one-channel-per-mode design narrative should be
  reconciled with (rather than merely factually corrected against) the verified predicate is
  logged as an open design question, not resolved by this task.

## References

- Plan: `specs/285_decisions_writer_script_and_handoff_notice_accuracy/plans/01_decisions-writer-handoff-notice.md`
- Report: `specs/285_decisions_writer_script_and_handoff_notice_accuracy/reports/01_decisions-writer-handoff-notice.md`
- Progress: `specs/285_decisions_writer_script_and_handoff_notice_accuracy/progress/phase-{1..7}-progress.json`
- Handoffs: `specs/285_decisions_writer_script_and_handoff_notice_accuracy/handoffs/phase-4-handoff-20261003T225200Z.md`
