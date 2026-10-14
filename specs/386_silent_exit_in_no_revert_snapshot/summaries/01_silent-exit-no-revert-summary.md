# Implementation Summary: Task #386

- **Task**: 386 - Silent exit in --no-revert git-snapshot.sh
- **Status**: [COMPLETED]
- **Started**: 2026-10-14T19:35:00Z
- **Completed**: 2026-10-14T21:45:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None (adjacency-only coordination note with the guard-destructive-git.sh /
  foreign-stash-pop task; no file-territory overlap)
- **Artifacts**: plans/01_silent-exit-no-revert.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`git-snapshot.sh` ran under `set -euo pipefail` with four unguarded command substitutions
(three in `--no-revert` mode, one duplicated in default mode) whose failure aborted the script
silently with the underlying git error already discarded by a `2>/dev/null` redirect. This
reproduced the originally reported "mode line, then nothing, then exit 1" signature exactly. All
four sites now report a named reason on stderr (with the underlying git stderr preserved
verbatim) before exiting or degrading; both SIGPIPE-prone `git stash list | head -1 | cut -d: -f1`
pipelines were structurally replaced with a non-piped pure-bash parse; `--branch` mode's
`ORIGINAL_BRANCH` read gained the same named-reason treatment; and the script's own header now
documents the per-mode fatal-vs-degrade failure posture. New RED-first fixture coverage (held
`.git/index.lock`, its negative control, and a 2000-entry SIGPIPE reproduction) was added to the
existing regression suite, which is fully green (7 passed, 0 failed).

## What Changed

- `agent-system/extensions/core/scripts/git-snapshot.sh` — guarded all four previously-unguarded
  command substitutions; the `--no-revert` stash-create/stash-ref pair now degrades to a named
  `WARNING` and continues (exit 0, `STASH_REF=NONE`) since the `.patch` file is already a
  complete durable record by that point; the untracked-file enumeration and `--branch` mode's
  `ORIGINAL_BRANCH` read stay fatal with a named reason (no independent backstop for either);
  both `git stash list | head -1 | cut -d: -f1` pipelines (the `--no-revert` branch and default
  mode's duplicate) are replaced by a new shared `resolve_latest_stash_ref()` function (pure
  command substitution + parameter expansion, structurally immune to SIGPIPE); the header's
  closing paragraph now documents the full per-mode fatal-vs-degrade failure posture and exit
  statuses.
- `agent-system/extensions/core/scripts/tests/test-git-snapshot.sh` — added three new fixture
  cases: a held-`.git/index.lock` `--no-revert` case (asserts the degrade-not-abort contract: exit
  0, named warning, patch+marker written, `STASH_REF=NONE`), its unlocked negative control
  (asserts the ordinary success path is unaffected), and a 2000-entry SIGPIPE reproduction
  (asserts a correctly parsed `stash@{N}`, never silence). A `shellcheck` SC2164 finding in the
  new SIGPIPE fixture's subshell (`cd` without `|| exit`) was found and fixed during Phase 5's
  gate run.
- Regenerated `.claude/` deploy artifacts via `deploy-headless.sh` (never hand-authored); the
  deployed copies of both files are confirmed byte-identical to the source-store copies.

## Decisions

- The held-`index.lock` fixture asserts exit 0, not a non-zero status: the research report's
  Decisions section (degrade-and-continue) and its Recommendation 4 (assert non-zero exit)
  contradicted each other. The plan followed the Decisions ruling — degrade is the substantive
  design choice, reasoned from the `.patch` file already being in hand — and reads acceptance
  (a)'s "documented exit status" as satisfied by the script header documenting that status, not
  as a requirement that it be non-zero. Recorded in `issues.jsonl` at plan time.
- Default mode's duplicate `git stash list | head -1 | cut -d: -f1` pipeline was brought in
  scope even though the dispatch's stated goal named `--no-revert` mode only, because the
  dispatch itself asked research to sweep other modes, and the default-mode instance is both the
  same unguarded shape and strictly more damaging (it can abort after the tree is already
  reverted, leaving the caller with no patch and no explanation).
- The non-piped `STASH_REF` parse was factored into one shared `resolve_latest_stash_ref()`
  function reused at both call sites, rather than duplicating the four-line block, matching the
  script's one existing precedent for a named helper function (`resolve_task_dir`).

## Plan Deviations

- A `shellcheck` SC2164 finding (`cd "$sigpipe_repo"` without `|| exit`) in this task's own
  Phase 1 fixture code was found during Phase 5's full gate run (not caught in Phase 1, since
  that phase's own verification checked the file before this exact form existed, and later
  phases' `shellcheck` checks targeted `git-snapshot.sh` only). Fixed, reverified (standalone
  `shellcheck -S warning`, a second full 375-file repo-wide sweep, and a suite re-run), and
  redeployed.
