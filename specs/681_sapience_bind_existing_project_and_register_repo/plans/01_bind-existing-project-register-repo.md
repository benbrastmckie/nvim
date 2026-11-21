# Implementation Plan: Task #681

- **Task**: 681 - Let the Sapience extension bind a repository to an existing shared project as
  well as to a new one, and register the repository with the server
- **Status**: [IMPLEMENTING]
- **Effort**: 8 hours
- **Dependencies**: None blocking. Ordered before
  `sapience_automatic_writes_and_retrieval_by_project_id`, which reads the file this task writes.
- **Research Inputs**: specs/681_sapience_bind_existing_project_and_register_repo/reports/01_bind-existing-project-register-repo.md
- **Artifacts**: plans/01_bind-existing-project-register-repo.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`sapience-project-bind.sh` gains a second mode alongside its existing create-a-fresh-project
mode: a read-only pick that lists the caller's accepted and owned projects, and a
`--project <name|id>` bind that registers this repository with the chosen project through
`POST /v1/people/projects/<cid>/link` and persists the same three-key `.sapience/project.json`.
The script becomes the sole writer of that file on every path, including the path that delegates
the bind to the installed vendor client, which is what makes requirement (4)'s byte-identity
claim provable rather than asserted. `/sapience` then surfaces the pick as a candidate option
inside its one existing approval picker rather than stopping dead, and the two domain docs gain
the link-route record the extension currently lacks entirely.

### Premise Re-Validation

The dispatch's `## Description` carries one long trigger-class line. Every load-bearing claim in
it was re-checked against live state during this planning dispatch, not taken on the prior
artifact's word:

| Dispatch claim | Verdict |
|---|---|
| `sapience-project-bind.sh` has one mode (create via `POST /v1/people/projects/share`) | **Confirmed.** Its argument loop accepts exactly `--name`, `--confirm`, `--to`, `-h/--help`; the one POST is to `/v1/people/projects/share`. |
| It never calls `POST /v1/people/projects/<cid>/link` | **Confirmed.** A grep for the link route across every script in the extension's source store returns nothing. |
| It cannot bind to a project the caller already belongs to | **Confirmed.** No `GET /v1/people/projects` call exists in the file at all; the only discovery call is `GET /v1/people` for collaborators. |
| With two connections of the same display name it refuses without `--to` | **Confirmed, with the mechanism narrowed**: the refusal fires on *any* connection count other than exactly 1, not specifically on a duplicate display name. |
| It writes the three-key `.sapience/project.json` | **Confirmed**, via the `jq -n --arg project --arg name --arg repo` call that is byte-identical to the server's `link_text()` serializer. |
| The vendor client carries `sapience link [<name or id>]` which lists accepted and owned projects, registers the repository, and writes the same file | **Confirmed** in the dev-source client (`link_cmd`, `_link_pick_project`), read directly this dispatch. |
| The installed client predates it | **Confirmed live**: `grep -c "sub == 'link'"` returns `0` against the installed `~/.sapience/sapience_cli.py` (1122 lines) and `1` against the dev-source copy. |
| 404 means the feature is not available for this account | **Confirmed but genuinely ambiguous**: the server returns the same `404` both when `repo_link.enabled(tok)` is false and when the cid/membership lookup misses, differing only in body prose. The plan's 404 policy is deliberately safe under either reading. |

Two refinements from research materially change the implementation and are carried as hard
constraints below, not as notes: the real `GET /v1/people/projects` response shape, and the link
response's `project` field not being a cid.

### Research Integration

- **The response shape is `{ok, candidates, shared, received, invites, ...}`** — not
  `{projects: [...]}` and not a bare array. Row set is `shared + received` filtered to
  `accepted or owner`. Two existing call sites in this same extension
  (`sapience-publish.sh`'s `ko`, `sapience-vault-read.sh`'s `notes_cid`) use a
  `has("projects")`-shaped jq expression that resolves to `[]` against this response. Those two
  files are **outside this task's declared territory** and must not be touched here; the new code
  must not copy their idiom. See Risks.
- **The link route's 200 response `project` field is the `{kind, key, name}` descriptor dict, not
  the channel cid.** The create path's `.share.id` extraction must never be reused for it. The
  bind path already holds the cid from its own pick step and needs nothing back from the
  response.
- **The `sapience` binary on `$PATH` cannot reach `link` at all** — it is a packaged bash wrapper
  with a fixed `case` table, no `link` branch and no fallback into the Python argument parser.
  Delegation invokes `python3 "<client path>" link ...` directly, and detection is a static grep
  against the client source, never a live invocation.
- **The vendor's `--name` means the repository short name**; this script's `--name` means the
  display name of the project being created. The two are never conflated.
- Server gate order, confirmed from source: write gate (401) → `repo_link.enabled` (404) →
  channel/membership lookup (404) → unaccepted member (403) → success (200).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided in this dispatch's delegation context; `specs/ROADMAP.md` was not
consulted and is not modified.

## Goals & Non-Goals

**Goals**:

- A `--project <name|id>` bind mode that registers this repository with an existing accepted or
  owned project and writes `.sapience/project.json`.
- A no-argument pick mode that lists the caller's accepted and owned projects and exits non-zero
  without writing.
