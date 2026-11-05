# Implementation Summary: Task #282

- **Task**: 282 - Write-time PreToolUse hook blocking record-versioning language, registered bare so exit 2 survives
- **Status**: [COMPLETED]
- **Started**: 2026-11-04T00:40:00Z
- **Completed**: 2026-11-04T02:10:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None outstanding
- **Artifacts**: plans/01_write-time-record-version-hook.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Built the write-time enforcement consumer for the record-versioning rule
(`rules/no-record-versioning-in-deliverables.md`): a `PreToolUse` hook
(`hooks/validate-no-record-versioning.sh`) that blocks a `Write`/`Edit` introducing
BLOCKING-tier record-version language into a non-`specs/**` deliverable, driven entirely by the
shared pattern library (`scripts/lib/record-version-patterns.sh`). Added its fixture test,
restored the lint/hook scope-agreement case in the sibling repo-wide-lint test suite, registered
the hook bare on both settings surfaces plus `manifest.json`, truth-ed up the taxonomy's
Enforcement section, and redeployed with live confirmation.

## What Changed

- `agent-system/extensions/core/hooks/validate-no-record-versioning.sh` — Created. A
  `PreToolUse` `Write|Edit` hook that blocks via exit code 2 plus an actionable stderr message
  (never `permissionDecision: deny`), fails OPEN (exit 0 with a warning) on a missing,
  unsourceable, or stale shared library, resolves the library `BASH_SOURCE`-relative, is
  advisory-silent (calls `rv_grep_blocking` only, never `rv_grep_advisory`), and scans an
  `Edit`'s `new_string` payload-only (no on-disk reconstruction, unlike the task-reference
  sibling hook).
- `agent-system/extensions/core/scripts/tests/test-validate-no-record-versioning.sh` — Created.
  15 fixture-driven cases driving the hook as a real subprocess: blocking (heading, supersession,
  Edit-shaped payload), allowed (specs/** both forms, advisory-only silent, inline/block marker,
  durable-axis-only, non-markdown path heading exclusion), degraded-library (missing, stale), and
  degenerate-input cases.
- `agent-system/extensions/core/scripts/tests/test-check-record-versioning.sh` — Restored the
  lint/hook scope-agreement case (Case 15), scoped to BLOCKING-tier fixtures and the specs/**
  exemption; removed the header note describing the case as omitted.
- `agent-system/extensions/core/manifest.json` — Added the hook to `provides.hooks` and the test
  to `provides.scripts`, beside the existing task-reference sibling entries.
- `agent-system/extensions/core/root-files/settings.json` and
  `agent-system/extensions/core/merge-sources/settings-hooks.json` — Bare registration (no
  `2>/dev/null || echo '{}'` wrapper) added to the existing `PreToolUse` `Write|Edit` matcher on
  both surfaces.
- `agent-system/extensions/core/context/standards/record-version-exemptions.md` — Rewrote the
  Enforcement section to state both consumers as current fact: paths, the lint's
  standalone-utility (not `verify-deploy.sh`-gated) posture, the advisory-silent write-time
  reason, and the payload-only Edit scope with its named blind spot.
- `agent-system/extensions/core/scripts/lib/record-version-patterns.sh` — Header comment only:
  corrected "planned" consumer language to describe both consumers as existing.
- `agent-system/extensions/core/index-entries.json` — Fixed the `line_count` mismatch for
  `record-version-exemptions.md` introduced by the Enforcement-section rewrite, via
  `generate-context-line-counts.sh --write`.
- Redeployed `.claude/` tree: the hook, test, registrations, and doc changes are live.

## Decisions

- Advisory-silent at write time: the hook never calls `rv_grep_advisory`, matching the dispatch's
  default recommendation and the measured live-corpus ADVISORY volume (hundreds of findings
  outside `specs/**`).
- Payload-only Edit scope: no on-disk reconstruction, since `strip_exempt_regions` has no nesting
  concept and no acceptance case exercises it; the accepted blind spot (a file-wide marker pair
  outside the edited span) is named in both the hook header and the Enforcement section.
- Omitted the `system-defect-record.sh` call the task-reference sibling hook makes on a block:
  the closed Signal A vocabulary (`context/patterns/system-defect-discrimination.md`) has no
  instance for "record-versioning language in a deliverable," and that document states
  extending the enum is "a future task's decision, not silently done by a detection site."

## Plan Deviations

- **Phase 1**: the task "calling `system-defect-record.sh` non-fatally as the sibling does" was
  altered — the call is omitted (see Decisions above and the hook's own DEVIATION comment).
- **Phase 5**: "Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`" was altered
  per this dispatch's Batch Gate Deferral directive — discharged instead via
  `verify-deploy.sh --skip-slow --only-gate 2,5,13,21,22` (PASS, 0 failures) plus
  `run-all.sh --only` across the six task-relevant suites (6 passed, 0 failed). The full gate set
  is deferred to the once-per-batch run at the end of this `/orchestrate` invocation.

## Verification

- Build: N/A
- Tests: Passed — `run-all.sh --only test-validate-no-record-versioning.sh,test-check-record-versioning.sh,test-lint-hook-registration-paths.sh,test-manifest-scripts-sync.sh,test-deploy-propagation.sh,test-record-version-patterns.sh` reports 6 passed, 0 failed.
- Files verified: Yes
- `shellcheck -S warning` clean on the hook and both touched test suites.
- `lint-hook-registration-paths.sh --verbose` reports 0 violations.
- Deployed `.claude/settings.json` registration confirmed bare (no `|| echo`, no `2>/dev/null`).
- Four live probes against the real deployed hook all behaved as specified (durable-axis
  allowed, unmarked blocking content blocked with a rule-naming message, specs/** exempt,
  self-edits to the hook/test files not blocked).
- Record-versioning lint BLOCKING count after redeploy: 3, matching the documented pre-change
  baseline exactly (all three pre-existing `lua/neotex/plugins/tools/himalaya/docs/` findings,
  untouched by this task).

## Impacts

- Every future `Write`/`Edit` to a non-`specs/**` deliverable in this repository is now screened
  for record-versioning language at write time, with the same discriminator the repo-wide lint
  uses.
- A self-hygiene gotcha was caught and fixed mid-task: `check-record-versioning.sh`'s
  `PATH_SCOPE` mode enumerates via `git ls-files`, so a self-check scoped to a not-yet-tracked
  new file silently reports false-clean rather than `[SKIP]` or an error — recorded as an issue
  for future similar work (see Follow-ups).

## Follow-ups

- A real observed instance of the hook's payload-only Edit-path blind spot (an edit landing
  inside a file-wide marker pair whose markers sit outside the edited span) would be separate,
  future scope, per the plan's own Risks table.
- `check-record-versioning.sh`'s `PATH_SCOPE` mode's git-ls-files-based enumeration silently
  false-cleans an untracked new file rather than reporting `[SKIP]` — worth a documentation note
  or a future fix in that script, not addressed here (out of this task's declared scope).

## References

- Plan: specs/282_record_versioning_write_time_hook/plans/01_write-time-record-version-hook.md
- Research: specs/282_record_versioning_write_time_hook/reports/01_write-time-hook-research.md
- Progress files: specs/282_record_versioning_write_time_hook/progress/phase-{1..5}-progress.json
- Handoffs: specs/282_record_versioning_write_time_hook/handoffs/phase-{1..5}-handoff-*.md
- Issue log: specs/282_record_versioning_write_time_hook/issues.jsonl
