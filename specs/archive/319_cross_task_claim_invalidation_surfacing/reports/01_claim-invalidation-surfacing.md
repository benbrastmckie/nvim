# Research Report: Cross-Task Claim Invalidation Surfacing

**Task**: 319 - Surface cross-task claim invalidation when a research dispatch refutes a filed premise
**Started**: 2026-10-09T04:49:14Z
**Completed**: 2026-10-09T05:30:00Z
**Effort**: large
**Dependencies**: 285 (completed — `.decisions.json` writer landed; see Findings)
**Sources/Inputs**: `agent-system/extensions/core/` scripts and docs, `specs/state.json`, git log, the memory extension's harvest/retrieve scripts
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- **Trigger surface (negative direction)**: an explicit, structured top-level field on
  `.return-meta.json`, producer-owned by the research agent, following the exact precedent already
  set by `proposed_file_scope` / `user_decision`. The two other candidates named in the task
  (`decisions_made` and `.decisions.json`) are both **ruled out** — neither is reachable from a
  research dispatch, and neither's schema fits a machine-checked refutation. See Findings.
- **Matching rule**: literal, word-boundary string matching on declaration names and explicit
  supersession markers against the non-terminal tasks' `title`/`description` fields in
  `state.json`. No natural-language equivalence, exactly as the task requires. False-negative
  posture stated explicitly in Decisions.
- **Posture**: advisory only, confirmed. No task description, `file_scope`, or status is ever
  written by the sweep.
- **Landing/wiring**: deliberately **not implemented in this task** — the call site belongs in
  `orchestrate-cycle-postflight.sh`, which is already in the declared `file_scope` of multiple
  open tasks (the same reasoning this task's own description already applies to its own call
  site). This task delivers the matcher script and its regression fixture only.
- **Positive direction (added scope)**: the mechanism this incident needs **already exists and is
  already built, but is never called**. `scripts/memory-harvest.sh` reads a task's
  `memory_candidates` out of `state.json` and writes them into the memory vault that
  `memory-retrieve.sh` injects at every dispatch's preflight — but its own header says plainly:
  *"this script is presently uncalled... `memory_candidates` is consumed via skill-todo's inline
  harvest logic (HarvestMemories stage), not via this script."* That stage is explicitly scoped to
  "completed tasks in the archival batch" (`/todo`-only, periodic, human-invoked). This is the
  exact mechanism of the measured gap: a finding recorded as a `memory_candidate` sits inert until
  a human runs `/todo` and the producing task reaches `[COMPLETED]` and is archived — which can be
  arbitrarily later than the very next dispatch that needed it.
- **Positive-direction verdict**: wire `memory-harvest.sh` as an **immediate per-dispatch
  harvest trigger** (option (i)), not a new ledger (iii) and not `/distill --dream` (ii). This
  reuses an already-built, already-threshold-gated (confidence >= 0.7) script with zero edits to
  it or to `skill-todo`'s separate inline logic — respecting the stated boundary against absorbing
  `/todo` consolidation scope. See Decisions for the full weighing and evidence.
- **Escape hatch**: NOT triggered. The positive-direction fix needs no new script, no new ledger,
  and no new matcher — only a new call site, which (like the negative direction's own call site)
  is deferred to the same future wiring task against `orchestrate-cycle-postflight.sh`. The two
  directions do not, in fact, share one artifact-walker as the amendment's framing assumed (see
  Decisions for the explicit correction); each is independently small enough to stay inside the
  existing phase-sizing bound without spawning a follow-up task.

## Context & Scope

Task 319 asks research to RULE, not assume, on three questions for a negative-direction sweep
(what triggers detection of a refutation/supersession; where the output lands; whether it blocks),
and an amendment adds a positive-direction requirement (a finding recorded in one task's artifacts
must reach a later task that would otherwise rediscover it), with an explicit escape hatch to spawn
the positive direction as its own task if the combined scope exceeds one dispatch.

This report is scoped to the ruling and the design it implies, not to writing
`scripts/sweep-invalidated-claims.sh` itself (an implementation-phase deliverable, per this task's
already-declared `file_scope`).

## Findings

### Negative direction: the two non-chosen candidates are unreachable or ill-shaped, not merely less convenient

