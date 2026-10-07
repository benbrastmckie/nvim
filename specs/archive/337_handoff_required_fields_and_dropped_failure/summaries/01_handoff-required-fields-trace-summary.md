# Implementation Summary: Task #337

- **Task**: 337 - Resolve the handoff-field gap: writers omit required `blockers`/`summary`, and a hard HANDOFF VALIDATION FAILED is printed and then dropped with no durable trace
- **Status**: [COMPLETED]
- **Started**: 2026-10-05
- **Completed**: 2026-10-06
- **Effort**: ~7 hours (across two resumed dispatch windows)
- **Dependencies**: None
- **Artifacts**: plans/01_handoff-required-fields-trace.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed the handoff-field gap in both directions decided by research. Adopted option (i),
writer-side obligation: a write-time required-field content check was added to the existing
`PostToolUse` hook (`hooks/validate-handoff-location.sh`) that already fires on every Write/Edit
of `.orchestrator-handoff.json`, so a non-compliant write (missing `summary`/`blockers`) is
rejected with `exit 2` and a fix-forward banner at write time, rather than discovered later.
Separately, a mandatory durable trace was wired at `orchestrate-cycle-postflight.sh`'s
handoff-present read path: any invalid handoff that still reaches postflight now records a
`HANDOFF_VALIDATION_FAILED` `events.jsonl` row and `detected_defects[]` entry, non-gating for
task completion. The two companion WARNs (`sorry_inventory`, `continuation_path`) were scoped to
only fire in the cases where they are informative, and all rulings were recorded in
`docs/architecture/handoff-schema.md` and `context/contracts/wrap-up.md`. All 42
byte-identical writer-prose blocks across the agent corpus now point at the write-time gate, and
the source-store changes were deployed and gated.

## What Changed