- A stray, gitignored runtime file (`.claude/tmp/stash-pre-<session-id>`) created by sibling task
  382's `guard-destructive-git.sh` hook infrastructure (triggered by this task's own `git
  stash`-containing Bash calls during SIGPIPE-fixture testing) was found during gate verification
  and deleted — outside either task's declared `file_scope`, not a tracked deliverable.
- Phase 5 closed `[COMPLETED WITH EXCLUSIONS]` rather than fully green: three pre-existing,
  cross-batch obstructions (detailed below) made the literal full-gate-set / full-suite-run
  verification criteria unreachable. All three are named in the dispatch's own known-obstruction
  list; none touches this task's declared file_scope.

## Verification

- Build: N/A (shell scripts; `bash -n` and `shellcheck -S warning` clean on both files)
- Tests: `agent-system/extensions/core/scripts/tests/test-git-snapshot.sh` — 7 passed, 0 failed
  (includes all 3 new cases plus the 4 pre-existing cases, unregressed)
- `run-all.sh --only test-git-snapshot.sh` — 1 passed, 0 failed
- `run-all.sh --only test-guard-destructive-git.sh` (sibling task 382's suite, which drives
  `git-snapshot.sh` as a real subprocess) — 1 passed, 0 failed, confirming the coupling holds
- `shellcheck` repo-wide (375 files) — 0 findings
- Deployed vs. source-store `diff` — byte-identical for both modified files
- Files verified: Yes

### Full Gate Set — Reasoned Exclusions

Three pre-existing, cross-batch obstructions made the literal full `verify-deploy.sh` /
unfiltered `run-all.sh` criteria unreachable; all three are named in the dispatch's own
known-obstruction list and none touches this task's declared file_scope. Full
reason/evidence detail lives in the plan's Phase 5 section (`#### Reasoned Exclusions` table);
summarized:

| Item | Reason |
|------|--------|
| Full `tests/run-all.sh` / gate 8 | `test-zotero-generate-export.sh` (literature extension) hangs indefinitely; tracked by a separate task. Narrow substitution (`--only test-git-snapshot.sh`, `--only test-guard-destructive-git.sh`) both PASS. |
| `verify-deploy.sh` doc-lint gate | FAILs entirely within the `lean` extension (a known, already-excluded fixture registration gap); `[core]`'s own section reports `OK`. |
| `verify-deploy.sh` orchestrator context-budget gate | Aggregate eager-load total exceeds baseline by cumulative growth from this batch's other sibling tasks; neither modified file is an eager-loaded context file, and both named per-file ceilings PASS. |

### Acceptance Criteria — Walked with Evidence

- **(a)** Held-`.git/index.lock` fixture: exit 0, named `WARNING` on stderr (with captured git
  stderr), patch and marker both written, `STASH_REF=NONE` — documented exit status per the
  script's own header.
- **(b)** Sweep query finds exactly one remaining bare substitution
  (`HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo "unknown")`), which already has its own
  `||` fallback and cannot abort. All four originally-unguarded sites are now guarded; both
  SIGPIPE-prone pipelines are structurally replaced.
- **(c)** Byte-for-byte diff of success-path stdout (pre-change vs. final script, identical
  fixture, timestamp-normalized) is empty.
- **(d)** Out-of-scope guard's gating condition is read-confirmed unchanged; the suite's
  pre-existing `--no-revert: never guarded` case still passes.

## Impacts

- `git-snapshot.sh --no-revert` (and default mode) callers — including
  `checkpoint-before-overflow.md`'s CHECKPOINT-BEFORE-OVERFLOW procedure and agent handoff
  steps that rely on this script — now always see a named reason on stderr instead of a bare
  non-zero exit, and a transient lock-contention stash-create failure no longer discards an
  otherwise fully achievable patch-only snapshot.
- Sibling task 382 (foreign-stash-pop guard) drives this script as a real subprocess in its own
  acceptance fixtures; its suite was re-run against the final script and still passes,
  confirming the observable contract (stdout byte-identical, out-of-scope guard behavior
  unchanged) held stable through this change.

## Follow-ups

- `context/standards/shell-strict-mode.md`'s Class A migration audit asserts "none found
  unguarded" for `git-snapshot.sh`'s `set -euo pipefail` population; this was contradicted by
  the four sites this task fixed. A follow-up correction to that document's audit claim is
  recommended (recorded in `issues.jsonl` at research time).
- The sibling `grep | head | cut` shape identified during research
  (`lib/plan-status-line.sh:40`, `lib/suite-selection-lib.sh:267,269`) was explicitly out of
  scope for this task (both are sourced libraries whose abort behavior depends on the caller's
  shell-option state, needing its own targeted audit) and remains unaddressed.

## References

- Plan: `specs/386_silent_exit_in_no_revert_snapshot/plans/01_silent-exit-no-revert.md`
- Research: `specs/386_silent_exit_in_no_revert_snapshot/reports/01_silent-exit-no-revert.md`
- Progress files: `specs/386_silent_exit_in_no_revert_snapshot/progress/phase-{1..5}-progress.json`
- Handoffs: `specs/386_silent_exit_in_no_revert_snapshot/handoffs/`
