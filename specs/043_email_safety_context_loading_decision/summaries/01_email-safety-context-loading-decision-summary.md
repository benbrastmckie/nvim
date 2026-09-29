# Implementation Summary: Email Safety Context-Loading Decision

- **Task**: 43 - Decide and implement how email safety context actually reaches agents (live defect: five inert safety pointers)
- **Status**: [COMPLETED]
- **Started**: 2026-09-29T02:04:12Z
- **Completed**: 2026-09-29T03:10:00Z
- **Effort**: ~1.1 hours
- **Dependencies**: 194 (archived/completed), 257 (archived/completed) — none blocking
- **Artifacts**: plans/01_email-safety-context-loading-decision.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Recorded decision (b) — the email extension's five "non-negotiable" safety domain files stay
on-demand reference material, deliberately not eager-loaded at any tier, because enforcement
already lives in `hooks/mail-guard.sh`, the nix-built wrapper binaries' own baked-in checks, and
inline copies duplicated in the four email skill/agent bodies. This closes the live defect where
`EXTENSION.md` told a reader to "see `domain/safety-invariants.md` before any `email` work" — an
imperative no consumer actually performs. All four phases are documentation-only, scoped entirely
to `agent-system/extensions/email/**`.

## What Changed

- `agent-system/extensions/email/context/project/email/domain/safety-invariants.md` — added a
  new `## Role and Loading Model` banner section (immediately after the H1) stating the file's
  on-demand, non-eager role, plus an `### Enforcement-Coverage Map` table mapping each of the
  file's 11 invariants to its inline consumer copy/copies and/or independent mechanical layer.
  No existing invariant content was altered (confirmed via `git diff`: zero deletions).
- `agent-system/extensions/email/EXTENSION.md` — replaced the opening paragraph's "Operating
  rules are non-negotiable — see `domain/safety-invariants.md` before any `email` work"
  imperative with wording stating the actual enforcement mechanism (the hook plus the wrapper
  binaries, plus inline consumer copies), and reframed `### Context Pointers` as explicitly
  read-on-demand reference, adding a line directing any future new email consumer to inline or
  explicitly `Read` the safety content it depends on. The five listed paths are unchanged in
  form (plain backticks, `.claude/`-prefixed, never promoted to `@`-imports).
- `agent-system/extensions/email/README.md` — updated the `safety-invariants.md` file-table row
  to name its on-demand/coverage-map role, and added the previously-missing
  `staleness-detection.md` row (one of the five `EXTENSION.md` pointers that had no README row).
- `agent-system/extensions/email/index-entries.json` — updated the `summary` field of the
  `project/email/domain/safety-invariants.md` entry to mention the loading model and the
  coverage map; also refreshed its `line_count` (102 -> 156) to match the file's new size
  (deviation from the literal task wording — see Plan Deviations).

## Decisions

- **Decision (b) holds unconditionally, full coverage, no gap**: Phase 1's enforcement-coverage
  map confirmed all 11 `safety-invariants.md` sections (not 5, as an earlier research draft had
  assumed) are each covered by at least one inline copy in one of the four consumer bodies
  (`agents/email-implementation-agent.md`, `skills/skill-email-cleanup/SKILL.md`,
  `skills/skill-email-sync/SKILL.md`, `skills/skill-email-implementation/SKILL.md`) and/or one
  independent mechanical layer (`hooks/mail-guard.sh`, or a baked-in wrapper-binary check). The
  decision gate therefore took the main branch, not the contingency branch — no invariant needed
  a conditional/gap phrasing in Phases 2-3.
- Coverage breadth varies by invariant and this is accepted, not a defect: `$PATH Precondition`
  is covered by all four consumers but zero mechanical layers; `Index-Freshness Gate`,
  `Default-Mode Cursor`, and `Archive Extra Gates` are each covered by only
  `skill-email-cleanup` (the only consumer that branches on `--all`/default-mode/`--archive`
  respectively) plus their own mechanical layer. The full per-invariant breakdown is the
  coverage-map table now embedded in `safety-invariants.md`.
- The two mechanical enforcement layers hold with zero markdown loaded: `hooks/mail-guard.sh`
  (PreToolUse allowlist/deny hook) and the nix-built wrapper binaries' own baked-in hash check,
  manifest-expiry refusal, `MAX_BATCH_SIZE` cap, and `--account` enum validation.
