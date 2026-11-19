# Implementation Plan: Task #648

- **Task**: 648 - Add the four Sapience write-surface publishers with loud-failure discipline
- **Status**: [NOT STARTED]
- **Effort**: 6.5 hours
- **Dependencies**: 647 (sapience-project-binding-and-vault-read) — COMPLETE; this task consumes its `scripts/lib/sapience-api-lib.sh` and its `.sapience/project.json` binding writer
- **Research Inputs**: specs/648_sapience_publish_write_surfaces/reports/01_sapience-publish-write-surfaces.md
- **Artifacts**: plans/01_sapience-publish-write-surfaces.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add one new script, `sapience-publish.sh`, to the Sapience extension's source store, exposing
four write-surface publishers (doc comment, doc version, direct message, repo-tagged knowledge
object) as subcommands behind a single entry point, each dry-run-by-default and each carrying
the loud-failure discipline already proven in `sapience-remember.sh`. All four route through the
dependency task's shared `lib/sapience-api-lib.sh` for host/token/HTTP, so no credential logic is
re-derived and no MCP write tool is ever named as a prescribed write path. The script is built
incrementally — scaffold and registration first, then one surface per phase, each landing with
its own test cases in a new `test-sapience-publish.sh` suite — and the whole thing is deployed
and verified once at the end.

### Research Integration

The research report re-derived every endpoint contract directly against
`/home/benjamin/Projects/Sapience/sapience-app/brain_server.py` rather than trusting the
dispatch's paraphrase, and three of its findings are load-bearing for this plan's phase shapes:

1. **The KO publisher's project key is not locally available.** `.sapience/project.json` stores
   exactly `{project (cid), name, repo}` and structurally cannot carry a `key` field
   (`repo_link.py`'s `parse_link` rejects secret-shaped dict keys, and `key` matches that
   guard). But `_ko_matches_channel` compares `ko['project']` against a channel's short
   `workstream` slug, not the cid. Phase 4 therefore resolves the key at runtime via
   `GET /v1/people/projects`, keyed on the binding's cid, refusing loudly on no match.
2. **Doc-version concurrency is keyed on `base_rev`, never `base_hash`.** `_docs_save` compares
   `base_rev` against `doc_rev(prev)`; `base_hash` is a secondary fallback only, and omitting
   `base_rev` does not skip the check. Phase 3 always fetches the doc's `rev` itself immediately
   before writing, and surfaces 409 `head_moved`, 202 `people_propose`, and 404 `share_gone` as
   three distinct exit paths rather than one generic failure.
3. **Doc-comment and DM share one server-side call.** A `kind:'chat'` head resolves
   `op = 'chat-msg'`, but both land in the same `doc_comment_add`/`people_after_comment` path, so
   Phase 2 builds one internal comment-POST helper and the `dm` subcommand's only extra step is
   the preceding `POST /v1/people/dm`.

The report also flagged `test-sapience-mcp-registration.sh`'s Case 30 lockstep array as needing
an explicit plan-time decision; see Decisions below.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap consultation was performed.

## Premise Re-Validation (Carried-Figure Discipline)

The dispatch flagged four description lines as carrying trigger-class claims. Each was checked
against the prior research artifact and against live state at plan time; results stated
explicitly even where the description is confirmed unchanged.

| Dispatch claim | Check performed at plan time | Result |
|----------------|------------------------------|--------|
| EDIT TARGET is `.extensions.sapience.source_dir` = `agent-system/extensions/sapience`, present on this filesystem | `jq -r '.extensions.sapience.source_dir' .claude-extensions.json`; directory listing of `scripts/`, `scripts/lib/`, `scripts/tests/` | **CONFIRMED UNCHANGED.** Resolves to `/home/benjamin/.config/nvim/agent-system/extensions/sapience`, present, with `lib/sapience-api-lib.sh` and `sapience-project-bind.sh` both on disk |
| DM surface: `POST /v1/people/dm` -> comment post; `kind:'chat'` so op is `chat-msg`; APP_OVERHAUL_FOR ON | Research re-confirmed the route-table entry and the `op = 'chat-msg' if head.get('kind') == 'chat'` line in `brain_server.py` | **CONFIRMED by source re-derivation.** The live ON-ness of `APP_OVERHAUL_FOR` rests on the dispatch author's own `GET /overhaul -> 200` probe and was **not** re-probed at plan time (no vault reads or writes performed during planning). Phase 2 re-checks it operationally via its first `--confirm` run; a gated response is a loud failure there, not a silent one |
| Repo-tagged KO: the `project` field is what `_ko_matches_channel` reads; `sapience-remember.sh` never sets it | `grep -n '"project"\|project:\|--arg project' sapience-remember.sh` | **CONFIRMED UNCHANGED.** Zero matches — `sapience-remember.sh` genuinely never sets `project`. Research separately confirmed `_ko_matches_channel` at `extract_local.py:1317-1321` |
| Loud-failure discipline: `gated >= 1`, non-empty `set_aside`, absent/zero `written` are all non-zero-exit failures | `grep -n` over `sapience-remember.sh` lines 14-31, 239-253 | **CONFIRMED UNCHANGED.** The script's header states this verbatim and its implementation checks `set_aside` -> `gated` -> `written` -> `ok` in that order, all four unconditionally. The "NO DELETE API (three probed routes 404)" claim rests on the dispatch author's probes and was not re-probed; it is a motivation for the discipline, not a value this plan depends on |

