# Research Report: Task #648

**Task**: 648 - Add the four Sapience write-surface publishers with loud-failure discipline
**Started**: 2026-11-19T10:55:56Z
**Completed**: 2026-11-19T11:30:00Z
**Effort**: medium (one new script, four publisher subcommands, one new test suite)
**Dependencies**: 647 (sapience-project-binding-and-vault-read) — COMPLETE; `scripts/lib/sapience-api-lib.sh` and `scripts/sapience-project-bind.sh` already exist in the source store and were read in full during this research pass
**Sources/Inputs**: Codebase (`agent-system/extensions/sapience/**`), live-verified server source (`/home/benjamin/Projects/Sapience/sapience-app/brain_server.py`, `repo_link.py`), installed client (`~/.sapience/extract_local.py`), `specs/state.json` task record, dispatch file
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dependency task (647) already delivered `scripts/lib/sapience-api-lib.sh` (host/token
  resolution, `sapience_post`/`sapience_get`, `SAPIENCE_DRY_RUN=1` redaction) and
  `scripts/sapience-project-bind.sh` (the worktree-checkout-resolution block, the
  `.sapience/project.json` binding writer, loud-failure conventions). `sapience-publish.sh`
  should source the library exactly as `sapience-project-bind.sh` and `sapience-vault-read.sh`
  already do, and copy the byte-identical marker block only if it needs repo-root resolution.
- Three of the four publishers (doc-comment, doc-version, DM) need **no** repo-root resolution
  at all — they take a slug/person-id argument and POST directly. Only the fourth
  (repo-tagged KO) needs repo-root resolution, and only to find `.sapience/project.json`.
