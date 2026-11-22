# Implementation Summary: Task #677

- **Task**: 677 - Sapience automatic writes and retrieval by project id
- **Status**: [COMPLETED]
- **Started**: 2026-11-21T22:00:00Z
- **Completed**: 2026-11-21T00:10:00Z
- **Effort**: 5.5 hours
- **Dependencies**: None blocking. Live end-to-end exercise of the read-side path remains gated
  on the app serving the link routes for this account and on `REPO_LINK_FOR` being non-empty in
  the deployed `fly.toml`; every phase was built and verified against a stub.
- **Artifacts**: plans/01_sapience-project-id-automatic-paths.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added a single shared link resolver to the Sapience extension's `scripts/lib/sapience-api-lib.sh`
that reads the committed `.sapience/project.json` binding and validates it field for field
against `repo_link.py`'s `parse_link`. Wired `sapience-retrieve.sh`'s read path to send
`project_cid` on `GET /v1/search` whenever a valid binding resolves, so a linked repository's
automatic dispatch memory block is drawn from the project's notes, while keeping the existing
`source=[repo:<slug>]` label filter as the no-link and rejection fallback. A `project_rejected`
field in an otherwise-2xx response degrades benignly (stderr warning, label-filtered result)
rather than being treated as a transport failure. The write-side `project_cid` path is
deliberately excluded (see Decisions below) — `sapience-remember.sh`, `postflight-sapience-notes.sh`,
and `sapience-publish.sh` are unmodified. `per-repo-scoping.md` now states the current design,
including the `&project=` (dead) vs. `project_cid` (honored) parameter distinction and the
installed vendor `mcp.py`'s unrelated `project` (company-store routing) argument on
`sapience_remember`.

## What Changed

- `agent-system/extensions/sapience/scripts/lib/sapience-api-lib.sh` — added
  `sapience_project_link_read <toplevel>` and `sapience_project_link_cid <toplevel>`: a
  single-location `.sapience/project.json` reader/validator (exact three-key `{project, name,
  repo}` shape, `repo` regex-checked, token/key/secret-shaped keys refused) with a header
  contract stating it takes an already-resolved toplevel and deliberately does not mirror
  `repo_link.py`'s upward `find_link` walk.
- `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` — sources the new lib after the
  existing `common.sh`/`PROJECT_ROOT` bootstrap; appends `&project_cid=<encoded cid>` to the
  `/v1/search` URL when a valid binding resolves (nothing appended on any failure path, keeping
  the no-link request byte-identical to before); treats a 2xx body's non-empty `project_rejected`
  field as a benign degrade (one stderr warning, continues through the existing hit-extraction
  path) rather than exit 2; header updated to document the new parameter, its `REPO_LINK_FOR`
  gating, the `project_cid` vs. `&project=` distinction, and the byte-identity guarantee.