**One premise the dispatch did NOT state, discovered at plan time and load-bearing:** the
dispatch's FILE SCOPE of two new files is incomplete in a commit-blocking way. See Decisions.

## Goals & Non-Goals

**Goals**:
- One script, `scripts/sapience-publish.sh`, with four subcommands (`doc-comment`,
  `doc-version`, `dm`, `ko`), dry-run by default and requiring an explicit `--confirm` before any
  network write, matching `sapience-project-bind.sh`'s established house posture.
- Every subcommand's `--dry-run` prints the **literal** payload it would POST, produced by the
  same payload-construction code path the confirmed write uses — never a second, divergent
  preview string.
- Loud-failure handling written against each endpoint's own verified response shape, never a
  one-size-fits-all check borrowed from a different endpoint.
- A new `scripts/tests/test-sapience-publish.sh` suite covering all four subcommands against a
  PATH-shadowed `curl` stub, plus a local lockstep assertion on the worktree block.
- The two new files registered so they actually deploy and so gate 3 stays green.

**Non-Goals**:
- Building, stubbing, or designing the `/sapience` command or its approval picker. It does not
  exist anywhere in the repository today and is a future consumer of this script, not part of
  this task.
- Re-deriving host/token/HTTP/redaction logic. All of it is reused from
  `lib/sapience-api-lib.sh`.
- Sending `project_cid` on any call. The `REPO_LINK_FOR` path is confirmed dark for this token,
  and `_project_stamp` would unconditionally overwrite a client-set `ko['project']` if a
  `project_cid` were ever server-verified — so the publisher sends only the plain `project`
  field and needs no code change the day the flag flips.
- Adding a second, independently-sized bound on KO writes. The existing 3-8-note-per-task bound
  is the only size bound.
- Naming any MCP write tool as a prescribed write path in the script's header, `--help`, or any
  other instruction surface (`rules/sapience-write-path.md`).

## Decisions

**D1 — `manifest.json` is in scope, and this is not optional.**
`check-extension-docs.sh` (gate 3, doc-lint) enumerates every tracked file under an extension's
`scripts/` via `git ls-files` and FAILs with `script file on disk NOT in provides.scripts:
scripts/<rel>` for any entry absent from `manifest.json`'s `provides.scripts` array (verified at
`check-extension-docs.sh:606-623`). Creating `sapience-publish.sh` and
`tests/test-sapience-publish.sh` without registering both therefore red-lines a **commit-blocking**
gate at the first phase-closing commit that includes them. The dependency task 647's own
`file_scope` already included `manifest.json` for exactly this reason. The manifest edit is
scheduled in the same phase that creates the scripts (Phase 1), per the coupled-generated-surface
obligation, and the canonical repair command the gate itself prints is
`bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --write`.

**D2 — Case 30's lockstep array is widened (research recommendation 7, option (a)).**
`sapience-publish.sh` needs the marker-delimited `sapience-worktree-checkout-resolution` block
for its `ko` subcommand (to locate `.sapience/project.json`), making it an eighth copy. Leaving
it out of `test-sapience-mcp-registration.sh`'s `LOCKSTEP_FILES` array would leave that copy with
no global mechanical drift catch. The array is a short bash literal and task 647 set the exact
precedent of widening it for its own two new scripts. Adding one line is strictly lower risk than
an undetected divergence.

**D3 — No redeploy until the final phase.**
Gate 3's Rule F (`check_deployed_script_drift`, `check-extension-docs.sh:258-282`) FAILs when a
`provides.scripts` entry's deployed copy differs in content from its source copy, but explicitly
**skips** (info note, never a FAIL) when the deployed copy is absent. So registering the scripts
in Phase 1 is safe pre-deploy, while deploying mid-plan would make every subsequent source edit a
drift FAIL until the next redeploy. The single redeploy therefore belongs at the end, after all
source edits have landed.

