# Implementation Plan: Topic-Keyed Post-Task Observer Seam

- **Task**: 331 - Topic-keyed post-task observer seam for extensions
- **Status**: [NOT STARTED]
- **Effort**: 8 hours
- **Dependencies**: 327 (completed), 330 (completed)
- **Research Inputs**: specs/331_topic_keyed_post_task_observer_seam/reports/01_topic-keyed-observer-seam.md
- **Artifacts**: plans/01_topic-keyed-observer-seam.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/source-store-deploy-boundary.md
  - .claude/rules/no-task-references-in-deliverables.md
  - .claude/context/standards/shell-strict-mode.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a manifest-declared `observers` block through which a loaded extension registers a script
that runs AFTER a task reaches a resting state under `/orchestrate`, matched prefix-aware on the
task's `topic` and/or `task_type` (match-if-either). The seam is advisory and non-blocking: the
observer's return code is recorded as an event in `specs/events.jsonl` and otherwise ignored, a
timeout bounds its runtime, and nothing it does can change task status or fail a dispatch. The
work spans a resolve-all-matches function in the shared manifest-routing library, a new
`run-task-observers.sh` invoker, its regression suite, one correctly-ordered call site in
`orchestrate-cycle-postflight.sh`, a new doc-consistency rule in `check-extension-docs.sh`, and
the documentation that makes `active_projects[].topic` a declared dispatch-matching key for the
first time. Definition of done is the dispatch's own ACCEPTANCE line, mechanically exercised.

**EDIT TARGET**: every file below is in the SOURCE STORE at
`/home/benjamin/.config/nvim/agent-system/extensions/core/`. `.claude/**` is a gitignored,
disposable deploy artifact; a file hand-authored there is wiped by the next deploy. Paths in
this plan are written relative to the core source-store root unless stated otherwise. No file
written into the source store may cite a task number — cite durable anchors (filenames, section
headings, manifest keys) instead.

### Research Integration

The research report (`reports/01_topic-keyed-observer-seam.md`) is integrated as follows, and its
measurements supersede the dispatch description's own stale line numbers:

- **Insertion point**: the dispatch's "~1048-1125" estimate is stale. Re-measured live at plan
  time: `orchestrate-cycle-postflight.sh` is 1762 lines; the `dispatch_status` case arm (every
  `issue-record.sh` call site) spans 931-1256; WORK (m)'s per-dispatch `dispatch-metrics.sh` call
  spans 1491-1543; WORK (i)'s per-task commit begins 1545; `persisted_status` is computed at
  ~1697-1711. The plan adopts the report's recommended option (b) — see Decision D4.
- **Library reuse boundary**: `manifest-routing-lib.sh`'s `routing_lookup`/`routing_lookup_flat`
  are first-match-wins single-value resolvers and are the WRONG shape for observers, which must
  fire EVERY match. Only the manifest-enumeration idiom and the prefix-match idiom
  (`grep -q ":"` then `cut -d: -f1`) are reused. A third, sibling, resolve-all function is added
  alongside them; neither existing ladder is modified.
- **rc event target**: `specs/events.jsonl` via `scripts/events-append.sh`, whose `--category`
  enum is closed (`deviation|blocker|milestone|success`) and stays closed — `success` on rc 0,
  `deviation` otherwise, with every distinguishing fact in `--detail-json`.
- **`topic` doc line**: `context/reference/state-management-schema.md:124` (the Project Entry
  Fields table row) is the single line to rewrite. Line 69's `active_topics` wording is accurate
  as-is and is NOT changed.
