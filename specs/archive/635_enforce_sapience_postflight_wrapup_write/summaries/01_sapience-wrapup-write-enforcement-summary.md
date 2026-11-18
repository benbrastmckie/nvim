# Implementation Summary: Task #635

- **Task**: 635 - Enforce the sapience postflight wrapup write at task completion
- **Status**: [COMPLETED]
- **Started**: 2026-11-17T10:35:40Z
- **Completed**: 2026-11-17T16:00:00Z
- **Effort**: ~5.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_sapience-wrapup-write-enforcement.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

The repo-tagged Sapience postflight wrapup write was prose-only (an `EXTENSION.md` instruction a
completing agent could simply not read), and measured evidence showed it fires intermittently.
This task anchors the *write* mechanically at a single new site,
`agent-system/extensions/sapience/scripts/postflight-sapience-notes.sh`, while leaving the
*note content* agent-authored: the completing implementation agent emits a bounded 3-8-item
`sapience_notes` array in `.return-meta.json`, and the new script performs one
`sapience-remember.sh` call per note, enforcing the 8-note ceiling mechanically and recording a
visible, non-blocking gap when the array is empty. The write site is wired at exactly three
invocation points across two core scripts — the live `/orchestrate` completion path
(`orchestrate-cycle-postflight.sh`) and the deferred completion path's two promotion arms
(`reconcile-task-status.sh`), which bypasses the live path's own propagation helpers entirely —
so both the live and deferred completion routes reach the same mechanical write.

## What Changed

- `agent-system/extensions/core/context/formats/return-metadata-file.md` — added the
  `### sapience_notes (optional)` field spec, sibling to `memory_candidates`, with the
  not-interchangeable statement.
- `agent-system/extensions/core/context/formats/issue-log.md` — added the `knowledge-capture
  gap` 17th seed class, with its seeded-on-introduction statement; bumped all count references.
- `agent-system/extensions/core/scripts/issue-record.sh` — added `knowledge-capture gap` to
  `ISSUE_SEED_CLASSES` and its comment copy; bumped count references.
- `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh` — bumped its own,
  previously-unsynced third copy of the seed-class array (a scope-hypothesis miss: the plan
  expected exactly 2 files for this grep, the real count was 4).
- `agent-system/extensions/core/context/standards/error-recovery-strategies.md` — bumped a
  fourth, plan-unnamed count reference.
- `agent-system/extensions/sapience/scripts/postflight-sapience-notes.sh` — new: the single
  write site (presence guard, fail-closed read, pre-write 8-note ceiling, 0-note gap, per-note
  degrade with continue-on-failure, usage-error-only non-zero exit).
- `agent-system/extensions/sapience/scripts/tests/test-postflight-sapience-notes.sh` — new:
  9-case, 31-assertion stubbed suite (`sapience-remember.sh` itself stubbed as a recorder).
- `agent-system/extensions/sapience/manifest.json` — registered both new scripts.
- `agent-system/extensions/core/scripts/tests/suite-classification.data` — classification row
  for the new suite.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — wired the guarded,
  `postflight_rc==0`-gated, non-fatal call in the `implemented)` case, plus its dry-run notice.
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` — wired the same guarded call
  in both the `implementing)` and `partial)` promotion arms, plus their dry-run notices.
- `agent-system/extensions/core/scripts/tests/test-reconcile-handoff-status.sh` — 6 new cases
  (12-17) exercising the live promotion path with both the write script and
  `update-task-status.sh` stubbed; all 20 cases in the suite PASS.
- `agent-system/extensions/core/agents/general-implementation-agent.md` — new `### Stage 6c:
  Emit Sapience Notes`; Stage 7's write-up and worked example updated.
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — new, phase- and
  presence-gated `sapience_notes_instruction` block (outside the `--clean` suppression path),
  reaching every domain implementation agent without editing five agent files.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — new Group
  23 (6 cases) asserting the block's presence/absence gating; full suite 238/238 PASS.
- `agent-system/extensions/sapience/EXTENSION.md` — "What this extension adds" and "Postflight
  wrapup" paragraphs rewritten to state the mechanical design; trimmed to the 60-line limit.
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` — "The
  Tagged-Write Call Site" and "No Lifecycle Hook" sections rewritten to name the new script and
  its three invocation points.
- `agent-system/extensions/core/index-entries.json`,
  `agent-system/extensions/sapience/index-entries.json` — regenerated stale `line_count` entries
  (`generate-context-line-counts.sh --write`).
- Regenerated: the deployed `.claude/**` tree via `deploy-headless.sh` (`landed_verify_clean`).

## Decisions

- Standalone script (`postflight-sapience-notes.sh`) rather than a `skill-base.sh` function,
  and placed under the sapience extension rather than core — both decisions carried from the
  plan's own Research Integration section, confirmed correct during implementation.
- The 8-note ceiling is a pre-write `jq length` check, never a running counter; the 3-note floor
  is agent-side guidance only, with the zero case recorded as a visible issue row.

