# Implementation Plan: Task #449

- **Task**: 449 - Site the Batch Gate Deferral directive where it is read before the phase's verification is launched
- **Status**: [IMPLEMENTING]
- **Effort**: 3.25 hours
- **Dependencies**: 328, 407, 445, 446, 447 (territory/serialization edges declared in the task description)
- **Research Inputs**: specs/449_hoist_batch_gate_deferral_directive/reports/01_batch-gate-deferral-siting.md
- **Artifacts**: plans/01_hoist-batch-gate-deferral-siting.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The `## Batch Gate Deferral` directive is emitted as the tenth of seventeen dispatch-file
sections, immediately after `## Plan` — the file's single largest section. A reader working the
file top-down reaches the plan body and the phase mission before reaching the constraint on how
that phase's verification must be run, which is how the cited miss happened. This plan implements
candidate mechanism (1): hoist the whole emission block so it is written immediately after
`## Description`, ahead of `## Artifact Round` and the entire `## Plan` / `## Continuation` /
`## Phase Mission` group, replacing the implicit `implement`-phase guard it loses with an explicit
one. It then pins the emitted POSITION (not merely the presence) in the composer's own fixture
suite, adds the one directive-text clause the folded-in evidence shows is missing (what to do when
the phase's own declared criterion names a check with no narrowing mapping), records the decision
and the two rejected options in the durable contracts, and redeploys.

The heading string stays byte-exact (`## Batch Gate Deferral`), the final-phase-only consumption
scoping stays exactly as written, and no phase weakens the deferral into a license to skip
verification.

### Premise Re-Validation

Each `## Premise Re-Validation` line from the dispatch, checked against the prior artifact and
live state. Results are stated even where they only confirm the description unchanged.

- **Source store is the edit target** — CONFIRMED live. `.claude-extensions.json` exists at the
  project root; `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` exists;
  `.claude/scripts/deploy-headless.sh` exists for the redeploy. Every edit below targets
  `agent-system/extensions/core/**`.
- **Section emission order / the description's line numbers** — DRIFTED, as the description's own
  "re-derive before editing" caveat anticipated; the premise itself is still live. Re-derived
  fresh: `## Identity` 569, `## Description` 586, `## Artifact Round` 594, `## Research Artifact`
  601, `## Prior Plan` 606, `## Plan` 614, `## Continuation` 635, `## Phase Mission` 647,
  `## Batch Gate Deferral` 682, `## Handoff` 725, `## Issue Log` 737, `## Territory` 770,
  `## Prior Decisions` 817, `## Premise Re-Validation` 836, `## Outstanding Gate Finding` 858,
  `## Wait Discipline` 872, `## User-Decision Contract` 882. The directive is still emitted after
  `## Plan` and after `## Phase Mission`, which is the defect being fixed.
- **"9 of 38 checks failed as contention timeouts, load avg 52.70, 24 cores, 21 concurrent gate
  processes"** — CONFIRMED as archived evidence by the research report against the archived
  issue entry; not re-measurable now and not re-measured. Treated as the historical motivation,
  not as a figure this plan re-asserts.
- **`agents/general-implementation-agent.md` "line 1023" anti-pattern and the Stage 4 obligation
  at "469-470"** — line numbers DRIFTED, text CONFIRMED unchanged in substance: the Stage 4C
  obligation now sits at ~510-521 and the paired anti-pattern is item 15 at ~1078. Neither file
  is edited by this plan (see Non-Goals).
- **"At least four consumers match on that heading string"** — CONFIRMED and exceeded. Live
  matches on the exact string: `agents/general-implementation-agent.md` (two sites),
  `context/contracts/phase-closure.md`, `context/formats/plan-format.md`,
  `context/contracts/batch-gate-stage.md` (two sites),
  `docs/architecture/orchestrate-state-machine.md`, `scripts/orchestrate-batch-gate.sh` (header
  comment), plus `scripts/tests/test-orchestrate-build-dispatch.sh` and
  `scripts/tests/test-orchestrate-cycle-plan.sh`. The rename prohibition is load-bearing.
- **Option (1) landing point "near `## Identity` or immediately after `## Description`"** —
  CONFIRMED feasible. The block's only inputs are `$batch_gate_deferral_flag` (set during
  argument parsing, ~line 197/217) and `$SKILL_REPO_ROOT` (established well before the emission
  block, used from ~line 250), so hoisting introduces no variable-ordering hazard.