**D4 — Phases 2, 3 and 4 are serialized, not parallelized.**
All three edit the same two files (`sapience-publish.sh`, `test-sapience-publish.sh`). They are
logically independent surfaces but share file territory, so the dependency chain is linear. This
is a deliberate choice to avoid write contention, not an unexamined default.

**D5 — The KO publisher resolves its project key at runtime and never guesses.**
Resolution order: `--project` override flag wins; else `.sapience/project.json`'s `.project`
(cid); then `GET /v1/people/projects`, defensively unwrapped the way `sapience-vault-read.sh`
already unwraps a vault list response, matching that cid to recover `.key`. If no binding exists,
or no entry matches, the publisher refuses with a non-zero exit and writes nothing — never a
silent untagged write, and never a key guessed from the binding's free-text `name` field.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `*v1/docs/*` curl-stub pattern matches both the doc-version POST and the doc-comments POST, silently exercising the wrong branch | H | M | Order the `/comments`-suffix pattern **before** the bare-slug pattern in the `case` statement (shell `case` matches first-listed-first), and document the ambiguity resolution in the test file's own header comment, as `test-sapience-project-bind.sh` documents its own |
| A KO write reaches the vault during development and cannot be undone (no delete API; `auto_approve:false` review gate is bypassed for explicit writes) | H | L | Dry-run is the default for every subcommand; `--confirm` is a separate, explicitly-named flag. Every test case drives the PATH-shadowed `curl` stub, never the real host. No phase's verification criteria require a live confirmed write |
| `deploy-root-guard.sh` is absent under the sapience source store pre-deploy (it lives in `core/scripts/`) | M | H (certain pre-deploy) | This is the established, working convention for every sibling script in this extension; the test suite's `build_scratch()` reproduces the post-deploy flattened layout. Follow it, do not invent a new one |
| The eighth copy of the worktree block is pasted with a whitespace difference, failing Case 30 | M | M | Copy the block with `sed -n '/BEGIN sapience-worktree-checkout-resolution/,/END sapience-worktree-checkout-resolution ===$/p'` from an existing copy rather than retyping it, and run the lockstep case before closing Phase 1 |
| A source edit lands after the Phase 5 redeploy, re-opening gate 3 drift | M | L | Phase 5's closing verification runs after the redeploy; any fix made at that point requires re-running the redeploy step before the phase closes |
| `APP_OVERHAUL_FOR` has flipped off since the dispatch's probe, so the `dm` subcommand's first live use fails | L | L | The DM publisher's loud-failure check surfaces a non-2xx status explicitly; the failure is loud and immediate, not silent. No plan phase depends on a live DM succeeding |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |

Phases within the same wave can execute in parallel. This plan's chain is deliberately linear —
see Decision D4.

---

### Phase 1: Scaffold, registration, and test harness [NOT STARTED]

**Goal**: `sapience-publish.sh` exists with its header, `--help`, flag parsing, library sourcing,
worktree block, and a four-way subcommand dispatch that refuses unknown subcommands; both new
files are registered so gate 3 is green; and `test-sapience-publish.sh` exists with its
`build_scratch()` scaffolding, `curl` stub harness, and the structural cases.

**Tasks**:
- [ ] Create `scripts/sapience-publish.sh`. Header comment states the four surfaces, the
      dry-run-by-default / `--confirm` posture, the exit-code contract, and — per
      `rules/sapience-write-path.md` — must not name `sapience_remember`/`sapience_wrapup`/
      `sapience_handoff`/`sapience_adddoc` as a prescribed write path. Record in the header the
      finding that `.sapience/project.json` cannot carry a `key` field and why the key is
      resolved at runtime instead.
- [ ] Source `lib/common.sh` (for `common_repo_root`), then
      `. "${SCRIPT_DIR}/deploy-root-guard.sh"`, then `lib/sapience-api-lib.sh` — in the exact
      order and form `sapience-project-bind.sh` uses.
- [ ] Embed the marker-delimited `sapience-worktree-checkout-resolution` block by extracting it
      verbatim from `sapience-project-bind.sh` with `sed -n '/BEGIN sapience-worktree-checkout-resolution/,/END sapience-worktree-checkout-resolution ===$/p'`,
      never by retyping.
