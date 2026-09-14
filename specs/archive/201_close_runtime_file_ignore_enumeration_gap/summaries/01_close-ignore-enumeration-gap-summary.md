# Implementation Summary: Task #201

- **Task**: 201 - Close runtime-file ignore enumeration gap
- **Status**: [COMPLETED]
- **Started**: 2026-09-09T20:24:00Z
- **Completed**: 2026-09-09T21:10:00Z
- **Effort**: ~1 hour
- **Dependencies**: None declared. Non-blocking file-footprint overlap with a separate,
  not-started task that relocates the same runtime files — this task landed first.
- **Artifacts**: plans/01_close-ignore-enumeration-gap.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  shell-strict-mode.md, orchestrator-runtime-files.md, source-store-deploy-boundary.md

## Overview

Four members of the "ephemeral orchestrator runtime state" class (`specs/.deploy-lock/`,
`specs/.scope-lock/`, `specs/.commit-lock/`, `specs/.errors.lock`) — plus a fifth,
`specs/.dispatch/`, found already drifting between the script's own two internal lists — were
missing or inconsistent across the three enumerations meant to cover the whole class: the
standards doc's "Consumer Repo Setup" gitignore block, `check-runtime-file-tracking.sh`'s two
internal lists, and (for two of the four) the consumer repo's own root `.gitignore`. Implemented
the plan's single-source design: one canonical class definition
(`scripts/lib/runtime-file-patterns.sh`, 16 members) that every mechanical consumer now derives
from, plus a doc-sync regression test that pins the markdown block (which cannot `source` a bash
lib) to that same source.

## What Changed

- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` — new file. Canonical
  16-member class definition (gitignore pattern, Check A probe, Check B regex, directory-class
  flag + basename per member) plus `runtime_ignore_block()` and
  `runtime_file_dir_basename_for_hit()`.
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` — rewired: both
  `EPHEMERAL_PROBES` and `b_patterns` now derive from the lib; the Check B remediation branch is
  generalized from a `.lock/`-only hardcoded check to a lib-driven lookup so every directory-class
  member prints `git rm -r --cached`, not just `.lock/`; removed the pre-existing unused `YELLOW`
  (resolved a pre-existing `SC2034`); added a cross-reference comment naming the lib as sole
  source.
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` — added 4 Class
  Table rows (`.deploy-lock/`, `.scope-lock/`, `.commit-lock/`, `.errors.lock`); replaced the
  "Consumer Repo Setup" fenced block with the lib's `runtime_ignore_block()` output verbatim
  (adds the 4 gaps plus `.dispatch/`); added a one-line exclusion note for
  `.eager-context-snapshot-*.json`; added a "Single source of truth" subsection recording the
  scope-(d) decision and its reasoning.
- `agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh`,
  `test-deploy-propagation.sh` — replaced the hand-maintained `GITIGNORE_EOF` heredoc in each
  with a call that sources the lib and writes `runtime_ignore_block()` to the scratch repo's
  `.gitignore`; updated the surrounding comment to state the block is generated, not
  hand-mirrored.
- `agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` — new regression
  suite, 5 cases: Case 1/2 reproduce the live incident end-to-end (force-track
  `specs/.deploy-lock/owner` -> FAIL with `git rm -r --cached` -> untrack -> PASS, file stays on
  disk); Case 3 is the doc-sync pin (standards block byte-identical to `runtime_ignore_block()`);
  Case 4 protects the MUST NOT (Check C fails on over-ignored `.orchestrator-handoff.json`); Case
  5 checks the lib's 6 parallel arrays stay 1:1 by construction.
- `agent-system/extensions/core/manifest.json` — registered `lib/runtime-file-patterns.sh` and
  `tests/test-runtime-file-tracking.sh`.
- `agent-system/extensions/core/index-entries.json` — resynced `line_count` for
  `standards/orchestrator-runtime-files.md` (356 -> 405).
- `/home/benjamin/.config/nvim/.gitignore` — added `**/.deploy-lock/` and `**/.scope-lock/` (the
  other two gaps, `**/.commit-lock/` and `**/.errors.lock`, were already present out of band).
- Regenerated `.claude/` deploy tree (gitignored, not tracked) via `deploy-headless.sh`.

## Decisions

- Single-source lib over patching five sites by hand: the drift was already live inside one
  script's own two internal lists (Check A probed `.dispatch/`, Check B did not), so
  hand-patching would have reproduced the exact defect class this task exists to close.
- The markdown block cannot `source` a bash file, so it is pinned to the lib by a doc-sync
  assertion in the new regression test (Case 3) rather than mechanically derived.
- Dropped one redundant Check A probe variant for the `return-meta-suffixed` class member
  (the old script probed both `specs/.return-meta-multi-sess_..._probe.json` and
  `${PROBE_DIR}/.return-meta-orchestrate.json` for the same gitignore pattern) in favor of exactly
  one probe per lib member, to keep the lib's arrays strictly 1:1 (verified by Case 5). Coverage
  is unaffected — the retained probe still exercises the same `**/.return-meta-*.json` pattern.
- Left `tests/test-git-commit-scoped.sh`'s own unrelated 4-line `.gitignore` heredoc untouched:
  it tests `git-commit-scoped.sh`'s own staging-narrowing logic, does not claim to mirror the
  standards block, and does not run a real deploy through gate 14 — out of this task's scope.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (shell/markdown task)
- Tests: Passed — `check-runtime-file-tracking.sh` PASSes against this repo from both the source
  store and the deployed `.claude/` copy (gate 14 green in the real headless deploy);
  `test-runtime-file-tracking.sh` (9/9), `test-deploy-orphans.sh`, and `test-deploy-propagation.sh`
  all pass, including inside the full `scripts/tests/run-all.sh` run (74 passed, 9 failed, 0
  skipped, 83 total — the 9 failures are pre-existing, unrelated to this task; see Impacts below).
  Both required deliberate-break mutation checks were performed and confirmed (reverting the
  remediation branch to `.lock/`-only broke Case 1; removing one pattern from the standards block
  broke Case 3; both restored).
- Files verified: Yes — deployed and source-store copies of every changed script/doc are
  byte-identical (`diff`); `manifest.json` and `index-entries.json` parse; line-count drift check
  green.

## Impacts

- Every mechanical enumeration of the ephemeral-runtime-file class now agrees, and a future class
  member can only be added in one place (the lib) without silently going stale in the other
  consumers, because a doc-sync test and 1:1-construction test now cover the previously-silent
  drift paths.
- `specs/.deploy-lock/owner` (the historically live-tracked mutex from commit `96fb00a40`) was
  already untracked (commit `cf51ce8bb`, verified — not re-run) and is now fully covered by the
  root `.gitignore`, so no future `deploy-headless.sh` mutex directory can be re-tracked by an
  ordinary `git-commit-scoped.sh ... -- specs/` invocation.
- **Observation (unrelated, out of scope)**: the full `run-all.sh` run surfaced two pre-existing
  failing suites — `test-state-write-regen-timing.sh` and `test-task-lock-reap.sh` — both failing
  because their fixture's copied-script list is missing `lib/task-lookup-lib.sh`, a dependency
  `task-lock.sh` gained from unrelated prior work. Neither suite references any file this task
  touched. Also observed: `verify-deploy.sh`'s eager-context-budget check reports the eager-load
  total over its recorded baseline and `commands/orchestrate.md` over its configured ceiling —
  again unrelated to any file this task edited. Both are noted here for visibility, not fixed, per
  this task's scope.

## Follow-ups

- The two pre-existing test-suite failures and the eager-context-budget drift noted above are
  candidates for their own separate tasks.
- A separate, not-started task that relocates session-scoped runtime files into a dot-prefixed
  subdirectory declares the same two files (the standards doc and the check script) in its file
  scope. Whichever of the two tasks lands second should re-derive its own view of the
  enumerations from the lib introduced here, per that task's own footprint note.

## References

- specs/201_close_runtime_file_ignore_enumeration_gap/plans/01_close-ignore-enumeration-gap.md
- specs/201_close_runtime_file_ignore_enumeration_gap/reports/01_close_ignore_enumeration_gap.md
