# Research Report: Task #273

**Task**: 273 - Three-channel orchestration conclusion stage with per-channel approval, as a
distinct post-postflight stage
**Started**: 2026-10-08T08:58:30Z
**Completed**: 2026-10-08T09:40:00Z
**Effort**: ~6 hours (research only; this is "the largest open orchestrator task" per the
dispatch's own Size Note)
**Dependencies**: Task 271 (completed), Task 184 (archived/completed), Task 329 (archived/
completed), Task 306 (completed) — all four resolved, none blocking
**Sources/Inputs**: Codebase (`agent-system/extensions/core/**`), task archive (184, 329),
completed-task summaries (271, 306), `specs/state.json`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **184 reconciliation verdict: RESOLUTION B (scope-limited coexistence).** Task 184's "do NOT
  auto-create tasks" clause is textually and structurally scoped, identically to its two sibling
  clauses in the same enumerated list, to one narrow trigger: `orchestrate-cycle-postflight.sh`'s
  per-task completion-claim gate firing on `handoff.skeleton == true` with a non-empty
  `sorry_inventory[]`. It never was a general principle about all orchestration follow-ups. No
  overturn is needed; 184 and 273 govern disjoint mechanisms (one per-task/mechanical/skeleton-
  only, one per-invocation/judgment-based/general) and can both stand unchanged.
- **The issue-log (task 329) is the correct, and only correct, aggregation carrier.** Of the
  four named existing channels, `issues.jsonl`/`issue-record.sh` is purpose-built for subagent
  contribution and already names "the conclusion stage" as its consumer throughout its own format
  doc. `.return-meta.json`'s `detected_defects` + the "System Defects Detected" table is a
  *different, orthogonal* channel: it is written only by the orchestrator engine's own mechanical
  detectors (stale handoff, etc.), never by a dispatched subagent, so it cannot carry subagent
  contributions and must not be conflated with or subsumed by the new stage.
- **Addition 2's "measured complication" is now stale.** Dependency task 306 completed since this
  dispatch was filed and built a brand-new live `scripts/roadmap-integration.sh` at the real
  (non-deprecated) path, already in 306's own `file_scope`. The deprecated copy is dead/
  quarantined and irrelevant. Correct the planned `file_scope` widening accordingly (see
  Recommendations).
- **306 currently has zero live callers, not two.** Neither `/todo` nor `/review` wires
  `--prune`/`--regenerate` yet. This task's roadmap update is the *first* live caller, which
  simplifies — rather than complicates — the "third caller" reconciliation question.
- **A new Move 5, once per `/orchestrate` invocation, is the right placement.** It sits after
  Move 4's consolidated output and batch-level state write (SKILL.md's existing final steps),
  never inside per-task `orchestrate-cycle-postflight.sh` and never inside the per-dispatch
  Postflight Boundary (`docs/architecture/handoff-schema.md`'s "Postflight Boundary" section,
  which is explicitly "After each stage dispatch... returns" — a different, narrower boundary
  than the one this task must write).