- [ ] Implement subcommand dispatch for `doc-comment`, `doc-version`, `dm`, `ko`, each currently
      a stub that exits non-zero with "not yet implemented"; an unknown subcommand and a missing
      subcommand both print usage and exit non-zero.
- [ ] Implement shared flag parsing: `--dry-run` (default) and `--confirm`, mutually exclusive;
      `--help`.
- [ ] Add `"sapience-publish.sh"` and `"tests/test-sapience-publish.sh"` to
      `manifest.json`'s `provides.scripts` array, preserving its existing sort order. Prefer
      `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --write` run from the
      repository root (the repair command gate 3 itself prints) over a hand edit.
- [ ] Add `"$SCRIPT_DIR/../sapience-publish.sh"` to `LOCKSTEP_FILES` in
      `scripts/tests/test-sapience-mcp-registration.sh`'s Case 30 array.
- [ ] Create `scripts/tests/test-sapience-publish.sh` modeled on
      `test-sapience-project-bind.sh`: the two-candidate `COMMON_SH` bootstrap, the
      `common_test_resolve_subject` / `common_test_declare_subject` calls for
      `sapience-publish.sh`, `sapience-api-lib.sh`, `deploy-root-guard.sh`, `common.sh` and
      `sapience-remember.sh`, and a `build_scratch()` reproducing the post-deploy flattened
      `.claude/scripts/` layout plus a scratch git repo.
- [ ] Install the PATH-shadowed inline `curl` stub with its `case "$url"` dispatch. Order the
      `*v1/docs/*/comments*` pattern **before** the bare `*v1/docs/*` pattern, and state that
      ordering requirement in the test file's header comment.
- [ ] Add structural test cases: `--help` exits 0 and names all four subcommands; an unknown
      subcommand exits non-zero; no subcommand exits non-zero; `--dry-run` and `--confirm`
      together are refused; the script's header names no MCP write tool as a prescribed path.
- [ ] Add the local lockstep case: the worktree block in `sapience-publish.sh` is byte-identical
      to the copy in `sapience-project-bind.sh` (mirroring `test-sapience-project-bind.sh`'s own
      case 14, as a second line of defense independent of Case 30).

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: Measured at plan time, `test-sapience-mcp-registration.sh`'s
`LOCKSTEP_FILES` array holds exactly **7** entries (lines 1218-1226) and `manifest.json`'s
`provides.scripts` holds exactly **16** entries; this phase takes them to 8 and 18 respectively.
Confirm both counts by re-reading each file before editing — a plan-time count can be stale
against live state by the time the phase runs, independent of drift this task introduces.

**Tier Justification**: Measured at plan time, `suite_selection_select` returns the
`__FULL_SWEEP__` sentinel over this phase's path set — the sentinel is absorbing and two of the
four paths are files this phase creates, so no mapped suite covers the set — and the honest
covering checks are therefore named directly in the Verification block below:
`bash .claude/scripts/verify-touched.sh` over the same four paths (whose own OWED-NOT-PAID
fallback handles the unmapped new files), plus
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3 /home/benjamin/.config/nvim` for
the commit-blocking provides.scripts parity rule that no suite checks against this repo's own
manifest.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/sapience-publish.sh` - new; header, sourcing,
  worktree block, flag parsing, subcommand dispatch with four stubs
- `agent-system/extensions/sapience/scripts/tests/test-sapience-publish.sh` - new; harness, the
  scratch-tree builder, curl stub, structural + lockstep cases
- `agent-system/extensions/sapience/manifest.json` - add both new scripts to the
  provides.scripts array (coupled generated surface; gate 3 is commit-blocking on this)
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` - add the
  eighth entry to Case 30's `LOCKSTEP_FILES`

**Verification**:
- `bash agent-system/extensions/sapience/scripts/tests/test-sapience-publish.sh` passes all
  structural and lockstep cases
- `bash agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` passes,
  Case 30 included, with the eighth file in the array
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3 /home/benjamin/.config/nvim`
  reports no `script file on disk NOT in provides.scripts` finding and no
  `manifest script entry missing on disk` finding
- `bash .claude/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/sapience-publish.sh agent-system/extensions/sapience/scripts/tests/test-sapience-publish.sh agent-system/extensions/sapience/manifest.json agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh`
  is green
- `bash -n agent-system/extensions/sapience/scripts/sapience-publish.sh` and the same for the
  test file

---

### Phase 2: `doc-comment` and `dm` subcommands [NOT STARTED]

**Goal**: Both comment-shaped surfaces work, sharing one internal comment-POST helper, with the
`dm` subcommand's extra conversation-resolution step layered on top.

