# Implementation Summary: Task #477

- **Task**: 477 - Normalize issue-log class vocabulary; reject the conclusion aggregator's malformed `--tasks` call shape
- **Status**: [COMPLETED]
- **Started**: 2026-11-23T03:00:00Z
- **Completed**: 2026-11-23T03:25:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_class-vocabulary-normalization.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Two defects sharing one edit target (`scripts/orchestrate-conclusion-aggregate.sh`) were fixed
together across six phases. Part 1 stopped the issue-log `class` vocabulary from fragmenting:
`scope excursion` was promoted into the seed enum (now 18 classes), grouping-time case-and-
separator folding was added to the aggregator's jq pipeline (never rewriting stored data), an
empty-but-documented semantic alias-table mechanism shipped, and `class` gained both a written
shape convention and append-time warnings in `issue-record.sh`. Part 2 replaced the aggregator's
silent last-wins handling of repeated `--tasks` (and a repeated mode flag) with a loud usage
rejection. All edits landed in the source store at `agent-system/extensions/core/`, and the
deployed `.claude/` tree was regenerated and re-verified once at the end.

## What Changed

- `agent-system/extensions/core/context/formats/issue-log.md` — 18th gloss row for `scope
  excursion` with canonical-spelling statement; section heading, derivation paragraph, Entry
  Field Table, Extensibility Rule, and Unknown-Class Tally all updated from 17 to 18 classes; new
  "Class Value Shape" and "Promoting a Class" sections.
- `agent-system/extensions/core/scripts/issue-record.sh` — `ISSUE_SEED_CLASSES` array entry for
  `scope excursion`; new `issue_fold_class()` bash helper (jq `fold_class` twin, SHARED
  FRAGILITY-commented); fold-aware seed-membership test with a canonical-spelling warning; the
  outside-the-seed-enum warning extended to cite the new class-shape convention; a new
  token-count style warning (>6 folded tokens).
- `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh` — `SEED_CLASSES_JSON`
  entry for `scope excursion`; `fold_class`/`canon_class` jq defs with a HARD CONSTRAINT comment
  (read-time only, never rewrites `issues.jsonl`); empty `CLASS_ALIASES_JSON` alias-table literal;
  `group_by` re-keyed to the canonical value; most-frequent-raw-spelling representative selection
  with a lexicographic tie-break (`most_frequent_raw()`); `class_variants` added to every
  proposal; `unknown_classes` re-keyed post-fold with its own `variants` set and no drop path; a
  `tasks_seen` counter rejecting a repeated `--tasks` flag; a `mode_seen` counter rejecting a
  repeated mode-selecting flag; usage header documentation for both the normalization and the
  flag audit, with `usage()`'s `sed` range updated twice to track the growing header.
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — dispatch-file injected
  text updated to "18-class seed enum".
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — assertion
  message text updated to match.
- `agent-system/extensions/core/context/contracts/conclusion-stage.md`,
  `agent-system/extensions/core/context/contracts/phase-closure.md`,
  `agent-system/extensions/core/context/standards/error-recovery-strategies.md`,
  `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` — each
  restatement of the enum's size updated to 18.
