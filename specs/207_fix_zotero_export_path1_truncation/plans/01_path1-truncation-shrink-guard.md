# Implementation Plan: Path 1 Truncation Fix and Shrink Guard

- **Task**: 207 - Fix the silent-truncation data-loss defect in zotero-generate-export.sh's Path 1, and add a shrink guard
- **Status**: [IMPLEMENTING]
- **Effort**: 9 hours
- **Dependencies**: None
- **Research Inputs**: specs/207_fix_zotero_export_path1_truncation/reports/01_path1-truncation-and-pagination-root-cause.md
- **Artifacts**: plans/01_path1-truncation-shrink-guard.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`fetch_path1()` in `agent-system/extensions/literature/scripts/zotero-generate-export.sh` silently
discards every page past ~200 items (a single `jq --argjson` argv string crosses the 128KiB Linux
`MAX_ARG_STRLEN` cap, and a `2>/dev/null || echo "$all_items"` fallback swallows the failure), then
exits 0 reporting success. Research confirmed that defect and found three more in the same file: the
loop's `page_len -lt limit` end-of-pagination test is the wrong signal for `format=csljson` (Zotero
drops annotation-typed rows from page bodies without adjusting `Total-Results` or the pagination
window, so short mid-library pages are normal), the per-page attachment/note CSL-`.type` filter is a
verified no-op (Zotero maps attachments to CSL type `document`, never `attachment`), and
`fetch_path3()`'s `itemTypeID NOT IN (1, 3, 28)` excludes `artwork`/`audioRecording`/`podcast`
instead of `attachment`/`note`/`annotation` (the real IDs are `2`/`26`/`37`).

This plan rewrites `fetch_path1()` (temp-file accumulator, loud failure, `Total-Results`-driven
termination, working itemType filter), adds a content-keyed shrink guard with its own `--allow-shrink`
opt-out distinct from the existing existence-keyed `--force`, corrects `fetch_path3()`'s itemTypeID
set so the guard has a meaningful baseline, extends the PATH-shadowing curl stub so all of it is
testable offline, and updates the four verified doc touchpoints. Done means: a >200-item library
exports completely or fails with a non-zero exit and no write; no error-swallowing fallback survives
in `fetch_path1`; the shrink guard blocks a catastrophic overwrite and is exercised by a test; the
>128KiB accumulator boundary has dedicated regression coverage run offline.

### Research Integration

- The accumulator diagnosis is confirmed (`zotero-generate-export.sh:258`); fix direction unchanged
  (per-page temp files, `jq -s 'add'` once).
- The absorbed 481-vs-4042 pagination question is **answered empirically**, not open: Zotero's
  `format=csljson` serializer drops annotation-typed rows from page *bodies* while still counting
  them in `Total-Results` and the `limit`/`start` window. Verified exactly at `start=400`: raw window
  = 100 rows including 19 annotations; csljson body = 81. `81 < limit` trips the existing break.
  Phase 2 therefore replaces the termination test rather than re-investigating the discrepancy.