**Tasks**:
- [ ] Implement an internal helper (e.g. `_post_comment <slug> <body> [quote] [reply_to]
      [resolve]`) that builds the `POST /v1/docs/<slug>/comments` body as a JSON object via `jq`,
      omitting absent optional fields rather than sending nulls, and dispatches through
      `SAPIENCE_DRY_RUN=1 sapience_post` or `sapience_post` from the one payload.
- [ ] Pre-validate body length against `DOC_COMMENT_MAX` (4000) locally to fail fast, while still
      handling the server's own `413 {"error": "comment over 4000 chars"}` — local validation is
      never a substitute for handling the server response.
- [ ] Loud-failure handling for the comment POST written against **this** endpoint's verified
      201 shape `{slug, n, hash, author, at}`: a non-2xx `sapience_api_post_http_status`, or a
      2xx body missing `hash`/`n`, is a non-zero exit with the server's message on stderr.
      Include an inline comment contrasting this field set with `sapience-remember.sh`'s
      `written`/`gated`/`set_aside` fields, so the two are never conflated.
- [ ] Implement `doc-comment <slug> --body <text> [--quote <text>] [--reply-to <id>]
      [--resolve]`, calling the helper directly.
- [ ] Implement `dm --to <person-id> --body <text>`: first `POST /v1/people/dm {to: "<id>"}`,
      accepting both 201 (new conversation) and 200 (existing conversation reused) and
      distinguishing them in the printed outcome; extract `.slug` from the reply; then call the
      same `_post_comment` helper. The recipient is never taken from the comment body — the
      server resolves it.
- [ ] `dm --dry-run` prints **both** literal payloads in sequence (the `/v1/people/dm` body and
      the follow-on comment body), since the picker shows the user the literal payload before
      approval and a DM is two writes.
- [ ] Add test cases: dry-run prints the literal payload and makes no curl call; confirmed
      doc-comment on a 201 exits 0; a 413 over-length response exits non-zero; a 2xx body missing
      `hash` exits non-zero; `dm` on a 201 and on a 200 both exit 0 with distinguishable output;
      `dm` with a non-2xx from `/v1/people/dm` exits non-zero without ever reaching the comment
      POST; the comments-suffix stub branch is confirmed hit rather than the bare-slug branch.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts that once Phase 1 has landed, the selector resolves
this phase's two paths to the new suite rather than returning the absorbing `__FULL_SWEEP__`
sentinel it returns at plan time — the selector is content-derived from which suites reference a
script, so the mapping appears only after the suite exists and names it. Confirm by running
`bash .claude/scripts/verify-touched.sh` over this phase's two paths and reading its printed
selection; if it still reports the sentinel, the Phase 1 references did not land and that is a
Phase 1 defect to fix before proceeding rather than a reason to widen this phase's tier.

