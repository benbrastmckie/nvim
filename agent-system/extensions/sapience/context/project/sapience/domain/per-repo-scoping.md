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

- **`&project=` is a dead end; `project_cid` is a different parameter that is not.** `/v1/search`
  silently ignores `&project=` — a real slug, another repo's slug, and a nonexistent slug all
  return the identical result set. `/v1/sf1/handoff?project=X` merely echoes the slug back with
  `project_known: false` and still returns cross-project KOs even for a bogus project.
  `/v1/sf1/state` returns 404. `/v1/projects` returns 403 `{"code": "company_only"}` — project
  surfaces are a paid-team feature on this account, not a per-repo-scoping primitive available
  here. `project_cid` is a structurally distinct query parameter that `/v1/search` and
  `/v1/recent` DO honor as a strict pre-filter, verified directly in `brain_server.py`'s own
  handlers — but that honoring is itself gated on `repo_link.enabled(tok)` (the `REPO_LINK_FOR`
  feature flag, deployed `""` for this account), so the honoring path is unexercisable live today
  and is confirmed stub-verified only. Both statements hold at once: `&project=` is dead on this
  account for the reason above, and `project_cid` is a live server capability this account cannot
  yet reach.
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

The installed vendor `~/.sapience/mcp.py` does carry a `project` argument on its own
`sapience_remember` tool, and it is worth naming here precisely because it is unrelated to the
mechanism above: it is company-store ROUTING, not per-repository tagging. `route_ko(ko,
project)` resolves the argument (or, absent one, the KO's own `project` field) through
`project_slug()` and matches it against `config.json`'s `routes` map, falling back to
`COMPANY_PROJECT`/`SAPIENCE_PROJECT` (default `"sapience-labs"`), to decide whether a write lands
in the shared company store or the caller's personal brain. This picks a destination STORE; it
still cannot produce a `[repo:<slug>]`-tagged write, for the same reason given above — the
connector's `remember_provenance()` shape has no injectable repo marker regardless of which store
the write lands in. (This is a discussion of the tool's existence and boundary, not a
prescription of it as a write path — `rules/sapience-write-path.md`'s "Discussing a Tool vs.
Prescribing It as a Write Path" governs this paragraph.)

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

  **Project-scoped reads.** When this repository carries a committed `.sapience/project.json`
  binding (written by `sapience-project-bind.sh`), this script additionally resolves it through
  the shared resolver against the already-resolved checkout toplevel and sends the binding's cid
  as a `project_cid` query parameter on the SAME `/v1/search` request — the retained `source=`
  label filter is sent unconditionally regardless, so the dispatch memory block becomes the
  project's own notes when the server honors `project_cid`, and stays label-scoped exactly as
  before when it does not. With no link file, or one that is missing, unreadable, non-JSON, or
  fails the resolver's three-key/path-shape validation, nothing is appended to the URL and the
  request is byte-identical to the pre-project-aware request. A 2xx response whose body carries a
  non-empty `project_rejected` is a benign degrade, not the exit-2 transport branch: one bounded
  warning goes to stderr and the same response is used for hit extraction, never a second request
  without the parameter.
- **`sapience-remember.sh --subject S --value V [...]`** — a repo-tagged, `explicit: true` write
  via `POST /ingest-kos`. `explicit: true` is mandatory, not an optional flag: a realistically
  worded note posted without it is silently discarded by the server's noise gate, returning
  `{"ok": true, "written": 0, "gated": 1}` — a success-shaped response that hides the loss. This
  script sets `explicit: true` unconditionally (no flag can turn it off) and treats `gated >= 1`,
  a non-empty `set_aside` array, or an absent/zero `written` as a loud, non-zero-exit failure
  naming the triggering field on stderr, never a silent success.

  **Project-key write, never `project_cid`.** With the same `.sapience/project.json` binding
  present, this script additionally resolves the binding's cid to a plain `project: "<key>"`
  field — looked up at runtime via `GET /v1/people/projects` against the binding's cid, exactly
  the same accepted-or-owned row shape `sapience-project-bind.sh` consumes — and carries it on the
  KO body. It never sends `project_cid`: a verified `project_cid` write is the one `sf1-engine`
  ruling 7 holds shut while two named leak surfaces stay open (see
  `linked-repo-write-policy.md` and `rules/sapience-write-path.md`), and `project_cid` trusting a
  client-supplied value is not server-verified for this token in any case. With no binding file,
  no `--project-key` override, or a resolution failure (a non-JSON listing, or a cid with no
  matching row), the write degrades to untagged-by-project with a stderr warning — never refused,
  never dropped — and is byte-identical to the pre-linking write.

  **The shared resolver.** `sapience_project_link_read` (and its cid-only wrapper
  `sapience_project_link_cid`) in `scripts/lib/sapience-api-lib.sh` is the one place this binding
  file is read, taking an already-resolved checkout toplevel from its caller. Both
  `sapience-retrieve.sh`'s read-side `project_cid` lookup above and `sapience-remember.sh`'s own
  binding-cid read go through it. The host/token resolution and the worktree-checkout-resolution
  block remain duplicated across scripts exactly as before this resolver existed — unchanged, and
  still pinned by `test-sapience-mcp-registration.sh` Case 30's lockstep byte-identity check —
  because consolidating those predates this resolver and is out of its boundary.

Both scripts are declared in this extension's `manifest.json` `provides.scripts` array and are
deployed to `.claude/scripts/`. `sapience-retrieve.sh` is called from core's
`orchestrate-build-dispatch.sh` Stage 3.5 `memory_context` block, replacing the local-memory-vault
call at that one site.

## The Tagged-Write Call Site

`sapience-remember.sh` is called by `scripts/postflight-sapience-notes.sh`, a mechanical write
site invoked directly from **three** invocation points across two core scripts, rather than
from instruction-level postflight wrapup text: `orchestrate-cycle-postflight.sh`'s terminal
`implemented)` case (the live `/orchestrate` completion path), and `reconcile-task-status.sh`'s
`implementing)` and `partial)` promotion arms (the deferred completion path — a deploy-gate exit
refusal later settled by that script, which bypasses the live path's own propagation helpers
entirely). Each invocation point is guarded on `postflight-sapience-notes.sh`'s own presence and
is non-fatal. This **replaces** the untagged `sapience_wrapup` MCP call rather than keeping both
(D3, below). The write script reads the completing implementation agent's own 3-8-note
`sapience_notes` array from `.return-meta.json` (see
`context/formats/return-metadata-file.md`'s `### sapience_notes (optional)` section) and issues
one `sapience-remember.sh` call per honored note. The call-site contract:

- **Bound**: 3-8 notes per completed task. The ceiling (8) is **mechanical**: a pre-write
  `jq length` check in `postflight-sapience-notes.sh`, performed once before any write is
  issued — never a running counter — slicing to the first 8 and recording a `tooling bug or gap`
  issue row on an excess. The floor (3) is **agent-side guidance only**: there is no content to
  fabricate when an agent has nothing durable to report, so the write script's only lower-end
  action is recording a visible `knowledge-capture gap` issue row when the array is empty,
  rather than silently writing nothing. `sapience-remember.sh` itself deliberately does not
  enforce either half of this bound (it is a general-purpose write primitive with other future
  callers); the write site is the one place it is enforced, and it is load-bearing there because
  every write is both permanent (no delete API) and unreviewed (bypasses the
  `auto_approve: false` review gate — see Hazards below).
- **Dry-run before real write**: `sapience-remember.sh --subject S --value V --dry-run` exits 0
  and prints the request body (provenance carrying `[repo:<slug>]`, token redacted) without
  making a network call; `postflight-sapience-notes.sh --dry-run` propagates `--dry-run` into
  every per-note call it issues. Verify the dry-run output before the first real rollout, and
  after any change to the call site, rather than discovering a defect from a landed, permanent
  write.
- **Degrade rule**: a failed `sapience-remember.sh` call (non-zero exit, a `gated >= 1` or
  non-empty `set_aside` response, or `written: 0`) is mirrored by `postflight-sapience-notes.sh`
  as one `infrastructure/transport unavailable` issue row per failed note, and the loop
  continues to the remaining notes — it never fails the postflight step, never blocks the
  `[IMPLEMENTING]` -> `[COMPLETED]` status transition, and never retries automatically (a retry
  of a write that failed the noise gate is not expected to succeed differently).

## No Lifecycle Hook

A `hooks.postflight` manifest entry was considered and rejected: `skill-base.sh`'s
`skill_get_extension_dir()` gates hook resolution on `[ -n "$ext_task_type" ] && [
"$ext_task_type" = "$task_type" ]`, and this extension declares no `task_type` at all (it is
deliberately typeless, applying to every task regardless of domain), so the hook path fails the
`-n` test unconditionally and silently — it can never fire. This is not a gap to close; it is why
the write site instead lives in a script the core completion paths invoke directly, sidestepping
extension-hook dispatch entirely rather than depending on it.

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
  hatch, not part of the normal write path). `--reap` is a third, cross-project standalone
  action: it removes `.mcpServers.sapience` from every `.projects[<path>]` row whose `<path>` is
  no longer a directory on disk, touching no other key — see "The Orphan Reaper" below.
- **`hooks/sapience-mcp-register-project.sh`** — a bidirectional `SessionStart` hook, now
  preceded on every invocation by the ungated reap pass described below. For the per-repo half:
  when the session's repo shows `extensions.sapience.status == "active"` in its own
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

**The Orphan Reaper (`--reap`).** The bidirectional register/remove pair above shares one
structural blind spot: both halves are gated on resolving the CURRENT session's own
`.claude-extensions.json`, a precondition a project directory that has since been deleted or
renamed can never again satisfy. Its removal branch only ever fires for a path that still
exists on disk AND still carries a manifest showing the extension inactive — a vanished
repository can do neither, so its `.projects[<path>].mcpServers.sapience` entry would otherwise
leak in `~/.claude.json` forever. The writer's `--reap` mode closes this from the one place that
CAN see every registered path at once (the writer itself, which already owns every
`~/.claude.json` mutation): it removes ONLY `.mcpServers.sapience` from every
`.projects[<path>]` row whose `<path>` is not a directory on disk, leaving every other key on
that row (another registered server, e.g. `lean-lsp`; the row's session/history/cost metadata)
and every other `.projects` row untouched. The hook invokes `--reap` unconditionally, before and
independent of its own manifest-reachability branch, on every session start in every
repository — because the only session that can ever clean up after a vanished repo is some
OTHER, still-living session, never the vanished repo's own. Two accepted edge cases, documented
rather than engineered around: a row left with `"mcpServers": {}` after reaping `sapience` stays
that way rather than having its whole project row deleted (the row still carries unrelated
session/history/cost metadata a row deletion would discard); and a path that exists on disk but
is unreadable or unmounted reads as absent and is reaped anyway — accepted because this is
self-healing, since the next session start in that repo re-registers the entry via the hook's
own register branch.

**Narrower divergence from the lean model.** Lean's own installer writes both registration
targets itself: `$HOME/.claude/settings.json` directly, and
`$HOME/.dotfiles/config/claude/settings.json` as a durable second target. This extension's
installer writes only the first: it is forbidden to touch any `.dotfiles` file, so it never
becomes the writer of the second target itself. Durability across a `home-manager switch` is
supplied instead by a companion-owned `SessionStart` entry in
`$HOME/.dotfiles/config/claude/settings.json`, written by that other repository's own
home-manager activation and merged into the enforced `hooks` key on every switch -- a second,
independent writer converging on the identical command string, rather than this extension's own
installer taking on a second write target. See the durability detail below.

## Worktree Resolution and the Two-Channel Asymmetry

A session running in a LINKED GIT WORKTREE (for example a throwaway automated checkout of a
repository, used to execute one isolated unit of work against it) reaches two structurally
different Sapience channels, and this extension treats them asymmetrically on purpose.

**Channel 2 (MCP retrieval) is deliberately made to reach a worktree.** Registration keys on the
PARENT CHECKOUT, never the worktree: the hook, the verifier, and the three
`[repo:<slug>]` provenance sites (`scripts/sapience-retrieve.sh`, `scripts/sapience-remember.sh`,
`scripts/verify-sapience-context-scoping.sh`) all resolve a linked worktree to its checkout's
git toplevel before deciding activation or deriving the repo slug. Claude Code's own
`~/.claude.json` per-project lookup already resolves a worktree path (at any nesting depth) to
its checkout's `.projects[<checkout>]` entry, so no worktree-keyed entry is ever written and
none ever needs retracting at teardown — there is nothing worktree-specific to retract, by
construction, not by a teardown mechanism this extension had to build. A query or a write issued
from inside the worktree therefore addresses exactly the same `[repo:<slug>]` knowledge objects
the checkout itself would.

**Channel 1 (hook-injected context: `SessionStart`, `UserPromptSubmit`, `PreToolUse`) is
deliberately left absent from a worktree, and this is a PROHIBITION, not a known gap awaiting a
fix.** Every hook and permission grant this extension owns reaches a repository only through
`settings-fragment.json` merged into THAT repository's own `.claude/settings.local.json`,
rendered by the regular deploy/merge mechanism. A fresh linked worktree has no `.claude/` tree
of its own at all, so this channel is already structurally absent there — nothing in this
extension may be changed to extend the merge engine, the hooks, or the permission grants into a
worktree. The reason is not merely that the channel is inconvenient to scope: `Foreclosure 2` in
`injection-site-scoping.md` establishes that `POST /v1/cli/context`'s response carries no
per-item attribution a local wrapper could filter or label by, so even a hypothetical
project-aware filter on that endpoint would have nothing to key on. A session driven by someone
else's work item, firing those hooks, would receive cross-repository and personal-vault content
inside work it did not originate — reopening that hazard to "fix" the worktree's missing hooks
would defeat the reason this channel is scoped at all.

**The `--strict-mcp-config` caveat.** An automated card-execution subprocess that passes
`--strict-mcp-config` together with an empty `--mcp-config` sees zero MCP servers regardless of
what this extension registers, because that flag combination refuses every MCP server before
`~/.claude.json` is ever consulted. The worktree-resolution fix above is necessary and sufficient
for every OTHER session shape started in that worktree; the automated subprocess's own exclusion
is a property of how it invokes its own session, is vendor-owned and out of this repository's
filesystem, and is recorded here rather than closed.

## Hazards

**The `SessionStart` MCP-registration hook is durable across a `home-manager switch`.** `hooks`
is a home-manager ENFORCED key (`~/.dotfiles/modules/home/core/dotfiles.nix`'s
`[_NOTE,env,hooks,model,permissions,statusLine]` set). `~/.dotfiles`'s own
`config/claude/settings.json` carries a companion-owned `SessionStart` entry invoking this same
hook, independently of this extension's own installer, and that entry is what the enforced
`hooks` key preserves on every switch. This extension's installer writes the byte-identical
command string directly to `$HOME/.claude/settings.json`; because both writers converge on the
exact same command string, re-running the installer after a switch reports a no-op rather than a
double registration. `verify-sapience-mcp.sh`'s check (d) confirms the entry's continued presence
in the live file.

**There is no delete API.** `DELETE /v1/ko/<hash>`, `DELETE /v1/kos/<hash>`, and `POST
/v1/ko/<hash>/delete` all return 404 on this vault. Every write through `sapience-remember.sh` is
therefore permanent; the only remedy is manual removal in the web app at app.spnc.ai. This shapes
how much gets written per task: few, high-value, well-formed notes at a task boundary, never a
write per decision.

**Writes through this path bypass the `auto_approve: false` review gate entirely.** That gate (see
`review-gate-boundary.md`) governs only the transcript-extraction path (`~/.sapience/extract_local.py`).
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
3. **Untagged by default, but taggable before review.** Transcript extraction runs through
   `~/.sapience/extract_local.py`, selected by `~/.sapience/config.json`'s `"backend":
   "anthropic"` key, which stages newly-extracted knowledge objects into
   `~/.sapience/pending_kos.jsonl` carrying no `provenance` field at all. `sapience review`'s
   posting path -- `review_queue()` passing each record through `_strip_meta()` (which removes
   only the underscore-prefixed `_hash`/`_staged_at` bookkeeping fields, with no re-redaction and
   no field re-derivation) and into `post_kos()` -- sends `provenance` to `POST /ingest-kos`
   exactly as it stands in the ledger, the same mechanism `sapience-remember.sh`'s tagged writes
   already rely on, reached here from the review path instead of a direct script call.
   `scripts/sapience-tag-pending.sh` occupies the one window where a repo tag can still be added
   to this population: after `sapience sync` stages a record into `pending_kos.jsonl` and before
   `sapience review` posts it, this script rewrites `provenance` to carry the literal
   `[repo:<slug>]` substring, resolving the slug the identical way
   `capture.projects[].name` -> `path_prefix` -> `resolve_checkout_toplevel()` -> `basename`.
   A record that passes through this window untouched -- captured, synced, and reviewed with no
   intervening tagging pass -- lands in the vault exactly as it always has: untagged, and, since
   there is no update or delete API (see "There is no delete API" above), permanently so. A
   repository never reaches this population at all unless its path is ALSO opted into capture:
   extraction is gated by `~/.sapience/config.json`'s `capture.projects[].enabled`, a SEPARATE
   opt-in list keyed by `path_prefix` (longest-prefix-wins, mirroring
   `~/.sapience/sapience_capture.py`'s `for_cwd()`) that is UNCONNECTED to this extension's own
   activation state -- a repository with no matching entry, or a matching entry with `enabled:
   false`, never reaches `extract_local.py`'s per-record `project` field at all, because the
   opt-in gate short-circuits before extraction runs. `scripts/verify-sapience-mcp.sh`'s check
   (i) reports this coupling for the current project, scoped to the single path it resolves; see
   that check's own inline comment and the "Capture/Activation Reconciliation" subsection below
   for the ruling on who, if anyone, should write `enabled` on this list.
4. **Belongs to no repository.** Documents shared by other people (provenance of the form
   `people <name> | shared by <name> <timestamp> | doc {...}`). Out of scope by construction:
   there is no repo to tag them with.

Populations 3 and 4 are a documented asymmetry, not a defect this design attempts to fix: no
mechanism available to this repository can tag either one. Population 2 is the one this
extension's own surfaces can and do control.

### Operational Sequencing for Pending-Ledger Tagging

`scripts/sapience-tag-pending.sh` has exactly one correct place in the three-step capture flow:
`sapience sync` (stages newly-captured records into `~/.sapience/pending_kos.jsonl`), then this
script with `--write` (rewrites `provenance` to carry `[repo:<slug>]` for every still-pending,
resolvable record -- its default, flag-free invocation is a dry-run that only prints a
per-project summary), then `sapience review`/`sapience review --all` (posts the now-tagged
records to `POST /ingest-kos`). The tag has to land in that middle step: once `sapience review`
posts a record, its `provenance` -- tagged or not -- is permanent, because the vault's KO
surface offers create (`/ingest-kos`) and read (`/v1/search`, `/v1/ko/subjects`) only, with no
update and no delete endpoint (see "There is no delete API" above). A record already posted
without the tag therefore stays untagged permanently; the only remedy is manual removal in the
web app at app.spnc.ai, which deletes the record rather than retagging it.

The one empirical confirmation that a tag survives the full `sapience review` round trip -- tag
a record, post it, then confirm it is retrievable via `scripts/sapience-retrieve.sh`'s
`source=[repo:<slug>]` filter -- is an OPERATOR step, never an agent one: `sapience review` is a
user-driven launcher surface and every post through it is permanent, so no agent in this
repository performs this confirmation on the operator's behalf.

### Capture/Activation Reconciliation

This source store stops at `verify-sapience-mcp.sh`'s check (i) and does NOT write
`capture.projects[].enabled` from either the `SessionStart` registration hook or the installer.
Two reasons: (1) no script in this extension reads or writes the `capture` key today, so adding
a writer here would be new, unreviewed surface rather than a fix to an existing one; (2)
`~/.dotfiles` already owns a capture-map writer, so a second independent writer in this source
store would create the two-writers-disagreeing hazard the Hazards census above already warns
about for the MCP-registration entry -- where byte-identical convergence across writers is
deliberately maintained and no equivalent guarantee would exist here. If active reconciliation
between extension activation and capture enablement is built at all, it belongs in
`~/.dotfiles`, per `rules/source-store-deploy-boundary.md`'s task-siting rule. The capture-map
`enabled` list and the extraction-scheduling lever below share this same `~/.dotfiles` owner --
see the "Capture Scheduling and the Manual-Only Trigger" subsection for the second lever.

**The primary-session hook path has no scoping mechanism at all, independent of tagging
state.** `SessionStart`, `UserPromptSubmit`, and `PreToolUse` never read `provenance` and never
call `/v1/search` — they call `GET /briefing`/`GET /v1/outstanding` or `POST /v1/cli/context`,
and the latter's `project` field is measured to be ignored by the server. A `[repo:nvim]`-tagged
knowledge object is therefore exactly as visible to another repository's `UserPromptSubmit` hook
as an untagged one: tagging a write more thoroughly has zero effect on what these three hooks
inject, in either direction. This is a read-path gap, not a fifth write population — it sits
beside the four-population census above rather than changing it. See
`domain/injection-site-scoping.md` for the full measurement.

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

### Capture Scheduling and the Manual-Only Trigger

Transcript capture extraction -- turning a captured transcript into the knowledge objects that
land in `~/.sapience/extracted.json` and `~/.sapience/pending_kos.jsonl` -- is driven entirely by
manual invocation of the nix-provided `sapience` launcher. Its `review`, `pending`, `sync`,
`coverage`, and `backfill` subcommands each `exec` straight into
`~/.sapience/extract_local.py --<verb>`; no script in this repository, and no script anywhere in
this source store, calls `extract_local.py` or schedules a call to it.

The only scheduling lever that exists is `services.sapience.backgroundSync` in
`~/.dotfiles/modules/home/services/sapience.nix`, which defaults to `false` with the module's own
recorded cost rationale: extraction spends real money or real CPU on every run, so the module
does not run it unattended by default. The module always defines a
`systemd.user.timers.sapience-sync` unit, but installs it only when `backgroundSync` is `true`
(`lib.mkIf cfg.backgroundSync`); with the default `false`, the timer is defined but never
installed, and no other systemd user timer or crontab entry drives this pipeline.

**Consequence for a future reader**: a staleness gap in `extracted.json`/`pending_kos.jsonl` --
their mtimes unchanged since the last manual `sapience <verb>` invocation -- is not a defect of
this extension and is not evidence that anything here is broken. Diagnose it from this section
first: check whether `backgroundSync` is enabled in `~/.dotfiles`, and if not, the gap is fully
explained by "nobody has run `sapience sync`/`review`/etc. since that date," not by a failure
anywhere in this source store's own scripts. Enabling scheduled extraction is the user's call,
made in `~/.dotfiles`, outside this repository's write surface; this section documents the
mechanism and its owner so that choice does not need to be re-discovered by live measurement each
time the question comes up.

## The Repo-Link Mechanism

A repository binds to a Sapience project through `scripts/sapience-project-bind.sh`, which writes
the repository's own `.sapience/project.json` and, on the bind path, registers that binding with
the server through `POST /v1/people/projects/<cid>/link`. This section documents the file format,
the listing endpoint's real response shape, the link route's gate order and its two named
non-success outcomes, and the vendor-delegation rule.

### The Three-Key File and Its Serializer

`.sapience/project.json` holds exactly three string keys, in order `project` (the channel cid),
`name` (the project's display name), and `repo` (this repository's short name) — two-space
indent, one trailing newline, no fourth key. This is byte-identical to the server's own
`repo_link.py` `link_text()` serializer, and `write_link_file()` in `sapience-project-bind.sh` is
the file's sole writer on every path — create, bind success, bind-404, and the
vendor-delegated bind's read-back normalization all route through it, so the on-disk bytes are
one script's canonical rendering regardless of which path produced them. The server's own
`parse_link` refuses any dict carrying a token/key/secret/password-shaped key, and refuses a
`repo` value that fails `^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$` or that looks path-shaped — both
checks are mirrored client-side before any write, matching that contract. Multiple repositories
are supported independently: each repository's own binding lives in its own toplevel's
`.sapience/project.json`, one file per repository.

### `GET /v1/people/projects`'s Real Shape

The listing endpoint returns `{ok, candidates, shared, received, invites, ...}` — never
`{projects: [...]}` and never a bare array. The caller's own accepted-or-owned row set is
`(.shared // []) + (.received // []) | map(select(.accepted or .owner))`. Two other call sites in
this extension — `sapience-publish.sh`'s `ko` subcommand and `sapience-vault-read.sh`'s
`notes_cid` resolution — consume this same endpoint with a `has("projects")`-shaped expression
that resolves to `[]` against the real shape; both are out of this task's territory and are
recorded here as a named follow-up rather than fixed.

### Pick, Bind, and Create

`sapience-project-bind.sh` has three modes, selected by which flag is present: no flag lists the
caller's accepted and owned rows (via the row filter above) and exits non-zero, writing and
POSTing nothing; `--project <name|id>` resolves the value to exactly one such row — matched
case-insensitively against `id`, `title`, and `project.key` — and binds this repository to it;
`--name <display name>` creates a fresh project and shares it with a collaborator. Pick and bind
never mutate without `--confirm`; create never mutates without both `--name` and `--confirm`.

### The Link Route's Gate Order and Its Two Named Non-Success Outcomes

`POST /v1/people/projects/<cid>/link` gates, in order: the write-permission check (401), the
`repo_link.enabled` feature flag (404), the channel/membership lookup (404), unaccepted
membership (403), then success (200). The two non-success statuses the bind path treats as
distinct, deliberate outcomes rather than uniform failures:

- **404** — either the feature is off for this account or the channel/membership lookup missed;
  the server's own response body differs only in prose between the two, so the client-side policy
  is deliberately safe under either reading. The file is still written (`write_link_file()`
  fires), and the caller is told plainly that the server does not read the file yet — the binding
  is recorded locally only.
- **403** — the caller is not yet an accepted member of the project. Nothing is written; the
  caller is told to join the project first.

Any other non-2xx status, a non-JSON body, or a `2xx` body missing `ok: true` is a loud,
non-zero-exit failure that writes nothing — never a success-shaped guess.

### The Response Trap

The link route's `200` response carries a `project` field, but it is the `{kind, key, name}`
descriptor dict, never the channel cid — unlike the create path's `POST
/v1/people/projects/share` response, whose `.share.id` IS the cid. The bind path never reads a
cid out of the link response at all: the cid it writes is the row's own `id`, captured from the
pick/match step before the POST ever fires.

### Static Vendor-Capability Detection

The installed vendor client (`~/.sapience/sapience_cli.py`) may or may not carry a `link`
subcommand; detection is a static `grep` for the literal string its `link` branch is keyed on,
never a live invocation. The `sapience` binary on `$PATH` cannot stand in for this check or for
the delegation itself: it is a packaged bash wrapper with a fixed `case` table, no `link` branch,
and no fallback into the Python client's own argument parser — delegation and detection both go
straight at `sapience_cli.py` via `python3`, never through `$PATH`.

### D1: Reconciling the 404-Write Requirement With Vendor Delegation

Delegating the bind to a link-capable vendor client and still writing the file on a 404 are not
simultaneously satisfiable by pure delegation — the vendor's own `link` command reports nothing
was written and exits non-zero on a 404, with nothing to write back. The reconciliation: when the
vendor exits 0 and writes a link file, this script reads its three keys back out and re-renders
them through `write_link_file()`, so the on-disk bytes are this script's canonical rendering on
either path — byte-identity between the delegated and the direct-HTTP path is an enforced
invariant, not an assumption about two independent serializers. When the vendor exits non-zero, or
exits 0 with no file written, the bind falls through to the direct HTTP path above, which
classifies the outcome by status code alone. The accepted consequence: against a link-capable
client, a 404 or 403 fires the vendor's own POST and then this script's POST a second time; both
are non-mutating at those statuses, so the duplicate is harmless, and the alternative —
classifying on the vendor's own stdout/stderr prose — is never done anywhere in this mechanism.
