# Implementation Summary: Task #647

- **Task**: 647 - Bind a repo to a Sapience project and read the vault's shared state
- **Status**: [COMPLETED]
- **Started**: 2026-11-19T08:50:00Z
- **Completed**: 2026-11-19T09:42:00Z
- **Effort**: ~5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_project-binding-vault-read-foundation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Built the shared host/token/API-resolution library (`sapience-api-lib.sh`) the `/sapience`
command group depends on, then the two scripts that sit on top of it: an interactive,
confirm-or-refuse project binder (`sapience-project-bind.sh`) that creates a fresh Sapience
project and persists the binding to `.sapience/project.json`, and a read-only aggregator
(`sapience-vault-read.sh`) that bundles local repo state and the vault's shared state into one
pinned JSON envelope for the as-yet-unwritten `/sapience` draft-assembly consumer. Both new
scripts are covered by their own test suites, the extension manifest is regenerated, and the
existing lockstep guard now compares all seven copies of the shared worktree-resolution block.

## What Changed

- `agent-system/extensions/sapience/scripts/lib/sapience-api-lib.sh` — new; the extension's
  first `scripts/lib/` file. Owns host/token precedence (mirroring `~/.sapience/mcp.py` exactly),
  one authenticated POST helper (`sapience_post`, also exposing the resolved HTTP status via
  `sapience_api_post_http_status`) and one authenticated GET helper (`sapience_get`, folding in
  the bounded one-retry-on-503-cold-start behavior), both with token redaction under
  `SAPIENCE_DRY_RUN=1`.
- `agent-system/extensions/sapience/scripts/sapience-project-bind.sh` — new; confirm-or-refuse
  creation of a fresh, named Sapience project shared with one collaborator discovered at runtime
  via `GET /v1/people`. Requires both `--name` and `--confirm` for the real mutation; the default
  dry-run posture prints the literal payload (a `<person id>` placeholder when `--to` is absent)
  and makes no network call at all. On success, writes `.sapience/project.json` byte-identical to
  `repo_link.py`'s `link_text()` serializer (exactly three string keys: `project`, `name`, `repo`).
  Loud-failure discipline on the confirmed response's `{ok, project, to}` shape.
- `agent-system/extensions/sapience/scripts/sapience-vault-read.sh` — new; read-only aggregator
  emitting the pinned `sapience-vault-read/1` envelope (local git/specs/session state plus five
  top-level vault GETs and two per-doc follow-ons for unread docs, bounded to 10). Per-source
  failure isolation: a single failing source records into `errors[]` and leaves its key `null`;
  the script exits non-zero only when all five top-level sources fail. `--update-cursor` is the
  only way `.sapience/last-read.json` is written.
- `agent-system/extensions/sapience/scripts/tests/test-sapience-project-bind.sh` — new; 14
  cases, 27 assertions, all passing.
