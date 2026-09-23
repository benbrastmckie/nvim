# Batch Orchestration Guardrails

This file documents the *principles* that govern admission control and batch composition for
batched `/orchestrate` invocations — when a guardrail must block dispatch, when it may merely
warn, how both answers should change (or not change) as batch size grows, and which open tasks
belong together in one batch in the first place. The *mechanisms* that implement these
principles already exist and are documented elsewhere; this file cross-references them by path
rather than restating their algorithms. This file defines no new behavior and changes no
skill, command, script, or agent file.

## Batching Is the Default: Selection Criteria and Conflict Resolution

`/orchestrate N[,N-N]` performs dependency-aware wave dispatch uniformly for a batch of one task
or many (see `commands/orchestrate.md`'s Constraints section). Because the mechanism is already
uniform, batching related open tasks into ONE `/orchestrate` invocation is the normal way to work
this system, not a specialized throughput optimization reserved for large backlogs. A single-task
invocation remains fully correct and unpenalized — it is simply the batch-of-one case of the same
mechanism, not a separate default posture.

### Why batch-as-default, not batch-as-optimization

The strongest argument for batching is not throughput — it is collision visibility. The three
admission layers documented below (creation-time overlap, runtime wave/cycle-split, lock
acquisition) can only compare tasks they can see together, within one invocation's candidate set
or the currently-held-lock set. Two related tasks dispatched from two separate `/orchestrate`
invocations are mutually invisible to every in-batch check — nothing retroactively notices they
should have been serialized. Batching is therefore the mechanism by which a real collision becomes
checkable at all; running related tasks apart does not avoid the collision, it only removes the
machinery's ability to see it.

### The three selection criteria

Three criteria inform which open tasks belong in one batch, and they do not always agree:

- **Shared file territory** — tasks whose declared `file_scope` (or otherwise known intent)
  overlaps in the files they touch.
- **Topic cohesion** — tasks sharing a `topic` field in `specs/state.json`, so one agent's
  research or implementation context warms the next.
- **Graph shape** — the shape of the batch's intra-batch dependency graph: a single connected
  component drains cleanly wave-by-wave, while a set of mutually independent tasks maximizes
  wave-1 width and therefore concurrency.

### The dominance rule

**Shared file territory > topic cohesion > graph shape (width).** Apply in this order:

1. **Shared file territory is mandatory, never optional.** If two open, non-terminal candidate
   tasks touch overlapping files, batch them together whenever both are realistic candidates for
   this invocation — even when doing so collapses the batch to width 1 (full serialization) and
   gains nothing from parallel dispatch except collision visibility. That visibility is a
   correctness property, not a throughput optimization, so it outranks width every time the two
   disagree.
2. **Topic cohesion beats width when filling remaining slots.** Once every territory-mandatory
   member is included, fill any open slots (subject to the batch-size cap below) with
   dispatch-safe same-topic candidates BEFORE adding any off-topic candidate. "Dispatch-safe"
   means non-terminal and not already blocked or held by a foreign lock. An off-topic candidate
   with no territory link to the batch may be added only as filler, once every dispatch-safe
   same-topic candidate is already in — this is a rule, not a judgment call: topic beats width.
   (An off-topic candidate that DOES share territory with a batch member is not filler — rule 1
   already made it mandatory, regardless of topic.)
3. **Graph shape is the residual tie-breaker**, applied only among candidates rules 1-2 already
   selected or left as ties. Prefer whichever addition widens wave 1 (adds a task with no
   in-batch dependency edge) over one that only extends an existing chain — but always include a
   dependent task whose sole prerequisite is already in the batch, since apart from that
   invocation the dependent cannot make progress at all. Wave dispatch handles a mixed graph
   (part chain, part independent singletons) correctly on its own; graph shape is a preference
   between otherwise-equal candidates, never a reason to exclude one.

**Worked resolution of the three pairwise conflicts:**

| Conflict | Winner | Why |
|---|---|---|
| Shared file territory vs. graph shape (width) | Territory | A collision left unbatched is invisible to every admission layer; width is a throughput preference, territory-driven serialization is a correctness requirement. |
| Shared file territory vs. topic cohesion | Territory (rarely actually conflicts) | Topic-cohesive tasks that also share territory were already going to be forced together by territory alone (or by the creation-time auto-`dependencies[]` edge — see `docs/reference/standards/multi-task-creation-standard.md`'s `### 4a. File Footprint Capture and Overlap Detection (Automatic)`); topic cohesion never has a reason to exclude a territory-mandatory task, since excluding it would only lose the visibility gain for no benefit. |
| Topic cohesion vs. graph shape (width) | Topic | Fill open slots with dispatch-safe same-topic candidates before any off-topic filler (rule 2 above). Width only decides ordering *among* the topic-cohesive candidates that pass the fill rule, or among off-topic filler once same-topic candidates are exhausted. |

### The batch-size cap (MAX_TASKS)

A batch is trimmed to its first 8 tasks (`MAX_TASKS=8`; see
`docs/architecture/orchestrate-state-machine.md`'s `### Batch Size Cap (MAX_TASKS)`) before
dispatch. Selection must respect this:

- Keep a proposed batch at 8 or fewer tasks.
- List territory-mandatory members (rule 1) first in the invocation's task-number list, so a trim
  to 8 can never split a territory-mandatory group off the end.
- If a single territory-mandatory group alone exceeds 8 tasks, it cannot be admitted as one
  invocation. Run it as consecutive batches in dependency order instead, and accept — explicitly,
  not silently — that cross-batch collision visibility is lost for the portion split across
  invocations; that loss is the same blind spot the "Why batch-as-default" argument above
  describes for any two tasks run apart.

### Territory is a human judgment, not a machine derivation (scope note)

This document's admission layers (below) derive collisions mechanically from `file_scope`; the
selection criterion here is different — it asks a human proposing a batch to recognize likely
shared territory *before* creation-time auto-edges or runtime admission ever run, since neither
mechanism exists to choose which tasks a human types into one `/orchestrate` invocation in the
first place. This section does not specify or depend on any machine derivation of "shared
territory" as a selection input — `file_scope` declaration granularity, backfill, and
absent-scope admission posture are owned by the file-scope-lifecycle topic and are out of scope
here. Where `file_scope` is undeclared or coarse, apply this criterion as ordinary human judgment
about which tasks are likely to touch the same code, not as a lookup against a machine-computed
set.

### Worked example

Five open tasks share `topic: "x"`: `A`, `B`, `C`, `D`, `E`. Two of them (`A`, `B`) declare
overlapping `file_scope`; a third (`C`) depends on `A`; `D` and `E` are unrelated to any of the
other four and to each other. Applying the rule above: `A` and `B` are mandatory together
(territory, rule 1) and listed first. `C` joins next — topic-cohesive, and its dependency edge to
`A` means it cannot dispatch usefully apart from the same invocation that resolves `A` (rule 3's
"always include a dependent whose prerequisite is already in the batch"). `D` and `E` are optional
adds — topic-cohesive and territory-clean, so batching them costs nothing and both widen wave 1
(rule 2's fill order, then rule 3's width preference). The batch stays at 5, under the cap. The
resulting invocation is `/orchestrate A,B,C,D,E`, whose intra-batch dependency graph is
`{A: [], B: [], C: [A], D: [], E: []}` — wave 1 dispatches `A, B, D, E`, wave 2 dispatches `C` —
and every territory-sharing pair (`A`, `B`) is visible to the admission layers because they were
batched together.

**Variant — territory beats topic.** Suppose a sixth task, `F`, shares no topic with `A`-`E` but
declares a `file_scope` overlapping `A`'s. Rule 1 is unconditional on topic: `F` is mandatory
alongside `A` regardless of the topic mismatch, giving `/orchestrate A,F,B,C,D,E` (territory-
mandatory members `A`, `F`, `B` listed first). `F` is not filler — it was never competing with `D`
or `E` for a slot; it was forced in by rule 1 before rule 2's fill order is even reached.

## The Three Existing Admission Layers

Batch admission control in this system is not a single check but three layers, each with a
different scan scope, that together approximate a combined optimistic-pre-check-plus-pessimistic-lock
concurrency strategy:

1. **Creation-time** — the pairwise directory-prefix overlap algorithm defined in
   `file-footprint-overlap.md` is run once across a batch of tasks proposed together at creation
   time, and a serializing `dependencies[]` edge is auto-added for every overlapping pair with no
   existing edge. Scan scope: the creation batch only.
2. **Runtime wave/cycle-split check** — before dispatching any wave or cycle containing 2+ tasks,
   the same overlap algorithm is re-applied to every pair already collected into *this
   invocation's* task set. On overlap with no `dependencies[]` edge, the lower-priority task
   (higher project number) is deferred to a later wave/cycle — never failed. Scan scope: this
   invocation's task set only.
3. **Lock-acquisition-time** — at per-task lock acquire, the acquiring task's `file_scope` is
   compared against every *other currently-held* lock's `file_scope`, repo-wide. A fresh
   overlapping foreign lock causes refusal; a stale one warns and proceeds. Scan scope: every
   currently-held lock, repo-wide.

A fourth, orthogonal dimension is layered on top of the batch-admission layer (layer 2's
cross-batch extension, `orchestrate-batch-admit.sh`): the **self-modification hazard** check. It
is not a new scan scope — it reuses layer 2's existing single-`specs/state.json`-read admission
call — but a different *predicate* evaluated on the same candidate before the pairwise overlap
scan runs at all: does the candidate's own `file_scope` name an orchestrator-critical file? See
"Self-Modification Hazard: The Fourth Admission Dimension" below for the full rationale.

Layers 1-2 are a cheap, no-agent-invoked, optimistic pre-check: they decide whether to even
attempt concurrent dispatch. Layer 3 is a pessimistic enforcement lock: it is the mutex that
actually prevents two concurrent writers. The layers are independently sound, but their scan
scopes do not overlap perfectly — a task that is neither in this invocation's set nor currently
holding a lock is invisible to layers 1-3 simultaneously. Closing that gap is a scan-scope
question, addressed under Non-Negotiables and the Open Design Fork below, not a new-check
question.

**A FIFTH, bounded input — the session registry — narrows this gap further, without eliminating
it.** Both layer 3 (`task-lock.sh`'s `cmd_acquire`) and the layer-2 cross-batch extension
(`orchestrate-batch-admit.sh`) now additionally consult `specs/.sessions/*.json` — a live
registered session's own precomputed, UNIONED `file_scope` across every task it covers (see
`file-footprint-overlap.md`'s "Three Contention Inputs" section for the full asymmetry between
this input and the other two). This closes a specific sub-case the state.json collision scan
alone could not: a session ACTIVELY WORKING a task whose declared `file_scope` alone would not
overlap the candidate, but whose session-wide UNIONED footprint (spanning several covered tasks
at once) does. **What remains genuinely invisible, by design, is narrower than before, and
precisely stated rather than left implicit: a task with no held lock, no live session currently
covering it, AND — the residual case worth naming explicitly — a TERMINAL status.** A terminal
task is excluded from ALL three inputs' scans on purpose (a completed/abandoned/expanded task
will not write anything and must never block dispatch), so this is an intentional non-goal, not
an accidental gap. A genuinely idle, NON-terminal task with no lock and no live session is NOT in
this residual set — its declared `file_scope` remains visible to `orchestrate-batch-admit.sh`'s
pre-existing `specs/state.json` collision scan regardless of lock or session state, exactly as it
was before the session-registry input was added. Do not read the session-registry addition as
having closed MORE than this: it adds one more live signal alongside held locks and
`state.json`, it does not change what `state.json` itself already made visible.

## Blocking vs. Advisory: The Criterion

A guardrail is **BLOCKING** — refuse to dispatch, i.e. defer — if and only if **both** of the
following hold:

1. It is computable purely from on-disk structural state, without invoking any agent.
2. The harm of proceeding anyway is silent and hard to detect after the fact (concurrent file
   corruption, acting on stale context, an unmet dependency treated as satisfied).

A guardrail is **ADVISORY** — warn, then continue — when either of these fails: the underlying
signal is inherently a heuristic or estimate rather than a hard fact, or the condition being
flagged is not this invocation's to fix. Advisory never means unlogged or silent; every advisory
signal must still surface a visible warning.

This is a conjunction of two conditions, not a single cost condition. A check that is cheap but
whose signal is a heuristic (for example, a drift-percentage estimate) is still advisory. A check
that is expensive but structural and silently-harmful if skipped is still blocking; cost alone
never demotes a check to advisory.

### Classification Table

| Guardrail | Classification | Why |
|---|---|---|
| File-scope overlap, `in_batch` (creation-time and runtime wave/cycle-split, colliding task is itself one of the invocation's candidates) | BLOCKING | On-disk `file_scope` comparison, no agent invoked; every `in_batch` candidate is imminently dispatched by construction, so an unserialized overlap risks silent concurrent-write corruption discovered only later |
| File-scope overlap, `cross_batch` (colliding task is NOT one of the invocation's candidates) | BLOCKING when the colliding task carries execution evidence (status in `researching`/`planning`/`implementing`); ADVISORY when it does not (NARROWED in `orchestrate-batch-admit-v5`, see `docs/architecture/batch-admit-schema.md`'s Version History) | An overlap against an IN-FLIGHT cross-batch task satisfies both halves of the criterion above exactly as the `in_batch` row does — computable from on-disk state, and the harm of skipping is a silent concurrent write, because that task really is running. An overlap against a provably IDLE cross-batch task (no execution evidence) satisfies neither: there is no second session to write concurrently — the colliding task simply is not running — so the residual concern is ORDERING, not concurrent-write corruption, and ordering is exactly what `dependencies[]` exists to express. That case is surfaced loudly via `idle_overlap_advisory` on an `admit` verdict rather than blocked, so it is never silent even though it does not block. |
| Held lock (lock-acquisition-time) | BLOCKING | On-disk lock state, no agent invoked; proceeding past a live lock risks the same silent corruption |
| Unmet predecessor (dependency-graph eligibility) | BLOCKING | On-disk dependency edge and terminal-status check, no agent invoked; treating an unmet dependency as satisfied is silent and hard to detect after the fact |
| Self-modification hazard (candidate `file_scope` names an orchestrator-critical path) | BLOCKING | Computable from the candidate's own on-disk `file_scope` against a fixed, declared critical-path list — no agent invoked; the harm (an unverifiable orchestrator-machinery fix committed automatically as part of a multi-task dispatch) is silent and hard to attribute later, satisfying both halves of the criterion |
| Heuristic drift-percentage signal | ADVISORY | The signal is an estimate from a fork's plan inspection, not a hard fact — fails condition 1's structural-fact requirement in spirit even though it reads on-disk state, because the *derived* percentage is inherently approximate |
| Absent completion-marker verification signal (`plan_markers_verified` missing or false) | ADVISORY | Per the handoff schema's own documented behavior, this warns but does not block the next lifecycle phase — the condition is logged, not gated, because it is deliberately designed as a non-blocking signal |
| Postflight completion-deploy gate (a source-store-touching task's own `modified_files` overlap `agent-system/extensions/**` AND the deploy is provably stale) | BLOCKING | Computable purely from on-disk state — the refusing task's own `.return-meta.json` `modified_files` plus a path-scoped `git log -1` freshness comparison, no agent invoked; the harm of proceeding (`[COMPLETED]` while the fix is absent from the running `.claude/` tree) is silent and discoverable only much later, as the research for this mechanism found for four already-completed tasks — satisfying both halves of the criterion exactly as the Self-Modification Hazard row above does |

## Ordering Constraint vs. Exclusion: The Normative Principle

Orthogonal to the Blocking vs. Advisory axis above (which governs whether a guardrail refuses
dispatch AT ALL) is a second axis: when a guardrail DOES refuse, does that refusal resolve on its
own as the system keeps running (an ORDERING CONSTRAINT — defer to a later wave/cycle/invocation)
or does it persist for the lifetime of the current run with no mechanism that clears it (a genuine
EXCLUSION)? **The normative principle this repository holds every admission gate to: a guardrail
should degrade to an ORDERING CONSTRAINT whenever possible, and fall back to a genuine EXCLUSION
only when the exclusion itself is a deliberate, justified safety property — never as an
accidental consequence of a gate's implementation shape.** An exclusion that exists only because
nothing was built to clear it is a defect, not a safety margin; the eligibility-status-gating and
self-modification-deadlock defects this repository has fixed were exactly this shape.

### Gate Catalogue (post-fix)

| Gate | `defer_reason` | Classification | Why |
|---|---|---|---|
| `self_modifying` | `self_modifying` | ORDERING CONSTRAINT | The designated-candidate tie-breaker inside `orchestrate-batch-admit.sh` admits exactly one self-modifying candidate — the lowest task number — every cycle; N co-dispatched self-modifying candidates converge to full dispatch in at most N cycles by construction (see "Self-Modification Hazard" below and `docs/architecture/batch-admit-schema.md`'s tie-breaker documentation). Formerly a de facto EXCLUSION for any 2+ self-modifying co-dispatch, since nothing broke the tie and the guard's only "remedy" was re-running affected tasks in isolation — this is the fixed defect the normative principle above names. |
| `file_scope_collision`, `collision_scope: "in_batch"` | `file_scope_collision` | ORDERING CONSTRAINT | Self-clears once the colliding in-batch task leaves `eligible_tasks` by terminating or failing — see "The Same-Cycle Narrowing and Its Hazard Accounting" above for the two-clause distinction this claim rests on. |
| `file_scope_collision`, `collision_scope: "cross_batch"`, colliding task carries execution evidence | `file_scope_collision` | ORDERING CONSTRAINT (does not self-clear WITHIN this invocation, but is not a permanent whole-invocation exclusion either — a later invocation re-evaluates once the colliding task's status independently changes) | A human resolves batch composition; the candidate is excluded from THIS run only, never permanently barred from ever running. |
| `file_scope_collision`, `collision_scope: "cross_batch"`, colliding task provably idle | (admits, with `idle_overlap_advisory`) | Not a defer at all (NARROWED in v5) | No second session to concurrently edit anything, so nothing is lost by admitting; the suppressed overlap is surfaced loudly rather than silently — see `docs/architecture/batch-admit-schema.md`'s Version History. |
| `session_active` | `session_active` | ORDERING CONSTRAINT | Clears once the contending session releases or its registry entry goes stale — the same convergence `file_scope_collision` already relies on. |
| Held lock (lock-acquisition-time, `task-lock.sh acquire` exit 1) | n/a (not an `orchestrate-batch-admit.sh` verdict; a Stage MT-4 dispatch-time refusal) | ORDERING CONSTRAINT | A fresh foreign lock defers the task out of THIS cycle's dispatch batch only (never added to `failed_tasks`); a stale lock is reclaimed with a warning, not refused at all. |
| `deploy_checkpoint` (inter-cycle redeploy checkpoint failure, branches (a)/(b)) | n/a (a whole-remaining-invocation defer, not a per-task `orchestrate-batch-admit.sh` verdict) | GENUINE, DELIBERATE EXCLUSION | The one gate this repository does NOT narrow to an ordering constraint, and this is correct: a failed or unverifiable redeploy of orchestrator machinery itself genuinely requires human remediation before ANY further dispatch in this invocation can be trusted. Unlike `self_modifying`'s former deadlock, there is no self-clearing condition to wait for — the system cannot safely make forward progress on unverified machinery, so continuing to defer-and-retry would just repeat the same failure every cycle at real cost. This exclusion is deliberate infra-safety, not an accidental byproduct of an under-built convergence mechanism. |
| `blocked` classifier verdict, discharged (`dependencies[]` all `status: "completed"`, no handoff blockers) | n/a (not an `orchestrate-batch-admit.sh` verdict; a `orchestrate-triage-classify.sh` verdict) | ORDERING CONSTRAINT | Self-clears as soon as the classifier next runs after the predecessor's `status` write lands; the dependent is dispatched to the phase its `previous_status` names, converged for both engines. This IS the fix this file's own normative principle already implied before it existed as code: the `blocked` classifier verdict's former unconditional `skip` was never a deliberately justified exclusion for this sub-case, it was an accidental byproduct of the classifier never having been taught to look past the status string. |
| `blocked` classifier verdict, NOT discharged (dependency outstanding, empty `dependencies[]`, a dependency stuck non-completed-terminal, or handoff blockers present) | n/a (not an `orchestrate-batch-admit.sh` verdict; a `orchestrate-triage-classify.sh` verdict) | Whatever the non-discharged classification already is (`skip` for `mt`, `needs_human` for `single`) — a documented, independently-implemented single/mt divergence, not an accidental exclusion | Both engines independently implement this divergence in their own handlers (single-task Stage 4's `blocked` handler always escalates; Stage MT-4's grouping table folds the non-discharged sub-case into `skip` so siblings can proceed) — see `orchestrate-triage-classify.sh`'s own audit discriminator for why independent implementation by both sides reads as design, not a bare shared-table assertion. This row is recorded explicitly here so it is never later misread as an accidental omission from this catalogue. |
| Unmet predecessor (dependency-graph eligibility) | n/a (not an `orchestrate-batch-admit.sh` verdict; a Stage MT-3 step 3 eligibility-gate exclusion) | ORDERING CONSTRAINT | Matches how the Blocking-vs-Advisory table above already classifies this same guardrail (BLOCKING); folded in here so the two tables stop disagreeing by omission. A task excluded from `eligible_tasks` because a predecessor is still in-progress is re-admitted automatically once that predecessor reaches a terminal state — no separate mechanism is needed to clear it. |

`defer_reason` values are echoed verbatim from what `orchestrate-batch-admit.sh` actually emits
(per that script's own header and `docs/architecture/batch-admit-schema.md`'s schema) — a
catalogue naming a gate the script does not emit would be a new false premise of exactly the kind
this file exists to prevent.

## Self-Modification Hazard: The Fourth Admission Dimension

A candidate task whose declared `file_scope` names a file that is itself part of the orchestrator
machinery — the dispatch loop, the admission predicate, the lock, the status gatekeeper — poses a
qualitatively different hazard than an ordinary file-scope collision: the running session that
would admit, commit, and grade that fix is the very machinery the fix changes. This section
records the two tests used to decide which files belong on that list, not merely today's answer,
so a future reader can judge a *newly proposed* file rather than pattern-match on the names below.

### The Two Conjunctive Tests

A file belongs on the critical-path list if and only if **both** hold:

1. **Reachability** — the file is actually read or executed on the MULTI-TASK batch-dispatch
   path. Single-task `/orchestrate` never has siblings to worry about, so a file that is only
   reachable there is out of scope for this specific gate (it may still be sensitive for other
   reasons, but this gate exists to protect *concurrent, batched* dispatch).
2. **Decision-relevance** — a defect in the file yields a silent WRONG admission, wave, lock, or
   completion decision, not a loud failure and not a merely cosmetic one. A file that would fail
   loudly (aborting the run) or that only affects reporting/formatting fails this test even if it
   is reachable.

Both tests must hold. A file that is reachable but not decision-relevant, or decision-relevant
but not reachable from MT dispatch, is excluded.

### Inclusion Table (nine files, with per-file evidence)

Re-applied at the narrowing that added the `scripts/verify-deploy.sh` row below: the other files
already in the table at that time were re-confirmed against both conjunctive tests and were
UNCHANGED — no row's reachability or decision-relevance verdict differed from the prior
evaluation. (The table originally carried a tenth row, a separate one for the standalone
hard-mode engine; that engine has since been merged into `skill-orchestrate/SKILL.md` and
deleted, so its row was folded into row 1 above rather than kept as a separate entry — the table
is nine rows today, not ten.)

| # | Path (relative to the core extension root) | Reachability evidence | Decision-relevance evidence |
|---|---|---|---|
| 1 | `skills/skill-orchestrate/SKILL.md` | The multi-task dispatch state machine itself — Stages MT-1 through MT-5 ARE the MT batch-dispatch path, covering both effort modes (the formerly-separate hard-mode engine, which used to inherit and extend MT-1..MT-5 for `/orchestrate --hard` batch runs, has been merged into this same file and deleted) | A defect here silently mis-routes eligibility, wave/cycle admission, or postflight status — the core decision surface, for both effort modes now that there is only one file |
| 2 | `commands/orchestrate.md` | The command entry point that parses flags and invokes `skill-orchestrate` for MT dispatch; the admission predicate itself is invoked solely at Stage MT-3 step 4.5 (row 1) | A defect here silently breaks flag threading into the delegation context, e.g. dropping a key `skill-orchestrate` reads |
| 3 | `scripts/skill-base.sh` | Sourced by preflight/postflight for every dispatched task in a batch | A defect silently corrupts the preflight/postflight/completion-claim gate for every task in the batch, not just one |
| 4 | `scripts/task-lock.sh` | Acquired/released per task inside MT dispatch (Stage MT-4) | A defect silently breaks the concurrency mutex itself — the last line of defense against two tasks writing the same files |
| 5 | `scripts/update-task-status.sh` | Invoked by postflight for every task a batch dispatches | A defect silently writes a wrong status transition, corrupting `state.json` for the whole batch |
| 6 | `scripts/orchestrate-batch-admit.sh` | THE admission predicate this gate itself extends; called once per wave/cycle | A defect here is maximally silent: it IS the mechanism deciding admission, so a bug in it defeats the very check meant to catch bugs like it |
| 7 | `scripts/orchestrate-triage-classify.sh` | Called once per MT cycle (Stage MT-4) to route tasks to research/plan/implement | A defect silently misroutes a task to the wrong lifecycle phase |
| 8 | `scripts/orchestrate-cycle-plan.sh` (`--dry-run` mode) | Composes the `--dry-run` report human operators trust to preview a live run | A defect silently misrepresents what a live run would actually do, undermining the one human-facing verification surface for batch composition |
| 9 | `scripts/verify-deploy.sh` | Executed directly from Stage MT-3 step 7 on the MT dispatch path (the inter-cycle redeploy checkpoint) | A defect causing a false PASS is silent and lets a broken deploy be treated as verified — matching row 6's own "a bug in it defeats the very check meant to catch bugs like it" language |

### Exclusion Table (explicitly excluded, with evidence)

**Excluded on the skill's own explicit statement / zero-reference grep** (fails reachability):

| Path | Evidence |
|---|---|
| `scripts/command-gate-in.sh` | `skills/skill-orchestrate/SKILL.md` states explicitly that MT dispatch never sources the single-task gate-in/gate-out scripts — the MT path has its own Stage MT-1/MT-2 initialization instead |
| `scripts/command-gate-out.sh` | Same explicit statement as above — MT dispatch never sources it |
| `scripts/orchestrator-postflight.sh` | Zero references anywhere in `skills/skill-orchestrate/SKILL.md` (confirmed by grep at authoring time) — this script belongs to a different command's postflight, not MT dispatch |

**Reachable but not decision-relevant** (fails decision-relevance — these files are read on the
MT path but a defect in them fails loudly or is merely cosmetic, not a silent wrong decision):

| Path | Evidence |
|---|---|
| `scripts/generate-todo.sh` | Regenerates the human-facing `TODO.md` view from `state.json` — a defect produces a visibly wrong rendered file, not a silent wrong admission/wave/lock/completion decision |
| `scripts/validate-artifact.sh` | Validates artifact format/presence — a defect fails loudly (a validation error) rather than silently corrupting a scheduling decision |
| `scripts/lifecycle-notify.sh` | A notification/logging hook — a defect at worst drops or garbles a notification; it does not feed back into any admission, wave, lock, or completion decision |
| `scripts/deploy-headless.sh` | Executed from Stage MT-3 step 7 immediately before `verify-deploy.sh`, so it is reachable on the MT dispatch path, but its primary failure mode is loud (`exit 1`/`2`, triggering the documented failure-path warning and `deferred_deploy_checkpoint` population) — matching the exclusion rationale already used for `validate-artifact.sh` above. Judged call, not an unconsidered omission: a hypothetical silent partial-sync defect (some files copied, some not, exit 0 anyway) would clear decision-relevance and belong in the Inclusion Table instead; the current implementation's failure mode is the loud one, so it stays here. |

### The Deploy-Manual Analysis and the Surviving Hazards

The research behind this gate initially hypothesized that a source-store edit to orchestrator
machinery could corrupt the *currently running* session. That hypothesis does not hold: this
repository's core extension deploys manually (a human runs `<leader>al` -> `[Reload All]` or
`[Regenerate]` to regenerate `.claude/` from `agent-system/extensions/core/`), so a source-store
edit cannot alter a session already in flight. That reversal does not cancel the gate — it redefines what the gate
actually protects. Of the three hazards this reasoning originally identified, hazard 2 below is
now **RETIRED**; hazards 1 and 3 remain live and are the actual, surviving rationale for keeping
this gate:

1. **Verification-gap risk** (live) — a fix to orchestrator machinery is necessarily verified only
   against a scratch deploy-tree copy (per this plan's own SOURCE-STORE RULE), never against the
   live, running system it will eventually become. That gap is real regardless of whether
   redeploy is immediate or manual.
2. **Rollback/commit-granularity risk — RETIRED.** This hazard previously read: "a multi-task
   batch commit mixes N tasks' index rows and diffs into one commit. If the self-modifying task's
   change needs to be reverted, isolating it from sibling tasks' unrelated changes in the same
   commit is harder than it would be for a solo, single-task commit." That batch commit no longer
   exists: MT mode now issues one scoped commit per task per phase transition, inside
   `skill-orchestrate`'s own per-task postflight loop (Stage MT-4 step 5.5), at the same
   granularity a solo run produces — see `docs/architecture/orchestrate-state-machine.md`'s
   "Commit Granularity" subsection. A self-modifying task's change is therefore isolated in its
   own commit, never mixed with a sibling task's diff. **Stated residual, not total elimination**:
   each per-task commit still stages `specs/state.json` and `specs/TODO.md`, which legitimately
   carry other tasks' current index rows (they are shared, wholesale-regenerated index files);
   `--honest-index-rows` labels this in the commit message. This is a labeled, honest residual, not
   a defect, and it does not revive this hazard — reverting a self-modifying task's commit still
   isolates that task's own source-store diff from every sibling's.
3. **Bootstrapping risk — PARTIALLY RETIRED, replaced by a narrower mid-invocation script-swap
   exposure.** This hazard previously read: admission for the task rewriting the admission
   predicate (or any of the other eight files) is decided by the OLD, currently-deployed copy of
   that same machinery. A defect the new candidate is trying to fix cannot fix its own admission
   decision; only a solo run followed by a manual redeploy breaks that circularity. That framing
   is now split into three parts:
   - (i) **Structurally impossible, on a premise that has since changed**: the in-batch,
     correctly-declared form — a candidate whose declared `file_scope` names a critical path,
     admitted alongside a `dependencies[]`-edge-connected sibling in the same invocation — remains
     structurally impossible, but the REASON changed. It previously read on the self-modification
     admission gate excluding such a candidate from the **whole invocation** (the old, never-reset
     `deferred_self_modifying` exclusion set); that premise no longer holds — see "### The
     Same-Cycle Narrowing and Its Hazard Accounting" above. The claim survives on a narrower,
     already-sufficient premise instead: Stage MT-3 step 3's eligibility rule guarantees an
     edge-connected successor is never eligible in the same cycle as its predecessor, regardless of
     the self-modification gate's own scope. "W0 fixes it, W1 still runs stale" still cannot happen
     for a correctly-declared, edge-connected candidate — it just was never actually the
     self-modification gate's whole-invocation scope doing that work.
   - (ii) **The two residual forms the inter-cycle redeploy checkpoint retires**: **declared/actual
     divergence** — a task whose declared `file_scope` does not name a critical path but whose
     actual `modified_files` do, invisible to a gate that only reads `file_scope` pre-dispatch —
     and **cross-invocation staleness** — a correctly-excluded task is later re-run solo, commits
     its fix, and nothing redeploys it before the next invocation picks up stale machinery.
   - (iii) **The replacement exposure, named as such**: seven of the nine critical paths
     (`scripts/skill-base.sh`, `scripts/task-lock.sh`, `scripts/update-task-status.sh`,
     `scripts/orchestrate-batch-admit.sh`, `scripts/orchestrate-triage-classify.sh`,
     `scripts/orchestrate-cycle-plan.sh`, `scripts/verify-deploy.sh`) are shell scripts
     re-invoked via a fresh `bash .claude/scripts/X.sh` subprocess at every use site, so they
     genuinely re-read on-disk bytes; the remaining two (`skills/skill-orchestrate/SKILL.md`,
     `commands/orchestrate.md`) are read once into the
     orchestrator's context at dispatch time and are unaffected for the current turn. A mid-run
     redeploy therefore genuinely swaps executing machinery mid-flight for the seven script paths.
     This is the **same underlying verification-gap tension as hazard 1, now manifesting
     mid-session rather than only cross-session** — not an independent fourth hazard. See
     `### The Inter-Cycle Redeploy Checkpoint` below for the mechanism that retires (ii) and
     contains (iii).

A later maintainer must not read the disproven live-corruption hypothesis as license to relax or
remove this gate — hazard 1 remains fully live and hazard 3 remains partially live (its
replacement exposure, per (iii) above); together they are, on their own, sufficient rationale to
keep it. Hazard 2 is retained here in retired form, not deleted, so a later reader can see what
changed and why; hazard 3 is now retained in the same style, split into its retired and surviving
parts rather than being deleted either.

### The Same-Cycle Narrowing and Its Hazard Accounting

**The two-clause distinction this section's "structurally impossible" claims rest on**: Stage
MT-3 step 3's eligibility rule historically carried two INDEPENDENT clauses — (1) all
predecessors in the dependency graph are terminal (the DEPENDENCY-TERMINAL-STATE clause), and (2)
status is not `{researching, planning}` (the former IN-FLIGHT-STATUS clause). Every
"structurally impossible" claim in this section — the edge-connected-pair-can-never-co-occupy
argument the paragraph immediately below relies on, and the A1 resolution's dead-code argument
further down — rests SOLELY on clause (1), which no change in this repository's eligibility-gate
work has ever touched. Clause (2) has since been REMOVED entirely (eligibility is no longer
status-gated on an in-flight string at all — see
`skills/skill-orchestrate/SKILL.md` Stage MT-3 step 3), and its removal falsifies none of the
claims here, because none of them ever depended on it. A future reader auditing this section
after any eligibility-rule change should re-derive which of the two clauses (if either survives
under a new name) a given claim actually rests on, rather than assuming "the eligibility rule"
is a single atomic fact.

The self-modification defer originally excluded a candidate from the WHOLE invocation whenever
`--invocation-count` exceeded 1 — never merely from the wave/cycle it was actually co-dispatched
in. That whole-invocation scope has been narrowed to the candidate's actual same-cycle co-dispatch
count (`${#eligible_tasks[@]}` at the skill's own call site), because a
`dependencies[]`-edge-connected pair can never share that count in the first place — Stage MT-3
step 3's eligibility rule guarantees a successor is never eligible until its predecessor leaves
the non-terminal set — so the whole-invocation count fired against pairs that could never
actually co-occur in a dispatch batch. That was a pure false positive, not a safety margin, and
removing it removes no protection against any of the three hazards above.

**Which hazard each unit of remaining strictness pays for, stated per hazard**:

- **Hazard 2 (rollback/commit-granularity) — RETIRED, and whole-invocation scope was never this
  hazard's mitigation anyway.** Once MT mode moved to one scoped commit per task per phase
  transition (Stage MT-4 step 5.5), the commit-granularity concern the original whole-invocation
  scope might have incidentally helped with was already resolved by a DIFFERENT mechanism. The
  narrowing does not touch this hazard's retired status either way.
- **Hazard 3's in-batch form — RETIRED, and whole-invocation scope WAS this form's mitigation, now
  replaced.** The old whole-invocation exclusion is exactly what made "a self-modifying candidate
  admitted alongside a sibling in the same invocation" structurally impossible. The narrowing
  removes that specific protection — but does not reopen the hazard, because same-cycle
  eligibility exclusion (Stage MT-3 step 3) already makes the in-batch, correctly-declared form
  structurally impossible on its own: an edge-connected successor is never eligible in the same
  cycle as its predecessor, narrowed scope or not. The over-protection here was scope wider than
  the eligibility rule already required, not a hazard the wider scope alone was holding back.
- **Hazard 1 (verification gap) — LIVE, and UNAFFECTED BY THE SCOPE CHOICE IN EITHER DIRECTION.**
  A fix to orchestrator machinery is verified only against a scratch deploy-tree copy regardless
  of whether the defer is scoped to the whole invocation or to one cycle — the gap is about
  WHERE verification happens, not how widely a defer excludes a candidate. This is precisely why
  hazard 1 is not itself an argument for whole-invocation scope: it does not distinguish the two
  scope choices. It IS the reason some gate must survive at some scope, which is why this task
  narrows the defer rather than removing it.

**A1 resolution — the dependency-edge exemption asymmetry is explained, not remedied.** The
collision dimension (`file_scope_collision`) excludes from its comparison set any task connected
to the candidate by a `dependencies[]` edge in either direction. The self-modification dimension
applies no equivalent exemption, and this is deliberate, not an oversight: the collision
dimension's comparison set spans EVERY non-terminal task in `specs/state.json` — including tasks
far outside the current wave/cycle — where an edge-connected pair genuinely can and does collide
if left unexempted (an out-of-batch predecessor sitting in `implementing` for many cycles is a
real, live comparison target). The self-modification dimension's comparison, by contrast, is now
scoped to `${#eligible_tasks[@]}` — the current cycle's actual co-dispatch set — and Stage MT-3
step 3's eligibility rule already guarantees an edge-connected pair can never occupy that set
together. An explicit dependency-edge exemption in the self-mod branch would therefore be
unreachable dead code: the condition it would guard against cannot occur once the count is
same-cycle-scoped. The asymmetry between the two dimensions is real, but it is load-bearing only
on the collision side, where the wider comparison set makes the edge case reachable; it is not a
gap in the self-modification check.

**The `--allow-self-modifying` override — recorded, default off.** Name:
`--allow-self-modifying`. Default: off (`"false"`), threaded through
`scripts/parse-command-args.sh`'s scan and strip chain exactly like every other boolean flag, and
read at the consumer (`skill-orchestrate/SKILL.md` Stage MT-3 step 4.5, covering both effort
modes now that the formerly-separate hard-mode engine's own transcription has been merged in and
deleted) — never passed to `orchestrate-batch-admit.sh`, which
always computes and emits the verdict honestly regardless of the flag. Justification for the
default: the narrowing itself trades a HUMAN-PACED solo re-run (where a person decides when to
redeploy after a self-modifying fix) for a self-modifying candidate now potentially running
inside ONE automated invocation, where the inter-cycle redeploy checkpoint auto-redeploys and
auto-verifies with ZERO human review in between. That is precisely the kind of automation hazard
1 warns is uniquely risky for an unverified orchestrator-machinery fix — a fix verified only
against a scratch deploy-tree copy, now also auto-deployed without a human looking at it first.
The override flag is framed as a deliberate, per-invocation, human-intent escape hatch for the
residual co-dispatch case (a genuinely co-dispatched self-modifying candidate that a human has
decided, this one time, should run anyway) — never as a general-purpose weakening of the gate.

### Scope Limitation and Residual Risk

**Corrected (this passage was stale)**: plain multi-task `/implement N,M`, `/research N,M`, and
`/plan N,M` are NOT blind to `orchestrate-batch-admit.sh` — each already runs a Batch Admission
Pre-Check (Step 2.5, "Gap C") that calls it over the whole validated candidate set with
`--invocation-count "${#validated_tasks[@]}"`, so a self-modifying candidate co-dispatched
alongside another candidate in the same plain multi-task batch IS deferred by this gate, exactly
as an `/orchestrate` co-dispatch is. What remains genuinely `/orchestrate`-only is the
**same-cycle narrowing** described above, not gate visibility itself — see the next paragraph.

**Decision, restated after the same-cycle narrowing: restate the acceptance, do not extend
protection.** The narrowing this document records above does NOT transfer to plain multi-task
`/implement`, `/research`, or `/plan` by analogy, and the reason is specific to what those
commands lack, not a general judgment that they are lower-risk. The narrowed self-modification
trigger is counted against `${#eligible_tasks[@]}` — a per-CYCLE co-dispatch set produced by
`/orchestrate`'s own Kahn-ordered wave/cycle machinery (Stage MT-3 steps 1-4). Plain multi-task
`/implement N,M`, `/research N,M`, and `/plan N,M` have no wave or cycle computation at all: no
Kahn ordering, no per-cycle eligibility re-evaluation, no concept of "this cycle's co-dispatch
set" for a narrowed trigger to be counted against. There is therefore no unit the narrowing could
even be expressed in for those commands — extending equivalent protection would require first
introducing a wave/cycle concept those commands do not have, which is a materially larger change
than narrowing an existing trigger. A future reader must not assume the narrowing implicitly
covered plain multi-task commands merely because it narrowed the analogous check inside
`/orchestrate`; a follow-up task would be required to extend equivalent protection to those
commands, should that ever be judged necessary. **This conclusion is specific to the
self-modification-hazard trigger and is unaffected by the file_scope-collision two-pass structure
described immediately below** — the two are orthogonal admission dimensions (see "The Three
Existing Admission Layers" above), and closing one's plain-multi-task gap has no bearing on the
other's.

**The `file_scope_collision` `in_batch` case, by contrast, NOW has a bounded plain-multi-task
analogue.** `commands/research.md`'s, `commands/plan.md`'s, and `commands/implement.md`'s Step
2.5 splits `defer_reason == "file_scope_collision"` by `collision_scope`: an `in_batch` hit is
re-sequenced into a new Step 3.5 (Second Pass) that re-runs `orchestrate-batch-admit.sh` over
exactly the deferred singleton/subset, rather than being dropped straight to `skipped_tasks` the
way it always was before. This is bounded at EXACTLY ONE extra pass — never a wave/cycle loop,
never more than the one bonus attempt `/orchestrate`'s multi-cycle machinery can make across many
cycles — and a task still deferred after that one extra pass lands in `skipped_tasks` with the
`"deferred after second pass"` reason, reporting the invocation's overall status as `partial`
rather than a hard failure. See `context/patterns/task-lock.md`'s "Four-Tier Conflict Response"
section (Tier 1) for the full mechanism and `context/patterns/multi-task-operations.md`'s
two-pass specification for the exact structural bound. Every other `file_scope_collision`
flavor (`cross_batch`) and every other defer flavor (`self_modifying`, `session_active`) keeps
the pre-existing single-pass exclude-to-`skipped_tasks` behavior verbatim — only the `in_batch`
file-scope case gained resequencing, and only within the current invocation's own candidate set,
never expanded to pull in an out-of-batch predecessor.

The batch-commit staging gap previously noted here — that the retired end-of-batch commit did not
stage an implementation agent's self-reported `modified_files` per task — is now closed: the
per-task commit described under hazard 2's retirement above stages each task's own `modified_files`
via the same contract single-task `/implement` uses (`context/standards/git-staging-scope.md`'s
"Multi-Task Application" subsection).

### The Inter-Cycle Redeploy Checkpoint

This subsection is the single, authoritative statement of the inter-cycle redeploy checkpoint
contract. Every other file that mentions the checkpoint (`regeneration-is-manual-only.md`,
`skills/skill-orchestrate/SKILL.md`, `docs/architecture/orchestrate-state-machine.md`,
`scripts/deploy-headless.sh`, `scripts/verify-deploy.sh`) cross-references this subsection by path
rather than restating it.

**Trigger**: the union of every task dispatched this cycle's actual `modified_files`, compared
against the `scope_roots x critical_paths` expansion of
`context/reference/orchestrator-critical-paths.json` using the directory-prefix overlap predicate
in `context/patterns/file-footprint-overlap.md` (both referenced by path, never restated here).
Non-empty overlap fires the checkpoint.

**Why `modified_files` and not `file_scope`**: the admission gate already performs the
`file_scope` check pre-dispatch (see the Self-Modification Hazard section above); using
post-dispatch `modified_files` is strictly more precise and closes the declared/actual divergence
gap named under hazard 3 above. The cost is a single jq comparison, since the array is already in
scope at Stage MT-4 step 5.5 of `skill-orchestrate/SKILL.md`.

**Rejected alternatives, recorded so a later pass cannot rediscover them**:
- **"Always redeploy between cycles"** — rejected. It imposes an unjustified deploy/verify cost
  on every cycle of every batch regardless of relevance, and it maximizes the script-swap window
  named in (iii) above rather than minimizing it.
- **A bare user-supplied opt-in flag** — rejected. It defeats `/orchestrate`'s zero-synchronous-
  confirmation-gates design (see Divergence from External Practice above): the operator cannot
  know in advance which cycle will touch a critical path, so an opt-in flag either fires on every
  invocation (equivalent to the first rejected alternative) or is never set when it matters.

**Considered and found ALREADY SATISFIED — redeploy-boundary serialization ("Direction 3")**: a
proposal to explicitly HOLD the redeploy checkpoint until every in-flight sibling task reaches a
cycle boundary, so no dispatched sibling could ever run against a script mid-swap. This is
distinct from "rejected" above — it is not a bad idea, it targets a hazard that provably cannot
occur under this system's existing architecture, so building it would add complexity with no
behavioral effect. Dispatch is CYCLE-SYNCHRONOUS by construction: the Stage MT-4 BATCHING RULE
requires every cycle's Agent tool calls to be issued in a single orchestrator message and their
handoffs read only after ALL of them return (Stage MT-3's "COMPLETION SEQUENCING" note), and
every dispatched task's own scoped commit (Stage MT-4 step 5.5) lands, unconditionally, BEFORE
the Stage MT-3 step 7 redeploy checkpoint for that same cycle ever evaluates (see "Sequencing"
above). There is no cross-cycle concurrency for the checkpoint to race against: by the time a
redeploy fires, every sibling dispatched in that cycle has already returned and committed, and no
sibling from a FUTURE cycle has been dispatched yet. "Hold the redeploy until in-flight siblings
reach a cycle boundary" is therefore already what happens, by construction, on every cycle — there
is no window in which the redeploy could run while a sibling remains mid-dispatch. **No follow-up
task is owed.** This finding is recorded here specifically so a later pass does not re-propose
Direction 3 without first re-deriving this cycle-synchronicity argument.

**Failure contract**: the two gates are asymmetric and are evaluated in three branches.

- **(a) `deploy-headless.sh` exit 1 or 2 (the deploy did not land)** — defer all remaining
  not-yet-dispatched tasks for the rest of the invocation, unconditionally, with NO baseline
  consultation whatsoever. A redeploy that did not complete has no meaningful "pre-existing"
  interpretation; this branch is unchanged from before the baseline mechanism existed. **Exit 3 is
  deliberately EXCLUDED from this branch**: it means the deploy LANDED but the inline
  `verify-deploy.sh --skip-slow` check reported one or more findings, which routes to the
  baseline-relative comparison in (b)/(c) below, never here. Both consumers of this contract
  (`scripts/command-gate-out.sh`'s `rc==6` handler and `scripts/orchestrate-cycle-plan.sh`'s
  inter-cycle redeploy checkpoint) now source ONE shared implementation of the (b)/(c) baseline
  comparison, `scripts/lib/deploy-baseline-lib.sh` (`deploy_findings_snapshot`,
  `deploy_baseline_new_findings`), so they cannot re-diverge the way `orchestrate-cycle-plan.sh`
  previously did — it long implemented only two of these three branches, collapsing exit 3 into
  branch (a) rather than reaching (b)/(c) at all, until this defect class was closed.
- **(b) `verify-deploy.sh` failure with at least one CONFIRMED, ATTRIBUTABLE newly-introduced
  finding** relative to the pre-redeploy baseline (see **Baseline mechanism** and
  **Confirmation and attribution filters** below) — defer all remaining not-yet-dispatched tasks
  for the rest of the invocation, unchanged in spirit from the pre-baseline contract, now
  evaluated at finding-level rather than exit-code-level granularity, and now requiring that a
  candidate new finding survive BOTH filters before it may defer anything. The defer message
  (stderr) and the `mt_state_file.defer_ledger` entry's `detail` field both name the specific
  blocking finding(s) verbatim — an operator reading either no longer has to re-run the whole
  gate by hand to discover what was new.
- **(c) `verify-deploy.sh` failure whose findings are ALL already present in the pre-redeploy
  baseline, OR whose every candidate new finding was shown flaky or unrelated to this batch's own
  modified files** — proceed to the next cycle, reported just as loudly as an outright failure.
  This is the third operator-visible state: "we checked, it's broken, it was ALREADY broken
  before this redeploy (or the apparent new breakage isn't real/isn't ours), and we proceeded
  deliberately." It is announced via a banner, a machine marker, and a durable
  `mt_state_file.verify_deploy_baseline_notices` record (see `skills/skill-orchestrate/SKILL.md`'s
  Stage MT-3 step 7 and Stage MT-5 for the mechanism, and
  `context/patterns/orchestrate-batch-results-template.md` for the rendering, emitted by
  Stage MT-5). A baseline must never become a mechanism for quietly swallowing failures — branch
  (c) exists to make a pre-existing or unattributable failure MORE visible, never less. The
  notice's own `filtered` field distinguishes the two ways this branch can be reached: `false` for
  the original, temporally-pre-existing case (no candidate new finding at all), `true` for the
  filtered sub-case (a candidate new finding existed but was confirmed flaky or shown unrelated) —
  the notice also then carries `flaky_count`/`flaky_findings` and/or
  `unrelated_count`/`unrelated_findings` so the filtered-out findings remain visible, never
  silently discarded.

**Confirmation and attribution filters (Defect C — the batch-deferral-attribution fix)**: a
candidate new finding (present post-redeploy, absent pre-redeploy) is passed through two
ADDITIVE filters, in order, before it is allowed to reach branch (b) at all. This extends branch
(c)'s existing "a pre-existing, unrelated red gate must not defer the whole batch" philosophy
from *temporally* pre-existing (identical in both snapshots) to *causally* unattributable (a
candidate new finding this batch still did not cause):

1. **Confirmation** (`deploy_baseline_confirm_new_findings` in `scripts/lib/deploy-baseline-lib.sh`)
   — take ONE additional `verify-deploy.sh --findings` snapshot, at the same full depth as the
   pre/post pair, and keep only candidate findings that REPRODUCE on this re-run. A candidate
   that does not reproduce is dropped as flaky. This directly targets the checkpoint's own
   self-inflicted-load hazard: the checkpoint runs a full deploy plus the entire shell test suite
   immediately before taking its post-redeploy snapshot, which is itself enough ambient load to
   flake a load-sensitive test in that same suite (observed: `test-lake-build-guard.sh`, known
   load-sensitive per its own "pressured fixture" and prior isolation commit). A real breakage
   reproduces on a now-settled re-run; a load-induced flake does not. This filter can only
   SHRINK the candidate set, never grow it, so it cannot weaken the gate against genuine
   regressions.
2. **Attribution** (`deploy_baseline_unattributable_findings` in the same library) — of the
   confirmed findings, drop any that POSITIVELY name an identifier (a `/`-bearing path token, or
   a `.sh`/`.md`/`.lua`/`.json` basename) absent (by basename match) from this batch's own
   `cycle_modified_files` — i.e. a red gate this batch's dispatched work could not plausibly have
   caused. **Fail-safe direction, load-bearing**: a finding naming NO identifier at all is NEVER
   dropped by this filter and stays blocking. Only a POSITIVE non-match (an identifier is named
   and it matches nothing in `cycle_modified_files`) can clear a finding as unrelated; the
   absence of an identifier can never be used as proof of unrelatedness. This is what stops the
   filter from degrading into a blanket disable of Gate 8 (or any other gate) — a finding the
   filter cannot positively clear stays in the blocking set.

Only findings surviving BOTH filters ("blocking") reach branch (b). Both filters are used ONLY by
this checkpoint (`scripts/orchestrate-cycle-plan.sh`) — `scripts/command-gate-out.sh`'s `rc==6`
handler deliberately does NOT apply either one: it gates a single task's own completion, with the
operator present to judge a flake or an unrelated red gate by hand, so an automatic
confirmation/attribution pipeline is unnecessary there. The checkpoint gates an entire batch with
no operator present, which is what makes the automatic pipeline necessary rather than optional.
This asymmetry is intentional and is commented at both call sites; see
`scripts/lib/deploy-baseline-lib.sh`'s own header for the canonical statement.

**Gate depth (Defect A — the fast/full depth disagreement, made explicit rather than silently
resolved)**: the checkpoint's own pre/post snapshot pair runs `verify-deploy.sh` at FULL depth
(no `--skip-slow`) on BOTH sides, and MUST stay symmetric — an asymmetric pair would make every
Gate 8 (shell test suite) finding look "new" simply because the pre-redeploy side never looked
for it, which is a strictly worse bug than any depth mismatch against `deploy-headless.sh`'s own
internal verify. `deploy-headless.sh` itself runs `verify-deploy.sh --skip-slow` internally (its
`deploy_exit -eq 0` == `landed_verify_clean` therefore only ever certifies the FAST subset —
every gate except Gate 8). This asymmetry between the checkpoint's full-depth comparison and
`deploy-headless.sh`'s own fast verify is DELIBERATE, not an oversight — the checkpoint takes its
own independent full-depth snapshots specifically so the baseline comparison sees slow-gate
(Gate 8) findings too, not only the fast subset `deploy-headless.sh` itself already checked. What
changed is that the disagreement is no longer silently resolved in either direction: when
`deploy_exit -eq 0` (deploy-headless.sh's own fast verify passed) yet the full-depth comparison
still finds a blocking finding, the checkpoint emits an explicit stderr "DEPTH NOTE" line and sets
`depth_disagreement: true` on the `defer_ledger` entry, stating plainly that the two verdicts
disagree by DEPTH, not by contradiction — the finding lives in the slow gate `--skip-slow`
deferred, and both verdicts are simultaneously correct at their own depth.

In all three branches: never abort, never silently continue. This is governed by the
`## Defer-Not-Fail: The Standing Default` section above. Abort is rejected because it discards
`mt_state_file` bookkeeping for no benefit, since deferral already halts further exposure.
Silent-continue is rejected outright because the operator would see nothing distinguishing "we
didn't check" from "we checked, it's broken, and we proceeded anyway" — the same reasoning the
Blocking vs. Advisory criterion above applies to any guardrail whose harm is silent and hard to
detect after the fact. Branch (c) does not weaken this: it is a third, EXPLICITLY ANNOUNCED state,
never an unannounced fourth option.

**Baseline mechanism**: the pre/post comparison is a sorted, deduplicated, line-level set
difference over `verify-deploy.sh --findings --quiet` output (see that script's own "Findings
mode" header section for the `FINDING `-prefixed, per-gate-labeled output contract), captured once
immediately before `deploy-headless.sh` runs and once after it succeeds. Exit-code-only comparison
is explicitly insufficient: a gate failing with 2 findings and the same gate failing with 5
findings (3 of them new) produce the identical non-zero exit code, so an exit-code-only comparison
would silently mask a newly-introduced failure hiding inside an already-failing gate — precisely
the scenario branch (b) above exists to still catch.

**Exit-2 resolution**: `verify-deploy.sh` exit 2 ("cannot run") is folded into the same findings
vocabulary as one synthesized `FINDING gate0 ...` sentinel line, rather than special-cased, so the
comparison stays a single uniform set difference with no separate branch of its own. This folding
is implemented once, in `scripts/lib/deploy-baseline-lib.sh`'s `deploy_findings_snapshot`, and
both consumers of this contract source it rather than each carrying their own copy. Two
consequences:
- Pre-redeploy exit 2 and post-redeploy exit 2 with the same reason → the sentinel is present in
  both captured sets → empty difference → **branch (c)**: proceed, reported loudly as "could not
  run, before or after this redeploy — pre-existing condition."
- Pre-redeploy exit 0 or 1, post-redeploy exit 2 → the sentinel is present only in the post set →
  non-empty difference → **branch (b)**: defer, unchanged. A redeploy that succeeded yet cannot be
  verified at all is exactly the verification gap this checkpoint exists to catch, never something
  to wave through on a pre-existing-failure technicality.

**Rejected alternative**: **exit-code-only baseline comparison** — rejected for the masking reason
given in Baseline mechanism above; recorded here so a later pass cannot rediscover and re-adopt it.

**Sequencing**: per-task commits at Stage MT-4 step 5.5 already precede any point the checkpoint
can occupy, unconditionally and inside the same per-task loop iteration. Committed-then-redeployed,
in that order, is guaranteed by existing step ordering and is stated here, not built.

**Idempotence guard (WITHIN-invocation only)**: the checkpoint fires only when this cycle's
overlap set contains at least one critical path not already recorded in
`mt_state_file.deployed_critical_paths`. Without it, a task sitting in `implementing` across
several cycles OF THE SAME `/orchestrate` INVOCATION would re-report the same `modified_files`
and re-fire the checkpoint every cycle, at unbounded redundant deploy/verify cost and with the
mid-run script-swap window maximized rather than minimized. `deployed_critical_paths` lives in
the SESSION-SUFFIXED `specs/.orchestrator-multi-state-{session_id}.json` (see the Class Table in
`context/standards/orchestrator-runtime-files.md`), which is minted fresh on every `/orchestrate`
invocation — it therefore has NO memory that lasts BETWEEN invocations. It is written only on the
checkpoint's three success branches (clean, branch (c), the filtered (c)-equivalent) and is never
written on defer (branch (a)/(b)) or on a durable-ledger skip (see "Durable redeploy ledger"
immediately below). This within-invocation scope and its accumulating-set behavior are unchanged
by the durable ledger below: it is its own, distinct, same-cycle deduplication mechanism, not the
same convergence mechanism as the same-cycle narrowing of `deferred_self_modifying` described
above, and not a substitute for cross-invocation memory.

**Durable redeploy ledger (cross-invocation memory)**: `deployed_critical_paths` above cannot, by
construction, tell a NEW `/orchestrate` invocation that a critical path it is about to redeploy
was already verified a moment ago by a PRIOR invocation — every invocation starts that field at
`[]`. A task sitting in `implementing` across separate invocations (the ordinary case) or a task
whose own `file_scope` IS the orchestrator source store (the self-modifying-task class, where the
content hash changes on every cycle BY CONSTRUCTION, since the task's own edits are what change
it) therefore re-triggered a full deploy+verify on every single invocation before this mechanism
existed, at real observed cost (single-digit minutes per firing) and, for the self-modifying
class, with 100% certainty on every cycle. This is closed by a durable, gitignored,
machine-local ledger — `lib/deploy-ledger-lib.sh`, default path
`specs/.orchestrator-deploy-ledger.json` (overridable via `DEPLOY_LEDGER_FILE`) — consulted BEFORE
the checkpoint's first expensive call (`deploy_findings_snapshot`, immediately after the existing
banner). See `context/standards/orchestrator-runtime-files.md`'s Class Table for why a gitignored
file here does NOT mean ephemeral, freshness-blind semantics: every read is hash-gated.

- **Record shape**: one rolling `deploy-ledger-v1` record — an aggregate sha256 and a per-path
  sha256 map over EVERY `critical_paths[].path` entry in
  `context/reference/orchestrator-critical-paths.json` (a missing file hashes to the literal
  `MISSING`), resolved ONLY against the `agent-system/extensions/core` scope root (the other two
  scope roots, `.claude` and `.opencode`, are deploy MIRRORS of it, never the source of truth for
  this hash) — plus `verified_at` (epoch seconds), `verify_outcome`, and the writing batch's
  `task_numbers`.
- **Verify-outcome vocabulary**: three SKIP-ELIGIBLE outcomes mirroring this subsection's own
  branches — `clean` (the success branch above), `pre_existing` (branch (c)), `filtered` (the
  filtered (c)-equivalent sub-branch) — plus two NON-eligible NEGATIVE records, `deploy_failed`
  (branch (a)) and `blocking` (branch (b)), written so an earlier clean record can never vouch for
  a tree a later failed or blocking deploy has since overwritten.
- **Two skip rules, not one, because they cover two DIFFERENT failure modes**:
  - **`skip_hash`** (the ordinary case): the current aggregate hash equals the ledger's aggregate
    AND the ledger is within `DEPLOY_LEDGER_MAX_AGE_SEC` (default 86400s / 24h) of `verified_at`.
  - **`skip_attributed`** (the self-modifying-task case): the ledger is within
    `DEPLOY_LEDGER_RECENT_SEC` (default 1800s / 30min) of `verified_at`, the ledger's
    `task_numbers` intersects the current batch's own `task_numbers` ("the deploy that just
    landed was mine"), AND every critical path whose per-path hash differs from the ledger is
    covered by the current cycle's own `cycle_modified_files` (the same directory-prefix overlap
    predicate this document uses throughout, checked with each changed path expanded across all
    three `scope_roots`). **The hash rule cannot help the self-modifying class at all**: that
    class changes the hash on every single cycle by construction, so `skip_hash` never fires for
    it — only the attributed rule, which recognizes "this batch's own edit", closes that case.
    Shipping only the hash skip would leave the self-modifying-task failure mode fully intact;
    the two rules are complementary, not redundant alternatives.
  - Both rules additionally require a skip-eligible `verify_outcome` and are OVERRIDDEN — forced
    to `run` — whenever any batch task's own `.return-meta.json` carries `deploy_pending: true`,
    so a skip can never starve the postflight completion-deploy gate's backstop (a task refused as
    stale must never be able to stay stuck behind a repeating skip).
- **Fail-safe read**: a missing, malformed, or schema-invalid ledger file, and a CANNOTVERIFY
  current hash state (missing `agent-system/extensions/core` root, missing `sha256sum`, or a jq
  failure), both degrade to "no evidence" and therefore to `run` — never to a skip. Absence of
  evidence can never justify skipping.
- **Env knobs**: `DEPLOY_LEDGER_RECENT_SEC`, `DEPLOY_LEDGER_MAX_AGE_SEC`, `DEPLOY_LEDGER_FILE`
  (test/operator override of the ledger path), and `DEPLOY_LEDGER_SKIP` (`0` forces every
  decision to `run` — an operational kill switch that needs no code revert).
- **Observability**: every skip decision is announced in a loud stderr banner naming the decision,
  the short aggregate hash, the prior verify outcome, the age, and the attributing task numbers
  (for `skip_attributed`), and is recorded in a new `mt_state_file.redeploy_skip_notices[]` entry
  (`{cycle, decision, reason, age_sec, ledger_outcome, changed_paths, attributing_tasks}`) —
  mirroring this document's own "never abort, never silently continue" posture for the checkpoint
  as a whole.
- **Rejected alternative: a bare recency window (no hash rule)** — rejected. A recency-only rule
  would skip a redeploy shortly after ANY prior deploy regardless of what changed since, which is
  strictly weaker evidence than a matching content hash; the hash rule is what lets an ordinary
  (non-self-modifying) task skip safely for up to a full day, not just a half hour.
- **Rejected alternative: a bare content-hash rule (no attributed rule)** — rejected. This is the
  precise scenario named in the "What to build" motivation above: a hash-only rule can NEVER skip
  the self-modifying-task class, since that class's own edits change the hash on every cycle by
  construction. Shipping only this rule leaves the observed failure mode (single-digit minutes of
  wall clock per firing, on every cycle, with certainty) fully intact.

**Concurrency**: the whole-tree overwrite is serialized by a fail-open `specs/.deploy-lock/`
mutex inside `scripts/deploy-headless.sh`, the same acquire/warn-and-proceed shape as the
existing `specs/.commit-lock/` mutex in `scripts/git-commit-scoped.sh`.

### Note on Reachability Durability

The reachability conclusion for the three explicitly-excluded files (`command-gate-in.sh`,
`command-gate-out.sh`, `orchestrator-postflight.sh`) is a fact about the CURRENT MT dispatch
implementation, not a permanent property of those files. If MT dispatch is ever rerouted through
the Skill tool in a way that sources any of them, the reachability test flips for that file and
it should be re-evaluated for inclusion using the same two tests above — not grandfathered out
because it was excluded once.

### The Postflight Completion-Deploy Gate

A sibling mechanism to the Inter-Cycle Redeploy Checkpoint above, addressing a DIFFERENT gap: the
checkpoint above is `/orchestrate`-only (Stage MT-3 step 7). Outside `/orchestrate`, a task whose
implementation edits `agent-system/extensions/**` could reach `[COMPLETED]` while its changes
remained absent from the running `.claude/` tree, because the only staleness signal
(`check-deploy-freshness.sh`) is advisory by contract and always exits 0 (see
`context/patterns/regeneration-is-manual-only.md`'s "Detecting When You're Stale" section). This
subsection is the single authoritative statement of the fix: a check-only, unconditional backstop
inside `scripts/update-task-status.sh` — the one chokepoint every completion path funnels
through, single-task and multi-task alike — plus two serialized, baseline-relative deploy
triggers that make the refusal self-resolving rather than a dead end.

**Trigger predicate (path-based, not `task_type`-based)**: the refusing task's OWN
`.return-meta.json` `modified_files` overlap `agent-system/extensions/**`, tested via
`scopes_overlap()` from `scripts/lib/file-scope-overlap.sh` against the directory-prefix rule in
`context/patterns/file-footprint-overlap.md` — the same overlap predicate the admission layers
above already use, applied here to a completion-time backstop instead of a pre-dispatch gate. A
`general`-typed task can touch the source store too; every other file-scope check in this system
is path-based, and this one follows suit rather than gating on `task_type == "meta"`.

**The check-only contract**: the backstop inside `update-task-status.sh` NEVER invokes the
deploy/regeneration script or the deploy-verification script itself — mechanically enforced by a
`grep -c` test asserting zero literal references to either script's name anywhere in the file
(see `scripts/tests/test-postflight-deploy-gate.sh`'s contract assertion). It performs only a
preflight-cheap, path-scoped `git log -1` comparison per touched extension, via
`scripts/lib/deploy-freshness-lib.sh`'s `deploy_freshness_status` function — the same comparison
algorithm `check-deploy-freshness.sh` uses, factored into one shared library so the two tiers
below share one algorithm. Multi-task `/implement` and `skill-orchestrate` both dispatch per-task
implementation skills in parallel; a deploy fired from inside per-task postflight would race the
fail-open `specs/.deploy-lock` mutex exactly as the Concurrency note above describes for the
Inter-Cycle checkpoint — so the actual redeploy trigger is placed ONLY at the two already-
serialized call sites named below, never inside the check-only backstop itself.

**The conclusiveness convention (six branches, mirroring this document's own Blocking vs.
Advisory posture of defaulting permissive on ambiguity)**: only "overlap AND provably stale" is
conclusive evidence the transition must wait — refuse, new exit code 6. Every other case passes
through: no `.return-meta.json` resolved; empty or absent `modified_files`; no overlap (not
applicable); a missing shared library (D4 — INCONCLUSIVE pass-through, never the loud exit-5 the
two pre-existing shared libraries in `update-task-status.sh` use, since this backstop is
UNCONDITIONAL and a hard environment exit would block completion system-wide on a deploy-ordering
accident); freshness that cannot be verified; and overlap with verified freshness (proceed).

**Exit 6's ordering-constraint semantics**: mirrors the existing `--phase-check=refuse` shape
exactly — no `state.json` write, no plan-file stamp, exit non-zero, self-resuming on the next
postflight retry. The task stays at its current status (typically `implementing`); it is never
pushed to `blocked`, since the remedy is a deploy the serialized trigger sites perform
automatically, not a human-only intervention.

**The two serialized trigger sites and their shared (a)/(b)/(c) baseline contract**: identical in
shape to this document's own Inter-Cycle Redeploy Checkpoint failure contract above — (a) the
redeploy itself fails to land (exit 1 or 2): defer unconditionally, no baseline consultation; (b)
the redeploy lands but introduces at least one NEW `verify-deploy.sh --findings` finding relative
to a pre-redeploy baseline: defer, do not re-attempt; (c) the redeploy lands and every post
finding was already present pre-redeploy (the expected case today, given `deploy-headless.sh`'s
universal exit 3 — see `regeneration-is-manual-only.md`'s "Inline Verification and Exit Code 3"
subsection): announce loudly (a `[PRE-EXISTING VERIFY-DEPLOY FAILURE]`-prefixed banner), then
re-attempt the refused transition exactly once. `verify-deploy.sh` exit 2 is folded into the same
findings vocabulary as one synthesized sentinel line, exactly as this document's own "Exit-2
resolution" subsection above specifies — not special-cased.

- **Single-task path**: `scripts/command-gate-out.sh`'s existing `gate_out_rc` handling, extended
  with an `rc == 6` branch alongside the pre-existing `rc == 4` phase-check branch. This call site
  has no concurrency — it is the true single-task `/implement` completion path — so it is safe to
  fire the redeploy directly from here.
- **Multi-task batch path**: `commands/implement.md` Step 4, already serial (it runs once, after
  all of Step 3's parallel dispatches have returned), placed strictly BEFORE the existing per-task
  `.return-meta.json` deletion loop so the deploy-pending evidence survives long enough to drive
  the re-attempt. Detects deploy-pending tasks by reading the `deploy_pending: true` marker
  `skill-base.sh`'s `skill_postflight_update` records into a refused task's own
  `.return-meta.json` on exit 6, then fires ONE redeploy for the whole batch (never once per
  refused task) and re-attempts each deploy-pending task's transition under the same (a)/(b)/(c)
  contract.

**Refusal propagation (the prerequisite for exit 6 to be visible at all)**: `skill_postflight_update`
in `scripts/skill-base.sh` previously invoked `update-task-status.sh` and let its own return value
be determined by whichever statement executed LAST in the function (the non-blocking events-append
call) — silently swallowing `update-task-status.sh`'s own exit code, including the pre-existing
`--phase-check=refuse` exit 4 and now exit 6. It now captures that rc into a local, keeps the
extension-hook and events legs running UNCONDITIONALLY exactly as before, and returns the captured
rc verbatim from the function. Every existing caller was checked (`grep -rn
skill_postflight_update`) and none invokes it under `set -e` in the same shell scope, so this is
not a newly-introduced abort hazard for any of them.

**Classification**: this gate is BLOCKING, not advisory — see the Classification Table below.

**Residual — the `/orchestrate` path (D6) — CLOSED**: `/orchestrate` is covered by the backstop's
refusal (a refused task simply stays non-completed); it has no serialized trigger of its own
analogous to the two single-task/multi-task sites above, and relies entirely on the Inter-Cycle
Redeploy Checkpoint mechanism documented earlier in this file. This residual is now closed by two
changes, landed together:

1. `orchestrate-cycle-postflight.sh`'s `implemented)` arm now captures `skill_postflight_update`'s
   return code (previously discarded) instead of silently swallowing it. On a `postflight_rc == 6`
   deploy-pending refusal, `verdict` resolves to `defer` (not `ok`) and the commit message reads
   `orchestration paused (cycle N)` (not `complete implementation`) — the refusal is now HONEST at
   the postflight layer, matching what actually happened to state.json.
2. The Inter-Cycle Redeploy Checkpoint's own `deploy_pending_any` computation — which already
   existed and already forced `deploy_ledger_decide`'s decision to `run` — was HOISTED out of the
   `matched_count -gt 0` branch and the branch condition widened to
   `matched_count -gt 0 OR deploy_pending_any`. A `meta` task touching ANY file under
   `agent-system/extensions/**`, not only a curated critical path, now reaches the override. The
   checkpoint's announcement names its own reason (the `deploy_pending` marker) on the widened
   path, rather than the old misleading "touched 0 orchestrator-critical path(s)" line.

Both changes route through the SAME already-sanctioned checkpoint call site — no new automated
`deploy-headless.sh` trigger was added anywhere (see the Concurrency Posture paragraph
immediately below). The `deployed_critical_paths` idempotence guard and the durable
`deploy_ledger_decide` ledger (with its hash/attributed skip rules) are consulted on the widened
path exactly as on the pre-existing matched-allowlist path — unchanged, not bypassed.

**Concurrency posture (why the redeploy still lives at the checkpoint boundary, never in
per-task postflight)**: `command-gate-out.sh`'s single-task trigger licenses itself on the grounds
that its call site has NO concurrency — the true single-task `/implement` completion path.
`skills/skill-orchestrate/SKILL.md`'s Move 2 issues every `dispatch[]` row's Agent call in ONE
message (genuinely simultaneous); a redeploy fired from inside `orchestrate-cycle-postflight.sh`
would therefore race the fail-open `specs/.deploy-lock` mutex against a sibling task's own
still-in-flight dispatch. The Inter-Cycle Redeploy Checkpoint, by contrast, runs at the START of
`orchestrate-cycle-plan.sh`, strictly BEFORE Move 2 issues that cycle's own dispatch batch — the
one point in the loop with no dispatch in flight — so widening its predicate closes this residual
without opening a third trigger site. **Cost, stated plainly**: convergence for a deploy-pending
refusal is deferred by one cycle (the checkpoint redeploys this cycle; the FOLLOWING cycle's
postflight retry then succeeds) rather than resolved within the same postflight. This is the
argued, deliberate trade this residual's closure makes — strictly preferable to an unserialized
redeploy racing a live batch, which would be a worse defect than the one being fixed. An
end-to-end scripted transcript tracing this exact one-cycle deferral (refusal → checkpoint fires
on the following cycle → retry succeeds → no fresh dispatch against an already-complete plan) is
preserved as a durable artifact alongside the change that closed this residual.

**Explicitly re-considered and re-confirmed split-out** while this same subsection's own
confirmation/attribution filters and Gate depth statement were added above: that work changed the
checkpoint's *verdict* logic (which candidate new findings may defer a batch, and how the
fast/full depth disagreement is reported) — a disjoint mechanism from what D6 was, which concerned
the checkpoint's *trigger* predicate (which cycles fire the checkpoint at all) and the
`deployed_critical_paths` idempotence backing store that predicate depends on. No edit was shared
between the two.

**Commit-granularity residual**: like the Inter-Cycle Redeploy Checkpoint's own freshness signal,
this backstop's freshness comparison is commit-granular, not per-file — an uncommitted
source-store edit at postflight time would make the gate report a false "fresh" (see
`context/patterns/regeneration-is-manual-only.md`'s "Detecting When You're Stale" section for the
same limitation stated for `check-deploy-freshness.sh`). The Commit-Per-Green-Substep Mandate
(`.claude/rules/git-workflow.md`) makes the uncommitted-at-postflight case rare in practice, and
`scripts/verify-deploy.sh` remains the deep, per-file companion for anyone who needs to check
beyond commit granularity.

## Admission-Time vs. Mid-Flight: A Knowability Test

The boundary between admission-control checks and mid-flight checks is a **knowability** test,
not a cost test: a problem belongs to admission control if and only if the fact needed to detect
it already exists on disk before any agent is invoked. It belongs to mid-flight detection if and
only if that fact does not exist until an agent has acted.

**Admission-time (fact already on disk before dispatch)**:

- File-scope collision — the `file_scope` arrays of both tasks are already recorded.
- Held lock — the lock's existence and holder are already recorded.
- Unmet predecessor — the dependency edge and the predecessor's terminal status are already
  recorded.
- Stale handoff — the handoff file's mtime is already on disk.

**Mid-flight (fact does not exist until an agent has acted)**:

- Premature completion claims — whether phase headings actually flipped to complete cannot be
  known until the dispatched agent has run and its output can be compared against its self-report.
- Churn — a trend across two or more cycles is only observable after those cycles have occurred.
- Drift — the same: an inspection of what actually changed, only meaningful after the change has
  happened.

Each admission-time example is disambiguated by naming the specific on-disk fact that makes it
knowable before dispatch; each mid-flight example is disambiguated by naming the fact that does
not exist until an agent has acted.

## Batch-Size Scaling: Scope of Deferral, Not Existence of the Check

Batch size changes the **scope of what gets deferred**, never the **existence** of a blocking
check. The runtime wave/cycle-split check and the lock-acquisition refusal both already implement
this correctly: on conflict, only the one lower-priority colliding task is deferred, not the
whole batch. The consequence is explicit: a batch of eight never pays more than one deferred task
for any single conflict, so the existence of a check is orthogonal to how large the batch is
allowed to grow.

**Evidence-gating is not batch-size-gating, and does not conflict with this section**: the
`cross_batch` narrowing in `orchestrate-batch-admit-v5` (see the Classification Table above and
`docs/architecture/batch-admit-schema.md`'s Version History) changes disposition based on whether
the COLLIDING TASK carries execution evidence, never based on how many candidates are in the
current invocation. The check still runs, at full comparison-set scope, for a batch of one exactly
as for a batch of fifty; what changed is which of its outcomes (block vs. advise) a given
colliding task's status produces. This is the opposite of the rejected pattern below (indexing
check strictness to batch size) — it indexes disposition to a per-collision structural fact
(is the other side of this collision provably not running?), which is itself computable from
on-disk state and does not vary with batch size at all.

## Rejected Approaches

**Relaxing a blocking check to advisory as batch size grows** (equivalently, indexing check
strictness to batch size) is rejected, not merely discouraged. The reasoning: this imports the
approval-fatigue / rubber-stamping failure mode — documented for *human* reviewers operating
under volume — into *machine* admission control, where it does not apply. A machine overlap check
does not become harder to run, or less necessary, as concurrency rises; if anything the opposite.
Batching and summarization are the right answer for the human-facing review of a batch's
consolidated outcome (see Divergence from External Practice below); they are the wrong answer for
whether two tasks may safely run concurrently, which is a deterministic, per-pair, machine-checked
question independent of batch size. This is named here explicitly so a later, less-grounded pass
cannot rediscover it and adopt it as a tunable.

**Auto-degrading a zero-dispatch batch into N sequential solo invocations** (Scope D) is rejected
in favor of PRINT-ONLY. Three-part justification:

(a) Each solo run pays its own full research/plan/implement dispatch cost. Silently converting one
zero-dispatch batch invocation into N solo invocations multiplies that cost without the caller's
consent.

(b) This system has zero synchronous confirmation gates by design (see Divergence from External
Practice below) — there is no point mid-run to obtain that consent. The absence of a confirmation
gate is a reason to take the SMALLER action (print the sequence) here, not licence to take the
bigger one (auto-execute it).

(c) Auto-degrading inverts defer-not-fail's own proportionality logic. Defer-not-fail exists to
make the system's response to a transient scheduling conflict SMALLER than the conflict — a
deferred task, not a failed one. Auto-executing N solo runs in response to a batch where nothing
was admitted is a larger response than the conflict warrants, the opposite direction from what
defer-not-fail is for.

The report therefore prints the dependency-ordered solo re-run sequence; the human runs it.

**Converting `commands/orchestrate.md`'s former Kahn's-algorithm pseudocode into an executable
script** was rejected while the pseudocode still existed (recorded alongside the
file_scope_collision two-pass work above, since both were weighed together while adding plain
multi-task resequencing); the pseudocode has since been deleted outright rather than converted,
so this rejection is history, not a live constraint. `skill-orchestrate/SKILL.md` Stage MT-3 step
4.5 is now the sole implementation of wave/cycle sequencing, re-deriving eligibility fresh every
cycle rather than consuming any pre-computed wave schedule.

**Adding `file_scope` overlap as a pre-computed `in_degree`/wave-assignment input** (rather than
a purely reactive, dispatch-time defer) is likewise rejected. Cost of adding: it duplicates, in a
pre-computed graph, a decision the executing gate (`orchestrate-batch-admit.sh` /
`task-lock.sh`'s cross-task scan) already re-derives fresh at admission/acquire time every
cycle — creating two independent sources of truth for the same fact that can drift out of sync
with each other (the pre-computed graph could go stale between when it was built and when a
later cycle's live state has since changed). Cost of NOT adding: overlap remains a reactive,
dispatch-time defer rather than a pre-dispatch ordering signal, so a colliding pair is only
discovered at the moment dispatch is attempted, not earlier during wave planning. Both costs are
accepted; the duplication risk of the "adding" cost was judged worse than the reactive-only
discovery timing of the "not adding" cost.

## Defer-Not-Fail: The Standing Default

Deferral is the standing default response to every admission-time conflict, not just the two
already implemented (wave/cycle-split deferral of the lower-priority task, and lock-acquisition
refusal). It generalizes to the two scan-scope gaps this document also flags as non-negotiables
below: a collision with a non-terminal, currently-unlocked task outside the batch, and a declared
dependency whose target lies outside the batch. Both should be deferred, never hard-failed.

The rationale: admission conflicts are transient by construction — they clear once the colliding
or blocking task terminates — whereas this system's failed/blocked states require human
intervention to clear. Treating a transient scheduling conflict as a terminal failure is
disproportionate to the conflict.

### The Forward-Progress Invariant

A zero-dispatch batch — every validated candidate deferred, nothing admitted on any wave or
cycle of the invocation — is a consequence of defer-not-fail applied repeatedly across an entire
run, which is why this subsection follows that section rather than standing alone. Defer-not-fail
says any single conflict is deferred, never failed; it says nothing about what the invocation as a
whole must do when *every* candidate hits some conflict. This subsection names that whole-run
outcome and requires it to be legible, not merely correct.

**Canonical vocabulary, used verbatim at every site that renders or detects this outcome**:

- **Invariant name**: the **forward-progress invariant**.
- **Violation outcome name**: the **zero-dispatch outcome**.
- **Structured field name**: `forward_progress_violated` (boolean).
- **Observation ledger field name**: `defer_ledger`.
- **Human-facing banner**:
  `[ZERO DISPATCH - 0 of N validated candidates dispatched; forward-progress invariant violated]`.
- **Machine-readable marker**: `<!-- forward-progress violated=true dispatched=0 validated=N -->`.

**Statement, precise and cause-agnostic**: the invariant is violated when the validated-candidate
set is non-empty AND no task was dispatched on any cycle of the invocation. The operational test is
`mt_state_file.dispatch_start_ts == {}` at loop exit — that map is already written only at actual
dispatch (three call sites in the skill's Stage MT-4), so detecting the invariant requires no new
dispatch-side bookkeeping. This is true regardless of which defer reason produced it —
`self_modifying`, `file_scope_collision` (`in_batch` or `cross_batch`), or a redeploy-checkpoint
deferral all count identically.

**Detection/rendering split, three loci, named explicitly**:

1. **Detection** — computed once, at the skill's Stage MT-5, as the single source of truth over
   `mt_state_file`.
2. **Rendering (live path)** — the command's Step 5, the human-facing consolidated-output surface.
3. **Rendering (preview path)** — the `--dry-run` reporter, which renders the same vocabulary
   against its own static, single-pass admission analysis.

**Relationship to the existing convergence guard**: the `consecutive_no_dispatch_cycles` guard
prevents ONE specific non-convergence mode — a mutually-colliding self-modifying set spinning to
the cycle cap. The forward-progress invariant is the GENERAL outcome-legibility requirement
covering every cause, including `file_scope_collision` (both scopes) and out-of-batch unmet
predecessors, not only the self-modifying case the guard watches. This is a legibility requirement
layered on top of the guard, not a widening of it: the guard's trigger condition is unchanged, and
the invariant is detected independently, at loop exit, regardless of whether the guard ever fired.

**Empirical finding**: the predecessor narrowing of the self-modification defer (recorded above
under "The Same-Cycle Narrowing and Its Hazard Accounting") did not shrink this requirement. The
remaining zero-dispatch cases are demonstrated true positives of a correctly-working gate, not
artifacts of an over-broad prior rule — the mechanism class is several independent
self-modifying candidates sharing one cycle with no dependency edge to serialize them, which the
same-cycle narrowing neither creates nor removes.

**Exit/status contract (Scope C), confirmed, not changed**: a zero-dispatch invocation does not
mutate `specs/state.json`, does not add any task to `failed_tasks`, and does not mark any task
failed or blocked. This is the standing defer-not-fail default applied to the whole-run outcome,
unchanged by naming it. A no-dispatch cycle DOES still consume a cycle — `cycle_count` increments
unconditionally at Stage MT-3 step 6, after dispatch — and that too is unchanged.

**PRINT-ONLY, not auto-degrade (Scope D)** — see the new `## Rejected Approaches` entry below for
the full justification; this subsection states only the vocabulary, that section states the
reasoning.

## Non-Negotiables

These five hold at any batch size and are never relaxed for throughput:

1. **Never promote to completed on a bare self-reported implementation status.** An outcome check
   on actual plan/artifact marker state (the handoff schema's `plan_markers_verified` field or
   equivalent) must gate it. Self-report is supplementary evidence only, never sufficient evidence
   on its own.
2. **Never narrow file-footprint or lock overlap scanning to the current invocation's task set as
   the only scope.** The scan must also reach non-terminal, currently-unlocked tasks outside the
   batch. Correctness of concurrent-write detection does not become cheaper as concurrency
   increases — it becomes more necessary.
3. **Never silently drop a dependency edge because its target is out of batch.** At minimum, warn
   loudly and exclude the dependent task by default. **Status: the warn-loudly and
   distinguish-subcases clauses are now satisfied; the exclude-by-default clause remains as
   documented in the Open Design Fork below.** `scripts/orchestrate-predispatch-review.sh` runs
   before `commands/orchestrate.md`'s compact STAGE 0 multi-task block discards out-of-batch edges
   to build its intra-batch-only dependency graph, and classifies every raw `dependencies[]` entry on every
   candidate into one of five buckets — `intra_batch` (no finding), `out_of_batch_live`,
   `out_of_batch_terminal`, `archived_satisfied`, and `nonexistent` — warning loudly by task
   number and target for the `out_of_batch_live`, `out_of_batch_terminal`, and `nonexistent`
   subcases, including the terminal one (this Non-Negotiable draws no exception for a terminal
   target). `archived_satisfied` (a dependency that was completed and then archived by `/todo`,
   resolvable only via `specs/archive/state.json`, never `active_projects[]`) is reported at
   informational volume instead — it is satisfied, not a hazard, so it does not warrant the same
   loud treatment as a dangling or out-of-batch-live edge. This is a REVIEW stage only: it never
   excludes on its own account. It does not newly exclude an `out_of_batch_live` or `nonexistent`
   predecessor from live dispatch either — `dependency_graph` (built by `commands/orchestrate.md`'s
   compact STAGE 0 multi-task block) is intra-batch-only, so an out-of-batch edge is simply absent
   from it, and `skills/skill-orchestrate/SKILL.md` Stage MT-3's eligibility check sees no
   predecessor to wait on. Closing that residual live-path exclusion gap is exactly the Open
   Design Fork question below, left unresolved by this warn-only stage on purpose.
4. **Never let human-facing batch approval substitute for or gate machine admission decisions.**
   Which tasks may run concurrently is a deterministic, per-pair, machine-checked question,
   independent of whether or how a human later reviews the batch's outcome.
5. **Never treat the batch-size cap as a correctness control.** It bounds human cognitive load
   over the consolidated output, not the soundness of per-pair admission checks. Raising it is
   safe only if the human-facing review strategy scales with it — the two are orthogonal
   questions and must be reasoned about separately.

## Divergence from External Practice

Stated plainly rather than smoothed over: the external human-in-the-loop literature this system's
design was checked against assumes a human is available to escalate to, synchronously, during a
run. This system assumes the opposite by design — autonomous orchestration has zero synchronous
confirmation gates between lifecycle phases. Escalation, when it happens, is a capped automated
fork sequence, and human review happens only after the fact, via the consolidated batch output and
the commit trail. No synchronous batch-approval gate exists here at all, and this document must
not be read as implying one does.

## Open Design Fork — RESOLVED

For an out-of-batch dependency (Non-Negotiable 3 above), whether the right response is to exclude
the dependent task from the batch, or to auto-expand the batch to include the predecessor, was
previously left unresolved here. **Resolution: exclude the dependent task by default; never
auto-expand the batch.** Both options were defer-not-fail-compatible; they differ in blast radius,
and this is why exclude wins:

- **Precedent**: two structurally identical situations elsewhere in this codebase already chose
  exclude-and-warn over auto-expansion — the now-retired `orchestrate-dry-run-report.sh`'s Step 6
  ("Out-of-batch unmet predecessors", a one-shot static report with no next cycle to defer to) and
  `orchestrate-batch-admit.sh`'s `collision_scope == "cross_batch"` handling (still live). A third,
  newly-diverging answer for the same shape of problem would be an unjustified inconsistency, not
  a considered design choice.
- **Blast radius**: auto-expanding the batch to pull in an out-of-batch predecessor would require
  that predecessor to pass the FULL admission check (self-modification, file_scope collision,
  lock contention, its own predecessors) before the expansion is safe to dispatch alongside —
  strictly more machinery layered onto a path that has had far less production exposure than the
  existing exclude-and-warn precedent.

This resolution is a recorded design decision, not (yet) a live-path behavior change: it applied
to `orchestrate-dry-run-report.sh`'s Step 6 exclusion before that script's retirement, and gives
future work a settled answer for closing the live-path gap described under Non-Negotiable 3 above
— the gap is UNCHANGED by that script's retirement: `orchestrate-cycle-plan.sh`'s live and
`--dry-run` paths alike defer an out-of-batch unmet predecessor to a later cycle exactly as the
rest of the eligibility model does (see Stage MT-3 step 3's port in that script), never a distinct
permanent exclusion — closing the gap remains future work.
`scripts/orchestrate-predispatch-review.sh` deliberately stays a
report-only REVIEW stage and does not itself implement this exclusion on the live dispatch path
(see that script's own header for the "never a fifth admission gate" framing). The fork is marked
resolved here so the reasoning survives for whichever future change implements the live-path
exclusion; the fork's text is not deleted.

**Accompanying bounded-scope note**: any future widening of the overlap scan (to close the
scan-scope gap in Non-Negotiable 2) should follow the existing bounded-scan precedent — compare
against a bounded set such as non-terminal tasks, never an unbounded scan of every task directory
— or it reintroduces the very cost problem this document exists to keep in check.

## Related Documents

This document states principles only. The mechanisms are defined, exactly once each, elsewhere:

- **Overlap algorithm**: `file-footprint-overlap.md` — the directory-prefix overlap predicate and
  its pairwise-set application, used by all three admission layers above.
- **Lock protocol**: `task-lock.md` — the lockfile schema, acquire/heartbeat/release contract, and
  the cross-task `file_scope` overlap check performed at lock-acquisition time.
- **Wave/cycle dispatch**: `commands/orchestrate.md` (the compact STAGE 0 dependency-graph build)
  and `skills/skill-orchestrate/SKILL.md` (the Lifecycle-Cycling Loop, which re-derives eligibility
  fresh every cycle rather than consuming a pre-computed wave schedule, and its runtime
  wave-split step, and the Phase-Aware Dispatch and Per-Task Postflight stage that maps a self-reported implementation
  status to a postflight update).
- **Handoff schema**: `docs/architecture/handoff-schema.md` — the `plan_markers_verified` field
  referenced under the Blocking vs. Advisory and Non-Negotiables sections above, and the token
  budget any future mid-flight signal must fit inside if it needs to reach the state-machine
  loop (see the schema's Context Flatness Constraint, restated in `skill-orchestrate/SKILL.md`'s
  MUST NOT section).
- **Creation-time overlap component**: `docs/reference/standards/multi-task-creation-standard.md`
  — the file-scope capture and overlap-detection component invoked at task-creation time.
- **Self-modification hazard data and schema**: `context/reference/orchestrator-critical-paths.json`
  — the single declaration of the critical-path list (13 entries as of the system-defect
  discrimination recursion guard's additions — see
  `context/patterns/system-defect-discrimination.md`'s "Recursion guard rule" section) and its
  `scope_roots` expansion rule, consumed by `scripts/orchestrate-batch-admit.sh` for the
  self-modification hazard check AND by the system-defect-discrimination recursion guard as a
  second consumer of the same `self_mod_match` predicate; and
  `docs/architecture/batch-admit-schema.md` — the `self_modifying` / `defer_reason` verdict fields
  this fourth dimension adds to the admission predicate's output.
- **Deliberate-invocation constraint and its automated exception**:
  `context/patterns/regeneration-is-manual-only.md` — the "must be invoked explicitly" constraint
  this document's inter-cycle redeploy checkpoint is the one recorded, additive carve-out against
  (see that file's `## Automated Exception` subsection).
