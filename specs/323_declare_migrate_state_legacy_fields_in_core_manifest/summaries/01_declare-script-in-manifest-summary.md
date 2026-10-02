# Implementation Summary: Task #323

- **Task**: 323 - Declare migrate-state-legacy-fields.sh in core manifest
- **Status**: [COMPLETED]
- **Started**: 2026-10-02T21:43:19Z
- **Completed**: 2026-10-02T22:24:00Z
- **Effort**: 0.75 hours
- **Dependencies**: None
- **Artifacts**: plans/01_declare-script-in-manifest.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`agent-system/extensions/core/scripts/migrate-state-legacy-fields.sh` was live, executable, and
git-tracked but absent from `provides.scripts` in the core extension's manifest, causing a
`check-extension-docs.sh` FAIL and an adjacent README-drift WARN. This task declared the script
in the manifest, refreshed the stale script count in the core README, and confirmed both the
doc-lint and the full deploy-verification gate are green — discovering and resolving two
unanticipated side effects along the way.

## What Changed

- `agent-system/extensions/core/manifest.json` — added `"migrate-state-legacy-fields.sh"` to
  `provides.scripts`, immediately after `"migrate-directory-padding.sh"` (array length 199 -> 200).
- `agent-system/extensions/core/README.md` — refreshed the stale `Scripts | 27` Overview-table
  row and the matching `# 27 utility scripts` Architecture-tree comment to `200`, the actual
  `provides.scripts` length after the manifest edit. No sibling migration script (including
  `migrate-directory-padding.sh`) was added to the tree's representative sample list, consistent
  with every other script category there.

## Decisions

- Used the exact figure `200` rather than an approximate style (`200+`) for the Scripts row,
  matching the precision of neighboring exact-count rows (e.g. `Hooks | 11`) rather than the
  approximate rows (`15+ dirs`, `23+ files`), since `provides.scripts` is a flat array whose exact
  length is trivially recomputable and unlikely to silently drift again before the next edit.
- After Phases 1-2 landed cleanly but Phase 3's verification surfaced unexpected gate failures
  (see Plan Deviations), ran `bash .claude/scripts/deploy-headless.sh` in its default
  non-destructive resync mode to refresh the gitignored, untracked `.claude/` deploy tree. This
  is the standard, repeatable mechanism this entire verification workflow depends on (per
  `rules/source-store-deploy-boundary.md`, `.claude/` is "a disposable deploy artifact
  regenerated from a source store"); it created no git commits, touched no tracked files, and
  is safely idempotent — confirmed via the script's own doc comment ("Never destructive; never
  removes anything").

## Plan Deviations

- **Task 3.2** altered: Immediately after Phases 1-2, `[core]` additionally showed an unrelated
  `FAIL: deployed script content drift (deployed != extension source): scripts/tests/test-deploy-orphans.sh`.
  Investigated via `git log`/`git diff` and confirmed this was caused entirely by sibling task
  324's own committed source-store edit to that file (the scheduled_tasks.lock whitelist
  scenario), not yet reflected in the stale deployed copy — a normal consequence of committing
  to the source store without an intervening redeploy, not a regression from this task's work.
  Resolved by the `deploy-headless.sh` redeploy described above, after which `[core]` returned
  fully clean (`OK`, zero FAIL/WARN/ADVISORY lines — the script is now deployed too).
- **Task 3.3** altered: The plan's Phase 3 research anticipated that `check-extension-docs.sh`'s
  Rule O exemption (ADVISORY, non-blocking) was the only consumer of the
  declared-but-undeployed-script condition. `verify-deploy.sh` gate 5 (`verify.lua`'s
  manifest-driven category parity check) turned out to be a second, stricter consumer with no
  such exemption: it reported `FAIL: core: Missing scripts: scripts/migrate-state-legacy-fields.sh`
  unconditionally for any manifest-declared script absent from the deployed target. This was not
  anticipated by the plan's research (a gap worth noting for future doc-lint-adjacent work: gate 3
  and gate 5 have different undeployed-script tolerance). The same `deploy-headless.sh` redeploy
  that resolved Task 3.2 also resolved this, since deploying the script was the only fix available
  and is a side effect of the standard redeploy rather than a special one-off action. A first
  post-redeploy `verify-deploy.sh --skip-slow` run came back `FAIL 1/33`: a transient
  `orphan file: tmp/noop-bash-count-<session>` gate-13 finding, traced to a runtime counter file
  this agent itself created via a single errant filler `echo waiting` Bash call made while
  waiting on a backgrounded command (a lapse this agent's own dispatch instructions explicitly
  warn against). `detect-noop-bash.sh`'s own reset-on-non-trivial-command logic deleted the file
  on the very next (non-trivial) command, and a second `verify-deploy.sh --skip-slow` run came
  back clean: `PASS — 33 check(s), 0 failure(s)`.

## Verification

- Build: N/A
- Tests: N/A (no test suite for this change; `--skip-slow` excludes the shell test suite per
  plan scope)
- `jq empty agent-system/extensions/core/manifest.json` exits 0.
- `jq -e '.provides.scripts | index("migrate-state-legacy-fields.sh")'` returns index 66 (array
  length 200).
- `bash .claude/scripts/check-extension-docs.sh`: `[core]` returns `OK` with no FAIL, no WARN,
  no ADVISORY.
- `bash .claude/scripts/verify-deploy.sh --skip-slow`: final run is `PASS — 33 check(s), 0
  failure(s)` (improved from the task's named baseline of FAIL 2/33).
- `git diff` across the task touches exactly two git-tracked files, both under
  `agent-system/extensions/core/` (`manifest.json`, `README.md`); nothing under `.claude/` is
  git-tracked, so the redeploy produced no git diff.
- Files verified: Yes.

## Impacts

- `[core]`'s doc-lint is fully clean, removing the gate-3 half of the `verify-deploy.sh
  --skip-slow` regression this task was filed to resolve.
- `verify-deploy.sh --skip-slow` is fully green (33/33), not merely the 1/33-or-better bar the
  plan set (which expected the sibling task 324's gate-13 orphan issue to remain as the sole
  residual failure) — both this task's and sibling task 324's fixes landed and were verified
  together in the same deploy/verify cycle.
- Task 250's description, which named this defect as explicitly out of its own scope pending a
  "re-check," can now treat it as resolved and no longer noise.
- Documents a previously-unknown gap in doc-lint tooling parity: `check-extension-docs.sh`'s
  Rule O (ADVISORY, non-blocking) and `verify-deploy.sh` gate 5's manifest-driven parity check
  (FAIL, no exemption) disagree on whether a declared-but-undeployed script is acceptable. Any
  future "declare but don't deploy" task should account for gate 5, not just the doc-lint
  ADVISORY.

## Follow-ups

- None required for this task's own scope. Worth noting for a future meta task: gate 5's lack of
  an undeployed-script exemption (unlike check-extension-docs.sh's Rule O) could surprise a future
  "declare in manifest, defer deployment" change; no action requested here since deployment itself
  resolved it cleanly in this case.

## References

- Plan: `specs/323_declare_migrate_state_legacy_fields_in_core_manifest/plans/01_declare-script-in-manifest.md`
- Research: `specs/323_declare_migrate_state_legacy_fields_in_core_manifest/reports/01_declare-script-in-manifest.md`
- Review that filed this task: `specs/reviews/review-2026-10-02.md`
