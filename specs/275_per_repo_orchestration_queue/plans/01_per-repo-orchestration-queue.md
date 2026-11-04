# Implementation Plan: Task #275

- **Task**: 275 - Per-repo orchestration queue: registered, live, archived on finish, and consumed by admission
- **Status**: [NOT STARTED]
- **Effort**: 7.5 hours
- **Dependencies**: 170, 272 (both substantive; 272's heartbeat repair is already landed in the
  source store — `cmd_session_heartbeat`'s "Piece 3" `derive_union_file_scope` re-derivation is
  present, and no task numbered 272 remains in `specs/state.json`)
- **Research Inputs**: `specs/275_per_repo_orchestration_queue/reports/01_per-repo-orchestration-queue.md`
- **Artifacts**: plans/01_per-repo-orchestration-queue.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  shell-strict-mode.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a per-repo orchestration queue — a live registry of in-flight orchestrations plus a durable
archive of finished ones — as an additive subcommand family on `scripts/task-lock.sh`, beside the
existing session registry rather than replacing it. The queue gets its own primary key
(`orchestration_id`) so a record can outlive the session whose liveness governs it, its live
entries' liveness is computed by the existing `session_liveness()` function (never a second
transcription), and a new blocking `queue-check` subcommand refuses a conflicting `/orchestrate`
invocation outright at invocation time with the conflicting orchestration named. Done means: the
four lifecycle states (`registered -> running -> finished -> archived`) are implemented and
documented to the rigor of `context/patterns/task-lock.md`'s Session-Registry CLI section,
finished orchestrations are moved into an archive rather than `rm -f`'d, the queue is wired as an
admission input, and one fixture suite covers the whole lifecycle plus the refusal path.

### Research Integration

The report settled five things this plan builds directly on: (1) no orchestration-level record
exists today and `cmd_session_release` is a bare `rm -f`, so the archive half is genuinely new
construction; (2) the three lifecycle transition points already exist as live call sites
(`skill-orchestrate/SKILL.md` Setup register, `orchestrate-cycle-plan.sh`'s
`session-heartbeat` call, `skill-orchestrate/SKILL.md` Move 4 release) and need no new hook; (3)
the archive belongs under `specs/.orchestration/`, the already-established per-repo
orchestration-runtime directory, not a newly invented dotdir; (4) `session_liveness()` must be
consumed, and its verdict shape (`live` = NOT IN {`dead-pid`, `stale-heartbeat`}) is already
exactly what `session_contention()` expects; (5) alternatives-on-conflict is explicitly a
downstream task's scope, so this refusal only has to *name* the conflict.

Two findings from this planning pass extend the report:

- `session_contention()` (`scripts/lib/file-scope-overlap.sh`) can be **reused verbatim**, with
  the queue's enriched listing substituted for `session-list`'s NDJSON, because it reads only
  `.session_id`, `.task_numbers`, `.file_scope`, `.live`, and `.liveness_reason` — all of which
  the queue entry schema below carries under identical key names. No edit to
  `lib/file-scope-overlap.sh` (a shared predicate with several consumers) is required.
- `scripts/lib/runtime-file-patterns.sh` already carries a directory-class member
  `orchestration` with pattern `**/.orchestration/`, which covers arbitrary subdirectories.
  `specs/.orchestration/queue/` and `specs/.orchestration/archive/` therefore need **no new
  pattern member and no `.gitignore` change**, and `reap-session-runtime-files.sh`'s sweep is a
  set of literal, non-recursive filename globs (`.orchestrator-multi-state-*.json`,
  `.return-meta-multi-*.json`) that cannot reach either subdirectory. Both facts must be
  re-verified at implementation time (see Phase 5) rather than trusted from this plan.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch context; no roadmap consultation was performed.

## Goals & Non-Goals

**Goals**:
- A per-orchestration identity (`orchestration_id`) distinct from `session_id`, serving as the
  queue record's primary key so the record can outlive the session.
- A documented record schema and the four lifecycle states
  `registered -> running -> finished -> archived`.
- Live-record currency driven off the same call site as `session-heartbeat`, with no second,
  independently-timed heartbeat mechanism.
- Archive-on-finish by moving the record, never `rm -f`, sited under `specs/.orchestration/`.
- Queue-entry liveness computed by calling `session_liveness()`, never by re-deriving it.
- A blocking `queue-check` that refuses a conflicting whole `/orchestrate` invocation at
  invocation time, naming the conflicting `orchestration_id`, the colliding task number, and the
  overlapping path.
- One fixture suite covering `registered -> running -> finished -> archived` plus the refusal
  path, shellcheck-clean per `context/standards/shell-strict-mode.md`.

