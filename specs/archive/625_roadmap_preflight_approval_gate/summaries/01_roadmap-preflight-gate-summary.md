# Implementation Summary: Task #625

- **Task**: 625 - Roadmap preflight approval gate
- **Status**: [COMPLETED]
- **Started**: 2026-11-13
- **Completed**: 2026-11-13
- **Effort**: ~5.5 hours (6 phases)
- **Dependencies**: None
- **Artifacts**: plans/01_roadmap-preflight-gate.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added a preflight gate that sits strictly in front of `roadmap-integration.sh`'s write modes.
A new shared library classifies `specs/ROADMAP.md` into `absent`/`unknown`/`classic`/`stage`
before any write-mode call, and mechanically scaffolds the classic eight-header skeleton on
approval. Both existing write-mode callers are now gated — an interactive `AskUserQuestion`
approval in `skill-roadmap`'s own pre-dispatch execution, and a loud, non-silent, non-writing
degrade (named warning + `events.jsonl` + best-effort per-task `issues.jsonl`) at
`/orchestrate`'s conclusion stage — so the previously-unescalated `--regenerate` refusal can no
longer leave `roadmap_batches`/`roadmap_notes` judgment stuck in `state.json` for weeks without
ever rendering.

## What Changed

- `agent-system/extensions/core/scripts/lib/roadmap-preflight-lib.sh` — new library: the
  layout-classification vocabulary moved verbatim from `roadmap-integration.sh`
  (`CLASSIC_HEADERS`, the fence helpers, `detect_layout`), plus `roadmap_preflight_classify`
  (four-way verdict, always exit 0), `roadmap_preflight_scaffold` (mechanical classic skeleton;
  preserves prior content verbatim on `unknown`; refuses non-destructively on `classic`/`stage`),
  and a `BASH_SOURCE` run-as-script CLI guard (`classify PATH` / `scaffold PATH`).