**Tier Justification**: Measured at plan time, `suite_selection_select` returns the
`__FULL_SWEEP__` sentinel over this phase's two paths (both are files this task creates, so
neither is in the corpus the selector maps from yet); the covering check named in the Verification
block below — `bash .claude/scripts/verify-touched.sh` over those same two paths, whose
OWED-NOT-PAID fallback handles exactly this unmapped case — is sufficient because the edit is confined to one script and its own suite, changes no externally visible
signature (the `/sapience` picker does not exist yet, so there are no call sites), and touches no
manifest or deploy surface.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/sapience-publish.sh` - shared comment-POST helper
  plus the doc-comment and dm subcommands
- `agent-system/extensions/sapience/scripts/tests/test-sapience-publish.sh` - comment and DM
  cases

**Verification**:
- `bash agent-system/extensions/sapience/scripts/tests/test-sapience-publish.sh` passes, with the
  new comment/DM cases green
- `bash .claude/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/sapience-publish.sh agent-system/extensions/sapience/scripts/tests/test-sapience-publish.sh`
  is green
- Manual read-through confirms the dry-run and confirmed paths share one payload-construction
  site (no second preview string anywhere in the file)
- `grep -n 'sapience_remember\|sapience_wrapup\|sapience_handoff\|sapience_adddoc' agent-system/extensions/sapience/scripts/sapience-publish.sh`
  shows no occurrence prescribing a write path

---

### Phase 3: `doc-version` subcommand [NOT STARTED]

**Goal**: Doc-version writes use the correct concurrency key and surface the three distinct
server outcomes as three distinct exit paths.

**Tasks**:
- [ ] Implement `doc-version <slug> --body-file <path> [--title <text>]`. The publisher fetches
      the current doc itself with one `sapience_get "/v1/docs/<slug>"` immediately before the
      write and sends that response's **`rev`** as `base_rev` — never its `hash`, and never a
      caller-supplied value the caller could race stale.
- [ ] Pre-validate the slug against `DOC_SLUG_RE` (`^[a-z0-9][a-z0-9._-]{0,79}$`) and the body
      against `DOC_BODY_MAX` (200000) to fail fast, while still handling the server's own
      400/413 responses.
- [ ] Exit path (a): `409` with `code:"head_moved"` — print the returned `head` object
      including its body (the server returns it, so no second GET is needed), exit non-zero,
      and never retry or overwrite. The message must make clear nothing was written.
- [ ] Exit path (b): `202` from the `can_edit:false` -> `people_propose` route — exit 0, but with
      an outcome string that says "proposed, awaiting owner" rather than "saved", so the future
      picker can tell the two apart.
- [ ] Exit path (c): `404` with `code:"share_gone"` — exit non-zero with a message stating that a
      `shared-*` slug with no existing document cannot be created by this route.
- [ ] Normal path: a 200/201 save exits 0 with the new revision identifier printed.
- [ ] All four outcomes are read from `sapience_api_post_http_status` plus the response body —
      one POST, no secondary HTTP call to discover the status.
- [ ] `--dry-run` prints the literal `{body, base_rev, title?}` payload, including the
      `base_rev` actually fetched, so the user approving it sees the real concurrency key.
- [ ] Add test cases: each of the four outcomes drives a distinct exit code/message via the curl
      stub; `base_rev` sent equals the stub GET's `rev` and **not** its `hash` (assert on the
      captured request body); the dry-run path performs the GET but no POST; an over-length body
      and a malformed slug are both refused locally before any network call.

**Timing**: 1.25 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes the doc-version POST and the doc-comments POST remain
distinguishable in the curl stub's `case` dispatch (the `/comments` pattern listed first, per
Phase 1). Confirm by asserting, in at least one doc-version case, that the bare-slug stub branch
was the one hit — a test that silently exercises the comments branch would pass for the wrong
reason.

**Tier Justification**: Measured at plan time, `suite_selection_select` returns the
`__FULL_SWEEP__` sentinel over this phase's two paths (both are files this task creates, so
neither is in the corpus the selector maps from yet); the covering check named in the Verification
block below — `bash .claude/scripts/verify-touched.sh` over those same two paths, whose
OWED-NOT-PAID fallback handles exactly this unmapped case — is sufficient because the edit stays inside that same single script and its own suite, changes no
signature, and touches no manifest or deploy surface.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/sapience-publish.sh` - `doc-version` subcommand with
  its pre-write GET and three distinct failure/alternate exit paths
- `agent-system/extensions/sapience/scripts/tests/test-sapience-publish.sh` - doc-version cases

**Verification**:
- `bash agent-system/extensions/sapience/scripts/tests/test-sapience-publish.sh` passes, with all
  four doc-version outcome cases green
- `bash .claude/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/sapience-publish.sh agent-system/extensions/sapience/scripts/tests/test-sapience-publish.sh`
  is green
- The `base_rev`-not-`base_hash` assertion is present and passing (this is the single most
  consequential correctness property of this phase)

---

### Phase 4: `ko` subcommand with runtime project-key resolution [NOT STARTED]

**Goal**: Repo-tagged knowledge-object writes carry the correct project key, resolved at runtime,
with `sapience-remember.sh`'s four-check loud-failure order reused verbatim.

**Tasks**:
- [ ] Implement `ko --note <text> [--note <text> ...] [--project <cid>]`, accepting the existing
      3-8-note-per-task bound as the only size bound — no second, independently-sized cap.
- [ ] Resolve the project key per Decision D5: `--project` override wins; else read
      `.sapience/project.json`'s `.project` (cid) from `${repo_toplevel}/.sapience/project.json`
      using the worktree block's `resolve_checkout_toplevel`; then
      `sapience_get "/v1/people/projects"`, unwrapped with the same defensive
      `(if has("projects") then .projects elif (type == "array") then . else [] end)` pattern
      `sapience-vault-read.sh` uses, matching the cid to recover `.key`.
- [ ] Refuse loudly (non-zero exit, nothing posted) when there is no binding, when the list call
      fails, or when no entry matches the cid. Never fall back to an untagged write and never
      derive the key from the binding's free-text `name`.
