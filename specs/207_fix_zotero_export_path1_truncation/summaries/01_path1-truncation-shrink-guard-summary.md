# Implementation Summary: Task #207

- **Task**: 207 - Fix zotero-generate-export.sh Path 1: accumulator truncation and shrink guard, then the pagination shortfall or path-preference order
- **Status**: [COMPLETED]
- **Started**: 2026-09-29T02:10:00Z
- **Completed**: 2026-09-29T02:36:00Z
- **Effort**: ~3.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_path1-truncation-shrink-guard.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed the silent-truncation data-loss defect in `zotero-generate-export.sh`'s Path 1 (Zotero 7
local API pull): a single `jq --argjson` argument crossing Linux's 128KiB `MAX_ARG_STRLEN` cap
was silently swallowed, truncating any library past ~200 items while still reporting success.
All 7 planned phases completed: a temp-file accumulator with loud failure and no partial
writes, `Total-Results`-driven pagination (replacing the wrong page-length-driven termination,
which resolved the absorbed 481-vs-4042 pagination question empirically), an authoritative
itemType-based exclusion filter (replacing a verified no-op CSL-`.type` predicate), a
content-keyed shrink guard with its own `--allow-shrink` opt-out distinct from `--force`, a
corrected `fetch_path3()` sqlite itemTypeID exclusion set (name-keyed, not hardcoded numeric
IDs), an 11-case offline regression suite driven by an extended PATH-shadowing curl stub, and
updated documentation across the two verified touchpoints that actually needed changes.

## What Changed

- `agent-system/extensions/literature/scripts/zotero-generate-export.sh` — `fetch_path1()`
  rewritten (temp-file accumulator via `mktemp -d` + `jq -s 'add'`, `Total-Results`-driven
  pagination, raw-format itemType cross-reference filter, loud abort on any failure with no
  write); generation control flow aborts before `write_output()` on a non-zero `fetch_path1()`;
  new `check_shrink_guard()` function and `--allow-shrink` flag; `fetch_path3()`'s SQL
  itemTypeID exclusion corrected to a name-keyed subquery on `itemTypes.typeName`; header
  comment, `show_usage()`, and exit-code documentation updated.
- `agent-system/extensions/literature/scripts/tests/curl-stub.sh` — extended with path-based
  dispatch (Zotero local API vs. Better BibTeX RPC, sharing `localhost:23119`), query-string
  parsing, a generic `-o`/`-D` handling path (also fixing the pre-existing
  `probe_zotero_api()`/`probe_bbt_rpc()` bare-code shape gap), synthetic Zotero item-type
  distribution knobs, and per-format fail/malformed knobs.
- `agent-system/extensions/literature/scripts/tests/generate-zotero-page-fixtures.sh` — new
  sibling helper: single-`jq -n`/`range`-invocation synthetic paged csljson/raw-format
  generator (never transits argv per item).
- `agent-system/extensions/literature/scripts/tests/generate-zotero-sqlite-fixture.sh` — new
  helper building a minimal, schema-faithful synthetic Zotero sqlite database for offline
  `fetch_path3()` testing.
- `agent-system/extensions/literature/scripts/tests/test-zotero-generate-export.sh` — new
  11-scenario regression suite (128KiB boundary, short mid-pagination page, loud
  transport/malformed failure, itemType exclusion, stub dispatch correctness, shrink guard
  blocks/opt-out/no-baseline, Path 3 itemType correction, and a re-run of the pre-existing Tier
  3 suite).
- `agent-system/extensions/literature/context/project/literature/patterns/zotero-pdf-resolution.md`
  — new subsection documenting the `format=csljson` pagination quirk (annotations dropped from
  bodies but counted in `Total-Results`/window), the itemTypes name-vs-ID lesson, and the
  corrected `fetch_path3()` exclusion.
- `agent-system/extensions/literature/commands/literature.md` — extended the Path 1/Path 3
  selection narrative with the shrink guard's behavior, `--allow-shrink` vs. `--force`
  semantics, and the broadened loud-failure contract.

## Decisions

- **`--allow-shrink` as a distinct opt-out from `--force`**: `--force` is existence-keyed and
  pre-fetch (required just to reach a fetch when the output already exists); reusing it for the
  shrink guard would make the guard unbypassable independently, since every guarded run already
  carries `--force` by construction. `--allow-shrink` is content-keyed and post-fetch.