- `agent-system/extensions/core/scripts/system-defect-record.sh` — added `HANDOFF_VALIDATION_FAILED` as a seventeenth closed `--defect-class` enum value; updated the four size/membership wordings.
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — added the seventeenth-instance paragraph, a new Class (a) registry row, and amended the Class (c) hook row; later reworded to remove two task-number citations flagged by the task-reference lint.
- `agent-system/extensions/core/scripts/skill-base.sh` — removed the discarded, log-only `validate-handoff.sh` invocation from `skill_corroborate_phase_counts`; updated its header comment.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — added the validate-and-record block to the handoff-present read path, covering every handoff-writing phase (not `implemented` only), non-gating.
- `agent-system/extensions/core/hooks/validate-handoff-location.sh` — added the write-time required-field content check, its fix-forward banner, its recorder call, and a header update naming both checks.
- `agent-system/extensions/core/scripts/validate-handoff.sh` — scoped the `sorry_inventory` and `continuation_path` WARNs to the cases where they inform; added `--help` rules bullets. No `log_fail` line or `required_fields` array entry was touched.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — rewrote the `validate-handoff.sh` wiring status paragraph; extended the Path Resolution Contract section; recorded the `sorry_inventory`/`continuation_path` rulings; added write-time enforcement notes to `summary`/`blockers`.
- `agent-system/extensions/core/context/contracts/wrap-up.md` — updated the hook's one-line description to name both checks.
- 42 `agent-system/extensions/*/agents/*.md` files — appended one sentence to the byte-identical writer-prose block pointing at the write-time gate, applied via one mechanical scripted pass (a Python script, since Perl's `/`-delimited `s///` collided with literal slashes in the replacement text).
- Four extended test suites: `test-validate-handoff.sh`, `test-validate-handoff-location.sh`, `test-orchestrate-cycle-postflight.sh`, `test-corroborate-phase-counts.sh`.
- A regenerated `.claude/` deploy tree (disposable artifact, not itself a committed deliverable).

## Decisions

- Moved the validator invocation out of `skill_corroborate_phase_counts` entirely (a deliberate refinement of the research's Recommendation 3) rather than threading a fourth stdout token through it, so plan-phase handoffs get validation coverage too and no existing call site's parse shape is disturbed.
- The 42-file writer-prose mechanical pass used a Python `str.replace`-based script instead of `sed`/`perl`, because the replacement sentence itself contains literal `/` characters that collided with `perl -i -pe 's///'`'s delimiter; this is the same scripted, single-pass-over-one-grep-derived-file-list intent the plan specified, just a different interpreter.
- Chose not to touch `scripts/tests/known-failures.txt` for the two pre-existing `run-all.sh` failures surfaced during Phase 7 (a stranded-dispatch-detection feature gap in the cycle-planning script, and a typst element-lint case) — both are unrelated to this plan's edits and are the subject of other, separate work.

## Plan Deviations

- **Task-reference lint fix** (not originally scoped as a task, discovered during Phase 7): Phase 1's seventeenth-instance paragraph in `system-defect-discrimination.md` cited two task numbers directly, violating `no-task-references-in-deliverables.md`. Reworded to describe the two measured incidents by shape instead of by number.
- **TODO.md/state.json sync fix** (not originally scoped, discovered during Phase 7): ran the sanctioned `generate-todo.sh` regeneration to resolve drift caused by concurrent sibling dispatches' preflight writes in this same batch — not caused by this plan's own edits.

## Verification

- Build: N/A (no compiled artifacts)
- Tests: Passed — `test-validate-handoff.sh` 15/15, `test-validate-handoff-location.sh` 14/14, `test-orchestrate-cycle-postflight.sh` 184/184, `test-corroborate-phase-counts.sh` 34/34.
- Deploy gate: `verify-deploy.sh` findings were triaged run-by-run in this concurrently-dispatched shared tree. Findings caused by this plan's own edits (task-reference lint) were fixed in place and confirmed green. Findings attributable to concurrent sibling tasks' own in-flight commit/deploy state (TODO.md/state.json drift; one sibling's undeployed new test file; one extension's undeployed observer script; two unrelated pre-existing `run-all.sh` suite failures) were recorded and left alone, per this plan's Phase 7 Verification notes.
- Files verified: Yes — deployed-copy spot-checks confirm `HANDOFF_VALIDATION_FAILED` present in all three new detection-site files (8 total occurrences) and `log_warn` count identical (6) between source and deployed `validate-handoff.sh`.
- This dispatch's own `.orchestrator-handoff.json` write exercised the new write-time content-check gate live: the write (made at this summary's close) included a non-empty `summary` and an explicit `blockers: []`, and passed the hook's content check cleanly with no banner and no `exit 2`.

## Impacts

- A dispatch whose handoff write omits `summary`/`blockers` is now rejected immediately at write time with actionable remediation, instead of silently completing via the COMPLETION-CLAIM GATE's phase-accounting case.
- Any handoff that still reaches postflight invalid (e.g. via the Bash-redirection write path the hook cannot see) is now durably recorded in `events.jsonl` and `detected_defects[]`, visible to a future reader without the terminal still being open.
- A clean, conforming handoff now emits zero `sorry_inventory`/`continuation_path` WARNs, removing noise that previously fired on ~100% of ordinary dispatches.
- Coverage extends to every handoff-writing phase (plan included), not just `implemented`-status dispatches.

## Follow-ups

- None required to close this task. The two `run-all.sh` suite failures surfaced during Phase 7 (stranded-dispatch-detection coverage gap in the cycle-planning script; a typst element-lint case) are pre-existing and unrelated to this plan — they are the subject of separate work already identified in this same batch, not a new follow-up from this task.

## References

- `specs/337_handoff_required_fields_and_dropped_failure/plans/01_handoff-required-fields-trace.md`
- `specs/337_handoff_required_fields_and_dropped_failure/reports/01_handoff-required-fields-dropped-failure.md`
- `specs/337_handoff_required_fields_and_dropped_failure/progress/phase-{1..7}-progress.json`