- [ ] Build each KO with `project: "<resolved key>"` and `explicit: true` set unconditionally.
      Never send `project_cid` — Non-Goals explains why.
- [ ] Reuse `sapience-remember.sh`'s loud-failure check verbatim in order and semantics:
      `set_aside` non-empty -> exit 2; `gated != 0` -> exit 2; `written` absent or 0 -> exit 2;
      `ok != true` -> exit 2. All four checked regardless of which the server would have hit
      first. Write an inline comment recording that this check is written against `_ingest_kos`'s
      verified field set (`ok`, `written`, `threads`, `gated`, `rejected`, `filtered`, plus
      conditional `set_aside`/`staged`), and that the dispatch-text paraphrase listing a `spend`
      field does not match this handler.
- [ ] `--dry-run` prints the literal `/ingest-kos` payload including the resolved `project` key,
      so the approver sees exactly what tag will be stamped.
- [ ] Add test cases: key resolution from a scratch `.sapience/project.json` binding matched
      against a stubbed project list; `--project` override wins over the binding; no binding ->
      non-zero exit, no POST; cid present but no matching entry -> non-zero exit, no POST; each
      of the four loud-failure shapes (`set_aside` non-empty, `gated: 1`, `written: 0`,
      `ok: false`) exits non-zero even when the response is otherwise success-shaped; a genuine
      `written >= 1` exits 0; the posted body carries `explicit: true` and carries **no**
      `project_cid` key.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes `GET /v1/people/projects` returns entries carrying both
a cid field matching `.sapience/project.json`'s `.project` and a short `key` field (the value
`_ko_matches_channel` compares against). The dispatch's live reference states key `oliver-ben`
for cid `mEdYrFW_qClSGDfx`, but research did **not** re-probe the live endpoint and this plan
hardcodes nothing. Confirm the actual response field names against
`sapience-vault-read.sh`'s existing project-list parsing before writing the stub fixture; if the
field names differ there, that script is the authority, not this hypothesis.

**Tier Justification**: Measured at plan time, `suite_selection_select` returns the
`__FULL_SWEEP__` sentinel over this phase's two paths (both are files this task creates, so
neither is in the corpus the selector maps from yet); the covering check named in the Verification
block below — `bash .claude/scripts/verify-touched.sh` over those same two paths, whose
OWED-NOT-PAID fallback handles exactly this unmapped case — is sufficient because the edit stays inside that same single script and its own suite, and the binding
file is read, never written, so no other script's inputs change.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/sapience-publish.sh` - the ko subcommand, runtime key
  resolution, four-check loud-failure block
- `agent-system/extensions/sapience/scripts/tests/test-sapience-publish.sh` - KO cases including
  all four loud-failure shapes

**Verification**:
- `bash agent-system/extensions/sapience/scripts/tests/test-sapience-publish.sh` passes, with all
  four loud-failure shapes asserted as non-zero exits
- `bash .claude/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/sapience-publish.sh agent-system/extensions/sapience/scripts/tests/test-sapience-publish.sh`
  is green
- `grep -n 'project_cid' agent-system/extensions/sapience/scripts/sapience-publish.sh` returns no
  occurrence that sends the field (an explanatory comment is permitted)
- A dry-run against the scratch fixture prints a payload whose `project` value is the resolved
  key, not the cid

---

### Phase 5: Deploy and closing verification [NOT STARTED]

**Goal**: The new script and suite are deployed into `.claude/scripts/`, gate 3's
deployed-vs-source drift rule is satisfied, and the task's complete verification obligation is
discharged.

**Tasks**:
- [ ] Confirm no source edits remain outstanding (Decision D3: the redeploy must come after the
      last source edit, or drift reopens).
- [ ] Run the headless deploy so `sapience-publish.sh` and `tests/test-sapience-publish.sh` reach
      `.claude/scripts/`, using the invocation form gate 3 itself requires (never the bare
      `scripts/deploy-headless.sh` form, which resolves from no working directory and exits 127).
- [ ] Confirm `.claude/scripts/sapience-publish.sh` and
      `.claude/scripts/tests/test-sapience-publish.sh` exist and `cmp -s` byte-identical to their
      source-store counterparts.
- [ ] Run the scoped touched-path check over every path this task touched.
- [ ] Record, in the phase's verification notes, that the complete gate set is deferred to the
      orchestration close rather than independently run in this dispatch.
- [ ] If any defect found here requires a source edit, fix it and **re-run the deploy step**
      before closing the phase.

**Timing**: 0.75 hours

