# Implementation Plan: Task #368

- **Task**: 368 - Tier-selection discipline: make a non-final-phase `full` verification tier justify itself
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: Gate 8 suite-selection mechanism (task 366) — SATISFIED, see Overview
- **Research Inputs**: specs/368_tier_selection_discipline_non_final_full/reports/01_tier-selection-discipline.md
- **Artifacts**: plans/01_tier-selection-discipline.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The four-tier ladder (`prose < local < interface < full`) already exists in
`context/formats/plan-format.md`. The defect is purely in *selection*: the tie-break at
`plan-format.md:271` is the only selection guidance a planner receives, it biases unconditionally
toward `full`, and nothing anywhere asks the planner to justify that choice or signals its cost. A
planner following the written guidance correctly lands on `full` by default — and under
`context/contracts/phase-closure.md:167-169` ("run in this dispatch and observed green", "never
trusted on sight") that is a real full gate run per phase per dispatch.

This plan qualifies that one line and propagates the qualification to the three other surfaces a
planner actually reads at tier-assignment time, introducing one required conditional field
(`**Tier Justification**:`) on every non-final phase. The final phase's `full` is untouched: this
plan adds a justification requirement at non-final phases, it does not add a cheaper option at the
final one.

**The plan is its own acceptance demonstration.** Phases 1-5 are non-final phases declaring tiers
below `full`, each carrying a `**Tier Justification**:` line in the exact shape the new guidance
requires; Phase 6 is the final phase, declares `full`, and runs the complete gate set. Acceptance
item 1 ("demonstrated end to end on an actual task, not asserted in prose") is satisfied by this
plan executing successfully, not by a claim inside it.

### Research Integration

Every anchor named in the task description was verified byte-exact by research. Four findings shape
this plan:

1. **The dependency is satisfied and citable by name.** `run-all.sh --only SUITE[,SUITE,...]`
   (`scripts/tests/run-all.sh:34,76-85,274-288`) and the sourced-only mapping library
   `scripts/lib/suite-selection-lib.sh` (`suite_selection_select` at :190) both landed. A cheaper
   tier now has a concrete command behind it.
2. **A second selection mechanism exists that research did not surface as citable**:
   `verify-deploy.sh --only-gate N[,M,...]` (gates 1-21, documented at
   `scripts/verify-deploy.sh:79-87`). This matters because it is the *only* narrowing mechanism
   available for pure-documentation edits (see finding 4).
3. **No fifth copy of the tie-break rule exists.** Eight other files mention tiers; every one
   defers by cross-reference to `plan-format.md`'s `## Verification Tiers` section. Acceptance item
   5 is reachable by editing exactly the four named files. One descriptive label is stale and is
   handled as a scoped incidental fix in Phase 5 (see Goals & Non-Goals).
4. **New finding, established during planning, that changes the guidance text**: running
   `suite_selection_select` against this task's own four targets returns `__FULL_SWEEP__` (the
   zero-hit fail-safe sentinel) for `agents/planner-agent.md`,
   `context/workflows/task-breakdown.md`, and `context/contracts/phase-closure.md`. Only
   `context/formats/plan-format.md` maps to real suites
   (`test-phase-heading-patterns.sh`, `test-plan-file-scope-harvest.sh`,
   `test-resume-scan-nonconformance.sh`). **A planner editing a pure-guidance markdown file
   therefore cannot honestly cite a covering shell suite at all** — the covering check is the
   doc-lint and task-reference-lint gates (`--only-gate 3,4`), not a suite subset. The new guidance
   must say this explicitly, or planners will either invent suite coverage that does not exist or
   fall back to `full` for every documentation phase — reproducing the exact defect this task
   removes, one layer down.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch, so no roadmap phases are added. Two ROADMAP
decisions are nonetheless binding on the content (carried from the task description and verified by
research against `context/standards/shell-script-testing.md:178-183`): Settled decision 15 —
Gate 8's deployed-tree coverage is knowingly reduced under `--skip-slow`, so a `--skip-slow` pass is
not evidence that doc-sync pins hold. The new guidance must not present `--skip-slow` as a tier and
must not let a cheaper non-final tier be read as discharging that evidence.

## Goals & Non-Goals

**Goals**:

- Qualify `plan-format.md:271`'s tie-break so it is cost-aware: strict-when-uncertain is retained
  unconditionally for the final phase and for genuine uncertainty, while a non-final phase states
  why its tier is the cheapest one that covers the edit's blast radius.
