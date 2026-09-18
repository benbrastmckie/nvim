# Implementation Summary: Task #212

- **Task**: 212 - Postflight honesty: gate research on a report file and derive the handoff-writer predicate from the dispatch row
- **Status**: [COMPLETED]
- **Started**: 2026-09-18T21:11:06Z
- **Completed**: 2026-09-19T00:25:00Z
- **Effort**: ~3.5 hours
- **Dependencies**: 194 (completed), 213 (completed)
- **Artifacts**: plans/01_gate-research-report-handoff-predicate.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, no-task-references-in-deliverables.md

## Overview

Two related postflight defects in `orchestrate-cycle-postflight.sh` are fixed by one plan. First,
the absent-handoff branch used to excuse every dispatched agent not on a two-entry hard-mode
allowlist, so a genuine double miss (no handoff, no usable `.return-meta.json`) from any base-mode
agent — the observed live incident was `general-implementation-agent` dying on context exhaustion
— recorded no defect at all. Second, a research dispatch could report `researched` while its
report file or `.return-meta.json` was missing or empty, and postflight still advanced the task.
The fix replaces the allowlist with a dispatch-derived `--handoff-expected true|false` predicate
(default `true`), adds a report-file existence/non-emptiness gate to the `researched` transition,
adds a `report_missing` output field plus a mechanical recovery helper
(`orchestrate-recover-message-findings.sh`) that saves an agent's message-borne findings under a
clearly-tagged banner, and hardens all 21 research agent contracts (plus `planner-agent` and
`general-implementation-agent`) against the harness's generic file-write-discouraging note.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — Deleted
  `is_contractual_handoff_writer()`; added `--handoff-expected true|false` (default `true`);
  rewrote the WORK (d) absent-handoff branch to record `HANDOFF_STALE_OR_ABSENT` whenever
  handoff is expected (with `transport_error=`/`meta_touched=` annotations), or emit a neutral
  INFO line when `--handoff-expected false`; hoisted the `meta_touched` computation; added a
  research report-file gate to the `researched)` case (existence + non-emptiness of both the
  report and `.return-meta.json`, resolved against the repo root), recording
  `ARTIFACTS_MISSING_ON_SUCCESS` on refusal and forcing `verdict=failed`; skipped WORK (g)
  artifact-link/round-advance and WORK (i) commit on gate failure; added the `report_missing`
  output field (round-number-keyed existence probe, never a prose read) to both final JSON
  shapes.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — Added
  fixtures A/B/C (Phase 1: the observed double-miss, the `--handoff-expected false` opt-out, and
  the research-phase equivalent) and D/E/F/G (Phase 2: nonexistent report, empty report, a
  genuine-success regression guard, and fixture C's `report_missing=true` assertion). 87/87 pass.
- `agent-system/extensions/core/scripts/orchestrate-recover-message-findings.sh` (new) — Mechanical,
  idempotent helper: reads a dispatch file's `## Artifact Round` section for naming (with a
  fallback + named WARN), writes a "recovered from agent message" banner plus the agent's
  message verbatim, never clobbers an existing file (suffix increments), always exits 0, never
  touches `state.json`/`.return-meta.json`/the handoff.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-recover-message-findings.sh` (new) —
  23/23 pass, including an end-to-end fixture that runs a real `orchestrate-cycle-postflight.sh`
  cycle and feeds its `report_missing=true` output into the helper.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Move 3 now reads
  `report_missing`; when true it documents the lead writing that row's Agent-tool return text
  verbatim to a capture file and calling the recovery helper. Amended the "MUST NOT (Postflight
  Boundary)" section with the named D4 exception.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — Rewrote the
  "Writer-Contract Determination (D1)" section (dispatch-derived predicate, no agent-name list)
  and amended the Postflight Boundary item 5 with the D4 exception.
- `agent-system/extensions/core/docs/architecture/orchestrate-cycle-postflight.md` — Updated the
  D1 pointer, added a "Research Report-File Gate" section, and documented `report_missing` in
  the output-fields section.
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` — Added a
  scoped "## Exceptions" section naming the D4 mechanism as `skill-orchestrate`-only (not a
  template addition other delegating skills inherit).
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — Updated the
  `ARTIFACTS_MISSING_ON_SUCCESS` row to name the new research-phase, file-missing-on-disk
  detector, and noted plan/implement phases and the null/absent-field sub-case remain uncovered.