- The create mode preserved exactly as it is today, behind its existing `--name` / `--confirm`
  pair.
- `404` and `403` from the link route handled as two distinct, named outcomes: 404 writes the file
  and says the server does not read it yet; 403 writes nothing.
- Delegation to the installed vendor client when it supports `link`, with this script's own HTTP
  path as the fallback, and the written file byte-identical on either path, proved by a test.
- The caller's role stated in the reply, so binding to someone else's project is a known choice.
- The pick surfaced in `/sapience` through its one existing approval picker.
- The reply ends with the exact file to commit; the script commits nothing.

**Non-Goals**:

- Fixing the latent `GET /v1/people/projects` schema mismatch in `sapience-publish.sh` and
  `sapience-vault-read.sh` (out of declared territory; see Risks for the follow-up).
- Enabling `REPO_LINK_FOR` for this credential, or any server-side change.
- Changing `/sapience`'s argument grammar or adding a second `AskUserQuestion` call.
- Any change to `commands/sapience.md`: it states the one-approval-picker guarantee and defers
  every detail to the skill and the domain record, and the bind pick is an internal
  Stage-1-into-Stage-9 wiring change inside the skill rather than a new flag. The file is named in
  the task's territory but needs no edit; this is stated so a reader does not read its absence
  from the phases below as an oversight.
- Any hand-edit under `.claude/**`, and any `deploy-headless.sh` run inside a phase. See
  Risks for how the deployed mirror is handled.

## Decisions

**D1 — The 404-write requirement and the delegation requirement are reconciled by making this
script the sole writer.** Requirement (3) (a 404 still writes the file) and requirement (4)
(delegate pick-and-register to the vendor) are not simultaneously satisfiable by pure delegation:
the vendor's `link_cmd` prints "Nothing was written." and returns 1 on a 404. The resolution:

1. Delegation applies only to `--project <value> --confirm`, never to the no-argument listing —
   the vendor's listing deliberately exits 1 and emits only human-formatted prose, so there is
   nothing machine-readable to delegate to.
2. When the vendor exits 0 and a link file is present, this script reads the three keys back out
   and re-renders them through its own single `write_link_file()` helper, so the bytes on disk are
   this script's canonical rendering on either path. Byte-identity becomes an enforced invariant
   rather than a hope about two independent serializers, and the test proving it is meaningful
   rather than circular.
3. When the vendor exits non-zero, or exits 0 with no file, this script falls through to its own
   HTTP path, which classifies the outcome by **status code** and applies the documented 404/403
   policy. No vendor stderr prose is parsed anywhere — that prose is not a contract.

Accepted consequence, to be stated in the script's own header: against a link-capable client, a
404 or 403 fires the vendor's POST and then this script's POST. Both are non-mutating at those
statuses, so the duplicate is harmless; the alternative (reading the outcome out of English
sentences) is not.

**D2 — Bind mode inherits the existing dry-run/`--confirm` posture.** Default (no `--confirm`)
resolves the target and prints the literal link payload without POSTing; `--confirm` performs the
real call. This is what lets `/sapience`'s Stage 7 preview and Stage 10 confirmed execution reuse
one identical argument vector, which is the discipline the other four surfaces already follow.
One deliberate asymmetry to document: create-mode dry-run makes *no* network call at all, while
bind-mode dry-run makes the one resolving `GET` — a read, not a mutation.

**D3 — Matching mirrors the vendor's three-field rule** (`id`, `title`, `project.key`,
case-insensitive, exactly one row or refuse). One widening: the vendor lowercases the search term
before comparing it to a raw `id`, so a cid containing uppercase cannot be matched by id there.
This script compares the id case-insensitively too — a superset of the vendor's behavior, noted in
the script header so the divergence is deliberate rather than accidental.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| New pick code copies the broken `has("projects")` jq idiom from the two adjacent call sites | H | M | Phase 1's row-extraction task names the correct expression explicitly and forbids the idiom in an inline comment; a Phase 1 test asserts a row is extracted from a real-shaped `{shared, received}` fixture, which the broken idiom cannot satisfy |
| The latent mismatch in `sapience-publish.sh` / `sapience-vault-read.sh` stays silently broken | M | H | Out of declared territory and deliberately untouched. Recorded here and in the final phase's doc update as a named follow-up, so it is discoverable rather than lost |
| The create path's `.share.id` extraction is copy-pasted into the bind path, writing a descriptor dict where a cid belongs | H | M | Phase 2 carries this as an explicit MUST NOT with an inline comment at the extraction site; the bind path takes its cid from the picked row and never reads one out of the link response |
| Vendor stderr prose is parsed to classify 404 vs 403 | M | M | D1 forbids it structurally: classification is status-code-only, in this script's own HTTP path |
| The marker-delimited `sapience-worktree-checkout-resolution` block is edited, breaking the lockstep guard shared with four other scripts | H | L | Every script-touching phase carries a Scope Hypothesis excluding that block; `test-sapience-project-bind.sh`'s existing case 14 and `test-sapience-mcp-registration.sh`'s case 30 both fail loudly if it diverges |
| Tests silently verify the stale deployed copy instead of the edited source | H | H | Every in-phase verification exports `CORE_TEST_SUBJECT_MODE=source-store`; `common_test_resolve_subject` otherwise prefers the deployed tree, which this dispatch's own freshness notice reports stale for this extension |
| Concurrent sibling task 683 declares `per-repo-scoping.md` in its own `file_scope` — the same file the final phase edits | M | M | The final phase **appends a new section** and edits no existing one in that file; it re-reads the file immediately before editing, stages only its own hunks, and stops and reports if a foreign modification is present |
| The deployed `.claude/**` sapience mirror stays stale, so a later reader runs old code | M | H | Already stale before this task; no phase hand-patches it and no phase runs the deploy script (which would be a whole-tree claim serializing against three concurrent siblings). The redeploy is deferred to the orchestration close, stated explicitly in the final phase |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Pick Mode — Listing and `--project` Resolution (Read-Only) [COMPLETED]

