# Implementation Plan: Task #677

- **Task**: 677 - Sapience automatic writes and retrieval by project id
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: None blocking this plan. Live end-to-end exercise of the read-side path is gated on the app serving the link routes for this account (`sapience-app`'s `open_mvp_flags_and_create_linked_team_project`, not started; `repo_link_code_onto_release_line`, HOLD) and on `REPO_LINK_FOR` being non-empty in the deployed `fly.toml` (currently `""`). Every phase below is buildable and testable against a stub today.
- **Research Inputs**: specs/677_sapience_automatic_writes_and_retrieval_by_project_id/reports/01_sapience-project-id-automatic-paths.md
- **Artifacts**: plans/01_sapience-project-id-automatic-paths.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/context/standards/artifact-management.md
  - .claude/context/formats/tasks.md
  - .claude/rules/source-store-deploy-boundary.md
  - .claude/rules/sapience-write-path.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The Sapience extension's automatic read path (`sapience-retrieve.sh`, called from
`orchestrate-build-dispatch.sh`'s Stage 3.5 `memory_context` block) keys off the working
directory's basename only: it filters `GET /v1/search` by `source=[repo:<slug>]` and has no
project-aware code at all. This plan adds a single shared link resolver to the extension's
existing `scripts/lib/sapience-api-lib.sh`, wires the read path to send `project_cid` from the
committed `.sapience/project.json` binding while keeping the `source=` label filter as the
no-link and rejection fallback, and proves with a recorded-URL negative control that a repo with
no link file issues a request byte-identical to today's. It then states the current design in
`per-repo-scoping.md`, including the two distinct project-shaped parameters on `/v1/search` and
the vendor client's own unrelated `project` argument on `sapience_remember`. Done when the
read-side cases pass against the stub, the no-link control is unchanged, and the domain doc
states the design.

### Research Integration

The research report changes this plan's scope in one decisive way and sharpens it in three
others:

- **Write-side `project_cid` is excluded, not deferred.** `sf1-engine`'s
  `integration/project-link.md` section 10 Ruling 7 — which this repository's own
  `linked-repo-write-policy.md` agrees with by citation, and which
  `.claude/rules/sapience-write-path.md` restates as Ruling 1/Ruling 2 — forbids any write
  attaching a *verified* `project_cid` from an autonomous run until two named leak paths close;
  neither is closed. The server's `_ingest_kos` handler overwrites `ko['author']` with the real
  member's display name and delivers live (`follow: true`) on a verified cid, which is exactly
  the misattribution the ruling exists to prevent. The existing plain `project: "<key>"` design
  in `sapience-remember.sh` / `postflight-sapience-notes.sh` / `sapience-publish.sh ko` sits
  below that gate and is preserved untouched. See Goals & Non-Goals and Decisions.
- **Reads are explicitly exempted** by the same ruling ("reads … are unaffected and may proceed
  independently"), and `brain_server.py`'s `/v1/search` and `/v1/recent` handlers do honor a
  `project_cid` query parameter as a strict pre-filter (gated on `repo_link.enabled(tok)`).
  This is a *different* parameter from the plain `&project=` slug that `per-repo-scoping.md`
  already documents as silently ignored; both claims are true at once and must not be conflated.
- **The resolver is a shared-home question, not a correctness fix.** Three scripts duplicate the
  worktree/host/token blocks on purpose, each citing a narrower `file_scope`, and
  `test-sapience-mcp-registration.sh`'s Case 30 asserts the worktree block is byte-identical
  across nine copies (the registration hook, the verifier, and seven slug-deriving scripts --
  re-derived live from Case 30's own `LOCKSTEP_FILES` array at plan authoring time; the research
  report's "five copies" figure is stale). This plan therefore puts the new resolver in the lib taking an
  already-resolved toplevel as its argument, adding no sixth copy of that block and leaving
  Case 30's lockstep set untouched.
- **`repo_link.py`'s `find_link` walks upward; every local script does not.** The resolver keeps
  the existing single-location lookup (the only place `sapience-project-bind.sh` ever writes) and
  says so explicitly in its own header rather than leaving the divergence implicit.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's context, and no roadmap phases are requested
(`roadmap_flag` absent).

## Goals & Non-Goals

**Goals**:

- One shared link resolver, in `scripts/lib/sapience-api-lib.sh`, that maps an already-resolved
  checkout toplevel to the committed `.sapience/project.json` and validates it field for field
  against `repo_link.py`'s `parse_link` (exactly three string keys `project`/`name`/`repo`, the
  `^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$` repo regex, refusal of any token/key/secret-shaped key).
- `sapience-retrieve.sh` sends `project_cid` on `GET /v1/search` when a valid link is present,
  so a dispatch's memory block is drawn from the project's notes, with the existing
  `source=[repo:<slug>]` label filter retained as the no-link and rejection fallback.
- A `project_rejected` field in an otherwise-2xx search response is a benign, documented server
  outcome: a stderr warning and the label-filtered result, never the exit-2 transport-failure
  branch.
- With no link file (or a malformed one), the request `sapience-retrieve.sh` issues is
  byte-identical to today's, proved by a URL-recording negative control pinned *before* the code
  change lands and re-run unchanged afterward.
- `per-repo-scoping.md` states the current design: the read-side `project_cid` path, the
  `&project=` vs. `project_cid` parameter distinction, and the vendor `mcp.py`'s own unrelated
  `project` argument on `sapience_remember` (company-store routing via `route_ko()` /
  `project_slug()` against `config.json`'s `routes` map).

**Non-Goals**:

- **Sending `project_cid` on any write.** Task item (2) is excluded by Ruling 7 (see Research
  Integration and Decisions). `sapience-remember.sh`, `postflight-sapience-notes.sh`, and
  `sapience-publish.sh` are not edited by this plan, and no alternative mechanism that reaches
  the same verified-`project_cid` write outcome under another name is substituted for it.
- **A `project_rejected` → issue-row mapping on a write path.** There is no write path here that
  can receive that reply; `sapience-project-bind.sh`'s link route already classifies 403/404
  distinctly and needs no change.
- **Migrating the existing duplicated host/token or worktree-resolution blocks**, or
  `sapience-remember.sh`'s own project-key GET, onto the lib. Each is deliberately duplicated and
  pinned by Case 30; consolidating them is a separate, wider-`file_scope` task.
- **`injection-site-scoping.md`.** `sapience-retrieve.sh` is that doc's explicitly contrasted
  fourth path (dispatched subagents only, not one of its three named primary-session sites), so
  nothing this plan changes touches a claim it makes.
- **Whole-tree regeneration.** The source-store copies are edited and the suites are run with
  `CORE_TEST_SUBJECT_MODE=source-store`; no deploy is invoked, so no `` `__WHOLE_TREE__` ``
  claim is declared by any phase.
- **Live end-to-end verification against a project-linked account.** `REPO_LINK_FOR` is deployed
  `""`, both named app-side tasks are unmet, and this repository carries no
  `.sapience/project.json`. Stub-only verification is the intended bar for this task.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A future implementer reads task item (2) literally and wires `project_cid` into `sapience-remember.sh` or the postflight pass, reopening the autonomous-write leak Ruling 7 keeps closed | H | M | The exclusion is stated three times (Non-Goals, Decisions, Phase 4's doc task) and the three write scripts are absent from every phase's `Files to modify`; the implementer is instructed to treat an edit to them as out of scope, not an oversight |
| `/v1/search`'s rejection shape for a cid the account cannot access is unverified — the flag is dark, so it cannot be exercised live | M | H | Phase 3 handles it defensively: a `project_rejected` field in a 2xx body warns and proceeds label-filtered, and any non-2xx keeps today's exit-2 behavior. The stub covers both shapes. Phase 4's doc text says the shape is stub-verified, not server-verified |
| Concurrent sibling task 682 declares `per-repo-scoping.md` and `index-entries.json` in its own implement-phase `file_scope` this same cycle | M | H | Phase 4 re-reads both files immediately before editing, stages only its own hunks by explicit file list, and stops and reports a foreign uncommitted modification rather than proceeding (per the dispatch's concurrency note and `context/contracts/territory.md`) |
| Sourcing the lib from `sapience-retrieve.sh` breaks the suite's scratch-tree build, which copies only `lib/common.sh` | M | H | Phase 2 extends `build_scratch` to copy `lib/sapience-api-lib.sh` before Phase 3 adds the source line, so the harness is ready before the consumer needs it |
| A new copy of the worktree-resolution block in the lib would silently invalidate `test-sapience-mcp-registration.sh` Case 30's nine-copy byte-identity assertion | M | L | The resolver takes an already-resolved toplevel as a parameter and contains no copy of that block; Phase 5 re-runs that suite to confirm the lockstep set is unchanged |
| Editing `per-repo-scoping.md` moves its `line_count` in `index-entries.json`, which `check-extension-docs.sh` Rule R checks | L | H | `index-entries.json` is declared in the same phase that moves the count (Phase 4) and the one entry's `line_count` is reconciled there, by a targeted field update rather than a whole-tree regeneration |

## Decisions

- **Task item (2) — write-side `project_cid` — is excluded from this implementation**, on the
  grounds of `sf1-engine`'s `integration/project-link.md` section 10 Ruling 7 and this
  repository's agreeing `linked-repo-write-policy.md` Ruling 2 / `rules/sapience-write-path.md`.
  The exclusion is a decision, not a deferral this plan tracks: closing the two leak paths the
  ruling names is an obligation owed in `sf1-engine`'s own milestones, not work this repository's
  plan can discharge. The existing plain `project: "<key>"` write-side design is preserved
  exactly as committed.
- **Task item (1) — one shared resolver — is delivered for the link file only**, in the lib, with
  the host/token and worktree-resolution duplications left in place. Delivering it over all three
  surfaces would require editing `sapience-remember.sh` and `postflight-sapience-notes.sh` (whose
  own headers justify the duplication) and updating Case 30's lockstep set, for a simplification
  with no correctness payoff. The resolver's header names this boundary explicitly so the next
  reader sees a decided scope, not an unfinished migration.
- **The resolver mirrors `resolve_checkout_toplevel`'s single-location lookup, not
  `repo_link.py`'s upward `find_link` walk.** The two agree whenever the link file sits at the
  repository root, which is the only place `sapience-project-bind.sh` writes it; the single
  lookup is what every existing write path already relies on. The divergence is stated in the
  resolver's own header rather than left for a future reader to re-derive.
- **`project_cid` is sent alongside `source=`, not instead of it.** Keeping both parameters makes
  degradation free: a server with the flag off, or one that rejects the cid, still returns the
  label-matched rows with no second request, which is both the no-link fallback the task
  description asks for and the cheapest rejection path.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |

Phases within the same wave can execute in parallel. This plan is fully sequential: Phases 1, 2,
and 3 each touch `scripts/tests/test-sapience-capture.sh`, so running them concurrently would
mean two writers in one file rather than genuine parallelism.

### Phase 1: Shared Link Resolver in `lib/sapience-api-lib.sh` [COMPLETED]

**Goal**: One function, in the library two scripts already source, that resolves an
already-resolved checkout toplevel to a validated `.sapience/project.json` binding — agreeing
field for field with `repo_link.py`'s `parse_link` — with unit coverage for the accept and
reject cases.

**Tasks**:

- [x] Read `agent-system/extensions/sapience/scripts/lib/sapience-api-lib.sh` in full, including
      its CONTRACT header block, before editing. *(completed)*
- [x] Add `sapience_project_link_read <toplevel>`: echoes the link file's compact JSON and
      returns 0 on a valid binding; returns 1 with no output (and no stderr noise) when the file
      is absent, unreadable, not JSON, or fails validation. Validation mirrors
      `repo_link.py`'s `parse_link` exactly: the object carries exactly the three string keys
      `project`, `name`, `repo`; `repo` matches `^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$` and is never
      path-shaped; any token/key/secret-shaped key present is a refusal. *(completed)*
- [x] Add a companion `sapience_project_link_cid <toplevel>` (or document the single-function
      equivalent) that echoes just the `project` cid, so a consumer needing only the cid does not
      re-parse the JSON at its own call site. *(completed)*
- [x] Write the function's header contract: it takes an ALREADY-RESOLVED toplevel and contains no
      copy of the `sapience-worktree-checkout-resolution` block (so
      `test-sapience-mcp-registration.sh`'s Case 30 nine-copy lockstep set is unchanged by this
      task); it performs a single-location lookup at `<toplevel>/.sapience/project.json` and
      deliberately does NOT mirror `repo_link.py`'s upward, 40-level `find_link` walk, because
      the two agree wherever `sapience-project-bind.sh` writes the file and the single lookup is
      what every existing write path relies on. *(completed)*
- [x] Add unit cases to `agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh`
      that source the lib directly and call the resolver: a valid three-key binding (accepted,
      cid echoed), a missing file (returns 1, no output), a non-JSON file (returns 1), a
      four-key / token-shaped-key object (refused), and a path-shaped `repo` value (refused).
      *(completed: cases 13-17, 7 assertions, sourced via common_test_resolve_subject so
      CORE_TEST_SUBJECT_MODE=source-store picks up the freshly-edited lib rather than the stale
      deployed copy)*
- [x] Confirm the lib still sets no shell options of its own and that the new function behaves
      correctly under a caller running `set -euo pipefail`. *(completed: no `set` lines added;
      cases 13-17 source the lib from within `test-sapience-capture.sh`, itself running under
      `set -uo pipefail`)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/lib/sapience-api-lib.sh agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` covers this phase's two paths via `test-postflight-sapience-notes.sh`, `test-sapience-capture.sh`, `test-sapience-context-scoping.sh`, `test-sapience-project-bind.sh`, `test-sapience-publish.sh`, and `test-sapience-vault-read.sh`, which is the whole dependent set for an additive library function with no changed signature.

**Scope Hypothesis**: the worktree-resolution block currently exists in nine copies, re-derived at
plan authoring time from `test-sapience-mcp-registration.sh` Case 30's own `LOCKSTEP_FILES` array
(not carried from the research report, whose "five copies" figure is stale), and this phase adds
none. Confirm at implementation time with
`grep -rc 'BEGIN sapience-worktree-checkout-resolution' agent-system/extensions/sapience/scripts/`
plus the Case 30 run in Phase 5: a count other than nine means the lockstep set moved under this
task and Case 30's array, not just this plan's prose, needs re-reading.

**Files to modify**:

- `agent-system/extensions/sapience/scripts/lib/sapience-api-lib.sh` - add the link resolver (and cid accessor) plus its header contract; no existing function's behavior changes
- `agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` - add the resolver's accept/reject unit cases

**Verification**:

- [x] `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` passes, with the pre-existing cases 1-12 unchanged and the new resolver cases passing. *(completed: 43 passed, 0 failed)*
- [x] `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/sapience/scripts/tests/test-sapience-publish.sh` and `.../test-sapience-vault-read.sh` still pass (both source this lib). *(completed: 53 passed/0 failed and 19 passed/0 failed respectively)*
- [x] `grep -c 'BEGIN sapience-worktree-checkout-resolution' agent-system/extensions/sapience/scripts/lib/sapience-api-lib.sh` returns 0, confirming no sixth copy of the lockstep block was added. *(completed: returns 0)*

---

### Phase 2: URL-Recording Stub and the Pre-Change Negative Control [COMPLETED]

**Goal**: The test harness records every request URL, and today's `sapience-retrieve.sh` request
shape is pinned as an assertion *before* any code change — so the same assertion re-run after
Phase 3 is a real negative control for task item (4) rather than a restatement of the new code.

**Tasks**:

- [x] Extend `build_curl_stub` in `test-sapience-capture.sh` to append each invocation's URL (its
      last argument) to a `.curl_urls` recorder file alongside the existing `.curl_call_count`,
      and add a `curl_urls <stub_dir>` readback helper. The addition is additive: every existing
      case's dispatch behavior (the `_1`/`_2`/unsuffixed response tiers) is unchanged.
      *(completed)*
- [x] Extend `build_scratch` to also copy `lib/sapience-api-lib.sh` into
      `<scratch>/.claude/scripts/lib/`, so the scratch tree is ready for Phase 3's source line.
      *(completed)*
- [x] Add the negative-control case: with no `.sapience/project.json` anywhere under the scratch
      repo, assert the recorded URL's query-parameter set is exactly `q`, `source`, `limit`,
      `token` — no `project_cid`, no `project` — and that `source=` carries the fixture's own
      minted slug rather than a hardcoded name. *(completed: case 18)*
- [x] Add a `write_binding <scratch> <cid>` helper to this suite, mirroring the one
      `test-sapience-remember.sh` and `test-sapience-publish.sh` already use (same three-key
      `{project, name, repo}` shape), for Phase 3's link-present cases. *(completed)*
- [x] Run the suite against the UNMODIFIED `sapience-retrieve.sh` and confirm the
      negative-control case passes — this is the baseline that gives the control its force.
      *(completed: 46 passed, 0 failed, including case 18 against the unmodified script)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` covers this phase's single path via `test-postflight-sapience-notes.sh`, `test-sapience-capture.sh`, `test-sapience-context-scoping.sh`, and `test-sapience-project-bind.sh`, and this phase edits only a test harness with no production consumer.

**Scope Hypothesis**: this phase expects to touch exactly one file (the suite), because the
`.curl_urls` recorder and `build_scratch`'s extra copy are both local to it. Confirm at
implementation time by checking `git status --short` before staging: a second modified file means
the harness change leaked into a script and the phase boundary needs restating.

**Files to modify**:

- `agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` - URL recorder plus readback helper, `build_scratch` lib copy, `write_binding` helper, and the pre-change negative-control case

**Verification**:

- [x] `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` passes with the new negative-control case green against the unmodified script. *(completed: 46 passed, 0 failed)*
- [x] The recorded URL asserted by that case contains neither `project_cid` nor `project`, confirmed by the case's own assertion text rather than by inspection alone. *(completed: case 18 asserts the exact param-name set `limit q source token`)*

---

### Phase 3: Read-Side `project_cid` in `sapience-retrieve.sh` [COMPLETED]

**Goal**: A linked repository's dispatch memory block is drawn from the project's notes, an
unlinked or malformed-link repository's request is byte-identical to today's, and a
`project_rejected` reply degrades to the label-filtered result instead of looking like a
transport failure.

**Tasks**:

- [x] Re-read `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` immediately before
      editing. *(completed)*
- [x] Source `lib/sapience-api-lib.sh` after the existing `lib/common.sh` source and
      `PROJECT_ROOT` bootstrap. Do NOT call `sapience_api_init` and do NOT route the request
      through `sapience_get`: this phase changes the URL's query string only, leaving the
      script's own host/token resolution, `issue_request` function, cold-start retry, and exit-code
      split untouched, so the no-link request stays byte-identical. *(completed)*
- [x] After the repo-slug block, resolve the binding with the Phase 1 resolver against the
      already-resolved `$repo_toplevel`. On success, URL-encode the cid the same way every other
      parameter is encoded (`jq -rn --arg v "$cid" '$v|@uri'`) and append
      `&project_cid=${encoded_cid}` to the `/v1/search` URL. On any failure path (no file,
      malformed, failed validation), append nothing at all. *(completed)*
- [x] On a 2xx response whose JSON body carries a non-empty `project_rejected`, print one bounded
      stderr warning naming the rejection value and continue through the existing hit-extraction
      path unchanged — never exit 2, and never re-issue the request without the parameter (the
      retained `source=` filter already makes the response label-scoped). *(completed)*
- [x] Update the script's own header: the read path's `project_cid` parameter, its gating on the
      server's `REPO_LINK_FOR` flag, the `project_cid`-vs-`&project=` distinction, the
      no-link byte-identity guarantee, and the `project_rejected` benign-degrade rule. State that
      the script sends no `project_cid` on any write path because it makes none. *(completed)*
- [x] Add the link-present cases to `test-sapience-capture.sh`: a valid binding yields a URL
      carrying both `project_cid=<cid>` and the unchanged `source=[repo:<slug>]`; a malformed
      binding yields the Phase 2 control URL exactly; a 2xx body carrying `project_rejected`
      exits 0 with the envelope (or 1 on zero hits) plus the warning on stderr, never 2; a
      non-2xx response still exits 2 exactly as before. *(completed: cases 19-22, 13 assertions)*
- [x] Re-run Phase 2's negative-control case unmodified and confirm it still passes — this is
      task item (4)'s proof. *(completed: case 18 unmodified, still passes)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/sapience-retrieve.sh agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` covers this phase's two paths via `test-orchestrate-build-aux-dispatch.sh`, `test-orchestrate-build-dispatch.sh`, `test-orchestrate-context-growth.sh`, `test-postflight-sapience-notes.sh`, `test-sapience-capture.sh`, `test-sapience-context-scoping.sh`, `test-sapience-mcp-registration.sh`, and `test-sapience-project-bind.sh` — the enumerated dependent set including the Stage 3.5 dispatch-composition consumer of this script's exit codes.

**Files to modify**:

- `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` - source the lib, append `project_cid` when a valid binding resolves, benign-degrade on `project_rejected`, and update the header contract
- `agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` - link-present, malformed-link, `project_rejected`, and non-2xx cases

**Verification**:

- [x] `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` passes, with Phase 2's negative-control case green and unmodified. *(completed: 59 passed, 0 failed)*
- [x] The link-present case's recorded URL contains both `project_cid=` and `source=`, asserted against the fixture's own cid and minted slug. *(completed: case 19)*
- [x] `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/sapience/scripts/tests/test-sapience-context-scoping.sh` still passes (it exercises this script's envelope contract). *(completed: 6 passed, 0 failed)*
- [x] `grep -n 'project_cid' agent-system/extensions/sapience/scripts/sapience-remember.sh agent-system/extensions/sapience/scripts/postflight-sapience-notes.sh` shows only the pre-existing Non-Goal header text, confirming no write path acquired the parameter. *(completed: only lines 63/102/266 of sapience-remember.sh's pre-existing Non-Goal text; postflight-sapience-notes.sh has zero matches)*

---

### Phase 4: State the Current Design in `per-repo-scoping.md` [NOT STARTED]

**Goal**: The domain doc states the design a reader now faces: two distinct project-shaped
parameters on `/v1/search`, the read side's `project_cid` path and its fallbacks, the vendor
client's unrelated `project` argument, and the write side's unchanged plain-key design with its
governing ruling.

**Tasks**:

- [ ] Re-read `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`
      immediately before editing, and check `git status --short` for a foreign uncommitted
      modification to it or to `index-entries.json`: both are in concurrent sibling task 682's
      declared `file_scope` this cycle. On a foreign modification, stop and report rather than
      proceeding.
- [ ] In the `## The Mechanism, and Why It Is the Only One That Works` section's
      "**`project` is a dead end**" bullet, add the parameter distinction: `&project=` (a plain
      slug) is silently ignored by `/v1/search`, while `project_cid` is a different parameter
      that `/v1/search` and `/v1/recent` do honor as a strict pre-filter — verified in
      `brain_server.py`'s own handlers, gated on `repo_link.enabled(tok)` (the `REPO_LINK_FOR`
      flag, deployed `""` for this account), so it is unexercisable live today and is
      stub-verified only. Both statements are true at once; the existing dead-end claim about
      `&project=` stands as written.
- [ ] In `## Why the MCP Write Tools Cannot Produce a Tagged Write`, add a short paragraph on the
      installed vendor `~/.sapience/mcp.py`'s `project` argument to `sapience_remember`: it
      exists, and it is company-store ROUTING (`project_slug()` / `route_ko()` matched against
      `config.json`'s `routes` map, falling back to `COMPANY_PROJECT` / `SAPIENCE_PROJECT`) that
      picks which token a write posts to — unrelated to the per-repository link mechanism, and
      still unable to produce a tagged write for the reason the section already gives. This is a
      discussion site, not a write-path prescription (`rules/sapience-write-path.md`'s
      "Discussing a Tool vs. Prescribing It as a Write Path").
- [ ] In `## The Two Scripts`, extend the `sapience-retrieve.sh` bullet with the read-side
      `project_cid` behavior: sent when a valid `.sapience/project.json` resolves through the
      shared resolver, alongside the retained `source=` label filter; no parameter and a
      byte-identical request with no link or a malformed one; a `project_rejected` reply is a
      benign label-filtered degrade with a stderr warning, not the exit-2 branch.
- [ ] Add a short statement of the write side's current design and its boundary: the write path
      sends a plain `project: "<key>"` resolved from the binding's cid and never `project_cid`,
      because a verified `project_cid` write is the one `sf1-engine` section 10 Ruling 7 holds
      shut while two named leak paths remain open — citing `linked-repo-write-policy.md` and
      `rules/sapience-write-path.md` as the durable carriers rather than restating their rulings.
- [ ] Name the shared resolver and its boundary: `sapience_project_link_read` in
      `scripts/lib/sapience-api-lib.sh` is the one link reader, taking an already-resolved
      toplevel; the host/token and worktree-resolution duplications are unchanged and still
      pinned by `test-sapience-mcp-registration.sh` Case 30.
- [ ] Update this file's `line_count` in `agent-system/extensions/sapience/index-entries.json`
      (currently `502` for `project/sapience/domain/per-repo-scoping.md`) to the post-edit
      `wc -l` value, by a targeted single-field edit — not by invoking any whole-tree
      regeneration.
- [ ] Write no task-number reference into either file (`.claude/rules/no-task-references-in-deliverables.md`)
      and no record-versioning language (`.claude/rules/no-record-versioning-in-deliverables.md`):
      state the current design, not what an earlier draft said.

**Timing**: 1.25 hours

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md agent-system/extensions/sapience/index-entries.json` covers this phase's two paths via `test-context-reachability.sh`, `test-deploy-orphans.sh`, `test-index-entries-schema.sh`, `test-install-uninstall-extension.sh`, `test-manifest-scripts-sync.sh`, and `test-roadmap-command-registration.sh`, which together cover the index schema and context-reachability surfaces a prose-plus-`line_count` edit can break.

**Scope Hypothesis**: this phase expects the `line_count` for exactly one index entry
(`project/sapience/domain/per-repo-scoping.md`, carried from `index-entries.json` at plan
authoring time as `502`, matching `wc -l` on that file) to move, and no other entry's to. Confirm
at implementation time with `jq`-diffing `index-entries.json` against `git show HEAD:` before
staging; a second changed entry means a sibling's edit was captured and must be unstaged.

**Files to modify**:

- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` - parameter distinction, vendor `project`-argument paragraph, read-side behavior, write-side boundary, resolver note (also in concurrent task 682's declared scope: re-read before editing)
- `agent-system/extensions/sapience/index-entries.json` - reconcile this one entry's `line_count` (also in concurrent task 682's declared scope: re-read before editing)

**Verification**:

- [ ] `wc -l agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` equals the `line_count` recorded for `project/sapience/domain/per-repo-scoping.md` in `index-entries.json`.
- [ ] `jq -e . agent-system/extensions/sapience/index-entries.json` succeeds and `git diff` on that file shows exactly one changed `line_count` field.
- [ ] `bash .claude/scripts/check-task-references.sh` (or the repo's own entry point for that lint) reports no new finding for either file, and exits 0.
- [ ] `git diff --staged` before the commit lists only this phase's two files, with no sibling hunks.

---

### Phase 5: Close the Round [NOT STARTED]

**Goal**: Every suite this task's paths reach is green against the source-store copies, the
lockstep and write-path invariants are re-confirmed unbroken, and the complete gate set is
handed to the orchestration close.

**Tasks**:

- [ ] Run, with `CORE_TEST_SUBJECT_MODE=source-store`:
      `test-sapience-capture.sh`, `test-sapience-remember.sh`,
      `test-postflight-sapience-notes.sh`, `test-sapience-publish.sh`,
      `test-sapience-vault-read.sh`, `test-sapience-project-bind.sh`,
      `test-sapience-context-scoping.sh`, and `test-sapience-mcp-registration.sh` — the last
      specifically to confirm Case 30's nine-copy worktree-block byte-identity assertion still
      passes with no copy added or removed.
- [ ] Re-confirm the write-path invariant by inspection: `sapience-remember.sh`,
      `postflight-sapience-notes.sh`, and `sapience-publish.sh` are unmodified by this task
      (`git diff HEAD --stat` lists none of them), and no instruction surface added in Phase 4
      names an MCP write tool as a write path.
- [ ] Run the scoped touched-path check over this task's own paths:
      `bash agent-system/extensions/core/scripts/verify-touched.sh` with the four files this
      task modified, and record its verdict.
- [ ] Record, in this phase's own verification notes, that the complete gate set is DEFERRED to
      the orchestration close (`context/contracts/batch-gate-stage.md`) rather than independently
      run in this dispatch, per `plan-format.md`'s "Batch-aware deferral".
- [ ] Emit the 3-8 `sapience_notes` the postflight pass consumes, and the `memory_candidates` the
      round's findings warrant, in `.return-meta.json`.

**Timing**: 0.75 hours

**Depends on**: 4

**Verification Tier**: full

**Files to modify**:

- `specs/677_sapience_automatic_writes_and_retrieval_by_project_id/summaries/01_sapience-project-id-automatic-paths-summary.md` - the round's completion summary

**Verification**:

- [ ] All eight named suites pass under `CORE_TEST_SUBJECT_MODE=source-store`, with
      `test-sapience-mcp-registration.sh`'s Case 30 explicitly green.
- [ ] `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/lib/sapience-api-lib.sh agent-system/extensions/sapience/scripts/sapience-retrieve.sh agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md agent-system/extensions/sapience/index-entries.json` reports a passing narrowed verdict, exit status checked, not only its printed output read.
- [ ] Under `/orchestrate`, the complete gate set (`verify-deploy.sh`) is DEFERRED to the
      once-per-invocation orchestration close and that deferral is stated in this phase's closing
      notes; in a standalone, non-orchestrated run with no such close, `bash .claude/scripts/verify-deploy.sh`
      is run directly here instead.

---

## Testing & Validation

- [ ] No-link negative control: the recorded `/v1/search` URL carries exactly `q`, `source`,
      `limit`, `token` — pinned before the code change and unchanged after it.
- [ ] Link-present: the recorded URL carries `project_cid=<fixture cid>` and the unchanged
      `source=[repo:<minted slug>]`.
- [ ] Malformed link file: the recorded URL equals the no-link control URL.
- [ ] `project_rejected` in a 2xx body: exit 0 with the envelope (or 1 on zero hits), one stderr
      warning, never exit 2.
- [ ] Non-2xx and curl-transport failures: exit 2 with the existing diagnostic, unchanged.
- [ ] Resolver unit cases: valid three-key binding accepted; absent, non-JSON, extra-key,
      token-shaped-key, and path-shaped-`repo` inputs all refused with no output.
- [ ] `test-sapience-mcp-registration.sh` Case 30 passes: the worktree-resolution block remains
      byte-identical across its nine existing copies, with no tenth added.
- [ ] `index-entries.json` `line_count` for `per-repo-scoping.md` matches `wc -l`.

## Artifacts & Outputs

- `agent-system/extensions/sapience/scripts/lib/sapience-api-lib.sh` — the shared link resolver
  (`sapience_project_link_read`, plus the cid accessor) and its header contract.
- `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` — the read-side `project_cid`
  path, its no-link byte-identity guarantee, and the `project_rejected` benign degrade.
- `agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` — URL recording, the
  pre-change negative control, the link-present/malformed/`project_rejected` cases, and the
  resolver unit cases.
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` — the
  stated current design.
- `agent-system/extensions/sapience/index-entries.json` — the reconciled `line_count`.
- `specs/677_sapience_automatic_writes_and_retrieval_by_project_id/summaries/01_sapience-project-id-automatic-paths-summary.md`
  — the round's summary.

## Rollback/Contingency

Each phase is one commit against one or two files, so reverting is per-phase and ordinary:
`git revert <sha>` for the phase's commit, newest first, since Phase 3 depends on Phase 2's
harness and Phase 1's resolver. No phase regenerates a deployed tree, writes outside
`agent-system/extensions/sapience/**` and this task's own `specs/**` directory, or mutates any
state a later `/orchestrate` cycle reads.

If a working-tree rollback of uncommitted work is genuinely needed mid-phase, take the snapshot
first per `context/contracts/recovery.md`'s rollback rung (including its out-of-scope override
flag for a deliberately wider revert) and then run the destructive command — never a bare
precautionary `git-snapshot.sh` as a routine checkpoint; `--no-revert` is the form for an
ordinary defensive checkpoint before risky work.

Contingency on the one external unknown: if `/v1/search` turns out, once `REPO_LINK_FOR` is live
for this account, to reject an unauthorized `project_cid` with a non-2xx status rather than a
`project_rejected` field in a 2xx body, Phase 3's `project_rejected` branch never fires and the
request falls into the existing exit-2 degrade — a fail-open path that loses the memory block for
that dispatch but breaks nothing. The fix at that point is a one-line addition to the status
case, not a redesign; the plan deliberately does not pre-build it, since the shape is unverifiable
today.
