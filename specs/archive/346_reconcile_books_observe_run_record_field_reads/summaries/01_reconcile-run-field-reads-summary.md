# Implementation Summary: Reconcile books-observe.sh RUN record field reads

- **Task**: 346 - Reconcile books-observe.sh RUN record field reads
- **Status**: [COMPLETED]
- **Started**: 2026-10-07T01:43:00Z
- **Completed**: 2026-10-07T04:10:00Z
- **Effort**: ~4 hours
- **Dependencies**: None
- **Artifacts**: plans/01_reconcile-run-field-reads.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

`books-observe.sh`'s single `jq -c -s` RUN-log aggregation read six field names and one field
type that do not exist in the normative `book-evidence-run-v1` schema, with the numeric-vs-string
task filter (`--argjson` against a schema-typed string) silently matching zero records on every
run and masking the other five mismatches entirely. All six mismatches are now corrected
schema-faithfully, a two-part stderr-only fail-loud diagnostic was added for the case the type
mismatch exemplifies, the test harness's bug-encoding Case 7 fixture was rewritten alongside the
reader as one atomic batch plus four new fixtures, `observation-record.md` was amended to the
record shapes the reader now writes, and the fix was redeployed and verified against the consumer
repository's live 230-line RUN log: task 175's OBSERVATION record now shows populated
`verification_tiers`/`certifier_outcomes`/`vacuous_passes` rather than silently-absent ones.

## What Changed

- `agent-system/extensions/books/scripts/books-observe.sh` — the six RUN-record field-read
  corrections (`--arg` string task filter, `.outcome_class` in place of `.outcome`,
  `.wall_seconds` in place of `.duration_seconds`, `certifier_outcome_classes` reading
  `.outcome_class` restricted to `tier == "certify"` in place of the nonexistent
  `.certifier_class`, `refusal_count_total`/`warning_count_total` integer sums in place of the
  `refusals`/`warnings` per-item text arrays the schema cannot supply, and
  `select(.outcome_class == "vacuous-pass")` in place of the `.vacuous`/`pass_vacuous`
  double-wrong sentinel), plus the two stderr-only fail-loud diagnostics (an
  unrecognized-`schema` partition/warning, and a permissive-vs-strict `caller_context.task`
  type-comparison divergence warning) co-located inside the same jq program as the strict
  filter.
- `agent-system/extensions/books/scripts/tests/test-books-observe.sh` — Case 7's fixture
  rewritten to schema-conformant JSONL (string `caller_context.task`, hyphenated `tier`,
  `outcome_class`) with populated-group assertions in place of exit-code-0-only assertions, plus
  four new fixtures (Cases 12-14, and a strengthened Case 2): a numeric-`caller_context.task`
  regression fixture pinning mismatch 1 (mutation-checked against a scratch `--argjson` revert),
  an unrecognized-`schema` fixture proving the loud path fires without breaking the non-blocking
  contract (mutation-checked by neutralizing the warning), and two silent-case fixtures (absent
  log, zero-match-but-recognized-schema) proving case (a) stays silent. A new
  `run_obs_capture_stderr` helper plus `assert_stderr_empty`/`assert_stderr_contains` capture
  stderr separately from the existing stdout-only helpers. 74 assertions pass, 0 failed (up from
  61 before this task).