**Depends on**: 4

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the deploy copies exactly the two new files into
`.claude/scripts/` and changes nothing else in the sapience extension's deployed surface. Confirm
with `git status --short` plus a `cmp -s` of each deployed copy against its source; a deployed
tree is gitignored, so the confirmation is the `cmp` result, not the git status.

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration (the deploy script), so the
  reserved sentinel is declared alongside the real paths below per plan-format.md's
  whole-tree-claim declaration rule
- `agent-system/extensions/sapience/scripts/sapience-publish.sh` - any defect fix surfaced by the
  closing checks
- `agent-system/extensions/sapience/scripts/tests/test-sapience-publish.sh` - any defect fix
  surfaced by the closing checks

**Verification**:
- Both deployed copies exist and `cmp -s` byte-identical to their source-store counterparts
- `bash .claude/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/sapience-publish.sh agent-system/extensions/sapience/scripts/tests/test-sapience-publish.sh agent-system/extensions/sapience/manifest.json agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh`
  is green — this is this phase's own in-dispatch obligation under `/orchestrate`
- The complete gate set (`bash .claude/scripts/verify-deploy.sh`) is **explicitly deferred to the
  orchestration close**, not independently invoked in this dispatch. On a standalone,
  non-orchestrated run of this plan (no orchestration close to defer to), run it directly here
  instead
- `bash .claude/scripts/tests/run-all.sh --only test-sapience-publish.sh,test-sapience-mcp-registration.sh,test-sapience-project-bind.sh`
  is green (the sapience suites most likely to be disturbed by this task)

---

## Testing & Validation

- [ ] All four subcommands refuse to write without `--confirm`, and `--dry-run` prints the
      literal payload the confirmed path would POST — produced by the same code path, verified by
      read-through, not by a second preview string
- [ ] `doc-comment` handles 201 success, 413 over-length, and a success-shaped body missing
      `hash` as three distinct outcomes
- [ ] `doc-version` sends the GET's `rev` as `base_rev` (asserted on the captured request body)
      and distinguishes 409 `head_moved`, 202 `people_propose`, and 404 `share_gone`
- [ ] `dm` reuses an existing conversation on 200 and creates on 201, distinguishably, and never
      reaches the comment POST when the conversation call fails
- [ ] `ko` resolves the project key at runtime, refuses loudly on every unresolvable case, sets
      `explicit: true`, sends no `project_cid`, and exits non-zero on all four silent-loss shapes
- [ ] The worktree block in `sapience-publish.sh` is byte-identical to its sibling copies, proven
      both locally (`test-sapience-publish.sh`) and globally (Case 30)
- [ ] No instruction surface in the new script names an MCP write tool as a prescribed write path
- [ ] Gate 3 reports no `provides.scripts` parity finding and no deployed-vs-source drift finding
      for the sapience extension after the Phase 5 deploy

## Artifacts & Outputs

- `agent-system/extensions/sapience/scripts/sapience-publish.sh` (new)
- `agent-system/extensions/sapience/scripts/tests/test-sapience-publish.sh` (new)
- `agent-system/extensions/sapience/manifest.json` (two `provides.scripts` entries added)
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` (one
  `LOCKSTEP_FILES` entry added)
- `.claude/scripts/sapience-publish.sh` and `.claude/scripts/tests/test-sapience-publish.sh`
  (deployed copies, regenerated — not hand-authored)

## Rollback/Contingency

The new script is additive: nothing existing calls it, and the `/sapience` picker that will call
it does not exist yet. A full rollback is therefore `git revert` of this task's commits, which
removes the two new files and restores the two edited files' prior content; a redeploy afterwards
removes the deployed copies.

Partial contingency, per phase:
- Phase 1 failing on gate 3 means the manifest edit and the on-disk files disagree — reconcile
  with `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --write` rather than
  hand-patching.
- Phase 1 failing Case 30 means the worktree block was retyped rather than extracted — re-extract
  it with `sed` from `sapience-project-bind.sh`.
- Phases 2-4 are independently revertable: each adds one subcommand plus its cases, leaving the
  scaffold from Phase 1 intact and the other subcommands untouched.
- Phase 5's deploy is idempotent and re-runnable; a drift finding after a late fix is resolved by
  re-running the deploy step, never by hand-editing the deployed copy under `.claude/`.

A defensive checkpoint before the Phase 5 deploy (the only phase touching a tree outside the
source store) can be taken with
`bash .claude/scripts/git-snapshot.sh 648 --no-revert` — a durable checkpoint that does not
revert the working tree. The default, reverting form belongs only to a genuine rollback.