- Introduce `**Tier Justification**:` as a required conditional field on every non-final phase,
  modeled structurally on the existing conditional `**Scope Hypothesis**:` field
  (`planner-agent.md:313-315`), so the requirement is *checkable* rather than prose-only.
- Settle, in one sentence, what "the final phase" means — the term is used as if operational at
  `plan-format.md:273-277` and `planner-agent.md:227` but is defined nowhere, and the new
  requirement is phase-position-conditional and therefore uncheckable without it.
- Make the two real narrowing mechanisms (`run-all.sh --only`, `verify-deploy.sh --only-gate`)
  discoverable at the moment of tier assignment, including the honest statement that a
  pure-documentation edit maps to no suite at all.
- Land the same rule on all four surfaces, with no surviving copy of the old unqualified tie-break.

**Non-Goals**:

- **Weakening the final gate in any way.** `plan-format.md:273-277` survives verbatim in force;
  `plan-format.md:279-282`'s "a phase declaring `full` names `bash .claude/scripts/verify-deploy.sh`
  ... in its own verification criteria" is unchanged.
- Adding a cheaper tier option at the final phase, or a fifth tier.
- Presenting `--skip-slow` as a tier, or letting any cheaper tier be read as discharging doc-sync-pin
  evidence.
- Changing `scripts/validate-artifact.sh`. Its tier check (lines 297-324) stays advisory/warn-only
  and gains no finality or justification logic. Enforcement for this task lives in
  `planner-agent.md`'s authoring checklist, which the file itself names as "where authoring-time
  enforcement of the tier vocabulary actually lives". A validator check is a reasonable follow-on,
  deliberately out of scope here.
- `agents/reviser-agent.md` — excluded by the task description after checking, and research
  independently confirmed zero independent tier logic in it (it defers wholly to `plan-format.md` at
  :16, :93, :177). No follow-up gap was found, so none is recorded.

**Scope note (one file beyond the four)**: `rules/plan-format-enforcement.md:43` currently reads
"... and the tie-break-upward rule". That is a descriptive label pointing at the rule, not a second
copy of it — but once the tie-break is no longer unconditionally upward, the label misdescribes it,
and a grep for the old rule surfaces it. Phase 5 makes a one-phrase fix there
("tie-break-upward rule" -> "tie-break rule"). This is a deliberate, bounded incidental fix
recommended by research, not a scope expansion; no other content in that file changes.

## Decisions

These three choices are settled here rather than deferred to implementation, because all four file
edits depend on them being identical.

**Decision 1 — one uniform field, required on every non-final phase (not only on non-final
`full`).** `**Tier Justification**:` is required whenever a phase is not the final phase; it is
omitted on the final phase, whose `full` is mandated by the invariant rather than chosen. Content
bar differs by tier:

- a tier *below* `full` names the specific covering check — the command, as a suite subset
  (`run-all.sh --only ...`), a gate subset (`verify-deploy.sh --only-gate ...`), or the concrete
  in-phase check the tier table already prescribes — and that same command appears in the phase's
  own `**Verification**` criteria;
- `full` at a non-final phase names the specific cross-cutting surface that no cheaper tier covers.

