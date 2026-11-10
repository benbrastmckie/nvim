# Per-Repo Scoping

## The Mechanism, and Why It Is the Only One That Works

Per-repo knowledge scoping on this vault works through exactly one field: a literal
`[repo:<slug>]` substring embedded in a KO's `provenance` string, filtered on read by
`GET /v1/search`'s `source=` query parameter. A KO written with `provenance` containing
`[repo:nvim]` is returned by `source=[repo:nvim]` (and by the bracket-free substring form
`source=repo:nvim`), and is **not** returned by `source=[repo:bimodal]` — the filter is a hard
pre-filter that dominates relevance ranking, not a ranking signal: an unrelated query against the
matching tag still returns only the repo-tagged rows, and a query against a non-matching tag
returns none, however large the vault is overall.

No other field does this:

- **`project` is a dead end.** `/v1/search` silently ignores `&project=` — a real slug, another
  repo's slug, and a nonexistent slug all return the identical result set. `/v1/sf1/handoff
  ?project=X` merely echoes the slug back with `project_known: false` and still returns
  cross-project KOs even for a bogus project. `/v1/sf1/state` returns 404. `/v1/projects` returns
  403 `{"code": "company_only"}` — project surfaces are a paid-team feature on this account, not
  a per-repo-scoping primitive available here.
- **`source_loc`** (the field the `sapience_remember` MCP tool's own `source` argument populates)
  is not matched by the `source=` filter and is not returned in search results. It names where a
  finding came from; it does not scope who can read it back.

## Why the MCP Write Tools Cannot Produce a Tagged Write

The `sapience_remember` MCP tool cannot write a repo-tagged KO, because its connector hardcodes
`provenance` with no injectable repo marker (`remember_provenance()` in `~/.sapience/mcp.py`
returns a fixed `"<Name> via <Client> session (MCP)"` shape; setting `explicit` via the tool's
`user_asked` argument only appends a fixed `', asked by the user'` literal, still with no repo
marker). Tagged writes therefore go through `POST /ingest-kos` directly, which accepts an
arbitrary `provenance` string verbatim — this is what `sapience-remember.sh` does.

## The Two Scripts

- **`sapience-retrieve.sh <description> <task_type> [focus_prompt]`** — a repo-filtered
  `GET /v1/search` read. Derives the repo slug from `basename "$(git rev-parse
  --show-toplevel)"`, so the same script works unmodified in every repo this system deploys
  into. Reuses the existing local-memory script's keyword-extraction stage verbatim (lowercase,
  split on non-alpha, stop-word filter, length > 3, top 10) and its 2000-token budget / 5-entry
  cap, and emits the same `<memory-context>` envelope shape, so no dispatch-side consumer needed
  to change. Exit 1 with empty stdout on every failure or no-match path (no token, no slug, no
  keywords, an unreachable host within its `--connect-timeout 3 --max-time 8` bound, zero hits).
- **`sapience-remember.sh --subject S --value V [...]`** — a repo-tagged, `explicit: true` write
  via `POST /ingest-kos`. `explicit: true` is mandatory, not an optional flag: a realistically
  worded note posted without it is silently discarded by the server's noise gate, returning
  `{"ok": true, "written": 0, "gated": 1}` — a success-shaped response that hides the loss. This
  script sets `explicit: true` unconditionally (no flag can turn it off) and treats `gated >= 1`,
  a non-empty `set_aside` array, or an absent/zero `written` as a loud, non-zero-exit failure
  naming the triggering field on stderr, never a silent success.

Both scripts are declared in this extension's `manifest.json` `provides.scripts` array and are
deployed to `.claude/scripts/`. `sapience-retrieve.sh` is called from core's
`orchestrate-build-dispatch.sh` Stage 3.5 `memory_context` block, replacing the local-memory-vault
call at that one site; `sapience-remember.sh` is not wired into any call site by this record —
its sanctioned call site is task-boundary postflight, writing a bounded 3-8-note set per
completed task, the same bound the existing `sapience_wrapup` gap-2 instruction already uses.

## Hazards

**There is no delete API.** `DELETE /v1/ko/<hash>`, `DELETE /v1/kos/<hash>`, and `POST
/v1/ko/<hash>/delete` all return 404 on this vault. Every write through `sapience-remember.sh` is
therefore permanent; the only remedy is manual removal in the web app at app.spnc.ai. This shapes
how much gets written per task: few, high-value, well-formed notes at a task boundary, never a
write per decision.

**Writes through this path bypass the `auto_approve: false` review gate entirely.** That gate (see
`review-gate-boundary.md`) governs only the transcript-extraction path (`~/.sapience/upload.py`).
A direct `POST /ingest-kos` write has no staging and no review step — every write landed by
`sapience-remember.sh` is therefore both permanent *and* unreviewed, which is why the bound above
(per completed task, not per decision) is load-bearing rather than a style preference.

**The vault accumulates two differently-shaped populations.** The transcript-extraction path
cannot carry a repo tag (it has no caller-supplied provenance to tag), so it keeps writing
untagged KOs that a repo-filtered read never sees, alongside the smaller, repo-tagged population
this extension's two scripts produce. This is a documented asymmetry, not a defect this design
attempts to fix.
