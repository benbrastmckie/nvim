# Implementation Summary: Task #648

- **Task**: 648 - Add the four Sapience write-surface publishers with loud-failure discipline
- **Status**: [COMPLETED]
- **Started**: 2026-11-19T03:00:00Z
- **Completed**: 2026-11-19T04:30:00Z
- **Effort**: ~3 hours
- **Dependencies**: 647 (sapience-project-binding-and-vault-read) — consumed its
  `scripts/lib/sapience-api-lib.sh` and its `.sapience/project.json` binding writer
- **Artifacts**: plans/01_sapience-publish-write-surfaces.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added `scripts/sapience-publish.sh` to the Sapience extension's source store, exposing four
write-surface publishers (`doc-comment`, `doc-version`, `dm`, `ko`) as subcommands behind one
entry point, each dry-run-by-default with an explicit `--confirm` required for any network
write. All four route through the dependency task's shared `lib/sapience-api-lib.sh` for
host/token/HTTP, and no instruction surface names an MCP write tool as a prescribed write path.
A new `scripts/tests/test-sapience-publish.sh` suite covers all four subcommands (53 cases, all
green) against a PATH-shadowed `curl` stub. Both files are deployed to `.claude/scripts/` and
confirmed byte-identical to their source-store copies.

## What Changed

- `agent-system/extensions/sapience/scripts/sapience-publish.sh` — new; four subcommands
  (`doc-comment`, `doc-version`, `dm`, `ko`), shared `--dry-run`/`--confirm` flag parsing, the
  byte-identical worktree-checkout-resolution block, a `_sapience_post_capture` helper that
  works around a `sapience_post` subshell/status-loss hazard, and per-endpoint loud-failure
  handling written against each endpoint's own verified response shape.
- `agent-system/extensions/sapience/scripts/tests/test-sapience-publish.sh` — new; 53 test
  cases covering structural behavior, the worktree-block lockstep guard, and all four
  subcommands' dry-run/confirmed/loud-failure paths.
- `agent-system/extensions/sapience/manifest.json` — registered both new scripts in
  `provides.scripts`, preserving sort order (gate 3's commit-blocking parity rule).
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` — widened
  Case 30's `LOCKSTEP_FILES` array to an eighth copy (`sapience-publish.sh`).
- `.claude/scripts/sapience-publish.sh` and `.claude/scripts/tests/test-sapience-publish.sh` —
  deployed copies (regenerated via `deploy-headless.sh`, not hand-authored).

## Decisions

- **`_sapience_post_capture` helper (Phase 2).** `sapience_post`'s `sapience_api_post_http_status`
  side-channel is documented as "set into the caller's shell," which is true only because the
  *library file* is sourced — a call site that wraps the invocation in `x="$(sapience_post ...)"`
  still forks a subshell for the command substitution and silently loses the status. Every call
  site in this script that needs the HTTP status redirects to a temp file instead
  (`sapience_post ... > "$tmp"`, which does not fork a subshell for a plain function call).
- **`ko --note <text>` field defaults (Phase 4).** The plan's `--note`/`--project` CLI is
  deliberately simpler than `sapience-remember.sh`'s `--subject`/`--value` interface and does not
  pin down the resulting KO's subject/predicate/ko_type/confidence. Filled in with the same
  defaults `sapience-remember.sh` uses (`subject: "finding"`, `predicate: "finding is"`,
  `ko_type: "insight"`, `confidence: 0.8`), recorded as a progress-file deviation since no plan
  verification criterion checks the subject field's content.
- **Single redeploy at the end (Decision D3, inherited from the plan).** Registering both new
  scripts in Phase 1 was safe pre-deploy (gate 3's drift rule skips an absent deployed copy);
  deploying mid-plan would have made every subsequent source edit a drift FAIL.

## Plan Deviations

- **Task 4.1** (ko's per-note field defaults): altered — see Decisions above. Not a scope
  change; no verification criterion is affected.

## Verification

- Build: N/A (bash scripts; `bash -n` clean on both new files)
- Tests: `test-sapience-publish.sh` 53/53 PASS; `test-sapience-mcp-registration.sh` 55/55 PASS
  (including the widened Case 30); `test-sapience-project-bind.sh` PASS against the deployed
  tree
- Files verified: Yes — both deployed copies exist and are `cmp -s` byte-identical to their
  source-store counterparts
- Gate 3 (`check-extension-docs.sh`/`verify-deploy.sh --only-gate 3`): no `provides.scripts`
  parity finding (`NOT in provides.scripts` / `missing on disk`) for this task's files; one
  pre-existing, out-of-scope drift finding remains on `sapience-vault-read.sh`
  (trailing-newline-only, from a prior task, not touched by this one)
- `grep` checks: no occurrence of any MCP write tool name prescribing a write path; no
  occurrence of `project_cid` being sent
- `verify-touched.sh` over all 4 touched paths, run twice (Phase 1 and Phase 5): both runs
  reproduced the same 2 pre-existing/environmental "NEW" failures
  (`test-mcp-merge-target.sh`, `test-verify-deploy-gate-selection.sh`'s wall-clock timing case),
  each building its own isolated fixture unrelated to this task's files, consistent with heavy
  concurrent multi-agent load on this machine during this dispatch
- Full gate set (`verify-deploy.sh` unflagged): explicitly deferred to the orchestration close
  per the dispatch's Batch Gate Deferral directive, not independently run in this dispatch

## Impacts

- Gives a future `/sapience` command's approval picker (not built here — explicit Non-Goal)
  concrete publisher interfaces to call: four subcommands, each with a literal-payload
  `--dry-run` preview the picker can show a user before approval.
- Closes the per-repo-scoping gap `_ko_matches_channel` depends on for the `ko` surface: writes
  now carry a resolved `project` key rather than leaving every KO's channel match permanently
  unsatisfiable.
- Discovered and fixed two reusable shell pitfalls (the `$(...)`-subshell status-loss hazard and
  the `cmd 2>/dev/null >&2` redirection-order bug) documented inline in the new script for any
  future Sapience script author to avoid repeating.

## Follow-ups

- Building the `/sapience` command and its approval picker (explicit Non-Goal of this task) is
  the natural next task, consuming these four subcommand interfaces.
- The pre-existing `sapience-vault-read.sh` deployed-vs-source drift (trailing-newline-only) is
  out of this task's scope and remains open for whichever task owns that file.
- The dark `REPO_LINK_FOR` path (`project_cid`) remains the eventual migration target per the
  plan's Non-Goals; this script sends only the plain `project` field today and needs no code
  change the day that flag is enabled.

## References

- Plan: `specs/648_sapience_publish_write_surfaces/plans/01_sapience-publish-write-surfaces.md`
- Research report: `specs/648_sapience_publish_write_surfaces/reports/01_sapience-publish-write-surfaces.md`
- Progress files: `specs/648_sapience_publish_write_surfaces/progress/phase-{1,2,3,4,5}-progress.json`
- Handoffs: `specs/648_sapience_publish_write_surfaces/handoffs/phase-{1,2,3,4,5}-handoff-*.md`