**Why uniform rather than `full`-only**: a rule conditioned on `full` alone leaves the opposite
failure wide open — a phase declaring `interface` with nothing named that actually covers it. One
field forces the blast-radius judgment in both directions, and gives the authoring checklist one
item to check instead of two conditional ones. The friction cost is one line per non-final phase,
and the bar is explicitly one line: *name the covering check* or *name the blast radius*, never an
essay. The worked `full` example already at `task-breakdown.md:171` ("touches shared token
generation, email delivery, and auth state") is exactly the right shape and becomes the documented
model.

**Decision 2 — "the final phase" is defined as the plan's highest-numbered phase, which MUST be a
terminal node of the dependency graph and MUST depend, directly or transitively, on every other
phase.** This is the definition research recommended (terminal node of the wave graph), tightened to
remove its one ambiguity: a last wave containing two mutually independent terminal phases would
otherwise have two candidate "final" phases. Requiring the highest-numbered phase to transitively
depend on all others is already the de facto shape of every plan in this corpus (and is exactly
what `planner-agent.md:150-153`'s roadmap-update phase already does), and it is what makes the final
`full` gate meaningful: the gate must observe all of the task's work. A single-phase plan's only
phase is its final phase — it declares `full` and carries no `**Tier Justification**`.

**Decision 3 — the `--skip-slow` / doc-sync caveat is cross-referenced, not restated.** The
constraint is already written in `context/standards/shell-script-testing.md:178-183` and echoed in
`suite-selection-lib.sh`'s header. The new guidance cites that location rather than producing a
third copy, which would itself be the drift mechanism acceptance item 5 targets.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Planners satisfy `**Tier Justification**` with a throwaway string ("to be safe", "cheaper"), defeating the purpose | M | M | The bar is stated concretely as *name the covering check / name the blast radius*, with the `task-breakdown.md:171` example as the model; the authoring checklist checks presence only, content quality stays review-time judgment — the same advisory-first precedent already documented for `**Verification Tier**` itself |
| A planner cites a suite subset for a documentation edit that maps to no suite (`__FULL_SWEEP__`), manufacturing false coverage | H | M | This is the planning-stage finding in Research Integration item 4; Phase 1 writes the `__FULL_SWEEP__` case into the guidance explicitly, naming `--only-gate 3,4` as the honest covering check for pure-guidance markdown and `suite_selection_select`'s sentinel as the signal that no suite coverage exists |
| Implementers escalate a cheaper non-final tier back to `full` out of caution, since `phase-closure.md:167-169` demands the declared verification be observed green | M | M | Phase 4 states at `phase-closure.md:53` that a cheaper non-final tier with its justification stated closes the phase legitimately — this is precisely why that file is in scope rather than only `plan-format.md` |
| The three non-`plan-format.md` surfaces drift from the contract because each restates it slightly differently | H | M | Phase 1 lands the authoritative text first and Phases 2-4 are explicitly restate-or-defer-only; Phase 5 is a dedicated cross-surface agreement audit with a grep proof, not a self-attestation |
| A cheaper non-final tier is read as discharging the doc-sync-pin evidence (ROADMAP Settled decision 15) | H | L | Decision 3: cross-reference `shell-script-testing.md:178-183` in the new guidance; Phase 5's audit verifies `--skip-slow` is nowhere presented as a tier |
| Source-store edits land but the deploy tree stays behind, so gates 3-4 fail | M | H (expected) | Phase 6 redeploys before the final gate set; drift findings in Phases 1-5 are expected and are explicitly *not* treated as phase failures |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |
| 4 | 6 | 5 |

Phases within the same wave can execute in parallel. Phases 2, 3, and 4 touch three disjoint files
and may be dispatched concurrently once Phase 1 has landed the authoritative text.

**Per Decision 2, Phase 6 is this plan's final phase**: it is the highest-numbered phase, no phase
depends on it, and it depends transitively on all of Phases 1-5.

**Deliverable rule, binding on every phase**: no task-number references in any edited file (all
four targets, plus the Phase 5 incidental, are outside `specs/**`). Cite file-and-line anchors — the
durable anchors used throughout this plan — never a task number. Enforced mechanically by
`hooks/validate-no-task-references.sh` at write time and by gate 4 at the final gate.

**Source-store rule, binding on every phase**: every edit targets
`agent-system/extensions/core/**`. Never hand-author under `.claude/**`, which is a disposable
deploy artifact regenerated in Phase 6 (`rules/source-store-deploy-boundary.md`).

---

### Phase 1: Settle the tier-selection contract in `plan-format.md` [COMPLETED]

**Goal**: Land the authoritative, cost-aware selection rule in the file that owns the tier
vocabulary, so the three restating surfaces have one text to agree with. This is the only
design-bearing phase; Phases 2-4 propagate it.

**Tasks**:

- [x] Re-read `context/formats/plan-format.md:250-285` immediately before editing (concurrent
      siblings are active on this working tree this cycle). *(completed)*
- [x] Qualify the tie-break at `plan-format.md:271`. Keep "when uncertain, apply the strictest
      applicable tier" as the rule for the final phase and for genuine uncertainty at any phase; add
      the non-final carve-out: a non-final phase states, in `**Tier Justification**:`, why its tier
      is the cheapest one covering the edit's blast radius — and a non-final `full` states the
      specific cross-cutting surface no cheaper tier covers. Remove the unqualified form entirely:
      no second copy may survive in this file (acceptance item 5). *(completed)*
- [x] Add a cost signal adjacent to the tie-break: a `full` declaration is a real full gate run per
      phase per dispatch, because `context/contracts/phase-closure.md:167-169` requires the declared
      verification to be run in that dispatch and observed green, never trusted on sight. Cite the
      measured cost from `context/standards/shell-script-testing.md` by reference rather than
      restating figures that go stale. *(completed)*
- [x] Define "the final phase" once, per Decision 2, in the `## Verification Tiers` section: the
      plan's highest-numbered phase, which must be a terminal node of the dependency graph and must
      depend directly or transitively on every other phase; a single-phase plan's only phase is its
      final phase. *(completed)*
- [x] Specify the `**Tier Justification**:` field per Decision 1: required on every non-final phase,
      omitted on the final phase, with the two tier-dependent content bars and the explicit
      one-line-not-an-essay instruction. *(completed)*
- [x] Name the two narrowing mechanisms a cheaper tier can cite:
      `bash agent-system/extensions/core/scripts/tests/run-all.sh --only SUITE[,SUITE,...]` for a
      suite subset within Gate 8, and
      `bash .claude/scripts/verify-deploy.sh --only-gate N[,M,...]` for a gate subset. State that
      `suite_selection_select` (`scripts/lib/suite-selection-lib.sh:190`) resolves a touched path to
      its covering suites. *(completed)*
- [x] Write in the `__FULL_SWEEP__` case explicitly (Research Integration finding 4): when
      `suite_selection_select` returns the full-sweep sentinel for a touched path, **no suite covers
      that file** and the justification must not claim one. For a pure-guidance markdown edit the
      honest covering check is the doc-lint and task-reference-lint gates
      (`--only-gate 3,4`) plus the tier table's own prescribed in-phase check. *(completed)*
- [x] Add the Decision 3 cross-reference: `--skip-slow` is not a tier, and neither a cheaper tier
      nor a `--skip-slow` pass discharges the doc-sync-pin evidence — see
      `context/standards/shell-script-testing.md:178-183`. *(completed)*
- [x] Confirm `plan-format.md:273-277` (the non-negotiable invariant) and `:279-282` (the `full`
      naming requirement) are byte-unchanged. *(completed)*

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: The edit is confined to one markdown contract file with no externally
visible signature; `suite_selection_select` maps it to exactly three covering suites, so the
covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-phase-heading-patterns.sh,test-plan-file-scope-harvest.sh,test-resume-scan-nonconformance.sh`
plus `--only-gate 3,4` for the doc-lint and task-reference-lint surface. No cross-cutting runtime,
elaboration, or config surface is touched, so `full` would add only the known
source-store-ahead-of-deploy drift findings that Phase 6 resolves.

**Scope Hypothesis**: This phase asserts the edit is confined to the `## Verification Tiers` section
of one file and that `plan-format.md:273-277` / `:279-282` need no change. Confirm at
implementation time with `git diff -- agent-system/extensions/core/context/formats/plan-format.md`:
every changed hunk must lie within `## Verification Tiers`, and the invariant and `full`-naming
passages must appear unchanged in the diff context.

**Files to modify**:

- `agent-system/extensions/core/context/formats/plan-format.md` - qualify the tie-break at :271;
  add the cost signal, the "final phase" definition, the `**Tier Justification**` field spec, the
  two narrowing mechanisms, the `__FULL_SWEEP__` honesty clause, and the `--skip-slow`/doc-sync
  cross-reference.

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-phase-heading-patterns.sh,test-plan-file-scope-harvest.sh,test-resume-scan-nonconformance.sh`
  fully green.
- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` — gate 4 (task-reference lint) green;
  gate 3 (doc-lint) drift findings naming only this phase's own edited file are expected until
  Phase 6 redeploys and are not a phase failure. Any gate-3 finding *not* attributable to that
  known drift is a failure.
- `grep -n 'strictest applicable tier' agent-system/extensions/core/context/formats/plan-format.md`
  returns only the qualified form — zero occurrences of the unconditional sentence.
- `grep -c 'skip-slow' ...` confirms the caveat is present as a cross-reference and that
  `--skip-slow` is nowhere listed among the tiers.
- Diff read-through confirms `plan-format.md:273-277` and `:279-282` are unchanged.

---

### Phase 2: Propagate to `planner-agent.md` — the three enforcement points [COMPLETED]

**Goal**: Make the new rule present at the three places in the planning agent where tier assignment
actually happens: the assignment step, the phase template, and the authoring checklist that the file
itself calls the real enforcement point.

**Tasks**:

- [x] Re-read `agents/planner-agent.md:210-230`, `:300-320`, `:378-392` immediately before editing. *(completed)*
- [x] Rewrite step 8's bias line at `planner-agent.md:220` to the Phase 1 text: strict-when-uncertain
      for the final phase and for genuine uncertainty, plus the non-final justification requirement.
      No unqualified copy survives (acceptance item 5). *(completed)*
- [x] Add the `**Tier Justification**:` instruction to step 8 alongside the existing
      `**Scope Hypothesis**:` instruction, with the two content bars and the
      name-the-covering-check / name-the-blast-radius bar; name the two narrowing commands and the
      `__FULL_SWEEP__` honesty clause by cross-reference to `plan-format.md`'s
      `## Verification Tiers` section rather than restating them. *(completed)*
- [x] Confirm step 8's existing do-not-weaken-the-final-gate `**MUST NOT**` at
      `planner-agent.md:227` survives unchanged, and that the new text does not contradict it. *(completed)*
- [x] Add `**Tier Justification**: {conditional ...}` to the phase template at
      `planner-agent.md:310-315`, placed beside `**Commit Mode**` and `**Scope Hypothesis**` and
      following their established omit-by-default/conditional phrasing. *(completed)*
- [x] Extend the authoring checklist at `planner-agent.md:384-389` so it checks the new field:
      every non-final phase has a `**Tier Justification**:` line, and the final phase (per the
      Decision 2 definition) declares `full` and names the complete gate set. A plan missing the
      field is detectable here (acceptance item 6). *(completed)*
- [x] Add a `**MUST NOT**` entry mirroring the existing numbered list: do not satisfy
      `**Tier Justification**` with a generic phrase; name the covering check or the blast radius. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The edit is confined to one agent-definition markdown file with no
externally visible signature. `suite_selection_select` returns `__FULL_SWEEP__` for this path — **no
shell suite covers it**, so per the Phase 1 honesty clause no suite subset is claimed; the covering
check is `verify-deploy.sh --only-gate 3,4` (doc-lint plus task-reference lint) together with a diff
read-through against the Phase 1 text. A `full` sweep would exercise 120+ suites none of which
reference this file.

**Files to modify**:

- `agent-system/extensions/core/agents/planner-agent.md` - step 8 (:216-227), the phase template
  (:310-315), the authoring checklist (:384-389), and one new `**MUST NOT**` entry.

**Verification**:

- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` — gate 4 green; gate 3 drift findings
  limited to this phase's own edited file (expected until Phase 6).
- `grep -n 'strictest applicable tier' agent-system/extensions/core/agents/planner-agent.md`
  returns only the qualified form.
- `grep -n 'Tier Justification' agent-system/extensions/core/agents/planner-agent.md` returns at
  least three hits: step 8, the phase template, the authoring checklist.
- Diff read-through confirms the `**MUST NOT**` at :227 is unchanged and the new text is consistent
  with Phase 1's `plan-format.md` wording — no paraphrase that could drift.

---

### Phase 3: Propagate to `task-breakdown.md` — templates and worked examples [NOT STARTED]

**Goal**: A template showing a bare tier value teaches a bare tier value. Both phase templates and
all three worked examples must show the justification field, including the worked non-final `full`
that demonstrates the requirement is satisfiable (acceptance item 3).

**Tasks**:

- [ ] Re-read `context/workflows/task-breakdown.md:60-180` immediately before editing.
- [ ] Add the conditional `**Tier Justification:**` placeholder to the Phase 1 template at
      `task-breakdown.md:76-78` and the Phase 2 template at `:94`, matching `planner-agent.md`'s
      phase-template phrasing from Phase 2 exactly.
- [ ] Give the worked `interface` example at `task-breakdown.md:131` a `**Tier Justification:**`
      line naming its covering check, in the one-line shape the guidance requires.
- [ ] Give the worked `local` example at `task-breakdown.md:154` the same treatment.
- [ ] Give the worked `full` example at `task-breakdown.md:171` a `**Tier Justification:**` line.
      This is the documented demonstration for acceptance item 3: a non-final phase legitimately
      declaring `full`, with a satisfiable one-line justification. The example's existing
      parenthetical ("touches shared token generation, email delivery, and auth state") is already
      the right shape — promote it into the field rather than inventing new text.
- [ ] Confirm the example plan's own final phase still declares `full` and that the examples do not
      contradict the Decision 2 "final phase" definition.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: The edit is confined to markdown inside a fenced template/example block with
zero compile, elaboration, or script surface — nothing in this file is executed or sourced.
`suite_selection_select` returns `__FULL_SWEEP__`, so no suite coverage is claimed; the tier table's
prescribed `prose` check (diff read-through confirming every changed hunk lies inside prose/template
regions) plus `--only-gate 4` for the task-reference lint is the complete honest covering check.

**Scope Hypothesis**: This phase asserts exactly five insertion sites (`:76-78`, `:94`, `:131`,
`:154`, `:171`) and no other change. Confirm with
`git diff --stat -- agent-system/extensions/core/context/workflows/task-breakdown.md` and a hunk
count: five added-line hunks, zero deletions outside those sites.

**Files to modify**:

- `agent-system/extensions/core/context/workflows/task-breakdown.md` - add the conditional field to
  both phase templates (:76-78, :94) and a one-line justification to all three worked examples
  (:131, :154, :171).

**Verification**:

- Diff read-through: every changed hunk lies inside the breakdown template or the example block;
  no edit crosses out of a prose/template region.
- `bash .claude/scripts/verify-deploy.sh --only-gate 4` green (no task-number references
  introduced).
- `grep -c 'Tier Justification' agent-system/extensions/core/context/workflows/task-breakdown.md`
  returns 5.
- The `full` example at :171 carries a justification naming its specific cross-cutting surface —
  the acceptance-item-3 demonstration, verified by reading it, not by grep alone.

---

### Phase 4: Propagate to `phase-closure.md` — a cheaper tier closes a phase legitimately [NOT STARTED]

**Goal**: Without this, implementers escalate back to `full` out of caution. State that a cheaper
non-final tier with its justification stated is a legitimate phase closure, and confirm the
run-and-observe rule applies uniformly across tiers rather than adding new prose to it.

**Tasks**:

- [ ] Re-read `context/contracts/phase-closure.md:45-60` and `:160-175` immediately before editing.
- [ ] At `phase-closure.md:53` (cheapest-closure-first ordering, which already names "a lower
      `**Verification Tier**`" as smallest-remaining-work), add one clause: a non-final phase whose
      cheaper tier is declared with its `**Tier Justification**` stated closes that phase
      legitimately — the cheaper tier is the phase's declared verification, not a shortcut around
      it, and cheapest-closure-first ordering must not be read as second-guessing a justified tier
      choice.
- [ ] At `phase-closure.md:167-169`, make **no change to the run-and-observe rule itself** — it
      already applies uniformly regardless of tier. Add only a cross-reference making that
      uniformity explicit: what must be run and observed green is the phase's *declared* tier, so a
      justified cheaper tier is discharged by running that tier's named check, and a `full`
      declaration is discharged only by the complete gate set.
- [ ] Confirm the no-promotion-without-evidence direction is textually unweakened: a cheaper tier
      changes *what* must be observed green, never *whether* it must be.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The edit is confined to one contract markdown file, two clause-level
insertions, no externally visible signature. `suite_selection_select` returns `__FULL_SWEEP__` for
this path, so no suite subset is claimed; the covering check is
`verify-deploy.sh --only-gate 3,4` plus a diff read-through confirming the run-and-observe rule at
:167-169 is unweakened. The file is read by implementers, not executed, so no runtime surface exists
for a `full` sweep to cover.

**Files to modify**:

- `agent-system/extensions/core/context/contracts/phase-closure.md` - one clause at :53; one
  cross-reference clause at :167-169.

**Verification**:

- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` — gate 4 green; gate 3 drift limited to
  this phase's own file.
- Diff read-through confirms the no-promotion-without-evidence sentences at :167-169 are present and
  unweakened — the added text must be additive cross-reference only.
- `grep -n 'Tier Justification' agent-system/extensions/core/context/contracts/phase-closure.md`
  returns at least one hit at the :53 clause.

---

### Phase 5: Cross-surface agreement audit, replay evidence, and incidental label fix [NOT STARTED]

**Goal**: Prove the four surfaces agree and that no unqualified tie-break copy survives anywhere
(acceptance item 5, by grep, since a second copy is the drift mechanism); record the live-instance
replay as evidence (acceptance item 2); and fix the one stale descriptive label outside the four
files.

**Tasks**:

- [ ] `grep -rn 'strictest applicable tier' agent-system/extensions/` across the whole source store.
      Every surviving hit must be the qualified form. Zero occurrences of the unconditional sentence
      in any file.
- [ ] `grep -rn 'Tier Justification' agent-system/extensions/` — confirm the field appears in all
      four in-scope files and that its stated content bar is identical in each (the two tier-dependent
      bars, the one-line instruction). Read the four passages side by side; a paraphrase that drifts
      in substance is a failure even if the field name matches.
- [ ] Confirm by grep that `--skip-slow` is nowhere presented as a tier in any of the four files, and
      that the doc-sync-pin caveat appears as a cross-reference to
      `context/standards/shell-script-testing.md:178-183` rather than a third verbatim copy
      (Decision 3).
- [ ] Fix the stale label at `rules/plan-format-enforcement.md:43`: "tie-break-upward rule" ->
      "tie-break rule". One phrase; no other content in that file changes. Re-read the file
      immediately beforehand.
- [ ] Record the live-instance replay as acceptance-item-2 evidence **in this task's specs artifacts
      only** (never in an edited deliverable file, per the deliverable rule). The replay target is
      the archived mid-task phase at
      `specs/archive/361_reclassify_bare_git_stash_as_destructive/plans/01_reclassify-stash-destructive.md:426`,
      which declared `full` to verify edits to `hooks/guard-destructive-git.sh` and
      `scripts/lib/push-grant-lib.sh`. Under the new guidance it selects `interface`, and the
      covering suite is established mechanically, not asserted: `suite_selection_select` resolves
      `push-grant-lib.sh` to exactly `test-guard-destructive-git.sh`, `test-guard-git-push.sh`,
      `test-please-grant.sh`, and `guard-destructive-git.sh` to an 8-suite set including
      `test-guard-destructive-git.sh` — so `test-guard-destructive-git.sh` covers **both** edited
      files and was in fact already run directly one line above the `full` requirement in that
      plan. Re-run `suite_selection_select` against both paths at implementation time and record the
      actual output; do not copy these suite names forward unverified.
- [ ] Confirm acceptance item 4 holds for the guidance as written: the final phase of every plan
      still declares `full` and names the complete gate set per `plan-format.md:279-282` — verified
      by reading the Phase 1 text, since `:279-282` was required to be byte-unchanged.

**Timing**: 0.75 hours

**Depends on**: 2, 3, 4

**Verification Tier**: interface

**Tier Justification**: This phase's own edit is a one-phrase label fix in a fifth file, but its
*verification* reaches across all five edited files to prove cross-surface agreement — the
multi-file consistency check is exactly the `interface` tier's "changed file plus its enumerated
dependents" shape, with the four in-scope files as the enumerated dependent set. No suite covers any
of these markdown paths (`suite_selection_select` returns `__FULL_SWEEP__` for
`rules/plan-format-enforcement.md`), so the covering check is the grep proofs above plus
`verify-deploy.sh --only-gate 3,4`.

**Scope Hypothesis**: This phase asserts the edit is exactly one phrase in one file and that the
grep sweep finds no fifth independent copy of the tie-break rule. Confirm with
`git diff --stat -- agent-system/extensions/core/rules/plan-format-enforcement.md` (one changed
line) and by reading every hit of the corpus-wide grep rather than only counting them. If a fifth
independent copy *is* found, stop and report it rather than silently widening scope.

**Files to modify**:

- `agent-system/extensions/core/rules/plan-format-enforcement.md` - :43, "tie-break-upward rule" ->
  "tie-break rule". One phrase only.

**Verification**:

- `grep -rn 'strictest applicable tier' agent-system/extensions/` — every hit is the qualified form;
  zero unconditional occurrences (acceptance item 5).
- `grep -rn 'Tier Justification' agent-system/extensions/` — present in all four in-scope files,
  substantively identical content bar in each, confirmed by reading the four passages.
- `grep -rn 'tie-break-upward' agent-system/extensions/` returns zero hits.
- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` — gate 4 green; gate 3 drift limited to
  this task's own edited files.
- The replay evidence is recorded in this task's specs artifacts with the actual
  `suite_selection_select` output pasted, and zero task-number references appear in any edited
  deliverable file.

---

### Phase 6: Redeploy and final gate set [NOT STARTED]

**Goal**: Regenerate the deploy tree from the source store and run the complete gate set, clearing
the source-store-ahead-of-deploy drift that Phases 1-5 knowingly deferred. This is the final phase
per Decision 2 — highest-numbered, terminal, transitively dependent on all others.

**Tasks**:

- [ ] Re-read all five edited files once more (concurrent siblings are active on this tree) and
      confirm the working tree contains only this task's own changes plus known sibling work.
- [ ] Redeploy the source store: `bash .claude/scripts/deploy-headless.sh`.
- [ ] Confirm the five edited files propagated to their `.claude/**` counterparts and that the
      deployed copies match the source-store copies.
- [ ] Run the complete gate set: `timeout 3000 bash .claude/scripts/verify-deploy.sh`. All gates
      green, including gate 3 (doc-lint) and gate 4 (task-reference lint), whose drift findings were
      expected until this redeploy, and gate 8 (the full shell test battery).
- [ ] If any gate fails, fix forward within this phase rather than deferring — this is the final
      gate and nothing is deferred past it.
- [ ] Record the acceptance-item-1 result: this plan declared tiers below `full` at every one of
      Phases 1-5, each with a stated `**Tier Justification**`, and its final gate passed. That is
      the end-to-end demonstration on an actual task, not a prose assertion.

**Timing**: 0.75 hours (dominated by gate 8 wall clock; see `context/standards/shell-script-testing.md`
for measured ranges on a loaded host)

**Depends on**: 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Verification**:

- `bash .claude/scripts/verify-deploy.sh` (source-store path:
  `agent-system/extensions/core/scripts/verify-deploy.sh`) — the complete gate set, all gates green,
  no gate skipped and no `--only-gate` or `--skip-slow` narrowing. Per
  `plan-format.md:279-282`, this phase names the complete gate set in its own verification criteria,
  and per the non-negotiable invariant at `plan-format.md:273-277` nothing is deferred past it.
- Deployed `.claude/**` copies of all five edited files match their `agent-system/extensions/core/**`
  sources.
- `grep` confirms zero task-number references in the five edited deliverable files.

---

## Testing & Validation

- [ ] `bash .claude/scripts/verify-deploy.sh` fully green at Phase 6 with no narrowing flags.
- [ ] Acceptance 1: this plan declared a tier below `full` at every non-final phase, each with a
      stated `**Tier Justification**`, and passed its final gate — demonstrated by execution.
- [ ] Acceptance 2: the live instance replays — the archived mid-task phase selects `interface`, and
      `suite_selection_select` output recorded in Phase 5 shows `test-guard-destructive-git.sh`
      covers both files that phase edited.
- [ ] Acceptance 3: a non-final `full` remains allowed and its justification is satisfiable —
      demonstrated by the worked `full` example at `task-breakdown.md:171` carrying a one-line
      justification naming its cross-cutting surface.
- [ ] Acceptance 4: the guidance still requires every plan's final phase to declare `full` and name
      the complete gate set; `plan-format.md:279-282` is byte-unchanged.
- [ ] Acceptance 5: `grep -rn 'strictest applicable tier' agent-system/extensions/` shows zero
      unqualified occurrences across the corpus; all four surfaces agree.
- [ ] Acceptance 6: `planner-agent.md`'s authoring checklist checks the `**Tier Justification**`
      field, and a plan missing it on a non-final phase is detectable there.
- [ ] `plan-format.md:273-277`'s non-negotiable invariant survives verbatim in force.
- [ ] `--skip-slow` is nowhere presented as a tier; no cheaper tier is presented as discharging
      doc-sync-pin evidence.

## Artifacts & Outputs

- `agent-system/extensions/core/context/formats/plan-format.md` (modified — authoritative contract)
- `agent-system/extensions/core/agents/planner-agent.md` (modified — three enforcement points)
- `agent-system/extensions/core/context/workflows/task-breakdown.md` (modified — templates and
  three worked examples)
- `agent-system/extensions/core/context/contracts/phase-closure.md` (modified — two clauses)
- `agent-system/extensions/core/rules/plan-format-enforcement.md` (modified — one stale phrase)
- Regenerated `.claude/**` deploy tree (Phase 6)
- `specs/368_tier_selection_discipline_non_final_full/summaries/01_*-summary.md` (implementation
  summary, carrying the Phase 5 replay evidence)

## Rollback/Contingency

All six phases are documentation-only edits to a source store under version control, each committed
per-substep. Rollback is `git revert` of the phase commits, in reverse order, followed by
`bash .claude/scripts/deploy-headless.sh` to regenerate the deploy tree from the reverted source.
No schema, state, or script behavior changes, so no data migration or state repair is involved.

Contingency within the phases: if Phase 5's corpus-wide grep finds a fifth file carrying an
independent copy of the tie-break rule (research found none, but the sweep is the proof rather than
the assumption), stop and report it rather than widening scope mid-phase — a fifth copy changes the
acceptance-item-5 surface and warrants an explicit scope decision.

If Phase 6's final gate fails on something outside this task's five files, check whether a
concurrent sibling's in-flight edit explains it (`git log`, `git status`) before treating it as a
regression from this task — three sibling tasks are dispatched on this same working tree this cycle.
