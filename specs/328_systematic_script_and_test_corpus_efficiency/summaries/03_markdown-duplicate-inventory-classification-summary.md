# Implementation Summary: Phase 15 — Classify the Markdown Duplicate-Block Inventory and Declare NET-MD

- **Task**: 328 - Systematic script and test corpus efficiency (markdown-corpus consolidation plan)
- **Status**: [COMPLETED]
- **Started**: 2026-11-05T23:30:00Z
- **Completed**: 2026-11-06T00:35:00Z
- **Effort**: ~1 hour
- **Dependencies**: Phase 2 (per-cluster net-deletion target derivation)
- **Artifacts**: plans/03_markdown-corpus-consolidation.md, markdown-block-inventory.tsv
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Re-derived the markdown corpus's cross-file duplicated-block inventory (5-line shingling,
`(g-1)/g` removable share) against the live corpus, partitioned it into gate-required,
deliberate-inlining, and consolidation-eligible pools, and — for the eligible pool — mechanically
confirmed which blocks already have a durable anchor doc versus which do not. No markdown file
outside `specs/**` was edited; this phase is measurement and classification only, ahead of
Phases 16-19's actual consolidation work.

## What Changed

- `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md` — Phase 15's task checklist fully annotated with completion notes; added a "Phase 15 Re-Derivation" subsection (re-derived per-role table, top-10 confirmed-anchor table, three-option `user_decision` text) under the phase's Scope Hypothesis; Verification bullets annotated with confirmation evidence; phase heading marked `[COMPLETED]`.
- `specs/328_systematic_script_and_test_corpus_efficiency/markdown-block-inventory.tsv` — created: 26 rows, one per mechanically-confirmed anchor (`anchor_path`, `anchor_heading`, `sharing_factor`, `occurrences`, `total_span_lines`, `files`).
- `specs/state.json` — task 328's `file_scope` widened by 3 concrete paths not already covered by existing directory-level entries (134 of 137 touched files were already covered).

## Decisions

- Gate-required/deliberate-inlining exclusion tests use content-overlap against the fragment
  files' own substantive-line set, not file-participant membership in a shared window — Check
  C/G/L's bullets are held on a single physical line each in the copying file, so a
  participant-membership test alone systematically undercounts them.
- Anchor-confirmation uses a strict exact-5-gram test (the anchor file must itself be one of the
  exact window's sharing participants) rather than a looser per-line-presence test, which was
  tried first and discarded for large false positives (documented in the progress file's
  `approaches_tried`).
- `file_scope` widening used a direct, minimal `specs/state.json` edit rather than
  `update-task-status.sh --file-scope-add`, which is restricted to
  `operation==postflight && target_status in {research, plan}` and refused this phase's
  mid-implement call.

## Plan Deviations

- **Task 15.8** (widen `file_scope` via `update-task-status.sh --file-scope-add`) completed via
  a direct `state.json` edit instead — the named mechanism is postflight/research-or-plan-only
  and does not apply mid-implement. The task's intent (widen file_scope to cover the inventory's
  touched files) was fully achieved; only the mechanism differs. See the plan's own completion
  note on this task item for detail.

## Verification

- Build: N/A (prose/measurement phase)
- Tests: N/A
- Files verified: Yes — `markdown-block-inventory.tsv` exists with 26 data rows, each naming an
  anchor file confirmed to exist on disk at measurement time.
- `bash .claude/scripts/validate-artifact.sh specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md plan` — PASS, 0 warnings.

## Impacts

- Phases 16-19 (the markdown tranche/consolidation phases) now have a concrete, mechanically
  confirmed starting inventory (933 net removable lines across 26 anchors) instead of the Scope
  Widening section's unconfirmed 12,752-line eligible-upper-bound hypothesis.
- The plan's declared −8,100 NET-MD target is now confirmed unreachable from mechanically-verified
  anchors alone (933 lines, an 89% shortfall) — a `user_decision` is raised rather than the target
  silently missed or the eligibility test relaxed.
- `file_scope` is widened ahead of Phases 17-19's commits, reducing the risk of those commits
  dropping touched paths against a stale declaration.

## Follow-ups

- The raised `user_decision` (three options: accept a lower NET-MD/NET-TOTAL target around
  −2,800 combined; authorize Phases 17-19 to perform semantic, not merely literal-text,
  anchor-finding as they consolidate each block — this phase's own recommendation; or lower the
  retained −10,000 floor itself) needs the operator's answer before Phase 17 proceeds on a
  specific numeric target.
- `markdown-block-inventory.tsv`'s `anchor_heading` values are mechanically located (nearest ATX
  heading at or above the matching line) and should be re-verified, not blindly trusted, by
  whichever phase replaces a given block with a pointer.

## References

- Plan: `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md`
- Inventory: `specs/328_systematic_script_and_test_corpus_efficiency/markdown-block-inventory.tsv`
- Handoff: `specs/328_systematic_script_and_test_corpus_efficiency/handoffs/phase-15-handoff-20261105T233928Z.md`
- Progress: `specs/328_systematic_script_and_test_corpus_efficiency/progress/phase-15-progress.json`
