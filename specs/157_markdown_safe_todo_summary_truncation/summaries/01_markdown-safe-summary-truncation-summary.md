# Implementation Summary: Task #157

- **Task**: 157 - Markdown-safe TODO summary truncation
- **Status**: [COMPLETED]
- **Started**: 2026-09-08T23:00:00Z
- **Completed**: 2026-09-09T00:20:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_markdown-safe-summary-truncation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

The "Grouped by Topic" summary lines in `specs/TODO.md` were produced by a blind
character slice in `generate-task-order.sh` that could orphan an inline-code backtick
mid-span, and that read from `.description` even when a purpose-written `.title`
already existed. This implementation landed three coupled sub-fixes at the primary
source expression (`build_graph`'s `desc_data` jq pipeline) and mirrored the same
guarantees to the secondary cross-topic slice site (`_print_topic_node`'s
`short_desc`), added a new regression suite proven to fail against the pre-fix
script and pass against the fix, deployed and regenerated `specs/TODO.md` against
live data, and ported the fix to the `.opencode/` renderer mirror.

## What Changed

- `agent-system/extensions/core/scripts/generate-task-order.sh` — the `desc_data` jq
  expression in `build_graph()` now reads `(.title // .description // .project_name)`,
  strips inline-markup hazard characters (`` ` ``, `*`, `_`, `[`) before slicing,
  normalizes embedded newlines to spaces inside jq, and truncates only when over the
  65-char budget, backing off to the last word boundary and appending a `"..."`
  marker reserved within the budget. A new `truncate_word_boundary()` bash helper
  (placed next to `normalize_topic()`) replaces the second slice site's
  `${desc:0:40}` with the same word-boundary/marker guarantee, idempotent against an
  already-marked input so the two slice sites can never stack markers.
- `agent-system/extensions/core/scripts/tests/test-generate-task-order.sh` — new
  16-assertion regression suite (4 case groups: markdown safety, title preference,
  budget/word-boundary, cross-topic second slice site) plus a live-tree isolation
  guard. Uses a scratch-repo harness modeled on `test-errors-append.sh`, resolving
  the script under test source-store-first (the deliberate inversion documented in
  `test-postflight-deploy-gate.sh`) and its two unchanged dependencies deploy-first.
- `agent-system/extensions/core/manifest.json` — registered the new test file in
  `provides.scripts` (a doc-lint gate requirement discovered mid-implementation; see
  Plan Deviations).
- `.opencode/scripts/generate-task-order.sh` — the same two slice-site fixes and the
  supporting bash helper, ported verbatim per the established render-side-parity
  practice for this mirror. No other change; the mirror's substantial pre-existing
  divergence (no transitive-reduction block, no `deploy-root-guard.sh` sourcing) was
  left untouched, per plan scope.
- `specs/TODO.md` — regenerated (never hand-edited) from the fixed generator against
  live `specs/state.json`.
- `specs/157_markdown_safe_todo_summary_truncation/baseline-grouped-by-topic.txt` —
  pre-fix snapshot of the "Grouped by Topic" section plus live-measured coverage
  numbers, captured before any fix landed.
- `specs/157_markdown_safe_todo_summary_truncation/{pre,post}-fix-test-run.log` —
  the new suite's output against the unfixed (10/16 pass) and fixed (16/16 pass)
  script.
- `specs/157_markdown_safe_todo_summary_truncation/regenerated-grouped-by-topic-after.txt`
  — post-fix snapshot of the same section, for the baseline diff.

## Decisions

- **Strip, not balance.** Chosen approach for the markdown-safety sub-fix: strip
  `` ` ``, `*`, `_`, and `[` unconditionally before slicing, rather than appending a
  closing backtick when the naive count is odd. Stripping eliminates the whole
  hazard class at once and never fabricates a span around a truncated fragment. This
  was the plan's recorded default and real post-fix output gave no reason to
  reconsider it.
- **Budget includes the marker.** "No line exceeds the budget" is interpreted as the
  *total* rendered length (content + `"..."`) never exceeding the stated budget (65
  primary, 40 cross-topic) — so the cut point reserves 3 characters for the marker
  within the budget, rather than appending it on top of a full-budget slice.
- **One shared truncation algorithm, two implementations.** The jq-side
  `wb_truncate()` (inside `build_graph`) and the bash-side `truncate_word_boundary()`
  helper implement the identical word-boundary-backoff-plus-marker semantics in
  their respective languages, so the two slice sites cannot silently drift apart in
  behavior.
- **The witness line proves sub-fix (a) only.** Task 44's line (the operator-reported
  regression) is repaired by title preference alone — zero of the 26 live task titles
  contain a backtick, so the backtick-strip guarantee (sub-fix b) is never exercised
  by that witness. This was flagged as a trap in the task description and confirmed
  during Phase 1's baseline measurement; the adversarial fixtures in case group 1
  (backtick/asterisk/bracket placed deliberately at the cut boundary) are the sole
  proof of sub-fix (b).
- **The cross-topic 40-char branch has no live demonstration.** Live data contains
  exactly one real "(see above)" line (task 165), and it takes the plain
  full-`task_desc` branch, not the 40-char `short_desc` branch — that branch requires
  a specific Uncategorized-bridging topology the live topic graph does not currently
  form. Stated plainly rather than claimed; the synthetic fixtures in case group 4
  are the branch's only proof.

## Plan Deviations

- Registered `tests/test-generate-task-order.sh` in
  `agent-system/extensions/core/manifest.json`'s `provides.scripts` array. Not an
  explicit plan task, but required — the first deploy attempt failed doc-lint with
  `FAIL: script file on disk NOT in provides.scripts` until this was added. Any
  future task adding a new `scripts/tests/test-*.sh` file under any extension will
  hit the identical failure without this registration.

## Verification

- Build: N/A (shell scripts + jq)
- Tests: Passed — `test-generate-task-order.sh` 16/16 (0/16 pre-fix baseline: 10/16
  passed, demonstrating the 6 red cases spanning case groups 1, 2, 3, and 4's marker
  assertion, per the acceptance bar). Full suite: `run-all.sh` 79/79 passed
  (0 failed, 0 skipped), including the new suite discovered via glob, no
  registration edit needed.
- Files verified: Yes — deployed `.claude/scripts/generate-task-order.sh` and
  `.claude/scripts/tests/test-generate-task-order.sh` confirmed byte-identical to
  their source-store copies; `deploy-headless.sh` RESULT=landed_verify_clean, 33/33
  checks; `check-deploy-freshness.sh` clean; `check-task-references.sh --quiet`
  0 unexempted occurrences.

Live-data verification (Phase 5): zero odd-backtick lines across the whole
regenerated "Grouped by Topic" section; the task-44 witness line repaired and
explicitly attributed to sub-fix (a) only; every changed line (24 of 26
title-bearing tasks) read individually and judged more informative than what it
replaced, several bypassing administrative preambles (`=== REVISED`, `DEFECT:`,
`PRODUCER-SIDE`) entirely; no line exceeds the 65-char budget; title-less tasks
(51, 89, 127, 183, etc.) still render from `.description`, now with a clean
word-boundary cut instead of a silent mid-word truncation; no administrative
preamble fragment remains on any title-bearing task's line (only title-less task
127 still shows one, expected and unchanged per the plan's Non-Goals).

## Impacts

- `specs/TODO.md`'s "Grouped by Topic" section is markdown-safe by construction for
  every future regeneration, not just the currently-live task set.
- ~24 task summary lines in the live TODO.md became more informative (title instead
  of a truncated description fragment), a one-time content shift documented and
  read line-by-line in Phase 5 rather than merely diffed for count.
- The `.opencode/` mirror gained the same render-side fix, keeping the two renderers
  from drifting further apart on this specific defect class (though the mirror
  remains otherwise intentionally divergent).
- `scripts/tests/` gained its first coverage of `generate-task-order.sh` — previously
  entirely untested.

## Follow-ups

- None required by this task. Backfilling `.title` for the 12 currently title-less
  tasks (29, 30, 45, 51, 89, 127, 168, 183, 184, 185, 187, 188) would extend the
  content-quality improvement further but was an explicit Non-Goal here.
- The `.opencode/` mirror's substantial divergence from the core copy (missing
  transitive-reduction block, missing `deploy-root-guard.sh` sourcing) remains
  unaddressed by design; a future task could bring it to full parity if that mirror
  becomes active (no `OC_`-prefixed task directories exist today).

## References

- Plan: `specs/157_markdown_safe_todo_summary_truncation/plans/01_markdown-safe-summary-truncation.md`
- Baseline: `specs/157_markdown_safe_todo_summary_truncation/baseline-grouped-by-topic.txt`
- Post-fix section: `specs/157_markdown_safe_todo_summary_truncation/regenerated-grouped-by-topic-after.txt`
- Test suite: `agent-system/extensions/core/scripts/tests/test-generate-task-order.sh`
- Pre/post-fix run logs: `specs/157_markdown_safe_todo_summary_truncation/{pre,post}-fix-test-run.log`
- Phase handoffs: `specs/157_markdown_safe_todo_summary_truncation/handoffs/phase-{1..6}-handoff-*.md`