- `agent-system/extensions/core/index-entries.json` — `issue-log.md` entry's summary string
  updated (line_count auto-corrected by the deploy's `generate-context-line-counts.sh --write`
  step).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-aggregate.sh` — six new
  cases (o) through (t) covering grouping-time normalization, the `--tasks` rejection, seed
  validation, the byte-identity hard constraint, unknown-class never-dropped/never-double-counted,
  and the no-over-merge control (scope excursion vs. scope omission).
- `agent-system/extensions/core/scripts/tests/test-issue-record.sh` — four new cases (s)-(v)
  covering the three free-text examples, the canonical-spelling warning, the token-count style
  warning, and the clean no-warning control.

## Decisions

- **D1 (mechanical fold + empty curated alias table + post-fold tally)**: case/separator folding
  is applied unconditionally because it can only merge strings built from the same words; a
  semantic merge (e.g. the five "scope" spellings, or `design-gap`/`design-ambiguity`) is left to
  a curated, hand-maintained, currently-empty alias table, since one corpus occurrence each is
  not enough evidence to commit a silent merge, and `scope/file_scope omission discovered
  pre-emptively` likely points the *opposite* direction from `scope excursion`.
- **D2 (two-part remedy for free-text `class` values)**: the outside-the-seed-enum stderr warning,
  extended to cite the class-shape convention, is the mechanism that discharges the dispatch's
  requirement that all three free-text examples be caught — it fires on all three regardless of
  token count (3, 4, and 8 tokens respectively). A token-count style warning above 6 is layered on
  top as an additional, sharper signal for the sentence-shaped subset. A verb/keyword blocklist was
  rejected: the research corpus shows widespread legitimate usage of "confirmed"/"found"/
  "discovered" in `kind: "win"` entries.
- **D3 (reject, not union, for repeated `--tasks`)**: the script's only live call site already
  uses the correct single-string form (re-verified by grep immediately before landing the
  rejection), so there is no competing convention to honor and no caller to break.
- **D4 (flag audit)**: `--session`, `--channel`, `--answer` are genuinely scalar selectors where
  last-wins is the ordinary, unsurprising convention and were left unchanged; the mode-selecting
  flags (`--aggregate`/`--record-approval`/`--check-approval`) shared the same last-wins hazard as
  `--tasks` and were closed too, enforcing the "exactly one of ..." promise the script's error
  message already made.
- **D5 (the fold is implemented twice, deliberately)**: jq (`fold_class`/`canon_class`) and bash
  (`issue_fold_class()`) cannot share a library across languages; each carries a reciprocal SHARED
  FRAGILITY comment naming its twin.

## Plan Deviations

- **Phase 3, task 3.2** (altered): the plan's literal phrasing "Nothing is emitted on stdout" for
  the `--tasks` rejection is satisfied in its operative sense only — `usage()` has always printed
  to stdout in this script (no stderr redirect) on every existing error path, and the actual
  acceptance criterion (no JSON, never `proposals: []`) was confirmed directly via a manual
  scratch invocation. See `progress/phase-3-progress.json`'s `deviations` array.

## Verification

- Build: N/A (bash/jq scripts; `bash -n` passed on every edited shell script).
- Tests: `test-orchestrate-conclusion-aggregate.sh` 21/21 and `test-issue-record.sh` 27/27,
  both green against the **deployed** copies with no `CORE_TEST_SUBJECT_MODE` set. Every one of
  the 10 new cases was independently confirmed non-vacuous (failing against a pre-fix script
  version extracted via `git show`, or against a deliberately bug-injected scratch copy where no
  historical commit exhibited the defect).
- Files verified: Yes — `deploy-headless.sh` reported `RESULT=landed_verify_clean`; the
  `17-class` grep is empty across both `agent-system/**` and `.claude/**`;
  `.claude/context/index.json` carries the regenerated summary; the scoped touched-path check
  across all 12 edited paths (31 selected suites, 2 OWED-fallback) reported 98 passed, 0 failed.
  The complete gate set is deferred to the orchestration close per this dispatch's Batch Gate
  Deferral section.

## Impacts

- Future conclusion-stage aggregation across multiple tasks will correctly group
  case/separator-equivalent `class` spellings into one proposal instead of fragmenting them,
  restoring the cross-task grouping signal the mechanism depends on.
- A caller passing repeated `--tasks` flags now gets an immediate, loud rejection instead of a
  confident-looking but wrong empty result that could cause an entire multi-task evidence base to
  be silently discarded.
- An agent recording a free-text sentence or a non-canonical seed spelling into `class` is now
  told so at append time, with a pointer to the convention, while the open-enum posture (never
  refuses) is fully preserved.

## Follow-ups

- The pre-existing `test-common-lib.sh` environment-leak defect (CORE_TEST_SUBJECT_MODE leaking
  into its own "mode=deploy-tree-first (both exist)" fixture case) was observed and recorded via
  `issue-record.sh` during Phase 1; it is unrelated to this task's edits and was not fixed here.
- The alias table ships empty by design (D1); populating it with any specific semantic merge
  (the five "scope" variants, `design-gap`/`design-ambiguity`, or any of the seven further
  already-hardcoded non-seed classes the research report names) is a separate, separately-
  evidenced follow-up, not acted on here.

## References

- Plan: specs/477_normalize_issue_log_class_vocabulary/plans/01_class-vocabulary-normalization.md
- Research report: specs/477_normalize_issue_log_class_vocabulary/reports/01_issue_log_class_vocabulary.md
- Progress files: specs/477_normalize_issue_log_class_vocabulary/progress/phase-{1..6}-progress.json
- Handoffs: specs/477_normalize_issue_log_class_vocabulary/handoffs/phase-{1..6}-handoff-*.md