- **Strong, reusable precedent exists for all three channels' mechanics** (not their approval
  gates, which are new): channel (c)'s task-creation-with-`parent_task` is `skill-spawn/
  SKILL.md`'s Stage 11, verbatim-reusable; channel (b)'s pre-dispatch-confirmation gate mirrors
  `meta-builder-agent.md`'s existing `collected_answers.confirmed` contract (it cannot call
  `AskUserQuestion` itself — the gate must happen at the orchestrator-lead level, before
  dispatch); channel (a) has no direct precedent and needs a new "final cleanup agent" dispatch
  shape.

## Context & Scope

Researched: the 184 reconciliation (verbatim ruling text, its actual implementation, and its
current documentation in `status-markers.md`); the issue-log infrastructure built by task 329;
the `detected_defects`/System-Defects-Detected mechanism as the other named existing channel; the
roadmap generation script built by task 306 and its caller contract; the `parent_task` edge
finished by task 271; `git-commit-scoped.sh`'s existing interface; the `skill-orchestrate`
four-move loop's structure and where a new stage would plug in; the meta-builder-agent's
anti-bypass constraint and its `AskUserQuestion`-withholding; and `skill-spawn`'s existing
task-creation-with-parentage mechanism.

Not researched in depth (left for planning): the exact script/file split for the new stage's
aggregation logic; the precise `AskUserQuestion` wording/batching for the three channels; whether
one dispatch of a "final cleanup agent" per approved fix or one dispatch covering all approved
fixes is more consistent with existing dispatch-shape conventions; the exact commit-message/
scoping template for each of the three channels plus the roadmap edit.

## Findings

### Codebase Patterns

**The four-move loop and where Move 5 goes.** `skills/skill-orchestrate/SKILL.md` documents
Move 1 (plan cycle) → Move 2 (dispatch) → Move 3 (per-task postflight, `orchestrate-cycle-
postflight.sh`) → Move 4 (branch: loop back to Move 1, or finalize). Move 4's finalization
sequence, read directly from SKILL.md and `docs/architecture/orchestrate-state-machine.md`'s
"Consolidated Output and Exit-Status Resolution" section, is, in order: resolve `exit_status` →
batched `AskUserQuestion` relay for `pending_ask_user[]` → batched stall re-prompt relay → emit
the consolidated output (`orchestrate-batch-results-template.md`) → non-blocking residue check →
release session registry → remove `.dispatch/` for completed tasks → write
`.return-meta-multi-${session_id}.json`. The new conclusion stage is a **Move 5**, positioned
strictly after all of this — i.e. after the batch's own state is already closed and written —
never interleaved with it and never inside per-task Move 3. This placement is what makes "runs
AFTER postflight has closed state and committed" concretely true: both the per-task postflight
(Move 3, one `git-commit-scoped.sh`-mediated commit per task/phase) and the batch-level
finalization (Move 4, which writes the multi-task return-meta file) are done before Move 5 ever
starts.

**The per-dispatch Postflight Boundary is a different, narrower boundary than the one this task
writes.** `docs/architecture/handoff-schema.md`'s "Postflight Boundary" section opens: "After
each stage dispatch (research/plan/implement) returns, the lead MUST NOT..." — this is Move 3's
per-dispatch boundary, implemented solely by `orchestrate-cycle-postflight.sh`, with one named
exception (D4, verbatim-recovery). `context/standards/postflight-tool-restrictions.md`'s existing
table documents the identical boundary. Neither document's existing table should be edited to
carry the new stage's rules — the dispatch's own instruction to add a **new, separate**
allowed/prohibited table to `postflight-tool-restrictions.md` is correct and necessary, because
Move 5's tool surface is categorically different (it must Edit source files for channel (a), must
invoke `meta-builder-agent`/`AskUserQuestion` for channel (b), must call `state-write.sh`-backed
task creation for channel (c), and must commit via `git-commit-scoped.sh` — every one of which
the existing table expressly prohibits for Move 3). Recommend titling it something like "## Move
5 (Conclusion Stage) Tool Restrictions" immediately after the existing table, explicitly cross-
referencing it as a sibling, not a replacement.

**Task 184's ruling, read in full, is narrowly and explicitly scoped — confirmed by its own
implementation.** The archived ruling text (`specs/archive/184_decide_lean_skeleton_plan_
completion_routing/.dispatch/5.md`, `10.md`, `14.md`, all byte-identical on this point) reads:

> "SCOPE (now concrete; no further decision phase). In `orchestrate-cycle-postflight.sh`, when
> the final implement handoff carries `skeleton=true` and a non-empty `sorry_inventory[]`: (i)
> print the follow_up_task entries in the cycle's stderr report...; (ii) record them on the
> state.json entry in an append-only field...; (iii) do NOT auto-create tasks: the report is the
> handoff and the user files them with `/task`."

Items (i), (ii), and (iii) are three enumerated consequences of the **same** opening clause ("In
`orchestrate-cycle-postflight.sh`, when the final implement handoff carries `skeleton=true` and a
non-empty `sorry_inventory[]`"). There is no principled reading under which (i) and (ii) are
scoped to that trigger while (iii) somehow escapes it and becomes a general principle — all three
share one antecedent. This is confirmed, not merely inferred, by the actual implementation
(`specs/archive/184_.../summaries/01_skeleton-follow-up-reporting-summary.md`): the delivered
mechanism lives entirely inside `orchestrate-cycle-postflight.sh`'s `implemented)` case, gated on
`handoff.skeleton == true` plus a `strategic == true` filter over `sorry_inventory[]`, reporting
via stderr + `completion_summary` + a new append-only `skeleton_follow_ups` state.json field —
and is now also documented, at the same narrow scope, in `context/standards/status-markers.md`'s
`[COMPLETED]` section under a "Skeleton-plan terminus" paragraph: "a strategic-sorry skeleton
plan... reaches `[COMPLETED]` through this same ordinary completion-claim gate as any other task
... Its strategic `sorry_inventory[]` entries are not auto-filed as tasks... The human files any
follow-up with `/task`." Every piece of corroborating evidence — the ruling text's grammar, the
delivered code, and the standing documentation — agrees the scope is: one task type (Lean/formal
skeleton plans), one trigger (`skeleton==true` + non-empty `sorry_inventory`), one detecting site
(the per-task completion-claim gate), one payload shape (`follow_up_task` entries already present
on a handoff field). Task 273's conclusion stage is none of these: it is task-type-agnostic, fires
once per whole `/orchestrate` invocation (not per-task-completion), derives its payload from the
aggregated `issues.jsonl` logs of every touched task, and — critically — gates task creation
behind an *explicit, interactively-confirmed, per-channel* approval that 184's mechanism never had
available to it (184's mechanism is pure shell inside a non-interactive per-task postflight path,
where `AskUserQuestion` is correctly out of scope per the Postflight Boundary above).

**Verdict and rationale for the losing resolution (Resolution A), recorded per the acceptance
criterion.** Resolution A ("narrow overturn": reinterpret 184's premise as "unapproved creation,"
declare per-channel approval removes that premise, and rewrite 184's scope to match) is not
chosen because it requires treating 184's own enumerated scope clause as broader than its text
and its delivered implementation actually support — it answers a contradiction that, on the
evidence above, does not exist. Overturning a ruling to resolve an apparent conflict is the right
move when the conflict is real; here, doing so would rewrite a narrow, mechanically-implemented,
and already-documented ruling to "fix" a reading of it that the ruling's own grammar does not
require. Resolution A's practical outcome (task creation permitted under explicit approval) is in
fact identical to Resolution B's — the two resolutions differ only in whether 184 needs to be
touched at all, and the narrower, non-destructive option (leave 184's scope exactly as written
and documented; let 273 govern the disjoint general case) is preferred when both reach the same
operational result. The cost Resolution B accepts, as the dispatch itself names: two adjacent
mechanisms producing follow-ups via two different routes (the `skeleton_follow_ups` trio for
strategic sorries; the issue-log-derived three-channel stage for everything else) — nothing
prevents an agent from *also* recording a strategic-sorry observation via `issue-record.sh` under
the open `class`/`tags` seam if it judges that worthwhile, so the two mechanisms are not even
mutually exclusive in practice, merely non-identical. A future task may choose to fold
`skeleton_follow_ups` into the general mechanism once both have run long enough to show it is
worth the migration cost — not forced here.

**The issue-log (task 329) is the correct aggregation carrier; `detected_defects` is a distinct,
orthogonal mechanism that is NOT a viable substitute.** `context/formats/issue-log.md` (task
329's deliverable) already states, in its own text, four separate times, that "the conclusion
stage" is `issues.jsonl`'s intended reader — including an explicit "Unknown-Class Tally — A Note
for the Conclusion Stage" section. Every dispatch already receives a "## Issue Log" section in
its composed dispatch file (`orchestrate-build-dispatch.sh` lines ~527-547) instructing it to call
`issue-record.sh` "AS THEY ARISE," for every phase (`research`/`plan`/`implement`/`conclusion`/
`other`) — this task's own dispatch file (`.dispatch/16.md`) carries exactly this section, and
this report itself used it twice during research (see Issue Log in `specs/273_.../issues.jsonl`).
By contrast, `detected_defects` (defined canonically in `orchestrate-state-machine.md`'s "Loop-
Owned Runtime State" section) is written exclusively by the orchestrator ENGINE's own mechanical
detectors — e.g. a stale-or-absent handoff, a dispatch-seq mismatch — via
`skill_orchestrate_merge_return_meta` in `scripts/skill-base.sh`. No dispatched subagent ever
writes to it; it answers "did the orchestrator's own machinery misbehave," not "what did this
subagent observe." `docs/architecture/orchestrate-state-machine.md` states explicitly: "no site in
this mechanism may call `AskUserQuestion`... accumulate-then-render is the deterministic
default," and it already has its own render path (`commands/orchestrate.md`'s "System Defects
Detected" table) that is **unconditional observation reporting, never gated by approval** — by
design, since these are mechanical facts about the engine, not proposals. Recommend: the new
stage's required "reason for rejecting all four [existing channels]" is — (1) `issues.jsonl` is
not rejected; it is adopted as the sole payload source; (2) `detected_defects`/System-Defects-
Detected is rejected as a *general-contribution carrier* because it structurally cannot receive
subagent writes and its own accumulate-then-render contract is incompatible with gated, three-way
channel proposals — it stays exactly as-is, continuing to render unconditionally and
independently of the new stage, never merged into it.

**Making issue-log contribution "mandatory rather than incidental" is a real, open gap.**
`context/contracts/phase-closure.md`'s "Record issues and wins during the phase" section (loaded
in both hard and standard modes) uses "Call... AS SOON AS an event worth recording happens" —
encouragement, not an enforced requirement, and nothing today verifies that a dispatch which
*should* have recorded something actually did. `general-implementation-agent.md` is the one
call site with a concrete, mandatory trigger (an out-of-scope path drop during commit staging
MUST also call `issue-record.sh`); research/plan agents and the general case have no comparable
trigger. Planning should decide the enforcement mechanism (a postflight presence/sanity check, a
stronger agent-prompt MUST, or an explicit "did you consider recording an issue" self-check field
in `.return-meta.json`) — this is a planning decision, not resolved here, but the gap is
confirmed real and the one existing mandatory precedent (`general-implementation-agent.md`'s
scope-excursion call site) is a usable template for how to word a second one.

**Addition 2's "measured complication" is stale; the live path is the correct `file_scope`
target.** At filing time (2026-10-07), `scripts/roadmap-integration.sh` genuinely did not exist
outside `scripts/deprecated/`. Task 306 has since completed (confirmed: `state.json`'s
`project_number: 306` entry has `"status": "completed"`) and built a fresh, live
`scripts/roadmap-integration.sh` (`--print`/`--regenerate`/`--prune`/`--dry-run`), already
registered in **306's own `file_scope`** (`agent-system/extensions/core/scripts/roadmap-
integration.sh`, confirmed verbatim in `state.json`) and in `manifest.json`'s `provides.scripts`.
The deprecated copy (`scripts/deprecated/roadmap-integration.sh`) remains quarantined, dead, and
irrelevant to this task. This means the dispatch's "detection gap" (273 and 306 targeting the same
script but declaring non-overlapping path strings) **no longer exists**: both tasks already name
the identical live path. Planning should widen `file_scope` to `agent-system/extensions/core/
scripts/roadmap-integration.sh` (the live path), NOT `scripts/deprecated/roadmap-integration.sh` —
using the deprecated path would target a dead file and miss the real collision-detection benefit
entirely.

**306 has zero live callers today, not two — this task would be the first.**
`context/patterns/roadmap-update.md` (306's own caller contract) states under "No Live Caller
Yet": "neither `/todo`'s skill... nor `/review`... invokes either mode. The dependent wiring work
was originally scoped to two tasks that were later abandoned and folded into a broader backlog
item's description that carries no dependency edge back to this contract... A wiring follow-up
should be filed." This simplifies Addition 2's "flag for the user" requirement: there is no
existing two-caller pattern to reconcile against a third caller, because there is no existing
caller at all. Two separate things should be flagged for the user, not conflated: (1) whether
306's documented `/todo`-prunes / `/review`-regenerates responsibility split needs a sentence
added naming `/orchestrate`'s conclusion stage as a third (now: first-in-practice) caller — a
one-line addition to `roadmap-update.md`, in 306's own territory, not editable by this task
silently; (2) the pre-existing, already-recorded 306 follow-up that `/todo` and `/review`
themselves still have no wiring at all — an independent gap this task does not need to fix, but
should surface as a candidate channel-(c) or channel-(b) proposal input if it recurs in issue
logs.

**`git-commit-scoped.sh` already exists and is ready to invoke; task 304 only patches it
later.** The script (`agent-system/extensions/core/scripts/git-commit-scoped.sh`, 33KB, already
deployed) is the "single sanctioned implementation of the scoped-commit contract" today — it
already serializes add+commit through `task-lock.sh`'s commit mutex, already supports per-task
contended-path claims via `--task N`, and already injects task-directory ephemeral-file excludes
automatically. Task 304 (which depends on 273, confirmed in `state.json`) will later fix a
specific out-of-repo-pathspec bug and extend `return-metadata-file.md`/`git-staging-scope.md`; none
of that blocks this task's use of the script as it exists today. Each of this task's three
channels plus the roadmap edit should get its own `git-commit-scoped.sh` invocation (separate
pathspecs, separate commit messages following the `task {N}: {action}` convention), per the
dispatch's explicit instruction not to sweep them into one undifferentiated commit.

**Channel (c)'s mechanics have a direct, reusable precedent: `skill-spawn/SKILL.md`'s Stage
11.** That stage already (a) walks a `dependency_order` array of proposed new tasks, (b) resolves
internal cross-references to real task numbers, (c) writes each via `state-write.sh` with
`"parent_task": $parent` set to the originating task number, inheriting the parent's `topic`.
This is exactly channel (c)'s required shape ("recorded as CHILDREN of the originating task via
the `parent_task` edge") and should be reused nearly verbatim, substituting the issue-log-derived
proposal list for `spawn-agent`'s blocker-analysis list. Note `skill-spawn` itself has **no**
general "approve these new tasks?" gate before Stage 11 — invoking `/spawn` at all is the user's
approval. The new stage's channel-(c) gate is therefore new work, not reused from `skill-spawn`,
and should follow the pattern below instead.

**Channel (b)'s approval gate has a direct, reusable precedent: `meta-builder-agent.md`'s
`collected_answers.confirmed` contract — and a hard constraint to preserve.**
`agents/meta-builder-agent.md`'s own "FORBIDDEN" list states: "**Call `AskUserQuestion`** — this
agent runs as a dispatched subagent and cannot call it (measured...). Every user choice is
collected by `skill-meta` **before** this agent is dispatched." This means channel (b)'s approval
must happen at the orchestrator-lead level (the Move-5 body itself, which — like Move 4's existing
batched `AskUserQuestion` relay for `pending_ask_user[]` — runs as the lead's own turn, not as a
dispatched subagent) strictly *before* `meta-builder-agent` is ever invoked, mirroring
`skill-meta`'s existing pre-delegation interview pattern exactly: compose the proposal text from
the issue-log derivation, ask once (batched with the other two channels' questions, per the
existing Move-4 "batched... never mid-cycle, never one call per task" convention), and only on an
explicit yes pass `collected_answers.confirmed: true` plus the proposal content into the
`meta-builder-agent` dispatch. The anti-bypass constraint itself (`meta-builder-agent` "NEVER
implements changes directly... creates TASKS only") is untouched by any of this — it governs what
the agent does once dispatched, which this task does not change.

**Channel (a) has no direct precedent in the codebase; it needs a new dispatch shape.** No
existing "final cleanup agent" exists. `general-implementation-agent` is the closest analog
(Edit/Write/Bash access, already governed by `source-store-deploy-boundary.md` and the file_scope
scope-excursion recording convention) but is always dispatched against a specific task's own plan
— there is no precedent for dispatching it against a *synthesized, cross-task* fix list derived
from the conclusion stage's own aggregation. Planning should decide whether to reuse
`general-implementation-agent` directly (with a purpose-built dispatch body naming the approved
fix list) or define a new, narrowly-scoped agent. Either way this is new design work, not a
simple reuse.

### External Resources

Not applicable — this is a pure in-repo infrastructure task; no external documentation was
consulted.

## Decisions

- **184/273 reconciliation: Resolution B (scope-limited coexistence).** 184's "do NOT auto-create
  tasks" clause is scoped to the skeleton-sorry mechanism only, by its own grammar and its
  delivered implementation; it does not bind 273's disjoint, general, approval-gated mechanism.
  Neither task's description needs rewriting; no edit to 184's archived artifacts is made or
  needed. (See Findings above for the full textual/implementation evidence and the losing
  Resolution A's rationale, both recorded per the acceptance criterion.)
- **`issues.jsonl`/`issue-record.sh` is the sole payload carrier for the new stage's three
  channels.** `detected_defects`/"System Defects Detected" remains a separate, unconditional,
  ungated observation channel and must not be merged into or subsumed by the new stage.
- **`file_scope` must target the live `agent-system/extensions/core/scripts/roadmap-
  integration.sh`, not the quarantined `scripts/deprecated/roadmap-integration.sh`.** The
  dispatch's Addition 2 "measured complication" and its associated detection-gap concern are both
  stale as of 306's completion; recorded as an issue-log entry (see Issue Log) rather than left
  standing silently in this report alone.
- **The new stage is Move 5**, running once per `/orchestrate` invocation after Move 4's
  consolidated output and batch-state write — never inside `orchestrate-cycle-postflight.sh`,
  never interleaved with per-task Move 3, and documented as such in both
  `docs/architecture/orchestrate-state-machine.md` and `skills/skill-orchestrate/SKILL.md`.
- **The new postflight-tool-restrictions.md table is additive, not a merge** into the existing
  per-dispatch Postflight Boundary table — the two boundaries govern different actors at
  different pipeline moments with deliberately different allowances.

## Recommendations

1. Carry the Resolution-B verdict into the plan's own description/acceptance language verbatim,
   quoting 184's enumerated SCOPE clause structure as the grounding evidence, so a future reader
   does not need to re-derive it.
2. Plan the new Move 5 stage as: (a) an aggregation step reading every touched task's
   `issues.jsonl` (mechanical: filter `resolution in {open, worked_around}`, separate `kind:
   "win"` entries into a summary-only bucket, group recurring `class` values across tasks); (b) a
   judgment step, performed by the orchestrator lead itself (not a script, since classification
   into exactly one of three channels and visible overriding of `suggested_channel` hints
   requires reasoning, not a deterministic rule) — this step is compatible with the Context
   Flatness Constraint, which only forbids reading `reports/*.md`/`plans/*.md`/`summaries/*.md`/
   `handoffs/*.md`, not `issues.jsonl`; (c) three independent `AskUserQuestion` gates (batched in
   one relay call per the existing Move-4 convention, never auto-approving one from another's
   answer); (d) per-approved-channel execution — (a) dispatch a cleanup agent, (b) dispatch
   `meta-builder-agent` with `collected_answers.confirmed: true`, (c) create child tasks via the
   `skill-spawn` Stage-11 pattern; (e) the roadmap update via `roadmap-integration.sh
   --regenerate` (recommend regenerate over prune/print, since the conclusion stage's own content
   — newly completed tasks — is exactly what `--regenerate`'s retention-aware rebuild is for;
   `--prune` additionally removes terminal tasks' lines entirely, which may be too aggressive for
   an automatic unattended call without a separate approval — flag this mode choice for planning,
   not settled here); (f) one `git-commit-scoped.sh` invocation per channel plus one for the
   roadmap edit, each independently staged and attributed.
3. Add the new allowed/prohibited table to `postflight-tool-restrictions.md` under a clearly
   distinct heading (e.g. "## Move 5 (Conclusion Stage) Tool Restrictions"), explicitly stating
   it is additive to, not a replacement for, the existing per-dispatch Postflight Boundary table,
   and covering both the tool surface (Edit/Write/Bash scope per channel) and the commit surface
   (which `git-commit-scoped.sh` pathspecs are in-scope per channel).
4. File, or at minimum flag for the user in this task's own plan, the two 306-adjacent follow-ups
   surfaced above: (i) a one-line addition to `context/patterns/roadmap-update.md` naming
   `/orchestrate`'s conclusion stage as a caller (306's own territory — flag, do not silently
   edit); (ii) the still-open, independently-recorded 306 follow-up that `/todo`/`/review`
   themselves remain unwired.
5. Decide the "mandatory contribution" mechanism explicitly as a planning task (not resolved
   here): the only existing mandatory precedent is `general-implementation-agent.md`'s
   scope-excursion call site; a comparable, explicit MUST for at least the implementation agent's
   general case (not just the scope-excursion sub-case) is the minimum needed to make "mandatory
   rather than incidental" true rather than aspirational.
6. Build the fixtures the acceptance section requires test-first per channel: each channel firing
   independently (three fixtures: (a) alone, (b) alone, (c) alone, each showing the other two
   channels' absence of effect), plus one fixture showing the anti-bypass constraint still holds
   (`meta-builder-agent` dispatch under channel (b) produces a task, never a direct edit).

## Risks & Mitigations

- **Risk**: Treating `detected_defects` as mergeable into the new stage's channels, because both
  "sound like" defect reporting. **Mitigation**: the structural distinction (subagent-writable
  vs. engine-only-writable) is load-bearing and documented above; planning must preserve it.
- **Risk**: Choosing `--prune` as the conclusion-stage roadmap mode without separate consideration
  — `--prune` removes content, which is a stronger unattended action than `--regenerate`'s
  retention-aware rebuild. **Mitigation**: flagged explicitly in Recommendation 2(e) for a
  deliberate planning choice, not a default.
- **Risk**: Editing `roadmap-update.md`'s responsibility-split prose silently while "just wiring
  the third caller." **Mitigation**: the dispatch's own instruction to flag rather than silently
  edit is reinforced in Recommendation 4; 306's own file is a cross-task edit this task should
  treat as a flag, not a direct change, absent a dependency edge granting that territory.
- **Risk**: Given the Size Note's own acknowledgment that this is the largest open orchestrator
  task, a single monolithic plan phase risks being unreviewable. **Mitigation**: the dispatch
  already directs planning to "flag immediately if it should be divided via `/task --expand`" —
  this research does not resolve that question but surfaces at least five independently-testable
  sub-units above (184 doc reconciliation; aggregation+judgment; three approval gates; three
  execution paths; roadmap wiring; commit contract) that a plan or an expand decision should use
  as phase/subtask boundaries.

## Context Extension Recommendations

- **Topic**: Conclusion-stage placement relative to the four-move loop.
- **Gap**: `docs/architecture/orchestrate-state-machine.md` currently documents Moves 1-4 in
  full detail but has no "Move 5" section at all — this task's own acceptance criterion requires
  adding one.
- **Recommendation**: add a new top-level section to `orchestrate-state-machine.md`, sited
  immediately after "Consolidated Output and Exit-Status Resolution," titled something like
  "## Move 5: Conclusion Stage" — this is itself part of this task's deliverable, not a
  separate follow-up task.

## Appendix

- Read: `specs/273_.../.dispatch/16.md` (full dispatch context); `specs/state.json` (273/271/
  306/184/329/304 entries); `specs/archive/184_.../.dispatch/{5,10,14}.md`; `specs/archive/
  184_.../summaries/01_skeleton-follow-up-reporting-summary.md`; `context/standards/status-
  markers.md` (`[COMPLETED]` section); `context/formats/issue-log.md` (full); `scripts/issue-
  record.sh` (header); `scripts/orchestrate-build-dispatch.sh` (Issue Log section); `context/
  contracts/phase-closure.md`, `context/contracts/wrap-up.md` (issue-record call sites);
  `agents/general-implementation-agent.md` (scope-excursion call site); `context/standards/
  postflight-tool-restrictions.md` (full); `skills/skill-orchestrate/SKILL.md` (Moves 1-4,
  MUST NOT sections); `docs/architecture/handoff-schema.md` ("Postflight Boundary" section);
  `docs/architecture/orchestrate-state-machine.md` (Loop-Owned Runtime State, Consolidated
  Output sections); `commands/orchestrate.md` (System Defects Detected table); `specs/
  306_.../summaries/01_roadmap-generation-contract-summary.md`; `context/patterns/roadmap-
  update.md` (full); `scripts/roadmap-integration.sh` (header); `specs/271_.../summaries/
  01_finish-parent-task-edge-summary.md`; `scripts/git-commit-scoped.sh` (header); `skills/
  skill-spawn/SKILL.md` (Stage 11); `agents/spawn-agent.md`; `agents/meta-builder-agent.md`
  (Constraints section); `context/standards/user-decision-contract.md` (overview).
- No web search performed — pure in-repo infrastructure research.
