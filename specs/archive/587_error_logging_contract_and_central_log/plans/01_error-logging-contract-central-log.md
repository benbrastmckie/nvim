# Implementation Plan: Task #587

- **Task**: 587 - Error logging contract and central log
- **Status**: [COMPLETED]
- **Effort**: 11 hours
- **Dependencies**: None (coordinates with, but does not depend on, tasks 477, 484, 519, 543, 562)
- **Research Inputs**: specs/587_error_logging_contract_and_central_log/reports/01_error-logging-contract.md
- **Artifacts**: plans/01_error-logging-contract-central-log.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Error logging in this agent system is incoherent in a specific, measured way: the documented
contract (`rules/error-handling.md`) names `errors-append.sh`/`specs/errors.json` as *the* error
store, and that store has zero production writers and has not been written in over two months,
while the two stores that actually carry failure traffic (`specs/{NNN}_{SLUG}/issues.jsonl` and
`specs/events.jsonl`) go unmentioned by the error docs. This plan resolves that divergence for
every error class at once: it corrects the contract to name the store that is actually written,
adds one class to the shared vocabulary that distinguishes infrastructure unavailability from
work failure, documents one general occurrence-collapse convention on the existing `tags` seam,
and adds one push-based promotion path from the two live shared writers to a single central log
in this repository. Sapience backend failure is implemented strictly as a subclass of that
mechanism — one mechanical capture point in `sapience-retrieve.sh`'s already-unhappy exit path
and an honest, explicitly best-effort note for the MCP-tool class that cannot be captured
mechanically at all. Done means: the contract names the live store, the 503 outage replays into a
readable record in both the task log and the central log, and the full gate set is green after a
redeploy.

### Research Integration

Report `reports/01_error-logging-contract.md` settles design questions (a)-(g); this plan
implements its eight decisions without relitigating them. Specifically carried forward:
reuse `issues.jsonl` rather than create a new store (decision 1); correct the doc pointer rather
than revive `errors-append.sh` (decision 2); one net-new seed class rather than a
renormalization (decision 3); severity `minor` for the silently-degraded retrieval case
(decision 4); the `tags.occurrence` write-side collapse convention plus a citation render cap,
since `group_by(.class)` already performs read-time collapse (decision 5); mechanical capture
only where a script already holds the diagnostic, with the MCP-tool class recorded as an
accepted gap (decision 6); `events.jsonl` with `task: null` for the no-task-context case
(decision 7); push, not pull, with an owning-repo skip and `flock` (decision 8).

Two implementation-level details the report did not reach, grounded during planning and
specified here because the design does not work without them:

1. `sapience-retrieve.sh` currently exits 1 identically for a genuine transport/server failure
   and for a benign zero-hit search. Capturing the first without flooding the log with the
   second requires `curl --write-out` to retain the HTTP status alongside the body, and a
   distinct exit code for the genuine-failure branch. Every one of the script's call sites uses
   the `2>/dev/null) || memory_context=""` form and discards the exit code, so splitting it is
   backward compatible.
2. The 15-class seed enum is duplicated in `scripts/issue-record.sh` as `ISSUE_SEED_CLASSES`
   (plus a usage-comment copy). Adding a class to `issue-log.md` alone would make the script
   warn to stderr on every use of the new class, so both copies move together.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap phases are included.

### Premise Re-Validation (carried figures, re-measured 2026-11-10)

Every flagged figure in the dispatch description was re-measured directly during this planning
dispatch. Results, stated explicitly even where they only confirm the description:

| Carried claim | Re-measured | Verdict |
|---|---|---|
| `specs/errors.json`: 19 records, newest `2026-09-03T13:17:51Z` | 19 records, newest `2026-09-03T13:17:51.663Z` | **Confirmed** |
| `specs/events.jsonl`: 8241 lines / 3.2 MB | 8252 lines / 3.2 MB | **Confirmed, still growing** (report measured 8249) |
| `issues.jsonl`: 1448 entries across 162 files, 34 caller sites | 1450 entries across 163 files, 34 caller sites | **Confirmed, still growing** |
| Repo registry: 313 entries, 2 real | 536 entries, 3 real | **Confirmed as unusable; worse than the dispatch figure, matching the report's own re-measure** |
| `errors-append.sh` has no production `append` caller | One hit across every extension's `agents`/`skills`/`hooks`/`commands`: `core/commands/errors.md` (reader + `update` only) | **Confirmed** |
| Source store is the edit target; `.claude/**` is a disposable deploy artifact | `.claude-extensions.json` resolves every extension's `source_dir` under `agent-system/extensions/`; this repo owns its own source store | **Confirmed** |
| MCP failures bypass the two Sapience scripts | `orchestrate-build-dispatch.sh` is the only core caller of `sapience-retrieve.sh` (one line); `mcp__sapience__*` calls reach the vendor-owned `~/.sapience/mcp.py`, not these scripts | **Confirmed** |

All correction targets this plan names were read on disk during planning and exist:
`rules/error-handling.md`, `context/formats/issue-log.md`, `context/formats/events-format.md`,
`scripts/issue-record.sh`, `scripts/events-append.sh`, `scripts/orchestrate-conclusion-aggregate.sh`,
`scripts/lib/runtime-file-patterns.sh`, `scripts/lib/source-store-path-lib.sh`,
`scripts/tests/suite-classification.data`, `scripts/tests/test-issue-record.sh`,
`sapience/scripts/sapience-retrieve.sh`, `sapience/EXTENSION.md`, and
`sapience/context/project/sapience/domain/per-repo-scoping.md`. No phase's goal turns on a
dispatch-created orchestration sidecar.

## Goals & Non-Goals

**Goals**:

- One documented store contract: `rules/error-handling.md` names the store that is actually
  written (`issue-record.sh` -> `issues.jsonl`), with `errors.json`/`/errors` explicitly
  re-described as a narrower, decoupled triage surface rather than silently dropped.
- One class vocabulary addition that distinguishes infrastructure/transport unavailability from
  work failure, stated so a reader and an aggregator both know an entry of that class is not
  evidence the task's work failed.
