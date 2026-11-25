# Implementation Summary: Task #683

- **Task**: 683 - Couple Sapience capture enablement to sapience-extension activation
- **Status**: [COMPLETED]
- **Started**: 2026-11-22T09:08:03Z
- **Completed**: 2026-11-22T11:55:00Z
- **Effort**: ~3 hours
- **Dependencies**: None
- **Artifacts**: plans/01_capture-activation-coupling.md, reports/01_capture-activation-coupling.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Coupled `~/.sapience/config.json`'s `capture.projects[].enabled` for a repository to that
repository's sapience-extension activation state, using the same bidirectional `SessionStart`
hook that already registers/removes its per-project MCP entry. The write goes exclusively
through the vendor's own `sapience projects on|off <path>` CLI (never a direct edit of
`config.json`), keeping the vendor client the sole writer of that file's `capture` key. Six
phases landed: a writer-side `--capture-set` action and helpers, a `--reap-capture` sweep for
vanished project directories, hook wiring keyed on the parent checkout, a verifier check (i)
update (informational line -> non-failing WARN), documentation rewriting the two-writers
reconciliation ruling and adding a new `folders` double-gate subsection, and a final redeploy
plus scoped verification pass.

## What Changed

- `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh` -- added `sapience_cli`,
  `capture_state_for_path`, the `--capture-set on|off` action, and the `--reap-capture` sweep
  (`process_reap_capture`), all invoking the vendor CLI with `SAPIENCE_NO_CAPTURE_SYNC=1` and a
  bounded `timeout 15`
- `agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh` -- wired
  `--capture-set`/`--reap-capture` into both existing branches and the ungated reap pass, keyed
  on `resolve_checkout_toplevel()`'s `GIT_ROOT` (never the per-repo half's own `PROJECT_PATH`,
  confirmed live to resolve to the worktree inside a linked worktree); extended header caveats
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` -- added a `warn()` helper;
  check (i)'s active+not-enabled-or-absent outcome is now a non-failing `[WARN] (i)` naming the
  lag/silent-degrade/`folders` causes; rewrote the RECONCILIATION RULING comment
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` -- added
  cases (56)-(72): writer capture-set (56-61), writer reap-capture (62-65), hook capture
  coupling (66-71), and the check (i) WARN-text case (72); amended cases (45)/(46); added
  `build_sapience_stub`, `install_sapience_stub_into`, `sapience_stub_call_count`,
  `sapience_stub_last_args`, `sapience_stub_last_no_capture_sync`, and
  `build_path_without_sapience` test helpers. 75 cases pass, 0 failed.
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` --
  rewrote "Capture/Activation Reconciliation" to state the new vendor-CLI-routed design and its
  three caveats; added "The `folders` Double-Gate" subsection, cross-referenced from "Capture
  Scheduling and the Manual-Only Trigger"
- `agent-system/extensions/sapience/index-entries.json` -- `line_count` for
  `per-repo-scoping.md` updated to 656 (post-edit `wc -l`)
- `specs/683_couple_sapience_capture_to_extension_activation/records/operator-followups.md` --
  Created: the two operator-owned follow-ups and the `folders` acceptance-test caveat

## Decisions

- Idempotence for `--capture-set` reads the EXACT-PATH `capture.projects[]` entry (realpath'd),
  matching `set_project()`'s own write-side key, never the longest-prefix match
  `verify-sapience-mcp.sh` check (i) uses for reporting -- a parent-prefix match would make a
  child repository under an enabled parent never acquire its own entry.
- Both new standalone actions (`--capture-set`, `--reap-capture`) live in
  `setup-sapience-mcp.sh` beside `--retire-global`/`--reap`, not in a new installed script:
  zero installer/manifest changes, one implementation of the capture-state query.
- The capture call keys on `GIT_ROOT` (from `resolve_checkout_toplevel()`), never on the hook's
  own `PROJECT_PATH`, because `.claude-extensions.json` is tracked and a linked worktree carries
  its own copy -- confirmed live that `PROJECT_PATH` resolves to the worktree in that case.
- Check (i)'s active+not-enabled outcome became a non-failing `[WARN]` (a new `warn()` helper
  was added, matching `pass()`/`fail()`'s own style) rather than a `[FAIL]`, since it can
  legitimately fire on every one-session-start lag or silent hook degradation.
- The `folders` double-gate is documented, not automated: no safe, non-interactive,
  single-writer vendor-CLI path exists to grow it.

## Plan Deviations

- Phase 1's header edit documented `--reap-capture`'s own edge-case note ahead of schedule (its
  implementation still landed in Phase 2 as planned) -- recorded in `progress/phase-1-progress.json`.
- Phase 5's premise stated `index-entries.json`'s `line_count` for `per-repo-scoping.md` was
  "currently 410, matching the file's live length"; the live value at Phase 5's start was
  actually 618 (a premise drift from an earlier dispatch, not a sibling edit) -- resolved by
  re-reading both values live and updating to the genuine post-edit length (656).

## Verification

- Build: N/A (bash scripts; `bash -n` parses clean on every edited script)
- Tests: Passed -- `test-sapience-mcp-registration.sh` 75/75 (source-store, final state);
  scoped `verify-touched.sh` runs across all six phases green, including a 98-suite OWED
  fallback battery
- `deploy-headless.sh`: `RESULT=landed_verify_clean`, `verify-deploy.sh` 41/41 checks (a
  shellcheck SC2034 finding this task introduced -- an unused `OUT70` test variable -- was
  caught by the first deploy attempt and fixed before the second, clean run)
- Files verified: Yes (all six edited files; `index-entries.json`'s `line_count` matches `wc -l`)
- `check-task-references.sh` / `check-record-versioning.sh`: 0 BLOCKING findings on the
  documentation edit

## Impacts

- Loading or unloading the sapience extension in any repository now also enables/disables
  transcript capture for that repository, at the next session start, with no manual
  `~/.sapience/config.json` edit required.
- `~/.sapience/config.json`'s `capture` key continues to have exactly one writer (the vendor
  client, under its own lock); this extension only ever calls that writer's own CLI.
- `verify-sapience-mcp.sh`'s check (i) no longer treats a lagged or silently-degraded
  active+not-enabled state as a bare informational line; it is now a named, non-blocking
  `[WARN]`.

## Follow-ups

- Operator: refresh the user-level hook/writer via `install-sapience-mcp-session-hook.sh`, then
  exercise the acceptance test in `/home/benjamin/Projects/Sapience/sf1-engine` (loading and
  unloading the extension across two session starts).
- Operator: file a task in `~/.dotfiles` to mirror this diff into that repository's own copies
  of the hook and the writer, restoring the byte-identity this task's Phase 3 confirmed broken.
- Operator: `sf1-engine` is in neither `capture.projects[]` nor `folders` today; after the
  acceptance test enables it, its transcripts stay ungated by `folders` until the vendor's
  interactive onboarding chooser is run once from a real terminal.
- See `records/operator-followups.md` for the full detail on all three.

## References

- Plan: `specs/683_couple_sapience_capture_to_extension_activation/plans/01_capture-activation-coupling.md`
- Report: `specs/683_couple_sapience_capture_to_extension_activation/reports/01_capture-activation-coupling.md`
- Operator record: `specs/683_couple_sapience_capture_to_extension_activation/records/operator-followups.md`
- Phase progress/handoffs: `specs/683_couple_sapience_capture_to_extension_activation/progress/phase-{1..6}-progress.json`,
  `specs/683_couple_sapience_capture_to_extension_activation/handoffs/phase-{1..6}-handoff-*.md`