- Verified correct termination signal: increment `start` by `limit` unconditionally, stop when
  `start >= Total-Results` (read once from the first response's header). Driven this way, a full
  41-request sweep reached the true end and summed to 3372 csljson entries.
- The existing `.type != "attachment" and .type != "note"` filter removed **exactly 0** items across
  the live 3372-item sweep. Work item 1's "retain the existing filter" is therefore satisfied by
  replacing it with one that works, not by preserving a no-op (Phase 3).
- `write_meta_stamp()` already records `item_count` in `.zotero-library.meta.json`; the shrink guard
  reads that instead of re-parsing a ~2MB JSON file (Phase 4).
- `--force` gates the pre-fetch "output already exists" check (exit 3) and is *required* just to
  reach the fetch when a file exists, so it cannot double as the shrink opt-out (Phase 4 rationale).
- `curl-stub.sh` dispatches on hostname substring only, emits no headers, parses no query string, and
  does not recognize `probe_zotero_api()`'s `-s -o /dev/null -w '%{http_code}'` shape. All four gaps
  are real work, not a new case branch (Phase 1).
- `zotero-pdf-resolution.md` already carries a "known, latent bug, recorded here as a follow-up"
  section for a different `fetch_path3()` defect — reuse that phrasing template (Phase 7).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- `fetch_path1()` never silently truncates: no argv-transiting accumulator, no error-swallowing
  fallback, and the three terminal conditions (end-of-pagination, `max_pages` guard, error)
  distinguished explicitly, with error aborting non-zero and writing nothing.
- Path 1 pagination terminates on `Total-Results`, not on page length.
- Path 1's non-bibliographic exclusion actually excludes attachments/notes/annotations.
- A content-keyed shrink guard refuses a catastrophic overwrite of the existing export, with an
  opt-out flag distinct from `--force` and a documented rationale for the chosen semantic.
- `fetch_path3()`'s itemTypeID exclusion set corrected so the guard's baseline is a true
  bibliographic count.
- Offline regression coverage for the >128KiB accumulator boundary, the short-mid-page termination
  case, the loud-abort-no-write case, and the shrink guard blocking an overwrite.
- The four verified doc touchpoints reflect the changed contract.

**Non-Goals**:
- `synthesize_citekeys()`'s line-484 accumulator. It pipes the growing value through stdin and passes
  only one small item via argv, so `MAX_ARG_STRLEN` does not apply. It is O(n^2) and error-swallowing;
  both are explicitly out of scope. Do not rewrite it as though it shared the accumulator cause.
- `fetch_path3()`'s hardcoded `$HOME/Zotero/storage/...` attachment root (a separate known, latent
  bug already recorded in `zotero-pdf-resolution.md`).
- Any edit to `zotero-integration.md` or `tools/zotero-scripts.md` (neither mentions this script;
  avoiding them also keeps this task at zero file overlap with the active
  zotero-metadata-resolution task).
- Any edit under the deployed `.claude/**` tree.
- Re-running the sibling-script `--argjson` sweep (complete; line 258 is the only genuine instance).
- Re-deriving the 481-vs-4042 discrepancy (answered; see Research Integration).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Fixing only the accumulator leaves Path 1 capping out at the next annotation-heavy short page — still silent truncation, different threshold | H | H | Phase 2 replaces the termination test in the same edit; Phase 6 gives the short-page case its own regression test distinct from the 128KiB case |
| Shrink guard measured against the current contaminated 4042 baseline falsely blocks a correctly-filtered future run (~1556 true items) | H | H | Phase 5 corrects `fetch_path3()`'s itemTypeID set before the guard is relied on; guard diagnostic always names the opt-out flag so a block is never unrecoverable. Surfaced as a non-blocking `user_decision` |
| itemType filter re-implemented on an unverified server-side `itemType=-a -b` query syntax and ships silently broken again | H | M | Phase 3 uses the cross-reference-with-raw-format approach (authoritative `data.itemType`, keyed by item key — the same `.id \| split("/") \| last` mapping `enrich_path2()` already relies on). Server-side syntax may only be used if independently confirmed against Zotero's API docs AND asserted by a test |
| Curl stub extended by hostname case only, misrouting BBT-RPC calls into the items handler (same host:port) | M | H | Phase 1 adds path-based dispatch as an explicit acceptance criterion, with a test asserting a BBT-RPC URL is not served an items body |
| Reading `Total-Results` requires a new curl invocation shape the stub cannot emit | M | M | Phase 1 and Phase 2 fix the header-capture shape together: Phase 2 states the exact invocation, Phase 1's stub emits a matching header block, Phase 6 asserts it end to end |
| Concurrent sibling tasks on the same working tree | M | M | Re-read each file immediately before editing; stage only this task's own hunks by explicit path; never a directory or glob `git add`; never `git-snapshot.sh` in reverting default mode |
| A test that shells out to the real API or a running Zotero | M | L | Every test in Phase 6 runs under the PATH-shadowing stub with `ZOTERO_SQLITE` pointed at a fixture; no test may depend on a live API |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6, 7 | 5 |

Phases within the same wave can execute in parallel. Phases 2-5 are deliberately serialized: all
four edit `zotero-generate-export.sh`, and serializing them keeps each commit a reviewable
single-concern hunk.