- `agent-system/extensions/core/context/contracts/deliverable-file-mandate.md` (new) — Shared,
  generated-copy-source contract (never `@`-imported) covering the deliverable-file mandate, the
  override clause, the completion clause, background, and consequence. Registered in
  `index-entries.json` with load conditions for `general-research-agent`, `planner-agent`,
  `general-implementation-agent`.
- All 21 research agent contracts (`general-research-agent.md` plus the 20 extension
  `*research*.md` files across cslib, epidemiology, formal, founder, latex, lean, nix, nvim,
  present, python, rust, typst, web, z3) — each carries a MUST DO override item and a MUST NOT
  completion item pointing to the shared contract; `general-research-agent.md` additionally
  carries the Stage 6 lead-in paragraph.
- `agent-system/extensions/core/agents/planner-agent.md`,
  `agent-system/extensions/core/agents/general-implementation-agent.md` — Same override/completion
  items added (their own deliverables are files too).
- `agent-system/extensions/core/context/processes/research-workflow.md` — One-line pointer to the
  shared contract at Step 3.
- `agent-system/extensions/core/manifest.json` — Registered the new script and its test.
- `agent-system/extensions/core/index-entries.json` — Registered `deliverable-file-mandate.md`;
  redeploy also self-corrected 3 stale `line_count` fields for files this task edited.

## Decisions

- **D1** — Default-true dispatch-derived predicate (`--handoff-expected`) replacing the
  agent-name allowlist entirely; self-maintaining as agents/extensions are added.
- **D2** — The absent-handoff defect records regardless of `transport_error`, annotated with
  `transport_error=`/`meta_touched=` for triage.
- **D3** — A refused `researched` transition resolves `verdict=failed` with task status
  unchanged (not `[PARTIAL]`, which is an implementation-phase-only exception state).
- **D4** — Message recovery is lead-side (writes the verbatim capture file) but
  script-backed (naming, banner, never-clobber owned by `orchestrate-recover-message-findings.sh`);
  documented as a narrow, named Postflight Boundary exception in three places.
- **D5** — See "WORK (a) and D5 Findings" below.

## WORK (a) and D5 Findings (recorded per Phase 6's task)

**WORK (a), current behavior before this task**: a message-only research return was NOT silently
accepted even before this fix — `have_outcome=false` already skipped the status transition, and
the verdict already resolved to `failed`, so the task was never marked `researched`. The actual
gaps this task closes were narrower than "silently accepted": (i) no defect was recorded for any
non-allowlisted agent (the WARN-only branch), (ii) message-borne findings were unconditionally
lost with no recovery path, and (iii) a `researched` outcome whose report file was missing or
empty was still trusted (no existence check existed in the `researched)` branch at all).