- One general occurrence-collapse convention, carried on the existing open `tags` seam with no
  schema or writer-signature change, plus one stated render bound on the conclusion stage's
  citation list.
- One push-based promotion path from the two live shared writers to a single central log in this
  repository, with a single-generation size bound, `flock` concurrency safety, an owning-repo
  skip, and a silent documented no-op when the target is absent or unwritable.
- Mechanical capture at the one Sapience point that already holds the diagnostic, with the
  non-capturable MCP-tool class recorded honestly as an accepted gap.
- A readable record produced when the measured 503 outage is replayed against the finished
  mechanism — the acceptance test.

**Non-Goals**:

- No Sapience health probe, no monitoring that initiates its own traffic, no polling, no new
  hook.
- No block or retry of a dispatch on Sapience being down; silent degradation stays the contract.
- No change to `~/.sapience/mcp.py` or anything vendor-owned.
- No reporting UI and no alerting; a readable central log is the deliverable.
- No repair of the extension repo registry.
- No mass rewrite of the 34 `issue-record.sh` call sites or the `events-append.sh` call sites —
  the shared helpers change, never the callers.
- No migration of historical records out of `errors.json` or `events.jsonl`.
- No retirement of `errors.json`, `errors-append.sh`, or the `/errors` command; that is a
  larger, separate decision flagged as a follow-up candidate.
