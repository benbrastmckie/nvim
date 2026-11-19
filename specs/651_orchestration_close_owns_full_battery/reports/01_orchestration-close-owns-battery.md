# Research Report: Task #651

**Task**: 651 - Make the orchestration, not the task, the unit that closes on the full gate battery
**Started**: 2026-11-18
**Completed**: 2026-11-18
**Effort**: ~2 hours
**Dependencies**: 610 (full_gate_verification_ceiling_and_stall) — [COMPLETED]; 650
(touched_path_verify_entry_and_unmapped_fallback) — [COMPLETED]; 599
(batch_gate_deferral_narrowing_for_project_sources) — [NOT STARTED, blocks Deliverable 5 only]
**Sources/Inputs**: Codebase (agent-system/extensions/core/**), specs/state.json, task 610's and
650's summaries/plans, .claude-extensions.json
**Artifacts**: specs/651_orchestration_close_owns_full_battery/reports/01_orchestration-close-owns-battery.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Deliverable 1 (batch-of-one deferral extension) is already DONE** — task 610 removed the
  `.task_numbers | length > 1` gate and shipped the mechanical half (batch-gate-pending marker +
  entry guards) that makes it safe. `context/contracts/batch-gate-stage.md` already documents
  the current, non-task-count-gated design. The dispatch's own "WHAT THE DESIGN DOES TODAY"
  framing is **stale** — written against the pre-610 state — and no further edit is owed here.
- **Deliverable 6 (owed-sweep discharge) is already DONE** — `orchestrate-batch-gate.sh` stamps
  `records/full-sweep-owed.jsonl` rows and carries `owed_discharged_count`/`owed_open_count`/
  `owed_open_roster` in its `batch_gate` record today.
- **Deliverable 5's declaration surface is already reserved, not built.**
  `context/standards/repo-level-declarations.md`'s `verification_scope` object names
  `closing_gate` as a field reserved explicitly "for the orchestration-close record" (this task).
  `scripts/lib/verification-scope-lib.sh` does not yet read or validate it. This is the correct,
  already-agreed seam — deliverable 5's job is to populate and wire it, not invent a new key.
- **Deliverable 2 (plan-format.md vocabulary) is NOT done.** `plan-format.md`'s `## Verification
  Tiers` table and its "final phase `full`... nothing is deferred past this tier" language, plus
  `planner-agent.md`'s explicit "the final phase itself declares `**Verification Tier**: full`,
  names the complete gate set in its own verification criteria" instruction, both still state the
  pre-batch-aware-deferral invariant. `scripts/validate-artifact.sh`'s tier check, however,
  **already accepts the amended invariant unmodified** — it validates only that the tier token is
  one of `prose|local|interface|full` and skips Tier-Justification measurement on the final
  phase; no code change is required there, only comment/doc alignment if any contradicts the new
  wording.
- **Deliverable 3's premise is largely vacuous in this repository as designed.** No skill or
  command other than `skill-orchestrate` ever dispatches an implementation agent (`grep -rn
  general-implementation-agent\|email-implementation-agent\|lean-implementation-agent\|...`
  across `skills/*/SKILL.md` and `commands/*.md` returns zero hits outside `skill-orchestrate`).
  There is today no live "implemented outside `/orchestrate`" path for this engine's own task
  types; the real residual risk is an **interrupted** `/orchestrate` invocation, which is
  Deliverable 4's concern, not a second entry point.
- **Deliverable 4 (red-close binding to task status) is NOT done and has no existing mechanism to
  extend.** `batch-gate-stage.md` is explicit: "No task's own `state.json` entry, status, or
  completion verdict is touched by this stage... out of this contract's scope." This is the
  largest genuinely open design question in the task.

## Context & Scope

Task 651 asks the orchestration engine itself — not each task's final implement phase — to be
the thing that owns discharging the complete gate battery, for every invocation shape including a
batch of one, and asks this research to settle the open design questions the dispatch's six
deliverables raise before any plan is authored. Scope here is read-only: re-derive what the
current, live design actually does (the dispatch explicitly warns the "WHAT THE DESIGN DOES
TODAY" bullets may be stale and asks for re-derivation before editing), and resolve or narrow the
six deliverables' open decisions enough for a plan to proceed without re-researching them.

Two sibling tasks landed very recently and change the premise substantially: 610
(`full_gate_verification_ceiling_and_stall`) completed 2026-11-19 and 650
(`touched_path_verify_entry_and_unmapped_fallback`) is also `[COMPLETED]`. Both are named in this
task's own Territory Edges as blocking prerequisites ("a task cannot stop closing on the full
battery until a trustworthy scoped check exists for its final phase"; "the guard is what makes
this record's policy enforceable; sequence 610 first"). Both prerequisites are now satisfied,
which is itself the single most important scope-narrowing finding of this research: three of the
task's six deliverables are already substantially or fully discharged by that prior work, and this
report's job shifts from "design all six" to "confirm which are done, and design only the rest."

## Findings

### Deliverable 1 — batch-of-one deferral extension: DONE (via task 610)

`scripts/orchestrate-cycle-plan.sh:2864-2878` (verbatim, current):

```
if [ "$g" = "implement" ]; then
  build_args+=(--batch-gate-deferral)
fi
```

The surrounding comment states explicitly: "NO LONGER gated on `.task_numbers | length > 1`
(Phase 4 of the gate-ceiling-fit work): a batch of one now receives this directive identically to
a genuine multi-task batch, closing the single-task invariance gap." The mechanical half that
makes this safe — a `specs/.orchestration/batch-gate-pending-<session_id>.json` marker written by
`orchestrate-cycle-plan.sh` whenever `.implement_agents` is non-empty, plus entry guards in
`verify-deploy.sh`/`run-all.sh` that mechanically refuse a nested, unfiltered battery while that
marker is live (exit 3, DEFERRED, never 0/1/2) — is also shipped and tested
(`test-batch-gate-pending-marker.sh`, 20/20 per task 610's summary). `batch-gate-stage.md`'s own
"Single-task invariance" subsection already documents this as current behavior, "superseded a
task-count-gated predecessor." **No further edit to the mechanism or to `batch-gate-stage.md` is
owed by this task** for Deliverable 1; the only residual action is correcting this task's own
dispatch-time "WHAT THE DESIGN DOES TODAY" framing in any downstream artifact that repeats it, so
a reader does not treat it as still live.

### Deliverable 6 — owed-sweep discharge: DONE

`scripts/orchestrate-batch-gate.sh:189-245` implements exactly what `batch-gate-stage.md`'s "Owed-
Sweep Discharge" section documents: for every task number in `.task_numbers`, it reads that task's
`records/full-sweep-owed.jsonl`, stamps every `discharged_ts == null` row with the current
timestamp **iff** `gate_exit_code -eq 0` and the invocation is not `--dry-run`, and carries
`owed_discharged_count`, `owed_open_count`, and `owed_open_roster` (an array of `{task, path}`)
in the `batch_gate` record consumed by `context/patterns/orchestrate-batch-results-template.md`'s
rendering. This closes the loop `scripts/verify-touched.sh`/`unmapped-fallback-lib.sh` (task 650)
opened. Nothing here is outstanding.

### Deliverable 5 — consumer-repository closing gate: declaration surface RESERVED, not yet read

`context/standards/repo-level-declarations.md`'s `## The verification_scope Entry Schema` section
(lines 120-168) already names the exact seam this deliverable needs:

```json
"verification_scope": {
  "tree_roots": [...],
  "project_suite_roots": [...],
  "resolver": {"command": "...", "compose": "union"},
  "project_gates": "<reserved for the project-sources record>",
  "closing_gate": "<reserved for the orchestration-close record>"
}
```

The document states plainly: "`project_gates`, `closing_gate` — RESERVED field names on this same
object, for the project-sources narrowing record and the orchestration-close record respectively
... `verification-scope-lib.sh` does not read or validate either one; they are named here so those
two records add fields to this one object rather than declaring a second, competing top-level
key." `closing_gate` is reserved **by name, for this task**, already. 599's own task description
independently confirms the same mutual awareness: "651 (orchestration_close_owns_full_battery)
makes the batch gate stage run the consumer repository's own declared closing gate. Whatever this
record chooses for the narrowing form should therefore declare two things per repository: the
narrowing form and the closing gate."

This means Deliverable 5's design question is **not** "where does the declaration live" (settled:
`verification_scope.closing_gate` on `.claude-extensions.json`) but **what shape `closing_gate`
takes and how Move 4 consumes it**, plus one genuinely open sub-question this research surfaces
and that no existing document answers:

**Open sub-question — evidence-pipeline compatibility.** `orchestrate-batch-gate.sh`'s entire
Capture/Confirm/Attribute pipeline (`batch-gate-stage.md`'s "Evidence Base" section) is built
around `deploy_findings_snapshot`'s `grep '^FINDING '`-filtered `verify-deploy.sh --findings`
output and `deploy_baseline_self_attributable_findings`'s identifier-matching against that exact
line shape. A consumer repository's own `closing_gate` command is very unlikely to emit that same
convention. Two shapes are available, and this research recommends the first:

1. **Contract the output shape.** `closing_gate` names a command that MUST emit `^FINDING `-
   prefixed lines (or the declaration additionally names a prefix/format the reader normalizes),
   so the existing attribution pipeline works unmodified against a declared command exactly as it
   does against `verify-deploy.sh --findings` today. This keeps one pipeline, one attribution
   algorithm, and treats `closing_gate` as "the thing that plays the role `verify-deploy.sh
   --findings` plays today," not a free-form arbitrary command.
2. **Exit-code-only evidence.** Any nonzero exit from the declared command is a batch-level,
   unattributed, blocking finding (no per-line attribution attempted). Simpler to wire, but
   discards the attribution story this whole record exists to improve, and produces a worse
   result for a consumer repository than for core — the opposite of the intended posture.

Recorded as a **Decision** below, since the plan this research feeds needs one answer, not two
live options.

The second measured consumer 599's own description names (`sf1-engine`, verifying a copied core
tree via `integration/tools/run-core-suite-three-roots.sh`) is further evidence this is a real,
not hypothetical, need — a second live consumer with its own closing-gate shape already exists in
the wild, outside this repository.

### Deliverable 2 — plan-format.md vocabulary settlement

**Current state (not yet amended):**
- `plan-format.md`'s `## Verification Tiers` table, `full` row: "The complete gate set for the
  repository: `bash .claude/scripts/verify-deploy.sh`... Nothing is deferred past this tier. This
  is the ceiling."
- Same file, "`**Tier Justification**:` — required on every non-final phase" subsection: "The
  final phase's `full` is mandated by the invariant below, not chosen."
- `agents/planner-agent.md:483-487`: "The final phase itself declares `**Verification Tier**:
  full`, names the complete gate set in its own verification criteria per plan-format.md's
  `## Verification Tiers` section."
- `agents/reviser-agent.md` carries **no duplicate copy** of this language (confirmed by grep —
  only generic "full" hits, none naming the final-phase contract) — it defers to plan-format.md
  by reference, so no edit is owed there beyond what plan-format.md itself changes.

These three statements collectively tell a planner the final phase's `full` tier means "run the
complete battery inside this phase," which is exactly the framing the batch-aware-deferral
mechanism (already built, Deliverable 1) has superseded at the dispatch level without plan-format.
md's own vocabulary ever being updated to match. The dispatch asks research to settle which of two
vocabulary shapes survives:

- **(a) Keep `full` as the tier token**, with an explicit "discharged at orchestration close"
  qualification layered onto its definition — i.e., the final phase still declares
  `**Verification Tier**: full`, but the tier's own table row and its "nothing is deferred past
  this tier" sentence are rewritten to say the complete set is owed once per *orchestration*, not
  once per *phase* — exactly mirroring what `## Batch-aware deferral`'s existing text already
  says about the *dispatch-time override*, just now said about the *tier's own baseline meaning*
  rather than only its override.
- **(b) Add a fifth, named tier value** (e.g. `deferred` or `close`) distinct from `full`.

**Recommendation: (a).** `scripts/validate-artifact.sh`'s tier check (verified by direct read,
`scripts/validate-artifact.sh:597-603`) validates only that the captured token matches
`^(prose|local|interface|full)$` — it does not independently require the final phase's
verification-criteria prose to literally name `verify-deploy.sh`; that requirement lives only in
planner-agent.md's prose instruction and plan-format.md's narrative, never in a mechanical check.
Choosing (a) means **zero code change to `validate-artifact.sh`'s accepted-value enum** — the
existing check already accepts a final phase declaring `full` with the amended meaning, exactly as
stated in the dispatch's own VERIFY clause ("validate-artifact.sh accepts a final phase written
under the amended invariant and still rejects an untiered phase"). Choosing (b) would require
widening that regex, widening `plan-format.md`'s `prose < local < interface < full` ordering
claim, and auditing every other consumer of the four-value enum (`update-task-status.sh`-adjacent
tooling, if any) for a fifth value it does not expect — a materially larger, riskier change for no
behavioral gain, since the override mechanism (Deliverable 1) already fully implements "discharged
elsewhere" as an *override* of an unchanged `full` declaration. Recorded as a Decision below.

**What remains to actually edit under (a)** — none of this is done yet:
1. `plan-format.md`'s `full` tier-table cell and the "mandated by the invariant... carries no
   justification line" sentence — rewrite to state: under `/orchestrate`, the final phase's `full`
   declaration is unconditionally discharged by Move 4's once-per-invocation close, not by an
   independent in-phase run; the phase's own in-dispatch obligation is the scoped tier the
   `## Batch Gate Deferral` directive names (today: unconditionally, per Deliverable 1). The
   non-negotiable invariant text ("the complete gate set still runs before a phase closes and
   before a task completes") needs a parallel clause: "...or before the orchestration that
   contains it concludes, whichever discharge mechanism actually applies."
2. `rules/plan-format-enforcement.md`'s mirrored prose (the deployed-tree copy of the same
   summary this file carries) needs the matching edit — it currently repeats the pre-amendment
   framing in its own words ("Required per-phase fields" section references plan-format.md's
   vocabulary by pointer, so it may need no new prose beyond what plan-format.md already states,
   but should be checked against the final wording once chosen).
3. `agents/planner-agent.md:483-487` — replace "the final phase itself declares
   `**Verification Tier**: full`, names the complete gate set in its own verification criteria"
   with language describing the deferral-aware obligation: the final phase still declares `full`,
   but its own verification criteria describe the scoped in-dispatch check plus an explicit
   deferral statement, per the (now-amended) plan-format.md contract — never independently
   invoking the full battery as the phase's own criterion.
4. No `agents/reviser-agent.md` edit is independently owed (see above) — confirm after (1)-(3) land
   that it still defers correctly and makes no stale restatement.
5. `scripts/validate-artifact.sh` — audit comments near the tier check and the Tier-Justification-
   measurement check (both already final-phase-aware) for any inline comment that restates the
   *old* meaning of `full` in a way that would now mislead a future editor; no functional change
   expected, per the analysis above.

### Deliverable 3 — the "non-orchestrated path": premise does not hold today

Grepping every `skills/*/SKILL.md` and `commands/*.md` for every implementation agent name
(`general-implementation-agent`, `email-implementation-agent`, `lean-implementation-agent`,
`nix-implementation-agent`, `neovim-implementation-agent`) returns matches **only** inside
`skills/skill-orchestrate/SKILL.md` (plus one passing mention of `general-implementation-agent.md`
inside `skill-git-workflow/SKILL.md`'s own doc-comment, not a dispatch call). `scripts/command-
route-agent.sh` — the dispatch helper `skill-orchestrate` calls to route a task type to its agent
— is itself invoked only from `skill-orchestrate/SKILL.md`. There is no standalone `/implement`
command in the command table (`.claude/CLAUDE.md`'s "Command Reference"), and no other skill
dispatches an implementation agent directly. **In this engine's current, live design, every
implement-phase dispatch for every task type this research could find passes through
`skill-orchestrate`'s Move loop**, which means it always receives Move 1's `--batch-gate-deferral`
flag (Deliverable 1, unconditional today) and is always a candidate for Move 4's close, as long as
the invocation reaches Move 4.

The one genuinely live gap this reframes rather than eliminates: an invocation that **starts**
inside `/orchestrate` (so Move 1-3 ran, dispatches happened, work was committed) but never
**reaches** Move 4 — a stop verdict, a crash, an operator interrupt, or a cycle-budget exhaustion
before the loop's own Move 4 step executes. This is not "implemented outside `/orchestrate`"; it
is "implemented inside `/orchestrate`, but the orchestration itself never finished its own close."
That is precisely Deliverable 4's "An orchestration that ends without running its close battery...
must leave an open, reported obligation" clause, not a second, independent entry point.

**Recommendation**: record Deliverable 3 as **resolved by observation, not by new mechanism** —
there is no live non-orchestrated implementation path in this repository to make honest, so no
"runs the complete gate set inline exactly as today" fallback is needed. The durable-record
alternative this deliverable asks to choose between collapses into Deliverable 4's own interrupted-
invocation obligation, which is the one place that actually needs a new mechanism. This finding
should be re-verified at implementation time with the same two greps above (agent names across
`skills/*/SKILL.md` and `commands/*.md`), since this is exactly the kind of currently-true
claim that a later-added skill or command could invalidate.

### Deliverable 4 — binding a red close battery to task status: the open design question

This is the one deliverable with no partial implementation and no reserved seam anywhere in the
codebase. `batch-gate-stage.md`'s own "The Executable Stage Body" section states flatly: "No
task's own `state.json` entry, status, or completion verdict is touched by this stage. A
`batch_gate` finding — attributed or unattributed — is rendered as a BATCH-level result,
informational to the user, never folded into one task's own completion status. Whether and how a
future task mechanically enforces against this record is explicitly out of this contract's
scope." Three sub-questions the dispatch poses, with findings/recommendations for each:

**(a) What does a red close mean for a task already marked `[COMPLETED]` in the same invocation?**
Today: nothing visible happens to that task at all beyond the batch-level render. The dispatch's
own floor requirement is "at minimum a durable, attributed, visible record per implicated task and
an explicit operator remedy." The closest existing precedent to model this on is exactly
`records/full-sweep-owed.jsonl` (task 650's mechanism, consumed by Deliverable 6 above): a
per-task, append-only, never-silently-dropped JSONL row, written at the same point
`orchestrate-batch-gate.sh` already computes per-task attribution (the "Attribute" step of its
Capture/Confirm/Attribute pipeline already has, in hand, exactly the set of tasks a given finding
is attributed to — no new attribution logic is needed, only a new write). Recommend a parallel
`records/close-battery-red.jsonl` row per implicated task, written unconditionally whenever that
task's own attributed-findings set is non-empty after a red `gate_exit_code`, never deleted, with
the same `discharged_ts`-style field this task's own future green re-run would stamp.

**(b) Should task completion be held until the close battery is green?** Recommend **no, as the
default** — record the rejected alternative explicitly, per the dispatch's own instruction. A
task's own completion verdict is decided by its own phase-closure evidence (`phase-closure.md`'s
no-promotion-without-evidence rule), which is unaffected by a batch-wide signal that, by
`batch-gate-stage.md`'s own documented reasoning, deliberately runs with full ambient load from
every sibling's work already present — holding status open pending a shared signal would make one
task's completion depend on another, unrelated task's files landing in the same invocation, which
is a correctness property the batch-attribution design explicitly tries to avoid conflating. Hold
status open only for a task that is **itself** the attributed cause (its own `modified_files`
positively named in the finding) — functionally, that task transitions toward `[PARTIAL]` or
`[BLOCKED]` (both already non-terminal, resumable exception states per
`.claude/CLAUDE.md`'s Status Markers section) rather than staying `[COMPLETED]`, rather than
inventing a new status value. A task attributed to NO finding, or only to the batch-level
unattributed set, keeps its `[COMPLETED]` status with the durable record from (a) attached, and an
operator remedy surfaced in the consolidated output.

**(c) An invocation that ends without running Move 4 at all** (stop verdict, crash, operator
interrupt — the scenario Deliverable 3's analysis above resolves into). Recommend: the batch-gate-
pending marker already written by `orchestrate-cycle-plan.sh` (Deliverable 1's own mechanical
half) is itself already the "open obligation" signal — it is staleness-bounded
(`BATCH_GATE_MARKER_STALE_SEC`, default 3600s) and today is consumed only by the entry guards (to
refuse a nested unfiltered battery). This deliverable's remaining work is to additionally surface
a **stale, undischarged marker** (one whose age exceeds the staleness window, found by a later
invocation or an explicit check) as a reported, visible obligation — e.g. at the next
`/orchestrate` invocation's own startup, or via a dedicated inspection the dispatch's VERIFY clause
implies ("an interrupted invocation leaves a reported open obligation"). This reuses an existing
artifact rather than inventing a second one; no new marker format is needed, only a new reader.

## Recommendations

1. Treat Deliverables 1 and 6 as **already satisfied** by task 610 and task 650's shipped work —
   no plan phase is owed for either beyond a documentation sanity-check that no surface still
   repeats the pre-610 framing (see Deliverable 1's finding above for exactly which framing is
   now stale).
2. For Deliverable 2, adopt vocabulary option (a) — keep `full` as the tier token, amend its
   stated meaning under `/orchestrate` to "discharged at orchestration close," and make the four
   edits enumerated in that finding's "What remains" list (plan-format.md, plan-format-
   enforcement.md, planner-agent.md; reviser-agent.md and validate-artifact.sh need only
   verification, not functional edits).
3. For Deliverable 3, record the vacuous-premise finding as this task's own settled answer rather
   than building a fallback mechanism for a path that does not exist; re-verify the two greps at
   implementation time as a cheap, load-bearing confirmation step.
4. For Deliverable 4, build the `records/close-battery-red.jsonl` per-task record (modeled
   directly on `full-sweep-owed.jsonl`'s shape and the existing Attribute step's already-computed
   per-task finding sets) plus a stale-marker surfacing step for the interrupted-invocation case,
   and hold status open only for a task that is itself the attributed cause of a red close,
   reusing `[PARTIAL]`/`[BLOCKED]` rather than a new status value.
5. For Deliverable 5, populate `verification_scope.closing_gate` per the schema
   `repo-level-declarations.md` already reserves, contract its emitted output to the same
   `^FINDING `-prefixed convention `verify-deploy.sh --findings` already uses so
   `orchestrate-batch-gate.sh`'s existing Capture/Confirm/Attribute pipeline needs no new
   attribution logic, and fail open to today's unnarrowed `verify-deploy.sh` invocation when the
   key is absent (the same fail-open posture every other `verification_scope` field already uses).
   Sequence this deliverable's plan phase after, or jointly with, task 599's own plan — both edit
   `orchestrate-build-dispatch.sh`'s directive composition and
   `test-orchestrate-build-dispatch.sh`, as the Territory Edges note already states.
6. File a small, separate note (not a new task, unless the implementing plan prefers one) that
   `context/standards/repo-level-declarations.md` contains a dangling internal cross-reference —
   "(see 'Decisions Settled' below)" at line 159 — to a heading that does not exist anywhere in
   that file. Whoever implements Deliverable 5 should either add that heading with the two
   records' actual settled decisions, or remove the dangling pointer.

## Decisions

- **Deliverable 2's tier-vocabulary choice**: `full` stays the single top tier token; its meaning
  under `/orchestrate` is amended to "discharged once at orchestration close," not split into a
  fifth tier value. Ground: `validate-artifact.sh`'s existing four-value enum check requires zero
  code change under this choice, and the override mechanism (Deliverable 1) already implements
  "discharged elsewhere" as a deferral layered on an unchanged `full` declaration — a fifth tier
  value would duplicate a distinction the system already expresses a different way. Rejected
  alternative: a new named tier (e.g. `deferred`) — rejected for the reasons given in the
  Deliverable 2 finding above (wider blast radius, no corresponding behavioral gain).
- **Deliverable 5's evidence-pipeline shape for a declared `closing_gate`**: the declared command
  MUST emit `^FINDING `-prefixed lines compatible with `deploy_findings_snapshot`'s existing
  filter, so the Capture/Confirm/Attribute pipeline (`batch-gate-stage.md`'s "Evidence Base"
  section) runs unmodified against it. Rejected alternative: exit-code-only evidence with no
  attribution — rejected because it gives a consumer repository's own closing gate a strictly
  worse attribution story than core's own `verify-deploy.sh` gets today, the opposite of this
  task's intent to generalize the mechanism, not degrade it for every repository but core.
- **Deliverable 3's scope**: no new mechanism is built for a "non-orchestrated implementation
  path," because none exists live in this repository as currently wired (confirmed by exhaustive
  grep across every `skills/*/SKILL.md` and `commands/*.md`). The interrupted-`/orchestrate`-
  invocation case this deliverable's prose also gestures at is folded into Deliverable 4 rather
  than kept as a separate concern, since it is the same underlying event (Move 4 never ran) viewed
  from two different angles.
- **Deliverable 4's status-binding shape**: a red close battery attaches a durable, attributed,
  append-only per-task record (`records/close-battery-red.jsonl`, modeled on
  `full-sweep-owed.jsonl`) and surfaces an explicit operator remedy; it does **not** hold task
  completion open as a default policy, except for a task that is itself the finding's attributed
  cause, which uses the existing `[PARTIAL]`/`[BLOCKED]` exception states rather than a new status
  value. Rejected alternative: holding every implicated task's completion open pending a green
  close — rejected because it couples one task's completion to unrelated siblings' files under
  concurrency, the exact attribution hazard `batch-gate-stage.md`'s own design already argues
  against for the shared-capture mechanism itself.

## Risks & Mitigations

- **Risk**: Deliverable 5's plan phase and task 599's own plan phase both edit
  `orchestrate-build-dispatch.sh`'s directive-composition block and
  `scripts/tests/test-orchestrate-build-dispatch.sh` — a genuine two-writer collision if the two
  tasks' implement phases run concurrently in the same `/orchestrate` batch.
  **Mitigation**: the Territory Edges section already names this and asks for by-hand
  reconciliation; the implementing plan should add an explicit dependency edge (not merely a
  territory note) so the two are sequenced rather than batched concurrently, per
  `context/patterns/batch-orchestration-guardrails.md`'s batching-is-the-default guidance's own
  carve-out for genuine unordered overlap.
- **Risk**: this report's Deliverable 3 finding ("no live non-orchestrated path") is a claim about
  the current state of two directories (`skills/`, `commands/`) that can be invalidated by any
  future skill or command addition.
  **Mitigation**: re-run the same two greps at the start of Deliverable 3's implement phase, not
  only at research time, and treat a new hit as cause to re-open the deliverable rather than trust
  this report's count.
- **Risk**: Deliverable 4's new per-task record format, if under-specified, could drift from
  `full-sweep-owed.jsonl`'s shape in a way that complicates a future consumer trying to read both.
  **Mitigation**: the implementing plan should explicitly declare `close-battery-red.jsonl`'s
  schema as a sibling of, not a copy-paste divergence from, `full-sweep-owed.jsonl`'s existing
  row shape (same `discharged_ts`-null-until-paid convention), and name both in whichever context
  file documents the pattern generically if one is added.

## Context Extension Recommendations

- **Topic**: `verification_scope.closing_gate`'s consumer-side contract (what Move 4 does once the
  field is populated).
  **Gap**: `repo-level-declarations.md` names the field and reserves it but documents no reader
  function, no fail-open table row for it, and no attribution-pipeline interaction — unlike
  `project_gates`' and `closing_gate`'s sibling fields (`tree_roots`, `resolver.command`), which
  all have full fail-open rows today.
  **Recommendation**: once Deliverable 5 lands, add a `closing_gate` row to that document's
  existing Fail-Open-on-Absence Guarantee table and a short subsection parallel to `resolver`'s,
  naming the exact `^FINDING `-emission contract this report's Decision above settles.
- **Topic**: the dangling "(see 'Decisions Settled' below)" cross-reference.
  **Gap**: `repo-level-declarations.md:159` points at a heading that does not exist in the file.
  **Recommendation**: add the heading (recording the `project_gates`/`closing_gate` reservation
  decisions as settled, cross-linking 599 and this task) or remove the dangling pointer, whichever
  Deliverable 5's implementer finds cheaper once the real decisions are written up there.

## Appendix

### Search queries / commands used

- `grep -n "length > 1\|length>1\|batch-gate-deferral\|batch_gate_deferral" scripts/orchestrate-cycle-plan.sh scripts/orchestrate-build-dispatch.sh`
- `grep -n "owed_discharged_count\|owed_open_count\|owed_open_roster\|full-sweep-owed\|discharged_ts" scripts/orchestrate-batch-gate.sh`
- `grep -n "full\b" scripts/validate-artifact.sh | grep -i "tier\|verification"`
- `grep -n "full\|final phase\|Verification Tier" agents/planner-agent.md agents/reviser-agent.md`
- `grep -rln "general-implementation-agent\|email-implementation-agent\|lean-implementation-agent\|nix-implementation-agent\|neovim-implementation-agent" skills/*/SKILL.md commands/*.md`
- `jq` queries against `specs/state.json` for tasks 610, 599, 454, 452, 564, 650, 645, 651 status

### Key paths referenced

- `agent-system/extensions/core/context/contracts/batch-gate-stage.md`
- `agent-system/extensions/core/context/formats/plan-format.md` (`## Verification Tiers`,
  `### Batch-aware deferral`)
- `agent-system/extensions/core/context/standards/repo-level-declarations.md`
  (`## The verification_scope Entry Schema`)
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh:2858-3233`
- `agent-system/extensions/core/scripts/orchestrate-batch-gate.sh` (full file, 267 lines)
- `agent-system/extensions/core/scripts/validate-artifact.sh:560-800`
- `agent-system/extensions/core/agents/planner-agent.md:216-487`
- `agent-system/extensions/core/agents/general-implementation-agent.md:505-525`
- `specs/610_full_gate_verification_ceiling_and_stall/summaries/01_gate-ceiling-fit-and-stall-detection-summary.md`
- `specs/650_touched_path_verify_entry_and_unmapped_fallback/plans/01_touched-path-entry-and-fallback.md`
