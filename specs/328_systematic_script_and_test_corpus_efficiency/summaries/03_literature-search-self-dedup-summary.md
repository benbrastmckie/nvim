# Implementation Summary: Task #328 — Phase 11

- **Task**: 328 - Systematic top-to-bottom consolidation of the shell script and test corpus under `agent-system/extensions/**`
- **Status**: [IN PROGRESS]
- **Started**: 2026-11-05T19:01:00Z
- **Completed**: 2026-11-05T19:45:00Z
- **Effort**: ~45 minutes
- **Dependencies**: None (Phase 11 depends on Phase 2, already completed)
- **Artifacts**: plans/03_markdown-corpus-consolidation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closes Phase 11 of the plan: collapsed `literature-search.sh`'s 172 self-internal duplicate
blocks (`peers=0` — the densest single-file duplication the corpus probe reports, and the one
target in this plan with no pre-existing paired test suite). Wrote the mandatory
characterization test first, confirmed it green on the unmodified script, extracted the
repeated Python helpers into a new file-local module, and confirmed the refactored script's
output is byte-identical to the original across all 20 tested CLI modes. 9 of 20 plan phases
now remain `[NOT STARTED]` (Phase 12 next).

## What Changed

- `agent-system/extensions/literature/scripts/tests/test-literature-search.sh` — new
  characterization suite (384 lines, 49 assertions). No paired test existed before this phase
  (`has_test: false`). Builds a from-scratch fixture local+global literature corpus (4 docs
  across verified/unverified fidelity and tagged/untagged projects, a local/global doc_id
  collision, chunk relations, and adjacency links) and exercises every documented CLI mode:
  default search, `--include-unverified`, `--project` filtering (both the scoped-match case and
  the zero-scoped-result unscoped-retry case), `--multi`, `--read` (verified/unverified/missing),
  `--toc`/`--doc`, `--refs`, `--next`/`--prev`, and 6 error paths. Every mode's raw stdout+exit
  code is captured under a `$CAPTURE_DIR` so a before/after run can be `diff -r`'d.
- `agent-system/extensions/literature/scripts/lib/literature_search_pylib.py` — new file-local
  Python module (332 lines). Holds `load_fidelity_map`, `get_fidelity`, the
  `TIER_RANK`/`ROW_TIER_LABEL` tier vocabulary, `ensure_trigram`, `build_sql`, `run_ladder`,
  `search_db`, and `run_single_search` — every helper that was previously re-defined inside
  multiple separate `python3` heredocs within `literature-search.sh` because a heredoc cannot
  `import` a function defined in a sibling heredoc of the same shell script. File-local to
  `literature-search.sh` by design (that script has `peers=0`; a cross-extension shared lib
  would add an import surface with no second consumer to justify it).
- `agent-system/extensions/literature/scripts/literature-search.sh` — 1,645 → 950 lines
  (`git diff --stat`: +30/-725). `do_search()`, `do_multi_search()`, `do_read()`, and `do_toc()`
  now `sys.path.insert` the lib directory and import the shared helpers instead of redefining
  them. The single largest duplicate block — `do_search()`'s entire ~230-line "re-run the whole
  search a second time without the project filter" fallback (an almost-complete second copy of
  the primary search pipeline, triggered when a project-scoped query returns zero rows) —
  collapsed into an in-process retry inside the new `run_single_search()` helper, eliminating a
  second, separately-interpolated `python3` heredoc invocation entirely rather than merely
  deduplicating its helper functions.
