# Implementation Plan: Zotero metadata resolution upgrade and Zotero 10 swap plan

- **Task**: 39 - Upgrade Zotero metadata resolution and plan the Zotero 10 backend swap
- **Status**: [IMPLEMENTING]
- **Effort**: 10 hours
- **Dependencies**: 38 (write-back path activation, completed)
- **Research Inputs**: `specs/039_zotero_metadata_resolution_upgrade/reports/01_zotero-tooling-landscape.md`, `specs/039_zotero_metadata_resolution_upgrade/reports/02_zotero-metadata-resolution-design.md`
- **Artifacts**: plans/02_zotero-metadata-resolution.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The literature extension's online-ingest bridge creates Zotero items with whatever metadata
`zot add --pdf` can extract from a PDF, which is nothing at all for an arXiv preprint with no
registered DOI — even though the discovery record already carries title, authors, and year. This
plan adds a real metadata-resolution step (translation-server `POST /search`) ahead of item
creation, adds the new write capability that resolved metadata requires, makes auto-attach an
explicit quota-aware policy instead of a discover-the-ceiling-by-413 failure mode, records the
zotero-mcp adoption decision, and records (does not execute) the Zotero 10 backend-swap plan.
Definition of done: all four acceptance criteria in the task description are satisfied, every edit
lands under `agent-system/extensions/literature/**`, and every step requiring a real write to the
production Zotero library or a change in another repository is an explicitly gated proposal with a
stated decline path.

### Effort divergence from the task estimate

The task description carries a 3-6 hour estimate written before research established that
translation-server integration requires a **new** `zotero-write.sh` operation (the existing
`item-add` cannot carry a JSON item body, and `zot add` has no JSON-body input at all — reconfirmed
live at plan time via `zot add --help`). That single finding turns Work Item 1 from wiring into
capability work and moves the realistic estimate to ~10 hours. The estimate above is the honest
one; the task-description figure is superseded, not ignored.

### Research Integration

Both reports are integrated. Report 02's **Live Verification** section (2026-08-11T21:46-21:49
UTC) and its "Summary of corrections" table are treated as authoritative wherever they supersede
earlier prose. Carried into this plan as fact:

- `zot` 0.10.0 is live and credentialed via `~/.config/zot/config.toml`.
- `zot` **does** ship `delete`, `orphans clean`, `trash list/restore`, and
  `duplicates --by doi|title|both`. Work Item 3's cleanup wraps `zot orphans clean`; no new
  Web-API-DELETE mechanism is invented.
- Local SQLite sync lag is a normal operating condition, not an edge case: an item created via the
  Web API is invisible to every `zot` read (`read`, `search`, `orphans list`, `duplicates`) until a
  desktop client syncs it down. Confirmed live against a same-day item and against the two known
  orphaned attachment records.
- translation-server is correctly OFF by default (0 unit files, nothing on port 1969) — design, not
  defect. `POST /search` was already live-smoke-tested with a real DOI during the cross-repo
  provisioning work; **`POST /web` has never been exercised by anyone**.
- Storage quota is not re-verifiable (no API endpoint; only a 413 body reveals it). Last known
  state stands: 2745.6 MB used against a 300 MB limit. A preflight check is structurally
  impossible; the gate must be reactive and/or operator-configured.
- `--via-bridge` remains unavailable (port 23119 closed, `zot bridge status` = `not_reachable`).
- `zotero-mcp` is confirmed absent (`command -v zotero-mcp` empty, absent from `claude mcp list`).
  The **defer** decision is grounded in verified absence.

Additional facts established at plan time (read-only probes, this session):