## Plan Deviations

- **Phase 1 scope-hypothesis miss**: the grep for `16-class`/`16 seed`/`16 classes` was expected
  in exactly 2 files; the real count was 4 files, 10 occurrences (the plan's own 2 plus
  `orchestrate-conclusion-aggregate.sh`'s unsynced third copy and `error-recovery-strategies.md`).
  All 4 updated; one unrelated `system_defect`/`system-defect-record.sh` reference correctly
  left untouched (a different, unrelated closed enum).
- **Phase 1 `file_scope` widening**: two of the four files above were outside the task's
  initially-declared `file_scope`; widened via `state-write.sh` (dry-run verified first) since
  both are genuinely in-scope work, then landed via a scoped `git-commit-scoped.sh` follow-up.
- **Phase 4 record-versioning wording**: the plan's own prose ("a correction to a
  previously-held belief") triggered `check-record-versioning.sh`'s advisory lint in both edited
  files; reworded to "a correction to an assumption this task's work disproved" with no loss of
  meaning.
- **Phase 5 doc-lint regressions, fixed**: `EXTENSION.md` grew past the 60-line limit (Rule U)
  and two `core/index-entries.json` entries (for Phase 1's own edited files) went stale
  (Rule R). Trimmed `EXTENSION.md` to exactly 60 lines; regenerated all stale `line_count`
  entries repo-wide via `generate-context-line-counts.sh --write`, widening `file_scope` to
  cover both `index-entries.json` files first.
- **Phase 6 gate-8 incident**: including gate 8 in a `verify-deploy.sh --only-gate` list
  triggered its own internal unflagged full `run-all.sh` sweep under the `specs/.gate-lock`
  mutex — exactly the cost this dispatch's Batch Gate Deferral directive exists to prevent.
  Recovered by killing the stalled run and its orphaned job-worker children, releasing the
  stale gate-lock via the sanctioned `task-lock.sh gate-release` path, and re-running without
  gate 8 (whose own content was already covered by a separate, gate-lock-free
  `run-all.sh --only` suite-scoped run).

## Verification

- Build: N/A (meta task)
- Tests: All new/modified suites PASS — `test-postflight-sapience-notes.sh` (31/31),
  `test-reconcile-handoff-status.sh` (20/20), `test-orchestrate-build-dispatch.sh` (238/238).
  Scoped `run-all.sh --only` (8 suites) and `verify-deploy.sh --only-gate 3,4,5,22,29` both
  PASS against the deployed tree, per this dispatch's Batch Gate Deferral directive — the
  complete 29-gate battery and the complete suite set are deferred to the once-per-batch full
  sweep at the end of this `/orchestrate` invocation, not independently re-run here.
- Files verified: Yes (grep self-check confirms exactly 3 logical invocation points across 2
  files for `postflight-sapience-notes.sh`; live `--dry-run` attestation confirmed 4-note and
  0-note fixture behavior exactly as specified).

## Impacts

- Every future task reaching `[COMPLETED]` via either completion path now has its agent-authored
  `sapience_notes` written through a mechanical, non-instruction-dependent site, with a visible
  issue row whenever zero notes were emitted — closing the measured intermittent-write gap.
- Every domain implementation agent (lean/nix/neovim/email/etc.) now receives the emission
  instruction via the dispatch builder, without any of their own agent files being edited.

## Follow-ups

- `rules/sapience-write-path.md`'s "14 files under the source store path" governed-surface
  count is stale (actual: 10 `.md` files or 24 files-total under either reading); left unedited
  (out of this task's declared `file_scope`), recorded via `issue-record.sh` for separate triage.
- A pre-existing, unrelated "15-class" stale-count drift (8 occurrences across `agent-system/**`,
  predating this task's own 16->17 bump) was discovered and recorded via `issue-record.sh`, not
  fixed (out of scope).
- `test-deploy-baseline-lib.sh` (3 failing cases, gate-selection cache-corruption handling)
  surfaced during Phase 3's scoped suite run; confirmed pre-existing and unrelated via `git log`,
  recorded via `issue-record.sh`, not fixed.
- The `postflight:pr_ready -> completed` transition (a `type: pr` task's user-invoked `/merge`
  step) carries no agent return to read and is explicitly out of scope per the plan's own
  Non-Goals, with a one-line remedy named if ever measured to drop notes.

## References

- Plan: `specs/635_enforce_sapience_postflight_wrapup_write/plans/01_sapience-wrapup-write-enforcement.md`
- Report: `specs/635_enforce_sapience_postflight_wrapup_write/reports/01_sapience-postflight-wrapup-enforcement.md`
- Progress files: `specs/635_enforce_sapience_postflight_wrapup_write/progress/phase-{1..6}-progress.json`
- Handoffs: `specs/635_enforce_sapience_postflight_wrapup_write/handoffs/phase-{1..6}-handoff-*.md`
- Issues log: `specs/635_enforce_sapience_postflight_wrapup_write/issues.jsonl` (15 entries)