- **Option (3) (batch-aware aggregator)** — NOT chosen; its fail-open obstacle (stale
  `.orchestrator-multi-state-*.json` files with no cleanup path) stands as the research recorded
  it. The dispatch's VERIFY item "if option (3) is chosen, pin both directions" therefore does
  not fire, and `scripts/verify-deploy.sh` is untouched by this plan.
- **Territory edge with 445** — reconciliation discharged with no action needed. 445's completed
  change is internal to `gate8_run()`'s exit-code branching; this plan does not touch
  `verify-deploy.sh` at all, so the anticipated file collision does not materialize.
- **VERIFY's position-fixture requirement** — CONFIRMED feasible with an existing in-suite idiom
  (`grep -n` each heading, compare line numbers numerically), and a single
  `--hard --phase-number N --batch-gate-deferral` build emits all three headings at once so the
  relative-position assertion has all its operands.

### Research Integration

The research report's recommendation is adopted without modification: mechanism (1), landing
immediately after `## Description`. Its three supporting findings drive the phase structure —
(a) the cited miss's phase genuinely carried the obligation, so the scoping is not the defect and
is not widened; (b) option (2) cannot reach the ordinary non-hard-mode dispatch shape that failed,
because `## Phase Mission` is emitted only under hard mode's per-phase dispatch; (c) option (3)
cannot be built fail-open today without session-identity plumbing that does not exist. The report
also located the exact reusable position-assertion idiom the new fixture copies.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, so no roadmap consultation
was performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Emit `## Batch Gate Deferral` ahead of `## Artifact Round` and the whole
  `## Plan`/`## Continuation`/`## Phase Mission` group, immediately after `## Description`.
- Keep the heading string byte-exact and every existing consumer's match intact.
- Keep the directive's `implement`-phase-only emission exactly as observable today, now via an
  explicit guard rather than block nesting.
- Add the one directive clause the folded-in evidence shows missing: what the implementer does
  when the phase's own declared criterion names a check with no `--only`/`--only-gate` mapping.
- Pin the emitted position (relative to `## Plan` and `## Phase Mission`), not merely its
  presence, so a later reordering fails the suite.
- Record the chosen mechanism and both rejected options in the durable contracts.

**Non-Goals**:
- Making `verify-deploy.sh` or `run-all.sh` batch-aware (option 3) — deferred; recorded as
  considered-and-not-chosen with its fail-open obstacle.
- Restating the directive inside `## Phase Mission` (option 2) — structurally unable to reach the
  dispatch shape that failed.
- Widening the final-phase-only consumption scoping. Research confirmed the directive applied to
  the cited phase; the scoping is not the defect.
- Editing `agents/general-implementation-agent.md` or `context/contracts/phase-closure.md`. The
  directive's name and semantics do not change, so neither file needs an edit — which also keeps
  this plan clear of the declared serialization edge that rewrites that same prose.
- Cleaning up stale `.orchestrator-multi-state-*.json` files, or acting on the folded-in
  per-phase generated-surface sequencing obligation for `.lean`-editing plans. The fold itself
  assigns the latter to the harvester record that owns `plan-file-scope-harvest.sh`; only its
  distinct sub-case (a declared criterion with no narrowing mapping) is in scope here.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Hoisting out of the `implement` block silently widens emission to research/plan dispatches | H | M | Phase 1 adds an explicit `[ "$phase" = "implement" ]` conjunct; Group 19 already asserts absence on both research and plan with the flag passed explicitly, and those assertions are run as Phase 1's own gate |
| A directive-text addition trips Group 19's `assert_not_contains "agent-system/extensions/core/scripts/"` | M | M | Phase 2 writes the new clause with no literal source-store path, and runs the suite before closing |
| Reordering perturbs `cycle_plan_dispatch_hash()`'s identical-dispatch halt | H | L | Reordering adds no new per-cycle-varying line, so the three-line strip pattern is unaffected; Phase 1 runs `test-orchestrate-cycle-plan.sh` (which owns Group 27's hash cases) as part of its own narrowing |
| Group 19's own comments keep asserting the retired "nested inside the implement block" rationale | M | H | Phase 3 updates those comments alongside the new fixture, so the stated mechanism matches the code |
| A future section inserted between `## Description` and the directive erodes the hoist | M | M | Phase 3's position fixture measures against `## Plan` and `## Phase Mission`, which catches any drift back toward them |
| Redeploy regenerates the whole `.claude/` tree and collides with a concurrent writer | H | M | Phase 5 declares `__WHOLE_TREE__` in its file scope so the batch admission layer serializes it |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Hoist the emission block [COMPLETED]