- `agent-system/extensions/books/context/project/books/standards/observation-record.md` — the
  `verification_tiers` row's tier vocabulary corrected from underscored to hyphenated spellings;
  the `certifier_outcomes` row's shape changed from `{outcome_classes, refusals, warnings,
  source}` to `{outcome_classes, refusal_count_total, warning_count_total, source}` with an
  explicit statement that the RUN schema carries integer counts only, never per-item text; and
  "The RUN Log" section amended to document the STRING match type and the fail-loud ruling.
- `agent-system/extensions/books/index-entries.json` — line-count resync
  (`generate-context-line-counts.sh --write`) for `observation-record.md`'s growth, plus two
  pre-existing, unrelated drifts in the same regeneration.
- Redeployed to `/home/benjamin/Projects/Logos/Verification/.claude/`.

## Decisions

- Mismatch 1's filter is fixed schema-faithfully (`--arg`, plain string equality) rather than
  with a permissive dual-type comparison — the schema fixes the type, and a permissive reader
  would hide a future writer-side regression rather than surface it.
- `refusals`/`warnings` become integer-count sums (`refusal_count_total`/`warning_count_total`)
  rather than per-item text arrays — the RUN schema has no per-item refusal/warning text under
  any field name, only the certify-tier-only integer counts `refusal_count`/`warning_count`.
- The fail-loud ruling is two complementary, stderr-only, diagnostic-only checks living inside
  the same jq program as the strict filter (so the two cannot drift apart without a reviewer
  seeing both): an unrecognized-`schema` partition, and a permissive-vs-strict
  `caller_context.task` divergence check. Neither ever feeds `$mine`, the written record, or the
  exit code. The divergence check is the one that would have caught mismatch 1's exact
  signature on every one of the consumer repository's live lines; the schema check alone would
  not have, since every live line already carries the correct, recognized `schema` value.
- Case (a) (missing/unreadable log, or a recognized-schema log with zero matches for this task)
  stays fully silent; case (b) (an unrecognized `schema`, or a permissive/strict divergence) is
  loud on stderr. The observer's non-blocking, always-exit-0-in-live-mode contract is unchanged.

## Plan Deviations

- None (implementation followed plan). Phase 5's `verify-deploy.sh` run surfaced 3 failing
  checks; 1 was attributable to this task's own edit (an index-entries.json line-count drift,
  fixed in-phase) and 2 were attributable to sibling task 300's already-committed, in-flight
  work under `agent-system/extensions/core/**` (confirmed via `git log`) plus unrelated
  pre-existing dirty state — not a deviation from this plan, but recorded in the Testing &
  Validation checklist annotation for transparency.

## Verification

- Build: N/A (shell scripts; `bash -n` on both changed files exits 0).
- Tests: `test-books-observe.sh` reports 74 passed, 0 failed. Both new regression/fail-loud
  fixtures mutation-checked (reverting `--arg` to `--argjson` makes the numeric-filter fixture
  fail; neutralizing the divergence warning makes its stderr assertion fail).
- Shellcheck: clean on both changed shell files.
- `check-task-references.sh agent-system/extensions/books`: 0 occurrences.
- `verify-deploy.sh` (source-store run): 3 failures, all attributable to sibling/pre-existing
  work outside this task's `file_scope` (see Plan Deviations). `verify-deploy.sh` against the
  consumer repository post-redeploy: PASS, 15 checks, 0 failures.
- Live verification: task 175 in the consumer repository, 230-line `runs.jsonl` (all
  `schema: book-evidence-run-v1`, all `tier: certify`, `caller_context.task` `"175"` or `null`).
  `--backfill 175` produced `verification_tiers.tiers.certify = {count: 23, outcomes: {pass:
  23}, total_seconds: 269.071}`, `certifier_outcomes = {outcome_classes: {pass: 23},
  refusal_count_total: 0, warning_count_total: 0, source: "backfilled"}`, `vacuous_passes = []`
  — all populated rather than absent. Confirmed (via a pre-run backup diff) that the only
  consumer-repository writes attributable to this invocation were `book.observation.json` itself
  and its one digest line in `observations.jsonl`; nothing was committed in the consumer
  repository.

## Impacts

- Every OBSERVATION record this observer has ever written for a books-topic task was silently
  missing its entire RUN-derived half; going forward (and via `--backfill` for past tasks), those
  records can carry the actual verification-tier/certifier-outcome/vacuous-pass evidence the RUN
  log holds.
- The fail-loud mechanism gives a future silent-zero defect of this same shape (a type mismatch
  between the filter and a schema field) a visible stderr signal on its very first occurrence,
  rather than surviving unnoticed for an unbounded number of runs.

## Follow-ups

- None. (Task 342's hold-blocked overlap with `observation-record.md`'s glob territory is
  pre-existing, named, and accepted in the dispatch; no action needed from this task.)

## References

- `specs/346_reconcile_books_observe_run_record_field_reads/reports/01_reconcile-run-field-reads.md`
- `specs/346_reconcile_books_observe_run_record_field_reads/plans/01_reconcile-run-field-reads.md`
- `/home/benjamin/Projects/Logos/Verification/books/schema/book-evidence-run-v1.md`
