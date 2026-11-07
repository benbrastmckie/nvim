# Implementation Summary: Task #485

- **Task**: 485 - Recapture the corpus baseline figures the net-deletion acceptance criterion is measured against, now that the measurement instrument has been corrected
- **Status**: [COMPLETED]
- **Started**: 2026-11-05
- **Completed**: 2026-11-05
- **Effort**: 3.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_recapture-corpus-baselines.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`script-inventory.sh --size-line` was found to enumerate its corpus from `git ls-files` alone,
blind to untracked-but-not-ignored in-corpus files, and was fixed to union tracked with untracked
and disclose the contribution via a trailing `untracked=N` field. This record recaptured the
corrected probe reading, dated and classified every baseline and running-net figure recorded in
the parent record's two plan files by instrument, bounded the exposure of the one frozen baseline
every acceptance figure is measured against, and applied the determination to both parent files.

**The correction is a null result.** All three baseline populations are confirmed sound with a
delta of 0. The parent's acceptance verdict — none of the three retained targets met, NET-TOTAL
+1,219 against the retained −10,000 floor — stands exactly as recorded.

## What Changed

- `specs/485_recapture_corpus_baselines_under_corrected_probe/plans/01_recapture-corpus-baselines.md` — extended with the corrected reading of record, a 17-row per-figure determination table, the exposure bound and per-population correction, and this record's own outcome.
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/01_corpus-consolidation-net-deletion.md` — baseline table and four interim probe readings annotated with their determination (confirmed sound).
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md` — the same annotation pass, extended to the Scope Widening markdown re-confirmation, the Phase-20 Instrument A and Instrument B blocks, and a new "Running net-deletion figure, restated against the corrected baseline" table naming each figure's instrument.

## Decisions

- **The Phase-20 Instrument A field-set ambiguity is resolved, not left open.** The reading
  postdates the probe fix by roughly 27 hours yet lacked both trailing fields. `git merge-base
  --is-ancestor` confirmed both fix commits are ancestors of the reading's own commit, the commit
  message records an explicit redeploy immediately beforehand, and the source file at that commit
  contains both fields' code verbatim. Conclusion: the fields were trimmed when recording, not
  evidence of a stale copy.
- **The correction's magnitude is bounded, not estimated as exact.** `git log --diff-filter=A`
  from the Phase-1 baseline's own commit to HEAD returned 62 candidate files (larger than this
  plan's own 13-file estimate, because the full 19-day range to HEAD is wider than the Scope
  Hypothesis's narrower window). A 2.5-hour commit-log bracket around the exact capture instant
  showed zero concurrent sibling activity, narrowing the plausible untracked-at-capture set to
  empty — every candidate is attributable to either the parent task's own later phases or an
  unrelated sibling task's deliverable, dated hours to weeks after the capture instant.
- **Instrument B (the parent's authoritative acceptance figure) is unaffected by construction, not
  merely by timing.** It is a `git show --numstat` sum over named commits, each diffed against its
  own parent, and never consults the probe's corpus enumeration at all — this correction could not
  have moved it even had it been material.

## Plan Deviations

- **Task 5.1 (run the complete gate set)** altered: per this dispatch's own Batch Gate Deferral
  directive, this phase's full-gate obligation was discharged against a scoped tier
  (`run-all.sh --only test-validate-artifact.sh`, 1 passed/0 failed) rather than an independent
  `verify-deploy.sh` run, since this task modified only three `specs/**` markdown files with no
  mapped suite or gate. The complete gate set runs once for the whole `/orchestrate` batch and is
  attributed back to this task via its own `modified_files`.

## Verification

- Build: N/A (markdown-only changes)
- Tests: `run-all.sh --only test-validate-artifact.sh` → 1 passed, 0 failed (scoped per Batch Gate Deferral)
- Files verified: Yes — `validate-artifact.sh` passed for all three touched plan files
- Second probe reading, taken at this phase's close: `script-inventory: scripts=249 lines=97567
  test_suites=183 test_lines=87535 md_files=949 md_lines=232244 cost_per_assertion_ms=191.5
  untracked=0` — byte-identical to Phase 1's reading, zero drift across the interval

## Impacts

- The parent record's net-deletion acceptance determination is confirmed unchanged: the frozen
  Phase-1 baseline (232 scripts/90,568 lines; 160 suites/76,832 lines; 927 files/229,217 lines) is
  sound, and the authoritative acceptance figure (Instrument B: NET-PROD +498, NET-TEST +1,402,
  NET-MD −681, NET-TOTAL +1,219) was never exposed to the defect regardless.
- A reader of either parent plan file can now see, per figure, an explicit determination rather
  than an implicit assumption of soundness.

## Follow-ups

- The sibling probe `context-reachability.sh` was identified (by the record that fixed
  `script-inventory.sh`) as carrying the identical tracked-only, `git ls-files`-only enumeration
  defect. Not addressed here — belongs in its own record.
- The parent's `plans/01_corpus-consolidation-net-deletion.md` carries an unreconciled plan-level
  `- **Status**: [IMPLEMENTING]` marker against the superseding
  `plans/03_markdown-corpus-consolidation.md`'s `[COMPLETED]`. Noted as an out-of-scope
  status-hygiene matter at this record's own plan time; still unreconciled.
- The parent's own Phase 3 closing note already documented, independently and in real time, the
  identical `git ls-files`-based blind spot for an unstaged new file (instructing later phases to
  `git add` before trusting the probe's delta) — further corroborating evidence that the running
  per-phase deltas, as opposed to the one frozen baseline this record examined, carry low residual
  risk from this defect class.

## References

- `specs/485_recapture_corpus_baselines_under_corrected_probe/plans/01_recapture-corpus-baselines.md`
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/01_corpus-consolidation-net-deletion.md`
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md`
- `specs/429_script_inventory_undercounts_untracked_files/summaries/01_untracked-corpus-enumeration-summary.md`
