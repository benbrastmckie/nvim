# Research Report: Task #242

**Task**: 242 - orchestrate partial-with-blocker stops redispatch
**Started**: 2026-09-22
**Completed**: 2026-09-22
**Effort**: medium (root-cause is a single wiring gap; fix is narrow, well-integrated with
existing machinery)
**Dependencies**: None
**Sources/Inputs**: Codebase read-through only (no web search needed — this is a self-contained
orchestrator defect)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Root cause identified precisely**: `scripts/orchestrate-cycle-postflight.sh`'s
  `partial|failed|blocked)` case arm (around line 792) never writes state.json's `status` field
  for a `partial` (or `blocked`) dispatch outcome — the comment literally says "No state.json
  transition performed; the task remains at its current in-flight status." Since `status` stays
  `implementing`, `orchestrate-triage-classify.sh`'s already-existing, already-tested
  `partial + blockers, no continuation -> needs_human` routing rule (its own header table, and
  `scripts/orchestrate-triage-classify.sh:78-86`) **never fires**, because that rule is keyed on
  `status == "partial"` and status is never actually set to `"partial"`. The `implementing`
  status row routes unconditionally to `implement`, with no blocker/continuation inspection at
  all. This is the entire mechanism behind the futile-redispatch defect.
- **Recommended fix (decided, not a candidate list)**: make the `partial` case arm call
  `update-task-status.sh postflight <N> partial` (via `skill_postflight_update`, mirroring the
  already-present `needs_research)` arm's pattern two cases above it) **unconditionally**
  whenever `dispatch_status == "partial"` — not only when `blockers[]` is non-empty. This is
  `postflight:partial`, an already-wired, already-tested `update-task-status.sh` transition
  (`scripts/update-task-status.sh:296`) whose own comment says it exists precisely for this:
  "state-management.md's permissive transition model admits partial/blocked from [IMPLEMENTING]
  on timeout/error." It was simply never called from the orchestrate postflight path.
- **This single change satisfies deliverable points 1 and 2 together, with no edits needed in
  `orchestrate-cycle-plan.sh` at all** — once `status` is genuinely `"partial"`,
  `orchestrate-triage-classify.sh`'s existing three-way precedence
  (continuation-pointer → `implement`; else non-empty `blockers[]` → `needs_human`; else →
  `implement`) does the discrimination correctly and automatically, for **both** the empty- and
  non-empty-`blockers[]` sub-cases, with **zero new branching**. `needs_human` already (a)
  appends the task to `failed_tasks` (excluding it from `eligible_tasks` for the rest of the run
  — `orchestrate-cycle-plan.sh:1592`) and (b) emits a visible `out_blocked_rows` entry (never a
  silent `skip`) — `orchestrate-cycle-plan.sh:1594`. Ordinary in-progress partials (empty
  `blockers[]`, no continuation) still resolve to `implement` under the same table, so today's
  defer/immediate-retry behavior for genuine work-in-progress is preserved byte-for-byte.
- **Rejected alternative — do NOT resolve to `status = "blocked"`** (candidate (a) in the
  dispatch's literal wording). `blocked` status in `orchestrate-triage-classify.sh` is
  overloaded with **dependency-graph discharge semantics** (`blocked, dependency outstanding or
  empty dependencies[] -> skip` for the multi-task engine — `orchestrate-triage-classify.sh:81`).
  An externally-blocked task (no `dependencies[]`, e.g. a missing upstream release asset) would
  land in that `skip` bucket, which is a **silent** `continue` in `orchestrate-cycle-plan.sh`
  (`orchestrate-cycle-plan.sh:1607-1610`) — no `out_blocked_rows` entry, invisible to the
  user/operator. That is arguably *worse* than the original defect (indefinite silent
  exclusion vs. indefinite futile retry). `status = "partial"` avoids this hazard entirely: the
  `partial + blockers` row always resolves to `needs_human`, which is always visible, in both
  engines.
- **Blocker-research aux escalation should still fire** for this case, reusing the existing
  `blocker-research` aux-signal mechanism (currently gated on `verdict == "blocked"` in
  `orchestrate-cycle-postflight.sh` around line 1012) — widen that gate to also cover
  `dispatch_status == "partial"` with non-empty `blockers[]`. Note the existing mechanism reads
  its human-readable description from state.json's own `.active_projects[].blockers` **string**
  field (distinct from the handoff's `blockers[]` **array**), which today is never written by any
  script — it must be seeded (e.g. at task creation, or by `/spawn`) or the aux signal falls back
  to `"Unspecified blocker"`. For this task's fix, derive a description from the handoff's
  `blockers[0].target`/`why_it_failed` instead of relying on that string field being present.
- **Agent-contract guidance** (deliverable point 3): the fix does not require agents to switch to
  `dispatch_status: "blocked"` for this scenario — the observed real-world case (implementer
  returned `"partial"` with a populated `blockers[]` entry at 3/4 phases) is already
  schema-legitimate per `docs/architecture/handoff-schema.md`'s own `blockers` field doc ("Non-empty
  only when `status = partial` or `status = blocked`"). The gap was purely on the orchestrator's
  reading side. Guidance should state the decision rule explicitly (see Decisions below) and
  should live in `context/contracts/wrap-up.md` (the shared H9 handoff contract), not be
  duplicated across every implementer agent file.

## Context & Scope

Task 242 investigates a defect observed live during a multi-task `/orchestrate` run in a sibling
repository: an implementer returned `.orchestrator-handoff.json` with `status: "partial"`,
`phases_completed: 3`, `phases_total: 4`, and a fully-populated `blockers[]` entry describing an
external, unrecoverable cause (a missing upstream release asset). `orchestrate-cycle-postflight.sh`
mapped this to verdict `defer`, left `state.json`'s task `status` untouched (still
`implementing`), and ignored `blockers[]` entirely. The next cycle's
`orchestrate-cycle-plan.sh` would have re-dispatched `implement` again — futile, since the
external cause cannot be resolved by another implementation attempt. The operator had to
manually run `update-task-status.sh postflight <N> blocked` to stop the loop.

Scope, per the dispatch's named files: `scripts/orchestrate-cycle-postflight.sh` and
`scripts/orchestrate-cycle-plan.sh` (the multi-task engine — the observed defect came from a
multi-task `/orchestrate` invocation), `agents/general-implementation-agent.md` (and sibling
implementer contracts sharing the handoff shape), and
`scripts/tests/test-orchestrate-cycle-postflight.sh`. The single-task engine's parallel Stage 4
handoff-triage logic (`skills/skill-orchestrate/SKILL.md`) is architecturally separate — it does
not currently call `orchestrate-triage-classify.sh --engine single` anywhere in the live code path
(only the `mt` engine argument is exercised outside the classifier's own tests) — and is out of
this task's named scope; flagged as a follow-up concern below, not addressed here.

## Findings

### Codebase Patterns

**The defect's exact mechanism** (confirmed by direct read, not inference):

1. `orchestrate-cycle-postflight.sh:792` — the `partial|failed|blocked)` case arm performs no
   state.json write for any of the three statuses; comment: "No state.json transition performed;
   the task remains at its current in-flight status."
2. `orchestrate-cycle-postflight.sh:944` — verdict resolution: `partial) verdict="defer" ;;`
   (unconditional, does not look at `blockers`).
3. `orchestrate-cycle-postflight.sh:1012-1023` — a `blocker-research` aux signal (informational,
   feeds a *separate* aux dispatch next cycle) fires only when `verdict == "blocked"` — i.e. only
   for a literal `dispatch_status: "blocked"`, never for `partial` regardless of `blockers[]`
   content. This aux signal does not by itself stop the main per-task `implement` redispatch — it
   only schedules an *additional* research dispatch.
4. `orchestrate-cycle-plan.sh` (both `mt` invocations, e.g. line ~1426) reads
   `current_statuses[$t]` from state.json and passes it to `orchestrate-triage-classify.sh`.
5. `orchestrate-triage-classify.sh`'s own header table (lines 66-86) already fully specifies the
   correct behavior:
   ```
   | planned, implementing                      | implement   | implement     |
   | partial + continuation                     | implement   | implement     |
   | partial + blockers, no continuation         | needs_human | needs_human   |
   | partial, neither                            | implement   | implement     |
   ```
   Because state.json `status` is always `implementing` (per finding 1), row 1 always wins — the
   `partial`-specific rows 2-4, including the exact discrimination this task needs, are **dead
   code** for every `/orchestrate`-driven partial outcome today.
6. Confirmed this is not accidental: `context/schemas`/`update-task-status.sh:291-297` already
   define and validate `postflight:partial` -> `STATE_STATUS="partial"` as a legitimate,
   schema-checked transition, with a comment explicitly citing
   "state-management.md's permissive transition model admits partial/blocked from [IMPLEMENTING]
   on timeout/error" — i.e., the target behavior was designed and wired on the
   `update-task-status.sh` side, but the caller (`orchestrate-cycle-postflight.sh`) never invokes
   it for a `partial` outcome. `state-management.md` (imported into `.claude/CLAUDE.md`) lists
   `[IMPLEMENTING] -> [PARTIAL]` as a documented, expected transition "on timeout/error" — this
   fix restores that already-documented contract rather than inventing new behavior.
7. `needs_human` handling in `orchestrate-cycle-plan.sh:1592-1595` already does everything
   deliverable point 2 asks for, with no code change needed there: appends to `failed_tasks`
   (excluded from `eligible_tasks` for the rest of the run, checked at
   `orchestrate-cycle-plan.sh:1408` and `:1304`/`:1322`) and emits a visible `out_blocked_rows`
   entry.
8. Contrast with `skip` (`orchestrate-cycle-plan.sh:1607-1610`): a silent `continue`, no row
   emitted at all. This is the concrete, evidenced reason `status = "blocked"` is the wrong
   target for an externally-blocked (non-dependency) task: `orchestrate-triage-classify.sh`'s
   `blocked` handling discriminates by `dependencies[]` discharge state (lines ~ near the
   `blocked` row group), and a task with empty `dependencies[]` — exactly this scenario, an
   external environment/release blocker, not a dependency on another task — routes to `skip` in
   the `mt` engine, not `needs_human`.
9. `.active_projects[].blockers` (a string, distinct from the handoff's `blockers[]` array) is
   read by the existing `blocker-research` aux-signal code
   (`orchestrate-cycle-postflight.sh:1016-1018`, falls back to `"Unspecified blocker"`), and is
   used as a pre-seeded fixture value in
   `scripts/tests/test-orchestrate-cycle-postflight.sh:1184` (`"blockers": "Missing API key"`),
   but is never *written* by any script grepped in this codebase — it is apparently populated
   only by hand or by task-creation tooling outside this defect's scope. For this task's fix, do
   not rely on it being populated; build the aux-signal description directly from the handoff's
   `blockers[0]` fields instead.
10. `skill-spawn/SKILL.md:90-91,156` already recognizes `status` values `blocked`, `implementing`,
    **and `partial`** as triggering a "blocker-driven spawn" — confirming `status = "partial"`
    with blockers is already an integrated, expected target state for the broader recovery
    ecosystem (not a new concept this task must invent).
11. `.orchestrator-handoff.json`'s `blockers` field is already fully specified in
    `docs/architecture/handoff-schema.md:226-248`: non-empty only when `status = "partial"` or
    `status = "blocked"`, canonical shape `{phase, target, verbatim_goal, what_was_tried,
    why_it_failed}`. The real-world defect's handoff was already schema-conformant — nothing to
    fix on the schema side.
12. `general-implementation-agent.md`'s `.return-meta.json` status vocabulary (Stage 7,
    line ~648) is `implemented|partial|failed` — **no `blocked`**. Only
    `.orchestrator-handoff.json` (the H9 wrap-up, written only when `orchestrator_mode: true`)
    carries the fuller `implemented|partial|blocked` vocabulary
    (general-implementation-agent.md line ~742). This confirms the real defect scenario is
    specifically an orchestrator-mode dispatch reading `.orchestrator-handoff.json`, matching the
    evidence source.
13. `context/contracts/wrap-up.md` is the single shared H9 handoff contract referenced (via "the
    shape defined by...") by roughly 60 implementer/research agent files across every extension
    (`grep -rl "orchestrator-handoff.json" */agents/*.md` — core, cslib, email, epidemiology,
    filetypes, formal, founder, latex, lean, nix, nvim, present, python, rust, typst, web, z3).
    Editing each individually is not tractable or DRY; the wrap-up.md contract is the correct
    single edit point for "blocked vs. partial" guidance (see Decisions).

### External Resources

None consulted — this is a self-contained internal-tooling defect; no external library/API
research applies.

## Decisions

1. **Fix location and mechanism**: in `orchestrate-cycle-postflight.sh`'s status-transition case
   switch (currently `partial|failed|blocked)` at line ~792), split out a dedicated `partial)`
   arm that calls `skill_postflight_update "$task_number" ... "partial" ...` (mirroring the
   `needs_research)` arm's call pattern two cases below it, which already demonstrates the
   correct `skill_postflight_update` invocation shape for a postflight-only terminus) —
   **unconditionally on every `dispatch_status == "partial"` outcome**, not gated on
   `blockers[]` content. `failed`/`blocked` keep their current no-transition-here behavior
   unchanged (their own paths — verdict `failed`/`blocked` and, for `blocked`, the `failed_tasks`
   append at WORK (j) — already work correctly and are out of this task's scope; note candidate
   (a)'s implicit assumption that `blocked` also needs a status fix was investigated and found
   NOT to be part of this defect — `blocked` dispatch outcomes already stop same-run redispatch
   via `failed_tasks`, independent of the state.json `status` field).
   - Rationale for the *unconditional* (not blockers-gated) form: `orchestrate-triage-classify.sh`
     already resolves the empty-`blockers[]` sub-case identically to today's `implementing`-status
     behavior (both route to `implement`), so this simplification changes nothing observable for
     ordinary in-progress partials while correctly activating the `needs_human` row for the
     blockers-populated sub-case. A blockers-gated conditional would work too but adds branching
     that the already-tested classifier makes unnecessary — prefer the unconditional form.
2. **Do not introduce a new verdict value or a new state.json status value.** `postflight:partial`
   already exists, is already schema-validated (`status_vocabulary_is_valid`), and is already the
   designed target per `state-management.md`. No `orchestrator-cycle-plan.sh` changes are needed
   for deliverable point 2 — verify this with a new regression test rather than new code (see
   below); the existing `needs_human` → `failed_tasks` + `out_blocked_rows` wiring already
   satisfies it.
3. **Blocker-research aux escalation**: widen the existing `if [ "$verdict" = "blocked" ]` gate
   (`orchestrate-cycle-postflight.sh:1012`) to also cover `dispatch_status == "partial"` with a
   non-empty handoff `blockers[]` array, so the operator still gets the useful "investigate this
   blocker" aux dispatch that already exists for the `blocked` case — this was the actual value
   candidate (a) was pointing at, decoupled from the (rejected) idea of changing the state.json
   `status` value itself. Build `blocker_desc` from `blockers[0].target`
   (+ `why_it_failed` if present) rather than assuming `.active_projects[].blockers` is populated
   (finding 9).
4. **Agent-contract guidance (deliverable point 3)**: add a concise decision rule to
   `context/contracts/wrap-up.md` near its existing `status` field documentation (around line 43),
   phrased approximately: *use `blocked` when no further implementation effort of any kind can
   proceed (the task is stuck at the outset or entirely); use `partial` with a populated
   `blockers[]` entry (and no continuation pointer) when some phases completed successfully but a
   specific remaining phase is blocked by a cause outside the agent's control (e.g. external
   service/asset unavailability) that no further implementation attempt on THIS phase can close —
   do not report `failed` in that case, since `failed` implies non-recoverable and would discard
   the credit for completed phases.* Add a one-line pointer from
   `agents/general-implementation-agent.md`'s existing `.orchestrator-handoff.json` section (it
   already says "Use the shape defined by...") to this new wrap-up.md subsection, rather than
   duplicating the guidance in every implementer agent file (finding 13) — this matches the
   codebase's own stated DRY bias (e.g. `orchestrate-triage-classify.sh`'s explicit "one code
   path... cannot drift into two silently-diverging copies again" rationale for its own table).
5. **Regression tests (deliverable point 4)**: extend
   `scripts/tests/test-orchestrate-cycle-postflight.sh`. Existing fixtures at line 1036
   (task 820, hard-mode churn) and line 1098 (task 821, base-mode churn negative-check) already
   use a `partial` + populated `blockers` handoff shape — reuse that exact fixture shape for new,
   dedicated assertions:
   - New case: `partial` + non-empty `blockers[]`, no continuation pointer -> assert
     `state.json`'s `active_projects[].status` for that task is now `"partial"` (read state.json
     after `run_sut`, mirroring how other tests read `$WORKDIR/specs/state.json` post-run — not
     just the stdout `>&3` line, which already echoes `dispatch_status` verbatim per the existing
     `acceptance (5)` test at line 340 and is not evidence of the state.json write).
   - New case: `partial` + empty `blockers[]` (reuse the tasks 822/823 drift fixtures, or a fresh
     minimal fixture) -> assert `state.json`'s `status` is **unchanged from its pre-run value**
     (still `implementing`), preserving the "current defer behaviour... must be preserved"
     deliverable requirement explicitly.
   - Optional but valuable: a companion assertion (or a new test in
     `scripts/tests/test-orchestrate-cycle-plan.sh`) that runs `orchestrate-cycle-plan.sh`
     against the resulting `status: "partial"` + populated-`blockers` state.json and asserts the
     task lands in `out_blocked_rows`/`needs_human`, not dispatched to `implement` — this directly
     demonstrates deliverable point 2 end-to-end rather than relying on the already-existing
     `orchestrate-triage-classify.sh` test suite as indirect evidence.

## Risks & Mitigations

- **Risk**: making `postflight:partial` unconditional could interact unexpectedly with the
  `user_decision` relay path (WORK (e), `orchestrate-cycle-postflight.sh:900-920`), where a
  `partial` outcome can also carry a `user_decision` payload (see the existing `acceptance (5)`
  test, line ~321, `partial` + `user_decision`). **Mitigation**: the state-transition case switch
  and the `user_decision`/verdict resolution are independent code sections today (the case switch
  runs first, unconditionally; `user_decision` only affects the *verdict* field, never the
  state.json write). Confirm during implementation that writing `status = "partial"` alongside an
  `ask_user` verdict is harmless (it should be — the task is genuinely incomplete either way) but
  call this out explicitly as a case worth a fixture in the new tests.
- **Risk**: `monotonic-max` status clamping (`skill_postflight_update`'s `status_clamp_mode`,
  `scripts/skill-base.sh:877-899`) could skip the write if `"partial"` is judged a "regression"
  from some ranked status. **Mitigation**: the `needs_research)` arm two cases above already calls
  `skill_postflight_update` without a clamp mode in the non-forced ordinary path; use the same
  (unclamped) call shape for `partial` unless there's a `force_invoked` interaction that argues
  otherwise — check `status_vocabulary_would_regress`'s ranking during implementation, since
  `partial` needs to be treated as a legitimate lateral/informational move from `implementing`,
  not a regression to be clamped away.
- **Risk**: widening the blocker-research aux-signal gate (Decision 3) could double-fire if a task
  is later ALSO reported with literal `dispatch_status: "blocked"` in a subsequent cycle.
  **Mitigation**: the existing `aux_pending` single-slot-per-task design already handles this (a
  fresh aux signal simply overwrites the pending one); no new risk beyond what already exists for
  the `blocked` case today.

## Context Extension Recommendations

- **Topic**: `orchestrate-triage-classify.sh`'s `partial`-status rows were dead code for every
  live `/orchestrate` invocation until this fix.
- **Gap**: no context file currently documents the state.json-`status`-must-be-written-for-the-
  classifier-to-discriminate dependency between `orchestrate-cycle-postflight.sh` and
  `orchestrate-triage-classify.sh` — this was discovered only by direct cross-file read.
- **Recommendation**: once implemented, add a short cross-reference comment (not a new context
  file) at both `orchestrate-cycle-postflight.sh`'s `partial)` arm and
  `orchestrate-triage-classify.sh`'s `partial + blockers` table row, each pointing at the other,
  so a future reader does not have to re-derive this dependency from scratch the way this research
  pass did.

## Appendix

- Files read in full or near-full: `scripts/orchestrate-cycle-postflight.sh`,
  `scripts/orchestrate-cycle-plan.sh` (targeted sections), `scripts/orchestrate-triage-classify.sh`
  (header/table + targeted body), `scripts/update-task-status.sh` (targeted),
  `scripts/skill-base.sh` (`skill_postflight_update`, targeted),
  `docs/architecture/handoff-schema.md` (targeted), `agents/general-implementation-agent.md`
  (targeted), `context/contracts/wrap-up.md` (targeted), `skills/skill-spawn/SKILL.md` (targeted),
  `scripts/tests/test-orchestrate-cycle-postflight.sh` (targeted).
- Key greps: `grep -n "partial\|blocker\|defer" scripts/orchestrate-cycle-postflight.sh`;
  `grep -rln "orchestrate-triage-classify" scripts/ commands/ docs/`;
  `grep -rl "orchestrator-handoff.json" */agents/*.md` (extension-wide scope check for deliverable
  point 3).