- **Significant finding**: `.sapience/project.json` (as written by `sapience-project-bind.sh`,
  confirmed by reading `repo_link.py`'s `parse_link`) stores exactly three keys —
  `project` (the server-minted channel **cid**, e.g. `mEdYrFW_qClSGDfx`), `name`, `repo` — and
  **cannot** store a fourth `key` field: `parse_link`'s `_SECRET_KEY_RE` guard rejects any dict
  key that looks secret/credential-shaped, and `key` matches that pattern. But the KO tag the
  client-side `_ko_matches_channel`/`channel_push_matching` logic in `extract_local.py` reads
  (`ko['project']`) is compared against a channel's **`workstream`** value — a short slug like
  `oliver-ben`, not the cid `mEdYrFW_qClSGDfx`. So "the bound project key" the task description
  asks the KO publisher to stamp is **not available in the binding file** and must be resolved
  at runtime via `GET /v1/people/projects`, matching the binding's `.project` cid against that
  list's own cid field to recover `.key`. This is a required design decision for the plan phase,
  not a detail the implementer can discover by re-reading the binding file alone.
- The 409 `head_moved` contract for doc-version writes, the `can_edit:false` → `people_propose`
  → HTTP 202 branch, and the `share_gone` 404-on-create-for-`shared-*` refusal are all confirmed
  directly in `brain_server.py`'s `_docs_save` handler (lines ~52165–52222); the publisher must
  surface all three distinctly rather than collapsing them into one generic failure.
- The `/sapience` command and its "approval picker" mentioned as this task's motivation do not
  exist yet anywhere in the repository (`grep` across `agent-system/extensions/sapience/` and
  `.claude/commands/` finds zero hits besides this task's own description). This task's file
  scope is exactly `scripts/sapience-publish.sh` + its test file — the picker is a separate,
  future consumer, not something this dispatch builds or needs to stub.
- `scripts/tests/test-sapience-mcp-registration.sh`'s Case 30 "lockstep guard" currently
  enumerates seven files that must carry a byte-identical `sapience-worktree-checkout-resolution`
  block. `sapience-publish.sh` will be an eighth copy of that same block (needed only by its
  repo-tagged-KO subcommand) but is **not** in this task's `file_scope`, so Case 30's array
  cannot be extended within this task without widening scope. Recommended resolution below.

## Context & Scope

Task 648 adds one new script, `scripts/sapience-publish.sh`, under
`agent-system/extensions/sapience/` (the source store — confirmed as
`.extensions.sapience.source_dir` in `.claude-extensions.json`, never the deployed
`.claude/**` tree per `rules/source-store-deploy-boundary.md`), plus
`scripts/tests/test-sapience-publish.sh`. The script exposes four write-surface publishers
(doc comment, doc version, direct message, repo-tagged knowledge-object) behind one entry
point, so a not-yet-built `/sapience` approval picker will have concrete, loud-failure,
dry-run-capable subcommands to call. This research pass re-derived the task's contract claims
directly against the dependency task's delivered scripts and against the live Sapience server
source, rather than trusting the dispatch's own paraphrase, per the Scope Hypothesis caution
recorded in this session's injected memory (stale research claims are a known failure mode in
this codebase).

## Findings

### Codebase Patterns

**`scripts/lib/sapience-api-lib.sh` (dependency deliverable, read in full)** — the shared
host/token resolution library every new write surface should build on:
- `sapience_api_init` resolves `$sapience_host`/`$sapience_token` into the *caller's* shell
  (sourced, not subshelled) with the exact precedence this task's constraint 4 names:
  `SAPIENCE_HOST` env → `~/.sapience/config.json` `.host` → `https://app.spnc.ai` literal;
  `SAPIENCE_TOKEN` env → that file's `.token`. `set -x` is suppressed around the credential
  read even if the caller already had it on.
- `sapience_post "<path>" "<json-body>"` and `sapience_get "<path>" ["<query>"]` are the two
  HTTP primitives. Both support `SAPIENCE_DRY_RUN=1`, printing the exact request (URL with the
  token redacted out of the query string, and for POST the body with `.token` replaced by
  `***REDACTED***` when the body is a JSON object) and making **no network call**. This is the
  literal-payload dry-run constraint 6 asks for — `sapience-publish.sh` does not need to
  reimplement redaction; it only needs to build the right JSON body per subcommand and pass
  `SAPIENCE_DRY_RUN=1` through from its own `--dry-run` flag.
- `sapience_post` leaves the resolved HTTP status in `sapience_api_post_http_status` (set into
  the caller's shell) via a single `curl --write-out`, which is exactly how
  `sapience-project-bind.sh` distinguishes a non-2xx status from a 2xx body carrying a
  failure shape (its case 9 loud-failure check). The doc-version publisher's 409 `head_moved`
  handling should use this same field, not a secondary HTTP call.
- `sapience_get` folds in the bounded one-retry-on-cold-start (`HTTP 503` + `starting:true`)
  behavior already proven in `sapience-retrieve.sh`. Any GET the KO publisher needs (e.g. the
  `GET /v1/people/projects` key-resolution call below) gets this for free.

**`scripts/sapience-project-bind.sh` (dependency deliverable, read in full)** — the template
to copy for structure, flag parsing, loud-failure phrasing, and the test suite shape:
- Sources `lib/common.sh` for `common_repo_root`, then `. "${SCRIPT_DIR}/deploy-root-guard.sh"`
  (present only post-deploy or in a test's flattened scratch tree — see Risks below), then
  `source "${SCRIPT_DIR}/lib/sapience-api-lib.sh"`.
- Embeds the marker-delimited `sapience-worktree-checkout-resolution` block verbatim (comment
  block + `resolve_checkout_toplevel()` function), used here only to compute `repo_slug` for
  validation and the `.sapience/project.json` `repo` field.
- Default posture is dry-run; an explicit, separately-named flag (`--confirm`) is required
  before any network call. The dry-run path prints the literal payload via
  `SAPIENCE_DRY_RUN=1 sapience_post ...` — i.e. it reuses the SAME code path that would run for
  real, rather than hand-building a separate preview string. `sapience-publish.sh`'s four
  subcommands should follow this identical shape: build the payload once, then either
  `SAPIENCE_DRY_RUN=1 sapience_post ...` (dry-run) or `sapience_post ...` (confirmed) — never
  two divergent payload-construction code paths.
- Loud-failure checks are written against the **specific confirmed response shape of each
  endpoint** (e.g. `{ok, to, share}` for the project-share call), explicitly contrasted in a
  comment with `sapience-remember.sh`'s different field names (`written`/`gated`/`set_aside`).
  This is the right model for `sapience-publish.sh`: each of the four publishers checks the
  *response shape verified for that specific endpoint* (see per-surface findings below), never
  a one-size-fits-all check borrowed from a different endpoint.
- Writes `.sapience/project.json` with `jq -n --arg ... '{project: $project, name: $name, repo: $repo}'`
  — exactly three keys, in that order, 2-space `jq` default indent, trailing newline. Confirmed
  byte-identical to `repo_link.py`'s `link_text()` serializer by the dependency task's own test
  case 7 (`cmp -s` against a `json.dumps(..., indent=2, sort_keys=False)` fixture).

**`scripts/sapience-remember.sh` (existing script, read in full)** — the canonical loud-failure
template for an `/ingest-kos` call specifically (as opposed to `sapience-project-bind.sh`'s
`/v1/people/projects/share` call):
- Checks, in this order, regardless of which fires first in server logic: `set_aside` non-empty
  → exit 2 (recoverable in the web app, nothing written yet); `gated != 0` → exit 2 (noise
  filter discarded the note; `ok:true` is explicitly NOT treated as success here); `written`
  absent/0 → exit 2 (nothing durably stored); `ok != "true"` → exit 2. The repo-tagged KO
  publisher in `sapience-publish.sh` must reuse this exact four-check order and exit-code
  convention (constraint 3), not merely "check written > 0".
- `explicit: true` is set unconditionally on every KO it posts, with a comment explaining this
  is what prevents a success-shaped `{"ok":true,"written":0,"gated":1}` silent loss. The new KO
  publisher must do the same.
- Uses `--data "$_body"` and `curl -sS --connect-timeout 3 --max-time 8`, matching
  `sapience-api-lib.sh`'s own `sapience_post` timeouts — consistent with routing the new write
  through the shared library instead of a fifth hand-rolled curl invocation (constraint 4).

**`scripts/sapience-vault-read.sh` (existing script, read in full)** — relevant mainly for two
patterns the KO publisher's project-key resolution should reuse:
- Its own project-notes-cid resolution order (`--project` flag wins, else
  `.sapience/project.json`'s binding, else the sole entry of `/v1/people/projects` when exactly
  one exists, else refuse — never guess among several) is the identical decision shape the new
  KO publisher needs for resolving the project **key** (see Executive Summary finding above):
  read the cid from the binding (or an override flag), then resolve `.key` by matching that cid
  inside a `GET /v1/people/projects` response, refusing loudly if no match is found rather than
  guessing.
- Confirms the `jq -e '(if has("projects") then .projects elif (type == "array") then . else [] end)'`
  defensive unwrap pattern for a vault list response whose exact top-level shape ambiguity this
  codebase has already hit once; the KO publisher's project list parsing should use the same
  defensive unwrap rather than assuming one shape.

**`scripts/tests/test-sapience-project-bind.sh` (existing suite, read in full)** — the template
for `test-sapience-publish.sh`:
- Bootstraps `COMMON_SH` with a two-candidate fallback (`../lib/common.sh` then
  `../../../core/scripts/lib/common.sh`) because this suite lives under the `sapience`
  extension but needs `core`'s shared `lib/common.sh` pre-deploy.
- Resolves the subject script via `common_test_resolve_subject "<name>" "deploy-tree-first"
  <deployed-path> <source-path>` then `common_test_declare_subject`, and does the same for every
  script/library it depends on (`sapience-api-lib.sh`, `deploy-root-guard.sh`, `common.sh`,
  `sapience-remember.sh` in that suite's case) — never reads a single script file ad hoc.
- `build_scratch()` assembles an isolated `<scratch>/.claude/scripts/{sapience-project-bind.sh,
  deploy-root-guard.sh,lib/{common.sh,sapience-api-lib.sh}}` tree plus a scratch git repo, i.e.
  it manually reproduces the **post-deploy flattened layout** so the script under test can find
  `deploy-root-guard.sh` next to itself even though pre-deploy the two files live in different
  extensions' source trees. `test-sapience-publish.sh` needs the identical scaffolding, extended
  with `sapience-remember.sh` present too if the KO publisher's loud-failure checks are tested
  by literal re-invocation rather than by inlining the same checks.
- Installs a minimal inline `curl` stub, PATH-shadowed, dispatching on URL substring via
  `case "$url" in *v1/people\?*) ... ;; *v1/people/projects/share*) ... ;; esac`, driven by
  env-var-configurable response body/code pairs. `test-sapience-publish.sh` needs one stub
  entry per endpoint touched by whichever of the four subcommands a given case exercises
  (`*v1/docs/*/comments*`, a bare `*v1/docs/<slug>*` POST vs the comments suffix, `*v1/people/dm*`,
  `*v1/people/projects*`, `*ingest-kos*`), distinguishing the no-suffix doc-version POST from the
  `/comments` suffix carefully since both match `*v1/docs/*`.
- Verifies the marker-delimited worktree block is byte-identical against a second script's copy
  from *within this suite itself* (its case 14), independent of
  `test-sapience-mcp-registration.sh`'s own Case 30 — i.e. each consuming suite re-asserts the
  lockstep property locally as well as it being asserted globally. `test-sapience-publish.sh`
  should add the equivalent local case against `sapience-remember.sh` (or
  `sapience-project-bind.sh`) if the KO publisher embeds the block.
- Explicitly documents, in a header comment, an *interpretation note* for an ambiguous point in
  its own governing plan's task text (what "refusal without --confirm" means operationally) —
  worth imitating for `sapience-publish.sh`'s test suite given this task's own description
  leaves the project-key-resolution question (see Executive Summary) genuinely open; the
  implementer's resolution of that question should be recorded the same way.

**`rules/sapience-write-path.md`** — the standing rule this task's constraint 1 restates: no
instruction surface under `agent-system/extensions/sapience/**` may name an MCP write tool as a
prescribed write path. `sapience-publish.sh`'s own header comment and `--help` text must avoid
naming `sapience_remember`/`sapience_wrapup`/`sapience_handoff`/`sapience_adddoc` as the thing a
write *should* do (discussing why they are not used, as `per-repo-scoping.md` and
`review-gate-boundary.md` already do, remains permitted).

### External Resources (live server source, verified against the running app)

All four endpoints were independently re-confirmed in `brain_server.py` during this research
pass, beyond the dispatch's own paraphrase:

1. **Doc comment** — `_docs_comments_post` (`brain_server.py` ~52526–52587):
   `DOC_COMMENT_MAX = 4000` (confirmed at line 25859); a body over that length is rejected
   `413 {"error": "comment over 4000 chars"}` *before* any write; a successful post calls
   `people_after_comment(tok, head, out, quote, mentions)`, which the dispatch's
   `only_tokens=None when the caller is NOT the channel creator` claim describes. Nothing in
   this handler treats a comment as a document version — confirmed structurally distinct from
   `_docs_save`.

2. **Doc version** — `_docs_save` (`brain_server.py` ~52165–52222), the single most
   consequential handler for this task:
   - Concurrency key is `base_rev` compared against `doc_rev(prev)` (the GET's `rev`, "hash +
     body + provenance digest"), explicitly NOT `base_hash` alone — a legacy/secondary field
     only consulted when `base_rev` is empty, and the inline comment at line 52188 explains
     exactly why `base_hash` alone misses an in-place update that kept the hash. The publisher
     must always send the GET's `rev` value as `base_rev`, never the GET's `hash`.
   - `base_rev == "none"` (the `DOC_BASE_NONE` sentinel) is reserved for "the editor opened this
     slug when it did not exist yet" — this is **not** a free-form create-with-no-base_rev
     path; sending literally empty `base_rev` against an EXISTING doc with a different
     `base_hash` is also checked (`moved` is true if `(not base_rev and base_hash and base_hash
     != prev['hash'])`), so there is no way to skip concurrency checking by simply omitting
     `base_rev`.
   - On a move: `409 {"error": "...", "code": "head_moved", "head": {...fields..., "body":
     prev_body[:DOC_BODY_MAX]}}` — confirming the dispatch's claim that the conflicting head
     (including its body) is returned, not just a bare code, so a publisher surfacing this to a
     human has the colliding content immediately, without a second GET.
   - The `can_edit:false` branch is exactly: `if prev and (prev.get('share') or {}).get('id')
     and not (prev.get('share') or {}).get('can_edit') and prev.get('kind') != 'chat':` → calls
     `people_propose`, replies with `202 if st == 200 else st`. The `kind != 'chat'` exclusion
     means a chat/DM-kind doc is never routed through `people_propose` even when shared —
     relevant because the DM publisher (surface 3) posts comments onto a `kind:'chat'` doc, and
     that path is confirmed to always go through `doc_comment_add`/`people_after_comment`
     (`op in ('comment', 'chat-msg')` branch, line 27257), never through this propose branch.
   - A `shared-*` slug with no existing document and a non-empty `base_rev`/`base_hash` returns
     `404 {"error": "that shared document was withdrawn; nothing was written", "code":
     "share_gone"}` (confirmed line 52203–52204, gated by `PEOPLE_COPY_SLUG_RE =
     re.compile(r'^shared-[0-9a-f]{8}-')`) — confirming there is genuinely no create-on-write
     path for a shared slug, exactly as the dispatch states.
   - `DOC_SLUG_RE = re.compile(r'^[a-z0-9][a-z0-9._-]{0,79}$')` and `DOC_BODY_MAX = 200000` are
     both enforced server-side before any write; the publisher can pre-validate against the same
     pattern/bound to fail fast and avoid a round trip for an obviously-invalid slug or an
     oversized body, but must not treat local validation as a substitute for handling the
     server's own 400/413 response.

3. **Direct message** — `_people_dm_new` (`brain_server.py` ~58236) handles
   `POST /v1/people/dm {to: <person id>} | {space: <space id>, member: <member id>}`; confirmed
   route table entry at line 49720 carries the exact 2026-11-14 APP_OVERHAUL_FOR gating note the
   dispatch cites. The conversation itself is `kind:'chat'`, and every subsequent message is
   posted as a comment whose `op` resolves to `'chat-msg'` for a `kind:'chat'` head (line 27358:
   `op = 'chat-msg' if head.get('kind') == 'chat' else 'comment'`) — i.e. the DM publisher's
   second call is the *same* `POST /v1/docs/<slug>/comments` endpoint the doc-comment publisher
   (surface 1) already implements; surfaces 1 and 3 should share one internal "post a comment to
   slug X" helper function inside `sapience-publish.sh` rather than duplicating the comment-POST
   logic.

4. **Repo-tagged KO** — `_ingest_kos` (`brain_server.py` ~50658) confirmed reply shape
   `{"ok": True, "written": written, "threads": threads, "gated": len(noise), "rejected":
   rejected, "filtered": n_valid - len(valid)}`, plus conditionally `set_aside`/`staged`/
   `switched_off`/`project_contributed` — matching the dispatch's `{written, threads, spend,
   filtered, staged}` description closely enough but with `spend` not actually present in this
   handler (the dispatch's field list appears to be a close paraphrase; `rejected` is the field
   actually present alongside `written`/`threads`/`gated`/`filtered` that the dispatch's list
   omits). **The publisher's loud-failure check must be written against the fields actually
   read here** (`set_aside`, `gated`, `written`, `ok` — identical to `sapience-remember.sh`'s
   own check, which this research confirms is already written against this exact handler),
   not against the dispatch's slightly-paraphrased field list.
   - `project_cid` (the dead, `REPO_LINK_FOR`-gated path) is handled entirely separately from
     the KO's own `project` field: `_project_stamp(ko, proj)` *overwrites* `ko['project']`
     unconditionally when a verified `project_cid` is supplied — confirming that if
     `project_cid` is ever sent without being server-verified as this token's own project, any
     client-set `ko['project']` value would be silently discarded. Since `project_cid` is
     confirmed dark for this token (dispatch's own two-probe confirmation, independently
     re-checked via `project_cid_verify`'s source at line 28308), the publisher should **never
     send `project_cid`** — only the per-KO `project` field — so today's write is never at risk
     of being silently overwritten by a verification path that cannot succeed anyway.
   - `_ko_matches_channel(k, workstream)` (confirmed in `~/.sapience/extract_local.py`,
     lines 1317–1321) is the **only** consumer of a client-set `ko['project']` value today, and
     it is strictly local-client logic (`channel_push_matching`, called only from
     `extract_local.py`'s own sync/review call sites) — never reached by `/ingest-kos` writes,
     confirming the dispatch's "dead path" framing precisely: today's publisher write is inert
     for channel-forwarding purposes and becomes live automatically the day either
     `REPO_LINK_FOR` is enabled for this token or `/ingest-kos`-originated KOs start flowing
     back through a local sync pass that evaluates `channel_push_matching` against them.

### Live Reference Value Re-Verification

The dispatch's "LIVE REFERENCE VALUES" section states the Oliver+Ben project's key is
`oliver-ben` for cid `mEdYrFW_qClSGDfx`. This research did not re-run a live GET against
`app.spnc.ai` (no new vault writes or reads were performed; this pass is codebase/source
research only, consistent with the dispatch's instruction that nothing be written to the vault
during verification). The cid→key relationship is taken as already live-verified by the
dispatch author; this report's contribution is identifying *mechanically* (via
`repo_link.py`'s `parse_link`/`_SECRET_KEY_RE` and `.sapience/project.json`'s three-key shape)
that the key cannot be read from the local binding file and must be resolved via a fresh
`GET /v1/people/projects` call at publish time — a design constraint, not a value to hardcode
(matching the dispatch's own "discover at runtime, NEVER hardcode" instruction).

## Recommendations

1. **Structure `sapience-publish.sh` as one script with four subcommands**
   (`doc-comment`, `doc-version`, `dm`, `ko`), each taking `--dry-run` or `--confirm`
   (mirroring `sapience-project-bind.sh`'s explicit-confirm default-dry-run posture — constraint
   6 requires a dry-run on every publisher, and the existing two-script precedent already
   settles "confirm-required, dry-run-default" as this extension's house style for an
   outward-facing write). Source `lib/common.sh`, `deploy-root-guard.sh`, and
   `lib/sapience-api-lib.sh` exactly as `sapience-project-bind.sh` does.

2. **Embed the worktree-checkout-resolution marker block only in the `ko` subcommand's code
   path** (or, more simply, embed it once at the top of the script since bash has no
   subcommand-scoped sourcing cost worth avoiding) — it is needed solely to resolve
   `.sapience/project.json`'s location. The other three subcommands need no repo-root
   resolution at all.

3. **Resolve the KO publisher's project `key` at runtime**, not from the binding file: read
   `.sapience/project.json`'s `.project` (cid), call `sapience_get "/v1/people/projects"`,
   defensively unwrap the response the way `sapience-vault-read.sh` already does, and find the
   entry whose cid matches; refuse loudly (non-zero exit, no write) if no match is found or if
   no binding exists at all — never fall back to an unqualified/untagged KO write silently, and
   never guess a key from the binding's `name` field (which is a free-text display name, not a
   slug — `sapience-project-bind.sh`'s own key derivation shows `name` and `key` can diverge,
   e.g. spaces/case).

4. **Give the doc-version publisher three distinct exit paths**, not one generic failure: (a)
   `409 head_moved` → print the returned `head` object (including its body) and exit non-zero
   without retrying or overwriting; (b) `202` from the `can_edit:false` route → exit 0 but with
   a message distinguishing "proposed, awaiting owner" from "saved directly" (the publisher's
   caller, i.e. the future `/sapience` picker, needs to tell these apart); (c) `404 share_gone`
   → exit non-zero with a message stating the shared slug cannot be created. Always send the
   GET's `rev` as `base_rev` (never `hash`), fetched by the publisher itself via one
   `sapience_get "/v1/docs/<slug>"` call immediately before the write, so the caller never has
   to supply `base_rev` manually and race a stale value.

5. **Share one internal comment-POST helper between the `doc-comment` and `dm` subcommands** —
   confirmed structurally identical server-side (`op in ('comment', 'chat-msg')` collapses to
   the same `doc_comment_add`/`people_after_comment` call). The `dm` subcommand's only extra
   step is the preceding `POST /v1/people/dm {to: "<person id>"}` to obtain/reuse the
   conversation slug.

6. **For the `ko` subcommand, reuse `sapience-remember.sh`'s four-check loud-failure order
   verbatim** (`set_aside` → `gated` → `written` → `ok`), set `explicit: true` unconditionally,
   and never send `project_cid` (only the per-KO `project` field) given the confirmed-dark
   `REPO_LINK_FOR` state. Treat the existing 3–8-note postflight bound as the only size bound
   (constraint 2) — do not add a second, independently-sized cap inside this script.

7. **`test-sapience-mcp-registration.sh`'s Case 30 lockstep array is out of this task's
   `file_scope`.** Recommend one of two explicit resolutions, decided at plan time rather than
   left implicit: (a) widen this task's `file_scope` by one file to add `sapience-publish.sh` to
   that array (small, mechanical, keeps the global guard complete), or (b) deliberately leave it
   out and record that decision plus its risk (an eighth copy of the block could silently drift
   with no mechanical catch outside `test-sapience-publish.sh`'s own local case) in the plan's
   Decisions section, matching how `test-sapience-project-bind.sh` already carries its own local
   Case 14 as a second line of defense. Re-deriving the file against the corpus at plan time
   (per `report-format.md`'s Carried-Figure Discipline): the array is a 5-line bash literal, so
   either resolution is a single, low-risk edit — this is not a reason to prefer (b) over (a) on
   cost grounds; the choice should rest on whether the plan author wants to touch a file this
   task's description did not name.

8. **Do not build or stub the `/sapience` command or its approval picker.** It does not exist
   anywhere in the repository today and is not in this task's file scope; the publisher script
   is a library of callable subcommands for that future consumer, nothing more.

## Decisions

- Confirmed this task's dependency (647: project-binding-and-vault-read) is complete and its
  two deliverables (`sapience-api-lib.sh`, `sapience-project-bind.sh`) are the correct and only
  sourcing targets for shared host/token/HTTP logic — no re-derivation of that logic in the new
  script (constraint 4 satisfied by reuse, not by restatement).
- Decided (research-level, to hand to planning) that the KO publisher's project-key must be
  resolved via a live `GET /v1/people/projects` call keyed on the binding's cid, because the
  binding file structurally cannot carry a `key` field (server-side `parse_link` rejection) —
  this is a load-bearing finding the dispatch text did not spell out and the plan must account
  for explicitly rather than assume the key is locally available.
- Decided the doc-comment and DM-message POST are the same underlying call and should share one
  helper function rather than two near-duplicate implementations.

## Risks & Mitigations

- **Risk**: `deploy-root-guard.sh` does not exist under `agent-system/extensions/sapience/scripts/`
  pre-deploy (it lives only in `agent-system/extensions/core/scripts/`); every existing script in
  this extension sources it via the bare relative path `"${SCRIPT_DIR}/deploy-root-guard.sh"`,
  which only resolves post-deploy once extensions are flattened into one `.claude/scripts/` tree.
  **Mitigation**: this is already the established, working pattern for every sibling script in
  this extension (confirmed in `sapience-project-bind.sh` and `sapience-vault-read.sh`); the test
  suite's `build_scratch()` helper already reproduces the flattened layout for pre-deploy testing.
  `sapience-publish.sh` and its test suite should follow the identical convention, not invent a
  new one.
- **Risk**: the `*v1/docs/*` curl-stub URL pattern in a test suite could accidentally match both
  the doc-version POST (`/v1/docs/<slug>`) and the doc-comments POST
  (`/v1/docs/<slug>/comments`) if cases are not ordered/anchored carefully, silently exercising
  the wrong stub branch. **Mitigation**: order the `case` statement's comments-suffix pattern
  before the bare-slug pattern (shell `case` matches first-listed-first), exactly as a careful
  reading of `test-sapience-project-bind.sh`'s existing stub (which has no such ambiguity, since
  it only ever stubs two disjoint URL shapes) would need extending for; call this out explicitly
  in the new test file's own header comment the way that suite documents its own ambiguity
  resolutions.
- **Risk**: a future enablement of `REPO_LINK_FOR` or a change to `/ingest-kos`'s project-tag
  handling could change what a client-set `ko['project']` value does (today confirmed inert for
  channel-forwarding). **Mitigation**: already addressed by design per the dispatch's own
  instruction — the publisher sends the plain `project` field and never `project_cid`, so it
  needs no code change when the flag flips; this report adds no new mitigation beyond confirming
  the dispatch's instruction is mechanically sound.

## Context Extension Recommendations

- none — this is a `task_type: meta` task operating entirely within an existing, well-documented
  extension (`agent-system/extensions/sapience/`) whose context files (`per-repo-scoping.md`,
  `review-gate-boundary.md`, `sapience-write-path.md`) already cover the relevant conventions in
  depth. No undocumented topic surfaced during this research that would benefit a new context
  file; the one genuinely new finding (the binding file's inability to carry a `key` field) is
  specific to this task's own deliverable and belongs in that script's own header comment, not in
  a standalone context file.

## Appendix

- Search queries / commands used: `jq` queries against `specs/state.json` for task 648/647/651
  records; `grep -n` passes over `brain_server.py` for `doc_comments`, `_docs_save`, `base_rev`,
  `head_moved`, `people_propose`, `PEOPLE_COPY_SLUG_RE`, `_people_dm_new`, `_ingest_kos`,
  `_ko_matches_channel`, `_project_stamp`, `project_cid_verify`, `DOC_SLUG_RE`, `DOC_BODY_MAX`;
  `grep -n` over `~/.sapience/extract_local.py` for `workstream`/`_ko_matches_channel`/
  `channel_push_matching`; full reads of `scripts/lib/sapience-api-lib.sh`,
  `scripts/sapience-remember.sh`, `scripts/sapience-project-bind.sh`,
  `scripts/sapience-vault-read.sh`, `scripts/tests/test-sapience-project-bind.sh`,
  `rules/sapience-write-path.md`, `context/project/sapience/domain/review-gate-boundary.md`;
  `grep -n` over `test-sapience-mcp-registration.sh` for the Case 30 lockstep array.
- References: `agent-system/extensions/sapience/scripts/lib/sapience-api-lib.sh`,
  `agent-system/extensions/sapience/scripts/sapience-project-bind.sh`,
  `agent-system/extensions/sapience/scripts/sapience-remember.sh`,
  `agent-system/extensions/sapience/scripts/sapience-vault-read.sh`,
  `agent-system/extensions/sapience/scripts/tests/test-sapience-project-bind.sh`,
  `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh`,
  `agent-system/extensions/sapience/rules/sapience-write-path.md`,
  `/home/benjamin/Projects/Sapience/sapience-app/brain_server.py`,
  `/home/benjamin/Projects/Sapience/sapience-app/repo_link.py`,
  `/home/benjamin/.sapience/extract_local.py`.