### Phase 1: Extend the curl stub for the Zotero local API [COMPLETED]

- **Goal:** `scripts/tests/curl-stub.sh` can drive `zotero-generate-export.sh` Path 1 end to end
  offline — paged synthetic csljson bodies large enough to cross 128KiB, a short mid-pagination page,
  `Total-Results`/`Link` response headers, and correct dispatch between the items endpoint and the
  BBT-RPC endpoint on the same host:port.
- **Tasks:**
  - [x] Add **path-based** dispatch: match `*/api/users/0/items*` and `*/better-bibtex/json-rpc*`
        separately. Both share `localhost:23119`, so hostname matching alone misroutes RPC calls.
  - [x] Add query-string parsing for `start=` and `limit=` so the stub serves the correct synthetic
        page for a given window.
  - [x] Add a third recognized invocation shape: `curl -s -o /dev/null -w '%{http_code}'` — print
        **only** the code, no body (this is `probe_zotero_api()`'s and `probe_bbt_rpc()`'s exact
        shape; the body is discarded by `-o /dev/null`).
  - [x] Add a header-emitting route matching whatever header-capture invocation Phase 2 settles on
        (e.g. `-D -`), emitting a `Total-Results:` and `Link: ...rel="last"` block.
  - [x] Add a synthetic-page generator (extend `generate-test-fixtures.py` or add a sibling helper)
        producing N csljson items per page with padded `abstract` fields, so a page and the
        accumulated total both cross 131072 bytes well before the page count is large.
  - [x] Add env-var knobs for the scenarios Phase 6 needs: total item count, a `start` offset whose
        page returns fewer than `limit` items while more pages remain, and a page index that returns
        a transport failure (`curl_fail`) or malformed JSON.
  - [x] Keep the existing four-provider host dispatch and the unknown-host `exit 7` behavior intact.
  - [x] Drive the stub from a scratch script (not the real generator yet) to confirm each shape and
        each knob produces the intended bytes and exit codes.
- **Timing:** 1.5 hours
- **Depends on:** none
- **Verification Tier:** local
- **Files to modify**:
  - `agent-system/extensions/literature/scripts/tests/curl-stub.sh` - path dispatch, query parsing,
    third invocation shape, header emission, new scenario knobs
  - `agent-system/extensions/literature/scripts/tests/generate-test-fixtures.py` - synthetic paged
    csljson generator (or a new sibling helper under `tests/`)
  - `agent-system/extensions/literature/scripts/tests/fixtures/` - any static fixture files added
- **Verification**:
  - `bash -n` clean on the stub.
  - Scratch driver shows: items URL and RPC URL served different bodies; `-o /dev/null -w` shape
    printed a bare 3-digit code and nothing else; a served page's byte size > 131072; the
    header route emitted a parseable `Total-Results:` value.

---

### Phase 2: Rewrite fetch_path1 accumulation, termination, and failure handling [COMPLETED]

- **Goal:** `fetch_path1()` accumulates through temp files (never argv), terminates on
  `Total-Results`, and aborts loudly with no write on any fetch or accumulation failure.