**Goal**: `sapience-project-bind.sh` can list the caller's accepted and owned projects and
resolve a `--project <name|id>` to exactly one row, writing nothing and POSTing nothing.

**Tasks**:

- [x] Extend the argument loop with `--project <name|id>` and `--force`, keeping `--name`,
      `--confirm`, `--to` unchanged. Refuse loudly when both `--name` and `--project` are given
      (two different modes, never silently preferring one). *(completed: also added an explicit
      refusal for `--confirm` given with neither `--name` nor `--project`, needed to keep
      pre-existing Case 2 green under the new mode selector)*
- [x] Replace the unconditional `--name is required` guard with a mode selector: `--name` present
      → create mode (today's behavior, unchanged); `--project` present → bind mode; neither →
      pick mode. *(completed)*
- [x] Add a row-extraction helper over `sapience_get "/v1/people/projects"`: validate the body is
      JSON, then take `(.shared // []) + (.received // []) | map(select(.accepted or .owner))`.
      Add an inline comment stating that `has("projects")` / bare-array handling is **wrong** for
      this endpoint and naming the two adjacent call sites that use it, so the idiom is not
      reintroduced by a future reader. *(completed: fetch_project_rows())*
- [x] Pick mode: print one line per row as `<title>  (<id>)  [creator|member]`, derived from the
      row's own `owner` flag; exit 1; write nothing. An empty filtered row set is its own named
      refusal ("you are not on any shared project yet"), exit 1. *(completed)*
- [x] `--project <value>`: match case-insensitively against `id`, `title`, and `project.key`;
      exactly one match or a named refusal pointing at the no-argument listing, exit 1. Capture
      `cid` (the row's `id`), `display_name` (`title // project.name // id`), and `owner`.
      *(completed: resolution only in this phase, per the phase Goal -- the resolved
      cid/display_name/owner are printed and the script exits 0 with no write/POST; a later phase
      replaces that exit with the dry-run/--confirm link-registration flow)*
- [x] Update the file header comment and `usage()` for the three modes and the new flags, and
      extend the exit-code table. *(completed)*
- [x] Extend the test suite's curl stub with a branch for `*v1/people/projects\?*` driven by
      `GET_PROJECTS_BODY` / `GET_PROJECTS_CODE`, placed alongside the existing
      `*v1/people/projects/share*` branch (the two URL patterns are disjoint — `/projects?` versus
      `/projects/<cid>/share` — so no ordering dependency is introduced; assert this by keeping
      both cases green). *(completed)*
- [x] Add test cases 15-17: (15) pick mode lists one `shared` row and one `received` accepted row
      with the correct `[creator]`/`[member]` labels, exits non-zero, writes nothing; (16) a
      `received` row with `accepted: false` and `owner: false` is excluded from the listing;
      (17) `--project nonexistent` refuses with a non-zero exit and writes nothing. *(completed)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/sapience-project-bind.sh agent-system/extensions/sapience/scripts/tests/test-sapience-project-bind.sh`
covers this phase's whole touched set — `suite_selection_select` over both paths together returns
exactly `test-sapience-project-bind.sh` and `test-sapience-mcp-registration.sh`, with no
unmapped-path sentinel.

**Scope Hypothesis**: this phase adds exactly three new test cases (15-17) and touches exactly two
files; it does **not** edit the marker-delimited `sapience-worktree-checkout-resolution` block,
`scripts/lib/sapience-api-lib.sh` (the existing `sapience_get` needs no change), or either of the
two out-of-territory `GET /v1/people/projects` call sites. The implementer confirms the case
numbering by grepping the suite for its highest existing `common_test_pass "(N)` before adding,
and confirms the two-file scope by `git status --short` before staging.

**Files to modify**:

- `agent-system/extensions/sapience/scripts/sapience-project-bind.sh` - mode selector, `--project`
  / `--force` flags, row extraction and matching, pick-mode listing, header and usage
- `agent-system/extensions/sapience/scripts/tests/test-sapience-project-bind.sh` - projects-endpoint
  stub branch, cases 15-17

**Verification**:

- [ ] `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/sapience/scripts/tests/test-sapience-project-bind.sh`
      passes with every pre-existing case (1-14) still green and the three new cases green.
- [ ] `bash -n agent-system/extensions/sapience/scripts/sapience-project-bind.sh` exits 0, and
      `bash .claude/scripts/lint/lint-shellcheck.sh agent-system/extensions/sapience/scripts/sapience-project-bind.sh agent-system/extensions/sapience/scripts/tests/test-sapience-project-bind.sh`
      exits 0.
- [ ] `bash .claude/scripts/verify-touched.sh <the two paths above>` green.
- [ ] A manual read confirms no `has("projects")` expression was introduced.

---

### Phase 2: Link Registration, the 404/403 Policy, Canonical Write, Role Note [COMPLETED]

**Goal**: bind mode registers the repository through the link route, applies the two named
non-success policies, writes the canonical three-key file through one writer, and reports the
caller's role and the file to commit.

**Tasks**:

- [x] Extract today's `jq -n --arg project --arg name --arg repo '{project: $project, name: $name,
      repo: $repo}'` write into a `write_link_file()` helper taking cid, display name, and repo
      slug. Route the existing create path through it unchanged, so exactly one writer exists in
      the file. *(completed)*
- [x] Bind-mode default posture (no `--confirm`): after resolving the row in Phase 1, print the
      literal `POST /v1/people/projects/<cid>/link` payload (`{"repo": "<slug>"}`) via
      `SAPIENCE_DRY_RUN=1 sapience_post` and exit 0 without POSTing. Document in the header that
      this posture makes the one resolving `GET` (a read) while create-mode dry-run makes no call
      at all. *(completed)*
- [x] Existing-link guard: when `.sapience/project.json` already exists and its `project` differs
      from the resolved cid, refuse with the exact re-run instruction naming `--force`, exit 1,
      write nothing. `--force` overwrites. *(completed: checked once, before both the dry-run
      print and the confirmed POST, since it governs whether the invocation should proceed at
      all)*
- [x] `--project <value> --confirm`: POST `{"repo": "<slug>"}` to
      `/v1/people/projects/<cid>/link`, then branch on `sapience_api_post_http_status` only:
      - `2xx` with `.ok == true` → `write_link_file()`, report success, exit 0.
      - `404` → `write_link_file()` anyway, report plainly that the server did not accept the link
        and does not read the file yet (binding recorded locally only), exit 0.
      - `403` → write nothing, report "join the project first", exit 2.
      - any other non-2xx, a non-JSON body, or a missing `ok: true` → loud named failure, write
        nothing, exit 2.
      *(completed: discovered and worked around a latent bug in this sense -- calling
      `sapience_post` via `x="$(sapience_post ...)"` command substitution forks a subshell, so
      its non-local `sapience_api_post_http_status` assignment never reaches the caller and
      reads back empty; the bind path instead redirects `sapience_post`'s stdout to a temp file,
      which keeps the call in-process so the status assignment is actually visible. Recorded
      inline in the script and as an issue-log entry; `sapience-api-lib.sh` itself is untouched,
      staying within this phase's declared scope)*
- [x] Add an inline MUST NOT comment at the response-handling site: the cid comes from the picked
      row; the link response's `project` field is the `{kind, key, name}` descriptor dict and is
      never a cid, unlike the share response's `.share.id`. *(completed)*
- [x] Role note, from the picked row's own `owner` flag (no extra call): creator → their notes flow
      to the collaborator; non-creator accepted member → their notes land as suggestions only the
      author sees until confirmed. Printed on the success path and on the 404 path. *(completed)*
- [x] End the reply with the exact file to commit (`<toplevel>/.sapience/project.json`). Confirm by
      grep that the bind path contains no `git` invocation of any kind. *(completed: grep over
      the bind-mode block for "git " returns no match)*
- [x] Add test cases 18-21: (18) bind success writes the three-key file byte-identically to the
      expected `link_text()` output and calls the link route exactly once (the stub increments a
      counter file per link-URL hit; assert `1`); (19) a `404` from the link route writes the file
      and the report names the degraded state, exit 0; (20) a `403` writes nothing and exits
      non-zero; (21) create mode with `--name` and no `--confirm` still fires no mutation (restate
      the existing dry-run safety property against the new mode selector). *(completed: all 21
      cases, 49 assertions, pass against the source store)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/sapience-project-bind.sh agent-system/extensions/sapience/scripts/tests/test-sapience-project-bind.sh`
covers this phase's whole touched set — the same two paths as Phase 1, for which
`suite_selection_select` returns exactly `test-sapience-project-bind.sh` and
`test-sapience-mcp-registration.sh`, with no unmapped-path sentinel.

**Scope Hypothesis**: this phase adds exactly four new test cases (18-21) and, after it,
`write_link_file()` is the **only** site in the script that writes `.sapience/project.json` — the
implementer confirms both by grepping the script for `project.json` write sites (expect exactly
one) and for `git ` in the bind path (expect none), and confirms case numbering as in Phase 1. The
marker-delimited worktree block and `sapience-api-lib.sh` remain unedited.

**Files to modify**:

- `agent-system/extensions/sapience/scripts/sapience-project-bind.sh` - `write_link_file()`
  extraction, bind dry-run, existing-link guard, link POST and the status-code branch, role note,
  commit-this-file line
- `agent-system/extensions/sapience/scripts/tests/test-sapience-project-bind.sh` - link-route stub
  branch with a call counter, cases 18-21

**Verification**:

- [ ] `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/sapience/scripts/tests/test-sapience-project-bind.sh`
      passes: cases 1-21 all green.
- [ ] Case 18's written file compares equal (`cmp`) to the expected three-key, two-space-indent,
      single-trailing-newline fixture.
- [ ] Case 18's link-route call counter reads exactly `1`.
- [ ] `bash -n` exits 0 on both files, and
      `bash .claude/scripts/lint/lint-shellcheck.sh agent-system/extensions/sapience/scripts/sapience-project-bind.sh agent-system/extensions/sapience/scripts/tests/test-sapience-project-bind.sh`
      exits 0.
- [ ] `bash .claude/scripts/verify-touched.sh <the two paths above>` green.

---

### Phase 3: Vendor Delegation With Single-Writer Normalization [COMPLETED]

**Goal**: when the installed client supports `link`, the bind delegates to it; the file is this
script's canonical bytes either way, and every non-success outcome is classified by this script's
own status-code path.

**Tasks**:

- [x] Add a `SAPIENCE_CLI_PATH` override defaulting to `$HOME/.sapience/sapience_cli.py`, so tests
      point at a fixture and never at the live, credential-bearing installation. *(completed)*
- [x] Static capability detection: `grep -q "sub == 'link'" "$SAPIENCE_CLI_PATH"`. Add a header
      note that the `sapience` binary on `$PATH` is a packaged wrapper with a fixed `case` table,
      no `link` branch and no fallback into the Python parser, so it can neither invoke nor detect
      this — delegation always goes through `python3 "$SAPIENCE_CLI_PATH" link ...`, and detection
      is never a live invocation. *(completed)*
- [x] Delegate only on `--project <value> --confirm`: invoke
      `python3 "$SAPIENCE_CLI_PATH" link "<value>" --name "$repo_slug" [--force]`. Comment that
      the vendor's `--name` is the **repository** short name while this script's own `--name` is
      the **project** display name, and that the two are never conflated. *(completed)*
- [x] Vendor exit 0 with a link file present → read `project`, `name`, `repo` back out of it and
      re-render through `write_link_file()`, so the on-disk bytes are this script's canonical
      rendering. Report success and the role note exactly as the HTTP path does. *(completed)*
- [x] Vendor exit non-zero, or exit 0 with no file → fall through to Phase 2's own HTTP path, which
      re-POSTs and classifies by status code. Add a header note on the accepted consequence: at a
      404 or 403 against a link-capable client, the vendor's POST fires and then this script's
      POST fires; both are non-mutating at those statuses, and the alternative — classifying on
      the vendor's English output — is not a contract. *(completed)*
- [x] Add test cases 22-24, all against a synthetic `sapience_cli.py` fixture under the scratch
      tree (never the real installation): (22) a link-capable fixture that writes a deliberately
      non-canonical file (four-space indent, reordered keys) is normalized so the result `cmp`s
      equal to the HTTP path's output from case 18 — this is requirement (4)'s byte-identity proof;
      (23) a fixture lacking `sub == 'link'` is never invoked (assert via a sentinel the fixture
      would have written) and the HTTP fallback runs to a successful write; (24) a link-capable
      fixture exiting 1 with no file falls through to the HTTP path, which then applies the 404
      policy. *(completed: cases 22-24 added, 24 cases / 61 assertions all green)*

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/sapience-project-bind.sh agent-system/extensions/sapience/scripts/tests/test-sapience-project-bind.sh`
covers this phase's whole touched set — the same two paths as Phases 1-2, for which
`suite_selection_select` returns exactly `test-sapience-project-bind.sh` and
`test-sapience-mcp-registration.sh`, with no unmapped-path sentinel.

**Scope Hypothesis**: this phase adds exactly three new test cases (22-24) and introduces the
extension's **first** subprocess call into `sapience_cli.py` — a grep across the source store's
`scripts/*.sh` for `sapience_cli.py` returns zero call sites today, which the implementer
re-confirms before adding, since a pre-existing call site would mean an established convention to
follow rather than a new pattern to establish. No test case invokes the real
`~/.sapience/sapience_cli.py`; `SAPIENCE_CLI_PATH` points at a scratch fixture in all three cases.
The marker-delimited worktree block stays unedited.

**Files to modify**:

- `agent-system/extensions/sapience/scripts/sapience-project-bind.sh` - `SAPIENCE_CLI_PATH`,
  static detection, delegated invocation, read-back normalization, fallthrough, header notes
- `agent-system/extensions/sapience/scripts/tests/test-sapience-project-bind.sh` - `sapience_cli.py`
  fixture builder, cases 22-24

**Verification**:

- [x] `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/sapience/scripts/tests/test-sapience-project-bind.sh`
      passes: cases 1-24 all green. *(completed: 61/61 assertions pass)*
- [x] Case 22 demonstrates byte-identity by `cmp` between the delegated-path file and the HTTP-path
      file, not by inspecting either one alone. *(completed)*
- [x] A grep of the script confirms no branch reads the vendor's stdout or stderr text to decide
      anything. *(completed: delegate_link()'s only vendor invocation redirects stdout/stderr to
      /dev/null; classification is by exit code and the written file's own content only)*
- [x] `bash -n` exits 0 on both files, and
      `bash .claude/scripts/lint/lint-shellcheck.sh agent-system/extensions/sapience/scripts/sapience-project-bind.sh agent-system/extensions/sapience/scripts/tests/test-sapience-project-bind.sh`
      exits 0. *(completed)*
- [x] `bash .claude/scripts/verify-touched.sh <the two paths above>` green. *(completed: deferred
      to the Batch Gate Deferral's scoped tier per this dispatch; verify-touched.sh resolved and
      ran the 3-suite narrowed battery green. Note: run-all.sh's own "deployed" mode executed the
      deployed, pre-Phase-3 copy of test-sapience-project-bind.sh -- the deployed .claude/
      sapience mirror is documented stale by this dispatch's deploy-freshness-context and no phase
      redeploys it, per the plan's own Risk table. The authoritative check for this phase's new
      cases 22-24 is the direct CORE_TEST_SUBJECT_MODE=source-store invocation above, which is
      green.)*

---

### Phase 4: `/sapience` Pick Surface — Stage 1 Into the One Approval Picker [COMPLETED]

**Goal**: in a repository with no link file, `/sapience` offers the bind as a candidate option in
its single existing approval picker instead of stopping, and never writes unattended.

**Tasks**:

- [x] Rewrite Stage 1's binding gate: a missing or invalid `$link_file` is no longer a stop. Run
      the read-only pick (`bash .claude/scripts/sapience-project-bind.sh` with no arguments; exit 1
      is the expected, non-error shape), capture the listing, and carry it forward as a candidate
      surface. Keep the prohibition in force in its correct, narrowed form: this skill never runs
      the script with `--confirm` outside Stage 10, and never performs the bind unattended.
      *(completed: zero-row and multi-row cases resolved via Stage 5's exactly-one-or-refuse
      discipline, reused rather than invented — see deviations)*
- [x] Stage 7: add a "Project binding" preview built the same way as the other four —
      `bash .claude/scripts/sapience-project-bind.sh --project "<id>"` with no `--confirm`, whose
      output is the literal link payload, printed in full above the picker. *(completed)*
- [x] Stage 8: add the binding row to the option table **inside the existing
      `askuserquestion-option-construction` marker pair** — no second block, no second
      `AskUserQuestion`. Included when no link file exists; never pre-checked, because the role
      note has to be read before binding to someone else's project is chosen. *(completed)*
- [x] Stage 9: add the binding option object, with the role note in its description alongside the
      pointer to the printed payload. *(completed)*
- [x] Stage 10: the confirmed bind re-invokes the identical Stage 7 vector with `--confirm`
      appended. *(completed)*
- [x] Stage 11: report the bind's three distinct outcomes by name — written and registered;
      written locally only because the server returned 404 and does not read it yet; refused with
      nothing written because the caller has not joined the project. *(completed)*
- [x] Update Stage 8's surface-ceiling wording from four options to five, and the matching
      sentence in Stage 9's preamble. Stage 12's empty-selection contract is unchanged and stays
      as-is. *(completed: also corrected two further stale "four" counts in Stage 11's own prose
      beside the new fifth bullet)*

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/verify-touched.sh agent-system/extensions/sapience/skills/skill-sapience/SKILL.md`
covers this phase's single touched path — `suite_selection_select` over it returns, with no
unmapped-path sentinel, exactly `test-approve-structural.sh`, `test-askuserquestion-rehome.sh`
(the one checking the single-marker-pair option-construction discipline this phase edits inside),
`test-conflict-predicate.sh`, `test-deploy-propagation.sh`, `test-double-loading-check.sh`,
`test-four-tier-conflict.sh`, `test-gate-cache-lib.sh`, `test-guard-git-push.sh`,
`test-handoff-dispatch-identity.sh`, `test-handoff-reader-parity.sh`,
`test-install-uninstall-extension.sh`, `test-lint-branch-gated-sections.sh`,
`test-lint-postflight-boundary.sh`, `test-lint-task-lookup-adoption.sh`, `test-lit-pipeline.sh`,
`test-orchestrate-build-dispatch.sh`, `test-orchestrate-conclusion-roadmap.sh`,
`test-orchestrate-context-growth.sh`, `test-orchestrate-cycle-plan.sh`,
`test-orchestrate-cycle-postflight.sh`, `test-orchestrate-recover-message-findings.sh`,
`test-resume-scan-nonconformance.sh`, `test-roadmap-command-registration.sh`,
`test-routing-resolution.sh`, `test-session-runtime-files.sh`, `test-skill-base-lifecycle.sh`,
`test-stall-reprompt-wiring.sh`, and `test-verify-deploy-context-budget.sh`.

**Scope Hypothesis**: Stage 1 is the **only** place in `SKILL.md` that hard-stops on a missing
binding, and Stage 8 is the **only** block that constructs picker options; the "at most four
options" ceiling appears in Stage 8 with a matching count in Stage 9. The implementer confirms all
three by grepping `SKILL.md` for `sapience-project-bind.sh`, for the
`askuserquestion-option-construction` marker pair (expect exactly one pair), and for `four` before
editing — a second option-construction site would change this phase's shape, not just its text.
`commands/sapience.md` is deliberately excluded (see Non-Goals) and no task here requires editing
it.

**Files to modify**:

- `agent-system/extensions/sapience/skills/skill-sapience/SKILL.md` - Stage 1 binding gate,
  Stage 7 preview, Stage 8 option row and ceiling, Stage 9 option object, Stage 10 confirmed
  invocation, Stage 11 outcome reporting

**Verification**:

- [x] `bash .claude/scripts/verify-touched.sh agent-system/extensions/sapience/skills/skill-sapience/SKILL.md`
      green. *(completed: 27 passed, 1 failed (1 expected, 0 NEW) -- the one failure is
      `test-verify-deploy-context-budget.sh`, named in this phase's own expected-suite roster
      above and caused by the pre-existing, already-documented deployed-`.claude/`-mirror drift
      for this extension, not by this phase's edit)*
- [x] Exactly one `askuserquestion-option-construction` marker pair remains, and exactly one
      `AskUserQuestion` call is described in the file. *(completed: confirmed via grep, and that
      the literal `AskUserQuestion` mention count (5) is unchanged from before this phase's edit)*
- [x] Every `sapience-project-bind.sh` invocation in the file is either argument-free (the pick) or
      a `--project <id>` form; the only `--confirm` occurrence is inside Stage 10. *(completed: the
      only skill-EXECUTED `--confirm` invocation is Stage 10's; the two other `--confirm`
      occurrences are inside verbatim manual commands the skill tells the user to run themselves
      (Stage 1's zero-row and multi-row UNAVAILABLE reasons), never executed by the skill, matching
      the pre-existing pattern this same Stage 1 already used for its create-mode suggestion)*
- [x] Stage 8's option table and Stage 9's option list both carry five surfaces, and no stated
      count still reads "four". *(completed)*
- [x] No task-number reference and no record-versioning language was introduced (both repo rules
      apply to this path). *(completed: checked via `git diff` grep against both rules' forbidden
      phrase lists)*

---

### Phase 5: Domain Record — Link Mechanism and the Fifth Surface [COMPLETED]

**Goal**: the extension's durable design record documents the repo-link mechanism it currently
omits entirely, and the picker record reflects five surfaces and a route that is now actively
called.

**Tasks**:

- [x] **Re-read both target files immediately before editing** (concurrent sibling 683 declares
      `per-repo-scoping.md` in its own `file_scope`). If a foreign uncommitted modification or a
      foreign commit is present, stop and report rather than proceeding. *(completed: `git status
      --porcelain` and `git log` over both files showed no foreign uncommitted modification; both
      files HAD been touched by task 678, but that task completed and committed fully before task
      681 phase 1 even started, so there is no live concurrency — not a foreign-in-progress write.
      Full detail in Deviations below.)*
- [x] `per-repo-scoping.md`: **append** a new `## The Repo-Link Mechanism` section — editing no
      existing section, which is what keeps this phase's hunks disjoint from the sibling's.
      Content: the three-key `.sapience/project.json` format and its server-side serializer; the
      real `GET /v1/people/projects` response shape and the `accepted or owner` row filter; the
      link route's gate order and the two named non-success outcomes (404 writes locally only, 403
      writes nothing); the trap that the link response's `project` field is a descriptor dict and
      never a cid; the pick-versus-create distinction; the static vendor-capability detection rule
      and why the `$PATH` wrapper is a dead end for it. Add a short named note that two other
      scripts in this extension consume the same endpoint with a shape that does not match it,
      recorded as a follow-up rather than fixed here. *(completed: appended, no existing section
      edited — confirmed by `git diff` showing additions only)*
- [x] `command-draft-and-picker.md`: extend "The Four Candidate Write Surfaces" to five, retitled
      accordingly, with the binding row mapping to `sapience-project-bind.sh --project <id>`; add
      its pre-check default (present when no link file exists, never pre-checked) to "Pre-Check
      Defaults"; and update "The Dark Migration Path" so the route reads as actively called by the
      bind path with a 404 as a named handled outcome, while the `REPO_LINK_FOR` gate itself is
      unchanged and still off for this credential. *(completed)*
- [x] Record D1's resolution (delegate the bind, normalize to one writer, classify by status code,
      never parse vendor prose) in the `per-repo-scoping.md` section, so the reconciliation is
      discoverable from the domain record and not only from this plan. *(completed: "### D1:
      Reconciling the 404-Write Requirement With Vendor Delegation" subsection)*
- [x] Both files: no task-number references and no record-versioning language ("no longer",
      "previously", "supersedes", a version label); state the current design only. *(completed:
      verified via `check-task-references.sh` on both files — 0 occurrences each — and a manual
      grep for the forbidden-phrase list against the diff, matching only false-positive `/v1/`
      substrings)*

**Timing**: 1 hour

**Depends on**: 3, 4

**Verification Tier**: full

**Scope Hypothesis**: `per-repo-scoping.md` carries **no** section on the repo-link mechanism today
(its headings cover knowledge-scoping, the two scripts, the tagged-write call site, the
MCP-registration triad, worktree resolution, and hazards — nothing on `.sapience/project.json` or
the link route), and `command-draft-and-picker.md`'s surface table carries exactly **four** rows.
The implementer confirms both by `grep -n '^#'` over the first file and by counting the table's
rows in the second before editing — if a link-route section already exists, this phase amends it in
place instead of appending a second one. The phase touches exactly these two files and, in
`per-repo-scoping.md`, **adds only** (no existing section of that file is edited, which is what
keeps its hunks disjoint from concurrent sibling 683's declared scope on the same path); no task in
this phase requires editing an existing section there.

**Files to modify**:

- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` - new
  appended repo-link mechanism section
- `agent-system/extensions/sapience/context/project/sapience/domain/command-draft-and-picker.md` -
  five-surface table, pre-check default, Dark Migration Path update

**Verification**:

- [x] In-dispatch obligation (scoped): `suite_selection_select` over this phase's touched set
      returns `__FULL_SWEEP__` alone — both paths are source-store markdown with no mapped suite —
      so the covering check is the source-store-repository gate subset
      `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
      (that root holds both a deployed `.claude/` tree and `agent-system/extensions`, which the
      gate-0 contract requires), together with a diff read-through of both files. *(completed,
      narrowed per this dispatch's own Batch Gate Deferral directive to `--only-gate 3,4
      --skip-unchanged` rather than `--skip-slow`: first run surfaced two genuine, self-caused
      `index-entries.json` `line_count` mismatches, fixed via `bash
      .claude/scripts/generate-context-line-counts.sh --write` against the deployed copy (writes
      only the source-store `index-entries.json`, never the deployed tree); re-run is green for
      gates 3/4 except the two pre-existing, already-documented `sapience-project-bind.sh` /
      `test-sapience-project-bind.sh` deployed-mirror-drift failures from Phases 1-3, explicitly
      deferred below.)*
- [x] `bash .claude/scripts/check-task-references.sh` reports no new occurrence in either file.
      *(completed: 0 occurrences in each)*
- [x] `command-draft-and-picker.md` carries five surfaces in its table and no remaining "four"
      count; `per-repo-scoping.md`'s pre-existing sections are untouched (`git diff` shows
      additions only). *(completed)*
- [x] **The complete gate set is deferred to the orchestration close** (Move 4 / the
      once-per-invocation batch gate stage), not run independently here. The stale-deployed-mirror
      redeploy (`bash .claude/scripts/deploy-headless.sh`, bounded-wait idiom) is deferred to that
      same close, deliberately: running it inside a phase would be a whole-tree claim serializing
      against three concurrent siblings, and no phase in this plan hand-patches `.claude/**` as a
      substitute. *(confirmed: not run in this phase)*

#### Deviations

- **Beyond the literal task list**: Ruling 5 in `command-draft-and-picker.md` asserted "this
  repo's own binding is always the owner side -- `sapience-project-bind.sh` always creates a
  fresh project rather than joining one," a claim Phases 1-3 of this same task invalidated by
  adding the `--project` bind-to-existing mode. Since this file is within Phase 5's own declared
  edit territory and the stale sentence sits immediately beside this phase's own table/pre-check
  edits, the parenthetical was corrected in place rather than left visibly false in a file this
  phase was already touching. The identical sentence in `linked-repo-write-policy.md` (committed
  by task 678, out of this task's declared territory) was left unedited and recorded as a
  follow-up via `issue-record.sh` instead.
- No other deviation from the plan's task list.

---

## Testing & Validation

- [ ] `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/sapience/scripts/tests/test-sapience-project-bind.sh`
      green with all 24 cases, run against the edited source store rather than the stale deployed
      copy.
- [ ] Pick mode lists both a `shared` and a `received` accepted row with correct role labels, and
      excludes a received-but-unaccepted row.
- [ ] Bind-existing writes the three-key file and calls the link route exactly once.
- [ ] A 404 writes the file and the reply names the degraded state; a 403 writes nothing.
- [ ] Create mode still fires no mutation without `--confirm`.
- [ ] The delegated path's file and the HTTP path's file `cmp` equal.
- [ ] No test case touches the real `~/.sapience/sapience_cli.py` or the real network.
- [ ] `test-sapience-mcp-registration.sh`'s lockstep case still passes (the shared worktree block
      is unchanged).

## Artifacts & Outputs

- `agent-system/extensions/sapience/scripts/sapience-project-bind.sh` — three modes (pick, bind,
  create), link registration, 404/403 policy, one canonical writer, vendor delegation
- `agent-system/extensions/sapience/scripts/tests/test-sapience-project-bind.sh` — cases 15-24
- `agent-system/extensions/sapience/skills/skill-sapience/SKILL.md` — the bind as a fifth surface
  in the one approval picker
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` — the
  repo-link mechanism record
- `agent-system/extensions/sapience/context/project/sapience/domain/command-draft-and-picker.md` —
  five surfaces, actively-called route
- A follow-up worth filing after this lands: the `GET /v1/people/projects` shape mismatch in
  `sapience-publish.sh`'s `ko` subcommand and `sapience-vault-read.sh`'s `notes_cid` resolution,
  both out of this task's territory.

## Rollback/Contingency

Every phase is a commit of its own, each green before it fires, so a revert of the last commit
restores the previous working state without touching the others. The script's create mode is
untouched behavior-first (Phase 2 only moves its write behind a helper), so a revert of Phases 1-3
leaves the existing create path exactly as it is today. No phase writes outside the source store,
no phase runs the deploy script, and no phase runs git beyond its own scoped commit, so there is
no deployed-tree or remote state to unwind. If Phase 3's delegation proves unworkable against the
real client, the HTTP path from Phase 2 is already complete and self-sufficient: Phase 3 can be
reverted alone, leaving a working bind mode that simply never delegates, and requirement (4)
recorded as unmet with its reason rather than silently dropped.