**D5, reproduction outcome**: no live multi-agent reproduction was attempted. The mechanism (the
harness's generic subagent "Notes:" block discouraging report/summary/analysis file writes) was
observed directly, verbatim, in this very dispatch's own system prompt — it is not a hypothesis
requiring reproduction, it is the literal text every dispatched subagent receives. A live
multi-agent repro attempt could show the mechanism failing to trigger a given research agent
(e.g. because that agent's contract is now hardened, post-Phase-5) without disproving that the
harness note itself exists and is capable of triggering the failure mode — a negative repro result
would be uninformative either way. The direct-observation evidence is stronger and cost nothing
extra to obtain.

## Plan Deviations

- **Phase 1** (altered): also updated `docs/architecture/handoff-schema.md`'s "Writer-Contract
  Determination (D1)" section and `orchestrate-cycle-postflight.md`'s pointer to it, beyond the
  plan's literally-named "header comment + WARN text" — both documented the now-deleted allowlist
  as canonical, which would have left a reader pointed at a removed mechanism.
- **Phase 3** (altered): registered the two new files in `manifest.json`'s scripts/tests arrays,
  beyond the plan's literal task list — required for Phase 6's redeploy to actually place the new
  script under `.claude/scripts/`.
- **Phase 5** (approach failure, caught and fixed): a mechanical Python insertion script initially
  split a wrapped, multi-line MUST DO/MUST NOT item across 3 of the 20 extension research-agent
  files (inserting the new item between an existing item's first line and its own continuation
  line). Caught by a post-hoc structural verification pass (checked for an indented,
  non-numbered line immediately following each inserted item) and hand-fixed in all 3 files
  before committing. See `progress/phase-5-progress.json`'s `approaches_tried` entry.

## Verification

- Build: N/A (shell scripts + markdown contracts)
- Tests: Passed — 87/87 (`test-orchestrate-cycle-postflight.sh`), 23/23
  (`test-orchestrate-recover-message-findings.sh`), 7/7 (`test-orchestrate-recover-outcome.sh`),
  238/238 (`test-orchestrate-cycle-plan.sh`), 92/92 (`test-orchestrate-build-dispatch.sh`) — 447
  total, 0 failed.
- shellcheck: clean on all 4 touched/new `.sh` files (identical to each file's pre-change
  baseline; the new script carries only the same info-level `SC1091` every core script's
  `source lib/common.sh` line carries).
- Lints: `check-task-references.sh` reports 0 occurrences across all 4 trees;
  `lint-postflight-boundary.sh` reports 0 violations across 23 files (re-run post-redeploy);
  `validate-index.sh` reports "Validation PASSED".
- Redeploy: `deploy-headless.sh` reported "PASS -- 33 check(s), 0 failure(s)",
  `RESULT=landed_verify_clean`. Every source/deploy file pair this task touched is a byte-for-byte
  MATCH (verified via `diff`). The four Phase 6 confirmation checks
  (`orchestrate-recover-message-findings.sh` exists, `is_contractual_handoff_writer` grep count
  0, override clause present in the deployed `general-research-agent.md`, shared contract
  deployed) all pass.
- Files verified: Yes.

## Impacts

- Every future `/orchestrate` cycle that reaches a genuine double-miss (no handoff, no usable
  `.return-meta.json`) from ANY dispatched agent — not just the two former hard-mode allowlist
  entries — now records `HANDOFF_STALE_OR_ABSENT`, closing the observed silent-excusal gap.
  Aux dispatches remain unaffected by construction (they never carry `handoff_path`, so the
  `--handoff-expected true` default's rationale never applies to them; no caller passes `false`
  today).
- A research dispatch can no longer silently advance to `researched` on a missing or empty report
  file — the task stays in-flight for re-dispatch, and `ARTIFACTS_MISSING_ON_SUCCESS` is recorded.
- Findings an agent delivers only by message (the originally observed defect) are now preserved
  under a clearly-tagged recovered file instead of being silently lost, while the dispatch still
  correctly fails/re-dispatches rather than being credited as complete.
- All 21 research agents plus `planner-agent`/`general-implementation-agent` now explicitly
  reject the harness's generic file-write-discouraging note as an excuse for a message-only
  return.

## Follow-ups

- `skills/skill-orchestrate/SKILL.md` now exceeds its configured eager-context ceiling (21318 B
  vs. 20000 B) after this task's Move 3 and Postflight Boundary additions. The gate is
  `ORCHESTRATOR_BUDGET_GATE_MODE=warn` (non-blocking) today; trimming SKILL.md's size was outside
  this task's declared scope and is left as a follow-up should the gate be promoted to hard mode.
- `ARTIFACTS_MISSING_ON_SUCCESS`'s null/absent/empty-`artifacts`-field sub-case (as opposed to the
  file-missing-on-disk sub-case this task wired) remains uncomputed, as does report-existence
  gating for the plan and implement phases — both explicitly out of this task's scope
  (Non-Goals).

## References

- `specs/212_gate_research_dispatch_missing_report/plans/01_gate-research-report-handoff-predicate.md`
- `specs/212_gate_research_dispatch_missing_report/reports/01_gate-research-report-handoff-predicate.md`
- `specs/212_gate_research_dispatch_missing_report/progress/phase-{1..6}-progress.json`
- `specs/212_gate_research_dispatch_missing_report/handoffs/phase-{1..5}-handoff-*.md`
