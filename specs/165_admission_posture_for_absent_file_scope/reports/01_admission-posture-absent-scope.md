# Research Report

**Task**: 165 - Admission gates in orchestrate-batch-admit.sh: posture for an absent
`file_scope`, then cross-session visibility for self-modifying candidates
**Started**: 2026-09-29T15:43:00Z
**Completed**: 2026-09-29T16:30:00Z
**Effort**: ~1.5 hours
**Dependencies**: 162 (formalize files-to-modify / harvest), 163 (surface missing/empty
file_scope), 245 (batch-admit defer against admitted-set only) — all three archived/completed
**Sources/Inputs**: codebase (`orchestrate-batch-admit.sh`, `lib/file-scope-overlap.sh`,
`orchestrate-predispatch-review.sh`, `validate-state.sh`, `backfill-file-scope.sh`,
`plan-file-scope-harvest.sh`, `docs/architecture/batch-admit-schema.md`,
`context/patterns/batch-orchestration-guardrails.md`), live measurement of three repos'
`specs/state.json` (this repo, `~/Projects/BimodalLogic`, `~/Projects/Logos/Verification`)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Coverage measurement settles the tradeoff named in the dispatch**: the backfill/harvest
  mitigation (tasks 162+163) has **not** landed uniformly. This repo is 27/28 covered (96%) and
  `Logos/Verification` is 32/33 (97%), but **`BimodalLogic` — the repo where the motivating harm
  itself occurred — is only 18/43 covered (42%); 25 of 43 non-terminal tasks still lack
  `file_scope`**, almost entirely `not_started` (plan-less) tasks that `backfill-file-scope.sh`
  deliberately, correctly leaves absent by design (it only harvests from an existing plan).
  Legacy backlog is real and current, not a solved problem.
- One BimodalLogic task (410, status `planned`, plan artifact on disk) is a genuine harvest
  miss, not a design gap: its plan uses a `## Territory Contract` table instead of the
  `**Files to modify**:` per-phase field `plan-file-scope-harvest.sh` parses, so harvest silently
  returns nothing for it. Recorded as a residual, not something to fix in this task's scope.
- **Recommended ruling — split the posture by scope kind, not one blanket answer**: keep
  cross-batch absence **advisory-only** (option a) — blocking it now would strand the 25-task
  BimodalLogic backlog on the very axis this task exists to protect against — but make **in-batch**
  absence **blocking** via the same designated-candidate convergence pattern `self_modifying`
  already uses (a narrow slice of option c/d). In-batch is cheap to serialize (extra cycles only,
  no legacy-backlog dependency, since it only ever concerns candidates being dispatched *this
  cycle*) and is exactly where the second evidence block's 8-task in-batch incident showed the
  worst outcome (concurrent gate runs regenerating a committed certificate).
