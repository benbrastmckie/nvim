# Research Report: Task #681

**Task**: 681 - Let the Sapience extension bind a repository to an existing shared project as
well as a new one, and register the repository with the server
**Started**: 2026-11-21
**Completed**: 2026-11-21
**Effort**: medium (one script's new mode, one skill-stage rewrite, two domain-doc updates, one
expanded test suite)
**Dependencies**: None blocking; this task is ordered before
`sapience_automatic_writes_and_retrieval_by_project_id`, which reads the file this task's script
writes.
**Sources/Inputs**:
- Source store: `agent-system/extensions/sapience/scripts/sapience-project-bind.sh`,
  `scripts/lib/sapience-api-lib.sh`, `commands/sapience.md`, `skills/skill-sapience/SKILL.md`,
  `context/project/sapience/domain/per-repo-scoping.md`,
  `context/project/sapience/domain/command-draft-and-picker.md`,
  `scripts/tests/test-sapience-project-bind.sh` (the task's declared territory)
- The actual Sapience server implementation, read directly:
  `/home/benjamin/Projects/Sapience/sapience-app/repo_link.py`,
  `/home/benjamin/Projects/Sapience/sapience-app/brain_server.py` (the real route handlers and
  response shapes, since `.claude/`'s deployed sapience context is marked stale)
- The vendor CLI's dev-source `link_cmd` implementation:
  `/home/benjamin/Projects/Sapience/sapience-app/sapience_cli.py`
- The installed client on this machine: `~/.sapience/sapience_cli.py`, and the NixOS-packaged
  `sapience` binary on `$PATH` (both probed directly, read-only, no mutating calls)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's own factual claims about the server and the vendor CLI all check out against
  the live Sapience server source and the two installed client generations on this machine — but
  two load-bearing details are more specific than the dispatch text states, and get them wrong
  and the new pick-mode breaks silently:
  1. `GET /v1/people/projects`'s real top-level shape is `{ok, candidates, shared, received,
     invites, sources_available, completeness, me}` — **not** `{projects: [...]}` nor a bare
     array. Two existing call sites in this same extension (`sapience-publish.sh`'s `ko`
     subcommand and `sapience-vault-read.sh`'s `notes_cid` resolution) assume the wrong shape
     and are very likely silently broken against the live server today — see Risks.
  2. `POST /v1/people/projects/<cid>/link`'s 200 response's `project` field is the
     `{kind, key, name}` descriptor dict, **not** the channel id — the opposite of what the
     existing create-mode code path extracts from `POST /v1/people/projects/share`'s response
     (`.share.id`). Reusing that extraction idiom for the new bind-existing path would silently
     write a malformed `project.json`.
- The vendor's own `sapience link` (dev-source `link_cmd` in `sapience_cli.py`) already does
  almost exactly what this task asks for pick mode — list `shared ∪ received` filtered to
  `accepted or owner`, match a given name/id case-insensitively, POST the link, write the same
  3-key file — and is a faithful behavioral reference to mirror.
- The vendor CLI **cannot be delegated to through the `sapience` command on `$PATH` at all**: the
  installed NixOS wrapper script dispatches by a fixed `case` statement with no `link` branch and
  no fallback to `sapience_cli.py`'s own argument parser; `sapience link` on this host prints
  "unknown command 'link'" regardless of what the underlying Python file supports. Delegation
  must invoke `python3 "$HOME/.sapience/sapience_cli.py" link ...` directly.
- The installed `~/.sapience/sapience_cli.py` on this machine (1122 lines) genuinely predates
  `link` support — confirmed by direct invocation: it falls through to the generic `cli`
  usage-doc printout, exit 0, no network call. The dev-source version (1334 lines, same
  filename, in the separate `Projects/Sapience/sapience-app` checkout) has it. This is a clean,
  mechanically checkable live instance of exactly the predates/supports split the dispatch names
  — detect it statically (`grep -q "sub == 'link'"`), not by invoking the broken `$PATH` binary.
- One real design tension the dispatch's own two requirements create: the vendor `link_cmd`
  writes **nothing** on a 404 ("linking a repository is not available for your Sapience yet.
  Nothing was written."), while the dispatch's item (3) requires a 404 to still write the file
  and report the degraded state. Pure delegation cannot satisfy both at once — see Risks.

## Context & Scope

Researched the exact mechanics needed to add a second ("bind to an existing project") mode to
`sapience-project-bind.sh` alongside its existing create-only mode, wire repository
registration through the server's repo-link route, and route the whole pick flow through
`/sapience`'s single approval picker rather than as a hard stop. Because `.claude/`'s deployed
`sapience` extension context is stale relative to the source store, all source-store files were
read from `agent-system/extensions/sapience/` directly (per
`.claude/rules/source-store-deploy-boundary.md`), and all server-behavior claims were verified
against the actual Sapience server implementation at
`/home/benjamin/Projects/Sapience/sapience-app/` rather than taken from this extension's own
(possibly stale) design notes — direct reference grounding, not inference from documentation.

## Findings

### Codebase Patterns

**Current `sapience-project-bind.sh` (create-only mode)** — `scripts/sapience-project-bind.sh`:
- `--name "<display>" --confirm [--to <id>]`; default (no `--confirm`) is a dry-run that prints
  the literal `POST /v1/people/projects/share` payload via `SAPIENCE_DRY_RUN=1 sapience_post`
  and exits 0 with no network call at all.
- Resolves the repo's git toplevel via the shared `resolve_checkout_toplevel` marker block
  (byte-identical across `sapience-project-bind.sh`, `sapience-remember.sh`,
  `sapience-retrieve.sh`, `verify-sapience-mcp.sh`, `verify-sapience-context-scoping.sh` — a
  lockstep-guarded copy set that any new copy in this task must join, not fork from).
- Validates the repo short name against `^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$` — this is not an
  invented pattern; it is `repo_link.REPO_NAME_RE` verbatim, confirmed by direct read of
  `repo_link.py`.
- Already sources `scripts/lib/sapience-api-lib.sh` (`sapience_api_init`, `sapience_get`,
  `sapience_post`), so the new mode needs no new credential-resolution code.
- Writes `.sapience/project.json` via `jq -n --arg project ... --arg name ... --arg repo ...
  '{project: $project, name: $name, repo: $repo}' > "$link_file"` — this is already
  byte-identical to `repo_link.link_text()`'s `json.dumps(..., indent=2, sort_keys=False) +
  '\n'` (confirmed: jq's default pretty-print is 2-space indent, trailing newline, same key
  order), and this exact idiom is what the new bind-existing path should reuse verbatim for its
  own write — not a second, hand-rolled JSON construction.
- On `--confirm`'s success path, derives `project_cid` from the **share** response's `.share.id`
  — this is specific to `POST /v1/people/projects/share`'s response shape and must **not** be
  reused for the new link-route's response, whose `project` field is a different shape (see
  "External Resources" below). The new bind-existing code already has the cid in hand from the
  pick step (the chosen project row's own `id`), so it never needs to parse one back out of the
  link response at all.

**`skills/skill-sapience/SKILL.md` Stage 1 (the binding gate)**: today, a repository with no
`.sapience/project.json` is a hard, unattended stop — the skill prints the exact
`sapience-project-bind.sh --name ... --confirm` command the user must run themselves, and
refuses to go further. Item (6) of this task's description requires this to change: the pick
(list-or-choose-existing-project) step must become the **first candidate surface** in the
existing Stage 9 single `AskUserQuestion` approval picker, not a separate unattended write and
not a second picker (Stage 6's collaborator picker is explicitly kept separate from Stage 9 for
the same reason — "D8" in the file — so a bind-pick option folded into Stage 9 is consistent
with that existing design rule, not a new exception to it).

**`commands/sapience.md`**: states the "one approval picker" guarantee and defers every detail
(including, now, the bind-pick surface) to `skill-sapience` and
`command-draft-and-picker.md`. No change to this file's own argument-parsing table is implied by
this task — the bind pick is an internal Stage-1-into-Stage-9 wiring change inside the skill, not
a new `/sapience` flag.

**`context/project/sapience/domain/command-draft-and-picker.md`**: its "Four Candidate Write
Surfaces" table and "The Dark Migration Path" section currently treat the repo-link server
mechanism as entirely dark/future ("a probe carrying a bogus project identifier returned a
normal answer with none of the markers an enabled binding check would add"). That framing
remains literally true for *this account's token* (REPO_LINK_FOR is an env-controlled allowlist
gate — see below — and nothing in this research found evidence this credential is on it), but
once this task's bind-existing mode exists, the route is no longer merely theoretical: it is
called for real, and a 404 is now a documented, handled, named outcome rather than an untested
hypothetical. This file's language will need a light update so a future reader does not read
"The Dark Migration Path" as meaning "untested" once this task lands — the gate itself does not
change, but the code now actively probes it every bind-existing attempt.

**`context/project/sapience/domain/per-repo-scoping.md`**: currently documents per-repo
*knowledge-scoping* (the `[repo:<slug>]` provenance-tag mechanism) and has no section on the
repo-*link* mechanism (`.sapience/project.json`, the `/link` route, `linked_repos`) at all. This
task's description explicitly names this file as in-territory, implying it should gain the
link-route documentation (404/403 semantics, response shape, the pick-vs-create distinction) —
there is currently nothing here to revise, only to add.

### External Resources (ground truth from the live server source)

Read directly from `/home/benjamin/Projects/Sapience/sapience-app/` rather than relied on
secondhand, since this extension's own deployed context is flagged stale:

- **`repo_link.py`** is the server-side module that owns the link file format and the one
  accepted-member rule. Confirms, byte-for-byte: `LINK_REL = '.sapience/project.json'`,
  `REPO_NAME_RE = r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'`, `link_text(cid, name, repo)` producing
  the exact 3-key/2-space-indent/trailing-newline shape the existing script already writes, and
  `REPO_LINK_FOR` as a `cli_context`-style env allowlist (comma/space-separated token prefixes,
  or `'*'`; empty/default = off, and an unlisted token's new routes answer 404 "as if they did
  not exist").
- **`GET /v1/people/projects`** (`brain_server.py`'s `_people_projects` → `project_register` →
  `_project_register_full`): real response is
  `{'ok': True, 'candidates': ..., 'shared': [...], 'received': [...], 'invites': [...],
  'sources_available': ..., 'completeness': ..., 'me': ...}`.
  - `shared` = every project *this token created* (iterates `ch_load()`, appends when
    `ch.get('created_by') == tok`).
  - `received` = every project *shared to this token*, active and not revoked, **regardless of
    whether this token has accepted it yet** (`elif not row['revoked'] and row['active']:
    received.append(row)` — `active` is the caller's own membership-active flag, not
    `accepted`). A pending, not-yet-accepted invite can appear in `received`.
  - Each row is `project_public(ch, tok)`, which layers onto `people_public(ch, tok)`:
    `id` (the channel cid), `title`, `owner` (bool, true iff `created_by == tok`), `accepted`
    (bool: `owner or bool(me.get('accepted'))`), `from` (creator's display name), `members`
    (list), `pending` (names of members who haven't accepted), `project: {kind, key, name}`,
    `linked_repos` (list of repo short names), `linked_repos_detail` (list of
    `{name, by, at}` with `by` always a resolved display name, never a raw token).
  - **Pick-mode filter**: list `shared + received` filtered to `r.get('accepted') or
    r.get('owner')` — this is exactly the filter the dispatch names ("accepted and owned
    projects") and exactly the filter the vendor CLI's own `link_cmd` already applies
    (`rows = [r for r in rows if r.get('accepted') or r.get('owner')]`). A received-but-not-yet-
    accepted invite is correctly excluded by this filter even though it is present in
    `received`.
- **`POST /v1/people/projects/<cid>/link {repo}`** (`_people_project_link` →
  `project_repo_link`): gate order, confirmed from source:
  1. `_docs_write_gate('people_write')` — no/invalid token → the gate's own 401, before this
     route's own logic runs at all.
  2. `repo_link.enabled(tok)` is false (the normal case today, since `REPO_LINK_FOR` is off by
     default and nothing found suggests this account's token is listed) → **`404
     {"error":"not found"}`**, by design indistinguishable from the route not existing.
  3. `_project_link_gate(ch, tok)`: channel not found, or caller not an active member at all →
     **`404 {"error":"no such project share"}`** (same status as (2), different body — a caller
     cannot distinguish "feature off" from "wrong cid" by status code alone, only by body text,
     and even that is not a stable contract to parse on). Caller is an active member but not yet
     `repo_link.accepted_member` (neither creator nor an accepted membership record) →
     **`403 {"error":"join the project first"}`**.
  4. Success → **`200 {"ok": true, "project": {"kind": "project", "key": ..., "name": ...},
     "name": "<display name>"}`**. Critically, this `project` field is the
     project **descriptor dict**, not the cid — `project_public(ch, tok)['project']` is
     `dict(pp.get('project') or {})`. The cid the caller must persist into `project.json` is the
     one it already supplied as `<cid>` in the URL (from the pick step), never something to
     re-derive from this response.
- **Vendor CLI `link_cmd`** (dev-source `sapience_cli.py`, confirmed present and absent from the
  installed copy — see below): implements exactly the behavior above, plus:
  - No argument → lists `title (id)` for every row in the `accepted or owner` filtered set and
    exits 1 (a deliberate non-mutating "show me the choices" exit, matching this task's item (1)
    requirement that a no-project pick mode "exit non-zero without writing").
  - An argument → matches case-insensitively against `id`, `title`, or `project.key` (whichever
    matches exactly one row); no match → named refusal, exit 1.
  - An existing link to a *different* cid, no `--force` → refuses with the exact re-link
    instruction; `--force` overwrites.
  - Repo short name defaults to `os.path.basename(root)`, overridable via `--name`
    (`--name` here is the *repo* short name override, a different meaning from this script's own
    `--name` which today names the *project* being created — worth flagging for the plan so the
    two scripts' flags are not conflated, even though both end up writing a `repo` field).
  - On success, writes the file via `mkstemp` + `os.chmod(0o644)` + `os.replace` — an atomic
    write, same end format as `repo_link.link_text()`.
  - **On 403**: "join the project ... first ... Nothing was written." — matches this task's
    item (3) 403 requirement exactly.
  - **On 404**: "linking a repository is not available for your Sapience yet. Nothing was
    written." — does **not** match this task's item (3) 404 requirement, which wants the file
    written anyway with a degraded-state report. See Risks.

### Vendor Client Version on This Machine (measured, not assumed)

- `~/.sapience/sapience_cli.py` (installed, 1122 lines) has **no** `link` subcommand: directly
  invoking `python3 ~/.sapience/sapience_cli.py link` falls through every `if sub == ...` branch
  in its `main()` and prints the generic `cli` usage-doc block, exit 0, with no network call —
  confirmed by direct invocation during this research.
- The dev-source `/home/benjamin/Projects/Sapience/sapience-app/sapience_cli.py` (1334 lines,
  same filename, a separate checkout) **does** have it (`if sub == 'link': return
  link_cmd(argv[1:])`).
- **The `sapience` binary on `$PATH` cannot be used to detect or invoke this at all**, on this
  machine or in general, independent of which `sapience_cli.py` is installed: it is a
  NixOS-packaged bash wrapper (`~/.nix-profile/bin/sapience`) with a fixed `case "$SUB"` table
  that dispatches to `extract_local.py` or `mcp.py` for its known subcommands and has **no
  `link` branch and no fallback into `sapience_cli.py`'s own argument parser** for an unmatched
  one — confirmed by direct invocation: `sapience link` prints `sapience: unknown command
  'link' (see: sapience help)`, exit 2, regardless of what the underlying `sapience_cli.py`
  supports. Delegation in this task must invoke `python3 "$HOME/.sapience/sapience_cli.py" link
  ...` directly, exactly mirroring this extension's existing convention of invoking
  `~/.sapience/mcp.py`/`sapience_cli.py` directly via `python3` in its hooks rather than through
  the `sapience` command (see e.g. the `SessionEnd`/`Stop` hook commands already merged by
  `.claude-extensions.json`).
- Recommended detection is **static, not a live probe**: `grep -q "sub == 'link'"
  "$HOME/.sapience/sapience_cli.py" 2>/dev/null` (or equivalently `def link_cmd`) distinguishes
  the two generations with no subprocess invocation and no incidental network call. No existing
  script in this extension currently shells into `sapience_cli.py` as a subprocess at all (grep
  across `scripts/*.sh` found zero such call sites) — this is a genuinely new pattern this task
  introduces, not an extension of an existing one, and should be tested against a synthetic
  stub file rather than the real `~/.sapience/sapience_cli.py`.

## Recommendations

1. **New `--project <name-or-id>` / no-argument pick mode in `sapience-project-bind.sh`**, kept
   alongside the existing `--name`/`--confirm` create mode (requirement 2): no argument → `GET
   /v1/people/projects`, filter `shared + received` to `accepted or owner`, print `title (id)`
   per row, exit 1, write nothing (mirrors vendor `link_cmd`'s own no-argument behavior and this
   task's item (1)). `--project <value>` → match case-insensitively against `id`, `title`, or
   `project.key` (reuse the vendor's own three-field match rule verbatim; it is already a good
   rule, not something to redesign).
2. **Reuse the existing `jq -n --arg project ... --arg name ... --arg repo ... '{project: ...,
   name: ..., repo: ...}'` write exactly as-is** for the bind-existing path's successful write —
   do not introduce a second JSON-construction idiom. This is what makes requirement (4)'s
   "byte-identical on either path" provable almost for free: both the HTTP-fallback write and
   the vendor-CLI-delegate write (when the task's own wrapper performs the write rather than
   trusting the vendor CLI's exit code alone — see Risks) go through the identical jq call.
3. **Never reuse the create-path's `.share.id` extraction for the link route's response.** The
   cid for the bind-existing path is already known (the picked row's `id`); the link response's
   own `project`/`name` fields are display confirmation only, in a different shape
   (`{kind, key, name}`, not a cid) — document this explicitly in the implementation to prevent
   a copy-paste bug.
4. **Status handling**, matching the server's real gate order:
   - `404` → treat as the two dispatch-named cases jointly (feature off for this account *or*
     cid/membership not found — the server does not let us tell these apart from the body
     alone, and the dispatch's own framing of 404 as "feature not available for this account" is
     the dominant real case today, since `REPO_LINK_FOR` is off by default): write the file
     anyway (same 3-key format, using the picked row's known cid/name/repo-slug — never fields
     recovered from the failed response), report plainly that the server does not yet honor it.
   - `403` → "join the project first": refuse, write nothing, report the refusal (requirement 3;
     matches vendor behavior exactly, no divergence here).
   - `200` → write the file, report success, including the per-role note from requirement (5):
     state plainly, based on the picked row's own `owner` field (already resolved during the
     pick step, no extra call needed), whether the caller is the project's creator (their notes
     flow to the collaborator) or a non-creator accepted member (their notes land as suggestions
     only they see until confirmed) — this is exactly `command-draft-and-picker.md`'s existing
     "Dark Migration Path" framing of the follow/auto distinction, now surfaced per-bind rather
     than left implicit.
5. **Delegation (requirement 4)**: detect via the static grep above; when the installed client
   supports it, invoke `python3 "$HOME/.sapience/sapience_cli.py" link <value> [--name
   <repo-short-name>]` directly (never through `$PATH`'s `sapience`, which cannot route to it at
   all on this or presumably any NixOS-packaged install using the current wrapper shape).
   **Resolve the 404 tension explicitly** (see Risks) rather than silently: the plan should state
   which of the two options it is choosing — (a) never delegate the write itself, only delegate
   the *pick* (listing/matching), and keep this script's own `project_repo_link`-equivalent POST
   and write in both the delegate and fallback paths so 404-handling is single-sourced; or
   (b) delegate fully and special-case the vendor's own "Nothing was written" 404 message to
   perform the same write this script would have done itself. (a) keeps the 404/403 logic in
   exactly one place and is the simpler, more testable choice; (b) is truer to "delegate... to
   it" as literally read. Either is defensible; the plan must pick one and say so, since the
   dispatch text does not resolve this itself.
6. **`skill-sapience/SKILL.md` Stage 1 rewrite** (requirement 6): replace the hard stop with: no
   link file → compute the pick-mode listing inline (same `GET /v1/people/projects` call,
   `accepted or owner` filter) and fold it into Stage 9's existing single `AskUserQuestion` as
   its own option set (bind to project X / create a fresh project named Y / skip for now) —
   never a second `AskUserQuestion` call, consistent with the existing D8 separation rule that
   already keeps Stage 6's collaborator picker apart from Stage 9 for the identical reason
   (one mandatory picker, payload-literal, never summary-based). A confirmed "bind" selection at
   Stage 10 re-invokes `sapience-project-bind.sh --project <id> --confirm` exactly as built in
   the preview step, matching the existing literal-payload-reuse discipline the other three
   surfaces already follow.
7. **Doc updates**: add a short, source-grounded section to `per-repo-scoping.md` documenting
   the link route's real response shape, gate order, and 404/403 semantics (the material in
   "External Resources" above, condensed); update `command-draft-and-picker.md`'s "Dark
   Migration Path" section to note that the route is now actively called (not merely probed) by
   the bind-existing path, while the gate itself (and its being off by default for this account)
   is unchanged.
8. **Tests**: extend `test-sapience-project-bind.sh` with the six cases the dispatch names (pick
   lists both `shared`/`received` rows filtered correctly; bind-existing success writes the
   3-key file and calls the link route exactly once; 404 writes the file and reports the state;
   403 writes nothing; create still refuses without `--confirm`; delegate-vs-fallback byte
   identity) using the suite's existing curl-stub convention — no new test infrastructure
   needed. For the delegation detection path, stub a synthetic `sapience_cli.py` fixture file
   rather than touching the real `~/.sapience/sapience_cli.py`.

## Decisions

- Verified, not merely assumed, every status-code and response-shape claim in this task's own
  dispatch description against the live Sapience server source rather than against this
  extension's own (flagged-stale) deployed context — per the hard-mode reference-grounding
  contract. All of them held up except the two refinements captured in the Executive Summary
  (the real `GET /v1/people/projects` shape, and the link route's `project` field not being a
  cid), which should be treated as corrections to the implementation detail, not to the task's
  overall design intent.
- Treated the vendor CLI's dev-source `link_cmd` as the authoritative behavioral reference for
  pick-mode UX and matching rules (list/match/force-relink/short-name-default), since it is the
  literal client this task's requirement (4) names as the delegation target once installed.

## Risks & Mitigations

- **Latent schema mismatch in two out-of-territory files.** `sapience-publish.sh`'s `ko`
  subcommand (resolving `KO_PROJECT_KEY`) and `sapience-vault-read.sh`'s `notes_cid` resolution
  both parse `GET /v1/people/projects` with `(if has("projects") then .projects elif (type ==
  "array") then . else [] end)` — a shape that matches neither the real `{shared, received,
  ...}` response confirmed above nor any other `/v1/people/projects*`-family response found in
  the server source. Read literally, this jq expression resolves to `[]` against the live
  server every time, meaning both call sites' project-key/notes-cid resolution may already be
  silently returning empty results in production. **This is outside task 681's declared
  territory** (neither file is named in the dispatch's Territory list) and must not be hand-
  patched under this task — but the new pick-mode code this task adds to
  `sapience-project-bind.sh` must not copy this same incorrect pattern, and this finding is
  worth a dedicated follow-up task/spawn once 681 lands, since it affects every KO write this
  extension's own `ko` subcommand makes today. Flagged here rather than silently worked around.
- **The 404-write-vs-vendor-delegation tension** (Executive Summary and Recommendation 5): the
  dispatch's requirement (3) and requirement (4) are not simultaneously satisfiable by pure
  delegation, since the vendor CLI itself refuses to write on 404. The plan must choose and state
  one of the two resolutions in Recommendation 5 rather than leaving it implicit; left
  unresolved, an implementer is likely to either silently drop the 404-write requirement (if
  delegation is coded first and trusted blindly) or silently abandon delegation (if the 404 case
  is discovered late and "worked around" by routing everything through the HTTP fallback).
- **404 is genuinely ambiguous** between "feature off for this account" and "cid/membership not
  found" (both the flag-gate check and the `_project_link_gate` miss produce the identical `404`
  status with only the response *body* differing, and body text is not a contract this script
  should parse on for behavior). The recommended write-anyway-and-report-degraded behavior is
  safe under both readings (nothing is lost by writing the binding file speculatively either
  way), so this ambiguity does not need resolving before implementation, only acknowledging in
  the user-facing report text ("the server did not accept this link — binding recorded locally
  only").
- **Delegation detection must not shell out to the real `~/.sapience/sapience_cli.py` during
  tests**, since that file is a live, auto-updating, per-machine credential-bearing installation
  outside this repository's control — the test suite must stub a fixture file at a controlled
  path and point the script at it via an override (mirroring how the existing suite already
  stubs `curl` on `PATH` rather than touching the real network).

## Context Extension Recommendations

None — `task_type: meta`.

## Appendix

### Search Queries / Commands Used

- `cat .claude-extensions.json` — resolved `sapience`'s `source_dir` to
  `agent-system/extensions/sapience` before reading any file (source-store-deploy-boundary
  rule).
- Direct `cat`/`grep`/`sed -n` reads of `sapience-project-bind.sh`, `sapience-api-lib.sh`,
  `commands/sapience.md`, `skills/skill-sapience/SKILL.md`,
  `context/project/sapience/domain/per-repo-scoping.md`,
  `context/project/sapience/domain/command-draft-and-picker.md`,
  `scripts/sapience-vault-read.sh`, `scripts/sapience-publish.sh` (the last two for cross-checking
  the existing `GET /v1/people/projects` consumption pattern, not for editing).
- `find / -iname "repo_link.py"` / `grep -rln "people/projects"` → located the real server
  checkout at `/home/benjamin/Projects/Sapience/sapience-app/`.
- Direct reads of `repo_link.py`, and targeted `grep -n`/`sed -n` passes over `brain_server.py`
  around `_people_project_link`, `project_repo_link`, `project_repo_unlink`,
  `_project_link_gate`, `_people_projects`, `project_register`, `_project_register_full`,
  `project_public`, `people_public`.
- Direct reads of `sapience_cli.py` (dev-source) around `link_cmd`, `_link_pick_project`,
  `_link_text`, `post`/`get`.
- `which sapience`; `cat /home/benjamin/.nix-profile/bin/sapience`; live invocation `sapience
  link` (observed `unknown command 'link'`, exit 2); live invocation `python3
  /home/benjamin/.sapience/sapience_cli.py link` (observed fallthrough to generic `cli` usage
  doc, exit 0, no network call) — both read-only probes, no mutating flags passed, no file
  written.
- `wc -l sapience_cli.py ~/.sapience/sapience_cli.py` and `grep -n "sub == 'link'"` to confirm
  the installed client predates the dev-source one.
- `git log --oneline -5 -- <the task's territory files>` — confirmed no concurrent-sibling or
  very-recent unrelated churn on these specific files.
