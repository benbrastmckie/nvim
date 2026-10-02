# Zotero Integration

Full Zotero library management is part of the literature extension (absorbed from the former
standalone zotero extension — there is no separate zotero extension to load).

## How the Library Is Reached

Two access paths, used for different jobs:

- **Better BibTeX CSL-JSON auto-export** — the search path. A single JSON file the extension
  reads directly, so search works with Zotero closed and requires no running client.
- **The `zot` CLI** — the optional direct-library path, used for reading item metadata/PDFs and
  for creating or attaching items during online ingest.

## Setup

In Zotero: **File > Export Library > Better CSL JSON**, check **"Keep updated"**, and save to:

```
~/Projects/Literature/zotero-library.json
```

(or `$LITERATURE_DIR/zotero-library.json` if `LITERATURE_DIR` is overridden — see
`tools/literature-dir-config.md`).

"Keep updated" is what makes the export a live mirror rather than a one-time snapshot; without
it, the search tier silently ages out as the library grows.

## Where It Is Used

| Consumer | Role of Zotero |
|----------|----------------|
| `/literature` Mode A, Tier 2 | Local library search before any online lookup |
| `/literature` online ingest | Item creation and PDF attachment via `zot` |
| `/cite` | Match-and-score source, and the basis for `--gaps` (in-library, no local PDF) |

## Zotero MCP: Adoption Decision

**Decision: defer.** `54yyyu/zotero-mcp` (the de-facto standard Zotero MCP server, ~4.6k stars,
hybrid mode = local-API reads + Web-API writes, add-by-DOI/URL/ISBN with an OA-PDF cascade) is
evaluated as an interactive complement for `/research --lit` sessions and NOT adopted at this
time.

**Reasons**:
- The candidate's write value-add largely duplicates this extension's own discovery/ingest
  cascade (`literature-discover.sh` -> `literature-ingest-online.sh`), but would bypass this
  pipeline's own dedup guard (`check_live_doi_duplicate()`/`check_duplicate_title()`) and index
  patching (`patch_global_index()`/`upsert_subindex()`) — an MCP-driven add would not know about
  or honor either.
- Its one genuinely unique value-add over this repository's scripts — semantic search over the
  library — is read-side only, and is not blocked by this decision; it remains available to
  adopt independently of the write-path question.
- The one owned write surface (`zotero-write.sh`) is not yet hardened enough to safely coexist
  with a second, independent write path into the same library.
- Zotero 10's native local-write API (see the Backend Swap Plan below) will likely obsolete the
  hybrid-mode proposition specifically (local-API reads + Web-API writes) once it stabilizes,
  which would change this evaluation's premise entirely.

**Verified absence**: `zotero-mcp` is confirmed NOT installed (`command -v zotero-mcp` empty) and
NOT registered (absent from `claude mcp list`) on this machine — the defer decision is grounded
in fact, not argued from landscape reasoning alone.

**Reversal triggers** (either one reopens this decision):
1. Zotero 10 stabilizes and the Backend Swap Plan below is executed — at that point the hybrid-
   mode proposition this candidate offers may already be moot, or may look different against a
   stable local-write API.
2. A genuine read-side semantic-search need arises that this repository's own search tooling
   (`zotero-search.sh`, the FTS5-backed literature index) cannot satisfy.

**Registration scope, if ever adopted**: registration and permission grants live in the user's
`~/.dotfiles` Claude configuration under the grant-at-registration-scope principle already
established for MCP servers there — never hand-edited in this repository, either way.

## Backend Swap Plan (Zotero 10)

Zotero 10 (beta) ships native local writes — items, collections, tags, and file upload — at
`localhost:23119/api/`, gated by a consent-obtained local API key via
`POST /api/local/authorize` (a Zotero-UI consent prompt, unrelated to the existing
`zotero.org`/Web-API key). This would eliminate the cloud round-trip for every write operation
and, because file uploads would land directly in local storage, eliminate the zotero.org storage
quota constraint for attached files entirely.

**Choke-point**: `zotero-write.sh` remains the sole write surface. The swap is an internal
backend-selection step added there, never a change to any caller.