- `zot add`'s complete option set is `--doi --url --from-file --pdf --dry-run --idempotency-key
  --no-resolve`. There is **no** raw-JSON-body option, confirming the capability gap. `zot add
  --url` exists but performs its own opaque resolution and cannot accept translation-server output,
  so it is not the chosen path.
- `zot orphans clean` supports `--include-recoverable`, `--yes`, `--dry-run`,
  `--idempotency-key`, defaults to dead-only orphans, and documents its own sync-lag behavior:
  "records that were never synced to the server return 'not_found' — remove those from the Zotero
  desktop instead."
- `ZOT_LIBRARY_ID` is **not** exported in the agent environment; `ZOTERO_API_KEY` is. The library
  ID lives in `~/.config/zot/config.toml` and is printed by `zot config show` as `Library ID:
  <id>`. A direct Web-API POST therefore needs a library-ID resolution ladder.
- `specs/zotero-index.json` does **not** currently exist in this repository, though
  `zotero-write.sh` already reads it opportunistically for `zot_data_dir`. The quota cache must
  create it if absent and merge rather than overwrite.
- Directive-token consumers outside the script are `commands/literature.md` and
  `context/project/literature/patterns/zotero-item-creation.md`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided and no ROADMAP.md consultation was requested.

## Goals & Non-Goals

**Goals**:

- Web-discovered sources get translation-server-resolved metadata when an identifier is available,
  with graceful degradation to today's behavior when the service is unreachable (the default state).
- Which resolution path produced each record is surfaced honestly in the corpus index.
- Auto-attach becomes an explicit, quota-aware policy; the silent quota-exhaustion failure mode
  (413 leaving an orphaned, file-less attachment record behind) is closed.
- The zotero-mcp decision is recorded with reasons and reversal triggers.
- The Zotero 10 backend-swap plan is recorded against `zotero-write.sh` as the sole choke-point,
  naming what changes internally and what stays constant for callers.

**Non-Goals**:

- Implementing the Zotero 10 swap. Zotero 10 is beta; Work Item 4 is plan-only.
- Registering or granting permissions to any MCP server. Registration lives in `~/.dotfiles`
  regardless of the adopt/defer outcome.
- Editing `~/.dotfiles` or running `home-manager switch` to enable translation-server. That is a
  different repository and a system-level activation; it is proposed, never performed here.
- Editing the deployed `.claude/**` tree. All edits target `agent-system/extensions/literature/**`.
- Modifying `literature-ingest.sh`, `literature-convert.sh`, `literature-chunk.sh`, or
  `literature-build-index.sh` — the ingest bridge's existing NON-GOALS stand unchanged.
- Calling `POST /web`. It has no caller path from today's discovery-record shape and has never been
  tested; it is documented as an open gap, not wired.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `item-add-json` must POST the Web API directly, breaking `zotero-write.sh`'s pure `zot`-wrapper (Category A) posture and its stdout-passthrough contract | M | H (certain) | Normalize the Web API's `{successful, success, failed}` response into the same `{"ok":…,"data":{"key":…}}` envelope `zot` emits, so `extract_envelope_field '.data.key'` keeps working unchanged. Document the normalization as a named, single exception in the script header |
| translation-server output contains keys the Web API rejects (`attachments`, `notes`, `key`, `version`) causing a 400 | M | M | Normalize the body with `jq 'del(.attachments, .notes, .key, .version)'` before POST; on any non-2xx, surface the API's error body verbatim and fall back — never fabricate success |
| Splitting the atomic `item-add --pdf` into create-then-attach reintroduces a partial-success surface (item created, attach failed) | M | M | Reuse the existing honest-surfacing pattern rather than inventing one: a distinct directive token plus an `attachment_state` field; the quota pre-check runs before the attach half so the common failure never reaches the API |
| A new directive token changes a header block explicitly marked STABLE CONTRACT | M | M | Additive only; grep-confirm and update every consumer (`commands/literature.md`, `patterns/zotero-item-creation.md`) in the same phase; no existing token's spelling, meaning, or exit code changes |
| Reactive quota cache goes stale optimistically (operator frees space; cache still says over quota) | L | M | 24h staleness bound, after which one real attempt is allowed and re-caches on failure. Accepted, self-correcting |
| `zot orphans clean` cannot see Web-API-created orphans until a desktop sync | M | H (currently true) | Treat cleanup as best-effort and non-blocking; log the sync-lag caveat and the tool's own "remove those from the Zotero desktop instead" guidance rather than reporting a false success |
| translation-server is off by default, so the resolution path is unexercised in normal operation | M | H | The degradation path is the default path and is what the test matrix actually exercises; `/search`'s response shape is grounded in the provisioning task's real successful call, and the live enable/test cycle is a gated proposal (Phase 9) |
| A live end-to-end test writes to the production Zotero library and is quota-relevant | H | M | Gated in Phase 9 with an explicit decline path; nothing in Phases 1-8 performs a real write |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2, 4 | 1, 3 |
| 3 | 5 | 2, 4 |
| 4 | 6 | 5 |
| 5 | 7, 8 | 6 |
| 6 | 9 | 7, 8 |

Phases within the same wave can execute in parallel. Wave 1 and wave 2 pair one `zotero-write.sh`
phase with one `literature-ingest-online.sh` phase; the two files are disjoint territory, and
within each file the phases are strictly sequential.

---

### Phase 1: `zotero-write.sh` gains `item-add-json` [COMPLETED]

**Goal**: Give the single write choke-point a way to create a Zotero item from a fully-formed JSON
item body, which `zot add` cannot do at all.

**Tasks**:

- [x] Re-run `zot add --help` and confirm no JSON-body option exists (see Scope Hypothesis). *(completed)*
- [x] Add `item-add-json` to the KEY-exemption list alongside `item-add` and `-h/--help` (the block
      that currently reads `[[ "$OPERATION" != "item-add" ]]`), since this operation creates a key
      rather than consuming one. *(completed)*
- [x] Add `--record-json <json>` to the argument-parsing loop; when omitted, read the body from
      stdin. Reject an empty body with exit 1. *(completed)*
- [x] Implement a library-ID resolution ladder: `$ZOT_LIBRARY_ID` -> parse `Library ID:` from
      `zot config show` -> exit 2 with a message naming both sources. Do not hard-code an ID. *(completed)*
- [x] Normalize the body: accept either a bare item object or a translation-server array and take
      element 0; strip `attachments`, `notes`, `key`, and `version` via `jq del(...)`; wrap in a
      single-element array (the Web API's items endpoint takes an array). *(completed)*
- [x] POST to `https://api.zotero.org/users/<libraryID>/items` with headers `Zotero-API-Version: 3`,
      `Zotero-API-Key: $ZOTERO_API_KEY`, `Content-Type: application/json`, and — when
      `--idempotency-key` was supplied — `Zotero-Write-Token` set to a 32-char hex value derived
      from the supplied key (hash it; do not pass a non-conforming key through). *(completed)*
- [x] Normalize the response: on a 2xx whose `.successful` is non-empty, emit
      `{"ok":true,"data":{"key":"<KEY>","raw":<original response>}}` on stdout so existing callers'
      `.data.key` probe keeps working; on a non-2xx, or a 2xx with a non-empty `.failed`, emit
      `{"ok":false,"error":{…}}` carrying the API's own message verbatim and exit 1. *(completed)*
- [x] `--dry-run` prints the planned request line and the normalized body to stdout with the API key
      redacted and performs **no** network call (unlike the `zot`-delegating operations, which hand
      `--dry-run` to `zot`; note the difference in the header). *(completed)*
- [x] Update the script header comment block and `show_usage()` with the new operation, its options,
      the envelope-normalization exception, and the unchanged 0/1/2 exit-code table. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts that (a) `zot add` exposes no JSON-body option, (b)
`ZOT_LIBRARY_ID` is unset while `ZOTERO_API_KEY` is set, and (c) `zot config show` prints a line
matching `Library ID: <id>`. Confirm all three at implementation time by running `zot add --help`,
`printenv ZOT_LIBRARY_ID ZOTERO_API_KEY`, and `zot config show` before writing code. If (a) turns
out false, prefer wrapping the `zot` subcommand and reduce this phase to a thin wrapper.

**Files to modify**:

- `agent-system/extensions/literature/scripts/zotero-write.sh` - new `item-add-json` operation,
  `--record-json` parsing, KEY-exemption entry, library-ID ladder, response normalization, header
  and usage text.

**Verification**:

- `bash -n scripts/zotero-write.sh` passes.
- `zotero-write.sh item-add-json --record-json '{"itemType":"journalArticle","title":"x"}'
  --dry-run` prints the planned request and normalized body, makes no network call, and exits 0.
- `zotero-write.sh item-add-json --dry-run </dev/null` exits 1 with an empty-body message.
- Every pre-existing operation still parses correctly under `--dry-run`: `note-add`, `tag-add`,
  `tag-remove`, `attach-file`, and `item-add` each invoked with `--dry-run` and dummy arguments,
  confirming the KEY-exemption and argument-loop edits did not regress them.

---

### Phase 2: `zotero-write.sh` gains `orphan-clean` [COMPLETED]

**Goal**: Expose `zot orphans clean` through the choke-point so the ingest bridge can attempt
best-effort cleanup of file-less attachment records without any script calling `zot` directly.

**Tasks**:

- [x] Add `orphan-clean` to the KEY-exemption list (it takes no item key). *(completed)*
- [x] Implement it as a thin wrapper: `zot orphans clean --yes`, forwarding `--dry-run` and
      `--idempotency-key` when supplied. Pass `zot`'s stdout straight through, unchanged, exactly
      like the other wrapper operations. *(completed)*
- [x] Deliberately do **not** expose `--include-recoverable`. Document in the header that
      discarding the server-side copy is an operator action taken manually with `zot` directly. *(completed)*
- [x] Document in the header and `show_usage()`: dead-only default; records never synced to the
      server return `not_found` (the tool's own guidance is to remove those from the Zotero desktop);
      and `zot orphans list/clean` read local SQLite, so a Web-API-created orphan is invisible until
      a desktop sync. *(completed)*
- [x] Exit codes: 0 on success or a no-op clean, 1 on `zot` failure. Callers are expected to treat
      failure as non-fatal. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Asserts `zot orphans clean` accepts `--yes`, `--dry-run`, and
`--idempotency-key` and defaults to dead-only orphans. Confirm with `zot orphans clean --help`
before implementing; if the flag set differs, adjust the forwarded flags rather than the wrapper's
external contract.

**Files to modify**:

- `agent-system/extensions/literature/scripts/zotero-write.sh` - new `orphan-clean` operation,
  header and usage text.

**Verification**:

- `bash -n scripts/zotero-write.sh` passes.
- `zotero-write.sh orphan-clean --dry-run` runs and reports `zot`'s own dry-run output (expected
  today: zero orphans visible locally, which is the documented sync-lag condition, not a failure).
- Phase 1's operation-regression sweep re-run to confirm the second KEY-exemption edit did not
  regress the KEY-taking operations.

---

### Phase 3: translation-server resolution helper [NOT STARTED]

**Goal**: Add a self-contained metadata-resolution helper to the ingest bridge that mirrors the
existing `check_export_freshness()` idiom: one HTTP call, one classification, globals set, never
worse than a warning on failure.

**Tasks**:

- [ ] Add `resolve_via_translation_server()` to `literature-ingest-online.sh`, setting globals
      `TRANSLATION_SERVER_RESOLVED` (compact JSON or empty) and `RESOLUTION_PATH`.
- [ ] Endpoint and identifier selection: `DOI_RAW` present -> `POST /search` with the bare DOI;
      else `ARXIV_ID_RAW` present -> `POST /search` with `arXiv:<id>`; else no call at all.
- [ ] Do **not** call `POST /web` with `pdf_url`. `pdf_url` is a PDF, not a landing page, and the
      discovery record carries no landing-URL field. Record in a comment that `/web` has no caller
      path today and has never been exercised by anyone.
- [ ] Configuration: `TRANSLATION_SERVER_URL` (default `http://localhost:1969`); setting it to the
      empty string disables the call entirely with a single logged notice.
- [ ] Degradation: `curl -s --max-time 5 --fail`, capture stderr, and treat *any* non-zero exit or
      any response failing `jq -e '.[0]'` as "not resolved" — log a WARNING naming the fallback and
      return 1. Never a hard stop. The 5s timeout (versus 30s for PDF downloads) is deliberate for a
      local service; note it in the comment.
- [ ] Define the `RESOLUTION_PATH` vocabulary in the helper's comment block and set it consistently:
      `translation-server` (resolved), `zot-crossref` (no resolution, DOI present so `zot add --doi`
      does its own Crossref lookup), `zot-bare` (no resolution and no DOI — today's silent-worst
      case), `existing-item` (attach-to-existing path; metadata already in the library).
- [ ] Set `RESOLUTION_PATH=existing-item` on the `existing_no_pdf` branch so the field is always
      populated, never absent.

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Asserts that a Tier-3 discovery record exposes `doi`, `arxiv_id`, and
`pdf_url` but no landing-page URL. Confirm by re-reading `literature-discover.sh`'s `tier3_search()`
output construction before implementing; if a landing-URL field exists, add the `/web` branch and
label it UNVERIFIED rather than leaving it unwired.

**Files to modify**:

- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` - new
  `resolve_via_translation_server()` helper, `RESOLUTION_PATH` globals and vocabulary.

**Verification**:

- `bash -n scripts/literature-ingest-online.sh` passes.
- With the service off (the default state), the helper returns 1 promptly, logs the WARNING naming
  the fallback, and sets `RESOLUTION_PATH` to a non-empty value — confirmed by a `--dry-run` bridge
  invocation on a synthetic arXiv-only record.
- With `TRANSLATION_SERVER_URL=""`, no `curl` is attempted and the disabled notice is logged once.

---

### Phase 4: rework the resolvable branch to consume resolved metadata [NOT STARTED]

**Goal**: Make the create-item path actually use translation-server output, while leaving today's
`--pdf`/`--doi` path intact as the fallback.

**Tasks**:

- [ ] Insert `resolve_via_translation_server()` into the resolvable branch **after**
      `resolvable_predownload_checks` (dedup) and **before** `download_and_verify` — dedup stays
      first because it is cheap and a confirmed duplicate must hard-stop before any network fetch.
- [ ] When resolution succeeded: call `zotero-write.sh item-add-json` with the resolved body, then —
      subject to the Phase 5 quota gate, which lands after this phase and is wired in there — call
      `zotero-write.sh attach-file <key> <staged-pdf>` as a separate second call.
- [ ] When resolution failed or was skipped: leave today's single atomic
      `item-add --pdf [--doi]` call exactly as it is. This path must not change behavior at all.
- [ ] Handle the new partial-success surface on the resolved path: item created but attach failed.
      Reuse the existing honest-surfacing shape rather than inventing one — set an
      `ATTACHMENT_STATE` global (`attached` | `failed` | `skipped-quota`) and add a distinct
      directive token `ONLINE_INGEST_INGESTED_NO_ATTACHMENT` (exit 0) for a created-and-ingested
      item with no attachment. Do not conflate it with `ONLINE_INGEST_INGESTED`.
- [ ] Extend the STABLE CONTRACT header additively: document the new token and its exit code, change
      no existing token's spelling, meaning, or exit code.
- [ ] Grep-confirm and update every consumer of the token set (expected:
      `commands/literature.md` and `context/project/literature/patterns/zotero-item-creation.md`) in
      this same phase, so the contract and its consumers never diverge.
- [ ] Update the `--dry-run` preview lines to show which of the two create paths would be taken and
      the resolved-metadata source.

**Timing**: 1.5 hours

**Depends on**: 1, 3

**Verification Tier**: interface

**Scope Hypothesis**: Asserts the directive-token consumers outside the script are exactly
`commands/literature.md` and `patterns/zotero-item-creation.md`. Confirm at implementation time with
`grep -rl 'ONLINE_INGEST_' agent-system/extensions/literature/` and update whatever that returns —
the enumerated pair is a hypothesis, not a closed list.

**Files to modify**:

- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` - resolvable-branch
  control flow, new token, `ATTACHMENT_STATE`, header contract, dry-run preview.
- `agent-system/extensions/literature/commands/literature.md` - directive-token handling for the
  new token (outside the task's declared `file_scope` but inside the binding rule; noted, not
  silently expanded).
- `agent-system/extensions/literature/context/project/literature/patterns/zotero-item-creation.md` -
  token list synchronization only; the fuller pattern rewrite is Phase 7.

**Verification**:

- `bash -n scripts/literature-ingest-online.sh` passes.
- `--dry-run` on a synthetic arXiv-only record (no DOI) prints the fallback path today (service
  off), names `zot-bare` as the resolution path, and exits 0 with exactly one stdout token.
- `--dry-run` on a synthetic DOI-bearing record prints the `zot-crossref` fallback path.
- `grep -c 'ONLINE_INGEST_' ` over each consumer shows the new token present in all of them.
- No live Zotero write is performed in this phase.

---

### Phase 5: explicit, quota-aware auto-attach policy [NOT STARTED]

**Goal**: Replace "discover the ceiling by 413" with an explicit policy plus a reactive cache, so no
silent quota-exhaustion failure mode remains and no further orphaned attachment records are created.

**Tasks**:

- [ ] Add an explicit policy knob `ZOTERO_AUTO_ATTACH` with values `always` | `under-quota` | `never`
      (default `under-quota`). Log the effective policy once per run.
- [ ] Implement `read_quota_state()` / `record_quota_state()` against
      `<repo>/specs/zotero-index.json` under a new top-level `quota_state` key
      (`{used_mb, limit_mb, checked_at, source}` where `source` is `413-observed` or
      `operator-configured`). Create the file with `{}` if absent and **merge** — never overwrite an
      existing `zot_data_dir` key. Mirror `upsert_subindex()`'s create-if-absent idiom.
- [ ] Pre-attach gate: under policy `under-quota`, if a non-stale cached state says
      `used_mb >= limit_mb`, skip the attach attempt entirely, set
      `ATTACHMENT_STATE=skipped-quota`, and surface it honestly (stderr line plus the
      `ONLINE_INGEST_INGESTED_NO_ATTACHMENT` token). A skipped attempt never reaches Zotero's
      create-child-record-then-upload two-step, which is precisely what prevents a new orphan.
- [ ] Reactive capture: when an attach **is** attempted and fails, parse the error body's
      `.error.message` for the `<used> > <limit>` MB pair (confirmed shape: `File would exceed quota
      (2745.6 > 300)`) and persist it with `source: 413-observed`. If the message does not match,
      record nothing and log that the failure was not quota-attributable — never guess.
- [ ] Operator override: `ZOTERO_ASSUMED_QUOTA_MB` (or a `quota_limit_mb` field alongside
      `quota_state`) sets `source: operator-configured`. Every log line consulting it must say
      "assumed, not API-verified" so it is never confused with an observed value.
- [ ] Staleness: cached state older than 24h is treated as unknown, permitting exactly one real
      attempt which re-caches on failure. Make the window a named constant.
- [ ] After a real quota failure, call `zotero-write.sh orphan-clean` best-effort and non-blocking:
      log its outcome, log that it may legitimately be a no-op because the just-created orphan has
      not synced to local SQLite yet, and never let its failure change the run's directive token.
- [ ] Document in the header that a preflight quota check is structurally impossible (no Web API
      endpoint exists), so the gate is reactive and/or operator-configured by necessity, not by
      preference.

**Timing**: 1.5 hours

**Depends on**: 2, 4

**Verification Tier**: local

**Scope Hypothesis**: Asserts `specs/zotero-index.json` does not currently exist and that
`zotero-write.sh` reads `.zot_data_dir` from it when it does. Confirm with `ls specs/zotero-index.json`
and by re-reading `zotero-write.sh`'s `ZOT_DATA_DIR` resolution block before writing the merge
logic; if the file exists with other keys, the merge must preserve all of them.

**Files to modify**:

- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` - policy knob, quota
  cache read/write, pre-attach gate, 413 parsing, best-effort orphan-clean call, header docs.

**Verification**:

- `bash -n scripts/literature-ingest-online.sh` passes.
- Seed a synthetic over-quota `quota_state` with a fresh `checked_at`; a `--dry-run` resolvable
  record reports the attach as skipped with the quota reason and the
  `ONLINE_INGEST_INGESTED_NO_ATTACHMENT` token.
- Backdate `checked_at` past 24h; the same invocation reports the state as stale and plans one real
  attempt.
- Set `ZOTERO_AUTO_ATTACH=never`; the attach is skipped regardless of cache state and the log names
  the policy, not the quota.
- Set `ZOTERO_AUTO_ATTACH=always` with an over-quota cache; the attach is planned and the log warns
  that the policy overrides a known-over-quota state.
- Feed the confirmed 413 message string to the parser in isolation and confirm it yields
  `used_mb=2745.6`, `limit_mb=300`; feed a non-matching message and confirm nothing is recorded.
- A pre-existing `specs/zotero-index.json` containing `zot_data_dir` still contains it after a
  `quota_state` write.

---

### Phase 6: resolution-path surfacing in the corpus index [NOT STARTED]

**Goal**: Make it possible for a future reader of the corpus index to tell which records got
translation-server-quality metadata and which fell back — the "honest surfacing" acceptance
criterion.

**Tasks**:

- [ ] Extend `patch_global_index()` with `resolution_path` and `attachment_state` parameters and
      write both onto the `index.json` entry alongside the existing `zotero_key`/`zotero_path`.
- [ ] Pass `RESOLUTION_PATH` and `ATTACHMENT_STATE` from both the resolvable and the
      `existing_no_pdf` branches so neither field is ever absent or empty.
- [ ] Extend `upsert_subindex()`'s per-entry record with the same `resolution_path` value so the
      per-repo sub-index does not silently lose the provenance the global index now carries.
- [ ] Document both fields — value vocabulary and meaning — in the script's header block.

**Timing**: 0.75 hours

**Depends on**: 5

**Verification Tier**: local

**Files to modify**:

- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` -
  `patch_global_index()`, `upsert_subindex()`, both call sites, header docs.

**Verification**:

- `bash -n scripts/literature-ingest-online.sh` passes.
- Run `patch_global_index` against a temporary copy of an `index.json` fixture and confirm the entry
  gains `resolution_path` and `attachment_state` and that re-running is idempotent (updates in
  place, never duplicates).
- Confirm the `existing_no_pdf` branch writes `resolution_path: existing-item` rather than an empty
  string.

---

### Phase 7: pattern, inventory, and README documentation [NOT STARTED]

**Goal**: Bring the extension's how-it-works docs in line with the two new write operations and the
new surfacing fields.

**Tasks**:

- [ ] `patterns/zotero-item-creation.md`: add a section for `item-add-json` covering the capability
      gap it closes, the envelope-normalization exception, the create-then-attach decomposition and
      its partial-success surface, and the `resolution_path`/`attachment_state` vocabulary. Extend
      the existing envelope-field-confirmation discipline (section 2) to the new operation, marking
      the normalized envelope CONFIRMED-BY-CONSTRUCTION and the live Web-API response shape
      UNCONFIRMED until Phase 9's gated test runs or is declined.
- [ ] `patterns/zotero-item-creation.md`: add a short subsection on `orphan-clean`, including the
      dead-only default, the deliberate absence of `--include-recoverable`, and the local-sync-lag
      caveat that limits when it can act.
- [ ] `tools/zotero-scripts.md`: update the `zotero-write.sh` row to name `item-add-json` and
      `orphan-clean`; note `zot`'s `delete`/`orphans`/`trash` family, absent from every context file
      today.
- [ ] `README.md`: update the `zotero-write.sh` row in "Available Scripts" to match, and confirm the
      Deployment Status section still reads correctly (deployment itself is an operator step; do not
      hand-copy anything into `.claude/`).
- [ ] Keep every task-number reference out of these files — cite filenames and section headings.

**Timing**: 1 hour

**Depends on**: 6

**Verification Tier**: prose

**Files to modify**:

- `agent-system/extensions/literature/context/project/literature/patterns/zotero-item-creation.md`
- `agent-system/extensions/literature/context/project/literature/tools/zotero-scripts.md`
- `agent-system/extensions/literature/README.md`

**Verification**:

- Diff read-through confirming every hunk is prose.
- `bash .claude/scripts/check-extension-docs.sh` exits 0 (or reports only pre-existing findings).
- `grep -nE 'task [0-9]+|tasks [0-9]+' ` over the three files returns nothing new.

---

### Phase 8: decisions of record in `zotero-integration.md` [NOT STARTED]

**Goal**: Record the two decisions the task asks for as durable, reasoned entries in the domain doc.

**Tasks**:

- [ ] Add a "Zotero MCP: adoption decision" section recording **defer**, with the reasons: the
      candidate's write value-add duplicates this extension's own discovery/ingest cascade and would
      bypass its dedup guard and index patching; its unique value (semantic search) is read-side
      only; the one owned write surface is not yet hardened; Zotero 10's native local writes may
      obsolete the hybrid-mode proposition. State the verified absence (`zotero-mcp` is not installed
      and not registered), state the two reversal triggers (Zotero 10 stabilizes and the swap plan
      executes; or a genuine read-side semantic-search need arises), and state that registration and
      grants would land in the user's `~/.dotfiles` Claude configuration under the
      grant-at-registration-scope principle — never hand-edited here.
- [ ] Add a "Backend Swap Plan (Zotero 10)" section naming `zotero-write.sh` as the sole
      choke-point. Specify what changes **internally**: a backend-selection step after the existing
      `zot`-installed and API-key checks, detecting `localhost:23119/api/` reachability plus a
      consent-obtained local API key, routing the write operations through local-API calls when
      both hold and falling back to today's path otherwise; and full-file PUT uploads that do not
      count against the storage quota. Specify what stays **constant for callers**: operation names,
      argument shapes, the 0/1/2 exit-code table, `--dry-run`/`--idempotency-key` semantics, and the
      stdout-envelope contract (including `item-add-json`'s normalization, which the local-API path
      must also produce).
- [ ] Record the explicit rejection of `/connector/saveItems` as a write contract, with reasons:
      undocumented internal protocol, writes into whatever collection is selected in the UI (a
      caller-uncontrollable side channel), and historical drift between versions.
- [ ] State plainly that the swap is **not implemented** — Zotero 10 is beta, and the local-API
      response field names are unconfirmed, which is why the defensive multi-candidate envelope
      lookup extends naturally rather than being rewritten.
- [ ] Add the explicit auto-attach policy statement (`ZOTERO_AUTO_ATTACH` values, the reactive
      cache, the operator override, the 24h staleness bound) and note that the quota gate becomes
      inert — not removed — once a local-API backend is active.
- [ ] Add a one-line mention of `zot duplicates --by doi|title|both` in the "Related" area as an
      operator-facing whole-library dedup sweep, explicitly distinct from the ingest bridge's own
      pre-write check, with the same local-SQLite sync-lag caveat.

**Timing**: 1 hour

**Depends on**: 6

**Verification Tier**: prose

**Files to modify**:

- `agent-system/extensions/literature/context/project/literature/domain/zotero-integration.md`

**Verification**:

- Diff read-through confirming every hunk is prose.
- The file names `zotero-write.sh` as the choke-point, lists what stays constant for callers,
  records the `/connector/saveItems` rejection, and records the MCP defer decision with reasons and
  reversal triggers — checked by reading, since these are the literal acceptance criteria.
- No task-number references.

---

### Phase 9: static verification and gated live-verification proposals [NOT STARTED]

**Goal**: Run everything that can be verified without touching production or another repository,
then put each genuinely gated action to the operator with a stated decline path.

**Tasks**:

- [ ] Run the full static gate set: `bash -n` on both modified scripts, `jq empty` on any JSON
      fixture touched, `bash .claude/scripts/check-extension-docs.sh`, and the repo-wide
      task-reference lint.
- [ ] Re-run the complete `--dry-run` matrix from Phases 1-6 end to end in one pass, confirming
      every `zotero-write.sh` operation still parses and the bridge produces exactly one stdout
      token per invocation.
- [ ] Confirm no file under `.claude/**` was modified (`git status --short .claude/` empty) and note
      that redeploying the extension is an operator step via the normal deploy flow, never a manual
      copy.
- [ ] **Gate A — translation-server live enable/test.** Propose a short, explicitly authorized
      enable/test/revert cycle in `~/.dotfiles` (`services.zoteroTranslationServer.enable = true`,
      `home-manager switch`, exercise `POST /search` and — the real open gap — `POST /web`, then
      revert). Do not edit that repository or flip the toggle unilaterally. **Decline path**: ship
      the degradation path as the tested default (it is the default state), record `/search`'s
      response shape as verified by the provisioning work's own successful real call, and record
      `/web` as UNVERIFIED and unwired in `zotero-item-creation.md`.
- [ ] **Gate B — live end-to-end ingest against the production library.** Propose one real run
      creating one item via `item-add-json` on a record chosen by the operator. **Decline path**:
      leave the live Web-API response field names marked UNCONFIRMED under the existing
      envelope-confirmation discipline, keep the defensive multi-candidate lookup, and state
      plainly in the summary that only `--dry-run` coverage exists.
- [ ] **Gate C — orphan cleanup of the two known file-less attachment records.** Propose running
      `zotero-write.sh orphan-clean --dry-run` first, then the real clean. Note that it is expected
      to be a no-op today because those records have not synced to local SQLite. **Decline path**:
      record the two orphan keys and `zot orphans clean`'s own guidance (remove them from the Zotero
      desktop instead) in `zotero-item-creation.md`, and leave the wrapper in place for when a sync
      has happened.
- [ ] Record, in the implementation summary, which gates were exercised and which were declined —
      a declined gate is a stated outcome, never an omission.

**Timing**: 1 hour

**Depends on**: 7, 8

**Verification Tier**: full

**Scope Hypothesis**: Asserts three gated actions and no more. Confirm at implementation time that
no other step in Phases 1-8 performed a real production write or a cross-repo edit; if one did, it
was a plan violation and must be reported rather than absorbed.

**Files to modify**:

- `agent-system/extensions/literature/context/project/literature/patterns/zotero-item-creation.md` -
  only if a gate is declined and its decline-path record must be written.

**Verification**:

- All static gates pass.
- `git status --short .claude/` is empty.
- Every gate is recorded as exercised-with-outcome or declined-with-recorded-consequence.

---

## Testing & Validation

- [ ] `bash -n` passes on `zotero-write.sh` and `literature-ingest-online.sh`.
- [ ] Every pre-existing `zotero-write.sh` operation (`note-add`, `tag-add`, `tag-remove`,
      `attach-file`, `item-add`) still parses and previews correctly under `--dry-run` after the
      argument-parsing and KEY-exemption edits.
- [ ] `item-add-json --dry-run` prints a redacted request plus a normalized body and makes no
      network call; an empty body exits 1; a missing library ID exits 2.
- [ ] `orphan-clean --dry-run` runs and passes `zot`'s output through unchanged.
- [ ] Bridge `--dry-run` matrix: arXiv-only record, DOI-bearing record, `in_zotero_no_pdf` record —
      each produces exactly one stdout directive token and a populated `resolution_path`.
- [ ] Quota matrix: fresh over-quota cache (attach skipped), stale cache (one attempt allowed),
      `ZOTERO_AUTO_ATTACH=never` (skipped by policy), `ZOTERO_AUTO_ATTACH=always` (attempted with a
      warning), non-matching error message (nothing recorded).
- [ ] `quota_state` write preserves a pre-existing `zot_data_dir` key.
- [ ] `patch_global_index` remains idempotent with the two new fields.
- [ ] `check-extension-docs.sh` exits 0, or reports only findings that pre-date this work.
- [ ] Task-reference lint reports no new occurrences outside `specs/**`.
- [ ] `git status --short .claude/` is empty at completion.

## Artifacts & Outputs

- `agent-system/extensions/literature/scripts/zotero-write.sh` - `item-add-json` and `orphan-clean`
  operations.
- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` - translation-server
  resolution, reworked resolvable branch, quota-aware auto-attach policy, resolution-path surfacing.
- `agent-system/extensions/literature/commands/literature.md` - new directive token handled.
- `agent-system/extensions/literature/context/project/literature/patterns/zotero-item-creation.md` -
  `item-add-json`, `orphan-clean`, surfacing fields, gate outcomes.
- `agent-system/extensions/literature/context/project/literature/domain/zotero-integration.md` - MCP
  defer decision, Zotero 10 backend-swap plan, auto-attach policy, `zot duplicates` note.
- `agent-system/extensions/literature/context/project/literature/tools/zotero-scripts.md` - updated
  inventory.
- `agent-system/extensions/literature/README.md` - updated script table.
- `specs/039_zotero_metadata_resolution_upgrade/summaries/02_zotero-metadata-resolution-summary.md`

## Rollback/Contingency

- Every phase is a commit-per-green-substep unit scoped to `agent-system/extensions/literature/**`;
  reverting a phase is `git revert` of its commit. No deploy step is performed, so the live
  `.claude/**` tree is unaffected until an operator redeploys.
- The two new `zotero-write.sh` operations are purely additive; if `item-add-json` proves unworkable
  against the live API, the resolvable branch's fallback (today's atomic `item-add --pdf [--doi]`)
  is still present and unchanged, so reverting Phase 4 alone restores current behavior while keeping
  the quota gate and surfacing work.
- The quota cache lives in `specs/zotero-index.json`; deleting the `quota_state` key restores
  attempt-then-fail behavior without touching code.
- If Phase 4's new directive token turns out to break a consumer that the grep did not surface,
  revert Phase 4 and re-land it with `ONLINE_INGEST_INGESTED` plus the `attachment_state` index
  field carrying the distinction instead — a documented, lower-churn fallback.
