# Implementation Summary: Task #676

- **Task**: 676 - Tag transcript-captured KOs with the repo tag
- **Status**: [COMPLETED]
- **Started**: 2026-11-20T21:00:00Z
- **Completed**: 2026-11-20T23:15:00Z
- **Effort**: ~2 hours
- **Dependencies**: None
- **Artifacts**: plans/01_tag-pending-kos-repo-tag.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added `agent-system/extensions/sapience/scripts/sapience-tag-pending.sh`, an extension-owned
script that injects a literal `[repo:<slug>]` tag into the `provenance` field of every
still-pending, resolvable record in `~/.sapience/pending_kos.jsonl`, between `sapience sync` and
`sapience review`. The slug resolution is identical in outcome to `sapience-remember.sh`'s
(`capture.projects[].name` -> `path_prefix` -> the shared `resolve_checkout_toplevel()` block ->
`basename`). All four plan phases completed: the script itself, a 14-case fixture-driven test
suite plus the extended byte-identity lockstep guard, a corrected population census and
operational-sequencing documentation, and a clean redeploy with a scoped verification sweep.

## What Changed

- `agent-system/extensions/sapience/scripts/sapience-tag-pending.sh` — new script: dry-run by
  default, `--write` to mutate; wraps the whole read-mutate-write cycle in a blocking exclusive
  `flock` on `~/.sapience/.ledger.lock`; writes back via `<path>.tmp.$$` + `mv` at mode `0600`;
  composes rather than clobbers an existing non-empty `provenance`.
- `agent-system/extensions/sapience/scripts/tests/test-sapience-tag-pending.sh` — new 14-case
  fixture-driven suite (cases a-j), entirely against a synthetic fixture `HOME`.
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` — Case 30's
  `LOCKSTEP_FILES` array extended to a ninth entry; pass-message/comment counts updated.
- `agent-system/extensions/sapience/manifest.json` — registered both new files under
  `provides.scripts`.
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` —
  rewrote population 3 of the four-population census to describe the live `extract_local.py`
  pipeline (was incorrectly attributed to the dead `upload.py` path in two places); added an
  "Operational Sequencing for Pending-Ledger Tagging" subsection covering the sync -> tag ->
  review ordering, the permanence of an already-posted record, and the operator-only one-record
  empirical confirmation step.
- `agent-system/extensions/sapience/EXTENSION.md` — "What this extension adds" now names four
  scripts (was three), including the new one's role.
- `agent-system/extensions/sapience/README.md` — File Inventory table gained a row for the new
  script.
- `agent-system/extensions/sapience/index-entries.json` — `line_count` for the per-repo-scoping
  context entry synced after the doc's growth (mechanical, deploy-time regeneration).

## Decisions

- No deploy-root-guard/`PROJECT_ROOT` sourcing in the new script: unlike
  `sapience-remember.sh`/`sapience-retrieve.sh`, it is not scoped to "this repo" — it resolves a
  slug per record across every `capture.projects[]` entry, each potentially a different repo.
- The ledger lock wraps the entire read-mutate-write cycle (acquired before the ledger is read),
  not just the final `mv`, closing the exact lost-write race `extract_local.py`'s own
  `_ledger_lock` class was built to prevent.
- Backfilling already-uploaded, untagged KOs and running the live `--write` pass against the
  real ledger are both left to the operator, per the plan's non-goals and the task's non-blocking
  `user_decision` (which recommended, and was not contradicted, shipping and fixture-testing
  only).

## Plan Deviations

- None (implementation followed the plan). Two real defects were found and fixed during
  implementation, both before any checklist item was marked done: (1) the first draft of the
  `--write` jq rewrite omitted `-c` (compact mode), which pretty-printed rewritten records across
  multiple lines and broke the ledger's one-JSON-object-per-line invariant — caught by a fixture
  idempotence test and fixed; (2) the Phase 3 `EXTENSION.md` edit initially pushed the file to 63
  lines, exceeding `check-extension-docs.sh`'s 60-line Rule U — caught by the Phase 4 deploy
  verification and fixed by trimming the paragraph.

