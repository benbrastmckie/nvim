# Implementation Summary: Zotero metadata resolution upgrade and Zotero 10 swap plan

- **Task**: 39 - Upgrade Zotero metadata resolution and plan the Zotero 10 backend swap
- **Status**: [COMPLETED]
- **Started**: 2026-10-02T19:00:00Z
- **Completed**: 2026-10-02T23:10:00Z
- **Effort**: ~10 hours (matches the plan's revised estimate, not the task description's superseded 3-6 hour figure)
- **Dependencies**: 38 (write-back path activation, completed)
- **Artifacts**: plans/02_zotero-metadata-resolution.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Implemented all 9 phases of the plan, closing all four work items from the task description: a
real translation-server metadata-resolution step for web-discovered sources ahead of item
creation, the zotero-mcp adoption decision (defer, with reasons and reversal triggers), an
explicit quota-aware auto-attach policy replacing discover-the-ceiling-by-413, and the recorded
(not executed) Zotero 10 backend-swap plan. Every edit landed under
`agent-system/extensions/literature/**`; nothing under `.claude/**` or `~/.dotfiles` was touched.

## What Changed

- `agent-system/extensions/literature/scripts/zotero-write.sh` — new `item-add-json` operation
  (POSTs the Zotero Web API's items endpoint directly — the one exception to this script's
  otherwise pure `zot`-wrapper posture — with a library-ID resolution ladder, body normalization,
  and response-envelope normalization to the existing `{"ok":…,"data":{"key":…}}` shape); new
  `orphan-clean` operation (thin wrapper around `zot orphans clean --yes`, dead-only, no
  `--include-recoverable`).
- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` — new
  `resolve_via_translation_server()` helper (calls `POST /search` with a DOI or arXiv ID,
  5s-timeout graceful degradation, never calls `POST /web`); reworked resolvable branch to a
  create-then-attach decomposition on a successful resolution (`item-add-json` then `attach-file`
  as separate calls) with the existing atomic `item-add --pdf [--doi]` call kept unchanged as the
  fallback; new `ONLINE_INGEST_INGESTED_NO_ATTACHMENT` directive token (exit 0) for the
  partial-success surface (item created, attach failed/skipped); quota-aware auto-attach policy
  (`ZOTERO_AUTO_ATTACH`, a reactive `specs/zotero-index.json` `quota_state` cache seeded from a
  real 413, an operator override, 24h staleness, best-effort post-failure `orphan-clean`);
  `resolution_path`/`attachment_state` provenance fields surfaced onto every `index.json` and
  `literature-index.json` entry via `patch_global_index()`/`upsert_subindex()`.
- `agent-system/extensions/literature/commands/literature.md` — handling for the new
  `ONLINE_INGEST_INGESTED_NO_ATTACHMENT` token.
- `agent-system/extensions/literature/context/project/literature/patterns/zotero-item-creation.md`
  — new Section 7 (`item-add-json`: capability gap, envelope-normalization exception,
  create-then-attach decomposition, `resolution_path`/`attachment_state` vocabulary,
  translation-server endpoint verification status) and Section 8 (`orphan-clean`, local-sync-lag
  caveat, the two known orphan keys).
- `agent-system/extensions/literature/context/project/literature/domain/zotero-integration.md` —
  new "Zotero MCP: Adoption Decision" section (defer, reasons, verified absence, reversal
  triggers, registration-elsewhere note), new "Backend Swap Plan (Zotero 10)" section (choke-point,
  what changes internally, what stays constant for callers, `/connector/saveItems` rejection, not
  implemented), new "Auto-Attach Policy (Quota-Aware)" section.
- `agent-system/extensions/literature/context/project/literature/tools/zotero-scripts.md` —
  updated `zotero-write.sh` inventory row; new section on the `zot` CLI's
  `delete`/`orphans`/`trash`/`duplicates` family.
- `agent-system/extensions/literature/README.md` — updated `zotero-write.sh` row and Deployment
  Status mention to name the two new operations.
- `agent-system/extensions/literature/index-entries.json` — `line_count` corrections for the
  three context files whose content grew (surgical, single-entry edits after Phase 7 surfaced
  that the bulk `generate-context-line-counts.sh --write` tool touches every extension, not just
  literature — see Decisions below).

## Decisions

- Reused the existing `ATTACHMENT_STATE` three-value enum (`attached`/`failed`/`skipped-quota`)
  for a `ZOTERO_AUTO_ATTACH=never` policy skip rather than inventing a fourth "skipped-policy"
  value — the log line, not the state value, distinguishes the reason, per the plan's closed
  vocabulary.
- `zotero-item-creation.md` needed no edit in Phase 4 (confirmed via `grep -c`): it carried no
  per-token enumeration to synchronize at that point; the full new sections landed in Phase 7 as
  the plan anticipated.
- After Phase 7's `generate-context-line-counts.sh --write` run touched four unrelated
  extensions' `index-entries.json` files (some overlapping concurrently-dispatched sibling
  tasks' declared file scope), reverted every one of those via `git apply -R` of each file's own
  diff and switched to direct, single-entry `line_count` edits for the remaining two phases —
  avoiding any cross-task interference for the rest of the implementation.
- All three Phase 9 gates (translation-server live enable/test in `~/.dotfiles`, a live
  end-to-end write to the production Zotero library, and a real `orphan-clean` run) were
  declined: this is an autonomous `/orchestrate` dispatch with no interactive operator present to
  grant the explicit authorization each gate requires. Decline-path records are in place per the
  plan's own designed decline paths (see Follow-ups).

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (shell scripts, docs)
- Tests: `bash -n` passed on both modified scripts; full `--dry-run` regression matrix passed for
  every `zotero-write.sh` operation (`note-add`, `tag-add`, `tag-remove`, `attach-file`,
  `item-add`, `item-add-json` including empty-body exit 1 and missing-library-ID exit 2,
  `orphan-clean`) and for the bridge's three classification paths (arXiv-only, DOI-bearing,
  `in_zotero_no_pdf`), each producing exactly one stdout directive token; sandboxed unit-test
  harnesses (fake `GIT_ROOT`/`LITERATURE_DIR`) verified the translation-server helper's four
  degradation branches plus a mocked success response, the full 9-case quota-policy matrix
  (fresh-over-quota skip, stale-cache one-attempt, never/always overrides, 413-message parse
  match/non-match, `zot_data_dir` preservation, operator-override precedence), and
  `patch_global_index`'s idempotency with the two new fields. Confirmed zero real Zotero writes
  and zero pollution of the real repo's `specs/zotero-index.json` (still absent) across every
  test.
- Files verified: Yes — `check-extension-docs.sh` reports only the expected
  deployed-script-content-drift finding for `literature-ingest-online.sh` (source edits postdate
  an intervening deploy; `zotero-write.sh`'s deployed copy already matches source); repo-wide
  task-reference lint reports 0 occurrences; `git status --short .claude/` empty throughout.

## Impacts

- Web-discovered sources with a DOI or arXiv ID now get translation-server-resolved, Crossref/
  publisher-quality metadata when the service is reachable, instead of relying solely on `zot add
  --pdf`'s own best-effort PDF-text DOI extraction — closing the pipeline's thinnest point per the
  task description.
- No silent quota-exhaustion failure mode remains: an over-quota attach attempt is now skipped
  pre-emptively (under the default `under-quota` policy) rather than discovered by a 413 that
  leaves an orphaned attachment record behind.
- Every ingested corpus-index entry now carries honest provenance (`resolution_path`,
  `attachment_state`), letting a future reader or auditor distinguish fully-resolved records from
  fallback-path ones without re-deriving it from logs.
- The zotero-mcp question is closed for now with a reasoned, reversible decision instead of an
  open question; the Zotero 10 swap has a concrete, reviewable plan ready for whenever that
  release stabilizes.

## Follow-ups

- **Operator action**: redeploy the literature extension via the normal deploy flow
  (`deploy-headless.sh` or the `<leader>al` picker action) to sync `.claude/scripts/
  literature-ingest-online.sh` with these source changes; `zotero-write.sh`'s deployed copy
  already matches.
- **Gate A (declined)**: a short, explicitly authorized enable/test/revert cycle in `~/.dotfiles`
  (`services.zoteroTranslationServer.enable = true`, exercise `POST /search` and the still-open
  `POST /web` gap, then revert) remains available whenever an operator wants to perform it.
- **Gate B (declined)**: a live end-to-end `item-add-json` write against the production library
  remains available to confirm the Web API's native response field names (currently UNCONFIRMED
  under the existing defensive multi-candidate envelope lookup).
- **Gate C (declined)**: `zotero-write.sh orphan-clean` (real run, not `--dry-run`) against the
  two known orphaned attachment records (`5J2WMXDD`, `CB99228V`) is expected to no-op until a
  Zotero desktop client syncs them down locally; `zot orphans clean`'s own guidance is to remove
  them from the desktop directly in the meantime.
- The account's storage quota (2745.6 MB used against a 300 MB limit, last directly observed) is
  not re-verifiable without a real write; the reactive cache in `specs/zotero-index.json` will
  self-correct on the next real attach attempt or 413.

## References

- Plan: `specs/039_zotero_metadata_resolution_upgrade/plans/02_zotero-metadata-resolution.md`
- Research: `specs/039_zotero_metadata_resolution_upgrade/reports/01_zotero-tooling-landscape.md`,
  `specs/039_zotero_metadata_resolution_upgrade/reports/02_zotero-metadata-resolution-design.md`
- Progress files: `specs/039_zotero_metadata_resolution_upgrade/progress/phase-{1..9}-progress.json`
- Handoff: `specs/039_zotero_metadata_resolution_upgrade/handoffs/phase-6-handoff-20261002T194137Z.md`
