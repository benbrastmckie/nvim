# Implementation Plan: Task #647

- **Task**: 647 - Bind a repo to a Sapience project and read the vault's shared state
- **Status**: [IMPLEMENTING]
- **Effort**: 8 hours
- **Dependencies**: None
- **Research Inputs**: specs/647_sapience_project_binding_and_vault_read/reports/01_project-binding-vault-read-foundation.md
- **Artifacts**: plans/01_project-binding-vault-read-foundation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build the shared host/token/API-resolution library the `/sapience` command group depends on, then
the two scripts that sit on top of it: an interactive, confirm-or-refuse project binder that
creates a fresh Sapience project and persists the binding to `.sapience/project.json`, and a
read-only aggregator that bundles local repo state and seven vault GETs into one stable JSON
envelope for the as-yet-unwritten draft-assembly consumer. Every deliverable lands in the source
store at `agent-system/extensions/sapience/`, never under `.claude/**`. Two existing files outside
the dispatch's declared FILE SCOPE must also change — the extension manifest (so the new scripts
deploy at all) and the lockstep test's hardcoded file list (so the duplicated worktree-resolution
block in the two new scripts is actually compared) — and both are planned explicitly below rather
than discovered mid-implementation.

### Research Integration

Every technical claim in the dispatch was independently re-verified by the research pass against
primary sources on this machine, and re-confirmed again during this planning pass (see
"Premise Re-Validation" below). The plan adopts the research report's eight recommendations
directly, with one addition the research surfaced but did not fully trace: `manifest.json`'s
`provides.scripts` is an explicit, hand-maintained array, so a new script that is not declared
there neither deploys nor passes `check-extension-docs.sh`'s Rule Q. `sync-manifest-scripts.sh
--write` is the sanctioned regenerator for that array, and it enumerates via `git ls-files`, so a
new file must be **staged** before the regenerator can see it. That ordering constraint is baked
into each phase's task list.

The research report's Decision that the marker-delimited worktree-resolution block stays a
duplicated-and-compared pattern (copied into each consumer, never folded into the new shared lib)
is adopted unchanged; folding it into `sapience-api-lib.sh` would collapse the lockstep test's
N-copies-must-agree guarantee into a single copy nothing can compare against.

### Premise Re-Validation

Carried-figure check against live state, run during this planning pass. Every flagged line in the
dispatch is **confirmed unchanged**:

| Dispatch claim | Live check | Result |
|---|---|---|
| `source_dir` is `.../agent-system/extensions/sapience` | `jq -r '.extensions.sapience.source_dir' .claude-extensions.json` | Confirmed; directory present on disk |
| Credential precedence mirrors `~/.sapience/mcp.py` | `grep -n 'DEFAULT_HOST\|^HOST\|^TOKEN' ~/.sapience/mcp.py` | Confirmed verbatim at lines 42-44 |
| `REPO_LINK_FOR` dark path: zero `project_cid` in installed client | `grep -c project_cid ~/.sapience/mcp.py` | Confirmed: `0` |
| `link_text` serializer: `{project,name,repo}`, indent 2, trailing newline | `repo_link.py:89-93` read directly | Confirmed verbatim |
| `sapience-remember.sh` loud-failure discipline (`set_aside` -> `gated` -> `written` -> `ok`, exit 2) | source read at lines ~234-268 | Confirmed, including the distinct exit-1 vs exit-2 split |
| `LOCKSTEP_FILES` holds exactly five hardcoded paths | `test-sapience-mcp-registration.sh:1218-1224` | Confirmed: five entries |
| Interactive-only posture required for the outward-facing share mutation | dispatch + research agree; no live probe made | Confirmed as a design constraint, carried into Phase 2 |

Two additions this pass established that the dispatch did not state:

- `agent-system/extensions/sapience/manifest.json`'s `provides.scripts` is an explicit 11-entry
  array; `sync-manifest-scripts.sh --check` currently reports `sapience: 11 on disk, 11 declared,
  0 missing, 0 absent` and `CHECK PASSED` for all twelve extensions.
- `suite_selection_select` returns `__FULL_SWEEP__` for every one of this task's five new paths
  (they do not exist yet, so no suite maps them), and returns `test-sapience-mcp-registration.sh`
  for that existing test file. Once the Phase 4 test files exist on disk, the resolver's
  self-identity and basename-pairing strata will map the new scripts to the new suites; that
  transition is a Scope Hypothesis to confirm, not an assumption to rely on.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; `specs/ROADMAP.md` was not consulted and is not
modified by this plan.

## Goals & Non-Goals

**Goals**:
- One shared `scripts/lib/sapience-api-lib.sh` owning host/token resolution and both
  authenticated HTTP helpers, so no future sapience script re-derives the precedence a fifth time.
- `sapience-project-bind.sh`: a confirm-or-refuse binder that cannot fire its outward-facing
  mutation from an unattended run, and whose `.sapience/project.json` bytes match
  `repo_link.py`'s own `link_text` serializer exactly.
- `sapience-vault-read.sh`: a read-only aggregator with one pinned JSON envelope shape, so the
  future draft-assembly consumer has a stable interface.
- Both new scripts covered by their own test suites, declared in the manifest, and watched by the
  existing lockstep guard.

**Non-Goals**:
- Writing any knowledge object, note, or document to the vault. This task performs exactly one
  mutating call (the project-share creation in Phase 2), and only under explicit human confirmation.
- Building `/sapience` itself, or the draft-assembly consumer. Those are separate tasks.
- Migrating to the `project_cid` / `REPO_LINK_FOR` path. That path is off for this token; the
  file format chosen here is forward-compatible with it, and nothing else is built against it.
- Redeploying `.claude/**`. The new scripts are useless until deployed, but `check-extension-docs.sh`'s
  Rule F explicitly treats an absent deployed copy as "not deployed, skipping drift check", never
  a failure — so no phase here regenerates the deploy tree, and this plan makes no whole-tree claim.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The outward-facing `/v1/people/projects/share` POST fires from an unattended `/orchestrate` dispatch, notifying the collaborator with no human present | H | M | Phase 2 requires BOTH an explicit `--name "<display>"` and a separate non-default `--confirm` flag, neither with a default that an empty invocation satisfies; `--dry-run` is the default posture and prints the literal payload |
| The token leaks into stdout, a log, or `set -x` output | H | M | Phase 1 reads the token into one local variable, never `echo`s it, suppresses `set -x` around the credential read, and redacts it out of both the printed JSON body and the printed URL under `--dry-run` |
| The two new copies of the worktree-resolution block silently drift, uncaught, because `LOCKSTEP_FILES` was never extended | M | H | Phase 5 appends both new paths to the array and re-runs the suite to confirm 7-way agreement |
| New scripts never deploy and Rule Q fails, because `provides.scripts` was not updated | M | H | Each of Phases 1-4 stages its new file then runs `sync-manifest-scripts.sh --write`; Phase 5 confirms with `--check` |
| `sync-manifest-scripts.sh --write` silently rewrites another extension's manifest | M | L | Baseline captured at authoring time (all 12 extensions `0 missing, 0 absent`); every phase confirms with `git diff --stat` that only `sapience/manifest.json` changed |
| `.sapience/project.json`'s bytes diverge from `repo_link.py`'s `link_text`, complicating a future diff-based verification once `REPO_LINK_FOR` flips on | L | M | Phase 2 reproduces key order, 2-space indent and trailing newline exactly, and the Phase 4 test asserts the bytes against a fixture generated from `link_text`'s documented shape |
| A careless port of `sapience-remember.sh`'s field names checks `written`/`gated`/`set_aside` against a `/v1/people/projects/share` response that has none of them | M | M | Phase 2's checks are written against the confirmed `{ok, project, to}` shape; only the *discipline* transfers, not the field names |
| `test-sapience-mcp-registration.sh` carries an uncommitted working-tree modification from a prior dispatch; editing it blind could clobber or conflict | M | M | Phase 5 re-reads the file immediately before editing and stages only its own hunks, per the cross-task territory contract |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Shared API library [COMPLETED]

**Goal**: `scripts/lib/sapience-api-lib.sh` exists and owns host/token resolution plus one
authenticated POST and one authenticated GET helper, with token redaction and a bounded
cold-start retry, so Phases 2 and 3 never re-derive any of it.

**Tasks**:
- [x] Create `agent-system/extensions/sapience/scripts/lib/sapience-api-lib.sh`. This is the
      extension's first `scripts/lib/` directory; add a header paragraph recording that it
      deliberately resolves (not contradicts) `sapience-remember.sh`'s own header note that the
      duplication there was forced by that task's narrower `file_scope`. *(completed)*
- [x] Implement `sapience_api_init`: resolve host as `SAPIENCE_HOST` env -> `~/.sapience/config.json`'s
      `.host` -> the `https://app.spnc.ai` literal, each `rstrip('/')`-equivalent; resolve token as
      `SAPIENCE_TOKEN` env -> that same file's `.token`. Read the token into ONE local variable.
      Suppress `set -x` around the credential read (save and restore the shell's `x` option) so
      the token can never reach a trace. Never `echo`, `printf`, or log it. *(completed)*
- [x] Implement `sapience_post <path> <json-body>`: authenticated POST, returning the raw response
      body on stdout and a non-zero status on transport failure. Under `SAPIENCE_DRY_RUN=1` print
      the method, URL and body with the token replaced by `***REDACTED***` (mirroring
      `sapience-remember.sh`'s `jq '.token = "***REDACTED***"'` pattern) and make no network call.
      *(completed)*
- [x] Implement `sapience_get <path> [query-string]`: authenticated GET. Where the token is carried
      as a URL query parameter, URL-encode it via the `--arg v "$tok" '$v|@uri'` pattern already
      used in `sapience-retrieve.sh`, and under dry-run redact the token **out of the printed URL**,
      not only out of a JSON body. *(completed)*
- [x] Fold `sapience-retrieve.sh`'s bounded one-retry-on-503-with-`starting:true` cold-start
      behavior into `sapience_get` once, so Phase 3's seven-plus call sites inherit it rather than
      each re-adding it. *(completed)*
- [x] Add no reference, in any comment or docstring, to `sapience_remember`, `sapience_wrapup`,
      `sapience_handoff`, or `sapience_adddoc` as a write path (rules/sapience-write-path.md).
      *(completed: grep confirms none)*
- [x] `git add` the new file, then run `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --write`
      and confirm via `git diff --stat` that only `agent-system/extensions/sapience/manifest.json`
      changed. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: `suite_selection_select` returns `__FULL_SWEEP__` for
`agent-system/extensions/sapience/scripts/lib/sapience-api-lib.sh` (confirmed at authoring time,
2026-11-19 — no suite maps a path that does not yet exist). Re-run
`suite_selection_select` over the path after creating it and before writing the phase's
verification note; if it now resolves to one or more real suites, run those instead of relying on
the unmapped verdict.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/lib/sapience-api-lib.sh`
is the covering check — the path is a single new file with no caller yet, and the selector returns
`__FULL_SWEEP__` for it, so no wider suite exists to reach.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/lib/sapience-api-lib.sh` - new; shared host/token
  resolution and the two authenticated HTTP helpers
- `agent-system/extensions/sapience/manifest.json` - its `provides.scripts` array derives from
  the scripts tree and must gain an entry for the new lib; regenerated in this phase by running
  sync-manifest-scripts.sh in write mode

**Verification**:
- `bash -n` and `shellcheck` clean on the new lib.
- A dry-run smoke harness sources the lib, calls `sapience_post` and `sapience_get` with
  `SAPIENCE_DRY_RUN=1`, and `grep`s the combined output for the live token value: zero matches.
- With `SAPIENCE_HOST` unset and `~/.sapience/config.json` present, the resolved host matches
  that file's `.host`; with `SAPIENCE_HOST` set, the env value wins.
- `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/lib/sapience-api-lib.sh`
  reports its verdict for the touched path.
- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` passes.

---

### Phase 2: Project binder [COMPLETED]

**Goal**: `scripts/sapience-project-bind.sh` creates a fresh, named Sapience project only under
explicit human confirmation, and persists the binding to `.sapience/project.json` in bytes
identical to `repo_link.py`'s own serializer.

**Tasks**:
- [x] Create `agent-system/extensions/sapience/scripts/sapience-project-bind.sh`, sourcing
      `scripts/lib/sapience-api-lib.sh` and `deploy-root-guard.sh` as the existing scripts do.
      *(completed)*
- [x] Copy the marker-delimited `# === BEGIN sapience-worktree-checkout-resolution ... # === END
      sapience-worktree-checkout-resolution ===` block **byte-for-byte** from
      `sapience-remember.sh` into this script. Do NOT move it into the lib — the lockstep test
      compares N independent copies and a single lib copy would have nothing to compare against.
      *(completed: diff confirms byte-identical)*
- [x] Argument contract: require BOTH `--name "<display name>"` and a separate `--confirm` flag.
      Refuse with a clear message and a non-zero exit if either is missing. Default posture is
      `--dry-run`: print the literal payload (`to`, `project.kind`, `project.key`, `follow`) and
      exit 0 without a network call. *(completed: dry-run uses a "<person id>" placeholder,
      matching the dispatch's own creation-call template, so even the GET /v1/people discovery
      call is skipped under dry-run — a deviation from a literal reading that would have resolved
      the real collaborator id even without --confirm; see Plan Deviations)*
- [x] Discover the collaborator person id and own `me_id` at runtime from the vault — never
      hardcode the values the dispatch cites as live reference. Derive `project.key` from the
      display name as a slug, validated against `^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$`. *(completed:
      only on the --confirm path, and only when --to is not given explicitly)*
- [x] On the confirmed path, POST `/v1/people/projects/share` with
      `{to:["<person id>"], project:{kind:"project", key:"<key>"}, follow:true}` via
      `sapience_post`. Record, in a header comment, why creating the project matters mechanically:
      `project_split_confirmed` computes `cross = doors & (sent | added | first_doors-if-owner-and-not-sent)`,
      so only the creator/owner's `follow:true` notes flow without a per-note confirm.
      *(completed)*
- [x] Apply loud-failure discipline to the response, written against the confirmed
      `{ok, project, to}` shape — an empty `to` array, a non-2xx status, a non-JSON body, or a
      response lacking `ok: true` is a loud non-zero-exit failure, never a success-shaped guess.
      Do NOT copy `sapience-remember.sh`'s `written`/`gated`/`set_aside` field names: this
      response carries none of them. *(completed: all four shapes verified by fixture to exit
      non-zero with no file write; sapience_post extended to expose the HTTP status via
      sapience_api_post_http_status for the non-2xx check)*
- [x] Resolve the repo toplevel via the copied block, then write `<toplevel>/.sapience/project.json`
      with EXACTLY three string keys in the order `project`, `name`, `repo`, two-space indent, one
      trailing newline — reproducing `repo_link.py`'s `link_text` byte-for-byte. Add no fourth key:
      `parse_link` returns `None` for a dict carrying ANY key matching
      `(token|key|secret|password)`, case-insensitive. Validate `repo` against
      `^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$` and reject a path-shaped value before writing.
      *(completed: byte-identical fixture confirmed via cmp; the fourth-key case is vacuously
      guaranteed by construction since the writer always emits exactly {project, name, repo}
      via jq object construction, verified with an adversarial --name containing literal
      "token": text that lands as an escaped string value, never a new key)*
- [x] `git add` the new file, run `sync-manifest-scripts.sh --write`, confirm via `git diff --stat`
      that only the sapience manifest changed. *(completed)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: `suite_selection_select` returns `__FULL_SWEEP__` for
`agent-system/extensions/sapience/scripts/sapience-project-bind.sh` (confirmed at authoring time,
2026-11-19). Re-run the selector after creating the file; once Phase 4's
`test-sapience-project-bind.sh` exists the pairing stratum will map it, but at THIS phase's close
it is still expected to be unmapped. If the selector already resolves real suites, run them.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/sapience-project-bind.sh`
covers it — one new self-contained script whose only dependency is the Phase 1 lib, with no
existing caller and no mapped suite.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/sapience-project-bind.sh` - new; interactive
  confirm-or-refuse project creation and `.sapience/project.json` writer
- `agent-system/extensions/sapience/manifest.json` - `provides.scripts` derives from the scripts
  tree; regenerated in this phase via `sync-manifest-scripts.sh --write`

**Verification**:
- `bash -n` and `shellcheck` clean.
- Invoking with no arguments, with `--name` alone, and with `--confirm` alone each exits non-zero
  and makes no network call.
- The default `--dry-run` path prints the literal payload with the token redacted and exits 0.
- A fixture run writes `.sapience/project.json` into a temp repo and `cmp`s the bytes against the
  expected `link_text` output (key order, 2-space indent, trailing newline).
- `diff` of this script's extracted marker block against `sapience-remember.sh`'s is empty.
- `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/sapience-project-bind.sh`
  reports its verdict.

---

### Phase 3: Vault reader [COMPLETED]

**Goal**: `scripts/sapience-vault-read.sh` emits one pinned, read-only JSON envelope on stdout
bundling local repo state and the seven vault GETs, with per-source failure isolation.

**Tasks**:
- [x] Create `agent-system/extensions/sapience/scripts/sapience-vault-read.sh`, sourcing the
      Phase 1 lib and `deploy-root-guard.sh`, and carrying its own byte-identical copy of the
      marker-delimited worktree-resolution block (same rule as Phase 2 — copy, never source).
      *(completed: diff confirms byte-identical)*
- [x] Pin the envelope contract, documented in the script header as the hand-off interface for the
      future draft-assembly consumer:
      `{"schema":"sapience-vault-read/1","generated_at":"<ISO8601>","repo":{"toplevel","name","binding"},`
      `"local":{"git":{"since","log","diff_stat"},"state","events","errors","sessions"},`
      `"vault":{"projects","docs","doc_bodies","doc_comments","project_notes","suggestions","notifications"},`
      `"errors":[{"source","message"}]}`.
      Every `vault.*` key is `null` when its source failed, with the reason recorded in `errors[]`.
      *(completed: a full-success fixture run validated every key via jq; an all-failing fixture
      confirmed every vault.* key null with a populated top-level errors[])*
- [x] Local side: `git log` / `git diff --stat` since a cursor; `specs/state.json` completions;
      `specs/events.jsonl`; `specs/central-errors.jsonl`; recent Claude Code session history. All
      paths resolved relative to the repo toplevel from the copied block, never the invocation cwd.
      *(completed; sessions is a best-effort listing of the most recent .jsonl transcript files
      under ~/.claude/projects/<slugified-toplevel>/, never a hard failure if absent)*
- [x] Cursor handling: `--since <git-ref>` wins; otherwise read `.sapience/last-read.json`'s
      recorded commit; otherwise fall back to a bounded default. `--update-cursor` is the only way
      the cursor file is written, so an ordinary read never mutates the repo. *(completed and
      fixture-verified: an ordinary run never creates the cursor file; --update-cursor creates it
      matching HEAD; a later ordinary run leaves it byte-unchanged)*
- [x] Vault side, every call through the Phase 1 `sapience_get` helper (never an ad hoc `curl`):
      `/v1/people/projects`, `/v1/docs`, `/v1/docs/<slug>` (with `?versions=1`),
      `/v1/docs/<slug>/comments`, `/v1/people/projects/<cid>/notes`,
      `/v1/people/projects/suggestions`, `/v1/notifications`. *(completed: doc_bodies/doc_comments
      are per-doc follow-ons bounded to MAX_DOC_FETCH=10 docs flagged unread in the /v1/docs
      response, rather than fetching every doc's body unconditionally on every invocation —
      see Plan Deviations)*
- [x] Failure posture: a single failing source records into `errors[]` and leaves its key `null`
      rather than aborting — this is read-only draft input, not a write. Exit non-zero only when
      EVERY vault source failed (which indicates a broken host/token, not a partial outage).
      *(completed: the five independently-resolvable top-level sources (projects, docs,
      project_notes, suggestions, notifications) are what the all-failed exit-2 test counts;
      doc_bodies/doc_comments are per-doc follow-ons of a successful docs fetch and do not
      themselves count toward that test — see Plan Deviations)*
- [x] Name no MCP write tool anywhere in the script's comments or help text. *(completed: the
      four tool names appear only inside this script's own negation sentence stating they are
      NOT the write path, mirroring the identical pattern already present in Phase 1's and
      Phase 2's deliverables and in sapience-remember.sh's own header)*
- [x] `git add` the new file, run `sync-manifest-scripts.sh --write`, confirm via `git diff --stat`
      that only the sapience manifest changed. *(completed)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: `suite_selection_select` returns `__FULL_SWEEP__` for
`agent-system/extensions/sapience/scripts/sapience-vault-read.sh` (confirmed at authoring time,
2026-11-19). Re-run the selector after creating the file and run whatever
real suites it resolves, if any, instead of relying on the unmapped verdict.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/sapience-vault-read.sh`
covers it — one new read-only script with no existing caller and no mapped suite; it cannot change
any other module's behavior.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/sapience-vault-read.sh` - new; read-only local+vault
  aggregator emitting the pinned JSON envelope
- `agent-system/extensions/sapience/manifest.json` - `provides.scripts` derives from the scripts
  tree; regenerated in this phase via `sync-manifest-scripts.sh --write`

**Verification**:
- `bash -n` and `shellcheck` clean.
- A run against a temp repo with every vault source stubbed as failing produces a well-formed
  envelope, `null` for each `vault.*` key, a populated `errors[]`, and a non-zero exit.
- A run with vault sources stubbed as succeeding produces an envelope that `jq -e` validates
  against every key named in the pinned contract above.
- An ordinary run without `--update-cursor` leaves `.sapience/last-read.json` byte-unchanged
  (or absent).
- `diff` of this script's extracted marker block against `sapience-remember.sh`'s is empty.
- `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/sapience-vault-read.sh`
  reports its verdict.

---

### Phase 4: Test suites for both scripts [COMPLETED]

**Goal**: `scripts/tests/test-sapience-project-bind.sh` and
`scripts/tests/test-sapience-vault-read.sh` exist, follow the extension's existing suite
conventions, and pass.

**Tasks**:
- [x] Create `test-sapience-project-bind.sh`, modeled structurally on the extension's existing
      suites (`pass()`/`fail()` counters, `mktemp -d` workdir with a `trap EXIT` cleanup,
      `common_test_resolve_subject` source-store-first resolution, exit 0/1/2 convention).
      *(completed: 14 cases, 27 assertions, all passing)*
- [x] Cases: refusal without `--name`; refusal without `--confirm`; `--dry-run` prints the literal
      payload and makes no call; the printed payload contains no live token substring; the written
      `.sapience/project.json` is byte-identical to the expected `link_text` output; a fourth key
      or a path-shaped `repo` is refused before any write; each of the four loud-failure response
      shapes (non-2xx, non-JSON, empty `to`, missing `ok:true`) exits non-zero. *(completed; see
      the test file's own header comment for the "refusal without --confirm" interpretation note
      — the plan's own Phase 2/4 text is ambiguous between a non-zero refusal and the default
      dry-run posture, resolved in favor of the dry-run shape already built and verified in
      Phase 2, with the safety property (no mutation without --confirm) asserted directly)*
- [x] Create `test-sapience-vault-read.sh`. Cases: envelope validates against every key in the
      pinned contract; a single failing source yields `null` + an `errors[]` entry and exit 0;
      all-sources-failing exits non-zero; no vault source is contacted via a raw `curl` call site
      (assert by grepping the script for `curl` outside the lib); an ordinary run does not write
      the cursor file. *(completed: 9 cases, 19 assertions, all passing)*
- [x] Stub the network at the `sapience_post`/`sapience_get` boundary (shadow the lib's functions
      in the test's own shell) rather than issuing real vault calls — no test in this task may
      contact `app.spnc.ai`, and none may perform a write. *(completed with a deviation: stubs
      install at the `curl` boundary via a PATH-shadowed `curl` executable, not by overriding the
      `sapience_post`/`sapience_get` bash functions directly — the SAME technique
      `test-sapience-capture.sh` already uses for this exact scenario, and the only one that
      works across the `bash <script>` subprocess boundary every script in this family uses (a
      function defined in the test's own shell is never visible inside a separately-exec'd
      subprocess); no network call reaches `app.spnc.ai` either way. See Plan Deviations. One
      genuine accidental live call DID occur during drafting — before this fixture discipline was
      fully applied to every case — recorded as a costly issue-log entry and fixed; see Plan
      Deviations.)*
- [x] `git add` both new files, run `sync-manifest-scripts.sh --write`, confirm via
      `git diff --stat` that only the sapience manifest changed. *(completed)*
- [x] Re-run `suite_selection_select` over the three Phase 1-3 script paths and record what it now
      resolves to, closing out those phases' Scope Hypotheses. *(completed: `run-all.sh --only
      test-sapience-project-bind.sh,test-sapience-vault-read.sh` discovers and passes exactly the
      two new suites by basename, confirming the pairing stratum now maps them; see Plan
      Deviations for the full resolution detail)*

**Timing**: 1.5 hours

**Depends on**: 2, 3

**Verification Tier**: local

**Scope Hypothesis**: once these two files exist under `scripts/tests/`, `run-all.sh`'s glob
discovery picks them up automatically (no manifest entry is needed for discovery, only for
deploy), and `suite_selection_select` should map each Phase 1-3 script to its paired new suite via
the resolver's self-identity and `test-<basename>` pairing strata. Confirm by running the selector
over all five paths after creation; if a path still returns `__FULL_SWEEP__`, say so plainly in
the phase note rather than asserting coverage that does not exist.

**Tier Justification**: `suite_selection_select` returns the `__FULL_SWEEP__` sentinel for this
phase's touched paths at authoring time — the two files this phase creates do not exist yet, so no
existing suite covers them — and the covering check is therefore executing each newly created file
directly with `bash`, which is the only check that reaches these edits at all.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/tests/test-sapience-project-bind.sh` - new suite
- `agent-system/extensions/sapience/scripts/tests/test-sapience-vault-read.sh` - new suite
- `agent-system/extensions/sapience/manifest.json` - `provides.scripts` derives from the scripts
  tree; regenerated in this phase via `sync-manifest-scripts.sh --write`

**Verification**:
- Both new suites exit 0 when run directly.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-sapience-project-bind.sh,test-sapience-vault-read.sh`
  passes and reports exactly two discovered suites (confirming `--only` resolved both basenames
  rather than refusing an unknown token).
- `grep -rn 'app.spnc.ai' ` over the two new suites finds no live-call site outside a stub fixture.
- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` passes.

---

### Phase 5: Lockstep coverage and full verification [NOT STARTED]

**Goal**: the two new copies of the worktree-resolution block are actually compared by the
existing lockstep guard, the manifest is confirmed in sync, and the task closes against the
complete gate set.

**Tasks**:
- [ ] **Re-read** `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh`
      immediately before editing. This file carries an uncommitted working-tree modification from a
      prior dispatch, and a sibling task is active on this same tree; confirm via `git log` and
      `git diff` that the pending change is this task's lineage or a known prior dispatch's before
      proceeding, and STOP and report if a foreign commit or foreign modification appears.
- [ ] Append `"$SCRIPT_DIR/../sapience-project-bind.sh"` and `"$SCRIPT_DIR/../sapience-vault-read.sh"`
      to the `LOCKSTEP_FILES` array (currently five entries at lines 1218-1224), taking the array's
      size from five to seven entries total.
- [ ] Update the surrounding Case 30 comment so the file count it narrates matches the array, and
      so a future reader is not told "five" while the array holds seven.
- [ ] Run `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` and confirm
      `sapience: 16 on disk, 16 declared, 0 missing, 0 absent` and `CHECK PASSED` across all
      extensions.
- [ ] Stage only this task's own hunks — never a directory or glob `git add` — given the concurrent
      sibling on this working tree.
- [ ] Record the issue-log entry for this phase, and attest explicitly if nothing arose.

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: full

**Scope Hypothesis**: `LOCKSTEP_FILES` held exactly five hardcoded paths at
`test-sapience-mcp-registration.sh:1218-1224` when this plan was authored (2026-11-19), and
`sync-manifest-scripts.sh --check` reported `sapience: 11 on disk, 11 declared` with all twelve
extensions clean. Both figures are hypotheses about a file that already carries an uncommitted
modification and sits on a shared working tree. Re-check both before editing: count the array's
entries directly, and run `--check` to see the live declared/on-disk numbers, rather than trusting
the counts above. If either differs, reconcile against live state and say so in the phase note.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` - extend its
  LOCKSTEP_FILES array from five to seven paths and correct the Case 30 comment's file count
- `agent-system/extensions/sapience/manifest.json` - confirmed in sync here; no edit expected,
  but declared because this phase runs the regenerator's `--check` against it

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh`
  passes, with Case 30 comparing seven byte-identical copies of the marker block.
- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` passes.
- Under `/orchestrate`, this phase's own in-dispatch obligation is the scoped touched-path check:
  `bash agent-system/extensions/core/scripts/verify-touched.sh` over this task's touched paths.
  The complete gate set is **deferred to the orchestration close** (the once-per-invocation batch
  gate stage), not independently invoked here; this phase's note records that deferral explicitly.
  In a standalone, non-orchestrated run with no orchestration close to defer to, run
  `bash .claude/scripts/verify-deploy.sh` directly instead.

---

## Testing & Validation

- [ ] No test or script in this task contacts `app.spnc.ai` during a test run; every vault call is
      stubbed at the `sapience_post`/`sapience_get` boundary.
- [ ] No test performs a vault write, and the one mutating call site in the whole task
      (`/v1/people/projects/share`) is unreachable without both `--name` and `--confirm`.
- [ ] The live token value appears in no stdout, stderr, or log output of any script under
      `--dry-run` or under `set -x`.
- [ ] `.sapience/project.json` as written is byte-identical to `repo_link.py`'s `link_text` output
      and carries exactly three string keys.
- [ ] Case 30's lockstep comparison covers seven files and passes.
- [ ] `sync-manifest-scripts.sh --check` reports zero missing and zero absent for every extension.
- [ ] No instruction surface added by this task names an MCP write tool as a prescribed write path.

## Artifacts & Outputs

- `agent-system/extensions/sapience/scripts/lib/sapience-api-lib.sh`
- `agent-system/extensions/sapience/scripts/sapience-project-bind.sh`
- `agent-system/extensions/sapience/scripts/sapience-vault-read.sh`
- `agent-system/extensions/sapience/scripts/tests/test-sapience-project-bind.sh`
- `agent-system/extensions/sapience/scripts/tests/test-sapience-vault-read.sh`
- `agent-system/extensions/sapience/manifest.json` (regenerated `provides.scripts`)
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` (extended
  `LOCKSTEP_FILES`)
- `.sapience/project.json` at a bound repo's root — written only by an explicitly confirmed
  `sapience-project-bind.sh` run, never by this task's implementation itself

## Rollback/Contingency

Every deliverable is a new file except two surgical edits to existing files, so reverting is a
matter of deleting the five new paths and restoring the two edited files from `HEAD`. Because a
sibling task is active on this same working tree, do NOT use `git-snapshot.sh` in its default
reverting mode; use `bash .claude/scripts/git-snapshot.sh 647 --no-revert` for a defensive
checkpoint before the Phase 5 edit to `test-sapience-mcp-registration.sh`, and revert individual
paths explicitly rather than resetting the tree.

If Phase 2's live project-creation call is never exercised (it requires a human at the keyboard),
that is an expected outcome, not a failure: the script ships with its confirm-or-refuse contract
tested against stubs, and the single real invocation is a deliberate, separate human act.
