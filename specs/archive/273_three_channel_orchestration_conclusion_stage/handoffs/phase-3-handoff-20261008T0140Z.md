# Phase 3 Handoff — Task 273

## Immediate Next Action

Begin Phase 4: `scripts/tests/test-orchestrate-conclusion-aggregate.sh` and manifest
registration. Phase 4 must register `orchestrate-conclusion-aggregate.sh` and the new test suite
in `agent-system/extensions/core/manifest.json`'s `provides.scripts` (file-granular, 229+
entries), then deploy and confirm both deployed paths exist. Phase 4's "register context file if
Phase 1 found that array file-granular" sub-step is now moot — `provides.context` is
directory-granular (confirmed Phase 1) — but the SEPARATE `index-entries.json` registration this
phase already performed for Rule S is unrelated to that sub-step and does not need repeating.

## Current State

Phase 3 completed. `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh`
exists, is `shellcheck -S warning` clean, refuses to run from the source store under every flag
(including `--help`), and its three modes (`--aggregate`, `--record-approval`,
`--check-approval`) were manually smoke-tested via a temporary copy into `.claude/scripts/`
(removed afterward — official deploy is Phase 4's job since the script is not yet registered in
`manifest.json`).

## Key Decisions Made

- `--help` must refuse from the source store too, matching `roadmap-integration.sh`'s verified
  convention — fixed an initial draft that let `--help` bypass the guard.
- Confirmed the 15-class seed enum in the new script's `SEED_CLASSES_JSON` matches
  `issue-log.md`/`issue-record.sh` exactly (no discrepancy to record).

## Deviations from Plan

- See `progress/phase-3-progress.json` deviations array: the `--help`/guard-ordering fix, and the
  `index-entries.json` registration (a gap in the original plan's file list, not an explicit
  Phase 3 task item).

## What NOT to Try

- Do not leave a manually-copied, unregistered script in `.claude/scripts/` — `verify-deploy.sh`'s
  gate 13 (whole-tree orphan detection) flags deployed-but-undeclared files. Any smoke-test copy
  made before Phase 4's official registration must be removed afterward (done here).
- Do not assume `verify-deploy.sh`'s full gate set is clean right now — gate 13 already flags 2
  pre-existing `tmp/noop-bash-shapes-*` orphan files unrelated to this task (harness scratch
  artifacts, not in this task's `file_scope`). Phase 9 re-measures the full gate set; if those
  persist, record them via `issue-record.sh` rather than fixing them out of scope.

## Critical Context

- `check-extension-docs.sh`'s Rule S (every deployed `context/contracts/*.md` needs an
  `index-entries.json` row) is a SEPARATE requirement from `manifest.json`'s
  `provides.context` directory-granularity. Phase 1 checked only the latter; this gap is now
  closed for `conclusion-stage.md`, but a future new contract file in this task (there are none
  planned) would need the same check.
- The repository is under heavy concurrent load this cycle (multiple sibling tasks' agents
  running `deploy-headless.sh`/`verify-deploy.sh` simultaneously) — background long-running
  verification commands and poll with a captured PID (`kill -0` loop, bounded timeout) rather
  than foreground-blocking on the default 120s Bash timeout.

## References

- Plan: `specs/273_three_channel_orchestration_conclusion_stage/plans/01_three-channel-conclusion-stage.md`
- New file: `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh`
- Modified: `agent-system/extensions/core/index-entries.json`, `specs/state.json`
- Current phase: 3 (complete) -> next: Phase 4