**Goal**: `## Batch Gate Deferral` is emitted immediately after `## Description`, ahead of
`## Artifact Round` and the whole `## Plan`/`## Continuation`/`## Phase Mission` group, with
emission still confined to the `implement` phase and the directive's body text byte-unchanged.

**Tasks**:
- [x] Re-derive the current line numbers of `echo "## Description"`, `echo "## Artifact Round"`,
      and the `if [ "$batch_gate_deferral_flag" = "true" ]` block in
      `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` before editing.
      *(completed: Description 586, Artifact Round 594, flag block 657-723 pre-edit)*
- [x] Move the entire block — the `run_all_candidates`/`verify_deploy_candidates` resolution
      preamble, its CANDIDATE-RESOLUTION comment, every `echo` through the closing blank line —
      as one unit to sit after the `## Description` emission (including its optional
      `User focus:` line) and before `echo "## Artifact Round"`. *(completed)*
- [x] Change the block's own guard to the explicit conjunction
      `if [ "$phase" = "implement" ] && [ "$batch_gate_deferral_flag" = "true" ]; then`, since it
      no longer inherits the enclosing `if [ "$phase" = "implement" ]` block's guard.
      *(completed)*
- [x] Update the block's leading comment to state the new siting and why it is sited there (read
      before the plan body it constrains), and that the explicit phase conjunct is what now
      carries the implement-only emission the nesting used to provide. *(completed)*
- [x] Confirm the directive's emitted body text is otherwise unchanged in this phase (a
      character-level diff of the moved lines against their prior content) — body-text changes
      belong to Phase 2. *(completed: git diff shows only relocation, guard conjunct, and new
      leading comment -- no body-text change)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: the covering check is the full selector-resolved suite set for this
composer, named exactly as `suite_selection_select` returns it — `test-force-phases.sh`,
`test-orchestrate-build-aux-dispatch.sh`, `test-orchestrate-build-dispatch.sh`,
`test-orchestrate-context-growth.sh`, `test-orchestrate-cycle-plan.sh`,
`test-orchestrate-record-decision.sh`, `test-orchestrate-recover-message-findings.sh`,
`test-orchestrate-unwind-dispatch.sh`, `test-routing-resolution.sh` — of which
`test-orchestrate-build-dispatch.sh` owns every emitted-section presence/absence and
byte-identity assertion for this flag and `test-orchestrate-cycle-plan.sh` owns the dispatch-hash
normalizer whose identical-dispatch halt a reordering could perturb.

**Scope Hypothesis**: the hoist is a pure relocation of one contiguous block with no other
call-site change anywhere in the composer. Confirm at implementation time by checking that the
only non-whitespace differences in the file's diff are the block's removal from its old position,
its reinsertion at the new one, the guard conjunct, and the comment rewrite; any additional
difference means the block was not self-contained and the finding is recorded before proceeding.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - relocate the batch-gate
  deferral emission block; add the explicit `implement`-phase guard conjunct; rewrite the block's
  leading comment.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-force-phases.sh,test-orchestrate-build-aux-dispatch.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-record-decision.sh,test-orchestrate-recover-message-findings.sh,test-orchestrate-unwind-dispatch.sh,test-routing-resolution.sh`
  exits 0 (Group 19's four existing arms — implement-with-flag presence, degradation wording,
  resolved deployed paths, research/plan absence — plus Group 27's hash cases).
- `bash -n agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` is clean.
- A manual composed-dispatch read confirms the heading's line number is below `## Description`'s
  and above `## Artifact Round`'s.

---

### Phase 2: Close the unmappable-criterion gap in the directive text [COMPLETED]

**Goal**: the emitted directive tells the implementer what to do in the two cases the folded-in
evidence shows it does not cover: the plan it constrains is named further down the file, and the
phase's own declared verification criterion may name a check with no `--only`/`--only-gate`
mapping in this repository.

**Tasks**:
- [x] Add one forward-pointer clause to the directive: it constrains the final phase of the plan
      named under `## Plan` below, so the reader who meets the directive before the plan body
      knows what it attaches to. *(completed)*
