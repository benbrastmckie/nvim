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
  to change. Exit codes are split: exit 1 with empty stdout on every BENIGN no-match path (no
  token, no slug, no keywords, zero hits) -- unchanged from before; exit 2 with empty stdout and
  one stderr diagnostic (the HTTP status and a length-bounded body excerpt) on a GENUINE
  transport/HTTP failure (a curl transport error, a non-2xx status, or a non-JSON body), read
  from the same request via `curl --write-out` -- no second network call and no added latency on
  the success path. `orchestrate-build-dispatch.sh`'s Stage 3.5 `memory_context` block captures
  this exit code and, only on exit 2, records an `infrastructure/transport unavailable` entry
  non-fatally via `issue-record.sh` carrying the stderr diagnostic; retrieval still never blocks
  or retries the dispatch on any exit code.
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
call at that one site.

## The Tagged-Write Call Site

`sapience-remember.sh` is called from `EXTENSION.md`'s postflight wrapup instruction, at the
`[IMPLEMENTING]` -> `[COMPLETED]` transition, **replacing** the untagged `sapience_wrapup` MCP
call rather than keeping both (D3, below). The call-site contract:

- **Bound**: 3-8 notes per completed task, one `sapience-remember.sh` call per note. The script
  itself deliberately does not enforce this bound (it is a general-purpose write primitive with
  other future callers); the call site is the only place it is enforced, and it is load-bearing
  there because every write is both permanent (no delete API) and unreviewed (bypasses the
  `auto_approve: false` review gate — see Hazards below).
- **Dry-run before real write**: `sapience-remember.sh --subject S --value V --dry-run` exits 0
  and prints the request body (provenance carrying `[repo:<slug>]`, token redacted) without
  making a network call. Verify the dry-run output before the first real rollout, and after any
  change to the call site, rather than discovering a defect from a landed, permanent write.
- **Degrade rule**: a failed `sapience-remember.sh` call (non-zero exit, a `gated >= 1` or
  non-empty `set_aside` response, or `written: 0`) is logged and stepped over — it never fails
  the postflight step, never blocks the `[IMPLEMENTING]` -> `[COMPLETED]` status transition, and
  never retries automatically (a retry of a write that failed the noise gate is not expected to
  succeed differently).

## No Lifecycle Hook

A `hooks.postflight` manifest entry was considered and rejected: `skill-base.sh`'s
`skill_get_extension_dir()` gates hook resolution on `[ -n "$ext_task_type" ] && [
"$ext_task_type" = "$task_type" ]`, and this extension declares no `task_type` at all (it is
deliberately typeless, applying to every task regardless of domain), so the hook path fails the
`-n` test unconditionally and silently — it can never fire. This is not a gap to close; it is why
the call site lives in the instruction-level postflight wrapup text instead.

## D3: Why Replace, Not Both

A live, unfiltered `sapience_search` returns a repo-tagged knowledge object alongside untagged
ones, confirming that the `[repo:<slug>]` provenance tag narrows only reads that explicitly
request the `source=` filter — an unfiltered read sees both populations, a repo-filtered read
sees only the tagged one. A tagged write is therefore strictly more reachable than an untagged
one: keeping both call sites would double permanent, unreviewed write volume for zero added
reachability. The bound above is a bound on the shared note set per completed task, not per
write path, so replacing rather than adding keeps that bound meaningful.

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

**An `mcp__sapience__*` tool failure cannot be captured mechanically from this repository, and
this is an accepted gap, stated plainly rather than implied away.** Only the two scripts above
(`sapience-retrieve.sh`, called from Stage 3.5; `sapience-remember.sh`, called from postflight
wrapup) pass through a point this repository controls. Every `mcp__sapience__*` tool call --
`sapience_search`, `sapience_ask`, `sapience_briefing`, `sapience_outstanding`,
`sapience_wrapup`, `sapience_handoff`, `sapience_papers`, and an untagged `sapience_remember`
call made outside the postflight wrapup site -- goes through the vendor-owned MCP client
(`~/.sapience/mcp.py`), which raises the server's own message as a `RuntimeError` with no
structured status this repository can intercept: the merged settings carry no wildcard-matcher
`PostToolUse` hook for MCP tool calls, and nothing in this repository sits between the client and
the tool-call result. A failure of this kind therefore surfaces only as transcript prose in the
calling agent's own turn. The only available remedy is agent self-report: when an
`mcp__sapience__*` call fails, the agent noticing it SHOULD record it via `issue-record.sh` with
`--class "infrastructure/transport unavailable"` and the tool's own error text as
`--what-happened` -- but this is explicitly best-effort, not a substitute for mechanical capture,
and an agent that does not notice or does not record it leaves no trace, exactly as today.