**Non-Goals**:
- Any scheduler, waiting queue, auto-start, wake-up, or unattended execution. "Queue" means the
  registry and its archive; nothing drains it.
- Suggesting alternative batches on refusal (a downstream task's scope — this refusal only names
  the conflict).
- A cross-repo or global queue (the per-repo scope ruling is not re-opened here; see the
  Cross-Repo Counterexample note below).
- Changing `cmd_session_release`'s own `rm -f` behavior for the session registry, or any change
  to `orchestrate-batch-admit.sh`'s per-candidate verdict schema.
- Archive pruning or rotation. The archive grows without bound by design in this round; a
  retention policy is left unbuilt and recorded as such in the documentation.
- A blocking queue gate inside `command-gate-in.sh` for the single-task commands (see Decisions).

### Decisions

These were open at plan time and are settled here so implementation does not re-litigate them.

- **D1 — `orchestration_id` is minted by `queue-register`; later subcommands resolve by
  `session_id`.** `common_session_id()` already mints a fresh, effectively collision-free id per
  invocation, so the gap the dispatch names is **grain and durability**, not collision: a session
  entry is deleted on release and cannot carry history. `queue-register` mints
  `orch_{epoch}_{6hex}` via a new `common_orchestration_id()` in `scripts/lib/common.sh` (same
  shape and implementation style as `common_session_id()`), uses it as the record filename, and
  prints it on stdout. `queue-heartbeat` / `queue-finish` take the `session_id` and resolve the
  single live entry carrying it — so no new variable has to be threaded through
  `skill-orchestrate`'s loop prose or the multi-state file. Rejected: threading
  `orchestration_id` through every dispatch context (large wiring surface, no behavior gained,
  since one session is one orchestration today).
- **D2 — Liveness is `session_liveness()` applied to the queue entry file itself.** The queue
  entry carries `pid`, `pid_source`, and `heartbeat_at` under the *identical* key names the
  session registry uses, precisely so the shared function applies unchanged with zero new logic.
  The session-registry entry is deliberately *not* consulted: it is `rm -f`'d on release, so a
  record that must outlive the session cannot depend on it being present. Rejected: a two-path
  "registry entry first, queue entry as fallback" scheme (two code paths, two test matrices, no
  additional truth).
- **D3 — Archive = move the record file into `specs/.orchestration/archive/`; no second
  ledger.** `skill-todo`'s precedent is move-plus-ledger because task directories are large; a
  queue record is one small JSON object, and a dedicated-directory glob (the same bounded
  enumeration `session-list` uses) reads the archive directly. Rejected: an append-only
  `archive/index.ndjson` ledger alongside the moved files (two stores of the same facts, free to
  diverge).
- **D4 — The archive is local, untracked provenance.** `**/.orchestration/` is already an
  ephemeral-class gitignore pattern, so archived records stay out of git. This is accepted, not
  overlooked: committing one JSON file per orchestration into `specs/` would add per-invocation
  commit noise and cross-session merge conflicts for history no consumer reads yet. Recorded in
  the documentation as a known limitation. Rejected: a tracked ledger under `specs/`.
- **D5 — Contract documentation goes in `context/patterns/task-lock.md` as a new peer section,
  not a new document.** The queue ships as subcommands on `task-lock.sh`, whose entire contract
  already lives in that one file; a peer document would split one script's contract across two
  files. Rejected: `context/patterns/orchestration-queue.md`.
