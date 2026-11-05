# Research Report: Task #275

**Task**: 275 - Per-repo orchestration queue: registered, live, archived on finish, and consumed by admission
**Started**: 2026-10-08T00:00:00Z
**Completed**: 2026-10-08T00:00:00Z
**Effort**: Medium (schema + lifecycle + archival + one admission wiring point; no scheduler, no new agents)
**Dependencies**: Task 272 (substantive; queue currency relies on live heartbeat). Task 51's
relocation work (`specs/.orchestration/`, `scripts/reap-session-runtime-files.sh`,
`context/standards/orchestrator-runtime-files.md`) is already landed in the source store and is
the archival-location precedent this task must follow — no live task numbered 51 remains in
`specs/state.json` or `specs/archive/` to depend on; its artifacts are already merged.
**Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/task-lock.sh`,
`scripts/lib/file-scope-overlap.sh`, `scripts/orchestrate-batch-admit.sh`,
`scripts/orchestrate-cycle-plan.sh`, `scripts/reap-session-runtime-files.sh`,
`skills/skill-orchestrate/SKILL.md`, `commands/orchestrate.md`,
`context/standards/orchestrator-runtime-files.md`, `context/patterns/task-lock.md`,
`skills/skill-todo/SKILL.md`), task 272's plan/report, `specs/TODO.md` history (`git log -p`) for
the original "Piece 4" text, task 274's description (downstream consumer).
**Artifacts**: `specs/275_per_repo_orchestration_queue/reports/01_per-repo-orchestration-queue.md` (this report)
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- **No orchestration-level record exists today.** The only persistent per-invocation record is
  the session registry (`specs/.sessions/{session_id}.json`), which is keyed on `session_id`,
  deleted (not archived) on `session-release`, and has zero history. The "queue" this task builds
  is a **new, additive, per-repo registry + archive**, not a rename of the session registry.
- **Build it as a second file class beside the session registry, not a replacement for it.** The
  session registry remains the liveness/lock substrate (`session_liveness()`,
  `session_contention()`); the new queue consumes that same liveness verdict rather than
  recomputing it, exactly as the dispatch's grounding point (4) requires.
- **Three existing call sites are where this queue's lifecycle transitions already have a home**:
  session-register (loop setup, `skill-orchestrate/SKILL.md` ~line 41) → `registered`/`running`;
  session-heartbeat (per-cycle, `scripts/orchestrate-cycle-plan.sh:1200`) → keep `running`
  metadata current; session-release (loop termination, `skill-orchestrate/SKILL.md` ~line 295) →
  `finished` → archive. No new dispatch-boundary hook is needed; the queue rides the same three
  calls task 272 is repairing the heartbeat propagation of.
- **Archival location must mirror task 51's already-landed relocation**: per-session batch
  runtime state (`.orchestrator-multi-state-*.json`, `.return-meta-multi-*.json`) now lives under
  `specs/.orchestration/`, not the `specs/` root. The queue's live and archive directories should
  sit there too (e.g. `specs/.orchestration/queue/` and `specs/.orchestration/archive/`), not at
  a freshly invented path, to avoid the "fourth orphaned naming generation" task 51's own text
  warns against.
- **`skill-todo`'s archive convention is move-not-delete, with a parallel ledger** — it moves a
  task directory under `specs/archive/` and appends to `specs/archive/state.json`'s
  `completed_projects` array rather than scattering per-item files. The queue's archive should
  follow the same shape: move/rewrite the finished entry's record file into an archive location
  and/or append it to an archive-side index, never `rm -f` it (today's `cmd_session_release`
  behavior, which is exactly the defect being fixed here for the orchestration-level record).
- **The "REFUSED IMMEDIATELY, conflict named" requirement is a blocking gate, not today's
  advisory behavior.** `orchestrate-predispatch-review.sh`'s Class E (session-registry
  contention) is explicitly advisory-loud, never blocking; `task-lock.sh cmd_acquire`'s
  cross-task overlap pass IS blocking but fires per-task, inside a cycle, after the orchestration
  has already begun processing a task — not as a single upfront whole-orchestration refusal at
  invocation time. This task needs a genuinely new blocking check, exposed as a script subcommand
  (or reusing `task-lock.sh`'s dispatch style), callable once per `/orchestrate` invocation before
  any dispatch.
- **Alternatives-on-conflict is explicitly NOT this task's job.** Task 274 (which depends on 275)
  owns the alternatives search, built by actually invoking `orchestrate-batch-admit.sh` over
  candidate sets — never a second copy of the admission predicate. This task's refusal only needs
  to **name** the conflicting orchestration (which repo state it is, which tasks/paths it covers)
  convincingly enough for a fixture to assert the refusal path; it does not need to compute a
  suggested replacement batch.

## Context & Scope

**What was researched**: the existing session-registry mechanism in `task-lock.sh` (schema,
lifecycle commands, liveness vocabulary, cross-task overlap/admission consumption), the
already-landed runtime-file relocation convention (`orchestrator-runtime-files.md`,
`reap-session-runtime-files.sh`), the archive convention used by `skill-todo` for task
directories, the wiring points in `skill-orchestrate/SKILL.md` and
`scripts/orchestrate-cycle-plan.sh` where a batch orchestration's lifecycle events already fire,
the admission scripts (`orchestrate-batch-admit.sh`, `orchestrate-predispatch-review.sh`) and
their advisory-vs-blocking posture, and the git history of the task description to recover the
original "Piece 4" text that explains why an orchestration-level identity distinct from
`session_id` is needed.

**Constraints carried verbatim from the dispatch** (RULED, not reopened by this report):
registry + immediate refusal only — no scheduler, no auto-start, no wait queue; per-repo scope
only; archive on finish rather than delete; liveness must be consumed from `session_liveness()`,
never re-derived; archival location must be consistent with task 51's relocation and with
`skill-todo`'s archive convention; edits land in `agent-system/extensions/core/` only.

## Findings

### Codebase Patterns

**Session registry schema** (`scripts/task-lock.sh`, `session_registry_dir()` ~line 497,
`write_session_entry()` ~line 561): one file per session at
`specs/.sessions/{session_id}.json`, written via the tmp-file-rename pattern, holding
`{session_id, pid, pid_source, command, task_numbers, file_scope, started_at, heartbeat_at}`.
`cmd_session_register`/`cmd_session_heartbeat` both call `write_session_entry` (register sets
`started_at`+`heartbeat_at` to now; heartbeat rewrites `heartbeat_at` and — once task 272 lands —
re-derives `file_scope`). `cmd_session_release` is `rm -f "$sessions_dir/${session_id}.json"` —
**no history survives**. `cmd_session_list` enriches each entry with `age_min`, `live`,
`liveness_reason` computed by `session_liveness()` before emitting NDJSON.

**`session_liveness()`** (~line 1640): the single factored-out liveness computation this queue
must consume rather than re-derive. Six reasons in a fixed evaluation order — `corrupt`
(unparseable JSON, short-circuits), `dead-pid` (pid confirmably gone AND age >
`SESSION_REGISTRY_DEAD_PID_MIN`), `dead-pid-within-grace`, `stale-heartbeat` (age >
`SESSION_REGISTRY_REAP_MIN`, fallback regardless of pid state), `pid-alive`, `undeterminable`.
Two thresholds, both overridable via env var, both deliberately **not** derived from
`TASK_LOCK_REAP_MIN` because a batch orchestration can run far longer than a single task's lock
window (up to `MAX_CYCLES_MT = min(task_count * 5, 25)` cycles). `cmd_session_list` and
`session_contention()` (in `scripts/lib/file-scope-overlap.sh`) both consume this one verdict;
`cmd_session_reap` fires on `dead-pid` or `stale-heartbeat` only.

**`session_contention()`** (`scripts/lib/file-scope-overlap.sh` ~line 123): D4's three exclusions
(self-session-id, liveness — `live == true` excludes only `dead-pid`/`stale-heartbeat` — and a
per-covered-task-number dependency-edge exclusion via `edge_connected_nums`), then
`scopes_overlap_first` against the surviving sessions' `file_scope`. Consumed today from two
call sites: `task-lock.sh cmd_acquire`'s cross-task overlap pass (BLOCKING — returns 1/ABORT on a
hit; never mutates the foreign session) and `orchestrate-batch-admit.sh --session-id` (feeds a
per-candidate `idle_overlap_advisory`/defer verdict, surfaced by
`orchestrate-predispatch-review.sh`'s Class E — **advisory only**, never blocking).

**Orchestration lifecycle call sites that already exist** (where this task's new transitions
should hook in, not invent new hook points):
- Session mint + register: `commands/orchestrate.md` ~line 204 (`batch_session_id="$(common_session_id)"`)
  and `skill-orchestrate/SKILL.md` ~line 41 (`task-lock.sh session-register "$session_id"
  "/orchestrate" "$(IFS=,; echo "${task_numbers[*]}")"`).
- Per-cycle currency: `scripts/orchestrate-cycle-plan.sh:1200`
  (`task-lock.sh session-heartbeat "$session_id"`) — the exact call task 272 is repairing
  end-to-end propagation of. A queue "running" record's own currency should piggyback on this
  same call rather than adding a second heartbeat timer.
- Termination + release: `skill-orchestrate/SKILL.md` ~line 295
  (`task-lock.sh session-release "$session_id"`), immediately before `.dispatch/` cleanup and the
  `.return-meta-multi-${session_id}.json` write. This is the natural `finished` → `archived`
  transition point.

**Runtime-file relocation precedent (task 51's work, already landed)**:
`context/standards/orchestrator-runtime-files.md`'s Class Table documents the two-class split
(Ephemeral / Durable provenance) and records that per-session **batch** runtime state
(`.orchestrator-multi-state-{session_id}.json`, `.return-meta-multi-{session_id}.json`) now
writes to `specs/.orchestration/` (created via `mkdir -p` on first write), with the legacy
`specs/` root globs kept permanently reapable in `scripts/reap-session-runtime-files.sh` for
already-stranded files. The session registry itself
(`specs/.sessions/{session_id}.json`) is listed as **Ephemeral**, still at the `specs/` root —
it was not itself relocated by that work. `reap-session-runtime-files.sh`'s own header explains
the four-naming-generations risk this task must not reproduce: **do not invent a fifth location**
for the queue; site it under `specs/.orchestration/` (the already-established per-repo
orchestration-runtime directory), not a new top-level dotdir.

**Archive convention precedent (`skill-todo/SKILL.md`)**: archiving a task is move-not-delete —
the task directory is `mv`'d from `specs/` to `specs/archive/`, and a **separate** ledger
(`specs/archive/state.json`'s `completed_projects` array, via `state-write.sh`) records the
archived entry's metadata. This is the shape to mirror for the queue's archive: a finished
orchestration's live record is moved (or its content copied) into an archive-side store and the
live queue stops listing it, rather than either (a) deleting it (today's `cmd_session_release`
defect for orchestrations generally) or (b) leaving it forever in the live/"running" view.

**Admission posture — advisory vs. blocking, precisely**:
- `orchestrate-predispatch-review.sh`'s Class E (session-registry contention) is explicitly
  "advisory-loud, never blocking" per its own header — the only hard abort surface before
  dispatch is `--dry-run`, which is a human opt-in, not automatic.
- `task-lock.sh cmd_acquire`'s cross-task overlap pass **is** blocking (returns 1 and the caller
  treats that as ABORT), but it fires once PER TASK, inside `orchestrate-cycle-plan.sh`'s
  per-cycle loop (~line 2287), i.e. after the orchestration has already been admitted and started
  processing — not as a single whole-orchestration refusal at `/orchestrate` invocation time,
  before any dispatch at all.
- The dispatch's SEMANTICS section ("REFUSED IMMEDIATELY... NO WAITING QUEUE") describes a gate
  that does not exist yet in this shape: a synchronous, blocking check run once per
  `/orchestrate` invocation (or per `/research`/`/plan`/`/implement` via
  `command-gate-in.sh`), before any task is admitted, that consults the new queue (not just the
  session registry) and refuses the whole invocation outright on a conflict.

**`orchestrate-batch-admit.sh`'s own documented boundary** (confirmed from its header and from
task 274's description, which depends on this task): the admission script answers "may this
candidate set run?" and has "NO NOTION OF ALTERNATIVES" — alternatives-on-conflict is an explicit
non-goal of the admission predicate itself, assigned instead to task 274 as "a NEW CALLER-SIDE
LOOP over candidate sets... never by re-implementing, approximating, or duplicating its logic."
This task's refusal path therefore only needs to **name** the conflict (which in-flight
orchestration, which overlapping path/task) — not search for or suggest a replacement batch.

**"Piece 4" / per-orchestration identity — recovered original intent** (via `git log -p` on
`specs/TODO.md`, since the live task 272 description now only says "moved to task 275"): the
original text read *"Introduce an orchestration-id DISTINCT from session_id, so two batches in two
sessions of one repo keep separate metadata/artifacts/return-meta rather than a single shared
in-flight record."* Cross-referenced against `common_session_id()` (`scripts/lib/common.sh`
~line 141: `sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom)`), which mints a fresh, effectively
collision-free id on every invocation — `session_id` already uniquely identifies one
`/orchestrate` invocation today. The identity gap is therefore not "two sessions collide" but
**"a session is the wrong grain for an orchestration-level audit record"**: the session registry
is purpose-built for lock liveness (deleted on release, no history), while the queue needs a
record that can **outlive** the session (survive into an archive) and be named independently of
whatever session-liveness machinery governs the lock. Minting `orchestration_id` alongside
`session_id` at the same point `batch_session_id` is minted
(`commands/orchestrate.md` ~line 204) gives the queue its own primary key without disturbing
`task-lock.sh`'s session-keyed liveness/lock substrate at all — consistent with the dispatch's
"build on, do not replace" instruction (grounding point 3).

### External Resources

Not applicable — this is a closed, repo-internal mechanism; no external library or API research
was warranted. The task description's own ACCEPTANCE criteria name the comparison standard
(`context/patterns/task-lock.md`'s existing session-registry contract), which was read in full
as the internal "external" reference for documentation rigor.

## Recommendations

1. **Mint `orchestration_id`** (e.g. `orch_{timestamp}_{rand}`, same shape as `common_session_id`,
   via a new `common_orchestration_id()` in `scripts/lib/common.sh` or a thin wrapper) at the same
   site `batch_session_id` is minted (`commands/orchestrate.md` ~line 204), and thread it through
   exactly like `batch_session_id` is threaded (delegation-context args, `.return-meta.json`,
   etc.) — this is the per-orchestration identity distinct from `session_id` that grounding point
   (2) requires.

2. **Add a new `task-lock.sh` subcommand family** (`queue-register` / `queue-heartbeat` /
   `queue-finish` / `queue-list` / `queue-check`, naming TBD at plan time) rather than a wholly
   separate script, so the new queue reuses `task-lock.sh`'s existing tmp-file-rename write
   helper, `session_liveness()`, and dispatch-table conventions instead of re-implementing them.
   A genuinely new script is warranted only if plan-time analysis shows the subcommand surface
   would make `task-lock.sh` unwieldy; the dispatch leaves this open ("Name them in the plan; do
   not pre-commit to them here").

3. **Site live entries and the archive under `specs/.orchestration/`**, e.g.
   `specs/.orchestration/queue/{orchestration_id}.json` (live: `registered`/`running`) and
   `specs/.orchestration/archive/{orchestration_id}.json` (or an appended archive-index file,
   mirroring `skill-todo`'s `completed_projects` array shape) for `finished`/`archived` — never
   a new top-level dotdir, and never deleted on completion.

4. **Wire the three lifecycle writes onto the three existing call sites** (register at loop
   setup, heartbeat-refresh at `orchestrate-cycle-plan.sh:1200`, finish+archive at
   `skill-orchestrate/SKILL.md` ~line 295 session-release), not a new dispatch-boundary hook.
   Record the queue entry's `running` currency as a read of the SAME heartbeat timestamp
   `session-heartbeat` already writes (or call the new queue-heartbeat subcommand from the exact
   same call site) so there is no second, independently-timed currency mechanism to drift out of
   sync with task 272's heartbeat repair.

5. **Build the blocking admission gate as a new, separate check** — most naturally a new
   `task-lock.sh` subcommand (e.g. `queue-check`) called once per `/orchestrate` invocation,
   before `validated_tasks` dispatch begins (near where `batch_session_id` is minted and
   Pre-Dispatch Review runs in `commands/orchestrate.md`), or from `command-gate-in.sh` for the
   single-task commands. It should consult the new queue's live entries (not the session
   registry directly) for a `file_scope` conflict, using `scopes_overlap_first`/
   `session_liveness()`-consuming logic analogous to `session_contention()` but against queue
   entries rather than session-registry entries, and refuse (nonzero exit, named conflict) rather
   than warn. Do not route this through `orchestrate-batch-admit.sh`'s per-candidate verdict
   schema — that script's job is per-task-candidate admission inside an already-running
   orchestration's cycle, not whole-orchestration refusal at invocation time; conflating the two
   would blur the exact boundary task 274's description is careful to preserve.

6. **Do not implement alternatives-on-conflict here.** The refusal message should name the
   conflicting orchestration (its `orchestration_id`, covered task numbers, and the overlapping
   path) with enough structure that task 274 can consume it, but the search for a suggested
   replacement batch is explicitly task 274's scope (which depends on this task for exactly that
   reason).

7. **Document the new lifecycle to the standard of `context/patterns/task-lock.md`**: add either
   a new peer document (`context/patterns/orchestration-queue.md`) or a clearly-scoped new section
   in `task-lock.md` itself, covering the record schema, state diagram
   (`registered → running → finished → archived`), the liveness-consumption rule (never
   recompute `session_liveness()`), and the refusal contract — mirroring the rigor of the
   existing "Lockfile Schema" / "Session-Registry helpers" sections.

8. **Fixture test**: add `scripts/tests/test-task-lock-queue.sh` (or
   `test-orchestration-queue.sh` if a separate script is chosen), modeled on
   `scripts/tests/test-task-lock-liveness.sh`'s fixture style, covering: register → running
   (heartbeat updates visible) → finished → archived (and that the archived entry no longer
   appears in the live listing, while the archive file/index does hold it); and the refusal path
   (two conflicting orchestrations, one registered, the second's `queue-check` refused with the
   first named).

## Decisions

- **Build on `task-lock.sh`'s session registry; do not replace or fork it.** The new queue is an
  additive concept with its own identity (`orchestration_id`) and its own record file(s), but its
  liveness computation is a direct `session_liveness()` consumption, never a re-derivation — this
  directly satisfies grounding point (4) and was independently confirmed by reading
  `session_liveness()` and both its current consumers (`cmd_session_list`,
  `session_contention()`).
- **Queue location: `specs/.orchestration/`, siblings `queue/` and `archive/`.** This follows
  task 51's already-landed relocation precedent rather than inventing a new top-level dotdir or
  leaving the queue at the legacy `specs/` root alongside `.sessions/`. ("Beside the existing
  session registry" in the dispatch's SCOPE section is read as "a sibling per-repo runtime
  concept," not "literally inside `specs/.sessions/`.")
- **Archive = move/append, never `rm -f`.** Mirrors `skill-todo`'s task-archival convention
  (move + separate ledger) and directly reverses the defect named in grounding point (1)
  (`cmd_session_release`'s bare `rm -f`) — but only for the NEW orchestration-level record; this
  task does not change `cmd_session_release`'s own behavior for the session registry itself,
  which is out of scope (task 272's territory, not re-opened here).
- **Alternatives-on-conflict is out of scope.** Confirmed against task 274's own description,
  which explicitly assigns that computation to itself via a caller-side loop over
  `orchestrate-batch-admit.sh` invocations, and explicitly depends on this task only for "nothing
  to draw from until 275 exists" — i.e., for the queue's existence, not for an alternatives
  algorithm this task would otherwise have to build and then discard.
- **No change to `orchestrate-batch-admit.sh`'s verdict schema.** The new blocking refusal is a
  separate check (new `task-lock.sh` subcommand or a small new script), not a mutation of the
  per-candidate admission predicate multiple other tasks (165, 274, `orchestrate-predispatch-review.sh`)
  already depend on having a stable schema.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Building a second, independently-timed heartbeat for queue currency drifts out of sync with task 272's heartbeat repair | Piggyback the queue's `running`-state currency write onto the exact same call site as `session-heartbeat` (`orchestrate-cycle-plan.sh:1200`), not a new timer |
| Choosing an archive location independently of task 51's relocation creates a "fourth orphaned naming generation" | Site under `specs/.orchestration/` (already-established, already read by `reap-session-runtime-files.sh`'s comments as the canonical per-repo orchestration-runtime directory) |
| Conflating the new blocking whole-orchestration refusal with `orchestrate-batch-admit.sh`'s per-candidate verdict schema | Keep them as two separate mechanisms: a new queue-level check for invocation-time refusal, the existing script unchanged for per-candidate admission inside an already-running orchestration |
| Scope creep into task 274's alternatives-search or task 272's heartbeat-propagation fix | Explicitly re-confirmed as out of scope above, cited against both tasks' own descriptions |
| A new top-level script duplicates `task-lock.sh`'s tmp-file-rename write pattern or liveness logic instead of reusing it | Prefer extending `task-lock.sh`'s own subcommand dispatch table over a new script, unless plan-time analysis shows a clear separation-of-concerns reason not to (left open per the dispatch's "name them in the plan" instruction) |

## Context Extension Recommendations

- **Topic**: Per-repo orchestration-queue lifecycle (once implemented).
- **Gap**: `context/patterns/task-lock.md` currently documents only the per-task lock and the
  session registry; it has no section for an orchestration-level registry/archive once this task
  lands.
- **Recommendation**: add a new section to `task-lock.md` (or a new peer document
  `context/patterns/orchestration-queue.md`, cross-linked from `task-lock.md`) documenting the
  queue's record schema, lifecycle states, and the refusal contract, at the plan/implementation
  stage — this report defers the exact form to the planner per the dispatch's "Name them in the
  plan" instruction for new scripts, which applies equally to new documentation structure.

## Appendix

**Search queries / exploration used** (all local codebase; no web search was warranted for this
closed, repo-internal design question):
- `grep -n "cmd_session\|session_liveness\|session_contention\|SESSIONS_DIR\|sessions_dir\|SESSION_REGISTRY" scripts/task-lock.sh`
- Read of `session_liveness()`, `write_session_entry()`, `session_registry_dir()`,
  `cmd_session_list()`, and the cross-task overlap pass in `scripts/task-lock.sh`
- `find . -iname "orchestrator-runtime-files*" -o -iname "reap-session-runtime-files*"` and full
  read of `context/standards/orchestrator-runtime-files.md`'s Class Table
- Full read of `scripts/reap-session-runtime-files.sh`
- `grep -n "specs/archive\|archive_task\|mv.*archive\|archive_dir" skills/skill-todo/SKILL.md`
- `grep -n "session-register\|session-heartbeat\|session-release\|common_session_id\|batch_session_id"`
  across `skills/skill-orchestrate/SKILL.md`, `commands/orchestrate.md`,
  `scripts/orchestrate-cycle-plan.sh`, `scripts/orchestrate-cycle-postflight.sh`
- Read of `scripts/orchestrate-batch-admit.sh`'s header and `scripts/orchestrate-predispatch-review.sh`'s
  header (Class E definition, advisory-vs-blocking posture)
- `git log --all -p --follow -- specs/TODO.md | grep -n "Piece 4"` to recover the original,
  since-rewritten "Piece 4" task text from task 272's history
- Read of task 274's full description (`specs/TODO.md` ~line 3588-3645) for the downstream
  alternatives-on-conflict consumer contract
- `jq`/`grep` checks confirming no live or archived task numbered 51 remains in
  `specs/state.json`; its artifacts (the files named above) are already present in the source
  store

**Key file paths for the planner**:
- `agent-system/extensions/core/scripts/task-lock.sh` (session registry + lock; extension point)
- `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh` (`session_contention`,
  `scopes_overlap_first` — reuse for the new refusal check)
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh:1200` (heartbeat call site)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (~line 41 register, ~line 295
  release)
- `agent-system/extensions/core/commands/orchestrate.md` (~line 204 session mint)
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` (Class Table —
  update when the queue's files are added)
- `agent-system/extensions/core/context/patterns/task-lock.md` (documentation standard to match)
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` (archive-convention precedent)
- `agent-system/extensions/core/scripts/tests/test-task-lock-liveness.sh` (fixture-test style to
  mirror)