**What changes internally**: a backend-selection step runs after the existing `zot`-installed and
`ZOTERO_API_KEY` checks, detecting (a) `localhost:23119/api/` reachability and (b) a
consent-obtained local API key. When both hold and Zotero 10 is the pinned stable version, write
operations (`note-add`, `tag-add`, `tag-remove`, `attach-file`, `item-add`, `item-add-json`,
`orphan-clean`) route through local-API calls instead of the Web API; otherwise today's Web-API
path (via `zot`) is unchanged. File attachment becomes a full-file PUT upload that does not count
against the storage quota at all.

**What stays constant for callers**: operation names, argument shapes, the 0/1/2 exit-code table,
`--dry-run`/`--idempotency-key` semantics, and the stdout-envelope contract — including
`item-add-json`'s `{"ok":…,"data":{"key":…,"raw":…}}` normalization, which the local-API path
must also produce. A caller of `zotero-write.sh` sees no difference regardless of which backend
served the write.

**Explicit rejection: `/connector/saveItems`**. This endpoint is NOT a candidate write contract,
despite also being able to write. Reasons: it is an undocumented internal protocol (not part of
the versioned, documented local API at `localhost:23119/api/`); it writes into whatever collection
is currently selected in the Zotero UI — a caller-uncontrollable side channel, incompatible with a
deterministic scripted pipeline; and it has a history of behavioral drift between Zotero versions.

**Not implemented.** Zotero 10 is beta; this is a recorded plan, not executed work. The local
API's exact response field names are unconfirmed (no live call has been made against it), which
is exactly why the existing defensive multi-candidate envelope lookup in
`literature-ingest-online.sh` extends naturally to a second backend rather than needing a
rewrite — it was already built to probe several plausible field-name candidates rather than
assume one shape.

## Auto-Attach Policy (Quota-Aware)

Stored-file uploads via the Web API count against the zotero.org storage quota (300 MB on the
free tier); a quota-rejected upload still leaves an orphaned, file-less attachment record behind
(see `patterns/zotero-item-creation.md` Section 2). `literature-ingest-online.sh` therefore gates
every attach attempt behind an explicit, policy-driven decision rather than discovering the
ceiling by a real failure:

- **`ZOTERO_AUTO_ATTACH`** (`always` | `under-quota` [default] | `never`): `always` attempts the
  attach even against a known-over-quota cached state (with a logged warning); `under-quota`
  skips the attach when a fresh cached state reports usage at or above the limit; `never` always
  skips, independent of quota state.
- **Reactive cache**: `specs/zotero-index.json`'s top-level `quota_state` key
  (`{used_mb, limit_mb, checked_at, source}`, `source` one of `413-observed` or
  `operator-configured`), merged in — never overwriting the pre-existing `zot_data_dir` key.
  Seeded by parsing a real 413 response's `.error.message` (confirmed shape: `"File would exceed
  quota (2745.6 > 300)"`); a non-matching message records nothing rather than guessing.
- **Operator override**: `ZOTERO_ASSUMED_QUOTA_MB` sets `source: operator-configured`; every log
  line consulting it states "assumed, not API-verified" so it is never confused with an observed
  value.
- **24h staleness bound**: a cached state older than 24 hours is treated as unknown, permitting
  exactly one real attempt, which re-caches on failure — self-correcting if the operator frees
  space without updating the cache by hand.
- A preflight quota check is structurally impossible (no Web API endpoint exposes current usage),
  so this gate is necessarily reactive and/or operator-configured by necessity, not preference.

**Interaction with the Backend Swap Plan above**: once a local-API backend is active and
selected, this gate becomes **inert, not removed** — local writes do not count against the
zotero.org storage quota, so the gate's checks simply never find a reason to skip. Removing the
gate code itself would be premature given the reactive/Web-API path remains the fallback whenever
the local API is unreachable.

## Related

- `tools/zotero-scripts.md` — the script inventory, argument gotcha, and the `zot` CLI's
  `delete`/`orphans`/`trash`/`duplicates` family (including `zot duplicates --by doi|title|both`,
  a whole-library, operator-facing dedup sweep distinct from this pipeline's own pre-write
  checks, with the same local-SQLite sync-lag caveat as `orphans list/clean`)
- `patterns/zotero-item-creation.md` — item creation, the `%PDF` magic-byte gate, `item-add-json`,
  `orphan-clean`, and the `resolution_path`/`attachment_state` surfacing vocabulary
- `patterns/zotero-pdf-resolution.md` — resolving an index entry to its Zotero PDF