- **D6 — `queue-check` consults queue entries only, and is wired at exactly one call site
  (`commands/orchestrate.md`'s pre-dispatch point).** Single-task sessions are already covered at
  per-task `acquire` time by `cmd_acquire`'s blocking cross-task overlap pass; folding
  `session-list` into `queue-check` would duplicate that ladder rung at a second grain.
  `command-gate-in.sh` is therefore **not** modified by this plan, a deliberate narrowing of the
  task's anticipated `file_scope`. Rejected: a union over queue entries and session-registry
  entries; rejected: a blocking gate inside `command-gate-in.sh`.
- **D7 — `--allow-scope-collision` is the refusal's override.** That flag is already the
  documented, this-invocation-only, human-intent bypass of the cross-batch `file_scope_collision`
  gate; the queue refusal honors it rather than introducing a second override vocabulary.

### Cross-Repo Counterexample — Not Re-Opened Here

The task record carries a measured cross-repo counterexample to the per-repo scope premise, with
an escalation pending under a separate record that owns running it to an owner decision. This
plan implements the per-repo ruling as written and adds no cross-repo mechanism. If the ruling is
amended, the amendment belongs in the task record as a dated note and this plan is revised; no
phase below anticipates it.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A second, independently-timed currency mechanism drifts from the session heartbeat | H | M | `queue-heartbeat` is inserted at the *same* call site as `session-heartbeat` in `orchestrate-cycle-plan.sh` (Phase 4), never on a timer of its own |
| A new blocking gate at invocation time refuses legitimate runs and strands the operator | H | M | Refusal excludes non-live entries via `session_liveness()`, applies the dependency-edge exclusion, and honors `--allow-scope-collision` (D7); the refusal message names the conflict and the override |
| Liveness is accidentally re-derived rather than consumed, contradicting the acceptance bar | M | M | A single call to `session_liveness()` per entry (D2), asserted by a dedicated test case that fixtures a dead pid and a stale heartbeat and checks the reported `liveness_reason` strings verbatim |
| Editing `lib/common.sh` (sourced repo-wide) collides with an existing symbol | M | L | Additive function with a `common_`-prefixed name; Phase 1 greps the whole source store for the name before adding it and runs `test-common-lib.sh` |
| An archive under an ephemeral-class gitignored directory is silently reaped or reported untracked | M | L | Phase 5 re-verifies `reap-session-runtime-files.sh`'s globs cannot reach the subdirectory and that gate 14 (`check-runtime-file-tracking.sh`) still passes; Class Table rows classify the archive explicitly |
| Touching `orchestrator-runtime-files.md` breaks a doc-sync pin | M | L | The pinned "Consumer Repo Setup" gitignore block is mechanically derived and must not be edited; Phase 5 runs `test-runtime-file-tracking.sh` |
| Unbounded archive growth | L | M | Accepted and documented as a known limitation (D4, Non-Goals); no pruning implemented |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |

Phases within the same wave can execute in parallel. This plan is fully sequential: every phase
edits `scripts/task-lock.sh` or depends on the complete subcommand surface the prior phase added.

---

### Phase 1: Record schema, identity, and the live half (`queue-register` / `queue-heartbeat` / `queue-list`) [NOT STARTED]

**Goal**: A queue record exists at `specs/.orchestration/queue/{orchestration_id}.json`, is
created in state `registered`, advances to `running` and refreshes its own `heartbeat_at` on
heartbeat, and is enumerable with `live`/`liveness_reason` computed by `session_liveness()`.

**Tasks**:
- [ ] Grep the whole source store for `common_orchestration_id` and `orch_` to confirm neither
      name is already taken; add `common_orchestration_id()` to `scripts/lib/common.sh`
      immediately after `common_session_id()`, emitting `orch_<unix_epoch>_<6hex>` by the same
      implementation (`od -An -N3 -tx1 /dev/urandom`), with a header comment cross-referencing
      `common_session_id()` as its model.
- [ ] Add `orchestration_queue_dir()` and `orchestration_archive_dir()` to `scripts/task-lock.sh`
      modeled byte-for-byte on `session_registry_dir()`, including its `create` parameter
      convention (directory creation confined to the register path; every other caller resolves
      read-only).
- [ ] Add `write_queue_entry()` modeled on `write_session_entry()` (same `jq -n` into
      `<file>.tmp`, empty-output guard, `mv`), writing the schema below.
- [ ] Add `cmd_queue_register <orchestration_id|--mint> <session_id> <command> <task_numbers_csv>
      [--pid N]` — actual argument shape to be fixed at implementation time, but it MUST mint via
      `common_orchestration_id()` when no id is supplied and print the id on stdout. Reuse
      `derive_union_file_scope()`, `resolve_session_pid()`, and `iso_now()` unchanged; preserve
      `started_at` across re-registration exactly as `cmd_session_register` does; set
      `state: "registered"`.
- [ ] Add `cmd_queue_heartbeat <session_id>`: resolve the one live entry carrying that
      `session_id`, re-derive `file_scope` via `derive_union_file_scope()` (matching the session
      registry's re-derivation rather than echoing a stale snapshot), set `state: "running"`,
      refresh `heartbeat_at`. A missing entry is a stderr WARN and exit 0 — never a block on the
      caller, mirroring `cmd_session_heartbeat`.
- [ ] Add `cmd_queue_list [--archived]`: bounded dedicated-directory glob over
      `queue/*.json` (or `archive/*.json`), one compact NDJSON line per entry, every raw field
      verbatim plus `age_min`, `live`, `liveness_reason` from a single `session_liveness()` call,
      with `live` derived as NOT IN {`dead-pid`, `stale-heartbeat`} and the corrupt-entry branch
      emitted (never dropped) exactly as `cmd_session_list` does.
- [ ] Register all three in the dispatch `case` block and in the usage string.
- [ ] Create `scripts/tests/test-task-lock-queue.sh` modeled on
      `scripts/tests/test-task-lock-liveness.sh` (isolated `mktemp -d` root satisfying
      `deploy-root-guard.sh`, copied script + libs, fixture `state.json`, controlled-epoch
      timestamps, no sleeping, `pass`/`fail`/`info` helpers, cleanup trap). Cases for this phase:
      register creates the file with `state: registered` and a well-formed `orchestration_id`;
      re-register preserves `started_at`; heartbeat advances `heartbeat_at` and sets
      `state: running`; heartbeat on a missing entry WARNs and exits 0; list emits
      `liveness_reason` of `pid-alive` for a fixture using the test's own `$$`, `dead-pid` for a
      probed-dead pid past the grace floor, and `stale-heartbeat` for an old heartbeat; a corrupt
      entry is listed with `liveness_reason: corrupt` and `live: true`.

**Record schema** (the field set `write_queue_entry()` emits; `pid`, `pid_source`, and
`heartbeat_at` keep the session registry's exact key names so `session_liveness()` applies
unchanged, per D2):

```json
{
  "orchestration_id": "orch_1736700000_a1b2c3",
  "session_id": "sess_1736700000_a1b2c3",
  "pid": 261744,
  "pid_source": "ancestor-claude",
  "command": "/orchestrate 275",
  "task_numbers": [275],
  "file_scope": ["agent-system/extensions/core/scripts/task-lock.sh"],
  "state": "running",
  "started_at": "2026-11-04T06:30:00Z",
  "heartbeat_at": "2026-11-04T06:42:00Z",
  "finished_at": null,
  "archived_at": null
}
```

**Timing**: 1.75 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: this phase is hypothesized to add roughly 200-250 lines to
`scripts/task-lock.sh`, ~12 lines to `scripts/lib/common.sh`, and a ~250-line new suite, touching
3 files and no existing function body. Confirm by diffing at phase close: if any *existing*
function in `task-lock.sh` or `common.sh` had to change, the hypothesis is wrong and the tier
must be re-evaluated upward before the phase closes.

**Tier Justification**: this phase adds a new function to `scripts/lib/common.sh`, which is
sourced repo-wide and so carries a real cross-file name-collision surface that a single-module
check cannot see, so the covering check is `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-common-lib.sh,test-task-lock-queue.sh,test-task-lock-liveness.sh,test-session-registry.sh,test-task-lock-reap.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/common.sh` - add `common_orchestration_id()`
- `agent-system/extensions/core/scripts/task-lock.sh` - add queue dir resolvers,
  `write_queue_entry()`, `cmd_queue_register`, `cmd_queue_heartbeat`, `cmd_queue_list`, dispatch
  entries, usage string
- `agent-system/extensions/core/scripts/tests/test-task-lock-queue.sh` - new fixture suite
  (register / heartbeat / list / liveness cases)

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-task-lock-queue.sh` exits 0 with every
  case of this phase PASSing.
- The `--only` run named in the Tier Justification is green.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` exits 0 (exit
  status checked, not just stdout read) covering all three changed files.
- `grep -c 'session_liveness' agent-system/extensions/core/scripts/task-lock.sh` shows the
  function is *called* by `cmd_queue_list`, with no second liveness computation added anywhere.

---

### Phase 2: Archive on finish (`queue-finish`, `queue-reap`) [NOT STARTED]

**Goal**: A finished orchestration's record is moved into `specs/.orchestration/archive/` with
`state: archived`, disappears from the live listing, and is readable from the archive listing — no
`rm -f` anywhere on the path. A crashed orchestration's abandoned live entry is archived rather
than left to linger.

**Tasks**:
- [ ] Add `cmd_queue_finish <session_id>`: resolve the live entry for that `session_id`, set
      `state: "finished"` with `finished_at`, then move it to
      `specs/.orchestration/archive/{orchestration_id}.json` with `state: "archived"` and
      `archived_at` set. Implement as write-new-then-remove-old via `write_queue_entry()` into
      the archive directory followed by removal of the live file, so a crash mid-transition
      leaves one readable record rather than none. Idempotent and always exit 0 on a
      missing/already-archived entry, mirroring `cmd_session_release`'s idempotency contract (but
      never its `rm -f` disposal).
- [ ] Add `cmd_queue_reap [--dry-run]`: for each live entry, consume `session_liveness()`; archive
      (same transition as `queue-finish`, with a distinguishing disposition recorded in the
      archived record — e.g. `state: "archived"` plus a `finished_at` of the last heartbeat and a
      reason field naming the liveness verdict) only entries whose verdict is `dead-pid` or
      `stale-heartbeat`, matching `cmd_session_reap`'s firing band exactly. Report-then-act shape
      and `--dry-run` support modeled on `cmd_reap`/`cmd_session_reap`.
- [ ] Register both in the dispatch `case` block and the usage string.
- [ ] Extend `scripts/tests/test-task-lock-queue.sh`: finish moves the record (live listing no
      longer shows it; `--archived` listing does; `state` is `archived` and both timestamps are
      set); finish is idempotent on an already-archived or absent entry; **no file is ever
      deleted without an archive counterpart existing** (assert the archive file exists before
      asserting the live file is gone); reap archives a `dead-pid` entry and a `stale-heartbeat`
      entry, leaves a `pid-alive` entry untouched, and `--dry-run` mutates nothing.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: hypothesized to touch exactly 2 files (`task-lock.sh` and the suite from
Phase 1) and to add no new library or dependency. Confirm by `git status --short` at phase close
showing only those two paths modified.

**Tier Justification**: the edit is confined to additive subcommands in one script plus its own
new suite, with no externally visible signature change, and is covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-task-lock-queue.sh,test-task-lock-reap.sh,test-session-registry.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/task-lock.sh` - add `cmd_queue_finish`,
  `cmd_queue_reap`, dispatch entries, usage string
- `agent-system/extensions/core/scripts/tests/test-task-lock-queue.sh` - add finish/archive/reap
  cases

**Verification**:
- The suite exits 0 with the finish, idempotency, never-delete-without-archive, and reap cases
  PASSing.
- The `--only` run named in the Tier Justification is green.
- `grep -n 'rm -f' agent-system/extensions/core/scripts/task-lock.sh` shows no new `rm -f` on any
  queue path that is not preceded by a verified archive write.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` exits 0.

---

### Phase 3: Blocking admission refusal (`queue-check`) [NOT STARTED]

**Goal**: `queue-check` answers "may this invocation start?" against the live queue, reusing
`session_contention()` unmodified, and refuses with a nonzero exit and a named conflict rather
than a warning.

**Tasks**:
- [ ] Add `cmd_queue_check <session_id> <task_numbers_csv> [--allow-scope-collision]`: lazily
      source `lib/file-scope-overlap.sh` via the existing `ensure_file_scope_overlap_lib`
      helper; build the queue's enriched entry array from `cmd_queue_list` in-process (the same
      same-process pattern `cmd_acquire` uses with `cmd_session_list`, not a subprocess); then for
      each candidate task number in the CSV, evaluate `session_contention($cscope; $cnum;
      $own_sid; $all; $entries)` with `$cscope` = that candidate's own `get_file_scope`, `$cnum` =
      the candidate, `$own_sid` = this invocation's `session_id`, `$all` = `active_projects`.
      First hit wins (matching the predicate's documented first-match-wins convention).
- [ ] On a hit, resolve the hit's `session_id` back to its queue entry's `orchestration_id` and
      covered task numbers, and emit a refusal to stderr naming: the conflicting
      `orchestration_id`, its covered task numbers and `command`, the overlapping path, the
      candidate task number of *ours* that collided, the conflicting entry's `liveness_reason`,
      and the `--allow-scope-collision` override. State explicitly that nothing is queued or
      retried. Exit 1 (reserving 2 for usage errors), matching `cmd_acquire`'s ABORT convention.
- [ ] With `--allow-scope-collision`, downgrade the same message to a loud WARN and exit 0.
- [ ] No edit to `scripts/lib/file-scope-overlap.sh` — if the implementation finds itself needing
      one, STOP and record it as a deviation rather than editing a predicate with several other
      consumers.
- [ ] Register in the dispatch `case` block and the usage string.
- [ ] Extend `scripts/tests/test-task-lock-queue.sh` with the refusal matrix: (a) no live
      entries -> exit 0; (b) a live entry with an overlapping `file_scope` and an unrelated task
      number -> exit 1 with the refusal naming the `orchestration_id`, the overlapping path, and
      the colliding task number; (c) the same conflict with `--allow-scope-collision` -> exit 0
      with a WARN; (d) a conflicting entry whose session is `dead-pid` -> exit 0 (liveness
      exclusion); (e) a conflicting entry covering only a dependency-edge-connected task number
      -> exit 0 (edge exclusion); (f) an entry carrying our own `session_id` -> exit 0
      (self-exclusion); (g) an **archived** entry with an overlapping scope -> exit 0 (the archive
      is never an admission input).

**Timing**: 1.75 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: hypothesized to touch exactly 2 files and to require zero changes to
`scripts/lib/file-scope-overlap.sh`. Confirm with `git status --short` at phase close; a modified
`file-scope-overlap.sh` falsifies the hypothesis and requires the tier to be raised to
`interface` (that library has multiple consumers) before the phase closes.

**Tier Justification**: the edit is confined to one additive subcommand in one script plus its
own suite, consuming an unmodified shared predicate, and is covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-task-lock-queue.sh,test-conflict-predicate.sh,test-four-tier-conflict.sh,test-session-registry.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/task-lock.sh` - add `cmd_queue_check`, dispatch entry,
  usage string
- `agent-system/extensions/core/scripts/tests/test-task-lock-queue.sh` - add the seven-case
  refusal matrix

**Verification**:
- All seven refusal cases PASS; the refusal message's text is asserted to contain the conflicting
  `orchestration_id` and the overlapping path (not merely a nonzero exit).
- The `--only` run named in the Tier Justification is green.
- `git diff --stat -- agent-system/extensions/core/scripts/lib/file-scope-overlap.sh` is empty.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` exits 0.

---

### Phase 4: Lifecycle and admission wiring [NOT STARTED]

**Goal**: The three lifecycle transitions fire from the three existing call sites, and the
refusal gate runs once per `/orchestrate` invocation before any dispatch.

**Tasks**:
- [ ] `skills/skill-orchestrate/SKILL.md`, Setup block: immediately after the existing
      `session-register` call, add the `queue-register` call with the identical
      best-effort/non-blocking posture (`2>/dev/null || true`) and the same `task_numbers` CSV
      expression. Registration must never turn a startable invocation into a failure.
- [ ] `skills/skill-orchestrate/SKILL.md`, Move 4 termination sentence: add `queue-finish
      "$session_id"` alongside the existing `session-release "$session_id"`, phrased so the
      archive transition is named (not "release the queue").
- [ ] `scripts/orchestrate-cycle-plan.sh`: directly beside the existing `session-heartbeat`
      invocation, add the `queue-heartbeat` call with the same `2>/dev/null || true` posture, and
      a one-line comment stating that the two calls are co-sited deliberately so the queue never
      acquires a second, independently-timed currency mechanism.
- [ ] `commands/orchestrate.md`: after `batch_session_id` is minted and before the dispatch
      section begins (co-located with the Pre-Dispatch Review call, which stays advisory), add the
      blocking `queue-check` invocation, forwarding `ALLOW_SCOPE_COLLISION_FLAG`, and document in
      the surrounding prose that a nonzero exit ABORTS the whole invocation with the conflict
      named, that nothing is queued or retried, and that this is the one blocking
      whole-orchestration admission surface (distinct from Pre-Dispatch Review's advisory Class E
      and from the per-task `acquire` pass).
- [ ] Update the flags table row for `--allow-scope-collision` in `commands/orchestrate.md` so it
      names the queue refusal as a second thing the flag bypasses.
- [ ] Do NOT modify `scripts/command-gate-in.sh` (D6). Record the narrowing of the task's
      anticipated `file_scope` in the phase notes.

**Timing**: 1.25 hours

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: hypothesized to be 5 edits across exactly 3 files (two in `SKILL.md`, one
in `orchestrate-cycle-plan.sh`, two in `commands/orchestrate.md`) and zero edits to
`command-gate-in.sh`. Confirm with `git status --short` plus a grep for `queue-register`,
`queue-heartbeat`, `queue-finish`, and `queue-check` showing exactly one call site each.

**Tier Justification**: inserting a call into `orchestrate-cycle-plan.sh`'s cycle body changes a
module whose call sites and dispatch composition span several files, so the covering check is the
mechanically resolved suite set for the touched paths —
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only "$(set +u; . agent-system/extensions/core/scripts/lib/suite-selection-lib.sh; suite_selection_select agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh agent-system/extensions/core/skills/skill-orchestrate/SKILL.md agent-system/extensions/core/commands/orchestrate.md)"` —
falling back to the full Gate 8 sweep if that resolver returns `__FULL_SWEEP__`.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - `queue-register` in Setup;
  `queue-finish` in Move 4
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - `queue-heartbeat` co-sited
  with `session-heartbeat`
- `agent-system/extensions/core/commands/orchestrate.md` - blocking `queue-check` before
  dispatch; `--allow-scope-collision` flags-table row

**Verification**:
- `grep -n 'queue-register\|queue-heartbeat\|queue-finish\|queue-check'` across
  `skills/`, `scripts/`, and `commands/` shows exactly the four intended call sites and no others.
- The resolved `--only` run (or the full Gate 8 sweep on the sentinel) is green.
- `grep -n 'queue-' agent-system/extensions/core/scripts/command-gate-in.sh` is empty (D6 held).
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` exits 0.

---

### Phase 5: Contract documentation [NOT STARTED]

**Goal**: The queue's schema, lifecycle, liveness rule, refusal contract, and storage
classification are documented to the rigor of the existing session-registry contract, with no
claim in the docs that the code does not support.

**Tasks**:
- [ ] `context/patterns/task-lock.md`: add an `## Orchestration-Queue CLI: queue-register /
      queue-heartbeat / queue-finish / queue-reap / queue-list / queue-check` section, sited
      immediately after the Session-Registry CLI section and mirroring its structure: an opening
      "a FOURTH standalone CLI family, and what makes it different" paragraph; a Reader Contract
      subsection; a Record Schema block with the per-field table; a lifecycle subsection with the
      `registered -> running -> finished -> archived` state diagram naming which subcommand drives
      each transition; a per-subcommand subsection; a **Liveness Is Consumed, Never Recomputed**
      subsection stating that `session_liveness()` is applied to the queue entry file itself and
      why the session-registry entry is deliberately not consulted (D2); a **Refusal Contract**
      subsection giving the exact exit codes, the three exclusions inherited from
      `session_contention()`, the message's named fields, the `--allow-scope-collision` override,
      and an explicit "nothing is queued, nothing is retried, nothing auto-starts"; and a
      **Known Limitations** subsection recording that the archive is local and untracked (D4) and
      that no retention policy exists.
- [ ] Cross-reference the new section from the Session-Registry CLI section ("build on, do not
      replace") and from the Four-Tier Conflict Response section, placing the queue refusal
      relative to the existing tiers.
- [ ] `context/standards/orchestrator-runtime-files.md`: add two Class Table rows —
      `specs/.orchestration/queue/{orchestration_id}.json` (**Ephemeral**; written by
      `queue-register`/`queue-heartbeat`, read by `queue-list`/`queue-check`, disposed by
      `queue-finish`/`queue-reap` *by archival, never deletion*) and
      `specs/.orchestration/archive/{orchestration_id}.json` (**Durable provenance**; never
      reaped, never deleted, untracked per D4). State in the rows' rationale that the existing
      `**/.orchestration/` directory-class pattern already covers both and that
      `reap-session-runtime-files.sh`'s literal, non-recursive filename globs cannot reach either
      subdirectory.
- [ ] Verify mechanically before writing those claims: `grep -n 'orchestration'
      scripts/lib/runtime-file-patterns.sh` (pattern member present), and a read of
      `reap-session-runtime-files.sh`'s candidate glob list (no recursive or `queue/`/`archive/`
      glob). If either check contradicts the claim, fix the code or the claim in this phase
      rather than documenting an aspiration.
- [ ] Do NOT edit the mechanically derived "Consumer Repo Setup" gitignore block in
      `orchestrator-runtime-files.md` — it is pinned by `test-runtime-file-tracking.sh` and
      derives from `runtime-file-patterns.sh`, which this plan does not change.

**Timing**: 1.25 hours

**Depends on**: 4

**Verification Tier**: prose

**Scope Hypothesis**: hypothesized to touch exactly 2 markdown files and to require zero code
change (the two mechanical verifications above are expected to confirm the existing pattern and
globs suffice). Confirm with `git status --short`; any `.sh` file appearing there falsifies the
hypothesis and requires the tier to be raised before the phase closes.

**Tier Justification**: every changed hunk is prose inside two source-store markdown files with
no executable surface, so the covering check is the diff read-through plus
`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 agent-system/extensions/core`
and `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-runtime-file-tracking.sh`
for the pinned gitignore block in the Class Table's own file.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/task-lock.md` - new Orchestration-Queue CLI
  section plus two cross-references
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - two Class
  Table rows

**Verification**:
- Diff read-through confirms every hunk is prose/table content inside the two files, and that the
  pinned gitignore block is untouched.
- The `--only-gate 3,4` run against the source store passes (doc-lint, task-reference lint).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-runtime-file-tracking.sh`
  is green.
- Every subcommand named in the documentation exists in `task-lock.sh`'s usage string, checked by
  diffing the two name lists.

---

### Phase 6: Full gate set and acceptance walk-through [NOT STARTED]

**Goal**: The complete repository gate set is green, and each acceptance criterion from the task
record is checked off against observed evidence rather than assumed from the phases above.

**Tasks**:
- [ ] Run the complete gate set: `bash agent-system/extensions/core/scripts/verify-deploy.sh
      agent-system/extensions/core` with no gate filter and no `--skip-slow`, and record the
      result. Pay explicit attention to gate 8 (shell suites, including the new
      `test-task-lock-queue.sh`), gate 14 (runtime-file tracking), and gate 22 (shellcheck).
- [ ] Walk the task record's ACCEPTANCE list item by item and record the evidence for each:
      (a) schema + lifecycle documented to the session-registry contract's standard — cite the
      new section; (b) finished orchestrations archived rather than `rm -f`'d — cite the
      never-delete-without-archive test case and the archive Class Table row; (c) queue-entry
      liveness consumes `session_liveness()` — cite the single call site and the liveness test
      cases; (d) queue readable as an admission input — cite `queue-check`'s wiring in
      `commands/orchestrate.md`; (e) fixture test covering
      `registered -> running -> finished -> archived` and the refusal path — cite the suite's case
      list; (f) shellcheck clean; (g) no task-number references in deliverables outside `specs/**`
      — cite gate 4.
- [ ] Redeploy so the deployed tree stops being stale for `core`:
      `timeout 540 bash .claude/scripts/deploy-headless.sh` (Bash tool `timeout` parameter raised
      to 600000 per `context/patterns/external-process-wait.md` Rule 1), then re-run
      `bash .claude/scripts/check-deploy-freshness.sh`.
- [ ] If any acceptance item cannot be evidenced, record it as a deviation in the issue log and in
      the handoff rather than closing the phase on an assumption.

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: full

**Scope Hypothesis**: no new files are expected to change in this phase; it is a verification
phase. Confirm with `git status --short` showing only gate-produced artifacts (if any) and the
deploy's own regenerated `.claude/**` tree.

**Files to modify**:
- none planned - verification-only phase; any file change here is a gate-driven fix and must be
  recorded as a deviation

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-deploy.sh agent-system/extensions/core` exits
  0 with the complete gate set run (no `--only-gate`, no `--skip-slow`, no deferral).
- Every acceptance item above has named evidence recorded in the phase notes.
- `bash .claude/scripts/check-deploy-freshness.sh` reports no stale extension for `core`.

---

## Testing & Validation

- [ ] `scripts/tests/test-task-lock-queue.sh` passes standalone and under `run-all.sh` discovery
      (it is auto-discovered by the `scripts/tests/test-*.sh` glob; no registration edit needed —
      verify this rather than assuming it).
- [ ] Lifecycle coverage: `registered` (register), `running` (heartbeat), `finished` + `archived`
      (finish), plus the reap path for a crashed orchestration.
- [ ] Never-delete-without-archive: the archive file is asserted to exist *before* the live file's
      absence is asserted.
- [ ] Refusal matrix: no-conflict, conflict-refused (message content asserted), override-warns,
      dead-entry-excluded, dependency-edge-excluded, self-excluded, archived-entry-excluded.
- [ ] Liveness consumption: `pid-alive`, `dead-pid`, `stale-heartbeat`, and `corrupt`
      `liveness_reason` values observed through `queue-list`, with no second liveness computation
      present in the diff.
- [ ] `lib/file-scope-overlap.sh` is byte-identical to its pre-task state.
- [ ] Regression suites for the shared files: `test-common-lib.sh`, `test-session-registry.sh`,
      `test-task-lock-liveness.sh`, `test-task-lock-reap.sh`, `test-conflict-predicate.sh`,
      `test-four-tier-conflict.sh`, `test-orchestrate-cycle-plan.sh`,
      `test-runtime-file-tracking.sh`, `test-session-runtime-files.sh`.
- [ ] Full gate set green (Phase 6), shellcheck clean per
      `context/standards/shell-strict-mode.md`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/task-lock.sh` — six new queue subcommands, two directory
  resolvers, `write_queue_entry()`
- `agent-system/extensions/core/scripts/lib/common.sh` — `common_orchestration_id()`
- `agent-system/extensions/core/scripts/tests/test-task-lock-queue.sh` — new fixture suite
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — register + finish wiring
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — heartbeat wiring
- `agent-system/extensions/core/commands/orchestrate.md` — blocking `queue-check` wiring, flags
  table row
- `agent-system/extensions/core/context/patterns/task-lock.md` — Orchestration-Queue CLI section
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` — two Class
  Table rows
- Runtime (not committed): `specs/.orchestration/queue/{orchestration_id}.json`,
  `specs/.orchestration/archive/{orchestration_id}.json`

## Rollback/Contingency

Every phase is additive: the new subcommands are unreachable until Phase 4's wiring lands, so
reverting Phase 4's four call sites alone restores today's behavior exactly while leaving the
new code dormant and harmless. That is the preferred contingency if the blocking refusal proves
too aggressive in practice — revert the `commands/orchestrate.md` `queue-check` insertion first,
keeping the registry and archive, since the record-keeping half carries no admission risk.

If a full revert is needed and uncommitted work must be discarded, take a snapshot first per
`context/contracts/recovery.md`'s rollback rung (which gives the exact `git-snapshot.sh`
invocation shape, including its out-of-scope override flag for a whole-tree case) and then run
the destructive command; never discard uncommitted work without that snapshot. Phase commits are
per-phase and scoped, so `git revert` of a single phase's commit is the normal path and needs no
snapshot at all.

Runtime state needs no rollback: `specs/.orchestration/queue/` and
`specs/.orchestration/archive/` are untracked, locally-scoped directories, and removing them by
hand returns the repo to its pre-task state with no effect on the session registry, the task
locks, or any committed artifact.