- [x] Add one clause covering the unmappable-criterion case: when the phase's own declared
      verification criterion names a repository-specific check that neither narrowing invocation
      can express (no matching suite basename for `--only`, no matching gate number for
      `--only-gate`), run that named check directly — scoped to this phase's own files where the
      check supports scoping — and record it as the scoped discharge. State explicitly that an
      unmappable criterion is never waived, dropped, or treated as satisfied by a narrowing that
      does not reach it. *(completed: added only inside the resolved branch, since the degraded
      branch already runs the complete gate set and has no scoped tier to miss a check)*
- [x] Keep both clauses free of any literal `agent-system/extensions/core/scripts/` path, so
      Group 19's `assert_not_contains` on that string still holds in both the degraded and the
      resolved-path arms. *(completed: verified by manual composed-dispatch smoke test, both arms)*
- [x] Re-read the emitted section end to end and confirm it still reads as a narrowing of the
      verification, never a permission to skip it. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: the covering check is the same selector-resolved suite set this composer
maps to — `test-force-phases.sh`, `test-orchestrate-build-aux-dispatch.sh`,
`test-orchestrate-build-dispatch.sh`, `test-orchestrate-context-growth.sh`,
`test-orchestrate-cycle-plan.sh`, `test-orchestrate-record-decision.sh`,
`test-orchestrate-recover-message-findings.sh`, `test-orchestrate-unwind-dispatch.sh`,
`test-routing-resolution.sh` — of which `test-orchestrate-build-dispatch.sh`'s Group 19 degraded
and resolved-path arms assert on this exact emitted text, including the `assert_not_contains`
guard the new clauses must not trip.

**Scope Hypothesis**: both clauses fit inside the existing emission block with no new conditional
branch and no new resolved path. Confirm by checking that the diff adds only `echo` lines inside
the already-hoisted block; if either clause turns out to need its own resolution logic, record
that and treat it as a scope finding rather than absorbing it silently.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - add the forward-pointer
  clause and the unmappable-criterion clause to the emitted directive.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-force-phases.sh,test-orchestrate-build-aux-dispatch.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-record-decision.sh,test-orchestrate-recover-message-findings.sh,test-orchestrate-unwind-dispatch.sh,test-routing-resolution.sh`
  exits 0.
- A composed dispatch (both the resolved-candidate and the no-candidate arms) contains both new
  clauses and no literal source-store path.

---

### Phase 3: Pin the emitted position and the heading string [COMPLETED]

**Goal**: a later reordering, or a rename of the heading, fails `test-orchestrate-build-dispatch.sh`
instead of silently reintroducing the defect.

**Tasks**:
- [x] Extend Group 19 with a position case: build one dispatch carrying all three headings at
      once (`implement` with `--hard`, `--phase-number N`, and `--batch-gate-deferral`), then
      `grep -n` each of `^## Batch Gate Deferral`, `^## Plan`, `^## Phase Mission`, and assert
      numerically that the deferral heading's line number is less than both others — using the
      same `grep -n ... | head -1 | cut -d: -f1` plus named pass/fail idiom the hard-mode
      Wait-Discipline-vs-User-Decision-Contract ordering guard already uses (the research's
      "Group 15" reference drifted; the idiom lives in what is now the hard-mode-implement case
      above Group 15). *(completed)*
- [x] Add an adjacent assertion that the deferral heading's line number is greater than
      `^## Description`'s, so the section cannot drift up above the description it follows.
      *(completed)*
- [x] Add a heading-string case: assert the exact literal `## Batch Gate Deferral` is present in
      each prose consumer — `agents/general-implementation-agent.md`,
      `context/contracts/phase-closure.md`, `context/formats/plan-format.md`,
      `context/contracts/batch-gate-stage.md`,
      `docs/architecture/orchestrate-state-machine.md` — resolving each by the suite's existing
      deploy-first / source-store-fallback convention and skipping with an explicit note rather
      than failing if a consumer is genuinely absent from this repository shape. *(completed:
      all five resolved from the deployed tree in this repository shape)*
- [x] Update Group 19's own header comment and its research/plan absence labels, which currently
      explain the absence by the retired "nested inside this SUT's own `if [ "$phase" =
      "implement" ]` block" mechanism; state the explicit-guard mechanism instead. *(completed)*

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: the covering check is this touched path's selector-resolved suite set —
`test-orchestrate-build-aux-dispatch.sh`, `test-orchestrate-build-dispatch.sh`,
`test-orchestrate-context-growth.sh`, `test-orchestrate-cycle-plan.sh` — of which
`test-orchestrate-build-dispatch.sh` is both the covering check and the artifact under change,
and a deliberately perturbed scratch copy of the composer confirms the position assertion
actually fails when the order is wrong.

**Scope Hypothesis**: Group 19 is the only group whose comments assert the retired nesting
rationale, and no other group's assertions depend on the directive's position. Confirm by
grepping the suite for `Batch Gate Deferral` and for the nesting phrase before editing; any
further site found is fixed in this same phase and the count recorded.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - add the
  position case, the description-floor assertion, and the consumer heading-string case to
  Group 19; update Group 19's comments to the explicit-guard mechanism.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-build-aux-dispatch.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh`
  exits 0 with the new cases counted.
