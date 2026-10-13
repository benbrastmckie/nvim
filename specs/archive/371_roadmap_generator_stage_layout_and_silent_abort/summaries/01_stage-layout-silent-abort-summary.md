# Implementation Summary: Task #371

- **Task**: 371 - Teach roadmap-integration.sh the stage-based ROADMAP layout and fix its silent abort
- **Status**: [COMPLETED]
- **Started**: 2026-10-10T00:38:45Z
- **Completed**: 2026-10-10T03:45:00Z
- **Effort**: ~3 hours
- **Dependencies**: None
- **Artifacts**: plans/01_stage-layout-silent-abort-plan.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`core/scripts/roadmap-integration.sh` hardcoded an eight-header classic section vocabulary, so
against a stage-based `specs/ROADMAP.md` (the layout BimodalLogic's own commit `5e28ad981`
restructured to) every section extraction returned empty, which killed `--regenerate` silently
under `set -euo pipefail` and made `--prune` silently succeed at wiping ~280 lines of authored
content. This task landed six phases: an always-present stderr marker plus a named `ERROR:`
diagnostic line on every failure path; a permanent, structural layout-recognition gate that
refuses loudly (named reason, non-zero exit, no write) on a vocabulary neither write mode can
round-trip; the single unguarded no-match-as-error pipeline (plus one more found by this task's
own audit); full stage-layout round-trip support for both `--regenerate` and `--prune`, built on
byte-for-byte retention of every authored section; and an updated `roadmap-format.md` generation
contract describing both recognised layouts.

## What Changed

- `agent-system/extensions/core/scripts/roadmap-integration.sh` — hoisted `task_count`/`topic_count`
  earlier; added `emit_marker()` (EXIT trap, `MARKER_EMITTED` guard) and an `ERR` trap emitting a
  named failure line; added `detect_layout`/`refuse_unrecognised_layout`
  (classic/stage/unknown classification and the permanent destructive-overwrite refusal); guarded
  `covered_ids_from()`'s pipeline (the reported crash site) and one additional unguarded pipeline
  this task's own code introduced; added `split_sections`/`assemble_stage_roadmap` (a
  vocabulary-agnostic, position-based section splitter/reassembler) and `mode_regenerate_stage`/
  `mode_prune_stage` (full stage-layout round-trip support, reusing `prune_next_body` unmodified).
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` — grew from 28 to 68
  passing cases: failure-path diagnosability, unknown/stage-vocabulary refusal, the exact
  empty-`## Next` crash reproduction (now passing), full stage-layout round-trip (byte-for-byte
  section retention, inline fence comment survival, idempotence, appendix replacement), and
  stage-layout `--prune` (terminal-line dropping, comment-line survival, dry-run no-op).
- `agent-system/extensions/core/context/formats/roadmap-format.md` — rewrote `## Section Order`
  to describe both layouts (classic's literal eight headers; stage's structural predicate); added
  a "Destructive-Overwrite Refusal (permanent property)" subsection; amended `## Generation`'s
  marker paragraph with the precise scope and the separate `ERROR:` line; documented stage
  `--prune` semantics.
- `agent-system/extensions/core/index-entries.json` — `roadmap-format.md`'s `line_count`
  auto-repaired (163 -> 226) by `deploy-headless.sh`.

## Decisions

- Layout detection is structural (a `^## Stage [0-9]+` header plus a fenced `/orchestrate` block),
  never exact-header matching — survives the cosmetic stage-header renames already observed
  between one regenerate pass and the next in the real regression fixture.
- The stderr marker's six-field shape is frozen (per the plan's Decision 2); diagnosability is
  delivered via a separate `ERROR:` line instead of a new marker field, since the marker's regex
  is pinned elsewhere and a caller doc (out of this task's scope) relies on its exact shape.
- `split_sections` locates sections by line-number POSITION from one `grep -n` pass, not by
  re-matching header text the way the classic layout's `extract_section` does — deliberately more
  robust against two stage sections sharing identical header text.
- `prune_next_body` was reused completely unmodified for the stage layout's run-order section; the
  plan's declared fallback (refuse loudly if comment lines don't survive) was not needed, since
  comment-line survival was confirmed directly.

