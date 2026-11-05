# Implementation Summary: Task #328 — Phase 10

- **Task**: 328 - Systematic top-to-bottom consolidation of the shell script and test corpus under `agent-system/extensions/**`
- **Status**: [IN PROGRESS]
- **Started**: 2026-11-05T15:05:00Z
- **Completed**: 2026-11-05T15:28:00Z
- **Effort**: ~25 minutes
- **Dependencies**: None (Phase 10 depends on Phase 2, already completed)
- **Artifacts**: plans/03_markdown-corpus-consolidation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closes Phase 10 of the plan: deduplicated the mutual duplicate-block pair
`chapter-quality-check.sh` / `typst-element-lint.sh` in the typst extension by extracting their
shared ANSI-color palette, CLI option-parsing loop, and recursive `.typ`-file collection loop into
a new typst-extension-local library, `agent-system/extensions/typst/scripts/lib/
typst-scan-lib.sh`. 11 of 20 plan phases now remain `[NOT STARTED]` (Phase 11 next).

## What Changed

- `agent-system/extensions/typst/scripts/lib/typst-scan-lib.sh` — new file (108 lines). Provides
  the shared color palette and two functions, `typst_scan_parse_args` and
  `typst_scan_collect_files`, each called once per consuming script. Six `shellcheck
  disable=SC2034` annotations added (each with an inline reason) for the color/VERBOSE globals,
  which are consumed only by the sourcing script, not by this library itself, and so register as
  unused under shellcheck's single-file analysis.
- `agent-system/extensions/typst/scripts/chapter-quality-check.sh` — sources the new library;
  removed its own copy of the color palette and the CLI-parsing/file-collection blocks (763 -> 707
  lines).
- `agent-system/extensions/typst/scripts/typst-element-lint.sh` — same change (370 -> 316 lines).
- `agent-system/extensions/typst/manifest.json` — registered `lib/typst-scan-lib.sh` in
  `provides.scripts` (committed as a follow-up commit; `git-commit-phase.sh`'s containment
  self-check correctly dropped it from the phase-closing commit because this path is not itself
  named in task 328's declared `file_scope`).

## Decisions

- Both scripts already carried paired fixture suites, so the Paired-Test Coverage precondition
  was satisfied without writing a new characterization test (unlike Phase 9's install/uninstall
  pair, which had none).
- Kept the new library typst-extension-local rather than moving it to core, per the plan's own
  instruction — extension independence is a deliberate property of the layout and neither script
  has a consumer outside the typst extension.
- Extracted exactly the shared surface `script-inventory.sh`'s 10-line sliding-window detector
  flagged (color palette + CLI loop + file-collection loop), leaving every check function
  (placement, remark item-count/density/presence, backtick-path resolution, citation-key
  resolution, heading depth, CONFIRM-comment well-formedness, claim ratio, hedging/filler,
  paragraph length, judged-rule prompts) untouched.
- Verified behavioral equivalence via byte-identical `diff` of both scripts' output over a
  constructed scratch fixture (exercising every finding class in both scripts) plus four CLI edge
  cases per script (no PATH, `--help`, a nonexistent PATH, an unknown option) — eight captures
  total, all identical before and after the refactor.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (shell scripts, no build step)
- Tests: Passed — `run-all.sh --only test-chapter-quality-check.sh,test-typst-element-lint.sh`
  (2/2) and `test-manifest-scripts-sync.sh` (1/1), both before and after the refactor
- Files verified: Yes — `bash -n` syntax check on all three touched/new shell files;
  `lint-shellcheck.sh` clean (0 findings) on all three
- Byte-identical finding output confirmed on 8 captures (4 CLI edge cases x 2 scripts) plus a
  scratch fixture exercising every check in both scripts

## Impacts

- `script-inventory.sh`'s duplicate-block count for this pair drops from 44/44 to 0/0.
- NET-PROD for this phase: -2 lines (`git diff --numstat`: `chapter-quality-check.sh` 4 ins/60
  del, `typst-element-lint.sh` 5 ins/59 del, `lib/typst-scan-lib.sh` +108/-0 new file;
  manifest.json's 2 ins/1 del excluded, consistent with Phase 9's convention since
  `script-inventory.sh`'s line totals cover `*.sh` only). Independently confirmed via raw line
  counts: 763+370=1,133 before vs. 707+316+108=1,131 after. NET-TEST for this phase: 0 (no new
  test file required).
- Small yield relative to Phase 9's -70 because this pair's shared mass was only the CLI/output
  skeleton, not large per-type loops — matching Phase 2's own derived bound of -30 to -70 for this
  cluster.

## Follow-ups

- Phase 11 next: `literature/scripts/literature-search.sh`'s self-internal repetition — 5 Python
  helper definitions re-embedded verbatim inside 5 separate `python3` heredocs (not repeated bash;
  a different fix shape than Phases 9-10). Re-run `script-inventory.sh` at phase start before
  acting, per the plan's own measurement-discipline requirement.
- 10 of 20 plan phases remain `[NOT STARTED]` (11-20).

## References

- Plan: `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md` (Phase 10 section)
- Handoff: `specs/328_systematic_script_and_test_corpus_efficiency/handoffs/phase-10-handoff-20261105T151401Z.md`
- Progress: `specs/328_systematic_script_and_test_corpus_efficiency/progress/phase-10-progress.json`
