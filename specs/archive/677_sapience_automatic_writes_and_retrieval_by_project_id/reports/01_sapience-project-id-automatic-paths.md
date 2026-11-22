# Research Report: Task #677

**Task**: 677 - Sapience automatic writes and retrieval by project id
**Started**: 2026-11-21
**Completed**: 2026-11-21
**Effort**: medium (one shared resolver, two call-site wirings, one blocked clause, doc updates)
**Dependencies**: None blocking research; app-side `open_mvp_flags_and_create_linked_team_project` (not started) and `repo_link_code_onto_release_line` (HOLD) gate live end-to-end exercise of the read/write paths this task touches
**Sources/Inputs**:
- Codebase: `agent-system/extensions/sapience/scripts/{sapience-remember.sh,postflight-sapience-notes.sh,sapience-retrieve.sh,sapience-project-bind.sh,sapience-publish.sh,lib/sapience-api-lib.sh}`, `context/project/sapience/domain/{per-repo-scoping.md,injection-site-scoping.md,linked-repo-write-policy.md,review-gate-boundary.md}`, `rules/sapience-write-path.md`
- External source checkouts (read-only reference, not edited): `~/Projects/Sapience/sapience-app/{repo_link.py,brain_server.py,mcp.py,fly.toml,specs/TODO.md,specs/ROADMAP.md}`, `~/Projects/Sapience/sf1-engine/integration/project-link.md`
- Installed vendor client: `~/.sapience/mcp.py`, `~/.sapience/config.json`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The repository already implements most of the *write-side* machinery the task description
  asks for, under a **deliberately different, already-settled design**: `sapience-remember.sh`
  and `sapience-publish.sh ko` resolve `.sapience/project.json`'s `project` cid to a `key` via
  `GET /v1/people/projects` and send a plain `project: "<key>"` field — **never `project_cid`** —
  with the Non-Goal explicitly documented in both scripts' headers. `postflight-sapience-notes.sh`
  already resolves this key once per batch and forwards it as `--project-key`.