- `index-entries.json`'s `load_when` block for the safety-invariants entry was verified
  consistent with the decision as-is: it is an advisory index hint consumed by
  `check-extension-docs.sh`/`install-extension.sh` metadata paths, never a harness auto-load
  mechanism, so no semantic change was needed there — only its `summary` (and, as a deviation,
  its `line_count`) were updated.

## Plan Deviations

- **Task 3.4** (Phase 3, `index-entries.json`): the plan named only the `summary` field for
  update. Also refreshed the entry's `line_count` from 102 to 156, since Phase 1 added ~54 lines
  to `safety-invariants.md` and leaving `line_count` stale would trip
  `validate-context-index.sh`'s 10%-tolerance line-count check on the next run. Purely additive
  accuracy fix; no change to `load_when` semantics.
- **Testing & Validation** (Phase 4): `bash .claude/scripts/validate-wiring.sh` does not exit 0.
  It fails on 11 pre-existing errors, all missing `project/neovim/**` and
  `project/memory/README.md` context files — entirely unrelated to and outside
  `agent-system/extensions/email/**`, and not touched by any commit in this task's range or by
  any concurrently-dispatched sibling task's declared `file_scope` this cycle (139, 162, 163,
  199, 207, 244, 167). `git diff --stat` over this task's own commits confirms exactly the four
  intended email paths changed. Treated as pre-existing per the plan's own escape clause; not
  fixed here (out of this task's scope).

## Verification

- Build: N/A (documentation-only task)
- Tests: N/A
- `bash .claude/scripts/validate-context-index.sh`: PASS (225 entries checked, 0 errors, 0
  warnings)
- `bash .claude/scripts/check-task-references.sh`: PASS (0 unexempted occurrences across all 4
  scanned trees)
- `bash .claude/scripts/validate-wiring.sh`: FAILS on pre-existing, unrelated neovim/memory
  context-file gaps (see Plan Deviations)
- `jq empty agent-system/extensions/email/index-entries.json`: exits 0
- `git diff --stat` across this task's commits: exactly
  `EXTENSION.md`, `README.md`, `index-entries.json`,
  `context/project/email/domain/safety-invariants.md` — no entry under `agents/` or `skills/`
- Files verified: Yes

## Impacts

- A future audit of the email extension's context-loading model will find the reasoning already
  recorded (the coverage map plus the three consistent accounts in `EXTENSION.md`, `README.md`,
  and `index-entries.json`) instead of re-litigating the question.
- **The deployed `.claude/` tree is unaffected until the next manual regeneration.** This task
  edited only the source store (`agent-system/extensions/email/**`); regeneration is manual-only
  (see `context/patterns/regeneration-is-manual-only.md`), and running one during this dispatch
  would have swept in seven concurrently-dispatched sibling tasks' in-flight source-store edits.
  Anyone reading `.claude/context/project/email/domain/safety-invariants.md` or the deployed
  `.claude/CLAUDE.md`'s `## Email Extension` section before the next regeneration will still see
  the pre-task wording.
- Two documented copies of the safety rules (this file's derivation vs. each consumer's inline
  restatement) now carry an explicit editor's instruction to keep both in sync — an accepted,
  named drift risk rather than a silent one.

## Follow-ups

- Deferred (not created as a task by this dispatch, per the plan's Non-Goals): a core
  `context/patterns/context-loading-tiers.md` pattern doc generalizing the three-tier
  loading-model distinction (session-start eager / invocation-time eager / on-demand) beyond the
  email extension — agent-system-wide scope, belongs to `extensions/core`.
- Deferred: a constants-drift lint across the duplicated safety-rule locations (the four
  consumer bodies vs. `safety-invariants.md`), to catch the two copies drifting apart over time.
- Not a follow-up but worth flagging for a future reader: `validate-wiring.sh`'s pre-existing
  neovim/memory context-file failures (see Plan Deviations) are unrelated to this task and were
  left unfixed as out of scope.

## References

- Plan: `specs/043_email_safety_context_loading_decision/plans/01_email-safety-context-loading-decision.md`
- Research: `specs/043_email_safety_context_loading_decision/reports/01_email-safety-context-loading-decision.md`
- Progress files: `specs/043_email_safety_context_loading_decision/progress/phase-{1,2,3,4}-progress.json`
- Handoffs: `specs/043_email_safety_context_loading_decision/handoffs/phase-{1,2,3}-handoff-*.md`