- Negative control: with the emission block temporarily moved back below `## Plan` in a scratch
  copy of the composer, the new position case FAILS; the composer is restored immediately after.

---

### Phase 4: Record the decision in the durable contracts [COMPLETED]

**Goal**: the chosen mechanism, the two rejected options, the directive's siting, and the
unmappable-criterion rule are readable from the contracts rather than only from this plan.

**Tasks**:
- [x] In `context/contracts/batch-gate-stage.md`, record Mechanism A's siting (emitted
      immediately after `## Description`, ahead of the plan body it constrains) and why: a reader
      working top-down must meet the constraint before the work it constrains. Record the two
      rejected alternatives on their own merits — a restatement inside `## Phase Mission` cannot
      reach the ordinary dispatch shape, since that section is emitted only for a per-phase
      hard-mode dispatch; a batch-aware aggregator cannot be made fail-open today because the
      invocation-scoped batch-state file has no cleanup path and its mere presence is therefore
      not evidence of a live batch. *(completed: new "## Mechanism A's Dispatch-Time Siting"
      section appended)*
- [x] In `context/formats/plan-format.md`'s "Batch-aware deferral" subsection, add the
      unmappable-criterion rule: a declared criterion naming a check that neither narrowing
      invocation can express is discharged by running that named check directly, scoped where the
      check supports scoping, and is never waived by the override. *(completed)*