- `agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` — added a `.curl_urls`
  URL recorder and `curl_urls` readback helper to `build_curl_stub`; extended `build_scratch` to
  copy `lib/sapience-api-lib.sh`; added a `write_binding` helper; added the pre-change
  negative-control case (case 18, pinned against the unmodified script) and the resolver unit
  cases (13-17) and link-present/malformed/`project_rejected`/non-2xx cases (19-22) — 59 passed,
  0 failed in the final run.
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` (502 ->
  556 lines) — states the current design: the `&project=`/`project_cid` parameter distinction,
  the vendor `mcp.py` `project`-argument (company-store routing) discussion paragraph, the
  read-side `project_cid` behavior and its fallbacks, the write-side's unchanged plain-`project`-
  key design and its governing `sf1-engine` ruling-7 boundary, and the shared resolver's name and
  single-location-lookup boundary.
- `agent-system/extensions/sapience/index-entries.json` — reconciled the `line_count` for
  `project/sapience/domain/per-repo-scoping.md` (502 -> 556) by a targeted single-field edit.
- `specs/677_sapience_automatic_writes_and_retrieval_by_project_id/plans/01_sapience-project-id-automatic-paths.md`
  — all five phases checked off `[COMPLETED]`.

## Decisions

- **Write-side `project_cid` is excluded, not deferred.** `sf1-engine`'s
  `integration/project-link.md` section 10 Ruling 7 — agreed with by this repository's
  `linked-repo-write-policy.md` and restated by `rules/sapience-write-path.md` — forbids any
  write attaching a verified `project_cid` from an autonomous run until two named leak paths
  close. The existing plain `project: "<key>"` write design is preserved exactly as committed.
- **One shared resolver, delivered for the link file only.** The host/token and
  worktree-resolution duplications across `sapience-remember.sh`,
  `postflight-sapience-notes.sh`, and the resolver's own call sites are left in place —
  consolidating them would require editing those scripts and `test-sapience-mcp-registration.sh`
  Case 30's nine-copy lockstep set for a simplification with no correctness payoff.
- **The resolver mirrors the single-location lookup, not `repo_link.py`'s upward `find_link`
  walk** — the two agree wherever `sapience-project-bind.sh` writes the file, which is the only
  place it ever does.
- **`project_cid` is sent alongside `source=`, never instead of it** — a server with the flag off
  or one that rejects the cid still returns the label-matched rows with no second request.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (bash scripts and markdown; no build step)
- Tests: Passed — all eight named suites green under `CORE_TEST_SUBJECT_MODE=source-store`:
  `test-sapience-capture.sh` (59/0), `test-sapience-remember.sh` (11/0),
  `test-postflight-sapience-notes.sh` (41/0), `test-sapience-publish.sh` (53/0),
  `test-sapience-vault-read.sh` (19/0), `test-sapience-project-bind.sh` (61/0),
  `test-sapience-context-scoping.sh` (6/0), `test-sapience-mcp-registration.sh` (58/0, Case 30's
  nine-copy worktree-block byte-identity assertion explicitly green, no tenth copy added).
  `bash .claude/scripts/verify-touched.sh` over the five touched paths: exit 0, 16 suites
  selected + 1 owed-fallback class (98 suites) = 114/114 passed, 0 failed.
- Files verified: Yes — `jq -e .` on `index-entries.json` succeeds; `wc -l` on
  `per-repo-scoping.md` (556) matches its `index-entries.json` `line_count`;
  `check-task-references.sh` and `check-record-versioning.sh` report 0 new findings on the
  edited files; `git diff` against the pre-plan commit shows `sapience-remember.sh`,
  `postflight-sapience-notes.sh`, and `sapience-publish.sh` unmodified.
- Full gate set: **deferred** to the once-per-invocation orchestration close per this cycle's
  multi-task `/orchestrate` batch directive (`## Batch Gate Deferral`) — this round discharged
  against the scoped `verify-touched.sh` tier and the eight named suites above, not an
  independent `verify-deploy.sh` run inside this dispatch.

## Impacts

- A repository with a committed `.sapience/project.json` binding now receives, on the read side
  only, a dispatch memory block scoped to the linked project's own notes once the server-side
  `REPO_LINK_FOR` flag is live for an account — currently unexercisable live (flag deployed
  `""`), verified against a stub instead.
- An unlinked or malformed-binding repository's `sapience-retrieve.sh` request is unchanged
  byte-for-byte, proved by a negative control pinned before the code change and re-run unchanged
  afterward.
- No write-path behavior changed: `sapience-remember.sh`, `postflight-sapience-notes.sh`, and
  `sapience-publish.sh` are untouched, and the governing `sf1-engine` Ruling 7 boundary on a
  verified autonomous `project_cid` write remains shut.

## Follow-ups

- Live end-to-end verification of the read-side `project_cid` path is blocked on the app serving
  the account's link routes (`sapience-app`'s `open_mvp_flags_and_create_linked_team_project`,
  not started; `repo_link_code_onto_release_line`, HOLD) and on `REPO_LINK_FOR` going non-empty
  in the deployed `fly.toml` — out of this repository's control.
- If `/v1/search` turns out to reject an unauthorized `project_cid` with a non-2xx status rather
  than a `project_rejected` field in a 2xx body once the flag is live, the existing exit-2 degrade
  fires instead (fail-open: the dispatch loses its memory block but nothing breaks); the fix at
  that point is a one-line addition to the status case, deliberately not pre-built since the
  shape is unverifiable today.

## References

- specs/677_sapience_automatic_writes_and_retrieval_by_project_id/plans/01_sapience-project-id-automatic-paths.md
- specs/677_sapience_automatic_writes_and_retrieval_by_project_id/reports/01_sapience-project-id-automatic-paths.md
- agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md
- agent-system/extensions/sapience/context/project/sapience/domain/linked-repo-write-policy.md
- .claude/rules/sapience-write-path.md
