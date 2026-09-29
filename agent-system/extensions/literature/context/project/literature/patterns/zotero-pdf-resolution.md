# Zotero PDF Resolution Pattern

How to resolve a `~/Projects/Literature/index.json` doc_id to its underlying Zotero PDF, safely
and reproducibly. Established alongside `.claude/scripts/zotero-resolve-pdf.sh`, building on
the `provenance_fidelity` enum and `zotero-resolve-sqlite-path.sh`'s dataDir derivation.

## 1. Prefer the live local HTTP API when Zotero is running

Zotero 7 exposes a local HTTP API at `http://127.0.0.1:23119/api/users/0/...` whenever the
desktop app is running. This is the preferred resolution path:

- `GET /api/users/0/items?q=<query>&itemType=-attachment&limit=N` -- bibliographic search.
- `GET /api/users/0/items/<key>/children` -- list an item's child attachments; check for
  `data.contentType == "application/pdf"`.

Probe reachability with `curl -sf -m 5 http://127.0.0.1:23119/api/users/0/items?limit=1` before
choosing an access mode. This is always non-destructive (plain GETs).

## 2. The sqlite fallback requires Zotero to be closed

`zotero.sqlite` is locked (`sqlite3 -readonly ...` returns `Error: database is locked`) the
entire time Zotero is running. A resolver must handle three states, not just "Zotero open or
closed":

| Zotero process | Live API | Access mode | Behavior |
|---|---|---|---|
| Running | Reachable | `live-api` | Use the HTTP API; never open sqlite. |
| Not running | Unreachable | `sqlite-readonly` | Open with `sqlite3 -readonly`; never write. |
| Running | Unreachable | `abort` | Do not force a locked read; ask the user to enable Zotero's local API (Settings -> Advanced -> "Allow other applications on this computer to communicate with Zotero") and stop. |
| Not running | Reachable | `live-api` | Something else is serving the API; treat as live-api. |

## 3. The storage root must be derived, never hardcoded

`zotero-generate-export.sh`'s `fetch_path3()` hardcodes `$HOME/Zotero/storage/<attKey>/<filename>`
for resolving `storage:`-prefixed attachment paths. This is wrong on any machine with a custom
Zotero Data Directory (Zotero Settings -> Advanced -> Files and Folders -> "Data Directory
Location: Custom") -- confirmed concretely: this machine's real storage root is
`/home/benjamin/Documents/Zotero/storage/`, and `~/Zotero/storage/<key>/` does not exist.

Always derive the storage root the same way `zotero-resolve-sqlite-path.sh` derives the sqlite
path, then descend into `storage/`:

```bash
ZOTERO_SQLITE="$(bash .claude/scripts/zotero-resolve-sqlite-path.sh)"
ZOTERO_DATA_DIR="$(dirname "$ZOTERO_SQLITE")"
ZOTERO_STORAGE_ROOT="$ZOTERO_DATA_DIR/storage"
```

`zotero-generate-export.sh`'s `fetch_path3()` hardcode is a known, latent bug (recorded here as a
follow-up item, not yet fixed -- it is latent because Path 3 only runs when the live API
is unreachable). Any new script must use the derivation above, not copy that hardcode.

## 4. `zotero-library.json` carries no attachment paths and goes stale

The 400-entry CSL-JSON snapshot (`zotero-generate-export.sh` Path 1/2 output) is pure
bibliography -- title/author/issued/citation-key -- with zero file-path or attachment
information. It can at best narrow a title/author search to a candidate item key; the actual PDF
location must still come from the live API's `/children` endpoint or the sqlite
`itemAttachments` table. The snapshot is also demonstrably stale: a live-API search found a real
match (`bacon_2018_broadest-necessity` -> Zotero key `Q3YVBYBT`) for a title absent from the
400-entry snapshot entirely. Never trust the snapshot as a resolution source; only the live API or
a closed-Zotero sqlite read reflect current reality.

## 5. `index.json`'s `zotero_key` field is not always a real Zotero API item key

Some `index.json` entries carry a `zotero_key` value that is a Better-BibTeX-style citekey (e.g.
`"Burgess1982I"`), not the item's real 8-character Zotero API key (e.g. `"7XEG8NM9"`). A direct
`GET /items/<citekey>/children` call with the citekey 404s. Treat a non-null `zotero_key` as a
**trust signal** (this doc_id is known to be Zotero-tracked) rather than a literal API path
segment: still resolve via title/author search, and tier the result `key-anchored` (vs.
`search-candidate` for entries with no pre-existing `zotero_key`) to preserve the distinction
between "we already knew this was in Zotero" and "we found this via a cold search."

## 6. Title-similarity search needs both a truncation strategy and a similarity floor

Two failure modes were found empirically while building `zotero-resolve-pdf.sh`:

- **Over-specific queries silently return zero hits.** Zotero's quick search (`q=`) requires all
  query tokens to be present. A corpus title with a trailing slug-derived word not in the real
  bibliographic title (e.g. `fine_2014_truthmaker-semantics-intuitionistic`'s title field including
  "Intuitionistic", which the real Zotero item's title lacks) returns nothing. Mitigation:
  progressively drop trailing words (right-truncate) down to a 2-word floor before falling back
  to an author-only query, stopping at the first query that returns any result.
- **Author-only fallback queries collide on common/substring surnames.** A single-surname query
  (used only when title search entirely fails) can match a coincidentally similar or
  substring-overlapping surname in an unrelated library (e.g. author "Een" substring-matched
  "Shaheen"; author "Liu" collided with an unrelated modal-logic paper by a different "Liu").
  These collisions score low title similarity (empirically 0.12-0.43) against genuine matches
  (0.52-1.0). Mitigation: apply a minimum title-similarity floor (0.4 in the initial
  implementation) before accepting ANY non-key-anchored candidate, and always select the
  highest-similarity candidate with a resolvable PDF among all search results -- never just the
  first one returned by the API in result order.

Even with both mitigations, a resolver's output is a *candidate*, not a verified match. A
secondary gate (year/DOI/venue cross-check against the doc_id's own metadata) is still required
before any non-key-anchored candidate may be written into the corpus -- see the Reference
implementation section below for that gate.

## 7. The local API's `format=csljson` pagination quirk, and the itemTypes name-vs-ID lesson

`zotero-generate-export.sh`'s Path 1 (live local-API pull) previously terminated pagination on
"this page returned fewer than `limit` items" -- the wrong signal for `format=csljson`.
Empirically verified against the live API: at `start=400`, the raw item window (`format=json`,
same `limit`/`start`) returned 100 rows including 19 annotation-typed items, but the `format=csljson`
serialization for that identical window returned only 81 entries. **Zotero silently drops
annotation-typed rows from the csljson body while still counting them in `Total-Results` and the
`limit`/`start` pagination window.** A page-length-driven loop stops at the first such page,
years before the real end of the library (measured: pagination stopped at 481 items against a
4042-item `Total-Results`). The fix is `Total-Results`-driven termination: read `Total-Results`
once from the first response's headers, advance `start` by `limit` unconditionally, and stop only
when `start >= Total-Results`.

A second, independent quirk in the same function: the CSL `.type` field cannot carry an
attachment/note exclusion filter. Zotero maps its `attachment` itemType to CSL type `document`
(never to CSL type `"attachment"`), so a `select(.type != "attachment" and .type != "note")`
predicate is a verified no-op -- confirmed live, 0 items ever removed by that predicate across a
full sweep of a real library. The working fix cross-references each pagination window's raw
(`format=json`) response, which DOES carry the authoritative `data.itemType`, by item key
(`.id | split("/") | last`, the same mapping `enrich_path2()` already relies on for citekey
enrichment) -- never a CSL-field heuristic.

**The itemTypes name-vs-ID lesson** (also fixed in `fetch_path3()`, the sqlite reconstruction
path): itemTypeID values are NOT stable identifiers to hardcode. `fetch_path3()` previously
excluded `WHERE it.itemTypeID NOT IN (1, 3, 28)`, intending to exclude
attachment/note/annotation -- but on this installation, IDs 1/3/28 are actually
`artwork`/`audioRecording`/`podcast` (the real IDs are `attachment=2`, `note=26`,
`annotation=37`). That mismatch was a verified no-op that let roughly 61% attachment/note stub
entries (empty title/author/issued) into every sqlite-path export. The fix resolves the
exclusion set by TYPE NAME via a subquery on `itemTypes.typeName`, never a hardcoded numeric ID,
so it cannot rot the same way across Zotero versions or installations again.

## Follow-up items (recorded, not yet fixed)

- **`zotero-generate-export.sh`'s `fetch_path3()` hardcoded storage root.** Currently latent
  (Path 3 only runs when the live API is unreachable), but will silently resolve to a nonexistent
  path on any machine with a custom Zotero dataDir the day it does run. Should be fixed to reuse
  the same derivation as `zotero-resolve-sqlite-path.sh` / `zotero-resolve-pdf.sh`.
- **Suspected corpus-metadata duplicate**: `fine_2012_difficulty-possible-worlds-counterfactuals`
  vs. `fine_2012_counterfactuals-without-possible-worlds`. Near-identical titles; only the latter
  has a confirmed independent Zotero hit. Not yet de-duplicated (flagged as
  out-of-scope); worth a dedicated look.

## Reference implementation

`.claude/scripts/zotero-resolve-pdf.sh` -- read-only, `--doc-id <id>` or stdin JSON input, emits
a single JSON object with `tier` (`key-anchored` | `search-candidate` | `matched-no-pdf` |
`absent`), resolved Zotero metadata, and (for non-key-anchored tiers) a `title_similarity` score.