- No renormalization of existing class spellings (task 477's ground), no edit to the two
  scope-excursion emitters (task 484's ground), and no change to
  `orchestrate-cycle-postflight.sh`'s charge/verdict logic (task 519's ground).

### Boundary against the five named open tasks

Carried verbatim in substance from the research report, so no phase below silently re-solves
their ground:

- **Task 477** owns folding the already-fragmenting class spellings and the `--tasks`
  repeated-flag parsing bug inside `orchestrate-conclusion-aggregate.sh`. This plan adds one
  net-new class with no existing fragmenting spellings to fold, and touches none of 477's
  outcomes. It depends on the open-enum *mechanism*, not on 477's pending edits.
- **Task 484** owns the concrete per-path collapse fix at its two named emitter sites. Phase 1
  below defines the general collapse convention 484's own fix should then adopt — 484 becomes an
  **application of** this convention — but no phase here edits either emitter.
- **Task 519** owns the cycle-accounting exemption in `orchestrate-cycle-postflight.sh`, which
  runs on postflight's own transport-exception signals and never reads the `class` field. The new
  class name gives prose language to the same underlying concept; 519 does not consume the field
  and no phase here touches that script.
- **Task 543** (distrust the inherited error count) is an unrelated relay defect with no overlap
  in storage, classification, or promotion. Left untouched.
- **Task 562**'s underlying defect is already fixed in the live aggregator
  (`(.resolution // "open")`); it stays open only for an administrative transplant. Left
  untouched. Phase 6's render cap is additive and does not disturb that predicate.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The retrieval capture point fires on benign zero-hit searches, flooding every task log with noise | H | H if unaddressed | Phase 5 splits the exit codes explicitly: a dedicated non-zero code for genuine transport/HTTP failure, the existing code for zero-hit, and the capture call fires only on the former. The split is asserted in the new test suite, not assumed |
| The central-log push duplicates every entry of this repo into itself | M | H if unaddressed | The owning-repo skip is specified in Phase 3's lib contract and asserted by its tests, not left to implementation discretion |
| The push turns a non-fatal logging call into a fatal one | H | M | The lib returns 0 on every failure path and never sets `-e`-propagating state in its callers; Phase 4 wires it so a push failure cannot change `issue-record.sh`'s or `events-append.sh`'s exit code, and a test asserts that for an unwritable target |
| The central log grows unbounded, reproducing exactly the `events.jsonl` defect this task cites | M | M | A single-generation rotation at a stated line ceiling, performed under the same `flock` as the append (Phase 3) |
| A new lock file lands tracked in git, tripping the runtime-file-tracking gate | M | M | Phase 3 registers the lock as a named file-class member in `runtime-file-patterns.sh` and regenerates the managed `specs/.gitignore` block via `init-specs.sh`, rather than hand-editing the generated block |
| Correcting the contract pointer leaves a second, smaller divergence: a rule half-describing a now-inert `/errors` surface | M | M | Phase 2 states `/errors` and `errors.json` as a narrower, decoupled triage surface explicitly, and records full retirement as a follow-up candidate rather than performing or implying it |
| The best-effort MCP self-report note is read as "this is handled" | M | M | Phase 5 marks it best-effort in the note's own text and states the mechanical gap plainly beside it |
| A new file lands unregistered, so the deploy drops it silently | H | M | Each phase that creates a file registers it in the owning extension's `manifest.json` in that same phase (via `sync-manifest-scripts.sh --write`), never deferred to a later phase |
| Task numbers or record-versioning language leak into files under `agent-system/**` | M | M | Every phase's verification includes the task-reference and record-versioning lints; see the standing note below |

### Standing note for every phase

- **Edit target is the source store.** Every path below is under `agent-system/extensions/**`.
  No phase hand-edits anything under `.claude/**`. Only Phase 7 redeploys.
- **No task numbers, no record-versioning language** in any file landing under
  `agent-system/**` (`rules/no-task-references-in-deliverables.md`,
  `rules/no-record-versioning-in-deliverables.md`). Task numbers appear in this plan and in the
  dispatch description, where they are permitted; they must not be carried into an edited file.
  Describe the new class, the convention, and the central log on their own merits — never as
  "formerly", "no longer", or "replaces the old".
- **Scripts are not runnable from the source store** (`deploy-root-guard.sh`). Phases 1-6
  exercise changed scripts only through the existing test harness, which builds its own
  synthetic deployed tree (as `test-issue-record.sh` already does). No phase before Phase 7
  invokes `deploy-headless.sh`.
- **Record issues and wins as they arise** via `issue-record.sh`, per the dispatch's Issue Log
  section.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 5, 6 | 1 |
| 3 | 4 | 3 |
| 4 | 7 | 2, 4, 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Class vocabulary, collapse convention, and store topology [COMPLETED]

**Goal**: `context/formats/issue-log.md` becomes the single place that states the three-store
topology, carries a 16th seed class for infrastructure/transport unavailability, documents the
general occurrence-collapse convention on the existing `tags` seam, and specifies the central
log's envelope shape — with `issue-record.sh`'s duplicated seed-class list moved in the same
pass so the new class does not warn on every use.

**Tasks**:
- [x] Add a `infrastructure/transport unavailable` row to `issue-log.md`'s seed class table, with
      the gloss: an external system genuinely unreachable or self-reporting unavailable (an HTTP
      503 from a backing service, a transport `ESERVFAIL`, a dead MCP connection). State
      explicitly in the gloss that an entry of this class records infrastructure being
      unavailable, not the task's own work failing, and that nothing in cycle accounting reads
      this field — cycle-accounting treatment of transport deaths is a separate concern owned
      elsewhere and deliberately not changed here.
- [x] Update the section heading and prose that currently say "15-Class Taxonomy" / "15 seed
      classes" so the count matches the table. Audit the whole file for every count reference
      (there are occurrences in the field table's `class` row, the Extensibility Rule, and the
      section heading) and update each.
- [x] Add an `### Occurrence Collapse` subsection under `## The `tags` Seam` specifying the
      general convention: a caller that has already discovered N occurrences of one underlying
      event *before its first `issue-record.sh` call* writes exactly one line carrying
      `tags.occurrence = {count, first_seen, last_seen}` (`count` an integer, the two timestamps
      ISO 8601 UTC), passed via the existing `--tags-json`. State that this needs no schema or
      writer change, that it is a write-side convention available to any caller and to any error
      class, and that read-time cross-entry collapse is already performed by
      `orchestrate-conclusion-aggregate.sh`'s `group_by(.class)` and is not duplicated here.
- [x] Add a `## The Three-Store Topology` section stating the one-line verdict for each store,
      mirroring the clarity of the existing "Relation to the Six Existing Issue-Bearing Surfaces"
      table: `issues.jsonl` via `issue-record.sh` is the general-purpose capture surface for any
      failure inside a task context; `events.jsonl` via `events-append.sh` is the append-only
      lifecycle store and the only one of the three that accepts a null task, making it the
      capture surface when no task directory exists; `errors.json` via `errors-append.sh` is a
      narrower triage surface read by `/errors`, not the general error-handling write path.
      Cross-reference `rules/error-handling.md` and `context/formats/events-format.md` by name.
- [x] Add a `## Central Cross-Repo Log` section specifying the promotion target and its envelope,
      which Phase 3 implements against: path `specs/central-errors.jsonl` under the repository
      that owns the source store; one JSON object per line; envelope fields `central_id`
      (`cen_{timestamp_ms}_{random6}`), `recorded_at` (ISO 8601 UTC), `origin_repo` (the writing
      repository's absolute root), `origin_store` (`issues.jsonl` or `events.jsonl`), and `entry`
      (the original store line, verbatim and unmodified). State the promotion filter
      (`kind == "issue"` from `issues.jsonl`; `category == "blocker"` from `events.jsonl`; wins
      and non-blocker events are not promoted), the single-generation rotation bound, the
      owning-repo skip, and that an absent or unwritable target is a silent no-op by design.
      State the reading rule plainly: this log is the cross-repo inbox, so an entry written in
      the owning repository stays in its own task log and is not duplicated here — a reader
      asking "what has been breaking everywhere" reads this file together with this repository's
      own task logs.
- [x] Add `"infrastructure/transport unavailable"` to `ISSUE_SEED_CLASSES` in
      `scripts/issue-record.sh` and to the usage-comment copy of the enum in the same file, so
      the new class does not trip the lenient stderr warning. Change nothing else about the
      script's validation posture — `class` stays an open enum that warns and proceeds.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/tests/run-all.sh --only test-dispatch-metrics.sh,test-git-commit-phase.sh,test-git-commit-scoped.sh,test-issue-record.sh,test-orchestrate-batch-admit.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-conclusion-aggregate.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-redeploy-remedy-lib.sh,test-run-task-observers.sh` is the verbatim union `suite_selection_select` returns for this phase's two paths, and the edit is an additive array member plus prose with no signature change.

**Files to modify**:
- `agent-system/extensions/core/context/formats/issue-log.md` - new seed class row and gloss; count references corrected; new Occurrence Collapse subsection, Three-Store Topology section, and Central Cross-Repo Log section
- `agent-system/extensions/core/scripts/issue-record.sh` - new member in `ISSUE_SEED_CLASSES` and in the usage-comment enum copy

**Verification**:
- `bash .claude/scripts/tests/run-all.sh --only test-dispatch-metrics.sh,test-git-commit-phase.sh,test-git-commit-scoped.sh,test-issue-record.sh,test-orchestrate-batch-admit.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-conclusion-aggregate.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-redeploy-remedy-lib.sh,test-run-task-observers.sh` green
- `bash <repo_root>/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <repo_root>` green (doc-lint and task-reference lint; `<repo_root>` is the directory holding `.claude-extensions.json`, never a `source_dir`)
- Diff read-through confirming no count reference to the seed enum's size was left stale, and no task number or record-versioning phrasing was introduced

---

### Phase 2: Correct the documented error-store contract [COMPLETED]

**Goal**: `rules/error-handling.md` stops naming an abandoned store as the error-handling write
path and names the live one instead, with the no-task-context route stated and
`errors.json`/`/errors` re-described as a narrower triage surface rather than silently dropped.

**Tasks**:
- [x] Rewrite `rules/error-handling.md`'s `### 1. Log the Error` to name
      `bash .claude/scripts/issue-record.sh` as the mandated capture call for a dispatch-time
      error, with the documented non-fatal invocation form and a pointer to
      `context/formats/issue-log.md` for the field contract, the severity scale's admission
      tests, the seed class enum, and the CAPTURE ONLY boundary.
- [x] Add, in the same section, the no-task-context route: when no task directory exists,
      capture via `bash .claude/scripts/events-append.sh --category blocker` with `--task`
      omitted (the field is nullable by design), and state that this is the narrower answer for
      the one case `issue-record.sh` structurally cannot serve — it hard-requires a task
      directory.
- [x] Add a short `### Where Errors Are Stored` subsection pointing at `issue-log.md`'s new
      Three-Store Topology section rather than restating it, and describing
      `errors.json`/`errors-append.sh`/`/errors` on its own terms: a narrower triage surface with
      its own living-record schema and its own command, decoupled from the general capture path.
      Do not describe it as superseded, retired, or formerly-anything; state what it is.
- [x] Map the existing External Errors category list onto the new class vocabulary where they
      correspond: note that `tool_unavailable` and `mcp_abort_error` are the
      `infrastructure/transport unavailable` class in the capture store's vocabulary, and that an
      entry of that class is not evidence that the task's work failed.
- [x] Add a short note to `context/formats/events-format.md` at its nullable-`task` discussion
      recording that a non-task-scoped error capture is one of the intended uses of that
      nullability, with `category: "blocker"`, cross-referencing `rules/error-handling.md`.
- [x] Record, in the `### Where Errors Are Stored` subsection, that whether `errors.json`,
      `errors-append.sh`, and `/errors` should be retired outright is an open question left to a
      follow-up — a decision that would delete a command and a schema, deliberately not taken
      here.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: `bash .claude/scripts/tests/run-all.sh --only test-validate-wiring.sh,test-deploy-baseline-lib.sh` is the verbatim union `suite_selection_select` returns for this phase's two markdown paths, and both edits are confined to prose with no executable surface.

**Scope Hypothesis**: `errors-append.sh` has exactly one caller across every extension's
`agents`/`skills`/`hooks`/`commands` directories — `core/commands/errors.md`, which reads
`errors.json` and calls `errors-append.sh update`, never `append`. Confirm at implementation
time with `grep -rln 'errors-append.sh' agent-system/extensions/*/agents
agent-system/extensions/*/skills agent-system/extensions/*/hooks
agent-system/extensions/*/commands` before writing the "decoupled triage surface" description; if
a second caller has appeared, say so in the subsection rather than asserting the single-caller
shape.

**Files to modify**:
- `agent-system/extensions/core/rules/error-handling.md` - `### 1. Log the Error` rewritten to name `issue-record.sh`; no-task-context route added; new `### Where Errors Are Stored` subsection; External Errors categories mapped onto the new class
- `agent-system/extensions/core/context/formats/events-format.md` - note at the nullable-`task` discussion recording non-task-scoped error capture as an intended use

**Verification**:
- `bash .claude/scripts/tests/run-all.sh --only test-validate-wiring.sh,test-deploy-baseline-lib.sh` green
- `bash <repo_root>/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <repo_root>` green
- Diff read-through confirming the file no longer names `errors-append.sh append` as the mandated write path, that `/errors` is described rather than deprecated, and that no record-versioning phrasing was introduced
- `grep -n 'errors-append.sh' agent-system/extensions/core/rules/error-handling.md` shows only the triage-surface description, not a mandate

---

### Phase 3: The central-log push library [COMPLETED]

**Goal**: a new shared library resolves the owning repository, applies the promotion filter, and
performs a bounded, `flock`-guarded, silently-failing append — registered in the manifest and
with its lock file declared as a runtime file class, but not yet wired into any caller.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/lib/central-log-lib.sh` exporting one
      function, `central_log_promote <origin_store> <json_line>`, with a header stating it is the
      single home of this algorithm, that it is safe to source, that it sets no shell options a
      caller inherits, and that it returns 0 on every path including every failure path.
- [x] Implement owning-repository resolution with no repo enumeration and no registry read: read
      each extension's own per-extension `source_dir` from `<repo_root>/.claude-extensions.json`,
      resolve that directory's enclosing git toplevel, and take that toplevel as the owning
      repository. Reuse the attribution and containment rules already documented in
      `scripts/lib/source-store-path-lib.sh`'s header rather than inventing a second procedure;
      source that library if it gives the answer directly. A top-level `.source_dir` lookup
      returns `null` and must never be read as the key being absent.
- [x] Implement the owning-repo skip: when the resolved owning toplevel equals the writing
      repository's own canonicalized root, return 0 having written nothing.
- [x] Implement the promotion filter: promote an `issues.jsonl` line only when `kind == "issue"`;
      promote an `events.jsonl` line only when `category == "blocker"`; return 0 having written
      nothing otherwise.
- [x] Build the envelope with `jq -c -n` (never string concatenation), with the fields Phase 1
      specified: `central_id`, `recorded_at`, `origin_repo`, `origin_store`, `entry`.
- [x] Implement the bounded append under `flock -x` on `<owning_root>/specs/.central-errors.lock`:
      inside the lock, if `specs/central-errors.jsonl` already holds 20000 lines or more, rename
      it to `specs/central-errors.jsonl.1` (replacing any prior generation) and start a fresh
      file; then append the one envelope line.
- [x] Implement the silent no-op paths, each returning 0 with nothing written and nothing on
      stdout: `.claude-extensions.json` absent or unparseable; no extension's `source_dir`
      resolving to a git toplevel; `<owning_root>/specs` not an existing directory (never
      `mkdir -p` — an absent directory means the target is not a live owning repo); the lock or
      the append failing for any reason. Never retry, never emit a non-zero return, never write
      to stdout.
- [x] Register the new library in `agent-system/extensions/core/manifest.json`'s
      `provides.scripts` via `bash .claude/scripts/sync-manifest-scripts.sh --write` (then review
      the diff), never by hand-editing the array.
- [x] Add a `central-errors-lock` named member to `scripts/lib/runtime-file-patterns.sh`'s
      file-class list, immediately after the existing `issues-lock`/`metrics-lock` members and
      documented in the same shape, contributing the pattern `**/.central-errors.lock`. The
      central log itself is durable, tracked provenance and must NOT be added.
- [x] Regenerate the managed block in `specs/.gitignore` via `bash .claude/scripts/init-specs.sh`
      (or the regeneration entry point that file's own managed-block header names) rather than
      hand-editing the generated pattern list, and confirm the new pattern appears.
- [x] Create `agent-system/extensions/core/scripts/tests/test-central-log-lib.sh` asserting, over
      synthetic repository fixtures under `mktemp -d`: the owning-repo skip; a successful foreign
      -repo promotion producing exactly one well-formed envelope line; the `kind: "win"` and
      non-blocker filters each writing nothing; a missing `<owning>/specs` directory writing
      nothing and returning 0; an unwritable target returning 0; and the rotation firing at the
      line ceiling with the prior generation present at `.jsonl.1`. Register the suite in the
      core manifest in the same `sync-manifest-scripts.sh --write` pass, and add its
      `suite-classification.data` row as `unit` (the suite must therefore not spawn
      `deploy-headless.sh`, `verify-deploy.sh`, or a nested `run-all.sh`).

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: full

**Tier Justification**: this phase edits `core/manifest.json`'s `provides.scripts` and
`scripts/lib/runtime-file-patterns.sh`'s file-class list — global deploy configuration read by
every deploy, structural, orphan, and runtime-file-tracking gate — and regenerates the managed
`specs/.gitignore` block, a cross-cutting surface no suite subset or one-hop dependent build
covers.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/central-log-lib.sh` - new: `central_log_promote`, owning-repo resolution, promotion filter, envelope build, bounded `flock` append, silent no-op paths
- `agent-system/extensions/core/scripts/tests/test-central-log-lib.sh` - new: fixture-driven unit suite for the above
- `agent-system/extensions/core/manifest.json` - `provides.scripts` rows for the new library and the new suite, added via `sync-manifest-scripts.sh --write`
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` - new `central-errors-lock` file-class member contributing `**/.central-errors.lock`
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - `unit` row for `test-central-log-lib.sh`
- `specs/.gitignore` - managed block regenerated so it carries the new lock pattern

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` (the complete gate set) green, including gate 8's shell suites, the manifest-sync and undeclared-script structural checks, and the runtime-file-tracking gate
- `bash .claude/scripts/tests/run-all.sh --only test-central-log-lib.sh` green
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` exits 0 (the repository's sanctioned shellcheck entry point, exactly as gate 22 invokes it — never the bare binary)
- `git status --short specs/.gitignore` shows the regenerated managed block; `grep -n 'central-errors' specs/.gitignore` shows the lock pattern and nothing else

---

### Phase 4: Wire the push into the two shared store writers [COMPLETED]

**Goal**: `issue-record.sh` and `events-append.sh` each promote their just-written line through
the Phase 3 library, with zero change to any call site and no possibility of a push failure
affecting the writer's own exit code.

**Tasks**:
- [x] In `scripts/issue-record.sh`, after the existing `flock`-guarded append to
      `issues.jsonl` and before the `echo "$entry_id"`, source `lib/central-log-lib.sh` and call
      `central_log_promote issues.jsonl "$line"` in a form that cannot propagate a failure:
      guarded so neither `set -e` nor a non-zero return can change the script's own exit status
      or its stdout contract (stdout stays exactly the `entry_id`).
- [x] In `scripts/events-append.sh`, make the symmetric change after its `flock`-guarded append
      and before `echo "$event_id"`, calling `central_log_promote events.jsonl "$line"` under the
      same guard; stdout stays exactly the `event_id`.
- [x] Update both scripts' header comments to document the second, non-fatal promotion append and
      to point at `context/formats/issue-log.md`'s Central Cross-Repo Log section for the
      envelope and the filter. Do not change either script's documented CLI, exit codes, or
      stdout contract.
- [x] Extend `scripts/tests/test-issue-record.sh` with assertions that a `kind: "issue"` append
      in a synthetic foreign-repo fixture also lands one envelope line in the owning repo's
      central log; that a `kind: "win"` append lands nothing there; that `issue-record.sh`'s own
      stdout is still exactly the `entry_id`; and that an unwritable or absent central target
      leaves `issue-record.sh`'s exit code at 0.
- [x] Confirm by reading, not by assumption, that no call site of either script reads a stdout
      line beyond the single id, so the unchanged stdout contract is genuinely unchanged.

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: interface

**Tier Justification**: `bash .claude/scripts/tests/run-all.sh --only test-dispatch-metrics.sh,test-git-commit-phase.sh,test-git-commit-scoped.sh,test-issue-record.sh,test-orchestrate-batch-admit.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-conclusion-aggregate.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-redeploy-remedy-lib.sh,test-run-task-observers.sh,test-deploy-baseline-lib.sh,test-gate-cache-equivalence.sh,test-gate-out-repair-reporting.sh,test-gate-out-self-attribution.sh,test-guard-git-push.sh,test-handoff-dispatch-identity.sh,test-orchestrate-context-growth.sh,test-orchestrate-recover-message-findings.sh,test-please-grant.sh,test-subagent-postflight-marker.sh` is the verbatim union `suite_selection_select` returns for this phase's three paths — the enumerated direct dependents of the two changed writers.

**Scope Hypothesis**: `issue-record.sh` has 34 caller sites and `events-append.sh` has its own
set, and this phase changes none of them. Confirm at implementation time with
`grep -rl 'issue-record.sh' agent-system --include='*.sh' --include='*.md' | wc -l` (expected 34)
and by checking that `git status --short` after the phase lists no caller file; if the count has
moved, record the new figure rather than carrying 34 forward.

**Files to modify**:
- `agent-system/extensions/core/scripts/issue-record.sh` - non-fatal `central_log_promote issues.jsonl` call after the existing append; header comment documents the promotion
- `agent-system/extensions/core/scripts/events-append.sh` - non-fatal `central_log_promote events.jsonl` call after the existing append; header comment documents the promotion
- `agent-system/extensions/core/scripts/tests/test-issue-record.sh` - new assertions for the promotion, the win filter, the unchanged stdout contract, and the non-fatal unwritable-target path

**Verification**:
- The `run-all.sh --only` invocation named in the Tier Justification above, green
- `bash .claude/scripts/tests/run-all.sh --only test-issue-record.sh,test-central-log-lib.sh` green
- Diff read-through confirming neither script's CLI, exit codes, nor stdout contract changed, and that no call-site file appears in the diff

---

### Phase 5: Sapience capture — mechanical where possible, honest where not [COMPLETED]

**Goal**: `sapience-retrieve.sh` distinguishes a genuine transport/HTTP failure from a benign
zero-hit search and retains the server's own diagnostic body; its one core caller records an
`infrastructure/transport unavailable` entry on that branch; and the MCP-tool class that cannot
be captured mechanically is documented as an accepted gap with an explicitly best-effort
self-report note.

**Tasks**:
- [x] In `sapience-retrieve.sh`, change the single `curl` invocation to retain the HTTP status
      alongside the body (`--write-out` with a separator the parser can split on), keeping
      `-sS --connect-timeout 3 --max-time 8` and adding no second request.
- [x] Split the script's failure exits: keep the existing exit code for the benign outcomes
      (no token configured, zero hits after normalization, empty selection) and introduce one
      distinct non-zero exit code for the genuine-failure branch — curl transport failure, a
      non-2xx HTTP status, or a non-JSON body. On that branch only, emit a one-line diagnostic to
      stderr carrying the HTTP status and a length-bounded excerpt of the response body (so a 503
      carrying `{"error": "...", "starting": true, "retry_after": 15, "db_mb": 0}` is preserved
      rather than discarded). Document the exit-code split and the stderr shape in the script's
      header. Add no network call and no latency on the success path.
- [x] In `orchestrate-build-dispatch.sh`'s Stage 3.5 `memory_context` block, capture stderr and
      the exit code from the existing single call, and — only on the genuine-failure exit code —
      call `issue-record.sh` non-fatally with `--class "infrastructure/transport unavailable"`,
      `--severity minor`, `--resolution worked_around`, the retained stderr diagnostic as
      `--what-happened`, and the current `--phase`/`--dispatch-seq`/`--session`. On every other
      exit code, behave exactly as today: `memory_context=""` and nothing recorded. Retrieval must
      still never block or retry the dispatch.
- [x] Verify by reading that `sapience-remember.sh` already emits a precise stderr diagnostic and
      a distinct non-zero exit on each of its failure branches (`set_aside`, `gated`,
      `written == 0`, `ok != true`), and leave the script unedited. Instead, extend the postflight
      wrapup instruction in `sapience/EXTENSION.md` so a failed `sapience-remember.sh` call is
      recorded via `issue-record.sh` with the same class and the script's own stderr text as
      `--what-happened`, keeping the existing degrade rule (a failed write never blocks
      postflight) unchanged.
- [x] Add a short, explicitly best-effort note to `sapience/EXTENSION.md` and to
      `context/project/sapience/domain/per-repo-scoping.md` stating the mechanical gap plainly:
      an `mcp__sapience__*` tool failure does not pass through either script, surfaces only as a
      tool-call error in the agent's own turn, and there is no repository-side interception point
      for it (the merged settings carry no wildcard-matcher `PostToolUse` hook, and the MCP client
      is vendor-owned and outside this repository). Ask the agent to self-report such a failure
      via `issue-record.sh` with the same class, and say in the note's own text that this is
      best-effort and not a substitute for mechanical capture.
- [x] Create `agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` asserting,
      with `curl` stubbed in the manner `scripts/tests/curl-stub.sh` already establishes: a 503
      body yields the genuine-failure exit code with the body excerpt on stderr; a 200 with an
      empty result set yields the benign exit code with nothing on stderr; a 200 with hits exits
      0 and emits the memory block; and a curl transport failure yields the genuine-failure exit
      code. Register the suite in `sapience/manifest.json`'s `provides.scripts` as
      `tests/test-sapience-capture.sh` via `sync-manifest-scripts.sh --write`, and add its
      `unit` row to core's `suite-classification.data`.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: full

**Tier Justification**: this phase edits `sapience/manifest.json`'s `provides.scripts` — global
deploy configuration read by every deploy and structural gate — alongside
`sapience-retrieve.sh`'s exit-code contract, which is consumed from ten call sites across nine
extensions; no suite subset or one-hop dependent build covers both surfaces.

**Scope Hypothesis**: `sapience-retrieve.sh` has ten call sites — one in
`core/scripts/orchestrate-build-dispatch.sh` and nine in domain research/implementation skill
bodies — and every one of them uses the `2>/dev/null) || memory_context=""` form, discarding the
exit code, which is what makes the split backward compatible. Confirm at implementation time with
`grep -rn 'sapience-retrieve.sh' agent-system --include='*.sh' --include='*.md'` and by reading
each hit's invocation form; if any call site reads the exit code or stderr, adapt that site in
this phase rather than asserting compatibility.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` - `curl --write-out` retains HTTP status; genuine-failure branch split onto its own exit code with a length-bounded stderr diagnostic; header documents the split
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - Stage 3.5 captures the retrieval exit code and stderr and records an `infrastructure/transport unavailable` entry non-fatally on the genuine-failure code only
- `agent-system/extensions/sapience/EXTENSION.md` - postflight wrapup records a failed `sapience-remember.sh` call via `issue-record.sh`; best-effort MCP self-report note with the mechanical gap stated plainly
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` - the same mechanical-gap statement at the two scripts' contract description
- `agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` - new: curl-stubbed suite asserting the exit-code split and the stderr diagnostic
- `agent-system/extensions/sapience/manifest.json` - `provides.scripts` row for the new suite, added via `sync-manifest-scripts.sh --write`
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - `unit` row for `test-sapience-capture.sh`

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` (the complete gate set) green, including the manifest-sync, undeclared-script, and index-entry structural checks
- `bash .claude/scripts/tests/run-all.sh --only test-sapience-capture.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-build-aux-dispatch.sh,test-orchestrate-context-growth.sh` green
- Diff read-through confirming the success path gained no network call and no added work, and that the best-effort note states the gap rather than implying coverage

---

### Phase 6: Bound the conclusion stage's citation render [COMPLETED]

**Goal**: the aggregator's per-class proposal renders a bounded citation list with a stated
remainder count, so a long outage or a high-volume emitter cannot produce an unreadable
proposal — the read-side half of the general collapse rule, with the existing `group_by(.class)`
grouping and null-resolution predicate untouched.

**Tasks**:
- [x] In `scripts/orchestrate-conclusion-aggregate.sh`'s `--aggregate` pipeline, cap the rendered
      `citations` list at the first 10 entries and append an explicit remainder marker naming the
      exact number withheld (never a silent truncation). Preserve the full set in the underlying
      data the raw `issues.jsonl` evidence already carries; this is a render bound, not a filter.
- [x] Leave `group_by(.class)` and the `(.resolution // "open")` predicate exactly as they are.
      Do not fold, case-normalize, or otherwise renormalize any class spelling — that is a
      separate task's ground.
- [x] Document the cap in `context/contracts/conclusion-stage.md` beside the existing filter
      predicate: the number, the remainder-marker shape, and the statement that the full evidence
      set remains in the per-task logs.
- [x] Extend `scripts/tests/test-orchestrate-conclusion-aggregate.sh` with an assertion that a
      class carrying more than 10 entries renders exactly 10 citations plus a remainder marker
      with the correct count, and that a class with fewer renders them all with no marker.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/tests/run-all.sh --only test-orchestrate-conclusion-aggregate.sh,test-orchestrate-suggest-next-batch.sh` is the verbatim union `suite_selection_select` returns for this phase's paths, and the change is confined to one script's render step with no signature change.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh` - `--aggregate` renders at most 10 citations per class plus an explicit remainder count
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` - the cap, its remainder-marker shape, and the full-evidence-remains statement documented beside the filter predicate
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-aggregate.sh` - assertions for the over-cap and under-cap render shapes

**Verification**:
- `bash .claude/scripts/tests/run-all.sh --only test-orchestrate-conclusion-aggregate.sh,test-orchestrate-suggest-next-batch.sh` green
- `bash <repo_root>/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <repo_root>` green
- Diff read-through confirming `group_by(.class)` and the `(.resolution // "open")` predicate are byte-identical to before

---

### Phase 7: Redeploy, run the full gate set, and replay the outage [COMPLETED WITH EXCLUSIONS]

**Goal**: the source-store changes reach the deployed tree, the complete gate set is green, and
the acceptance test passes — replaying the measured 503 outage against the finished mechanism
yields a readable record in both the task log and the central log.

**Tasks**:
- [x] Redeploy with the bounded-wait idiom: `timeout 540 bash .claude/scripts/deploy-headless.sh`
      with the Bash tool's `timeout` parameter raised to 600000, per
      `context/patterns/external-process-wait.md` Rule 1. This resolves the per-extension staleness
      the dispatch flagged for `core` as well as the changes above.
- [x] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` with no `--skip-slow` *(completed with exclusions: see Reasoned Exclusions below)*
      and no `--only-gate`, and confirm green. A narrowed pass is not evidence here.
- [x] Acceptance replay, Sapience retrieval: with `curl` stubbed to return HTTP 503 carrying the
      measured body (`{"error": "your Sapience is starting, try again in a minute", "starting":
      true, "retry_after": 15, "db_mb": 0}`), exercise the deployed
      `.claude/scripts/sapience-retrieve.sh` and confirm the genuine-failure exit code and the
      body excerpt on stderr; then confirm that a dispatch-build pass over that branch appends an
      `infrastructure/transport unavailable` entry to this task's `issues.jsonl` whose
      `what_happened` carries the server's own sentence. Read the resulting line and confirm it is
      readable on its own — the acceptance bar the dispatch set.
- [x] Acceptance replay, central promotion: in a synthetic foreign-repo fixture, confirm the same
      entry produces exactly one well-formed envelope line in this repository's
      `specs/central-errors.jsonl`, and that a same-repo write produces none (the owning-repo
      skip).
- [x] Acceptance replay, collapse: confirm a caller passing
      `--tags-json '{"occurrence":{"count":N,"first_seen":"...","last_seen":"..."}}'` writes one
      line carrying that object, and that a class with more than 10 entries renders 10 citations
      plus a remainder count at the conclusion stage.
- [x] State the measured cost figure in the implementation summary, as the dispatch's (g)
      requires: no new hook, no polling, no probe, no added network call, and zero added work on
      the retrieval success path; per promoted error-bearing record, one `jq -c -n` envelope
      build, one line count, and one `flock`-guarded local filesystem append. Measure the actual
      per-call overhead during this phase rather than asserting the estimate.
- [x] Confirm the lints the standing note names are green across the whole diff: no task-number
      reference and no record-versioning phrasing in any file under `agent-system/**`.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| `verify-deploy.sh` gate 24 (`lint-dead-command-recommendations.sh`) FAIL naming `/ide` | Pre-existing, unrelated to this task: the two violations are in `agent-system/extensions/memory/context/project/memory/{memory-setup.md,memory-troubleshooting.md}`, neither touched by this diff | `git log --oneline -3` on both files shows their last touches were unrelated tasks 435/29/863; `git diff` across this task's full commit range shows neither file appears |
| `tests/run-all.sh` (gate 8) reports 5 suites as NEW failures: `test-deploy-baseline-lib.sh`, `test-gate-cache-lib.sh`, `test-gate-registry-resolution.sh`, `test-lint-deploy-caller-wrap.sh`, `test-orchestrate-build-aux-dispatch.sh` | Pre-existing, unrelated latent bug in each suite's own repo-root path resolution: a hardcoded 4-level walk-up assumes source-store invocation depth and resolves to a path outside the repository when `run-all.sh` invokes the suite from its deployed location instead | Direct reproduction: the walk-up resolves `ROOT=/home/benjamin` (outside the repo) when run from `.claude/scripts/tests/`, versus the correct repo root when run from `agent-system/extensions/core/scripts/tests/`; all 5 suites pass 100% (30/30, 28/28, 44/44, 7/7, 22/22) when invoked from the source-store path instead; `git log` on each file shows its last touch predates this task (tasks 328/416/418/446/554) |

A genuinely NEW regression this same gate-8 run surfaced mid-phase — `issue-record.sh`/
`events-append.sh` unconditionally sourcing the new `lib/central-log-lib.sh`, crashing any
fixture lacking it — was fixed inline during this phase (see the commit guarding both scripts'
source call with a file-existence check) and is NOT part of this exclusion; it is a closed,
fixed defect, re-verified green across every affected suite (`test-git-commit-phase.sh`,
`test-guard-git-push.sh`, `test-please-grant.sh`, `test-run-task-observers.sh`,
`test-subagent-postflight-marker.sh`, `test-runtime-file-tracking.sh`).

**Timing**: 1.5 hours

**Depends on**: 2, 4, 5, 6

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, regenerating the entire deployed tree; declared per the whole-tree-claim rule
- `specs/587_error_logging_contract_and_central_log/summaries/01_error-logging-contract-central-log-summary.md` - implementation summary carrying the measured cost figure and the acceptance-replay results

**Verification**:
- `timeout 540 bash .claude/scripts/deploy-headless.sh` completes, and the deploy-freshness warning for `core` is gone
- `bash .claude/scripts/verify-deploy.sh` (the complete gate set, no `--skip-slow`, no `--only-gate`) green
- `bash .claude/scripts/tests/run-all.sh` green (the full suite corpus, gate 8's own battery)
- The replayed 503 produces a readable `infrastructure/transport unavailable` line in this task's `issues.jsonl` and exactly one envelope line in a foreign-repo fixture's promotion, with the owning-repo skip observed
- The measured per-call overhead figure is recorded in the summary

---

## Testing & Validation

- [ ] `bash .claude/scripts/tests/run-all.sh --only test-central-log-lib.sh` — owning-repo skip, promotion filter, envelope shape, rotation bound, and every silent no-op path
- [ ] `bash .claude/scripts/tests/run-all.sh --only test-issue-record.sh` — the new class accepted without a stderr warning; promotion from a foreign-repo fixture; win filtered; stdout still exactly the `entry_id`; exit 0 on an unwritable central target
- [ ] `bash .claude/scripts/tests/run-all.sh --only test-sapience-capture.sh` — the 503 body yields the genuine-failure exit code with the body excerpt; a zero-hit 200 yields the benign code silently; a transport failure yields the genuine-failure code
- [ ] `bash .claude/scripts/tests/run-all.sh --only test-orchestrate-conclusion-aggregate.sh` — the 10-citation cap with an explicit remainder count, and the under-cap no-marker case
- [ ] `bash .claude/scripts/verify-deploy.sh` (complete gate set) green after the Phase 7 redeploy
- [ ] `bash .claude/scripts/tests/run-all.sh` (full corpus) green
- [ ] Acceptance test: replaying the measured 503 outage yields a readable record in `issues.jsonl` and one envelope line in the central log
- [ ] No task-number reference and no record-versioning phrasing anywhere in the diff under `agent-system/**`
- [ ] `grep -rn 'errors-append.sh append' agent-system/extensions/core/rules/` returns nothing

## Artifacts & Outputs

- `agent-system/extensions/core/context/formats/issue-log.md` — 16-class seed enum, Occurrence Collapse convention, Three-Store Topology, Central Cross-Repo Log envelope and filter
- `agent-system/extensions/core/rules/error-handling.md` — corrected store contract, no-task-context route, `errors.json`/`/errors` described as a narrower triage surface
- `agent-system/extensions/core/context/formats/events-format.md` — non-task-scoped error capture noted as an intended use of the nullable `task`
- `agent-system/extensions/core/scripts/lib/central-log-lib.sh` — new shared promotion library
- `agent-system/extensions/core/scripts/issue-record.sh`, `.../events-append.sh` — non-fatal promotion wired in; new seed class in the enum
- `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh`, `.../context/contracts/conclusion-stage.md` — bounded citation render
- `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` — exit-code split and retained diagnostic body
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — capture on the genuine-failure branch
- `agent-system/extensions/sapience/EXTENSION.md`, `.../domain/per-repo-scoping.md` — remember-failure capture and the best-effort MCP note with the mechanical gap stated
- New suites: `core/scripts/tests/test-central-log-lib.sh`, `sapience/scripts/tests/test-sapience-capture.sh`, with their manifest rows and `suite-classification.data` rows
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` and the regenerated `specs/.gitignore` managed block — the new lock file class
- `specs/587_error_logging_contract_and_central_log/summaries/01_error-logging-contract-central-log-summary.md` — implementation summary with the measured cost figure
- `specs/central-errors.jsonl` — the central log, created lazily on its first foreign-repo promotion

## Rollback/Contingency

Every change is additive and confined to the source store plus two generated files
(`specs/.gitignore`'s managed block and, lazily, `specs/central-errors.jsonl`). Phases commit
per green sub-step, so the unit of revert is a single commit.

- **A phase goes wrong mid-flight**: fix forward — correct the source to resolve the failure.
  Never discard uncommitted changes to reach a passing gate (`rules/error-handling.md`'s
  write-gating constraint).
- **A genuine rollback is required** (a committed phase must be undone): follow
  `context/contracts/recovery.md`'s rollback rung for the exact snapshot-then-rollback invocation
  shape, including its out-of-scope override flag. Do not emit a bare reverting snapshot as a
  routine precaution; an ordinary defensive checkpoint before risky work uses the non-reverting
  form.
- **The central-log push misbehaves in production**: the fastest safe disable is to make
  `central_log_promote` return 0 immediately at its entry, which restores the pre-change behavior
  of both writers exactly, since every other code path in them is untouched. The promotion is
  non-fatal by construction, so a misbehaving push cannot fail a dispatch in the meantime.
- **The retrieval exit-code split breaks a call site**: every call site discards the exit code
  today, so reverting the split is a single-file revert of `sapience-retrieve.sh` plus the Stage
  3.5 capture block; neither the contract documentation nor the central log depends on it.
- **A redeploy leaves the tree inconsistent**: re-run
  `timeout 540 bash .claude/scripts/deploy-headless.sh` and then
  `bash .claude/scripts/verify-deploy.sh`. Never hand-patch a file under `.claude/**` as a
  substitute — that masks the divergence instead of fixing it.