- **Pagination termination on `Total-Results`, not page length**: verified live (during
  research) that `format=csljson` silently drops annotation-typed rows from page bodies while
  still counting them in `Total-Results` and the `limit`/`start` window, making a short
  mid-library page a normal occurrence rather than an end-of-data signal.
- **itemType exclusion via raw-format cross-reference by key**, not the CSL `.type` field:
  Zotero maps itemType `attachment` to CSL type `document` (never `"attachment"`), so the prior
  `.type != "attachment"` predicate was a verified no-op.
- **`fetch_path3()`'s itemTypeID exclusion resolved by type NAME**, not hardcoded numeric ID:
  the prior `NOT IN (1, 3, 28)` mismatch (those IDs are actually
  artwork/audioRecording/podcast on this installation, not attachment/note/annotation) is
  exactly the class of bug a name-keyed subquery cannot reintroduce.
- **User-decision resolution**: the plan's non-blocking `user_decision` (whether to fix
  `fetch_path3`'s itemTypeID filter in this task) was relayed by the team lead with no user
  answer obtained; proceeded on the planner's own recommendation per explicit instruction ("fix
  it in this task"), exactly as Phase 5 specifies.

## Plan Deviations

- Phase 3: added `CURL_STUB_ZOTERO_RAW_FAIL_AT`/`CURL_STUB_ZOTERO_RAW_MALFORMED_AT` stub knobs
  (format=json-only), not itemized in Phase 1's original task list, so the raw-itemType-fetch
  failure case could be tested independently of the initial no-start API probe (which defaults
  to `start=0` and would otherwise collide with a general `FAIL_AT=0`).
- Phase 6: delivered 11 test scenarios against the plan's asserted 9 (split "loud failure, no
  write" into distinct transport/malformed cases; added `path3-itemtype` and
  `pre-existing-suite` as explicit scenarios) — additive, not a coverage reduction.

## Verification

- Build: N/A (bash scripts)
- Tests: Passed — `bash -n` clean and `shellcheck -S warning` (0 findings) on all 5
  changed/new scripts; `test-zotero-generate-export.sh` 11/11; pre-existing
  `test-literature-discover-tier3.sh` 27/27 (both standalone and via this suite's own
  `pre-existing-suite` scenario)
- Files verified: Yes

## Impacts

- Any future Path 1 regeneration of a >200-item Zotero library now either exports completely
  or fails loudly with no write — the previously catastrophic silent-truncation overwrite
  scenario (a good 4046-item export replaced by a 200-item one, reported as success) can no
  longer recur even without the shrink guard.
- The shrink guard is a second independent line of defense: any path (1, 2, or 3) producing a
  dramatically smaller result than the last recorded export is blocked pending explicit
  `--allow-shrink`.
- `fetch_path3()`'s corrected itemTypeID exclusion means the NEXT sqlite-path regeneration will
  legitimately trip the shrink guard once (the corrected, true bibliographic count is
  materially smaller than the current contaminated on-disk count) — this is documented at the
  guard call site, in `fetch_path3()`'s own comment, and in `commands/literature.md`.

## Follow-ups

- The standing operational rule from this task's dispatch remains in force until a live Zotero
  regeneration is performed: any real regeneration should be done with Zotero closed (Path 3)
  until the user has verified Path 1 behaves correctly against the live API, since this task's
  verification was entirely offline via the PATH-shadowing stub.
- The first live regeneration after this fix lands (either path) is expected to need
  `--allow-shrink` once, per the Phase 5 rationale, to move the recorded baseline to the
  corrected, true bibliographic count.
- `fetch_path3()`'s hardcoded `$HOME/Zotero/storage/...` attachment root remains a known,
  latent, out-of-scope bug (already recorded in `zotero-pdf-resolution.md`'s Follow-up items
  section prior to this task).

## References

- Plan: `specs/207_fix_zotero_export_path1_truncation/plans/01_path1-truncation-shrink-guard.md`
- Research: `specs/207_fix_zotero_export_path1_truncation/reports/01_path1-truncation-and-pagination-root-cause.md`
- Progress files: `specs/207_fix_zotero_export_path1_truncation/progress/phase-{1..7}-progress.json`
- Handoffs: `specs/207_fix_zotero_export_path1_truncation/handoffs/`
