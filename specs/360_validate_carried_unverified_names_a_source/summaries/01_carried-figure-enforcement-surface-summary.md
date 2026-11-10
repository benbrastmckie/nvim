# Implementation Summary: Task #360

- **Task**: 360 - Evidence discipline for report and plan artifacts, in three folded parts:
  validate that a `CARRIED-UNVERIFIED` mark names a source, extend the carried-figure obligation
  to a recommendation's mechanical claim and a dispatch's acted-on premise, and require a
  self-derived enumeration to state and stress-test its search pattern
- **Status**: [COMPLETED]
- **Started**: 2026-11-10T01:28:00Z
- **Completed**: 2026-11-10T02:10:57Z
- **Effort**: 11.5 hours (plan estimate)
- **Dependencies**: 328 (SERIALIZATION only, per the dispatch's territory edges)
- **Artifacts**: plans/01_carried-figure-enforcement-surface.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Built the first mechanical surface for the `## Carried-Figure Discipline` convention and then
widened the convention itself across nine phases. An advisory-only well-formedness check in
`scripts/validate-artifact.sh` now confirms every mark of `CARRIED-UNVERIFIED`,
`CORPUS-UNVERIFIED`, or `COVERAGE-UNVERIFIED` names a non-empty source designator, surviving
markdown emphasis, table cells, line wrapping, and bare token mentions. `report-format.md`'s
Carried-Figure Discipline section was widened in three ways: a corpus-dependent recommendation's
mechanical claim (Part A), a dispatch's acted-on premise (Part B, both the owner ruling and its
composer-side implementation in `orchestrate-build-dispatch.sh`), and a self-derived
enumeration's completeness obligation plus the verification-independence rule. All nine phases
are `[COMPLETED]`.

## What Changed

- `agent-system/extensions/core/scripts/validate-artifact.sh` — new advisory check, scoped to
  `report`/`plan` artifacts, parameterized over `CFD_TOKENS=("CARRIED-UNVERIFIED"
  "CORPUS-UNVERIFIED" "COVERAGE-UNVERIFIED")`: flattens newlines, suppresses backtick/backslash-
  preceded mentions, bounds the designator window, and emits `log_warn` (never `log_error`) on
  an empty designator or an unclosed bracket.
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` — `make_plan_fixture`
  gained an optional second (trailing-content) parameter; 38 new CFD test cases covering every
  recall-failure shape (plain inline, markdown emphasis, table cell, line-wrapped, bracket-alone-
  on-its-own-line) in both directions, for all three tokens, plus mention-suppression, the
  hide-a-following-mark case, and a direct bounded-window-exceeded case.
- `agent-system/extensions/core/context/formats/report-format.md` — `## Carried-Figure
  Discipline` section widened in place (no relocation, no new `##` heading): rewritten
  Enforcement-level paragraph naming both reasoned exclusions (does-the-source-resolve: NO;
  is-a-mark-OWED: NO); rewritten Out-of-scope paragraph plus a new corpus-dependent-recommendation
  trigger, discharge rule, and `CORPUS-UNVERIFIED` token definition with canonical positive/
  negative instances; the acted-on-premise obligation, owner ruling (composer emits / receiving
  agent adjudicates), and the mechanical-conflict-detection exclusion; the enumeration-
  completeness trigger, the three-part obligation and `COVERAGE-UNVERIFIED` token definition,
  the verification-independence rule, an honest enforcement-level statement, and the worked
  check against both cited instances.
- `agent-system/extensions/core/context/formats/plan-format.md` — one new pointer-only
  subsection, "Verification sweep independence", under `## Verification Tiers`.
- `agent-system/extensions/core/agents/general-research-agent.md` — two new pointer-only
  paragraphs in Stage 6 (Part A's corpus-dependent-recommendation obligation; the enumeration-
  completeness obligation).
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — a new
  `## Premise Re-Validation` block, emitted only when the task directory already holds a prior
  dispatch artifact AND the description contains a line matching one of the six Carried-Figure-
  Discipline trigger-class lexical signatures; lists the prior artifact paths and the matching
  lines, with a pointer to report-format.md, and performs no conflict detection of its own.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — new Group 22
  pinning the block in all three directions (with-artifact+trigger fires; no-artifact is silent;
  with-artifact+no-trigger is silent).
- Deployed tree regenerated via `deploy-headless.sh` (gitignored, not separately listed).

## Decisions

- Both the empty-designator and no-closing-bracket conditions shipped together in Phase 1,
  because the real-corpus sweep after mention-suppression showed zero flags of either kind —
  the plan's own fallback (ship empty-designator alone, exclude the other) was not needed.
- `CORPUS-UNVERIFIED` and `COVERAGE-UNVERIFIED` are new, distinctly-named tokens, never
  `CARRIED-UNVERIFIED` — that token's definition is keyed to a claim copied from elsewhere, and
  both new claims are the artifact's own.
- Part B's owner ruling is split by capability: the dispatch composer emits candidate claims and
  a pointer (no new measurement, since it already holds both documents); the receiving agent
  adjudicates and must state the result even when it only confirms the premise. Mechanical
  conflict detection is explicitly excluded in writing.
