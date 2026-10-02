# Zotero Item Creation Pattern

How the online-discovery -> Zotero+PDF -> ingest bridge (`literature-ingest-online.sh`) creates a
brand-new Zotero item with an attached PDF, re-points at the durable storage copy, and hands off
to the unmodified `literature-ingest.sh` pipeline. Companion to `zotero-pdf-resolution.md`, which
covers resolving an *existing* doc_id to its Zotero PDF; this document covers the complementary
*create-item* direction.

## 1. The capability is `zot add --pdf`, wrapped by `zotero-write.sh item-add`

Every other `zotero-write.sh` operation (`note-add`, `tag-add`, `tag-remove`, `attach-file`)
mutates an item that already exists — each takes a mandatory `KEY` argument. `item-add` is the one
operation that does **not**: it creates a brand-new bibliographic item (optionally with a PDF
attachment) via a single atomic `zot add --pdf <path>` call, which the `zotero-cli-cc` (`zot`)
CLI documents as: "extracts DOI from the PDF, creates the item, and attaches the file." A
companion `--doi <doi>` flag may be passed alongside `--pdf` (forwarded to `zot` to
corroborate/skip its own DOI-from-PDF extraction), or used alone as an item-only fallback with
**no** attachment — callers must treat that fallback as "no PDF attached" and surface it honestly,
never as a full success.

The local HTTP API at `127.0.0.1:23119` is confirmed read-only (every endpoint is a GET); it
cannot create items. All writes — including `item-add` — go through the Web API via `zot`, using
the same `$ZOTERO_API_KEY` dependency `zotero-write.sh` already requires for its other operations.

`zot add --help` documents that a `--doi`-driven create fetches metadata (title, authors,
journal, year, ...) from Crossref before posting, but a `--pdf`-only create does **not**: its
help text states plainly that metadata is "not auto-resolved by API" for the PDF path. A
`--pdf`-only create does not merely yield a barer item, however — it can **hard-fail outright**.
`zotero-cli-cc` v0.10.0's `commands/add.py::_add_from_pdf` calls `extract_doi()`, which regexes
`10\.\d{4,9}/\S+` over only the PDF's first two pages; when that finds nothing, `_add_from_pdf`
calls `emit_error("validation_error", "No DOI found in PDF")` and exits with `SystemExit(3)`
**before ever calling `writer.add_item`** — no item is created at all, not even a bare one. This
is the actual failure this bridge originally hit on arXiv-only `open_access` records (no `doi`
field, only an `arxiv_id`), not the milder "barer item" outcome this section previously claimed.

**Implemented mitigation**: `literature-ingest-online.sh` derives `10.48550/arXiv.<arxiv_id>` (the
arXiv DataCite DOI, which arXiv's own metadata always exposes) and passes it as `--doi` for any
`open_access`/`arxiv_id`-only record with no real `doi`, bypassing `_add_from_pdf`'s PDF-text
regex entirely so the item gets created. Honest caveat: this DataCite DOI is **not** a
Crossref-registered, published-venue DOI, and Crossref will not resolve it — the created Zotero
item therefore ends up metadata-bare (DOI field populated, but no Crossref-enriched
title/author/journal/date) exactly like a `--pdf`-only create would otherwise be. This is treated
as an accepted tradeoff, not a defect: an existing, metadata-bare Zotero item is strictly better
than the pre-mitigation outcome of no item at all. The corpus-side `index.json` entry is
unaffected — it is patched from the discovery record's own title/authors/year, never from this
synthesized DOI.

Whenever a discovery record carries a known DOI, pass `--doi` together with `--pdf` so the
created item gets Crossref-enriched metadata rather than the bare PDF-derived shell.

## 2. The `zot add --pdf` envelope's `data.*` field names: confirmed for item creation, still open for attachment success

A live call was made against the production library (904-item account, user-gated, single
authorized `item-add` + `attach-file` pair; item key `QWF66MNX`, DOI
`10.26686/ajl.v22i2.5680`). This confirms the item-creation field paths and narrows, but does not
close, the attachment-key question below.

**Confirmed item-key path**: `.data.key` resolves and is the correct item key
(`"QWF66MNX"` in the live call). The other two candidates named in the original mitigation,
`.data.item.key` and `.data.itemKey`, are **not present** in the real envelope — remove them as
live candidates for the item-key lookup specifically (see the probing-retention decision below
for why the helper still keeps multi-path probing overall).

**Confirmed sibling fields on a successful `item-add` with `--doi`**: `.data.doi` (echoes the
posted DOI), `.data.resolved.{title,author,journal,date}` (Crossref-enriched metadata — populated
because `--doi` accompanied `--pdf`; a `--pdf`-only call would not populate this per section 1),
`.data.sync_required` (boolean, `true` in the live call — see the sync-lag caveat below),
`.data.next` (an array of one or more suggested follow-up shell commands, e.g. a manual
`zot attach <key> --file <path>` retry — present specifically because the internal attach step
below failed), and, only on that failure, `.data.attachment_error` (a string containing the raw
Zotero API error).

**Sync-lag caveat, confirmed empirically**: `zot`'s read commands (`search`, `read`, `stats` —
everything `zotero-read.sh` wraps) query the **local SQLite database only**, never the Web API
live state. Immediately after the live `item-add` call above, `zot read QWF66MNX` and
`zot search` for its DOI both returned "not found" / no hits, and `zot stats` still reported the
pre-creation item count — because no Zotero desktop client was running to sync the new item down
(`.data.sync_required: true` documents exactly this gap). Practically: a duplicate created via the
Web API is invisible to Phase 4's `check_live_doi_duplicate()` dedup check until a desktop client
syncs it down, so "live" there means "last-locally-synced", not "current server state" — worth
knowing, though no code change is in scope for this phase.