## Plan Deviations

- None. All six phases' tasks were completed as planned; Phase 6 closed
  `[COMPLETED WITH EXCLUSIONS]` for one explicitly reasoned, evidenced, out-of-scope exclusion
  (see Verification below), not a deviation from what this task's own scope controls.

## Verification

- Build: N/A (bash scripts)
- Tests: `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` — 68/68 passed.
  `agent-system/extensions/core/scripts/tests/run-all.sh` (whole suite) — 135/136 suites passed;
  the one failure is a pre-existing, unrelated latent defect (see Follow-ups).
  `bash .claude/scripts/verify-deploy.sh` (full battery, no `--skip-slow`) — 35/36 checks passed,
  same one unrelated exclusion. `deploy-headless.sh`'s own fast-gate verification (what every
  normal deploy runs): `RESULT=landed_verify_clean`, 35/35.
- Files verified: Yes
- Real-fixture verification (read-only, never written): BimodalLogic's `specs/ROADMAP.md` at
  commit `c9ea5ac36` now classifies `stage` and round-trips cleanly under both `--regenerate`
  (diff confined to one added coverage-appendix block) and `--prune` (diff confined to dropped
  all-terminal Run lines); previously this crashed `--regenerate` silently and would have let
  `--prune` wipe ~280 lines. This repository's own classic `specs/ROADMAP.md`:
  `--regenerate --dry-run` exits 0, diff confined to generated `## Open work` status tokens, live
  file confirmed untouched throughout.

## Impacts

- `/orchestrate`'s conclusion-stage Step 5 (roadmap regeneration) is no longer a silent no-op
  against a stage-based `specs/ROADMAP.md` in any consumer repository using that layout.
- The destructive-overwrite refusal is now a standing, permanent property: any future roadmap
  vocabulary this generator cannot round-trip is refused loudly rather than silently guessed at
  or overwritten.

## Follow-ups

- **`prune_next_body()` CLI-flag-parsing bug** (discovered during Phase 5's real-fixture
  verification, pre-existing, affects classic and stage layouts identically, NOT fixed here): a
  Run line's task list followed by a CLI flag before its rationale comment (e.g.
  `/orchestrate 716,714 --hard   # rationale`) gets the flag text concatenated onto the last task
  id, which then fails the active-ids lookup and is wrongly dropped as if terminal — in one
  minimal reproduction against the classic layout, an entire Run line collapsed to empty, silently
  dropping an active task's scheduling. Recommend a follow-up task.
- **`test-verify-deploy-context-budget.sh` fixture defect** (discovered during Phase 6's full
  gate-set run, pre-existing, unrelated to this task's file scope, NOT fixed here): the fixture
  `git init`s a scratch directory but never `git add`s it, so Gate 22's `git ls-files`-based file
  discovery finds zero `.sh` files and the baseline case fails unconditionally. Recommend a
  follow-up task (the fix is a one-line `git add -A && git commit` addition to that test's
  fixture setup).
- Both findings are recorded in this task's own issue log
  (`specs/371_roadmap_generator_stage_layout_and_silent_abort/issues.jsonl`).

## References

- Plan: `specs/371_roadmap_generator_stage_layout_and_silent_abort/plans/01_stage-layout-silent-abort-plan.md`
- Research: `specs/371_roadmap_generator_stage_layout_and_silent_abort/reports/01_stage-layout-silent-abort-research.md`
- Script: `agent-system/extensions/core/scripts/roadmap-integration.sh`
- Format spec: `agent-system/extensions/core/context/formats/roadmap-format.md`
- Test suite: `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh`