- `agent-system/extensions/literature/manifest.json` — registered the two new files in
  `provides.scripts` (committed as a follow-up commit; `git-commit-phase.sh`'s containment
  self-check correctly dropped both this path and the new `lib/` file from the phase-closing
  commit because neither is itself named in task 328's declared `file_scope`, which only covers
  `literature/scripts/literature-search.sh` and `literature/scripts/tests/` — the same pattern
  Phase 10's `typst/manifest.json` follow-up commit already established).

## Decisions

- Extracted to a Python module rather than restructuring the bash-level heredoc plumbing: each
  `do_*` function still spawns one `python3` process per call (no behavior change to process
  count per search, except the collapsed fallback case above), but every heredoc now imports
  from one shared, file-local module instead of repeating the same function bodies.
- Kept `TIER_RANK` in the shared module even though it is dead code (defined, never read,
  verified by `grep` across the original file) — a verbatim move preserves the "no behavior
  change" property the byte-identical diff is meant to verify; removing dead code was out of
  this phase's scope.
- Did not attempt to also collapse `do_read`/`do_toc`'s per-call `python3` process spawn into the
  shared module's search path — they are structurally distinct queries (point lookup / listing,
  not FTS5 search) and only shared the fidelity-map helpers, which are now imported rather than
  duplicated.

## Plan Deviations

- None (implementation followed plan). The phase's own "Tier Justification" named
  `run-all.sh --only <the script's suite, or the characterization test written in this phase>`
  as the covering check; since no prior suite existed, the newly written
  `test-literature-search.sh` is that check, run directly (not yet wired into
  `tests/run-all.sh`'s discovery, which the plan's later phases and `tests/run-all.sh`'s own
  existing auto-discovery convention are expected to pick up without a dedicated phase step).

## Verification

- Build: N/A (bash + Python, no compiled artifact).
- Tests: `bash agent-system/extensions/literature/scripts/tests/test-literature-search.sh` — 49/49
  passed, both on the unmodified script (baseline capture) and on the refactored script.
  `bash agent-system/extensions/literature/scripts/test-lit-pipeline.sh` — 8/8 passed (sanity
  check on a real downstream caller's wiring). `shellcheck -x literature-search.sh` — clean.
  `bash -n literature-search.sh` — clean.
- Files verified: Yes. `diff -r` of the full `$CAPTURE_DIR` tree from the before-run against the
  after-run (40 captured stdout/exit files across 20 CLI modes) reported zero differences.

## NET-PROD / NET-TEST Accounting

- `literature-search.sh`: 1,645 → 950 lines (git diff: +30/-725, net **-695**).
- `lib/literature_search_pylib.py` (new, file-local, counted as production code backing this one
  script): **+332** lines.
- **NET-PROD this phase: -695 + 332 = -363** (negative, as the phase's verification requires).
- `manifest.json`: +2 lines, excluded from NET-PROD per the convention Phase 9 established.
- `tests/test-literature-search.sh` (new, necessary because `has_test` was `false` going in):
  **NET-TEST +384**. Not counted toward NET-PROD and not required negative by this phase's own
  verification criteria (unlike the markdown/test-harness phases later in this plan, which do
  carry a NET-TEST reduction requirement).
- `duplicate_blocks` for this file: 172 → 0 (`script-inventory.sh`, re-measured post-refactor).

## Impacts

- `literature-briefing.sh`, `literature-ingest.sh`, `literature-term-match.sh`,
  `literature-doc-key.sh`, `literature-fidelity-audit.sh`, and `test-lit-pipeline.sh` all invoke
  `literature-search.sh` only as an external CLI subprocess (confirmed via `grep`: no caller
  `source`s it), so the fully-preserved CLI contract (identical flags, identical stdout/exit
  shapes, confirmed byte-identical) means none of them required any change.
- `literature-search.sh` now has its first paired characterization test, closing the `has_test:
  false` gap `script-inventory.sh` previously reported for this file.

## Follow-ups

- The follow-up commit registering `manifest.json` and the new `lib/` file (same pattern as
  Phase 10's typst follow-up) should land immediately after the phase-closing commit.
- `tests/test-literature-search.sh` is not yet referenced by any `run-all.sh --only` convenience
  alias; a later phase wiring the corpus-wide suite-classification/selection surface (Phase 12-14)
  should pick it up through the existing auto-discovery mechanism rather than needing a dedicated
  step.

## References

- `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md`
  (Phase 11)
- `specs/328_systematic_script_and_test_corpus_efficiency/progress/phase-11-progress.json`
