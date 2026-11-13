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
  non-fatally via `issue-record.sh` carrying the stderr diagnostic; retrieval never blocks the
  dispatch, and retries the dispatch's own request only on the narrow cold-start signal
  described next.

  **Bounded cold-start retry**: a response is retried exactly once when, and only when, it is
  HTTP 503 with a body that parses as JSON and carries a strict-boolean `.starting == true` (a
  truthy string does not qualify). On that match, the script honors the server's own
  `retry_after` hint, clamped into `[RETRY_DELAY_MIN, RETRY_DELAY_MAX]` = `[1, 20]` seconds with
  `RETRY_DELAY_DEFAULT = 15` used when the hint is missing or non-numeric, sleeps that many
  seconds, and issues one more request. A 4xx, a non-JSON body, and a curl transport error are
  never retried. Worst-case added wall clock on the cold-start path is therefore ~36s (8s first
  `--max-time` + 20s clamp ceiling + 8s second `--max-time`), versus ~8s on every other path.
  Whether or not a retry fires, the terminal behavior on a second failure (or on any
  non-retried genuine failure) is the unchanged exit-2 fail-open degrade: `issue-record.sh`
  records the failure non-fatally and the dispatch proceeds with an empty `memory_context`.
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

## The MCP-Registration Triad

Per-repo activation also covers WHICH `mcp.py` process a session connects to, not only which
knowledge it can read or write. Four scripts mirror the lean extension's own shipped per-project
`lean-lsp` triad. This registration triad's own `SessionStart` hook is a SEPARATE, sixth hook
surface from the five `settings-fragment.json` merges (`SessionStart`, `UserPromptSubmit`,
`PreToolUse`, `SessionEnd`, `Stop`) -- installed at user level, not merged by the fragment:

- **`scripts/setup-sapience-mcp.sh`** — the writer. Registers, repairs, or removes
  `.projects["<abs project path>"].mcpServers.sapience` in `~/.claude.json` for exactly one
  project, via a whole-file `jq` merge that preserves every other key. Never touches the
  top-level `.mcpServers` key (the `--retire-global` action is a separate, standalone escape
  hatch, not part of the normal write path).
- **`hooks/sapience-mcp-register-project.sh`** — a bidirectional `SessionStart` hook. When the
  session's repo shows `extensions.sapience.status == "active"` in its own
  `.claude-extensions.json`, it invokes the writer to register/repair the entry; when it does
  not and an entry exists, it invokes the writer with `--remove`. This is the only mechanism
  that can retract the per-project `~/.claude.json` entry once the extension unloads, since the
  settings-merge engine governs only in-tree merge targets, never `~/.claude.json`.
- **`scripts/install-sapience-mcp-session-hook.sh`** — idempotent, `--remove`-capable installer
  that seeds the hook and the writer to `$HOME/.claude/{hooks,scripts}/` and registers the
  `SessionStart` entry in `$HOME/.claude/settings.json`.
- **`scripts/verify-sapience-mcp.sh`** — the verifier, checking activation, the per-project
  entry, the installed files, and the `SessionStart` registration for one project.

**Stable-user-level-path invariant.** The hook and writer are installed to
`$HOME/.claude/hooks/` and `$HOME/.claude/scripts/` — stable, user-level paths outside any
repository's own disposable `.claude/` tree (`context/patterns/mcp-server-ownership.md`'s
`.claude/`-path boundary invariant). This is load-bearing, not merely tidy: the hook must work in
a fresh git worktree with no `.claude/` deploy at all, so it cannot resolve the writer relative
to the calling repository's own tree.

**One-session-start removal lag.** Unloading the extension does not retroactively remove a
repo's `~/.claude.json` entry until the NEXT session start in that repo (the bidirectional hook
above only fires at session start) — or immediately, via
`install-sapience-mcp-session-hook.sh --remove`.

**Deliberate divergence from the lean model.** Lean's own installer also writes
`$HOME/.dotfiles/config/claude/settings.json` as a durable second registration target. This
extension's installer does not: it is forbidden to touch any `.dotfiles` file, so the
`SessionStart` registration above lives ONLY in `$HOME/.claude/settings.json`. See the
durability-residual hazard below.

## Hazards

**The `SessionStart` MCP-registration hook is NOT durable across a `home-manager switch` --
accepted residual, same shape as the write-grant residual above.** `hooks` is a home-manager
ENFORCED key (`~/.dotfiles/modules/home/core/dotfiles.nix`'s
`[_NOTE,env,hooks,model,permissions,statusLine]` set), reset from `.dotfiles`'
`config/claude/settings.json` on every `home-manager switch` while that source carries a
`hooks` key -- which it will, for other entries, even after a companion task removes the
Sapience ones from it. Because this extension's installer deliberately does not write
`.dotfiles` (see above), the registration this installer adds to
`$HOME/.claude/settings.json` is wiped by the next switch and must be re-run. `install-sapience-mcp-session-hook.sh`
prints a loud WARNING naming this on every run, and `verify-sapience-mcp.sh`'s check (d) detects
the loss so it is caught rather than silent. **Named escape valve**: a companion task (or a
follow-up) taking ownership of a durable user-level `SessionStart` entry for this hook, the same
way the write-grant residual above names a follow-up task as its escape valve rather than a
silent hope the gap is never hit.

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

**The vault accumulates four differently-shaped populations, and only one carries the tag.**

1. **Tagged.** `sapience-remember.sh`'s `POST /ingest-kos` writes, carrying `[repo:<slug>]` in
   `provenance`. This is the only population a `source=` filtered read ever returns.
2. **Untagged, but reachable from this extension's own instruction surfaces.** The four MCP
   write tools (`sapience_remember`, `sapience_wrapup`, `sapience_handoff`, `sapience_adddoc`):
   none can produce a tagged write (see "Why the MCP Write Tools Cannot Produce a Tagged Write"
   above), and the standing rule (`rules/sapience-write-path.md`) now prohibits naming any of
   them as a prescribed write path -- see `review-gate-boundary.md`'s
   `## Write-Tool Disposition` section for the per-tool disposition. This population stays
   untagged going forward only if a stray proactive call bypasses the rule; it is not expected
   to grow under normal use.
3. **Untagged and vendor-owned.** Transcript extraction via `~/.sapience/upload.py`. Its
   `_chunk()` sends `'project': m['project']` per chunk, so the repo identity does reach the
   server, but the server-authored provenance drops it before the KO is stored -- this is the
   largest population on this vault and cannot be fixed from this repository.
4. **Belongs to no repository.** Documents shared by other people (provenance of the form
   `people <name> | shared by <name> <timestamp> | doc {...}`). Out of scope by construction:
   there is no repo to tag them with.

Populations 3 and 4 are a documented asymmetry, not a defect this design attempts to fix: no
mechanism available to this repository can tag either one. Population 2 is the one this
extension's own surfaces can and do control.

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