- **Next Rule letter**: `X` (A-W assigned per `check-extension-docs.sh`'s own header index).
- **Research nuance adopted**: `scripts/memory-retrieve.sh` reads a DIFFERENT field also named
  `topic` (a memory-index entry's own taxonomy value, used as a retrieval-scoring bonus). All
  prose written by this plan therefore claims that `active_projects[].topic` becomes a
  **dispatch-matching** key for the first time — never the unqualified "topic is never a routing
  key", which that reader would contradict.
- **`timeout` availability**: confirmed live on this machine (`GNU coreutils 9.11` at
  `/run/current-system/sw/bin/timeout`); no script in the codebase uses it yet. See Decision D3.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch context; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:
- A top-level `observers` block in `manifest.json` by which a loaded extension registers a
  post-task script, matched prefix-aware on `topic` and/or `task_type`, match-if-either.
- Resolve-ALL-matches resolution shared out of `scripts/lib/manifest-routing-lib.sh`, so observer
  resolution is not a second independent manifest reader.
- A `scripts/run-task-observers.sh` invoker: resolve, match, invoke with a bounded timeout, emit
  exactly one rc event per attempted observer, always exit 0.
- Exactly one call site in `orchestrate-cycle-postflight.sh`, provably ordered AFTER this
  dispatch's issue-log and metrics writes.
- Mechanical enforcement that a declared observer is documented (`check-extension-docs.sh`
  Rule X).
- Documentation in `docs/guides/creating-extensions.md` (schema, ordering guarantee, advisory
  contract, WHY NOT LIFECYCLE HOOKS) and `context/reference/state-management-schema.md` (`topic`
  is now a binding key).

**Non-Goals**:
- No concrete first-consumer observer is written by this task; the seam ships with zero live
  declarations (a separate backlog item depends on this one).
- No change to the existing lifecycle-hook mechanism, and specifically NO plumbing of `TASK_TYPE`
  through the `/orchestrate` postflight hook path — that would still be equality-on-`task_type`
  and would still match none of the measured corpus (see Decision D2).
- No change to `routing_lookup` / `routing_lookup_flat` precedence or return contracts.
- No new event category; no new event store; no `manifest.json` JSON Schema file (none exists).
- No observer invocation anywhere but the `/orchestrate` postflight path (not from
  `skill-base.sh`, not from the single-task `/research|/plan|/implement` skills).

## Decisions

These are design choices this plan fixes so the implementer does not re-litigate them. They are
recorded here and in the guide section Phase 6 writes.

- **D1 — manifest schema**: an open-keyed object of per-entry objects, modeled on
  `keyword_overrides`:
  ```json
  "observers": {
    "my-observer": {
      "script": "scripts/my-observer.sh",
      "topic": "books",
      "task_type": "books"
    }
  }
  ```
  `script` is REQUIRED. At least one of `topic` / `task_type` is REQUIRED. Both present means
  match-if-either. Any other key in an entry is a Rule X failure. The `script` value resolves by
  BASENAME against the deployed `.claude/scripts/` directory, identical to the lifecycle-hook
  path-resolution contract, and must therefore also appear in `provides.scripts`.
- **D2 — why not lifecycle hooks** (verified against live code by the research pass, both points
  exactly as the dispatch stated): (1) `skill_get_extension_dir()` (`scripts/skill-base.sh`,
  measured 150-169) resolves by STRING EQUALITY against a manifest's single-valued top-level
  `task_type` field — no prefix awareness, no `topic` awareness. (2) under `/orchestrate`,
  `skill_postflight_update` passes `"${TASK_TYPE:-}"` (`skill-base.sh:1089`) while
  `orchestrate-cycle-postflight.sh` sets no `TASK_TYPE` anywhere in its 1762 lines, so the
  postflight hook receives an EMPTY task type on that path. The already-landed lifecycle-hook
  repair fixed the resolver, the return-code channel and the verification stage; it did not and
  could not supply a task type that is never set on that path. Both facts must be re-measured by
  the implementer before being written down, and both belong in the guide.
- **D3 — timeout mechanism**: prefer `timeout`, then `gtimeout`, then SKIP the observer with a
  `deviation` rc event carrying `"skipped": "no_timeout_binary"`. Running an observer
  un-timed-out is NOT an acceptable fallback — "give it a timeout so a hanging observer cannot
  wedge an orchestration" is the contract, and an un-bounded invocation violates it while
  appearing to satisfy it in code. Skipping is loud (an event), non-blocking, and preserves the
  invariant. Default timeout: 30 seconds, overridable per entry by an optional
  `timeout_seconds` integer key (admitted by Rule X's key allowlist).
- **D4 — insertion point**: immediately AFTER the `persisted_status` computation (~line 1697-1711
  as measured, re-measure by its `# ─── persisted_status:` comment marker, never by line number)
  and BEFORE the `# ─── Final output ───` block, as a new WORK-lettered section. Rationale: it
  runs after BOTH per-dispatch records (WORK (k)'s issue-log sites at 931-1256 and WORK (m)'s
  metrics at 1491-1543), which is the ordering contract's only real requirement; it lets the
  "resting status reached" argument be `$persisted_status` verbatim rather than requiring a
  second case-on-`dispatch_status` translation; and `specs/events.jsonl` is not in WORK (i)'s
  `stage_paths`, so there is no commit-ordering reason to prefer the earlier slot.
- **D5 — gating**: gate on `is_live` ONLY, mirroring WORK (m)'s own documented posture, and emit
  the standard `[dry-run] would ...` notice on the else branch. Do NOT attempt to detect "did a
  genuine new resting-state transition happen this cycle": the `blocked)` and ordinary
  blocker-free `partial)` arms perform no state.json transition at all yet are exactly the
  outcomes an observer may care about. Pass whatever `$persisted_status` is and let the observer
  author decide what is interesting.
- **D6 — manifest root resolution must be cwd-independent**: `run-task-observers.sh` sets
  `ROUTE_MANIFEST_ROOT` to an absolute `"${PROJECT_ROOT}/.claude"` when the caller has not
  already set it, so resolution never depends on the invoking shell's working directory. This is
  what lets the postflight fixture sandbox exercise the real path with its own synthetic
  `.claude/extensions/*/manifest.json` tree.
- **D7 — multiple-match ordering**: deterministic, by manifest glob order (the filesystem order
  `"${ROUTE_MANIFEST_ROOT}"/extensions/*/manifest.json` yields), then by observer key sorted
  within a manifest. Documented, so test expectations are stable when two extensions both match
  one task.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Line-number staleness in `orchestrate-cycle-postflight.sh` (three tasks in a row have edited it, and a dependent task follows) | M | H | Phase 4 re-greps the `# ─── WORK (` and `# ─── persisted_status:` comment markers and locates the insertion point by marker, never by any line number — including the ones in this plan |
| `timeout` absent in some consuming environment, so a hanging observer wedges an orchestration despite the contract being met in code | H | L | D3: skip-with-event rather than invoke un-bounded; a Phase 3 test case drives the no-binary path via a `PATH`-stripped fixture |
| Observer resolution accidentally inherits `routing_lookup`'s first-match-wins return, silently dropping all but one match | H | M | Phase 1 adds a SIBLING function and never touches the two existing ladders; a Phase 3 test case asserts two matching extensions both fire |
| An observer mutates task status or fails the dispatch | H | L | The call site is non-fatal (`\|\| echo "Note: ..." >&2`), `run-task-observers.sh` always `exit 0`, and a Phase 3 case asserts a crashing observer leaves the status file untouched |
| Rule X's README documentation check hard-fails a real extension on first run | M | L | No live extension declares `observers` today (verified in Phase 5); the check returns 0 when the block is absent, exactly like Rule W |
| Adding a function to a sourced library breaks every sourcing caller on a syntax error | H | L | Phase 1 is `interface` tier with the dependent set enumerated and re-run |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 5, 6 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 2, 3 |
| 5 | 7 | 3, 4, 5, 6 |

Phases within the same wave can execute in parallel; their file sets are disjoint.

---

### Phase 1: Resolve-all-matches observer resolution in the shared routing library [NOT STARTED]

**Goal**: `scripts/lib/manifest-routing-lib.sh` gains one sibling function that returns EVERY
observer declaration matching a given `(topic, task_type)` pair across every loaded extension,
without touching either existing single-value ladder.

**Tasks**:
- [ ] Re-read `scripts/lib/manifest-routing-lib.sh` in full (257 lines measured) and confirm its
      three contract clauses still hold: never calls `exit`, sets no shell options (Class C per
      `context/standards/shell-strict-mode.md`), every internal variable `_route_`-prefixed and
      unset before return.
- [ ] Add `routing_resolve_observers "<topic>" "<task_type>"`, emitting one TAB-separated line
      per match on stdout: `manifest_path<TAB>extension_name<TAB>observer_name<TAB>script<TAB>matched_on<TAB>timeout_seconds`,
      where `matched_on` is one of `topic`, `task_type`, `both`. Empty stdout on a total miss;
      always `return 0`.
- [ ] Implement match-if-either with prefix awareness on BOTH keys, reusing the existing idiom
      verbatim (`printf '%s' "$v" | grep -q ":"` then `cut -d: -f1`): a declared `books` matches a
      value of `books:certify`; an exact match also counts. Compute `matched_on` as `both` only
      when both declared keys matched.
- [ ] Enumerate `"${ROUTE_MANIFEST_ROOT:-.claude}"/extensions/*/manifest.json` in glob order; do
      NOT skip the core manifest (unlike `routing_lookup`, core participates — core could
      legitimately declare an observer, and there is no precedence to establish when every match
      fires). Sort observer keys within a manifest for determinism (D7).
- [ ] Skip, without failing, any entry missing `script` or missing both of `topic`/`task_type` —
      structural validation is Rule X's job (Phase 5), not the resolver's; the resolver must
      never be the thing that halts.
- [ ] Emit `timeout_seconds` as the entry's own value when a positive integer, else the literal
      default `30`.
- [ ] This is a resolve-all function, NOT a third single-value ladder: use plain stdout, not the
      `_ROUTE_LAST_VALUE`/`_ROUTE_LAST_VIA` globals, so it is safe under command substitution and
      cannot be mistaken for a sibling of `routing_lookup`.
- [ ] Extend the FILE-HEADER comment block (not only the function's local comment) to list the
      new function alongside the two existing ladders, preserving the header's "single source of
      truth" framing, and stating explicitly that this function's return shape is
      resolve-all/one-line-per-match and must not be folded into `routing_lookup`.
- [ ] Add a `Usage:` line for the new function to the header's existing usage block.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: the file is measured at 257 lines with exactly two resolver functions plus
`routing_core_manifest` and `routing_trace`, and its sourcing dependents are measured as
`scripts/command-route-agent.sh`, `scripts/orchestrate-build-dispatch.sh`,
`scripts/lib/common.sh`, `scripts/lib/task-type-detect.sh`, `scripts/lint/lint-routing-wiring.sh`,
and four test suites (`test-routing-resolution.sh`, `test-orchestrate-build-dispatch.sh`,
`test-orchestrate-cycle-plan.sh`, `test-orchestrate-cycle-postflight.sh`). Confirm at
implementation time with `grep -rln "manifest-routing-lib" --include="*.sh" agent-system/` before
relying on that dependent list for this phase's verification.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh` - add
  `routing_resolve_observers`; extend file-header function inventory and usage block

**Verification**:
- `bash -n` on the library and on every enumerated sourcing dependent.
- `shellcheck` clean on the library per `context/standards/shell-strict-mode.md` (Class C — no
  `set` line is added).
- `bash agent-system/extensions/core/scripts/tests/test-routing-resolution.sh` passes unchanged
  (existing ladders untouched).
- Ad-hoc source-and-call smoke check against a scratch `ROUTE_MANIFEST_ROOT` fixture: a
  `topic: books` declaration returns a line for `books` and for `books:certify`, and nothing for
  `other`.

---

### Phase 2: `scripts/run-task-observers.sh` — the advisory, non-blocking invoker [NOT STARTED]

**Goal**: a standalone script that, given a task's identity and resting status, invokes every
matching observer under a bounded timeout and records exactly one event per attempt, and that
can never fail its caller.

**Tasks**:
- [ ] Create `scripts/run-task-observers.sh` with `set -uo pipefail` and a header comment
      documenting the advisory contract verbatim (never changes status, never fails a dispatch,
      never blocks; rc is recorded as an event and otherwise ignored; always exits 0) plus the
      ordering guarantee it depends on.
- [ ] Flag-parse `--task N --task-type T --topic P --task-dir D --session S --status ST`, plus
      `--dry-run`. Accept an empty `--topic` and an empty `--task-type` without erroring (either
      may legitimately be unset on a task row); a task with BOTH empty resolves to zero matches
      and the script exits 0 silently.
- [ ] Resolve `PROJECT_ROOT` via the established `deploy-root-guard.sh` / `lib/common.sh`
      convention used by sibling scripts, then set `ROUTE_MANIFEST_ROOT="${PROJECT_ROOT}/.claude"`
      when unset (D6) and source `lib/manifest-routing-lib.sh`.
- [ ] Call `routing_resolve_observers "$topic" "$task_type"` and iterate its TSV lines. Zero
      lines: exit 0 with no event and no output (a seam with no declarations must be silent).
- [ ] Per match: resolve `script` by BASENAME against `"${PROJECT_ROOT}/.claude/scripts/"` (D1).
      A missing or non-executable resolved path produces a `deviation` rc event and nothing else
      — never a failure, never a status change.
- [ ] Select the timeout binary per D3 (`timeout`, then `gtimeout`, else skip-with-event).
- [ ] Invoke the observer with the six positional arguments in this fixed order:
      `$1` task_number, `$2` task_type, `$3` topic, `$4` task_dir, `$5` session_id,
      `$6` resting_status. Redirect its stdout and stderr to a scratch capture so an observer can
      never corrupt the caller's own channels; measure wall-clock around the call.
- [ ] Emit exactly ONE event per attempted observer via `scripts/events-append.sh`:
      `--event-type task_observer_run`, `--category success` on rc 0 and `--category deviation`
      on any non-zero rc / crash / missing / non-executable / timeout / no-timeout-binary,
      `--task`, `--session`, `--duration`, a one-line `--message`, and a `--detail-json` payload
      carrying `observer`, `extension`, `script`, `matched_on`, `rc`, `timed_out` (boolean),
      `timeout_seconds`, and `skipped` when applicable. Keep the category enum closed — every
      distinguishing fact lives in the detail payload, never in a new category value.
- [ ] Treat a timeout as rc 124 (the `timeout` convention) and set `timed_out: true`; record the
      distinction in the detail payload rather than inventing an event type per failure mode.
- [ ] Make the event append itself non-fatal (`|| true` with a stderr note): a failure to record
      must never become a failure to run, and vice versa.
- [ ] `--dry-run`: print one `would invoke observer <name> (<script>) matched_on=<k>` line per
      match to stderr, append no event, invoke nothing, exit 0.
- [ ] Final statement is an unconditional `exit 0`. Add an explicit header note that returning a
      child rc here would flip the non-blocking contract for any caller running under `set -e` —
      the same reasoning `skill_run_extension_hook`'s own `return 0` already records.
- [ ] Register `"run-task-observers.sh"` in `manifest.json`'s `provides.scripts` array (sorted
      into position alongside the existing entries, e.g. near `"dispatch-metrics.sh"`), so the
      script actually deploys.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: `provides.scripts` is asserted to be the single registration point needed
for a flat `scripts/*.sh` file to deploy (measured: `dispatch-metrics.sh` at
`core/manifest.json:94`, with its test at `:213` as a separate entry). Confirm by grepping the
manifest for an existing flat script and its test before adding the two entries, and by checking
after Phase 7's deploy that `.claude/scripts/run-task-observers.sh` exists and is executable.

**Files to modify**:
- `agent-system/extensions/core/scripts/run-task-observers.sh` - new file: resolve, match,
  timeout-bounded invoke, rc event, always exit 0
- `agent-system/extensions/core/manifest.json` - add `scripts/run-task-observers.sh` to
  `provides.scripts`

**Verification**:
- `bash -n` and `shellcheck` clean on the new script (Class A/B justification recorded in its
  header per `shell-strict-mode.md`).
- `jq -e '.provides.scripts | index("run-task-observers.sh")' agent-system/extensions/core/manifest.json`
  returns a non-null index.
- Manual smoke run against a scratch `ROUTE_MANIFEST_ROOT`: an observer that `exit 0`s produces
  one `success` event; one that `exit 3`s produces one `deviation` event with `rc: 3`; both
  invocations return 0.

---

### Phase 3: `scripts/tests/test-run-task-observers.sh` — regression suite [NOT STARTED]

**Goal**: every clause of the matching and advisory contracts is asserted mechanically, in an
isolated scratch sandbox that never touches the live repo's `specs/` or `.claude/`.

**Tasks**:
- [ ] Create `scripts/tests/test-run-task-observers.sh` on the established harness model
      (`scripts/tests/test-dispatch-metrics.sh` / `test-issue-record.sh`): `set -uo pipefail`
      (Class B per `shell-strict-mode.md`), `pass()`/`fail()`/`info()` helpers, `PASSED`/`FAILED`
      integer counters, exit 0 all-pass / 1 any-fail / 2 environment error, and the
      deploy-tree-first / source-store-fallback script-under-test candidate list so the suite runs
      both post-deploy and in a source-store-only checkout.
- [ ] Build a scratch sandbox per case: `mktemp -d` root with `.claude/scripts/` (the SUT,
      `events-append.sh`, `deploy-root-guard.sh`, `lib/common.sh`, `lib/manifest-routing-lib.sh`
      copied in so the `*/.claude` parent check passes and `PROJECT_ROOT` resolves to the
      scratch root), `.claude/extensions/<name>/manifest.json` fixtures, and a scratch `specs/`.
- [ ] Case: **prefix match** — a `topic: books` declaration fires for topic `books:certify`.
- [ ] Case: **topic-only match** — a declaration with `topic` and no `task_type` fires on topic,
      and does not fire for a task whose topic differs but whose task_type coincidentally equals
      the topic string.
- [ ] Case: **task_type-only match** — a declaration with `task_type` and no `topic` fires on
      task_type, prefix-aware (`present` matches `present:grant`).
- [ ] Case: **both-declared match-if-either** — a declaration with both keys fires when only the
      topic matches, fires when only the task_type matches, and reports `matched_on: both` when
      both match.
- [ ] Case: **no match** — a declaration on `Y` does not fire for topic `X`; no event is
      appended; exit 0.
- [ ] Case: **multiple matching extensions** — two fixture extensions both matching one task BOTH
      fire (the regression guard against inheriting first-match-wins), in the documented
      deterministic order (D7).
- [ ] Case: **missing script** — a declaration whose `script` resolves to no deployed file yields
      exactly one `deviation` event and exit 0.
- [ ] Case: **non-executable script** — same shape, distinguished in the detail payload.
- [ ] Case: **non-zero rc** — an observer exiting 3 yields one `deviation` event carrying
      `rc: 3`, and the SUT still exits 0.
- [ ] Case: **timeout** — an observer that sleeps past a 1-second `timeout_seconds` is killed,
      the event carries `timed_out: true`, the SUT exits 0, and total wall-clock stays bounded.
- [ ] Case: **no timeout binary** — with `timeout`/`gtimeout` removed from `PATH`, the observer is
      SKIPPED (not invoked un-bounded: assert the observer's own side-effect file was never
      written) and one `deviation` event carrying the skip reason is appended.
- [ ] Case: **a failing observer does not change status** — a fixture observer that writes garbage
      to its own `specs/state.json` argument path is not given the chance to matter: assert the
      scratch `specs/state.json` byte-identical before and after a crashing-observer run, and that
      the SUT's exit status is 0.
- [ ] Case: **malformed declaration tolerance** — an entry missing `script`, and an entry with
      neither `topic` nor `task_type`, are skipped without failing the run (structural validation
      belongs to Rule X, not the resolver).
- [ ] Case: **`--dry-run`** — matches are reported on stderr, no event is appended, the observer's
      side-effect file is absent.
- [ ] Register `"tests/test-run-task-observers.sh"` in `manifest.json`'s `provides.scripts` as its
      own entry (the two-entry registration pattern `dispatch-metrics.sh` already follows).

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: 14 cases are enumerated above, covering the dispatch's nine named test
requirements plus five derived ones (multiple-match, non-executable, no-timeout-binary,
malformed-declaration, dry-run). The count is a hypothesis: confirm at implementation time that
each of the dispatch's nine named requirements (prefix match, topic-only, task_type-only,
both-declared, no match, missing script, non-zero rc, timeout, failing-observer-does-not-change-status)
maps to at least one implemented case before declaring the phase complete, and adjust the count
rather than the coverage.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-run-task-observers.sh` - new regression suite
- `agent-system/extensions/core/manifest.json` - add `tests/test-run-task-observers.sh` to
  `provides.scripts`

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-run-task-observers.sh` exits 0 with every
  case PASS.
- `shellcheck` clean; the suite's Class B `set -uo pipefail` posture justified in its header.
- The suite leaves no residue: assert `mktemp -d` roots are cleaned by its `trap`, and that the
  live repo's `specs/events.jsonl` is unchanged by a full run.

---

### Phase 4: Postflight invocation site, correctly ordered [NOT STARTED]

**Goal**: exactly one `run-task-observers.sh` call in `orchestrate-cycle-postflight.sh`'s
completion path, provably after this dispatch's issue-log and metrics writes, with the ordering
guarantee asserted mechanically rather than asserted in prose only.

**Tasks**:
- [ ] RE-MEASURE FIRST. Do not trust any line number in this plan, in the research report, or in
      the dispatch description. Locate the insertion point by comment marker:
      `grep -n '# ─── WORK (' scripts/orchestrate-cycle-postflight.sh` and
      `grep -n '# ─── persisted_status:' scripts/orchestrate-cycle-postflight.sh`. Confirm that
      WORK (m)'s `dispatch-metrics.sh` call and every `issue-record.sh` call site precede the
      `persisted_status` assignment; if they do not, STOP and record an issue rather than guessing
      a slot.
- [ ] Add a fresh `topic` read from `$STATE_FILE`, in the style of the adjacent `persisted_status`
      read: a plain `jq -r --argjson num "$task_number" '.active_projects[] | select(.project_number == $num) | .topic // ""'`
      with a `2>/dev/null` and an empty-string fallback, never a mutation, so it is correct under
      `--dry-run` too. `topic` is currently read NOWHERE in this script — this is a new read, not
      a reuse.
- [ ] Insert the invocation as a new WORK-lettered section immediately AFTER the
      `persisted_status` assignment and BEFORE the `# ─── Final output ───` block (D4). Take the
      next free WORK letter by re-reading the file header's own WORK inventory; do not assume a
      letter from this plan.
- [ ] Gate on `is_live` ONLY, with the standard `[dry-run] would ...` notice on the else branch
      (D5). Call non-fatally in the measured house style:
      `bash "${SCRIPT_DIR}/run-task-observers.sh" ... >/dev/null 2>&1 || echo "Note: task-observer invocation failed (non-fatal)" >&2`.
- [ ] Pass the six arguments: `--task "$task_number" --task-type "$task_type" --topic "$topic"
      --task-dir "$TASK_DIR" --session "$session_id" --status "$persisted_status"`. `$task_type`
      is the already-parsed `--task-type` flag value (measured at line 244; re-confirm) — no new
      plumbing needed for that field.
- [ ] Add a paragraph to the script's own file-header WORK-letter inventory for the new section,
      matching this script's established self-documentation convention, and stating in-line: the
      ordering guarantee and WHY it matters (an observer that ran before the issue-log and metrics
      writes would see an incomplete record and the seam would be worthless), the `is_live`-only
      gating rationale, and the non-blocking contract.
- [ ] Add `run-task-observers.sh` to `scripts/tests/test-orchestrate-cycle-postflight.sh`'s
      `require_file` list and its `setup_sandbox` copy loop, so the suite exercises the real call
      rather than silently hitting the non-fatal missing-script branch.
- [ ] Add an **ordering assertion** case to `scripts/tests/test-run-task-observers.sh`: parse
      `orchestrate-cycle-postflight.sh` and assert the line number of the
      `run-task-observers.sh` invocation is GREATER than the line numbers of both the
      `dispatch-metrics.sh` invocation and every `issue-record.sh` invocation, and greater than
      the `persisted_status=` assignment. This is the mechanical guard that makes the ordering
      guarantee a test rather than a comment.
- [ ] Add an **end-to-end acceptance** case to `scripts/tests/test-orchestrate-cycle-postflight.sh`:
      a synthetic `$WORKDIR/.claude/extensions/testobs/manifest.json` declaring an observer on
      topic `X`, whose script records into a probe file whether `metrics.jsonl` and `issues.jsonl`
      already exist in the task directory it was handed. Assert the observer fired for a task with
      topic `X`, fired for topic `X:sub`, did NOT fire for topic `Y`, and that both per-dispatch
      records were already present when it ran. Assert a second fixture observer that `exit 1`s
      leaves the task's persisted status and the SUT's own JSON verdict unchanged.

**Timing**: 1.5 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Scope Hypothesis**: measured live at plan time — the script is 1762 lines, the issue-log call
sites sit inside the `dispatch_status` case arm at 931-1256, WORK (m)'s metrics call at
1491-1543, WORK (i)'s commit at 1545, and `persisted_status` at ~1697-1711. Three tasks in a row
have edited this file and a dependent task follows, so every one of those numbers is a hypothesis
with a known decay rate. Confirm by comment-marker grep (first task above) before any edit; the
numbers here exist only to make a mismatch visible, never to be edited against.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - new `topic` read; new
  WORK-lettered observer invocation after `persisted_status`; file-header WORK inventory paragraph
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - sandbox
  collaborator registration; end-to-end acceptance case
- `agent-system/extensions/core/scripts/tests/test-run-task-observers.sh` - ordering assertion case

**Verification**:
- `bash -n` and `shellcheck` clean on the postflight script.
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` exits 0,
  including the new end-to-end case and with no pre-existing case regressed.
- `bash agent-system/extensions/core/scripts/tests/test-run-task-observers.sh` exits 0, including
  the ordering assertion.
- Full gate set: `bash .claude/scripts/verify-deploy.sh` (source-store path:
  `agent-system/extensions/core/scripts/verify-deploy.sh`) — run after Phase 7's deploy, since the
  gate reads the deployed tree.

---

### Phase 5: `check-extension-docs.sh` Rule X — structural + documentation checks [NOT STARTED]

**Goal**: a declared observer that is malformed, undeployable, or undocumented is caught
mechanically.

**Tasks**:
- [ ] Re-read `scripts/check-extension-docs.sh`'s header rule index (measured 52-77, A-W) and
      confirm `X` is the next free letter before claiming it.
- [ ] Add `check_observers_resolve()`, modeled line-for-line on `check_lifecycle_hooks_resolve()`
      (measured 610-640) including its ADVISORY-vs-`fail()` split: return 0 immediately when the
      manifest has no `observers` key; then per entry —
      `fail()` when `script` is absent; `fail()` when neither `topic` nor `task_type` is present;
      `fail()` on any key outside the allowlist `{script, topic, task_type, timeout_seconds}`;
      `fail()` when the `script` basename is not declared in `provides.scripts` (it will never
      deploy, regardless of regeneration); `advisory()` when the resolved
      `.claude/scripts/<basename>` is not yet deployed or is deployed but not executable (a
      source-store edit legitimately precedes a deploy, so hard-failing would brick the gate for
      every caller).
- [ ] Add `check_observers_documented()`, modeled on `check_readme_vs_manifest()`'s commands
      sub-check (measured 1049-1059): for each key under `observers`, `fail()` unless that key
      name OR its `script` basename appears in the declaring extension's own `README.md`. This is
      the mechanism that makes "a declared observer with no documentation is caught" literally
      true at the per-extension level, independent of and additional to the one-time generic
      schema documentation Phase 6 owes.
- [ ] Wire both calls into the per-extension dispatch loop alongside
      `check_lifecycle_hooks_resolve "$ext_path"` (measured ~1502).
- [ ] Add the Rule X entry to the file's own header rule-letter index, in first-introduced order,
      naming both functions and what each catches.
- [ ] Verify no live extension currently declares `observers`
      (`jq -e 'has("observers")' agent-system/extensions/*/manifest.json`), so the new rule
      cannot hard-fail an existing extension on first run.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: `X` is asserted to be the next free Rule letter, and the two modeling
targets are asserted at `check_lifecycle_hooks_resolve` (610-640) and
`check_readme_vs_manifest` (1034-1060). Confirm both by grep against the live file before
editing; if a concurrent task has already claimed `X`, take the next free letter rather than
colliding.

**Files to modify**:
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - add
  `check_observers_resolve` and `check_observers_documented`; wire both into the per-extension
  loop; add the Rule X header index entry

**Verification**:
- `bash -n` and `shellcheck` clean.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh --quiet` exits 0 against the
  live source store (no extension declares `observers`, so the new rule is a no-op today).
- Scratch-fixture drive of each branch: a well-formed-but-undocumented observer `fail()`s; one
  missing `script` `fail()`s; one declaring neither key `fail()`s; one with a stray key `fail()`s;
  one whose basename is absent from `provides.scripts` `fail()`s; one declared, documented and
  in `provides.scripts` but not yet deployed produces an `advisory()` and exit 0.

---

### Phase 6: Documentation — observers schema and `topic` as a binding key [NOT STARTED]

**Goal**: the `observers` block, the ordering guarantee, the advisory contract, the WHY TOPIC
measurement, and the WHY NOT LIFECYCLE HOOKS reasoning are written where the next person looks;
and `topic`'s schema row stops implying it is presentational only.

**Tasks**:
- [ ] Add a `## Post-Task Observers` section to `docs/guides/creating-extensions.md`, placed
      immediately after the existing `## Lifecycle Hooks` section (measured 655-833) and before
      `## Troubleshooting`, modeled on that section's own sub-section skeleton:
      `### Observers vs. Lifecycle Hooks`, `### Observer Schema`, `### Observer Execution
      Contract`, `### Invocation Site and Ordering`, `### Example: A Topic-Keyed Observer`,
      `### Adding an Observer to Your Extension`.
- [ ] **Schema** (D1): the worked `observers` JSON block; `script` required; at least one of
      `topic`/`task_type` required; both means match-if-either; `timeout_seconds` optional
      (default 30); the basename-against-`.claude/scripts/` resolution rule and the consequent
      `provides.scripts` requirement, cross-referencing the identical trap already documented in
      the Hook Schema section.
- [ ] **Matching contract**: prefix-aware on BOTH keys — a declared `books` matches a value of
      `books:certify`, matching on the segment before the first `:`, because compound task-type
      values with a `:` sub-route (e.g. `present:grant`) are an established convention here.
      Every match fires; this is not a first-match-wins resolver. Document the deterministic
      multi-match order (D7).
- [ ] **Execution contract**: the six positional arguments in order; a bounded timeout; the rc is
      recorded as a `task_observer_run` event in `specs/events.jsonl` (`success` on 0,
      `deviation` otherwise) and otherwise IGNORED; an observer can never change task status,
      never fail a dispatch, never block; a missing, non-executable, crashing, or hanging observer
      produces a warning event and nothing else.
- [ ] **Ordering guarantee** (state it explicitly, it is part of the contract): the observer runs
      AFTER the per-dispatch issue-log and metrics records for that dispatch have been written, so
      an observer can READ them. Name the invocation site (the completion path of
      `scripts/orchestrate-cycle-postflight.sh`, after its `persisted_status` computation) and say
      why: an observer that ran before those writes would see an incomplete record and the whole
      seam would be worthless.
- [ ] **WHY TOPIC** (the measurement, written down where the next person looks): in the consuming
      repository's corpus, the 17 tasks carrying topic `books` have task_type `lean4` (14),
      `general` (2) and `typst` (1) — NOT ONE has task_type `books`, and the books extension is
      not even loaded there. An observer keyed on `task_type` alone would have matched NONE of the
      tasks whose work it exists to observe. That is the whole argument for `topic` as a match key.
      Phrase the novelty claim precisely: this is the first place `active_projects[].topic` becomes
      a **dispatch-matching** key (`scripts/memory-retrieve.sh` already reads a different,
      same-named field — a memory-index entry's own topic taxonomy value used as a
      retrieval-scoring bonus — which this wording must not accidentally contradict).
- [ ] **WHY NOT LIFECYCLE HOOKS** (D2, so it is not re-litigated): both measured reasons, with
      their anchors — resolution by manifest `task_type` string EQUALITY in
      `scripts/skill-base.sh`'s `skill_get_extension_dir()` (equality, not prefix; task_type, not
      topic), and the postflight hook receiving an EMPTY task type under `/orchestrate` because
      `skill_postflight_update` passes `"${TASK_TYPE:-}"` while
      `orchestrate-cycle-postflight.sh` sets no `TASK_TYPE` at all. Add the explicit warning: do
      not "fix" this by plumbing `TASK_TYPE` through the postflight hook as a substitute — that
      would still be equality-on-`task_type` and would still match none of the measured corpus.
      Note that the already-landed lifecycle-hook repair fixed the resolver, the return-code
      channel and the verification stage, and did not and could not supply a task type that is
      never set on that path.
- [ ] **Documentation requirement**: state that each declared observer must be mentioned in the
      declaring extension's own `README.md`, and that `scripts/check-extension-docs.sh`'s Rule X
      enforces this.
- [ ] Rewrite the `topic` row in `context/reference/state-management-schema.md`'s Project Entry
      Fields table (measured line 124) so it no longer implies presentational-only use: keep the
      aggregation fact, and add that `topic` is a BINDING, dispatch-matching key — matched
      prefix-aware by the manifest `observers` block to select post-task observer scripts under
      `/orchestrate` — with a pointer to the guide section. Do NOT change line 69's
      `active_topics` row; its wording describes aggregation only and is accurate as-is.
- [ ] Verify the `## Post-Task Observers` heading does not collide with an existing heading, and
      that the guide's own internal cross-references still resolve.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: the two edit targets are asserted as
`docs/guides/creating-extensions.md`'s `## Lifecycle Hooks` section (measured 655-833, with
`## Troubleshooting` at 833) and `context/reference/state-management-schema.md` line 124 as the
ONLY Project Entry Fields `topic` row (two `topic` occurrences measured: lines 69 and 124).
Confirm both by `grep -n "topic" context/reference/state-management-schema.md` and
`grep -n "^## " docs/guides/creating-extensions.md` before editing.

**Files to modify**:
- `agent-system/extensions/core/docs/guides/creating-extensions.md` - new `## Post-Task
  Observers` section after `## Lifecycle Hooks`
- `agent-system/extensions/core/context/reference/state-management-schema.md` - rewrite the
  Project Entry Fields `topic` row (line 69's `active_topics` row unchanged)

**Verification**:
- Diff read-through confirming every changed hunk is prose/markdown with zero compile surface.
- `grep -c "observers" agent-system/extensions/core/docs/guides/creating-extensions.md` is
  non-zero and the new section's heading hierarchy (`##` + six `###`) renders correctly.
- The `topic` row no longer contains only the aggregation clause:
  `grep -n "topic" agent-system/extensions/core/context/reference/state-management-schema.md`
  shows the binding-key language on the Project Entry Fields row.
- No task-number reference introduced:
  `bash .claude/scripts/check-task-references.sh` (or the repo-wide lint equivalent) clean.

---

### Phase 7: Deploy, shellcheck sweep, end-to-end acceptance [NOT STARTED]

**Goal**: the seam is deployed, every gate is green, and each clause of the dispatch's ACCEPTANCE
line is demonstrated rather than asserted.

**Tasks**:
- [ ] Deploy the source store (`bash .claude/scripts/deploy-headless.sh`, or the operator's
      `Reload All`) and confirm `.claude/scripts/run-task-observers.sh` and
      `.claude/scripts/tests/test-run-task-observers.sh` exist and are executable.
- [ ] `shellcheck` sweep over every script this task touched, per
      `context/standards/shell-strict-mode.md`, with each file's strict-mode class justified in
      its own header (Class A for `run-task-observers.sh` unless its own control flow justifies
      B; Class B for the test suite; Class C unchanged for `manifest-routing-lib.sh`).
- [ ] Run the full test battery: `bash .claude/scripts/tests/run-all.sh` (which auto-discovers
      `tests/test-*.sh` by glob — confirm the new suite is picked up), with particular attention
      to `test-run-task-observers.sh`, `test-orchestrate-cycle-postflight.sh`, and
      `test-routing-resolution.sh`.
- [ ] `bash .claude/scripts/check-extension-docs.sh` exits 0 (and with `STRICT_CORE_DEPLOY=1`).
- [ ] Full gate set: `bash .claude/scripts/verify-deploy.sh` clean.
- [ ] Walk the ACCEPTANCE line clause by clause and record which test proves each:
      (i) a test extension declaring an observer on topic `X` is invoked for topic `X` and for
      `X:sub`, and not for `Y`; (ii) the observer sees a task directory in which this dispatch's
      issue-log and metrics lines are already present; (iii) a crashing observer leaves the task's
      status and the orchestration unaffected and produces an rc event; (iv)
      `check-extension-docs.sh` flags an undocumented observer; (v) shellcheck clean.
      Any clause with no test behind it is a gap to close here, not a clause to narrate.
- [ ] Confirm the seam is inert in production: no live extension declares `observers`, so a real
      `/orchestrate` postflight resolves zero matches, appends no event, and prints nothing.
      Verify by running the deployed `run-task-observers.sh` once against a real task's identity
      and asserting silent exit 0 with `specs/events.jsonl` unchanged.

**Timing**: 1 hour

**Depends on**: 3, 4, 5, 6

**Verification Tier**: full

**Scope Hypothesis**: this phase asserts that five ACCEPTANCE clauses each map to at least one
implemented test. Confirm the mapping explicitly (clause -> suite -> case name) at
implementation time; a clause with no named case behind it means the phase is not done.

**Files to modify**:
- `agent-system/extensions/core/scripts/run-task-observers.sh` - shellcheck/strict-mode fixes
  only, if the sweep finds any
- `agent-system/extensions/core/scripts/tests/test-run-task-observers.sh` - gap-closing cases
  only, if the ACCEPTANCE walk finds an unproven clause

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0.
- `bash .claude/scripts/tests/run-all.sh` exits 0 with the new suite discovered and passing.
- `bash .claude/scripts/check-extension-docs.sh` exits 0, and with `STRICT_CORE_DEPLOY=1`.
- A table in the implementation summary mapping each ACCEPTANCE clause to the test case proving it.

---

## Testing & Validation

- [ ] `test-run-task-observers.sh`: all cases PASS (prefix, topic-only, task_type-only,
      both-declared, no match, multiple matching extensions, missing script, non-executable
      script, non-zero rc, timeout, no-timeout-binary, failing-observer-does-not-change-status,
      malformed declaration, dry-run, postflight ordering assertion).
- [ ] `test-orchestrate-cycle-postflight.sh`: all pre-existing cases unregressed, plus the new
      end-to-end acceptance case (observer fires for `X` and `X:sub`, not for `Y`; sees
      `metrics.jsonl` and `issues.jsonl` already written; a crashing observer changes nothing).
- [ ] `test-routing-resolution.sh`: unchanged and passing (the two existing ladders untouched).
- [ ] `check-extension-docs.sh`: exits 0 on the live source store; each Rule X branch driven by a
      scratch fixture.
- [ ] `run-all.sh`: the new suite is auto-discovered and green.
- [ ] `verify-deploy.sh`: clean.
- [ ] `shellcheck`: clean on every touched script, per `shell-strict-mode.md`.
- [ ] `check-task-references.sh`: no task-number reference introduced into any source-store file.
- [ ] Inertness: the deployed `run-task-observers.sh` exits 0 silently with no declared observers
      and leaves `specs/events.jsonl` unchanged.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh` — `routing_resolve_observers`
  plus extended file-header inventory
- `agent-system/extensions/core/scripts/run-task-observers.sh` — new invoker
- `agent-system/extensions/core/scripts/tests/test-run-task-observers.sh` — new regression suite
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — new `topic` read and
  WORK-lettered observer invocation
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — sandbox
  collaborator registration and end-to-end acceptance case
- `agent-system/extensions/core/scripts/check-extension-docs.sh` — Rule X (two checks)
- `agent-system/extensions/core/docs/guides/creating-extensions.md` — `## Post-Task Observers`
- `agent-system/extensions/core/context/reference/state-management-schema.md` — `topic` as a
  binding key
- `agent-system/extensions/core/manifest.json` — two `provides.scripts` entries
- `specs/331_topic_keyed_post_task_observer_seam/summaries/01_*-summary.md` — implementation
  summary including the ACCEPTANCE-clause-to-test mapping table

## Rollback/Contingency

Every phase is an additive, independently revertible change; nothing existing changes behavior
until Phase 4's single call site lands, and that call site is non-fatal in both directions.

- **Before Phase 4** (the only phase that edits live orchestration control flow), take a durable
  non-reverting checkpoint: `bash .claude/scripts/git-snapshot.sh --no-revert 331`. This is a
  checkpoint, not a rollback.
- **Fastest kill switch**: delete the single `run-task-observers.sh` invocation block from
  `orchestrate-cycle-postflight.sh`. Nothing else in the system calls the script, so the seam goes
  inert with one hunk reverted and no other phase needs undoing.
- **Second kill switch, no code change**: since the seam resolves zero matches when no extension
  declares `observers`, removing an offending `observers` block from a manifest and redeploying
  disables that observer without touching core.
- **Genuine rollback** (reverting uncommitted work): follow `context/contracts/recovery.md`'s
  rollback rung for the exact `git-snapshot.sh` invocation shape, including its out-of-scope
  override flag for the deliberate whole-tree case, then run the destructive command.
- **Doc-only phases** (5, 6) revert independently of the code phases and carry no runtime risk.