`docs/architecture/handoff-schema.md`'s own "Handoff Writers" section states plainly: **"Research
agents never write it, in any mode"** — meaning `decisions_made` (which lives only on
`.orchestrator-handoff.json`) can never be set by the very agent type (research) that produces the
refutation in the motivating incident. Candidate (a) of the trigger question is therefore not a
matter of taste; it is the only candidate a research dispatch can physically reach.

`.decisions.json` (candidate (c), the reason task 285 was declared as a dependency) is now
confirmed landed (`git log` shows task 285's full phase sequence through "complete implementation
(post-deploy reconcile)"). Reading its actual writer, `orchestrate-record-decision.sh`, and its
schema in `handoff-schema.md`'s "Decisions File Schema" section shows it is scoped exclusively to
**answers the user gave to a `user_decision` question the loop's own `AskUserQuestion` relay
asked** — required fields are `question`, `answer`, `cycle`, `timestamp`, and the writer is "the
loop's own branch move... never hand-authored JSON," called only after the user answers a batched
question. A machine-checked refutation is not a question anyone asked the user, and research
agents do not call this script (it is invoked by the lead's own loop-level move, never a dispatched
agent). Bolting a refutation record onto this file would mean either breaking its one existing
consumer's assumption (`orchestrate-build-dispatch.sh`'s "Prior Decisions" rendering, which expects
Q/A pairs) or stretching `question`/`answer` to mean something they were never designed to mean.
Dependency 285 is therefore correctly satisfied (it had to land before this ruling could even be
checked), but its conclusion is that **this route is the wrong shape**, not merely unavailable.

Candidate (b), a free-text convention in the report body, is the status quo the task is trying to
fix: the BimodalLogic incident already recorded 29 occurrences of "refut" as free text in task
descriptions, and nothing could sweep it reliably. Re-adopting prose convention for the trigger
would reproduce the same failure one layer down (report prose instead of description prose).

This leaves candidate (a) — an explicit top-level field on `.return-meta.json` — as not just the
best option but the **only reachable, correctly-shaped** one. `context/formats/return-metadata-file.md`
already has a well-worn precedent for exactly this shape: `proposed_file_scope`, `user_decision`,
and `research_questions` are all optional, top-level, **producer-owned** fields that a later writer
in the same invocation must preserve untouched (the "Multiple Sequential Writers" section). A new
field following this exact convention requires no change to the validator's permissiveness (there
is no closed-schema "unknown field" rejection in `validate-return-meta.sh` — confirmed by grep) and
no change to any existing consumer.

### Postflight Boundary confirms the sweep itself is mechanical, not "analysis"

`docs/architecture/handoff-schema.md`'s "Postflight Boundary" section lists five things the lead's
per-dispatch postflight body must never do, including "Analyze or grep source" and "Write
reports/plans/summaries" (with one narrow, already-named exception, D4). A literal substring/
word-boundary match of a handful of declaration names against `state.json`'s `description` fields
is the same class of mechanical, deterministic operation `orchestrate-cycle-postflight.sh` already
performs today (e.g. the `proposed_file_scope` merge, the research-report gate, `system-defect-record.sh`
calls) — none of which constitute "analysis" in the sense that boundary prohibits (LLM judgment
over application source to form new conclusions). This confirms the sweep is safe to run as a
postflight-called script, consistent with this task's own `file_scope` declaring exactly one script
and one test file and nothing inside `orchestrate-cycle-postflight.sh` itself.

### Why the call site (for both directions) is correctly deferred, not an oversight

The task's own description already explains why `orchestrate-cycle-postflight.sh`'s call site is
not declared: it sits in the `file_scope` of (per the task's own count at time of writing) eight
other open tasks, so wiring it here adds eight serializing dependency edges for one call line. That
reasoning applies identically to wherever the positive-direction harvest trigger would be wired —
also `orchestrate-cycle-postflight.sh` (or an equally-contended postflight entry point) — so
deferring both to the same future "wiring task" is the consistent application of the task's own
stated principle, not a new exception invented for this report.

### Positive direction: the required mechanism is dormant infrastructure, not missing infrastructure

Direct evidence, read from the scripts themselves:

- `scripts/memory-harvest.sh`'s header: *"NOTE: this script is presently uncalled (no caller in
  the skill/command pipeline). `memory_candidates` is consumed via skill-todo's inline harvest
  logic (HarvestMemories stage), not via this script."* It already reads `memory_candidates` for a
  given task number straight out of `state.json`, filters by `confidence >= 0.7`, deduplicates
  against `memory-index.json` and the filesystem, and writes a vault entry — the entire mechanism
  the positive direction needs, already implemented, already exercising the exact
  `memory_candidates` field every research/plan/implement agent already populates per
  `return-metadata-file.md`.