- [x] In `docs/architecture/orchestrate-state-machine.md`'s batch-gate-stage description, correct
      the claim that Mechanism A is composed onto "a final implement-phase dispatch": the
      composer sets the flag for every `implement`-phase dispatch of a genuine multi-task batch,
      and the final-phase-only restriction is the consuming agent's own obligation. State both
      halves so the division of responsibility is unambiguous. *(completed: confirmed against
      orchestrate-cycle-plan.sh's actual build_args gate, `[ "$g" = "implement" ] &&
      [ "$_bgd_task_count" -gt 1 ]`, with no per-phase-number condition)*
- [x] Confirm no edit renames or re-cases the heading string, and that no added prose implies the
      deferral may skip verification. *(completed: grep -c confirms all 5 consumers still match
      the exact literal; both new prose sections state the full gate set is deferred, never
      forgiven)*
- [x] Confirm no task-number reference and no record-versioning language lands in any edited
      file (these are `agent-system/**` deliverables). *(completed: check-task-references.sh and
      check-record-versioning.sh both exit 0 clean on all three edited files; one advisory
      "previously relied on" phrase this phase itself introduced was rephrased to avoid it)*

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for all three touched
paths — no suite covers a pure-guidance markdown edit with no executable surface, so none is
claimed. This is source-store, non-`specs/**` markdown, so the honest covering check is the
sub-case (b) gate subset `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
(doc-lint plus task-reference lint, with `TARGET` the repository root that holds both the
deployed tree and the source store), run alongside the `prose` row's own diff read-through.

**Scope Hypothesis**: exactly three prose files need editing, and `general-implementation-agent.md`
and `phase-closure.md` need none, because the directive's name and consumption semantics are
unchanged. Confirm by re-reading both of those files' `Batch Gate Deferral` passages against the
post-Phase-2 emitted text; if either has become inaccurate, record the finding and raise it rather
than editing into the serialization edge's declared prose.

**Files to modify**:
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md` - record Mechanism A's
  siting and the two rejected alternatives.
- `agent-system/extensions/core/context/formats/plan-format.md` - add the unmappable-criterion
  rule to the "Batch-aware deferral" subsection.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - correct the
  which-dispatches-carry-Mechanism-A claim and state the agent-side final-phase restriction.

**Verification**:
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0, with both selected gates reporting a real (non-SKIP) result.
- `bash .claude/scripts/check-task-references.sh` and
  `bash .claude/scripts/check-record-versioning.sh` each exit 0 with no new findings on the
  edited files.
- Diff read-through of all three edited files confirms the recorded decision matches what landed
  in Phases 1-2.
- `grep -rn '## Batch Gate Deferral' agent-system/extensions/core/` still matches every consumer
  enumerated in Phase 3.

---

### Phase 5: Redeploy and discharge the full gate set [NOT STARTED]

**Goal**: the source-store changes are live in the deployed tree and the complete gate set is
green.

**Tasks**:
- [ ] Run `bash .claude/scripts/deploy-headless.sh` to regenerate the deployed `.claude/` tree
      from the source store.
- [ ] Confirm the deployed `.claude/scripts/orchestrate-build-dispatch.sh`,
      `.claude/scripts/tests/test-orchestrate-build-dispatch.sh`, and the three deployed markdown
      consumers carry this plan's changes (the deploy is what makes them live; a source-store-only
      edit is inert).
- [ ] Discharge the full verification tier: run the complete gate set per the dispatch's own
      instruction for this phase. If this dispatch's file carries a `## Batch Gate Deferral`
      section, honor it — discharge against the scoped tier it names, record in this phase's
      verification notes that the full set was deferred to the batch-level stage, and do NOT run
      the full aggregator concurrently with other sessions (the exact contention this plan
      exists to prevent). Check for that section BEFORE launching anything.
- [ ] Record in the issue log whether the deferral directive was present on this dispatch and
      which invocation was actually run — this plan's own subject, exercised on itself.

**Timing**: 0.5 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Scope Hypothesis**: the deploy regenerates the entire `.claude/` tree, so this phase's real
blast radius is every deployed file, not only the five this plan edited. Confirm by checking the
deploy's own reported file count and verifying the five edited files' deployed copies match their
source-store originals.

**Files to modify**:
- `__WHOLE_TREE__` - the deploy regenerates the whole deployed tree; no individual deployed-tree
  path is declared, since a `.claude/**` path is never a legitimate file-scope member.

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` (the complete gate set it aggregates) is green — or,
  when this dispatch carries the deferral directive, the directive's named narrowing invocation
  is green and the deferral is recorded as such in this phase's verification notes.
- `diff` confirms the deployed copies of the five edited files match their source-store
  originals.
- A composed dispatch from the DEPLOYED composer shows `## Batch Gate Deferral` above `## Plan`.

---

## Testing & Validation

- [ ] `run-all.sh --only test-orchestrate-build-dispatch.sh,test-orchestrate-cycle-plan.sh` passes
      after the hoist.
- [ ] The new position case fails against a deliberately reverted composer and passes against the
      hoisted one.
- [ ] `## Batch Gate Deferral` is emitted above `## Plan` and above `## Phase Mission`, and below
      `## Description`.
- [ ] The heading string is byte-identical and every enumerated consumer still matches it.
- [ ] The directive is absent from research- and plan-phase dispatches even when
      `--batch-gate-deferral` is passed explicitly.
- [ ] The emitted directive narrows verification and nowhere permits skipping it.
- [ ] `check-task-references.sh` and `check-record-versioning.sh` are clean on every edited
      `agent-system/**` file.
- [ ] The full gate set (or the dispatch-directed scoped narrowing, recorded as such) is green
      after redeploy.

## Artifacts & Outputs

- Hoisted and extended `## Batch Gate Deferral` emission in
  `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`.
- Position, description-floor, and consumer heading-string cases in
  `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` Group 19.
- Decision and rejected-alternatives record in `context/contracts/batch-gate-stage.md`;
  unmappable-criterion rule in `context/formats/plan-format.md`; corrected Mechanism A scope in
  `docs/architecture/orchestrate-state-machine.md`.
- Regenerated deployed `.claude/` tree.
- Issue-log entries recorded as they arise, including whether this task's own final dispatch
  carried the deferral directive.

## Rollback/Contingency

Every change is a source-store edit under `agent-system/extensions/core/**` plus a regeneration.
To revert, restore the edited files from `HEAD` with `git show HEAD:<path>` written back to the
source store (never a tree-wide or path-reverting git operation on this shared working tree — see
`git-workflow.md`'s destructive-git rule), then re-run `deploy-headless.sh`. Each phase commits
on its own green, so a mid-plan abort leaves a consistent tree: Phases 1-2 alone leave the
directive hoisted and functional with its old test comments, Phase 3 alone leaves the pins in
place, and Phase 4 alone leaves prose ahead of nothing it contradicts. Only Phase 5's redeploy
makes any of it live, so an abort before Phase 5 leaves the running system byte-unchanged.