- `agent-system/extensions/sapience/scripts/tests/test-sapience-vault-read.sh` — new; 9 cases,
  19 assertions, all passing.
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` — extended
  `LOCKSTEP_FILES` from five to seven entries (adding the two new scripts) and updated Case 30's
  comment/pass message accordingly.
- `agent-system/extensions/sapience/manifest.json` — `provides.scripts` regenerated to declare
  all three new scripts and both new test suites (11 → 16 entries).

## Decisions

- Dry-run default posture (no `--confirm`) makes NO network call at all, including skipping the
  `GET /v1/people` collaborator-discovery call, and uses a literal `<person id>` placeholder in
  the printed payload — matching the dispatch's own creation-call template and satisfying the
  plan's "exit 0 without a network call" requirement, which an initial draft that resolved the
  real collaborator id even under dry-run would have violated.
- The written `.sapience/project.json`'s `project` field is the response's `.share.id` (the
  server-minted channel cid, confirmed against `brain_server.py`'s `_people_project_share` ->
  `people_share_project` -> `project_public` -> `people_public` chain), never `.project.key`
  (only the slug this script itself sent in the request).
- The dispatch's "seven vault GETs" are implemented as five independently-resolvable top-level
  sources (projects, docs, project_notes, suggestions, notifications) plus two per-doc follow-ons
  (doc_bodies, doc_comments) bounded to `MAX_DOC_FETCH=10` docs flagged `unread: true` — never an
  unbounded per-doc fan-out. The all-failed exit-2 test counts only the five top-level sources.
- Network stubbing in both new test suites happens at the `curl` PATH-shadow boundary (mirroring
  `test-sapience-capture.sh`'s established technique), not by overriding the
  `sapience_post`/`sapience_get` bash functions directly — functions defined in a test's own
  shell are never visible inside the separately `bash <script>`-exec'd subprocess every script in
  this family uses.

## Plan Deviations

- **Task 2 (dry-run posture)**: redesigned to skip the `GET /v1/people` discovery call entirely
  under dry-run, using a `<person id>` placeholder — see Decisions above.
- **Task 3 (vault-side GET enumeration)**: treated as five top-level sources plus two bounded
  per-doc follow-ons rather than seven independent top-level sources — see Decisions above.
- **Task 4 (network stub boundary)**: stubbed at the `curl` PATH-shadow boundary rather than the
  `sapience_post`/`sapience_get` function boundary the plan's text names — see Decisions above.
- **Task 4 ("refusal without --confirm")**: interpreted as the dry-run default's safety property
  (no network call, no file write, exit 0) rather than a non-zero-exit refusal, resolving an
  ambiguity in the plan's own Phase 2/4 text in favor of the design already built in Phase 2.
- **Phase 5 staging mechanism**: the mechanized `git-commit-phase.sh`/`git-commit-scoped.sh`
  wrappers both call `git add` on their given pathspec, which would re-stage a foreign,
  unrelated prior dispatch's uncommitted hunk already present in `test-sapience-mcp-
  registration.sh`'s working tree. Worked around for the Phase 5 mid-phase commit via a
  hand-built `git apply --cached` sub-patch (isolating only this task's 3 hunks) with the working
  tree temporarily swapped to match the staged content. **This workaround did not survive the
  Phase 5 phase-close commit**: that commit's own `files_touched`-derived pathspec re-triggered
  `git add` on the whole file, sweeping the (by-then-restored) foreign hunk into commit
  `c435dba6b` under this task's own message. The foreign content is correct and the suite still
  passes; this is a commit-attribution defect, not a code defect, and no history rewrite was
  attempted (forbidden while another writer may be live on this shared tree). Recorded in detail
  in the Issue Log (`foreign-hunk-misattribution`, costly) as a mechanism gap: the Phase-Commit
  Containment Self-Check verifies a touched path is within the task's declared `file_scope`, but
  has no concept of "a hunk within an in-scope file that this task did not itself produce."

## Verification

- Build: N/A (shell scripts)
- Tests: Passed — `test-sapience-project-bind.sh` (27/27), `test-sapience-vault-read.sh` (19/19),
  `test-sapience-mcp-registration.sh` (all cases including the extended Case 30)
- Files verified: Yes — `bash -n` and `shellcheck` clean on every new/modified script;
  `sync-manifest-scripts.sh --check` reports `sapience: 16 on disk, 16 declared, 0 missing, 0
  absent` and `CHECK PASSED` across all 12 extensions

## Impacts

- The `/sapience` draft-assembly consumer (a separate, future task) can now call
  `sapience-vault-read.sh` for a stable, pinned JSON envelope of local + vault state, and
  `sapience-project-bind.sh` for the one-time, human-confirmed project creation/binding step.
- `sapience-api-lib.sh` is now available for any future Sapience script to source instead of
  re-deriving host/token resolution a fourth or fifth time.
- One commit (`c435dba6b`) in this task's own history carries a foreign, unrelated prior
  dispatch's hunk alongside this task's own LOCKSTEP_FILES change — see Plan Deviations and the
  Issue Log. The other task/dispatch that authored that hunk should treat it as already landed
  and not attempt to re-commit it.

## Follow-ups

- The `/sapience` command itself and the draft-assembly consumer that reads
  `sapience-vault-read.sh`'s envelope are separate, not-yet-built tasks (explicit Non-Goals here).
- Migrating to the `project_cid`/`REPO_LINK_FOR` server-side path once that flag is enabled on
  this token — `.sapience/project.json`'s format is already forward-compatible with it, but no
  script here reads/writes `project_cid` yet (by design; the flag is currently off).
- The Phase-Commit Containment Self-Check's mechanism gap (a foreign hunk within an in-scope
  file is never detected) is a system-level hardening opportunity worth a future task, surfaced
  by the `foreign-hunk-misattribution` issue-log entry.

## References

- Plan: `specs/647_sapience_project_binding_and_vault_read/plans/01_project-binding-vault-read-foundation.md`
- Report: `specs/647_sapience_project_binding_and_vault_read/reports/01_project-binding-vault-read-foundation.md`
- Progress files: `specs/647_sapience_project_binding_and_vault_read/progress/phase-{1..5}-progress.json`
- Handoffs: `specs/647_sapience_project_binding_and_vault_read/handoffs/phase-{1..5}-handoff-*.md`
- Issue log: `specs/647_sapience_project_binding_and_vault_read/issues.jsonl`