- `skills/skill-todo/SKILL.md` Stage 7 ("HarvestMemories") confirms the *only* live harvest path
  today is its own **separate, inline** duplicate of this logic, explicitly scoped: *"For each
  completed task in the archival batch"* — i.e. triggered solely by a human running `/todo`, and
  only for tasks that have already reached `[COMPLETED]` and are in that archival run's batch.
- `memory-retrieve.sh` is already called automatically at every `/research`, `/plan`, and
  `/implement` preflight (confirmed in this repository's own root `CLAUDE.md`, "Memory-Augmented
  Research" section) — so the **retrieval** side of the pipeline already runs on every dispatch.
  The entire gap is on the **harvest** side: a `memory_candidate` written by one task's dispatch is
  invisible to `memory-retrieve.sh`'s index until a human-invoked, terminal-status-gated `/todo`
  run processes it.

This is precisely the failure mode the amendment's motivating measurement describes: "a finding
written into `specs/NNN_*/summaries/` is invisible to the next task. Nothing reads it, nothing
indexes it, and the memory extension's `memory-retrieve.sh` preflight injection did not surface it
either." The root cause is not that no mechanism exists for this; it is that the one mechanism that
does exist (`memory_candidates` -> vault -> retrieval) only fires at a single, late, human-gated
checkpoint instead of immediately when the finding is recorded.

## Decisions

1. **Trigger surface (negative direction)**: a new top-level, optional, producer-owned array field
   on `.return-meta.json`, named `claim_invalidations`, set only by a research dispatch that
   machine-checks a refutation or closes a question by supersession. Each entry: `declaration_names`
   (array of strings — the sharp, grep-able keys), `kind` (`"refutation"` or `"supersession"`),
   `claim` (one-sentence human-readable statement of what was falsified/closed), and
   `evidence_path` (the probe/artifact substantiating it, mirroring `issue-log.md`'s
   `evidence_path` field name for consistency). Follows the existing "Multiple Sequential Writers"
   contract exactly like `proposed_file_scope`/`user_decision`: must survive any later writer's
   read-modify-write of the same file.

2. **Matching rule**: literal, case-sensitive, word-boundary substring matching of each
   `declaration_names` entry against the `title` and `description` fields of every **non-terminal**
   task in `state.json` (excluding `COMPLETED`, `ABANDONED`, `EXPANDED`) other than the producing
   task itself. **Explicit false-negative posture**: this will miss a refutation referenced only by
   paraphrase, pronoun, or restated claim without the declaration name or an explicit supersession
   marker present in the sibling task's own text — exactly the honest limitation the task requires
   be stated rather than papered over. It is deliberately NOT a semantic or natural-language
   claim-matcher.

3. **Advisory, never mutating**: confirmed. The sweep (and the future call site that invokes it)
   must never write to a task's `description`, `file_scope`, or `status`. Its own output is itself
   the complete deliverable — a list of flagged task numbers with the matched declaration name(s).

4. **Landing (where output goes)**: deferred, by design, to the same future wiring task that adds
   the call site to `orchestrate-cycle-postflight.sh` (see Findings, "call site... correctly
   deferred"). This task's concrete deliverable is the script's contract: given one or more
   `declaration_names` and a producing task number, it returns (stdout, JSON array) every matched
   `{task_number, matched_name}` pair across the open backlog, exits 0 unconditionally (advisory;
   never fails a dispatch), and writes nothing. The wiring task's job is to decide the durable
   sink (a per-task advisory record analogous to `.decisions.json`'s lazily-created JSON array, plus
   a console notice using the existing `${notice_prefix} NOTE:` convention already used throughout
   `orchestrate-cycle-postflight.sh`) — both reachable without inventing a new file-format
   convention, but out of scope for the narrow file_scope this task already declared.

5. **Positive direction verdict — option (i), harvest trigger, chosen over (ii) and (iii)**:
   - **Against (iii) a dedicated per-domain finding ledger**: would duplicate a mechanism
     (`memory_candidates` + vault + retrieval) that already exists, is already schema-stable, and
     is already wired into every dispatch's preflight. Building a second ledger beside an unused
     first one compounds the gap rather than closing it.
   - **Against (ii) `/distill --dream`**: wrong cadence and wrong grain. `--dream` is explicitly
     interactive, excluded from `--auto`, and surfaces *vault-wide recurring themes* with no
     existing memory or task coverage — not a directed "task A's recorded finding should reach
     task B" propagation at the moment B is dispatched. Routing this incident's fix through
     `--dream` would still require a human to run it at exactly the right moment, which is the
     same late-and-optional characteristic that caused the measured 75-of-127-minute loss.
   - **For (i)**: `memory-harvest.sh` already exists, already enforces a defensible precision
     threshold (`confidence >= 0.7`, self-reported by the producing agent under
     `return-metadata-file.md`'s existing Confidence Scoring Guidance — not a new matcher this
     task would need to design), already deduplicates against the index and filesystem, and
     already feeds the exact retrieval path (`memory-retrieve.sh`) that runs at every dispatch's
     preflight. The only change needed is a **new caller** — invoke `memory-harvest.sh
     <task_number>` immediately when a dispatch's `.return-meta.json` shows non-empty
     `memory_candidates`, rather than waiting for `/todo`'s archival batch. **Zero edits to
     `memory-harvest.sh` or to `skill-todo`'s separate inline Stage 7 logic are required** — this
     is a new, additional call site, not a change to the `/todo` consolidation work's owned script,
     so it does not cross the boundary the task amendment explicitly protects ("ADDED SCOPE TO
     SPAWN, NOT TO ABSORB" is not triggered because nothing about the owned script changes).
   - **Precision/recall posture for the positive direction**: inherited unchanged from the
     existing, already-live `memory-retrieve.sh` keyword-overlap/topic-match scorer (`TOKEN_BUDGET`,
     `MAX_ENTRIES=5`, `MIN_SCORE=1`) plus the harvest-side `confidence >= 0.7` gate. This sidesteps
     the "no equivalently sharp signal" problem the task amendment flags — the positive direction
     does not need a new matcher designed from scratch, because reusing the existing pipeline means
     its already-tuned, already-live false-positive rate carries over unchanged.

6. **Escape hatch: not triggered — correcting the amendment's own framing**. The amendment's
   rationale for keeping both directions in one task assumed they would share "the artifact walk
   this task already builds, plus a matching rule" — i.e., that the positive direction would need a
   new walker over `specs/NNN_*/summaries/` paired with a new matching rule, mirroring the negative
   direction's walk over task descriptions. Research found this assumption does not hold: the
   positive direction needs no new walker and no new matcher at all, because the dormant
   `memory_candidates` -> `memory-harvest.sh` -> vault -> `memory-retrieve.sh` pipeline already is
   that walker-and-matcher, fully built, merely uncalled. Each direction is independently small
   (one new narrow script + test for the negative direction; one new call site, with no new script,
   for the positive direction), and both call sites are deferred to the same future
   `orchestrate-cycle-postflight.sh` wiring task regardless. The combined scope does not exceed one
   dispatch, so the positive direction is **recorded here, not spawned as a separate task**. This
   divergence from the amendment's own stated mechanism is itself worth flagging as a plan-input
   correction, not silently substituted.

## Recommendations

1. Implementation phase should add `claim_invalidations` to
   `context/formats/return-metadata-file.md` (a new optional top-level field section, following the
   exact prose pattern already used for `proposed_file_scope`), plus the agent-contract template
   update that field requires (mirroring how `proposed_file_scope` is already referenced from
   `general-research-agent.md`'s own Stage 5/6/7 instructions).
2. Build `scripts/sweep-invalidated-claims.sh` (already in this task's declared `file_scope`) to the
   contract in Decision 4 above: CLI-testable, pure/read-only, JSON-out, exit-0-always.
3. Build `scripts/tests/test-sweep-invalidated-claims.sh` as a regression fixture directly
   reproducing the acceptance criterion: a synthetic `state.json` carrying analogs of the five
   originally-affected tasks (replace the real task numbers/descriptions with durable, anonymized
   stand-ins per `rules/no-task-references-in-deliverables.md` — the test fixture itself lives under
   `specs/**`/`scripts/tests/**` so real task numbers are permitted there, but keep the matched
   declaration name realistic) plus at least one non-matching control task, asserting the sweep
   returns exactly the matching set and leaves the fixture file byte-identical.
4. Record, as a follow-up item for whichever future task wires
   `orchestrate-cycle-postflight.sh`'s research-phase call site, that it should add **two** new
   calls at that one site: (a) `sweep-invalidated-claims.sh` keyed on this dispatch's
   `claim_invalidations`, and (b) `memory-harvest.sh <task_number>` keyed on this dispatch's
   non-empty `memory_candidates` — bundling both into the same wiring task rather than creating two
   separate contended-file tasks, per Decision 6.
5. Do not touch `scripts/memory-harvest.sh` or `skill-todo/SKILL.md`'s Stage 7 in this task or the
   wiring task described above — both stay exactly as they are; only a new caller is added
   elsewhere.

## Risks & Mitigations

- **Risk**: a declaration name used as a sweep key could coincidentally appear as a common English
  word or short identifier inside an unrelated task's description, producing a false positive.
  **Mitigation**: word-boundary matching (not a bare substring) and advisory-only posture mean a
  false positive costs a human one line of review, never a silent mutation — acceptable given the
  stated false-negative-biased precision posture.
- **Risk**: an immediate `memory-harvest.sh` call on every dispatch could harvest a candidate that
  is later contradicted by the same task's own subsequent work (a provisional finding harvested
  too early). **Mitigation**: `memory_candidates` are specified (per `return-metadata-file.md`) as
  self-contained reusable insights an agent judges confident enough to emit with `confidence >=
  0.7` already — the same bar `/todo`'s existing harvest applies today; moving the timing earlier
  does not relax that bar.
- **Risk**: adding a second call site into `orchestrate-cycle-postflight.sh` compounds the
  file's existing contention (already named in multiple open tasks' `file_scope`).
  **Mitigation**: explicitly recommended to land as one combined wiring task (Recommendation 4)
  rather than two, halving the number of future serializing edges against that file relative to
  treating the two directions as separate wiring efforts.

## Context Extension Recommendations

- **Topic**: the dormant-script pattern (`memory-harvest.sh` built, documented, and tested-never,
  because its only caller duplicates its logic inline instead of invoking it).
- **Gap**: no existing context file documents "grep for an uncalled script before building new
  harvest/sweep infrastructure" as a general research step; this report had to discover it by
  reading `memory-harvest.sh`'s own header comment directly.
- **Recommendation**: a short addition to a research-pattern doc (e.g.
  `context/patterns/context-discovery.md` or a new short pattern file) noting that a script's own
  header "presently uncalled" disclaimer is a strong signal worth searching for before any task
  proposes new cross-task propagation infrastructure.

## Appendix

- Searches performed: `jq` queries against `specs/state.json` (task 319, 285, 312 entries and the
  full `active_projects[].project_number` list); `git log --oneline --all | grep -i "task 285"`;
  targeted reads of `orchestrate-record-decision.sh`, `handoff-schema.md` (Handoff Writers,
  Postflight Boundary, Decisions File Schema sections), `return-metadata-file.md` (full file),
  `user-decision-contract.md` (full file), `issue-log.md` (full file), `errors.json` and
  `events.jsonl` samples, `memory-harvest.sh` and `memory-retrieve.sh` (headers and body), and
  `skill-todo/SKILL.md` Stage 7.
- Declaration-name-keyed sweep approach and the `NoFiniteWidthModel` worked example are as stated
  in the task description; this report does not re-verify the BimodalLogic repository directly
  (out of scope — a separate repository not present in this working tree).