## Verification

- Build: N/A (shell scripts; `bash -n` passes on both new files)
- Tests: Passed — `test-sapience-tag-pending.sh` 14/14, `test-sapience-mcp-registration.sh` 55/0
  (both from the source store and again from the deployed tree), `test-manifest-scripts-sync.sh`
  21/0, `test-script-inventory.sh` 32/0, and a 34-suite `run-all.sh --only` roster covering every
  touched `.sh`/`manifest.json` path, all passing (see Follow-ups for the one contention note).
- Files verified: Yes — deploy confirmed present and executable in `.claude/scripts/`, the
  `.claude/CLAUDE.md` merge and the `.claude/context/project/sapience/` mirror both carry the
  updated content, and `deploy-headless.sh`'s own verification sweep passed 41/0 after the Rule
  U fix.
- Live ledger: `~/.sapience/pending_kos.jsonl` (3757 records: 1687 `.dotfiles`, 1260 `nvim`, 810
  `sapience-app`; 0 carrying a `provenance` key both before and after) is byte-identical
  (`sha256sum`) across every dry-run and test invocation performed during this whole
  implementation. No `--write` was ever run against it; `sapience sync`/`sapience review` were
  never invoked.

## Impacts

- Once the operator runs `sapience sync` -> `sapience-tag-pending.sh --write` -> `sapience
  review`, newly-posted transcript-capture knowledge objects become retrievable via
  `sapience-retrieve.sh`'s repo-scoped `source=[repo:<slug>]` filter, closing the gap the task
  description measured (39 untagged vs. 4 tagged on an nvim-topic search).
- The already-uploaded untagged population (the 39-vs-4 gap's existing half) remains permanently
  untagged: the vault's KO surface offers create and read only, with no update or delete API, so
  this backfill was never in scope and stays that way.

## Follow-ups

- **Operator action required**: run `sapience sync`, then `scripts/sapience-tag-pending.sh
  --write` (or the deployed `.claude/scripts/sapience-tag-pending.sh --write`) against the real
  ledger, then `sapience review`/`sapience review --all`. Before trusting the mechanism at
  scale, perform the one-record empirical confirmation named in the plan: tag and post a single
  record, then confirm it is retrievable via `scripts/sapience-retrieve.sh`'s
  `source=[repo:<slug>]` filter. No agent performs any of this — `sapience review` is a
  user-driven launcher surface and every post through it is permanent.
- A `verify-deploy.sh --only-gate 8` scoped-sweep attempt in Phase 4 reported `[FAIL]` under
  heavy multi-task batch contention (load average 5.88-9.34); the identical 34-suite roster,
  re-run directly via `run-all.sh --only` with no wrapper, passed 34/0. This is recorded as a
  contention/timeout artifact in the issue log, not a defect in this task's own work, but is
  worth the orchestration's attention if it recurs on a less-contended run.
- The pre-existing, already-noted drift between the shared `resolve_checkout_toplevel()` block's
  in-block comment (still names five files) and the lockstep guard's actual array (now nine) was
  left untouched, as the plan's own Risks table directs — the comment must be copied verbatim,
  never "corrected" in isolation.

## References

- Plan: `specs/676_tag_transcript_captured_kos_with_repo_tag/plans/01_tag-pending-kos-repo-tag.md`
- Research: `specs/676_tag_transcript_captured_kos_with_repo_tag/reports/01_tag-transcript-captured-kos-repo.md`
- Progress files: `specs/676_tag_transcript_captured_kos_with_repo_tag/progress/phase-{1,2,3,4}-progress.json`
- Handoffs: `specs/676_tag_transcript_captured_kos_with_repo_tag/handoffs/phase-{1,2,3,4}-handoff-*.md`
