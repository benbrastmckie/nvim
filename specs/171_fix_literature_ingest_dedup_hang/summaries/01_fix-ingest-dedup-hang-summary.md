# Implementation Summary: Fix literature ingest dedup hang

- **Task**: 171 - Fix the literature online-ingest hang caused by an O(n) per-title subprocess loop
- **Status**: [COMPLETED]
- **Started**: 2026-09-08T22:35:58Z
- **Completed**: 2026-09-08T22:42:02Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_fix-ingest-dedup-hang.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, .claude/rules/source-store-deploy-boundary.md

## Overview

`check_duplicate_title()` in `literature-ingest-online.sh` spawned one `python3` subprocess per
title in the global `index.json` (11,793 entries measured on `~/Projects/Literature/index.json`),
so every `in_zotero_no_pdf`/`open_access` ingest stalled roughly 9-10 minutes (or timed out at
540s, rc=124, with no directive token) before the non-blocking dedup check finished. All 4 plan
phases are implemented and verified: `.zotero-title-sim.py` gained an additive `--batch` mode,
`check_duplicate_title()` was rewritten as one hard-timed, fail-open batch invocation, a
regression suite locks the contract in, and both the script header and the tools doc were
updated.

## What Changed

- `agent-system/extensions/literature/scripts/.zotero-title-sim.py` — Added a `--batch
  <candidate-title>` mode (existing titles read from stdin, one per line) that short-circuits to
  score `1.0` on the first normalized-equality match and otherwise keeps the first strict-maximum
  `SequenceMatcher` ratio, matching the tie-break order of the replaced shell loop. The 2-argv
  CLI contract (`sim.py TITLE_A TITLE_B` -> one float) and `normalize()` are byte-for-byte
  unchanged; `zotero-resolve-pdf.sh`'s `title_similarity()` still uses that path untouched.
  Docstring updated to name both consumers and both modes.
- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` —
  `check_duplicate_title()` rewritten from a `while read` loop spawning one `python3` process per
  title into a single `jq | timeout 10 python3 --batch` pipeline. Fail-open: any timeout,
  non-zero exit, empty output, or output line that doesn't parse as `<score><TAB><title>` is
  treated as "no duplicate found" and the function always returns 0 (guarded so `set -euo
  pipefail` cannot turn a fail-open branch into a script abort). The `WARNING: possible duplicate
  --` line and the `0.85` threshold are preserved byte-for-byte. Two header-comment paragraphs
  (`ONLINE_INGEST_DUPLICATE_DETECTED` description and the EXPORT FRESHNESS + LIVE DEDUP GUARD
  paragraph) updated to describe the bounded, fail-open behavior. No call site
  (`:721`→`:724`/`:835`→`:838` after the edit), directive token, or exit code changed.
- `agent-system/extensions/literature/scripts/tests/test-title-sim-dedup.sh` — New regression
  suite (house pattern: `t_log`/`t_pass`/`t_fail`, `mktemp -d` + `trap ... EXIT`, corpus-mutation
  guard). 11 assertions covering: the 2-argv contract (identical/wrong-arity/punctuation-only),
  batch exact-normalized short-circuit, batch first-strict-maximum tie-break, batch
  empty/all-blank stdin, `check_duplicate_title()` end-to-end WARNING emission on a genuine
  (non-short-circuited, ~0.8738-scoring) near-duplicate, no-WARNING on sub-0.85 similarity, and
  fail-open on both a missing and an invalid-JSON `index.json`. Verified to actually catch a
  regression: reverting the threshold to `0.99` makes the suite fail (10 passed, 1 failed) before
  being restored.
- `agent-system/extensions/literature/manifest.json` — Registered
  `tests/test-title-sim-dedup.sh` under `provides.scripts`, alongside the other 5
  `tests/`-prefixed entries.
- `agent-system/extensions/literature/context/project/literature/tools/zotero-scripts.md` — Added
  a "Duplicate-Title Dedup Check" subsection documenting the recommendation-only, single-bounded-
  invocation, 0.85-threshold, fail-open contract, and pointing to the new regression suite.

## Decisions

- Batch mode reads existing titles from **stdin**, not argv, to avoid any `ARG_MAX` risk against
  an 11k+-entry index — this was an explicit plan requirement, not a later choice.
- `check_duplicate_title()` keeps a hard `timeout 10` wrapper even though real-corpus timing
  measured well under 1 second, per the plan's fail-open safety requirement (defense against a
  future corpus size increase or a pathological `index.json`).
- The near-duplicate test fixture was deliberately chosen to score inside `(0.85, 1.0)` via real
  `SequenceMatcher` scoring rather than via the normalized-equality short-circuit (which would
  always score `1.0` regardless of the threshold and could not catch a threshold regression) —
  this was necessary to make the deliberate-break verification meaningful; an initial
  normalized-identical fixture (`"...Processing"` vs `"...Processing!"`) failed to catch a
  threshold break and was replaced with `"...Processing Applications"` (score ≈0.8738).

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A (shell/python, no build step)
- Tests: Passed — `bash -n` clean, `python3 -m py_compile` clean, new suite 11/11 PASS (and
  correctly FAILS when the threshold is deliberately broken), existing suites unaffected:
  `test-literature-build-index.sh` 9/9, `test-literature-discover-tier3.sh` 27/27 (exercises
  `literature-ingest-online.sh --dry-run` directly), `test-literature-convert.sh` 30/30.
  `shellcheck` was not available in this environment (not installed) so the pre/post-edit
  baseline diff step from the plan's Phase 2 verification could not be run; `bash -n` and the
  functional test suites are the substitute evidence of correctness.
- Files verified: Yes — every file in "What Changed" confirmed to exist and match the intended
  diff via `git diff`/`git diff --stat` after each phase's commit.

**Measured timing** (the acceptance bar): against the real, read-only
`~/Projects/Literature/index.json` (11,793 entries, confirmed via `jq '.entries | length'` both
at plan time and again at implementation time), a direct call of the new
`check_duplicate_title()` pipeline completed in **~0.7 seconds** (measured with `time`), versus
the task description's observed **9-10 minutes** (or a 540s/rc=124 timeout with no directive
token at all) for the old per-title-subprocess loop. This is comfortably inside "low
single-digit seconds," the plan's stated acceptance bar. No corpus data was written by any
verification step; `stat -c %Y` on the real `index.json` was unchanged before/after test runs.

## Impacts

- Any `in_zotero_no_pdf` or `open_access` online-ingest call now completes its (still
  non-blocking, recommendation-only) duplicate-title check in well under a second instead of
  stalling 9-10 minutes or timing out; the caller in `commands/literature.md` will see a directive
  token promptly instead of a silent multi-minute hang indistinguishable from a wedged process.
- `zotero-resolve-pdf.sh`'s `title_similarity()` scores are unaffected — it still uses the
  unmodified 2-argv code path.

## Follow-ups

- **Redeploy required**: this fix lives in the source store
  (`agent-system/extensions/literature/**`) per `.claude/rules/source-store-deploy-boundary.md`.
  The running `.claude/scripts/literature-ingest-online.sh` and
  `.claude/scripts/.zotero-title-sim.py` deploy copies are stale until the user runs a
  regeneration/redeploy. The sibling `literature-briefing.sh` SIGPIPE defect referenced in the
  task description is likewise already fixed in this source store (now using
  `jq -c first(...)`) and only awaits the same redeployment — no code changes for it were made or
  needed in this task.
- **Observation (not part of this task's scope)**: during implementation, `git status` showed two
  unrelated plan files with small (2-line) uncommitted modifications that this task did not
  create or touch: `specs/157_markdown_safe_todo_summary_truncation/plans/01_markdown-safe-summary-truncation.md`
  and `specs/186_fix_deploy_headless_path_in_regeneration_doc/plans/01_fix-deploy-headless-invocation-path.md`.
  These were left untouched (not staged, not committed) by every commit in this task, which used
  targeted path lists rather than `git add -A`. Flagging per the observation-duty contract in
  case they represent in-flight work from a concurrent session.

## References

- Plan: specs/171_fix_literature_ingest_dedup_hang/plans/01_fix-ingest-dedup-hang.md
- Dispatch: specs/171_fix_literature_ingest_dedup_hang/.dispatch/5.md
- New regression suite: agent-system/extensions/literature/scripts/tests/test-title-sim-dedup.sh