- **A second, independently confirmed defect** (absorbed ex-task 190): the self-modification
  branch's precedence (D4: self-mod runs first and short-circuits) means a **solo-admitted
  self-modifying candidate never reaches the `session_active` (or collision) pass at all** —
  confirmed directly in the jq source, not just asserted. The fix is additive only (surface the
  hazard on the admit verdict; never change the admit decision), matching this script's own
  non-bump precedent (v5's tie-breaker/phase-map change), not a `defer_reason` change.
- Adding a **new `defer_reason` value** (needed only for the in-batch blocking half of the
  ruling) requires a schema version bump to v6 and consumer updates, per this script's own
  Version History precedent (every prior new-`defer_reason` addition, v1→v2 and v3→v4, was a
  version bump with an explicit consumer table) — `orchestrate-predispatch-review.sh`'s Class
  selects are a closed `if/else` per class and silently drop an unrecognized `defer_reason`.
- Promotion criterion (to record in the header, mirroring `validate-state.sh` Check 10's own
  wording and plan-format.md's Verification Tier precedent): promote cross-batch absence from
  advisory to blocking once `bash .claude/scripts/validate-state.sh --strict` reports zero
  `missing_key`/`null_value` findings for Check 10 across the deployed repos this system
  targets — a directly re-usable, already-implemented measurement, not a new one to invent.

## Context & Scope

Task 165 asks whether an absent `file_scope` should be admission-relevant in
`orchestrate-batch-admit.sh` (currently purely advisory — an absent/empty scope trivially never
overlaps anything, so it silently passes every collision check), and separately (absorbed from
former task 190) whether a solo self-modifying candidate's cross-session blindness should be
fixed. Both are `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` concerns,
gated behind three now-completed prerequisites: task 162 (plan-time `file_scope` harvest wired
into the plan lifecycle going forward), task 163 (WARN-only *detection* of missing/empty/glob
`file_scope`, in `validate-state.sh` Checks 10/11 and `orchestrate-predispatch-review.sh` Classes
F/G — but explicitly **not** wired into the admission decision itself), and task 245 (the
admitted-set-only in-batch collision narrowing, already live in the v5 script).

This research phase does not implement anything; it establishes the factual basis (does the
backfill mitigation actually cover the legacy population? what exactly does the self-mod
short-circuit skip today?) the ruling and the follow-on plan depend on, per the dispatch's own
"verify that mitigation actually landed before tightening" instruction.

## Findings

### Codebase Patterns

**Current absent-scope handling (`orchestrate-batch-admit.sh`)**: an entry whose `file_scope` is
null, missing, or `[]` short-circuits to a bare `{"decision":"admit","self_modifying":false}`
(`scripts/orchestrate-batch-admit.sh` lines ~569-571) *before* the collision scan runs for it as
a candidate. Separately, and more importantly for the observed harm, when such an entry is the
*other* side of another candidate's comparison (`$other.file_scope // []`), `scopes_overlap_first`
against an empty array always returns `null` — there is structurally nothing to compare, which is
exactly what the dispatch's two motivating incidents demonstrate. No advisory field is emitted by
this script for this case today — the only place absence is surfaced is the separate,
independently-computed Class F (`orchestrate-predispatch-review.sh`) and Check 10
(`validate-state.sh`), neither of which affects admission.

**Precedence and short-circuit (D4)**: self-modification is checked FIRST and, when it fires,
completely bypasses the `file_scope_collision` and `session_active` passes — confirmed directly
in the jq (`scripts/orchestrate-batch-admit.sh` lines ~572-611): every one of the three
self-mod outcomes (phase-exempt admit, tie-break-winner admit, solo/`inv_count<=1` admit) returns
its verdict object immediately, never falling into the `else` branch that runs the collision scan
and `session_contention()`. This confirms ex-task 190's core claim precisely. The self-exclusion
inside `session_contention()` is keyed on `session_id`, not `pid` (`lib/file-scope-overlap.sh`
line ~127: `select($sess.session_id != $own_sid)`) — so ex-task 190's alternate "pid-keying" hazard
hypothesis does **not** apply; the defect is the precedence short-circuit alone, not a
self-exclusion bug.

**Schema versioning precedent (`docs/architecture/batch-admit-schema.md`, "Version History")**:
every prior addition of a *new* `defer_reason` value (v1→v2 introducing the discriminator itself;
v3→v4 adding `session_active`) was a version bump, each with an explicit table of which
in-repo consumers were updated and why — the stated reason is always the same: a consumer with a
closed `if/else` over `defer_reason` mis-buckets an unrecognized new value into an existing
branch and reads absent fields from it. By contrast, purely *additive*, non-decision-changing
fields (v5's `idle_overlap_advisory`, and the tie-breaker/`--phase-map` change) did **not** bump
the schema, because `orchestrate-predispatch-review.sh`'s Class selects are `select()`-based and
simply ignore an unrecognized field rather than mis-bucketing it. This is the load-bearing
precedent for scoping the fix to the self-mod cross-session gap as additive-only, and for
treating a genuine new in-batch-absence `defer_reason` as version-bump work.

**`orchestrate-predispatch-review.sh` consumer risk**: Classes C/D/E select on
`decision == "defer" and defer_reason == "..."` — an unrecognized `defer_reason` string produces
*zero* matching rows in every existing class (verified by reading the jq: each class's `select`
is a positive match, not an exhaustive `if/else`, so this script is actually already safe against
an unrecognized value the same way it survived `session_active`'s v4 introduction inertly) but
would still render **nothing** for the new reason until a dedicated class is added. This matches
the v4 history entry's own characterization ("was already safe... inert rather than mis-bucketed")
— so schema safety is not at risk, but visibility is, until a plan phase adds the class.

**`backfill-file-scope.sh` is deliberately partial by design, not a completed rollout**: it
explicitly and correctly skips (a) any task with no resolvable plan artifact ("plan-less, left
absent" — never guesses a scope) and (b) any task whose harvest from an existing plan's
`**Files to modify**:` field yields nothing. It is a one-shot, idempotent, additive-merge tool
(`(.file_scope // []) + $add | unique` via `state-write.sh`) — re-running it is safe but does not
by itself close the plan-less gap; that gap closes only as those tasks are eventually planned
(task 162's ongoing plan-time harvest).

**`validate-state.sh` Check 10 already states this exact promotion criterion** (lines ~104-109,
task 163): "promote `missing_key` and `null_value` from WARN to FAIL once no non-terminal task
under specs/ lacks a usable file_scope... This task does NOT perform the promotion." Task 165's
absent-scope half is the direct, named continuation of that unperformed promotion — but for a
*different* consumer (the admission predicate, not `validate-state.sh`'s own exit code).

### External Resources

Not applicable — this is a closed, in-repo predicate whose only inputs are `specs/state.json` and
the session registry; no external documentation applies.

### Measured Evidence — Backfill Coverage Across Repos

Live measurement (2026-09-29), non-terminal tasks (`completed`/`abandoned`/`expanded` excluded):

| Repo | Non-terminal tasks | Missing `file_scope` | Coverage | Notes |
|---|---|---|---|---|
| this repo (nvim) | 28 | 1 (#268, `not_started`) | 96% | expected gap — plan-less |
| `~/Projects/Logos/Verification` | 33 | 1 (#105, `not_started`) | 97% | expected gap — plan-less |
| `~/Projects/BimodalLogic` | 43 | **25** | **42%** | 24 plan-less (design-correct gap) + 1 genuine harvest miss (#410, has a plan, `**Files to modify**` absent from it) |

`BimodalLogic` is the repo of both the primary motivating harm (`/orchestrate 544,545`) and the
second, larger in-batch incident (8-task batch). Its coverage is the one that matters for "has
the mitigation landed", and it has not — 58% of its non-terminal population is still unprotected
by any declared scope, mechanically identical to the state that produced both incidents. This is
not a stale measurement artifact: `bash .claude/scripts/backfill-file-scope.sh --dry-run` was run
directly against that repo's live `specs/state.json` and reproduces the same 25-task gap,
confirming the tool has already been run to convergence there (0 backfillable) rather than simply
never invoked.

### Recommendations

**Ruling 1 — absent `file_scope`, split by scope kind (not one blanket posture)**:

- **Cross-batch**: stay **advisory-only** for now. The measured coverage above is the direct,
  requested justification: blocking now would defer real work on the ~58%-uncovered BimodalLogic
  backlog, almost all of which is plan-less legacy debt with no near-term remedy other than
  "get planned" (task 162's mechanism, already wired for new work going forward). This is
  option (a) from the dispatch's options list, chosen deliberately, not by default. Record the
  promotion criterion explicitly in the header (mirroring `validate-state.sh` Check 10's own
  wording): *promote cross-batch absence from advisory to blocking once
  `validate-state.sh --strict` shows zero `missing_key`/`null_value` Check 10 findings across the
  repos this system targets.* Until then, add a new **additive, non-blocking** field on the
  admit verdict (parallel to `idle_overlap_advisory`, e.g. `absent_scope_advisory`) so the
  hazard is at least visible on the verdict itself, not only in the separate
  `orchestrate-predispatch-review.sh` Class F report — this part needs no version bump, per the
  additive-field precedent above.
- **In-batch**: make it **blocking**, narrowly (this is the dispatch's option (d), scoped to
  in-batch only, which is the second evidence block's own explicit suggestion). Rationale, stated
  as the dispatch requires: an absent-scope candidate co-dispatched with siblings this cycle has
  *no evidence it is disjoint from them* — the cost of wrongly serializing is only extra cycles
  (identical in kind to an ordinary `file_scope_collision` in-batch defer), while the cost of
  wrongly parallelizing, per the second evidence block, was concurrent edits to a shared gate
  script and concurrent certificate-regenerating verification runs. This does **not** depend on
  legacy-backlog coverage at all — it only ever concerns tasks actively being dispatched this
  cycle, so the coverage gap above is irrelevant to it. Implementation shape: reuse the
  `self_modifying` tie-breaker convergence pattern exactly — among this cycle's absent-scope
  candidates, the lowest task number is the designated candidate and admits; every other
  absent-scope in-batch candidate defers under a **new** `defer_reason` value (this task's own
  name, distinct from `file_scope_collision`, per the dispatch's own field-shape argument: no
  `colliding_task_number`/`overlapping_path` exist for "missing information", so forcing it into
  `file_scope_collision`'s payload would leave those fields present-but-empty, violating the
  schema's existing "present only when..." field discipline). No override (`--allow-X`) is
  needed or warranted: unlike `self_modifying`'s override (which exists because a permanent
  whole-invocation exclusion was once possible), this defer self-clears next cycle once the
  designated candidate's absence is resolved by declaring a scope, or once it dispatches and its
  status leaves the in-batch set — the same non-deadlocking property `self_modifying`'s
  tie-breaker already guarantees. Sits in the override hierarchy alongside
  `file_scope_collision`/`session_active` (no override), not alongside `self_modifying` (has
  one).
- This is a genuine version-bump change (v5→v6) for the in-batch half: it is a **new**
  `defer_reason` value, and per the Version History precedent every prior such addition bumped
  the schema and updated `orchestrate-predispatch-review.sh` (a new Class), `orchestrate-dry-run-
  report.sh`, and `skill-orchestrate/SKILL.md` Stage MT-3 step 4.5's `if/else`. The advisory-only
  cross-batch half does not need a bump (additive field only).

**Ruling 2 — self-modifying cross-session blindness (ex-task 190), confirmed live**: fix by
running `session_contention()` (and, for full parity, the state.json collision scan) against the
self-modifying candidate's own `file_scope` **after** the admit decision is already made, in every
one of the three self-mod admit sub-branches (phase-exempt, tie-break-winner, solo) — never
changing the decision itself (ex-task 190's explicit MUST NOT), only attaching a new additive
field (e.g. `cross_session_hazard`, mirroring `idle_overlap_advisory`'s existing shape:
session_id / colliding task number / overlapping path / liveness reason) when a hit is found.
This is additive-only and needs no version bump, matching the tie-breaker/`--phase-map`
non-bump precedent. `orchestrate-predispatch-review.sh` needs a new render class (its existing
Class C/C-admitted select only on `self_modifying`/`defer_reason`, so a new field is currently
inert there, same "safe but incomplete" residual v5's own history entry already accepts for
`idle_overlap_advisory`). A fixture test should extend
`scripts/tests/test-orchestrate-batch-admit.sh`'s existing isolated-temp-root harness (copies the
real script + `deploy-root-guard.sh` + `lib/file-scope-overlap.sh` + `lib/common.sh` +
`lib/task-lookup-lib.sh` + `task-lock.sh` into a throwaway root) with a two-session registration
whose covered scopes overlap, reproducing the exact `<A>`/`<B>` probe sequence from the dispatch's
own "MEASURED EVIDENCE" block.

## Decisions

- Split posture by scope kind (in-batch blocking via a new self-clearing `defer_reason`;
  cross-batch advisory-only via a new additive field) rather than one blanket answer — directly
  justified by measured, unequal backfill coverage across repos (BimodalLogic 42% vs. this
  repo's/Logos-Verification's ~96-97%).
- The cross-batch promotion criterion is `validate-state.sh --strict`'s existing Check 10
  zero-finding state, reused rather than reinvented, echoing plan-format.md's Verification Tier
  precedent the dispatch names.
- The self-mod cross-session fix is additive-only (no decision change, no version bump); the
  in-batch absence fix is a genuine v6 bump requiring the same three consumers every prior
  `defer_reason` addition required.
- Task 410's harvest miss in BimodalLogic (Territory Contract table vs. `**Files to modify**:`
  field) is recorded as a residual for a *different* task (`plan-file-scope-harvest.sh`'s parsing
  coverage), not addressed here — it is evidence for the coverage measurement, not part of this
  task's file scope.

## Risks & Mitigations

- **Risk**: blocking in-batch absence could stall a batch containing several legacy plan-less
  tasks with no declared scope at all. **Mitigation**: the tie-breaker convergence means only one
  extra cycle per absent-scope candidate beyond the first, identical in cost to today's
  self-modifying tie-breaker convergence — never a permanent block.
- **Risk**: a new `defer_reason` silently mis-renders in a consumer that assumes a closed
  two/three-value set. **Mitigation**: confirmed (see Codebase Patterns above) that
  `orchestrate-predispatch-review.sh`'s Classes are `select()`-based, not exhaustive `if/else` —
  an unrecognized value is inert, not mis-bucketed, matching the v4 precedent's own finding. Still
  needs an explicit new class for visibility, per the "safe but incomplete" residual pattern.
- **Risk**: `--phase-map`'s research/plan exemption (which exempts self-modifying research/plan
  dispatches from the self-mod defer) has no analogue check against the new in-batch
  absent-scope defer — a research/plan dispatch of an absent-scope candidate would still defer
  under the new rule even though it touches only its own `reports/`/`plans/` subdirectory. Flag
  for the plan phase: consider the same phase-group exemption there.

## Context Extension Recommendations

- None beyond what the plan/implement phases will produce (the header contract itself, and a
  `docs/architecture/batch-admit-schema.md` v6 Version History entry) — this is exactly the kind
  of decision the schema doc's own Version History mechanism exists to record, not a gap in a
  separate context file.

## Appendix

- Search/read commands used: direct `Read`/`grep -n` over `orchestrate-batch-admit.sh` (744
  lines, header + jq body), `lib/file-scope-overlap.sh`, `orchestrate-predispatch-review.sh`,
  `validate-state.sh`, `backfill-file-scope.sh`, `plan-file-scope-harvest.sh`,
  `docs/architecture/batch-admit-schema.md`, `context/patterns/batch-orchestration-guardrails.md`,
  `scripts/tests/test-orchestrate-batch-admit.sh`.
- Live measurements: `python3` scan of `specs/state.json` (this repo,
  `~/Projects/BimodalLogic`, `~/Projects/Logos/Verification`) for non-terminal tasks lacking
  `file_scope`; `bash .claude/scripts/backfill-file-scope.sh --dry-run` against
  `~/Projects/BimodalLogic` to confirm the gap is not merely an unrun tool.
- Prerequisite task summaries read: `specs/archive/163_surface_missing_and_empty_file_scope/
  summaries/01_surface-missing-empty-file-scope-summary.md`.