- **Tasks:**
  - [x] Create a per-run `tmpdir` (`mktemp -d`) and register a `trap` cleaning it on EXIT, INT and
        TERM so it is removed on every exit path.
  - [x] Write each fetched page to `$tmpdir/page_${start}.json`; combine once at the end with
        `jq -s 'add'` over the page files. Neither a page nor the accumulator ever transits argv.
  - [x] Capture response headers on the first request (e.g. `curl -sD "$tmpdir/hdr" -o "$page_file"`)
        and parse `Total-Results` once into a `total` variable; treat a missing or non-numeric
        `Total-Results` as an error condition, not as zero.
  - [x] Replace the loop control with `start=$(( start + limit ))` unconditionally, looping while
        `start < total`. Do **not** break on a short page — short pages are a normal mid-pagination
        occurrence for `format=csljson`.
  - [x] Distinguish the three terminal conditions explicitly, each with its own message: (a) genuine
        end (`start >= total`), (b) `max_pages` guard hit, (c) error. Raise `max_pages` so a
        `total`-driven loop over a 4000+ item library is not clipped by it, and treat hitting it as
        condition (b), which is an error for write purposes, not a silent success.
  - [x] Delete the `2>/dev/null || echo "$all_items"` fallback entirely, and every other
        `|| echo "$all_items"` / `|| echo "[]"` in this function that can return a short result as
        success. A non-zero `curl`, an unparseable body, or a failed `jq -s 'add'` must return
        non-zero from `fetch_path1()`.
  - [x] Make the caller honor that: in the generation control flow, a non-zero `fetch_path1()` must
        abort before `write_output()` with a non-zero exit and no file written or overwritten (mirror
        the existing hardened orchestrator-mode "no silent empty export" branch's phrasing).
  - [x] Keep the trailing `citation-key`-defaulting `jq` pass, but route its failure to the same
        loud-abort path rather than `|| echo "$all_items"`.
- **Timing:** 1.5 hours
- **Depends on:** 1
- **Verification Tier:** full
- **Files to modify**:
  - `agent-system/extensions/literature/scripts/zotero-generate-export.sh` - `fetch_path1()` and the
    Path 1 branch of the generation control flow
- **Verification**:
  - `bash -n` clean; `shellcheck` no new findings on the changed function.
  - Under the Phase 1 stub with a synthetic library of 500+ items, the script writes a file whose
    item count equals the stub's configured total (proves the 128KiB boundary is crossed without loss).
  - With the stub configured to fail on page 3, the script exits non-zero and the output path's mtime
    and byte size are unchanged.
  - `grep -n '|| echo "\$all_items"' zotero-generate-export.sh` returns nothing inside `fetch_path1`.

---

### Phase 3: Replace the no-op CSL-type filter with an authoritative itemType filter [COMPLETED]

- **Goal:** Path 1 excludes attachment-, note-, and annotation-typed items using Zotero's
  authoritative `data.itemType`, not the CSL `.type` string.
- **Tasks:**
  - [x] Remove the existing `select((.type // "") != "attachment" and (.type // "") != "note")`
        predicate. It is a verified no-op (0 items removed across a full live sweep) and keeping it
        would ship ~1800 `document`-typed attachment stubs into every Path 1 export.
  - [x] For each pagination window, additionally fetch the raw format (`format=json`, same
        `limit`/`start`) to a temp file and collect the set of item keys whose `data.itemType` is
        `attachment`, `note`, or `annotation`.
  - [x] Filter the csljson page by key: a csljson entry's key is `.id | split("/") | last` — the same
        mapping `enrich_path2()` already relies on. Drop entries whose key is in the excluded set.
  - [x] Route raw-fetch and parse failures to Phase 2's loud-abort path; a failed exclusion lookup
        must not silently degrade to "exclude nothing".
  - [x] Do **not** use a server-side `itemType=-attachment -note -annotation` query parameter unless
        the syntax is independently confirmed against Zotero's official API `itemType` grammar AND a
        test asserts the exclusion actually happened. Ad hoc testing of that form during research did
        not filter as hoped.
  - [x] Add a brief comment recording why the CSL `.type` field cannot carry this filter (Zotero maps
        its `attachment` itemType to CSL `document`).
- **Timing:** 1.5 hours
- **Depends on:** 2
- **Verification Tier:** full
- **Scope Hypothesis:** Research measured, live, that this library yields 3372 csljson-converted
  entries of which ~1821 are CSL type `document` (mostly attachment stubs), leaving ~1556 true
  bibliographic items. These are plan-time hypotheses from one measurement session, not facts: at
  implementation time confirm the excluded-key count and the surviving count against the stub's
  configured synthetic mix (deterministic), and, if the real API is exercised at all, against
  `sqlite3 "file:$ZOTERO_SQLITE?immutable=1" "SELECT itemTypeID, count(*) FROM items GROUP BY 1"`.
  Do not hardcode 1556, 3372, or 1821 anywhere in the script or the tests.
- **Files to modify**:
  - `agent-system/extensions/literature/scripts/zotero-generate-export.sh` - `fetch_path1()` filter
  - `agent-system/extensions/literature/scripts/tests/curl-stub.sh` - serve a matching raw-format
    body for the same `start`/`limit` window
- **Verification**:
  - Under the stub with a synthetic mix containing attachment/note/annotation rows, the written
    export's item count equals the synthetic bibliographic-only count, and no written entry's key
    appears in the stub's excluded set.
  - With the raw fetch stubbed to fail, the script exits non-zero and writes nothing.

---

### Phase 4: Content-keyed shrink guard with a distinct opt-out flag [COMPLETED]

- **Goal:** The script refuses to overwrite an existing export with a dramatically smaller one unless
  explicitly allowed, via a flag distinct from `--force`, with the rationale documented in the
  script's own usage text.
- **Tasks:**
  - [x] Add `--allow-shrink` to the argument parser and to `show_usage()`.
  - [x] Record the rationale as a comment at the guard and in `show_usage()`: `--force` is
        **existence-keyed and pre-fetch** ("may I overwrite a file that exists?", exit 3, evaluated
        before any fetch, and *required* just to reach the fetch when a file exists);
        `--allow-shrink` is **content-keyed and post-fetch** ("may I overwrite with materially less
        data?"). Reusing `--force` would make the shrink guard unbypassable independently, because
        every guarded run already carries `--force` by construction.
  - [x] Implement the guard after `ITEMS` is final (post `synthesize_citekeys()`) and immediately
        **before** `write_output()`.
  - [x] Read the previous count from `.zotero-library.meta.json`'s `item_count` rather than
        re-parsing the multi-megabyte JSON. If the stamp is missing or unparseable but the export
        file exists, fall back to `jq 'length'` on the existing export; if that also fails, treat the
        previous count as unknown and **block** (an unknown baseline is not a safe baseline).
  - [x] Guard predicate: block when the candidate count is 0, or when
        `candidate < previous * 0.9` (a >10% shrink). State the threshold and its units in the
        diagnostic.
  - [x] No-existing-export branch: when neither the export file nor the stamp exists, there is
        nothing to protect — proceed and log one line saying the guard was not applicable because no
        prior export was found. Do not describe this as "first regeneration is unguarded"; the
        live state has a complete export on disk, so this branch is the exception, not the norm.
  - [x] Blocked path must exit non-zero with a distinct exit code (not 3, which is the
        already-exists code), write nothing, and print the previous count, the candidate count, the
        threshold, and the exact `--allow-shrink` invocation to override.
  - [x] The guard applies to every path (1, 2, and 3), not just Path 1 — the loss scenario is defined
        by what gets written, not by which path produced it.
- **Timing:** 1 hour
- **Depends on:** 3
- **Verification Tier:** full
- **Files to modify**:
  - `agent-system/extensions/literature/scripts/zotero-generate-export.sh` - arg parser,
    `show_usage()`, new guard function, generation control flow before `write_output()`
- **Verification**:
  - Against a fixture export + stamp with a large `item_count` and a stub serving far fewer items:
    non-zero exit, distinct exit code, output file byte-identical to before, diagnostic names
    `--allow-shrink`.
  - Same scenario with `--allow-shrink`: exits 0 and the smaller file is written.
  - With no export and no stamp present: exits 0, writes the file, logs the not-applicable line.
  - With a present export but a corrupt stamp and an unreadable export: blocks.

---

### Phase 5: Correct fetch_path3's itemTypeID exclusion set [NOT STARTED]

- **Goal:** `fetch_path3()` excludes `attachment`/`note`/`annotation` rather than
  `artwork`/`audioRecording`/`podcast`, so the sqlite path produces a bibliographic-only export and
  the shrink guard's baseline is meaningful.
- **Tasks:**
  - [ ] Replace `WHERE it.itemTypeID NOT IN (1, 3, 28)` with an exclusion resolved from the
        `itemTypes` table **by type name**, not by hardcoded numeric ID — e.g.
        `WHERE it.itemTypeID NOT IN (SELECT itemTypeID FROM itemTypes WHERE typeName IN
        ('attachment','note','annotation'))`. A name-keyed subquery cannot rot across Zotero versions
        the way the current hardcoded IDs did.
  - [ ] Add a comment recording the observed IDs for this installation (`attachment=2`, `note=26`,
        `annotation=37`) and that `1`/`3`/`28` were `artwork`/`audioRecording`/`podcast` — so the
        original mistake is not silently reintroduced.
  - [ ] Note in the same comment that this correction materially reduces the exported item count on
        the sqlite path (stub entries with empty title/author/issued fields are dropped), and that a
        first post-fix regeneration over a pre-fix export is expected to trip the Phase 4 shrink
        guard and legitimately needs `--allow-shrink` once.
- **Timing:** 1 hour
- **Depends on:** 4
- **Verification Tier:** full
- **Scope Hypothesis:** Research measured, live, `NOT IN (1,3,28)` = 4042 (identical to the unfiltered
  count) and `NOT IN (2,26,37)` = 1556 for this library. Confirm at implementation time against a
  fixture sqlite database built for the test (deterministic, no running Zotero needed), and against
  `SELECT itemTypeID, typeName FROM itemTypes` if the real database is read at all. The name-keyed
  subquery means no numeric ID is asserted by the shipped code.
- **Files to modify**:
  - `agent-system/extensions/literature/scripts/zotero-generate-export.sh` - `fetch_path3()` SQL and
    its rationale comment
- **Verification**:
  - Against a fixture sqlite database containing known counts of each item type, `fetch_path3()`'s
    output count equals the fixture's bibliographic-only count and contains no attachment/note/
    annotation-derived entries.
  - `sqlite3` invocation still succeeds read-only against a locked database path is **not** required
    here (Path 3 runs with Zotero closed); do not change the connection mode.

---

### Phase 6: Offline regression coverage [NOT STARTED]

- **Goal:** A new test script asserts every defect fixed above stays fixed, running entirely offline
  under the PATH-shadowing curl stub with no live API and no running Zotero.
- **Tasks:**
  - [ ] Create `scripts/tests/test-zotero-generate-export.sh`, following the structure and
        pass/fail-reporting conventions of the existing `test-literature-*.sh` scripts in that
        directory.
  - [ ] Install the stub as `curl` in a scratch dir prepended to `PATH`; point `ZOTERO_LIBRARY` at a
        scratch output path so no test can touch the real `$LITERATURE_DIR` export.
  - [ ] Test: **>128KiB accumulator boundary.** A synthetic library whose accumulated JSON exceeds
        131072 bytes well before the last page exports with an item count exactly equal to the
        configured total. Assert the byte size of the accumulated payload actually crossed the
        boundary, so the test cannot silently stop exercising the threshold it exists to cover.
  - [ ] Test: **short mid-pagination page.** A stub scenario returning fewer than `limit` items at a
        mid-library offset while `Total-Results` reports more must still export the full total —
        guarding the regression that produced the 481-item stop.
  - [ ] Test: **loud failure, no write.** With a mid-sweep page returning a transport failure, and
        again with one returning malformed JSON: non-zero exit, and the pre-existing output file
        unchanged (compare checksum before/after).
  - [ ] Test: **shrink guard blocks.** Pre-seed an export plus stamp with a large `item_count`, stub a
        much smaller library: non-zero exit, distinct exit code, file unchanged, diagnostic mentions
        `--allow-shrink`.
  - [ ] Test: **shrink guard opt-out.** Same scenario with `--allow-shrink`: exit 0, smaller file
        written.
  - [ ] Test: **no-existing-export branch.** Empty scratch dir: exit 0, file written, not-applicable
        line logged.
  - [ ] Test: **itemType exclusion.** Synthetic mix with attachment/note/annotation rows: no excluded
        key appears in the written export.
  - [ ] Test: **stub dispatch correctness.** A BBT-RPC URL is not served an items body (regression
        guard for the shared host:port).
  - [ ] Run the full existing test suite in `scripts/tests/` to confirm the stub changes broke no
        existing Tier 3 discovery test.
- **Timing:** 1.5 hours
- **Depends on:** 5
- **Verification Tier:** full
- **Scope Hypothesis:** This phase asserts nine test cases and one new test file. Confirm at
  implementation time that each case actually fails against the pre-fix script (stash the fix or run
  against `git show HEAD:<path>`) — a regression test that passes before the fix is not coverage.
  Report the actual case count if it differs.
- **Files to modify**:
  - `agent-system/extensions/literature/scripts/tests/test-zotero-generate-export.sh` - new
  - `agent-system/extensions/literature/scripts/tests/fixtures/` - fixture export, stamp, and
    sqlite database as needed
- **Verification**:
  - `bash scripts/tests/test-zotero-generate-export.sh` passes with every case reported.
  - Each new case demonstrably fails against the pre-fix version of the script.
  - No test invocation reaches `localhost:23119` (assert via the stub's `CURL_STUB_LOG`, and confirm
    no case requires Zotero to be running).

---

### Phase 7: Document the changed contract [NOT STARTED]

- **Goal:** The four verified doc touchpoints describe the new pagination contract, the working
  itemType filter, the shrink guard and its flag, and the corrected sqlite exclusion set.
- **Tasks:**
  - [ ] `context/project/literature/patterns/zotero-pdf-resolution.md`: add a subsection recording
        the Zotero local-API `format=csljson` pagination quirk (annotation rows dropped from page
        bodies while still counted in `Total-Results` and the `limit`/`start` window), the
        `itemTypes` name-vs-ID lesson, and the corrected `fetch_path3()` exclusion. Reuse the
        existing "known, latent bug, recorded here as a follow-up item" phrasing template already in
        that file for anything left undone.
  - [ ] `commands/literature.md`: extend the existing Path 1/Path 3 selection narrative with the
        shrink guard's behavior, `--allow-shrink` vs. `--force` semantics, and the new distinct exit
        code; align the existing "never write an empty file, fail loudly instead" guarantee with the
        now-broader loud-failure contract.
  - [ ] `context/project/literature/domain/literature-index.md`: re-check the single
        `zotero-generate-export.sh` "Not applicable" row for continued accuracy after these changes;
        amend only if it became inaccurate.
  - [ ] `context/project/literature/domain/corpus-directory-conventions.md`: same re-check of its
        single `zotero-generate-export.sh` row.
  - [ ] Update the script's own header comment block so the three-path rationale, the pagination
        contract, and the guard are discoverable at the point of use.
  - [ ] Confirm no task-number reference is introduced in any of these files (all are outside
        `specs/**`).
- **Timing:** 1 hour
- **Depends on:** 5
- **Verification Tier:** prose
- **Scope Hypothesis:** Four doc files are asserted as the touchpoints, verified by grep during
  research (`zotero-integration.md` and `tools/zotero-scripts.md` have zero hits for this script and
  are deliberately excluded to keep zero file overlap with the active zotero-metadata-resolution
  task). Two of the four carry only a single one-line "not applicable" mention and may need no edit
  at all. Confirm by re-grepping `zotero-generate-export` across
  `agent-system/extensions/literature/` at implementation time and report the actual edited set.
- **Files to modify**:
  - `agent-system/extensions/literature/context/project/literature/patterns/zotero-pdf-resolution.md`
  - `agent-system/extensions/literature/commands/literature.md`
  - `agent-system/extensions/literature/context/project/literature/domain/literature-index.md` (re-check)
  - `agent-system/extensions/literature/context/project/literature/domain/corpus-directory-conventions.md` (re-check)
  - `agent-system/extensions/literature/scripts/zotero-generate-export.sh` (header comment only)
- **Verification**:
  - Diff read-through confirming every changed hunk is prose or a comment region.
  - `bash .claude/scripts/check-task-references.sh` (or the repo's equivalent lint) reports no new
    task-number reference.
  - `grep -rn 'zotero-generate-export' agent-system/extensions/literature/` shows no touchpoint left
    describing the old contract.

---

## Testing & Validation

- [ ] `bash -n` and `shellcheck` clean on `zotero-generate-export.sh` and `curl-stub.sh`.
- [ ] `bash agent-system/extensions/literature/scripts/tests/test-zotero-generate-export.sh` passes.
- [ ] Every pre-existing test under `agent-system/extensions/literature/scripts/tests/` still passes
      (the stub is shared with the Tier 3 discovery tests).
- [ ] Acceptance criterion 1: a >200-item synthetic library exports completely under the stub; an
      injected mid-sweep failure produces a non-zero exit with the output file unchanged.
- [ ] Acceptance criterion 2: no `2>/dev/null ||` fallback that can return a short result as success
      remains anywhere in `fetch_path1`.
- [ ] Acceptance criterion 3: the shrink guard blocks a catastrophic overwrite, is exercised by a
      test, and its opt-out is `--allow-shrink`, distinct from `--force`, with the rationale in
      `show_usage()` and in `commands/literature.md`.
- [ ] Acceptance criterion 4: the >128KiB boundary has a dedicated test that asserts the boundary was
      actually crossed, run offline via the PATH-shadowing stub.
- [ ] Acceptance criterion 5: the four verified doc touchpoints reflect the changed contract.
- [ ] Absorbed pagination criterion: the 481-vs-4042 discrepancy is documented with its empirical
      cause, and the `Total-Results`-driven loop reaches the true end of pagination under the stub.
      Note that Path 1's achievable ceiling is Zotero's own csljson-converted set, so "Path 1 count
      == the pre-fix on-disk 4042" is explicitly **not** a parity target (that number is the
      unfiltered raw item-table total, contaminated with attachment/note/annotation stubs).
- [ ] No edit landed under `.claude/**`; every change is under
      `agent-system/extensions/literature/**`.

## Artifacts & Outputs

- `agent-system/extensions/literature/scripts/zotero-generate-export.sh` (modified)
- `agent-system/extensions/literature/scripts/tests/curl-stub.sh` (modified)
- `agent-system/extensions/literature/scripts/tests/test-zotero-generate-export.sh` (new)
- `agent-system/extensions/literature/scripts/tests/generate-test-fixtures.py` and
  `tests/fixtures/` (modified/new fixtures)
- `agent-system/extensions/literature/commands/literature.md` (modified)
- `agent-system/extensions/literature/context/project/literature/patterns/zotero-pdf-resolution.md`
  (modified)
- `agent-system/extensions/literature/context/project/literature/domain/literature-index.md`
  (re-checked, possibly modified)
- `agent-system/extensions/literature/context/project/literature/domain/corpus-directory-conventions.md`
  (re-checked, possibly modified)
- `specs/207_fix_zotero_export_path1_truncation/summaries/01_*-summary.md` (implementation summary)

## Rollback/Contingency

- Every phase is a separate scoped commit by explicit path, so any single phase reverts with
  `git revert <sha>` without disturbing the others. Prefer this over any working-tree discard.
- Sibling tasks are dispatched against this same working tree this cycle. Stage only this task's own
  hunks by explicit path; never a directory or glob `git add`; never `git add -A`.
- If a genuine working-tree rollback is needed, take a snapshot first per
  `context/contracts/recovery.md`'s rollback rung (including its out-of-scope override flag for a
  deliberate whole-tree case). Do not emit `git-snapshot.sh` in its reverting default mode as a
  routine start-of-phase checkpoint; a defensive checkpoint before risky work uses `--no-revert`.
- The user's real export at `/home/benjamin/Projects/Literature/zotero-library.json` is outside this
  repo, is not git-tracked, and has no backup. No phase may run the generator against the resolved
  default output path: every test and manual check must set `ZOTERO_LIBRARY` to a scratch path. If a
  manual run against the real path is ever wanted, copy the export and its `.zotero-library.meta.json`
  stamp aside first.
- Standing operational rule until this lands: any real regeneration must be done with Zotero
  CLOSED, so Path 3 runs instead of the truncating Path 1.
- Contingency on Phase 5: if the Path 3 itemTypeID correction is declined (see the `user_decision`
  raised with this plan), close Phase 5 as `[COMPLETED WITH EXCLUSIONS]` with a
  `#### Reasoned Exclusions` record, record the defect in `zotero-pdf-resolution.md` using its
  existing "known, latent bug" template, and state plainly in Phase 4's diagnostic and in
  `commands/literature.md` that the guard's baseline is knowingly a raw item-table count rather than
  a bibliographic one.