- `agent-system/extensions/core/scripts/roadmap-integration.sh` — sources the library back;
  deleted its own four moved definitions; zero duplicate copies remain.
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` — added a
  deploy-tree-first dependency resolution and `build_scratch` population for the new library,
  plus a 13-case preflight-library regression section (all four classify verdicts, both scaffold
  cases, the classic/stage refusal, and scaffold-then-regenerate idempotence).
- `agent-system/extensions/core/manifest.json` — declared the new library under
  `provides.scripts`.
- `agent-system/extensions/core/skills/skill-roadmap/SKILL.md` — `AskUserQuestion` added to
  `allowed-tools`; Stage 1 now classifies before dispatch and gates `absent`/`unknown` with a
  single approval question (modeled on `skill-meta/SKILL.md` Section 2), scaffolding on approval
  or stopping cleanly on decline; Stage 3's second warning now points back at the Stage 1
  preflight; the MUST NOT list's items 3/4 carry an explicit scaffold carve-out.
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` — Step 5 now classifies
  before `--regenerate`; on `absent`/`unknown` it skips the write entirely and degrades at three
  surfaces (a named warning, an `events-append.sh` record written first, then a best-effort
  per-task `issue-record.sh` loop) rather than silently skipping or auto-writing.
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` — Move 5's
  Bash allow-list gained `lib/roadmap-preflight-lib.sh classify` and `issue-record.sh`; a new
  Prohibited bullet bars `scaffold` at this stage (classify-only; no approver present).
- `agent-system/extensions/core/context/patterns/roadmap-update.md` — new "Preflight Obligation"
  section documenting the gate as every write-mode caller's duty; "Live Callers" corrected from
  one to two (`/orchestrate` conclusion stage and `roadmap-agent.md`'s own pre-existing Write
  Contract); the hard constraint (never weakens/bypasses the refusal; scaffold is the only
  sanctioned write) stated explicitly.
- `agent-system/extensions/core/scripts/lint/lint-roadmap-batch-proposals.sh` — routed its own
  layout sniff through the new library (`detect_layout`) instead of a second hand-transcribed
  copy of `CLASSIC_HEADERS`/`is_classic_layout`/`is_stage_layout`; see Plan Deviations.
- `agent-system/extensions/core/index-entries.json` — regenerated `line_count` rows for the three
  edited context files (`roadmap-update.md`, `conclusion-stage.md`,
  `postflight-tool-restrictions.md`); `generate-context-line-counts.sh --check` reports zero
  drift.

## Decisions

- Extracted the classification vocabulary into a sourced library rather than sourcing
  `roadmap-integration.sh` directly, because that script parses `$@` and calls `exit` at top
  level with no run-as-script guard — sourcing it would run its argument parser against the
  caller's own `$@`.
- The four-way verdict space (`absent` checked before `detect_layout`'s three-way result) lives
  in the library's public entry point, so neither gated caller re-derives file existence itself.
- The gate fires on exactly two verdicts (`absent`/`unknown`); `classic`/`stage` proceed
  ungated, unchanged.
- Move 5 degrades loudly rather than adding a third `AskUserQuestion` key to the conclusion
  stage's approval ledger — the write is not time-critical, since the next interactive
  `/roadmap` resolves it via its own gate.

## Plan Deviations

- **Phase 6** (altered): the plan's files-to-modify list for Phase 6 did not name
  `scripts/lint/lint-roadmap-batch-proposals.sh`, but Phase 6's own verification criterion
  (`grep -rn CLASSIC_HEADERS` returns exactly one definition site) failed against the as-planned
  file set — this lint script carried a second, deliberately hand-transcribed copy of the
  vocabulary, justified in its own header comment by `roadmap-integration.sh` being unsafe to
  source. That rationale no longer holds once a safe-to-source library exists for exactly this
  purpose, so the lint was updated in-phase to source the library and call `detect_layout`
  directly, closing the duplicate rather than leaving the plan's own verification criterion
  unsatisfied.

## Verification

- Build: N/A (no compiled artifacts)
- Tests: Phase-scoped suite runs all green (`test-roadmap-generation.sh` 106/106 including the
  13 new preflight cases; `test-orchestrate-conclusion-aggregate.sh`; the 7-suite union covering
  every Phase 6 touched file that maps to a concrete suite). Full `run-all.sh`/`verify-deploy.sh`
  deliberately deferred to the once-per-invocation batch gate stage per this dispatch's Batch
  Gate Deferral directive — see each phase's own progress-file notes for the scoped discharge
  actually run in this dispatch.
- Files verified: Yes — `bash -n` and `shellcheck` clean on every edited/new shell file;
  `generate-context-line-counts.sh --check` reports zero drift; the repo-wide
  `CLASSIC_HEADERS` grep returns exactly one definition site; `roadmap-format.md`'s
  Destructive-Overwrite Refusal section carries no diff and no `--force` path exists anywhere in
  `roadmap-integration.sh`.

## Impacts

- A consumer repo whose `specs/ROADMAP.md` is absent or unknown-layout can no longer silently
  accumulate unrendered `roadmap_batches`/`roadmap_notes` judgment — the write is either
  explicitly approved and scaffolded, or the gap is surfaced loudly (named warning,
  `events.jsonl`, best-effort `issues.jsonl`) rather than hidden behind a soft `WARNING:` echo
  that propagated no non-zero status.
- `scripts/lint/lint-roadmap-batch-proposals.sh` now tracks the canonical layout vocabulary
  automatically instead of risking silent drift between two hand-maintained copies.

## Follow-ups

- Two pre-existing, unrelated issues surfaced by this dispatch's wider suite selections were
  recorded via `issue-record.sh` rather than fixed here (out of this task's declared file
  scope): (1) `test-deploy-propagation.sh`'s failure traces to a single task-reference-lint
  finding in `orchestrator-context-budget.json` last touched by an unrelated task; (2)
  `test-lint-roadmap-batch-proposals.sh`'s "real corpus: default resolution" case fails under
  `CORE_TEST_SUBJECT_MODE=source-store` due to a stray, empty, untracked
  `agent-system/extensions/core/specs/` directory confusing that script's own root-resolution
  walk-up — latent in the pre-edit script too, confirmed unrelated to this task's diff by
  hunk inspection.
- The deployed `.claude/` tree will show content drift against the source store for every file
  this task edited until the next deploy cycle runs; per this repository's own documented
  self-healing behavior, this requires no manual action from this task.

## References

- `specs/625_roadmap_preflight_approval_gate/plans/01_roadmap-preflight-gate.md`
- `specs/625_roadmap_preflight_approval_gate/reports/01_roadmap-preflight-gate.md`
- `agent-system/extensions/core/context/formats/roadmap-format.md`
- `agent-system/extensions/core/context/patterns/roadmap-update.md`