- **Item (2) of the task description — sending `project_cid` on automatic writes from the
  postflight pass — conflicts with an already cross-harness-agreed governance ruling** and must
  not be implemented as literally written. `sf1-engine`'s `integration/project-link.md` section
  10 Ruling 7 (cited by this repo's own `linked-repo-write-policy.md`) forbids any write
  attaching a *verified* `project_cid` from an autonomous task run unless its `write_origin`
  resolves to `'typed'`, and keeps the feature gated off until two named leak paths close (neither
  is closed). The server's own `_ingest_kos` handler confirms the stakes: a verified `project_cid`
  write overwrites `ko['author']` with the real member's own display name and is delivered live
  to the collaborator (`follow:true`, no suggestion-lane gating) — exactly the misattribution risk
  the ruling exists to prevent. The existing plain-`project`-key design sits below that gate and
  should be preserved.
- **Item (3) — the read side sending `project_cid`** is explicitly exempted by the same ruling
  ("reads … are unaffected and may proceed independently") and is also the one piece of the
  description that is genuinely unbuilt today: `sapience-retrieve.sh` has no project-aware code
  path at all yet, and the server's `/v1/search` handler does honor a `project_cid` query
  parameter as a strict pre-filter — gated on `repo_link.enabled(tok)` (the `REPO_LINK_FOR`
  feature flag), which is deployed `""` (off for everyone) today.
- **Item (1) — one resolver shared by every script** is buildable (a `lib/sapience-api-lib.sh`
  already exists and is sourced by two of the five scripts), but three scripts currently
  duplicate the resolution logic *on purpose*, each citing the same declared-`file_scope`
  rationale. Consolidating is a legitimate simplification, not a correctness fix, and the
  planner should weigh it against that documented rationale rather than treat it as free.
- **Item (4) — byte-identical request with no link file** already holds for every existing
  write-side call site and is a straightforward negative-control test to add for the new
  read-side code.
- **Item (5) — the vendor `mcp.py`'s `project` argument on `sapience_remember`** is confirmed to
  exist, and confirmed to be an **unrelated mechanism** (company-store routing via
  `route_ko()`/`config.json`'s `routes` map), not a tagged-write or per-repo-link path — worth a
  one-paragraph addition to `per-repo-scoping.md` to pre-empt confusion, as the task description
  itself anticipates.
- Both app-side dependencies the task names are unmet today (`open_mvp_flags_and_create_linked_
  team_project` not started; `repo_link_code_onto_release_line` on HOLD; `REPO_LINK_FOR = ""` in
  the deployed `fly.toml`), and this repository carries no `.sapience/project.json` binding yet —
  so every live-server-dependent behavior must be built and tested against a stub, exactly as the
  task description itself anticipates.

## Context & Scope

Task 677 asks the Sapience extension's *automatic* paths (the postflight note-capture pass and
the dispatch-time memory-retrieval pass) to key off the repository's own linked-project identity
rather than its working-directory basename, once such a link exists. The task names five
sub-goals: (1) one shared resolver; (2) writes carrying `project_cid` with `project_rejected`
surfaced as an issue; (3) reads carrying `project_cid` with the label match as fallback; (4) a
byte-identical no-link control; (5) doc updates including the vendor client's own `project`
argument on `sapience_remember`.

This research reads every script and domain doc the dispatch names, the server-side handlers
those scripts call (`sapience-app`'s `brain_server.py`, `repo_link.py`, `mcp.py`), and the
cross-harness governance document (`sf1-engine`'s `integration/project-link.md`) that this
repo's own `linked-repo-write-policy.md` explicitly agrees with by citation. No code was changed;
this is a read-only research pass. Two non-fatal issue rows were recorded via `issue-record.sh`
during this pass (a cross-repo governance conflict, costly; an unmet-dependency note, minor) —
see Appendix.

## Findings

### Codebase Patterns

**Write side already resolves a project key, deliberately never a `project_cid`.**
`sapience-remember.sh` (lines 42–67, 228–263) and `sapience-publish.sh`'s `ko` subcommand
(lines 22–41, 546–584) both: read `.sapience/project.json`'s `project` (cid) field at the git
toplevel (following a linked worktree to its parent checkout), call `GET /v1/people/projects`,
match the binding's cid against that list's entries to recover a `key`, and send a plain
`project: "<key>"` field on the KO body. Both scripts' headers state, as an explicit Non-Goal,
that `project_cid` is never sent, because "the REPO_LINK_FOR path that would make the server
trust a client-supplied cid is confirmed dark for this token, and `_project_stamp` would
unconditionally overwrite a client-set `ko['project']` the day that path is ever
server-verified." `postflight-sapience-notes.sh` resolves this key **once per batch**
(`resolve_project_key_once()`, lines 166–214) and forwards it to every per-note
`sapience-remember.sh` call as `--project-key`, short-circuiting that script's own per-call GET.
Degrade is uniform and already matches item (4)'s intent: no binding file → zero GETs, no
`project` field, byte-identical to pre-tagging behavior; a binding present but resolution
failing → untagged write plus one non-fatal issue row, never a dropped note.

**Read side has no project-aware code at all.** `sapience-retrieve.sh` builds its `GET
/v1/search` request from keywords and the repo-slug label (`source=[repo:<slug>]`) only; it
never reads `.sapience/project.json` and never sends `project_cid` or `project`. This is the one
piece of the task's five sub-goals that is genuinely greenfield.

**Resolution logic is duplicated by design, not by oversight.** Three scripts
(`sapience-remember.sh`, `postflight-sapience-notes.sh`, `sapience-retrieve.sh`) each inline the
identical worktree-checkout-resolution block and the identical host/token-precedence block,
each with a comment stating the duplication is deliberate "for the same declared file_scope
reason" rather than extracted into the already-existing `lib/sapience-api-lib.sh` (which
`sapience-project-bind.sh` and `sapience-publish.sh` already source). `test-sapience-mcp-
registration.sh`'s Case 30 mechanically asserts the worktree-resolution block is byte-identical
across its five copies (the fourth and fifth being `verify-sapience-mcp.sh` and
`verify-sapience-context-scoping.sh`) — any consolidation that removes a copy must also update
that lockstep test.

**The vendor `mcp.py`'s `sapience_remember` `project` argument is a distinct, unrelated
mechanism.** The installed client (`~/.sapience/mcp.py`, confirmed present, last modified
2026-11-13) implements `project_slug()`/`route_ko()`: an optional `project` tool argument is
matched against `config.json`'s `"routes"` map (falling back to `COMPANY_PROJECT`/
`SAPIENCE_PROJECT`) to pick **which token** (personal brain vs. a shared company store) the
write is posted to. This has nothing to do with the per-repository link/`project_cid` mechanism
and cannot produce a tagged write for the reason `per-repo-scoping.md` already states (the
connector's `provenance` has no injectable repo marker) — but `per-repo-scoping.md` currently
does not mention this argument exists at all, which is exactly the gap task item (5) names.

### External Resources (sapience-app / sf1-engine source)

**`repo_link.py` (`~/Projects/Sapience/sapience-app/repo_link.py`) is the authoritative field
shape.** `parse_link(text)` requires exactly three string keys — `project` (cid), `name`
(display name), `repo` (short name matching `^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$`, never
path-shaped) — refusing any dict carrying a token/key/secret-shaped key. This matches
`sapience-project-bind.sh`'s `write_link_file()` byte-for-byte (verified: same three keys, same
order, same validation regex, same path-shape rejection). One difference worth naming for a
literal "field for field" resolver: `repo_link.py`'s own `find_link(start_dir)` walks **upward**
from `start_dir` toward the filesystem root (bounded to 40 levels) looking for the first valid
link file, whereas every local script resolves only the git toplevel's own `.sapience/
project.json` (via `resolve_checkout_toplevel`) and never walks further up. In practice these
agree whenever the link file lives at the repository root (the only place `sapience-project-
bind.sh` ever writes it), so this is a latent divergence, not a live bug — flagged so a shared
resolver's own contract statement can note it rather than silently assume `find_link`'s broader
walk is being mirrored.

**`/v1/search`'s `project_cid` parameter is a real, working strict pre-filter — a different
parameter from the one `per-repo-scoping.md` already tested.** `brain_server.py`'s `/v1/search`
handler (~line 50380) and `/v1/recent` handler (~line 49023) both read a `project_cid` query
parameter, gate it on `repo_link.enabled(tok)` (the `REPO_LINK_FOR` flag), verify it via
`cli_project_scope.gate` (channel resolution + the same accepted-member rule `repo_link.
accepted_member` encodes), and on success return **only** that project's notes via
`room_project_notes`/`mcp_project_scope.search_rows`, never falling back to the single-tenant
store. This does **not** contradict `per-repo-scoping.md`'s existing claim that `&project=`
(a different, plain-slug parameter) is silently ignored by `/v1/search` — that claim is still
true and was tested against the right parameter name for that claim. The two parameters
(`project`, ignored; `project_cid`, honored-but-flagged) must not be conflated in the updated
docs.

**`project_cid` on a write is a *verified*, authorship-overwriting mechanism — this is the crux
of the item-(2) conflict.** `brain_server.py`'s `_ingest_kos` handler (~line 50828): when the
request carries a non-empty `project_cid`, it calls `project_cid_verify(tok, cid)` (shared gate,
~line 28333); on success it calls `_project_stamp(ko, proj)` for every KO in the batch **and
sets `ko['author'] = _owner_author(tok)`** — i.e. the real person's own display name — then the
project's owner receives the note live (`follow:true`, no suggestion framing) per `sapience-
project-bind.sh`'s own documented `cross = doors & (...)` mechanics. On rejection, the reply
carries `project_rejected: 'not_a_member'|'no_such_project'` and the KO is still written,
untagged (`mcp.py`'s `repo_link_tail()` renders this as "Saved to your own Sapience, untagged").

**`sf1-engine`'s `integration/project-link.md` section 10, Ruling 7, forbids exactly the write
item (2) describes.** Verbatim: *"automatic project writes — any write that attaches a verified
`project_cid` — require the task flag that turns the feature on to stay **off** until both (a)
the dispatched-child leak … is closed, and (b) gate M4 item 4.3's non-typed registration of
command expansions, skill text, and dispatch files lands … This gate binds only writes that
attach a verified `project_cid`; reads (mirroring a project's notes) and the person's own
typed-decision writes … are unaffected and may proceed independently."* Neither (a) nor (b) is
closed as of this research pass. This repo's own `linked-repo-write-policy.md` Ruling 2 already
states the Claude Code side of this agreement ("the mid-run ban is not lifted, for either note
kind … it is about the untagged, unbounded MCP-write-tool path itself, which link state does not
change") and its "Cross-Harness Agreement" section already states that the plain-`project`-key
mechanism "sits entirely below section 10's own gate" and that sending a verified `project_cid`
"would reopen section 10's ruling 7 gate for it." The postflight pass
(`postflight-sapience-notes.sh`) is precisely the autonomous, non-interactive write surface
Ruling 7's own leak-surface language describes ("turns handed to the Claude Code worker, which
runs with every hook, permission rule, and instruction file disabled").

**Both app-side dependencies the task names are unmet; the flag is off.** `fly.toml:165` deploys
`REPO_LINK_FOR = ""`. `sapience-app/specs/TODO.md` still carries
`open_mvp_flags_and_create_linked_team_project` as an open item (not started). `sapience-app/
specs/ROADMAP.md:76` lists `repo_link_code_onto_release_line` as `HOLD`. This repository itself
has no `.sapience/project.json` (confirmed: no such file, not gitignored, not tracked). So every
live-server-dependent behavior in items 2–3 is untestable end-to-end today; the task description
anticipates exactly this ("the scripts here call the HTTP API directly and can be built and
tested against a stub before either lands").

## Recommendations

1. **Do not send `project_cid` from `sapience-remember.sh` or the postflight pass.** Keep the
   existing plain-`project`-key design exactly as committed. Implementing item (2) literally
   would violate the cross-harness-agreed Ruling 7 and risks misattributing agent-authored
   postflight notes as the human member's own typed decisions, delivered live with no review.
   This should be treated as a **scope exclusion**, not a deferred sub-task, until the two named
   leak closures land upstream (tracked externally, in `sf1-engine`'s own milestones — not an
   obligation this repository's plan can discharge).
2. **Do** surface `project_rejected` as a recorded issue, but only where it can actually occur
   today: `sapience-project-bind.sh`'s link route already classifies 403/404 distinctly; no
   change needed there. If a future, explicitly-authorized interactive path (e.g. `/sapience`'s
   human-reviewed approval picker — already the one surface Ruling 2's own text names as
   structurally exempt from the mid-run ban) ever sends a verified `project_cid`, that call site
   — and only that one — is the right place for a `project_rejected` → issue-row mapping.
3. **Build the read-side `project_cid` path in `sapience-retrieve.sh`** (item 3), gated
   identically to the existing degrade discipline: no `.sapience/project.json` → request
   byte-identical to today (item 4's negative control); a binding present → send `project_cid`
   (not the plain `project`/key field — the search/recent endpoints key on `project_cid`, not on
   a resolved key) alongside the existing `source=[repo:<slug>]` label filter, so a server that
   has the flag off or rejects the cid still falls back to the current label-matched result
   rather than returning nothing. Treat a `project_rejected` reply the same way the existing exit
   codes treat a benign no-match (exit 1 / fall back to label-only), not as a transport failure
   (exit 2) — rejection is a normal, documented server outcome, not an error.
4. **Consolidate the resolver only if the plan explicitly widens file_scope to cover it**, since
   three scripts' own headers currently justify duplication by citing a *narrower* file_scope.
   A pragmatic middle path: add the resolver to the already-shared `lib/sapience-api-lib.sh`
   (which two of five scripts already source) and have the three currently-duplicating scripts
   source it too, while updating `test-sapience-mcp-registration.sh`'s Case 30 lockstep set
   accordingly. State explicitly whether the new resolver's contract matches
   `resolve_checkout_toplevel`'s single-location lookup or `repo_link.py`'s upward `find_link`
   walk — recommend keeping the existing single-location lookup (it is what every write path
   already relies on and what `sapience-project-bind.sh` already writes to) rather than adding
   the upward walk, and say so explicitly in the resolver's own header rather than leaving the
   divergence implicit.
5. **Update `per-repo-scoping.md`** to add a short paragraph on the vendor `mcp.py`'s
   `sapience_remember` `project` argument (company-store routing via `route_ko`/`config.json`
   `"routes"`), explicitly distinguishing it from the per-repository link mechanism, per item (5).
   Update `injection-site-scoping.md` only if the read-side change touches one of its three named
   primary-session sites — it does not: `sapience-retrieve.sh` is explicitly the "fourth path,
   deliberately contrasted" in that doc, feeding dispatched subagents only, so no change to that
   file is needed from this task.

## Decisions

- **Treat item (2) (write-side `project_cid`) as out of scope for this task's implementation**,
  pending the two leak closures Ruling 7 names; the plan should state this exclusion explicitly
  rather than silently dropping it, and should not re-derive a different write-side mechanism
  that reaches the same verified-`project_cid` outcome by another name.
- **Treat item (1) (one shared resolver) as a planner-level trade-off**, not a mandate to
  override the existing duplication rationale without updating the file_scope declarations and
  the lockstep test that depend on it.
- **Item (3) (read-side `project_cid`) is the one piece of new, uncontested functionality this
  task should deliver**, built against a stub (no live `REPO_LINK_FOR` account to test against
  today) with the no-link byte-identical control as its primary correctness test.

## Risks & Mitigations

- **Risk**: a future implementer, reading the task description literally without this report,
  wires `project_cid` into `sapience-remember.sh`/the postflight pass, reopening the exact
  autonomous-write leak Ruling 7 keeps closed. **Mitigation**: this report's Decisions section
  and the recorded `cross-repo governance conflict` issue row (see Appendix) should be surfaced
  to the planning phase explicitly; the plan should carry the exclusion as a stated scope
  boundary, not an implicit omission.
- **Risk**: building and testing the read-side `project_cid` path with no live account carrying
  `REPO_LINK_FOR` means the only verification available is a stub/mock server or a dry-run
  inspection of the constructed URL. **Mitigation**: mirror the existing test pattern in
  `test-sapience-remember.sh`/`test-sapience-project-bind.sh` (which already test against a
  fixture HTTP responder rather than the live host) for the new `sapience-retrieve.sh` behavior.
- **Risk**: consolidating the resolver without updating `test-sapience-mcp-registration.sh` Case
  30 leaves a stale byte-identity assertion that silently stops testing anything meaningful (or
  starts failing for the wrong reason). **Mitigation**: name this test explicitly in the plan's
  file_scope if consolidation is chosen.

## Context Extension Recommendations

- **Topic**: the vendor `mcp.py`'s `sapience_remember` `project` argument (company-store
  routing).
  **Gap**: `per-repo-scoping.md`'s "Why the MCP Write Tools Cannot Produce a Tagged Write"
  section does not mention this argument exists, which could lead a future reader to assume no
  MCP write tool accepts any project-shaped argument at all.
  **Recommendation**: add a short paragraph there (task item 5), citing `route_ko()`/
  `project_slug()` in the installed `mcp.py` and the `config.json` `"routes"` map, with an
  explicit "this is unrelated to the per-repository link mechanism" sentence.
- **Topic**: `/v1/search`'s `project_cid` parameter.
  **Gap**: `per-repo-scoping.md`'s "`project` is a dead end" subsection, read in isolation, could
  be misread as "no project-shaped parameter ever works on `/v1/search`" — this research found
  that `project_cid` (a different parameter, gated on `REPO_LINK_FOR`) does work.
  **Recommendation**: when item (3) lands, add a sentence to that subsection distinguishing the
  two parameter names explicitly, so the next reader does not have to re-derive this from the
  server source.

## Appendix

### Search Queries / Investigation Steps

- Direct reads of all five named scripts plus `sapience-project-bind.sh`/`sapience-publish.sh`
  (not named in the territory list but load-bearing for the existing project-key mechanism).
- `grep -rn "project_cid|project_rejected|REPO_LINK_FOR"` across `~/Projects/Sapience/
  sapience-app` (non-test files) to establish which server routes honor which parameter.
- Direct reads of `brain_server.py`'s `/v1/search`, `/v1/recent`, and `_ingest_kos` handlers
  around their `project_cid` branches.
- Direct read of `repo_link.py` (`parse_link`, `link_text`, `find_link`, `accepted_member`).
- Direct read of `sf1-engine/integration/project-link.md` section 10, rulings 1–7 and the
  cross-repository register (which names this task by its stable slug,
  `sapience_linked_repo_write_and_capture_policy`, as an obligation owed back).
- Checked `fly.toml` for the deployed `REPO_LINK_FOR` value, and `sapience-app`'s `specs/TODO.md`
  / `specs/ROADMAP.md` for the two named dependency tasks' current status.
- Checked this repository for an existing `.sapience/project.json` (absent) and the installed
  `~/.sapience/mcp.py`/`sapience_cli.py` for `project_cid` occurrences (zero — the installed
  client is a build that predates or excludes that feature, consistent with the flag being off).

### Non-Fatal Issues Recorded This Pass

- `cross-repo governance conflict` (severity: costly, resolution: open) — the item-(2)/Ruling-7
  conflict detailed above.
- `dependency not ready` (severity: minor, resolution: open) — both named app-side dependencies
  unmet; `REPO_LINK_FOR` off; no local link file.
