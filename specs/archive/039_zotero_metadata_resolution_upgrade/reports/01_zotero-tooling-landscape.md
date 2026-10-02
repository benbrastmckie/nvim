# Zotero Tooling Landscape (August 2026): Metadata Resolution and Forward-Compatibility

- **Task**: 39
- **Date**: 2026-08-11
- **Type**: Seed research report (web research verified against official docs and repos; see
  sources at bottom)
- **Scope**: External tooling relevant to upgrading the literature extension's Zotero
  integration beyond bare write-path activation (task 38's territory)

## Version context

Current stable Zotero is **9.0.6** (released 2026-07-07); Zotero 8 shipped 2026-01-22, Zotero 9
shipped 2026-04-10 — release cadence is now ~6-10 weeks. **Zotero 10 is in beta** and is the
gate for native local writes (see section 4).

## 1. translation-server — the missing metadata-resolution step

`github.com/zotero/translation-server` is an official Zotero project, still maintained, with an
official Docker image (`zotero/translation-server`, port 1969). Endpoints:

- `POST /search` — DOI / ISBN / PMID / arXiv ID → full Zotero JSON metadata
- `POST /web` — URL → Zotero JSON (with a multi-result select flow)
- `POST /export`, `POST /import` — Zotero JSON ⇄ BibTeX/RIS/CSL

It produces metadata only — it does not write to libraries or download PDFs. The standard
recipe is translation-server output → Web API item create → separate PDF upload. This is the
cleanest scriptable "URL/DOI → library" pipeline and produces far better bibliographic records
than `zot add --pdf`'s DOI-from-PDF extraction alone (which fails on books, preprints without
embedded DOIs, and scanned PDFs). The current ingest bridge has no metadata-resolution step at
all for web-discovered sources — this is the pipeline's thinnest point.

Service provisioning (container or Node service) belongs to ~/.dotfiles (its task 129);
this repo's work is the integration: call `/search` (preferred, when a DOI/arXiv ID is known
from Tier-3 discovery) or `/web` (URL fallback) before item creation, and pass the resolved
metadata through the create path instead of relying on PDF extraction.

## 2. Zotero MCP servers — the interactive complement

- **54yyyu/zotero-mcp** (Python, `zotero-mcp-server` on PyPI) — de-facto standard: ~4.6k stars,
  actively maintained. Read: semantic search (local/OpenAI/Gemini/Ollama embeddings,
  auto-updating vector DB), keyword/tag search, metadata as markdown/JSON/BibTeX, annotation
  extraction. **Write**: add items by DOI/URL/ISBN/BibTeX/CSL-JSON, attach files, create
  collections/notes/tags, update metadata; auto-fetches OA PDFs via an
  Unpaywall → arXiv → Semantic Scholar → PMC cascade (overlaps this extension's Tier-3
  discovery). Supports a **hybrid mode: local-API reads + Web-API writes** — exactly the
  bidirectional shape this extension wants. `zotero-mcp setup` auto-configures Claude clients.
- **Xevos117/mcp-zotero** (TypeScript) — smaller but active; `add_items_by_doi`,
  `import_pdf_to_zotero`, batch OA discovery (`find_and_attach_pdfs`), delete with safety
  controls. Web-API-based.
- Others (richardjlyon/zotero-mcp with OAuth/HTTP transport, cookjohn, translator-wrapping
  servers) exist; the ecosystem churns. Only 54yyyu's is a low-risk adoption today.

**Positioning**: community practice in 2026 is a split — MCP for interactive, conversational
"find and add this paper" during research sessions; deterministic scripts/CLI for pipelines
(testable, no MCP tool-schema context cost). That matches this extension's architecture: the
scripts stay the pipeline of record; zotero-mcp is an optional interactive layer. If adopted,
registration scope and permission grants follow the grant-at-registration-scope principle
already established for MCP servers in the ~/.dotfiles Claude configuration.

## 3. Storage quota — a real ceiling for auto-attach

Stored-file uploads via the Web API count against the zotero.org **300 MB free tier** (data/
metadata sync is unlimited; paid tiers and WebDAV exist; linked files bypass quota but cannot
be created through the Web API upload flow — they require local-side creation, i.e. the Zotero
10 local API or an add-on shim). The library has 948 stored attachments locally. Before
enabling agent-driven auto-attach at scale, verify the account's storage plan/usage and decide
policy: attach always, attach only under quota headroom, or defer attachments to local-only.
The 4-step upload flow's `{"exists": 1}` response gives free content-hash dedup on PDF bytes
(but not on metadata items).

## 4. Zotero 10 — the planned backend swap

Zotero 10 (beta as of Aug 2026) ships **native local write support** in the local API at
`localhost:23119/api/`: POST/PUT/PATCH/DELETE for items/collections/tags plus file upload
(full-file only, no partial/binary-diff), with auth via a local API key obtained through
`POST /api/local/authorize` (user-consent prompt in the Zotero UI; unrelated to zotero.org
keys). When 10 goes stable this becomes the preferred write path: no cloud round-trip, no
storage quota for attached files, works offline. On stable Zotero ≤9 the local API remains
read-only (writes return 501), and the `/connector/saveItems` endpoint — while it does write —
is an undocumented internal protocol (docs stub last touched Dec 2025, saves into the
currently-selected collection, drifts between versions) and must not be adopted as a contract.

Design consequence: `zotero-write.sh` must remain the single write choke-point (established in
the write-path activation work) so the `zot`/Web-API backend can be swapped for local-API POSTs
without touching callers. This task should record the swap plan, not perform it before Zotero
10 is stable.

## 5. Adjacent facts worth recording

- **Better BibTeX** remains the right index-sync mechanism: JSON-RPC at
  `localhost:23119/better-bibtex/json-rpc` (`item.search`, `item.citationkey`,
  `autoexport.add`, ...), pinned citation keys as durable IDs, auto-export for the greppable
  CSL-JSON file. It is not an item-creation path.
- **pyzotero** (v1.13.x) is the canonical Python client and wraps the full 4-step attachment
  upload (`attachment_simple()`/`upload_attachments()`); `chriscarrollsmith/pyzotero-cli`
  exposes it as an agent-friendly CLI. These are fallback options if `zotero-cli-cc` ever
  stalls.
- **Dead ends**: ZotFile (never ported past Zotero 6; successors ZotMoov/Attanger, and renaming
  is now built into Zotero), jbaiter/zotcli (unmaintained).
- **Web API discipline**: honor `Backoff:` headers (can appear on 2xx) and `429`/`Retry-After`;
  use `Zotero-Write-Token` for idempotent item creates; `mtime` in milliseconds and exact md5
  in the upload flow.

## Sources

zotero.org/support/dev/web_api/v3/local_api · .../file_upload · .../basics ·
zotero.org/support/dev/client_coding/connector_http_server ·
github.com/zotero/translation-server · github.com/54yyyu/zotero-mcp ·
github.com/Xevos117/mcp-zotero · retorque.re/zotero-better-bibtex/exporting/json-rpc/ ·
pyzotero.readthedocs.io · zotero.org/support/changelog · zotero.org/support/duplicate_detection ·
forums.zotero.org (Announcing Zotero 8; MCP for Zotero; local-API threads)