**Attachment-key path: still unconfirmed, for a concrete and reproducible reason.** Both real
attach attempts in this session — `item-add`'s internal attach step, and the standalone
`attach-file` call that followed it — failed identically with a Zotero API `413` error:
`"File would exceed quota (2745.6 > 300)"` (megabytes; this account's storage quota is already far
exceeded by existing content, independent of this test's 1.5 MB PDF). Neither call reached a
successful attachment envelope, so none of the four candidate attachment-key paths
(`.data.attachment.key`, `.data.attachmentKey`, `.data.attachment_key`,
`.data.attachments[0].key`) could be ruled in or out. On this failure the envelope carries **no**
`.data.*` at all — it is `{"ok": false, "error": {"code", "message", "retryable", "hint",
"context"}}`. The bridge/local route (`zot attach --via-bridge`) was not a viable alternative
either: Zotero desktop was confirmed unreachable at test time (no listener on
`127.0.0.1:23119`), and `zot attach`'s default auto-detect route itself confirmed
`via_bridge: false` (dry-run preview) before the real, also-quota-rejected call.

**A second, more consequential finding from the same failure**: both quota-rejected attach
attempts left an **orphaned attachment item record** as a child of the parent item — confirmed via
a direct, read-only Web-API `GET .../items/QWF66MNX/children` call (not a write; performed purely
to gather this evidence). Zotero's attach flow creates the child attachment item's metadata record
(`itemType: attachment`, `linkMode: imported_file`, `filename`, `contentType`) in a separate call
*before* uploading file bytes; when the upload itself is rejected by quota, that empty record
(`md5: null`, `mtime: null` — no file ever attached) persists rather than being rolled back. This
live call therefore produced one parent item (`QWF66MNX`) plus two orphaned, file-less
attachment-record children (`5J2WMXDD` from the internal attach, `CB99228V` from the standalone
`attach-file` call). All three are children/parent of the same rollback unit — see the
implementation summary for the rollback instruction.

**Mitigation applied** (unchanged in mechanism, strengthened by the finding above):
`literature-ingest-online.sh`'s `extract_envelope_field()` and `resolve_storage_path_from_envelope()`
helpers probe several plausible jq field paths in order rather than assuming one shape. If none
resolve, the script does not fail hard — it falls back to the original staging download path for
`source_path`/`zotero_path`, logs a visible (non-silent) warning, and continues. `zotero-write.sh`
itself does not parse the envelope at all; like every other operation, it passes `zot`'s stdout
straight through unmodified, so the parsing responsibility (and the defensive multi-path lookup)
lives entirely in the caller.

**Probing-retention decision: keep the multi-path probing (plan's recommended default), now for a
stronger reason than "costs nothing."** The live test confirmed the item-key path
(`.data.key`) and eliminated two dead candidates for it, but produced **zero** successful
attachment envelopes to confirm or eliminate any attachment-key candidate — the account's storage
quota blocks the only reachable route (Web API/cloud; the bridge route requires a running desktop
client, unavailable in this environment) regardless of file size. Simplifying
`resolve_storage_path_from_envelope()`'s attachment-key lookup to a single guessed path now, with
literally no positive evidence for any candidate, would be strictly worse than keeping the
existing defensive probe. **Required follow-up, unchanged in substance**: the attachment-key
confirmation remains open until either the account's storage quota is resolved (paid tier, or
freed space) or a `--via-bridge` run against a running Zotero desktop is performed — at that
point, repeat this same live-call procedure and update this section.

## 3. The mandatory `%PDF` magic-byte gate runs before ANY Zotero write

`pdf_url` values sourced from Semantic Scholar / OpenAlex / Crossref (via Unpaywall) / Unpaywall /
arXiv can resolve to a cookie-wall or
landing-page HTML document served with a 200 status rather than actual PDF bytes. Silently
creating a Zotero item and attachment from such a file would fabricate a download the honest-
surfacing invariant explicitly prohibits.

```bash
curl -sL --fail --max-time 30 -o "$dest" "$url"
magic="$(head -c4 "$dest")"
if [ "$magic" != "%PDF" ]; then
  # ONLINE_INGEST_DOWNLOAD_FAILED -- never fall through to item creation
fi
```

This check runs immediately after every download, in both the create-item path (Phase 3/4) and
the attach-to-existing path (Phase 6, where the PDF URL itself first has to be discovered via an
Unpaywall DOI lookup against the resolved item's DOI, since Tier-2 `in_zotero_no_pdf` discovery
records carry no `pdf_url` of their own). Any curl failure or magic-byte mismatch is a full stop
— no Zotero write of any kind is attempted afterward.

## 4. Storage re-pointing reuses the derived-storage-root rule from `zotero-pdf-resolution.md`

Once an item (and, ideally, its attachment) exists, Zotero copies the uploaded file into its own
managed `storage/<attachmentKey>/<filename>` tree. The bridge re-points the file it hands to
`literature-ingest.sh` at that durable copy — not the ephemeral staging download — so
`source_path`/`zotero_path` in the resulting `index.json` entry reference a permanent location.
The storage root itself is **always derived**, never hardcoded, exactly as `zotero-resolve-pdf.sh`
already does:

```bash
ZOTERO_SQLITE="$(bash zotero-resolve-sqlite-path.sh)"
ZOTERO_DATA_DIR="$(dirname "$ZOTERO_SQLITE")"
ZOTERO_STORAGE_ROOT="$ZOTERO_DATA_DIR/storage"
```

If the resolved storage path does not exist (unconfirmed field names above, or the copy has not
landed yet), the bridge falls back to the original staging path and logs this honestly as a
follow-up rather than claiming a false success.

`zot attach` exposes `--via-bridge`/`--no-via-bridge` (default: auto-detect — bridge when the
Zotero desktop is reachable, else the Web API); `zotero-write.sh` passes neither, so it always
takes the auto-detected route. When the Zotero desktop is not running, `zot attach` auto-detects
the Web-API/cloud route: the file is stored in zotero.org cloud storage and does **not** appear
in the local `storage/<key>/` tree until the desktop is running and syncs it down (requires
"Sync attachment files" enabled). On a headless ingest host — where the desktop is routinely not
running — hitting the staging-path fallback above is therefore the **expected common case**, not
a rare failure mode.

**Live-confirmed outcome (a user-gated, single-item production test)**: the auto-detected route
confirmed `via_bridge: false` (Zotero desktop unreachable at test time), so
both the internal attach inside `item-add` and the standalone `attach-file` call took the
Web-API/cloud route as predicted. The file landed in **neither** cloud storage nor local
`storage/<key>/` — the upload was rejected with a `413` storage-quota error before any bytes
transferred (`"File would exceed quota (2745.6 > 300)"`, i.e. this account's existing usage
already far exceeds its 300 MB quota, independent of this test's file size). See section 2 above
for the full envelope evidence and the resulting orphaned-attachment-record finding. The bridge
route was not available to test as an alternative: Zotero desktop was confirmed unreachable for
the whole exercise, so no route in this environment currently reaches a successful file upload.

## 5. `in_zotero_no_pdf` is an attach-to-existing problem, not a create-item problem

A Tier-2 discovery record with `status == "in_zotero_no_pdf"` refers to an item that **already
exists** in Zotero but lacks a PDF attachment. This case reuses `zotero-write.sh attach-file`
(pre-existing capability) against the *resolved* real Zotero item key — never `item-add`. The
citation_key a Tier-2 record carries is not guaranteed to be the literal 8-character Zotero API
key (see `zotero-pdf-resolution.md` finding #5), so the real key must be resolved via
`zotero-resolve-pdf.sh`'s existing title/author search logic (piped a synthesized
`{doc_id, record}` object over stdin) before any attach call — never assumed or invented. A
`tier == "absent"` result from that resolver is a full, honest stop; the bridge never fabricates a
key.

A corrective edge case worth knowing: if the resolver's `resolved_path` field is non-empty despite
the record's own `in_zotero_no_pdf` classification, the underlying Zotero item actually already has
a PDF attached (the classification came from a stale `zotero-library.json` CSL-JSON snapshot — see
`zotero-pdf-resolution.md` finding #4 on staleness). The bridge detects this and skips the
attach-file call entirely, using the already-existing PDF directly.

## 6. Verification scope limitation on this development machine

A real, already-configured Zotero instance was found running and bound to `127.0.0.1:23119` on the
machine this bridge was developed and tested on (discovered via a failed attempt to bind a mock
server to that port for testing purposes). To avoid any risk of touching a real user's Zotero
library, live-API mocking was abandoned mid-testing. What was verified instead: the honest
`tier == "absent"` stop path (a safe, read-only real-API call with a fabricated, guaranteed-
non-matching title), full end-to-end exercise of the create-item path using a stub `zot`
executable (rather than a real write call against the production library), and code-level
reuse confirmation that the attach-to-existing path shares every downstream helper
(`download_and_verify`, `resolve_storage_path_from_envelope`, the `literature-ingest.sh` delegate,
the metadata patch, and the sub-index upsert) with the already-fully-tested create-item path.

**`--dry-run` cannot exercise or reproduce this section's failure**: `zot add --dry-run` returns a
static preview and never calls `_add_from_pdf`, so it cannot reach `extract_doi()` or its
`SystemExit(3)` hard-fail — the arXiv-DOI mitigation above (and the "No DOI found in PDF" failure
it works around) can only be exercised by a real `zot add --pdf` call, or by a forced-failure/stub
`zot` executable placed first on `PATH` that reproduces the real CLI's exit code and stderr text
for the `add --pdf` (no `--doi`) case.

## 7. `item-add-json`: closing the JSON-body capability gap, and the create-then-attach decomposition

Section 1 established that `zot add` has no path for passing a fully-formed metadata body at
all — its complete option set is `--doi`, `--url`, `--from-file`, `--pdf`, `--dry-run`,
`--idempotency-key`, `--no-resolve` (reconfirmed live via `zot add --help` at implementation
time). When a discovery record already carries a resolved identifier (a DOI, or an arXiv ID),
relying on `zot add --pdf`'s own best-effort PDF-text DOI extraction throws away metadata the
bridge already has. `zotero-write.sh item-add-json` closes this gap by POSTing the Zotero Web
API's items endpoint directly — the ONE exception to `zotero-write.sh`'s otherwise pure
`zot`-wrapper (Category A) posture (see `zotero-write.sh`'s own header comment for the full
rationale and the wrapper-contract vocabulary this falls under).

**Envelope-normalization exception**: the Web API's native batch-create response shape is
`{successful, success, failed}` (keyed by positional index), not the `{"ok":…,"data":{"key":…}}`
shape every other operation's caller already expects (via `extract_envelope_field`). `item-add-json`
normalizes the native response into that same shape on success —
`{"ok":true,"data":{"key":"<KEY>","raw":<original response>}}` — so `extract_envelope_field
'.data.key'` keeps working unchanged for this operation too. Extending the envelope-confirmation
discipline from Section 2 above: the **normalized shell** (`.ok`/`.data.key`/`.data.raw`) is
CONFIRMED-BY-CONSTRUCTION — `zotero-write.sh` builds it itself, so there is no field-name
ambiguity on that side. What remains UNCONFIRMED is the Web API's own native response shape under
a real authorized call (field names inside `.data.raw`, and whether `.successful`/`.failed` key
on string indices or something else in practice) — that confirmation is gated behind a live,
operator-authorized end-to-end write test against the production library, exercised or
explicitly declined (see the implementation summary for this gate's outcome).

**Create-then-attach decomposition and its partial-success surface**: unlike the atomic
`item-add --pdf` call (one `zot` invocation does create+attach together), the resolved path is
necessarily two separate calls — `item-add-json` (create, no attachment) then `attach-file`
(attach). This reintroduces the partial-success surface item-add avoided: the item can be created
successfully while the attach fails (or is skipped — see the quota policy below). The bridge
surfaces this honestly via an `ATTACHMENT_STATE` global (`attached` | `failed` | `skipped-quota`)
and a distinct directive token, `ONLINE_INGEST_INGESTED_NO_ATTACHMENT` (exit 0) — the item exists
and corpus ingest still proceeds from the local staging PDF, but the caller is told the Zotero
side has no attachment, never silently conflated with the full-success
`ONLINE_INGEST_INGESTED` token.

**`resolution_path` / `attachment_state` vocabulary** (written onto every ingested `index.json`
and `literature-index.json` entry, never absent):
- `resolution_path`: `translation-server` (resolved via `/search`) | `zot-crossref` (no
  resolution, but a real DOI let `zot add --doi` do its own Crossref lookup on the fallback path)
  | `zot-bare` (no resolution and no DOI) | `existing-item` (attach-to-existing path; metadata
  already lived in the Zotero item).
- `attachment_state`: `attached` | `failed` | `skipped-quota`.

**Quota-aware auto-attach policy**: an attach attempt is gated by `ZOTERO_AUTO_ATTACH`
(`always` | `under-quota` default | `never`) against a reactive cache in
`specs/zotero-index.json`'s `quota_state` key (`{used_mb, limit_mb, checked_at, source}`). A
preflight quota check is structurally impossible — no Web API endpoint exposes current usage,
only a 413 response body ever reveals it (the confirmed shape: `"File would exceed quota (2745.6
> 300)"`) — so the cache is necessarily reactive (seeded by a real 413) and/or operator-configured
(`ZOTERO_ASSUMED_QUOTA_MB`, always logged as "assumed, not API-verified"). A cached state older
than 24h is treated as unknown, permitting one real attempt. Under `under-quota`, a fresh
over-quota cache skips the attach entirely — never reaching Zotero's create-child-record-then-
upload two-step — which is precisely what prevents a new orphan (see Section 2's finding on
orphaned attachment records). On a real quota-attributable failure, the bridge calls
`zotero-write.sh orphan-clean` best-effort and non-blocking (see Section 8 below).

## 8. `orphan-clean`: best-effort cleanup of file-less attachment records

`zotero-write.sh orphan-clean` wraps `zot orphans clean --yes` — dead-only orphans (no file
anywhere) by default. It deliberately does **not** expose `--include-recoverable`: discarding the
server-side copy too is an operator action taken manually with `zot` directly, never silently via
this choke-point. Like `item-add`/`item-add-json`, it takes no existing item `KEY` — it operates
library-wide.

**Local-sync-lag caveat (same as Section 2's orphaned-record finding)**: `zot orphans list/clean`
read the **local SQLite database only**, never the Web API's live state. An orphan created via a
Web-API write (the exact kind this bridge's quota-rejected attaches produce) is invisible to
`orphan-clean` until a Zotero desktop client syncs it down. A record that was never synced to the
server at all returns `not_found` from the Web API — `zot`'s own guidance is to remove those from
the Zotero desktop instead. Both of the two known orphaned attachment records from Section 2's
live test (`5J2WMXDD`, `CB99228V`) are expected to no-op under `orphan-clean` until that sync
happens; this is a documented limitation, not a bridge defect, and the bridge logs it rather than
reporting a false success when the cleanup call changes nothing.

## Reference implementation

`literature-ingest-online.sh` — see its header comment block for the full STABLE CONTRACT (input
schema, directive tokens, exit codes) that downstream tooling built on top of this bridge depends
on.