- Substituted the plan's literal "reuse the fingerprint-and-supersession idiom" instruction
  (Phase 7, task 7.3) with a grep-based lexical extraction, because the sha256sum idiom detects
  whether a recorded past description matches the current one, and nothing in this codebase
  records a fingerprint of a premise to compare against. Recorded as a deviation.
- The two "ALSO SETTLE" questions from the dispatch (does-the-source-resolve;
  is-a-mark-owed-where-missing) are both ruled NO and recorded as named reasoned exclusions in
  `report-format.md`, not left open.
- Phase 9's "run the complete gate set" / `verify-deploy.sh exits 0` obligations were discharged
  against this dispatch's own Batch Gate Deferral directive: a scoped `run-all.sh --only`
  invocation over every file this task touched, deferring the complete gate set to the
  batch-level stage at the end of this `/orchestrate` invocation.

## Plan Deviations

- **Task 3.4** skipped: the no-closing-bracket exclusion was not recorded because Phase 1's
  corpus sweep showed zero flags for either condition after mention-suppression — both shipped
  together, so there was nothing to exclude.
- **Task 7.3** altered: substituted a grep-based lexical extraction for the literal
  fingerprint-and-supersession idiom reuse (see Decisions above for the full reasoning).
- **Phase 9 "Run the complete gate set"** and the matching plan-wide Testing & Validation item
  (`verify-deploy.sh exits 0`) altered/deferred per the dispatch's Batch Gate Deferral directive
  — a scoped invocation was run instead; the complete gate set runs once for the whole batch.

## Verification

- Build: N/A (markdown/shell-script edits, no compiled build)
- Tests: `test-validate-artifact.sh` 134/134 passed (deployed and source-store); `test-orchestrate-build-dispatch.sh` 193/193 passed (deployed and source-store)
- Files verified: Yes — every file in Files to modify exists and was redeployed
- `bash -n` and `shellcheck`: clean on both edited scripts (pre-existing info-level findings only, no new ones)
- Real-corpus sweep: 0 advisories across every report/plan artifact under `specs/` carrying any of the three tokens, measured against both the source-store and the deployed validator
- `lint/lint-agent-contracts.sh`: exit 0 (421 passed, 15 pre-existing recorded-exclusion warnings, 0 failed)
- `check-task-references.sh agent-system/`: PASS, 0 unexempted occurrences
- `check-record-versioning.sh agent-system/extensions/core/`: 0 BLOCKING, 567 pre-existing advisory findings (none newly introduced)
- `deploy-headless.sh`: deploy landed (confirmed by grepping deployed copies for the new content); internal fast-gate verification found 3 pre-existing, confirmed-unrelated findings outside this task's `file_scope` (see Impacts/Follow-ups)

## Impacts

- Every future report or plan artifact carrying a malformed `CARRIED-UNVERIFIED`,
  `CORPUS-UNVERIFIED`, or `COVERAGE-UNVERIFIED` mark now draws a named advisory at validation
  time, without affecting default-mode pass/fail status.
- Every future `/orchestrate` dispatch whose task directory already holds a prior artifact, and
  whose description still asserts one of the six Carried-Figure-Discipline trigger-class claims,
  now surfaces that claim plus a pointer to the prior artifact in its own dispatch file —
  cheaply, with no new measurement and no conflict detection.
- Future research reports gain two new pointer-bearing obligations (corpus-dependent
  recommendations; enumeration completeness), both routed through the single authoritative
  `report-format.md` section.

## Follow-ups

- Three pre-existing, confirmed-unrelated gate findings were observed during this task's scoped
  verification and recorded via `issue-record.sh` rather than fixed here (outside `file_scope`):
  an eager-context-budget overage (another open task's territory, per this dispatch's own text),
  a shellcheck finding in `agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh`,
  and a dead-command-recommendation finding (`/ide` has no definition file) in two
  `agent-system/extensions/memory/**` context files.
- Three blast-radius test suites (`test-orchestrate-build-aux-dispatch.sh`,
  `test-orchestrate-cycle-postflight.sh`, `test-orchestrate-unwind-dispatch.sh`) were red during
  this task's scoped `run-all.sh --only` pass, for reasons individually confirmed unrelated to
  this task's content (an agent-model-resolution mismatch, postflight status-demotion logic, and
  a test fixture's `REQUIRED_LIB_SCRIPTS` array missing `lib/project-number-inuse.sh`). Recorded
  via `issue-record.sh`; left for the batch-level gate stage or their owning tasks to address.
- The complete gate set (`bash .claude/scripts/verify-deploy.sh`) was not independently run to a
  green exit by this dispatch, per its own Batch Gate Deferral directive — it runs once at the
  end of the whole `/orchestrate` batch invocation.

## References

- Plan: `specs/360_validate_carried_unverified_names_a_source/plans/01_carried-figure-enforcement-surface.md`
- Research report: `specs/360_validate_carried_unverified_names_a_source/reports/01_carried-unverified-source-naming-validation.md`
- Progress files: `specs/360_validate_carried_unverified_names_a_source/progress/phase-{1..9}-progress.json`
- Handoffs: `specs/360_validate_carried_unverified_names_a_source/handoffs/phase-{1..9}-handoff-*.md`
