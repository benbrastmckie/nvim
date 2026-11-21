# Implementation Summary: Task #681

- **Task**: 681 - Let the Sapience extension bind a repository to an existing shared project as
  well as to a new one, and register the repository with the server
- **Status**: [COMPLETED]
- **Started**: 2026-11-21
- **Completed**: 2026-11-21
- **Effort**: 8 hours (plan estimate; actual spread across 5 phases/dispatches)
- **Dependencies**: None blocking. Ordered before the task that reads the file this one writes.
- **Artifacts**: plans/01_bind-existing-project-register-repo.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`sapience-project-bind.sh` now has three modes instead of one: a read-only pick that lists the
caller's accepted and owned projects, a `--project <name|id>` bind that registers this
repository with an existing project through the server's link route, and the original
`--name`/`--confirm` create mode, unchanged. `/sapience` surfaces the bind as a fifth candidate
option inside its one existing approval picker. The two domain design records gained the
link-route mechanism they previously omitted entirely.

## What Changed

- `agent-system/extensions/sapience/scripts/sapience-project-bind.sh` -- added pick mode,
  `--project`/`--force` flags, row extraction/matching against the real `GET
  /v1/people/projects` response shape, `write_link_file()` as the sole writer, the link-route
  POST with 404/403 status-code classification, a role note, and static vendor-CLI delegation
  with read-back byte-identity normalization.
- `agent-system/extensions/sapience/scripts/tests/test-sapience-project-bind.sh` -- cases 15-24
  (61 assertions), covering pick listing, bind success/404/403, and delegated-vs-HTTP
  byte-identity.
- `agent-system/extensions/sapience/skills/skill-sapience/SKILL.md` -- Stage 1's binding gate no
  longer hard-stops on a missing link file; the bind is carried forward as a "Project binding"
  candidate through Stages 7-11 of the existing single `AskUserQuestion` picker (ceiling
  four -> five), reusing the file's own exactly-one-or-refuse discipline for the pick's
  zero/multi-row cases.
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` --
  appended a new `## The Repo-Link Mechanism` section documenting the three-key file format and
  its server-side serializer, the real listing-endpoint shape, the link route's gate order and
  its two named non-success outcomes, the response trap (the link response's `project` field is
  a descriptor dict, never a cid), static vendor-capability detection, and D1's
  delegate-then-normalize reconciliation.
- `agent-system/extensions/sapience/context/project/sapience/domain/command-draft-and-picker.md`
  -- retitled "The Four Candidate Write Surfaces" to five, added the Project binding row and its
  pre-check default (present when unlinked, never pre-checked), updated "The Dark Migration Path"
  to state the link route is now actively called with 404 as a named handled outcome while
  `REPO_LINK_FOR` stays off, and corrected Ruling 5's stale "always the owner side" parenthetical
  (invalidated by this task's own bind-to-existing mode).
- `agent-system/extensions/sapience/index-entries.json` -- regenerated `line_count` for the two
  edited domain-doc entries (mechanical, via `generate-context-line-counts.sh --write`, source
  store only).

## Decisions

- D1 (delegate the bind to a link-capable vendor client, normalize to one canonical writer on
  read-back, classify every outcome by HTTP status code alone, never parse vendor prose) is now
  recorded in `per-repo-scoping.md`, not only in the plan.
- The stale "this repo's own binding is always the owner side" claim in
  `command-draft-and-picker.md`'s Ruling 5 was corrected in place, since it sits in a file within
  this phase's own declared edit territory and was directly invalidated by this task's own
  Phase 1-3 work. The identical sentence in `linked-repo-write-policy.md` (committed by the
  already-completed task 678, out of this task's territory) was left unedited and recorded as a
  follow-up issue instead of touched out of scope.

## Plan Deviations

- **Phase 5**: corrected Ruling 5's stale ownership-side parenthetical in
  `command-draft-and-picker.md`, beyond the plan's literal task list, because this task's own
  earlier phases invalidated that sentence and it sits in a file this phase was already editing.
  See the plan's Phase 5 Deviations subsection and the progress file's `deviations` array for the
  full record.
- No other deviations from the plan.

## Verification

- Build: N/A (markdown/shell extension, no compiled build)
- Tests: `CORE_TEST_SUBJECT_MODE=source-store bash
  agent-system/extensions/sapience/scripts/tests/test-sapience-project-bind.sh` -- 24 cases, 61
  assertions, all green (Phases 1-3).
- `bash .claude/scripts/verify-touched.sh agent-system/extensions/sapience/skills/skill-sapience/SKILL.md`
  -- green except the pre-existing, already-documented deployed-mirror drift (Phase 4).
- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4 --skip-unchanged` (Phase 5, this
  dispatch's Batch Gate Deferral narrowing) -- green for both edited domain docs after fixing a
  self-caused `index-entries.json` `line_count` mismatch; the only remaining gate-3 failures are
  the pre-existing `sapience-project-bind.sh`/`test-sapience-project-bind.sh` deployed-mirror
  drift from Phases 1-3, deferred to the orchestration-close redeploy per the plan's Risk table.
- `bash .claude/scripts/check-task-references.sh` -- 0 occurrences in both Phase 5 files.
- Files verified: Yes.

## Impacts

- Running the bind from a fresh clone of any repository can now link it to a chosen existing
  project (not only a freshly created one), and the repository is registered with the server's
  linked-repository list where the server's `repo_link.enabled` flag supports it (currently off
  for this credential; the 404 path records the binding locally only).
- `/sapience` in an unlinked repository now offers binding as a first-class option inside its
  existing approval picker instead of stopping dead.

## Follow-ups

- The `GET /v1/people/projects` response-shape mismatch in `sapience-publish.sh`'s `ko`
  subcommand and `sapience-vault-read.sh`'s `notes_cid` resolution (both out of this task's
  territory) is a named follow-up worth filing, per the plan's Artifacts & Outputs section.
- `linked-repo-write-policy.md`'s Ruling 5 (owned by the already-completed task 678, out of this
  task's territory) carries the same now-stale "always the owner side" claim this task's own
  in-territory copy of the sentence was corrected for; recorded via `issue-record.sh` as a
  follow-up to apply the identical correction there.
- The deployed `.claude/` mirror for the sapience extension is stale relative to this task's
  edited source store (scripts and SKILL.md); redeploy is deferred to the orchestration close, as
  planned.

## References

- Plan: specs/681_sapience_bind_existing_project_and_register_repo/plans/01_bind-existing-project-register-repo.md
- Research: specs/681_sapience_bind_existing_project_and_register_repo/reports/01_bind-existing-project-register-repo.md
- Progress files: specs/681_sapience_bind_existing_project_and_register_repo/progress/phase-{1..5}-progress.json
- Handoffs: specs/681_sapience_bind_existing_project_and_register_repo/handoffs/
