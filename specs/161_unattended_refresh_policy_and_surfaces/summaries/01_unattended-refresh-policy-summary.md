# Implementation Summary: Task #161

- **Task**: 161 - Settle the unattended-refresh policy and update the systemd, skill, and command surfaces
- **Status**: [COMPLETED]
- **Started**: 2026-09-07T00:00:00Z
- **Completed**: 2026-09-07T21:13:04Z
- **Effort**: ~2.5 hours
- **Dependencies**: Task 160 (completed)
- **Artifacts**: plans/01_unattended-refresh-policy.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Settled the unattended-refresh policy by recording, directly in `claude-refresh.service`'s own
comment block, the confirmed code-level ruling that no pass added since the unit was authored
requires a unit change, and made an explicit, implemented ruling on the unit's dependency on the
gitignored deploy tree (`ConditionPathExists`, chosen over the two bare alternatives because it
is the only option that changes the failure mode). Rebuilt `skill-refresh/SKILL.md` and
`commands/refresh.md` from a from-source-derived, ten-item canonical pass inventory (not the task
description's seven, and not the research report's own nine), giving both surfaces a single
scannable table plus the previously-missing destructiveness/mirror subsections, and confirmed
every acceptance gate green.

## What Changed

- `agent-system/extensions/core/systemd/claude-refresh.service` — extended the `# Policy:`
  comment block with the confirmed new-passes ruling (all four `main()` passes run
  unconditionally threading the single `ExecStart`'s `--dry-run`; only the Lean pass can
  terminate, and only under `--force`, which this unit never passes) and a scope note that the
  file/spec cleanup passes are `/refresh`-only; added `ConditionPathExists=%h/.config/nvim/.claude/scripts/claude-refresh.sh`
  to `[Unit]` with a comment recording the deploy-path ruling.
- `agent-system/extensions/core/systemd/claude-refresh.timer` — confirmed unchanged; no concrete
  reason surfaced to edit it.
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` — rewrote the opening framing from
  "two operations" to the accurate three-area, ten-pass structure; inserted a canonical Pass
  Inventory table (# / pass / owning Step-section / gate / destructive / hourly-cadence-reached)
  before `## Execution`; added an explicit destructiveness statement to Step 3 (age-threshold-only
  deletion, no confirmation, `/refresh`-only).
- `agent-system/extensions/core/commands/refresh.md` — inserted the matching inventory table near
  the top of `## What It Cleans`; added the three subsections the inventory showed were missing:
  `### Orphaned Postflight Markers`, `### Stale Session Registry Entries`, and
  `### Stale Backup Files`; updated the `## Options` `--dry-run`/`--force` descriptions, which
  previously undercounted scope to only "process" and "directory" cleanup.
- `agent-system/extensions/core/scripts/claude-refresh.sh` — added one text-only line to
  `print_help()` naming the four passes the script runs each invocation; no control-flow, flag, or
  pass-behavior change.

## Decisions

- **Real pass count is ten, not seven or nine.** Phase 1 enumerated from source (SKILL.md `###
  Step` headings, `claude-refresh.sh` `main()`'s pass functions, `refresh.md` subsections) rather
  than trusting the task description's seven or the research report's own nine-row table. The two
  passes both undercounts missed: the `~/.claude/` directory-cleanup operation (Steps 6-7 /
  `claude-cleanup.sh`) and `Step 5: Clean Stale Backup Files`.
- **`ConditionPathExists` over the two bare alternatives.** Implemented rather than merely
  documented, because it is the only option that changes the unit's actual failure mode (hourly
  failed-unit noise becomes a clean informational skip) on a machine where the gitignored deploy
  tree is absent.
- **Deploy-drift resolved via the sanctioned `deploy-headless.sh` resync, not a hand-edit.** Editing
  the source-store `claude-refresh.sh` made the deployed `.claude/scripts/claude-refresh.sh` stale,
  which `check-extension-docs.sh` flagged as a transient `core` FAIL (deployed-script-content
  drift). Ran `bash .claude/scripts/deploy-headless.sh` (default, non-destructive mode) to
  regenerate `.claude/` from the source store — explicitly exempted under
  `source-store-deploy-boundary.md` ("the deploy/reload process ... is not a violation") — which
  restored `core PASS` and left the deployed script byte-identical to source.

## Plan Deviations

- **Task 4.6** (Phase 4) added: an `### Stale Backup Files` subsection in `refresh.md`, beyond the
  two subsections the plan's task list named explicitly. The plan's own Scope Hypothesis for Phase
  4 flagged this as a live candidate omission contingent on Phase 1's findings; Phase 1 confirmed
  `refresh.md` had zero mention of `.backup`-file cleanup, so the subsection was added to keep
  every Phase-1-confirmed pass mirrored in both surfaces.

## Verification

- Build: N/A (no build system for this file set)
- Tests: N/A (no automated test suite for systemd units / markdown docs)
- Files verified: Yes
- `systemd-analyze verify` on both `claude-refresh.service` and `claude-refresh.timer`: PASS (exit
  0; sole output the unrelated `cups.socket` legacy-path warning)
- `bash .claude/scripts/check-extension-docs.sh`: `core PASS`; overall reports 1 issue, solely the
  pre-existing, out-of-scope `lean` FAIL (an `index-entries.json` line-count mismatch unrelated to
  this task's file scope)
- `bash agent-system/extensions/core/scripts/claude-refresh.sh --help`: pass list matches the
  documented inventory; confirmed byte-identical between source-store and deployed copies after
  the redeploy
- `ConditionPathExists=` path matches `ExecStart=`'s path character-for-character
- `SKILL.md` and `refresh.md` inventory tables agree row-for-row on gate/destructive/cadence (10/10
  rows; the only textual difference is each file's own correct section-name pointer)
- `git status --porcelain` shows no unexpected `.claude/` hand-edit (the only `.claude/` change was
  the sanctioned `deploy-headless.sh` resync)
- No task-number reference introduced outside `specs/**` (grepped every edited file)

## Impacts

- A future reader of `claude-refresh.service` can now confirm from the comment block alone, without
  re-deriving it, that a new pass wired into `main()`'s unconditional sequence needs no unit change.
- A machine where the gitignored `.claude/` deploy tree is absent now gets a clean, log-quiet
  informational skip on the hourly timer instead of an hourly `systemctl --failed` unit.
- `skill-refresh/SKILL.md` and `commands/refresh.md` now each carry one scannable, cross-agreeing
  ten-row inventory rather than requiring a reader to assemble the same information from six
  separate Step/section blocks per file.

## Follow-ups

- None required by this task's own acceptance criteria. If a future pass is added to
  `claude-refresh.sh`'s `main()` with its own independent gating (its own flag or `ExecStart`
  line) rather than folded into the existing unconditional sequence, the service comment's
  new-passes ruling should be re-derived rather than assumed to still hold (noted explicitly in
  the comment itself).

## References

- `specs/161_unattended_refresh_policy_and_surfaces/plans/01_unattended-refresh-policy.md`
- `specs/161_unattended_refresh_policy_and_surfaces/reports/01_unattended-refresh-policy.md`
- `specs/161_unattended_refresh_policy_and_surfaces/progress/phase-1-progress.json` (canonical
  pass inventory and divergence note)
- `specs/161_unattended_refresh_policy_and_surfaces/progress/phase-2-progress.json`
- `specs/161_unattended_refresh_policy_and_surfaces/progress/phase-3-progress.json`
- `specs/161_unattended_refresh_policy_and_surfaces/progress/phase-4-progress.json`
- `specs/161_unattended_refresh_policy_and_surfaces/progress/phase-5-progress.json`
